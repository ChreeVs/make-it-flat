class_name MainMenu
extends Control

@onready var title_screen: Control = $TitleScreen
@onready var career_summary: PanelContainer = $TitleScreen/SideBar/VBox/CareerSummary
@onready var summary_text: Label = $TitleScreen/SideBar/VBox/CareerSummary/SummaryText
@onready var continue_btn: Button = $TitleScreen/SideBar/VBox/ContinueButton
@onready var new_game_btn: Button = $TitleScreen/SideBar/VBox/NewGameButton
@onready var intro_btn: Button = $TitleScreen/SideBar/VBox/IntroButton
@onready var settings_btn: Button = $TitleScreen/SideBar/VBox/SettingsButton
@onready var quit_btn: Button = $TitleScreen/SideBar/VBox/QuitButton

@onready var pause_overlay: Control = $PauseOverlay
@onready var resume_btn: Button = $PauseOverlay/PausePanel/VBox/ResumeButton
@onready var pause_skills_btn: Button = $PauseOverlay/PausePanel/VBox/PauseSkillsButton
@onready var pause_settings_btn: Button = $PauseOverlay/PausePanel/VBox/PauseSettingsButton
@onready var pause_intro_btn: Button = $PauseOverlay/PausePanel/VBox/PauseIntroButton
@onready var back_to_title_btn: Button = $PauseOverlay/PausePanel/VBox/BackToTitleButton

@onready var intro_overlay: Control = $IntroOverlay
@onready var step_indicator: Label = $IntroOverlay/IntroPanel/VBox/StepIndicator
@onready var intro_title: Label = $IntroOverlay/IntroPanel/VBox/IntroTitle
@onready var intro_body: Label = $IntroOverlay/IntroPanel/VBox/IntroBody
@onready var prev_step_btn: Button = $IntroOverlay/IntroPanel/VBox/ButtonsRow/PrevStepButton
@onready var skip_intro_btn: Button = $IntroOverlay/IntroPanel/VBox/ButtonsRow/SkipIntroButton
@onready var next_step_btn: Button = $IntroOverlay/IntroPanel/VBox/ButtonsRow/NextStepButton

const INTRO_STEPS: Array[Dictionary] = [
	{
		"title": "1. Demolisci con Strategia & Fisica Reale",
		"body": "Sei il capo-cantiere di una ditta di demolizioni in prima persona.\n\n• Ogni edificio è costruito con pilastri portanti, solette, vetrate, tetti e SCALE INTERNE PERCORRIBILI: entra nelle strutture, sali ai piani superiori e studia i punti deboli.\n• Abbatti i pilastri alla base per far collassare l'intera struttura in un crollo a catena e incassare bonus enormi.\n• Raggiunta la soglia dell'88%, i pochi blocchi residui si illuminano a raggi X e puoi premere [E] per riscuotere il premio commessa."
	},
	{
		"title": "2. Economia, Albero Abilità & Costo del C4",
		"body": "Ogni blocco demolito aumenta il tuo capitale in tempo reale:\n\n• Premi [K] per aprire l'ALBERO DELLE ABILITÀ a 3 rami (Potenza & C4, Economia & Fisica, Mobilità & Drone).\n• Premi [B] per l'OFFICINA STRUMENTI e le Licenze Tier 2–5.\n• Attenzione al C4: è devastante contro cemento armato e acciaio, ma OGNI CARICA PIAZZATA COSTA DENARO (€180 base, scontabile nell'Albero Abilità)! Piazzalo con intelligenza sui pilastri chiave e innesca con il Detonatore [7]."
	},
	{
		"title": "3. Comandi Principali di Cantiere",
		"body": "• WASD + SHIFT + SPAZIO: Muoviti, corri, salta e sali le scale interne degli edifici\n• CLICK SINISTRO: Colpisci / Demolisci / Piazza C4 / Detona\n• TASTI [1–7] o ROTELLINA MOUSE: Cambia strumento equipaggiato\n• [B] Officina Strumenti   •   [K] Albero Abilità   •   [C] Commesse\n• [E] Incassa Premio Commessa (oltre l'88%)   •   [R] Ripristina Cantiere\n• [ESC] Menu Pausa & Impostazioni (Audio, Mouse, FOV, Grafica)"
	}
]

var _intro_step: int = 0
var _start_game_after_intro: bool = false

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	intro_btn.pressed.connect(func(): open_intro(false))
	settings_btn.pressed.connect(_open_settings)
	quit_btn.pressed.connect(func(): get_tree().quit())

	resume_btn.pressed.connect(resume_game)
	pause_skills_btn.pressed.connect(_on_pause_open_skills)
	pause_settings_btn.pressed.connect(_open_settings)
	pause_intro_btn.pressed.connect(func(): open_intro(false))
	back_to_title_btn.pressed.connect(open_title_screen)

	prev_step_btn.pressed.connect(_on_intro_prev)
	next_step_btn.pressed.connect(_on_intro_next)
	skip_intro_btn.pressed.connect(close_intro)

	open_title_screen()

func open_title_screen() -> void:
	GameManager.close_gameplay_overlays()
	GameManager.is_main_menu_open = true
	GameManager.is_pause_menu_open = false
	GameManager.is_intro_open = false

	visible = true
	title_screen.visible = true
	pause_overlay.visible = false
	intro_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var has_save: bool = SaveManager.has_existing_career()
	continue_btn.visible = has_save
	career_summary.visible = has_save
	if has_save:
		var completed: int = SaveManager.save_data.get("completed_contracts", []).size()
		summary_text.text = "Carriera Salvata  •  Capitale: € %d  •  Licenza Tier %d\nCommesse completate: %d  •  Prestigio: x%.1f" % [
			int(EconomyManager.current_money),
			EconomyManager.unlocked_tier,
			completed,
			EconomyManager.permanent_multiplier
		]

	EventBus.game_state_changed.emit("main_menu")

func _on_continue_pressed() -> void:
	EventBus.ui_click.emit()
	_enter_gameplay()

func _on_new_game_pressed() -> void:
	EventBus.ui_click.emit()
	if SaveManager.has_existing_career():
		EconomyManager.reset_for_new_career()
		var t1: ContractData = load("res://data/contracts/tier1_fence.tres")
		if t1:
			GameManager.load_contract(t1)

	if not bool(SaveManager.save_data.get("has_seen_intro", false)):
		open_intro(true)
	else:
		_enter_gameplay()

func _enter_gameplay() -> void:
	GameManager.is_main_menu_open = false
	GameManager.is_pause_menu_open = false
	GameManager.is_intro_open = false
	title_screen.visible = false
	pause_overlay.visible = false
	intro_overlay.visible = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.game_state_changed.emit("playing")

func open_pause_menu() -> void:
	GameManager.close_gameplay_overlays()
	GameManager.is_pause_menu_open = true
	visible = true
	title_screen.visible = false
	intro_overlay.visible = false
	pause_overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_click.emit()
	EventBus.game_state_changed.emit("paused")

func resume_game() -> void:
	EventBus.ui_click.emit()
	GameManager.is_pause_menu_open = false
	pause_overlay.visible = false
	visible = false
	if not GameManager.is_any_ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.game_state_changed.emit("playing")

func _on_pause_open_skills() -> void:
	GameManager.is_pause_menu_open = false
	pause_overlay.visible = false
	visible = false
	var st := get_tree().get_root().find_child("SkillTreeMenu", true, false)
	if st and st.has_method("open_menu"):
		st.open_menu()

func _open_settings() -> void:
	EventBus.ui_click.emit()
	var sm := get_tree().get_root().find_child("SettingsMenu", true, false)
	if sm and sm.has_method("open_settings"):
		sm.open_settings()

func open_intro(start_after: bool = false) -> void:
	EventBus.ui_click.emit()
	_start_game_after_intro = start_after
	_intro_step = 0
	GameManager.is_intro_open = true
	visible = true
	intro_overlay.visible = true
	_refresh_intro_page()

func close_intro() -> void:
	EventBus.ui_click.emit()
	GameManager.is_intro_open = false
	intro_overlay.visible = false
	SaveManager.save_data["has_seen_intro"] = true
	SaveManager.save_game()

	if _start_game_after_intro:
		_start_game_after_intro = false
		_enter_gameplay()
	elif not GameManager.is_main_menu_open and not GameManager.is_pause_menu_open:
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_intro_page() -> void:
	var step: Dictionary = INTRO_STEPS[_intro_step]
	step_indicator.text = "BRIEFING DI CANTIERE  •  SCHEDA %d / %d" % [_intro_step + 1, INTRO_STEPS.size()]
	intro_title.text = step["title"]
	intro_body.text = step["body"]
	prev_step_btn.disabled = (_intro_step == 0)
	if _intro_step >= INTRO_STEPS.size() - 1:
		next_step_btn.text = "INIZIA DEMOLIZIONE!" if _start_game_after_intro else "Ho capito!"
	else:
		next_step_btn.text = "Avanti →"

func _on_intro_prev() -> void:
	if _intro_step > 0:
		_intro_step -= 1
		EventBus.ui_click.emit()
		_refresh_intro_page()

func _on_intro_next() -> void:
	if _intro_step < INTRO_STEPS.size() - 1:
		_intro_step += 1
		EventBus.ui_click.emit()
		_refresh_intro_page()
	else:
		close_intro()
