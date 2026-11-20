class_name SkyscraperBuilder
extends StructureManager

# Grattacielo Gigante completamente arredato (Lobby & Bar, Uffici & Bagni, Appartamenti, Ristorante, Suite, Server Room, Eliporto)
# Il numero di piani si adatta automaticamente alla difficoltà scelta (Facile: 4, Normale: 6, Hardcore: 8).
@export var width: int = 11
@export var depth: int = 9
@export var floor_height: int = 4
@export var override_floors: int = 0 # 0 = usa EconomyManager.get_target_skyscraper_floors()

const FLOOR_THEME_NAMES: Array[String] = [
	"Hall, Reception & Caffetteria Bar",
	"Uffici Open-Space, Sala Riunioni & Bagni",
	"Appartamenti Residenziali Arredati",
	"Ristorante Panoramico & Sky Bar",
	"Suite Direzionale & Lounge VIP",
	"Sala Server IT & Uffici Tecnici",
	"Appartamenti Panoramici di Lusso",
	"Attico Presidenziale & Penthouse"
]

var _block_scene: PackedScene
var _mat_steel: MaterialData
var _mat_concrete: MaterialData
var _mat_brick: MaterialData
var _mat_drywall: MaterialData
var _mat_marble: MaterialData
var _mat_furn_wood: MaterialData
var _mat_fabric: MaterialData
var _mat_ceramic: MaterialData
var _mat_appliance: MaterialData
var _placed: Dictionary = {}

func _ready() -> void:
	if get_child_count() == 0:
		generate_skyscraper()
	super._ready()

func _add_b(
	coord: Vector3i,
	mat: MaterialData,
	shape: DestructibleBlock.BlockShape,
	anchored: bool = false,
	f_idx: int = -1,
	display_name: String = "",
	yaw_deg: float = 0.0
) -> void:
	if _placed.has(coord):
		return
	_placed[coord] = true

	var block := _block_scene.instantiate() as DestructibleBlock
	block.material_data = mat
	block.is_anchored = anchored
	block.grid_coord = coord
	block.block_shape = shape
	block.floor_index = f_idx
	block.custom_display_name = display_name
	block.prop_yaw_deg = yaw_deg
	block.name = "Sky_%d_%d_%d" % [coord.x, coord.y, coord.z]

	var offset_x: float = (float(width) - 1.0) * 0.5
	var offset_z: float = (float(depth) - 1.0) * 0.5
	block.position = Vector3(float(coord.x) - offset_x, float(coord.y) + 0.5, float(coord.z) - offset_z)
	add_child(block)

func _is_stair_well(x: int, z: int) -> bool:
	return (x == 1 or x == 2) and (z >= 2 and z <= 5)

func generate_skyscraper() -> void:
	_placed.clear()
	floor_names.clear()

	_block_scene = load("res://scenes/structures/DestructibleBlock.tscn")
	_mat_steel = load("res://data/materials/steel_beam.tres")
	_mat_concrete = load("res://data/materials/concrete_reinforced.tres")
	_mat_brick = load("res://data/materials/brick_dry.tres")
	_mat_drywall = load("res://data/materials/drywall_interior.tres")
	_mat_marble = load("res://data/materials/marble_floor.tres")
	_mat_furn_wood = load("res://data/materials/furniture_wood.tres")
	_mat_fabric = load("res://data/materials/fabric_sofa.tres")
	_mat_ceramic = load("res://data/materials/ceramic_tile.tres")
	_mat_appliance = load("res://data/materials/appliance_metal.tres")

	var num_floors: int = override_floors if override_floors > 0 else EconomyManager.get_target_skyscraper_floors()
	num_floors = clampi(num_floors, 3, 8)
	var total_top_y: int = num_floors * floor_height + 1

	# 1. BASAMENTO MARMOREO / CEMENTO (y = 0) + 4 MEGA-COLONNE IN ACCIAIO ANCORATE A TERRA
	for x in range(width):
		for z in range(depth):
			var is_corner: bool = (x == 0 or x == width - 1) and (z == 0 or z == depth - 1)
			if is_corner:
				_add_b(Vector3i(x, 0, z), _mat_steel, DestructibleBlock.BlockShape.PILLAR, true, 0, "Mega-Colonna Portante")
			else:
				var base_mat: MaterialData = _mat_marble if (z >= 3 and x >= 2 and x <= 8) else _mat_concrete
				_add_b(Vector3i(x, 0, z), base_mat, DestructibleBlock.BlockShape.SLAB_BOTTOM, false, 0, "Pavimento Hall")

	# Rampa d'ingresso sul lato Sud (z = depth)
	for ex in [4, 5, 6]:
		_add_b(Vector3i(ex, 0, depth), _mat_marble, DestructibleBlock.BlockShape.STAIR_NORTH, false, 0, "Gradini Ingresso")

	# 2. GENERAZIONE DI TUTTI I PIANI ARREDATI (0 .. num_floors - 1)
	for f in range(num_floors):
		var base_y: int = 1 + f * floor_height
		var theme_name: String = FLOOR_THEME_NAMES[f % FLOOR_THEME_NAMES.size()]
		floor_names[f] = "Piano %d — %s" % [f, theme_name]

		for dy in range(floor_height):
			var y: int = base_y + dy
			var is_slab_row: bool = (dy == floor_height - 1)

			if is_slab_row:
				for x in range(width):
					for z in range(depth):
						var is_corner: bool = (x == 0 or x == width - 1) and (z == 0 or z == depth - 1)
						if is_corner:
							_add_b(Vector3i(x, y, z), _mat_steel, DestructibleBlock.BlockShape.PILLAR, false, f, "Colonna Acciaio")
						elif _is_stair_well(x, z):
							continue
						else:
							var slab_mat: MaterialData = _mat_marble if (f == 0 and z >= 4) else _mat_concrete
							_add_b(Vector3i(x, y, z), slab_mat, DestructibleBlock.BlockShape.SLAB, false, f, "Soletta Piano %d" % (f + 1))
			else:
				for x in range(width):
					for z in range(depth):
						var on_x_edge: bool = (x == 0 or x == width - 1)
						var on_z_edge: bool = (z == 0 or z == depth - 1)
						if not on_x_edge and not on_z_edge:
							continue

						var is_corner: bool = on_x_edge and on_z_edge
						var is_mid_col: bool = (on_z_edge and x == 5) or (on_x_edge and z == 4)
						if is_corner:
							_add_b(Vector3i(x, y, z), _mat_steel, DestructibleBlock.BlockShape.PILLAR, false, f, "Colonna Acciaio")
						elif is_mid_col:
							_add_b(Vector3i(x, y, z), _mat_concrete, DestructibleBlock.BlockShape.PILLAR, false, f, "Pilastro Cemento")
						elif f == 0 and z == depth - 1 and x >= 4 and x <= 6:
							if dy == 2:
								_add_b(Vector3i(x, y, z), _mat_marble, DestructibleBlock.BlockShape.DOOR_LINTEL_X, false, f, "Architrave Ingresso")
						elif dy == 0:
							if z == depth - 1 and x >= 2 and x <= 8:
								_add_b(Vector3i(x, y, z), _mat_drywall, DestructibleBlock.BlockShape.WINDOW_X, false, f, "Vetrata Panoramica")
							elif on_z_edge:
								_add_b(Vector3i(x, y, z), _mat_brick if f < 2 else _mat_concrete, DestructibleBlock.BlockShape.WALL_X, false, f, "Parapetto Facciata")
							else:
								_add_b(Vector3i(x, y, z), _mat_brick if f < 2 else _mat_concrete, DestructibleBlock.BlockShape.WALL_Z, false, f, "Parapetto Facciata")
						else:
							if x == 0 and z >= 1 and z <= 5:
								_add_b(Vector3i(x, y, z), _mat_concrete, DestructibleBlock.BlockShape.WALL_Z, false, f, "Muro Vano Scale")
							elif on_z_edge:
								_add_b(Vector3i(x, y, z), _mat_drywall, DestructibleBlock.BlockShape.WINDOW_X, false, f, "Vetrata Panoramica")
							else:
								_add_b(Vector3i(x, y, z), _mat_drywall, DestructibleBlock.BlockShape.WINDOW_Z, false, f, "Vetrata Panoramica")

		# Vano Scale Interno Percorribile Largo 2 Metri (rampe alternate piano per piano fino al tetto)
		var stair_shape: DestructibleBlock.BlockShape = (
			DestructibleBlock.BlockShape.STAIR_SOUTH if (f % 2 == 0) else DestructibleBlock.BlockShape.STAIR_NORTH
		)
		for step in range(floor_height):
			var sz: int = (2 + step) if (f % 2 == 0) else (5 - step)
			var sy: int = base_y + step
			_add_b(Vector3i(1, sy, sz), _mat_concrete, stair_shape, false, f, "Scala Interna")
			_add_b(Vector3i(2, sy, sz), _mat_concrete, stair_shape, false, f, "Scala Interna")

		match (f % 6):
			0: _furnish_lobby_and_bar(base_y, f)
			1: _furnish_offices_and_bathrooms(base_y, f)
			2: _furnish_apartments(base_y, f)
			3: _furnish_restaurant_and_skybar(base_y, f)
			4: _furnish_executive_suite(base_y, f)
			5: _furnish_server_room_and_tech(base_y, f)

	# 3. TETTO PANORAMICO: PARAPETTO, ELIPORTO, HVAC & TERRAZZA
	var roof_y: int = total_top_y
	var roof_f: int = num_floors
	floor_names[roof_f] = "Tetto & Eliporto"
	for x in range(width):
		for z in range(depth):
			if x == 0 or x == width - 1 or z == 0 or z == depth - 1:
				var is_corner: bool = (x == 0 or x == width - 1) and (z == 0 or z == depth - 1)
				if is_corner:
					_add_b(Vector3i(x, roof_y, z), _mat_steel, DestructibleBlock.BlockShape.PILLAR, false, roof_f, "Torretta Angolare")
				elif z == 0 or z == depth - 1:
					_add_b(Vector3i(x, roof_y, z), _mat_concrete, DestructibleBlock.BlockShape.WALL_X, false, roof_f, "Parapetto Tetto")
				else:
					_add_b(Vector3i(x, roof_y, z), _mat_concrete, DestructibleBlock.BlockShape.WALL_Z, false, roof_f, "Parapetto Tetto")

	_add_b(Vector3i(4, roof_y, 2), _mat_appliance, DestructibleBlock.BlockShape.FURN_HVAC_UNIT, false, roof_f, "Unità Clima HVAC")
	_add_b(Vector3i(5, roof_y, 2), _mat_appliance, DestructibleBlock.BlockShape.FURN_HVAC_UNIT, false, roof_f, "Unità Clima HVAC")
	_add_b(Vector3i(8, roof_y, 2), _mat_appliance, DestructibleBlock.BlockShape.FURN_HVAC_UNIT, false, roof_f, "Unità Clima HVAC")
	_add_b(Vector3i(8, roof_y, 6), _mat_fabric, DestructibleBlock.BlockShape.FURN_SOFA, false, roof_f, "Divano Terrazza", 180.0)
	_add_b(Vector3i(9, roof_y, 6), _mat_fabric, DestructibleBlock.BlockShape.FURN_SOFA, false, roof_f, "Divano Terrazza", 180.0)
	_add_b(Vector3i(8, roof_y, 5), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_TABLE, false, roof_f, "Tavolino Terrazza")
	_add_b(Vector3i(3, roof_y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_PLANT, false, roof_f, "Fioriera Terrazza")
	_add_b(Vector3i(9, roof_y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_PLANT, false, roof_f, "Fioriera Terrazza")

# --- PIANO 0: HALL RECEPTION, LOUNGE, CAFFETTERIA BAR & BAGNO ---
func _furnish_lobby_and_bar(y: int, f: int) -> void:
	# Bagno Hall (Nord-Centro, x=4..6, z=1..2)
	_build_partition_z(3, 1, 2, y, f, _mat_ceramic, 2)
	_build_partition_z(6, 1, 2, y, f, _mat_ceramic, 2)
	_add_b(Vector3i(4, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_TOILET, false, f, "WC Hall", 0.0)
	_add_b(Vector3i(5, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_SINK, false, f, "Lavabo & Specchio", 0.0)

	# Reception Hall
	_add_b(Vector3i(4, y, 4), _mat_marble, DestructibleBlock.BlockShape.FURN_BAR_COUNTER, false, f, "Bancone Reception", 0.0)
	_add_b(Vector3i(5, y, 4), _mat_marble, DestructibleBlock.BlockShape.FURN_BAR_COUNTER, false, f, "Bancone Reception", 0.0)
	_add_b(Vector3i(4, y, 3), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Poltrona Reception", 0.0)
	_add_b(Vector3i(3, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_PLANT, false, f, "Pianta Hall")
	_add_b(Vector3i(7, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_PLANT, false, f, "Pianta Hall")

	# Zona Lounge Attesa (Ovest)
	_add_b(Vector3i(1, y, 7), _mat_fabric, DestructibleBlock.BlockShape.FURN_SOFA, false, f, "Divano Lounge", 90.0)
	_add_b(Vector3i(2, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_TABLE, false, f, "Tavolino Lounge")

	# Caffetteria & Cocktail Bar (Est, x=7..9)
	for bz in [2, 3, 4]:
		_add_b(Vector3i(8, y, bz), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BAR_COUNTER, false, f, "Bancone Bar", -90.0)
		_add_b(Vector3i(7, y, bz), _mat_fabric, DestructibleBlock.BlockShape.FURN_BAR_STOOL, false, f, "Sgabello Bar")
	_add_b(Vector3i(9, y, 1), _mat_appliance, DestructibleBlock.BlockShape.FURN_FRIDGE, false, f, "Frigo Bar", 0.0)
	_add_b(Vector3i(9, y, 3), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BOOKSHELF, false, f, "Scaffale Bottiglie", -90.0)

	# Tavolini Bistrot del Bar (Sud-Est)
	_add_b(Vector3i(8, y, 6), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_TABLE, false, f, "Tavolino Bar")
	_add_b(Vector3i(7, y, 6), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Sedia Bistrot", 90.0)
	_add_b(Vector3i(9, y, 6), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Sedia Bistrot", -90.0)
	_add_b(Vector3i(9, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_PLANT, false, f, "Pianta Bar")

# --- PIANO 1: UFFICI OPEN-SPACE, SALA RIUNIONI & DOPPI BAGNI ---
func _furnish_offices_and_bathrooms(y: int, f: int) -> void:
	# Doppi Bagni (Nord-Centro, x=4..6, z=1..2)
	_build_partition_z(3, 1, 2, y, f, _mat_ceramic, 2)
	_build_partition_z(5, 1, 2, y, f, _mat_ceramic, 2)
	_build_partition_z(7, 1, 2, y, f, _mat_ceramic, 2)
	_add_b(Vector3i(4, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_TOILET, false, f, "WC Ufficio", 0.0)
	_add_b(Vector3i(6, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_TOILET, false, f, "WC Ufficio", 0.0)
	_add_b(Vector3i(4, y, 2), _mat_ceramic, DestructibleBlock.BlockShape.FURN_SINK, false, f, "Lavabo Bagno", 90.0)
	_add_b(Vector3i(6, y, 2), _mat_ceramic, DestructibleBlock.BlockShape.FURN_SINK, false, f, "Lavabo Bagno", -90.0)

	# Postazioni Lavoro Open-Space con PC
	var desks := [
		[Vector3i(3, y, 7), Vector3i(3, y, 6), 180.0],
		[Vector3i(5, y, 7), Vector3i(5, y, 6), 180.0],
		[Vector3i(4, y, 4), Vector3i(4, y, 5), 0.0],
		[Vector3i(6, y, 4), Vector3i(6, y, 5), 0.0]
	]
	for d in desks:
		_add_b(d[0], _mat_furn_wood, DestructibleBlock.BlockShape.FURN_DESK, false, f, "Scrivania con PC", d[2])
		_add_b(d[1], _mat_fabric, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Sedia Ufficio", d[2])

	_add_b(Vector3i(1, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BOOKSHELF, false, f, "Archivio Ufficio", 180.0)
	_add_b(Vector3i(2, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BOOKSHELF, false, f, "Archivio Ufficio", 180.0)

	# Sala Riunioni (Ala Est)
	_build_partition_z(7, 5, 7, y, f, _mat_drywall, 2)
	for mz in [3, 4, 5]:
		_add_b(Vector3i(9, y, mz), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_TABLE, false, f, "Tavolo Riunioni")
		_add_b(Vector3i(8, y, mz), _mat_fabric, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Poltrona Riunioni", 90.0)
	_add_b(Vector3i(9, y, 1), _mat_appliance, DestructibleBlock.BlockShape.FURN_TV_STAND, false, f, "Maxi Schermo Riunioni", 0.0)

# --- PIANO 2: APPARTAMENTI RESIDENZIALI COMPLETI ---
func _furnish_apartments(y: int, f: int) -> void:
	_build_partition_z(5, 1, 4, y, f, _mat_drywall, 2)
	_build_partition_z(5, 7, 7, y, f, _mat_drywall, 2)

	# Appartamento Ovest (Camera + Bagno con Vasca)
	_add_b(Vector3i(1, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BED, false, f, "Letto Matrimoniale", 90.0)
	_add_b(Vector3i(2, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BED, false, f, "Letto Matrimoniale", 90.0)
	_add_b(Vector3i(4, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BOOKSHELF, false, f, "Armadio Camera", 180.0)
	_build_partition_z(3, 1, 2, y, f, _mat_ceramic, 2)
	_add_b(Vector3i(4, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_TOILET, false, f, "WC Appartamento", 0.0)
	_add_b(Vector3i(4, y, 2), _mat_ceramic, DestructibleBlock.BlockShape.FURN_BATHTUB, false, f, "Vasca da Bagno", 90.0)

	# Appartamento Est (Cucina + Soggiorno TV)
	_add_b(Vector3i(6, y, 1), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_KITCHEN_COUNTER, false, f, "Piano Cucina", 0.0)
	_add_b(Vector3i(7, y, 1), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_KITCHEN_COUNTER, false, f, "Piano Cottura", 0.0)
	_add_b(Vector3i(8, y, 1), _mat_appliance, DestructibleBlock.BlockShape.FURN_FRIDGE, false, f, "Frigorifero Inox", 0.0)
	_add_b(Vector3i(7, y, 3), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_TABLE, false, f, "Tavolo da Pranzo")
	_add_b(Vector3i(6, y, 3), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Sedia Pranzo", 90.0)
	_add_b(Vector3i(8, y, 3), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Sedia Pranzo", -90.0)

	_add_b(Vector3i(6, y, 6), _mat_fabric, DestructibleBlock.BlockShape.FURN_SOFA, false, f, "Divano Soggiorno", 90.0)
	_add_b(Vector3i(6, y, 7), _mat_fabric, DestructibleBlock.BlockShape.FURN_SOFA, false, f, "Divano Soggiorno", 90.0)
	_add_b(Vector3i(9, y, 6), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_TV_STAND, false, f, "Mobile TV Salotto", -90.0)
	_add_b(Vector3i(9, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_PLANT, false, f, "Pianta Salotto")

# --- PIANO 3: RISTORANTE PANORAMICO & SKY BAR ---
func _furnish_restaurant_and_skybar(y: int, f: int) -> void:
	_build_partition_z(6, 1, 2, y, f, _mat_ceramic, 2)
	_add_b(Vector3i(7, y, 1), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_KITCHEN_COUNTER, false, f, "Cucina Ristorante", 0.0)
	_add_b(Vector3i(8, y, 1), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_KITCHEN_COUNTER, false, f, "Fornelli Chef", 0.0)
	_add_b(Vector3i(9, y, 1), _mat_appliance, DestructibleBlock.BlockShape.FURN_FRIDGE, false, f, "Cella Frigo", 0.0)

	_build_partition_z(3, 1, 2, y, f, _mat_ceramic, 2)
	_add_b(Vector3i(4, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_TOILET, false, f, "WC Ristorante", 0.0)
	_add_b(Vector3i(5, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_SINK, false, f, "Lavabo Ristorante", 0.0)

	for bx in [4, 5, 6]:
		_add_b(Vector3i(bx, y, 4), _mat_marble, DestructibleBlock.BlockShape.FURN_BAR_COUNTER, false, f, "Sky Cocktail Bar", 0.0)
		_add_b(Vector3i(bx, y, 5), _mat_fabric, DestructibleBlock.BlockShape.FURN_BAR_STOOL, false, f, "Sgabello Sky Bar")

	for tx in [4, 8]:
		_add_b(Vector3i(tx, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_TABLE, false, f, "Tavolo Ristorante")
		_add_b(Vector3i(tx - 1, y, 7), _mat_fabric, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Sedia Ristorante", 90.0)
		_add_b(Vector3i(tx + 1, y, 7), _mat_fabric, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Sedia Ristorante", -90.0)
	_add_b(Vector3i(1, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_PLANT, false, f, "Pianta Ristorante")

# --- PIANO 4: SUITE DIREZIONALE & LOUNGE VIP ---
func _furnish_executive_suite(y: int, f: int) -> void:
	_add_b(Vector3i(8, y, 3), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_DESK, false, f, "Scrivania CEO", 0.0)
	_add_b(Vector3i(8, y, 2), _mat_fabric, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Poltrona CEO", 0.0)
	_add_b(Vector3i(9, y, 1), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BOOKSHELF, false, f, "Libreria Executive", 0.0)
	_add_b(Vector3i(8, y, 1), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_BOOKSHELF, false, f, "Libreria Executive", 0.0)

	_add_b(Vector3i(3, y, 7), _mat_fabric, DestructibleBlock.BlockShape.FURN_SOFA, false, f, "Divano VIP", 180.0)
	_add_b(Vector3i(4, y, 7), _mat_fabric, DestructibleBlock.BlockShape.FURN_SOFA, false, f, "Divano VIP", 180.0)
	_add_b(Vector3i(4, y, 5), _mat_appliance, DestructibleBlock.BlockShape.FURN_TV_STAND, false, f, "Home Theater VIP", 0.0)
	_add_b(Vector3i(8, y, 7), _mat_marble, DestructibleBlock.BlockShape.FURN_BAR_COUNTER, false, f, "Angolo Bar VIP", 180.0)
	_add_b(Vector3i(9, y, 7), _mat_marble, DestructibleBlock.BlockShape.FURN_BAR_COUNTER, false, f, "Angolo Bar VIP", 180.0)
	_add_b(Vector3i(8, y, 6), _mat_fabric, DestructibleBlock.BlockShape.FURN_BAR_STOOL, false, f, "Sgabello VIP")

	_build_partition_z(3, 1, 2, y, f, _mat_marble, 2)
	_build_partition_z(6, 1, 2, y, f, _mat_marble, 2)
	_add_b(Vector3i(4, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_BATHTUB, false, f, "Vasca Idromassaggio", 0.0)
	_add_b(Vector3i(5, y, 1), _mat_ceramic, DestructibleBlock.BlockShape.FURN_SINK, false, f, "Doppio Lavabo Spa", 0.0)

# --- PIANO 5: SALA SERVER IT & UFFICI TECNICI ---
func _furnish_server_room_and_tech(y: int, f: int) -> void:
	for sx in [4, 6, 8, 9]:
		_add_b(Vector3i(sx, y, 2), _mat_appliance, DestructibleBlock.BlockShape.FURN_SERVER_RACK, false, f, "Rack Server Mainframe", 0.0)
		_add_b(Vector3i(sx, y, 4), _mat_appliance, DestructibleBlock.BlockShape.FURN_SERVER_RACK, false, f, "Rack Server Mainframe", 0.0)

	for dx in [4, 6]:
		_add_b(Vector3i(dx, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_DESK, false, f, "Console Controllo IT", 180.0)
		_add_b(Vector3i(dx, y, 6), _mat_fabric, DestructibleBlock.BlockShape.FURN_CHAIR, false, f, "Sedia Tecnica", 180.0)

	_add_b(Vector3i(8, y, 7), _mat_furn_wood, DestructibleBlock.BlockShape.FURN_KITCHEN_COUNTER, false, f, "Angolo Caffè IT", 180.0)
	_add_b(Vector3i(9, y, 7), _mat_appliance, DestructibleBlock.BlockShape.FURN_FRIDGE, false, f, "Frigo Bevande", 180.0)
	_add_b(Vector3i(1, y, 7), _mat_ceramic, DestructibleBlock.BlockShape.FURN_TOILET, false, f, "WC Tecnico", 90.0)

func _build_partition_z(x: int, z_start: int, z_end: int, base_y: int, f: int, mat: MaterialData, h: int) -> void:
	for dy in range(h):
		for z in range(z_start, z_end + 1):
			_add_b(Vector3i(x, base_y + dy, z), mat, DestructibleBlock.BlockShape.WALL_Z, false, f, "Tramezzo Interno")
