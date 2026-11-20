class_name IndustrialPlantBuilder
extends StructureManager

@export var plant_width: int = 20     # 10 metri capannone
@export var plant_depth: int = 14     # 7 metri
@export var plant_height: int = 9     # 4.5 metri
@export var smokestack_height: int = 32 # 16 metri di ciminiera!

func _ready() -> void:
	if get_child_count() == 0:
		generate_plant()
	super._ready()

func generate_plant() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_steel: MaterialData = load("res://data/materials/steel_beam.tres")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_brick: MaterialData = load("res://data/materials/brick_dry.tres")
	var mat_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	var half_w: int = int(plant_width * 0.5)
	var half_d: int = int(plant_depth * 0.5)

	# 1. CAPANNONE INDUSTRIALE CON PILASTRI IN ACCIAIO
	var col_x: Array[int] = [0, int(plant_width * 0.33), int(plant_width * 0.66), plant_width - 1]
	var col_z: Array[int] = [0, plant_depth - 1]

	for y in range(plant_height - 1):
		for z in range(plant_depth):
			for x in range(plant_width):
				var is_col: bool = col_x.has(x) and col_z.has(z)
				var is_perimeter: bool = (x == 0 or x == plant_width - 1 or z == 0 or z == plant_depth - 1)

				if y == 0 and not is_col:
					continue
				if not is_perimeter and not is_col:
					continue

				# Portone merci scorrevole frontale
				if z == plant_depth - 1 and (x >= 7 and x <= 12) and y < 6:
					continue

				# Finestrature industriali alte
				if (x == 0 or x == plant_width - 1) and (y == 5 or y == 6) and (z % 3 == 1):
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_col:
					block.material_data = mat_steel
				elif y <= 1:
					block.material_data = mat_concrete
				elif y == plant_height - 2:
					block.material_data = mat_steel
				else:
					block.material_data = mat_hollow

				var x_pos: float = float(x - half_w) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - half_d) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Plant_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_col:
					block.is_anchored = true

				add_child(block)

	# 2. TETTO INDUSTRIALE A SHED (Dente di sega con lucernari verticali)
	var roof_base_y: int = plant_height - 1
	for z in range(plant_depth):
		for x in range(plant_width):
			# Profilo a denti di sega (ripetizione ogni 4 blocchi su X)
			var tooth_x: int = x % 4
			var tooth_elev: int = tooth_x / 2
			var y_coord: int = roof_base_y + tooth_elev

			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_steel if (tooth_x == 0 or z == 0 or z == plant_depth - 1) else mat_concrete

			var x_pos: float = float(x - half_w) * block_size
			var y_pos: float = (float(y_coord) + 0.5) * block_size
			var z_pos: float = float(z - half_d) * block_size

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "ShedRoof_%d_%d_%d" % [x, y_coord, z]
			block.grid_coord = Vector3i(x, y_coord, z)
			add_child(block)

	# 3. ALTA CIMINIERA INDUSTRIALE IN MATTONI E ANELLI D'ACCIAIO
	# Posizionata a lato del capannone (+X), solida canna fumaria ottagonale/quadrata 3x3
	var stack_center_x: int = half_w + 5
	var stack_center_z: int = 0

	for sy in range(smokestack_height):
		var is_steel_ring: bool = (sy % 6 == 0 or sy == smokestack_height - 1)

		for sz in range(-1, 2):
			for sx in range(-1, 2):
				# Canna fumaria cava all'interno (il centro è vuoto per il fumo)
				if sx == 0 and sz == 0:
					continue

				var gx: int = stack_center_x + sx
				var gz: int = stack_center_z + sz

				var s_block: DestructibleBlock = block_scene.instantiate()
				s_block.material_data = mat_steel if is_steel_ring else (mat_concrete if sy < 3 else mat_brick)

				var x_pos: float = float(gx) * block_size
				var y_pos: float = (float(sy) + 0.5) * block_size
				var z_pos: float = float(gz) * block_size

				s_block.position = Vector3(x_pos, y_pos, z_pos)
				s_block.name = "Smokestack_%d_%d_%d" % [gx, sy, gz]
				s_block.grid_coord = Vector3i(gx + half_w, sy, gz + half_d)
				if sy == 0:
					s_block.is_anchored = true

				add_child(s_block)

	# 4. CONDOTTO DI SCARICO ORIZZONTALE (Collega il capannone alla ciminiera)
	var duct_y: int = 4
	for dx in range(half_w, stack_center_x):
		var d_block: DestructibleBlock = block_scene.instantiate()
		d_block.material_data = mat_steel
		var x_pos: float = float(dx) * block_size
		var y_pos: float = (float(duct_y) + 0.5) * block_size
		var z_pos: float = float(stack_center_z) * block_size

		d_block.position = Vector3(x_pos, y_pos, z_pos)
		d_block.name = "FlueDuct_%d" % dx
		d_block.grid_coord = Vector3i(dx + half_w, duct_y, stack_center_z + half_d)
		add_child(d_block)
