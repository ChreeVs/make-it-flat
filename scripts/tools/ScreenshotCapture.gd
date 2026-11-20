extends Node

# Strumento di sviluppo: carica MainGame, inquadra il cantiere da alcuni punti di vista e salva PNG.
# Uso (finestra visibile, serve il renderer):
#   Godot --path . res://scenes/tools/ScreenshotCapture.tscn -- --test-mode --out=C:/percorso/cartella [--contract=tier5_skyscraper]

const SHOTS: Array[Dictionary] = [
	{"name": "01_overview", "pos": Vector3(14.0, 9.0, 22.0), "look": Vector3(0.0, 6.0, 0.0)},
	{"name": "02_street", "pos": Vector3(-3.0, 1.6, 12.0), "look": Vector3(0.0, 3.0, 0.0)},
	{"name": "03_closeup", "pos": Vector3(2.5, 1.6, 7.5), "look": Vector3(0.0, 1.8, 3.0)},
	{"name": "04_interior", "pos": Vector3(1.0, 1.5, 1.0), "look": Vector3(-3.0, 1.2, -2.0)}
]

func _ready() -> void:
	call_deferred("_run")

func _get_arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return fallback

func _run() -> void:
	var out_dir: String = _get_arg("out", ProjectSettings.globalize_path("user://screenshots"))
	DirAccess.make_dir_recursive_absolute(out_dir)

	var game: Node3D = (load("res://scenes/MainGame.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in range(10):
		await get_tree().process_frame

	var diff: String = _get_arg("difficulty", "")
	if diff != "":
		EconomyManager.set_difficulty(diff)
		await GameManager.load_skyscraper_for_difficulty()

	var contract_id: String = _get_arg("contract", "")
	if contract_id != "":
		var c: ContractData = load("res://data/contracts/%s.tres" % contract_id)
		await GameManager.load_contract(c)

	# Chiude il menu principale e nasconde la UI per avere inquadrature pulite
	GameManager.is_main_menu_open = false
	var ui := game.find_child("UILayer", true, false) as CanvasLayer
	if ui:
		ui.visible = false

	var cam := Camera3D.new()
	cam.fov = 70.0
	game.add_child(cam)
	cam.current = true

	for shot in SHOTS:
		cam.global_position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)
		for i in range(int(_get_arg("settle", "12"))):
			await get_tree().process_frame
		var t0: int = Time.get_ticks_usec()
		var n_frames: int = int(_get_arg("measure", "0"))
		for i in range(n_frames):
			await get_tree().process_frame
		var avg_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(float(n_frames), 1.0)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = out_dir.path_join("%s.png" % shot["name"])
		img.save_png(path)
		print("Screenshot salvato: ", path)
		print("  perf %s: %.1f ms/frame (%.0f FPS) | draw call %d | primitive %d" % [shot["name"], avg_ms, 1000.0 / maxf(avg_ms, 0.01),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])

	if _get_arg("fp", "1") == "1":
		await _capture_first_person(game, cam, out_dir)

	get_tree().quit(0)

func _snap(out_dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join("%s.png" % shot_name)
	img.save_png(path)
	print("Screenshot salvato: ", path)

# Vista in prima persona con ogni strumento + danni/crepe/polvere su un pilastro
func _capture_first_person(game: Node3D, overview_cam: Camera3D, out_dir: String) -> void:
	var player := game.find_child("Player", true, false) as Player
	if not player:
		return
	overview_cam.current = false
	player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.global_position = Vector3(1.6, 0.05, 6.2)
	player.rotation = Vector3(0, deg_to_rad(12.0), 0)
	player.head.rotation = Vector3(deg_to_rad(-4.0), 0, 0)
	for tid in EconomyManager.TOOL_ORDER:
		EconomyManager.unlock_tool(tid)
	for tid in [&"crowbar", &"hammer", &"sledgehammer_3kg", &"sledgehammer_8kg", &"electric_demolisher", &"c4_charge"]:
		EconomyManager.equip_tool(tid)
		for i in range(10):
			await get_tree().process_frame
		await _snap(out_dir, "fp_%s" % String(tid))

	# Danni progressivi su blocchi vicini: crepe procedurali, polvere, schegge
	var sm := GameManager.current_structure as StructureManager
	if sm:
		var near: Array[DestructibleBlock] = sm.get_intact_blocks_in_radius(player.global_position + Vector3(0, 1.2, -3.0), 3.2)
		var k: int = 0
		for b in near:
			if b.is_anchored:
				continue
			b.take_damage(b.max_hp * (0.35 + 0.15 * float(k % 4)), 9, b.global_position, Vector3.BACK)
			k += 1
		for i in range(6):
			await get_tree().process_frame
		await _snap(out_dir, "fp_damage")
		var broken: int = 0
		for b in near:
			if is_instance_valid(b) and not b.is_destroyed and not b.is_anchored and broken < 4:
				b.take_damage(999999.0, 9, b.global_position, Vector3.BACK)
				broken += 1
		for i in range(8):
			await get_tree().process_frame
		await _snap(out_dir, "fp_shatter")
