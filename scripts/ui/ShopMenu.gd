class_name ShopMenu
extends Control

@onready var money_label: Label = $Panel/Margin/VBox/Header/MoneyLabel
@onready var skills_switch_btn: Button = $Panel/Margin/VBox/Header/SkillsSwitchButton
@onready var tools_container: GridContainer = $Panel/Margin/VBox/Scroll/ContentVBox/ToolsList
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var license_info: Label = $Panel/Margin/VBox/Scroll/ContentVBox/LicensePanel/LicenseHBox/LicenseInfo
@onready var license_button: Button = $Panel/Margin/VBox/Scroll/ContentVBox/LicensePanel/LicenseHBox/LicenseButton
@onready var prestige_label: Label = $Panel/Margin/VBox/Scroll/ContentVBox/PrestigePanel/PrestigeSection/PrestigeInfo
@onready var prestige_button: Button = $Panel/Margin/VBox/Scroll/ContentVBox/PrestigePanel/PrestigeSection/PrestigeButton

var tool_definitions: Array[Dictionary] = [
	{"id": &"crowbar", "slot": 1, "name": "Piede di Porco", "cost": 0.0, "tier": 1, "desc": "35 DMG • T1 • Base"},
	{"id": &"hammer", "slot": 2, "name": "Martello Carpentiere", "cost": 150.0, "tier": 1, "desc": "65 DMG • T1 • Rapido"},
	{"id": &"sledgehammer_3kg", "slot": 3, "name": "Mazza Cantiere 3kg", "cost": 500.0, "tier": 1, "desc": "120 DMG • T1 • AoE 0.8m"},
	{"id": &"sledgehammer_8kg", "slot": 4, "name": "Mazza Pesante 8kg", "cost": 1800.0, "tier": 2, "desc": "260 DMG • T2 • AoE 1.3m"},
	{"id": &"electric_demolisher", "slot": 5, "name": "Demolitore Elettrico", "cost": 3800.0, "tier": 2, "desc": "45/tick • T2 • Continuo"},
	{"id": &"c4_charge", "slot": 6, "name": "Carica Esplosiva C4", "cost": 7500.0, "tier": 3, "desc": "950 DMG • T4 • A pagamento/carica"},
	{"id": &"remote_detonator", "slot": 7, "name": "Detonatore Remoto", "cost": 2500.0, "tier": 3, "desc": "Innesco a Catena C4"}
]

var _card_style: StyleBoxFlat
var _card_equipped_style: StyleBoxFlat

func _ready() -> void:
	visible = false
	_init_styles()
	close_button.pressed.connect(close_shop)
	skills_switch_btn.pressed.connect(_on_switch_to_skills)
	if prestige_button:
		prestige_button.pressed.connect(_on_prestige_pressed)
	if license_button:
		license_button.pressed.connect(_on_license_pressed)

	EventBus.currency_changed.connect(func(_new_amt, _delta): if visible: refresh_shop())
	EventBus.upgrade_purchased.connect(func(_id, _lvl, _cost): if visible: refresh_shop())
	EventBus.tier_unlocked.connect(func(_tier): if visible: refresh_shop())

func _init_styles() -> void:
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(0.09, 0.11, 0.145, 0.96)
	_card_style.border_width_left = 1
	_card_style.border_width_top = 1
	_card_style.border_width_right = 1
	_card_style.border_width_bottom = 1
	_card_style.border_color = Color(0.26, 0.32, 0.40, 0.9)
	_card_style.set_corner_radius_all(7)
	_card_style.content_margin_left = 10
	_card_style.content_margin_right = 10
	_card_style.content_margin_top = 10
	_card_style.content_margin_bottom = 10

	_card_equipped_style = StyleBoxFlat.new()
	_card_equipped_style.bg_color = Color(0.18, 0.14, 0.065, 0.98)
	_card_equipped_style.border_width_left = 2
	_card_equipped_style.border_width_top = 2
	_card_equipped_style.border_width_right = 2
	_card_equipped_style.border_width_bottom = 2
	_card_equipped_style.border_color = Color(0.98, 0.72, 0.14, 1.0)
	_card_equipped_style.set_corner_radius_all(7)
	_card_equipped_style.content_margin_left = 10
	_card_equipped_style.content_margin_right = 10
	_card_equipped_style.content_margin_top = 10
	_card_equipped_style.content_margin_bottom = 10

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_main_menu_open or GameManager.is_pause_menu_open:
		return
	if event.is_action_pressed("toggle_shop"):
		if visible:
			close_shop()
		else:
			open_shop()

func open_shop() -> void:
	GameManager.close_gameplay_overlays("ShopMenu")
	visible = true
	GameManager.is_shop_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_click.emit()
	refresh_shop()

func close_shop() -> void:
	visible = false
	GameManager.is_shop_open = false
	if not GameManager.is_any_ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_switch_to_skills() -> void:
	var st := get_tree().get_root().find_child("SkillTreeMenu", true, false)
	if st and st.has_method("open_menu"):
		st.open_menu()

func refresh_shop() -> void:
	money_label.text = "Capitale: € %d" % int(EconomyManager.current_money)
	_update_license_section()
	_build_tools_list()
	_update_prestige_section()

func _update_license_section() -> void:
	var curr_tier: int = EconomyManager.unlocked_tier
	if curr_tier >= 5:
		license_info.text = "Licenza Demolizioni: TIER 5 MASSIMO (Tutte le strutture sbloccate!)"
		license_button.text = "LICENZA MASSIMA"
		license_button.disabled = true
	else:
		var next_tier: int = curr_tier + 1
		var cost: float = EconomyManager.get_tier_license_cost(next_tier)
		license_info.text = "Licenza Attiva: TIER %d  •  Sblocca Tier %d completando un cantiere attuale o acquistando subito la licenza" % [curr_tier, next_tier]
		license_button.text = "Licenza Tier %d (€ %d)" % [next_tier, int(cost)]
		license_button.disabled = EconomyManager.current_money < cost

func _on_license_pressed() -> void:
	var next_tier: int = EconomyManager.unlocked_tier + 1
	if EconomyManager.purchase_tier_license(next_tier):
		refresh_shop()

func _update_prestige_section() -> void:
	var has_tower: bool = SaveManager.save_data.get("completed_contracts", []).has("tier5_skyscraper")
	var can_prestige: bool = EconomyManager.current_money >= 25000.0 or has_tower
	prestige_label.text = "Cicli Prestigio: %d  |  Moltiplicatore Permanente: %.1fx  •  Requisito: €25.000 o completa il Grattacielo Skyline" % [
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

func _build_tools_list() -> void:
	for child in tools_container.get_children():
		child.queue_free()

	var c4_unit: int = int(EconomyManager.get_c4_unit_cost())
	for t_def in tool_definitions:
		var t_id: StringName = t_def["id"]
		var is_unlocked: bool = EconomyManager.unlocked_tools.has(String(t_id))
		var is_equipped: bool = (EconomyManager.equipped_tool_id == t_id)
		var cost: float = t_def["cost"]

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(205, 134)
		card.add_theme_stylebox_override("panel", _card_equipped_style if is_equipped else _card_style)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)

		var badge_lbl := Label.new()
		badge_lbl.text = "TASTO [%d] • TIER %d" % [t_def["slot"], t_def["tier"]]
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.add_theme_font_size_override("font_size", 11)
		badge_lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.22) if is_equipped else Color(0.55, 0.65, 0.78))
		vbox.add_child(badge_lbl)

		var name_lbl := Label.new()
		name_lbl.text = t_def["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
		vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = ("950 DMG • T4 • €%d/carica" % c4_unit) if t_id == &"c4_charge" else String(t_def["desc"])
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_color_override("font_color", Color(1.0, 0.64, 0.34) if t_id == &"c4_charge" else Color(0.72, 0.76, 0.82))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(desc_lbl)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(0, 34)

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
