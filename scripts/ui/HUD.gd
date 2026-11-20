class_name HUD
extends Control

@onready var money_label: Label = $TopLeft/MoneyPanel/VBox/MoneyLabel
@onready var tier_label: Label = $TopLeft/MoneyPanel/VBox/MetaRow/TierLabel
@onready var prestige_badge: Label = $TopLeft/MoneyPanel/VBox/MetaRow/PrestigeBadge
@onready var c4_badge: Label = $TopLeft/MoneyPanel/VBox/C4Badge

@onready var contract_title_label: Label = $TopCenter/ProgressPanel/ProgressContainer/ContractTitle
@onready var progress_bar: ProgressBar = $TopCenter/ProgressPanel/ProgressContainer/ProgressBar
@onready var progress_label: Label = $TopCenter/ProgressPanel/ProgressContainer/ProgressLabel

@onready var completion_banner: PanelContainer = $CenterNotification/CompletionBanner
@onready var completion_label: Label = $CenterNotification/CompletionBanner/VBox/CompletionText
@onready var notification_label: Label = $TopNotification/NotificationLabel

@onready var target_inspector: PanelContainer = $TargetInspector
@onready var target_mat_name: Label = $TargetInspector/VBox/HeaderRow/MatName
@onready var target_tier_tag: Label = $TargetInspector/VBox/HeaderRow/TierTag
@onready var target_hp_bar: ProgressBar = $TargetInspector/VBox/HpBar
@onready var target_warn_label: Label = $TargetInspector/VBox/WarnLabel

@onready var hotbar_container: HBoxContainer = $BottomCenter/Hotbar
@onready var tool_name_label: Label = $BottomRight/ToolPanel/ToolContainer/ToolName
@onready var tool_stats_label: Label = $BottomRight/ToolPanel/ToolContainer/ToolStats
@onready var floating_text_layer: Control = $FloatingTextLayer
@onready var crosshair: Control = $Crosshair

const HOTBAR_SHORT_NAMES: Dictionary = {
	&"crowbar": "Piede",
	&"hammer": "Martello",
	&"sledgehammer_3kg": "Mazza 3k",
	&"sledgehammer_8kg": "Mazza 8k",
	&"electric_demolisher": "Elettrico",
	&"c4_charge": "C4",
	&"remote_detonator": "Deton."
}

var current_completion_available: bool = false
var notification_tween: Tween
var _hovered_block: DestructibleBlock = null
var _hotbar_panels: Dictionary = {} # StringName -> PanelContainer
var _style_slot_locked: StyleBoxFlat
var _style_slot_unlocked: StyleBoxFlat
var _style_slot_active: StyleBoxFlat

func _ready() -> void:
	completion_banner.visible = false
	notification_label.visible = false
	target_inspector.visible = false

	_create_hotbar_styles()
	_build_hotbar()

	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.contract_progress_updated.connect(_on_progress_updated)
	EventBus.contract_threshold_reached.connect(_on_contract_threshold_reached)
	EventBus.contract_completed.connect(_on_contract_completed)
	EventBus.contract_selected.connect(_on_contract_selected)
	EventBus.show_notification.connect(show_notification)
	EventBus.show_floating_text.connect(_spawn_floating_text)
	EventBus.tool_equipped.connect(_on_tool_equipped)
	EventBus.tool_unlocked.connect(_on_tool_unlocked)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.tier_unlocked.connect(_on_tier_or_prestige_changed)
	EventBus.prestige_performed.connect(_on_prestige_performed)
	EventBus.target_block_hovered.connect(_on_target_block_hovered)
	EventBus.block_damaged.connect(_on_block_damaged_feedback)
	EventBus.explosives_count_changed.connect(_on_explosives_count_changed)

	_update_money_display(EconomyManager.current_money)
	_update_meta_badges()
	_update_contract_header()
	_update_tool_display()
	_refresh_hotbar()

func _create_hotbar_styles() -> void:
	_style_slot_locked = StyleBoxFlat.new()
	_style_slot_locked.bg_color = Color(0.06, 0.07, 0.09, 0.55)
	_style_slot_locked.border_width_left = 1
	_style_slot_locked.border_width_top = 1
	_style_slot_locked.border_width_right = 1
	_style_slot_locked.border_width_bottom = 1
	_style_slot_locked.border_color = Color(0.22, 0.25, 0.30, 0.5)
	_style_slot_locked.set_corner_radius_all(5)
	_style_slot_locked.content_margin_left = 8
	_style_slot_locked.content_margin_right = 8
	_style_slot_locked.content_margin_top = 4
	_style_slot_locked.content_margin_bottom = 4

	_style_slot_unlocked = StyleBoxFlat.new()
	_style_slot_unlocked.bg_color = Color(0.09, 0.11, 0.14, 0.84)
	_style_slot_unlocked.border_width_left = 1
	_style_slot_unlocked.border_width_top = 1
	_style_slot_unlocked.border_width_right = 1
	_style_slot_unlocked.border_width_bottom = 1
	_style_slot_unlocked.border_color = Color(0.38, 0.43, 0.50, 0.85)
	_style_slot_unlocked.set_corner_radius_all(5)
	_style_slot_unlocked.content_margin_left = 8
	_style_slot_unlocked.content_margin_right = 8
	_style_slot_unlocked.content_margin_top = 4
	_style_slot_unlocked.content_margin_bottom = 4

	_style_slot_active = StyleBoxFlat.new()
	_style_slot_active.bg_color = Color(0.18, 0.15, 0.07, 0.94)
	_style_slot_active.border_width_left = 2
	_style_slot_active.border_width_top = 2
	_style_slot_active.border_width_right = 2
	_style_slot_active.border_width_bottom = 2
	_style_slot_active.border_color = Color(0.98, 0.72, 0.14, 1.0)
	_style_slot_active.set_corner_radius_all(5)
	_style_slot_active.content_margin_left = 8
	_style_slot_active.content_margin_right = 8
	_style_slot_active.content_margin_top = 4
	_style_slot_active.content_margin_bottom = 4

func _build_hotbar() -> void:
	for child in hotbar_container.get_children():
		child.queue_free()
	_hotbar_panels.clear()

	for i in range(EconomyManager.TOOL_ORDER.size()):
		var tid: StringName = EconomyManager.TOOL_ORDER[i]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(78, 44)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 0)

		var num_lbl := Label.new()
		num_lbl.text = "[%d]" % (i + 1)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 11)
		num_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(num_lbl)

		var name_lbl := Label.new()
		name_lbl.name = "SlotName"
		name_lbl.text = HOTBAR_SHORT_NAMES.get(tid, String(tid))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		slot.add_child(vbox)
		hotbar_container.add_child(slot)
		_hotbar_panels[tid] = slot

func _refresh_hotbar() -> void:
	for tid in _hotbar_panels.keys():
		var slot: PanelContainer = _hotbar_panels[tid]
		var is_unlocked: bool = EconomyManager.unlocked_tools.has(String(tid))
		var is_equipped: bool = EconomyManager.equipped_tool_id == tid
		if is_equipped:
			slot.add_theme_stylebox_override("panel", _style_slot_active)
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif is_unlocked:
			slot.add_theme_stylebox_override("panel", _style_slot_unlocked)
			slot.modulate = Color(0.92, 0.94, 0.98, 0.95)
		else:
			slot.add_theme_stylebox_override("panel", _style_slot_locked)
			slot.modulate = Color(0.55, 0.58, 0.62, 0.55)

func _process(_delta: float) -> void:
	if GameManager.is_shop_open or GameManager.is_contract_menu_open:
		return

	if current_completion_available and Input.is_action_just_pressed("interact"):
		GameManager.complete_current_contract()
		current_completion_available = false
		completion_banner.visible = false

	if Input.is_action_just_pressed("reset_site"):
		GameManager.restart_current_contract()

	# Aggiorna HP del blocco attualmente mirato
	if is_instance_valid(_hovered_block) and not _hovered_block.is_destroyed:
		_refresh_target_inspector(_hovered_block)
	elif target_inspector.visible:
		_hovered_block = null
		target_inspector.visible = false
		_set_crosshair_color(Color(1.0, 1.0, 1.0, 0.88))

func _format_euros(amount: float) -> String:
	var n: int = int(floor(amount))
	var s: String = str(n)
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "." + out
		out = s[i] + out
		count += 1
	return "€ " + out

func _on_currency_changed(new_amount: float, _delta: float) -> void:
	_update_money_display(new_amount)

func _update_money_display(amount: float) -> void:
	money_label.text = _format_euros(amount)

func _update_meta_badges() -> void:
	tier_label.text = "LICENZA TIER %d" % EconomyManager.unlocked_tier
	if EconomyManager.prestige_count > 0 or EconomyManager.permanent_multiplier > 1.01:
		prestige_badge.visible = true
		prestige_badge.text = "• PRESTIGIO x%.1f" % EconomyManager.permanent_multiplier
	else:
		prestige_badge.visible = false

func _update_contract_header() -> void:
	if GameManager.current_contract:
		contract_title_label.text = "TIER %d  —  %s" % [GameManager.current_contract.tier, GameManager.current_contract.title.to_upper()]
	else:
		contract_title_label.text = "CANTIERE ATTIVO"

func _on_contract_selected(_contract: ContractData) -> void:
	current_completion_available = false
	completion_banner.visible = false
	_update_contract_header()

func _on_progress_updated(ratio: float, destroyed_mass: float, total_mass: float) -> void:
	var percent: float = ratio * 100.0
	progress_bar.value = percent
	var thresh_pct: int = int(round((GameManager.current_contract.completion_threshold if GameManager.current_contract else 0.88) * 100.0))
	progress_label.text = "Demolizione: %.1f%%  (%.0f / %.0f kg)  •  Soglia %d%%" % [percent, destroyed_mass, total_mass, thresh_pct]
	_update_contract_header()

func _on_contract_threshold_reached(contract: ContractData) -> void:
	if GameManager.contract_bonus_claimed:
		return
	current_completion_available = true
	completion_banner.visible = true
	var base_bonus: float = contract.completion_bonus if contract else 150.0
	var final_bonus: float = base_bonus * EconomyManager.permanent_multiplier
	completion_label.text = "SOGLIA RAGGIUNTA! Premi [E] per Incassare %s (o demolisci il resto)" % _format_euros(final_bonus)

func _on_contract_completed(_contract: ContractData) -> void:
	completion_banner.visible = false
	current_completion_available = false
	_update_meta_badges()

func _on_tool_equipped(_tool: ToolData) -> void:
	_update_tool_display()
	_refresh_hotbar()

func _on_tool_unlocked(_tool_id: StringName) -> void:
	_refresh_hotbar()

func _on_upgrade_purchased(_id: StringName, _new_lvl: int, _cost: float) -> void:
	_update_tool_display()

func _on_tier_or_prestige_changed(_val: int) -> void:
	_update_meta_badges()

func _on_prestige_performed(_count: int, _mult: float) -> void:
	_update_meta_badges()
	_refresh_hotbar()
	_update_tool_display()

func _on_explosives_count_changed(count: int) -> void:
	c4_badge.visible = count > 0
	c4_badge.text = "C4 ARMATI: %d  ([7] Detonatore)" % count

func _on_target_block_hovered(block: Node3D) -> void:
	if block is DestructibleBlock and is_instance_valid(block) and not block.is_destroyed:
		_hovered_block = block
		_refresh_target_inspector(block)
	else:
		_hovered_block = null
		target_inspector.visible = false
		_set_crosshair_color(Color(1.0, 1.0, 1.0, 0.88))

func _refresh_target_inspector(block: DestructibleBlock) -> void:
	target_inspector.visible = true
	var mat: MaterialData = block.material_data
	var m_name: String = mat.display_name if mat else "Blocco"
	var m_tier: int = mat.hardness_tier if mat else 1

	target_mat_name.text = m_name
	target_tier_tag.text = "TIER %d" % m_tier
	target_hp_bar.max_value = maxf(block.max_hp, 1.0)
	target_hp_bar.value = clampf(block.current_hp, 0.0, block.max_hp)

	var player: Player = get_tree().get_first_node_in_group("player") as Player
	var pen: int = player.equipped_tool.hardness_penetration if (player and player.equipped_tool) else 1
	if pen < m_tier:
		target_warn_label.visible = true
		target_warn_label.text = "DUREZZA INSUFFICIENTE • SERVE TIER %d" % m_tier
		_set_crosshair_color(Color(1.0, 0.30, 0.25, 0.95))
	else:
		target_warn_label.visible = false
		_set_crosshair_color(Color(1.0, 0.82, 0.25, 0.95))

func _set_crosshair_color(col: Color) -> void:
	for child in crosshair.get_children():
		if child is ColorRect:
			child.color = col

func _on_block_damaged_feedback(_block: Node3D, _amount: float, _pos: Vector3, _nrm: Vector3) -> void:
	crosshair.scale = Vector2(1.28, 1.28)
	crosshair.pivot_offset = crosshair.size * 0.5
	var t: Tween = create_tween()
	t.tween_property(crosshair, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_tool_display() -> void:
	var tool_data: ToolData = EconomyManager.get_tool_data(EconomyManager.equipped_tool_id)
	if not tool_data:
		return

	tool_name_label.text = tool_data.display_name

	var dmg_mult: float = EconomyManager.get_upgrade_total_multiplier(&"tool_damage")
	var spd_mult: float = EconomyManager.get_upgrade_total_multiplier(&"attack_speed")
	var reach_mult: float = EconomyManager.get_upgrade_total_multiplier(&"reach_distance")

	var actual_dmg: float = tool_data.base_damage * dmg_mult
	var actual_cooldown: float = maxf(tool_data.attack_cooldown / spd_mult, 0.055)
	var actual_reach: float = tool_data.reach_distance * reach_mult

	if tool_data.behavior_type == ToolData.BehaviorType.REMOTE_DETONATOR:
		tool_stats_label.text = "Innesco a Catena  |  Cariche Attive: %d" % GameManager.get_active_explosives_count()
	elif tool_data.behavior_type == ToolData.BehaviorType.EXPLOSIVE_PLACED:
		tool_stats_label.text = "Esplosivo T4  |  Raggio: %.1fm  |  Danno: %.0f" % [tool_data.aoe_radius, actual_dmg]
	else:
		var aoe_str: String = "  |  AoE %.1fm" % tool_data.aoe_radius if tool_data.aoe_radius > 0.0 else ""
		tool_stats_label.text = "DMG: %.0f  |  T%d  |  %.2fs  |  %.1fm%s" % [
			actual_dmg,
			tool_data.hardness_penetration,
			actual_cooldown,
			actual_reach,
			aoe_str
		]

func show_notification(message: String, color: Color = Color.WHITE) -> void:
	notification_label.text = message
	notification_label.modulate = color
	notification_label.visible = true

	if notification_tween and notification_tween.is_valid():
		notification_tween.kill()

	notification_tween = create_tween()
	notification_label.modulate.a = 1.0
	notification_tween.tween_interval(2.4)
	notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.45)
	notification_tween.tween_callback(func():
		if is_instance_valid(notification_label):
			notification_label.visible = false
	)

func _spawn_floating_text(text: String, world_pos: Vector3, color: Color) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam or cam.is_position_behind(world_pos):
		return

	var screen_pos: Vector2 = cam.unproject_position(world_pos)
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.position = screen_pos + Vector2(randf_range(-18, 18), randf_range(-12, 12))
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_text_layer.add_child(label)

	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 48.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.72)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)
