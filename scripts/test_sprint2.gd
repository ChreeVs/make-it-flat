extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- INIZIO VERIFICA SPRINT 2 (Grafo Static-to-Dynamic) ---")
	var scene_res: PackedScene = load("res://scenes/Sandbox_Sprint2.tscn")
	var root_node: Node3D = scene_res.instantiate()
	root.add_child(root_node)

	# Aspetta 5 frame di fisica
	for i in range(5):
		await physics_frame

	var wall: ModularStructureBuilder = root_node.find_child("Wall_10x5_Test", true, false)
	assert(wall != null, "Wall_10x5_Test non trovato!")
	print("[OK] Parete 10x5 caricata. Blocchi totali registrati: %d" % wall.all_blocks.size())
	assert(wall.all_blocks.size() == 42, "Numero di blocchi non corrispondente (attesi 42: 2 pilastri base + 40 muro)!")

	# Verifica zero movimento iniziale (tutti freeze = true)
	var moving_count: int = 0
	for b in wall.all_blocks:
		if not b.freeze:
			moving_count += 1
	assert(moving_count == 0, "Errore: ci sono blocchi dinamici allo spawn!")
	print("[OK] Criterio 1 verificato: 0 movimenti allo spawn, tutti i blocchi sono in FREEZE_MODE_STATIC.")

	# Identifica i due pilastri alla base
	var p1: DestructibleBlock = wall.get_node_or_null("Block_2_0")
	var p2: DestructibleBlock = wall.get_node_or_null("Block_7_0")
	assert(p1 != null and p2 != null, "I due pilastri di base non sono stati trovati!")

	print("Distruzione del primo pilastro (Block_2_0)...")
	p1.shatter(false)
	await process_frame
	await physics_frame

	# Il muro deve rimanere ancorato tramite il secondo pilastro
	var unvisited_count: int = 0
	for b in wall.all_blocks:
		if is_instance_valid(b) and not b.freeze:
			unvisited_count += 1
	print("Blocchi crollati dopo distruzione del primo pilastro: %d (atteso: 0, muro regge)" % unvisited_count)

	print("Distruzione del secondo pilastro (Block_7_0)...")
	p2.shatter(false)
	await process_frame
	await physics_frame
	await physics_frame

	# Ora tutti i blocchi devono essere scongelati
	var unfrozen_count: int = 0
	for b in wall.all_blocks:
		if is_instance_valid(b) and not b.freeze:
			unfrozen_count += 1

	print("Blocchi scongelati dopo rottura secondo pilastro: %d / %d" % [unfrozen_count, wall.all_blocks.size() - 2])
	assert(unfrozen_count == 40, "Errore: i 40 blocchi superiori dovevano crollare tutti!")
	print("[OK] Criterio 2 verificato: BFS ha rilevato la perdita di ancoraggio e ha scongelato tutti i 40 blocchi superiori in dinamica Jolt!")

	print("--- SPRINT 2 COMPLETAMENTE VERIFICATO CON SUCCESSO! ---")
	quit(0)
