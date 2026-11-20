class_name ModularStructureBuilder
extends StructureManager

@export var wall_width: int = 16
@export var wall_height: int = 8
@export var left_pillar_x: int = 3
@export var right_pillar_x: int = 12
@export var default_material: MaterialData
@export var pillar_material: MaterialData

func _enter_tree() -> void:
	if get_child_count() == 0:
		generate_wall()

func generate_wall() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_wood: MaterialData = default_material if default_material else load("res://data/materials/wood_plank.tres")
	var mat_brick: MaterialData = pillar_material if pillar_material else load("res://data/materials/brick_dry.tres")

	for y in range(wall_height):
		for x in range(wall_width):
			if y == 0 and x != left_pillar_x and x != right_pillar_x:
				continue

			var block: DestructibleBlock = block_scene.instantiate()
			var is_pillar: bool = (x == left_pillar_x or x == right_pillar_x)
			block.material_data = mat_brick if is_pillar else mat_wood
			
			var x_pos: float = float(x - int(wall_width * 0.5)) * block_size
			var y_pos: float = (float(y) + 0.5) * block_size
			var z_pos: float = 0.0

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "Block_%d_%d" % [x, y]
			block.grid_coord = Vector3i(x, y, 0)
			
			if y == 0 and is_pillar:
				block.is_anchored = true

			add_child(block)
