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

const TIER_LICENSE_COSTS: Dictionary = {
	2: 900.0,
	3: 4500.0,
	4: 16000.0,
	5: 45000.0
}

const C4_BASE_UNIT_COST: float = 160.0

# Profili di difficoltà regolabili (Facile -> Normale -> Hardcore)
const DIFFICULTIES: Dictionary = {
	"easy": {
		"id": "easy",
		"label": "FACILE",
		"subtitle": "Torre 4 Piani Arredati  •  Guadagni +85%  •  Costi -32%  •  Sblocca tutto in 1 partita",
		"floors": 4,
		"payout_mult": 1.85,
		"hp_mult": 0.72,
		"cost_mult": 0.68,
		"c4_cost": 90.0,
		"floor_bonus_base": 1100.0,
		"tower_bonus": 16000.0
	},
	"normal": {
		"id": "normal",
		"label": "NORMALE",
		"subtitle": "Torre 6 Piani Arredati  •  Economia Bilanciata  •  Sfida Strutturale Completa",
		"floors": 6,
		"payout_mult": 1.20,
		"hp_mult": 1.00,
		"cost_mult": 1.00,
		"c4_cost": 160.0,
		"floor_bonus_base": 1400.0,
		"tower_bonus": 28000.0
	},
	"hardcore": {
		"id": "hardcore",
		"label": "HARDCORE",
		"subtitle": "Torre 8 Piani Colossale  •  Strutture +45% HP  •  C4 €240  •  Per Demolitori Esperti",
		"floors": 8,
		"payout_mult": 0.90,
		"hp_mult": 1.45,
		"cost_mult": 1.25,
		"c4_cost": 240.0,
		"floor_bonus_base": 1800.0,
		"tower_bonus": 55000.0
	}
}

# Mappa Sblocco Automatico Strumenti tramite Potenziamenti dell'Albero Abilità!
const UPGRADE_TOOL_UNLOCKS: Array[Dictionary] = [
	{"upgrade": &"tool_damage", "level": 1, "tool": &"hammer", "name": "Martello Carpentiere [2]"},
	{"upgrade": &"attack_speed", "level": 1, "tool": &"sledgehammer_3kg", "name": "Mazza 3kg [3]"},
	{"upgrade": &"attack_speed", "level": 3, "tool": &"sledgehammer_8kg", "name": "Mazza Pesante 8kg [4]"},
	{"upgrade": &"aoe_boost", "level": 1, "tool": &"electric_demolisher", "name": "Demolitore Elettrico [5]"},
	{"upgrade": &"c4_discount", "level": 1, "tool": &"c4_charge", "name": "Carica C4 [6]"},
	{"upgrade": &"c4_discount", "level": 1, "tool": &"remote_detonator", "name": "Detonatore Remoto [7]"}
]

var current_difficulty: String = "easy"
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
	# NODO RADICE -> Lv.1 sblocca Martello [2]
	_register_upgrade(
		&"tool_damage",
		"Forza & Martello",
		"Potenzia il danno base di tutti gli strumenti del +25%/lv.  ★ Lv.1 SBLOCCA: Martello Carpentiere [2]!",
		"RADICE",
		120.0,
		1.52,
		10,
		0.25,
		&"",
		0,
		Vector2(0.50, 0.13),
		"Lv.1 → Martello [2]"
	)

	# RAMO 1: POTENZA & ARSENALE (Sinistra)
	_register_upgrade(
		&"attack_speed",
		"Ritmo & Mazze",
		"Velocità d'attacco +15%/lv.  ★ Lv.1 SBLOCCA: Mazza 3kg [3]  •  ★ Lv.3 SBLOCCA: Mazza Pesante 8kg [4] (T2)!",
		"POTENZA",
		320.0,
		1.55,
		8,
		0.15,
		&"tool_damage",
		1,
		Vector2(0.18, 0.39),
		"Lv.1 Mazza 3k • Lv.3 Mazza 8k"
	)
	_register_upgrade(
		&"aoe_boost",
		"Demolitore & Onda d'Urto",
		"Espande raggio AoE di mazze ed esplosivi del +20%/lv.  ★ Lv.1 SBLOCCA: Demolitore Elettrico [5] (T3)!",
		"POTENZA",
		1600.0,
		1.58,
		6,
		0.20,
		&"attack_speed",
		2,
		Vector2(0.18, 0.65),
		"Lv.1 → Demolitore [5]"
	)
	_register_upgrade(
		&"c4_discount",
		"Genio Esplosivista C4",
		"★ Lv.1 SBLOCCA: C4 [6] + Detonatore [7] (T4)! Ogni livello aumenta il danno esplosivo del +25%; dal Lv.2 ogni livello sconta il costo C4 del -12,5% (max -50%).",
		"POTENZA",
		4800.0,
		1.62,
		5,
		0.10,
		&"aoe_boost",
		1,
		Vector2(0.18, 0.89),
		"Lv.1 → C4 [6] + Deton. [7]"
	)

	# RAMO 2: ECONOMIA & RECUPERO (Centro)
	_register_upgrade(
		&"debris_value",
		"Riciclo Arredi & Macerie",
		"Aumenta il valore commerciale di ogni mobile, parete e pilastro demolito del +25% per livello.",
		"ECONOMIA",
		240.0,
		1.54,
		10,
		0.25,
		&"tool_damage",
		1,
		Vector2(0.50, 0.39),
		"+25% Valore Arredi"
	)
	_register_upgrade(
		&"chain_bonus",
		"Effetto Domino",
		"Bonus extra del +35% sui blocchi e piani abbattuti per crollo gravitazionale a catena.",
		"ECONOMIA",
		720.0,
		1.58,
		8,
		0.35,
		&"debris_value",
		1,
		Vector2(0.50, 0.65),
		"+35% Bonus Crolli"
	)
	_register_upgrade(
		&"contract_bonus_mult",
		"Premi di Piano & Appalto",
		"Incrementa i premi monetari al completamento di ogni piano e dell'intera torre del +25% per livello.",
		"ECONOMIA",
		1500.0,
		1.60,
		6,
		0.25,
		&"chain_bonus",
		1,
		Vector2(0.50, 0.89),
		"+25% Premi Piano/Torre"
	)

	# RAMO 3: MOBILITÀ & AUTOMAZIONE (Destra)
	_register_upgrade(
		&"reach_distance",
		"Braccio Esteso",
		"Aumenta la portata di demolizione e piazzamento C4 del +14% per livello.",
		"MOBILITA",
		260.0,
		1.55,
		6,
		0.14,
		&"tool_damage",
		1,
		Vector2(0.82, 0.39),
		"+14% Portata"
	)
	_register_upgrade(
		&"player_speed",
		"Stivali & Agilità",
		"Velocità di corsa, accovacciata, salto e salita scale aumentata del +12% per livello.",
		"MOBILITA",
		380.0,
		1.55,
		6,
		0.12,
		&"reach_distance",
		1,
		Vector2(0.82, 0.65),
		"+12% Corsa & Scale"
	)
	_register_upgrade(
		&"automation_drone",
		"Drone Laser Autonomo",
		"★ Lv.1 DISPIEGA il Drone Laser Autonomo che demolisce il grattacielo dall'alto! Livelli extra potenziano il laser.",
		"AUTOMAZIONE",
		2200.0,
		1.65,
		5,
		0.50,
		&"player_speed",
		1,
		Vector2(0.82, 0.89),
		"Lv.1 → Drone Laser"
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
	tree_pos: Vector2,
	unlock_badge: String = ""
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
		"tree_pos": tree_pos,
		"unlock_badge": unlock_badge
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

func get_difficulty_config() -> Dictionary:
	return DIFFICULTIES.get(current_difficulty, DIFFICULTIES["easy"])

func set_difficulty(diff_id: String) -> void:
	if not DIFFICULTIES.has(diff_id):
		diff_id = "easy"
	current_difficulty = diff_id
	SaveManager.save_data["difficulty"] = diff_id
	SaveManager.save_game()
	EventBus.difficulty_changed.emit(diff_id)

func get_difficulty_hp_multiplier() -> float:
	return float(get_difficulty_config().get("hp_mult", 1.0))

func get_difficulty_payout_multiplier() -> float:
	return float(get_difficulty_config().get("payout_mult", 1.0))

func get_difficulty_cost_multiplier() -> float:
	return float(get_difficulty_config().get("cost_mult", 1.0))

func get_target_skyscraper_floors() -> int:
	return int(get_difficulty_config().get("floors", 4))

func get_floor_clear_bonus(floor_index: int) -> float:
	var base: float = float(get_difficulty_config().get("floor_bonus_base", 1100.0))
	var mult: float = get_upgrade_total_multiplier(&"contract_bonus_mult")
	return round(base * (1.0 + float(floor_index) * 0.22) * mult * permanent_multiplier)

func get_tool_unlock_hint(tool_id: StringName) -> String:
	if tool_id == &"crowbar":
		return "Strumento Base"
	for entry in UPGRADE_TOOL_UNLOCKS:
		if entry["tool"] == tool_id:
			var uid: StringName = entry["upgrade"]
			var title: String = String(upgrade_registry.get(uid, {}).get("title", String(uid)))
			return "Potenzia '%s' a Lv.%d [K]" % [title, int(entry["level"])]
	return "Sbloccabile nell'Albero Abilità [K]"

func _sync_from_save() -> void:
	var data := SaveManager.save_data
	current_difficulty = String(data.get("difficulty", "easy"))
	if not DIFFICULTIES.has(current_difficulty):
		current_difficulty = "easy"
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
	_sync_tools_from_upgrades(false)

func _sync_tools_from_upgrades(notify: bool = true) -> void:
	for entry in UPGRADE_TOOL_UNLOCKS:
		var uid: StringName = entry["upgrade"]
		var req_lvl: int = int(entry["level"])
		var tid: StringName = entry["tool"]
		if get_upgrade_level(uid) >= req_lvl and not unlocked_tools.has(String(tid)):
			unlock_tool(tid)
			if notify:
				EventBus.show_notification.emit(
					"NUOVO STRUMENTO SBLOCCATO: %s!" % String(entry["name"]),
					Color(0.98, 0.78, 0.22)
				)
				if tid != &"remote_detonator":
					equip_tool(tid)

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
	var base_c4: float = float(get_difficulty_config().get("c4_cost", C4_BASE_UNIT_COST))
	var disc_lvl: int = maxi(get_upgrade_level(&"c4_discount") - 1, 0)
	var discount: float = clampf(float(disc_lvl) * 0.125, 0.0, 0.50)
	return round(base_c4 * (1.0 - discount))

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
	var exp_bonus: float = 1.0 + float(get_upgrade_level(&"c4_discount")) * 0.25
	return base_mult * exp_bonus

func get_aoe_radius_multiplier() -> float:
	return get_upgrade_total_multiplier(&"aoe_boost")

func get_contract_bonus(contract: ContractData) -> float:
	var base_bonus: float = float(get_difficulty_config().get("tower_bonus", 16000.0))
	if contract and contract.contract_id != &"tier5_skyscraper":
		base_bonus = contract.completion_bonus
	var bonus_mult: float = get_upgrade_total_multiplier(&"contract_bonus_mult")
	return round(base_bonus * bonus_mult * permanent_multiplier)

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
	var raw_cost: float = float(def["base_cost"]) * pow(float(def["multiplier"]), float(lvl))
	return floor(raw_cost * get_difficulty_cost_multiplier())

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
	_sync_tools_from_upgrades(true)
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
		return 8.0 * get_difficulty_payout_multiplier()
	var base_val: float = mat_data.base_money_value
	var debris_mult: float = get_upgrade_total_multiplier(&"debris_value")
	var chain_mult: float = get_upgrade_total_multiplier(&"chain_bonus") if by_gravity else 1.0
	var diff_mult: float = get_difficulty_payout_multiplier()
	return base_val * debris_mult * chain_mult * diff_mult * permanent_multiplier

func reset_for_new_career(difficulty_id: String = "") -> void:
	SaveManager.reset_career_save(difficulty_id)
	_sync_from_save()
	EventBus.difficulty_changed.emit(current_difficulty)
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
