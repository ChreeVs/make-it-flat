extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- INIZIO VERIFICA SPRINT 3 (Core Loop Incrementale & UI) ---")
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var game: Node3D = main_scene.instantiate()
	add_child(game)

	# Aspetta 5 frame
	for i in range(5):
		await get_tree().physics_frame

	var initial_money: float = EconomyManager.current_money
	var initial_dmg_mult: float = EconomyManager.get_upgrade_total_multiplier("tool_damage")
	print("[1] Stato Iniziale: Denaro = €%.0f | Moltiplicatore Danno = %.2fx" % [initial_money, initial_dmg_mult])
	assert(initial_dmg_mult == 1.0, "Il moltiplicatore iniziale doveva essere 1.0!")

	# Simula la distruzione di blocchi
	print("[2] Simulazione distruzione blocchi e crollo...")
	var structure: StructureManager = GameManager.current_structure as StructureManager
	assert(structure != null, "Nessuna struttura caricata in GameManager!")
	
	# Rompi 3 blocchi
	var count_to_break: int = mini(3, structure.all_blocks.size())
	for i in range(count_to_break):
		var b: DestructibleBlock = structure.all_blocks[i]
		if is_instance_valid(b) and not b.is_destroyed:
			b.shatter(false)

	await get_tree().process_frame
	await get_tree().physics_frame

	var money_after_break: float = EconomyManager.current_money
	print("[OK] Denaro accumulato dalla distruzione: €%.0f (precedente: €%.0f)" % [money_after_break, initial_money])
	assert(money_after_break > initial_money, "Il denaro doveva aumentare distruggendo i blocchi!")

	# Ora assicuriamoci di avere abbastanza denaro per testare l'acquisto di un upgrade
	EconomyManager.add_money(100.0)
	var cost: float = EconomyManager.get_upgrade_cost("tool_damage")
	print("[3] Acquisto upgrade 'tool_damage' al costo di €%.0f..." % cost)
	
	var buy_success: bool = EconomyManager.purchase_upgrade("tool_damage")
	assert(buy_success, "L'acquisto dell'upgrade 'tool_damage' è fallito!")

	var new_lvl: int = EconomyManager.get_upgrade_level("tool_damage")
	var new_dmg_mult: float = EconomyManager.get_upgrade_total_multiplier("tool_damage")
	print("[OK] Upgrade acquistato: Livello %d | Nuovo Moltiplicatore = %.2fx (+25%%)" % [new_lvl, new_dmg_mult])
	assert(new_lvl == 1 and is_equal_approx(new_dmg_mult, 1.25), "Il nuovo moltiplicatore doveva essere 1.25!")

	# Verifica persistenza su disco
	print("[4] Verifica persistenza del salvataggio su file...")
	var saved_money: float = EconomyManager.current_money
	SaveManager.save_game()

	# Ricarica da zero il file di salvataggio
	SaveManager.load_game()
	EconomyManager._sync_from_save()

	assert(EconomyManager.get_upgrade_level("tool_damage") == 1, "Il livello dell'upgrade non è stato persistito correttamente!")
	assert(is_equal_approx(EconomyManager.current_money, saved_money), "Il denaro non è stato persistito correttamente!")
	print("[OK] Persistenza verificata: dati salvati e ricaricati correttamente da user://save_v1.json!")

	print("--- SPRINT 3 COMPLETAMENTE VERIFICATO CON SUCCESSO! ---")
	get_tree().quit(0)
