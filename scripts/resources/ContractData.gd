class_name ContractData
extends Resource

@export var contract_id: StringName = &"tier1_fence"
@export var tier: int = 1
@export var title: String = "Staccionata Fatiscente"
@export_multiline var description: String = "Abbatti la vecchia staccionata in legno marcio e ripulisci il perimetro."
@export var structure_scene: PackedScene
@export var completion_threshold: float = 0.88
@export var completion_bonus: float = 150.0
@export var required_capital: float = 0.0
