class_name SkyscraperBuilder
extends StructureManager

@export var tower_width: int = 8
@export var tower_depth: int = 8
@export var tower_height: int = 12

func _ready() -> void:
	if get_child_count() == 0:
		generate_skyscraper()
	super._ready()

func generate_skyscraper() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_steel: MaterialData = load("res://data/materials/steel_beam.tres")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")

	var floor_h: int = 4

	for y in range(tower_height):
		var local_y: int = y % floor_h
		var is_slab_level: bool = (local_y == floor_h - 1)

		for z in range(tower_depth):
			for x in range(tower_width):
				var is_corner: bool = (x == 0 or x == tower_width - 1) and (z == 0 or z == tower_depth - 1)
				var is_front_back: bool = (z == 0 or z == tower_depth - 1)
				var is_side: bool = (x == 0 or x == tower_width - 1)
				var is_perimeter: bool = is_front_back or is_side

				if is_perimeter:
					# Ampia hall d'ingresso al piano terra (+Z)
					if z == tower_depth - 1 and (x == 3 or x == 4) and y <= 1:
						continue

					var block: DestructibleBlock = block_scene.instantiate()
					if is_corner:
						block.material_data = mat_steel
						block.block_shape = DestructibleBlock.BlockShape.PILLAR
					elif z == tower_depth - 1 and (x == 3 or x == 4) and y == 2:
						block.material_data = mat_steel
						block.block_shape = DestructibleBlock.BlockShape.DOOR_LINTEL_X
					elif is_slab_level:
						block.material_data = mat_steel
						block.block_shape = DestructibleBlock.BlockShape.BEAM_X if is_front_back else DestructibleBlock.BlockShape.BEAM_Z
					elif local_y == 1 or local_y == 2:
						# Facciata continua vetrata da grattacielo moderno
						block.material_data = mat_concrete
						block.block_shape = DestructibleBlock.BlockShape.WINDOW_X if is_front_back else DestructibleBlock.BlockShape.WINDOW_Z
					else:
						block.material_data = mat_concrete
						block.block_shape = DestructibleBlock.BlockShape.WALL_X if is_front_back else DestructibleBlock.BlockShape.WALL_Z

					block.position = Vector3(
						float(x - int(tower_width * 0.5)) * block_size,
						(float(y) + 0.5) * block_size,
						float(z - int(tower_depth * 0.5)) * block_size
					)
					block.name = "Tower_%d_%d_%d" % [x, y, z]
					block.grid_coord = Vector3i(x, y, z)
					if y == 0 and is_corner:
						block.is_anchored = true
					add_child(block)

				elif is_slab_level:
					# Solette dei piani con tromba scale interna su x=1, z=2..5
					if x == 1 and (z >= 2 and z <= 5):
						continue
					var slab: DestructibleBlock = block_scene.instantiate()
					slab.material_data = mat_concrete
					slab.block_shape = DestructibleBlock.BlockShape.SLAB
					slab.position = Vector3(
						float(x - int(tower_width * 0.5)) * block_size,
						(float(y) + 0.5) * block_size,
						float(z - int(tower_depth * 0.5)) * block_size
					)
					slab.name = "Tower_Slab_%d_%d_%d" % [x, y, z]
					slab.grid_coord = Vector3i(x, y, z)
					add_child(slab)

	# VANO SCALE INTERNO A RAMPE ALTERNATE fino alla terrazza eliporto (3 piani x 4 gradini)
	for f in range(3):
		var base_y: int = f * floor_h
		var going_north: bool = (f % 2 == 0)
		for step_i in range(floor_h):
			var sy: int = base_y + step_i
			var sz: int = (5 - step_i) if going_north else (2 + step_i)
			var stair: DestructibleBlock = block_scene.instantiate()
			stair.material_data = mat_steel
			stair.block_shape = DestructibleBlock.BlockShape.STAIR_NORTH if going_north else DestructibleBlock.BlockShape.STAIR_SOUTH
			stair.position = Vector3(
				float(1 - int(tower_width * 0.5)) * block_size,
				(float(sy) + 0.5) * block_size,
				float(sz - int(tower_depth * 0.5)) * block_size
			)
			stair.name = "Tower_Stair_%d_%d" % [f, step_i]
			stair.grid_coord = Vector3i(1, sy, sz)
			add_child(stair)

	# Corona sommitale / bordo eliporto
	var crown_y: int = tower_height
	for z in range(2, tower_depth - 2):
		for x in range(2, tower_width - 2):
			if not (x == 2 or x == tower_width - 3 or z == 2 or z == tower_depth - 3):
				continue
			var crown: DestructibleBlock = block_scene.instantiate()
			crown.material_data = mat_steel
			crown.block_shape = DestructibleBlock.BlockShape.SLAB_BOTTOM
			crown.position = Vector3(
				float(x - int(tower_width * 0.5)) * block_size,
				(float(crown_y) + 0.5) * block_size,
				float(z - int(tower_depth * 0.5)) * block_size
			)
			crown.name = "Tower_Crown_%d_%d" % [x, z]
			crown.grid_coord = Vector3i(x, crown_y, z)
			add_child(crown)
