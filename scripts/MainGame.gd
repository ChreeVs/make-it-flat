extends Node3D

@onready var structure_container: Node3D = $StructureHolder
@onready var scenery_root: Node3D = $EnvironmentScenery
@onready var menu_camera_pivot: Node3D = $MenuCameraPivot
@onready var menu_camera: Camera3D = $MenuCameraPivot/MenuCamera
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var player: Player = $Player

var _crane_jib: Node3D = null
var _orbit_angle: float = 0.45

func _ready() -> void:
	GameManager.structure_container = structure_container
	_build_industrial_district()
	_apply_visual_settings()

	EventBus.settings_changed.connect(_apply_visual_settings)
	EventBus.game_state_changed.connect(_on_game_state_changed)

	_sync_cameras()
	call_deferred("_load_initial_contract")

func _process(delta: float) -> void:
	if is_instance_valid(_crane_jib):
		_crane_jib.rotation.y = sin(Time.get_ticks_msec() * 0.00018) * 0.45

	if GameManager.is_main_menu_open and is_instance_valid(menu_camera_pivot):
		_orbit_angle += delta * 0.18
		menu_camera_pivot.rotation.y = _orbit_angle

func _on_game_state_changed(_state: String) -> void:
	_sync_cameras()

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

func _load_initial_contract() -> void:
	var start_path := "res://data/contracts/tier1_fence.tres"
	if not ResourceLoader.exists(start_path):
		start_path = "res://data/contracts/tier1_wall.tres"
	if ResourceLoader.exists(start_path):
		var contract: ContractData = load(start_path)
		if contract:
			GameManager.load_contract(contract)

# --- Generatore Ambientazione Urbana & Industriale 3D di Sfondo ---
func _make_mat(col: Color, rough: float = 0.85, metal: float = 0.0, tex_path: String = "", uv_scale: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.uv1_scale = uv_scale
	if tex_path != "" and ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
	return m

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_industrial_district() -> void:
	if not is_instance_valid(scenery_root):
		return

	var mat_earth := _make_mat(Color(0.32, 0.30, 0.25), 0.96)
	var mat_asphalt := _make_mat(Color(0.85, 0.85, 0.88), 0.90, 0.0, "res://assets/textures/tex_asphalt.png", Vector3(24, 4, 1))
	var mat_road_line := _make_mat(Color(0.94, 0.82, 0.25), 0.65)
	var mat_concrete := _make_mat(Color(0.76, 0.77, 0.78), 0.88, 0.0, "res://assets/textures/tex_mat_concrete.png", Vector3(2, 2, 1))
	var mat_steel := _make_mat(Color(0.82, 0.85, 0.90), 0.38, 0.72, "res://assets/textures/tex_dark_steel.png")
	var mat_crane_yellow := _make_mat(Color(0.95, 0.68, 0.10), 0.42, 0.35)
	var mat_container := _make_mat(Color(0.92, 0.94, 0.96), 0.55, 0.35, "res://assets/textures/tex_container_metal.png", Vector3(2, 1, 1))
	var mat_container_orange := _make_mat(Color(0.86, 0.36, 0.14), 0.55, 0.30, "res://assets/textures/tex_container_metal.png", Vector3(2, 1, 1))
	var mat_brick := _make_mat(Color(0.92, 0.88, 0.84), 0.86, 0.0, "res://assets/textures/tex_mat_brick_dry.png")
	var mat_hazard := _make_mat(Color(1.0, 1.0, 1.0), 0.5, 0.0, "res://assets/textures/tex_hazard_stripes.png", Vector3(3, 1, 1))
	var mat_lamp := StandardMaterial3D.new()
	mat_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_lamp.albedo_color = Color(1.0, 0.94, 0.76)

	# 1. Terreno circostante esteso (sotto il piazzale)
	_add_box(scenery_root, Vector3(220, 0.4, 220), Vector3(0, -0.25, 0), mat_earth, Vector3.ZERO, false)

	# 2. Strada asfaltata davanti al cantiere (+Z) + corsia trasversale
	_add_box(scenery_root, Vector3(160, 0.06, 9.5), Vector3(0, 0.01, 20.5), mat_asphalt, Vector3.ZERO, false)
	for i in range(-12, 13):
		_add_box(scenery_root, Vector3(3.2, 0.08, 0.22), Vector3(float(i) * 6.5, 0.02, 20.5), mat_road_line, Vector3.ZERO, false)
	# Marciapiede in cemento
	_add_box(scenery_root, Vector3(160, 0.18, 2.2), Vector3(0, 0.09, 14.8), mat_concrete, Vector3.ZERO, false)

	# 3. Barriere Jersey e 4 torri faro agli angoli del piazzale
	var barrier_coords := [
		[Vector3(-12.6, 0.55, -7.0), Vector3(0, 90, 0)],
		[Vector3(-12.6, 0.55, 7.0), Vector3(0, 90, 0)],
		[Vector3(12.6, 0.55, -7.0), Vector3(0, 90, 0)],
		[Vector3(12.6, 0.55, 7.0), Vector3(0, 90, 0)],
		[Vector3(-6.5, 0.55, -12.6), Vector3.ZERO],
		[Vector3(6.5, 0.55, -12.6), Vector3.ZERO]
	]
	for b in barrier_coords:
		_add_box(scenery_root, Vector3(3.8, 1.1, 0.65), b[0], mat_concrete, b[1])

	var flood_corners := [
		Vector3(-11.8, 0, -11.8), Vector3(11.8, 0, -11.8),
		Vector3(-11.8, 0, 11.8), Vector3(11.8, 0, 11.8)
	]
	for fc in flood_corners:
		_add_box(scenery_root, Vector3(0.24, 9.0, 0.24), fc + Vector3(0, 4.5, 0), mat_steel)
		_add_box(scenery_root, Vector3(1.1, 0.42, 0.42), fc + Vector3(0, 9.1, 0), mat_lamp, Vector3(0, 45, 0), false)

	# 4. Container Ufficio di Cantiere (sinistra) + Magazzino Attrezzi (destra) + Pallet di mattoni
	_add_box(scenery_root, Vector3(3.0, 2.8, 6.8), Vector3(-18.5, 1.4, 3.0), mat_container, Vector3(0, 8, 0))
	_add_box(scenery_root, Vector3(3.1, 0.25, 7.0), Vector3(-18.5, 2.88, 3.0), mat_steel, Vector3(0, 8, 0))
	_add_box(scenery_root, Vector3(2.8, 2.7, 6.2), Vector3(-19.0, 4.25, 3.0), mat_container_orange, Vector3(0, -4, 0))
	# Cabina ingresso + sbarra gialla/nera
	_add_box(scenery_root, Vector3(2.4, 2.6, 2.4), Vector3(16.5, 1.3, 11.0), mat_concrete)
	_add_box(scenery_root, Vector3(4.5, 0.16, 0.16), Vector3(12.8, 1.1, 13.0), mat_hazard)
	# Pallet di mattoni e travi stoccate sul lato destro
	_add_box(scenery_root, Vector3(2.2, 1.2, 1.6), Vector3(16.8, 0.6, -2.5), mat_brick)
	_add_box(scenery_root, Vector3(2.0, 1.0, 1.6), Vector3(17.2, 0.5, -5.2), mat_brick, Vector3(0, 14, 0))
	_add_box(scenery_root, Vector3(1.4, 0.6, 5.5), Vector3(18.0, 0.3, 3.2), mat_steel, Vector3(0, -6, 0))

	# 5. Grande GRU A TORRE gialla sullo sfondo (-X, -Z)
	var crane_base := Node3D.new()
	crane_base.position = Vector3(-24.0, 0.0, -22.0)
	scenery_root.add_child(crane_base)
	_add_box(crane_base, Vector3(3.6, 1.4, 3.6), Vector3(0, 0.7, 0), mat_concrete)
	_add_box(crane_base, Vector3(1.6, 30.0, 1.6), Vector3(0, 15.0, 0), mat_crane_yellow)
	_crane_jib = Node3D.new()
	_crane_jib.position = Vector3(0, 30.2, 0)
	crane_base.add_child(_crane_jib)
	_add_box(_crane_jib, Vector3(2.2, 2.2, 2.2), Vector3(1.4, -0.4, 0), mat_steel) # Cabina operatore
	_add_box(_crane_jib, Vector3(32.0, 1.2, 1.2), Vector3(9.5, 0.6, 0), mat_crane_yellow) # Braccio
	_add_box(_crane_jib, Vector3(3.6, 1.8, 2.4), Vector3(-6.8, 0.5, 0), mat_concrete) # Contrappeso
	_add_box(_crane_jib, Vector3(0.14, 11.0, 0.14), Vector3(20.0, -5.5, 0), mat_steel, Vector3.ZERO, false) # Cavo gancio

	# 6. Skyline Urbano & Distretto Industriale a 360° (edifici distanti + serbatoi + ciminiere)
	var mat_city_a := _make_mat(Color(0.32, 0.35, 0.40), 0.82)
	var mat_city_b := _make_mat(Color(0.42, 0.40, 0.38), 0.86)
	var mat_city_c := _make_mat(Color(0.25, 0.30, 0.36), 0.76, 0.15)
	var mat_win_glow := StandardMaterial3D.new()
	mat_win_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_win_glow.albedo_color = Color(0.95, 0.85, 0.60)
	var mat_hill := _make_mat(Color(0.26, 0.34, 0.24), 0.96)
	var mat_foliage := _make_mat(Color(0.20, 0.38, 0.22), 0.92)
	var mat_trunk := _make_mat(Color(0.34, 0.24, 0.16), 0.94)

	var skyline := [
		# Sfondo Nord (-Z)
		[Vector3(-48, 0, -48), Vector3(14, 24, 12), mat_city_a],
		[Vector3(-30, 0, -54), Vector3(12, 34, 14), mat_city_c],
		[Vector3(-12, 0, -52), Vector3(15, 20, 12), mat_city_b],
		[Vector3(8, 0, -56), Vector3(14, 42, 14), mat_city_c],
		[Vector3(28, 0, -50), Vector3(16, 28, 12), mat_city_a],
		[Vector3(48, 0, -46), Vector3(14, 22, 14), mat_city_b],
		# Lato Ovest (-X)
		[Vector3(-46, 0, -18), Vector3(14, 18, 18), mat_city_b],
		[Vector3(-50, 0, 8), Vector3(16, 26, 16), mat_city_a],
		[Vector3(-46, 0, 36), Vector3(14, 16, 14), mat_city_c],
		# Lato Est (+X)
		[Vector3(44, 0, -16), Vector3(16, 15, 22), mat_city_b],
		[Vector3(48, 0, 10), Vector3(14, 28, 14), mat_city_c],
		[Vector3(44, 0, 38), Vector3(18, 19, 14), mat_city_a],
		# Lato Sud oltre la strada (+Z)
		[Vector3(-24, 0, 48), Vector3(18, 16, 12), mat_city_b],
		[Vector3(4, 0, 52), Vector3(20, 22, 14), mat_city_a],
		[Vector3(30, 0, 50), Vector3(14, 30, 12), mat_city_c]
	]
	for b in skyline:
		var pos: Vector3 = b[0]
		var sz: Vector3 = b[1]
		var bm_mat: Material = b[2]
		_add_box(scenery_root, sz, Vector3(pos.x, sz.y * 0.5, pos.z), bm_mat, Vector3.ZERO, false)
		# Fascia luminosa sul coronamento per profondità urbana
		_add_box(scenery_root, Vector3(sz.x * 0.82, 0.55, sz.z * 0.82), Vector3(pos.x, sz.y - 2.2, pos.z), mat_win_glow, Vector3.ZERO, false)

	# Colline morbide all'orizzonte lontano
	var hills := [
		[Vector3(-85, 6, -85), Vector3(68, 14, 40)],
		[Vector3(0, 8, -95), Vector3(88, 18, 36)],
		[Vector3(85, 7, -80), Vector3(65, 16, 45)],
		[Vector3(-92, 5, 20), Vector3(36, 12, 85)],
		[Vector3(92, 6, 18), Vector3(38, 14, 85)]
	]
	for h in hills:
		_add_box(scenery_root, h[1], h[0], mat_hill, Vector3(0, 12, 0), false)

	# Alberi lungo il viale davanti al cantiere
	for tx in [-26.0, -16.0, 16.0, 26.0, 34.0]:
		_add_box(scenery_root, Vector3(0.45, 2.8, 0.45), Vector3(tx, 1.4, 27.2), mat_trunk, Vector3.ZERO, false)
		_add_box(scenery_root, Vector3(2.8, 2.8, 2.8), Vector3(tx, 3.6, 27.2), mat_foliage, Vector3(0, 22, 0), false)
