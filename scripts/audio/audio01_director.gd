class_name Audio01Director
extends PrototypeMusic
## AUDIO-01. Separate background music, 3D radio and one-shot musical cues.
## Extends PrototypeMusic only to preserve existing saved settings and test APIs.

const RADIO_PATHS := [
	"res://assets/audio/music/radio/radio_01_jazz.ogg",
	"res://assets/audio/music/radio/radio_02_vibraphone.ogg",
	"res://assets/audio/music/radio/radio_03_acoustic.ogg",
	"res://assets/audio/music/radio/radio_04_harp.ogg",
	"res://assets/audio/music/radio/radio_05_duduk.ogg",
	"res://assets/audio/music/radio/radio_06_ambient_a.ogg",
	"res://assets/audio/music/radio/radio_07_ambient_b.ogg",
	"res://assets/audio/music/radio/radio_08_bossa.ogg",
	"res://assets/audio/music/radio/radio_09_ambient_space.ogg",
	"res://assets/audio/music/radio/radio_10_dreamy.ogg",
]
const THEMES := {
	"menu": "res://assets/audio/music/menu.ogg",
	"garage": "res://assets/audio/music/garage.ogg",
	"day_end": "res://assets/audio/music/day_end.ogg",
}
const OPENING := "res://assets/audio/music/opening_sting.wav"
const ACHIEVEMENT := "res://assets/audio/music/achievement_sting.wav"
const FADE_TIME := 1.5
const BASE_DB := -6.0
const SILENT_DB := -70.0

var radio_on := false
var first_shift_sting_played := false
var played_achievements: Dictionary = {}
var radio_index := -1

var _bg_b: AudioStreamPlayer
var _active_bg: AudioStreamPlayer
var _outgoing_bg: AudioStreamPlayer
var _radio: AudioStreamPlayer3D
var _cue: AudioStreamPlayer
var _context := ""
var _fade_elapsed := FADE_TIME
var _outgoing_start_db := BASE_DB
var _rng := RandomNumberGenerator.new()
var _test_mode := OS.get_cmdline_user_args().has("--test-mode")
var _focus_muted := false
var _master_was_muted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_music_bus()
	_player = AudioStreamPlayer.new()
	_player.name = "Audio01BackgroundA"
	_player.bus = "Music"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_bg_b = AudioStreamPlayer.new()
	_bg_b.name = "Audio01BackgroundB"
	_bg_b.bus = "Music"
	_bg_b.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bg_b)
	_cue = AudioStreamPlayer.new()
	_cue.name = "Audio01Cues"
	_cue.bus = "Music"
	_cue.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_cue)

func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("Radio") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Radio")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Radio"), "Music")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Radio"), true)

func _stream(path: String, repeat: bool = false) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("AUDIO-01: audio file not found: " + path)
		return null
	var clip := load(path) as AudioStream
	if clip is AudioStreamOggVorbis:
		(clip as AudioStreamOggVorbis).loop = repeat
	elif clip is AudioStreamWAV:
		(clip as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if repeat else AudioStreamWAV.LOOP_DISABLED
	return clip

func set_preferences(enabled: bool, volume_db: float) -> void:
	# Shared Music bus governs background themes, radio and cues.
	_volume_db = clampf(volume_db, -40.0, -3.0)
	_muted = not enabled or _volume_db <= -39.9
	var index := AudioServer.get_bus_index("Music")
	if index >= 0:
		AudioServer.set_bus_volume_db(index, _volume_db)
		AudioServer.set_bus_mute(index, _muted)

func attach_radio(parent: Node3D, local_position: Vector3) -> void:
	if _radio != null:
		return
	_radio = AudioStreamPlayer3D.new()
	_radio.name = "Audio01RadioSpeaker"
	_radio.position = local_position
	_radio.bus = "Radio"
	_radio.process_mode = Node.PROCESS_MODE_ALWAYS
	_radio.unit_size = 2.0
	_radio.max_distance = 22.0
	_radio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(_radio)
	_radio.finished.connect(_advance_radio)
	_apply_radio_power()
	if _context == "trade":
		_start_radio_broadcast()

func set_context(context: String) -> void:
	if context not in ["menu", "garage", "trade", "day_end"]:
		push_warning("AUDIO-01: unknown context: " + context)
		return
	if context == _context:
		return
	# A third transition during crossfade must not leave an orphaned stream.
	if _outgoing_bg != null and _outgoing_bg != _active_bg:
		_outgoing_bg.stop()
		_outgoing_bg = null
	var old_context := _context
	_context = context
	if context == "trade":
		_apply_radio_power()
		if old_context != "trade":
			_start_radio_broadcast()
	elif context == "day_end":
		# The Radio bus is muted, preserving the current underlying timeline.
		_apply_radio_power()
	elif context == "menu" or context == "garage":
		# Leaving the trading session starts a fresh broadcast next time.
		if _radio != null:
			_radio.stop()
			radio_index = -1
		_apply_radio_power()
	var path := str(THEMES.get(context, ""))
	var incoming: AudioStreamPlayer = null
	if not path.is_empty():
		incoming = _bg_b if _active_bg == _player else _player
		var stream := _stream(path, context in ["menu", "garage"])
		if stream != null:
			incoming.stop()
			incoming.stream = stream
			incoming.volume_db = SILENT_DB
			if not _test_mode:
				incoming.play()
		else:
			incoming = null
	_outgoing_bg = _active_bg
	_outgoing_start_db = _outgoing_bg.volume_db if _outgoing_bg != null else BASE_DB
	_active_bg = incoming
	_fade_elapsed = 0.0

func _process(delta: float) -> void:
	if _fade_elapsed >= FADE_TIME:
		return
	_fade_elapsed = minf(FADE_TIME, _fade_elapsed + maxf(delta, 0.0))
	var ratio := _fade_elapsed / FADE_TIME
	if _active_bg != null:
		_active_bg.volume_db = lerpf(SILENT_DB, BASE_DB, ratio)
	if _outgoing_bg != null and _outgoing_bg != _active_bg:
		_outgoing_bg.volume_db = lerpf(_outgoing_start_db, SILENT_DB, ratio)
		if ratio >= 1.0:
			_outgoing_bg.stop()
			_outgoing_bg = null

func _start_radio_broadcast() -> void:
	if _radio == null or _radio.playing:
		return
	_advance_radio()

func _advance_radio() -> void:
	if _radio == null or RADIO_PATHS.is_empty() or _context != "trade":
		return
	var index := next_radio_index(radio_index)
	var stream := _stream(RADIO_PATHS[index], false)
	if stream == null:
		push_warning("AUDIO-01: skipping invalid radio track " + str(index))
		return
	radio_index = index
	_radio.stream = stream
	_apply_radio_power()
	if not _test_mode:
		_radio.play()

func next_radio_index(previous: int) -> int:
	var count := RADIO_PATHS.size()
	if count <= 1:
		return 0
	var index := _rng.randi_range(0, count - 2)
	if previous >= 0 and previous < count and index >= previous:
		index += 1
	return index

func toggle_radio() -> void:
	radio_on = not radio_on
	_apply_radio_power()
	# Turning off the speaker must not stop playback or reset its timeline.

func _apply_radio_power() -> void:
	# Bus mute silences precisely, unlike a -70 dB attenuation which can leak.
	# A muted bus keeps the audio players advancing, as a real broadcast would.
	var bus_index := AudioServer.get_bus_index("Radio")
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, not (radio_on and _context == "trade"))
	if _radio != null:
		_radio.volume_db = -8.0

func play_opening_once() -> bool:
	if first_shift_sting_played:
		return false
	first_shift_sting_played = true
	_play_cue(OPENING)
	return true

func play_achievement_once(identifier: String) -> bool:
	if identifier.is_empty() or played_achievements.has(identifier):
		return false
	played_achievements[identifier] = true
	_play_cue(ACHIEVEMENT)
	return true

func _play_cue(path: String) -> void:
	var stream := _stream(path)
	if _cue != null and stream != null and not _test_mode:
		_cue.stream = stream
		_cue.volume_db = -6.0
		_cue.play()

func snapshot_audio() -> Dictionary:
	return {
		"radio_on": radio_on,
		"opening_played": first_shift_sting_played,
		"achievement_ids": played_achievements.keys(),
	}

func validate_audio(data: Dictionary) -> bool:
	if data.has("radio_on") and not data.radio_on is bool:
		return false
	if data.has("opening_played") and not data.opening_played is bool:
		return false
	if data.has("achievement_ids"):
		if not data.achievement_ids is Array:
			return false
		for item in data.achievement_ids:
			if not item is String or item.is_empty() or item.length() > 100:
				return false
	return true

func restore_audio(data: Dictionary) -> bool:
	if not validate_audio(data):
		return false
	radio_on = bool(data.get("radio_on", false))
	first_shift_sting_played = bool(data.get("opening_played", false))
	played_achievements.clear()
	for item in data.get("achievement_ids", []):
		played_achievements[item] = true
	# Loading a career starts a fresh random broadcast, never restoring
	# the previous track or its playback position (MUSIC-08).
	if _radio != null:
		_radio.stop()
		radio_index = -1
		if _context == "trade":
			_start_radio_broadcast()
	_apply_radio_power()
	return true

func stop_all() -> void:
	for player in [_player, _bg_b, _cue]:
		if player != null:
			player.stop()
	if _radio != null:
		_radio.stop()
	radio_index = -1

func _input(_event: InputEvent) -> void:
	# Legacy M/P/- keys do not control the radio: only a physical E interaction.
	pass

func _notification(what: int) -> void:
	if _test_mode:
		return
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _focus_muted:
		_master_was_muted = AudioServer.is_bus_mute(master)
		AudioServer.set_bus_mute(master, true)
		_focus_muted = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _focus_muted:
		AudioServer.set_bus_mute(master, _master_was_muted)
		_focus_muted = false
