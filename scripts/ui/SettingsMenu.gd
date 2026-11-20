class_name SettingsMenu
extends Control

@onready var vol_label: Label = $Panel/VBox/VolRow/VolLabel
@onready var vol_slider: HSlider = $Panel/VBox/VolRow/VolSlider
@onready var sens_label: Label = $Panel/VBox/SensRow/SensLabel
@onready var sens_slider: HSlider = $Panel/VBox/SensRow/SensSlider
@onready var fov_label: Label = $Panel/VBox/FovRow/FovLabel
@onready var fov_slider: HSlider = $Panel/VBox/FovRow/FovSlider
@onready var shake_check: CheckButton = $Panel/VBox/ShakeCheck
@onready var shadows_check: CheckButton = $Panel/VBox/ShadowsCheck
@onready var fog_check: CheckButton = $Panel/VBox/FogCheck
@onready var reset_btn: Button = $Panel/VBox/FooterRow/ResetButton
@onready var close_btn: Button = $Panel/VBox/FooterRow/CloseButton

var _loading_ui: bool = false
var quality_option: OptionButton = null

const QUALITY_IDS: Array[String] = ["low", "medium", "high"]
const QUALITY_LABELS: Array[String] = ["Bassa (prestazioni)", "Media", "Alta (SSIL, riflessi, nebbia volumetrica)"]

func _ready() -> void:
	visible = false
	vol_slider.value_changed.connect(_on_any_changed)
	sens_slider.value_changed.connect(_on_any_changed)
	fov_slider.value_changed.connect(_on_any_changed)
	shake_check.toggled.connect(_on_any_changed)
	shadows_check.toggled.connect(_on_any_changed)
	fog_check.toggled.connect(_on_any_changed)
	reset_btn.pressed.connect(_on_reset_defaults)
	_build_quality_row()
	close_btn.pressed.connect(close_settings)

func _build_quality_row() -> void:
	var vbox := $Panel/VBox as VBoxContainer
	var row := HBoxContainer.new()
	row.name = "QualityRow"
	var lbl := Label.new()
	lbl.text = "Qualità Grafica:"
	lbl.custom_minimum_size = Vector2(200, 0)
	row.add_child(lbl)
	quality_option = OptionButton.new()
	quality_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(QUALITY_IDS.size()):
		quality_option.add_item(QUALITY_LABELS[i], i)
	quality_option.item_selected.connect(_on_any_changed)
	row.add_child(quality_option)
	vbox.add_child(row)
	var footer := vbox.get_node_or_null("FooterRow")
	if footer:
		vbox.move_child(row, footer.get_index())

func open_settings() -> void:
	visible = true
	GameManager.is_settings_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sync_ui_from_save()

func close_settings() -> void:
	EventBus.ui_click.emit()
	SaveManager.save_settings()
	visible = false
	GameManager.is_settings_open = false
	if not GameManager.is_any_ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _sync_ui_from_save() -> void:
	_loading_ui = true
	var s: Dictionary = SaveManager.settings
	vol_slider.value = float(s.get("master_volume", 0.85)) * 100.0
	sens_slider.value = float(s.get("mouse_sensitivity", 1.0))
	fov_slider.value = float(s.get("fov", 78.0))
	shake_check.button_pressed = bool(s.get("camera_shake", true))
	shadows_check.button_pressed = bool(s.get("shadows_enabled", true))
	fog_check.button_pressed = bool(s.get("fog_enabled", true))
	if quality_option:
		quality_option.select(maxi(QUALITY_IDS.find(String(s.get("graphics_quality", "high"))), 0))
	_loading_ui = false
	_update_labels()

func _update_labels() -> void:
	vol_label.text = "Volume Master: %d%%" % int(round(vol_slider.value))
	sens_label.text = "Sensibilità Mouse: %.1fx" % sens_slider.value
	fov_label.text = "Campo Visivo (FOV): %d°" % int(round(fov_slider.value))

func _on_any_changed(_val = null) -> void:
	if _loading_ui:
		return
	_update_labels()
	SaveManager.settings["master_volume"] = vol_slider.value / 100.0
	SaveManager.settings["mouse_sensitivity"] = sens_slider.value
	SaveManager.settings["fov"] = fov_slider.value
	SaveManager.settings["camera_shake"] = shake_check.button_pressed
	SaveManager.settings["shadows_enabled"] = shadows_check.button_pressed
	SaveManager.settings["fog_enabled"] = fog_check.button_pressed
	if quality_option:
		SaveManager.settings["graphics_quality"] = QUALITY_IDS[clampi(quality_option.selected, 0, QUALITY_IDS.size() - 1)]
	SaveManager.apply_settings()

func _on_reset_defaults() -> void:
	EventBus.ui_click.emit()
	SaveManager.settings = SaveManager._get_default_settings()
	SaveManager.save_settings()
	_sync_ui_from_save()
