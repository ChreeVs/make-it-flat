class_name DestructibleBlock
extends RigidBody3D

enum BlockShape {
	FULL_CUBE,
	PILLAR,
	WALL_X,
	WALL_Z,
	SLAB,
	SLAB_BOTTOM,
	BEAM_X,
	BEAM_Z,
	STAIR_NORTH,
	STAIR_SOUTH,
	STAIR_EAST,
	STAIR_WEST,
	ROOF_SLOPE_N,
	ROOF_SLOPE_S,
	WINDOW_X,
	WINDOW_Z,
	DOOR_LINTEL_X,
	DOOR_LINTEL_Z,
	FENCE_POST,
	FENCE_PANEL_X,
	# Arredi interni dettagliati per Grattacielo (uffici, appartamenti, bagni, bar, sala server, tetto)
	FURN_DESK,
	FURN_CHAIR,
	FURN_SOFA,
	FURN_TABLE,
	FURN_BAR_COUNTER,
	FURN_BAR_STOOL,
	FURN_TOILET,
	FURN_SINK,
	FURN_BATHTUB,
	FURN_BED,
	FURN_BOOKSHELF,
	FURN_KITCHEN_COUNTER,
	FURN_FRIDGE,
	FURN_SERVER_RACK,
	FURN_PLANT,
	FURN_TV_STAND,
	FURN_HVAC_UNIT
}

@export var material_data: MaterialData
@export var is_anchored: bool = false
@export var grid_coord: Vector3i = Vector3i.ZERO
@export var block_shape: BlockShape = BlockShape.FULL_CUBE
@export var custom_display_name: String = ""
@export var floor_index: int = -1
@export var prop_yaw_deg: float = 0.0

var max_hp: float = 100.0
var current_hp: float = 100.0
var is_destroyed: bool = false
var _crack_stage: int = 0
var _xray_enabled: bool = false
var _instance_material: StandardMaterial3D = null
var _visual_meshes: Array[MeshInstance3D] = []

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Risorse statiche condivise + budget VFX per frame (zero lag durante esplosioni C4)
static var _base_material_cache: Dictionary = {}
static var _accent_materials: Dictionary = {}
static var _crack_materials: Array[StandardMaterial3D] = []
static var _xray_material: ShaderMaterial = null
static var _glass_material: StandardMaterial3D = null
static var _roof_material: StandardMaterial3D = null
static var _shard_mesh: BoxMesh = null
static var _particle_mesh: BoxMesh = null
static var _last_fx_frame: int = -1
static var _frame_particle_count: int = 0
static var _frame_shard_count: int = 0

func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	_ensure_shared_resources()
	_apply_material_properties()
	_build_architectural_geometry()

static func _ensure_shared_resources() -> void:
	if _crack_materials.is_empty():
		var paths := [
			"res://assets/textures/tex_cracks_stage1.png",
			"res://assets/textures/tex_cracks_stage2.png",
			"res://assets/textures/tex_cracks_stage3.png"
		]
		for p in paths:
			var cm := StandardMaterial3D.new()
			cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cm.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
			cm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			cm.uv1_triplanar = true
			if ResourceLoader.exists(p):
				cm.albedo_texture = load(p)
			_crack_materials.append(cm)

	if _xray_material == null:
		var sh_path := "res://assets/shaders/block_xray_outline.gdshader"
		if ResourceLoader.exists(sh_path):
			_xray_material = ShaderMaterial.new()
			_xray_material.shader = load(sh_path)

	if _glass_material == null:
		_glass_material = StandardMaterial3D.new()
		_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_material.albedo_color = Color(0.84, 0.95, 1.0, 0.72)
		_glass_material.roughness = 0.10
		_glass_material.metallic = 0.32
		if ResourceLoader.exists("res://assets/textures/tex_mat_curtain_glass.png"):
			_glass_material.albedo_texture = load("res://assets/textures/tex_mat_curtain_glass.png")
		elif ResourceLoader.exists("res://assets/textures/tex_mat_glass.png"):
			_glass_material.albedo_texture = load("res://assets/textures/tex_mat_glass.png")

	if _roof_material == null:
		_roof_material = StandardMaterial3D.new()
		_roof_material.albedo_color = Color(0.95, 0.92, 0.88, 1.0)
		_roof_material.roughness = 0.84
		if ResourceLoader.exists("res://assets/textures/tex_roof_tiles.png"):
			_roof_material.albedo_texture = load("res://assets/textures/tex_roof_tiles.png")

	if _accent_materials.is_empty():
		_accent_materials["dark_metal"] = _make_simple_mat(Color(0.18, 0.20, 0.24), 0.35, 0.80)
		_accent_materials["chrome"] = _make_simple_mat(Color(0.84, 0.87, 0.90), 0.16, 0.95)
		_accent_materials["brass"] = _make_simple_mat(Color(0.86, 0.68, 0.24), 0.25, 0.85)
		_accent_materials["porcelain"] = _make_simple_mat(Color(0.96, 0.97, 0.99), 0.14, 0.05)
		_accent_materials["cushion_red"] = _make_simple_mat(Color(0.74, 0.20, 0.20), 0.88, 0.0)
		_accent_materials["cushion_navy"] = _make_simple_mat(Color(0.18, 0.28, 0.48), 0.88, 0.0)
		_accent_materials["cushion_cream"] = _make_simple_mat(Color(0.93, 0.91, 0.85), 0.90, 0.0)
		_accent_materials["foliage"] = _make_simple_mat(Color(0.18, 0.52, 0.22), 0.82, 0.0)
		_accent_materials["soil"] = _make_simple_mat(Color(0.28, 0.19, 0.12), 0.96, 0.0)
		_accent_materials["terracotta"] = _make_simple_mat(Color(0.74, 0.38, 0.22), 0.78, 0.0)
		_accent_materials["screen_on"] = _make_emissive_mat(Color(0.25, 0.68, 0.95), 0.9)
		_accent_materials["led_green"] = _make_emissive_mat(Color(0.22, 0.96, 0.45), 1.4)
		_accent_materials["bottle_amber"] = _make_simple_mat(Color(0.86, 0.46, 0.12), 0.15, 0.1)
		_accent_materials["bottle_green"] = _make_simple_mat(Color(0.18, 0.64, 0.28), 0.15, 0.1)
		_accent_materials["book_blue"] = _make_simple_mat(Color(0.20, 0.38, 0.74), 0.82, 0.0)
		_accent_materials["book_gold"] = _make_simple_mat(Color(0.84, 0.62, 0.18), 0.82, 0.0)
		_accent_materials["mirror"] = _make_simple_mat(Color(0.78, 0.88, 0.95), 0.05, 0.92)
		_accent_materials["granite"] = _make_simple_mat(Color(0.32, 0.34, 0.38), 0.28, 0.12)

	if _shard_mesh == null:
		_shard_mesh = BoxMesh.new()
		_shard_mesh.size = Vector3(0.22, 0.22, 0.22)

	if _particle_mesh == null:
		_particle_mesh = BoxMesh.new()
		_particle_mesh.size = Vector3(0.09, 0.09, 0.09)

static func _make_simple_mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

static func _make_emissive_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.2
	return m

func _get_or_create_base_material(mat_data: MaterialData) -> StandardMaterial3D:
	if block_shape == BlockShape.WINDOW_X or block_shape == BlockShape.WINDOW_Z:
		return _glass_material
	if block_shape == BlockShape.ROOF_SLOPE_N or block_shape == BlockShape.ROOF_SLOPE_S:
		return _roof_material

	var key: StringName = mat_data.material_id
	if _base_material_cache.has(key):
		return _base_material_cache[key] as StandardMaterial3D

	var std := StandardMaterial3D.new()
	std.albedo_color = mat_data.color
	std.roughness = mat_data.roughness
	std.metallic = mat_data.metallic
	std.uv1_scale = mat_data.uv_scale
	if mat_data.albedo_texture:
		std.albedo_texture = mat_data.albedo_texture
	if mat_data.normal_texture:
		std.normal_enabled = true
		std.normal_texture = mat_data.normal_texture
		std.normal_scale = 1.15
	_base_material_cache[key] = std
	return std

func _apply_material_properties() -> void:
	if not material_data:
		material_data = load("res://data/materials/wood_rotten.tres")
	if not material_data:
		return

	var diff_hp: float = EconomyManager.get_difficulty_hp_multiplier()
	max_hp = material_data.max_hp * diff_hp
	if block_shape == BlockShape.WINDOW_X or block_shape == BlockShape.WINDOW_Z:
		max_hp = minf(max_hp * 0.25, 32.0)
	current_hp = max_hp
	mass = maxf(material_data.mass_kg, 1.0)

func _add_sub_box(size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, override_mat: Material = null, parent_node: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	var base_mat: Material = override_mat if override_mat != null else _get_or_create_base_material(material_data)
	mi.set_surface_override_material(0, base_mat)
	if parent_node != null:
		parent_node.add_child(mi)
	else:
		add_child(mi)
	_visual_meshes.append(mi)
	return mi

func _set_box_collision(size: Vector3, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> void:
	if not collision_shape:
		return
	var bs := BoxShape3D.new()
	bs.size = size
	collision_shape.shape = bs
	collision_shape.position = pos
	collision_shape.rotation_degrees = rot_deg

func _build_architectural_geometry() -> void:
	_visual_meshes.clear()
	var base_mat: StandardMaterial3D = _get_or_create_base_material(material_data)

	if block_shape == BlockShape.FULL_CUBE:
		if mesh_instance:
			mesh_instance.visible = true
			mesh_instance.set_surface_override_material(0, base_mat)
			_visual_meshes.append(mesh_instance)
		return

	if mesh_instance:
		mesh_instance.visible = false

	match block_shape:
		BlockShape.PILLAR:
			_add_sub_box(Vector3(0.58, 0.84, 0.58), Vector3(0, 0, 0), Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(0.76, 0.12, 0.76), Vector3(0, -0.44, 0), Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(0.76, 0.12, 0.76), Vector3(0, 0.44, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.70, 1.0, 0.70), Vector3.ZERO)

		BlockShape.WALL_X:
			_add_sub_box(Vector3(1.0, 1.0, 0.30), Vector3.ZERO, Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(1.0, 0.10, 0.36), Vector3(0, -0.45, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 1.0, 0.32), Vector3.ZERO)

		BlockShape.WALL_Z:
			_add_sub_box(Vector3(0.30, 1.0, 1.0), Vector3.ZERO, Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(0.36, 0.10, 1.0), Vector3(0, -0.45, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.32, 1.0, 1.0), Vector3.ZERO)

		BlockShape.SLAB:
			_add_sub_box(Vector3(1.0, 0.28, 1.0), Vector3(0, 0.36, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.28, 1.0), Vector3(0, 0.36, 0))

		BlockShape.SLAB_BOTTOM:
			_add_sub_box(Vector3(1.0, 0.26, 1.0), Vector3(0, -0.37, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.26, 1.0), Vector3(0, -0.37, 0))

		BlockShape.BEAM_X:
			_add_sub_box(Vector3(1.0, 0.36, 0.36), Vector3(0, 0.32, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.36, 0.36), Vector3(0, 0.32, 0))

		BlockShape.BEAM_Z:
			_add_sub_box(Vector3(0.36, 0.36, 1.0), Vector3(0, 0.32, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.36, 0.36, 1.0), Vector3(0, 0.32, 0))

		BlockShape.STAIR_NORTH, BlockShape.STAIR_SOUTH, BlockShape.STAIR_EAST, BlockShape.STAIR_WEST:
			_build_stair_geometry(base_mat)

		BlockShape.ROOF_SLOPE_N:
			_add_sub_box(Vector3(1.02, 0.20, 1.38), Vector3(0, 0.0, 0), Vector3(35.0, 0, 0), _roof_material)
			_set_box_collision(Vector3(1.0, 0.22, 1.35), Vector3(0, 0.0, 0), Vector3(35.0, 0, 0))

		BlockShape.ROOF_SLOPE_S:
			_add_sub_box(Vector3(1.02, 0.20, 1.38), Vector3(0, 0.0, 0), Vector3(-35.0, 0, 0), _roof_material)
			_set_box_collision(Vector3(1.0, 0.22, 1.35), Vector3(0, 0.0, 0), Vector3(-35.0, 0, 0))

		BlockShape.WINDOW_X:
			var frame_mat: StandardMaterial3D = _accent_materials["dark_metal"]
			_add_sub_box(Vector3(1.0, 0.10, 0.24), Vector3(0, -0.45, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(1.0, 0.10, 0.24), Vector3(0, 0.45, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.08, 0.82, 0.20), Vector3(-0.46, 0, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.08, 0.82, 0.20), Vector3(0.46, 0, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.86, 0.82, 0.08), Vector3.ZERO, Vector3.ZERO, _glass_material)
			_set_box_collision(Vector3(1.0, 1.0, 0.24), Vector3.ZERO)

		BlockShape.WINDOW_Z:
			var frame_mat: StandardMaterial3D = _accent_materials["dark_metal"]
			_add_sub_box(Vector3(0.24, 0.10, 1.0), Vector3(0, -0.45, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.24, 0.10, 1.0), Vector3(0, 0.45, 0), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.20, 0.82, 0.08), Vector3(0, 0, -0.46), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.20, 0.82, 0.08), Vector3(0, 0, 0.46), Vector3.ZERO, frame_mat)
			_add_sub_box(Vector3(0.08, 0.82, 0.86), Vector3.ZERO, Vector3.ZERO, _glass_material)
			_set_box_collision(Vector3(0.24, 1.0, 1.0), Vector3.ZERO)

		BlockShape.DOOR_LINTEL_X:
			_add_sub_box(Vector3(1.0, 0.34, 0.34), Vector3(0, 0.33, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.34, 0.34), Vector3(0, 0.33, 0))

		BlockShape.DOOR_LINTEL_Z:
			_add_sub_box(Vector3(0.34, 0.34, 1.0), Vector3(0, 0.33, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.34, 0.34, 1.0), Vector3(0, 0.33, 0))

		BlockShape.FENCE_POST:
			_add_sub_box(Vector3(0.26, 1.0, 0.26), Vector3.ZERO, Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(0.34, 0.10, 0.34), Vector3(0, 0.47, 0), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(0.30, 1.0, 0.30), Vector3.ZERO)

		BlockShape.FENCE_PANEL_X:
			_add_sub_box(Vector3(1.0, 0.11, 0.12), Vector3(0, 0.26, 0), Vector3.ZERO, base_mat)
			_add_sub_box(Vector3(1.0, 0.11, 0.12), Vector3(0, -0.26, 0), Vector3.ZERO, base_mat)
			for i in range(4):
				var px: float = -0.36 + float(i) * 0.24
				_add_sub_box(Vector3(0.16, 0.96, 0.08), Vector3(px, 0.0, 0.06), Vector3.ZERO, base_mat)
			_set_box_collision(Vector3(1.0, 0.98, 0.20), Vector3.ZERO)

		_:
			_build_furniture_geometry(base_mat)

func _build_furniture_geometry(base_mat: StandardMaterial3D) -> void:
	var pivot := Node3D.new()
	pivot.rotation_degrees = Vector3(0.0, prop_yaw_deg, 0.0)
	add_child(pivot)

	var metal: Material = _accent_materials["dark_metal"]
	var chrome: Material = _accent_materials["chrome"]
	var brass: Material = _accent_materials["brass"]
	var porc: Material = _accent_materials["porcelain"]

	match block_shape:
		BlockShape.FURN_DESK:
			# Scrivania direzionale/ufficio con monitor acceso e tastiera
			_add_sub_box(Vector3(0.94, 0.08, 0.72), Vector3(0, 0.10, 0), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.07, 0.58, 0.64), Vector3(-0.42, -0.21, 0), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.28, 0.56, 0.62), Vector3(0.31, -0.22, 0), Vector3.ZERO, base_mat, pivot)
			# Monitor + supporto + tastiera
			_add_sub_box(Vector3(0.42, 0.28, 0.04), Vector3(-0.08, 0.34, -0.18), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.36, 0.22, 0.02), Vector3(-0.08, 0.34, -0.155), Vector3.ZERO, _accent_materials["screen_on"], pivot)
			_add_sub_box(Vector3(0.08, 0.12, 0.06), Vector3(-0.08, 0.20, -0.18), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.32, 0.025, 0.12), Vector3(-0.08, 0.15, 0.08), Vector3.ZERO, metal, pivot)
			_set_box_collision(Vector3(0.94, 0.96, 0.74), Vector3(0, -0.02, 0))

		BlockShape.FURN_CHAIR:
			# Sedia ergonomica da ufficio/pranzo
			_add_sub_box(Vector3(0.50, 0.08, 0.48), Vector3(0, -0.08, 0), Vector3.ZERO, _accent_materials["cushion_navy"], pivot)
			_add_sub_box(Vector3(0.48, 0.46, 0.08), Vector3(0, 0.16, -0.22), Vector3.ZERO, _accent_materials["cushion_navy"], pivot)
			_add_sub_box(Vector3(0.07, 0.36, 0.07), Vector3(0, -0.30, 0), Vector3.ZERO, chrome, pivot)
			_add_sub_box(Vector3(0.46, 0.06, 0.08), Vector3(0, -0.47, 0), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.08, 0.06, 0.46), Vector3(0, -0.47, 0), Vector3.ZERO, metal, pivot)
			_set_box_collision(Vector3(0.56, 0.90, 0.56), Vector3(0, -0.05, 0))

		BlockShape.FURN_SOFA:
			# Divano lounge imbottito con braccioli e cuscini
			_add_sub_box(Vector3(0.96, 0.22, 0.82), Vector3(0, -0.34, 0.04), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.92, 0.16, 0.72), Vector3(0, -0.16, 0.06), Vector3.ZERO, _accent_materials["cushion_red"], pivot)
			_add_sub_box(Vector3(0.96, 0.48, 0.20), Vector3(0, 0.02, -0.28), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.14, 0.36, 0.82), Vector3(-0.42, -0.12, 0.04), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.14, 0.36, 0.82), Vector3(0.42, -0.12, 0.04), Vector3.ZERO, base_mat, pivot)
			_set_box_collision(Vector3(0.96, 0.78, 0.84), Vector3(0, -0.11, 0))

		BlockShape.FURN_TABLE:
			# Tavolo ristorante / riunioni con 4 gambe
			_add_sub_box(Vector3(0.94, 0.09, 0.94), Vector3(0, 0.12, 0), Vector3.ZERO, base_mat, pivot)
			for gx in [-0.38, 0.38]:
				for gz in [-0.38, 0.38]:
					_add_sub_box(Vector3(0.08, 0.60, 0.08), Vector3(gx, -0.20, gz), Vector3.ZERO, metal, pivot)
			_set_box_collision(Vector3(0.94, 0.68, 0.94), Vector3(0, -0.16, 0))

		BlockShape.FURN_BAR_COUNTER:
			# Bancone Bar / Reception con top in granito, poggiapiedi in ottone e bottiglie
			_add_sub_box(Vector3(0.98, 0.78, 0.66), Vector3(0, -0.11, 0), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(1.00, 0.10, 0.80), Vector3(0, 0.32, 0.04), Vector3.ZERO, _accent_materials["granite"], pivot)
			_add_sub_box(Vector3(0.96, 0.05, 0.05), Vector3(0, -0.34, 0.40), Vector3.ZERO, brass, pivot)
			# Bottiglie / macchina caffè sul bancone
			_add_sub_box(Vector3(0.10, 0.24, 0.10), Vector3(-0.28, 0.48, -0.10), Vector3.ZERO, _accent_materials["bottle_amber"], pivot)
			_add_sub_box(Vector3(0.10, 0.26, 0.10), Vector3(-0.12, 0.49, -0.12), Vector3.ZERO, _accent_materials["bottle_green"], pivot)
			_add_sub_box(Vector3(0.28, 0.24, 0.24), Vector3(0.24, 0.48, -0.06), Vector3.ZERO, chrome, pivot)
			_set_box_collision(Vector3(1.0, 0.98, 0.82), Vector3(0, -0.01, 0))

		BlockShape.FURN_BAR_STOOL:
			# Sgabello alto da bar con cuscino rosso e poggiapiedi cromato
			_add_sub_box(Vector3(0.42, 0.10, 0.42), Vector3(0, 0.16, 0), Vector3.ZERO, _accent_materials["cushion_red"], pivot)
			_add_sub_box(Vector3(0.08, 0.62, 0.08), Vector3(0, -0.18, 0), Vector3.ZERO, chrome, pivot)
			_add_sub_box(Vector3(0.36, 0.04, 0.36), Vector3(0, -0.24, 0), Vector3.ZERO, brass, pivot)
			_add_sub_box(Vector3(0.40, 0.05, 0.40), Vector3(0, -0.47, 0), Vector3.ZERO, chrome, pivot)
			_set_box_collision(Vector3(0.44, 0.72, 0.44), Vector3(0, -0.14, 0))

		BlockShape.FURN_TOILET:
			# WC completo in porcellana bianca con cassetta e scarico cromato
			_add_sub_box(Vector3(0.38, 0.24, 0.42), Vector3(0, -0.38, 0.04), Vector3.ZERO, porc, pivot)
			_add_sub_box(Vector3(0.48, 0.20, 0.54), Vector3(0, -0.18, 0.08), Vector3.ZERO, porc, pivot)
			_add_sub_box(Vector3(0.48, 0.06, 0.52), Vector3(0, -0.05, 0.08), Vector3.ZERO, _accent_materials["cushion_cream"], pivot)
			_add_sub_box(Vector3(0.48, 0.56, 0.24), Vector3(0, -0.02, -0.28), Vector3.ZERO, porc, pivot)
			_add_sub_box(Vector3(0.10, 0.04, 0.08), Vector3(0, 0.28, -0.28), Vector3.ZERO, chrome, pivot)
			_set_box_collision(Vector3(0.54, 0.80, 0.74), Vector3(0, -0.10, 0))

		BlockShape.FURN_SINK:
			# Mobile lavabo bagno con rubinetto cromato e specchio
			_add_sub_box(Vector3(0.76, 0.54, 0.52), Vector3(0, -0.23, -0.12), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.80, 0.12, 0.56), Vector3(0, 0.08, -0.12), Vector3.ZERO, porc, pivot)
			_add_sub_box(Vector3(0.06, 0.16, 0.14), Vector3(0, 0.20, -0.26), Vector3.ZERO, chrome, pivot)
			_add_sub_box(Vector3(0.68, 0.42, 0.05), Vector3(0, 0.52, -0.36), Vector3.ZERO, _accent_materials["mirror"], pivot)
			_set_box_collision(Vector3(0.80, 0.96, 0.58), Vector3(0, -0.02, -0.10))

		BlockShape.FURN_BATHTUB:
			# Vasca da bagno in porcellana con rubinetto cromato
			_add_sub_box(Vector3(0.96, 0.46, 0.82), Vector3(0, -0.27, 0), Vector3.ZERO, porc, pivot)
			_add_sub_box(Vector3(0.80, 0.12, 0.64), Vector3(0, -0.06, 0), Vector3.ZERO, _accent_materials["cushion_navy"], pivot)
			_add_sub_box(Vector3(0.08, 0.26, 0.10), Vector3(-0.38, 0.08, 0), Vector3.ZERO, chrome, pivot)
			_set_box_collision(Vector3(0.96, 0.56, 0.82), Vector3(0, -0.22, 0))

		BlockShape.FURN_BED:
			# Letto residenziale con testiera in legno, materasso, coperta e cuscini
			_add_sub_box(Vector3(0.96, 0.24, 0.96), Vector3(0, -0.36, 0), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.90, 0.20, 0.90), Vector3(0, -0.14, 0.02), Vector3.ZERO, _accent_materials["cushion_cream"], pivot)
			_add_sub_box(Vector3(0.92, 0.12, 0.62), Vector3(0, -0.06, 0.16), Vector3.ZERO, _accent_materials["cushion_navy"], pivot)
			_add_sub_box(Vector3(0.36, 0.12, 0.22), Vector3(-0.22, -0.01, -0.28), Vector3.ZERO, porc, pivot)
			_add_sub_box(Vector3(0.36, 0.12, 0.22), Vector3(0.22, -0.01, -0.28), Vector3.ZERO, porc, pivot)
			_add_sub_box(Vector3(0.96, 0.68, 0.10), Vector3(0, -0.08, -0.44), Vector3.ZERO, base_mat, pivot)
			_set_box_collision(Vector3(0.96, 0.68, 0.96), Vector3(0, -0.16, 0))

		BlockShape.FURN_BOOKSHELF:
			# Libreria / Archivio con 3 ripiani di libri colorati
			_add_sub_box(Vector3(0.92, 0.98, 0.42), Vector3(0, 0, -0.20), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.76, 0.18, 0.14), Vector3(0, 0.28, 0.02), Vector3.ZERO, _accent_materials["book_blue"], pivot)
			_add_sub_box(Vector3(0.74, 0.18, 0.14), Vector3(0, 0.0, 0.02), Vector3.ZERO, _accent_materials["cushion_red"], pivot)
			_add_sub_box(Vector3(0.76, 0.18, 0.14), Vector3(0, -0.28, 0.02), Vector3.ZERO, _accent_materials["book_gold"], pivot)
			_set_box_collision(Vector3(0.94, 1.0, 0.50), Vector3(0, 0, -0.16))

		BlockShape.FURN_KITCHEN_COUNTER:
			# Piano cucina con fornelli, top in granito e maniglie
			_add_sub_box(Vector3(0.96, 0.76, 0.68), Vector3(0, -0.12, -0.06), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.98, 0.09, 0.72), Vector3(0, 0.30, -0.06), Vector3.ZERO, _accent_materials["granite"], pivot)
			_add_sub_box(Vector3(0.44, 0.04, 0.44), Vector3(0.12, 0.36, -0.06), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.32, 0.04, 0.04), Vector3(-0.22, 0.14, 0.30), Vector3.ZERO, chrome, pivot)
			_add_sub_box(Vector3(0.32, 0.04, 0.04), Vector3(0.22, 0.14, 0.30), Vector3.ZERO, chrome, pivot)
			_set_box_collision(Vector3(0.98, 0.90, 0.72), Vector3(0, -0.05, -0.06))

		BlockShape.FURN_FRIDGE:
			# Frigorifero doppia anta in acciaio inox con maniglie cromate
			_add_sub_box(Vector3(0.78, 0.98, 0.72), Vector3(0, 0, 0), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.74, 0.03, 0.04), Vector3(0, 0.12, 0.36), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.05, 0.30, 0.06), Vector3(-0.28, 0.30, 0.38), Vector3.ZERO, chrome, pivot)
			_add_sub_box(Vector3(0.05, 0.42, 0.06), Vector3(-0.28, -0.14, 0.38), Vector3.ZERO, chrome, pivot)
			_set_box_collision(Vector3(0.80, 1.0, 0.76), Vector3.ZERO)

		BlockShape.FURN_SERVER_RACK:
			# Rack Server IT / Distributore con griglie e LED verdi luminosi
			_add_sub_box(Vector3(0.84, 0.98, 0.76), Vector3(0, 0, 0), Vector3.ZERO, metal, pivot)
			for sy in [-0.30, -0.08, 0.14, 0.34]:
				_add_sub_box(Vector3(0.68, 0.12, 0.04), Vector3(0, sy, 0.38), Vector3.ZERO, base_mat, pivot)
				_add_sub_box(Vector3(0.08, 0.04, 0.05), Vector3(0.24, sy, 0.39), Vector3.ZERO, _accent_materials["led_green"], pivot)
			_set_box_collision(Vector3(0.86, 1.0, 0.80), Vector3.ZERO)

		BlockShape.FURN_PLANT:
			# Pianta ornamentale da interni in vaso di terracotta
			_add_sub_box(Vector3(0.46, 0.40, 0.46), Vector3(0, -0.30, 0), Vector3.ZERO, _accent_materials["terracotta"], pivot)
			_add_sub_box(Vector3(0.40, 0.06, 0.40), Vector3(0, -0.09, 0), Vector3.ZERO, _accent_materials["soil"], pivot)
			_add_sub_box(Vector3(0.56, 0.36, 0.56), Vector3(0, 0.12, 0), Vector3(0, 18, 0), _accent_materials["foliage"], pivot)
			_add_sub_box(Vector3(0.40, 0.34, 0.40), Vector3(0, 0.34, 0), Vector3(0, 45, 0), _accent_materials["foliage"], pivot)
			_set_box_collision(Vector3(0.56, 0.96, 0.56), Vector3(0, -0.02, 0))

		BlockShape.FURN_TV_STAND:
			# Mobile TV con maxi schermo piatto acceso
			_add_sub_box(Vector3(0.96, 0.36, 0.52), Vector3(0, -0.32, 0), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.14, 0.14, 0.10), Vector3(0, -0.08, -0.06), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.90, 0.50, 0.06), Vector3(0, 0.22, -0.06), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.82, 0.42, 0.03), Vector3(0, 0.22, -0.02), Vector3.ZERO, _accent_materials["screen_on"], pivot)
			_set_box_collision(Vector3(0.96, 0.96, 0.54), Vector3(0, -0.02, 0))

		BlockShape.FURN_HVAC_UNIT:
			# Unità Condizionamento Industriale da tetto
			_add_sub_box(Vector3(0.94, 0.84, 0.94), Vector3(0, -0.08, 0), Vector3.ZERO, base_mat, pivot)
			_add_sub_box(Vector3(0.68, 0.08, 0.68), Vector3(0, 0.38, 0), Vector3.ZERO, metal, pivot)
			_add_sub_box(Vector3(0.70, 0.46, 0.06), Vector3(0, -0.06, 0.48), Vector3.ZERO, metal, pivot)
			_set_box_collision(Vector3(0.96, 0.92, 0.96), Vector3(0, -0.04, 0))

func _build_stair_geometry(base_mat: StandardMaterial3D) -> void:
	# 4 gradini scolpiti + rampa fisica continua a 45° perfettamente allineata
	var yaw: float = 0.0
	match block_shape:
		BlockShape.STAIR_NORTH: yaw = 0.0       # sale verso -Z
		BlockShape.STAIR_SOUTH: yaw = 180.0     # sale verso +Z
		BlockShape.STAIR_EAST:  yaw = -90.0     # sale verso +X
		BlockShape.STAIR_WEST:  yaw = 90.0      # sale verso -X

	var basis_rot := Basis(Vector3.UP, deg_to_rad(yaw))
	for i in range(4):
		var step_h: float = 0.25 * float(i + 1)
		var local_pos := Vector3(0.0, -0.5 + step_h * 0.5, 0.375 - float(i) * 0.25)
		var world_local: Vector3 = basis_rot * local_pos
		var step_size: Vector3 = Vector3(0.98, step_h, 0.26)
		if block_shape == BlockShape.STAIR_EAST or block_shape == BlockShape.STAIR_WEST:
			step_size = Vector3(0.26, step_h, 0.98)
		_add_sub_box(step_size, world_local, Vector3.ZERO, base_mat)

	var ramp_rot := Vector3(45.0, 0.0, 0.0)
	match block_shape:
		BlockShape.STAIR_NORTH: ramp_rot = Vector3(45.0, 0.0, 0.0)
		BlockShape.STAIR_SOUTH: ramp_rot = Vector3(-45.0, 0.0, 0.0)
		BlockShape.STAIR_EAST:  ramp_rot = Vector3(0.0, 0.0, 45.0)
		BlockShape.STAIR_WEST:  ramp_rot = Vector3(0.0, 0.0, -45.0)

	var ramp_size := Vector3(0.98, 0.18, 1.40)
	if block_shape == BlockShape.STAIR_EAST or block_shape == BlockShape.STAIR_WEST:
		ramp_size = Vector3(1.40, 0.18, 0.98)
	_set_box_collision(ramp_size, Vector3(0.0, -0.05, 0.0), ramp_rot)

func get_display_label() -> String:
	if custom_display_name != "":
		return custom_display_name
	return material_data.display_name if material_data else "Struttura"

func _apply_material_to_all_meshes(mat: Material) -> void:
	for mi in _visual_meshes:
		if is_instance_valid(mi):
			mi.set_surface_override_material(0, mat)

func _ensure_instance_material() -> StandardMaterial3D:
	if _instance_material == null:
		var base := _get_or_create_base_material(material_data) if material_data else StandardMaterial3D.new()
		_instance_material = base.duplicate() as StandardMaterial3D
		if not _visual_meshes.is_empty() and is_instance_valid(_visual_meshes[0]):
			_visual_meshes[0].set_surface_override_material(0, _instance_material)
	return _instance_material

func _refresh_overlay_passes() -> void:
	if _crack_stage == 0 and not _xray_enabled:
		if material_data and not _visual_meshes.is_empty() and is_instance_valid(_visual_meshes[0]):
			_visual_meshes[0].set_surface_override_material(0, _get_or_create_base_material(material_data))
		_instance_material = null
		return

	var mat := _ensure_instance_material()
	var crack_mat: StandardMaterial3D = null
	if _crack_stage > 0 and _crack_stage <= _crack_materials.size():
		crack_mat = _crack_materials[_crack_stage - 1]

	if crack_mat != null and _xray_enabled and _xray_material != null:
		var crack_dup := crack_mat.duplicate() as StandardMaterial3D
		crack_dup.next_pass = _xray_material
		mat.next_pass = crack_dup
	elif crack_mat != null:
		mat.next_pass = crack_mat
	elif _xray_enabled and _xray_material != null:
		mat.next_pass = _xray_material
	else:
		mat.next_pass = null

func set_xray_highlight(enabled: bool) -> void:
	if is_destroyed or not freeze:
		enabled = false
	if _xray_enabled == enabled:
		return
	_xray_enabled = enabled
	_refresh_overlay_passes()

func take_damage(
	amount: float,
	tool_penetration: int = 1,
	hit_pos: Vector3 = Vector3.INF,
	normal: Vector3 = Vector3.UP
) -> void:
	if is_destroyed or amount <= 0.0:
		return
	if hit_pos == Vector3.INF:
		hit_pos = global_position

	var req_tier: int = material_data.hardness_tier if material_data else 1
	var actual_damage: float = amount

	if tool_penetration < req_tier:
		actual_damage = amount * 0.10
		EventBus.block_ricochet.emit(self, hit_pos, normal, req_tier)
		_spawn_hit_particles(hit_pos, normal, Color(1.0, 0.78, 0.22), 7, 4.2)
	else:
		var dcol: Color = material_data.dust_color if material_data else Color(0.7, 0.65, 0.6)
		_spawn_hit_particles(hit_pos, normal, dcol, 6, 3.0)

	current_hp = maxf(current_hp - actual_damage, 0.0)
	EventBus.block_damaged.emit(self, actual_damage, hit_pos, normal)

	_update_damage_visuals()
	_play_hit_jolt()

	if current_hp <= 0.0:
		shatter(false)

func _update_damage_visuals() -> void:
	var ratio: float = current_hp / maxf(max_hp, 1.0)
	var new_stage: int = 0
	if ratio <= 0.28:
		new_stage = 3
	elif ratio <= 0.56:
		new_stage = 2
	elif ratio <= 0.82:
		new_stage = 1

	if new_stage != _crack_stage:
		_crack_stage = new_stage
		_refresh_overlay_passes()

	if _instance_material != null and material_data:
		var darken: float = lerpf(0.74, 1.0, ratio)
		_instance_material.albedo_color = material_data.color * Color(darken, darken, darken, _instance_material.albedo_color.a)

func _play_hit_jolt() -> void:
	if is_destroyed or _visual_meshes.is_empty():
		return
	var target: MeshInstance3D = _visual_meshes[0]
	if not is_instance_valid(target):
		return
	target.scale = Vector3(0.94, 0.94, 0.94)
	var t: Tween = create_tween()
	t.tween_property(target, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func shatter(by_gravity: bool = false) -> void:
	if is_destroyed:
		return
	is_destroyed = true

	var payout: float = EconomyManager.calculate_block_payout(material_data, by_gravity)
	EconomyManager.add_money(payout)

	var stats: Dictionary = SaveManager.save_data.get("stats", {})
	stats["blocks_destroyed"] = int(stats.get("blocks_destroyed", 0)) + 1
	stats["mass_demolished_kg"] = float(stats.get("mass_demolished_kg", 0.0)) + mass
	SaveManager.save_data["stats"] = stats

	var pos := global_position
	if not by_gravity:
		var dcol: Color = material_data.dust_color if material_data else Color(0.7, 0.65, 0.6)
		_spawn_hit_particles(pos, Vector3.UP, dcol, 10, 4.4)
		_spawn_shatter_shards(pos)

	EventBus.block_destroyed.emit(self, by_gravity)
	queue_free()

func activate_dynamic_debris(impulse: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed or not freeze:
		return

	set_xray_highlight(false)
	freeze = false
	collision_layer = 8
	collision_mask = 1 | 4 | 8

	var kick := impulse + Vector3(randf_range(-1.4, 1.4), randf_range(-0.6, 0.6), randf_range(-1.4, 1.4))
	apply_central_impulse(kick * clampf(mass * 0.12, 1.0, 14.0))
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 2.5)

	DebrisPool.register_debris(self)

func _check_fx_budget(is_shard: bool) -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != _last_fx_frame:
		_last_fx_frame = frame
		_frame_particle_count = 0
		_frame_shard_count = 0
	if is_shard:
		if _frame_shard_count >= 3:
			return false
		_frame_shard_count += 1
		return true
	if _frame_particle_count >= 4:
		return false
	_frame_particle_count += 1
	return true

func _spawn_hit_particles(pos: Vector3, normal: Vector3, color: Color, amount: int, speed: float) -> void:
	if not _check_fx_budget(false):
		return
	var root := get_tree().current_scene
	if not root:
		return

	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = 0.38
	p.mesh = _particle_mesh
	p.direction = (normal + Vector3(0, 0.4, 0)).normalized()
	p.spread = 52.0
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.25

	var pm := StandardMaterial3D.new()
	pm.albedo_color = color
	pm.roughness = 0.85
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = pm

	root.add_child(p)
	p.global_position = pos
	p.emitting = true

	var t := p.create_tween()
	t.tween_interval(0.55)
	t.tween_callback(func():
		if is_instance_valid(p):
			p.queue_free()
	)

func _spawn_shatter_shards(origin: Vector3) -> void:
	if not _check_fx_budget(true):
		return
	var root := get_tree().current_scene
	if not root:
		return

	var shard_mat: StandardMaterial3D = _get_or_create_base_material(material_data) if material_data else null
	for i in range(3):
		var shard := RigidBody3D.new()
		shard.collision_layer = 16
		shard.collision_mask = 1
		shard.mass = 2.0

		var mi := MeshInstance3D.new()
		mi.mesh = _shard_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if shard_mat:
			mi.set_surface_override_material(0, shard_mat)
		shard.add_child(mi)

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.22, 0.22, 0.22)
		cs.shape = box
		shard.add_child(cs)

		root.add_child(shard)
		shard.global_position = origin + Vector3(
			randf_range(-0.25, 0.25),
			randf_range(-0.25, 0.25),
			randf_range(-0.25, 0.25)
		)
		shard.linear_velocity = Vector3(
			randf_range(-4.0, 4.0),
			randf_range(1.6, 4.8),
			randf_range(-4.0, 4.0)
		)
		shard.angular_velocity = Vector3(
			randf_range(-7.0, 7.0),
			randf_range(-7.0, 7.0),
			randf_range(-7.0, 7.0)
		)

		var t := shard.create_tween()
		t.tween_interval(0.80)
		t.tween_property(shard, "scale", Vector3(0.05, 0.05, 0.05), 0.22)
		t.tween_callback(func():
			if is_instance_valid(shard):
				shard.queue_free()
		)
