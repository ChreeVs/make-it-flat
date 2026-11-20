extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- INIZIO VERIFICA SPRINT 5 (Distruzione Avanzata Tier 3-4 & C4) ---")
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var game: Node3D = main_scene.instantiate()
	add_child(game)

	for i in range(5):
		await get_tree().physics_frame

	# 1. Carica la Palazzina 3 Piani
	var palazzina_contract: ContractData = load("res://data/contracts/tier3_palazzina.tres")
	assert(palazzina_contract != null, "tier3_palazzina.tres non trovato!")
	print("[1] Caricamento contratto Tier 3: %s..." % palazzina_contract.title)
	await GameManager.load_contract(palazzina_contract)

	for i in range(5):
		await get_tree().physics_frame

	var building: MultiFloorBuilder = GameManager.current_structure as MultiFloorBuilder
	assert(building != null, "Palazzina non caricata!")
	print("[OK] Palazzina 3 piani caricata. Blocchi totali: %d | Massa iniziale: %.0f kg" % [
		building.all_blocks.size(),
		building.total_initial_mass
	])

	# 2. Identifica i 6 pilastri portanti del piano terra
	var ground_pillars: Array[DestructibleBlock] = []
	for b in building.anchored_blocks:
		if is_instance_valid(b) and b.grid_coord.y == 0:
			ground_pillars.append(b)

	print("[2] Pilastri di fondazione identificati a terra: %d (attesi: 6)" % ground_pillars.size())
	assert(ground_pillars.size() == 6, "I pilastri di fondazione dovevano essere esattamente 6!")

	# 3. Piazza 6 cariche C4 sui 6 pilastri
	print("[3] Posizionamento di 6 cariche C4 sui pilastri portanti...")
	var c4_scene: PackedScene = load("res://scenes/tools/ExplosiveCharge.tscn")
	for pillar in ground_pillars:
		var c4: ExplosiveCharge = c4_scene.instantiate()
		pillar.add_child(c4)
		c4.position = Vector3(0, 0, 0.45)
		GameManager.register_explosive(c4)

	assert(GameManager.placed_explosives.size() == 6, "Dovevano essere registrate 6 cariche C4!")
	print("[OK] 6 cariche C4 armate e pronte alla detonazione sequenziale.")

	# 4. Innesco detonazione sequenziale e misurazione tempi
	print("[4] INNESCO DETONATORE REMOTO! Sequenza di demolizione controllata avviata...")
	var start_time: int = Time.get_ticks_msec()

	var collapse_tracker := {
		"chain_events": 0,
		"fallen_blocks": 0
	}
	EventBus.chain_collapse_triggered.connect(func(cnt: int, _mass: float):
		collapse_tracker["chain_events"] += 1
		collapse_tracker["fallen_blocks"] += cnt
	)

	# Avvia sequenza C4
	GameManager.detonate_all_explosives_sequentially()

	# Aspetta fino a 8 secondi o completamento cantiere
	var elapsed_seconds: float = 0.0
	while elapsed_seconds < 8.0:
		await get_tree().physics_frame
		elapsed_seconds = float(Time.get_ticks_msec() - start_time) / 1000.0
		var current_ratio: float = building.destroyed_mass / building.total_initial_mass
		if current_ratio >= 0.88:
			print("[OK] Soglia di completamento (88 percento) raggiunta in %.2f secondi!" % elapsed_seconds)
			break

	var total_time: float = float(Time.get_ticks_msec() - start_time) / 1000.0
	var final_ratio: float = building.destroyed_mass / building.total_initial_mass
	print("[5] Risultato Demolizione Controllata:")
	print("  -> Tempo totale impiegato: %.2f secondi (limite DoD: < 10.0s)" % total_time)
	print("  -> Percentuale struttura distrutta: %.1f percento (limite DoD: > 80 percento)" % (final_ratio * 100.0))
	print("  -> Eventi di crollo a catena: %d | Blocchi crollati: %d" % [
		collapse_tracker["chain_events"],
		collapse_tracker["fallen_blocks"]
	])

	assert(total_time < 10.0, "La sequenza di detonazione ha impiegato più di 10 secondi!")
	assert(final_ratio >= 0.80, "La palazzina doveva implodere per oltre l'80% della massa!")

	print("--- SPRINT 5 COMPLETAMENTE VERIFICATO CON SUCCESSO! ---")
	get_tree().quit(0)
