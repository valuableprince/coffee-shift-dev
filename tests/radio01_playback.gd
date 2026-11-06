extends "res://tests/asset_integration.gd"
## Rendered scene for a real PulseAudio monitor recording or manual E review.
## Run without --audio-driver Dummy; --test-mode isolates save files only.
var phases: Array = []
var evidence := ""

func run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): evidence = arg.trim_prefix("--evidence=")
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	level.music._test_mode = false
	level.new_game(1)
	level.music.set_preferences(true, -10)
	level.audio.set_volume(0)
	var speaker := level.music._radio
	# Use one already-approved recording and identical musical segments for the
	# near/far comparison. Product playback still uses AUDIO-01's random catalog.
	speaker.stop()
	speaker.stream = load(Audio01Director.RADIO_PATHS[0])
	level.music.radio_index = 0
	speaker.play(10)
	await view(level.stations.radio.global_position, Vector3(0, .4, 2.20), 60)
	print("RADIO-01 READY: ", AudioServer.output_device, "; physical E target: ", level.player.get_interactable())
	if OS.get_cmdline_user_args().has("--interactive"):
		return
	mark("off-near")
	await create_timer(3).timeout
	await use("radio")
	speaker.play(10)
	mark("on-near")
	await create_timer(7).timeout
	# Exterior camera at ground level, five metres from the physical receiver.
	await aim(level.stations.radio.global_position, Vector3(4, 0, 2.30))
	speaker.play(10)
	mark("on-outside")
	await create_timer(7).timeout
	await aim(level.stations.radio.global_position, Vector3(0, .4, 2.20))
	await use("radio")
	mark("off-again")
	await create_timer(3).timeout
	await use("radio")
	speaker.play(10)
	mark("on-again-near")
	await create_timer(7).timeout
	await use("radio")
	mark("off-final")
	await create_timer(2).timeout
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("playback-phases.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"output_device": AudioServer.output_device, "phases": phases}, "\t"))
	level.music.stop_all()
	level.audio.stop_all()
	level.free()
	await frames(3)
	print("RADIO-01 SYSTEM PLAYBACK COMPLETE")
	quit(1 if failures else 0)

func mark(phase: String) -> void:
	var state := {"phase": phase, "unix_time": Time.get_unix_time_from_system(), "radio_on": level.music.radio_on, "playing": level.music._radio.playing, "listener": [level.player.position.x, level.player.position.y, level.player.position.z]}
	phases.append(state)
	check(level.music.radio_on == phase.begins_with("on-"), "recording phase power: " + phase)
	print("RADIO-01 PHASE ", JSON.stringify(state))
