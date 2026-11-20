class_name MaterialData
extends Resource

@export var material_id: StringName = &"wood_plank"
@export var display_name: String = "Legno Grezzo"
@export_range(1, 5) var hardness_tier: int = 1
@export var max_hp: float = 100.0
@export var mass_kg: float = 20.0
@export var base_money_value: float = 10.0
@export var is_composite: bool = false
@export var color: Color = Color(0.65, 0.45, 0.25)
@export var dust_color: Color = Color(0.75, 0.65, 0.5)
@export var fractured_scene: PackedScene
@export var impact_sounds: Array[AudioStream] = []
@export var break_sounds: Array[AudioStream] = []
