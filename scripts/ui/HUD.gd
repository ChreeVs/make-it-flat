class_name HUD
extends Control

@onready var money_label: Label = $TopLeft/MoneyPanel/VBox/MoneyRow/MoneyLabel
@onready var money_delta_label: Label = $TopLeft/MoneyPanel/VBox/MoneyRow/MoneyDeltaLabel
@onready var tier_label: Label = $TopLeft/MoneyPanel/VBox/MetaRow/TierLabel
@onready var prestige_badge: Label = $TopLeft/MoneyPanel/VBox/MetaRow/PrestigeBadge
@onready var c4_badge: Label = $TopLeft/MoneyPanel/VBox/C4Badge

@onready var contract_title_label: Label = $TopCenter/ProgressPanel/ProgressContainer/ContractTitle
@onready var progress_bar: ProgressBar = $TopCenter/ProgressPanel/ProgressContainer/BarHolder/ProgressBar
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

const RESET_HOLD_DURATION: float = 1.2

var current_completion_available: bool = false
var notification_tween: Tween
var _hovered_block: DestructibleBlock = null
var _hotbar_panels: Dictionary = {}
var _style_slot_locked: StyleBoxFlat
var _style_slot_unlocked: StyleBoxFlat
var _style_slot_active: StyleBoxFlat

# Animazione fluida del contatore denaro (senza scritte fluttuanti 3D -> zero lag!)
var _displayed_money: float = 0.0
var _target_money: float = 0.0
var _accumulated_delta: float = 0.0
var _delta_fade_timer: float = 0.0
var _money_punch_tween: Tween = null

# Protezione anti-reset accidentale su tasto [R]
var _reset_hold_timer: float = 0.0
var _reset_triggered: bool = false

func _ready() -> void:
	completion_banner.visible = false
	notification_label.visible = false
	target_inspector.visible = false
	money_delta_label.visible = false

	_create_hotbar_styles()
	_build_hotbar()

	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.contract_progress_updated.connect(_on_progress_updated)
	EventBus.contract_threshold_reached.connect(_on_contract_threshold_reached)
	EventBus.contract_completed.connect(_on_contract_completed)
	EventBus.contract_selected.connect(_on_contract_selected)
	EventBus.show_notification.connect(show_notification)
	EventBus.tool_equipped.connect(_on_tool_equipped)
	EventBus.tool_unlocked.connect(_on_tool_unlocked)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.tier_unlocked.connect(_on_tier_or_prestige_changed)
	EventBus.prestige_performed.connect(_on_prestige_performed)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	EventBus.floor_cleared.connect(_on_floor_cleared)
	EventBus.target_block_hovered.connect(_on_target_block_hovered)
	EventBus.block_damaged.connect(_on_block_damaged_feedback)
	EventBus.explosives_count_changed.connect(_on_explosives_count_changed)
	EventBus.game_state_changed.connect(_on_game_state_changed)

	_displayed_money = EconomyManager.current_money
	_target_money = EconomyManager.current_money
	money_label.text = _format_euros(_displayed_money)

	_update_meta_badges()
	_update_contract_header()
	_update_tool_display()
	_refresh_hotbar()
	_sync_hud_visibility()

func _on_game_state_changed(_state: String) -> void:
	_sync_hud_visibility()

func _sync_hud_visibility() -> void:
	visible = not GameManager.is_main_menu_open

func _create_hotbar_styles() -> void:
	_style_slot_locked = StyleBoxFlat.new()
	_style_slot_locked.bg_color = Color(0.05, 0.06, 0.08, 0.52)
	_style_slot_locked.border_width_left = 1
	_style_slot_locked.border_width_top = 1
	_style_slot_locked.border_width_right = 1
	_style_slot_locked.border_width_bottom = 1
	_style_slot_locked.border_color = Color(0.20, 0.24, 0.30, 0.45)
	_style_slot_locked.set_corner_radius_all(5)
	_style_slot_locked.content_margin_left = 8
	_style_slot_locked.content_margin_right = 8
	_style_slot_locked.content_margin_top = 5
	_style_slot_locked.content_margin_bottom = 5

	_style_slot_unlocked = StyleBoxFlat.new()
	_style_slot_unlocked.bg_color = Color(0.07, 0.09, 0.12, 0.86)
	_style_slot_unlocked.border_width_left = 1
	_style_slot_unlocked.border_width_top = 1
	_style_slot_unlocked.border_width_right = 1
	_style_slot_unlocked.border_width_bottom = 1
	_style_slot_unlocked.border_color = Color(0.36, 0.42, 0.50, 0.85)
	_style_slot_unlocked.set_corner_radius_all(5)
	_style_slot_unlocked.content_margin_left = 8
	_style_slot_unlocked.content_margin_right = 8
	_style_slot_unlocked.content_margin_top = 5
	_style_slot_unlocked.content_margin_bottom = 5

	_style_slot_active = StyleBoxFlat.new()
	_style_slot_active.bg_color = Color(0.18, 0.14, 0.06, 0.96)
	_style_slot_active.border_width_left = 2
	_style_slot_active.border_width_top = 2
	_style_slot_active.border_width_right = 2
	_style_slot_active.border_width_bottom = 2
	_style_slot_active.border_color = Color(0.98, 0.72, 0.14, 1.0)
	_style_slot_active.set_corner_radius_all(5)
	_style_slot_active.content_margin_left = 8
	_style_slot_active.content_margin_right = 8
	_style_slot_active.content_margin_top = 5
	_style_slot_active.content_margin_bottom = 5

func _build_hotbar() -> void:
	for child in hotbar_container.get_children():
		child.queue_free()
	_hotbar_panels.clear()

	for i in range(EconomyManager.TOOL_ORDER.size()):
		var tid: StringName = EconomyManager.TOOL_ORDER[i]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(82, 48)
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
	var c4_cost: int = int(EconomyManager.get_c4_unit_cost())
	for tid in _hotbar_panels.keys():
		var slot: PanelContainer = _hotbar_panels[tid]
		var is_unlocked: bool = EconomyManager.unlocked_tools.has(String(tid))
		var is_equipped: bool = EconomyManager.equipped_tool_id == tid
		var name_lbl := slot.find_child("SlotName", true, false) as Label
		if name_lbl:
			if tid == &"c4_charge":
				name_lbl.text = "C4 (€%d)" % c4_cost
			else:
				name_lbl.text = HOTBAR_SHORT_NAMES.get(tid, String(tid))

		if is_equipped:
			slot.add_theme_stylebox_override("panel", _style_slot_active)
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif is_unlocked:
			slot.add_theme_stylebox_override("panel", _style_slot_unlocked)
			slot.modulate = Color(0.92, 0.94, 0.98, 0.95)
		else:
			slot.add_theme_stylebox_override("panel", _style_slot_locked)
			slot.modulate = Color(0.55, 0.58, 0.62, 0.55)

func _process(delta: float) -> void:
	# Rolling count-up fluido del denaro + fade del badge accumulatore
	if not is_equal_approx(_displayed_money, _target_money):
		var diff: float = _target_money - _displayed_money
		if absf(diff) < 1.0:
			_displayed_money = _target_money
		else:
			_displayed_money = lerpf(_displayed_money, _target_money, minf(12.0 * delta, 1.0))
		money_label.text = _format_euros(_displayed_money)

	if _delta_fade_timer > 0.0:
		_delta_fade_timer -= delta
		if _delta_fade_timer <= 0.0:
			_accumulated_delta = 0.0
			money_delta_label.visible = false
		elif _delta_fade_timer < 0.35:
			money_delta_label.modulate.a = clampf(_delta_fade_timer / 0.35, 0.0, 1.0)

	if GameManager.is_any_ui_open():
		_reset_hold_timer = 0.0
		_reset_triggered = false
		return

	if current_completion_available and Input.is_action_just_pressed("interact"):
		GameManager.complete_current_contract()
		current_completion_available = false
		completion_banner.visible = false

	# Reset cantiere solo tenendo premuto [R] per 1.2s (impedisce reset accidentali!)
	if Input.is_action_pressed("reset_site"):
		if not _reset_triggered:
			_reset_hold_timer += delta
			var pct: int = clampi(int((_reset_hold_timer / RESET_HOLD_DURATION) * 100.0), 0, 100)
			notification_label.visible = true
			notification_label.modulate = Color(1.0, 0.72, 0.25, 1.0)
			notification_label.text = "Tieni premuto [R] per ricostruire il cantiere... %d%%" % pct
			if _reset_hold_timer >= RESET_HOLD_DURATION:
				_reset_triggered = true
				_reset_hold_timer = 0.0
				GameManager.restart_current_contract()
	else:
		if _reset_hold_timer > 0.0 and not _reset_triggered:
			notification_label.visible = false
		_reset_hold_timer = 0.0
		_reset_triggered = false

	if is_instance_valid(_hovered_block) and not _hovered_block.is_destroyed:
		_refresh_target_inspector(_hovered_block)
	elif target_inspector.visible:
		_hovered_block = null
		target_inspector.visible = false
		_set_crosshair_color(Color(1.0, 1.0, 1.0, 0.88))

func _format_euros(amount: float) -> String:
	var n: int = int(floor(maxf(amount, 0.0)))
	var s: String = str(n)
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "." + out
		out = s[i] + out
		count += 1
	return "€ " + out

func _on_currency_changed(new_amount: float, delta_val: float) -> void:
	_target_money = new_amount
	if absf(delta_val) < 0.01:
		_displayed_money = new_amount
		money_label.text = _format_euros(_displayed_money)
		return

	# Accumula nella finestra attiva invece di creare centinaia di scritte (0 lag!)
	if _delta_fade_timer <= 0.0 or (delta_val > 0.0 and _accumulated_delta < 0.0) or (delta_val < 0.0 and _accumulated_delta > 0.0):
		_accumulated_delta = delta_val
	else:
		_accumulated_delta += delta_val

	_delta_fade_timer = 1.25
	money_delta_label.visible = true
	money_delta_label.modulate.a = 1.0
	if _accumulated_delta >= 0.0:
		money_delta_label.text = "+%s" % _format_euros(_accumulated_delta)
		money_delta_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.25))
	else:
		money_delta_label.text = "-%s" % _format_euros(absf(_accumulated_delta))
		money_delta_label.add_theme_color_override("font_color", Color(1.0, 0.36, 0.28))

	# Piccolo punch animato sul contatore
	if _money_punch_tween and _money_punch_tween.is_valid():
		_money_punch_tween.kill()
	money_label.pivot_offset = Vector2(0.0, money_label.size.y * 0.5)
	money_label.scale = Vector2(1.12, 1.12)
	_money_punch_tween = create_tween()
	_money_punch_tween.tween_property(money_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_meta_badges() -> void:
	var cfg: Dictionary = EconomyManager.get_difficulty_config()
	var d_id: String = String(cfg.get("id", "easy"))
	tier_label.text = "%s  •  %d PIANI" % [String(cfg.get("label", "FACILE")), int(cfg.get("floors", 4))]
	if d_id == "hardcore":
		tier_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.34))
	elif d_id == "normal":
		tier_label.add_theme_color_override("font_color", Color(0.98, 0.76, 0.22))
	else:
		tier_label.add_theme_color_override("font_color", Color(0.34, 0.94, 0.52))

	if EconomyManager.prestige_count > 0 or EconomyManager.permanent_multiplier > 1.01:
		prestige_badge.visible = true
		prestige_badge.text = "• PRESTIGIO x%.1f" % EconomyManager.permanent_multiplier
	else:
		prestige_badge.visible = false

func _update_contract_header() -> void:
	var cfg: Dictionary = EconomyManager.get_difficulty_config()
	if GameManager.current_contract and GameManager.current_contract.contract_id == &"tier5_skyscraper":
		contract_title_label.text = "%s  •  %s (%d PIANI)" % [
			GameManager.current_contract.title.to_upper(),
			String(cfg.get("label", "FACILE")),
			int(cfg.get("floors", 4))
		]
	elif GameManager.current_contract:
		contract_title_label.text = "TIER %d  —  %s" % [GameManager.current_contract.tier, GameManager.current_contract.title.to_upper()]
	else:
		contract_title_label.text = "TORRE SKYLINE ARREDATA"

func _on_contract_selected(_contract: ContractData) -> void:
	current_completion_available = false
	completion_banner.visible = false
	_update_contract_header()

func _on_difficulty_changed(_diff_id: String) -> void:
	_update_meta_badges()
	_update_contract_header()
	_refresh_hotbar()
	_update_tool_display()

func _on_floor_cleared(floor_index: int, floor_name: String, bonus_money: float) -> void:
	show_notification(
		"PIANO %d SGOMBERATO (%s)! BONUS +%s" % [floor_index + 1, floor_name, _format_euros(bonus_money)],
		Color(0.34, 0.98, 0.56)
	)

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
	var final_bonus: float = EconomyManager.get_contract_bonus(contract) if contract else 16000.0
	var what: String = "GRATTACIELO ABBATTUTO" if (not contract or contract.contract_id == &"tier5_skyscraper") else "%s ABBATTUTO" % contract.title.to_upper()
	completion_label.text = "%s! Premi [E] per Incassare %s (o demolisci fino al 100%%)" % [what, _format_euros(final_bonus)]

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
	_refresh_hotbar()

func _on_tier_or_prestige_changed(_val: int) -> void:
	_update_meta_badges()

func _on_prestige_performed(_count: int, _mult: float) -> void:
	_update_meta_badges()
	_refresh_hotbar()
	_update_tool_display()

func _on_explosives_count_changed(count: int) -> void:
	c4_badge.visible = count > 0
	c4_badge.text = "C4 ARMATI: %d  ([F] o [7] Detona)" % count
	_update_tool_display()

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
	var m_name: String = block.get_display_label()
	if block.floor_index >= 0:
		m_name = "%s  (P%d)" % [m_name, block.floor_index + 1]
	var m_tier: int = mat.hardness_tier if mat else 1

	target_mat_name.text = m_name
	target_tier_tag.text = "TIER %d" % m_tier
	target_hp_bar.max_value = maxf(block.max_hp, 1.0)
	target_hp_bar.value = clampf(block.current_hp, 0.0, block.max_hp)

	var player: Player = get_tree().get_first_node_in_group("player") as Player
	var pen: int = player.equipped_tool.hardness_penetration if (player and player.equipped_tool) else 1
	if pen < m_tier:
		target_warn_label.visible = true
		target_warn_label.text = "SERVE STRUMENTO T%d  •  Sblocca in [K]" % m_tier
		_set_crosshair_color(Color(1.0, 0.30, 0.25, 0.95))
	else:
		target_warn_label.visible = false
		_set_crosshair_color(Color(1.0, 0.82, 0.25, 0.95))

func _set_crosshair_color(col: Color) -> void:
	for child in crosshair.get_children():
		if child is ColorRect:
			child.color = col

func _on_block_damaged_feedback(_block: Node3D, _amount: float, _pos: Vector3, _nrm: Vector3) -> void:
	crosshair.scale = Vector2(1.25, 1.25)
	crosshair.pivot_offset = crosshair.size * 0.5
	var t: Tween = create_tween()
	t.tween_property(crosshair, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_tool_display() -> void:
	var tool_data: ToolData = EconomyManager.get_tool_data(EconomyManager.equipped_tool_id)
	if not tool_data:
		return

	tool_name_label.text = tool_data.display_name

	var dmg_mult: float = EconomyManager.get_upgrade_total_multiplier(&"tool_damage")
	var spd_mult: float = EconomyManager.get_upgrade_total_multiplier(&"attack_speed")
	var reach_mult: float = EconomyManager.get_upgrade_total_multiplier(&"reach_distance")
	var aoe_mult: float = EconomyManager.get_aoe_radius_multiplier()

	var actual_dmg: float = tool_data.base_damage * dmg_mult
	var actual_cooldown: float = maxf(tool_data.attack_cooldown / spd_mult, 0.055)
	var actual_reach: float = tool_data.reach_distance * reach_mult

	if tool_data.behavior_type == ToolData.BehaviorType.REMOTE_DETONATOR:
		tool_stats_label.text = "Innesco a Catena [LMB / F]  |  Cariche: %d" % GameManager.get_active_explosives_count()
	elif tool_data.behavior_type == ToolData.BehaviorType.EXPLOSIVE_PLACED:
		var c4_cost: int = int(EconomyManager.get_c4_unit_cost())
		var c4_rad: float = tool_data.aoe_radius * aoe_mult
		var c4_dmg: float = tool_data.base_damage * EconomyManager.get_c4_damage_multiplier()
		tool_stats_label.text = "€%d/carica  |  Raggio %.1fm  |  DMG %.0f  |  RMB/F Detona" % [c4_cost, c4_rad, c4_dmg]
	else:
		var aoe_str: String = "  |  AoE %.1fm" % (tool_data.aoe_radius * aoe_mult) if tool_data.aoe_radius > 0.0 else ""
		tool_stats_label.text = "DMG: %.0f  |  T%d  |  %.2fs  |  %.1fm%s" % [
			actual_dmg,
			tool_data.hardness_penetration,
			actual_cooldown,
			actual_reach,
			aoe_str
		]

func show_notification(message: String, color: Color = Color.WHITE) -> void:
	if GameManager.is_main_menu_open:
		return
	notification_label.text = message
	notification_label.modulate = color
	notification_label.visible = true

	if notification_tween and notification_tween.is_valid():
		notification_tween.kill()

	notification_tween = create_tween()
	notification_label.modulate.a = 1.0
	notification_tween.tween_interval(2.6)
	notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.42)
	notification_tween.tween_callback(func():
		if is_instance_valid(notification_label):
			notification_label.visible = false
	)
