extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("================================================================")
	print("=== VERIFICA EDIFICI ARCHITETTONICI & PROGRESSIONE LIVELLI ===")
	print("================================================================")

	var contracts: Array[String] = [
		"res://data/contracts/tier1_villa.tres",
		"res://data/contracts/tier2_warehouse.tres",
		"res://data/contracts/tier3_condominium.tres",
		"res://data/contracts/tier4_industrial.tres",
		"res://data/contracts/tier5_skyscraper.tres"
	]

	# 1. Verifica caricamento e instanziazione delle 5 tipologie di edifici logici
	for path in contracts:
		assert(ResourceLoader.exists(path), "File contratto inesistente: %s" % path)
		var c: ContractData = load(path)
		assert(c != null, "Caricamento contratto fallito: %s" % path)
		assert(c.structure_scene != null, "Scena mancante per: %s" % c.title)

		var inst: Node3D = c.structure_scene.instantiate()
		assert(inst != null, "Istanziazione fallita per: %s" % c.title)
		add_child(inst)

		for i in range(2):
			await get_tree().physics_frame

		# Conta blocchi generati ed elementi strutturali
		var block_count: int = 0
		var anchored_count: int = 0
		for child in inst.get_children():
			if child is DestructibleBlock:
				block_count += 1
				if (child as DestructibleBlock).is_anchored:
					anchored_count += 1

		print("[OK] %s (Tier %d): %d blocchi totali | %d ancorati a terra" % [c.title, c.tier, block_count, anchored_count])
		assert(block_count >= 50, "Numero insufficiente di blocchi (%d) per %s" % [block_count, c.title])
		assert(anchored_count >= 4, "Troppi pochi blocchi ancorati (%d) per %s" % [anchored_count, c.title])

		inst.queue_free()
		await get_tree().process_frame

	# 2. Verifica sequenza di gioco e transizione automatica
	print("\n[2] Test avvio partita e transizione automatica al livello successivo...")
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var main_game: Node3D = main_scene.instantiate()
	add_child(main_game)

	for i in range(5):
		await get_tree().physics_frame

	assert(GameManager.current_contract != null, "Nessun contratto caricato all'avvio!")
	print("[OK] Cantiere iniziale attivo: %s (Tier %d)" % [GameManager.current_contract.title, GameManager.current_contract.tier])
	assert(GameManager.current_contract.contract_id == &"tier1_villa", "Il cantiere iniziale deve essere tier1_villa!")

	# Simula completamento contratto Villa
	var initial_money: float = EconomyManager.current_money
	GameManager.complete_current_contract()
	assert(GameManager.contract_bonus_claimed, "Il bonus di completamento deve risultare incassato!")
	assert(EconomyManager.current_money > initial_money, "Il saldo economico non è aumentato!")
	assert(GameManager.auto_advance_timer > 0.0, "Il timer di avanzamento automatico deve essere attivo!")
	print("[OK] Contratto completato: +€%.0f | auto_advance_timer = %.1fs" % [
		EconomyManager.current_money - initial_money,
		GameManager.auto_advance_timer
	])

	# Esegui avanzamento al prossimo cantiere (Capannone)
	GameManager.advance_to_next_contract()
	for i in range(5):
		await get_tree().physics_frame

	assert(GameManager.current_contract != null, "Nessun cantiere caricato dopo l'avanzamento!")
	print("[OK] Avanzamento automatico completato con successo: %s (Tier %d)" % [
		GameManager.current_contract.title,
		GameManager.current_contract.tier
	])
	assert(GameManager.current_contract.contract_id == &"tier2_warehouse", "Il secondo cantiere della sequenza deve essere tier2_warehouse!")

	# 3. Verifica Comandi Crouch e Salto sul Giocatore
	var player: Player = main_game.find_child("Player", true, false) as Player
	assert(player != null, "Player non trovato nella scena!")
	assert(player.base_jump_velocity > 4.5, "Velocità di salto non configurata!")
	assert(player.base_crouch_speed < player.base_walk_speed, "Velocità crouch non calibrata!")
	print("[OK] Controlli Player: Salto (%.1f m/s), Camminata (%.1f m/s), Crouch (%.1f m/s)" % [
		player.base_jump_velocity,
		player.base_walk_speed,
		player.base_crouch_speed
	])

	main_game.queue_free()
	print("\n================================================================")
	print("=== TUTTI I TEST ARCHITETTURA E LIVELLI SUPERATI CON SUCCESSO! ===")
	print("================================================================\n")
	get_tree().quit(0)
