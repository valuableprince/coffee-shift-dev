extends SceneTree
## AUDIO-01 smoke checks. Run after importing OGGs with Godot 4.3.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS AUDIO-01: " + message)
	else:
		failures += 1
		push_error("FAIL AUDIO-01: " + message)

func _verify() -> void:
	var music := Audio01Director.new()
	root.add_child(music)
	check(Audio01Director.RADIO_PATHS.size() == 10, "10 radio compositions")
	check(AudioServer.get_bus_index("Music") >= 0, "independent Music bus")
	check(AudioServer.get_bus_index("Radio") >= 0, "independent Radio bus")
	for path in Audio01Director.RADIO_PATHS:
		check(ResourceLoader.exists(path), "imported radio resource " + path.get_file())
		check(load(path) is AudioStream, "radio OGG decodes " + path.get_file())
	for context in ["menu", "garage", "day_end"]:
		var path: String = Audio01Director.THEMES[context]
		check(ResourceLoader.exists(path), "theme " + context)
		check(load(path) is AudioStream, "theme stream " + context)
	for cue in [Audio01Director.OPENING, Audio01Director.ACHIEVEMENT]:
		var clip := load(cue) as AudioStreamWAV
		check(clip != null, "cue WAV exists " + cue.get_file())
		if clip != null:
			check(clip.mix_rate == 22050 and not clip.stereo, "cue format " + cue.get_file())
	music.set_preferences(true, -12.0)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music bus unmuted")
	music.set_preferences(false, -12.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music bus muted")
	music.set_preferences(true, -12.0)
	music.set_context("menu")
	check(music._context == "menu", "menu background")
	music.set_context("garage")
	check(music._context == "garage", "garage background")
	var speaker_root := Node3D.new()
	root.add_child(speaker_root)
	music.attach_radio(speaker_root, Vector3(1, 2, 3))
	music.set_context("trade")
	check(music._context == "trade", "trade removes background theme")
	check(music._radio != null, "spatial radio exists")
	check(music._radio.position == Vector3(1, 2, 3), "radio emitter anchored")
	check(music.radio_index >= 0 and music.radio_index < 10, "random initial broadcast")
	for old in range(10):
		for _iteration in range(20):
			check(music.next_radio_index(old) != old, "no immediate radio repeat " + str(old))
	music.toggle_radio()
	check(music.radio_on, "E turns speaker on")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "powered-on radio bus is audible")
	var position_before := music.radio_index
	music.toggle_radio()
	check(not music.radio_on and music.radio_index == position_before, "off does not reset broadcast")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "powered-off radio bus is silent")
	check(music.play_opening_once(), "first shift plays sting")
	check(not music.play_opening_once(), "sting cannot replay in career")
	check(music.play_achievement_once("first_sale"), "achievement plays once")
	check(not music.play_achievement_once("first_sale"), "achievement cannot repeat")
	var saved := music.snapshot_audio()
	check(music.validate_audio(saved), "valid audio save")
	check(not music.validate_audio({"radio_on": "yes"}), "reject invalid radio flag")
	check(not music.validate_audio({"achievement_ids": [1]}), "reject invalid achievement ids")
	music.restore_audio({})
	check(not music.radio_on and not music.first_shift_sting_played, "legacy save defaults")
	check(music.restore_audio(saved), "restore audio state")
	check(music.first_shift_sting_played and music.played_achievements.has("first_sale"), "persistent one-time flags")
	music.set_context("day_end")
	check(music._context == "day_end", "one-shot end-day theme")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "end-day mutes physical radio bus")
	music.set_context("trade")
	music.toggle_radio()
	check(music.radio_on and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "resume trading restores powered radio")
	music.set_context("garage")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "garage mutes physical radio")
	music.stop_all()
	print("AUDIO-01: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
