@tool
extends SceneTree

func _init() -> void:
	print("--- GENERAZIONE TEXTURE COMPLETE PBR (Materiali, Crepe, Suolo, Attrezzi) ---")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets/textures"):
		dir.make_dir_recursive("assets/textures")

	# Attrezzi
	_create_wood_texture()
	_create_painted_metal_texture()
	_create_dark_steel_texture()
	_create_hazard_texture()
	_create_demolisher_texture()
	_create_c4_texture()
	_create_detonator_texture()

	# Suolo cantiere
	_create_ground_texture()

	# Materiali blocchi
	_create_mat_brick_dry()
	_create_mat_brick_hollow()
	_create_mat_concrete()
	_create_mat_wood_plank()
	_create_mat_wood_rotten()

	# Crepe sovrapposte
	_create_crack_textures()

	print("--- TUTTE LE TEXTURE GENERATE CON SUCCESSO! ---")
	quit(0)

func _create_flat_normal(width: int, height: int, bump_strength: float = 0.05) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var nx: float = clamp(0.5 + randf_range(-bump_strength, bump_strength), 0.0, 1.0)
			var ny: float = clamp(0.5 + randf_range(-bump_strength, bump_strength), 0.0, 1.0)
			img.set_pixel(x, y, Color(nx, ny, 1.0, 1.0))
	return img

func _create_ground_texture() -> void:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for y in range(512):
		for x in range(512):
			var n: float = randf_range(-0.04, 0.04)
			var gravel: float = 0.08 if randf() < 0.08 else 0.0
			var c: float = clamp(0.24 + n + gravel, 0.15, 0.38)
			img.set_pixel(x, y, Color(c, c * 1.02, c * 0.98, 1.0))
	img.save_png("res://assets/textures/tex_site_ground.png")

	var n_img := _create_flat_normal(512, 512, 0.08)
	n_img.save_png("res://assets/textures/tex_site_ground_n.png")

func _create_mat_brick_dry() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var n_img := Image.create(256, 256, false, Image.FORMAT_RGBA8)

	for y in range(256):
		var row: int = y / 32
		var is_mortar_y: bool = (y % 32 < 3)
		var x_offset: int = 64 if (row % 2 == 1) else 0

		for x in range(256):
			var is_mortar_x: bool = ((x + x_offset) % 128 < 3)
			var is_mortar: bool = is_mortar_y or is_mortar_x

			if is_mortar:
				img.set_pixel(x, y, Color(0.72, 0.70, 0.65, 1.0))
				n_img.set_pixel(x, y, Color(0.5, 0.5, 0.85, 1.0))
			else:
				var n: float = randf_range(-0.04, 0.04)
				img.set_pixel(x, y, Color(0.72 + n, 0.32 + n * 0.5, 0.22 + n * 0.3, 1.0))
				var nx: float = clamp(0.5 + randf_range(-0.06, 0.06), 0.0, 1.0)
				var ny: float = clamp(0.5 + randf_range(-0.06, 0.06), 0.0, 1.0)
				n_img.set_pixel(x, y, Color(nx, ny, 1.0, 1.0))

	img.save_png("res://assets/textures/tex_mat_brick_dry.png")
	n_img.save_png("res://assets/textures/tex_mat_brick_dry_n.png")

func _create_mat_brick_hollow() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var n_img := Image.create(256, 256, false, Image.FORMAT_RGBA8)

	for y in range(256):
		var is_line: bool = (y % 40 < 4)
		for x in range(256):
			var is_col: bool = (x % 64 < 4)
			var is_joint: bool = is_line or is_col
			if is_joint:
				img.set_pixel(x, y, Color(0.68, 0.65, 0.60, 1.0))
				n_img.set_pixel(x, y, Color(0.5, 0.5, 0.85, 1.0))
			else:
				var n: float = randf_range(-0.03, 0.03)
				img.set_pixel(x, y, Color(0.85 + n, 0.44 + n * 0.5, 0.20 + n * 0.3, 1.0))
				n_img.set_pixel(x, y, Color(0.5 + randf_range(-0.05, 0.05), 0.5 + randf_range(-0.05, 0.05), 1.0, 1.0))

	img.save_png("res://assets/textures/tex_mat_brick_hollow.png")
	n_img.save_png("res://assets/textures/tex_mat_brick_hollow_n.png")

func _create_mat_concrete() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var n_img := Image.create(256, 256, false, Image.FORMAT_RGBA8)

	for y in range(256):
		for x in range(256):
			var n: float = randf_range(-0.05, 0.05)
			var aggregate: float = 0.08 if randf() < 0.04 else 0.0
			var c: float = clamp(0.55 + n + aggregate, 0.4, 0.72)
			img.set_pixel(x, y, Color(c, c, c * 1.02, 1.0))
			n_img.set_pixel(x, y, Color(0.5 + randf_range(-0.06, 0.06), 0.5 + randf_range(-0.06, 0.06), 1.0, 1.0))

	img.save_png("res://assets/textures/tex_mat_concrete.png")
	n_img.save_png("res://assets/textures/tex_mat_concrete_n.png")

func _create_mat_wood_plank() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var n_img := Image.create(256, 256, false, Image.FORMAT_RGBA8)

	for y in range(256):
		for x in range(256):
			var grain: float = sin(float(x) * 0.3 + sin(float(y) * 0.04) * 5.0) * 0.12
			var n: float = randf_range(-0.03, 0.03)
			var r: float = clamp(0.65 + grain + n, 0.45, 0.85)
			var g: float = clamp(0.45 + grain * 0.7 + n, 0.3, 0.65)
			var b: float = clamp(0.25 + grain * 0.4 + n, 0.15, 0.4)
			img.set_pixel(x, y, Color(r, g, b, 1.0))
			n_img.set_pixel(x, y, Color(0.5 + grain * 0.2, 0.5 + randf_range(-0.03, 0.03), 1.0, 1.0))

	img.save_png("res://assets/textures/tex_mat_wood_plank.png")
	n_img.save_png("res://assets/textures/tex_mat_wood_plank_n.png")

func _create_mat_wood_rotten() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var n_img := Image.create(256, 256, false, Image.FORMAT_RGBA8)

	for y in range(256):
		for x in range(256):
			var grain: float = sin(float(x) * 0.25) * 0.1
			var rot: float = randf_range(-0.08, 0.08)
			var r: float = clamp(0.48 + grain + rot, 0.3, 0.65)
			var g: float = clamp(0.35 + grain * 0.6 + rot, 0.2, 0.48)
			var b: float = clamp(0.22 + grain * 0.3 + rot, 0.1, 0.32)
			img.set_pixel(x, y, Color(r, g, b, 1.0))
			n_img.set_pixel(x, y, Color(0.5 + randf_range(-0.07, 0.07), 0.5 + randf_range(-0.07, 0.07), 1.0, 1.0))

	img.save_png("res://assets/textures/tex_mat_wood_rotten.png")
	n_img.save_png("res://assets/textures/tex_mat_wood_rotten_n.png")

func _create_crack_textures() -> void:
	for stage in range(1, 4):
		var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		# Sfondo trasparente
		img.fill(Color(0, 0, 0, 0))

		var num_lines: int = stage * 3
		for l in range(num_lines):
			var start_x: int = randi_range(30, 226)
			var start_y: int = randi_range(30, 226)
			var length: int = randi_range(40, 100)
			var angle: float = randf_range(0, TAU)

			for step in range(length):
				var px: int = int(start_x + cos(angle) * step + randf_range(-1, 1))
				var py: int = int(start_y + sin(angle) * step + randf_range(-1, 1))
				if px >= 0 and px < 256 and py >= 0 and py < 256:
					img.set_pixel(px, py, Color(0.08, 0.08, 0.08, 0.85))
					if stage >= 2 and px + 1 < 256:
						img.set_pixel(px + 1, py, Color(0.12, 0.12, 0.12, 0.65))

		img.save_png("res://assets/textures/tex_cracks_stage%d.png" % stage)

func _create_wood_texture() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var grain: float = sin(float(x) * 0.4 + sin(float(y) * 0.05) * 6.0) * 0.15
			var noise_val: float = randf_range(-0.04, 0.04)
			var base_r: float = clamp(0.62 + grain + noise_val, 0.4, 0.8)
			var base_g: float = clamp(0.38 + grain * 0.7 + noise_val, 0.25, 0.55)
			var base_b: float = clamp(0.18 + grain * 0.4 + noise_val, 0.1, 0.3)
			img.set_pixel(x, y, Color(base_r, base_g, base_b, 1.0))
	img.save_png("res://assets/textures/tex_wood_handle.png")

func _create_painted_metal_texture() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var scratch: float = 0.0
			if randf() < 0.02 or (x % 32 == 0 and randf() < 0.3):
				scratch = randf_range(0.2, 0.5)
			var r: float = clamp(0.85 + scratch * 0.1, 0.7, 0.95)
			var g: float = clamp(0.35 + scratch * 0.4, 0.25, 0.75)
			var b: float = clamp(0.10 + scratch * 0.6, 0.05, 0.75)
			img.set_pixel(x, y, Color(r, g, b, 1.0))
	img.save_png("res://assets/textures/tex_painted_metal.png")

func _create_dark_steel_texture() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var n: float = randf_range(-0.06, 0.06)
			var edge_highlight: float = 0.08 if (x < 6 or x > 250 or y < 6 or y > 250) else 0.0
			var c: float = clamp(0.25 + n + edge_highlight, 0.15, 0.45)
			img.set_pixel(x, y, Color(c, c, c * 1.05, 1.0))
	img.save_png("res://assets/textures/tex_dark_steel.png")

func _create_hazard_texture() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var stripe: bool = (int(x + y) / 24) % 2 == 0
			var col: Color = Color(0.95, 0.75, 0.05) if stripe else Color(0.12, 0.12, 0.14)
			var n: float = randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(col.r + n, col.g + n, col.b + n, 1.0))
	img.save_png("res://assets/textures/tex_hazard_stripes.png")

func _create_demolisher_texture() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var is_vent: bool = (y >= 80 and y <= 160) and (x % 16 < 6)
			if is_vent:
				img.set_pixel(x, y, Color(0.1, 0.1, 0.1, 1.0))
			else:
				var n: float = randf_range(-0.02, 0.02)
				img.set_pixel(x, y, Color(0.92 + n, 0.72 + n, 0.08 + n, 1.0))
	img.save_png("res://assets/textures/tex_demolisher_body.png")

func _create_c4_texture() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var is_tape: bool = (x >= 60 and x <= 85) or (x >= 170 and x <= 195)
			if is_tape:
				var tape_val: float = 0.5 + randf_range(-0.03, 0.03)
				img.set_pixel(x, y, Color(tape_val, tape_val, tape_val * 0.95, 1.0))
			else:
				var n: float = randf_range(-0.04, 0.04)
				img.set_pixel(x, y, Color(0.25 + n, 0.32 + n, 0.22 + n, 1.0))
	img.save_png("res://assets/textures/tex_c4_block.png")

func _create_detonator_texture() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var is_side_grip: bool = (x < 30 or x > 226) and (y % 12 < 8)
			if is_side_grip:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.08, 1.0))
			else:
				var n: float = randf_range(-0.03, 0.03)
				img.set_pixel(x, y, Color(0.22 + n, 0.22 + n, 0.24 + n, 1.0))
	img.save_png("res://assets/textures/tex_detonator.png")
