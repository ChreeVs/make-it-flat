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
	{"id": &"crowbar", "slot": 1, "name": "Piede di Porco", "tier": 1, "desc": "35 DMG • T1 • Base"},
	{"id": &"hammer", "slot": 2, "name": "Martello Carpentiere", "tier": 1, "desc": "65 DMG • T1 • Rapido"},
	{"id": &"sledgehammer_3kg", "slot": 3, "name": "Mazza Cantiere 3kg", "tier": 1, "desc": "120 DMG • T1 • AoE 0.8m"},
	{"id": &"sledgehammer_8kg", "slot": 4, "name": "Mazza Pesante 8kg", "tier": 2, "desc": "260 DMG • T2 • AoE 1.3m"},
	{"id": &"electric_demolisher", "slot": 5, "name": "Demolitore Elettrico", "tier": 3, "desc": "58/tick • T3 • Continuo"},
	{"id": &"c4_charge", "slot": 6, "name": "Carica Esplosiva C4", "tier": 4, "desc": "950 DMG • T4 • A carica"},
	{"id": &"remote_detonator", "slot": 7, "name": "Detonatore Remoto", "tier": 4, "desc": "Innesco a Catena [F / LMB]"}
]

var _card_style: StyleBoxFlat
var _card_equipped_style: StyleBoxFlat

func _ready() -> void:
	visible = false
	_init_styles()
	close_button.focus_mode = Control.FOCUS_NONE
	skills_switch_btn.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_shop)
	skills_switch_btn.pressed.connect(_on_switch_to_skills)
	if prestige_button:
		prestige_button.focus_mode = Control.FOCUS_NONE
		prestige_button.pressed.connect(_on_prestige_pressed)
	if license_button:
		license_button.focus_mode = Control.FOCUS_NONE
		license_button.pressed.connect(_on_license_pressed)

	EventBus.currency_changed.connect(func(_new_amt, _delta): if visible: refresh_shop())
	EventBus.upgrade_purchased.connect(func(_id, _lvl, _cost): if visible: refresh_shop())
	EventBus.tool_unlocked.connect(func(_tid): if visible: refresh_shop())
	EventBus.difficulty_changed.connect(func(_d): if visible: refresh_shop())

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
	var cfg: Dictionary = EconomyManager.get_difficulty_config()
	var unlocked_cnt: int = EconomyManager.unlocked_tools.size()
	license_info.text = "Modalità %s (%d Piani Arredati)  •  Strumenti sbloccati: %d/%d  —  Tutti gli strumenti si sbloccano potenziando l'Albero Abilità [K]" % [
		String(cfg.get("label", "FACILE")),
		int(cfg.get("floors", 4)),
		unlocked_cnt,
		EconomyManager.TOOL_ORDER.size()
	]
	license_button.text = "Apri Albero Abilità [K]"
	license_button.disabled = false

func _on_license_pressed() -> void:
	_on_switch_to_skills()

func _update_prestige_section() -> void:
	var has_tower: bool = SaveManager.save_data.get("completed_contracts", []).has("tier5_skyscraper")
	var can_prestige: bool = EconomyManager.current_money >= 25000.0 or has_tower
	prestige_label.text = "Cicli Prestigio: %d  |  Moltiplicatore Permanente: %.1fx  •  Requisito: €25.000 o completa il Grattacielo Arredato" % [
		EconomyManager.prestige_count,
		EconomyManager.permanent_multiplier
	]
	prestige_button.disabled = not can_prestige

func _on_prestige_pressed() -> void:
	EconomyManager.perform_prestige()
	GameManager.load_skyscraper_for_difficulty()
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

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(205, 140)
		card.add_theme_stylebox_override("panel", _card_equipped_style if is_equipped else _card_style)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 5)

		var badge_lbl := Label.new()
		badge_lbl.text = "TASTO [%d] • PENETRAZIONE T%d" % [t_def["slot"], t_def["tier"]]
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.add_theme_font_size_override("font_size", 10)
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
		action_btn.focus_mode = Control.FOCUS_NONE

		if is_equipped:
			action_btn.text = "✓ Equipaggiato"
			action_btn.disabled = true
		elif is_unlocked:
			action_btn.text = "Equipaggia"
			action_btn.pressed.connect(func():
				_equip_tool(t_id)
			)
		else:
			action_btn.text = EconomyManager.get_tool_unlock_hint(t_id)
			action_btn.add_theme_font_size_override("font_size", 10)
			action_btn.pressed.connect(_on_switch_to_skills)

		vbox.add_child(action_btn)
		card.add_child(vbox)
		tools_container.add_child(card)

func _equip_tool(t_id: StringName) -> void:
	EconomyManager.equip_tool(t_id)
	EventBus.ui_click.emit()
	refresh_shop()
