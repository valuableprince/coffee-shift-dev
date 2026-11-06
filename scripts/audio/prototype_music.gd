class_name PrototypeMusic
extends Node

signal preferences_changed(enabled: bool, volume_db: float)
## Two original, calm instrumental loops for the early playable prototype.
## Purely procedural PCM, no third-party tracks, no external downloads.

const SAMPLE_RATE := 22050
const BPM := 96.0
const BEAT := 60.0 / BPM
const BARS := 8
const MUSIC_NAMES := ["Тёплое утро", "После смены"]
const PCM_SCALE := 28000.0

var _player: AudioStreamPlayer
var _cache: Dictionary = {}
var _track := 0
var _muted := false
var _volume_db := -10.0
var _notice: Label
var _notice_time := 0.0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "PrototypeMusicPlayer"
	_player.volume_db = _volume_db
	add_child(_player)
	if OS.get_cmdline_user_args().has("--test-mode"):
		return
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_notice = Label.new()
	_notice.position = Vector2(28, 184)
	_notice.add_theme_color_override("font_color", Color("e8dab8"))
	_notice.add_theme_font_size_override("font_size", 17)
	layer.add_child(_notice)
	_notice.hide()
	# Generate only the current track. The second is built lazily on demand.
	call_deferred("_start_music")

func _start_music() -> void:
	if not is_inside_tree():
		return
	if not _cache.has(_track):
		_cache[_track] = make_track(_track)
	_player.stream = _cache[_track]
	_player.volume_db = -80.0 if _muted else _volume_db
	_player.play()
	_show("Музыка: " + MUSIC_NAMES[_track] + "  ·  [M] вкл/выкл  [P] следующая  [-/=] громкость")

func set_preferences(enabled: bool, volume_db: float) -> void:
	_volume_db = clampf(volume_db,-40.0,-3.0)
	_muted = not enabled or _volume_db <= -39.9
	if _player != null:
		_player.volume_db = -80.0 if _muted else _volume_db

func _input(event: InputEvent) -> void:
	if OS.get_cmdline_user_args().has("--test-mode"):
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_M:
			_muted = not _muted
			_player.volume_db = -80.0 if _muted else _volume_db
			_show("Музыка выключена" if _muted else "Музыка: " + MUSIC_NAMES[_track])
			preferences_changed.emit(not _muted,_volume_db)
		KEY_P:
			_track = (_track + 1) % MUSIC_NAMES.size()
			_start_music()
			_show("Мелодия: " + MUSIC_NAMES[_track])
		KEY_MINUS:
			_volume_db = clampf(_volume_db - 3.0, -40.0, -3.0)
			_player.volume_db = -80.0 if _muted else _volume_db
			_show("Громкость музыки: %d дБ" % roundi(_volume_db))
			preferences_changed.emit(not _muted,_volume_db)
		KEY_EQUAL:
			_volume_db = clampf(_volume_db + 3.0, -40.0, -3.0)
			_player.volume_db = -80.0 if _muted else _volume_db
			_show("Громкость музыки: %d дБ" % roundi(_volume_db))

func _show(value: String) -> void:
	if _notice == null:
		return
	_notice.text = value
	_notice.show()
	_notice_time = 2.6

func _process(delta: float) -> void:
	if _notice == null or _notice_time <= 0.0:
		return
	_notice_time -= delta
	if _notice_time <= 0.0:
		_notice.hide()

func make_track(index: int) -> AudioStreamWAV:
	# 8 measures of an original instrumental pattern: soft electric keys,
	# simple bass, and unobtrusive brush-like percussion.
	var frames := roundi(float(BARS * 4) * BEAT * float(SAMPLE_RATE))
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var chords := [
		[[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [55, 59, 62, 65]],
		[[48, 52, 55, 59], [45, 48, 52, 55], [50, 53, 57, 60], [55, 59, 62, 65]]
	]
	var lines := [
		[69, -1, 72, 71, 69, 67, 65, -1, 67, 69, 72, 69, 67, -1, 65, 67,
		 69, 72, 76, 72, 69, -1, 67, 65, 67, 69, 71, 74, 72, -1, 69, 67],
		[64, -1, 67, 69, 72, 69, 67, -1, 65, 64, 60, 62, 65, -1, 69, 67,
		 64, 67, 72, 74, 72, 69, 67, 64, 62, -1, 65, 67, 69, 67, 64, -1]
	]
	var progression: Array = chords[posmod(index, chords.size())]
	var melody: Array = lines[posmod(index, lines.size())]
	for bar in range(BARS):
		var start := float(bar * 4) * BEAT
		var chord: Array = progression[bar % 4]
		for pitch in chord:
			_add_note(samples, int(pitch), start, BEAT * 3.8, 0.024, 0)
		_add_note(samples, int(chord[0]) - 12, start, BEAT * 1.55, 0.047, 1)
		_add_note(samples, int(chord[0]) - 12, start + BEAT * 2.0, BEAT * 1.5, 0.043, 1)
	for i in range(melody.size()):
		if int(melody[i]) >= 0:
			_add_note(samples, int(melody[i]), float(i) * BEAT, BEAT * .72, .054, 2)
	for beat_index in range(BARS * 8):
		_add_brush(samples, float(beat_index) * BEAT / 2.0, 0.012 if beat_index % 2 == 0 else 0.008)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for frame in range(frames):
		var taper := minf(1.0, minf(float(frame) / float(SAMPLE_RATE * .035),
			float(frames - frame - 1) / float(SAMPLE_RATE * .055)))
		data.encode_s16(frame * 2, clampi(roundi(samples[frame] * PCM_SCALE * maxf(0.0, taper)), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_begin = 0
	stream.loop_end = frames
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream

func _add_note(samples: PackedFloat32Array, midi: int, start: float, duration: float, gain: float, voice: int) -> void:
	var frequency := 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)
	var first := roundi(start * SAMPLE_RATE)
	var last := mini(samples.size(), first + roundi(duration * SAMPLE_RATE))
	for i in range(first, last):
		var t := float(i - first) / float(SAMPLE_RATE)
		var attack := minf(1.0, t / .015)
		var envelope := attack * (pow(maxf(0.0, 1.0 - t / duration), .7) if voice == 0
			else exp(-2.8 * t / duration))
		var phase := TAU * frequency * t
		var tone := (sin(phase) * .84 + sin(phase * 2.0) * .14 + sin(phase * 3.0) * .02) if voice != 1 else sin(phase)
		samples[i] += tone * envelope * gain

func _add_brush(samples: PackedFloat32Array, start: float, gain: float) -> void:
	var first := roundi(start * SAMPLE_RATE)
	var last := mini(samples.size(), first + roundi(.045 * SAMPLE_RATE))
	for i in range(first, last):
		var t := float(i - first) / float(SAMPLE_RATE)
		var texture := sin(float(i) * 21.117) * sin(float(i) * 5.711)
		samples[i] += texture * exp(-85.0 * t) * gain
