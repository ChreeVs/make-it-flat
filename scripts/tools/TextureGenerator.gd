@tool
extends SceneTree

func _init() -> void:
	print("--- GENERAZIONE TEXTURE STRUMENTI PBR ---")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets/textures"):
		dir.make_dir_recursive("assets/textures")

	_create_wood_texture()
	_create_painted_metal_texture()
	_create_dark_steel_texture()
	_create_hazard_texture()
	_create_demolisher_texture()
	_create_c4_texture()
	_create_detonator_texture()

	print("--- TUTTE LE TEXTURE GENERATE CON SUCCESSO IN res://assets/textures/ ---")
	quit(0)

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
				scratch = randf_range(0.2, 0.5) # Metallo vivo esposto
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
