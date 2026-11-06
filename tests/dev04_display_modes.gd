extends "res://tests/asset_integration.gd"
## Exercise the actual menu callbacks and native Godot window, plus dusk lighting.
func run() -> void:
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	await click("Настройки",level.main_menu)
	var fullscreen: CheckBox
	var sizes: OptionButton
	for child in level.main_menu._content.get_children():
		if child is CheckBox and child.text == "Полноэкранный режим": fullscreen = child
		if child is Label and child.text == "Разрешение оконного режима":
			sizes = level.main_menu._content.get_child(child.get_index()+1)
	check(fullscreen != null and sizes != null, "native display controls exist")
	if fullscreen == null or sizes == null: quit(1); return
	fullscreen.button_pressed = true
	await frames(8)
	check(level.game_settings.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "real menu enters native fullscreen")
	fullscreen.button_pressed = false
	await frames(8)
	check(not level.game_settings.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "real menu returns to native windowed mode")
	for index in [2,0]:
		sizes.select(index)
		sizes.item_selected.emit(index)
		await frames(5)
		check(DisplayServer.window_get_size() == Vector2i(CoffeeShiftSettings.WIDTHS[index],CoffeeShiftSettings.HEIGHTS[index]), "native window resolution changes to " + str(index))
	await click("Назад",level.main_menu)
	check(level.new_game(1), "real scene resumes after display changes")
	var samples: Array[float] = []
	for brightness in [.75, 1.25]:
		level.game_settings.brightness = brightness
		level.game_settings.apply_to_game(level.player,level.hud,level.music,false)
		await frames(4)
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		var sample := frame.get_pixel(int(frame.get_width()*.45),int(frame.get_height()*.45))
		samples.append(sample.get_luminance())
	check(samples[1] > samples[0] + .02, "brightness changes actual rendered world pixels")
	level.game_settings.brightness = 1.0
	level.game_settings.apply_to_game(level.player,level.hud,level.music,false)
	level.session.clock = 20 * 3600
	await view(Vector3(0,1.4,0),Vector3(5.5,.02,5.5),70)
	check(level.get_node("Daylight").light_energy < .2, "evening clock reduces daylight")
	await shot("10-evening-1280")
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	print("DEV04 DISPLAY MODES: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
