class_name MainGame
extends Node3D

@onready var structure_holder: Node3D = $StructureHolder

func _ready() -> void:
	# Carica la prima commessa di default se non ancora attiva
	if GameManager.current_contract == null:
		var initial_contract: ContractData = load("res://data/contracts/tier1_shack.tres")
		if initial_contract:
			GameManager.load_contract(initial_contract)
