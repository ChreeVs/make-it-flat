class_name SkyscraperBuilder
extends StructureManager

@export var tower_width: int = 8
@export var tower_depth: int = 8
@export var tower_height: int = 13

func _ready() -> void:
	if get_child_count() == 0:
		generate_skyscraper()
	super._ready()

func generate_skyscraper() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_steel: MaterialData = load("res://data/materials/steel_beam.tres")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_brick: MaterialData = load("res://data/materials/brick_dry.tres")

	for y in range(tower_height):
		var is_slab: bool = (y > 0 and (y % 4 == 0 or y == tower_height - 1))

		for z in range(tower_depth):
			for x in range(tower_width):
				var is_corner: bool = (x == 0 or x == tower_width - 1) and (z == 0 or z == tower_depth - 1)
				var is_perimeter: bool = (x == 0 or x == tower_width - 1 or z == 0 or z == tower_depth - 1)

				if not is_slab:
					if y == 0 and not is_corner:
						continue
					if not is_perimeter:
						continue
					# Ampie vetrate del grattacielo sulle facciate (lascia pilastri d'angolo e montanti centrali)
					if not is_corner and (y % 4 == 2 or y % 4 == 3):
						if (z == 0 or z == tower_depth - 1) and (x == 2 or x == 5):
							continue
						if (x == 0 or x == tower_width - 1) and (z == 2 or z == 5):
							continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_corner:
					block.material_data = mat_steel
				elif is_slab:
					block.material_data = mat_concrete
				else:
					block.material_data = mat_concrete if (x == 3 or x == 4 or z == 3 or z == 4) else mat_brick

				var x_pos: float = float(x - int(tower_width * 0.5)) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - int(tower_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Tower_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_corner:
					block.is_anchored = true

				add_child(block)

	# Corona tecnica / eliporto sommitale
	var crown_y: int = tower_height
	for z in range(2, tower_depth - 2):
		for x in range(2, tower_width - 2):
			var is_crown_edge: bool = (x == 2 or x == tower_width - 3 or z == 2 or z == tower_depth - 3)
			if not is_crown_edge:
				continue
			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_steel
			var x_pos: float = float(x - int(tower_width * 0.5)) * block_size
			var y_pos: float = (float(crown_y) + 0.5) * block_size
			var z_pos: float = float(z - int(tower_depth * 0.5)) * block_size
			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "Tower_Crown_%d_%d" % [x, z]
			block.grid_coord = Vector3i(x, crown_y, z)
			add_child(block)
