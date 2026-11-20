class_name SkyscraperBuilder
extends StructureManager

@export var tower_width: int = 14     # 7 metri
@export var tower_depth: int = 14     # 7 metri
@export var tower_height: int = 28    # 14 metri (7 piani totali)
@export var spire_height: int = 8     # Guglia/Antenna sommitale

func _ready() -> void:
	if get_child_count() == 0:
		generate_skyscraper()
	super._ready()

func generate_skyscraper() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_steel: MaterialData = load("res://data/materials/steel_beam.tres")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_brick: MaterialData = load("res://data/materials/brick_dry.tres")

	var half_w: int = int(tower_width * 0.5)
	var half_d: int = int(tower_depth * 0.5)

	# 1. 8 Grandi Colonne Portanti Perimetrali in Acciaio Pesante
	var col_x: Array[int] = [0, half_w, tower_width - 1]
	var col_z: Array[int] = [0, half_w, tower_depth - 1]

	# Core centrale in cemento armato (vano 4 ascensori e impianti)
	var core_x_min: int = half_w - 2
	var core_x_max: int = half_w + 1
	var core_z_min: int = half_d - 2
	var core_z_max: int = half_d + 1

	for y in range(tower_height):
		var is_slab: bool = (y > 0 and (y % 4 == 0 or y == tower_height - 1))
		var is_penthouse: bool = (y >= tower_height - 4)

		for z in range(tower_depth):
			for x in range(tower_width):
				var is_corner_col: bool = (x == 0 or x == tower_width - 1) and (z == 0 or z == tower_depth - 1)
				var is_perimeter_col: bool = (col_x.has(x) and (z == 0 or z == tower_depth - 1)) or (col_z.has(z) and (x == 0 or x == tower_width - 1))
				var is_core: bool = (x >= core_x_min and x <= core_x_max and z >= core_z_min and z <= core_z_max)
				var is_perimeter: bool = (x == 0 or x == tower_width - 1 or z == 0 or z == tower_depth - 1)

				# Penthouse rientrato di 1 blocco
				if is_penthouse and is_perimeter:
					continue

				if not is_slab:
					if y == 0 and not is_perimeter_col and not is_core:
						continue
					if not is_perimeter and not is_perimeter_col and not is_core:
						continue

					# Piano terra: Grande atrio vetrato a doppia altezza
					if y < 4 and not is_perimeter_col and not is_core:
						continue

					# Facciata continua a nastro (vetrate perimetrali aperte a intervalli di piano)
					if not is_perimeter_col and not is_core and (y % 4 == 2 or y % 4 == 3):
						# Fasce finestre vetrate aperte
						if (x % 3 != 0 and z % 3 != 0):
							continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_perimeter_col:
					block.material_data = mat_steel
				elif is_core or is_slab:
					block.material_data = mat_concrete
				else:
					block.material_data = mat_concrete if (y % 4 == 0 or y % 4 == 1) else mat_brick

				var x_pos: float = float(x - half_w) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - half_d) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Tower_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and (is_perimeter_col or is_core):
					block.is_anchored = true

				add_child(block)

	# 2. ELIPORTO SOMMITALE E PARAPETTO (Helipad sul tetto)
	var helipad_y: int = tower_height
	for z in range(2, tower_depth - 2):
		for x in range(2, tower_width - 2):
			var is_edge: bool = (x == 2 or x == tower_width - 3 or z == 2 or z == tower_depth - 3)
			# Marcature 'H' centrale in acciaio
			var is_h_cross: bool = (abs(z - half_d) <= 1 and (abs(x - half_w) == 2 or (z == half_d and abs(x - half_w) <= 2)))

			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_steel if (is_edge or is_h_cross) else mat_concrete

			var x_pos: float = float(x - half_w) * block_size
			var y_pos: float = (float(helipad_y) + 0.5) * block_size
			var z_pos: float = float(z - half_d) * block_size

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "Helipad_%d_%d" % [x, z]
			block.grid_coord = Vector3i(x, helipad_y, z)
			add_child(block)

	# 3. GUGLIA / ANTENNA DI TELECOMUNICAZIONE
	for ay in range(helipad_y + 1, helipad_y + 1 + spire_height):
		var ant: DestructibleBlock = block_scene.instantiate()
		ant.material_data = mat_steel
		var x_pos: float = 0.0
		var y_pos: float = (float(ay) + 0.5) * block_size
		var z_pos: float = 0.0

		ant.position = Vector3(x_pos, y_pos, z_pos)
		ant.name = "Spire_%d" % ay
		ant.grid_coord = Vector3i(half_w, ay, half_d)
		add_child(ant)
