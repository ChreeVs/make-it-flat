extends Node

# Sprint 8 — Regressioni dei bugfix (salvataggi isolati, C4, soglia contratto, query spaziale,
# tasti menu, integrità strutturale di tutti i cantieri).

const CONTRACT_PATHS: Array[String] = [
	"res://data/contracts/tier1_fence.tres",
	"res://data/contracts/tier1_shack.tres",
	"res://data/contracts/tier1_wall.tres",
	"res://data/contracts/tier2_garage.tres",
	"res://data/contracts/tier3_palazzina.tres",
	"res://data/contracts/tier4_warehouse.tres",
	"res://data/contracts/tier5_skyscraper.tres"
]

func _ready() -> void:
	call_deferred("_run_test")

func _wait_physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _run_test() -> void:
	print("=== VERIFICA SPRINT 8 (Bugfix & Regressioni) ===")

	# 1. I test non devono toccare il salvataggio reale
	assert(SaveManager.is_test_mode, "SaveManager deve riconoscere l'esecuzione da TestRunner!")
	assert(SaveManager.SAVE_PATH == SaveManager.TEST_SAVE_PATH, "I test devono usare il salvataggio di test!")
	assert(SaveManager.SETTINGS_PATH == SaveManager.TEST_SETTINGS_PATH, "I test devono usare le impostazioni di test!")
	EconomyManager.reset_for_new_career("easy")
	EconomyManager.add_money(1234.0)
	SaveManager.save_game()
	assert(FileAccess.file_exists(SaveManager.TEST_SAVE_PATH), "Salvataggio di test non scritto!")
	assert(not FileAccess.file_exists(SaveManager.TEST_SAVE_PATH + ".tmp"), "Il file temporaneo deve essere rinominato!")
	SaveManager.load_game()
	assert(is_equal_approx(float(SaveManager.save_data["money"]), 1234.0), "Salvataggio atomico non ricaricato correttamente!")
	print("[OK] Salvataggi isolati in modalità test + scrittura atomica verificata.")

	# 2. Integrità strutturale allo spawn di ogni cantiere (nessun blocco doppio o sospeso)
	for path in CONTRACT_PATHS:
		var c: ContractData = load(path)
		var inst := c.structure_scene.instantiate() as StructureManager
		add_child(inst)
		await _wait_physics(2)
		var coords: Dictionary = {}
		var dupes: int = 0
		for b in inst.all_blocks:
			if coords.has(b.grid_coord):
				dupes += 1
			coords[b.grid_coord] = true
		assert(dupes == 0, "%s: %d blocchi con coordinate di griglia duplicate!" % [c.contract_id, dupes])
		assert(not inst.anchored_blocks.is_empty(), "%s: nessun blocco ancorato!" % c.contract_id)
		var before: int = inst.active_intact_blocks.size()
		inst._run_structural_bfs()
		var floating: int = before - inst.active_intact_blocks.size()
		assert(floating == 0, "%s: %d blocchi sospesi nel vuoto allo spawn!" % [c.contract_id, floating])
		# Passo griglia coerente con le forme da 1m: blocchi adiacenti distano ~1m
		assert(is_equal_approx(inst.block_size, 1.0), "%s: passo griglia diverso da 1m!" % c.contract_id)
		print("  [OK] %s: %d blocchi, %d ancorati, 0 duplicati, 0 sospesi" % [c.contract_id, before, inst.anchored_blocks.size()])
		inst.queue_free()
		await get_tree().process_frame

	# 3. Gioco completo: query spaziale, soglia contratto, C4 per simpatia, tasti menu
	var game: Node3D = (load("res://scenes/MainGame.tscn") as PackedScene).instantiate()
	add_child(game)
	await _wait_physics(5)
	GameManager.is_main_menu_open = false

	var garage: ContractData = load("res://data/contracts/tier2_garage.tres")
	await GameManager.load_contract(garage)
	await _wait_physics(4)
	var sm := GameManager.current_structure as StructureManager
	assert(sm != null, "Garage non caricato!")

	# 3a. Query spaziale == scansione lineare
	var center: Vector3 = sm.active_intact_blocks[sm.active_intact_blocks.size() / 2].global_position
	var fast: Array[DestructibleBlock] = sm.get_intact_blocks_in_radius(center, 2.6)
	var slow: Array[DestructibleBlock] = sm._linear_blocks_in_radius(center, 2.6)
	assert(fast.size() == slow.size() and fast.size() > 0, "Query spaziale (%d) diversa dalla scansione lineare (%d)!" % [fast.size(), slow.size()])
	print("[OK] Query spaziale Jolt coerente con la scansione lineare (%d blocchi)." % fast.size())

	# 3b. C4 piazzato su un blocco che viene distrutto prima del detonatore: deve esplodere per simpatia
	var host: DestructibleBlock = null
	for b in sm.active_intact_blocks:
		if not b.is_anchored and b.grid_coord.y >= 1:
			host = b
			break
	assert(host != null, "Nessun blocco ospite trovato per il test C4!")
	var c4: ExplosiveCharge = (load("res://scenes/tools/ExplosiveCharge.tscn") as PackedScene).instantiate()
	GameManager.structure_container.add_child(c4)
	c4.global_position = host.global_position + Vector3(0, 0, 0.5)
	c4.attach_to_block(host)
	GameManager.register_explosive(c4)
	var td: ToolData = EconomyManager.get_tool_data(&"c4_charge")
	assert(is_equal_approx(c4.base_blast_damage, td.base_damage) and is_equal_approx(c4.blast_radius, td.aoe_radius),
		"Il C4 deve usare gli stessi valori mostrati in HUD (ToolData)!")
	var explosions: Array[int] = [0]
	var on_expl := func(_p: Vector3, _r: float): explosions[0] += 1
	EventBus.explosion_triggered.connect(on_expl)
	host.take_damage(999999.0, 9, host.global_position, Vector3.UP)
	await _wait_physics(3)
	EventBus.explosion_triggered.disconnect(on_expl)
	assert(explosions[0] == 1, "Il C4 doveva detonare per simpatia alla distruzione del supporto!")
	assert(GameManager.get_active_explosives_count() == 0, "Il contatore C4 deve azzerarsi dopo la detonazione!")
	print("[OK] C4 su supporto distrutto: detonazione per simpatia + contatore aggiornato.")

	# 3c. Soglia raggiunta: niente incasso automatico (serve [E]); a demolizione totale incasso automatico
	await GameManager.load_contract(garage)
	await _wait_physics(3)
	sm = GameManager.current_structure as StructureManager
	var completed: Array[int] = [0]
	var on_done := func(_c): completed[0] += 1
	EventBus.contract_completed.connect(on_done)
	var target_mass: float = sm.total_initial_mass * 0.90
	var blocks: Array[DestructibleBlock] = sm.active_intact_blocks.duplicate()
	blocks.sort_custom(func(a, b): return a.grid_coord.y > b.grid_coord.y)
	for b in blocks:
		if sm.destroyed_mass >= target_mass:
			break
		if is_instance_valid(b) and not b.is_destroyed and b.freeze and not b.is_anchored:
			b.take_damage(999999.0, 9, b.global_position, Vector3.UP)
			await get_tree().process_frame
	await _wait_physics(2)
	if sm.destroyed_mass / sm.total_initial_mass < 0.999 and not sm.active_intact_blocks.is_empty():
		assert(sm.threshold_reached, "La soglia dell'88% doveva essere raggiunta!")
		assert(completed[0] == 0 and not GameManager.contract_bonus_claimed, "Il premio NON deve essere incassato in automatico alla soglia!")
		print("[OK] Soglia 88% raggiunta: premio in attesa del tasto [E].")
	for b in sm.active_intact_blocks.duplicate():
		if is_instance_valid(b) and not b.is_destroyed:
			b.take_damage(999999.0, 9, b.global_position, Vector3.UP)
	await _wait_physics(3)
	assert(completed[0] == 1 and GameManager.contract_bonus_claimed, "A demolizione totale il premio va incassato automaticamente!")
	EventBus.contract_completed.disconnect(on_done)
	print("[OK] Demolizione 100%: premio accreditato automaticamente una sola volta.")

	# 3d. [B] apre lo Shop, [K] apre l'Albero Abilità
	var shop := game.find_child("ShopMenu", true, false)
	var skills := game.find_child("SkillTreeMenu", true, false)
	_press_action("toggle_shop")
	assert(shop.visible and GameManager.is_shop_open and not skills.visible, "[B] deve aprire lo Shop!")
	_press_action("toggle_shop")
	assert(not shop.visible, "[B] deve richiudere lo Shop!")
	_press_action("toggle_skills")
	assert(skills.visible and GameManager.is_skill_tree_open, "[K] deve aprire l'Albero Abilità!")
	_press_action("toggle_skills")
	print("[OK] Tasti menu: [B] Shop, [K] Albero Abilità.")

	# 3e. Il drone non lavora nel menu principale
	GameManager.is_main_menu_open = true
	SaveManager.save_data["upgrades"]["automation_drone"] = 3
	await GameManager.load_contract(garage)
	await _wait_physics(3)
	sm = GameManager.current_structure as StructureManager
	var intact_before: int = sm.active_intact_blocks.size()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await get_tree().physics_frame
	assert(sm.active_intact_blocks.size() == intact_before, "Il drone non deve demolire mentre si è nel menu principale!")
	print("[OK] Drone inattivo nel menu principale.")

	print("=== TUTTI I TEST SPRINT 8 SUPERATI! ===")
	get_tree().quit(0)

func _press_action(action: String) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var ev := (events[0] as InputEventKey).duplicate() as InputEventKey
	ev.pressed = true
	ev.keycode = ev.physical_keycode
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
