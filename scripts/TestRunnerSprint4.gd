extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- INIZIO VERIFICA SPRINT 4 (Game Feel, Kit Modulare & Tier 1-2) ---")
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var game: Node3D = main_scene.instantiate()
	add_child(game)

	for i in range(5):
		await get_tree().physics_frame

	# 1. Carica il cantiere Tier 2 (Garage)
	var garage_contract: ContractData = load("res://data/contracts/tier2_garage.tres")
	assert(garage_contract != null, "tier2_garage.tres non trovato!")
	print("[1] Caricamento contratto Tier 2: %s..." % garage_contract.title)
	await GameManager.load_contract(garage_contract)

	for i in range(5):
		await get_tree().physics_frame

	var garage: GarageBuilder = GameManager.current_structure as GarageBuilder
	assert(garage != null, "Garage non caricato correttamente!")
	print("[OK] Garage Tier 2 caricato nel cantiere. Blocchi totali: %d" % garage.all_blocks.size())

	# 2. Test penetrazione durezza
	print("[2] Verifica controllo Durezza Materiale...")
	var test_block: DestructibleBlock = garage.all_blocks[0]
	assert(test_block.material_data.hardness_tier == 2, "I blocchi del Garage devono essere Tier 2!")

	var initial_hp: float = test_block.current_hp
	# Prova con attrezzo Tier 1 (penetration = 1)
	test_block.take_damage(50.0, 1)
	var dmg_taken_t1: float = initial_hp - test_block.current_hp
	print("[OK] Colpo Tier 1 su materiale Tier 2: inflitti %.1f danni (ridotto al 10%% per mancata penetrazione)" % dmg_taken_t1)
	assert(is_equal_approx(dmg_taken_t1, 5.0), "Il danno doveva essere ridotto al 10%!")

	# 3. Equipaggia strumento Tier 2
	print("[3] Equipaggiamento strumento Tier 2 (Mazza 8kg / Demolitore Elettrico)...")
	var t2_tool: ToolData = load("res://data/tools/sledgehammer_8kg.tres")
	EventBus.tool_equipped.emit(t2_tool)
	
	test_block.take_damage(50.0, t2_tool.hardness_penetration)
	var dmg_taken_t2: float = initial_hp - dmg_taken_t1 - test_block.current_hp
	print("[OK] Colpo Tier 2 su materiale Tier 2: inflitti %.1f danni (danno pieno)" % dmg_taken_t2)
	assert(is_equal_approx(dmg_taken_t2, 50.0), "Il danno doveva essere 100% pieno!")

	# 4. Abbatti i pilastri d'angolo per far crollare l'intero tetto
	print("[4] Demolizione dei 4 pilastri portanti del garage per innescare Crollo a Catena del tetto...")
	var collapse_result := {
		"recorded": false,
		"count": 0,
		"mass": 0.0
	}

	EventBus.chain_collapse_triggered.connect(func(cnt: int, mass: float):
		collapse_result["recorded"] = true
		collapse_result["count"] += cnt
		collapse_result["mass"] += mass
	)

	print("[DEBUG] Anchored blocks count in garage: %d" % garage.anchored_blocks.size())
	for a in garage.anchored_blocks:
		print("  -> Anchor: %s pos=%s coord=%s" % [a.name, a.global_position, a.grid_coord])

	# Trova e distruggi i 4 blocchi d'angolo a terra (y=0)
	var corners_destroyed: int = 0
	for b in garage.all_blocks:
		if is_instance_valid(b) and b.grid_coord.y == 0 and b.is_anchored:
			b.shatter(false)
			corners_destroyed += 1

	print("Pilastri a terra distrutti: %d" % corners_destroyed)
	print("[DEBUG] Remaining anchors after destruction: %d" % garage.anchored_blocks.size())
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	print("[OK] Evento Crollo a Catena catturato: %s! Blocchi crollati: %d (Massa: %.0f kg)" % [
		"SI" if collapse_result["recorded"] else "NO",
		collapse_result["count"],
		collapse_result["mass"]
	])
	assert(collapse_result["recorded"] and collapse_result["count"] >= 30, "L'intera soletta del tetto doveva crollare in un evento a catena!")

	print("--- SPRINT 4 COMPLETAMENTE VERIFICATO CON SUCCESSO! ---")
	get_tree().quit(0)
