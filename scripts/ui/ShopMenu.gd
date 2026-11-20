class_name ShopMenu
extends Control

@onready var money_label: Label = $Panel/Margin/VBox/Header/MoneyLabel
@onready var upgrades_container: VBoxContainer = $Panel/Margin/VBox/Scroll/ContentVBox/UpgradesList
@onready var tools_container: HBoxContainer = $Panel/Margin/VBox/Scroll/ContentVBox/ToolsList
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var prestige_label: Label = $Panel/Margin/VBox/Scroll/ContentVBox/PrestigeSection/PrestigeInfo
@onready var prestige_button: Button = $Panel/Margin/VBox/Scroll/ContentVBox/PrestigeSection/PrestigeButton

var tool_definitions: Array[Dictionary] = [
	{"id": &"crowbar", "name": "Piede di Porco", "cost": 0.0, "tier": 1, "desc": "Danno: 35 | Base"},
	{"id": &"hammer", "name": "Martello da Carpentiere", "cost": 120.0, "tier": 1, "desc": "Danno: 65 | Veloce"},
	{"id": &"sledgehammer_3kg", "name": "Mazza da Cantiere (3kg)", "cost": 350.0, "tier": 1, "desc": "Danno: 120 | AoE 0.8m"},
	{"id": &"sledgehammer_8kg", "name": "Mazza Pesante (8kg)", "cost": 950.0, "tier": 2, "desc": "Danno: 260 | AoE 1.3m"},
	{"id": &"electric_demolisher", "name": "Demolitore Elettrico", "cost": 1600.0, "tier": 2, "desc": "Danno Continuo | T2"},
	{"id": &"c4_charge", "name": "Carica Esplosiva C4", "cost": 3200.0, "tier": 3, "desc": "Piazzabile | 900 Danno"},
	{"id": &"remote_detonator", "name": "Detonatore Remoto", "cost": 1200.0, "tier": 3, "desc": "Innesco a Catena | T3"}
]

func _ready() -> void:
	visible = false
	close_button.pressed.connect(close_shop)
	if prestige_button:
		prestige_button.pressed.connect(_on_prestige_pressed)

	EventBus.currency_changed.connect(func(_new_amt, _delta): if visible: refresh_shop())
	EventBus.upgrade_purchased.connect(func(_id, _lvl, _cost): refresh_shop())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_shop"):
		if visible:
			close_shop()
		else:
			open_shop()

func open_shop() -> void:
	visible = true
	GameManager.is_shop_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_shop()

func close_shop() -> void:
	visible = false
	GameManager.is_shop_open = false
	if not GameManager.is_contract_menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_shop() -> void:
	money_label.text = "Disponibilità: € %d" % int(EconomyManager.current_money)
	_build_upgrades_list()
	_build_tools_list()
	if prestige_label and prestige_button:
		prestige_label.text = "Cicli Prestigio: %d | Moltiplicatore Permanente Attivo: %.1fx" % [
			EconomyManager.prestige_count,
			EconomyManager.permanent_multiplier
		]
		var can_prestige: bool = EconomyManager.current_money >= 5000.0 or SaveManager.save_data.get("completed_contracts", []).has("tier5_skyscraper")
		prestige_button.disabled = not can_prestige

func _on_prestige_pressed() -> void:
	EconomyManager.perform_prestige()
	GameManager.restart_current_contract()
	close_shop()
	EventBus.show_notification.emit(
		"PRESTIGIO ESEGUITO! Nuovo Moltiplicatore Permanente: %.1fx" % EconomyManager.permanent_multiplier,
		Color(1.0, 0.85, 0.2)
	)

func _build_upgrades_list() -> void:
	for child in upgrades_container.get_children():
		child.queue_free()

	for up_id in EconomyManager.upgrade_registry.keys():
		var def: Dictionary = EconomyManager.upgrade_registry[up_id]
		var lvl: int = EconomyManager.get_upgrade_level(up_id)
		var max_lvl: int = def["max_level"]
		var cost: float = EconomyManager.get_upgrade_cost(up_id)
		var can_afford: bool = EconomyManager.current_money >= cost and lvl < max_lvl

		var item_panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var vbox_info := VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title_lbl := Label.new()
		title_lbl.text = "%s (Liv. %d / %d)" % [def["title"], lvl, max_lvl]
		title_lbl.add_theme_font_size_override("font_size", 16)
		vbox_info.add_child(title_lbl)

		var desc_lbl := Label.new()
		var total_effect: float = lvl * def["effect"] * 100.0
		desc_lbl.text = "%s (Attuale: +%.0f%%)" % [def["description"], total_effect]
		desc_lbl.modulate = Color(0.75, 0.75, 0.75)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		vbox_info.add_child(desc_lbl)

		hbox.add_child(vbox_info)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(140, 40)
		if lvl >= max_lvl:
			buy_btn.text = "MAX"
			buy_btn.disabled = true
		else:
			buy_btn.text = "€ %d" % int(cost)
			buy_btn.disabled = not can_afford
			buy_btn.pressed.connect(func():
				if EconomyManager.purchase_upgrade(up_id):
					refresh_shop()
			)

		hbox.add_child(buy_btn)
		item_panel.add_child(hbox)
		upgrades_container.add_child(item_panel)

func _build_tools_list() -> void:
	for child in tools_container.get_children():
		child.queue_free()

	for t_def in tool_definitions:
		var t_id: StringName = t_def["id"]
		var is_unlocked: bool = EconomyManager.unlocked_tools.has(String(t_id))
		var is_equipped: bool = (EconomyManager.equipped_tool_id == t_id)
		var cost: float = t_def["cost"]

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(170, 110)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var name_lbl := Label.new()
		name_lbl.text = t_def["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = t_def["desc"]
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.modulate = Color(0.7, 0.7, 0.7)
		desc_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(desc_lbl)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(130, 32)

		if is_equipped:
			action_btn.text = "Equipaggiato"
			action_btn.disabled = true
		elif is_unlocked:
			action_btn.text = "Equipaggia"
			action_btn.pressed.connect(func():
				_equip_tool(t_id)
			)
		else:
			action_btn.text = "Sblocca (€%d)" % int(cost)
			action_btn.disabled = (EconomyManager.current_money < cost)
			action_btn.pressed.connect(func():
				if EconomyManager.spend_money(cost):
					EconomyManager.unlock_tool(t_id)
					_equip_tool(t_id)
			)

		vbox.add_child(action_btn)
		card.add_child(vbox)
		tools_container.add_child(card)

func _equip_tool(t_id: StringName) -> void:
	EconomyManager.equip_tool(t_id)
	var t_path: String = "res://data/tools/%s.tres" % t_id
	if ResourceLoader.exists(t_path):
		var tool_data: ToolData = load(t_path)
		EventBus.tool_equipped.emit(tool_data)
	refresh_shop()
