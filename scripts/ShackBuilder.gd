class_name ShackBuilder
extends StructureManager

@export var shack_width: int = 7
@export var shack_depth: int = 6
@export var wall_height: int = 3

func _ready() -> void:
	if get_child_count() == 0:
		generate_shack()
	super._ready()

func generate_shack() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_rotten: MaterialData = load("res://data/materials/wood_rotten.tres")
	var mat_plank: MaterialData = load("res://data/materials/wood_plank.tres")

	# Pareti, pilastri, porta con architrave e finestre vetrate
	for y in range(wall_height):
		for z in range(shack_depth):
			for x in range(shack_width):
				var is_corner: bool = (x == 0 or x == shack_width - 1) and (z == 0 or z == shack_depth - 1)
				var is_front_back: bool = (z == 0 or z == shack_depth - 1)
				var is_side: bool = (x == 0 or x == shack_width - 1)
				if not is_front_back and not is_side:
					continue

				# Porta d'ingresso centrale sul fronte (+Z)
				if z == shack_depth - 1 and x == 3 and y <= 1:
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_corner:
					block.material_data = mat_plank
					block.block_shape = DestructibleBlock.BlockShape.PILLAR
				elif z == shack_depth - 1 and x == 3 and y == 2:
					block.material_data = mat_plank
					block.block_shape = DestructibleBlock.BlockShape.DOOR_LINTEL_X
				elif is_side and y == 1 and (z == 2 or z == 3):
					block.material_data = mat_plank
					block.block_shape = DestructibleBlock.BlockShape.WINDOW_Z
				elif z == 0 and y == 1 and (x == 2 or x == 4):
					block.material_data = mat_plank
					block.block_shape = DestructibleBlock.BlockShape.WINDOW_X
				elif is_front_back:
					block.material_data = mat_rotten
					block.block_shape = DestructibleBlock.BlockShape.WALL_X
				else:
					block.material_data = mat_rotten
					block.block_shape = DestructibleBlock.BlockShape.WALL_Z

				block.position = Vector3(
					float(x - int(shack_width * 0.5)) * block_size,
					(float(y) + 0.5) * block_size,
					float(z - int(shack_depth * 0.5)) * block_size
				)
				block.name = "Shack_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_corner:
					block.is_anchored = true
				add_child(block)

	# Tetto spiovente a doppia falda (falda nord y=3 z=0..2, falda sud y=3 z=3..5, colmo centrale y=4 z=2..3)
	for z in range(shack_depth):
		for x in range(shack_width):
			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_plank
			if z <= 1:
				block.block_shape = DestructibleBlock.BlockShape.ROOF_SLOPE_N
			elif z >= shack_depth - 2:
				block.block_shape = DestructibleBlock.BlockShape.ROOF_SLOPE_S
			else:
				block.block_shape = DestructibleBlock.BlockShape.SLAB
			block.position = Vector3(
				float(x - int(shack_width * 0.5)) * block_size,
				(float(wall_height) + 0.5) * block_size,
				float(z - int(shack_depth * 0.5)) * block_size
			)
			block.name = "Shack_Roof_%d_%d" % [x, z]
			block.grid_coord = Vector3i(x, wall_height, z)
			add_child(block)

	# Trave di colmo superiore
	for x in range(shack_width):
		var ridge: DestructibleBlock = block_scene.instantiate()
		ridge.material_data = mat_plank
		ridge.block_shape = DestructibleBlock.BlockShape.BEAM_X
		ridge.position = Vector3(
			float(x - int(shack_width * 0.5)) * block_size,
			(float(wall_height + 1) + 0.5) * block_size,
			float(2 - int(shack_depth * 0.5)) * block_size
		)
		ridge.name = "Shack_Ridge_%d" % x
		ridge.grid_coord = Vector3i(x, wall_height + 1, 2)
		add_child(ridge)
