class_name UpgradeData
extends Resource

enum Category {
	TOOL,
	PLAYER,
	ECONOMY,
	AUTOMATION
}

@export var upgrade_id: StringName = &"tool_damage"
@export var display_name: String = "Potenza d'Impatto"
@export var description: String = "+25% danno per ogni colpo"
@export var category: Category = Category.TOOL
@export var base_cost: float = 50.0
@export var cost_growth_factor: float = 1.18
@export var effect_per_level: float = 0.25
@export var max_level: int = 50
