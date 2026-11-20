extends Node

const SAVE_PATH := "user://save_v1.json"
const SETTINGS_PATH := "user://settings_v1.json"
const AUTOSAVE_DELAY_SEC := 2.5

var save_data: Dictionary = {}
var settings: Dictionary = {}
var _dirty: bool = false
var _autosave_timer: float = 0.0

func _ready() -> void:
	save_data = _get_default_save()
	settings = _get_default_settings()
	load_game()
	load_settings()
	apply_settings()

func _process(delta: float) -> void:
	if _dirty:
		_autosave_timer -= delta
		if _autosave_timer <= 0.0:
			_dirty = false
			save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			_dirty = false
			save_game()

func _get_default_save() -> Dictionary:
	return {
		"version": 2,
		"has_seen_intro": false,
		"money": 0.0,
		"total_earned": 0.0,
		"prestige_count": 0,
		"permanent_multiplier": 1.0,
		"unlocked_tier": 1,
		"equipped_tool": "crowbar",
		"unlocked_tools": ["crowbar"],
		"completed_contracts": [],
		"upgrades": {
			"tool_damage": 0,
			"attack_speed": 0,
			"aoe_boost": 0,
			"c4_discount": 0,
			"debris_value": 0,
			"chain_bonus": 0,
			"contract_bonus_mult": 0,
			"reach_distance": 0,
			"player_speed": 0,
			"automation_drone": 0
		},
		"stats": {
			"blocks_destroyed": 0,
			"mass_demolished_kg": 0.0,
			"contracts_completed": 0
		}
	}

func _get_default_settings() -> Dictionary:
	return {
		"master_volume": 0.85,
		"mouse_sensitivity": 1.0,
		"fov": 78.0,
		"camera_shake": true,
		"shadows_enabled": true,
		"fog_enabled": true
	}

func has_existing_career() -> bool:
	return float(save_data.get("total_earned", 0.0)) > 0.0 or int(save_data.get("stats", {}).get("blocks_destroyed", 0)) > 0

func mark_dirty() -> void:
	_dirty = true
	_autosave_timer = AUTOSAVE_DELAY_SEC

func save_game() -> void:
	var clean_upgrades: Dictionary = {}
	var raw_upgrades: Dictionary = save_data.get("upgrades", {})
	for k in raw_upgrades.keys():
		clean_upgrades[String(k)] = int(raw_upgrades[k])
	save_data["upgrades"] = clean_upgrades

	var clean_tools: Array = []
	for t in save_data.get("unlocked_tools", ["crowbar"]):
		var s: String = String(t)
		if not clean_tools.has(s):
			clean_tools.append(s)
	save_data["unlocked_tools"] = clean_tools

	var clean_contracts: Array = []
	for c in save_data.get("completed_contracts", []):
		var cs: String = String(c)
		if not clean_contracts.has(cs):
			clean_contracts.append(cs)
	save_data["completed_contracts"] = clean_contracts
	save_data["equipped_tool"] = String(save_data.get("equipped_tool", "crowbar"))

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
	else:
		push_error("SaveManager: impossibile salvare la partita.")

func load_game() -> void:
	var defaults := _get_default_save()
	if not FileAccess.file_exists(SAVE_PATH):
		save_data = defaults
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		save_data = defaults
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		save_data = _deep_merge(defaults, parsed)
		var upg: Dictionary = save_data.get("upgrades", {})
		if upg.has("auto_salvage"):
			upg.erase("auto_salvage")
	else:
		save_data = defaults

func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()
	apply_settings()

func load_settings() -> void:
	var defaults := _get_default_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		settings = defaults
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		settings = defaults
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		settings = _deep_merge(defaults, parsed)
	else:
		settings = defaults

func apply_settings() -> void:
	var vol: float = clampf(float(settings.get("master_volume", 0.85)), 0.0, 1.0)
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, vol <= 0.005)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(vol, 0.005)))
	EventBus.settings_changed.emit()

func reset_career_save() -> void:
	save_data = _get_default_save()
	_dirty = false
	save_game()

func reset_save_for_prestige(new_prestige_count: int, new_multiplier: float) -> void:
	var old_stats: Dictionary = save_data.get("stats", {}).duplicate(true)
	save_data = _get_default_save()
	save_data["has_seen_intro"] = true
	save_data["prestige_count"] = new_prestige_count
	save_data["permanent_multiplier"] = new_multiplier
	save_data["stats"] = _deep_merge(save_data["stats"], old_stats)
	_dirty = false
	save_game()

func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in override.keys():
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(override[key]) == TYPE_DICTIONARY:
			result[key] = _deep_merge(result[key], override[key])
		else:
			result[key] = override[key]
	return result
