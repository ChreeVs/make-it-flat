extends Node

const MAX_ACTIVE_DEBRIS: int = 75
const DEBRIS_SETTLE_TIME_SEC: float = 1.6
const MAX_DEBRIS_LIFETIME_SEC: float = 5.5
const SETTLE_SPEED_THRESHOLD: float = 0.45

# Ogni entry: { "body": DestructibleBlock, "still_time": float, "life_time": float }
var active_debris: Array[Dictionary] = []

func register_debris(body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return

	# Evita doppie registrazioni e ripulisci riferimenti morti
	var i: int = active_debris.size() - 1
	while i >= 0:
		var entry_body: Variant = active_debris[i].get("body")
		if not is_instance_valid(entry_body):
			active_debris.remove_at(i)
		elif entry_body == body:
			return
		i -= 1

	active_debris.append({
		"body": body,
		"still_time": 0.0,
		"life_time": 0.0
	})

	# Se superiamo il budget di macerie dinamiche, incassa e dissolvi subito la più vecchia
	while active_debris.size() > MAX_ACTIVE_DEBRIS:
		var oldest: Dictionary = active_debris.pop_front()
		var old_body: Variant = oldest.get("body")
		if is_instance_valid(old_body):
			_dissolve_and_pay(old_body as RigidBody3D)

func _physics_process(delta: float) -> void:
	var i: int = active_debris.size() - 1
	while i >= 0:
		var entry: Dictionary = active_debris[i]
		var raw_body: Variant = entry.get("body")
		if not is_instance_valid(raw_body):
			active_debris.remove_at(i)
			i -= 1
			continue

		var body: RigidBody3D = raw_body as RigidBody3D
		entry["life_time"] = float(entry["life_time"]) + delta
		var speed: float = body.linear_velocity.length()

		if speed < SETTLE_SPEED_THRESHOLD or body.sleeping:
			entry["still_time"] = float(entry["still_time"]) + delta
		else:
			entry["still_time"] = 0.0

		# Rimuovi sia quando si ferma sia dopo il limite massimo (evita macerie che rotolano all'infinito)
		if float(entry["still_time"]) >= DEBRIS_SETTLE_TIME_SEC or float(entry["life_time"]) >= MAX_DEBRIS_LIFETIME_SEC or body.global_position.y < -10.0:
			active_debris.remove_at(i)
			_dissolve_and_pay(body)

		i -= 1

func _dissolve_and_pay(body: RigidBody3D) -> void:
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return

	# Evita doppi incassi sullo stesso blocco
	if body is DestructibleBlock:
		var block := body as DestructibleBlock
		if block.is_destroyed:
			return
		block.is_destroyed = true

		if block.material_data:
			var payout: float = EconomyManager.calculate_block_payout(block.material_data, true)
			EconomyManager.add_money(payout)
			EventBus.show_floating_text.emit(
				"+€%d" % int(round(payout)),
				block.global_position + Vector3(0, 0.35, 0),
				Color(0.35, 0.96, 0.50)
			)
		EventBus.block_destroyed.emit(block, true)

	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze = true

	var tween: Tween = body.create_tween()
	tween.tween_property(body, "scale", Vector3(0.05, 0.05, 0.05), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(body):
			body.queue_free()
	)

func clear_all() -> void:
	for entry in active_debris:
		var b: Variant = entry.get("body")
		if is_instance_valid(b):
			(b as RigidBody3D).queue_free()
	active_debris.clear()
