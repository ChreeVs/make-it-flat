extends Node

const MAX_ACTIVE_DEBRIS: int = 48
const DEBRIS_SETTLE_TIME_SEC: float = 1.4
const MAX_DEBRIS_LIFETIME_SEC: float = 4.6
const SETTLE_SPEED_THRESHOLD: float = 0.45

var active_debris: Array[Dictionary] = []

func register_debris(body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return

	for entry in active_debris:
		if entry["body"] == body:
			return

	active_debris.append({
		"body": body,
		"still_time": 0.0,
		"life_time": 0.0
	})

	while active_debris.size() > MAX_ACTIVE_DEBRIS:
		var oldest: Dictionary = active_debris.pop_front()
		if is_instance_valid(oldest["body"]):
			_dissolve_and_pay(oldest["body"])

func _physics_process(delta: float) -> void:
	var i: int = active_debris.size() - 1
	while i >= 0:
		var entry: Dictionary = active_debris[i]
		# Controllo di validità PRIMA dell'assegnazione tipizzata: assegnare un'istanza già liberata
		# (es. cantiere ricostruito con macerie in volo) a una var tipizzata genera un errore a ogni frame.
		var raw_body: Variant = entry["body"]
		if not is_instance_valid(raw_body):
			active_debris.remove_at(i)
			i -= 1
			continue
		var body: RigidBody3D = raw_body

		entry["life_time"] = float(entry["life_time"]) + delta
		var speed: float = body.linear_velocity.length()

		if speed < SETTLE_SPEED_THRESHOLD or body.sleeping:
			entry["still_time"] = float(entry["still_time"]) + delta
		else:
			entry["still_time"] = 0.0

		if float(entry["still_time"]) >= DEBRIS_SETTLE_TIME_SEC or float(entry["life_time"]) >= MAX_DEBRIS_LIFETIME_SEC or body.global_position.y < -10.0:
			active_debris.remove_at(i)
			_dissolve_and_pay(body)

		i -= 1

func _dissolve_and_pay(body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return

	if body is DestructibleBlock:
		var block := body as DestructibleBlock
		if block.is_destroyed:
			return
		block.is_destroyed = true

		# Nessuna scritta 3D fluttuante per evitare lag: accredita direttamente al contatore animato HUD
		if block.material_data:
			var payout: float = EconomyManager.calculate_block_payout(block.material_data, true)
			EconomyManager.add_money(payout)
		# Anche i blocchi crollati per gravità contano nelle statistiche di carriera
		var stats: Dictionary = SaveManager.save_data.get("stats", {})
		stats["blocks_destroyed"] = int(stats.get("blocks_destroyed", 0)) + 1
		stats["mass_demolished_kg"] = float(stats.get("mass_demolished_kg", 0.0)) + block.mass
		SaveManager.save_data["stats"] = stats
		EventBus.block_destroyed.emit(block, true)

	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze = true

	var tween: Tween = body.create_tween()
	# Si scala la parte visiva (scalare direttamente un RigidBody3D non è supportato dalla fisica)
	var visual: Node3D = body.get_node_or_null("Visual") as Node3D
	var target: Node3D = visual if visual else body
	tween.tween_property(target, "scale", Vector3(0.05, 0.05, 0.05), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(body):
			body.queue_free()
	)
