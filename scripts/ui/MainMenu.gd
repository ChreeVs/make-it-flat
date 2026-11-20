class_name MainMenu
extends Control

@onready var title_screen: Control = $TitleScreen
@onready var easy_btn: Button = $TitleScreen/SideBar/VBox/DifficultyBox/DiffVBox/DiffButtons/EasyBtn
@onready var normal_btn: Button = $TitleScreen/SideBar/VBox/DifficultyBox/DiffVBox/DiffButtons/NormalBtn
@onready var hardcore_btn: Button = $TitleScreen/SideBar/VBox/DifficultyBox/DiffVBox/DiffButtons/HardcoreBtn
@onready var diff_subtitle: Label = $TitleScreen/SideBar/VBox/DifficultyBox/DiffVBox/DiffSubtitle

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
		"title": "1. Il Grattacielo Interamente Arredato",
		"body": "La tua missione: radere al suolo un gigantesco grattacielo multipiano nel cuore del distretto metropolitano!\n\n• Ogni piano è arredato da cima a fondo: Lobby & Bar con bancone e sgabelli, Uffici con scrivanie e PC, Bagni completi di WC/lavandini/vasche, Appartamenti con letti, cucine e divani, Ristorante Panoramico, Suite VIP e Sala Server.\n• Usa le ampie SCALE INTERNE per salire fino al tetto. Sgomberare ogni piano all'84% assegna un ricco BONUS DI PIANO, mentre abbattere i pilastri portanti a terra scatena crolli a catena!"
	},
	{
		"title": "2. Potenzia le Abilità per Sbloccare Strumenti",
		"body": "Ogni mobile, vetrata o parete distrutta ti fa guadagnare denaro in tempo reale:\n\n• Apri l'ALBERO DELLE ABILITÀ con [K] o [TAB]: potenziando i nodi sblocchi AUTOMATICAMENTE tutto l'arsenale!\n  ★ Forza Lv.1 → Martello [2]  •  Ritmo Lv.1/Lv.3 → Mazze 3kg [3] & 8kg [4]\n  ★ Onda d'Urto Lv.1 → Demolitore Elettrico [5] (T3)  •  Esplosivista Lv.1 → C4 [6] + Detonatore [7] (T4)\n  ★ Drone Laser Lv.1 → Drone autonomo aereo! (Ogni carica C4 ha un costo operativo per evitare spam gratuito.)\n• In modalità FACILE i guadagni sono bilanciati per sbloccare e potenziare TUTTO in una sola demolizione!"
	},
	{
		"title": "3. Comandi Completi & Precisi",
		"body": "• WASD + SHIFT + SPAZIO: Muoviti, corri, salta e sali fluidamente le scale interne\n• CTRL o [C]: Accovacciati per passare sotto macerie e colpire i pilastri bassi\n• CLICK SINISTRO: Colpisci / Demolisci continuo / Piazza carica C4\n• CLICK DESTRO: Colpo Pesante (1.65x danno + mini AoE) oppure Detona subito i C4\n• [1–7] / ROTELLINA / [Q]: Cambia strumento (o scambia rapidamente con l'ultimo usato)\n• [F]: Detona istantaneamente tutti i C4 armati da qualsiasi strumento!\n• [K] o [TAB] Albero Potenziamenti  •  [B] Arsenale & Prestigio  •  [E] Incassa Premio Torre (≥88%)\n• TIENI PREMUTO [R] (1.2s): Ricostruisci il Grattacielo  •  [ESC] Pausa & Impostazioni"
	}
]

var _intro_step: int = 0
var _start_game_after_intro: bool = false
var _selected_difficulty: String = "easy"
var _style_diff_idle: StyleBoxFlat
var _style_diff_active_easy: StyleBoxFlat
var _style_diff_active_normal: StyleBoxFlat
var _style_diff_active_hard: StyleBoxFlat

func _ready() -> void:
	_init_diff_styles()
	_selected_difficulty = EconomyManager.current_difficulty

	easy_btn.pressed.connect(func(): _select_difficulty("easy"))
	normal_btn.pressed.connect(func(): _select_difficulty("normal"))
	hardcore_btn.pressed.connect(func(): _select_difficulty("hardcore"))

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

func _init_diff_styles() -> void:
	_style_diff_idle = StyleBoxFlat.new()
	_style_diff_idle.bg_color = Color(0.10, 0.125, 0.165, 0.92)
	_style_diff_idle.border_width_left = 1
	_style_diff_idle.border_width_top = 1
	_style_diff_idle.border_width_right = 1
	_style_diff_idle.border_width_bottom = 1
	_style_diff_idle.border_color = Color(0.26, 0.32, 0.42, 0.85)
	_style_diff_idle.set_corner_radius_all(5)

	_style_diff_active_easy = _make_active_diff_style(Color(0.08, 0.24, 0.15, 0.98), Color(0.32, 0.94, 0.52, 1.0))
	_style_diff_active_normal = _make_active_diff_style(Color(0.24, 0.18, 0.06, 0.98), Color(0.98, 0.74, 0.18, 1.0))
	_style_diff_active_hard = _make_active_diff_style(Color(0.26, 0.08, 0.08, 0.98), Color(0.98, 0.36, 0.30, 1.0))

func _make_active_diff_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = border
	s.set_corner_radius_all(5)
	return s

func _select_difficulty(diff_id: String) -> void:
	EventBus.ui_click.emit()
	_selected_difficulty = diff_id
	if EconomyManager.current_difficulty != diff_id:
		EconomyManager.set_difficulty(diff_id)
		# Ricarica in tempo reale il grattacielo dietro la telecamera orbitale!
		GameManager.load_skyscraper_for_difficulty()
	_refresh_difficulty_ui()

func _refresh_difficulty_ui() -> void:
	var cfg: Dictionary = EconomyManager.DIFFICULTIES.get(_selected_difficulty, EconomyManager.DIFFICULTIES["easy"])
	diff_subtitle.text = String(cfg.get("subtitle", ""))

	var pairs := [
		["easy", easy_btn, _style_diff_active_easy],
		["normal", normal_btn, _style_diff_active_normal],
		["hardcore", hardcore_btn, _style_diff_active_hard]
	]
	for p in pairs:
		var is_sel: bool = (_selected_difficulty == p[0])
		var btn: Button = p[1]
		var st: StyleBoxFlat = p[2] if is_sel else _style_diff_idle
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", p[2])
		btn.add_theme_stylebox_override("pressed", p[2])

	new_game_btn.text = "INIZIA PARTITA  (%s • %d PIANI)" % [
		String(cfg.get("label", "FACILE")),
		int(cfg.get("floors", 4))
	]

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

	_selected_difficulty = EconomyManager.current_difficulty
	_refresh_difficulty_ui()

	var has_save: bool = SaveManager.has_existing_career()
	continue_btn.visible = has_save
	career_summary.visible = has_save
	if has_save:
		var cfg: Dictionary = EconomyManager.get_difficulty_config()
		var tools_cnt: int = EconomyManager.unlocked_tools.size()
		summary_text.text = "Carriera Attiva (%s • %d Piani)  •  Capitale: € %d\nStrumenti Sbloccati: %d / %d  •  Prestigio: x%.1f" % [
			String(cfg.get("label", "FACILE")),
			int(cfg.get("floors", 4)),
			int(EconomyManager.current_money),
			tools_cnt,
			EconomyManager.TOOL_ORDER.size(),
			EconomyManager.permanent_multiplier
		]

	EventBus.game_state_changed.emit("main_menu")

func _on_continue_pressed() -> void:
	EventBus.ui_click.emit()
	_enter_gameplay()

func _on_new_game_pressed() -> void:
	EventBus.ui_click.emit()
	EconomyManager.reset_for_new_career(_selected_difficulty)
	GameManager.load_skyscraper_for_difficulty()

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
