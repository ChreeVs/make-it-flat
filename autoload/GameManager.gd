extends Node

var current_contract: ContractData = null
var current_structure: Node3D = null
var is_shop_open: bool = false
var is_contract_menu_open: bool = false
var placed_explosives: Array[Node] = []

func _ready() -> void:
	EventBus.contract_selected.connect(load_contract)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Se il cursore è catturato, mostralo, altrimenti ricatturalo
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			if not is_shop_open and not is_contract_menu_open:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func load_contract(contract: ContractData) -> void:
	current_contract = contract
	DebrisPool.clear_all()
	
	if is_instance_valid(current_structure):
		current_structure.queue_free()
		await get_tree().process_frame

	if contract and contract.structure_scene:
		var scene_inst: Node3D = contract.structure_scene.instantiate()
		var structures_root: Node = get_tree().get_root().find_child("StructureHolder", true, false)
		if structures_root:
			structures_root.add_child(scene_inst)
		else:
			get_tree().current_scene.add_child(scene_inst)
		current_structure = scene_inst

func complete_current_contract() -> void:
	if current_contract:
		EconomyManager.add_money(current_contract.completion_bonus)
		EventBus.show_notification.emit(
			"Cantiere Completato! Bonus: +€%.0f" % current_contract.completion_bonus,
			Color(0.2, 1.0, 0.4)
		)
		EventBus.contract_completed.emit(current_contract)
		
		var completed_list: Array = SaveManager.save_data.get("completed_contracts", [])
		if not completed_list.has(String(current_contract.contract_id)):
			completed_list.append(String(current_contract.contract_id))
			SaveManager.save_data["completed_contracts"] = completed_list
			SaveManager.save_game()

func restart_current_contract() -> void:
	if current_contract:
		load_contract(current_contract)

func register_explosive(charge: Node) -> void:
	if not placed_explosives.has(charge):
		placed_explosives.append(charge)

func detonate_all_explosives_sequentially() -> void:
	if placed_explosives.is_empty():
		EventBus.show_notification.emit("Nessuna carica C4 piazzata!", Color(1.0, 0.4, 0.4))
		return

	var charges: Array[Node] = []
	for c in placed_explosives:
		if is_instance_valid(c):
			charges.append(c)
	placed_explosives.clear()

	for charge in charges:
		if is_instance_valid(charge) and charge.has_method("detonate"):
			charge.detonate()
			await get_tree().create_timer(0.15, true, false, true).timeout
