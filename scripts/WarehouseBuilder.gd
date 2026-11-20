class_name WarehouseBuilder
extends StructureManager

@export var warehouse_width: int = 18   # 9 metri
@export var warehouse_depth: int = 16   # 8 metri
@export var warehouse_height: int = 10  # 5 metri

func _ready() -> void:
	if get_child_count() == 0:
		generate_warehouse()
	super._ready()

func generate_warehouse() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_steel: MaterialData = load("res://data/materials/steel_beam.tres")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_brick: MaterialData = load("res://data/materials/brick_dry.tres")
	var mat_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	# 1. Posizioni colonne portanti in acciaio (8 pilastri pesanti)
	var col_x: Array[int] = [0, int(warehouse_width * 0.5), warehouse_width - 1]
	var col_z: Array[int] = [0, int(warehouse_depth * 0.5), warehouse_depth - 1]

	var half_w: int = int(warehouse_width * 0.5)
	var half_d: int = int(warehouse_depth * 0.5)

	# 2. Pareti, Pilastri e Baia di Carico Camion
	for y in range(warehouse_height - 1):
		for z in range(warehouse_depth):
			for x in range(warehouse_width):
				var is_col: bool = col_x.has(x) and col_z.has(z)
				var is_perimeter: bool = (x == 0 or x == warehouse_width - 1 or z == 0 or z == warehouse_depth - 1)

				if y == 0 and not is_col:
					continue
				if not is_perimeter and not is_col:
					continue

				# Ampio portone industriale frontale per camion (+Z, x da half_w - 3 a half_w + 3, altezza y < 6)
				var is_truck_door: bool = (z == warehouse_depth - 1 and abs(x - half_w) <= 3 and y < 6)
				if is_truck_door:
					continue

				# Finestre industriali a nastro in quota sui fianchi (x=0 o x=warehouse_width-1, y=6..7, z a intervalli)
				var is_industrial_window: bool = ((x == 0 or x == warehouse_width - 1) and (y == 6 or y == 7) and (z % 4 >= 1 and z % 4 <= 2))
				if is_industrial_window:
					continue

				# Porta laterale pedonale d'emergenza (x=0, z=3..4, y < 4)
				var is_emergency_door: bool = (x == 0 and (z == 3 or z == 4) and y < 4)
				if is_emergency_door:
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_col:
					block.material_data = mat_steel
				elif y <= 2:
					block.material_data = mat_concrete # Cordolo / zoccolo inferiore anti-urto
				elif y == warehouse_height - 2:
					block.material_data = mat_concrete # Trave perimetrale di coronamento
				else:
					block.material_data = mat_hollow

				var x_pos: float = float(x - half_w) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - half_d) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "WH_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_col:
					block.is_anchored = true

				add_child(block)

	# 3. Travi Reticolari del Tetto (Capriate in acciaio) e Copertura
	var roof_y: int = warehouse_height - 1
	for z in range(warehouse_depth):
		for x in range(warehouse_width):
			# Lucernari centrali trasparenti (lasciati aperti per luce solare zenitale)
			var is_skylight: bool = (abs(x - half_w) <= 1 and (z % 4 == 1 or z % 4 == 2))
			if is_skylight:
				continue

			var block: DestructibleBlock = block_scene.instantiate()
			var is_truss_beam: bool = col_z.has(z) or x == 0 or x == warehouse_width - 1 or x == half_w
			block.material_data = mat_steel if is_truss_beam else mat_concrete

			var x_pos: float = float(x - half_w) * block_size
			var y_pos: float = (float(roof_y) + 0.5) * block_size
			var z_pos: float = float(z - half_d) * block_size

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "Roof_%d_%d_%d" % [x, roof_y, z]
			block.grid_coord = Vector3i(x, roof_y, z)

			add_child(block)

	# 4. Silo Industriale Esterno Annesso (Cilindro di stoccaggio su fianco destro)
	var silo_center_x: int = half_w + 3
	var silo_center_z: int = 0
	var silo_radius: int = 2
	var silo_height: int = warehouse_height + 2

	for sy in range(silo_height):
		for sz in range(-silo_radius, silo_radius + 1):
			for sx in range(-silo_radius, silo_radius + 1):
				var dist_sq: int = sx * sx + sz * sz
				if dist_sq > silo_radius * silo_radius or dist_sq < (silo_radius - 1) * (silo_radius - 1):
					continue
				var world_gx: int = silo_center_x + sx
				var world_gz: int = silo_center_z + sz

				var s_block: DestructibleBlock = block_scene.instantiate()
				s_block.material_data = mat_steel if (sy == 0 or sy == silo_height - 1) else mat_concrete
				var x_pos: float = float(world_gx) * block_size
				var y_pos: float = (float(sy) + 0.5) * block_size
				var z_pos: float = float(world_gz) * block_size

				s_block.position = Vector3(x_pos, y_pos, z_pos)
				s_block.name = "Silo_%d_%d_%d" % [world_gx, sy, world_gz]
				s_block.grid_coord = Vector3i(world_gx + half_w, sy, world_gz + half_d)
				if sy == 0:
					s_block.is_anchored = true

				add_child(s_block)
