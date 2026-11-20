class_name WarehouseBuilder
extends StructureManager

@export var warehouse_width: int = 12
@export var warehouse_depth: int = 10
@export var warehouse_height: int = 7

func _ready() -> void:
	if get_child_count() == 0:
		generate_warehouse()
	super._ready()

func generate_warehouse() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_steel: MaterialData = load("res://data/materials/steel_beam.tres")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	# 6 piloni industriali in acciaio pesante lungo i fianchi (soli ancorati a terra y=0)
	var col_x: Array[int] = [0, warehouse_width - 1]
	var col_z: Array[int] = [0, int(warehouse_depth * 0.5), warehouse_depth - 1]

	for y in range(warehouse_height - 1):
		for z in range(warehouse_depth):
			for x in range(warehouse_width):
				var is_col: bool = col_x.has(x) and col_z.has(z)
				var is_front_back: bool = (z == 0 or z == warehouse_depth - 1)
				var is_side: bool = (x == 0 or x == warehouse_width - 1)
				if not is_front_back and not is_side:
					continue

				# Ampia baia di carico camion sul fronte (+Z)
				if z == warehouse_depth - 1 and (x >= 3 and x <= warehouse_width - 4) and y <= 3:
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_col:
					block.material_data = mat_steel
					block.block_shape = DestructibleBlock.BlockShape.PILLAR
				elif z == warehouse_depth - 1 and (x >= 3 and x <= warehouse_width - 4) and y == 4:
					block.material_data = mat_steel
					block.block_shape = DestructibleBlock.BlockShape.DOOR_LINTEL_X
				elif is_side and y == 4 and (z % 2 == 1):
					block.material_data = mat_concrete
					block.block_shape = DestructibleBlock.BlockShape.WINDOW_Z
				elif y == warehouse_height - 2:
					block.material_data = mat_steel
					block.block_shape = DestructibleBlock.BlockShape.BEAM_X if is_front_back else DestructibleBlock.BlockShape.BEAM_Z
				else:
					block.material_data = mat_concrete if y == 0 else mat_hollow
					block.block_shape = DestructibleBlock.BlockShape.WALL_X if is_front_back else DestructibleBlock.BlockShape.WALL_Z

				block.position = Vector3(
					float(x - int(warehouse_width * 0.5)) * block_size,
					(float(y) + 0.5) * block_size,
					float(z - int(warehouse_depth * 0.5)) * block_size
				)
				block.name = "WH_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_col:
					block.is_anchored = true
				add_child(block)

	# SCALA METALLICA INTERNA lungo il lato ovest (x=1, z=6..3, y=0..3) verso la passerella sopraelevata!
	for step_i in range(4):
		var stair: DestructibleBlock = block_scene.instantiate()
		stair.material_data = mat_steel
		stair.block_shape = DestructibleBlock.BlockShape.STAIR_NORTH
		stair.position = Vector3(
			float(1 - int(warehouse_width * 0.5)) * block_size,
			(float(step_i) + 0.5) * block_size,
			float((6 - step_i) - int(warehouse_depth * 0.5)) * block_size
		)
		stair.name = "WH_Stair_%d" % step_i
		stair.grid_coord = Vector3i(1, step_i, 6 - step_i)
		add_child(stair)

	# Passerella sopraelevata / soppalco uffici in acciaio sul fondo nord (z=1..2, y=3)
	for z in range(1, 3):
		for x in range(1, warehouse_width - 1):
			var catwalk: DestructibleBlock = block_scene.instantiate()
			catwalk.material_data = mat_steel if z == 2 else mat_concrete
			catwalk.block_shape = DestructibleBlock.BlockShape.SLAB
			catwalk.position = Vector3(
				float(x - int(warehouse_width * 0.5)) * block_size,
				(3.5) * block_size,
				float(z - int(warehouse_depth * 0.5)) * block_size
			)
			catwalk.name = "WH_Catwalk_%d_%d" % [x, z]
			catwalk.grid_coord = Vector3i(x, 3, z)
			add_child(catwalk)

	# Copertura industriale con travi reticolari in acciaio e solette in cemento
	var roof_y: int = warehouse_height - 1
	for z in range(warehouse_depth):
		for x in range(warehouse_width):
			var block: DestructibleBlock = block_scene.instantiate()
			var is_truss: bool = col_z.has(z) or x == 0 or x == warehouse_width - 1
			block.material_data = mat_steel if is_truss else mat_concrete
			block.block_shape = DestructibleBlock.BlockShape.BEAM_X if (col_z.has(z) and x > 0 and x < warehouse_width - 1) else DestructibleBlock.BlockShape.SLAB
			block.position = Vector3(
				float(x - int(warehouse_width * 0.5)) * block_size,
				(float(roof_y) + 0.5) * block_size,
				float(z - int(warehouse_depth * 0.5)) * block_size
			)
			block.name = "WH_Roof_%d_%d_%d" % [x, roof_y, z]
			block.grid_coord = Vector3i(x, roof_y, z)
			add_child(block)
