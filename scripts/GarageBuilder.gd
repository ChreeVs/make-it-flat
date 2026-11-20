class_name GarageBuilder
extends StructureManager

@export var garage_width: int = 10
@export var garage_depth: int = 10
@export var garage_height: int = 6

func _ready() -> void:
	if get_child_count() == 0:
		generate_garage()
	super._ready()

func generate_garage() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_brick_dry: MaterialData = load("res://data/materials/brick_dry.tres")
	var mat_brick_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	for y in range(garage_height):
		for z in range(garage_depth):
			for x in range(garage_width):
				var is_corner: bool = (x == 0 or x == garage_width - 1) and (z == 0 or z == garage_depth - 1)
				var is_perimeter: bool = (x == 0 or x == garage_width - 1 or z == 0 or z == garage_depth - 1)
				var is_roof: bool = (y == garage_height - 1)

				if not is_roof:
					if y == 0 and not is_corner:
						continue
					if not is_perimeter:
						continue
					# Ampia serranda garage sul lato frontale (+Z)
					if z == garage_depth - 1 and (x >= 2 and x <= garage_width - 3) and y <= garage_height - 3:
						continue
					# Finestre alte sui fianchi
					if (x == 0 or x == garage_width - 1) and y == garage_height - 3 and (z == 3 or z == 6):
						continue

				var block: DestructibleBlock = block_scene.instantiate()
				# Tutti i blocchi sono di Tier 2 (brick_dry / brick_hollow) per coerenza cantiere Tier 2
				if is_corner or y == garage_height - 2 or (is_roof and (x == 0 or x == garage_width - 1 or z == 0 or z == garage_depth - 1)):
					block.material_data = mat_brick_dry
				else:
					block.material_data = mat_brick_hollow

				var x_pos: float = float(x - int(garage_width * 0.5)) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - int(garage_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Garage_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_corner:
					block.is_anchored = true

				add_child(block)
