extends SceneTree
## Ordinary graphical launch, without --test-mode. Dummy audio verifies playback state.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(8): await process_frame
	if not world.main_menu.visible or world.player.controls_enabled:
		push_error("FAIL: ordinary launch menu")
		quit(1)
		return
	if not world.music._player.playing or not world.audio.ambient.playing:
		push_error("FAIL: ordinary launch audio")
		quit(1)
		return
	world.audio.play_event("coins")
	for i in range(8): await process_frame
	print("ORDINARY GL STARTUP: menu, original music, ambient and effects active; no test-mode")
	world.quit_game()
