extends Node

var current_money: float = 0.0
var scrap_inventory: Dictionary = {}
var upgrade_levels: Dictionary = {}
var unlocked_tools: Array = ["crowbar"]
var equipped_tool_id: StringName = &"crowbar"
var unlocked_tier: int = 1
var prestige_count: int = 0
var permanent_multiplier: float = 1.0

# Database degli upgrade registrati
var upgrade_registry: Dictionary = {}

func _ready() -> void:
	_init_upgrades()
	_sync_from_save()

	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.chain_collapse_triggered.connect(_on_chain_collapse_triggered)

func _init_upgrades() -> void:
	_register_upgrade("tool_damage", "Danno Strumento", "+25% danno per colpo", 40.0, 1.18, 0.25, 50)
	_register_upgrade("attack_speed", "Velocità Braccio", "+12% velocità d'attacco", 50.0, 1.20, 0.12, 35)
	_register_upgrade("debris_value", "Valore Macerie", "+20% denaro ricavato dai detriti", 60.0, 1.22, 0.20, 40)
	_register_upgrade("reach_distance", "Allungo Operaio", "+15% distanza di colpo", 35.0, 1.16, 0.15, 20)
	_register_upgrade("chain_bonus", "Maestro del Crollo", "+30% moltiplicatore caduta", 80.0, 1.25, 0.30, 25)
	_register_upgrade("automation_drone", "Drone Demolitore", "Drone orbitale che distrugge automaticamente i blocchi", 2500.0, 1.30, 0.40, 10)

func _register_upgrade(id: StringName, title: String, desc: String, base_cost: float, growth: float, effect: float, max_lvl: int) -> void:
	upgrade_registry[id] = {
		"id": id,
		"title": title,
		"description": desc,
		"base_cost": base_cost,
		"growth": growth,
		"effect": effect,
		"max_level": max_lvl
	}

func _sync_from_save() -> void:
	var data: Dictionary = SaveManager.save_data
	current_money = float(data.get("money", 0.0))
	scrap_inventory = data.get("scrap_materials", {})
	unlocked_tier = int(data.get("unlocked_tier", 1))
	unlocked_tools = data.get("unlocked_tools", ["crowbar"])
	equipped_tool_id = StringName(data.get("equipped_tool", "crowbar"))
	prestige_count = int(data.get("prestige_count", 0))
	permanent_multiplier = float(data.get("permanent_multiplier", 1.0))
	
	var saved_upgrades: Dictionary = data.get("upgrade_levels", {})
	for id in upgrade_registry.keys():
		upgrade_levels[id] = int(saved_upgrades.get(id, 0))

func add_money(amount: float, notify_pos: Vector3 = Vector3.ZERO) -> void:
	if amount <= 0.0:
		return
	current_money += amount
	SaveManager.save_data["money"] = current_money
	EventBus.currency_changed.emit(current_money, amount)
	if notify_pos != Vector3.ZERO:
		EventBus.show_floating_text.emit("+€%.0f" % amount, notify_pos, Color(0.2, 0.9, 0.3))

func spend_money(amount: float) -> bool:
	if current_money >= amount:
		current_money -= amount
		SaveManager.save_data["money"] = current_money
		EventBus.currency_changed.emit(current_money, -amount)
		SaveManager.save_game()
		return true
	return false

func get_upgrade_level(id: StringName) -> int:
	return upgrade_levels.get(id, 0)

func get_upgrade_cost(id: StringName) -> float:
	if not upgrade_registry.has(id):
		return 999999.0
	var def: Dictionary = upgrade_registry[id]
	var lvl: int = get_upgrade_level(id)
	return round(def["base_cost"] * pow(def["growth"], lvl))

func get_upgrade_total_multiplier(id: StringName) -> float:
	if not upgrade_registry.has(id):
		return 1.0
	var def: Dictionary = upgrade_registry[id]
	var lvl: int = get_upgrade_level(id)
	return 1.0 + (lvl * def["effect"])

func purchase_upgrade(id: StringName) -> bool:
	if not upgrade_registry.has(id):
		return false
	var def: Dictionary = upgrade_registry[id]
	var lvl: int = get_upgrade_level(id)
	if lvl >= def["max_level"]:
		return false
	var cost: float = get_upgrade_cost(id)
	if spend_money(cost):
		upgrade_levels[id] = lvl + 1
		SaveManager.save_data["upgrade_levels"][id] = lvl + 1
		SaveManager.save_game()
		EventBus.upgrade_purchased.emit(id, lvl + 1, get_upgrade_cost(id))
		return true
	return false

func _on_block_destroyed(block: Node3D, by_gravity: bool, mat_data: MaterialData, pos: Vector3) -> void:
	if not mat_data:
		return
	var base_val: float = mat_data.base_money_value
	var value_mult: float = get_upgrade_total_multiplier("debris_value")
	var chain_mult: float = 1.0
	if by_gravity:
		chain_mult = 1.5 * get_upgrade_total_multiplier("chain_bonus")
	var payout: float = base_val * value_mult * chain_mult * permanent_multiplier
	add_money(payout, pos)

func _on_chain_collapse_triggered(count: int, total_mass: float) -> void:
	# Bonus aggiuntivo proporzionale alla massa crollata
	var collapse_bonus: float = (total_mass * 0.15) * get_upgrade_total_multiplier("chain_bonus") * permanent_multiplier
	if collapse_bonus > 1.0:
		add_money(collapse_bonus)
		EventBus.show_notification.emit("Crollo a Catena! +€%.0f (%d blocchi, %.0f kg)" % [collapse_bonus, count, total_mass], Color(1.0, 0.8, 0.2))

func unlock_tool(tool_id: StringName) -> void:
	if not unlocked_tools.has(String(tool_id)):
		unlocked_tools.append(String(tool_id))
		SaveManager.save_data["unlocked_tools"] = unlocked_tools
		SaveManager.save_game()
		EventBus.tool_unlocked.emit(tool_id)

func equip_tool(tool_id: StringName) -> void:
	equipped_tool_id = tool_id
	SaveManager.save_data["equipped_tool"] = String(tool_id)
	SaveManager.save_game()

func unlock_next_tier() -> void:
	unlocked_tier += 1
	SaveManager.save_data["unlocked_tier"] = unlocked_tier
	SaveManager.save_game()
	EventBus.tier_unlocked.emit(unlocked_tier)

func perform_prestige() -> void:
	prestige_count += 1
	permanent_multiplier += 0.5 # +50% permanente per ciclo
	current_money = 0.0
	unlocked_tier = 1
	unlocked_tools = ["crowbar"]
	equipped_tool_id = &"crowbar"
	for k in upgrade_levels.keys():
		upgrade_levels[k] = 0
	SaveManager.save_data["prestige_count"] = prestige_count
	SaveManager.save_data["permanent_multiplier"] = permanent_multiplier
	SaveManager.save_data["money"] = current_money
	SaveManager.save_data["unlocked_tier"] = unlocked_tier
	SaveManager.save_data["unlocked_tools"] = unlocked_tools
	SaveManager.save_data["equipped_tool"] = "crowbar"
	SaveManager.save_data["upgrade_levels"] = upgrade_levels
	SaveManager.save_game()
	EventBus.prestige_performed.emit(prestige_count, permanent_multiplier)
