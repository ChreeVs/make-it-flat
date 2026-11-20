class_name SupportDrone
extends Node3D

@export var scan_interval: float = 1.2
@export var laser_damage: float = 75.0
@export var hover_height: float = 12.0

@onready var laser_mesh: MeshInstance3D = $LaserBeam
@onready var drone_body: MeshInstance3D = $DroneBody

var scan_timer: float = 0.0
var target_block: DestructibleBlock = null

func _ready() -> void:
	laser_mesh.visible = false

func _physics_process(delta: float) -> void:
	var drone_level: int = EconomyManager.get_upgrade_level("automation_drone") if EconomyManager else 0
	if drone_level <= 0:
		visible = false
		return
	
	visible = true
	var actual_damage: float = laser_damage * (1.0 + (drone_level - 1) * 0.4)
	var actual_speed: float = scan_interval / (1.0 + (drone_level - 1) * 0.2)

	# Movimento orbitale leggero
	var t: float = Time.get_ticks_msec() * 0.001
	global_position = Vector3(cos(t * 0.5) * 6.0, hover_height + sin(t) * 0.5, sin(t * 0.5) * 6.0)

	scan_timer += delta
	if scan_timer >= actual_speed:
		scan_timer = 0.0
		_acquire_and_attack_target(actual_damage)

func _acquire_and_attack_target(damage: float) -> void:
	var structure: StructureManager = GameManager.current_structure as StructureManager
	if not structure or structure.all_blocks.is_empty():
		return

	# Cerca il blocco intatto più vicino
	var closest_block: DestructibleBlock = null
	var min_dist: float = 999999.0

	for b in structure.all_blocks:
		if is_instance_valid(b) and not b.is_destroyed and not b.freeze == false:
			var d: float = global_position.distance_to(b.global_position)
			if d < min_dist:
				min_dist = d
				closest_block = b

	if closest_block:
		target_block = closest_block
		look_at(target_block.global_position, Vector3.UP)
		_fire_laser_at(target_block.global_position)
		target_block.take_damage(damage, 3, target_block.global_position, Vector3.UP, 40.0)

func _fire_laser_at(target_pos: Vector3) -> void:
	if not laser_mesh:
		return
	
	var dist: float = global_position.distance_to(target_pos)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.04
	cylinder.bottom_radius = 0.04
	cylinder.height = dist
	laser_mesh.mesh = cylinder

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	laser_mesh.material_override = mat

	laser_mesh.global_position = (global_position + target_pos) * 0.5
	laser_mesh.look_at(target_pos, Vector3.UP)
	laser_mesh.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	laser_mesh.visible = true

	var tween: Tween = create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func():
		if is_instance_valid(laser_mesh):
			laser_mesh.visible = false
	)
