class_name ToolData
extends Resource

enum BehaviorType {
	MELEE_SINGLE,
	CONTINUOUS_DRILL,
	EXPLOSIVE_PLACED,
	REMOTE_DETONATOR
}

@export var tool_id: StringName = &"crowbar"
@export var display_name: String = "Piede di Porco"
@export var unlock_cost: float = 0.0
@export var required_tier: int = 1
@export var base_damage: float = 35.0
@export var hardness_penetration: int = 1
@export var attack_cooldown: float = 0.35
@export var reach_distance: float = 3.5
@export var aoe_radius: float = 0.0
@export var behavior_type: BehaviorType = BehaviorType.MELEE_SINGLE
@export var impact_impulse: float = 120.0
@export var swing_duration: float = 0.15
@export var tool_color: Color = Color(0.8, 0.4, 0.2)
