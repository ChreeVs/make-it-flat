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

func _ready() -> void:
	visible = false
	vol_slider.value_changed.connect(_on_any_changed)
	sens_slider.value_changed.connect(_on_any_changed)
	fov_slider.value_changed.connect(_on_any_changed)
	shake_check.toggled.connect(_on_any_changed)
	shadows_check.toggled.connect(_on_any_changed)
	fog_check.toggled.connect(_on_any_changed)
	reset_btn.pressed.connect(_on_reset_defaults)
	close_btn.pressed.connect(close_settings)

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
	SaveManager.apply_settings()

func _on_reset_defaults() -> void:
	EventBus.ui_click.emit()
	SaveManager.settings = SaveManager._get_default_settings()
	SaveManager.save_settings()
	_sync_ui_from_save()
