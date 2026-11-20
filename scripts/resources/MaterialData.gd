class_name MaterialData
extends Resource

@export var material_id: StringName = &"wood_rotten"
@export var display_name: String = "Legno Marcio"
@export var hardness_tier: int = 1
@export var max_hp: float = 40.0
@export var mass_kg: float = 20.0
@export var base_money_value: float = 10.0
@export var is_composite: bool = false
@export var color: Color = Color(0.95, 0.92, 0.88)
@export var dust_color: Color = Color(0.55, 0.42, 0.28)
@export var albedo_texture: Texture2D
@export var normal_texture: Texture2D
@export_range(0.0, 1.0) var roughness: float = 0.82
@export_range(0.0, 1.0) var metallic: float = 0.0
@export var uv_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

func get_residual_value() -> float:
	return base_money_value * 0.5
