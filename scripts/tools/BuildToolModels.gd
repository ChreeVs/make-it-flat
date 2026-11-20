extends SceneTree

# Strumento di sviluppo: genera le scene dei modelli strumenti in prima persona a partire dai glTF
# Poly Haven (CC0). Struttura: Radice -> "Tilt" (inclinazione/posizione in mano) -> modello (yaw/scala/offset).
# Uso: Godot --headless --path . --script res://scripts/tools/BuildToolModels.gd

const PH := "res://assets/polyhaven/models/%s/%s_1k.gltf"

const TOOLS: Array[Dictionary] = [
	{"out": "CrowbarModel", "model": "crowbar_01", "tilt": Vector3(-42, 0, 0), "pos": Vector3(-0.02, -0.02, -0.10), "yaw": 180.0, "scale": 1.45, "offset": Vector3(0, 0.02, 0)},
	{"out": "HammerModel", "model": "cross_pein_hammer", "tilt": Vector3(-38, 0, 0), "pos": Vector3(-0.02, -0.04, -0.10), "yaw": 90.0, "scale": 1.9, "offset": Vector3(0, 0.03, 0)},
	{"out": "Sledgehammer3kgModel", "model": "sledgehammer_01", "tilt": Vector3(-35, 0, 0), "pos": Vector3(-0.02, -0.05, -0.14), "yaw": 90.0, "scale": 0.88, "offset": Vector3(0, 0.19, 0)},
	{"out": "Sledgehammer8kgModel", "model": "sledgehammer_01", "tilt": Vector3(-35, 0, 0), "pos": Vector3(-0.02, -0.07, -0.16), "yaw": 90.0, "scale": 1.0, "offset": Vector3(0, 0.22, 0)}
]

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		# I nodi interni del glTF istanziato restano parte della sotto-scena: non vanno serializzati
		if c.scene_file_path == "":
			_set_owner_recursive(c, owner)

func _init() -> void:
	for t in TOOLS:
		var root := Node3D.new()
		root.name = t["out"]
		var tilt := Node3D.new()
		tilt.name = "Tilt"
		tilt.rotation_degrees = t["tilt"]
		tilt.position = t["pos"]
		root.add_child(tilt)
		var ps: PackedScene = load(PH % [t["model"], t["model"]])
		var model := ps.instantiate() as Node3D
		model.name = "Model"
		model.rotation_degrees = Vector3(0, t["yaw"], 0)
		model.scale = Vector3.ONE * float(t["scale"])
		model.position = t["offset"]
		tilt.add_child(model)
		_set_owner_recursive(root, root)
		var packed := PackedScene.new()
		var err := packed.pack(root)
		if err == OK:
			err = ResourceSaver.save(packed, "res://scenes/tools/models/%s.tscn" % t["out"])
		print("%s -> %s" % [t["out"], "OK" if err == OK else "ERR %d" % err])
		root.free()
	quit()
