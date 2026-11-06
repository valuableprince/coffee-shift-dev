extends SceneTree
## Real first_shift viewport; --baseline captures the unmodified PR #79.
var level: ShiftWorld
var checks := 0
var failures := 0
var screenshots := ""
var baseline := false
var selected := -1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots = arg.trim_prefix("--screenshots=")
		if arg == "--baseline": baseline = true
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 6) -> void:
	for i in range(count): await physics_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		# Route to the game window even when the runner owns desktop focus;
		# one rendered frame also prevents press/release sharing a catch-up tick.
		root.push_input(event, true)
		await process_frame
		await frames(2)

func aim(point: Vector3, standing: Vector3) -> void:
	level.player.position = standing
	level.player.velocity = Vector3.ZERO
	var direction := point - (standing + Vector3(0, 1.62, 0))
	level.player.rotation.y = atan2(-direction.x, -direction.z)
	level.player.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	level.player.camera.rotation = Vector3(level.player.pitch, 0, 0)
	await frames()

func shot(name: String) -> void:
	if screenshots == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots.path_join(name + ".png")) == OK, "actual Godot frame " + name)

func run() -> void:
	root.size = Vector2i(1280, 720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames()
	check(level.new_game(1), "start first shift")
	var sink := level.new_assets.sink
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await frames()
		await aim(Vector3(2.0, 1.6, 0.0), Vector3(0, .4, 0))
		level.hud.set_dialogue_preferences(false, .12)
		level._panel("ПОКУПАТЕЛЬ", "Добрый день! Один капучино, пожалуйста.", [
			{"label": "Подтвердить заказ", "call": func() -> void: selected = 0}], true)
		await frames()
		await shot("dialogue-short-%d" % dimensions.x)
		if not baseline:
			var rect := level.hud.panel.get_global_rect()
			# canvas_items already scales the 1280x720 logical canvas at 1080p.
			var canvas_size := root.get_visible_rect().size
			var scale_factor := minf(canvas_size.x / 1280.0, canvas_size.y / 720.0)
			check(rect.size.x >= 650 * scale_factor and rect.size.x <= 760 * scale_factor, "compact width " + str(dimensions))
			check(rect.size.y >= 110 * scale_factor and rect.size.y <= 190 * scale_factor, "compact height with readable Rubik and a separate footer " + str(dimensions))
			check(absf(rect.get_center().x - canvas_size.x * .5) < 2, "dialogue centered on screen")
			print("DIALOGUE MEASUREMENT: window=%s canvas=%s panel=%s" % [dimensions, canvas_size, rect])
			check(not rect.intersects(level.hud.orders_panel.get_global_rect()), "orders sidebar clear of dialogue")
			check(not level.hud._dialogue_buttons[0].disabled, "effect off enables answer")
		level.hud.close_panel()
		var long_line := "Здравствуйте! Мне, пожалуйста, большой капучино с ванильным сиропом и без сахара. "
		long_line += "Ещё нужен маленький американо для коллеги. Мы сегодня работаем в офисе напротив. "
		long_line += "Крышки наденьте на оба стаканчика, а напитки поставьте в один картонный держатель. "
		long_line += "Я подожду у окна. Подскажите, всё ли правильно вы записали?"
		level._panel("ПОКУПАТЕЛЬ · ДЛИННАЯ РЕПЛИКА", long_line, [
			{"label": "Повторить состав и подтвердить заказ", "call": func() -> void: selected = 1}], true)
		await frames()
		await shot("dialogue-long-%d" % dimensions.x)
		if not baseline:
			check(level.hud._dialogue_copy.text == long_line, "long reply retained completely")
			check(level.hud._dialogue_text_scroll.get_v_scroll_bar().max_value > level.hud._dialogue_text_scroll.size.y, "long text scrolls within compact block")
			var before_scroll: int = level.hud.get("_dialogue_text_scroll").scroll_vertical
			await key(KEY_PAGEDOWN)
			check(level.hud._dialogue_text_scroll.scroll_vertical > before_scroll, "keyboard scroll reaches remainder of long reply")
			var text_bar: VScrollBar = level.hud._dialogue_text_scroll.get_v_scroll_bar()
			for page in range(10):
				if text_bar.value + text_bar.page >= text_bar.max_value - .5: break
				await key(KEY_PAGEDOWN)
			check(text_bar.value + text_bar.page >= text_bar.max_value - .5, "last line of long reply is reachable without clipping")
			await shot("dialogue-long-scrolled-%d" % dimensions.x)
		level.hud.close_panel()
		level._panel("ПОКУПАТЕЛЬ · ВАРИАНТЫ ОТВЕТА", "Кофе можно взять с собой?", [
			{"label": "Да, конечно", "call": func() -> void: selected = 2},
			{"label": "Уточнить заказ", "call": func() -> void: selected = 3}], true)
		await frames()
		await shot("dialogue-choices-%d" % dimensions.x)
		if not baseline:
			selected = -1
			await key(KEY_DOWN)
			await key(KEY_ENTER)
			check(selected == 3, "arrows and Enter activate selected response once")
		level.hud.close_panel()
		await aim(sink.global_position + Vector3(0, -.06, 0), Vector3(0, .4, 1.75))
		await shot("sink-workstation-%d" % dimensions.x)
		await aim(sink.global_position + Vector3(0, -.08, 0), Vector3(-.18, .4, 1.35))
		await shot("sink-close-%d" % dimensions.x)
		await aim(sink.get_node("HandReachFaucet").global_position, Vector3(0, .4, 1.15))
		await shot("sink-hover-off-%d" % dimensions.x)
		await key(KEY_E)
		await frames(25)
		await shot("sink-hover-on-%d" % dimensions.x)
		if not baseline:
			check(sink.faucet_on, "E turns faucet on")
			check(level.hud.reticle.is_visible_in_tree(), "center dot remains visible")
			var faucet_point: Vector3 = sink.get_node("LeverPivot").global_position
			check(faucet_point.x < sink.global_position.x - .15, "faucet behind bowl towards -X wall")
			check(faucet_point.x > -1.14, "lever clears inner wall")
		await key(KEY_E)
		await frames(25)
		await aim(Vector3(-.15, 1.4, -.6), Vector3(0, .4, 2.0))
		await shot("interior-%d" % dimensions.x)
	if not baseline:
		level.hud.set_dialogue_preferences(true, .25)
		level._panel("ПОКУПАТЕЛЬ", "Раз два три четыре пять шесть.", [
			{"label": "Первый ответ", "call": func() -> void: selected = 4}], true)
		check(level.hud._dialogue_buttons[0].disabled, "reveal locks responses")
		selected = -1
		await key(KEY_ENTER)
		check(not level.hud._is_typing() and selected == -1, "Enter finishes animation without choosing response")
		await key(KEY_ENTER)
		check(selected == 4, "next Enter confirms focused response")
		await key(KEY_ESCAPE)
		check(not level.hud.panel.visible and level.player.controls_enabled, "Esc closes dialogue and returns controls")
		root.size = Vector2i(1280, 720)
		level.hud.set_dialogue_preferences(false, .12)
		var many_actions: Array = []
		for index in range(8):
			many_actions.append({"label": "Вариант ответа %d" % (index + 1), "call": func() -> void: pass})
		level._panel("ПОКУПАТЕЛЬ", "Проверка длинного списка вариантов.", many_actions, true)
		await frames()
		await key(KEY_UP)
		var focused := root.gui_get_focus_owner()
		check(focused is Button and focused.text == "К работе [Esc]", "keyboard reaches last action in long choice list")
		check(level.hud.panel.get_global_rect().intersection(focused.get_global_rect()).size.y >= focused.size.y * .9, "long choice list scrolls to focused action")
		await key(KEY_ENTER)
		check(not level.hud.panel.visible, "keyboard closes long choice list")
		selected = -1
		level._panel("ПОКУПАТЕЛЬ", "Проверка выбора мышью.", [
			{"label": "Выбрать мышью", "call": func() -> void: selected = 5}], true)
		await frames()
		var point := level.hud._dialogue_buttons[0].get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, true)
		for pressed in [true, false]:
			var mouse := InputEventMouseButton.new()
			mouse.position = point
			mouse.global_position = point
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = pressed
			root.push_input(mouse, true)
			await frames(2)
		check(selected == 5, "actual mouse events activate dialogue response")
		level.hud.close_panel()
	print("DEV03 POLISH: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
