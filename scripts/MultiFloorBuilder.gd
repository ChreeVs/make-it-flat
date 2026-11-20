class_name MultiFloorBuilder
extends StructureManager

@export var building_width: int = 8
@export var building_depth: int = 7
@export var floors: int = 3
@export var floor_height: int = 4

func _ready() -> void:
	if get_child_count() == 0:
		generate_building()
	super._ready()

func generate_building() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_brick_dry: MaterialData = load("res://data/materials/brick_dry.tres")
	var mat_brick_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	var total_height: int = floors * floor_height
	# ESATTAMENTE 6 pilastri portanti in cemento armato (3 su X x 2 su Z) per Sprint 5 C4
	var col_x: Array[int] = [0, int(building_width * 0.5), building_width - 1]
	var col_z: Array[int] = [0, building_depth - 1]

	for y in range(total_height):
		var local_y: int = y % floor_height
		var is_slab_level: bool = (local_y == floor_height - 1)

		for z in range(building_depth):
			for x in range(building_width):
				var is_col: bool = col_x.has(x) and col_z.has(z)
				var is_front_back: bool = (z == 0 or z == building_depth - 1)
				var is_side: bool = (x == 0 or x == building_width - 1)
				var is_perimeter: bool = is_front_back or is_side

				if is_perimeter or is_col:
					# Ingresso principale al piano terra (+Z)
					if z == building_depth - 1 and (x == 2 or x == 3) and y <= 1:
						continue
					# Non sovrapporre alla scala interna (x=1 è interno)
					var block: DestructibleBlock = block_scene.instantiate()
					if is_col:
						block.material_data = mat_concrete
						block.block_shape = DestructibleBlock.BlockShape.PILLAR
					elif z == building_depth - 1 and (x == 2 or x == 3) and y == 2:
						block.material_data = mat_concrete
						block.block_shape = DestructibleBlock.BlockShape.DOOR_LINTEL_X
					elif is_slab_level:
						block.material_data = mat_concrete
						block.block_shape = DestructibleBlock.BlockShape.BEAM_X if is_front_back else DestructibleBlock.BlockShape.BEAM_Z
					elif local_y == 1 and is_front_back and (x == 2 or x == 5):
						block.material_data = mat_brick_hollow
						block.block_shape = DestructibleBlock.BlockShape.WINDOW_X
					elif local_y == 1 and is_side and (z == 2 or z == 4):
						block.material_data = mat_brick_hollow
						block.block_shape = DestructibleBlock.BlockShape.WINDOW_Z
					else:
						block.material_data = mat_brick_dry if local_y == 0 else mat_brick_hollow
						block.block_shape = DestructibleBlock.BlockShape.WALL_X if is_front_back else DestructibleBlock.BlockShape.WALL_Z

					block.position = Vector3(
						float(x - int(building_width * 0.5)) * block_size,
						(float(y) + 0.5) * block_size,
						float(z - int(building_depth * 0.5)) * block_size
					)
					block.name = "Palazzina_%d_%d_%d" % [x, y, z]
					block.grid_coord = Vector3i(x, y, z)
					if y == 0 and is_col:
						block.is_anchored = true
					add_child(block)

				elif is_slab_level:
					# Solette calpestabili di ogni piano (lascia tromba scale su x=1, z=1..4)
					if x == 1 and (z >= 1 and z <= 4):
						continue
					var slab: DestructibleBlock = block_scene.instantiate()
					slab.material_data = mat_concrete
					slab.block_shape = DestructibleBlock.BlockShape.SLAB
					slab.position = Vector3(
						float(x - int(building_width * 0.5)) * block_size,
						(float(y) + 0.5) * block_size,
						float(z - int(building_depth * 0.5)) * block_size
					)
					slab.name = "Palazzina_Slab_%d_%d_%d" % [x, y, z]
					slab.grid_coord = Vector3i(x, y, z)
					add_child(slab)

	# VANO SCALE INTERNO PERCORRIBILE: collega Piano Terra -> 1° Piano -> 2° Piano -> Terrazza sul Tetto!
	# Ogni piano alterna rampa verso Nord (z=4->1) e verso Sud (z=1->4) lungo la parete ovest (x=1)
	for f in range(floors):
		var base_y: int = f * floor_height
		var going_north: bool = (f % 2 == 0)
		for step_i in range(floor_height):
			var sy: int = base_y + step_i
			var sz: int = (4 - step_i) if going_north else (1 + step_i)
			var stair: DestructibleBlock = block_scene.instantiate()
			stair.material_data = mat_concrete
			stair.block_shape = DestructibleBlock.BlockShape.STAIR_NORTH if going_north else DestructibleBlock.BlockShape.STAIR_SOUTH
			stair.position = Vector3(
				float(1 - int(building_width * 0.5)) * block_size,
				(float(sy) + 0.5) * block_size,
				float(sz - int(building_depth * 0.5)) * block_size
			)
			stair.name = "Palazzina_Stair_%d_%d" % [f, step_i]
			stair.grid_coord = Vector3i(1, sy, sz)
			add_child(stair)
