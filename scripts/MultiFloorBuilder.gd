class_name MultiFloorBuilder
extends StructureManager

@export var building_width: int = 10
@export var building_depth: int = 8
@export var num_floors: int = 3
@export var floor_height: int = 4

func _enter_tree() -> void:
	if get_child_count() == 0:
		generate_building()

func generate_building() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_brick: MaterialData = load("res://data/materials/brick_dry.tres")

	# Le 6 posizioni delle colonne nel piano XZ (griglia 3x2)
	var col_x_indices: Array[int] = [0, int(building_width * 0.5), building_width - 1]
	var col_z_indices: Array[int] = [0, building_depth - 1]

	var current_y: int = 0

	for floor_idx in range(num_floors):
		# Colonne del piano
		for h in range(floor_height - 1):
			var y_coord: int = current_y + h
			for cx in col_x_indices:
				for cz in col_z_indices:
					var block: DestructibleBlock = block_scene.instantiate()
					block.material_data = mat_concrete

					var x_pos: float = float(cx - int(building_width * 0.5)) * block_size
					var y_pos: float = (float(y_coord) + 0.5) * block_size
					var z_pos: float = float(cz - int(building_depth * 0.5)) * block_size

					block.position = Vector3(x_pos, y_pos, z_pos)
					block.name = "Pillar_F%d_%d_%d_H%d" % [floor_idx, cx, cz, h]
					block.grid_coord = Vector3i(cx, y_coord, cz)
					if floor_idx == 0 and h == 0:
						block.is_anchored = true

					add_child(block)

		current_y += (floor_height - 1)

		# Soletta / Pavimento del piano
		var slab_y: int = current_y
		for z in range(building_depth):
			for x in range(building_width):
				var block: DestructibleBlock = block_scene.instantiate()
				var is_col_spot: bool = col_x_indices.has(x) and col_z_indices.has(z)
				block.material_data = mat_concrete if is_col_spot else mat_brick

				var x_pos: float = float(x - int(building_width * 0.5)) * block_size
				var y_pos: float = (float(slab_y) + 0.5) * block_size
				var z_pos: float = float(z - int(building_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Slab_F%d_%d_%d" % [floor_idx, x, z]
				block.grid_coord = Vector3i(x, slab_y, z)

				add_child(block)

		current_y += 1
