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
var _xray_enabled: bool = false
var _damage_level: float = 0.0

# Tutta la parte visiva vive sotto _visual_root (scalata dal "jolt" d'impatto).
var _visual_root: Node3D = null
var _visual_meshes: Array[GeometryInstance3D] = []   # tutte le geometrie (X-Ray, ombre)
var _shader_meshes: Array[GeometryInstance3D] = []   # geometrie con lo shader strutturale (crepe/flash)
var _jolt_tween: Tween = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const MODEL_DIR: String = "res://assets/polyhaven/models/%s/%s_1k.gltf"
const FURNITURE_VIS_RANGE: float = 55.0
## Gli arredi sono dentro l'edificio (già in ombra): non proiettano ombre per risparmiare draw call
static var furniture_shadows: bool = false

# Risorse statiche condivise (mesh, materiali, modelli) + budget VFX per frame
static var _structure_shader: Shader = null
static var _structure_material_cache: Dictionary = {} # material_id -> ShaderMaterial
static var _accent_materials: Dictionary = {}
static var _xray_material: ShaderMaterial = null
static var _glass_material: StandardMaterial3D = null
static var _frame_material: StandardMaterial3D = null
static var _roof_material: StandardMaterial3D = null
static var _box_cache: Dictionary = {}
static var _rbox_cache: Dictionary = {}
static var _cyl_cache: Dictionary = {}
static var _model_cache: Dictionary = {} # path -> {"scene": PackedScene, "aabb": AABB}
static var _rock_meshes: Array[ArrayMesh] = []
static var _dust_materials: Dictionary = {}
static var _dust_quad: QuadMesh = null
static var _dust_curve: Curve = null
static var _dust_ramp: Gradient = null
static var _last_fx_frame: int = -1
static var _frame_particle_count: int = 0
static var _frame_shard_count: int = 0

func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	_ensure_shared_resources()
	_apply_material_properties()
	_build_architectural_geometry()

# ---------------------------------------------------------------------------------------------
# RISORSE CONDIVISE
# ---------------------------------------------------------------------------------------------
static func _ensure_shared_resources() -> void:
	if _structure_shader == null:
		_structure_shader = load("res://assets/shaders/structure_pbr.gdshader")

	if _xray_material == null:
		var sh_path := "res://assets/shaders/block_xray_outline.gdshader"
		if ResourceLoader.exists(sh_path):
			_xray_material = ShaderMaterial.new()
			_xray_material.shader = load(sh_path)

	if _glass_material == null:
		_glass_material = StandardMaterial3D.new()
		_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_material.albedo_color = Color(0.42, 0.55, 0.62, 0.38)
		_glass_material.roughness = 0.04
		_glass_material.metallic = 0.15
		_glass_material.metallic_specular = 0.9
		_glass_material.rim_enabled = true
		_glass_material.rim = 0.35
		_glass_material.rim_tint = 0.2

	if _frame_material == null:
		_frame_material = _make_simple_mat(Color(0.13, 0.14, 0.16), 0.38, 0.85)

	if _roof_material == null:
		_roof_material = StandardMaterial3D.new()
		_roof_material.albedo_color = Color(0.92, 0.88, 0.84, 1.0)
		_roof_material.roughness = 0.84
		_roof_material.uv1_triplanar = true
		_roof_material.uv1_scale = Vector3(0.8, 0.8, 0.8)
		if ResourceLoader.exists("res://assets/textures/tex_roof_tiles.png"):
			_roof_material.albedo_texture = load("res://assets/textures/tex_roof_tiles.png")

	if _accent_materials.is_empty():
		_accent_materials["dark_metal"] = _make_simple_mat(Color(0.12, 0.13, 0.15), 0.42, 0.85)
		_accent_materials["brushed_steel"] = _make_simple_mat(Color(0.72, 0.74, 0.77), 0.30, 0.95)
		_accent_materials["chrome"] = _make_simple_mat(Color(0.90, 0.91, 0.93), 0.08, 1.0)
		_accent_materials["brass"] = _make_simple_mat(Color(0.86, 0.66, 0.30), 0.22, 1.0)
		var porc := _make_simple_mat(Color(0.95, 0.96, 0.97), 0.10, 0.0)
		porc.clearcoat_enabled = true
		porc.clearcoat = 0.8
		porc.clearcoat_roughness = 0.08
		_accent_materials["porcelain"] = porc
		_accent_materials["linen"] = _make_simple_mat(Color(0.93, 0.91, 0.86), 0.95, 0.0)
		_accent_materials["duvet"] = _make_simple_mat(Color(0.24, 0.33, 0.46), 0.92, 0.0)
		_accent_materials["water"] = _make_simple_mat(Color(0.55, 0.72, 0.80), 0.02, 0.0)
		_accent_materials["granite"] = _make_simple_mat(Color(0.16, 0.16, 0.17), 0.18, 0.05)
		_accent_materials["black_glass"] = _make_simple_mat(Color(0.03, 0.03, 0.035), 0.05, 0.2)
		_accent_materials["led_green"] = _make_emissive_mat(Color(0.22, 0.96, 0.45), 2.5)
		_accent_materials["led_blue"] = _make_emissive_mat(Color(0.25, 0.55, 1.0), 2.0)
		_accent_materials["mirror"] = _make_simple_mat(Color(0.86, 0.90, 0.93), 0.02, 1.0)
		_accent_materials["bottle_amber"] = _make_simple_mat(Color(0.55, 0.26, 0.06), 0.08, 0.0)
		_accent_materials["bottle_green"] = _make_simple_mat(Color(0.10, 0.30, 0.14), 0.08, 0.0)
		_accent_materials["vent"] = _make_simple_mat(Color(0.05, 0.05, 0.06), 0.6, 0.6)

	if _rock_meshes.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 1337
		for i in range(5):
			_rock_meshes.append(_generate_rock_mesh(rng))

	if _dust_quad == null:
		_dust_quad = QuadMesh.new()
		_dust_quad.size = Vector2(0.6, 0.6)
		_dust_curve = Curve.new()
		_dust_curve.add_point(Vector2(0.0, 0.35))
		_dust_curve.add_point(Vector2(0.35, 0.85))
		_dust_curve.add_point(Vector2(1.0, 1.25))
		_dust_ramp = Gradient.new()
		_dust_ramp.set_color(0, Color(1, 1, 1, 0.75))
		_dust_ramp.set_color(1, Color(1, 1, 1, 0.0))
		_dust_ramp.add_point(0.25, Color(1, 1, 1, 0.55))

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

static func get_structure_material(mat_data: MaterialData) -> ShaderMaterial:
	_ensure_shared_resources()
	var key: StringName = mat_data.material_id if mat_data else &"_default"
	if _structure_material_cache.has(key):
		return _structure_material_cache[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = _structure_shader
	if mat_data:
		m.set_shader_parameter("albedo_tex", mat_data.albedo_texture)
		m.set_shader_parameter("normal_tex", mat_data.normal_texture)
		m.set_shader_parameter("has_normal", mat_data.normal_texture != null)
		m.set_shader_parameter("rough_tex", mat_data.roughness_texture)
		m.set_shader_parameter("ao_tex", mat_data.ao_texture)
		m.set_shader_parameter("tint", mat_data.color)
		m.set_shader_parameter("world_size", mat_data.texture_world_size)
		m.set_shader_parameter("roughness_mult", 1.0 if mat_data.roughness_texture else mat_data.roughness)
		m.set_shader_parameter("metallic_value", mat_data.metallic)
		m.set_shader_parameter("grime_amount", mat_data.grime_amount)
	_structure_material_cache[key] = m
	return m

# ---------------------------------------------------------------------------------------------
# MESH CONDIVISE (cache: migliaia di blocchi riusano le stesse mesh invece di crearne copie)
# ---------------------------------------------------------------------------------------------
static func _get_box(size: Vector3) -> BoxMesh:
	var key := "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if not _box_cache.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_box_cache[key] = bm
	return _box_cache[key]

static func _get_cylinder(radius: float, height: float, top_ratio: float = 1.0) -> CylinderMesh:
	var key := "%.3f|%.3f|%.2f" % [radius, height, top_ratio]
	if not _cyl_cache.has(key):
		var cm := CylinderMesh.new()
		cm.bottom_radius = radius
		cm.top_radius = radius * top_ratio
		cm.height = height
		cm.radial_segments = 16
		cm.rings = 1
		_cyl_cache[key] = cm
	return _cyl_cache[key]

# Box con spigoli arrotondati (raggio r): niente forme "a cubetti" per sanitari, letti, elettrodomestici
static func _get_rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	var key := "%.3f|%.3f|%.3f|%.3f" % [size.x, size.y, size.z, radius]
	if _rbox_cache.has(key):
		return _rbox_cache[key]
	var h: Vector3 = size * 0.5
	var r: float = minf(radius, minf(h.x, minf(h.y, h.z)) * 0.98)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: Array[float] = [0.0, 0.18, 0.42, 0.7, 1.0]
	var faces: Array = [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]
	]
	for f in faces:
		var nrm: Vector3 = f[0]
		var u_ax: Vector3 = f[1]
		var v_ax: Vector3 = f[2]
		var hu: float = absf(u_ax.dot(h))
		var hv: float = absf(v_ax.dot(h))
		var hn: float = absf(nrm.dot(h))
		var coords_u: Array[float] = _rounded_axis_coords(hu, r, steps)
		var coords_v: Array[float] = _rounded_axis_coords(hv, r, steps)
		var grid: Array = []
		for cv in coords_v:
			var row: Array[Vector3] = []
			for cu in coords_u:
				var p: Vector3 = nrm * hn + u_ax * cu + v_ax * cv
				var inner := Vector3(clampf(p.x, -h.x + r, h.x - r), clampf(p.y, -h.y + r, h.y - r), clampf(p.z, -h.z + r, h.z - r))
				var d: Vector3 = p - inner
				var n: Vector3 = d.normalized() if d.length_squared() > 1e-10 else nrm
				row.append(inner + n * r)
			grid.append(row)
		for j in range(grid.size() - 1):
			for i in range(coords_u.size() - 1):
				var a: Vector3 = grid[j][i]
				var b: Vector3 = grid[j][i + 1]
				var c: Vector3 = grid[j + 1][i + 1]
				var d2: Vector3 = grid[j + 1][i]
				_add_tri(st, a, b, c, h, r)
				_add_tri(st, a, c, d2, h, r)
	var mesh: ArrayMesh = st.commit()
	_rbox_cache[key] = mesh
	return mesh

static func _rounded_axis_coords(half: float, r: float, steps: Array[float]) -> Array[float]:
	var out: Array[float] = []
	for s in steps:
		out.append(-half + r * s)
	for i in range(steps.size() - 1, -1, -1):
		var v: float = half - r * steps[i]
		if v > out[out.size() - 1] + 1e-5:
			out.append(v)
	return out

static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, h: Vector3, r: float) -> void:
	# Godot considera "fronte" i triangoli in senso orario visti dall'esterno
	var outward: Vector3 = (a + b + c) / 3.0
	var tri_n: Vector3 = (b - a).cross(c - a)
	var verts: Array[Vector3] = [a, b, c]
	if tri_n.dot(outward) > 0.0:
		verts = [a, c, b]
	for v in verts:
		var inner := Vector3(clampf(v.x, -h.x + r, h.x - r), clampf(v.y, -h.y + r, h.y - r), clampf(v.z, -h.z + r, h.z - r))
		var d: Vector3 = v - inner
		st.set_normal(d.normalized() if d.length_squared() > 1e-10 else outward.normalized())
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)

# Scheggia irregolare (sfera deformata e schiacciata) per macerie realistiche
static func _generate_rock_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 7
	sphere.rings = 4
	var arrays: Array = sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var squash := Vector3(rng.randf_range(0.7, 1.2), rng.randf_range(0.45, 0.8), rng.randf_range(0.7, 1.2))
	var offsets: Dictionary = {}
	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		var k := "%.3f|%.3f|%.3f" % [v.x, v.y, v.z]
		if not offsets.has(k):
			offsets[k] = rng.randf_range(0.72, 1.18)
		verts[i] = v * squash * float(offsets[k])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, idx.size(), 3):
		for j in range(3):
			st.add_vertex(verts[idx[i + j]])
	st.generate_normals()
	return st.commit()

# ---------------------------------------------------------------------------------------------
# MODELLI 3D (Poly Haven, CC0)
# ---------------------------------------------------------------------------------------------
static func _get_model_entry(model_id: String) -> Dictionary:
	var path: String = MODEL_DIR % [model_id, model_id]
	if _model_cache.has(path):
		return _model_cache[path]
	var entry: Dictionary = {}
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		if ps:
			var probe: Node = ps.instantiate()
			var acc: Array = []
			_accumulate_aabb(probe, Transform3D.IDENTITY, acc)
			probe.free()
			if not acc.is_empty():
				entry = {"scene": ps, "aabb": acc[0]}
	_model_cache[path] = entry
	return entry

static func _accumulate_aabb(node: Node, xf: Transform3D, acc: Array) -> void:
	var t: Transform3D = xf
	if node is Node3D:
		t = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var a: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
		if acc.is_empty():
			acc.append(a)
		else:
			acc[0] = (acc[0] as AABB).merge(a)
	for c in node.get_children():
		_accumulate_aabb(c, t, acc)

## Istanzia un modello adattandolo al box `fit` (anisotropia limitata per non deformarlo troppo),
## appoggiato a quota `bottom_y` nello spazio del pivot. Ritorna l'altezza finale del modello.
func _place_model(model_id: String, fit: Vector3, parent: Node3D, bottom_y: float = -0.5, offset: Vector3 = Vector3.ZERO, cast_shadows: bool = true) -> float:
	var entry: Dictionary = _get_model_entry(model_id)
	if entry.is_empty():
		return 0.0
	var aabb: AABB = entry["aabb"]
	var sz: Vector3 = aabb.size.max(Vector3(0.001, 0.001, 0.001))
	var s := Vector3(minf(fit.x / sz.x, 1.0), minf(fit.y / sz.y, 1.0), minf(fit.z / sz.z, 1.0))
	var s_min: float = minf(s.x, minf(s.y, s.z))
	var cap: float = s_min * 1.6
	s = Vector3(minf(s.x, cap), minf(s.y, cap), minf(s.z, cap))
	var inst := (entry["scene"] as PackedScene).instantiate() as Node3D
	inst.scale = s
	var center: Vector3 = aabb.position + aabb.size * 0.5
	inst.position = Vector3(-center.x * s.x, bottom_y - aabb.position.y * s.y, -center.z * s.z) + offset
	parent.add_child(inst)
	_register_model_geometry(inst, cast_shadows)
	return sz.y * s.y

func _register_model_geometry(node: Node, cast_shadows: bool) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.visibility_range_end = FURNITURE_VIS_RANGE
		gi.visibility_range_end_margin = 4.0
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (cast_shadows and furniture_shadows) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual_meshes.append(gi)
	for c in node.get_children():
		_register_model_geometry(c, cast_shadows)

# ---------------------------------------------------------------------------------------------
# PROPRIETÀ & GEOMETRIA
# ---------------------------------------------------------------------------------------------
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

## Aggiunge un pezzo di geometria. `mat` = null -> materiale strutturale PBR del blocco.
func _add_piece(mesh: Mesh, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, mat: Material = null, parent_node: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	var use_mat: Material = mat if mat != null else get_structure_material(material_data)
	mi.material_override = use_mat
	(parent_node if parent_node != null else _visual_root).add_child(mi)
	_visual_meshes.append(mi)
	if use_mat is ShaderMaterial and (use_mat as ShaderMaterial).shader == _structure_shader:
		_shader_meshes.append(mi)
	return mi

func _add_sub_box(size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, override_mat: Material = null, parent_node: Node3D = null) -> MeshInstance3D:
	return _add_piece(_get_box(size), pos, rot_deg, override_mat, parent_node)

func _add_rbox(size: Vector3, radius: float, pos: Vector3, mat: Material = null, parent_node: Node3D = null, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _add_piece(_get_rounded_box(size, radius), pos, rot_deg, mat, parent_node)

func _add_cyl(radius: float, height: float, pos: Vector3, mat: Material, parent_node: Node3D = null, rot_deg: Vector3 = Vector3.ZERO, top_ratio: float = 1.0) -> MeshInstance3D:
	return _add_piece(_get_cylinder(radius, height, top_ratio), pos, rot_deg, mat, parent_node)

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
	_shader_meshes.clear()
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	if mesh_instance:
		mesh_instance.visible = false

	match block_shape:
		BlockShape.FULL_CUBE:
			_add_sub_box(Vector3(1.0, 1.0, 1.0), Vector3.ZERO)

		BlockShape.PILLAR:
			# Colonna continua: impilando più blocchi si ottiene un unico pilastro senza giunture
			_add_sub_box(Vector3(0.62, 1.0, 0.62), Vector3.ZERO)
			_set_box_collision(Vector3(0.70, 1.0, 0.70), Vector3.ZERO)

		BlockShape.WALL_X:
			_add_sub_box(Vector3(1.0, 1.0, 0.30), Vector3.ZERO)
			_set_box_collision(Vector3(1.0, 1.0, 0.32), Vector3.ZERO)

		BlockShape.WALL_Z:
			_add_sub_box(Vector3(0.30, 1.0, 1.0), Vector3.ZERO)
			_set_box_collision(Vector3(0.32, 1.0, 1.0), Vector3.ZERO)

		BlockShape.SLAB:
			_add_sub_box(Vector3(1.0, 0.28, 1.0), Vector3(0, 0.36, 0))
			_set_box_collision(Vector3(1.0, 0.28, 1.0), Vector3(0, 0.36, 0))

		BlockShape.SLAB_BOTTOM:
			_add_sub_box(Vector3(1.0, 0.26, 1.0), Vector3(0, -0.37, 0))
			_set_box_collision(Vector3(1.0, 0.26, 1.0), Vector3(0, -0.37, 0))

		BlockShape.BEAM_X:
			_add_sub_box(Vector3(1.0, 0.36, 0.36), Vector3(0, 0.32, 0))
			_set_box_collision(Vector3(1.0, 0.36, 0.36), Vector3(0, 0.32, 0))

		BlockShape.BEAM_Z:
			_add_sub_box(Vector3(0.36, 0.36, 1.0), Vector3(0, 0.32, 0))
			_set_box_collision(Vector3(0.36, 0.36, 1.0), Vector3(0, 0.32, 0))

		BlockShape.STAIR_NORTH, BlockShape.STAIR_SOUTH, BlockShape.STAIR_EAST, BlockShape.STAIR_WEST:
			_build_stair_geometry()

		BlockShape.ROOF_SLOPE_N:
			_add_sub_box(Vector3(1.02, 0.20, 1.38), Vector3.ZERO, Vector3(35.0, 0, 0), _roof_material)
			_set_box_collision(Vector3(1.0, 0.22, 1.35), Vector3.ZERO, Vector3(35.0, 0, 0))

		BlockShape.ROOF_SLOPE_S:
			_add_sub_box(Vector3(1.02, 0.20, 1.38), Vector3.ZERO, Vector3(-35.0, 0, 0), _roof_material)
			_set_box_collision(Vector3(1.0, 0.22, 1.35), Vector3.ZERO, Vector3(-35.0, 0, 0))

		BlockShape.WINDOW_X:
			_build_window(false)
			_set_box_collision(Vector3(1.0, 1.0, 0.24), Vector3.ZERO)

		BlockShape.WINDOW_Z:
			_build_window(true)
			_set_box_collision(Vector3(0.24, 1.0, 1.0), Vector3.ZERO)

		BlockShape.DOOR_LINTEL_X:
			_add_sub_box(Vector3(1.0, 0.34, 0.34), Vector3(0, 0.33, 0))
			_set_box_collision(Vector3(1.0, 0.34, 0.34), Vector3(0, 0.33, 0))

		BlockShape.DOOR_LINTEL_Z:
			_add_sub_box(Vector3(0.34, 0.34, 1.0), Vector3(0, 0.33, 0))
			_set_box_collision(Vector3(0.34, 0.34, 1.0), Vector3(0, 0.33, 0))

		BlockShape.FENCE_POST:
			_add_sub_box(Vector3(0.24, 1.0, 0.24), Vector3.ZERO)
			_set_box_collision(Vector3(0.30, 1.0, 0.30), Vector3.ZERO)

		BlockShape.FENCE_PANEL_X:
			_add_sub_box(Vector3(1.0, 0.10, 0.08), Vector3(0, 0.30, -0.02))
			_add_sub_box(Vector3(1.0, 0.10, 0.08), Vector3(0, -0.30, -0.02))
			for i in range(5):
				var px: float = -0.40 + float(i) * 0.20
				var h: float = 0.94 - float(i % 2) * 0.06
				_add_sub_box(Vector3(0.17, h, 0.03), Vector3(px, -0.02, 0.04), Vector3(0, 0, (float(i) - 2.0) * 0.6))
			_set_box_collision(Vector3(1.0, 0.98, 0.20), Vector3.ZERO)

		_:
			_build_furniture_geometry()

func _build_window(along_z: bool) -> void:
	# Serramento sottile (una sola mesh condivisa) + vetro: finestre affiancate = facciata continua
	_add_piece(_get_window_frame(along_z), Vector3.ZERO, Vector3.ZERO, _frame_material)
	if along_z:
		_add_sub_box(Vector3(0.02, 0.9, 0.92), Vector3.ZERO, Vector3.ZERO, _glass_material)
	else:
		_add_sub_box(Vector3(0.92, 0.9, 0.02), Vector3.ZERO, Vector3.ZERO, _glass_material)

static var _window_frame_cache: Dictionary = {}

static func _get_window_frame(along_z: bool) -> ArrayMesh:
	if _window_frame_cache.has(along_z):
		return _window_frame_cache[along_z]
	var t: float = 0.05
	var parts: Array = []
	if along_z:
		parts = [[Vector3(0.16, t, 1.0), Vector3(0, -0.5 + t * 0.5, 0)], [Vector3(0.16, t, 1.0), Vector3(0, 0.5 - t * 0.5, 0)],
			[Vector3(0.14, 0.9, 0.04), Vector3(0, 0, -0.48)], [Vector3(0.14, 0.9, 0.04), Vector3(0, 0, 0.48)]]
	else:
		parts = [[Vector3(1.0, t, 0.16), Vector3(0, -0.5 + t * 0.5, 0)], [Vector3(1.0, t, 0.16), Vector3(0, 0.5 - t * 0.5, 0)],
			[Vector3(0.04, 0.9, 0.14), Vector3(-0.48, 0, 0)], [Vector3(0.04, 0.9, 0.14), Vector3(0.48, 0, 0)]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		st.append_from(_get_box(p[0]), 0, Transform3D(Basis.IDENTITY, p[1]))
	var mesh: ArrayMesh = st.commit()
	_window_frame_cache[along_z] = mesh
	return mesh

func _build_furniture_geometry() -> void:
	var pivot := Node3D.new()
	pivot.rotation_degrees = Vector3(0.0, prop_yaw_deg, 0.0)
	_visual_root.add_child(pivot)

	var wood: Material = get_structure_material(material_data)
	var dark: Material = _accent_materials["dark_metal"]
	var steel: Material = _accent_materials["brushed_steel"]
	var chrome: Material = _accent_materials["chrome"]
	var brass: Material = _accent_materials["brass"]
	var porc: Material = _accent_materials["porcelain"]

	match block_shape:
		BlockShape.FURN_DESK:
			var desk_h: float = _place_model("metal_office_desk", Vector3(1.3, 0.78, 0.9), pivot)
			_place_model("classic_laptop", Vector3(0.38, 0.30, 0.30), pivot, -0.5 + desk_h, Vector3(-0.1, 0, 0.05), false)
			_set_box_collision(Vector3(0.94, 0.96, 0.74), Vector3(0, -0.02, 0))

		BlockShape.FURN_CHAIR:
			_place_model("modern_arm_chair_01", Vector3(0.78, 0.95, 0.85), pivot)
			_set_box_collision(Vector3(0.56, 0.90, 0.56), Vector3(0, -0.05, 0))

		BlockShape.FURN_SOFA:
			_place_model("sofa_02", Vector3(1.35, 0.78, 0.86), pivot)
			_set_box_collision(Vector3(0.96, 0.78, 0.84), Vector3(0, -0.11, 0))

		BlockShape.FURN_TABLE:
			_place_model("WoodenTable_01", Vector3(1.15, 0.76, 0.9), pivot)
			_set_box_collision(Vector3(0.94, 0.68, 0.94), Vector3(0, -0.16, 0))

		BlockShape.FURN_BAR_STOOL:
			_place_model("bar_chair_round_01", Vector3(0.5, 0.82, 0.5), pivot, -0.5, Vector3.ZERO, false)
			_set_box_collision(Vector3(0.44, 0.72, 0.44), Vector3(0, -0.14, 0))

		BlockShape.FURN_BOOKSHELF:
			_place_model("Shelf_01", Vector3(0.96, 1.9, 0.45), pivot, -0.5, Vector3(0, 0, -0.26))
			_set_box_collision(Vector3(0.94, 1.0, 0.50), Vector3(0, 0, -0.16))

		BlockShape.FURN_PLANT:
			_place_model("potted_plant_02", Vector3(0.7, 0.95, 0.7), pivot, -0.5, Vector3.ZERO, false)
			_set_box_collision(Vector3(0.56, 0.96, 0.56), Vector3(0, -0.02, 0))

		BlockShape.FURN_TV_STAND:
			var cab_h: float = _place_model("modern_wooden_cabinet", Vector3(1.25, 0.5, 0.5), pivot, -0.5, Vector3(0, 0, -0.12))
			_place_model("Television_01", Vector3(0.75, 0.55, 0.4), pivot, -0.5 + cab_h, Vector3(0, 0, -0.15))
			_set_box_collision(Vector3(0.96, 0.96, 0.54), Vector3(0, -0.02, 0))

		BlockShape.FURN_HVAC_UNIT:
			_place_model("exterior_aircon_unit", Vector3(1.0, 0.9, 0.55), pivot)
			_set_box_collision(Vector3(0.96, 0.92, 0.96), Vector3(0, -0.04, 0))

		BlockShape.FURN_BAR_COUNTER:
			# Bancone: fronte in legno, top in granito lucido, poggiapiedi in ottone, bottiglie
			_add_rbox(Vector3(0.98, 0.96, 0.62), 0.03, Vector3(0, -0.04, -0.02), wood, pivot)
			_add_rbox(Vector3(1.0, 0.06, 0.78), 0.02, Vector3(0, 0.47, 0.04), _accent_materials["granite"], pivot)
			_add_cyl(0.022, 0.98, Vector3(0, -0.36, 0.40), brass, pivot, Vector3(0, 0, 90))
			_add_cyl(0.04, 0.26, Vector3(-0.30, 0.63, -0.16), _accent_materials["bottle_amber"], pivot, Vector3.ZERO, 0.45)
			_add_cyl(0.04, 0.30, Vector3(-0.18, 0.65, -0.20), _accent_materials["bottle_green"], pivot, Vector3.ZERO, 0.45)
			_add_rbox(Vector3(0.30, 0.30, 0.26), 0.03, Vector3(0.26, 0.65, -0.12), steel, pivot)
			_set_box_collision(Vector3(1.0, 1.0, 0.82), Vector3.ZERO)

		BlockShape.FURN_TOILET:
			# WC sospeso in ceramica: tazza arrotondata, sedile, cassetta, pulsante cromato
			_add_rbox(Vector3(0.36, 0.34, 0.50), 0.14, Vector3(0, -0.22, 0.06), porc, pivot)
			_add_rbox(Vector3(0.38, 0.04, 0.48), 0.12, Vector3(0, -0.03, 0.07), porc, pivot)
			_add_rbox(Vector3(0.44, 0.48, 0.18), 0.05, Vector3(0, 0.05, -0.30), porc, pivot)
			_add_rbox(Vector3(0.10, 0.06, 0.02), 0.01, Vector3(0, 0.18, -0.205), chrome, pivot)
			_set_box_collision(Vector3(0.54, 0.80, 0.74), Vector3(0, -0.10, 0))

		BlockShape.FURN_SINK:
			# Mobile lavabo sospeso: cassettone in legno, lavabo in ceramica, rubinetto, specchio
			_add_rbox(Vector3(0.78, 0.40, 0.46), 0.02, Vector3(0, -0.06, -0.20), wood, pivot)
			_add_rbox(Vector3(0.80, 0.10, 0.50), 0.04, Vector3(0, 0.19, -0.19), porc, pivot)
			_add_rbox(Vector3(0.56, 0.02, 0.32), 0.12, Vector3(0, 0.245, -0.16), _accent_materials["water"], pivot)
			_add_cyl(0.018, 0.16, Vector3(0, 0.32, -0.38), chrome, pivot)
			_add_cyl(0.014, 0.12, Vector3(0, 0.39, -0.33), chrome, pivot, Vector3(90, 0, 0))
			_add_rbox(Vector3(0.70, 0.52, 0.02), 0.01, Vector3(0, 0.62, -0.46), _accent_materials["mirror"], pivot)
			_set_box_collision(Vector3(0.80, 0.96, 0.58), Vector3(0, -0.02, -0.10))

		BlockShape.FURN_BATHTUB:
			# Vasca in ceramica con bordo arrotondato, acqua e miscelatore
			_add_rbox(Vector3(0.96, 0.52, 0.80), 0.10, Vector3(0, -0.24, 0), porc, pivot)
			_add_rbox(Vector3(0.80, 0.02, 0.62), 0.16, Vector3(0, 0.015, 0), _accent_materials["water"], pivot)
			_add_cyl(0.02, 0.22, Vector3(-0.40, 0.12, 0), chrome, pivot)
			_add_cyl(0.016, 0.14, Vector3(-0.34, 0.22, 0), chrome, pivot, Vector3(0, 0, 90))
			_set_box_collision(Vector3(0.96, 0.56, 0.82), Vector3(0, -0.22, 0))

		BlockShape.FURN_BED:
			# Letto: struttura in legno, materasso, piumone, cuscini, testiera imbottita
			_add_rbox(Vector3(0.98, 0.22, 0.98), 0.02, Vector3(0, -0.36, 0.0), wood, pivot)
			_add_rbox(Vector3(0.92, 0.18, 0.92), 0.06, Vector3(0, -0.17, 0.02), _accent_materials["linen"], pivot)
			_add_rbox(Vector3(0.95, 0.10, 0.64), 0.05, Vector3(0, -0.07, 0.16), _accent_materials["duvet"], pivot)
			_add_rbox(Vector3(0.38, 0.11, 0.22), 0.05, Vector3(-0.22, -0.03, -0.30), _accent_materials["linen"], pivot)
			_add_rbox(Vector3(0.38, 0.11, 0.22), 0.05, Vector3(0.22, -0.03, -0.30), _accent_materials["linen"], pivot)
			_add_rbox(Vector3(0.98, 0.70, 0.08), 0.035, Vector3(0, -0.10, -0.46), get_structure_material(load("res://data/materials/fabric_sofa.tres")), pivot)
			_set_box_collision(Vector3(0.96, 0.68, 0.96), Vector3(0, -0.16, 0))

		BlockShape.FURN_KITCHEN_COUNTER:
			# Cucina: basi in legno con zoccolo, top in granito, piano cottura a induzione, maniglie
			_add_sub_box(Vector3(0.94, 0.08, 0.58), Vector3(0, -0.46, -0.08), Vector3.ZERO, dark, pivot)
			_add_rbox(Vector3(0.98, 0.74, 0.62), 0.012, Vector3(0, -0.05, -0.06), wood, pivot)
			_add_rbox(Vector3(1.0, 0.04, 0.68), 0.01, Vector3(0, 0.34, -0.06), _accent_materials["granite"], pivot)
			_add_rbox(Vector3(0.52, 0.008, 0.44), 0.01, Vector3(0.14, 0.364, -0.08), _accent_materials["black_glass"], pivot)
			_add_rbox(Vector3(0.30, 0.02, 0.02), 0.008, Vector3(-0.24, 0.20, 0.26), steel, pivot)
			_add_rbox(Vector3(0.30, 0.02, 0.02), 0.008, Vector3(0.24, 0.20, 0.26), steel, pivot)
			_set_box_collision(Vector3(0.98, 0.90, 0.72), Vector3(0, -0.05, -0.06))

		BlockShape.FURN_FRIDGE:
			# Frigorifero combinato in acciaio spazzolato con fuga tra le ante e maniglie verticali
			_add_rbox(Vector3(0.74, 0.98, 0.70), 0.03, Vector3(0, 0, -0.02), steel, pivot)
			_add_sub_box(Vector3(0.72, 0.012, 0.02), Vector3(0, 0.12, 0.335), Vector3.ZERO, dark, pivot)
			_add_rbox(Vector3(0.025, 0.30, 0.035), 0.012, Vector3(-0.30, 0.32, 0.36), chrome, pivot)
			_add_rbox(Vector3(0.025, 0.40, 0.035), 0.012, Vector3(-0.30, -0.12, 0.36), chrome, pivot)
			_set_box_collision(Vector3(0.80, 1.0, 0.76), Vector3.ZERO)

		BlockShape.FURN_SERVER_RACK:
			# Rack 42U: telaio nero, server con griglie di ventilazione e LED di stato
			_add_rbox(Vector3(0.62, 0.98, 0.80), 0.015, Vector3.ZERO, dark, pivot)
			for i in range(7):
				var sy: float = -0.40 + float(i) * 0.13
				_add_sub_box(Vector3(0.54, 0.10, 0.02), Vector3(0, sy, 0.40), Vector3.ZERO, _accent_materials["vent"], pivot)
				_add_sub_box(Vector3(0.03, 0.015, 0.02), Vector3(0.22, sy + 0.02, 0.412), Vector3.ZERO, _accent_materials["led_green"] if i % 3 != 0 else _accent_materials["led_blue"], pivot)
			_set_box_collision(Vector3(0.86, 1.0, 0.80), Vector3.ZERO)

		_:
			_add_rbox(Vector3(0.8, 0.8, 0.8), 0.05, Vector3.ZERO, wood, pivot)

func _build_stair_geometry() -> void:
	# 4 gradini + rampa fisica continua a 45° perfettamente allineata
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
		_add_sub_box(step_size, world_local)

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

# ---------------------------------------------------------------------------------------------
# STATO VISIVO: X-RAY, DANNI, IMPATTI
# ---------------------------------------------------------------------------------------------
func set_xray_highlight(enabled: bool) -> void:
	if is_destroyed or not freeze:
		enabled = false
	if _xray_enabled == enabled:
		return
	_xray_enabled = enabled
	var overlay: Material = _xray_material if enabled else null
	for gi in _visual_meshes:
		if is_instance_valid(gi):
			gi.material_overlay = overlay

func _set_shader_instance_param(param: StringName, value: Variant) -> void:
	for gi in _shader_meshes:
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter(param, value)

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
		_spawn_sparks(hit_pos, normal)
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
	var dmg: float = clampf(1.0 - ratio, 0.0, 1.0)
	if absf(dmg - _damage_level) > 0.01:
		_damage_level = dmg
		_set_shader_instance_param(&"damage", dmg)

func _play_hit_jolt() -> void:
	if is_destroyed or not is_instance_valid(_visual_root):
		return
	if _jolt_tween and _jolt_tween.is_valid():
		_jolt_tween.kill()
	_visual_root.scale = Vector3(0.96, 0.96, 0.96)
	_set_shader_instance_param(&"hit_flash", 1.0)
	_jolt_tween = create_tween()
	_jolt_tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_jolt_tween.parallel().tween_method(func(v: float): _set_shader_instance_param(&"hit_flash", v), 1.0, 0.0, 0.12)

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
		_spawn_dust_cloud(pos, dcol)
		_spawn_shatter_shards(pos)

	EventBus.block_destroyed.emit(self, by_gravity)
	queue_free()

func activate_dynamic_debris(impulse: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed or not freeze:
		return

	set_xray_highlight(false)
	# La texture ora segue il pezzo che cade (mappatura in spazio oggetto)
	_set_shader_instance_param(&"local_mode", 1.0)
	freeze = false
	collision_layer = 8
	collision_mask = 1 | 4 | 8

	var kick := impulse + Vector3(randf_range(-1.4, 1.4), randf_range(-0.6, 0.6), randf_range(-1.4, 1.4))
	apply_central_impulse(kick * clampf(mass * 0.12, 1.0, 14.0))
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 2.5)

	DebrisPool.register_debris(self)

# ---------------------------------------------------------------------------------------------
# VFX: polvere, schegge, scintille (con budget per frame anti-lag durante le esplosioni)
# ---------------------------------------------------------------------------------------------
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
	if _frame_particle_count >= 5:
		return false
	_frame_particle_count += 1
	return true

static func _get_dust_material(col: Color) -> StandardMaterial3D:
	var key := col.to_html(false)
	if _dust_materials.has(key):
		return _dust_materials[key]
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col.lightened(0.15)
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.4
	_dust_materials[key] = m
	return m

func _spawn_hit_particles(pos: Vector3, normal: Vector3, color: Color, amount: int, speed: float) -> void:
	if not _check_fx_budget(false):
		return
	var root := get_tree().current_scene
	if not root:
		return

	# Schegge piccole (mesh irregolari) + sbuffo di polvere
	var chips := CPUParticles3D.new()
	chips.one_shot = true
	chips.explosiveness = 0.95
	chips.amount = amount
	chips.lifetime = 0.55
	chips.mesh = _rock_meshes[randi() % _rock_meshes.size()]
	chips.direction = (normal + Vector3(0, 0.45, 0)).normalized()
	chips.spread = 50.0
	chips.initial_velocity_min = speed * 0.6
	chips.initial_velocity_max = speed * 1.1
	chips.gravity = Vector3(0, -14.0, 0)
	chips.scale_amount_min = 0.05
	chips.scale_amount_max = 0.12
	chips.angular_velocity_min = -400.0
	chips.angular_velocity_max = 400.0
	chips.material_override = get_structure_material(material_data)
	root.add_child(chips)
	chips.global_position = pos
	chips.emitting = true

	var dust := _make_dust_emitter(color, 4, 0.9, 0.35)
	dust.direction = normal
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.3
	root.add_child(dust)
	dust.global_position = pos + normal * 0.05
	dust.emitting = true

	_free_later(chips, 0.9)
	_free_later(dust, 1.2)

func _make_dust_emitter(color: Color, amount: int, lifetime: float, size_scale: float) -> CPUParticles3D:
	var d := CPUParticles3D.new()
	d.one_shot = true
	d.explosiveness = 0.85
	d.amount = amount
	d.lifetime = lifetime
	d.mesh = _dust_quad
	d.material_override = _get_dust_material(color)
	d.spread = 70.0
	d.gravity = Vector3(0, 0.25, 0)
	d.damping_min = 1.5
	d.damping_max = 3.0
	d.scale_amount_min = size_scale * 0.7
	d.scale_amount_max = size_scale * 1.4
	d.scale_amount_curve = _dust_curve
	d.color_ramp = _dust_ramp
	d.angle_min = -180.0
	d.angle_max = 180.0
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return d

func _spawn_dust_cloud(pos: Vector3, color: Color) -> void:
	if not _check_fx_budget(false):
		return
	var root := get_tree().current_scene
	if not root:
		return
	var cloud := _make_dust_emitter(color, 7, 1.8, 1.6)
	cloud.direction = Vector3.UP
	cloud.spread = 180.0
	cloud.initial_velocity_min = 0.6
	cloud.initial_velocity_max = 1.8
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cloud.emission_sphere_radius = 0.4
	root.add_child(cloud)
	cloud.global_position = pos
	cloud.emitting = true
	_free_later(cloud, 2.2)

func _spawn_sparks(pos: Vector3, normal: Vector3) -> void:
	if not _check_fx_budget(false):
		return
	var root := get_tree().current_scene
	if not root:
		return
	var s := CPUParticles3D.new()
	s.one_shot = true
	s.explosiveness = 1.0
	s.amount = 10
	s.lifetime = 0.28
	var q := QuadMesh.new()
	q.size = Vector2(0.015, 0.09)
	s.mesh = q
	var m := _make_emissive_mat(Color(1.0, 0.72, 0.28), 6.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material_override = m
	s.direction = normal
	s.spread = 55.0
	s.initial_velocity_min = 3.5
	s.initial_velocity_max = 7.0
	s.gravity = Vector3(0, -12.0, 0)
	s.particle_flag_align_y = true
	root.add_child(s)
	s.global_position = pos
	s.emitting = true
	_free_later(s, 0.5)

func _free_later(node: Node, delay: float) -> void:
	var t := node.create_tween()
	t.tween_interval(delay)
	t.tween_callback(func():
		if is_instance_valid(node):
			node.queue_free()
	)

func _spawn_shatter_shards(origin: Vector3) -> void:
	if not _check_fx_budget(true):
		return
	var root := get_tree().current_scene
	if not root:
		return

	var shard_mat: Material = get_structure_material(material_data)
	for i in range(4):
		var size: float = randf_range(0.16, 0.32)
		var shard := RigidBody3D.new()
		shard.collision_layer = 16
		shard.collision_mask = 1
		shard.mass = 2.0 * size * 4.0

		var mi := MeshInstance3D.new()
		mi.mesh = _rock_meshes[randi() % _rock_meshes.size()]
		mi.scale = Vector3.ONE * size
		mi.material_override = shard_mat
		mi.set_instance_shader_parameter(&"local_mode", 1.0)
		mi.set_instance_shader_parameter(&"damage", 0.6)
		shard.add_child(mi)

		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = size * 0.42
		cs.shape = sph
		shard.add_child(cs)

		root.add_child(shard)
		shard.global_position = origin + Vector3(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
		shard.linear_velocity = Vector3(randf_range(-3.5, 3.5), randf_range(1.4, 4.4), randf_range(-3.5, 3.5))
		shard.angular_velocity = Vector3(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))

		var t := shard.create_tween()
		t.tween_interval(1.4)
		t.tween_property(mi, "scale", Vector3.ONE * size * 0.05, 0.3)
		t.tween_callback(func():
			if is_instance_valid(shard):
				shard.queue_free()
		)
