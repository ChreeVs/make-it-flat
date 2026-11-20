extends Node

var sfx_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 16

# Sintetizzatore procedurale
var synth_player: AudioStreamPlayer
var synth_generator: AudioStreamGenerator
var synth_playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		sfx_players.append(p)

	_setup_procedural_synth()

	EventBus.block_damaged.connect(_on_block_damaged)
	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.chain_collapse_triggered.connect(_on_chain_collapse)

func _setup_procedural_synth() -> void:
	synth_player = AudioStreamPlayer.new()
	synth_generator = AudioStreamGenerator.new()
	synth_generator.mix_rate = 22050.0
	synth_generator.buffer_length = 0.1
	synth_player.stream = synth_generator
	synth_player.volume_db = -6.0
	add_child(synth_player)
	synth_player.play()
	synth_playback = synth_player.get_stream_playback() as AudioStreamGeneratorPlayback

func play_stream(stream: AudioStream, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch_scale
			p.volume_db = volume_db
			p.play()
			return

func _synthesize_tone(frequency: float, duration: float, decay: float, noise_mix: float = 0.2) -> void:
	if not synth_playback:
		return
	var sample_rate: float = synth_generator.mix_rate
	var total_frames: int = int(sample_rate * duration)
	var available: int = synth_playback.get_frames_available()
	var frames_to_push: int = mini(total_frames, available)

	for i in range(frames_to_push):
		var t: float = float(i) / sample_rate
		var envelope: float = exp(-decay * t)
		var sine_val: float = sin(TAU * frequency * t)
		var noise_val: float = randf_range(-1.0, 1.0)
		var sample: float = ((sine_val * (1.0 - noise_mix)) + (noise_val * noise_mix)) * envelope * 0.4
		synth_playback.push_frame(Vector2(sample, sample))

func _on_block_damaged(_block: Node3D, amount: float, _hit_pos: Vector3, _normal: Vector3) -> void:
	# Thud di impatto a bassa frequenza + rumore
	var freq: float = clamp(180.0 - amount * 0.3, 80.0, 220.0)
	_synthesize_tone(freq, 0.05, 35.0, 0.4)

func _on_block_destroyed(_block: Node3D, by_gravity: bool, mat_data: MaterialData, _pos: Vector3) -> void:
	if mat_data and mat_data.break_sounds.size() > 0:
		var snd: AudioStream = mat_data.break_sounds.pick_random()
		play_stream(snd, randf_range(0.9, 1.1))
	else:
		# Frantumazione procedurale
		var freq: float = 90.0 if by_gravity else 140.0
		_synthesize_tone(freq, 0.08, 25.0, 0.7)

func _on_currency_changed(_new_amount: float, delta: float) -> void:
	if delta > 0.0:
		# Ding procedurale moneta
		_synthesize_tone(880.0, 0.04, 20.0, 0.05)

func _on_chain_collapse(_count: int, _total_mass: float) -> void:
	# Rombo sismico profondo
	_synthesize_tone(55.0, 0.18, 12.0, 0.5)
