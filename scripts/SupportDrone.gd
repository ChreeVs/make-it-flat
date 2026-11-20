class_name SupportDrone
extends Node3D

@export var orbit_radius: float = 6.5
@export var orbit_height: float = 7.5
@export var orbit_speed: float = 0.55

var _angle: float = 0.0
var _fire_timer: float = 0.0
var _laser_show_timer: float = 0.0
var _laser_mat: StandardMaterial3D = null

@onready var drone_body: Node3D = $DroneBody
@onready var laser_beam: MeshInstance3D = $LaserBeam

func _ready() -> void:
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.albedo_color = Color(0.22, 0.95, 1.0, 1.0)
	if laser_beam:
		laser_beam.material_override = _laser_mat
		laser_beam.visible = false

	_update_visibility()
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.prestige_performed.connect(func(_c, _m): _update_visibility())

func _on_upgrade_purchased(up_id: StringName, _lvl: int, _cost: float) -> void:
	if up_id == &"automation_drone":
		_update_visibility()

func _update_visibility() -> void:
	var lvl: int = EconomyManager.get_upgrade_level(&"automation_drone")
	visible = lvl > 0

func _physics_process(delta: float) -> void:
	var lvl: int = EconomyManager.get_upgrade_level(&"automation_drone")
	if lvl <= 0:
		if visible:
			visible = false
		return
	if not visible:
		visible = true

	_angle += orbit_speed * delta
	var center: Vector3 = Vector3(0.0, orbit_height, 0.0)
	var sm := GameManager.current_structure as StructureManager
	if is_instance_valid(sm):
		center.x = sm.global_position.x
		center.z = sm.global_position.z

	global_position = Vector3(
		center.x + cos(_angle) * orbit_radius,
		center.y + sin(_angle * 2.1) * 0.45,
		center.z + sin(_angle) * orbit_radius
	)

	if is_instance_valid(drone_body):
		drone_body.rotation.y = -_angle
		for r_name in ["RotorFL", "RotorFR", "RotorBL", "RotorBR"]:
			var r := drone_body.get_node_or_null(r_name) as Node3D
			if r:
				r.rotate_y(24.0 * delta)

	if _laser_show_timer > 0.0:
		_laser_show_timer -= delta
		if _laser_show_timer <= 0.0 and is_instance_valid(laser_beam):
			laser_beam.visible = false

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		var cooldown: float = maxf(1.25 - float(lvl) * 0.11, 0.30)
		_fire_timer = cooldown
		_fire_at_structure(lvl)

func _fire_at_structure(lvl: int) -> void:
	var sm := GameManager.current_structure as StructureManager
	if not is_instance_valid(sm) or sm.active_intact_blocks.is_empty():
		return

	# Scegli un blocco intatto valido dalla lista indicizzata O(1)
	var target: DestructibleBlock = null
	var count: int = sm.active_intact_blocks.size()
	for _attempt in range(5):
		var candidate: DestructibleBlock = sm.active_intact_blocks[randi() % count]
		if is_instance_valid(candidate) and not candidate.is_destroyed:
			target = candidate
			break
	if not target:
		return

	var dmg_mult: float = EconomyManager.get_upgrade_total_multiplier(&"tool_damage")
	var drone_dmg: float = (42.0 + float(lvl) * 38.0) * dmg_mult
	var drone_pen: int = clampi(2 + int(ceil(float(lvl) * 0.5)), 3, 5)

	var target_pos: Vector3 = target.global_position
	_show_laser(global_position + Vector3(0.0, -0.22, 0.0), target_pos)
	target.take_damage(drone_dmg, drone_pen, target_pos, Vector3.UP)

func _show_laser(from_pos: Vector3, to_pos: Vector3) -> void:
	if not is_instance_valid(laser_beam):
		return
	var diff: Vector3 = to_pos - from_pos
	var dist: float = diff.length()
	if dist < 0.05:
		return

	laser_beam.visible = true
	laser_beam.global_position = (from_pos + to_pos) * 0.5
	var dir: Vector3 = diff / dist
	var up_ref: Vector3 = Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	laser_beam.look_at(to_pos, up_ref)
	laser_beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	laser_beam.scale = Vector3(1.0, dist, 1.0)
	_laser_show_timer = 0.14
