class_name FenceBuilder
extends StructureManager

@export var fence_length: int = 14
@export var fence_height: int = 3

func _enter_tree() -> void:
	if get_child_count() == 0:
		generate_fence()

func generate_fence() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_rotten: MaterialData = load("res://data/materials/wood_rotten.tres")
	var mat_plank: MaterialData = load("res://data/materials/wood_plank.tres")

	for x in range(fence_length):
		for y in range(fence_height):
			var block: DestructibleBlock = block_scene.instantiate()
			var is_post: bool = (x % 3 == 0)
			block.material_data = mat_plank if is_post else mat_rotten

			var x_pos: float = float(x - int(fence_length * 0.5)) * block_size
			var y_pos: float = (float(y) + 0.5) * block_size
			var z_pos: float = 0.0

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "Fence_%d_%d" % [x, y]
			block.grid_coord = Vector3i(x, y, 0)
			if y == 0:
				block.is_anchored = true

			add_child(block)
