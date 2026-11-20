class_name DestructibleBlock
extends RigidBody3D

@export var material_data: MaterialData
@export var is_anchored: bool = false
@export var grid_coord: Vector3i = Vector3i.ZERO

var max_hp: float = 100.0
var current_hp: float = 100.0
var is_destroyed: bool = false
var _crack_stage: int = 0
var _xray_enabled: bool = false
var _instance_material: StandardMaterial3D = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Risorse condivise statiche per minimizzare i draw-call e la memoria GPU
static var _base_material_cache: Dictionary = {} # StringName -> StandardMaterial3D
static var _crack_materials: Array[StandardMaterial3D] = []
static var _xray_material: ShaderMaterial = null
static var _shard_mesh: BoxMesh = null
static var _particle_mesh: BoxMesh = null

func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	_ensure_shared_resources()
	_apply_material_properties()

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
			cm.no_depth_test = false
			cm.uv1_triplanar = true
			cm.uv1_world_triplanar = false
			if ResourceLoader.exists(p):
				cm.albedo_texture = load(p)
			_crack_materials.append(cm)

	if _xray_material == null:
		var sh_path := "res://assets/shaders/block_xray_outline.gdshader"
		if ResourceLoader.exists(sh_path):
			_xray_material = ShaderMaterial.new()
			_xray_material.shader = load(sh_path)

	if _shard_mesh == null:
		_shard_mesh = BoxMesh.new()
		_shard_mesh.size = Vector3(0.24, 0.24, 0.24)

	if _particle_mesh == null:
		_particle_mesh = BoxMesh.new()
		_particle_mesh.size = Vector3(0.09, 0.09, 0.09)

func _get_or_create_base_material(mat_data: MaterialData) -> StandardMaterial3D:
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
	current_hp = max_hp
	mass = maxf(material_data.mass_kg, 1.0)

	if mesh_instance:
		mesh_instance.set_surface_override_material(0, _get_or_create_base_material(material_data))

func _ensure_instance_material() -> StandardMaterial3D:
	if _instance_material == null:
		var base := _get_or_create_base_material(material_data) if material_data else StandardMaterial3D.new()
		_instance_material = base.duplicate() as StandardMaterial3D
		if mesh_instance:
			mesh_instance.set_surface_override_material(0, _instance_material)
	return _instance_material

func _refresh_overlay_passes() -> void:
	if not mesh_instance:
		return
	if _crack_stage == 0 and not _xray_enabled:
		if material_data:
			mesh_instance.set_surface_override_material(0, _get_or_create_base_material(material_data))
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
		_spawn_hit_particles(hit_pos, normal, Color(1.0, 0.78, 0.22), 9, 4.5)
		EventBus.show_floating_text.emit("DURO! T%d" % req_tier, hit_pos + Vector3(0, 0.25, 0), Color(1.0, 0.36, 0.25))
	else:
		var dcol: Color = material_data.dust_color if material_data else Color(0.7, 0.65, 0.6)
		_spawn_hit_particles(hit_pos, normal, dcol, 8, 3.2)

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
		_instance_material.albedo_color = material_data.color * Color(darken, darken, darken, 1.0)

func _play_hit_jolt() -> void:
	if not mesh_instance or is_destroyed:
		return
	mesh_instance.scale = Vector3(0.93, 0.93, 0.93)
	var t: Tween = create_tween()
	t.tween_property(mesh_instance, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func shatter(by_gravity: bool = false) -> void:
	if is_destroyed:
		return
	is_destroyed = true

	var payout: float = EconomyManager.calculate_block_payout(material_data, by_gravity)
	EconomyManager.add_money(payout)

	var stats: Dictionary = SaveManager.save_data.get("stats", {})
	stats["blocks_destroyed"] = int(stats.get("blocks_destroyed", 0)) + 1
	stats["mass_demolished_kg"] = float(stats.get("mass_demolished_kg", 0.0)) + mass
	SaveManager.save_data["stats"] = stats

	var pos := global_position
	var col := Color(0.35, 0.96, 0.50) if by_gravity else Color(1.0, 0.88, 0.25)
	EventBus.show_floating_text.emit("+€%d" % int(round(payout)), pos + Vector3(0, 0.35, 0), col)

	if not by_gravity:
		var dcol: Color = material_data.dust_color if material_data else Color(0.7, 0.65, 0.6)
		_spawn_hit_particles(pos, Vector3.UP, dcol, 14, 4.8)
		_spawn_shatter_shards(pos)

	EventBus.block_destroyed.emit(self, by_gravity)
	queue_free()

func activate_dynamic_debris(impulse: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed or not freeze:
		return

	set_xray_highlight(false)
	freeze = false
	collision_layer = 8 # Debris_Large (bit 4)
	collision_mask = 1 | 4 | 8 # Ground + Intact + Debris

	var kick := impulse + Vector3(randf_range(-1.4, 1.4), randf_range(-0.6, 0.6), randf_range(-1.4, 1.4))
	apply_central_impulse(kick * clampf(mass * 0.12, 1.0, 14.0))
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 2.5)

	DebrisPool.register_debris(self)

func _spawn_hit_particles(pos: Vector3, normal: Vector3, color: Color, amount: int, speed: float) -> void:
	var root := get_tree().current_scene
	if not root:
		return

	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = 0.42
	p.mesh = _particle_mesh
	p.direction = (normal + Vector3(0, 0.4, 0)).normalized()
	p.spread = 52.0
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.35

	var pm := StandardMaterial3D.new()
	pm.albedo_color = color
	pm.roughness = 0.85
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = pm

	root.add_child(p)
	p.global_position = pos
	p.emitting = true

	var t := p.create_tween()
	t.tween_interval(0.65)
	t.tween_callback(func():
		if is_instance_valid(p):
			p.queue_free()
	)

func _spawn_shatter_shards(origin: Vector3) -> void:
	var root := get_tree().current_scene
	if not root:
		return

	var shard_mat: StandardMaterial3D = _get_or_create_base_material(material_data) if material_data else null
	for i in range(4):
		var shard := RigidBody3D.new()
		shard.collision_layer = 16 # Debris_Small
		shard.collision_mask = 1 # World_Ground only
		shard.mass = 2.0

		var mi := MeshInstance3D.new()
		mi.mesh = _shard_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if shard_mat:
			mi.set_surface_override_material(0, shard_mat)
		shard.add_child(mi)

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.24, 0.24, 0.24)
		cs.shape = box
		shard.add_child(cs)

		root.add_child(shard)
		shard.global_position = origin + Vector3(
			randf_range(-0.28, 0.28),
			randf_range(-0.28, 0.28),
			randf_range(-0.28, 0.28)
		)
		shard.linear_velocity = Vector3(
			randf_range(-4.5, 4.5),
			randf_range(1.8, 5.2),
			randf_range(-4.5, 4.5)
		)
		shard.angular_velocity = Vector3(
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0)
		)

		var t := shard.create_tween()
		t.tween_interval(0.95)
		t.tween_property(shard, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
		t.tween_callback(func():
			if is_instance_valid(shard):
				shard.queue_free()
		)
