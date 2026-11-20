extends Node

const SAVE_PATH := "user://save_v1.json"
const AUTOSAVE_DELAY_SEC := 2.5

var save_data: Dictionary = {}
var _dirty: bool = false
var _autosave_timer: float = 0.0

func _ready() -> void:
	save_data = _get_default_save()
	load_game()

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
		"version": 1,
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
			"debris_value": 0,
			"reach_distance": 0,
			"player_speed": 0,
			"chain_bonus": 0,
			"automation_drone": 0
		},
		"stats": {
			"blocks_destroyed": 0,
			"mass_demolished_kg": 0.0,
			"contracts_completed": 0
		}
	}

func mark_dirty() -> void:
	_dirty = true
	_autosave_timer = AUTOSAVE_DELAY_SEC

func save_game() -> void:
	# Normalizza eventuali chiavi StringName a String per JSON pulito
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
		push_error("SaveManager: impossibile aprire file di salvataggio in scrittura.")

func load_game() -> void:
	var defaults := _get_default_save()
	if not FileAccess.file_exists(SAVE_PATH):
		save_data = defaults
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		save_data = defaults
		return

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if typeof(parsed) == TYPE_DICTIONARY:
		save_data = _deep_merge(defaults, parsed)
		# Rimuovi eventuali chiavi legacy obsolete come "auto_salvage"
		var upg: Dictionary = save_data.get("upgrades", {})
		if upg.has("auto_salvage"):
			upg.erase("auto_salvage")
	else:
		push_warning("SaveManager: file salvataggio corrotto, ripristino predefiniti.")
		save_data = defaults

func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in override.keys():
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(override[key]) == TYPE_DICTIONARY:
			result[key] = _deep_merge(result[key], override[key])
		else:
			result[key] = override[key]
	return result

func reset_save_for_prestige(new_prestige_count: int, new_multiplier: float) -> void:
	var old_stats: Dictionary = save_data.get("stats", {}).duplicate(true)
	save_data = _get_default_save()
	save_data["prestige_count"] = new_prestige_count
	save_data["permanent_multiplier"] = new_multiplier
	save_data["stats"] = _deep_merge(save_data["stats"], old_stats)
	_dirty = false
	save_game()
