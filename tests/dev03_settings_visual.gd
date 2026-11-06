extends SceneTree
## Real Godot window screenshots of the on-screen dialogue-toggle controls.
var screenshots := ""
var checks := 0
var failures := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots = arg.trim_prefix("--screenshots=")
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 2) -> void:
	for i in range(count): await process_frame

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var match_button := find_button(child, caption)
		if match_button != null: return match_button
	return null

func run() -> void:
	root.size = Vector2i(1280,720)
	var level: ShiftWorld = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	var settings_button := find_button(level.main_menu, "Настройки")
	check(settings_button != null, "real first-shift title has Settings")
	if settings_button == null: quit(1); return
	settings_button.pressed.emit()
	await frames(5)
	var content: VBoxContainer = level.main_menu._content
	var scroll := content.get_parent() as ScrollContainer
	var toggle: CheckBox = null
	var interval_slider: Control = null
	for control in content.get_children():
		if control is CheckBox and control.text == "Постепенное появление текста":
			toggle = control
		if control is Label and control.text == "Интервал между словами (мс)":
			interval_slider = content.get_child(control.get_index() + 1) as Control
	check(scroll != null and toggle != null and interval_slider != null, "word toggle and 60–250 ms interval are present")
	if scroll == null or toggle == null or interval_slider == null: quit(1); return
	check(toggle.button_pressed, "word reveal defaults enabled in settings")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		await frames(4)
		scroll.ensure_control_visible(interval_slider)
		await frames(6)
		var visible := scroll.get_global_rect()
		check(toggle.get_global_rect().intersection(visible).size.y >= toggle.size.y * .8,
			"toggle is genuinely visible within scroll at " + str(dimensions))
		check(interval_slider.get_global_rect().intersection(visible).size.y >= interval_slider.size.y * .8,
			"interval slider is genuinely visible at " + str(dimensions))
		if screenshots != "" and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(screenshots)
			await RenderingServer.frame_post_draw
			var out := screenshots.path_join("dialogue-settings-toggle-%d.png" % dimensions.x)
			check(root.get_texture().get_image().save_png(out) == OK, "real GL screenshot: " + out)
	print("DEV03 SETTINGS VISUAL: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
