class_name ShopMenu
extends Control

@onready var money_label: Label = $Panel/Margin/VBox/Header/MoneyLabel
@onready var upgrades_container: VBoxContainer = $Panel/Margin/VBox/Scroll/ContentVBox/UpgradesList
@onready var tools_container: GridContainer = $Panel/Margin/VBox/Scroll/ContentVBox/ToolsList
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var license_info: Label = $Panel/Margin/VBox/Scroll/ContentVBox/LicensePanel/LicenseHBox/LicenseInfo
@onready var license_button: Button = $Panel/Margin/VBox/Scroll/ContentVBox/LicensePanel/LicenseHBox/LicenseButton
@onready var prestige_label: Label = $Panel/Margin/VBox/Scroll/ContentVBox/PrestigePanel/PrestigeSection/PrestigeInfo
@onready var prestige_button: Button = $Panel/Margin/VBox/Scroll/ContentVBox/PrestigePanel/PrestigeSection/PrestigeButton

var tool_definitions: Array[Dictionary] = [
	{"id": &"crowbar", "slot": 1, "name": "Piede di Porco", "cost": 0.0, "tier": 1, "desc": "35 DMG • T1 • Base"},
	{"id": &"hammer", "slot": 2, "name": "Martello Carpentiere", "cost": 120.0, "tier": 1, "desc": "65 DMG • T1 • Rapido"},
	{"id": &"sledgehammer_3kg", "slot": 3, "name": "Mazza Cantiere 3kg", "cost": 350.0, "tier": 1, "desc": "120 DMG • T1 • AoE 0.8m"},
	{"id": &"sledgehammer_8kg", "slot": 4, "name": "Mazza Pesante 8kg", "cost": 950.0, "tier": 2, "desc": "260 DMG • T2 • AoE 1.3m"},
	{"id": &"electric_demolisher", "slot": 5, "name": "Demolitore Elettrico", "cost": 1600.0, "tier": 2, "desc": "45/tick • T2 • Continuo"},
	{"id": &"c4_charge", "slot": 6, "name": "Carica Esplosiva C4", "cost": 3200.0, "tier": 3, "desc": "950 DMG • T4 • Piazzabile"},
	{"id": &"remote_detonator", "slot": 7, "name": "Detonatore Remoto", "cost": 1200.0, "tier": 3, "desc": "Innesco a Catena C4"}
]

var _card_style: StyleBoxFlat
var _card_equipped_style: StyleBoxFlat
var _upgrade_row_style: StyleBoxFlat

func _ready() -> void:
	visible = false
	_init_styles()
	close_button.pressed.connect(close_shop)
	if prestige_button:
		prestige_button.pressed.connect(_on_prestige_pressed)
	if license_button:
		license_button.pressed.connect(_on_license_pressed)

	EventBus.currency_changed.connect(func(_new_amt, _delta): if visible: refresh_shop())
	EventBus.upgrade_purchased.connect(func(_id, _lvl, _cost): if visible: refresh_shop())
	EventBus.tier_unlocked.connect(func(_tier): if visible: refresh_shop())

func _init_styles() -> void:
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(0.11, 0.13, 0.165, 0.96)
	_card_style.border_width_left = 1
	_card_style.border_width_top = 1
	_card_style.border_width_right = 1
	_card_style.border_width_bottom = 1
	_card_style.border_color = Color(0.28, 0.33, 0.40, 0.9)
	_card_style.set_corner_radius_all(7)
	_card_style.content_margin_left = 10
	_card_style.content_margin_right = 10
	_card_style.content_margin_top = 10
	_card_style.content_margin_bottom = 10

	_card_equipped_style = StyleBoxFlat.new()
	_card_equipped_style.bg_color = Color(0.17, 0.14, 0.08, 0.98)
	_card_equipped_style.border_width_left = 2
	_card_equipped_style.border_width_top = 2
	_card_equipped_style.border_width_right = 2
	_card_equipped_style.border_width_bottom = 2
	_card_equipped_style.border_color = Color(0.98, 0.70, 0.14, 1.0)
	_card_equipped_style.set_corner_radius_all(7)
	_card_equipped_style.content_margin_left = 10
	_card_equipped_style.content_margin_right = 10
	_card_equipped_style.content_margin_top = 10
	_card_equipped_style.content_margin_bottom = 10

	_upgrade_row_style = StyleBoxFlat.new()
	_upgrade_row_style.bg_color = Color(0.11, 0.13, 0.16, 0.94)
	_upgrade_row_style.border_width_left = 3
	_upgrade_row_style.border_width_top = 1
	_upgrade_row_style.border_width_right = 1
	_upgrade_row_style.border_width_bottom = 1
	_upgrade_row_style.border_color = Color(0.32, 0.38, 0.46, 0.85)
	_upgrade_row_style.set_corner_radius_all(6)
	_upgrade_row_style.content_margin_left = 14
	_upgrade_row_style.content_margin_right = 12
	_upgrade_row_style.content_margin_top = 8
	_upgrade_row_style.content_margin_bottom = 8

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_shop"):
		if visible:
			close_shop()
		else:
			open_shop()

func open_shop() -> void:
	# Chiudi eventuale menu commesse aperto (mutua esclusione)
	var contract_menu: Node = get_tree().get_root().find_child("ContractMenu", true, false)
	if contract_menu and contract_menu.visible and contract_menu.has_method("close_menu"):
		contract_menu.close_menu()

	visible = true
	GameManager.is_shop_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_click.emit()
	refresh_shop()

func close_shop() -> void:
	visible = false
	GameManager.is_shop_open = false
	if not GameManager.is_contract_menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_shop() -> void:
	money_label.text = "Capitale: € %d" % int(EconomyManager.current_money)
	_update_license_section()
	_build_tools_list()
	_build_upgrades_list()
	_update_prestige_section()

func _update_license_section() -> void:
	if not license_info or not license_button:
		return
	var curr_tier: int = EconomyManager.unlocked_tier
	if curr_tier >= 5:
		license_info.text = "Licenza Demolizioni: TIER 5 MASSIMO (Tutte le megastrutture sbloccate!)"
		license_button.text = "LICENZA MASSIMA"
		license_button.disabled = true
	else:
		var next_tier: int = curr_tier + 1
		var cost: float = EconomyManager.get_tier_license_cost(next_tier)
		license_info.text = "Licenza Attiva: TIER %d  •  Sblocca Tier %d completando un cantiere o acquistando la licenza" % [curr_tier, next_tier]
		license_button.text = "Licenza Tier %d (€ %d)" % [next_tier, int(cost)]
		license_button.disabled = EconomyManager.current_money < cost

func _on_license_pressed() -> void:
	var next_tier: int = EconomyManager.unlocked_tier + 1
	if EconomyManager.purchase_tier_license(next_tier):
		refresh_shop()

func _update_prestige_section() -> void:
	if not prestige_label or not prestige_button:
		return
	var has_tower: bool = SaveManager.save_data.get("completed_contracts", []).has("tier5_skyscraper")
	var can_prestige: bool = EconomyManager.current_money >= 5000.0 or has_tower
	prestige_label.text = "Cicli Prestigio: %d  |  Moltiplicatore Permanente: %.1fx  •  Requisito: €5.000 o completa Grattacielo Skyline" % [
		EconomyManager.prestige_count,
		EconomyManager.permanent_multiplier
	]
	prestige_button.disabled = not can_prestige

func _on_prestige_pressed() -> void:
	EconomyManager.perform_prestige()
	var t1: ContractData = load("res://data/contracts/tier1_fence.tres")
	if t1:
		GameManager.load_contract(t1)
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
		item_panel.add_theme_stylebox_override("panel", _upgrade_row_style)

		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 12)

		var vbox_info := VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_info.add_theme_constant_override("separation", 3)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)

		var cat_lbl := Label.new()
		cat_lbl.text = "[%s]" % def.get("category", "UPGRADE")
		cat_lbl.add_theme_font_size_override("font_size", 11)
		cat_lbl.add_theme_color_override("font_color", Color(0.42, 0.78, 0.98))
		top_row.add_child(cat_lbl)

		var title_lbl := Label.new()
		title_lbl.text = "%s  —  Liv. %d / %d" % [def["title"], lvl, max_lvl]
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
		top_row.add_child(title_lbl)

		vbox_info.add_child(top_row)

		var desc_lbl := Label.new()
		var total_effect: float = lvl * def["effect"] * 100.0
		desc_lbl.text = "%s  (Bonus attuale: +%.0f%%)" % [def["description"], total_effect]
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
		desc_lbl.add_theme_font_size_override("font_size", 12)
		vbox_info.add_child(desc_lbl)

		hbox.add_child(vbox_info)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(145, 42)
		if lvl >= max_lvl:
			buy_btn.text = "LIVELLO MAX"
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
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(195, 118)
		card.add_theme_stylebox_override("panel", _card_equipped_style if is_equipped else _card_style)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 5)

		var badge_lbl := Label.new()
		badge_lbl.text = "TASTO [%d] • TIER %d" % [t_def["slot"], t_def["tier"]]
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.add_theme_font_size_override("font_size", 11)
		badge_lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.22) if is_equipped else Color(0.55, 0.65, 0.78))
		vbox.add_child(badge_lbl)

		var name_lbl := Label.new()
		name_lbl.text = t_def["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
		vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = t_def["desc"]
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(desc_lbl)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(0, 32)

		if is_equipped:
			action_btn.text = "✓ Equipaggiato"
			action_btn.disabled = true
		elif is_unlocked:
			action_btn.text = "Equipaggia"
			action_btn.pressed.connect(func():
				_equip_tool(t_id)
			)
		else:
			action_btn.text = "Sblocca € %d" % int(cost)
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
	EventBus.ui_click.emit()
	refresh_shop()
