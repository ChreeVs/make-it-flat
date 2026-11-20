class_name ShackBuilder
extends StructureManager

@export var shack_width: int = 8
@export var shack_depth: int = 8
@export var shack_height: int = 5

func _enter_tree() -> void:
	if get_child_count() == 0:
		generate_shack()

func generate_shack() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_rotten: MaterialData = load("res://data/materials/wood_rotten.tres")
	var mat_plank: MaterialData = load("res://data/materials/wood_plank.tres")

	# Pareti e colonne fino all'ultimo piano prima del tetto
	for y in range(shack_height - 1):
		for z in range(shack_depth):
			for x in range(shack_width):
				var is_corner: bool = (x <= 1 or x >= shack_width - 2) and (z <= 1 or z >= shack_depth - 2)
				var is_wall: bool = (x == 0 or x == shack_width - 1 or z == 0 or z == shack_depth - 1)

				# A terra solo le 4 colonne portanti angolari raddoppiate
				if y == 0 and not is_corner:
					continue
				if not is_wall and not is_corner:
					continue
				# Vano porta sul fronte (z=0, x da 3 a 4, y < 4)
				if z == 0 and (x == 3 or x == 4) and y < 4:
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				block.material_data = mat_plank if is_corner else mat_rotten

				var x_pos: float = float(x - int(shack_width * 0.5)) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - int(shack_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Block_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_corner:
					block.is_anchored = true

				add_child(block)

	# Tetto completo
	var roof_y: int = shack_height - 1
	for z in range(shack_depth):
		for x in range(shack_width):
			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_plank

			var x_pos: float = float(x - int(shack_width * 0.5)) * block_size
			var y_pos: float = (float(roof_y) + 0.5) * block_size
			var z_pos: float = float(z - int(shack_depth * 0.5)) * block_size

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "Roof_%d_%d_%d" % [x, roof_y, z]
			block.grid_coord = Vector3i(x, roof_y, z)

			add_child(block)
