class_name StructureManager
extends Node3D

signal structure_completed()
signal progress_updated(ratio: float)

@export var block_size: float = 0.5
@export var ground_tolerance: float = 0.35
@export var completion_threshold: float = 0.88

var all_blocks: Array[DestructibleBlock] = []
var active_intact_blocks: Dictionary = {} # DestructibleBlock -> bool
var grid_map: Dictionary = {} # Vector3i -> DestructibleBlock
var neighbors_map: Dictionary = {} # DestructibleBlock -> Array[DestructibleBlock]
var anchored_blocks: Array[DestructibleBlock] = []

var total_initial_mass: float = 0.0
var destroyed_mass: float = 0.0
var is_completed: bool = false
var outline_enabled: bool = false

func _ready() -> void:
	build_structure_graph()

func build_structure_graph() -> void:
	all_blocks.clear()
	active_intact_blocks.clear()
	grid_map.clear()
	neighbors_map.clear()
	anchored_blocks.clear()
	total_initial_mass = 0.0
	destroyed_mass = 0.0
	is_completed = false
	outline_enabled = false

	# 1. Trova tutti i DestructibleBlock figli
	_collect_blocks(self)

	# 2. Registra posizioni e ancoraggi
	for block in all_blocks:
		total_initial_mass += block.mass
		active_intact_blocks[block] = true
		
		# Calcola coordinata griglia deterministica per ogni blocco
		var local_pos: Vector3 = to_local(block.global_position)
		var gx: int = int(round(local_pos.x / block_size))
		var gy: int = int(round((local_pos.y - 0.5 * block_size) / block_size))
		var gz: int = int(round(local_pos.z / block_size))
		var coord := Vector3i(gx, gy, gz)
		block.grid_coord = coord

		grid_map[coord] = block
		var n_arr: Array[DestructibleBlock] = []
		neighbors_map[block] = n_arr

		# Determina se è ancorato a terra
		if block.is_anchored or block.global_position.y <= ground_tolerance:
			block.is_anchored = true
			anchored_blocks.append(block)

		# Connetti segnale distruzione
		block.block_destroyed.connect(_on_block_destroyed.bind(block))

	# 3. Costruisci le adiacenze (6 direzioni adiacenti ortogonali)
	var directions: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]

	for coord in grid_map.keys():
		var block: DestructibleBlock = grid_map[coord]
		var block_neighbors: Array[DestructibleBlock] = neighbors_map[block]

		for d in directions:
			var n_coord: Vector3i = coord + d
			if grid_map.has(n_coord):
				var neighbor: DestructibleBlock = grid_map[n_coord]
				if not block_neighbors.has(neighbor):
					block_neighbors.append(neighbor)

	EventBus.contract_progress_updated.emit(0.0, 0.0, total_initial_mass)

func _collect_blocks(node: Node) -> void:
	if node is DestructibleBlock:
		all_blocks.append(node)
	for child in node.get_children():
		_collect_blocks(child)

func _on_block_destroyed(by_gravity: bool, block: DestructibleBlock) -> void:
	if not active_intact_blocks.has(block):
		return

	active_intact_blocks.erase(block)
	anchored_blocks.erase(block)
	grid_map.erase(block.grid_coord)

	destroyed_mass += block.mass
	_update_progress()

	# Disconnetti dai vicini
	if neighbors_map.has(block):
		var n_list: Array[DestructibleBlock] = neighbors_map[block]
		for n in n_list:
			if neighbors_map.has(n):
				var neighbor_neighbors: Array[DestructibleBlock] = neighbors_map[n]
				neighbor_neighbors.erase(block)
		neighbors_map.erase(block)

	call_deferred("_evaluate_structural_integrity")

func _evaluate_structural_integrity() -> void:
	# BFS Multi-Sorgente partendo da tutti i blocchi ancorati ancora intatti
	var visited: Dictionary = {}
	var queue: Array[DestructibleBlock] = []

	for anchor in anchored_blocks:
		if is_instance_valid(anchor) and active_intact_blocks.has(anchor):
			visited[anchor] = true
			queue.append(anchor)

	while not queue.is_empty():
		var curr: DestructibleBlock = queue.pop_front()
		if not neighbors_map.has(curr):
			continue
		
		var neighbors: Array[DestructibleBlock] = neighbors_map[curr]
		for neighbor in neighbors:
			if is_instance_valid(neighbor) and active_intact_blocks.has(neighbor):
				if not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)

	var disconnected: Array[DestructibleBlock] = []
	var fallen_mass: float = 0.0

	for block in active_intact_blocks.keys():
		if not is_instance_valid(block):
			continue
		if not visited.has(block):
			disconnected.append(block)

	if disconnected.is_empty():
		return

	for block in disconnected:
		active_intact_blocks.erase(block)
		anchored_blocks.erase(block)
		grid_map.erase(block.grid_coord)
		neighbors_map.erase(block)

		fallen_mass += block.mass
		destroyed_mass += block.mass
		block.unfreeze_block()

	_update_progress()

	EventBus.chain_collapse_triggered.emit(disconnected.size(), fallen_mass)
	var shake_strength: float = clamp(fallen_mass * 0.003, 0.2, 0.8)
	EventBus.request_camera_shake.emit(shake_strength)

func _update_progress() -> void:
	if total_initial_mass <= 0.0:
		return

	var ratio: float = clamp(destroyed_mass / total_initial_mass, 0.0, 1.0)
	progress_updated.emit(ratio)
	EventBus.contract_progress_updated.emit(ratio, destroyed_mass, total_initial_mass)

	if (1.0 - ratio) <= 0.15 and not outline_enabled:
		outline_enabled = true
		for block in active_intact_blocks.keys():
			if is_instance_valid(block):
				block.set_highlight_outline(true)

	if ratio >= completion_threshold and not is_completed:
		is_completed = true
		structure_completed.emit()
		GameManager.complete_current_contract()
