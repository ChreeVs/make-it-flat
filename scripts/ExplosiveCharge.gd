class_name ExplosiveCharge
extends Node3D

@export var explosion_radius: float = 3.5
@export var explosion_damage: float = 900.0
@export var explosion_impulse: float = 1200.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var led_light: OmniLight3D = $OmniLight3D

var is_detonated: bool = false
var target_block: DestructibleBlock

func _ready() -> void:
	# Bip/flash intermittente del LED rosso
	if led_light:
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(led_light, "light_energy", 1.5, 0.2)
		tween.tween_property(led_light, "light_energy", 0.0, 0.2)

func detonate() -> void:
	if is_detonated:
		return
	is_detonated = true

	# Scossa camera violenta
	EventBus.request_camera_shake.emit(0.65)
	EventBus.request_hitstop.emit(0.04)

	# Query fisica per blocchi nel raggio dell'onda d'urto
	var space_state := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 4 | 8 # Layer 3: Structure_Intact (4) e Layer 4: Debris_Large (8)

	var results := space_state.intersect_shape(query, 64)
	for res in results:
		var collider = res.collider
		if collider is DestructibleBlock and is_instance_valid(collider):
			var dist: float = global_position.distance_to(collider.global_position)
			var falloff: float = clamp(1.0 - (dist / explosion_radius), 0.35, 1.0)
			var dir: Vector3 = (collider.global_position - global_position).normalized()
			if dir == Vector3.ZERO:
				dir = Vector3.UP

			# Esplosivo C4 ha durezza Tier 4
			collider.take_damage(
				explosion_damage * falloff,
				4,
				collider.global_position,
				dir,
				explosion_impulse
			)
		elif collider is RigidBody3D and is_instance_valid(collider):
			var dir: Vector3 = (collider.global_position - global_position).normalized()
			collider.apply_impulse(dir * explosion_impulse, collider.global_position - global_position)

	# Effetto visivo particellare temporaneo
	_spawn_explosion_vfx()

	queue_free()

func _spawn_explosion_vfx() -> void:
	# Flash luminoso istantaneo
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.2)
	flash.light_energy = 5.0
	flash.omni_range = explosion_radius * 2.0
	get_parent().add_child(flash)
	flash.global_position = global_position

	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.25)
	tween.tween_callback(flash.queue_free)
