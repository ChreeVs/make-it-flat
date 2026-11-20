extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("=========================================================================")
	print("=== VERIFICA SPRINT 7 (Grattacielo Arredato, Difficoltà & Comandi) ===")
	print("=========================================================================")

	# 1. Verifica generazione Grattacielo Arredato per tutte e 3 le difficoltà (Facile 4P / Normale 6P / Hardcore 8P)
	var diff_specs: Array[Dictionary] = [
		{"id": "easy", "floors": 4, "min_blocks": 900},
		{"id": "normal", "floors": 6, "min_blocks": 1350},
		{"id": "hardcore", "floors": 8, "min_blocks": 1800}
	]

	var sky_contract: ContractData = load("res://data/contracts/tier5_skyscraper.tres") as ContractData
	assert(sky_contract != null and sky_contract.structure_scene != null, "Contratto grattacielo non valido!")

	for spec in diff_specs:
		EconomyManager.set_difficulty(String(spec["id"]))
		assert(EconomyManager.get_target_skyscraper_floors() == int(spec["floors"]), "Conteggio piani errato per %s" % spec["id"])

		var inst: Node3D = sky_contract.structure_scene.instantiate() as Node3D
		add_child(inst)
		for i in range(2):
			await get_tree().physics_frame

		var block_count: int = 0
		var anchored_count: int = 0
		var stair_count: int = 0
		var furniture_count: int = 0
		var has_toilet: bool = false
		var has_bar: bool = false
		var has_desk: bool = false
		var has_bed: bool = false

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
				if blk.block_shape >= DestructibleBlock.BlockShape.FURN_DESK:
					furniture_count += 1
				if blk.block_shape == DestructibleBlock.BlockShape.FURN_TOILET:
					has_toilet = true
				elif blk.block_shape == DestructibleBlock.BlockShape.FURN_BAR_COUNTER:
					has_bar = true
				elif blk.block_shape == DestructibleBlock.BlockShape.FURN_DESK:
					has_desk = true
				elif blk.block_shape == DestructibleBlock.BlockShape.FURN_BED:
					has_bed = true

		assert(block_count >= int(spec["min_blocks"]), "Blocchi insufficienti (%d) in %s" % [block_count, spec["id"]])
		assert(anchored_count >= 4, "Ancoraggi insufficienti (%d) in %s" % [anchored_count, spec["id"]])
		assert(stair_count >= int(spec["floors"]) * 4, "Scale interne insufficienti (%d) in %s" % [stair_count, spec["id"]])
		assert(furniture_count >= 120, "Arredi interni insufficienti (%d) in %s" % [furniture_count, spec["id"]])
		assert(has_toilet and has_bar and has_desk and has_bed, "Arredi chiave (WC/Bar/Ufficio/Appartamento) mancanti in %s!" % spec["id"])

		print("[OK] Grattacielo %s (%d piani): %d blocchi | %d arredi | %d scale | %d ancorati" % [
			String(spec["id"]).to_upper(), int(spec["floors"]), block_count, furniture_count, stair_count, anchored_count
		])
		inst.queue_free()
		await get_tree().process_frame

	# 2. Verifica Sblocco Automatico Strumenti tramite Potenziamenti + Costo C4
	print("\n[2] Verifica sblocco automatico strumenti via Skill Tree e costo C4...")
	EconomyManager.reset_for_new_career("easy")
	assert(not EconomyManager.unlocked_tools.has("hammer"), "Martello deve partire bloccato!")
	assert(not EconomyManager.try_pay_c4_charge(), "Il C4 deve fallire con saldo insufficiente!")

	EconomyManager.add_money(25000.0)
	var expected_c4_cost: float = EconomyManager.get_c4_unit_cost()
	assert(expected_c4_cost == 90.0, "In Facile il C4 base deve costare €90!")

	assert(not EconomyManager.is_skill_prereq_met(&"attack_speed"), "attack_speed deve richiedere tool_damage >= 1!")
	assert(EconomyManager.purchase_upgrade(&"tool_damage", true), "Acquisto tool_damage Lv.1 fallito!")
	assert(EconomyManager.unlocked_tools.has("hammer"), "tool_damage Lv.1 deve sbloccare automaticamente il Martello!")

	assert(EconomyManager.purchase_upgrade(&"attack_speed", true), "Acquisto attack_speed Lv.1 fallito!")
	assert(EconomyManager.unlocked_tools.has("sledgehammer_3kg"), "attack_speed Lv.1 deve sbloccare Mazza 3kg!")
	assert(EconomyManager.purchase_upgrade(&"attack_speed", true), "Acquisto attack_speed Lv.2 fallito!")
	assert(EconomyManager.purchase_upgrade(&"attack_speed", true), "Acquisto attack_speed Lv.3 fallito!")
	assert(EconomyManager.unlocked_tools.has("sledgehammer_8kg"), "attack_speed Lv.3 deve sbloccare Mazza 8kg!")

	assert(EconomyManager.purchase_upgrade(&"aoe_boost", true), "Acquisto aoe_boost Lv.1 fallito!")
	assert(EconomyManager.unlocked_tools.has("electric_demolisher"), "aoe_boost Lv.1 deve sbloccare Demolitore Elettrico!")

	assert(EconomyManager.purchase_upgrade(&"c4_discount", true), "Acquisto c4_discount Lv.1 fallito!")
	assert(EconomyManager.unlocked_tools.has("c4_charge") and EconomyManager.unlocked_tools.has("remote_detonator"),
		"c4_discount Lv.1 deve sbloccare C4 e Detonatore Remoto!")

	var pre_c4_money: float = EconomyManager.current_money
	assert(EconomyManager.try_pay_c4_charge(), "Il C4 deve scalare il costo con fondi sufficienti!")
	assert(is_equal_approx(EconomyManager.current_money, pre_c4_money - expected_c4_cost), "Saldo post-C4 errato!")
	print("[OK] Tutti i 7 strumenti sbloccati automaticamente via Skill Tree + C4 a pagamento verificato.")

	# 3. Verifica MainGame, Ambientazione Metropolitana, UI completa & Comandi Player (Scale + Accovacciamento)
	print("\n[3] Verifica MainGame, UI completa e controller Player...")
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
	assert(player.base_crouch_speed > 0.0, "Accovacciamento Player non configurato!")
	print("[OK] MainGame, UI (MainMenu/Difficoltà/SkillTree/Settings/HUD) e Player (Scale + Crouch) verificati.")

	main_game.queue_free()
	print("\n=========================================================================")
	print("=== TUTTI I TEST SPRINT 7 (GRATTACIELO ARREDATO) SUPERATI! ===")
	print("=========================================================================\n")
	get_tree().quit(0)
