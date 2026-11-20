class_name ExplosiveCharge
extends Node3D

@export var blast_radius: float = 3.8
@export var base_blast_damage: float = 950.0
@export var blast_penetration: int = 4

var _detonated: bool = false
var _blink_time: float = 0.0

@onready var led_light: OmniLight3D = $OmniLight3D

func _process(delta: float) -> void:
	if _detonated:
		return
	_blink_time += delta
	if is_instance_valid(led_light):
		var pulse: float = 0.5 + 0.5 * sin(_blink_time * 10.0)
		led_light.light_energy = lerpf(0.25, 2.2, pulse)

func detonate() -> void:
	if _detonated:
		return
	_detonated = true

	var origin: Vector3 = global_position
	var effective_radius: float = blast_radius * EconomyManager.get_aoe_radius_multiplier()
	var total_dmg: float = base_blast_damage * EconomyManager.get_c4_damage_multiplier()

	_spawn_explosion_vfx(origin, effective_radius)
	EventBus.explosion_triggered.emit(origin, effective_radius)

	var sm := GameManager.current_structure as StructureManager
	if is_instance_valid(sm):
		var snapshot: Array[DestructibleBlock] = sm.active_intact_blocks.duplicate()
		for b in snapshot:
			if not is_instance_valid(b) or b.is_destroyed:
				continue
			var dist: float = b.global_position.distance_to(origin)
			if dist <= effective_radius:
				var falloff: float = clampf(1.0 - (dist / (effective_radius * 1.15)), 0.45, 1.0)
				var dir: Vector3 = (b.global_position - origin).normalized()
				if dir.length_squared() < 0.001:
					dir = Vector3.UP
				b.take_damage(total_dmg * falloff, blast_penetration, b.global_position, dir)

	queue_free()

func _spawn_explosion_vfx(origin: Vector3, radius: float) -> void:
	var root := get_tree().current_scene
	if not root:
		return

	var vfx_holder := Node3D.new()
	root.add_child(vfx_holder)
	vfx_holder.global_position = origin

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.62, 0.18)
	flash.light_energy = 12.0
	flash.omni_range = radius * 3.2
	vfx_holder.add_child(flash)

	var wave := MeshInstance3D.new()
	var smesh := SphereMesh.new()
	smesh.radius = 0.5
	smesh.height = 1.0
	wave.mesh = smesh
	var wmat := StandardMaterial3D.new()
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.albedo_color = Color(1.0, 0.58, 0.14, 0.72)
	wave.material_override = wmat
	vfx_holder.add_child(wave)

	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.96
	sparks.amount = 24
	sparks.lifetime = 0.62
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.18, 0.18, 0.18)
	sparks.mesh = pmesh
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 4.5
	sparks.initial_velocity_max = 11.0
	sparks.gravity = Vector3(0, -8.5, 0)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1.0, 0.45, 0.10)
	sparks.material_override = pmat
	vfx_holder.add_child(sparks)
	sparks.emitting = true

	var t := vfx_holder.create_tween()
	t.tween_property(wave, "scale", Vector3.ONE * (radius * 1.45), 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(wmat, "albedo_color:a", 0.0, 0.26)
	t.parallel().tween_property(flash, "light_energy", 0.0, 0.30)
	t.tween_interval(0.50)
	t.tween_callback(func():
		if is_instance_valid(vfx_holder):
			vfx_holder.queue_free()
	)
