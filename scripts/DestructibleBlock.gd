class_name DestructibleBlock
extends RigidBody3D

signal block_damaged(amount: float, remaining_hp: float)
signal block_destroyed(by_gravity: bool)

@export var material_data: MaterialData
@export var is_anchored: bool = false
@export var grid_coord: Vector3i = Vector3i.ZERO

var current_hp: float = 100.0
var max_hp: float = 100.0
var is_active_debris: bool = false
var is_destroyed: bool = false
var original_mesh: MeshInstance3D
var collision_shape: CollisionShape3D

# Shader/Material flash
var original_material: Material
var flash_material: StandardMaterial3D

func _ready() -> void:
	# Layer 3: Structure_Intact (bit 3 -> 4)
	# Mask: Layer 1 (World_Ground: 1) + Layer 2 (Player: 2) + Layer 4 (Debris_Large: 8) = 11
	collision_layer = 4
	collision_mask = 11

	# RigidBody3D static freeze mode per massima stabilità e zero jitter
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

	_setup_nodes()
	_apply_material_data()

func _setup_nodes() -> void:
	original_mesh = get_node_or_null("MeshInstance3D")
	collision_shape = get_node_or_null("CollisionShape3D")

	if original_mesh:
		var active_mat: Material = original_mesh.get_active_material(0)
		if active_mat:
			original_material = active_mat.duplicate()
		else:
			original_material = StandardMaterial3D.new()
		original_mesh.material_override = original_material

func _apply_material_data() -> void:
	if not material_data:
		return

	mass = material_data.mass_kg
	max_hp = material_data.max_hp
	current_hp = max_hp

	if original_material is StandardMaterial3D:
		original_material.albedo_color = material_data.color
		original_material.roughness = 0.85

func take_damage(amount: float, penetration: int, hit_pos: Vector3 = Vector3.ZERO, hit_normal: Vector3 = Vector3.UP, impulse: float = 0.0) -> void:
	if is_destroyed:
		return

	# Controllo Durezza
	if material_data and penetration < material_data.hardness_tier:
		# Strumento troppo debole: danno ridotto al 10%
		amount *= 0.1
		EventBus.show_notification.emit(
			"Durezza insufficiente! Serve strumento Tier %d" % material_data.hardness_tier,
			Color(1.0, 0.4, 0.4)
		)

	current_hp -= amount
	EventBus.block_damaged.emit(self, amount, hit_pos, hit_normal)
	block_damaged.emit(amount, current_hp)

	# Effetto hit flash visivo
	_visual_hit_flash()

	# Se il corpo è dinamico, applica impulso
	if not freeze and impulse > 0.0 and hit_normal != Vector3.ZERO:
		apply_impulse(-hit_normal * impulse, hit_pos - global_position)

	if current_hp <= 0.0:
		shatter(false)

func unfreeze_block() -> void:
	if is_active_debris or is_destroyed:
		return

	is_active_debris = true
	is_anchored = false

	# Layer 4: Debris_Large (bit 4 -> 8)
	# Mask: Layer 1 (1) + Layer 3 (4) + Layer 4 (8) = 13
	collision_layer = 8
	collision_mask = 13

	# Scongela simulazione fisica Jolt
	freeze = false

	# Abilita monitoraggio contatti per danno da impatto
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)

	# Piccolo micro-impulso per distacco naturale
	var random_impulse := Vector3(
		randf_range(-0.5, 0.5),
		randf_range(-0.3, -0.8),
		randf_range(-0.5, 0.5)
	) * 8.0
	apply_central_impulse(random_impulse)

	# Registra nel pool detriti
	EventBus.debris_registered.emit(self)

func _on_body_entered(body: Node) -> void:
	if is_destroyed:
		return

	# Calcola velocità d'impatto relativa
	var rel_vel: float = linear_velocity.length()
	if body is RigidBody3D:
		rel_vel = (linear_velocity - body.linear_velocity).length()

	# Se l'impatto supera la soglia di violenza (4.5 m/s)
	if rel_vel > 4.5:
		var impact_damage: float = (mass * rel_vel) * 0.35
		current_hp -= impact_damage
		if current_hp <= 0.0:
			shatter(true)

func shatter(by_gravity: bool) -> void:
	if is_destroyed:
		return
	is_destroyed = true

	EventBus.block_destroyed.emit(self, by_gravity, material_data, global_position)
	block_destroyed.emit(by_gravity)

	# Genera piccoli frammenti visivi (Layer 5: Debris_Small)
	_spawn_small_shards()

	# Rimuove collisioni e cancella il nodo
	queue_free()

func _spawn_small_shards() -> void:
	var shard_count: int = randi_range(3, 5)
	for i in range(shard_count):
		var shard := RigidBody3D.new()
		shard.collision_layer = 16 # Layer 5: Debris_Small
		shard.collision_mask = 1   # Solo con terreno Layer 1
		shard.mass = mass * 0.08

		var mesh_inst := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(randf_range(0.08, 0.16), randf_range(0.08, 0.16), randf_range(0.08, 0.16))
		mesh_inst.mesh = box_mesh
		
		var shard_mat := StandardMaterial3D.new()
		shard_mat.albedo_color = material_data.color if material_data else Color.GRAY
		shard_mat.roughness = 0.9
		mesh_inst.material_override = shard_mat
		shard.add_child(mesh_inst)

		var col_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_mesh.size
		col_shape.shape = shape
		shard.add_child(col_shape)

		get_parent().add_child(shard)
		shard.global_position = global_position + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3))
		
		var launch_vel := Vector3(randf_range(-3.0, 3.0), randf_range(2.0, 5.0), randf_range(-3.0, 3.0))
		shard.linear_velocity = launch_vel
		DebrisPool.register_shard(shard)

		# Auto-distruzione rapida per le schegge (evita scale=0 per Jolt)
		var tween: Tween = shard.create_tween()
		tween.tween_interval(3.0)
		tween.tween_property(shard, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tween.tween_callback(shard.queue_free)

func _visual_hit_flash() -> void:
	if not original_mesh:
		return

	var tween: Tween = create_tween()
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.8)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(0.8, 0.7, 0.5)
	original_mesh.material_override = flash_mat

	tween.tween_interval(0.04)
	tween.tween_callback(func():
		if is_instance_valid(original_mesh):
			original_mesh.material_override = original_material
	)

func set_highlight_outline(enabled: bool) -> void:
	if not original_mesh or not original_material is StandardMaterial3D:
		return
	if enabled:
		original_material.emission_enabled = true
		original_material.emission = Color(0.2, 0.8, 1.0)
		original_material.emission_energy_multiplier = 0.6
	else:
		original_material.emission_enabled = false

func get_residual_value() -> float:
	if material_data:
		return material_data.base_money_value * 0.5
	return 0.0
