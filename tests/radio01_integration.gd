extends "res://tests/asset_integration.gd"
## Full first-shift scene, original GLB, player ray/E, real AudioServer and saves.
const FaultDirector := preload("res://tests/radio01_missing_audio.gd")

func run() -> void:
	root.size = Vector2i(1280, 720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	# Keep isolated test saves, but exercise real playback rather than AUDIO-01's
	# smoke-test short circuit. Audible output is separately recorded via Pulse.
	level.music._test_mode = false
	check(level.new_game(1), "T01: first-shift scene and new career start")
	var receiver := level.radio_receiver
	var speaker := receiver.get_node("RadioSound") as AudioStreamPlayer3D
	check(FileAccess.get_sha256("res://assets/models/radio_receiver/coffee_shift_radio_receiver.glb") == "204d6569d7c22ed68c738eb1a24e3fa0a3d87f82815180d630ac878e8db883b0", "T02: approved GLB bytes preserved")
	check(receiver.get_node("Visual").scene_file_path.ends_with("coffee_shift_radio_receiver.glb"), "T02: real original GLB instance")
	check(receiver.global_basis.get_scale().is_equal_approx(Vector3.ONE), "T02: natural metre scale")
	check(receiver.global_basis.z.dot(Vector3.RIGHT) > .999, "T02: front faces staff aisle")
	var box := bounds(receiver)
	var shelf := bounds(level.trailer.get_node("RadioShelf"))
	check(is_equal_approx(box.position.y, shelf.end.y), "T02: feet touch shelf without floating or penetration")
	check(box.position.x > shelf.position.x and box.end.x < shelf.end.x and box.position.z > shelf.position.z and box.end.z < shelf.end.z, "T02: full footprint including antenna stays over shelf")
	for other in [level.machine_visual, level.grinder_visual, level.new_assets.register, level.new_assets.sink, level.new_assets.cabinets.WallRear]:
		check(not box.intersects(bounds(other)), "T02: receiver clears " + str(other.name))
	check(level.trailer.get_node_or_null("RadioCase") == null, "T02: old placeholder removed")
	check(not receiver.powered and not level.music.radio_on, "T03: new career defaults OFF")
	await view(Vector3(-.64, 1.66, 1.86), Vector3(.05, .4, 1.45), 75)
	await shot("01-radio-inside-trailer")
	await aim(level.stations.radio.global_position, Vector3(0, .4, 2.20))
	check(level.player.get_interactable() == level.stations.radio, "T03: existing player ray reaches radio body")
	check(level.hud.hint.text.contains("Включить радио"), "T03: OFF hover prompt")
	await shot("02-radio-off-prompt")
	await view(receiver.to_global(Vector3(0, .14, .04)), Vector3(-.08, .4, 2.20), 38)
	await shot("03-radio-close-up")
	await key(KEY_E)
	check(level.music.radio_on and receiver.powered, "T04: shared E powers on receiver and LED")
	check(speaker.playing and speaker.stream != null, "T04: actual 3D stream plays")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "T04: Radio output unmuted")
	check(not level.music._player.playing and not level.music._bg_b.playing, "T04: no global background overlap")
	check(level.hud.hint.text.contains("Выключить радио"), "T04: ON hover prompt")
	check((receiver.get_node("PowerIndicator").material_override as StandardMaterial3D).emission_enabled, "T04: soft LED emission enabled")
	check(is_equal_approx(receiver._volume_pivot.rotation.z, deg_to_rad(-60)), "T04: existing volume parts rotate about original shaft")
	await shot("04-radio-on-indicator")
	var track := level.music.radio_index
	await key(KEY_E)
	check(not receiver.powered and AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "T05: OFF makes output silent and turns LED off")
	check(not (receiver.get_node("PowerIndicator").material_override as StandardMaterial3D).emission_enabled, "T05: indicator does not emit when OFF")
	check(track == level.music.radio_index, "T05: AUDIO-01 broadcast timeline retained while silent")
	for i in range(3):
		await key(KEY_E)
		await key(KEY_E)
	await key(KEY_E)
	level.music.attach_radio(receiver, Vector3.ZERO, speaker)
	check(receiver.find_children("*", "AudioStreamPlayer3D", true, false).size() == 1 and level.music._radio == speaker, "T06: repeated E and attachment keep exactly one emitter")
	check(speaker.playing and level.music.radio_on and level.music.radio_index == track, "T06: re-enable resumes same broadcast without restarting")
	check(speaker.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE and speaker.unit_size == 1.5 and speaker.max_distance == 8, "T07: emitter uses distance falloff and finite outdoor range")
	# Real near/far output levels are measured in the separate system recording.
	check(level.save_manager.save_slot("manual", 1, true) == OK, "T08: ON saved to actual career file")
	level.music.toggle_radio()
	check(level.save_manager.load_slot(1, "manual", 1), "T08: save loads through existing envelope/validation")
	check(receiver.powered and level.music.radio_on and speaker.playing and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "T08: loaded ON state matches model and actual output")
	var snapshot := level.capture_snapshot()
	var directory := level.save_manager.directory
	level.music.stop_all()
	level.audio.stop_all()
	await create_timer(.2).timeout
	level.free()
	await frames(3)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	level.music._test_mode = false
	level.save_manager.directory = directory
	check(level.save_manager.load_slot(1, "manual", 1), "T08: new scene instance loads saved career")
	level.resume_game()
	await frames(4)
	check(level.radio_receiver.powered and level.music._radio.playing and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "T08: fresh scene restores audible ON")
	var legacy := snapshot.duplicate(true)
	legacy.world.erase("audio")
	check(level.apply_snapshot(legacy), "T08: old save without audio field remains compatible")
	check(not level.radio_receiver.powered and not level.music.radio_on and AudioServer.is_bus_mute(AudioServer.get_bus_index("Radio")), "T08: legacy defaults OFF with silent output")
	var corrupt := snapshot.duplicate(true)
	corrupt.world.audio.radio_on = "yes"
	check(not level.apply_snapshot(corrupt) and not level.music.radio_on, "T08: invalid radio state rejected without side effects")
	level.music.stop_all()
	await missing_audio()
	# Fault director shares the same buses; restore authoritative scene audio.
	level.music.restore_audio({})
	for device in ["machine", "grinder", "cash", "fridge"]:
		await use(device)
		check(bool(level.session.equipment[device]), "T10: existing " + device + " still operates with physical E")
		if level.hud.panel.visible: level.hud.close_panel()
	check(not level.new_assets.register.drawer_open and not level.fridge.opened, "T10: inspections leave drawer and fridge closed")
	await use("cash")
	await use("fridge")
	await frames(32)
	check(level.new_assets.register.drawer_open and level.fridge.opened, "T10: checked cash drawer and fridge still operate")
	check(level.validate_snapshot(level.capture_snapshot()), "T10: full career snapshot remains valid")
	level.save_manager.autosave_enabled = false
	level.music.stop_all()
	level.audio.stop_all()
	await create_timer(.2).timeout
	level.free()
	await frames(3)
	print("RADIO-01: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func missing_audio() -> void:
	var director := FaultDirector.new()
	root.add_child(director)
	var anchor := Node3D.new()
	root.add_child(anchor)
	director.attach_radio(anchor, Vector3.ZERO)
	director._test_mode = false
	director.set_context("trade")
	director.toggle_radio()
	check(director.radio_index == -1 and not director._radio.playing, "T09: missing audio files leave safe silence")
	director.paths.append(Audio01Director.RADIO_PATHS[0])
	director._advance_radio()
	check(director.radio_index == 2 and director._radio.playing, "T09: missing tracks skipped to next approved playable track")
	director.stop_all()
	# AudioServer owns playback references until the mixer handles stop().
	# Allow that real-time handoff before freeing the spatial speaker and tree.
	await create_timer(.2).timeout
	director.free()
	anchor.free()
