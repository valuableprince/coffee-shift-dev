extends "res://tests/dev02_integration.gd"
## Additional GL verification from the real on-disk playthrough, never a fake ready state.
## Run after dev02_integration.gd in the same Godot user-data directory.

func _run() -> void:
	await _new_level()
	var base := OS.get_user_data_dir()
	var selected_source := ""
	var modified := -1
	for folder in DirAccess.get_directories_at(base):
		if not folder.begins_with("dev02_tests_"):
			continue
		var directory := base.path_join(folder)
		level.save_manager.directory = directory
		var saved: Dictionary = level.save_manager.read_slot(1,"manual",1)
		if saved.is_empty() or not saved.data.restoration.ready_for_opening:
			continue
		var time := FileAccess.get_modified_time(level.save_manager.slot_path(1,"manual",1))
		if time > modified:
			modified = time
			selected_source = directory
	_check(selected_source!="","completed physical playthrough save exists")
	if selected_source=="":
		quit(1)
		return
	level.save_manager.directory = selected_source
	_check(level.save_manager.load_slot(1,"manual",1) and state.ready_for_opening,"GL reconstructs completed world from actual playthrough")
	var partial: Dictionary = level.save_manager.read_slot(1,"manual",2)
	_check(not partial.is_empty(),"physical partial-cleaning checkpoint exists")
	saved_partial = float(partial.data.restoration.records["trailer_01.service_window"].progress)
	var partial_path: String = level.save_manager.slot_path(1,"manual",2)
	test_directory = "user://dev02_render_checks_"+str(OS.get_process_id())+"_"+str(int(Time.get_unix_time_from_system()*1000000))
	level.save_manager.directory = test_directory
	var destination: String = level.save_manager.slot_path(1,"manual",2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	DirAccess.copy_absolute(partial_path,destination)
	await _save_checks()
	_check(level.save_manager.load_slot(1,"manual",1),"valid reload clears feedback from negative save tests")
	_check(level.save_manager.load_slot(1,"manual",2),"load discovered unfinished tasks for paper layout checks")
	await _tap("notebook")
	for spread in range(level.hud.notebook.page_count()):
		level.hud.notebook.spread = spread
		level.hud.notebook.refresh()
		await _frames(2)
		for page in [level.hud.notebook.notes,level.hud.notebook.entries]:
			_check(page.get_content_height()<=page.size.y+4,"GL paper text fits spread %d"%spread)
	await _tap("notebook")
	_check(level.save_manager.load_slot(1,"manual",1),"restore ready world after all paper page checks")
	await _tool(&"brush")
	await _place(Vector3(2.5,.02,0),Vector3(1.185,1.65,0))
	await _frames(22)
	level.hud.show_belt()
	await _shot("10-tools-in-hand")
	level.hud.notebook.spread = 0
	await _tap("notebook")
	await _shot("08-completed-notebook")
	await _tap("notebook")
	await _tap("save_menu")
	await _shot("09-career-save-menu")
	await _tap("save_menu")
	await _place(Vector3(0,.41,0),Vector3(.84,1.51,-1.52))
	await _shot("11-equipment")
	level.queue_free()
	await _frames(3)
	print("DEV-02 GL SAVE RESULT: %d checks; %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
