class_name ContractMenu
extends Control

@onready var contracts_list: VBoxContainer = $Panel/Margin/VBox/Scroll/ContractsList
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton

var contracts_data: Array[ContractData] = []

func _ready() -> void:
	visible = false
	close_button.pressed.connect(close_menu)
	_load_contracts()

func _load_contracts() -> void:
	contracts_data.clear()
	var paths := [
		"res://data/contracts/tier1_fence.tres",
		"res://data/contracts/tier1_shack.tres",
		"res://data/contracts/tier1_wall.tres",
		"res://data/contracts/tier2_garage.tres",
		"res://data/contracts/tier3_palazzina.tres",
		"res://data/contracts/tier5_skyscraper.tres"
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
	visible = true
	GameManager.is_contract_menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_contracts()

func close_menu() -> void:
	visible = false
	GameManager.is_contract_menu_open = false
	if not GameManager.is_shop_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_contracts() -> void:
	for child in contracts_list.get_children():
		child.queue_free()

	for c in contracts_data:
		var panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title_lbl := Label.new()
		title_lbl.text = "Tier %d - %s" % [c.tier, c.title]
		title_lbl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = "%s (Bonus Completamento: +€%d)" % [c.description, int(c.completion_bonus)]
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(desc_lbl)

		hbox.add_child(vbox)

		var select_btn := Button.new()
		select_btn.custom_minimum_size = Vector2(160, 40)
		select_btn.text = "Avvia Lavori"
		select_btn.pressed.connect(func():
			EventBus.contract_selected.emit(c)
			close_menu()
		)
		hbox.add_child(select_btn)

		panel.add_child(hbox)
		contracts_list.add_child(panel)
