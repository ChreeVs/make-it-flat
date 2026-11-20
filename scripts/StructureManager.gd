class_name StructureManager
extends Node3D

@export var block_size: float = 1.0 # passo griglia = dimensione delle forme dei blocchi (1m)

var all_blocks: Array[DestructibleBlock] = []
var active_intact_blocks: Array[DestructibleBlock] = []
var grid_map: Dictionary = {} # Vector3i -> DestructibleBlock
var anchored_blocks: Array[DestructibleBlock] = []

var total_initial_mass: float = 0.0
var destroyed_mass: float = 0.0
var threshold_reached: bool = false
var xray_active: bool = false

# Tracciamento completamento per piano (premi intermedi durante la demolizione del grattacielo!)
var floor_names: Dictionary = {}        # int -> String
var _floor_total_count: Dictionary = {} # int -> int
var _floor_broken_count: Dictionary = {} # int -> int
var _floor_cleared: Dictionary = {}     # int -> bool

var _counted_block_ids: Dictionary = {} # instance_id -> true
var _bfs_scheduled: bool = false

const XRAY_REMAINING_RATIO: float = 0.85 # outline quando resta < 15% della massa

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
	_floor_total_count.clear()
	_floor_broken_count.clear()
	_floor_cleared.clear()
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
			if b.floor_index >= 0:
				_floor_total_count[b.floor_index] = int(_floor_total_count.get(b.floor_index, 0)) + 1

	if total_initial_mass <= 0.0:
		total_initial_mass = 1.0

func _record_block_counted(b: DestructibleBlock) -> void:
	var bid: int = b.get_instance_id()
	if _counted_block_ids.has(bid):
		return
	_counted_block_ids[bid] = true
	destroyed_mass += b.mass
	if b.floor_index >= 0:
		var f: int = b.floor_index
		var broken: int = int(_floor_broken_count.get(f, 0)) + 1
		_floor_broken_count[f] = broken
		if not bool(_floor_cleared.get(f, false)):
			var total_f: int = int(_floor_total_count.get(f, 1))
			if float(broken) / float(maxi(total_f, 1)) >= 0.84:
				_floor_cleared[f] = true
				var f_name: String = String(floor_names.get(f, "Piano %d" % f))
				var bonus: float = EconomyManager.get_floor_clear_bonus(f)
				EconomyManager.add_money(bonus)
				var stats: Dictionary = SaveManager.save_data.get("stats", {})
				stats["floors_cleared"] = int(stats.get("floors_cleared", 0)) + 1
				SaveManager.save_data["stats"] = stats
				EventBus.floor_cleared.emit(f, f_name, bonus)
				EventBus.show_notification.emit(
					"PIANO DEMOLITO: %s! Premio +€ %d" % [f_name.to_upper(), int(bonus)],
					Color(0.32, 0.96, 0.56)
				)

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

	_record_block_counted(db)
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

	var visited: Dictionary = {}
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
			_record_block_counted(b)
			collapsed_mass += b.mass
		i -= 1

	if not disconnected.is_empty():
		for b in disconnected:
			b.activate_dynamic_debris(Vector3(0.0, -1.2, 0.0))
		EventBus.chain_collapse_triggered.emit(disconnected.size(), collapsed_mass)

		if disconnected.size() >= 6:
			EventBus.show_notification.emit(
				"CROLLO A CATENA! %d elementi (%.0f kg)" % [disconnected.size(), collapsed_mass],
				Color(1.0, 0.72, 0.18)
			)

	_emit_progress()

func _emit_progress() -> void:
	var ratio: float = clampf(destroyed_mass / maxf(total_initial_mass, 1.0), 0.0, 1.0)
	EventBus.contract_progress_updated.emit(ratio, destroyed_mass, total_initial_mass)

	var threshold: float = GameManager.current_contract.completion_threshold if GameManager.current_contract else 0.88
	if not threshold_reached and ratio >= threshold:
		threshold_reached = true
		EventBus.contract_threshold_reached.emit(GameManager.current_contract)

	# X-Ray anti pixel-hunting: solo quando resta meno del 15% della massa
	if not xray_active and ratio >= XRAY_REMAINING_RATIO:
		_enable_xray_on_remaining()

	# Soglia raggiunta -> il giocatore incassa con [E]; a demolizione totale il premio viene accreditato in automatico
	var fully_demolished: bool = ratio >= 0.999 or active_intact_blocks.is_empty()
	if threshold_reached and fully_demolished and GameManager.current_contract and not GameManager.contract_bonus_claimed:
		if GameManager.current_structure == self:
			GameManager.complete_current_contract()

# Query spaziale per danni ad area (C4, mazze): interroga la broadphase di Jolt sul layer
# Structure_Intact invece di scorrere tutti i blocchi della torre (fino a ~2000 in Hardcore).
func get_intact_blocks_in_radius(center: Vector3, radius: float) -> Array[DestructibleBlock]:
	var result: Array[DestructibleBlock] = []
	if not is_inside_tree() or radius <= 0.0:
		return result
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return _linear_blocks_in_radius(center, radius)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collision_mask = 4 # Layer 3: Structure_Intact
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hits: Array[Dictionary] = space.intersect_shape(q, 4096)
	var seen: Dictionary = {}
	for h in hits:
		var b := h.get("collider") as DestructibleBlock
		if b == null or seen.has(b) or b.is_destroyed or not b.freeze or b.get_parent() != self:
			continue
		seen[b] = true
		if b.global_position.distance_to(center) <= radius:
			result.append(b)
	return result

func _linear_blocks_in_radius(center: Vector3, radius: float) -> Array[DestructibleBlock]:
	var result: Array[DestructibleBlock] = []
	for b in active_intact_blocks:
		if is_instance_valid(b) and not b.is_destroyed and b.global_position.distance_to(center) <= radius:
			result.append(b)
	return result

func _enable_xray_on_remaining() -> void:
	if xray_active:
		return
	xray_active = true
	for b in active_intact_blocks:
		if is_instance_valid(b) and not b.is_destroyed and b.freeze:
			b.set_xray_highlight(true)
