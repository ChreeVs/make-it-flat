extends Node3D

@onready var structure_container: Node3D = $StructureHolder
@onready var scenery_root: Node3D = $EnvironmentScenery
@onready var menu_camera_pivot: Node3D = $MenuCameraPivot
@onready var menu_camera: Camera3D = $MenuCameraPivot/MenuCamera
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var player: Player = $Player

var _crane_jib: Node3D = null
var _orbit_angle: float = 0.42

func _ready() -> void:
	GameManager.structure_container = structure_container
	_build_metropolitan_district()
	_apply_visual_settings()

	EventBus.settings_changed.connect(_apply_visual_settings)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)

	_sync_cameras()
	call_deferred("_load_initial_skyscraper")

func _process(delta: float) -> void:
	if is_instance_valid(_crane_jib):
		_crane_jib.rotation.y = sin(Time.get_ticks_msec() * 0.00018) * 0.48

	if GameManager.is_main_menu_open and is_instance_valid(menu_camera_pivot):
		_orbit_angle += delta * 0.16
		menu_camera_pivot.rotation.y = _orbit_angle

func _on_game_state_changed(_state: String) -> void:
	_sync_cameras()

func _on_difficulty_changed(_diff_id: String) -> void:
	_adjust_menu_camera_for_height()

func _adjust_menu_camera_for_height() -> void:
	if not is_instance_valid(menu_camera_pivot) or not is_instance_valid(menu_camera):
		return
	var floors: int = EconomyManager.get_target_skyscraper_floors()
	var mid_y: float = float(floors) * 2.1
	menu_camera_pivot.position = Vector3(0.0, mid_y, 0.0)
	var dist: float = 19.0 + float(floors) * 2.2
	menu_camera.position = Vector3(0.0, 5.0 + float(floors) * 0.6, dist)
	menu_camera.look_at(Vector3(0.0, mid_y, 0.0), Vector3.UP)

func _sync_cameras() -> void:
	if is_instance_valid(menu_camera):
		menu_camera.current = GameManager.is_main_menu_open
	if is_instance_valid(player) and is_instance_valid(player.camera):
		player.camera.current = not GameManager.is_main_menu_open

func _apply_visual_settings() -> void:
	if is_instance_valid(sun_light):
		sun_light.shadow_enabled = bool(SaveManager.settings.get("shadows_enabled", true))
	if is_instance_valid(world_env) and world_env.environment:
		world_env.environment.fog_enabled = bool(SaveManager.settings.get("fog_enabled", true))

func _load_initial_skyscraper() -> void:
	_adjust_menu_camera_for_height()
	await GameManager.load_skyscraper_for_difficulty()

# --- Generatore Ambientazione Metropolitana & Cantiere 3D a 360° ---
func _make_mat(col: Color, rough: float = 0.85, metal: float = 0.0, tex_path: String = "", uv_scale: Vector3 = Vector3.ONE, norm_path: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.uv1_scale = uv_scale
	if tex_path != "" and ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
	if norm_path != "" and ResourceLoader.exists(norm_path):
		m.normal_enabled = true
		m.normal_texture = load(norm_path)
		m.normal_scale = 0.9
	return m

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_OFF
	parent.add_child(mi)
	return mi

func _build_metropolitan_district() -> void:
	if not is_instance_valid(scenery_root):
		return

	var mat_earth := _make_mat(Color(0.26, 0.28, 0.25), 0.96)
	var mat_asphalt := _make_mat(Color(0.86, 0.86, 0.89), 0.90, 0.0, "res://assets/textures/tex_asphalt.png", Vector3(26, 5, 1))
	var mat_paver := _make_mat(Color(0.92, 0.92, 0.94), 0.84, 0.0, "res://assets/textures/tex_sidewalk_paver.png", Vector3(30, 3, 1), "res://assets/textures/tex_sidewalk_paver_n.png")
	var mat_road_line := _make_mat(Color(0.95, 0.82, 0.24), 0.65)
	var mat_white_line := _make_mat(Color(0.94, 0.95, 0.96), 0.72)
	var mat_concrete := _make_mat(Color(0.78, 0.79, 0.81), 0.86, 0.0, "res://assets/textures/tex_mat_concrete.png", Vector3(2, 2, 1))
	var mat_steel := _make_mat(Color(0.84, 0.86, 0.90), 0.34, 0.78, "res://assets/textures/tex_dark_steel.png")
	var mat_crane_yellow := _make_mat(Color(0.96, 0.68, 0.10), 0.40, 0.32)
	var mat_machine_orange := _make_mat(Color(0.92, 0.44, 0.10), 0.42, 0.28)
	var mat_tire := _make_mat(Color(0.11, 0.12, 0.13), 0.94)
	var mat_container_blue := _make_mat(Color(0.82, 0.90, 0.98), 0.54, 0.35, "res://assets/textures/tex_container_metal.png", Vector3(2, 1, 1))
	var mat_container_orange := _make_mat(Color(0.92, 0.42, 0.18), 0.54, 0.30, "res://assets/textures/tex_container_metal.png", Vector3(2, 1, 1))
	var mat_brick := _make_mat(Color(0.92, 0.88, 0.84), 0.86, 0.0, "res://assets/textures/tex_mat_brick_dry.png")
	var mat_hazard := _make_mat(Color(1.0, 1.0, 1.0), 0.48, 0.0, "res://assets/textures/tex_hazard_stripes.png", Vector3(3, 1, 1))
	var mat_glass_cab := _make_mat(Color(0.55, 0.82, 0.95), 0.12, 0.5)

	var mat_lamp := StandardMaterial3D.new()
	mat_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_lamp.albedo_color = Color(1.0, 0.94, 0.76)

	var mat_beacon := StandardMaterial3D.new()
	mat_beacon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_beacon.albedo_color = Color(1.0, 0.20, 0.14)

	# 1. Terreno esteso metropolitano
	_add_box(scenery_root, Vector3(260, 0.4, 260), Vector3(0, -0.25, 0), mat_earth, Vector3.ZERO, false)

	# 2. Viale Urbano a 4 corsie davanti al grattacielo (+Z) + Strada trasversale Est (+X)
	_add_box(scenery_root, Vector3(200, 0.06, 12.0), Vector3(0, 0.01, 24.0), mat_asphalt, Vector3.ZERO, false)
	_add_box(scenery_root, Vector3(11.0, 0.05, 180.0), Vector3(32.0, 0.008, 0.0), mat_asphalt, Vector3.ZERO, false)
	for i in range(-14, 15):
		_add_box(scenery_root, Vector3(3.4, 0.08, 0.24), Vector3(float(i) * 6.5, 0.02, 24.0), mat_road_line, Vector3.ZERO, false)
	# Strisce pedonali
	for s in range(-3, 4):
		_add_box(scenery_root, Vector3(0.65, 0.075, 4.4), Vector3(float(s) * 1.35, 0.02, 24.0), mat_white_line, Vector3.ZERO, false)

	# Marciapiedi in lastricato di granito su entrambi i lati del viale
	_add_box(scenery_root, Vector3(190, 0.20, 3.2), Vector3(0, 0.10, 16.5), mat_paver, Vector3.ZERO, false)
	_add_box(scenery_root, Vector3(190, 0.20, 3.2), Vector3(0, 0.10, 31.5), mat_paver, Vector3.ZERO, false)

	# 3. Barriere Jersey, Lampioni Stradali & 4 Torri Faro Cantiere
	var barrier_coords := [
		[Vector3(-13.8, 0.55, -7.5), Vector3(0, 90, 0)],
		[Vector3(-13.8, 0.55, 7.5), Vector3(0, 90, 0)],
		[Vector3(13.8, 0.55, -7.5), Vector3(0, 90, 0)],
		[Vector3(13.8, 0.55, 7.5), Vector3(0, 90, 0)],
		[Vector3(-7.0, 0.55, -13.8), Vector3.ZERO],
		[Vector3(7.0, 0.55, -13.8), Vector3.ZERO]
	]
	for b in barrier_coords:
		_add_box(scenery_root, Vector3(4.2, 1.1, 0.65), b[0], mat_concrete, b[1])

	for lx in [-24.0, -10.0, 10.0, 24.0]:
		_add_box(scenery_root, Vector3(0.18, 6.4, 0.18), Vector3(lx, 3.2, 17.5), mat_steel)
		_add_box(scenery_root, Vector3(0.16, 0.16, 1.8), Vector3(lx, 6.3, 18.4), mat_steel)
		_add_box(scenery_root, Vector3(0.55, 0.14, 0.85), Vector3(lx, 6.2, 19.1), mat_lamp, Vector3.ZERO, false)

	for fc in [Vector3(-12.6, 0, -12.6), Vector3(12.6, 0, -12.6), Vector3(-12.6, 0, 12.6), Vector3(12.6, 0, 12.6)]:
		_add_box(scenery_root, Vector3(0.26, 9.6, 0.26), fc + Vector3(0, 4.8, 0), mat_steel)
		_add_box(scenery_root, Vector3(1.2, 0.44, 0.44), fc + Vector3(0, 9.7, 0), mat_lamp, Vector3(0, 45, 0), false)

	# 4. Quartier Generale Cantiere (Container impilati) + Escavatore & Camion Ribaltabile parcheggiati!
	_add_box(scenery_root, Vector3(3.2, 2.8, 7.2), Vector3(-20.0, 1.4, 2.5), mat_container_blue, Vector3(0, 8, 0))
	_add_box(scenery_root, Vector3(3.3, 0.25, 7.4), Vector3(-20.0, 2.88, 2.5), mat_steel, Vector3(0, 8, 0))
	_add_box(scenery_root, Vector3(2.9, 2.7, 6.4), Vector3(-20.4, 4.25, 2.5), mat_container_orange, Vector3(0, -4, 0))
	_add_box(scenery_root, Vector3(2.4, 2.6, 2.4), Vector3(17.5, 1.3, 11.8), mat_concrete)
	_add_box(scenery_root, Vector3(4.8, 0.16, 0.16), Vector3(13.8, 1.1, 13.6), mat_hazard)

	# Escavatore Cingolato da Demolizione parcheggiato sul lato destro (+X)
	var exc := Node3D.new()
	exc.position = Vector3(19.5, 0.0, -3.5)
	exc.rotation_degrees = Vector3(0, -32, 0)
	scenery_root.add_child(exc)
	_add_box(exc, Vector3(0.8, 0.85, 4.4), Vector3(-1.3, 0.42, 0), mat_tire)
	_add_box(exc, Vector3(0.8, 0.85, 4.4), Vector3(1.3, 0.42, 0), mat_tire)
	_add_box(exc, Vector3(2.8, 1.3, 3.6), Vector3(0, 1.45, -0.3), mat_crane_yellow)
	_add_box(exc, Vector3(1.2, 1.5, 1.5), Vector3(-0.7, 2.25, 0.5), mat_glass_cab)
	_add_box(exc, Vector3(0.45, 0.55, 4.4), Vector3(0.6, 3.1, 2.2), mat_crane_yellow, Vector3(-32, 0, 0))
	_add_box(exc, Vector3(0.38, 0.42, 3.2), Vector3(0.6, 3.2, 4.8), mat_steel, Vector3(48, 0, 0))

	# Camion Ribaltabile parcheggiato sul lato sinistro del viale
	var truck := Node3D.new()
	truck.position = Vector3(-17.5, 0.0, 21.8)
	truck.rotation_degrees = Vector3(0, 90, 0)
	scenery_root.add_child(truck)
	_add_box(truck, Vector3(2.4, 1.9, 2.1), Vector3(0, 1.45, 2.4), mat_machine_orange)
	_add_box(truck, Vector3(2.1, 0.9, 0.2), Vector3(0, 1.85, 3.42), mat_glass_cab)
	_add_box(truck, Vector3(2.6, 1.8, 4.8), Vector3(0, 1.65, -1.1), mat_steel)
	for wz in [-2.6, -0.6, 2.3]:
		_add_box(truck, Vector3(0.42, 0.95, 0.95), Vector3(-1.25, 0.48, wz), mat_tire)
		_add_box(truck, Vector3(0.42, 0.95, 0.95), Vector3(1.25, 0.48, wz), mat_tire)

	# Pallet di materiali sul cantiere
	_add_box(scenery_root, Vector3(2.2, 1.2, 1.6), Vector3(18.0, 0.6, 4.2), mat_brick)
	_add_box(scenery_root, Vector3(1.4, 0.6, 5.5), Vector3(19.5, 0.3, 8.2), mat_steel, Vector3(0, -6, 0))

	# 5. Grande GRU A TORRE gialla animata sullo sfondo (-X, -Z)
	var crane_base := Node3D.new()
	crane_base.position = Vector3(-25.0, 0.0, -23.0)
	scenery_root.add_child(crane_base)
	_add_box(crane_base, Vector3(3.8, 1.5, 3.8), Vector3(0, 0.75, 0), mat_concrete)
	_add_box(crane_base, Vector3(1.7, 38.0, 1.7), Vector3(0, 19.0, 0), mat_crane_yellow)
	_crane_jib = Node3D.new()
	_crane_jib.position = Vector3(0, 38.2, 0)
	crane_base.add_child(_crane_jib)
	_add_box(_crane_jib, Vector3(2.3, 2.3, 2.3), Vector3(1.5, -0.4, 0), mat_steel)
	_add_box(_crane_jib, Vector3(36.0, 1.3, 1.3), Vector3(11.0, 0.6, 0), mat_crane_yellow)
	_add_box(_crane_jib, Vector3(4.0, 1.9, 2.5), Vector3(-7.4, 0.5, 0), mat_concrete)
	_add_box(_crane_jib, Vector3(0.15, 13.0, 0.15), Vector3(23.0, -6.5, 0), mat_steel, Vector3.ZERO, false)
	_add_box(_crane_jib, Vector3(0.45, 0.45, 0.45), Vector3(0, 2.4, 0), mat_beacon, Vector3.ZERO, false)

	# 6. SKYLINE METROPOLITANO REALISTICO A 360° (Grattacieli con facciate vetrate illuminate + antenne!)
	var mat_city_glass := _make_mat(Color(0.92, 0.95, 1.0), 0.35, 0.35, "res://assets/textures/tex_city_facade.png", Vector3(2, 4, 1))
	var mat_city_warm := _make_mat(Color(0.96, 0.90, 0.84), 0.45, 0.20, "res://assets/textures/tex_city_facade.png", Vector3(2, 3, 1))
	var mat_city_dark := _make_mat(Color(0.76, 0.82, 0.90), 0.30, 0.45, "res://assets/textures/tex_city_facade.png", Vector3(3, 5, 1))
	var mat_hill := _make_mat(Color(0.24, 0.34, 0.24), 0.96)
	var mat_foliage := _make_mat(Color(0.19, 0.42, 0.22), 0.90)
	var mat_trunk := _make_mat(Color(0.34, 0.23, 0.15), 0.94)

	var skyline := [
		[Vector3(-54, 0, -52), Vector3(16, 36, 14), mat_city_glass],
		[Vector3(-32, 0, -58), Vector3(14, 52, 14), mat_city_dark],
		[Vector3(-12, 0, -56), Vector3(16, 28, 14), mat_city_warm],
		[Vector3(10, 0, -60), Vector3(16, 62, 16), mat_city_dark],
		[Vector3(32, 0, -54), Vector3(16, 40, 14), mat_city_glass],
		[Vector3(54, 0, -48), Vector3(15, 30, 14), mat_city_warm],
		[Vector3(-52, 0, -18), Vector3(16, 26, 18), mat_city_warm],
		[Vector3(-54, 0, 10), Vector3(16, 42, 16), mat_city_glass],
		[Vector3(-50, 0, 42), Vector3(16, 24, 14), mat_city_dark],
		[Vector3(52, 0, -16), Vector3(16, 24, 22), mat_city_warm],
		[Vector3(54, 0, 12), Vector3(16, 46, 16), mat_city_dark],
		[Vector3(50, 0, 44), Vector3(18, 28, 14), mat_city_glass],
		[Vector3(-28, 0, 54), Vector3(18, 26, 14), mat_city_warm],
		[Vector3(4, 0, 58), Vector3(20, 38, 16), mat_city_glass],
		[Vector3(32, 0, 56), Vector3(16, 44, 14), mat_city_dark]
	]
	for b in skyline:
		var pos: Vector3 = b[0]
		var sz: Vector3 = b[1]
		var bm_mat: Material = b[2]
		_add_box(scenery_root, sz, Vector3(pos.x, sz.y * 0.5, pos.z), bm_mat, Vector3.ZERO, false)
		# Coronamento tecnico sul tetto + antenna con luce rossa di segnalazione aerea
		_add_box(scenery_root, Vector3(sz.x * 0.55, 2.6, sz.z * 0.55), Vector3(pos.x, sz.y + 1.3, pos.z), mat_concrete, Vector3.ZERO, false)
		if sz.y >= 38.0:
			_add_box(scenery_root, Vector3(0.24, 7.5, 0.24), Vector3(pos.x, sz.y + 6.2, pos.z), mat_steel, Vector3.ZERO, false)
			_add_box(scenery_root, Vector3(0.6, 0.6, 0.6), Vector3(pos.x, sz.y + 10.1, pos.z), mat_beacon, Vector3.ZERO, false)

	# Colline morbide all'orizzonte lontano
	for h in [
		[Vector3(-98, 7, -98), Vector3(76, 16, 44)],
		[Vector3(0, 9, -110), Vector3(96, 20, 40)],
		[Vector3(98, 8, -92), Vector3(72, 18, 48)],
		[Vector3(-104, 6, 20), Vector3(40, 14, 92)],
		[Vector3(104, 7, 18), Vector3(42, 16, 92)]
	]:
		_add_box(scenery_root, h[1], h[0], mat_hill, Vector3(0, 12, 0), false)

	# Viale alberato con fioriere urbane
	for tx in [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]:
		_add_box(scenery_root, Vector3(1.5, 0.55, 1.5), Vector3(tx, 0.28, 31.8), mat_concrete, Vector3.ZERO, false)
		_add_box(scenery_root, Vector3(0.42, 3.0, 0.42), Vector3(tx, 1.8, 31.8), mat_trunk, Vector3.ZERO, false)
		_add_box(scenery_root, Vector3(3.0, 3.0, 3.0), Vector3(tx, 4.1, 31.8), mat_foliage, Vector3(0, 22, 0), false)
