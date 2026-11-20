class_name FenceBuilder
extends StructureManager

@export var fence_length: int = 12
@export var fence_height: int = 3

func _ready() -> void:
	if get_child_count() == 0:
		generate_fence()
	super._ready()

func generate_fence() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_rotten: MaterialData = load("res://data/materials/wood_rotten.tres")
	var mat_plank: MaterialData = load("res://data/materials/wood_plank.tres")

	# Pali portanti distanziati ogni 3-4 metri (ancorati a terra y=0)
	var post_x: Array[int] = [0, 4, 7, fence_length - 1]

	for y in range(fence_height):
		for x in range(fence_length):
			var is_post: bool = post_x.has(x)
			if y == 0 and not is_post:
				continue

			var block: DestructibleBlock = block_scene.instantiate()
			block.material_data = mat_plank if is_post else mat_rotten

			var x_pos: float = float(x - int(fence_length * 0.5)) * block_size
			var y_pos: float = (float(y) + 0.5) * block_size
			block.position = Vector3(x_pos, y_pos, 0.0)
			block.name = "Fence_%d_%d" % [x, y]
			block.grid_coord = Vector3i(x, y, 0)

			if y == 0 and is_post:
				block.is_anchored = true

			add_child(block)
