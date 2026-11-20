class_name GarageBuilder
extends StructureManager

@export var garage_width: int = 10
@export var garage_depth: int = 10
@export var garage_height: int = 5

func _ready() -> void:
	if get_child_count() == 0:
		generate_garage()
	super._ready()

func generate_garage() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_brick_dry: MaterialData = load("res://data/materials/brick_dry.tres")
	var mat_brick_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	# Pareti perimetrali, 4 pilastri angolari (soli ancorati a y=0), portone garage e finestre vetrate
	for y in range(garage_height):
		for z in range(garage_depth):
			for x in range(garage_width):
				var is_corner: bool = (x == 0 or x == garage_width - 1) and (z == 0 or z == garage_depth - 1)
				var is_front_back: bool = (z == 0 or z == garage_depth - 1)
				var is_side: bool = (x == 0 or x == garage_width - 1)
				if not is_front_back and not is_side:
					continue

				# Ampio portone garage sul lato frontale (+Z) alto 3 metri
				if z == garage_depth - 1 and (x >= 2 and x <= garage_width - 3) and y <= 2:
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				# Tutti i blocchi sono Tier 2 per coerenza cantiere Tier 2 e TestRunnerSprint4
				if is_corner:
					block.material_data = mat_brick_dry
					block.block_shape = DestructibleBlock.BlockShape.PILLAR
				elif z == garage_depth - 1 and (x >= 2 and x <= garage_width - 3) and y == 3:
					block.material_data = mat_brick_dry
					block.block_shape = DestructibleBlock.BlockShape.DOOR_LINTEL_X
				elif is_side and y == 2 and (z == 2 or z == 4 or z == 6):
					block.material_data = mat_brick_hollow
					block.block_shape = DestructibleBlock.BlockShape.WINDOW_Z
				elif z == 0 and y == 2 and (x == 3 or x == 6):
					block.material_data = mat_brick_hollow
					block.block_shape = DestructibleBlock.BlockShape.WINDOW_X
				elif is_front_back:
					block.material_data = mat_brick_dry if y == garage_height - 1 else mat_brick_hollow
					block.block_shape = DestructibleBlock.BlockShape.WALL_X
				else:
					block.material_data = mat_brick_dry if y == garage_height - 1 else mat_brick_hollow
					block.block_shape = DestructibleBlock.BlockShape.WALL_Z

				block.position = Vector3(
					float(x - int(garage_width * 0.5)) * block_size,
					(float(y) + 0.5) * block_size,
					float(z - int(garage_depth * 0.5)) * block_size
				)
				block.name = "Garage_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_corner:
					block.is_anchored = true
				add_child(block)

	# SCALA INTERNA PERCORRIBILE lungo la parete ovest (x=1, sale verso nord da z=6 a z=2, y=0..4)
	for step_i in range(garage_height):
		var sx: int = 1
		var sy: int = step_i
		var sz: int = 6 - step_i
		var stair: DestructibleBlock = block_scene.instantiate()
		stair.material_data = mat_brick_dry
		stair.block_shape = DestructibleBlock.BlockShape.STAIR_NORTH
		stair.position = Vector3(
			float(sx - int(garage_width * 0.5)) * block_size,
			(float(sy) + 0.5) * block_size,
			float(sz - int(garage_depth * 0.5)) * block_size
		)
		stair.name = "Garage_Stair_%d" % step_i
		stair.grid_coord = Vector3i(sx, sy, sz)
		add_child(stair)

	# Soletta tetto terrazzato calpestabile a y = garage_height - 1 (lascia apertura tromba scale su x=1, z=2..5)
	var roof_y: int = garage_height - 1
	for z in range(1, garage_depth - 1):
		for x in range(1, garage_width - 1):
			# Apertura tromba delle scale per sbucare comodamente sul tetto
			if x == 1 and (z >= 2 and z <= 5):
				continue
			var slab: DestructibleBlock = block_scene.instantiate()
			slab.material_data = mat_brick_dry if (x == 1 or x == garage_width - 2 or z == 1 or z == garage_depth - 2) else mat_brick_hollow
			slab.block_shape = DestructibleBlock.BlockShape.SLAB
			slab.position = Vector3(
				float(x - int(garage_width * 0.5)) * block_size,
				(float(roof_y) + 0.5) * block_size,
				float(z - int(garage_depth * 0.5)) * block_size
			)
			slab.name = "Garage_Roof_%d_%d" % [x, z]
			slab.grid_coord = Vector3i(x, roof_y, z)
			add_child(slab)

	# Parapetto perimetrale basso sulla terrazza del tetto (y = garage_height)
	for z in range(garage_depth):
		for x in range(garage_width):
			var is_front_back: bool = (z == 0 or z == garage_depth - 1)
			var is_side: bool = (x == 0 or x == garage_width - 1)
			if not is_front_back and not is_side:
				continue
			var para: DestructibleBlock = block_scene.instantiate()
			para.material_data = mat_brick_dry
			para.block_shape = DestructibleBlock.BlockShape.SLAB_BOTTOM
			para.position = Vector3(
				float(x - int(garage_width * 0.5)) * block_size,
				(float(garage_height) + 0.5) * block_size,
				float(z - int(garage_depth * 0.5)) * block_size
			)
			para.name = "Garage_Parapet_%d_%d" % [x, z]
			para.grid_coord = Vector3i(x, garage_height, z)
			add_child(para)
