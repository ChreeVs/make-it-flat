extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("=== VERIFICA SPRINT 7 (Architettura, Scale, Skill Tree & C4) ===")
	print("==================================================================")

	# 1. Verifica caricamento, stabilità e scale interne di tutti i 7 cantieri reali
	var contracts: Array[Dictionary] = [
		{"path": "res://data/contracts/tier1_fence.tres", "expect_stairs": false, "min_blocks": 18},
		{"path": "res://data/contracts/tier1_shack.tres", "expect_stairs": false, "min_blocks": 80},
		{"path": "res://data/contracts/tier1_wall.tres", "expect_stairs": false, "min_blocks": 40},
		{"path": "res://data/contracts/tier2_garage.tres", "expect_stairs": true, "min_blocks": 200},
		{"path": "res://data/contracts/tier3_palazzina.tres", "expect_stairs": true, "min_blocks": 300},
		{"path": "res://data/contracts/tier4_warehouse.tres", "expect_stairs": true, "min_blocks": 250},
		{"path": "res://data/contracts/tier5_skyscraper.tres", "expect_stairs": true, "min_blocks": 350}
	]

	for entry in contracts:
		var path: String = entry["path"]
		assert(ResourceLoader.exists(path), "File contratto inesistente: %s" % path)
		var c: ContractData = load(path) as ContractData
		assert(c != null and c.structure_scene != null, "Contratto/Scena non validi: %s" % path)

		var inst: Node3D = c.structure_scene.instantiate() as Node3D
		assert(inst != null, "Istanziazione fallita: %s" % c.title)
		add_child(inst)

		for i in range(2):
			await get_tree().physics_frame

		var block_count: int = 0
		var anchored_count: int = 0
		var stair_count: int = 0
		for child in inst.get_children():
			if child is DestructibleBlock:
				var blk := child as DestructibleBlock
				block_count += 1
				if blk.is_anchored:
					anchored_count += 1
				if blk.block_shape in [
					DestructibleBlock.BlockShape.STAIR_NORTH,
					DestructibleBlock.BlockShape.STAIR_SOUTH,
					DestructibleBlock.BlockShape.STAIR_EAST,
					DestructibleBlock.BlockShape.STAIR_WEST
				]:
					stair_count += 1

		assert(block_count >= int(entry["min_blocks"]), "Blocchi insufficienti (%d) in %s" % [block_count, c.title])
		assert(anchored_count >= 2, "Ancoraggi insufficienti (%d) in %s" % [anchored_count, c.title])
		if bool(entry["expect_stairs"]):
			assert(stair_count > 0, "Scale interne mancanti in %s!" % c.title)

		print("[OK] %s (T%d): %d blocchi | %d ancorati | %d rampe scale" % [
			c.title, c.tier, block_count, anchored_count, stair_count
		])
		inst.queue_free()
		await get_tree().process_frame

	# 2. Verifica Economia C4 a pagamento e Albero delle Abilità
	print("\n[2] Verifica costo C4 per carica e prerequisiti Skill Tree...")
	EconomyManager.reset_for_new_career()
	assert(EconomyManager.get_c4_unit_cost() == EconomyManager.C4_BASE_UNIT_COST, "Costo base C4 non allineato!")
	assert(not EconomyManager.try_pay_c4_charge(), "Il C4 deve fallire con saldo insufficiente!")
	EconomyManager.add_money(500.0)
	assert(EconomyManager.try_pay_c4_charge(), "Il C4 deve scalare il costo con fondi sufficienti!")
	assert(is_equal_approx(EconomyManager.current_money, 500.0 - EconomyManager.C4_BASE_UNIT_COST), "Saldo post-C4 errato!")

	# Verifica prerequisiti albero delle abilità
	assert(not EconomyManager.is_skill_prereq_met(&"attack_speed"), "attack_speed deve richiedere tool_damage >= 1!")
	assert(not EconomyManager.purchase_upgrade(&"attack_speed", true), "Acquisto senza prerequisito deve essere bloccato!")
	assert(EconomyManager.purchase_upgrade(&"tool_damage", true), "Acquisto nodo radice tool_damage fallito!")
	assert(EconomyManager.is_skill_prereq_met(&"attack_speed"), "Prerequisito attack_speed ora deve essere soddisfatto!")
	print("[OK] C4 a pagamento (€%.0f/carica) e prerequisiti Skill Tree verificati." % EconomyManager.get_c4_unit_cost())

	# 3. Verifica MainGame, Ambientazione 3D, Menu Principale, SkillTree, Impostazioni & Fisica Scale
	print("\n[3] Verifica MainGame, UI completa e salita scale Player...")
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var main_game: Node3D = main_scene.instantiate() as Node3D
	add_child(main_game)

	for i in range(4):
		await get_tree().physics_frame

	assert(main_game.find_child("EnvironmentScenery", true, false) != null, "EnvironmentScenery mancante!")
	assert(main_game.find_child("MainMenu", true, false) != null, "MainMenu mancante!")
	assert(main_game.find_child("SkillTreeMenu", true, false) != null, "SkillTreeMenu mancante!")
	assert(main_game.find_child("SettingsMenu", true, false) != null, "SettingsMenu mancante!")
	assert(main_game.find_child("HUD", true, false) != null, "HUD mancante!")

	var player: Player = main_game.find_child("Player", true, false) as Player
	assert(player != null, "Player non trovato!")
	assert(player.floor_max_angle >= deg_to_rad(50.0), "floor_max_angle troppo basso per salire le scale!")
	assert(player.floor_snap_length >= 0.30, "floor_snap_length troppo basso per scale fluide!")
	print("[OK] MainGame, UI (MainMenu/SkillTree/Settings/HUD) e fisica scale Player verificati.")

	main_game.queue_free()
	print("\n==================================================================")
	print("=== TUTTI I TEST SPRINT 7 SUPERATI CON SUCCESSO! ===")
	print("==================================================================\n")
	get_tree().quit(0)
