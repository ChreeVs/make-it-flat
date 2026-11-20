class_name Player
extends CharacterBody3D

@export var base_walk_speed: float = 5.4
@export var base_sprint_speed: float = 8.6
@export var base_crouch_speed: float = 2.5
@export var base_jump_velocity: float = 5.8
@export var mouse_sensitivity: float = 0.0024
@export var base_fov: float = 78.0
@export var sprint_fov: float = 84.0

const NORMAL_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.0
const NORMAL_HEAD_Y: float = 1.62
const CROUCH_HEAD_Y: float = 0.85

var is_crouching: bool = false
var current_crouch_ratio: float = 0.0
var _capsule_shape: CapsuleShape3D = null

const COYOTE_TIME_SEC: float = 0.12
const JUMP_BUFFER_SEC: float = 0.10
const FALL_RESPAWN_Y: float = -15.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var equipped_tool: ToolData = null
var attack_timer: float = 0.0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _bob_time: float = 0.0
var _shake_intensity: float = 0.0
var _sway_offset: Vector2 = Vector2.ZERO
var _tool_pivot_base_pos: Vector3 = Vector3(0.34, -0.26, -0.44)
var _swing_tween: Tween = null
var _current_tool_model: Node3D = null
var _hovered_block: DestructibleBlock = null
var _hitstop_active: bool = false

const TOOL_MODEL_PATHS: Dictionary = {
	&"crowbar": "res://scenes/tools/models/CrowbarModel.tscn",
	&"hammer": "res://scenes/tools/models/HammerModel.tscn",
	&"sledgehammer_3kg": "res://scenes/tools/models/Sledgehammer3kgModel.tscn",
	&"sledgehammer_8kg": "res://scenes/tools/models/Sledgehammer8kgModel.tscn",
	&"electric_demolisher": "res://scenes/tools/models/ElectricDemolisherModel.tscn",
	&"c4_charge": "res://scenes/tools/models/C4Model.tscn",
	&"remote_detonator": "res://scenes/tools/models/RemoteDetonatorModel.tscn"
}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var tool_pivot: Node3D = $Head/Camera3D/ToolPivot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		_capsule_shape = collision_shape.shape.duplicate() as CapsuleShape3D
		collision_shape.shape = _capsule_shape

	_tool_pivot_base_pos = tool_pivot.position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	EventBus.tool_equipped.connect(_on_tool_equipped)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.explosion_triggered.connect(_on_explosion_shake)
	EventBus.chain_collapse_triggered.connect(_on_collapse_shake)

	var initial_tool: ToolData = EconomyManager.get_tool_data(EconomyManager.equipped_tool_id)
	if not initial_tool:
		initial_tool = load("res://data/tools/crowbar.tres")
	if initial_tool:
		_apply_tool(initial_tool)

func _input(event: InputEvent) -> void:
	# Cliccando nella finestra con i menu chiusi, cattura subito il cursore per visuale libera
	if event is InputEventMouseButton and event.pressed:
		if not GameManager.is_shop_open and not GameManager.is_contract_menu_open:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if GameManager.is_shop_open or GameManager.is_contract_menu_open:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		rotate_y(-mm.relative.x * mouse_sensitivity)
		head.rotate_x(-mm.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-86.0), deg_to_rad(86.0))
		_sway_offset.x = clampf(_sway_offset.x - mm.relative.x * 0.0005, -0.035, 0.035)
		_sway_offset.y = clampf(_sway_offset.y + mm.relative.y * 0.0005, -0.03, 0.03)

	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var slot_idx: int = -1
		match key_event.physical_keycode:
			KEY_1: slot_idx = 0
			KEY_2: slot_idx = 1
			KEY_3: slot_idx = 2
			KEY_4: slot_idx = 3
			KEY_5: slot_idx = 4
			KEY_6: slot_idx = 5
			KEY_7: slot_idx = 6
		if slot_idx >= 0 and slot_idx < EconomyManager.TOOL_ORDER.size():
			var tid: StringName = EconomyManager.TOOL_ORDER[slot_idx]
			if EconomyManager.unlocked_tools.has(String(tid)):
				EconomyManager.equip_tool(tid)
			else:
				EventBus.show_notification.emit("Strumento bloccato! Apri lo Shop [B] per sbloccarlo.", Color(1.0, 0.65, 0.25))

	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_unlocked_tool(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_unlocked_tool(1)

func _cycle_unlocked_tool(step: int) -> void:
	var unlocked_ordered: Array[StringName] = []
	for tid in EconomyManager.TOOL_ORDER:
		if EconomyManager.unlocked_tools.has(String(tid)):
			unlocked_ordered.append(tid)
	if unlocked_ordered.size() <= 1:
		return
	var cur_idx: int = unlocked_ordered.find(EconomyManager.equipped_tool_id)
	if cur_idx == -1:
		cur_idx = 0
	var next_idx: int = (cur_idx + step + unlocked_ordered.size()) % unlocked_ordered.size()
	EconomyManager.equip_tool(unlocked_ordered[next_idx])

func _on_tool_equipped(tool_data: Resource) -> void:
	if tool_data is ToolData:
		_apply_tool(tool_data as ToolData)

func _on_upgrade_purchased(up_id: StringName, _lvl: int, _cost: float) -> void:
	if up_id == &"reach_distance":
		_update_raycast_reach()

func _apply_tool(tool_data: ToolData) -> void:
	equipped_tool = tool_data
	_update_raycast_reach()
	_rebuild_tool_model()

func _update_raycast_reach() -> void:
	if not interaction_ray:
		return
	var base_reach: float = equipped_tool.reach_distance if equipped_tool else 3.5
	var reach_mult: float = EconomyManager.get_upgrade_total_multiplier(&"reach_distance")
	interaction_ray.target_position = Vector3(0.0, 0.0, -(base_reach * reach_mult))

func _rebuild_tool_model() -> void:
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	if is_instance_valid(_current_tool_model):
		_current_tool_model.queue_free()
		_current_tool_model = null

	if not equipped_tool:
		return

	var path: String = TOOL_MODEL_PATHS.get(equipped_tool.tool_id, "")
	if path != "" and ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		if scene:
			_current_tool_model = scene.instantiate() as Node3D
			tool_pivot.add_child(_current_tool_model)
			_current_tool_model.position = Vector3.ZERO
			_current_tool_model.rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	# Respawn di sicurezza se il giocatore cade fuori mappa
	if global_position.y < FALL_RESPAWN_Y:
		global_position = GameManager.PLAYER_SAFE_SPAWN
		velocity = Vector3.ZERO

	if GameManager.is_shop_open or GameManager.is_contract_menu_open:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Gestione Crouch (Ctrl o C)
	var prev_crouching: bool = is_crouching
	is_crouching = Input.is_action_pressed("crouch") and not GameManager.is_shop_open and not GameManager.is_contract_menu_open
	if is_crouching != prev_crouching:
		EventBus.player_stance_changed.emit(is_crouching)

	current_crouch_ratio = lerpf(current_crouch_ratio, 1.0 if is_crouching else 0.0, 14.0 * delta)
	head.position.y = lerpf(NORMAL_HEAD_Y, CROUCH_HEAD_Y, current_crouch_ratio)
	if _capsule_shape:
		var target_h: float = lerpf(NORMAL_HEIGHT, CROUCH_HEIGHT, current_crouch_ratio)
		_capsule_shape.height = target_h
		collision_shape.position.y = target_h * 0.5

	# Movimento con upgrade player_speed, Coyote Time e Jump Buffer
	var speed_mult: float = EconomyManager.get_upgrade_total_multiplier(&"player_speed")
	if is_on_floor():
		_coyote_timer = COYOTE_TIME_SEC
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_SEC
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = base_jump_velocity * (1.0 + (speed_mult - 1.0) * 0.45)
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	# Taglio variabile del salto per massimo controllo
	if Input.is_action_just_released("jump") and velocity.y > 1.8:
		velocity.y *= 0.52

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var is_sprinting: bool = Input.is_action_pressed("sprint") and direction.length_squared() > 0.01 and not is_crouching

	var target_speed: float
	if is_crouching:
		target_speed = base_crouch_speed * speed_mult
	elif is_sprinting:
		target_speed = base_sprint_speed * speed_mult
	else:
		target_speed = base_walk_speed * speed_mult

	if direction.length_squared() > 0.001:
		velocity.x = lerpf(velocity.x, direction.x * target_speed, 14.0 * delta)
		velocity.z = lerpf(velocity.z, direction.z * target_speed, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)

	move_and_slide()

	# FOV dinamico durante lo sprint
	var target_fov: float = sprint_fov if is_sprinting else base_fov
	camera.fov = lerpf(camera.fov, target_fov, 10.0 * delta)

	# Weapon bob + mouse sway + camera micro-shake
	_update_camera_and_weapon_feel(delta)

	# Aggiorna blocco mirato per l'ispettore HUD
	_update_hovered_block()

	# Gestione attacco / piazzamento / detonatore
	if attack_timer > 0.0:
		attack_timer -= delta

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and equipped_tool:
		var is_single_trigger: bool = (
			equipped_tool.behavior_type == ToolData.BehaviorType.EXPLOSIVE_PLACED
			or equipped_tool.behavior_type == ToolData.BehaviorType.REMOTE_DETONATOR
		)
		var wants_action: bool = Input.is_action_just_pressed("primary_action") if is_single_trigger else Input.is_action_pressed("primary_action")
		if wants_action and attack_timer <= 0.0:
			_perform_primary_action()

func _update_camera_and_weapon_feel(delta: float) -> void:
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_speed > 0.35:
		_bob_time += delta * (8.5 + horiz_speed * 0.45)
	else:
		_bob_time = 0.0

	var bob_x: float = sin(_bob_time) * 0.014 if horiz_speed > 0.35 else 0.0
	var bob_y: float = absf(cos(_bob_time)) * 0.014 if horiz_speed > 0.35 else 0.0

	_sway_offset = _sway_offset.lerp(Vector2.ZERO, 10.0 * delta)
	var target_pivot: Vector3 = _tool_pivot_base_pos + Vector3(bob_x + _sway_offset.x, -bob_y + _sway_offset.y, 0.0)
	tool_pivot.position = tool_pivot.position.lerp(target_pivot, 14.0 * delta)

	if _shake_intensity > 0.001:
		camera.h_offset = randf_range(-_shake_intensity, _shake_intensity)
		camera.v_offset = randf_range(-_shake_intensity, _shake_intensity)
		_shake_intensity = lerpf(_shake_intensity, 0.0, 14.0 * delta)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _update_hovered_block() -> void:
	var hit_block: DestructibleBlock = null
	if interaction_ray.is_colliding():
		var col := interaction_ray.get_collider()
		if col is DestructibleBlock and not col.is_destroyed:
			hit_block = col as DestructibleBlock

	if hit_block != _hovered_block:
		_hovered_block = hit_block
		EventBus.target_block_hovered.emit(_hovered_block)

func _perform_primary_action() -> void:
	var spd_mult: float = EconomyManager.get_upgrade_total_multiplier(&"attack_speed")
	attack_timer = maxf(equipped_tool.attack_cooldown / spd_mult, 0.055)
	EventBus.tool_swung.emit(equipped_tool)

	match equipped_tool.behavior_type:
		ToolData.BehaviorType.REMOTE_DETONATOR:
			_play_button_press_animation()
			GameManager.detonate_all_explosives_sequentially()
			return
		ToolData.BehaviorType.EXPLOSIVE_PLACED:
			_try_place_c4()
			return
		ToolData.BehaviorType.CONTINUOUS_DRILL:
			_play_drill_animation()
		_:
			_play_swing_animation()

	if not interaction_ray.is_colliding():
		return

	var collider := interaction_ray.get_collider()
	var hit_pos: Vector3 = interaction_ray.get_collision_point()
	var hit_normal: Vector3 = interaction_ray.get_collision_normal()

	var dmg_mult: float = EconomyManager.get_upgrade_total_multiplier(&"tool_damage")
	var total_dmg: float = equipped_tool.base_damage * dmg_mult
	var broke_any: bool = false

	if collider is DestructibleBlock and not collider.is_destroyed:
		var block := collider as DestructibleBlock
		var was_alive: bool = not block.is_destroyed
		block.take_damage(total_dmg, equipped_tool.hardness_penetration, hit_pos, hit_normal)
		if was_alive and block.is_destroyed:
			broke_any = true
		_add_shake(0.032 if equipped_tool.aoe_radius > 0.0 else 0.016)

		# Danno AoE per mazze pesanti
		if equipped_tool.aoe_radius > 0.05:
			broke_any = _apply_aoe_damage(hit_pos, block, total_dmg * 0.65, equipped_tool.aoe_radius) or broke_any
	elif collider is RigidBody3D:
		var rb := collider as RigidBody3D
		if not rb.freeze:
			rb.apply_impulse(-camera.global_transform.basis.z * equipped_tool.impact_impulse * 0.15, hit_pos - rb.global_position)

	if broke_any and equipped_tool.behavior_type != ToolData.BehaviorType.CONTINUOUS_DRILL:
		_trigger_hitstop(0.028)

func _apply_aoe_damage(center: Vector3, exclude_block: DestructibleBlock, aoe_dmg: float, radius: float) -> bool:
	var broke_any: bool = false
	var sm := GameManager.current_structure as StructureManager
	if not is_instance_valid(sm):
		return false

	var snapshot: Array[DestructibleBlock] = sm.active_intact_blocks.duplicate()
	for b in snapshot:
		if not is_instance_valid(b) or b.is_destroyed or b == exclude_block:
			continue
		var dist: float = b.global_position.distance_to(center)
		if dist <= radius:
			var falloff: float = 1.0 - (dist / (radius + 0.001)) * 0.45
			b.take_damage(aoe_dmg * falloff, equipped_tool.hardness_penetration, b.global_position, Vector3.UP)
			if b.is_destroyed:
				broke_any = true
	return broke_any

func _try_place_c4() -> void:
	if not interaction_ray.is_colliding():
		EventBus.show_notification.emit("Avvicinati a un pilastro o muro per piazzare il C4!", Color(1.0, 0.65, 0.25))
		return

	var collider := interaction_ray.get_collider()
	if not (collider is DestructibleBlock):
		EventBus.show_notification.emit("Il C4 va piazzato direttamente sui blocchi della struttura!", Color(1.0, 0.65, 0.25))
		return

	var block := collider as DestructibleBlock
	var hit_pos: Vector3 = interaction_ray.get_collision_point()
	var hit_normal: Vector3 = interaction_ray.get_collision_normal().normalized()

	var c4_scene: PackedScene = load("res://scenes/tools/ExplosiveCharge.tscn")
	if not c4_scene:
		return

	var c4 := c4_scene.instantiate() as Node3D
	block.add_child(c4)
	c4.global_position = hit_pos + hit_normal * 0.08

	# Protezione look_at contro vettori collineari (superfici orizzontali pavimento/tetto)
	var up_ref: Vector3 = Vector3.RIGHT if absf(hit_normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
	c4.look_at(c4.global_position + hit_normal, up_ref)

	GameManager.register_explosive(c4)
	_play_button_press_animation()
	EventBus.ui_click.emit()
	EventBus.show_notification.emit(
		"C4 ARMATO (%d attivi) • Premi [7] Detonatore per innescare!" % GameManager.get_active_explosives_count(),
		Color(1.0, 0.42, 0.22)
	)

func _play_swing_animation() -> void:
	if not is_instance_valid(_current_tool_model):
		return
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_current_tool_model.rotation = Vector3.ZERO
	_current_tool_model.position = Vector3.ZERO

	var dur: float = clampf(equipped_tool.swing_duration, 0.08, 0.22)
	_swing_tween = create_tween()
	_swing_tween.tween_property(_current_tool_model, "rotation", Vector3(deg_to_rad(-58.0), deg_to_rad(14.0), deg_to_rad(22.0)), dur * 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_swing_tween.parallel().tween_property(_current_tool_model, "position", Vector3(-0.08, -0.05, -0.14), dur * 0.42)
	_swing_tween.tween_property(_current_tool_model, "rotation", Vector3.ZERO, dur * 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swing_tween.parallel().tween_property(_current_tool_model, "position", Vector3.ZERO, dur * 0.85)

func _play_drill_animation() -> void:
	if not is_instance_valid(_current_tool_model):
		return
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_current_tool_model.position = Vector3(randf_range(-0.015, 0.015), randf_range(-0.015, 0.015), -0.065)
	_swing_tween = create_tween()
	_swing_tween.tween_property(_current_tool_model, "position", Vector3.ZERO, 0.06)

func _play_button_press_animation() -> void:
	if not is_instance_valid(_current_tool_model):
		return
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_property(_current_tool_model, "position", Vector3(0.0, -0.04, -0.09), 0.07)
	_swing_tween.tween_property(_current_tool_model, "position", Vector3.ZERO, 0.12)

func _add_shake(amount: float) -> void:
	_shake_intensity = maxf(_shake_intensity, amount)

func _on_explosion_shake(world_pos: Vector3, radius: float) -> void:
	var dist: float = global_position.distance_to(world_pos)
	var factor: float = clampf(1.0 - dist / maxf(radius * 5.0, 12.0), 0.15, 1.0)
	_add_shake(0.14 * factor)
	_trigger_hitstop(0.035)

func _on_collapse_shake(count: int, _mass: float) -> void:
	_add_shake(clampf(0.02 + float(count) * 0.0025, 0.025, 0.11))

func _trigger_hitstop(duration_sec: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.25
	await get_tree().create_timer(duration_sec, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false
