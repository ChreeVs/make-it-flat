class_name Player
extends CharacterBody3D

@export var mouse_sensitivity: float = 0.002
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 5.5
@export var gravity: float = 18.0

# Camera & Shake
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var tool_pivot: Node3D = $Head/Camera3D/ToolPivot

# Tool & Attacco
var equipped_tool: ToolData
var attack_timer: float = 0.0
var is_swinging: bool = false

# Trauma / Shake
var trauma: float = 0.0
var trauma_power: float = 2.0
var trauma_decay: float = 2.5
var max_pitch: float = 0.05
var max_yaw: float = 0.05
var max_roll: float = 0.05

func _ready() -> void:
	# Layer 2: Player (bit 2 -> 2)
	# Mask: Layer 1 (1) + Layer 3 (4) + Layer 6 (32) = 37
	collision_layer = 2
	collision_mask = 37

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	EventBus.request_camera_shake.connect(add_trauma)
	EventBus.request_hitstop.connect(trigger_hitstop)
	EventBus.tool_equipped.connect(_on_tool_equipped)

	_load_initial_tool()

func _load_initial_tool() -> void:
	var tool_path: String = "res://data/tools/%s.tres" % EconomyManager.equipped_tool_id
	if ResourceLoader.exists(tool_path):
		equipped_tool = load(tool_path)
	else:
		equipped_tool = load("res://data/tools/crowbar.tres")
	_update_tool_visual()

func _on_tool_equipped(new_tool: ToolData) -> void:
	equipped_tool = new_tool
	_update_tool_visual()

func _update_tool_visual() -> void:
	if not equipped_tool or not tool_pivot:
		return

	for child in tool_pivot.get_children():
		child.queue_free()

	var model_scene_path: String = ""
	match equipped_tool.tool_id:
		&"crowbar":
			model_scene_path = "res://scenes/tools/models/CrowbarModel.tscn"
		&"hammer":
			model_scene_path = "res://scenes/tools/models/HammerModel.tscn"
		&"sledgehammer_3kg":
			model_scene_path = "res://scenes/tools/models/Sledgehammer3kgModel.tscn"
		&"sledgehammer_8kg":
			model_scene_path = "res://scenes/tools/models/Sledgehammer8kgModel.tscn"
		&"electric_demolisher":
			model_scene_path = "res://scenes/tools/models/ElectricDemolisherModel.tscn"
		&"c4_charge":
			model_scene_path = "res://scenes/tools/models/C4Model.tscn"
		&"remote_detonator":
			model_scene_path = "res://scenes/tools/models/RemoteDetonatorModel.tscn"

	if model_scene_path != "" and ResourceLoader.exists(model_scene_path):
		var model_scene: PackedScene = load(model_scene_path)
		var model_inst: Node3D = model_scene.instantiate()
		tool_pivot.add_child(model_inst)

	if interaction_ray:
		interaction_ray.target_position = Vector3(0, 0, -equipped_tool.reach_distance)

func _input(event: InputEvent) -> void:
	# Cliccando nella finestra, cattura subito il mouse se i menu sono chiusi
	if event is InputEventMouseButton and event.pressed:
		if not GameManager.is_shop_open and not GameManager.is_contract_menu_open:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Visuale libera FPS in prima persona: basta muovere il mouse senza tenere premuto nulla
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_attack(delta)
	_handle_camera_shake(delta)

func _handle_movement(delta: float) -> void:
	# Gravità
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Input direzionale
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed_mult: float = EconomyManager.get_upgrade_total_multiplier("player_speed") if EconomyManager else 1.0
	var current_speed: float = (sprint_speed if Input.is_action_pressed("sprint") else walk_speed) * speed_mult

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, current_speed * 8.0 * delta)

	move_and_slide()

func _handle_attack(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta

	if Input.is_action_pressed("primary_action") and attack_timer <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if equipped_tool:
			var speed_upgrade: float = EconomyManager.get_upgrade_total_multiplier("attack_speed") if EconomyManager else 1.0
			var cooldown: float = equipped_tool.attack_cooldown / speed_upgrade
			attack_timer = cooldown
			_execute_attack()

func _execute_attack() -> void:
	if not equipped_tool:
		return

	if equipped_tool.behavior_type == ToolData.BehaviorType.REMOTE_DETONATOR:
		_play_swing_animation()
		GameManager.detonate_all_explosives_sequentially()
		return

	if equipped_tool.behavior_type == ToolData.BehaviorType.EXPLOSIVE_PLACED:
		_play_swing_animation()
		if interaction_ray.is_colliding():
			var collider: Object = interaction_ray.get_collider()
			if collider is DestructibleBlock:
				_place_c4_on_block(collider, interaction_ray.get_collision_point(), interaction_ray.get_collision_normal())
		return

	if equipped_tool.behavior_type == ToolData.BehaviorType.CONTINUOUS_DRILL:
		_play_drill_animation()
	else:
		_play_swing_animation()

	if interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		var hit_pos: Vector3 = interaction_ray.get_collision_point()
		var hit_normal: Vector3 = interaction_ray.get_collision_normal()

		var damage_mult: float = EconomyManager.get_upgrade_total_multiplier("tool_damage") if EconomyManager else 1.0
		var final_damage: float = equipped_tool.base_damage * damage_mult

		if equipped_tool.aoe_radius > 0.0:
			_apply_aoe_damage(hit_pos, final_damage, equipped_tool.aoe_radius)
		else:
			if collider is DestructibleBlock:
				collider.take_damage(
					final_damage,
					equipped_tool.hardness_penetration,
					hit_pos,
					hit_normal,
					equipped_tool.impact_impulse
				)
				var trauma_amount: float = 0.05 if equipped_tool.behavior_type == ToolData.BehaviorType.CONTINUOUS_DRILL else 0.15
				add_trauma(trauma_amount)
				if equipped_tool.behavior_type != ToolData.BehaviorType.CONTINUOUS_DRILL:
					trigger_hitstop(0.02)
			elif collider is RigidBody3D:
				collider.apply_impulse(-hit_normal * equipped_tool.impact_impulse, hit_pos - collider.global_position)

func _place_c4_on_block(block: DestructibleBlock, hit_pos: Vector3, hit_normal: Vector3) -> void:
	var c4_scene: PackedScene = load("res://scenes/tools/ExplosiveCharge.tscn")
	var c4: Node3D = c4_scene.instantiate()
	block.add_child(c4)
	c4.global_position = hit_pos + hit_normal * 0.08
	
	if hit_normal != Vector3.UP and hit_normal != Vector3.DOWN:
		c4.look_at(hit_pos + hit_normal, Vector3.UP)

	GameManager.register_explosive(c4)
	EventBus.show_notification.emit("Carica C4 piazzata! (%d attive)" % GameManager.placed_explosives.size(), Color(0.2, 0.9, 0.4))

func _play_drill_animation() -> void:
	if not tool_pivot:
		return
	var offset := Vector3(randf_range(-0.015, 0.015), randf_range(-0.015, 0.015), randf_range(-0.06, 0.02))
	tool_pivot.position = Vector3(0.35, -0.25, -0.4) + offset

func _apply_aoe_damage(center_pos: Vector3, damage: float, radius: float) -> void:
	add_trauma(0.35)
	trigger_hitstop(0.03)

	var space_state := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), center_pos)
	query.collision_mask = 4 | 8 # Structure_Intact (4) e Debris_Large (8)

	var results := space_state.intersect_shape(query, 32)
	for res in results:
		var collider = res.collider
		if collider is DestructibleBlock and is_instance_valid(collider):
			var dist: float = center_pos.distance_to(collider.global_position)
			var falloff: float = clamp(1.0 - (dist / radius), 0.3, 1.0)
			var normal: Vector3 = (collider.global_position - center_pos).normalized()
			if normal == Vector3.ZERO:
				normal = Vector3.UP
			collider.take_damage(
				damage * falloff,
				equipped_tool.hardness_penetration,
				collider.global_position,
				normal,
				equipped_tool.impact_impulse
			)

func _play_swing_animation() -> void:
	if not tool_pivot:
		return
	var tween: Tween = create_tween()
	var initial_rot: Vector3 = Vector3(0, 0, 0)
	var swing_rot: Vector3 = Vector3(deg_to_rad(-45.0), deg_to_rad(30.0), deg_to_rad(-20.0))

	tween.tween_property(tool_pivot, "rotation", swing_rot, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(tool_pivot, "rotation", initial_rot, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func trigger_hitstop(duration: float = 0.025) -> void:
	Engine.time_scale = 0.1
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)

func _handle_camera_shake(delta: float) -> void:
	if trauma > 0.0:
		trauma = max(trauma - trauma_decay * delta, 0.0)
		var shake_amount: float = pow(trauma, trauma_power)
		camera.rotation.x = max_pitch * shake_amount * randf_range(-1.0, 1.0)
		camera.rotation.y = max_yaw * shake_amount * randf_range(-1.0, 1.0)
		camera.rotation.z = max_roll * shake_amount * randf_range(-1.0, 1.0)
	else:
		camera.rotation = Vector3.ZERO
