class_name VillaBuilder
extends StructureManager

@export var villa_width: int = 16   # 8 metri
@export var villa_depth: int = 14   # 7 metri
@export var ground_floor_height: int = 6 # 3 metri
@export var roof_height: int = 5    # 2.5 metri

func _ready() -> void:
	if get_child_count() == 0:
		generate_villa()
	super._ready()

func generate_villa() -> void:
	var block_scene: PackedScene = load("res://scenes/structures/DestructibleBlock.tscn")
	var mat_brick: MaterialData = load("res://data/materials/brick_dry.tres")
	var mat_hollow: MaterialData = load("res://data/materials/brick_hollow.tres")
	var mat_wood: MaterialData = load("res://data/materials/wood_plank.tres")
	var mat_concrete: MaterialData = load("res://data/materials/concrete_reinforced.tres")

	var half_w: int = int(villa_width * 0.5)
	var half_d: int = int(villa_depth * 0.5)

	# 1. PIANO TERRA: Pareti esterne, pilastri del portico, tramezzo interno
	for y in range(ground_floor_height):
		for z in range(villa_depth):
			for x in range(villa_width):
				var is_corner: bool = (x == 0 or x == villa_width - 1) and (z == 0 or z == villa_depth - 1)
				var is_perimeter: bool = (x == 0 or x == villa_width - 1 or z == 0 or z == villa_depth - 1)
				# Colonne del portico frontale (+Z)
				var is_porch_pillar: bool = (z == villa_depth - 1 and (x == 3 or x == villa_width - 4))
				# Tramezzo divisorio interno stanze
				var is_interior_wall: bool = (x == half_w and z >= 2 and z <= villa_depth - 3)

				# A terra poggiano solo perimetro, pilastri portico e tramezzo
				if not is_perimeter and not is_interior_wall and not is_porch_pillar:
					continue

				# Porta d'ingresso principale frontale (z=villa_depth-1, centro, y < 4)
				var is_front_door: bool = (z == villa_depth - 1 and abs(x - half_w) <= 1 and y < 4)
				# Finestre frontali (z=villa_depth-1, y=2..3)
				var is_front_window: bool = (z == villa_depth - 1 and ((x >= 2 and x <= 3) or (x >= villa_width - 4 and x <= villa_width - 3)) and (y >= 2 and y <= 3))
				# Finestre laterali (x=0 o x=villa_width-1, z=4..7, y=2..3)
				var is_side_window: bool = ((x == 0 or x == villa_width - 1) and (z >= 4 and z <= 7) and (y >= 2 and y <= 3))
				# Porta interna di passaggio tra stanze
				var is_interior_door: bool = (is_interior_wall and z == 4 and y < 4)

				if is_front_door or is_front_window or is_side_window or is_interior_door:
					continue

				var block: DestructibleBlock = block_scene.instantiate()
				if is_corner or is_porch_pillar:
					block.material_data = mat_concrete
				elif y == 0:
					block.material_data = mat_brick
				else:
					block.material_data = mat_hollow

				var x_pos: float = float(x - half_w) * block_size
				var y_pos: float = (float(y) + 0.5) * block_size
				var z_pos: float = float(z - half_d) * block_size

				block.position = Vector3(x_pos, y_pos, z_pos)
				block.name = "Villa_GF_%d_%d_%d" % [x, y, z]
				block.grid_coord = Vector3i(x, y, z)
				if y == 0:
					block.is_anchored = true

				add_child(block)

	# 2. SOLAIO DEL PIANO TERRA / SOFFITTO
	var slab_y: int = ground_floor_height
	for z in range(villa_depth):
		for x in range(villa_width):
			var block: DestructibleBlock = block_scene.instantiate()
			var is_edge: bool = (x == 0 or x == villa_width - 1 or z == 0 or z == villa_depth - 1)
			block.material_data = mat_concrete if is_edge else mat_wood

			var x_pos: float = float(x - half_w) * block_size
			var y_pos: float = (float(slab_y) + 0.5) * block_size
			var z_pos: float = float(z - half_d) * block_size

			block.position = Vector3(x_pos, y_pos, z_pos)
			block.name = "Villa_Slab_%d_%d_%d" % [x, slab_y, z]
			block.grid_coord = Vector3i(x, slab_y, z)

			add_child(block)

	# 3. TETTO A DUE FALDE SPIOVENTI (Tetto a spiovente)
	for r_level in range(roof_height):
		var y_coord: int = slab_y + 1 + r_level
		var inset_x: int = r_level
		var x_left: int = inset_x
		var x_right: int = villa_width - 1 - inset_x

		for z in range(villa_depth):
			# Falda sinistra
			if x_left <= half_w:
				var b_left: DestructibleBlock = block_scene.instantiate()
				b_left.material_data = mat_wood
				var xl_pos: float = float(x_left - half_w) * block_size
				var y_pos: float = (float(y_coord) + 0.5) * block_size
				var z_pos: float = float(z - half_d) * block_size

				b_left.position = Vector3(xl_pos, y_pos, z_pos)
				b_left.name = "RoofL_%d_%d_%d" % [x_left, y_coord, z]
				b_left.grid_coord = Vector3i(x_left, y_coord, z)
				add_child(b_left)

			# Falda destra
			if x_right > half_w and x_right != x_left:
				var b_right: DestructibleBlock = block_scene.instantiate()
				b_right.material_data = mat_wood
				var xr_pos: float = float(x_right - half_w) * block_size
				var y_pos: float = (float(y_coord) + 0.5) * block_size
				var z_pos: float = float(z - half_d) * block_size

				b_right.position = Vector3(xr_pos, y_pos, z_pos)
				b_right.name = "RoofR_%d_%d_%d" % [x_right, y_coord, z]
				b_right.grid_coord = Vector3i(x_right, y_coord, z)
				add_child(b_right)

			# Timpano triangolare frontale e posteriore (chiude il vertice)
			if (z == 0 or z == villa_depth - 1):
				for x in range(x_left + 1, x_right):
					var b_gable: DestructibleBlock = block_scene.instantiate()
					b_gable.material_data = mat_brick
					var xg_pos: float = float(x - half_w) * block_size
					var y_pos: float = (float(y_coord) + 0.5) * block_size
					var z_pos: float = float(z - half_d) * block_size

					b_gable.position = Vector3(xg_pos, y_pos, z_pos)
					b_gable.name = "Gable_%d_%d_%d" % [x, y_coord, z]
					b_gable.grid_coord = Vector3i(x, y_coord, z)
					add_child(b_gable)

	# 4. COMIGNOLO IN MATTONI
	var chimney_x: int = half_w - 3
	var chimney_z: int = 3
	for cy in range(slab_y + 1, slab_y + roof_height + 3):
		var ch_block: DestructibleBlock = block_scene.instantiate()
		ch_block.material_data = mat_brick
		var x_pos: float = float(chimney_x - half_w) * block_size
		var y_pos: float = (float(cy) + 0.5) * block_size
		var z_pos: float = float(chimney_z - half_d) * block_size

		ch_block.position = Vector3(x_pos, y_pos, z_pos)
		ch_block.name = "Chimney_%d" % cy
		ch_block.grid_coord = Vector3i(chimney_x, cy, chimney_z)
		add_child(ch_block)
