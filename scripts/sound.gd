class_name AsterSound
extends Node

enum BugCue { CALL, HURT, DEATH, WINDUP, STRUCTURE_HIT, PLAYER_HIT }

const BUG_PROFILE := [
	[0.58, 141.0, -13.0, 0.61],
	[0.23, 225.0, -12.0, 0.11],
	[0.63, 176.0, -11.0, 0.13],
	[0.24, 163.0, -14.0, 0.29],
	[0.31, 95.0, -8.0, 0.10],
	[0.24, 69.0, -8.0, 0.09],
]
const BUG_DISTANCE := 34.0
const BUG_STEP_DISTANCE := 19.0

const SAMPLE_RATE := 22050
const PROFILES := {
	&"hit": [0.085, 370.0, 112.0, 0.42, -17.0],
	&"empty": [0.052, 320.0, 153.0, 0.58, -18.0],
	&"repair": [0.097, 601.0, 780.0, 0.14, -23.0],
	&"crate": [0.16, 210.0, 77.0, 0.49, -16.0],
	&"lock": [0.24, 277.0, 528.0, 0.24, -14.0],
}
const MECHANICAL := {
	&"rifle_reload_grip": [0.15, -13.0, [Vector3(0.0, 390.0, 0.38), Vector3(0.049, 710.0, 0.65)]],
	&"rifle_reload_remove": [0.22, -10.0, [Vector3(0.0, 528.0, 0.72), Vector3(0.068, 288.0, 0.78)]],
	&"rifle_reload_seat": [0.24, -8.0, [Vector3(0.0, 354.0, 0.78), Vector3(0.092, 862.0, 0.59)]],
	&"turret_unlatch": [0.30, -10.0, [Vector3(0.0, 242.0, 0.53), Vector3(0.12, 167.0, 0.86)]],
	&"turret_remove": [0.34, -10.0, [Vector3(0.0, 153.0, 0.96), Vector3(0.13, 315.0, 0.56)]],
	&"turret_insert": [0.30, -10.0, [Vector3(0.0, 181.0, 0.76), Vector3(0.106, 292.0, 0.61)]],
	&"turret_seat": [0.42, -8.0, [Vector3(0.0, 132.0, 1.0), Vector3(0.077, 482.0, 0.75), Vector3(0.21, 204.0, 0.42)]],
}
var _clips: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _sand_steps: Array[AudioStreamWAV] = []
var _deck_steps: Array[AudioStreamWAV] = []
var _service_voices: Array[AudioStreamPlayer3D] = []
var _bug_voices: Array[AudioStreamPlayer3D] = []
var _bug_clips: Array = []
var _last_bug_cue: Array[float] = [-100.0, -100.0, -100.0, -100.0, -100.0, -100.0]
var _next_bug := 0
var _bug_sand_steps: Array[AudioStreamWAV] = []
var _bug_hard_steps: Array[AudioStreamWAV] = []
var _bug_step_voices: Array[AudioStreamPlayer3D] = []
var _next_bug_step := 0
var _bug_step_wait: Array[float] = [0.0, 0.0]
var _next_service := 0
var _rifle_clips: Array[AudioStreamWAV] = []
var _turret_clips: Array[AudioStreamWAV] = []
var _turret_voices: Array[AudioStreamPlayer3D] = []
var _rifle_voices: Array[AudioStreamPlayer] = []
var _next_turret := 0
var _next_rifle := 0

func _ready() -> void:
	for kind: StringName in PROFILES:
		_clips[kind] = _make_clip(kind)
	for kind: StringName in MECHANICAL:
		_clips[kind] = _mechanical_clip(MECHANICAL[kind])
	for index in range(10):
		var voice := AudioStreamPlayer.new()
		_players.append(voice)
		add_child(voice)
	for variant in range(4):
		_sand_steps.append(_step_clip(false, variant))
		_deck_steps.append(_step_clip(true, variant))
		_bug_sand_steps.append(_bug_step_clip(false, variant))
		_bug_hard_steps.append(_bug_step_clip(true, variant))
		_rifle_clips.append(_shot_clip(false, variant))
		_turret_clips.append(_shot_clip(true, variant))
	for index in range(26):
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 11.0
		voice.max_distance = 72.0
		voice.volume_db = -13.0
		voice.attenuation_filter_cutoff_hz = 3900.0
		_turret_voices.append(voice)
		add_child(voice)
	for index in range(8):
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 5.5
		voice.max_distance = 27.0
		_service_voices.append(voice)
		add_child(voice)
	for cue in range(BUG_PROFILE.size()):
		var bank: Array[AudioStreamWAV] = []
		for variant in range(3):
			bank.append(_wall_strike_clip(variant) if cue == BugCue.STRUCTURE_HIT else _bug_clip(cue, variant))
		_bug_clips.append(bank)
	for index in range(12):
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 8.0
		voice.max_distance = BUG_DISTANCE
		voice.attenuation_filter_cutoff_hz = 4800.0
		_bug_voices.append(voice)
		add_child(voice)
	for index in range(8):
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 4.0
		voice.max_distance = BUG_STEP_DISTANCE
		voice.attenuation_filter_cutoff_hz = 3100.0
		_bug_step_voices.append(voice)
		add_child(voice)
	for index in range(5):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -7.5
		_rifle_voices.append(voice)
		add_child(voice)

func _exit_tree() -> void:
	for voice in _players:
		voice.stop()
	for voice in _rifle_voices:
		voice.stop()
	for voice in _turret_voices:
		voice.stop()
	for voice in _service_voices:
		voice.stop()
	for voice in _bug_voices:
		voice.stop()
	for voice in _bug_step_voices:
		voice.stop()

func _physics_process(delta: float) -> void:
	for band in range(_bug_step_wait.size()):
		_bug_step_wait[band] = maxf(0.0, _bug_step_wait[band] - delta)

func play(kind: StringName) -> void:
	if not _clips.has(kind):
		return
	var profile: Array = MECHANICAL[kind] if MECHANICAL.has(kind) else PROFILES[kind]
	_play_local(_clips[kind], profile[1] if MECHANICAL.has(kind) else profile[4])

func step(on_deck: bool, gain_db: float) -> void:
	var bank := _deck_steps if on_deck else _sand_steps
	_play_local(bank[randi() % bank.size()], (-14.0 if on_deck else -15.0) + gain_db)

func play_service(kind: StringName, at: Vector3) -> void:
	var voice := _service_voices[_next_service]
	_next_service = (_next_service + 1) % _service_voices.size()
	voice.global_position = at
	voice.stream = _clips[kind]
	voice.volume_db = MECHANICAL[kind][1]
	voice.play()

func _play_local(clip: AudioStreamWAV, volume_db: float) -> void:
	var voice := _players[_next]
	_next = (_next + 1) % _players.size()
	voice.stream = clip
	voice.volume_db = volume_db
	voice.play()

func fire_at(heavy: bool, origin: Vector3) -> void:
	if _rifle_voices.is_empty():
		return
	if heavy:
		var voice := _turret_voices[_next_turret]
		_next_turret = (_next_turret + 1) % _turret_voices.size()
		voice.global_position = origin
		voice.stream = _turret_clips[randi() % _turret_clips.size()]
		voice.play()
	else:
		var voice := _rifle_voices[_next_rifle]
		_next_rifle = (_next_rifle + 1) % _rifle_voices.size()
		voice.stream = _rifle_clips[randi() % _rifle_clips.size()]
		voice.play()

func bug_cue(cue: BugCue, point: Vector3) -> void:
	var listener := get_viewport().get_camera_3d()
	if listener == null or point.distance_squared_to(listener.global_position) > BUG_DISTANCE * BUG_DISTANCE:
		return
	var now := Time.get_ticks_msec() * 0.001
	var profile: Array = BUG_PROFILE[cue]
	if now - _last_bug_cue[cue] < float(profile[3]):
		return
	_last_bug_cue[cue] = now
	var voice := _bug_voices[_next_bug]
	_next_bug = (_next_bug + 1) % _bug_voices.size()
	var bank: Array = _bug_clips[cue]
	voice.stream = bank[randi() % bank.size()]
	voice.global_position = point
	voice.pitch_scale = randf_range(0.90, 1.11)
	voice.volume_db = profile[2]
	voice.play()

func bug_step(point: Vector3, hard_surface: bool, light: bool) -> void:
	var listener := get_viewport().get_camera_3d()
	if listener == null:
		return
	var distance_squared := point.distance_squared_to(listener.global_position)
	if distance_squared > BUG_STEP_DISTANCE * BUG_STEP_DISTANCE:
		return
	var band := 0 if distance_squared < 64.0 else 1
	if _bug_step_wait[band] > 0.0:
		return
	_bug_step_wait[band] = 0.047 if band == 0 else 0.10
	var bank := _bug_hard_steps if hard_surface else _bug_sand_steps
	var voice := _bug_step_voices[_next_bug_step]
	_next_bug_step = (_next_bug_step + 1) % _bug_step_voices.size()
	voice.stream = bank[randi() % bank.size()]
	voice.global_position = point
	voice.pitch_scale = randf_range(0.93, 1.07) * (1.13 if light else 1.0)
	voice.volume_db = (-12.0 if hard_surface else -10.0) - (2.0 if light else 0.0)
	voice.play()

func _bug_step_clip(hard_surface: bool, variant: int) -> AudioStreamWAV:
	var count := roundi(SAMPLE_RATE * (0.15 if hard_surface else 0.19))
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 31881 + variant * 163 + int(hard_surface) * 21
	var lag := random.randf_range(0.023, 0.047)
	var pitch := random.randf_range(82.0, 122.0)
	var bass := 0.0
	var grit := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var noise := random.randf_range(-1.0, 1.0)
		bass = lerpf(bass, noise, 0.061)
		grit = lerpf(grit, noise, 0.41)
		var second := maxf(0.0, t - lag)
		var taps := exp(-t * 45.0) * minf(t * 790.0, 1.0)
		taps += 0.65 * exp(-second * 82.0) * minf(second * 1040.0, 1.0)
		var thud := (bass * 2.1 + sin(TAU * pitch * t) * exp(-t * 52.0) * 0.31) * taps
		var scrape := (grit - bass) * (0.74 * taps + exp(-absf(t - lag - 0.032) * 35.0) * 0.36)
		var claw := (noise - grit) * taps * (0.92 if hard_surface else 0.28)
		var knock := sin(TAU * pitch * 7.18 * t) * exp(-t * 93.0) * taps * 0.27 if hard_surface else 0.0
		var fade := smoothstep(0.0, 0.026, float(count - index) / SAMPLE_RATE)
		data.encode_s16(index * 2, roundi(tanh((thud + scrape + claw + knock) * fade) * 29000.0))
	return _wave(data)

func _wall_strike_clip(variant: int) -> AudioStreamWAV:
	var count := roundi(SAMPLE_RATE * float(BUG_PROFILE[BugCue.STRUCTURE_HIT][0]))
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 38194 + variant * 79
	var weight := random.randf_range(71.0, 87.0)
	var recoil := random.randf_range(0.044, 0.079)
	var low := 0.0
	var grain := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var noise := random.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.049)
		grain = lerpf(grain, noise, 0.27)
		var thud := (sin(TAU * weight * t) * 0.66 + sin(TAU * weight * 1.63 * t) * 0.25 + low * 1.8) * exp(-t * 28.0)
		var crack := (noise - grain * 0.67) * exp(-t * 181.0) * 1.28
		var scrape := (grain - low) * exp(-absf(t - recoil) * 51.0) * 0.58
		var crumbs := (noise - grain) * exp(-absf(t - recoil * 1.81) * 65.0) * 0.15
		var envelope := minf(t * 1700.0, 1.0) * smoothstep(0.0, 0.041, float(count - index) / SAMPLE_RATE)
		data.encode_s16(index * 2, roundi(tanh((thud + crack + scrape + crumbs) * envelope) * 31200.0))
	return _wave(data)

func _bug_clip(cue: int, variant: int) -> AudioStreamWAV:
	var profile: Array = BUG_PROFILE[cue]
	var count := roundi(SAMPLE_RATE * float(profile[0]))
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 6149 + cue * 421 + variant * 29
	var pitch := float(profile[1]) * random.randf_range(0.87, 1.17)
	var chatter := random.randf_range(10.0, 18.0)
	var phase := 0.0
	var throat := 0.0
	var grit := 0.0
	var impact := cue == BugCue.PLAYER_HIT
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var progress := float(index) / count
		var noise := random.randf_range(-1.0, 1.0)
		throat = lerpf(throat, noise, 0.077)
		grit = lerpf(grit, noise, 0.36)
		var sweep := lerpf(1.58, 0.57 if cue == BugCue.DEATH else 0.95, progress)
		phase += TAU * pitch * sweep / SAMPLE_RATE
		var sound := 0.0
		if impact:
			var snap := (noise - grit * 0.62) * exp(-t * 144.0)
			var body := (sin(phase) * 0.85 + throat * 2.1) * exp(-t * 24.0)
			var ring := sin(phase * 4.73) * exp(-t * 34.0) * 0.04
			sound = (body + snap * 0.8 + ring) * minf(t * 1250.0, 1.0)
		else:
			var voice := sin(phase + sin(phase * 1.46) * 1.3) * 0.37 + sin(phase * 2.03) * 0.19
			var rasp := (grit - throat * 0.5) * 0.64 + throat * 0.93
			var pulse := 0.58 + 0.42 * pow((sin(TAU * t * chatter + sin(TAU * t * 4.1)) + 1.0) * 0.5, 2.0)
			var fade_in := smoothstep(0.0, 0.035 if cue == BugCue.CALL else 0.016, t)
			sound = (voice + rasp) * pulse * fade_in * pow(1.0 - progress, 1.5)
		var fade := smoothstep(0.0, 0.029, float(count - index) / SAMPLE_RATE)
		data.encode_s16(index * 2, roundi(tanh(sound * fade) * 30000.0))
	return _wave(data)

func _step_clip(on_deck: bool, variant: int) -> AudioStreamWAV:
	var count := roundi(SAMPLE_RATE * (0.225 if on_deck else 0.175))
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 71411 + variant * 73 + int(on_deck) * 557
	var pitch := (115.0 if on_deck else 76.0) + random.randf_range(-8.0, 8.0)
	var low := 0.0
	var mid := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var noise := random.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.065)
		mid = lerpf(mid, noise, 0.40)
		var impact := exp(-t * 32.0) * (sin(TAU * pitch * t) * 0.51 + low * 1.2)
		var scuff := (mid - low) * (0.6 * exp(-t * 23.0) + 0.23 * exp(-absf(t - 0.053) * 58.0))
		var ring := sin(TAU * pitch * 3.22 * t) * exp(-t * 16.0) * 0.26 if on_deck else 0.0
		var window := minf(t * 520.0, 1.0) * smoothstep(0.0, 0.025, float(count - index) / SAMPLE_RATE)
		data.encode_s16(index * 2, roundi(tanh((impact + scuff + ring) * window) * 28200.0))
	return _wave(data)

func _mechanical_clip(profile: Array) -> AudioStreamWAV:
	var count := roundi(float(profile[0]) * SAMPLE_RATE)
	var strokes: Array = profile[2]
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 8384 + count
	var tail := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var noise := random.randf_range(-1.0, 1.0)
		tail = lerpf(tail, noise, 0.27)
		var signal_value := 0.0
		for stroke: Vector3 in strokes:
			var age := t - stroke.x
			if age < 0.0 or age > 0.18:
				continue
			var phase := TAU * stroke.y * age
			var body := (sin(phase) * 0.48 + sin(phase * 2.53) * 0.17) * exp(-age * 47.0)
			var rattle := (noise * 0.25 + tail * 0.65) * exp(-age * 34.0)
			signal_value += stroke.z * (body + rattle) * minf(age * 1900.0, 1.0)
		var fade := smoothstep(0.0, 0.020, float(count - index) / SAMPLE_RATE)
		data.encode_s16(index * 2, roundi(tanh(signal_value * fade) * 30000.0))
	return _wave(data)

func _shot_clip(heavy: bool, variant: int) -> AudioStreamWAV:
	if heavy:
		return _turret_clip(variant)
	var count := roundi(SAMPLE_RATE * 0.19)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 56537 + variant * 131
	var resonance := 108.0 + random.randf_range(-5.0, 5.0)
	var phase := 0.0
	var low := 0.0
	var mid := 0.0
	for i in range(count):
		var seconds := float(i) / SAMPLE_RATE
		var noise := random.randf_range(-1.0, 1.0)
		phase += TAU * (resonance + 96.0 * exp(-seconds * 63.0)) / SAMPLE_RATE
		low = lerpf(low, noise, 0.083)
		mid = lerpf(mid, noise, 0.26)
		var crack := (noise - mid * 0.71) * exp(-seconds * 92.0)
		var body := (sin(phase) * 0.75 + sin(phase * 1.87) * 0.20 + low * 1.08) * exp(-seconds * 37.0)
		var trail := (mid - low * 0.52) * (exp(-seconds * 19.0) + 0.26 * exp(-absf(seconds - 0.071) * 88.0))
		var envelope := minf(seconds * 1500.0, 1.0) * smoothstep(0.0, 0.035, float(count - i) / SAMPLE_RATE)
		var signal_value := (crack * 0.82 + body * 0.52 + trail * 0.46) * envelope
		data.encode_s16(i * 2, roundi(tanh(signal_value * 1.56) * 32000.0))
	return _wave(data)

func _turret_clip(variant: int) -> AudioStreamWAV:
	var count := roundi(SAMPLE_RATE * 0.32)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 42809 + variant * 131
	var resonance := 49.0 + random.randf_range(-3.0, 3.0)
	var phase := 0.0
	var bass_noise := 0.0
	var thump_noise := 0.0
	var crack_noise := 0.0
	for i in range(count):
		var seconds := float(i) / SAMPLE_RATE
		var noise := random.randf_range(-1.0, 1.0)
		bass_noise = lerpf(bass_noise, noise, 0.029)
		thump_noise = lerpf(thump_noise, noise, 0.15)
		crack_noise = lerpf(crack_noise, noise, 0.31)
		phase += TAU * (resonance + 38.0 * exp(-seconds * 55.0)) / SAMPLE_RATE
		var body := (0.83 * sin(phase) + 0.32 * sin(phase * 2.03) + 1.95 * bass_noise) * exp(-seconds * 16.0)
		var mechanism := (thump_noise - bass_noise) * (exp(-seconds * 42.0) + 0.30 * exp(-absf(seconds - 0.043) * 68.0))
		var crack := (crack_noise + noise * 0.11) * exp(-seconds * 148.0)
		var envelope := minf(seconds * 1250.0, 1.0) * smoothstep(0.0, 0.042, float(count - i) / SAMPLE_RATE)
		data.encode_s16(i * 2, roundi(tanh((body * 0.98 + mechanism * 0.68 + crack * 0.49) * envelope) * 30200.0))
	return _wave(data)

func _make_clip(kind: StringName) -> AudioStreamWAV:
	var profile: Array = PROFILES[kind]
	var data := PackedByteArray()
	var count := roundi(float(profile[0]) * SAMPLE_RATE)
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 4592 + count
	var phase := 0.0
	var filtered := 0.0
	for i in range(count):
		var progress := float(i) / count
		var pitch := lerpf(profile[1], profile[2], progress)
		phase += TAU * pitch / SAMPLE_RATE
		filtered = lerpf(filtered, random.randf_range(-1, 1), 0.52)
		var signal_value := lerpf(sin(phase) * 0.67 + sin(phase * 1.5) * 0.23, filtered, profile[3])
		var envelope := minf(float(i) / 95.0, 1.0) * pow(1.0 - progress, 2.1)
		data.encode_s16(i * 2, roundi(signal_value * envelope * 30700))
	return _wave(data)

func _wave(data: PackedByteArray) -> AudioStreamWAV:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = SAMPLE_RATE
	clip.data = data
	return clip
