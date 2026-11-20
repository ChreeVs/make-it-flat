extends Node

const MAX_ACTIVE_LARGE_DEBRIS: int = 150
const MAX_ACTIVE_SMALL_SHARDS: int = 120

var active_large_debris: Array[RigidBody3D] = []
var active_shards: Array[Node3D] = []

func _ready() -> void:
	EventBus.debris_registered.connect(register_debris)

func _physics_process(delta: float) -> void:
	var i: int = active_large_debris.size() - 1
	while i >= 0:
		var body: RigidBody3D = active_large_debris[i]
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			active_large_debris.remove_at(i)
		elif body.sleeping:
			var sleep_time: float = body.get_meta("sleep_timer", 0.0) + delta
			body.set_meta("sleep_timer", sleep_time)
			if sleep_time > 2.0:
				active_large_debris.remove_at(i)
				_dissolve_debris(body)
		i -= 1

func register_debris(body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return
	body.set_meta("sleep_timer", 0.0)
	body.set_meta("spawn_time", Time.get_ticks_msec())
	active_large_debris.append(body)

	while active_large_debris.size() > MAX_ACTIVE_LARGE_DEBRIS:
		var oldest: RigidBody3D = active_large_debris.pop_front()
		if is_instance_valid(oldest) and not oldest.is_queued_for_deletion():
			_dissolve_debris(oldest)

func register_shard(shard: Node3D) -> void:
	if not is_instance_valid(shard):
		return
	active_shards.append(shard)
	while active_shards.size() > MAX_ACTIVE_SMALL_SHARDS:
		var oldest: Node3D = active_shards.pop_front()
		if is_instance_valid(oldest) and not oldest.is_queued_for_deletion():
			oldest.queue_free()

func _dissolve_debris(body: RigidBody3D) -> void:
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0

	var block_val: float = 0.0
	if body.has_method("get_residual_value"):
		block_val = body.get_residual_value()
	elif body.has_meta("residual_value"):
		block_val = float(body.get_meta("residual_value"))

	if block_val > 0.0:
		EconomyManager.add_money(block_val, body.global_position)
		EventBus.debris_despawned.emit(body, block_val)

	var tween: Tween = create_tween()
	# Usa Vector3(0.01, 0.01, 0.01) invece di ZERO per evitare basi singolari in Jolt
	tween.tween_property(body, "scale", Vector3(0.01, 0.01, 0.01), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(body.queue_free)

func clear_all() -> void:
	for body in active_large_debris:
		if is_instance_valid(body):
			body.queue_free()
	active_large_debris.clear()

	for shard in active_shards:
		if is_instance_valid(shard):
			shard.queue_free()
	active_shards.clear()
