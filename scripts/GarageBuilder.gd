class_name GarageBuilder
extends StructureManager

@export var garage_width: int = 10
@export var garage_depth: int = 10
@export var garage_height: int = 6

func _enter_tree() -> void:
	if get_child_count() == 0:
		generate_garage()

func generate_garage() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")
	var mat_dry: MaterialData = load("res://data/materials/brick_dry.tres")

	# Pareti e colonne
	for y in range(garage_height - 1):
		for z in range(garage_depth):
			for x in range(garage_width):
				var is_corner: bool = (x <= 1 or x >= garage_width - 2) and (z <= 1 or z >= garage_depth - 2)
				var is_perimeter: bool = (x == 0 or x == garage_width - 1 or z == 0 or z == garage_depth - 1)

				# A terra solo i pilastri angolari
				if y == 0 and not is_corner:
					continue
				if not is_perimeter and not is_corner:
					continue
				# Ingresso garage frontale (z=0, x da 3 a 6)
				if z == 0 and (x >= 3 and x <= 6) and y < garage_height - 1:
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				block.material_data = mat_hollow if is_corner else mat_dry

				var x_pos: float = float(x - int(garage_width * 0.5)) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - int(garage_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Garage_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_corner:
					block.is_anchored = true

				add_child(block)

	# Soletta tetto massiccia
	var roof_y: int = garage_height - 1
	for z in range(garage_depth):
		for x in range(garage_width):
			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_hollow

			var x_pos: float = float(x - int(garage_width * 0.5)) * block_size
			var y_pos: float = (float(roof_y) + 0.5) * block_size
			var z_pos: float = float(z - int(garage_depth * 0.5)) * block_size

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "Roof_%d_%d_%d" % [x, roof_y, z]
			block.grid_coord = Vector3i(x, roof_y, z)

			add_child(block)
