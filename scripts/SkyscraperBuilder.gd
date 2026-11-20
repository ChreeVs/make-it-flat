class_name SkyscraperBuilder
extends StructureManager

@export var tower_width: int = 10
@export var tower_depth: int = 10
@export var tower_height: int = 12

func _enter_tree() -> void:
	if get_child_count() == 0:
		generate_skyscraper()

func generate_skyscraper() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	# Le 4 colonne angolari di fondazione (posizioni XZ raddoppiate per maggiore stabilità strutturale)
	var corner_coords: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(tower_width - 1, 0), Vector2i(tower_width - 2, 0), Vector2i(tower_width - 1, 1), Vector2i(tower_width - 2, 1),
		Vector2i(0, tower_depth - 1), Vector2i(1, tower_depth - 1), Vector2i(0, tower_depth - 2), Vector2i(1, tower_depth - 2),
		Vector2i(tower_width - 1, tower_depth - 1), Vector2i(tower_width - 2, tower_depth - 1), Vector2i(tower_width - 1, tower_depth - 2), Vector2i(tower_width - 2, tower_depth - 2)
	]

	for y in range(tower_height):
		var is_floor_slab: bool = (y % 3 == 2 or y == tower_height - 1)

		for z in range(tower_depth):
			for x in range(tower_width):
				var is_corner: bool = corner_coords.has(Vector2i(x, z))
				var is_outer_edge: bool = (x == 0 or x == tower_width - 1 or z == 0 or z == tower_depth - 1)

				# A terra solo i pilastri di fondazione
				if y == 0 and not is_corner:
					continue
				
				# Se non è una soletta, genera solo perimetro o pilastri
				if not is_floor_slab and not is_outer_edge:
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				block.material_data = mat_concrete if is_corner else mat_hollow

				var x_pos: float = float(x - int(tower_width * 0.5)) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - int(tower_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Tower_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_corner:
					block.is_anchored = true

				add_child(block)
