class_name StructureManager
extends Node3D

@export var block_size: float = 0.5

var all_blocks: Array[DestructibleBlock] = []
var active_intact_blocks: Array[DestructibleBlock] = []
var grid_map: Dictionary = {} # Vector3i -> DestructibleBlock
var anchored_blocks: Array[DestructibleBlock] = []

var total_initial_mass: float = 0.0
var destroyed_mass: float = 0.0
var threshold_reached: bool = false
var xray_active: bool = false

var _counted_block_ids: Dictionary = {} # instance_id -> true
var _bfs_scheduled: bool = false

const DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1)
]

func _ready() -> void:
	_index_structure()
	EventBus.block_destroyed.connect(_on_block_destroyed)
	_emit_progress()

func _index_structure() -> void:
	all_blocks.clear()
	active_intact_blocks.clear()
	grid_map.clear()
	anchored_blocks.clear()
	_counted_block_ids.clear()
	total_initial_mass = 0.0
	destroyed_mass = 0.0
	threshold_reached = false
	xray_active = false

	for child in get_children():
		if child is DestructibleBlock:
			var b := child as DestructibleBlock
			all_blocks.append(b)
			active_intact_blocks.append(b)
			grid_map[b.grid_coord] = b
			total_initial_mass += b.mass
			if b.is_anchored:
				anchored_blocks.append(b)

	if total_initial_mass <= 0.0:
		total_initial_mass = 1.0

func _on_block_destroyed(block: Node3D, _by_gravity: bool) -> void:
	if not (block is DestructibleBlock):
		return
	var db := block as DestructibleBlock
	if db.get_parent() != self:
		return

	var coord: Vector3i = db.grid_coord
	if grid_map.get(coord) == db:
		grid_map.erase(coord)

	active_intact_blocks.erase(db)
	if db.is_anchored:
		anchored_blocks.erase(db)

	var bid: int = db.get_instance_id()
	if not _counted_block_ids.has(bid):
		_counted_block_ids[bid] = true
		destroyed_mass += db.mass

	_schedule_bfs()
	_emit_progress()

func _schedule_bfs() -> void:
	if _bfs_scheduled:
		return
	_bfs_scheduled = true
	call_deferred("_run_structural_bfs")

func _run_structural_bfs() -> void:
	_bfs_scheduled = false
	if active_intact_blocks.is_empty():
		_emit_progress()
		return

	# BFS O(V+E) con cursore a indice (evita O(N^2) di Array.pop_front)
	var visited: Dictionary = {} # Vector3i -> true
	var queue: Array[Vector3i] = []

	for anchor in anchored_blocks:
		if is_instance_valid(anchor) and not anchor.is_destroyed and anchor.freeze:
			var c: Vector3i = anchor.grid_coord
			if grid_map.has(c) and not visited.has(c):
				visited[c] = true
				queue.append(c)

	var head: int = 0
	while head < queue.size():
		var curr: Vector3i = queue[head]
		head += 1
		for dir in DIRECTIONS:
			var nxt: Vector3i = curr + dir
			if not visited.has(nxt) and grid_map.has(nxt):
				var nb: DestructibleBlock = grid_map[nxt]
				if is_instance_valid(nb) and not nb.is_destroyed and nb.freeze:
					visited[nxt] = true
					queue.append(nxt)

	var disconnected: Array[DestructibleBlock] = []
	var collapsed_mass: float = 0.0

	var i: int = active_intact_blocks.size() - 1
	while i >= 0:
		var b: DestructibleBlock = active_intact_blocks[i]
		if not is_instance_valid(b) or b.is_destroyed:
			active_intact_blocks.remove_at(i)
		elif not visited.has(b.grid_coord):
			active_intact_blocks.remove_at(i)
			grid_map.erase(b.grid_coord)
			disconnected.append(b)
			var bid: int = b.get_instance_id()
			if not _counted_block_ids.has(bid):
				_counted_block_ids[bid] = true
				destroyed_mass += b.mass
			collapsed_mass += b.mass
		i -= 1

	if not disconnected.is_empty():
		for b in disconnected:
			b.activate_dynamic_debris(Vector3(0.0, -1.2, 0.0))
		EventBus.chain_collapse_triggered.emit(disconnected.size(), collapsed_mass)

		if disconnected.size() >= 6:
			EventBus.show_notification.emit(
				"CROLLO A CATENA! %d blocchi (%.0f kg)" % [disconnected.size(), collapsed_mass],
				Color(1.0, 0.72, 0.18)
			)

	_emit_progress()

func _emit_progress() -> void:
	var ratio: float = clampf(destroyed_mass / maxf(total_initial_mass, 1.0), 0.0, 1.0)
	EventBus.contract_progress_updated.emit(ratio, destroyed_mass, total_initial_mass)

	var threshold: float = GameManager.current_contract.completion_threshold if GameManager.current_contract else 0.75
	if not threshold_reached and ratio >= threshold:
		threshold_reached = true
		_enable_xray_on_remaining()
		EventBus.contract_threshold_reached.emit(GameManager.current_contract)
		if GameManager.current_contract and not GameManager.contract_bonus_claimed:
			GameManager.complete_current_contract()

func _enable_xray_on_remaining() -> void:
	if xray_active:
		return
	xray_active = true
	for b in active_intact_blocks:
		if is_instance_valid(b) and not b.is_destroyed and b.freeze:
			b.set_xray_highlight(true)
