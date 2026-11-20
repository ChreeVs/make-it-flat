extends Node

const SAVE_PATH: String = "user://save_v1.json"
const SAVE_TMP_PATH: String = "user://save_v1.tmp"

var save_data: Dictionary = {
	"version": 1,
	"money": 0.0,
	"scrap_materials": {},
	"unlocked_tier": 1,
	"unlocked_tools": ["crowbar"],
	"equipped_tool": "crowbar",
	"upgrade_levels": {},
	"completed_contracts": [],
	"prestige_count": 0,
	"permanent_multiplier": 1.0,
	"settings": {
		"mouse_sensitivity": 0.002,
		"master_volume": 1.0,
		"sfx_volume": 1.0
	}
}

func _ready() -> void:
	load_game()

func get_default_data() -> Dictionary:
	return {
		"version": 1,
		"money": 0.0,
		"scrap_materials": {},
		"unlocked_tier": 1,
		"unlocked_tools": ["crowbar"],
		"equipped_tool": "crowbar",
		"upgrade_levels": {
			"tool_damage": 0,
			"attack_speed": 0,
			"debris_value": 0,
			"reach_distance": 0,
			"player_speed": 0,
			"auto_salvage": 0
		},
		"completed_contracts": [],
		"prestige_count": 0,
		"permanent_multiplier": 1.0,
		"settings": {
			"mouse_sensitivity": 0.002,
			"master_volume": 1.0,
			"sfx_volume": 1.0
		}
	}

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		save_data = get_default_data()
		save_game()
		return true

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("Impossibile aprire il file di salvataggio: " + SAVE_PATH)
		save_data = get_default_data()
		return false

	var json_str := file.get_as_text()
	file.close()

	var test_json_conv := JSON.new()
	var parse_err := test_json_conv.parse(json_str)
	if parse_err != OK:
		push_error("Errore di parsing JSON nel file di salvataggio: %s (Linea %d)" % [test_json_conv.get_error_message(), test_json_conv.get_error_line()])
		save_data = get_default_data()
		return false

	var loaded_dict: Variant = test_json_conv.data
	if loaded_dict is Dictionary:
		var default_data := get_default_data()
		for key in default_data.keys():
			if not loaded_dict.has(key):
				loaded_dict[key] = default_data[key]
		save_data = loaded_dict
		return true
	else:
		save_data = get_default_data()
		return false

func save_game() -> bool:
	var json_str := JSON.stringify(save_data, "\t")
	var tmp_file := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if not tmp_file:
		push_error("Impossibile creare il file temporaneo di salvataggio: " + SAVE_TMP_PATH)
		return false

	tmp_file.store_string(json_str)
	tmp_file.flush()
	tmp_file.close()

	var dir := DirAccess.open("user://")
	if dir:
		if dir.file_exists(SAVE_PATH):
			dir.remove(SAVE_PATH)
		var rename_err := dir.rename(SAVE_TMP_PATH, SAVE_PATH)
		if rename_err != OK:
			push_error("Errore durante il salvataggio atomico: %d" % rename_err)
			return false
		return true
	return false

func reset_save() -> void:
	save_data = get_default_data()
	save_game()
