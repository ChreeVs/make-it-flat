class_name SkillTreeMenu
extends Control

@onready var money_label: Label = $Panel/Margin/VBox/Header/MoneyLabel
@onready var shop_switch_btn: Button = $Panel/Margin/VBox/Header/ShopSwitchButton
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var tree_canvas: Control = $Panel/Margin/VBox/Body/TreeFrame/TreeCanvas

@onready var branch_tag: Label = $Panel/Margin/VBox/Body/DetailPanel/DetailVBox/BranchTag
@onready var node_title: Label = $Panel/Margin/VBox/Body/DetailPanel/DetailVBox/NodeTitle
@onready var node_level: Label = $Panel/Margin/VBox/Body/DetailPanel/DetailVBox/NodeLevel
@onready var node_desc: Label = $Panel/Margin/VBox/Body/DetailPanel/DetailVBox/NodeDesc
@onready var bonus_box: Label = $Panel/Margin/VBox/Body/DetailPanel/DetailVBox/BonusBox
@onready var prereq_label: Label = $Panel/Margin/VBox/Body/DetailPanel/DetailVBox/PrereqLabel
@onready var buy_button: Button = $Panel/Margin/VBox/Body/DetailPanel/DetailVBox/BuyButton

const NODE_SIZE := Vector2(196.0, 74.0)

const BRANCH_COLORS: Dictionary = {
	"RADICE": Color(0.98, 0.74, 0.18),
	"POTENZA": Color(0.98, 0.42, 0.26),
	"ECONOMIA": Color(0.32, 0.92, 0.50),
	"MOBILITA": Color(0.32, 0.76, 1.0),
	"AUTOMAZIONE": Color(0.76, 0.52, 1.0)
}

var _selected_id: StringName = &"tool_damage"
var _node_buttons: Dictionary = {} # StringName -> Button
var _style_locked: StyleBoxFlat
var _style_available: StyleBoxFlat
var _style_active: StyleBoxFlat
var _style_selected: StyleBoxFlat

func _ready() -> void:
	visible = false
	_init_styles()
	close_button.focus_mode = Control.FOCUS_NONE
	shop_switch_btn.focus_mode = Control.FOCUS_NONE
	buy_button.focus_mode = Control.FOCUS_NONE
	shop_switch_btn.text = "Arsenale [B]"

	close_button.pressed.connect(close_menu)
	buy_button.pressed.connect(_on_buy_pressed)
	shop_switch_btn.pressed.connect(_on_switch_to_shop)
	tree_canvas.draw.connect(_on_canvas_draw)
	tree_canvas.resized.connect(_layout_nodes)

	EventBus.currency_changed.connect(func(_a, _d): if visible: refresh_tree())
	EventBus.upgrade_purchased.connect(func(_id, _lvl, _cost): if visible: refresh_tree())
	EventBus.difficulty_changed.connect(func(_d): if visible: refresh_tree())

	_create_node_buttons()

func _init_styles() -> void:
	_style_locked = StyleBoxFlat.new()
	_style_locked.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	_style_locked.border_width_left = 2
	_style_locked.border_width_top = 1
	_style_locked.border_width_right = 1
	_style_locked.border_width_bottom = 1
	_style_locked.border_color = Color(0.24, 0.28, 0.34, 0.85)
	_style_locked.set_corner_radius_all(7)

	_style_available = StyleBoxFlat.new()
	_style_available.bg_color = Color(0.11, 0.14, 0.19, 0.96)
	_style_available.border_width_left = 3
	_style_available.border_width_top = 1
	_style_available.border_width_right = 1
	_style_available.border_width_bottom = 1
	_style_available.border_color = Color(0.55, 0.68, 0.84, 0.95)
	_style_available.set_corner_radius_all(7)

	_style_active = StyleBoxFlat.new()
	_style_active.bg_color = Color(0.09, 0.19, 0.14, 0.96)
	_style_active.border_width_left = 3
	_style_active.border_width_top = 1
	_style_active.border_width_right = 1
	_style_active.border_width_bottom = 1
	_style_active.border_color = Color(0.32, 0.92, 0.50, 0.95)
	_style_active.set_corner_radius_all(7)

	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.20, 0.16, 0.07, 0.98)
	_style_selected.border_width_left = 3
	_style_selected.border_width_top = 2
	_style_selected.border_width_right = 2
	_style_selected.border_width_bottom = 2
	_style_selected.border_color = Color(0.98, 0.74, 0.18, 1.0)
	_style_selected.set_corner_radius_all(7)

func open_menu() -> void:
	GameManager.close_gameplay_overlays("SkillTreeMenu")
	visible = true
	GameManager.is_skill_tree_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_click.emit()
	call_deferred("_layout_and_refresh")

func _layout_and_refresh() -> void:
	_layout_nodes()
	refresh_tree()

func close_menu() -> void:
	visible = false
	GameManager.is_skill_tree_open = false
	if not GameManager.is_any_ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_switch_to_shop() -> void:
	var shop := get_tree().get_root().find_child("ShopMenu", true, false)
	if shop and shop.has_method("open_shop"):
		shop.open_shop()

func _create_node_buttons() -> void:
	for child in tree_canvas.get_children():
		child.queue_free()
	_node_buttons.clear()

	# Intestazioni di ramo fisse in alto alle 3 colonne
	var col_headers := [
		["ARSENALE & C4", 0.18, Color(0.98, 0.45, 0.28)],
		["ECONOMIA & CROLLI", 0.50, Color(0.32, 0.92, 0.50)],
		["MOBILITÀ & DRONE", 0.82, Color(0.35, 0.78, 1.0)]
	]
	for ch in col_headers:
		var lbl := Label.new()
		lbl.name = "Header_%s" % ch[0]
		lbl.text = ch[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", ch[2])
		lbl.set_meta("col_x", ch[1])
		tree_canvas.add_child(lbl)

	for up_id in EconomyManager.upgrade_registry.keys():
		var btn := Button.new()
		btn.custom_minimum_size = NODE_SIZE
		btn.size = NODE_SIZE
		btn.clip_text = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func():
			_selected_id = up_id
			EventBus.ui_click.emit()
			refresh_tree()
		)
		tree_canvas.add_child(btn)
		_node_buttons[up_id] = btn

func _layout_nodes() -> void:
	var sz: Vector2 = tree_canvas.size
	if sz.x < 100.0 or sz.y < 100.0:
		return

	for child in tree_canvas.get_children():
		if child is Label and child.has_meta("col_x"):
			var cx: float = float(child.get_meta("col_x")) * sz.x
			child.size = Vector2(180.0, 20.0)
			child.position = Vector2(cx - 90.0, sz.y * 0.245)

	for up_id in _node_buttons.keys():
		var def: Dictionary = EconomyManager.upgrade_registry[up_id]
		var rel: Vector2 = def.get("tree_pos", Vector2(0.5, 0.5))
		var btn: Button = _node_buttons[up_id]
		var center := Vector2(rel.x * sz.x, rel.y * sz.y)
		btn.size = NODE_SIZE
		btn.position = center - NODE_SIZE * 0.5

	tree_canvas.queue_redraw()

func _on_canvas_draw() -> void:
	var sz: Vector2 = tree_canvas.size
	if sz.x < 100.0 or sz.y < 100.0:
		return

	for up_id in EconomyManager.upgrade_registry.keys():
		var def: Dictionary = EconomyManager.upgrade_registry[up_id]
		var parent_id: StringName = def.get("parent_id", &"")
		if parent_id == &"" or not EconomyManager.upgrade_registry.has(parent_id):
			continue

		var p_rel: Vector2 = EconomyManager.upgrade_registry[parent_id].get("tree_pos", Vector2(0.5, 0.13))
		var c_rel: Vector2 = def.get("tree_pos", Vector2(0.5, 0.5))
		var p_pos := Vector2(p_rel.x * sz.x, p_rel.y * sz.y)
		var c_pos := Vector2(c_rel.x * sz.x, c_rel.y * sz.y)

		var prereq_ok: bool = EconomyManager.is_skill_prereq_met(up_id)
		var child_lvl: int = EconomyManager.get_upgrade_level(up_id)
		var line_col := Color(0.24, 0.28, 0.36, 0.85)
		var width := 2.5
		if child_lvl > 0:
			line_col = Color(0.32, 0.92, 0.50, 0.95)
			width = 3.8
		elif prereq_ok:
			line_col = Color(0.96, 0.72, 0.18, 0.90)
			width = 3.0

		var mid_y: float = (p_pos.y + c_pos.y) * 0.5
		tree_canvas.draw_line(p_pos, Vector2(p_pos.x, mid_y), line_col, width, true)
		tree_canvas.draw_line(Vector2(p_pos.x, mid_y), Vector2(c_pos.x, mid_y), line_col, width, true)
		tree_canvas.draw_line(Vector2(c_pos.x, mid_y), c_pos, line_col, width, true)

func refresh_tree() -> void:
	var cfg: Dictionary = EconomyManager.get_difficulty_config()
	money_label.text = "Capitale: € %d  (%s)" % [int(EconomyManager.current_money), String(cfg.get("label", "FACILE"))]

	for up_id in _node_buttons.keys():
		var btn: Button = _node_buttons[up_id]
		var def: Dictionary = EconomyManager.upgrade_registry[up_id]
		var lvl: int = EconomyManager.get_upgrade_level(up_id)
		var max_lvl: int = int(def["max_level"])
		var prereq_ok: bool = EconomyManager.is_skill_prereq_met(up_id)
		var cost: int = int(EconomyManager.get_upgrade_cost(up_id))
		var badge: String = String(def.get("unlock_badge", ""))

		var sub_str: String = "MAX" if lvl >= max_lvl else ("€ %d" % cost if prereq_ok else "BLOCCATO")
		if badge != "":
			btn.text = "%s\n★ %s\nLiv. %d/%d  •  %s" % [def["title"], badge, lvl, max_lvl, sub_str]
		else:
			btn.text = "%s\nLiv. %d/%d  •  %s" % [def["title"], lvl, max_lvl, sub_str]

		var style: StyleBoxFlat = _style_locked
		if up_id == _selected_id:
			style = _style_selected
		elif lvl > 0:
			style = _style_active
		elif prereq_ok:
			style = _style_available
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", _style_selected)
		btn.add_theme_stylebox_override("pressed", _style_selected)

	_refresh_detail_panel()
	tree_canvas.queue_redraw()

func _refresh_detail_panel() -> void:
	if not EconomyManager.upgrade_registry.has(_selected_id):
		return
	var def: Dictionary = EconomyManager.upgrade_registry[_selected_id]
	var lvl: int = EconomyManager.get_upgrade_level(_selected_id)
	var max_lvl: int = int(def["max_level"])
	var cost: float = EconomyManager.get_upgrade_cost(_selected_id)
	var prereq_ok: bool = EconomyManager.is_skill_prereq_met(_selected_id)
	var cat: String = String(def.get("category", "ABILITA"))
	var badge: String = String(def.get("unlock_badge", ""))

	branch_tag.text = "RAMO %s" % cat
	branch_tag.add_theme_color_override("font_color", BRANCH_COLORS.get(cat, Color.WHITE))
	node_title.text = String(def["title"])
	node_level.text = "Livello: %d / %d" % [lvl, max_lvl]
	node_desc.text = String(def["description"])

	var cur_pct: float = float(lvl) * float(def["effect"]) * 100.0
	var next_pct: float = float(mini(lvl + 1, max_lvl)) * float(def["effect"]) * 100.0
	var bonus_lines: String = ""
	if _selected_id == &"c4_discount":
		var disc_pct: float = clampf(float(maxi(lvl - 1, 0)) * 12.5, 0.0, 50.0)
		bonus_lines = "Costo C4 attuale: €%d/carica  (Sconto -%.1f%% • Danno C4 +%.0f%%)" % [
			int(EconomyManager.get_c4_unit_cost()),
			disc_pct,
			float(lvl) * 25.0
		]
	elif lvl >= max_lvl:
		bonus_lines = "Bonus Massimo Raggiunto: +%.0f%%" % cur_pct
	else:
		bonus_lines = "Bonus Attuale: +%.0f%%  →  Prossimo: +%.0f%%" % [cur_pct, next_pct]

	if badge != "":
		bonus_lines += "\n★ Sblocco: %s" % badge
	bonus_box.text = bonus_lines

	if not prereq_ok:
		var p_id: StringName = def["parent_id"]
		var p_title: String = EconomyManager.upgrade_registry[p_id]["title"]
		prereq_label.visible = true
		prereq_label.text = "PREREQUISITO: Porta '%s' almeno al Livello %d" % [p_title, int(def["min_parent_lvl"])]
	else:
		prereq_label.visible = false

	if lvl >= max_lvl:
		buy_button.text = "ABILITÀ AL MASSIMO"
		buy_button.disabled = true
	elif not prereq_ok:
		buy_button.text = "PREREQUISITO RICHIESTO"
		buy_button.disabled = true
	else:
		buy_button.text = "POTENZIA  (€ %d)" % int(cost)
		buy_button.disabled = EconomyManager.current_money < cost

func _on_buy_pressed() -> void:
	if EconomyManager.purchase_upgrade(_selected_id, true):
		refresh_tree()
