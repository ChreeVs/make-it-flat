class_name MultiFloorBuilder
extends StructureManager

@export var building_width: int = 8
@export var building_depth: int = 6
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
	# Esattamente 6 pilastri portanti (3 su X x 2 su Z) per demolizione controllata C4
	var col_x: Array[int] = [0, int(building_width * 0.5), building_width - 1]
	var col_z: Array[int] = [0, building_depth - 1]

	for y in range(total_height):
		var local_y: int = y % floor_height
		var is_slab: bool = (local_y == floor_height - 1)

		for z in range(building_depth):
			for x in range(building_width):
				var is_col: bool = col_x.has(x) and col_z.has(z)
				var is_perimeter: bool = (x == 0 or x == building_width - 1 or z == 0 or z == building_depth - 1)

				if not is_slab:
					if y == 0 and not is_col:
						continue
					if not is_perimeter and not is_col:
						continue
					# Finestre di facciata su ogni piano (non sui pilastri)
					if not is_col and local_y == 1 and (z == 0 or z == building_depth - 1) and (x == 2 or x == 5):
						continue
					if not is_col and local_y == 1 and (x == 0 or x == building_width - 1) and (z == 2 or z == 3):
						continue
					# Ingresso piano terra
					if y == 1 and z == building_depth - 1 and (x == 2 or x == 3):
						continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_col or is_slab:
					block.material_data = mat_concrete
				elif local_y == 0:
					block.material_data = mat_brick_dry
				else:
					block.material_data = mat_brick_hollow

				var x_pos: float = float(x - int(building_width * 0.5)) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - int(building_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Palazzina_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_col:
					block.is_anchored = true

				add_child(block)
