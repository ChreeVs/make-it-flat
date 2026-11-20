extends Node

const PLAYER_SAFE_SPAWN := Vector3(0.0, 1.0, 14.5)

var current_contract: ContractData = null
var current_structure: Node3D = null
var structure_container: Node3D = null

var is_main_menu_open: bool = true
var is_intro_open: bool = false
var is_pause_menu_open: bool = false
var is_settings_open: bool = false
var is_shop_open: bool = false
var is_skill_tree_open: bool = false
var is_contract_menu_open: bool = false
var contract_bonus_claimed: bool = false

var placed_explosives: Array[Node3D] = []

func _ready() -> void:
	EventBus.contract_selected.connect(_on_contract_selected)

func is_any_ui_open() -> bool:
	return (
		is_main_menu_open
		or is_intro_open
		or is_pause_menu_open
		or is_settings_open
		or is_shop_open
		or is_skill_tree_open
		or is_contract_menu_open
	)

# Usiamo _input invece di _unhandled_input per garantire che ESC / K / B funzionino
# SEMPRE anche se un pulsante o uno slider ha il focus della GUI!
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return

	if event.is_action_pressed("ui_cancel"):
		_handle_escape_key()
		get_viewport().set_input_as_handled()
		return

	# Non aprire overlay di gioco se siamo nel Menu Principale, Pausa, Intro o Impostazioni
	if is_main_menu_open or is_pause_menu_open or is_intro_open or is_settings_open:
		return

	if event.is_action_pressed("toggle_skills") or event.is_action_pressed("toggle_shop"):
		_toggle_upgrade_hub()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_contracts"):
		var cm := get_tree().get_root().find_child("ContractMenu", true, false)
		if cm:
			if cm.visible and cm.has_method("close_menu"):
				cm.close_menu()
			elif not cm.visible and cm.has_method("open_menu"):
				cm.open_menu()
			get_viewport().set_input_as_handled()

func _toggle_upgrade_hub() -> void:
	var st := get_tree().get_root().find_child("SkillTreeMenu", true, false)
	if not st:
		return
	if st.visible and st.has_method("close_menu"):
		st.close_menu()
	elif st.has_method("open_menu"):
		st.open_menu()

func _handle_escape_key() -> void:
	if is_main_menu_open:
		if is_settings_open:
			_close_node("SettingsMenu", "close_settings")
		elif is_intro_open:
			_close_node("MainMenu", "close_intro")
		return

	if is_settings_open:
		_close_node("SettingsMenu", "close_settings")
		return
	if is_skill_tree_open:
		_close_node("SkillTreeMenu", "close_menu")
		return
	if is_shop_open:
		_close_node("ShopMenu", "close_shop")
		return
	if is_contract_menu_open:
		_close_node("ContractMenu", "close_menu")
		return
	if is_intro_open:
		_close_node("MainMenu", "close_intro")
		return

	var main_menu := get_tree().get_root().find_child("MainMenu", true, false)
	if main_menu:
		if is_pause_menu_open and main_menu.has_method("resume_game"):
			main_menu.resume_game()
		elif not is_pause_menu_open and main_menu.has_method("open_pause_menu"):
			main_menu.open_pause_menu()

func _close_node(node_name: String, method_name: String) -> void:
	var node := get_tree().get_root().find_child(node_name, true, false)
	if node and node.has_method(method_name):
		node.call(method_name)

func close_gameplay_overlays(except_name: String = "") -> void:
	var pairs := [
		["ShopMenu", "close_shop"],
		["SkillTreeMenu", "close_menu"],
		["ContractMenu", "close_menu"],
		["SettingsMenu", "close_settings"]
	]
	for p in pairs:
		if p[0] == except_name:
			continue
		var n := get_tree().get_root().find_child(p[0], true, false)
		if n and n.visible and n.has_method(p[1]):
			n.call(p[1])

func _on_contract_selected(contract: ContractData) -> void:
	load_contract(contract)

func load_skyscraper_for_difficulty() -> void:
	var path := "res://data/contracts/tier5_skyscraper.tres"
	if ResourceLoader.exists(path):
		var c: ContractData = load(path)
		if c:
			await load_contract(c)

func load_contract(contract: ContractData) -> void:
	if not contract:
		return
	current_contract = contract
	contract_bonus_claimed = false
	clear_explosives()

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
		push_error("GameManager: StructureHolder non trovato nella scena corrente!")
		return

	if not contract.structure_scene:
		push_error("GameManager: structure_scene mancante nel contratto: %s" % contract.title)
		return

	var inst: Node3D = contract.structure_scene.instantiate() as Node3D
	if inst:
		structure_container.add_child(inst)
		current_structure = inst
		_reposition_player_safely()
		if not is_main_menu_open:
			var d_lbl: String = String(EconomyManager.get_difficulty_config().get("label", "FACILE"))
			EventBus.show_notification.emit(
				"Grattacielo pronto [%s — %d Piani Arredati]!" % [d_lbl, EconomyManager.get_target_skyscraper_floors()],
				Color(0.96, 0.78, 0.24)
			)

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

	var bonus: float = EconomyManager.get_contract_bonus(current_contract)
	EconomyManager.add_money(bonus)

	var cid: String = String(current_contract.contract_id)
	var completed_list: Array = SaveManager.save_data.get("completed_contracts", [])
	if not completed_list.has(cid):
		completed_list.append(cid)
		SaveManager.save_data["completed_contracts"] = completed_list

	var stats: Dictionary = SaveManager.save_data.get("stats", {})
	stats["contracts_completed"] = int(stats.get("contracts_completed", 0)) + 1
	SaveManager.save_data["stats"] = stats

	if current_contract.tier >= EconomyManager.unlocked_tier and current_contract.tier < 5:
		EconomyManager.unlock_tier(current_contract.tier + 1)

	EventBus.show_notification.emit(
		"GRATTACIELO RASO AL SUOLO! Premio Finale: +€%d" % int(bonus),
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
		EventBus.ui_error.emit()
		EventBus.show_notification.emit("Nessuna carica C4 piazzata!", Color(1.0, 0.55, 0.25))
		return

	var queue: Array[Node3D] = placed_explosives.duplicate()
	placed_explosives.clear()
	EventBus.explosives_count_changed.emit(0)

	for charge in queue:
		if is_instance_valid(charge) and charge.has_method("detonate"):
			charge.detonate()
			await get_tree().create_timer(0.18).timeout
