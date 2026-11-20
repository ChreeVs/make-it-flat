class_name HUD
extends Control

@onready var money_label: Label = $TopLeft/MoneyContainer/MoneyLabel
@onready var progress_bar: ProgressBar = $TopCenter/ProgressContainer/ProgressBar
@onready var progress_label: Label = $TopCenter/ProgressContainer/ProgressLabel
@onready var completion_banner: PanelContainer = $CenterNotification/CompletionBanner
@onready var completion_label: Label = $CenterNotification/CompletionBanner/VBox/CompletionText
@onready var tool_name_label: Label = $BottomRight/ToolContainer/ToolName
@onready var tool_stats_label: Label = $BottomRight/ToolContainer/ToolStats
@onready var notification_label: Label = $TopNotification/NotificationLabel
@onready var floating_text_layer: Control = $FloatingTextLayer
@onready var crosshair: CenterContainer = $Crosshair

var current_completion_available: bool = false
var notification_tween: Tween

func _ready() -> void:
	completion_banner.visible = false
	notification_label.visible = false

	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.contract_progress_updated.connect(_on_progress_updated)
	EventBus.contract_completed.connect(_on_contract_completed)
	EventBus.show_notification.connect(show_notification)
	EventBus.show_floating_text.connect(_spawn_floating_text)
	EventBus.tool_equipped.connect(_on_tool_equipped)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)

	_update_money_display(EconomyManager.current_money)
	_update_tool_display()

func _process(_delta: float) -> void:
	if current_completion_available and Input.is_action_just_pressed("interact"):
		GameManager.complete_current_contract()
		current_completion_available = false
		completion_banner.visible = false

	if Input.is_action_just_pressed("reset_site"):
		GameManager.restart_current_contract()

func _on_currency_changed(new_amount: float, _delta: float) -> void:
	_update_money_display(new_amount)

func _update_money_display(amount: float) -> void:
	money_label.text = "€ %d" % int(amount)

func _on_progress_updated(ratio: float, destroyed_mass: float, total_mass: float) -> void:
	var percent: float = ratio * 100.0
	progress_bar.value = percent
	progress_label.text = "Demolizione: %.1f%% (%.0f / %.0f kg)" % [percent, destroyed_mass, total_mass]

	if ratio >= 0.88 and not current_completion_available:
		current_completion_available = true
		completion_banner.visible = true
		var bonus: float = GameManager.current_contract.completion_bonus if GameManager.current_contract else 150.0
		completion_label.text = "SOGLIA RAGGIUNTA! Premi [E] per incassare il Bonus (+€%.0f)" % bonus

func _on_contract_completed(_contract: ContractData) -> void:
	completion_banner.visible = false
	current_completion_available = false

func _on_tool_equipped(_tool: ToolData) -> void:
	_update_tool_display()

func _on_upgrade_purchased(_id: StringName, _new_lvl: int, _cost: float) -> void:
	_update_tool_display()

func _update_tool_display() -> void:
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if not player or not player.equipped_tool:
		return
	
	var tool_data: ToolData = player.equipped_tool
	tool_name_label.text = tool_data.display_name
	
	var dmg_mult: float = EconomyManager.get_upgrade_total_multiplier("tool_damage")
	var spd_mult: float = EconomyManager.get_upgrade_total_multiplier("attack_speed")
	var reach_mult: float = EconomyManager.get_upgrade_total_multiplier("reach_distance")

	var actual_dmg: float = tool_data.base_damage * dmg_mult
	var actual_cooldown: float = tool_data.attack_cooldown / spd_mult
	var actual_reach: float = tool_data.reach_distance * reach_mult

	tool_stats_label.text = "Danno: %.0f | Durezza: T%d | Velocità: %.2fs | Allungo: %.1fm" % [
		actual_dmg,
		tool_data.hardness_penetration,
		actual_cooldown,
		actual_reach
	]

func show_notification(message: String, color: Color = Color.WHITE) -> void:
	notification_label.text = message
	notification_label.modulate = color
	notification_label.visible = true

	if notification_tween and notification_tween.is_valid():
		notification_tween.kill()

	notification_tween = create_tween()
	notification_label.modulate.a = 1.0
	notification_tween.tween_interval(2.2)
	notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.5)
	notification_tween.tween_callback(func(): notification_label.visible = false)

func _spawn_floating_text(text: String, world_pos: Vector3, color: Color) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return
	
	if cam.is_position_behind(world_pos):
		return

	var screen_pos: Vector2 = cam.unproject_position(world_pos)
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.position = screen_pos + Vector2(randf_range(-15, 15), randf_range(-10, 10))
	label.add_theme_font_size_override("font_size", 20)
	floating_text_layer.add_child(label)

	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", screen_pos.y - 45.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
	tween.tween_callback(label.queue_free)
