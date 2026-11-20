class_name FenceBuilder
extends StructureManager

@export var fence_length: int = 12
@export var fence_height: int = 2

func _ready() -> void:
	if get_child_count() == 0:
		generate_fence()
	super._ready()

func generate_fence() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_rotten: MaterialData = load("res://data/materials/wood_rotten.tres")
	var mat_plank: MaterialData = load("res://data/materials/wood_plank.tres")

	var post_x: Array[int] = [0, 4, 7, fence_length - 1]

	for y in range(fence_height):
		for x in range(fence_length):
			var is_post: bool = post_x.has(x)
			# Lascia un piccolo varco pedonale al centro tra i pali 4 e 7 al livello 0
			if y == 0 and (x == 5 or x == 6):
				continue

			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_plank if is_post else mat_rotten
			if is_post:
				block.block_shape = DestructibleBlock.BlockShape.FENCE_POST
			elif y == 1 and (x == 5 or x == 6):
				block.block_shape = DestructibleBlock.BlockShape.DOOR_LINTEL_X
			else:
				block.block_shape = DestructibleBlock.BlockShape.FENCE_PANEL_X

			var x_pos: float = float(x - int(fence_length * 0.5)) * block_size
			var y_pos: float = (float(y) + 0.5) * block_size
			block.position = Vector3(x_pos, y_pos, 0.0)
			block.name = "Fence_%d_%d" % [x, y]
			block.grid_coord = Vector3i(x, y, 0)

			if y == 0 and is_post:
				block.is_anchored = true

			add_child(block)
