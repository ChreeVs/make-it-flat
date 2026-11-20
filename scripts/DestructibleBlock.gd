class_name DestructibleBlock
extends RigidBody3D

enum BlockShape {
	FULL_CUBE,
	PILLAR,
	WALL_X,
	WALL_Z,
	SLAB,
	SLAB_BOTTOM,
	BEAM_X,
	BEAM_Z,
	STAIR_NORTH,
	STAIR_SOUTH,
	STAIR_EAST,
	STAIR_WEST,
	ROOF_SLOPE_N,
	ROOF_SLOPE_S,
	WINDOW_X,
	WINDOW_Z,
	DOOR_LINTEL_X,
	DOOR_LINTEL_Z,
	FENCE_POST,
	FENCE_PANEL_X
}

@export var material_data: MaterialData
@export var is_anchored: bool = false
@export var grid_coord: Vector3i = Vector3i.ZERO
@export var block_shape: BlockShape = BlockShape.FULL_CUBE

var max_hp: float = 100.0
var current_hp: float = 100.0
var is_destroyed: bool = false
var _crack_stage: int = 0
var _xray_enabled: bool = false
var _instance_material: StandardMaterial3D = null
var _visual_meshes: Array[MeshInstance3D] = []

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Risorse statiche condivise + budget VFX per frame (zero lag durante esplosioni C4)
static var _base_material_cache: Dictionary = {}
static var _crack_materials: Array[StandardMaterial3D] = []
static var _xray_material: ShaderMaterial = null
static var _glass_material: StandardMaterial3D = null
static var _roof_material: StandardMaterial3D = null
static var _shard_mesh: BoxMesh = null
static var _particle_mesh: BoxMesh = null
static var _last_fx_frame: int = -1
static var _frame_particle_count: int = 0
static var _frame_shard_count: int = 0

func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	_ensure_shared_resources()
	_apply_material_properties()
	_build_architectural_geometry()

static func _ensure_shared_resources() -> void:
	if _crack_materials.is_empty():
		var paths := [
			"res://assets/textures/tex_cracks_stage1.png",
			"res://assets/textures/tex_cracks_stage2.png",
			"res://assets/textures/tex_cracks_stage3.png"
		]
		for p in paths:
			var cm := StandardMaterial3D.new()
			cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cm.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
			cm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			cm.uv1_triplanar = true
			if ResourceLoader.exists(p):
				cm.albedo_texture = load(p)
			_crack_materials.append(cm)

	if _xray_material == null:
		var sh_path := "res://assets/shaders/block_xray_outline.gdshader"
		if ResourceLoader.exists(sh_path):
			_xray_material = ShaderMaterial.new()
			_xray_material.shader = load(sh_path)

	if _glass_material == null:
		_glass_material = StandardMaterial3D.new()
		_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_material.albedo_color = Color(0.82, 0.94, 1.0, 0.72)
		_glass_material.roughness = 0.12
		_glass_material.metallic = 0.25
		if ResourceLoader.exists("res://assets/textures/tex_mat_glass.png"):
			_glass_material.albedo_texture = load("res://assets/textures/tex_mat_glass.png")

	if _roof_material == null:
		_roof_material = StandardMaterial3D.new()
		_roof_material.albedo_color = Color(0.95, 0.92, 0.88, 1.0)
		_roof_material.roughness = 0.84
		if ResourceLoader.exists("res://assets/textures/tex_roof_tiles.png"):
			_roof_material.albedo_texture = load("res://assets/textures/tex_roof_tiles.png")

	if _shard_mesh == null:
		_shard_mesh = BoxMesh.new()
		_shard_mesh.size = Vector3(0.22, 0.22, 0.22)

	if _particle_mesh == null:
		_particle_mesh = BoxMesh.new()
		_particle_mesh.size = Vector3(0.09, 0.09, 0.09)

func _get_or_create_base_material(mat_data: MaterialData) -> StandardMaterial3D:
	if block_shape == BlockShape.WINDOW_X or block_shape == BlockShape.WINDOW_Z:
		return _glass_material
	if block_shape == BlockShape.ROOF_SLOPE_N or block_shape == BlockShape.ROOF_SLOPE_S:
		return _roof_material

	var key: StringName = mat_data.material_id
	if _base_material_cache.has(key):
		return _base_material_cache[key] as StandardMaterial3D

	var std := StandardMaterial3D.new()
	std.albedo_color = mat_data.color
	std.roughness = mat_data.roughness
	std.metallic = mat_data.metallic
	std.uv1_scale = mat_data.uv_scale
	if mat_data.albedo_texture:
		std.albedo_texture = mat_data.albedo_texture
	if mat_data.normal_texture:
		std.normal_enabled = true
		std.normal_texture = mat_data.normal_texture
		std.normal_scale = 1.15
	_base_material_cache[key] = std
	return std

func _apply_material_properties() -> void:
	if not material_data:
		material_data = load("res://data/materials/wood_rotten.tres")
	if not material_data:
		return

	max_hp = material_data.max_hp
	if block_shape == BlockShape.WINDOW_X or block_shape == BlockShape.WINDOW_Z:
		max_hp = minf(max_hp * 0.25, 35.0)
	current_hp = max_hp
	mass = maxf(material_data.mass_kg, 1.0)

func _add_sub_box(size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, override_mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	var base_mat: Material = override_mat if override_mat != null else _get_or_create_base_material(material_data)
	mi.set_surface_override_material(0, base_mat)
	add_child(mi)
	_visual_meshes.append(mi)
	return mi

func _set_box_collision(size: Vector3, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> void:
	if not collision_shape:
		return
	var bs := BoxShape3D.new()
	bs.size = size
	collision_shape.shape = bs
	collision_shape.position = pos
	collision_shape.rotation_degrees = rot_deg

func _build_architectural_geometry() -> void:
	_visual_meshes.clear()
	var base_mat: StandardMaterial3D = _get_or_create_base_material(material_data)

	if block_shape == BlockShape.FULL_CUBE:
		if mesh_instance:
			mesh_instance.visible = true
			mesh_instance.set_surface_override_material(0, base_mat)
			_visual_meshes.append(mesh_instance)
		return

	# Per tutte le forme scolpite nascondiamo il cubo base e costruiamo geometria architettonica
	if mesh_instance:
		mesh_instance.visible = false

	match block_shape:
		BlockShape.PILLAR:
			# Colonna strutturale con basamento e capitello
			_add_sub_box(Vector3(0.56, 0.84, 0.56), Vector3(0, 0, 0), Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(0.74, 0.12, 0.74), Vector3(0, -0.44, 0), Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(0.74, 0.12, 0.74), Vector3(0, 0.44, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.68, 1.0, 0.68), Vector3.ZERO)

		BlockShape.WALL_X:
			_add_sub_box(Vector3(1.0, 1.0, 0.34), Vector3.ZERO, Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(1.0, 0.10, 0.40), Vector3(0, -0.45, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 1.0, 0.36), Vector3.ZERO)

		BlockShape.WALL_Z:
			_add_sub_box(Vector3(0.34, 1.0, 1.0), Vector3.ZERO, Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(0.40, 0.10, 1.0), Vector3(0, -0.45, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.36, 1.0, 1.0), Vector3.ZERO)

		BlockShape.SLAB:
			# Soletta calpestabile nella parte superiore della cella
			_add_sub_box(Vector3(1.0, 0.30, 1.0), Vector3(0, 0.35, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.30, 1.0), Vector3(0, 0.35, 0))

		BlockShape.SLAB_BOTTOM:
			_add_sub_box(Vector3(1.0, 0.28, 1.0), Vector3(0, -0.36, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.28, 1.0), Vector3(0, -0.36, 0))

		BlockShape.BEAM_X:
			_add_sub_box(Vector3(1.0, 0.38, 0.38), Vector3(0, 0.31, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.38, 0.38), Vector3(0, 0.31, 0))

		BlockShape.BEAM_Z:
			_add_sub_box(Vector3(0.38, 0.38, 1.0), Vector3(0, 0.31, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.38, 0.38, 1.0), Vector3(0, 0.31, 0))

		BlockShape.STAIR_NORTH, BlockShape.STAIR_SOUTH, BlockShape.STAIR_EAST, BlockShape.STAIR_WEST:
			_build_stair_geometry(base_mat)

		BlockShape.ROOF_SLOPE_N:
			_add_sub_box(Vector3(1.02, 0.20, 1.38), Vector3(0, 0.0, 0), Vector3(35.0, 0, 0), _roof_material)
			_set_box_collision(Vector3(1.0, 0.22, 1.35), Vector3(0, 0.0, 0), Vector3(35.0, 0, 0))

		BlockShape.ROOF_SLOPE_S:
			_add_sub_box(Vector3(1.02, 0.20, 1.38), Vector3(0, 0.0, 0), Vector3(-35.0, 0, 0), _roof_material)
			_set_box_collision(Vector3(1.0, 0.22, 1.35), Vector3(0, 0.0, 0), Vector3(-35.0, 0, 0))

		BlockShape.WINDOW_X:
			var frame_mat := _get_frame_material()
			_add_sub_box(Vector3(1.0, 0.12, 0.28), Vector3(0, -0.44, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(1.0, 0.10, 0.28), Vector3(0, 0.45, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.10, 0.80, 0.24), Vector3(-0.45, 0, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.10, 0.80, 0.24), Vector3(0.45, 0, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.84, 0.80, 0.08), Vector3.ZERO, Vector3.ZERO, _glass_material)
			_set_box_collision(Vector3(1.0, 1.0, 0.28), Vector3.ZERO)

		BlockShape.WINDOW_Z:
			var frame_mat := _get_frame_material()
			_add_sub_box(Vector3(0.28, 0.12, 1.0), Vector3(0, -0.44, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.28, 0.10, 1.0), Vector3(0, 0.45, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.24, 0.80, 0.10), Vector3(0, 0, -0.45), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.24, 0.80, 0.10), Vector3(0, 0, 0.45), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.08, 0.80, 0.84), Vector3.ZERO, Vector3.ZERO, _glass_material)
			_set_box_collision(Vector3(0.28, 1.0, 1.0), Vector3.ZERO)

		BlockShape.DOOR_LINTEL_X:
			_add_sub_box(Vector3(1.0, 0.34, 0.38), Vector3(0, 0.33, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.34, 0.38), Vector3(0, 0.33, 0))

		BlockShape.DOOR_LINTEL_Z:
			_add_sub_box(Vector3(0.38, 0.34, 1.0), Vector3(0, 0.33, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.38, 0.34, 1.0), Vector3(0, 0.33, 0))

		BlockShape.FENCE_POST:
			_add_sub_box(Vector3(0.26, 1.0, 0.26), Vector3.ZERO, Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(0.34, 0.10, 0.34), Vector3(0, 0.47, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.30, 1.0, 0.30), Vector3.ZERO)

		BlockShape.FENCE_PANEL_X:
			# 2 traversi orizzontali + 4 doghe verticali realistiche
			_add_sub_box(Vector3(1.0, 0.11, 0.12), Vector3(0, 0.26, 0), Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(1.0, 0.11, 0.12), Vector3(0, -0.26, 0), Vector3.ZERO, base_mat)
			for i in range(4):
				var px: float = -0.36 + float(i) * 0.24
				_add_sub_box(Vector3(0.16, 0.96, 0.08), Vector3(px, 0.0, 0.06), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.98, 0.20), Vector3.ZERO)

func _get_frame_material() -> StandardMaterial3D:
	if material_data:
		var key: StringName = material_data.material_id
		if _base_material_cache.has(key):
			return _base_material_cache[key] as StandardMaterial3D
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.24, 0.28, 0.34)
	fm.roughness = 0.55
	fm.metallic = 0.45
	return fm

func _build_stair_geometry(base_mat: StandardMaterial3D) -> void:
	# 4 gradini scolpiti + rampa di collisione inclinata a 45° per salita/discesa fluidissima
	var yaw: float = 0.0
	match block_shape:
		BlockShape.STAIR_NORTH: yaw = 0.0       # sale verso -Z
		BlockShape.STAIR_SOUTH: yaw = 180.0     # sale verso +Z
		BlockShape.STAIR_EAST:  yaw = -90.0     # sale verso +X
		BlockShape.STAIR_WEST:  yaw = 90.0      # sale verso -X

	var basis_rot := Basis(Vector3.UP, deg_to_rad(yaw))
	for i in range(4):
		var step_h: float = 0.25 * float(i + 1)
		var local_pos := Vector3(0.0, -0.5 + step_h * 0.5, 0.375 - float(i) * 0.25)
		var world_local: Vector3 = basis_rot * local_pos
		var step_size: Vector3 = Vector3(0.96, step_h, 0.26)
		if block_shape == BlockShape.STAIR_EAST or block_shape == BlockShape.STAIR_WEST:
			step_size = Vector3(0.26, step_h, 0.96)
		_add_sub_box(step_size, world_local, Vector3.ZERO, base_mat)

	# Rampa fisica fluida (45 gradi) lungo la diagonale della scala
	var ramp_rot := Vector3(45.0, yaw, 0.0)
	if block_shape == BlockShape.STAIR_EAST:
		ramp_rot = Vector3(0.0, 0.0, 45.0)
	elif block_shape == BlockShape.STAIR_WEST:
		ramp_rot = Vector3(0.0, 0.0, -45.0)
	elif block_shape == BlockShape.STAIR_SOUTH:
		ramp_rot = Vector3(-45.0, 0.0, 0.0)

	var ramp_size := Vector3(0.96, 0.20, 1.38)
	if block_shape == BlockShape.STAIR_EAST or block_shape == BlockShape.STAIR_WEST:
		ramp_size = Vector3(1.38, 0.20, 0.96)
	_set_box_collision(ramp_size, Vector3(0.0, -0.06, 0.0), ramp_rot)

func _apply_material_to_all_meshes(mat: Material) -> void:
	for mi in _visual_meshes:
		if is_instance_valid(mi):
			mi.set_surface_override_material(0, mat)

func _ensure_instance_material() -> StandardMaterial3D:
	if _instance_material == null:
		var base := _get_or_create_base_material(material_data) if material_data else StandardMaterial3D.new()
		_instance_material = base.duplicate() as StandardMaterial3D
		_apply_material_to_all_meshes(_instance_material)
	return _instance_material

func _refresh_overlay_passes() -> void:
	if _crack_stage == 0 and not _xray_enabled:
		if material_data:
			_apply_material_to_all_meshes(_get_or_create_base_material(material_data))
		_instance_material = null
		return

	var mat := _ensure_instance_material()
	var crack_mat: StandardMaterial3D = null
	if _crack_stage > 0 and _crack_stage <= _crack_materials.size():
		crack_mat = _crack_materials[_crack_stage - 1]

	if crack_mat != null and _xray_enabled and _xray_material != null:
		var crack_dup := crack_mat.duplicate() as StandardMaterial3D
		crack_dup.next_pass = _xray_material
		mat.next_pass = crack_dup
	elif crack_mat != null:
		mat.next_pass = crack_mat
	elif _xray_enabled and _xray_material != null:
		mat.next_pass = _xray_material
	else:
		mat.next_pass = null

func set_xray_highlight(enabled: bool) -> void:
	if is_destroyed or not freeze:
		enabled = false
	if _xray_enabled == enabled:
		return
	_xray_enabled = enabled
	_refresh_overlay_passes()

func take_damage(
	amount: float,
	tool_penetration: int = 1,
	hit_pos: Vector3 = Vector3.INF,
	normal: Vector3 = Vector3.UP
) -> void:
	if is_destroyed or amount <= 0.0:
		return
	if hit_pos == Vector3.INF:
		hit_pos = global_position

	var req_tier: int = material_data.hardness_tier if material_data else 1
	var actual_damage: float = amount

	if tool_penetration < req_tier:
		actual_damage = amount * 0.10
		EventBus.block_ricochet.emit(self, hit_pos, normal, req_tier)
		_spawn_hit_particles(hit_pos, normal, Color(1.0, 0.78, 0.22), 7, 4.2)
	else:
		var dcol: Color = material_data.dust_color if material_data else Color(0.7, 0.65, 0.6)
		_spawn_hit_particles(hit_pos, normal, dcol, 6, 3.0)

	current_hp = maxf(current_hp - actual_damage, 0.0)
	EventBus.block_damaged.emit(self, actual_damage, hit_pos, normal)

	_update_damage_visuals()
	_play_hit_jolt()

	if current_hp <= 0.0:
		shatter(false)

func _update_damage_visuals() -> void:
	var ratio: float = current_hp / maxf(max_hp, 1.0)
	var new_stage: int = 0
	if ratio <= 0.28:
		new_stage = 3
	elif ratio <= 0.56:
		new_stage = 2
	elif ratio <= 0.82:
		new_stage = 1

	if new_stage != _crack_stage:
		_crack_stage = new_stage
		_refresh_overlay_passes()

	if _instance_material != null and material_data:
		var darken: float = lerpf(0.74, 1.0, ratio)
		_instance_material.albedo_color = material_data.color * Color(darken, darken, darken, _instance_material.albedo_color.a)

func _play_hit_jolt() -> void:
	if is_destroyed or _visual_meshes.is_empty():
		return
	var target: MeshInstance3D = _visual_meshes[0]
	if not is_instance_valid(target):
		return
	target.scale = Vector3(0.94, 0.94, 0.94)
	var t: Tween = create_tween()
	t.tween_property(target, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func shatter(by_gravity: bool = false) -> void:
	if is_destroyed:
		return
	is_destroyed = true

	# Nessuna scritta fluttuante 3D: il denaro viene accumulato e animato nell'HUD senza lag
	var payout: float = EconomyManager.calculate_block_payout(material_data, by_gravity)
	EconomyManager.add_money(payout)

	var stats: Dictionary = SaveManager.save_data.get("stats", {})
	stats["blocks_destroyed"] = int(stats.get("blocks_destroyed", 0)) + 1
	stats["mass_demolished_kg"] = float(stats.get("mass_demolished_kg", 0.0)) + mass
	SaveManager.save_data["stats"] = stats

	var pos := global_position
	if not by_gravity:
		var dcol: Color = material_data.dust_color if material_data else Color(0.7, 0.65, 0.6)
		_spawn_hit_particles(pos, Vector3.UP, dcol, 10, 4.4)
		_spawn_shatter_shards(pos)

	EventBus.block_destroyed.emit(self, by_gravity)
	queue_free()

func activate_dynamic_debris(impulse: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed or not freeze:
		return

	set_xray_highlight(false)
	freeze = false
	collision_layer = 8
	collision_mask = 1 | 4 | 8

	var kick := impulse + Vector3(randf_range(-1.4, 1.4), randf_range(-0.6, 0.6), randf_range(-1.4, 1.4))
	apply_central_impulse(kick * clampf(mass * 0.12, 1.0, 14.0))
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 2.5)

	DebrisPool.register_debris(self)

func _check_fx_budget(is_shard: bool) -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != _last_fx_frame:
		_last_fx_frame = frame
		_frame_particle_count = 0
		_frame_shard_count = 0
	if is_shard:
		if _frame_shard_count >= 3:
			return false
		_frame_shard_count += 1
		return true
	if _frame_particle_count >= 4:
		return false
	_frame_particle_count += 1
	return true

func _spawn_hit_particles(pos: Vector3, normal: Vector3, color: Color, amount: int, speed: float) -> void:
	if not _check_fx_budget(false):
		return
	var root := get_tree().current_scene
	if not root:
		return

	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = 0.38
	p.mesh = _particle_mesh
	p.direction = (normal + Vector3(0, 0.4, 0)).normalized()
	p.spread = 52.0
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.25

	var pm := StandardMaterial3D.new()
	pm.albedo_color = color
	pm.roughness = 0.85
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = pm

	root.add_child(p)
	p.global_position = pos
	p.emitting = true

	var t := p.create_tween()
	t.tween_interval(0.55)
	t.tween_callback(func():
		if is_instance_valid(p):
			p.queue_free()
	)

func _spawn_shatter_shards(origin: Vector3) -> void:
	if not _check_fx_budget(true):
		return
	var root := get_tree().current_scene
	if not root:
		return

	var shard_mat: StandardMaterial3D = _get_or_create_base_material(material_data) if material_data else null
	for i in range(3):
		var shard := RigidBody3D.new()
		shard.collision_layer = 16
		shard.collision_mask = 1
		shard.mass = 2.0

		var mi := MeshInstance3D.new()
		mi.mesh = _shard_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if shard_mat:
			mi.set_surface_override_material(0, shard_mat)
		shard.add_child(mi)

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.22, 0.22, 0.22)
		cs.shape = box
		shard.add_child(cs)

		root.add_child(shard)
		shard.global_position = origin + Vector3(
			randf_range(-0.25, 0.25),
			randf_range(-0.25, 0.25),
			randf_range(-0.25, 0.25)
		)
		shard.linear_velocity = Vector3(
			randf_range(-4.0, 4.0),
			randf_range(1.6, 4.8),
			randf_range(-4.0, 4.0)
		)
		shard.angular_velocity = Vector3(
			randf_range(-7.0, 7.0),
			randf_range(-7.0, 7.0),
			randf_range(-7.0, 7.0)
		)

		var t := shard.create_tween()
		t.tween_interval(0.80)
		t.tween_property(shard, "scale", Vector3(0.05, 0.05, 0.05), 0.22)
		t.tween_callback(func():
			if is_instance_valid(shard):
				shard.queue_free()
		)
