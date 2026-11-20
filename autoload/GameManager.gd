extends Node

const PLAYER_SAFE_SPAWN := Vector3(0.0, 1.0, 9.5)

var current_contract: ContractData = null
var current_structure: Node3D = null
var structure_container: Node3D = null

var is_shop_open: bool = false
var is_contract_menu_open: bool = false
var contract_bonus_claimed: bool = false

var placed_explosives: Array[Node3D] = []

func _ready() -> void:
	EventBus.contract_selected.connect(_on_contract_selected)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_shop_open:
			var shop := get_tree().get_root().find_child("ShopMenu", true, false)
			if shop and shop.has_method("close_shop"):
				shop.close_shop()
				return
		if is_contract_menu_open:
			var cmenu := get_tree().get_root().find_child("ContractMenu", true, false)
			if cmenu and cmenu.has_method("close_menu"):
				cmenu.close_menu()
				return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_contract_selected(contract: ContractData) -> void:
	load_contract(contract)

func load_contract(contract: ContractData) -> void:
	if not contract:
		return
	current_contract = contract
	contract_bonus_claimed = false

	# Pulisci eventuali cariche C4 rimaste dal cantiere precedente
	clear_explosives()

	# Rimuovi vecchia struttura in modo pulito
	if is_instance_valid(current_structure):
		current_structure.queue_free()
		current_structure = null
		await get_tree().process_frame

	if not is_instance_valid(structure_container):
		var root := get_tree().current_scene
		if root:
			structure_container = root.find_child("StructureHolder", true, false) as Node3D
			if not is_instance_valid(structure_container):
				structure_container = root.find_child("StructureContainer", true, false) as Node3D

	if not is_instance_valid(structure_container):
		push_error("GameManager: StructureContainer non trovato nella scena corrente!")
		return

	if not contract.structure_scene:
		push_error("GameManager: structure_scene mancante nel contratto: %s" % contract.title)
		return

	var inst: Node3D = contract.structure_scene.instantiate() as Node3D
	if inst:
		structure_container.add_child(inst)
		current_structure = inst
		_reposition_player_safely()
		EventBus.show_notification.emit("Cantiere avviato: %s" % contract.title, Color(0.95, 0.80, 0.28))

func _reposition_player_safely() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if is_instance_valid(player):
		player.global_position = PLAYER_SAFE_SPAWN
		player.velocity = Vector3.ZERO
		player.rotation = Vector3.ZERO
		var head := player.get_node_or_null("Head") as Node3D
		if head:
			head.rotation = Vector3.ZERO

func restart_current_contract() -> void:
	if current_contract:
		load_contract(current_contract)

func complete_current_contract() -> void:
	if not current_contract or contract_bonus_claimed:
		return
	contract_bonus_claimed = true

	var bonus: float = current_contract.completion_bonus * EconomyManager.permanent_multiplier
	EconomyManager.add_money(bonus)

	var cid: String = String(current_contract.contract_id)
	var completed_list: Array = SaveManager.save_data.get("completed_contracts", [])
	if not completed_list.has(cid):
		completed_list.append(cid)
		SaveManager.save_data["completed_contracts"] = completed_list

	var stats: Dictionary = SaveManager.save_data.get("stats", {})
	stats["contracts_completed"] = int(stats.get("contracts_completed", 0)) + 1
	SaveManager.save_data["stats"] = stats

	# Sblocca automaticamente il Tier successivo se abbiamo completato un cantiere del Tier massimo attuale
	if current_contract.tier >= EconomyManager.unlocked_tier and current_contract.tier < 5:
		EconomyManager.unlock_tier(current_contract.tier + 1)
		EventBus.show_notification.emit(
			"CANTIERE COMPLETATO! +€%d  •  SBLOCCATO TIER %d!" % [int(bonus), EconomyManager.unlocked_tier],
			Color(0.30, 0.95, 0.48)
		)
	else:
		EventBus.show_notification.emit(
			"CANTIERE COMPLETATO! Premio incassato: +€%d" % int(bonus),
			Color(0.30, 0.95, 0.48)
		)

	SaveManager.save_game()
	EventBus.contract_completed.emit(current_contract)

func register_explosive(charge: Node3D) -> void:
	_prune_explosives()
	if is_instance_valid(charge) and not placed_explosives.has(charge):
		placed_explosives.append(charge)
	EventBus.explosives_count_changed.emit(placed_explosives.size())

func get_active_explosives_count() -> int:
	_prune_explosives()
	return placed_explosives.size()

func _prune_explosives() -> void:
	var alive: Array[Node3D] = []
	for c in placed_explosives:
		if is_instance_valid(c):
			alive.append(c)
	placed_explosives = alive

func clear_explosives() -> void:
	for c in placed_explosives:
		if is_instance_valid(c):
			c.queue_free()
	placed_explosives.clear()
	EventBus.explosives_count_changed.emit(0)

func detonate_all_explosives_sequentially() -> void:
	_prune_explosives()
	if placed_explosives.is_empty():
		EventBus.show_notification.emit("Nessuna carica C4 piazzata!", Color(1.0, 0.55, 0.25))
		return

	var queue: Array[Node3D] = placed_explosives.duplicate()
	placed_explosives.clear()
	EventBus.explosives_count_changed.emit(0)

	for charge in queue:
		if is_instance_valid(charge) and charge.has_method("detonate"):
			charge.detonate()
			await get_tree().create_timer(0.18).timeout
