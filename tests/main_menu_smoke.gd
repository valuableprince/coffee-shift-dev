extends SceneTree
## Fresh menu lifecycle with isolated save files. Run with --test-mode --test-menu.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	# Regression for Windows: input can arrive before a parent Node3D's _ready().
	# Both keyboard and pointer events must be ignored while the menu is null.
	var early_pointer := InputEventMouseMotion.new()
	scene._input(early_pointer)
	var early_escape := InputEventAction.new()
	early_escape.action = "ui_cancel"
	early_escape.pressed = true
	scene._input(early_escape)
	_check(scene.main_menu == null,"pre-ready input never dereferences a null menu")
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var manager: RestorationSaveManager = scene.save_manager
	manager.directory = "user://main_menu_tests_%d" % OS.get_process_id()
	_check(scene.main_menu.visible,"F5 starts with the title menu")
	_check(not scene.player.controls_enabled and not scene.player.mouse_captured,"title menu releases mouse and blocks gameplay")
	_check(scene.main_menu._career_selector.disabled,"Continue is disabled without a valid save")
	_check(manager.latest(1).is_empty(),"no save created by opening main menu")
	scene._new_game_from_menu(1,false)
	_check(not scene.main_menu.visible and scene.player.controls_enabled,"New game enters the garage")
	_check(not manager.latest(1).is_empty(),"new game creates first valid autosave")
	_check(manager.career == 1,"first career selected")
	scene._show_pause()
	_check(scene.main_menu.visible and not scene.player.mouse_captured,"pause opens a navigable overlay")
	scene.main_menu.back()
	_check(not scene.main_menu.visible and scene.player.mouse_captured,"Escape resumes gameplay from pause")
	scene._show_pause()
	scene._return_to_title()
	_check(scene.main_menu.visible and not scene._game_active,"return to title safely ends active gameplay")
	scene._continue_from_menu(1)
	_check(scene._game_active and manager.career == 1 and scene.player.controls_enabled,"Continue loads the latest save")
	scene._return_to_title()
	scene._new_game_from_menu(2,false)
	_check(manager.career == 2 and not manager.latest(2).is_empty(),"second career starts independently")
	_check(not manager.latest(1).is_empty(),"second career leaves the first intact")
	scene._return_to_title()
	scene._new_game_from_menu(1,true)
	_check(manager.career == 1 and not manager.latest(1).is_empty(),"confirmed overwrite creates a clean career")
	_check(not manager.latest(2).is_empty(),"overwriting first career does not delete second")
	# P0: DEV-02 must also save the new career before replacing the old files.
	scene._return_to_title()
	var before_failure: Dictionary = scene.capture_snapshot()
	var preferred: int = scene.game_settings.last_career
	var existing := {}
	for row in manager.list_slots(1):
		for suffix in ["", ".bak"]:
			var path := manager.slot_path(1, row.kind, row.slot) + str(suffix)
			if FileAccess.file_exists(path): existing[path] = FileAccess.get_file_as_bytes(path)
	var stage_path := manager.slot_path(1, "auto", 1).get_base_dir() + ".pending"
	var obstacle := FileAccess.open(stage_path, FileAccess.WRITE)
	obstacle.store_string("occupied staging path")
	obstacle.close()
	scene._new_game_from_menu(1, true)
	_check(scene.main_menu.visible and not scene._game_active, "failed overwrite keeps title menu open")
	_check(JSON.stringify(scene.capture_snapshot()) == JSON.stringify(before_failure), "failed overwrite retains garage world")
	_check(manager.career == 1 and scene.game_settings.last_career == preferred, "failed overwrite retains selected and preferred careers")
	for path in existing:
		_check(FileAccess.get_file_as_bytes(path) == existing[path], "failed overwrite retains garage save bytes")
	_check(manager.load_slot(1, "auto", 1), "garage save remains loadable after failed overwrite")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage_path))
	scene._continue_from_menu(1)
	scene._show_pause()
	scene.game_settings.master_volume = 50
	scene.game_settings.brightness = 1.1
	scene._apply_settings()
	_check(scene.game_settings.master_volume == 50 and is_equal_approx(scene.game_settings.brightness,1.1),"settings apply without corrupting a career")
	scene._resume_game()
	var snapshot: Dictionary = scene.capture_snapshot()
	_check(scene.validate_snapshot(snapshot),"menu lifecycle keeps restoration saves valid")
	scene.save_manager.autosave_enabled = false
	scene.queue_free()
	await process_frame
	print("MAIN MENU RESULT: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
