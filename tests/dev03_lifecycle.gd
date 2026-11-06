extends "res://tests/dev03_integration.gd"
## Save-screen transitions and a player entering an already-closing staff door.

func choose_career(id: int) -> void:
	level.save_menu.careers.select(id - 1)
	level.save_menu.careers.item_selected.emit(id - 1)
	await frames(3)

func run() -> void:
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	await click("Новая игра", level.main_menu)
	await click("Начать новую игру", level.main_menu)
	await use("machine")
	check(level.session.equipment.machine, "first career has its own checked equipment")
	await key(KEY_F6)
	check(level.save_menu.visible, "physical F6 opens save screen")
	await choose_career(2)
	check(level.save_manager.career == 2 and not level.session.equipment.machine, "empty career starts independently")
	check(level.save_menu.visible and not level.player.controls_enabled and not level.player.mouse_captured, "new career stays in save screen with cursor free")
	check(level.game_settings.last_career == 2, "new career becomes preferred Continue career")
	if not level.save_menu.visible: level.open_saves()
	await choose_career(1)
	check(level.save_manager.career == 1 and level.session.equipment.machine, "switch restores outgoing career checkpoint")
	check(level.game_settings.last_career == 1, "existing career becomes preferred Continue career")
	check(level.save_menu.visible and not level.player.controls_enabled, "loading existing career keeps save screen paused")
	await key(KEY_F6)
	check(not level.save_menu.visible and level.player.controls_enabled and level.player.mouse_captured, "closing F6 resumes direct gameplay")
	level.return_to_title()
	check(level.main_menu._career_selector.get_selected_id() == 1, "title Continue selects last switched career")
	level.continue_game(1)
	await key(KEY_ESCAPE)
	await click("Сохранения / загрузка", level.main_menu)
	await choose_career(3)
	check(level.save_manager.career == 3, "pause save screen can start third career")
	check(level.save_menu.visible and not level.main_menu.visible and not level.player.controls_enabled, "pause-origin save screen remains open after career creation")
	if not level.save_menu.visible: level.open_saves()
	await key(KEY_ESCAPE)
	check(level.main_menu.visible and not level.save_menu.visible and not level.player.controls_enabled, "closing pause-origin saves returns to pause")
	await click("Вернуться в игру", level.main_menu)
	await key(KEY_F6)
	await choose_career(1)
	# All target files are corrupt: selection must not silently start a new game.
	var damaged_files: Dictionary = {}
	for kind in ["manual", "auto"]:
		for slot in range(1, 4):
			for suffix in ["", ".bak"]:
				var path: String = level.save_manager.slot_path(3, kind, slot) + suffix
				if not FileAccess.file_exists(path): continue
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_string("damaged test save")
				file.close()
				damaged_files[path] = FileAccess.get_file_as_bytes(path)
	check(not damaged_files.is_empty(), "corrupt-career fixture occupies real save slots")
	var previous: Dictionary = level.capture_snapshot()
	await choose_career(3)
	check(level.save_manager.career == 1 and level.game_settings.last_career == 1, "corrupt target leaves current and preferred careers unchanged")
	check(level.save_menu.careers.get_selected_id() == 1, "failed selection restores current career in selector")
	check(level.save_menu.feedback_label.text.contains("Нет исправного сохранения"), "failed switch reports error inside visible save screen")
	check(JSON.stringify(level.capture_snapshot()) == JSON.stringify(previous), "corrupt target does not alter current world")
	for path in damaged_files:
		check(FileAccess.get_file_as_bytes(path) == damaged_files[path], "corrupt target files are preserved for recovery")
	await key(KEY_F6)
	check(not level.main_menu.visible and level.player.controls_enabled, "later direct F6 does not inherit pause return flag")
	var door: TrailerDoor = level.trailer.get_node("StaffDoor")
	await aim(door.to_global(Vector3(.475, .95, 0)), Vector3(0, .4, 1.8))
	await key(KEY_E)
	await frames(42)
	check(door.opened and not door.moving, "staff door opens before approach test")
	await aim(door.to_global(Vector3(.475, .95, 0)), Vector3(0, .4, 1.8))
	await key(KEY_E)
	check(not door.opened and door.moving, "closing starts while player is clear of doorway")
	check(level.save_manager.save_auto("Door is closing") == OK and not level.save_manager._pending, "closing target can be saved before approaching")
	level.player.rotation.y = 0
	level.player.pitch = 0
	level.player.camera.rotation = Vector3.ZERO
	var walk := InputEventKey.new()
	walk.physical_keycode = KEY_S
	walk.pressed = true
	Input.parse_input_event(walk)
	await frames(22)
	await key(KEY_S, false)
	check(absf(level.player.position.z - 2.78) < .38, "physical walking reaches doorway during closing")
	check(door.opened and door.moving, "door reverses smoothly when player enters during closing")
	check(level.save_manager._pending, "automatic reversal schedules checkpoint")
	check(level.capture_snapshot().world.staff_door_opened, "mid-reversal save records safe open target")
	check(level.save_manager.save_slot("manual", 3, true) == OK, "save during automatic reopening")
	await frames(48)
	check(door.opened and not door.moving and door.collision_layer == 1, "reopened door finishes with collision restored")
	check(is_equal_approx(door.rotation.y, deg_to_rad(-100)), "reversal ends at original asset open angle")
	door.restore_opened(false)
	check(level.save_manager.load_slot(1, "manual", 3) and door.opened and not door.moving, "reload mid-reversal safely restores open door")
	door.restore_opened(true)
	await aim(door.to_global(Vector3(.475, .95, 0)), Vector3(0, .4, 1.8))
	await key(KEY_E)
	await frames(42)
	check(not door.opened and not door.moving and door.collision_layer == 1, "door still closes normally after player steps away")
	# Directories at the temporary-file paths reproduce write failures without
	# producing an engine diagnostic for an intentionally invalid parent path.
	await key(KEY_F6)
	var directory := level.save_manager.directory
	var target_failure_directory := directory + "/target_write_failure"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_failure_directory))
	var stage_obstacle := FileAccess.open(target_failure_directory + "/career_2.pending", FileAccess.WRITE)
	stage_obstacle.store_string("occupied staging path")
	stage_obstacle.close()
	level.save_manager.directory = target_failure_directory
	previous = level.capture_snapshot()
	await choose_career(2)
	check(level.save_manager.career == 1 and level.game_settings.last_career == 1, "failed new-career write restores current and preferred careers")
	check(level.save_menu.careers.get_selected_id() == 1 and level.save_menu.visible and level.save_menu.feedback_label.text.contains("Не удалось переключить"), "failed new-career write keeps save screen usable with error message")
	check(JSON.stringify(level.capture_snapshot()) == JSON.stringify(previous), "failed new-career write restores original world")
	level.save_manager.directory = directory
	var source_failure_directory := directory + "/source_write_failure"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_failure_directory + "/career_1/auto_1.json.tmp"))
	level.save_manager.directory = source_failure_directory
	previous = level.capture_snapshot()
	await choose_career(2)
	check(level.save_manager.career == 1 and level.game_settings.last_career == 1, "failed outgoing checkpoint cancels switch")
	check(level.save_menu.careers.get_selected_id() == 1 and level.save_menu.visible and level.save_menu.feedback_label.text.contains("Не удалось сохранить"), "failed outgoing checkpoint restores save-screen selection with error message")
	check(JSON.stringify(level.capture_snapshot()) == JSON.stringify(previous), "failed outgoing checkpoint leaves world unchanged")
	level.save_manager.directory = directory
	level.audio.stop_all()
	level.save_manager.autosave_enabled = false
	level.queue_free()
	await frames(3)
	print("DEV03 LIFECYCLE: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
