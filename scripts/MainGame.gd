extends Node3D

@onready var structure_container: Node3D = $StructureHolder

func _ready() -> void:
	GameManager.structure_container = structure_container
	call_deferred("_load_initial_contract")

func _load_initial_contract() -> void:
	var start_path := "res://data/contracts/tier1_villa.tres"
	if not ResourceLoader.exists(start_path):
		start_path = "res://data/contracts/tier1_shack.tres"
	if ResourceLoader.exists(start_path):
		var contract: ContractData = load(start_path)
		if contract:
			GameManager.load_contract(contract)
