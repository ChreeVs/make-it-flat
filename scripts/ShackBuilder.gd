class_name ShackBuilder
extends StructureManager

@export var shack_width: int = 6
@export var shack_depth: int = 5
@export var shack_height: int = 4

func _ready() -> void:
	if get_child_count() == 0:
		generate_shack()
	super._ready()

func generate_shack() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_rotten: MaterialData = load("res://data/materials/wood_rotten.tres")
	var mat_plank: MaterialData = load("res://data/materials/wood_plank.tres")

	for y in range(shack_height):
		for z in range(shack_depth):
			for x in range(shack_width):
				var is_corner: bool = (x == 0 or x == shack_width - 1) and (z == 0 or z == shack_depth - 1)
				var is_perimeter: bool = (x == 0 or x == shack_width - 1 or z == 0 or z == shack_depth - 1)
				var is_roof: bool = (y == shack_height - 1)

				if not is_roof:
					if y == 0 and not is_corner:
						continue
					if not is_perimeter:
						continue
					# Porta sul fronte (+Z)
					if z == shack_depth - 1 and (x == 2 or x == 3) and y <= 2:
						continue
					# Finestre laterali
					if (x == 0 or x == shack_width - 1) and z == 2 and y == 2:
						continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_corner or is_roof:
					block.material_data = mat_plank
				else:
					block.material_data = mat_rotten

				var x_pos: float = float(x - int(shack_width * 0.5)) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - int(shack_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Shack_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_corner:
					block.is_anchored = true

				add_child(block)
