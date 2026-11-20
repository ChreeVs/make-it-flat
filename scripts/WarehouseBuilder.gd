class_name WarehouseBuilder
extends StructureManager

@export var warehouse_width: int = 12
@export var warehouse_depth: int = 10
@export var warehouse_height: int = 8

func _ready() -> void:
	if get_child_count() == 0:
		generate_warehouse()
	super._ready()

func generate_warehouse() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_steel: MaterialData = load("res://data/materials/steel_beam.tres")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")
	var mat_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")

	# 6 piloni industriali in acciaio pesante lungo i fianchi (griglia 2x3, baia frontale libera)
	var col_x: Array[int] = [0, warehouse_width - 1]
	var col_z: Array[int] = [0, int(warehouse_depth * 0.5), warehouse_depth - 1]

	for y in range(warehouse_height - 1):
		for z in range(warehouse_depth):
			for x in range(warehouse_width):
				var is_col: bool = col_x.has(x) and col_z.has(z)
				var is_perimeter: bool = (x == 0 or x == warehouse_width - 1 or z == 0 or z == warehouse_depth - 1)

				if y == 0 and not is_col:
					continue
				if not is_perimeter and not is_col:
					continue
				# Ampia baia di carico sul fronte (+Z)
				if z == warehouse_depth - 1 and (x >= 3 and x <= warehouse_width - 4) and y < warehouse_height - 3:
					continue
				# Lucernari industriali in alto sui fianchi
				if (x == 0 or x == warehouse_width - 1) and y == warehouse_height - 3 and (z % 2 == 1):
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_col:
					block.material_data = mat_steel
				elif y >= warehouse_height - 2:
					block.material_data = mat_concrete
				else:
					block.material_data = mat_hollow

				var x_pos: float = float(x - int(warehouse_width * 0.5)) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - int(warehouse_depth * 0.5)) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "WH_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0 and is_col:
					block.is_anchored = true

				add_child(block)

	# Copertura industriale con travi in acciaio e soletta in cemento
	var roof_y: int = warehouse_height - 1
	for z in range(warehouse_depth):
		for x in range(warehouse_width):
			var block: DestructibleBlock = block_scene.instantiate()
			var is_truss: bool = col_z.has(z) or x == 0 or x == warehouse_width - 1
			block.material_data = mat_steel if is_truss else mat_concrete

			var x_pos: float = float(x - int(warehouse_width * 0.5)) * block_size
			var y_pos: float = (float(roof_y) + 0.5) * block_size
			var z_pos: float = float(z - int(warehouse_depth * 0.5)) * block_size

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "WH_Roof_%d_%d_%d" % [x, roof_y, z]
			block.grid_coord = Vector3i(x, roof_y, z)
			add_child(block)
