extends Node

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 20
const COIN_COOLDOWN_MS: int = 75

var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _last_coin_ms: int = 0

var wav_hit_wood: AudioStreamWAV
var wav_hit_masonry: AudioStreamWAV
var wav_break_wood: AudioStreamWAV
var wav_break_masonry: AudioStreamWAV
var wav_ricochet: AudioStreamWAV
var wav_collapse: AudioStreamWAV
var wav_explosion: AudioStreamWAV
var wav_coin: AudioStreamWAV
var wav_drill_tick: AudioStreamWAV
var wav_ui_click: AudioStreamWAV

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.max_polyphony = 2
		add_child(p)
		_players.append(p)

	_generate_all_clips()

	EventBus.block_damaged.connect(_on_block_damaged)
	EventBus.block_ricochet.connect(_on_block_ricochet)
	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.chain_collapse_triggered.connect(_on_chain_collapse)
	EventBus.explosion_triggered.connect(_on_explosion)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.tool_swung.connect(_on_tool_swung)
	EventBus.ui_click.connect(_on_ui_click)

func _generate_all_clips() -> void:
	wav_hit_wood = _synth_impact(0.11, 185.0, 80.0, 0.45, 22.0)
	wav_hit_masonry = _synth_impact(0.13, 130.0, 52.0, 0.65, 19.0)
	wav_break_wood = _synth_shatter(0.24, 240.0, 0.72, 11.0)
	wav_break_masonry = _synth_shatter(0.32, 115.0, 0.85, 8.5)
	wav_ricochet = _synth_metallic_ping(0.22, 1480.0, 2210.0)
	wav_collapse = _synth_rumble(0.75, 58.0)
	wav_explosion = _synth_explosion(0.85)
	wav_coin = _synth_coin(0.16)
	wav_drill_tick = _synth_impact(0.06, 310.0, 140.0, 0.55, 38.0)
	wav_ui_click = _synth_impact(0.045, 760.0, 420.0, 0.12, 62.0)

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)), -32768, 32767)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _synth_impact(dur: float, f_start: float, f_end: float, noise_mix: float, decay: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * decay)
		var freq: float = lerpf(f_start, f_end, minf(t / maxf(dur, 0.01), 1.0))
		phase += TAU * freq / float(SAMPLE_RATE)
		var tone: float = sin(phase)
		var noise: float = randf_range(-1.0, 1.0)
		buf[i] = (tone * (1.0 - noise_mix) + noise * noise_mix) * env * 0.72
	return _make_wav(buf)

func _synth_shatter(dur: float, base_freq: float, noise_mix: float, decay: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * decay)
		var crunch: float = 1.0 if sin(t * 95.0) > -0.2 else 0.45
		var raw_noise: float = randf_range(-1.0, 1.0)
		lp = lerpf(lp, raw_noise, 0.35)
		var thump: float = sin(TAU * base_freq * t * exp(-t * 4.0))
		buf[i] = (thump * (1.0 - noise_mix) + lp * noise_mix * crunch) * env * 0.80
	return _make_wav(buf)

func _synth_metallic_ping(dur: float, f1: float, f2: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 16.0)
		var s: float = 0.55 * sin(TAU * f1 * t) + 0.35 * sin(TAU * f2 * t) + 0.10 * randf_range(-1.0, 1.0) * exp(-t * 45.0)
		buf[i] = s * env * 0.65
	return _make_wav(buf)

func _synth_rumble(dur: float, freq: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var attack: float = minf(t / 0.05, 1.0)
		var env: float = attack * exp(-t * 3.2)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.14)
		var sub: float = sin(TAU * (freq + 14.0 * sin(t * 11.0)) * t)
		buf[i] = (sub * 0.42 + lp * 0.78) * env * 0.85
	return _make_wav(buf)

func _synth_explosion(dur: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 3.8)
		var crack: float = exp(-t * 32.0) * randf_range(-1.0, 1.0)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.18)
		var boom: float = sin(TAU * lerpf(92.0, 26.0, minf(t * 2.2, 1.0)) * t)
		buf[i] = clampf((boom * 0.58 + lp * 0.68 + crack * 0.45) * env, -1.0, 1.0) * 0.92
	return _make_wav(buf)

func _synth_coin(dur: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var freq: float = 987.77 if t < 0.055 else 1318.51
		var env: float = exp(-t * 18.0)
		buf[i] = (0.75 * sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t)) * env * 0.45
	return _make_wav(buf)

func _play_clip(clip: AudioStreamWAV, volume_db: float = -6.0, pitch_min: float = 0.94, pitch_max: float = 1.06) -> void:
	if not clip or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	p.stream = clip
	p.volume_db = volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()

func _is_wood_block(block: Node3D) -> bool:
	if block is DestructibleBlock and block.material_data:
		var mid := String(block.material_data.material_id)
		return mid.begins_with("wood")
	return false

func _on_block_damaged(block: Node3D, _amount: float, _pos: Vector3, _nrm: Vector3) -> void:
	if _is_wood_block(block):
		_play_clip(wav_hit_wood, -8.0, 0.92, 1.12)
	else:
		_play_clip(wav_hit_masonry, -7.0, 0.88, 1.08)

func _on_block_ricochet(_block: Node3D, _pos: Vector3, _nrm: Vector3, _req_tier: int) -> void:
	_play_clip(wav_ricochet, -5.0, 0.96, 1.08)

func _on_block_destroyed(block: Node3D, by_gravity: bool) -> void:
	if by_gravity:
		return
	if _is_wood_block(block):
		_play_clip(wav_break_wood, -4.5, 0.90, 1.10)
	else:
		_play_clip(wav_break_masonry, -4.0, 0.86, 1.06)

func _on_chain_collapse(count: int, _mass: float) -> void:
	var vol: float = clampf(-9.0 + float(count) * 0.12, -8.0, -1.5)
	_play_clip(wav_collapse, vol, 0.85, 1.02)

func _on_explosion(_pos: Vector3, _radius: float) -> void:
	_play_clip(wav_explosion, -1.0, 0.92, 1.05)

func _on_currency_changed(_new_amount: float, delta: float) -> void:
	if delta <= 0.0:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_coin_ms >= COIN_COOLDOWN_MS:
		_last_coin_ms = now
		_play_clip(wav_coin, -11.0, 0.98, 1.08)

func _on_tool_swung(tool_data: Resource) -> void:
	if tool_data is ToolData and tool_data.behavior_type == ToolData.BehaviorType.CONTINUOUS_DRILL:
		_play_clip(wav_drill_tick, -12.0, 0.92, 1.10)

func _on_ui_click() -> void:
	_play_clip(wav_ui_click, -9.0, 0.98, 1.04)
