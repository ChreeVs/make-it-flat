extends Node

const TOOL_ORDER: Array[StringName] = [
	&"crowbar",
	&"hammer",
	&"sledgehammer_3kg",
	&"sledgehammer_8kg",
	&"electric_demolisher",
	&"c4_charge",
	&"remote_detonator"
]

# Nuova curva economica bilanciata per Tier 1 -> 5
const TIER_LICENSE_COSTS: Dictionary = {
	2: 900.0,
	3: 4500.0,
	4: 16000.0,
	5: 45000.0
}

# Costo unitario di ogni carica C4 piazzata (impedisce lo spam gratuito)
const C4_BASE_UNIT_COST: float = 180.0

var current_money: float = 0.0
var unlocked_tier: int = 1
var equipped_tool_id: StringName = &"crowbar"
var unlocked_tools: Array = ["crowbar"]
var prestige_count: int = 0
var permanent_multiplier: float = 1.0

var upgrade_registry: Dictionary = {}
var _tool_cache: Dictionary = {} # StringName -> ToolData

func _ready() -> void:
	_init_skill_tree()
	_preload_tools()
	_sync_from_save()

func _init_skill_tree() -> void:
	# NODO RADICE
	_register_upgrade(
		&"tool_damage",
		"Forza Strutturale",
		"Potenzia il danno base di tutti gli strumenti e delle esplosioni del +25% per livello.",
		"RADICE",
		45.0,
		1.62,
		20,
		0.25,
		&"",
		0,
		Vector2(0.50, 0.13)
	)

	# RAMO 1: POTENZA & ESPLOSIVI (Sinistra)
	_register_upgrade(
		&"attack_speed",
		"Ritmo di Demolizione",
		"Riduce il tempo tra un colpo e il successivo del +15% per livello.",
		"POTENZA",
		75.0,
		1.65,
		12,
		0.15,
		&"tool_damage",
		1,
		Vector2(0.18, 0.39)
	)
	_register_upgrade(
		&"aoe_boost",
		"Onda Sismica",
		"Espande il raggio d'urto delle mazze pesanti e delle cariche C4 del +18% per livello.",
		"POTENZA",
		280.0,
		1.78,
		8,
		0.18,
		&"attack_speed",
		2,
		Vector2(0.18, 0.65)
	)
	_register_upgrade(
		&"c4_discount",
		"Esplosivista Esperto",
		"Riduce il costo di ogni carica C4 del -10% (fino a -50%) e +20% danno esplosivo.",
		"POTENZA",
		950.0,
		1.95,
		5,
		0.10,
		&"aoe_boost",
		1,
		Vector2(0.18, 0.89)
	)

	# RAMO 2: ECONOMIA & FISICA (Centro)
	_register_upgrade(
		&"debris_value",
		"Riciclo Macerie",
		"Aumenta il valore commerciale di ogni blocco demolito del +20% per livello.",
		"ECONOMIA",
		85.0,
		1.68,
		18,
		0.20,
		&"tool_damage",
		1,
		Vector2(0.50, 0.39)
	)
	_register_upgrade(
		&"chain_bonus",
		"Effetto Domino",
		"Bonus extra del +30% sui blocchi abbattuti per crollo gravitazionale a catena.",
		"ECONOMIA",
		220.0,
		1.75,
		12,
		0.30,
		&"debris_value",
		2,
		Vector2(0.50, 0.65)
	)
	_register_upgrade(
		&"contract_bonus_mult",
		"Appalti d'Oro",
		"Incrementa il premio finale di completamento commessa del +18% per livello.",
		"ECONOMIA",
		650.0,
		1.88,
		10,
		0.18,
		&"chain_bonus",
		1,
		Vector2(0.50, 0.89)
	)

	# RAMO 3: MOBILITÀ & AUTOMAZIONE (Destra)
	_register_upgrade(
		&"reach_distance",
		"Braccio Esteso",
		"Aumenta la portata di colpimento e piazzamento C4 del +12% per livello.",
		"MOBILITA",
		90.0,
		1.65,
		8,
		0.12,
		&"tool_damage",
		1,
		Vector2(0.82, 0.39)
	)
	_register_upgrade(
		&"player_speed",
		"Stivali Antinfortunistici",
		"Velocita di corsa, salita scale e spinta di salto aumentate del +10% per livello.",
		"MOBILITA",
		110.0,
		1.62,
		10,
		0.10,
		&"reach_distance",
		1,
		Vector2(0.82, 0.65)
	)
	_register_upgrade(
		&"automation_drone",
		"Drone Demolitore",
		"Dispiega e potenzia un drone laser autonomo che demolisce le strutture dall'alto.",
		"AUTOMAZIONE",
		550.0,
		2.10,
		8,
		0.50,
		&"player_speed",
		2,
		Vector2(0.82, 0.89)
	)

func _register_upgrade(
	id: StringName,
	title: String,
	description: String,
	category: String,
	base_cost: float,
	multiplier: float,
	max_level: int,
	effect: float,
	parent_id: StringName,
	min_parent_lvl: int,
	tree_pos: Vector2
) -> void:
	upgrade_registry[id] = {
		"id": id,
		"title": title,
		"description": description,
		"category": category,
		"base_cost": base_cost,
		"multiplier": multiplier,
		"max_level": max_level,
		"effect": effect,
		"parent_id": parent_id,
		"min_parent_lvl": min_parent_lvl,
		"tree_pos": tree_pos
	}

func _preload_tools() -> void:
	_tool_cache.clear()
	for tid in TOOL_ORDER:
		var path := "res://data/tools/%s.tres" % String(tid)
		if ResourceLoader.exists(path):
			_tool_cache[tid] = load(path)

func get_tool_data(tool_id: StringName) -> ToolData:
	if _tool_cache.has(tool_id):
		return _tool_cache[tool_id] as ToolData
	var path := "res://data/tools/%s.tres" % String(tool_id)
	if ResourceLoader.exists(path):
		var td: ToolData = load(path)
		_tool_cache[tool_id] = td
		return td
	return null

func _sync_from_save() -> void:
	var data := SaveManager.save_data
	current_money = float(data.get("money", 0.0))
	unlocked_tier = int(data.get("unlocked_tier", 1))
	equipped_tool_id = StringName(String(data.get("equipped_tool", "crowbar")))
	unlocked_tools = data.get("unlocked_tools", ["crowbar"]).duplicate()
	prestige_count = int(data.get("prestige_count", 0))
	permanent_multiplier = float(data.get("permanent_multiplier", 1.0))

	var upgrades: Dictionary = data.get("upgrades", {})
	for up_id in upgrade_registry.keys():
		var key_str := String(up_id)
		if not upgrades.has(key_str):
			upgrades[key_str] = 0
	data["upgrades"] = upgrades

func add_money(amount: float) -> void:
	if amount <= 0.0:
		return
	current_money += amount
	SaveManager.save_data["money"] = current_money
	SaveManager.save_data["total_earned"] = float(SaveManager.save_data.get("total_earned", 0.0)) + amount
	SaveManager.mark_dirty()
	EventBus.currency_changed.emit(current_money, amount)

func spend_money(amount: float) -> bool:
	if amount < 0.0 or current_money < amount:
		return false
	current_money -= amount
	SaveManager.save_data["money"] = current_money
	SaveManager.save_game()
	EventBus.currency_changed.emit(current_money, -amount)
	return true

func get_c4_unit_cost() -> float:
	var disc_lvl: int = get_upgrade_level(&"c4_discount")
	var discount: float = clampf(float(disc_lvl) * 0.10, 0.0, 0.50)
	return round(C4_BASE_UNIT_COST * (1.0 - discount))

func try_pay_c4_charge() -> bool:
	var cost: float = get_c4_unit_cost()
	if current_money < cost:
		EventBus.ui_error.emit()
		EventBus.show_notification.emit(
			"Fondi insufficienti! Ogni carica C4 costa € %d" % int(cost),
			Color(1.0, 0.35, 0.28)
		)
		return false
	return spend_money(cost)

func get_c4_damage_multiplier() -> float:
	var base_mult: float = get_upgrade_total_multiplier(&"tool_damage")
	var exp_bonus: float = 1.0 + float(get_upgrade_level(&"c4_discount")) * 0.20
	return base_mult * exp_bonus

func get_aoe_radius_multiplier() -> float:
	return get_upgrade_total_multiplier(&"aoe_boost")

func get_contract_bonus(contract: ContractData) -> float:
	if not contract:
		return 0.0
	var bonus_mult: float = get_upgrade_total_multiplier(&"contract_bonus_mult")
	return round(contract.completion_bonus * bonus_mult * permanent_multiplier)

func get_upgrade_level(upgrade_id: StringName) -> int:
	var upgrades: Dictionary = SaveManager.save_data.get("upgrades", {})
	return int(upgrades.get(String(upgrade_id), 0))

func is_skill_prereq_met(upgrade_id: StringName) -> bool:
	if not upgrade_registry.has(upgrade_id):
		return false
	var def: Dictionary = upgrade_registry[upgrade_id]
	var parent_id: StringName = def.get("parent_id", &"")
	var min_lvl: int = int(def.get("min_parent_lvl", 0))
	if parent_id == &"" or min_lvl <= 0:
		return true
	return get_upgrade_level(parent_id) >= min_lvl

func get_upgrade_cost(upgrade_id: StringName) -> float:
	if not upgrade_registry.has(upgrade_id):
		return INF
	var def: Dictionary = upgrade_registry[upgrade_id]
	var lvl: int = get_upgrade_level(upgrade_id)
	return floor(float(def["base_cost"]) * pow(float(def["multiplier"]), float(lvl)))

func get_upgrade_total_multiplier(upgrade_id: StringName) -> float:
	if not upgrade_registry.has(upgrade_id):
		return 1.0
	var def: Dictionary = upgrade_registry[upgrade_id]
	var lvl: int = get_upgrade_level(upgrade_id)
	return 1.0 + float(lvl) * float(def["effect"])

func purchase_upgrade(upgrade_id: StringName, enforce_prereq: bool = false) -> bool:
	if not upgrade_registry.has(upgrade_id):
		return false
	if enforce_prereq and not is_skill_prereq_met(upgrade_id):
		EventBus.ui_error.emit()
		return false
	var def: Dictionary = upgrade_registry[upgrade_id]
	var lvl: int = get_upgrade_level(upgrade_id)
	if lvl >= int(def["max_level"]):
		return false
	var cost: float = get_upgrade_cost(upgrade_id)
	if not spend_money(cost):
		EventBus.ui_error.emit()
		return false

	var new_lvl: int = lvl + 1
	SaveManager.save_data["upgrades"][String(upgrade_id)] = new_lvl
	SaveManager.save_game()
	EventBus.ui_click.emit()
	EventBus.upgrade_purchased.emit(upgrade_id, new_lvl, cost)
	return true

func unlock_tool(tool_id: StringName) -> void:
	var key := String(tool_id)
	if not unlocked_tools.has(key):
		unlocked_tools.append(key)
		SaveManager.save_data["unlocked_tools"] = unlocked_tools.duplicate()
		SaveManager.save_game()
		EventBus.tool_unlocked.emit(tool_id)

func equip_tool(tool_id: StringName) -> void:
	var key := String(tool_id)
	if not unlocked_tools.has(key):
		return
	equipped_tool_id = tool_id
	SaveManager.save_data["equipped_tool"] = key
	SaveManager.mark_dirty()
	var td: ToolData = get_tool_data(tool_id)
	if td:
		EventBus.tool_equipped.emit(td)

func get_tier_license_cost(tier: int) -> float:
	return float(TIER_LICENSE_COSTS.get(tier, 999999.0))

func purchase_tier_license(tier: int) -> bool:
	if tier <= unlocked_tier or tier > 5:
		return false
	var cost: float = get_tier_license_cost(tier)
	if not spend_money(cost):
		EventBus.ui_error.emit()
		return false
	unlock_tier(tier)
	EventBus.ui_click.emit()
	EventBus.show_notification.emit("LICENZA TIER %d ACQUISTATA! Nuovi cantieri disponibili." % tier, Color(0.35, 0.92, 0.45))
	return true

func unlock_tier(new_tier: int) -> void:
	var clamped: int = clampi(new_tier, 1, 5)
	if clamped > unlocked_tier:
		unlocked_tier = clamped
		SaveManager.save_data["unlocked_tier"] = unlocked_tier
		SaveManager.save_game()
		EventBus.tier_unlocked.emit(unlocked_tier)

func calculate_block_payout(mat_data: MaterialData, by_gravity: bool = false) -> float:
	if not mat_data:
		return 5.0
	var base_val: float = mat_data.base_money_value
	var debris_mult: float = get_upgrade_total_multiplier(&"debris_value")
	var chain_mult: float = get_upgrade_total_multiplier(&"chain_bonus") if by_gravity else 1.0
	return base_val * debris_mult * chain_mult * permanent_multiplier

func reset_for_new_career() -> void:
	SaveManager.reset_career_save()
	_sync_from_save()
	EventBus.currency_changed.emit(current_money, 0.0)
	EventBus.tier_unlocked.emit(unlocked_tier)
	var start_tool: ToolData = get_tool_data(&"crowbar")
	if start_tool:
		EventBus.tool_equipped.emit(start_tool)

func perform_prestige() -> void:
	prestige_count += 1
	permanent_multiplier = 1.0 + (float(prestige_count) * 0.5)
	SaveManager.reset_save_for_prestige(prestige_count, permanent_multiplier)
	_sync_from_save()

	EventBus.prestige_performed.emit(prestige_count, permanent_multiplier)
	EventBus.currency_changed.emit(current_money, 0.0)
	EventBus.tier_unlocked.emit(unlocked_tier)
	var start_tool: ToolData = get_tool_data(&"crowbar")
	if start_tool:
		EventBus.tool_equipped.emit(start_tool)
