class_name CondominiumBuilder
extends StructureManager

@export var building_width: int = 16  # 8 metri
@export var building_depth: int = 12  # 6 metri
@export var floors: int = 4           # 4 piani (Terra + 3 piani)
@export var floor_height: int = 4     # 2 metri per piano

func _ready() -> void:
	if get_child_count() == 0:
		generate_condominium()
	super._ready()

func generate_condominium() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_brick: MaterialData = load("res://data/materials/brick_dry.tres")
	var mat_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	var total_height: int = floors * floor_height
	var half_w: int = int(building_width * 0.5)
	var half_d: int = int(building_depth * 0.5)

	# 6 pilastri portanti perimetrali e vano scale/ascensore centrale
	var col_x: Array[int] = [0, half_w, building_width - 1]
	var col_z: Array[int] = [0, building_depth - 1]

	# Core centrale vano scale/ascensore (2x2 blocchi in cemento al centro)
	var core_x_min: int = half_w - 1
	var core_x_max: int = half_w
	var core_z_min: int = half_d - 1
	var core_z_max: int = half_d

	for y in range(total_height):
		var floor_idx: int = y / floor_height
		var local_y: int = y % floor_height
		var is_slab: bool = (local_y == floor_height - 1)

		for z in range(building_depth):
			for x in range(building_width):
				var is_col: bool = col_x.has(x) and col_z.has(z)
				var is_core: bool = (x >= core_x_min and x <= core_x_max and z >= core_z_min and z <= core_z_max)
				var is_perimeter: bool = (x == 0 or x == building_width - 1 or z == 0 or z == building_depth - 1)
				# Tramezzo interno divisorio appartamenti
				var is_divider: bool = (x == half_w and not is_core)

				if is_slab:
					# Soletta del piano (lascia vuoto solo il vano scale per permettere il passaggio verticale)
					if is_core and (x == core_x_min and z == core_z_min):
						continue
				else:
					# A terra (y=0) poggiano solo pilastri, nucleo ascensore e perimetro
					if y == 0 and not is_col and not is_core and not is_perimeter:
						continue
					if not is_perimeter and not is_col and not is_core and not is_divider:
						continue

					# Portone d'ingresso al piano terra (fronte +Z, centro)
					if floor_idx == 0 and z == building_depth - 1 and abs(x - half_w) <= 1 and local_y < 3:
						continue

					# Porte interne corridoio
					if is_divider and (z == 2 or z == building_depth - 3) and local_y < 3:
						continue

					# Finestre appartamenti (piani 1, 2, 3)
					if floor_idx > 0 and not is_col and (local_y == 1 or local_y == 2):
						# Finestre fronte e retro
						if (z == 0 or z == building_depth - 1) and (x == 2 or x == 3 or x == building_width - 4 or x == building_width - 3):
							continue
						# Finestre laterali
						if (x == 0 or x == building_width - 1) and (z == 3 or z == building_depth - 4):
							continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_col or is_core or is_slab:
					block.material_data = mat_concrete
				elif floor_idx == 0 or local_y == 0:
					block.material_data = mat_brick
				else:
					block.material_data = mat_hollow

				var x_pos: float = float(x - half_w) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - half_d) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Condo_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and (is_col or is_core):
					block.is_anchored = true

				add_child(block)

		# Balconi aggettanti sui piani superiori (piani 1, 2, 3)
		if floor_idx > 0 and is_slab:
			for bx in range(2, building_width - 2):
				if bx == half_w:
					continue
				var b_slab: DestructibleBlock = block_scene.instantiate()
				b_slab.material_data = mat_concrete
				var bx_pos: float = float(bx - half_w) * block_size
				var by_pos: float = (float(y) + 0.5) * block_size
				var bz_pos: float = float(building_depth - half_d) * block_size
				b_slab.position = Vector3(bx_pos, by_pos, bz_pos)
				b_slab.name = "Balcony_Slab_%d_%d" % [bx, y]
				b_slab.grid_coord = Vector3i(bx, y, building_depth)
				add_child(b_slab)

				# Ringhiera del balcone
				var b_rail: DestructibleBlock = block_scene.instantiate()
				b_rail.material_data = mat_brick
				b_rail.position = Vector3(bx_pos, by_pos + block_size, bz_pos)
				b_rail.name = "Balcony_Rail_%d_%d" % [bx, y + 1]
				b_rail.grid_coord = Vector3i(bx, y + 1, building_depth)
				add_child(b_rail)

	# Parapetto di protezione sul tetto piano (muretto perimetrale)
	var roof_parapet_y: int = total_height
	for z in range(building_depth):
		for x in range(building_width):
			var is_edge: bool = (x == 0 or x == building_width - 1 or z == 0 or z == building_depth - 1)
			var is_penthouse: bool = (x >= core_x_min - 1 and x <= core_x_max + 1 and z >= core_z_min - 1 and z <= core_z_max + 1)
			if not is_edge and not is_penthouse:
				continue

			var p_block: DestructibleBlock = block_scene.instantiate()
			p_block.material_data = mat_concrete if is_penthouse else mat_brick
			var x_pos: float = float(x - half_w) * block_size
			var y_pos: float = (float(roof_parapet_y) + 0.5) * block_size
			var z_pos: float = float(z - half_d) * block_size

			p_block.position = Vector3(x_pos, y_pos, z_pos)
			p_block.name = "Parapet_%d_%d" % [x, z]
			p_block.grid_coord = Vector3i(x, roof_parapet_y, z)
			add_child(p_block)
