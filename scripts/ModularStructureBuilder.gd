class_name ModularStructureBuilder
extends StructureManager

@export var wall_width: int = 10
@export var wall_height: int = 5

func _ready() -> void:
	if get_child_count() == 0:
		generate_wall()
	super._ready()

func generate_wall() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_plank: MaterialData = load("res://data/materials/wood_plank.tres")
	var mat_rotten: MaterialData = load("res://data/materials/wood_rotten.tres")

	for y in range(wall_height):
		for x in range(wall_width):
			var is_pillar_base: bool = (y == 0 and (x == 2 or x == 7))
			if y == 0 and not is_pillar_base:
				continue

			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_plank if (x == 2 or x == 7 or y == wall_height - 1) else mat_rotten

			var x_pos: float = float(x - int(wall_width * 0.5)) * block_size
			var y_pos: float = (float(y) + 0.5) * block_size
			block.position = Vector3(x_pos, y_pos, 0.0)
			block.name = "Block_%d_%d" % [x, y]
			block.grid_coord = Vector3i(x, y, 0)
			if is_pillar_base:
				block.is_anchored = true

			add_child(block)
