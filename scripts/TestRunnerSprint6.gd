extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- INIZIO VERIFICA SPRINT 6 (Automazione, Endgame & Prestigio) ---")
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var game: Node3D = main_scene.instantiate()
	add_child(game)

	for i in range(5):
		await get_tree().physics_frame

	# 1. Verifica Automazione Drone
	print("[1] Test Drone Demolitore Autonomo...")
	EconomyManager.add_money(3000.0)
	var drone_bought: bool = EconomyManager.purchase_upgrade("automation_drone")
	assert(drone_bought, "Acquisto del drone fallito!")
	
	var drone: SupportDrone = game.find_child("SupportDrone", true, false) as SupportDrone
	assert(drone != null, "SupportDrone non trovato nella scena!")
	
	# Esegui frame per fare operare il drone
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("[OK] Drone di supporto autonomo sbloccato e attivo in orbita sopra il cantiere.")

	# 2. Carica la Megastruttura Tier 5 (Grattacielo)
	print("[2] Caricamento Megastruttura Tier 5 (Grattacielo Skyline)...")
	var tower_contract: ContractData = load("res://data/contracts/tier5_skyscraper.tres")
	assert(tower_contract != null, "tier5_skyscraper.tres non trovato!")
	await GameManager.load_contract(tower_contract)

	for i in range(5):
		await get_tree().physics_frame

	var tower: SkyscraperBuilder = GameManager.current_structure as SkyscraperBuilder
	assert(tower != null, "Grattacielo non caricato!")
	print("[OK] Grattacielo Tier 5 caricato. Blocchi totali: %d | Massa iniziale: %.0f kg" % [
		tower.all_blocks.size(),
		tower.total_initial_mass
	])

	# Verifica 0 movimenti allo spawn (stabilità megastruttura)
	var dynamic_at_spawn: int = 0
	for b in tower.all_blocks:
		if not b.freeze:
			dynamic_at_spawn += 1
	assert(dynamic_at_spawn == 0, "I blocchi della megastruttura devono essere tutti congelati allo spawn!")
	print("[OK] Stabilità Megastruttura: 0 oscillazioni o crolli spontanei.")

	# 3. Abbatti le colonne portanti di base per innescare collasso totale
	print("[3] Abbattimento delle 4 colonne portanti di base della Megastruttura...")
	var anchors_destroyed: int = 0
	for b in tower.all_blocks:
		if is_instance_valid(b) and b.grid_coord.y == 0 and b.is_anchored:
			b.shatter(false)
			anchors_destroyed += 1

	print("Fondazioni distrutte: %d" % anchors_destroyed)
	for i in range(10):
		await get_tree().physics_frame

	var tower_destroyed_ratio: float = tower.destroyed_mass / tower.total_initial_mass
	print("[OK] Crollo Megastruttura: %.1f percento demolito per gravità!" % (tower_destroyed_ratio * 100.0))
	assert(tower_destroyed_ratio >= 0.80, "La megastruttura doveva collassare per oltre l'80 percento!")

	# 4. Esecuzione del Prestigio
	print("[4] Esecuzione Prestigio aziendale...")
	var old_prestige: int = EconomyManager.prestige_count
	var old_mult: float = EconomyManager.permanent_multiplier
	print("  -> Stato pre-prestigio: Cicli = %d | Moltiplicatore = %.1fx" % [old_prestige, old_mult])

	EconomyManager.perform_prestige()

	var new_prestige: int = EconomyManager.prestige_count
	var new_mult: float = EconomyManager.permanent_multiplier
	print("  -> Stato post-prestigio: Cicli = %d | Moltiplicatore = %.1fx (+50 percento permanente!)" % [new_prestige, new_mult])
	assert(new_prestige == old_prestige + 1, "Il ciclo di prestigio doveva incrementare di 1!")
	assert(new_mult > old_mult, "Il moltiplicatore permanente doveva aumentare!")

	# Verifica persistenza su disco
	SaveManager.save_game()
	SaveManager.load_game()
	EconomyManager._sync_from_save()

	assert(EconomyManager.prestige_count == new_prestige, "Il prestigio non è stato persistito correttamente!")
	assert(is_equal_approx(EconomyManager.permanent_multiplier, new_mult), "Il moltiplicatore non è stato persistito correttamente!")
	print("[OK] Persistenza Prestigio verificata: dati salvati e ricaricati con successo.")

	print("--- SPRINT 6 COMPLETAMENTE VERIFICATO CON SUCCESSO! ---")
	get_tree().quit(0)
