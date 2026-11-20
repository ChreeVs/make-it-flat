class_name ContractMenu
extends Control

@onready var contracts_list: VBoxContainer = $Panel/Margin/VBox/Scroll/ContractsList
@onready var summary_label: Label = $Panel/Margin/VBox/Header/ProgressSummary
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton

var contracts_data: Array[ContractData] = []
var _row_style: StyleBoxFlat
var _row_active_style: StyleBoxFlat
var _row_locked_style: StyleBoxFlat

const TIER_COLORS: Dictionary = {
	1: Color(0.45, 0.85, 0.45),
	2: Color(0.95, 0.78, 0.22),
	3: Color(1.0, 0.55, 0.18),
	4: Color(0.95, 0.35, 0.32),
	5: Color(0.75, 0.45, 1.0)
}

func _ready() -> void:
	visible = false
	_init_styles()
	close_button.pressed.connect(close_menu)
	_load_contracts()
	EventBus.tier_unlocked.connect(func(_t): if visible: refresh_contracts())
	EventBus.contract_completed.connect(func(_c): if visible: refresh_contracts())

func _init_styles() -> void:
	_row_style = StyleBoxFlat.new()
	_row_style.bg_color = Color(0.11, 0.13, 0.165, 0.95)
	_row_style.border_width_left = 4
	_row_style.border_width_top = 1
	_row_style.border_width_right = 1
	_row_style.border_width_bottom = 1
	_row_style.border_color = Color(0.28, 0.46, 0.64, 0.9)
	_row_style.set_corner_radius_all(7)
	_row_style.content_margin_left = 14
	_row_style.content_margin_right = 12
	_row_style.content_margin_top = 10
	_row_style.content_margin_bottom = 10

	_row_active_style = StyleBoxFlat.new()
	_row_active_style.bg_color = Color(0.11, 0.17, 0.22, 0.98)
	_row_active_style.border_width_left = 4
	_row_active_style.border_width_top = 2
	_row_active_style.border_width_right = 2
	_row_active_style.border_width_bottom = 2
	_row_active_style.border_color = Color(0.30, 0.78, 1.0, 1.0)
	_row_active_style.set_corner_radius_all(7)
	_row_active_style.content_margin_left = 14
	_row_active_style.content_margin_right = 12
	_row_active_style.content_margin_top = 10
	_row_active_style.content_margin_bottom = 10

	_row_locked_style = StyleBoxFlat.new()
	_row_locked_style.bg_color = Color(0.08, 0.09, 0.11, 0.82)
	_row_locked_style.border_width_left = 4
	_row_locked_style.border_width_top = 1
	_row_locked_style.border_width_right = 1
	_row_locked_style.border_width_bottom = 1
	_row_locked_style.border_color = Color(0.24, 0.26, 0.30, 0.7)
	_row_locked_style.set_corner_radius_all(7)
	_row_locked_style.content_margin_left = 14
	_row_locked_style.content_margin_right = 12
	_row_locked_style.content_margin_top = 10
	_row_locked_style.content_margin_bottom = 10

func _load_contracts() -> void:
	contracts_data.clear()
	var paths := [
		"res://data/contracts/tier1_villa.tres",
		"res://data/contracts/tier2_warehouse.tres",
		"res://data/contracts/tier3_condominium.tres",
		"res://data/contracts/tier4_industrial.tres",
		"res://data/contracts/tier5_skyscraper.tres",
		"res://data/contracts/tier1_shack.tres",
		"res://data/contracts/tier1_fence.tres",
		"res://data/contracts/tier2_garage.tres"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			contracts_data.append(load(p))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_contracts"):
		if visible:
			close_menu()
		else:
			open_menu()

func open_menu() -> void:
	# Mutua esclusione con lo Shop
	var shop_menu: Node = get_tree().get_root().find_child("ShopMenu", true, false)
	if shop_menu and shop_menu.visible and shop_menu.has_method("close_shop"):
		shop_menu.close_shop()

	visible = true
	GameManager.is_contract_menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_click.emit()
	refresh_contracts()

func close_menu() -> void:
	visible = false
	GameManager.is_contract_menu_open = false
	if not GameManager.is_shop_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_contracts() -> void:
	for child in contracts_list.get_children():
		child.queue_free()

	var completed_list: Array = SaveManager.save_data.get("completed_contracts", [])
	summary_label.text = "Licenza: TIER %d  •  Completati: %d / %d" % [
		EconomyManager.unlocked_tier,
		completed_list.size(),
		contracts_data.size()
	]

	for c in contracts_data:
		var is_unlocked: bool = c.tier <= EconomyManager.unlocked_tier
		var is_active: bool = GameManager.current_contract != null and GameManager.current_contract.contract_id == c.contract_id
		var is_completed: bool = completed_list.has(String(c.contract_id))
		var scaled_bonus: float = c.completion_bonus * EconomyManager.permanent_multiplier

		var panel := PanelContainer.new()
		if is_active:
			panel.add_theme_stylebox_override("panel", _row_active_style)
		elif is_unlocked:
			panel.add_theme_stylebox_override("panel", _row_style)
		else:
			panel.add_theme_stylebox_override("panel", _row_locked_style)

		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 14)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 4)

		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)

		var tier_badge := Label.new()
		tier_badge.text = "[TIER %d]" % c.tier
		tier_badge.add_theme_font_size_override("font_size", 13)
		tier_badge.add_theme_color_override("font_color", TIER_COLORS.get(c.tier, Color.WHITE))
		title_row.add_child(tier_badge)

		var title_lbl := Label.new()
		title_lbl.text = c.title
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99) if is_unlocked else Color(0.55, 0.58, 0.62))
		title_row.add_child(title_lbl)

		if is_active:
			var act_lbl := Label.new()
			act_lbl.text = "• IN CORSO"
			act_lbl.add_theme_font_size_override("font_size", 12)
			act_lbl.add_theme_color_override("font_color", Color(0.30, 0.85, 1.0))
			title_row.add_child(act_lbl)

		if is_completed:
			var done_lbl := Label.new()
			done_lbl.text = "✓ COMPLETATO"
			done_lbl.add_theme_font_size_override("font_size", 12)
			done_lbl.add_theme_color_override("font_color", Color(0.30, 0.95, 0.48))
			title_row.add_child(done_lbl)

		vbox.add_child(title_row)

		var desc_lbl := Label.new()
		desc_lbl.text = "%s" % c.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", Color(0.74, 0.78, 0.84) if is_unlocked else Color(0.48, 0.50, 0.55))
		desc_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(desc_lbl)

		var reward_lbl := Label.new()
		reward_lbl.text = "Premio Completamento (soglia %d%%): +€ %d" % [int(round(c.completion_threshold * 100.0)), int(scaled_bonus)]
		reward_lbl.add_theme_color_override("font_color", Color(0.32, 0.92, 0.48) if is_unlocked else Color(0.45, 0.55, 0.48))
		reward_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(reward_lbl)

		hbox.add_child(vbox)

		var select_btn := Button.new()
		select_btn.custom_minimum_size = Vector2(180, 44)
		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		if is_unlocked:
			select_btn.text = "Ricarica Cantiere" if is_active else ("Rigioca" if is_completed else "Avvia Lavori")
			select_btn.pressed.connect(func():
				EventBus.ui_click.emit()
				EventBus.contract_selected.emit(c)
				close_menu()
			)
		elif c.tier == EconomyManager.unlocked_tier + 1:
			var lic_cost: float = EconomyManager.get_tier_license_cost(c.tier)
			select_btn.text = "Sblocca Tier %d (€%d)" % [c.tier, int(lic_cost)]
			select_btn.disabled = EconomyManager.current_money < lic_cost
			select_btn.pressed.connect(func():
				if EconomyManager.purchase_tier_license(c.tier):
					refresh_contracts()
			)
		else:
			select_btn.text = "Bloccato (Tier %d)" % c.tier
			select_btn.disabled = true

		hbox.add_child(select_btn)
		panel.add_child(hbox)
		contracts_list.add_child(panel)
