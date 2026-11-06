extends SceneTree
## Live first_shift regression and review frames. Sample conversations are
## presentation fixtures, not new NPC stories or economic rules.
var level: ShiftWorld
var checks := 0
var failures := 0
var screenshots := ""
var selected := -1
var activations := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots = arg.trim_prefix("--screenshots=")
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 4) -> void:
	for i in range(count): await process_frame

func key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		# Target the game viewport even if a test runner owns OS window focus.
		root.push_input(event, true)
		await frames(2)

func mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
		await frames(2)

func aim(point: Vector3, standing := Vector3(0, .4, 0)) -> void:
	level.player.position = standing
	level.player.velocity = Vector3.ZERO
	var delta := point - (standing + Vector3(0, 1.62, 0))
	level.player.rotation.y = atan2(-delta.x, -delta.z)
	level.player.pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())
	level.player.camera.rotation.x = level.player.pitch
	await frames()

func shot(filename: String) -> void:
	if screenshots.is_empty() or DisplayServer.get_name() == "headless": return
	var destination := ProjectSettings.globalize_path(screenshots).simplify_path()
	var repository := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if not destination.is_absolute_path() or destination == repository or destination.begins_with(repository + "/"):
		check(false, "review images must be outside the Git repository")
		return
	DirAccess.make_dir_recursive_absolute(destination)
	await frames()
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	check(frame.get_size() == root.size, "exact render size: " + filename)
	check(frame.save_png(destination.path_join(filename + ".png")) == OK, "real Godot frame: " + filename)

func sample_actions(count: int) -> Array:
	var result: Array = []
	for index in range(count):
		var choice := index
		result.append({"label": ["Да, всё верно. Сейчас приготовлю.", "Уточнить размер стакана", "Попросить немного подождать"][index % 3] + (" — вариант %d" % (index + 1) if count > 3 else ""),
			"call": func() -> void:
				selected = choice
				activations += 1})
	return result

func speaker() -> String:
	return (level.hud.panel_content.find_child("Speaker", true, false) as Label).text

func run() -> void:
	root.size = Vector2i(1280, 720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(8)
	check(level.new_game(1), "start a separate test career")
	# Presentation tests do not advance shifts while awaiting slow GL frames.
	level.set_physics_process(false)
	for device in level.session.equipment: check(level.session.prepare_equipment(device), "existing DEV-05 preparation: " + device)
	check(level.session.toggle_window() and level.session.open_shift(), "open service hatch and shift")
	var customer := level.session.spawn_customer()
	customer.state = "counter"
	customer.position = level.session.catalog.config.points.counter.duplicate()
	customer.items = [{"recipe": "espresso_small", "sugar": false, "syrup": false}]
	level._sync_customers(0)
	await create_timer(.65).timeout
	await aim(Vector3(1.9, 1.6, 0))
	level.hud.set_dialogue_preferences(false, .12)
	var before := level.session.snapshot()
	level.show_customer()
	await frames(6)
	check(speaker() == "Покупатель", "first unknown visit does not expose profile name")
	check(not level.player.controls_enabled and not level.player.mouse_captured, "full conversation owns input and shows cursor")
	check(level.hud._dialogue_buttons.size() == 1, "real order has one semantic confirmation")
	check(level.hud._dialogue_copy.get_theme_font("font").get_font_name().contains("Rubik"), "bundled Rubik used by dialogue copy")
	check(DialogueStyle.FONT_NOTICE.get_meta("text") == FileAccess.get_file_as_string("res://assets/fonts/rubik/OFL.txt"), "complete font licence retained as an exportable dependency")
	check(not level.hud.panel.get_global_rect().intersects(level.hud.orders_panel.get_global_rect()), "orders and DEV-05 HUD do not overlap panel")
	await shot("01-short-1280x720")
	await key(KEY_ESCAPE)
	check(level.player.controls_enabled and level.player.mouse_captured and not level.hud.panel.visible, "Esc closes conversation and returns FPS controls")
	check(level.session.snapshot() == before, "polite exit never creates order or changes economy")
	check((level.npc_visuals[int(customer.id)] as ShiftCustomerVisual).label.text.is_empty(), "unknown profile name not displayed above head")

	# Explicit domain-supplied knowledge contract. No acquaintance/story system
	# is invented here. Extra legacy-compatible metadata is round-tripped.
	customer.name = "Андрей"
	customer.name_known = true
	level.show_customer()
	check(speaker() == "Андрей", "known NPC uses the name supplied by the domain")
	level.hud.close_panel()
	var known_save := level.capture_snapshot()
	check(level.apply_snapshot(known_save), "schema 2 career restores without migration")
	customer = level.session.customer_by_id(int(customer.id))
	level.show_customer()
	check(speaker() == "Андрей", "explicitly known name survives snapshot restore")
	level.hud.close_panel()
	var old_save := known_save.duplicate(true)
	old_save.trade.customers[0].erase("name_known")
	check(level.apply_snapshot(old_save), "old schema 2 save without acquaintance metadata loads")
	customer = level.session.customers[0]
	level.show_customer()
	check(speaker() == "Покупатель", "old profile name never implies acquaintance")
	level.hud.close_panel()

	for dimensions in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = dimensions
		await frames(6)
		await aim(Vector3(1.9, 1.6, 0))
		level._panel("Покупатель", "Добрый день! Один капучино с собой, пожалуйста.", sample_actions(3), true)
		await frames(6)
		var rect := level.hud.panel.get_global_rect()
		check(rect.size.x <= root.get_visible_rect().size.x * .65 and rect.size.y <= root.get_visible_rect().size.y * .43, "compact panel at " + str(dimensions))
		check(absf(rect.get_center().x-root.get_visible_rect().size.x*.5) < 1, "centered panel at " + str(dimensions))
		check(level.hud._dialogue_navigation[0].get_global_rect().position.y < level.hud._dialogue_navigation[1].get_global_rect().position.y, "vertical replies at " + str(dimensions))
		await shot("02-three-answers-%dx%d" % [dimensions.x, dimensions.y])
		selected = -1
		activations = 0
		await key(KEY_DOWN)
		await key(KEY_ENTER)
		check(selected == 1 and activations == 1, "keyboard selects the second answer once")
		await key(KEY_ENTER)
		check(activations == 1, "rapid repeated confirmation never repeats callback")
		level.hud.close_panel()

		var long_text := "Здравствуйте! Мне, пожалуйста, большой капучино без сахара и маленький американо для коллеги. Крышки наденьте на оба стаканчика, напитки поставьте в один картонный держатель. "
		long_text += "Я подожду рядом с трейлером, пока вы готовите. " .repeat(8) + "Это последняя строка длинной реплики."
		level._panel("Покупатель", long_text, sample_actions(1), true)
		await frames(6)
		check(level.hud._dialogue_copy.text == long_text and level.hud._dialogue_copy.get_line_count() > 3, "long Cyrillic line wraps with full content retained")
		await shot("03-long-%dx%d" % [dimensions.x, dimensions.y])
		var scroll := level.hud._dialogue_text_scroll
		await key(KEY_PAGEDOWN)
		check(scroll.scroll_vertical > 0, "long text keyboard scroll works")
		for page in range(20): await key(KEY_PAGEDOWN)
		var bar := scroll.get_v_scroll_bar()
		check(bar.value + bar.page >= bar.max_value - 1, "last line of long text is reachable")
		level.hud.close_panel()

	root.size = Vector2i(1280,720)
	await frames(6)
	level.hud.set_dialogue_preferences(true, .25)
	level._panel("Покупатель", "Добрый день! Мне один большой капучино, пожалуйста. Я немного подожду у окна.", sample_actions(1), true)
	level.hud.set_process(false)
	level.hud._advance_dialogue(.55)
	check(level.hud._is_typing() and level.hud._dialogue_copy.visible_characters > 0, "word reveal progresses by whole words")
	check(level.hud._dialogue_buttons[0].disabled, "answer locked until word reveal completes")
	await shot("04-word-reveal-1280x720")
	activations = 0
	await mouse(level.hud._dialogue_buttons[0].get_global_rect().get_center())
	check(not level.hud._is_typing() and activations == 0, "mouse skip and release reveal text without selecting answer")
	await mouse(level.hud._dialogue_buttons[0].get_global_rect().get_center())
	check(activations == 1, "second mouse click confirms exactly once")
	level.hud.close_panel()
	level._panel("Покупатель", "Ещё одна новая реплика для проверки сброса.", sample_actions(1), true)
	check(level.hud._word_index == 0 and level.hud._dialogue_copy.visible_characters == 0, "new line resets reveal")
	activations = 0
	await key(KEY_SPACE)
	check(not level.hud._is_typing() and activations == 0, "Space only reveals text")
	await key(KEY_ENTER)
	check(activations == 1, "Enter confirms after reveal")
	level.hud.close_panel()
	level.hud.set_dialogue_preferences(false, .12)
	level.hud.set_process(true)

	var many := sample_actions(14)
	many[1].disabled = true
	level._panel("Покупатель", "Проверка прокручиваемого списка ответов.", many, true)
	await frames(6)
	await key(KEY_DOWN)
	check(root.gui_get_focus_owner() == level.hud._dialogue_navigation[2], "keyboard skips unavailable answer")
	for step in range(11): await key(KEY_DOWN)
	var focus := root.gui_get_focus_owner() as Button
	check(focus == level.hud._dialogue_navigation[13], "keyboard reaches last answer")
	check(level.hud._dialogue_actions_scroll.get_global_rect().encloses(focus.get_global_rect()), "focused final answer scrolled into view")
	await key(KEY_ESCAPE)
	var conversation_before := level.session.snapshot()
	level._panel("Покупатель", "Необязательная беседа без покупки.", [], true, false)
	await key(KEY_ESCAPE)
	check(level.hud.panel.visible, "Esc respects caller's close permission")
	level.hud.close_panel()
	check(not level.hud.panel.visible, "authoritative close remains available")
	check(level.session.snapshot() == conversation_before, "conversation without order never creates sale, tip or ingredient cost")
	await aim(level.new_assets.sink.get_node("HandReachFaucet").global_position, Vector3(0,.4,1.15))
	level._panel("Покупатель", "Выбор ответа временно занимает управление.", sample_actions(1), true)
	var closed_faucet: bool = level.new_assets.sink.faucet_on
	await key(KEY_E)
	check(level.new_assets.sink.faucet_on == closed_faucet, "equipment cannot activate while choosing full-dialogue answer")
	var frozen_yaw := level.player.rotation.y
	var blocked_motion := InputEventMouseMotion.new()
	blocked_motion.relative = Vector2(20,0)
	root.push_input(blocked_motion, true)
	check(is_equal_approx(frozen_yaw, level.player.rotation.y), "camera stays fixed while choosing answer")
	level.hud.close_panel()

	# Confirm the genuine existing order through the redesigned view.
	level.show_customer()
	await frames()
	await key(KEY_ENTER)
	check(not level.session.cash.payment.is_empty() and not level.hud._dialogue_mode, "dialogue confirmation opens existing cash UI")
	var order_id := int(level.session.cash.payment.order)
	check(level.session.accept_cash(), "cash still accepts tender after dialogue")
	var remaining := int(level.session.cash.payment.tender) - int(level.session.cash.payment.total)
	for denomination in ShiftCashRegister.DENOMINATIONS:
		while remaining >= denomination and level.session.cash.select(denomination): remaining -= denomination
	check(remaining == 0 and level.session.finalize_payment(), "correct change settles existing order")
	level.hud.close_panel()
	check(level.session.select_item(order_id,0), "select paid drink")
	for action in ["beans","grind","filter","dose","install","cup","extract"]:
		check(level.session.prepare_action(action), "existing manual preparation: " + action)
	customer = level.session.customer_by_id(int(customer.id))
	customer.wait = level.session.catalog.config.customers.patience_seconds + 1.0
	customer.warned = false
	var economy_before := JSON.stringify([level.session.cash.till, level.session.inventory.stock, level.session.inventory.reserved, level.session.stats])
	level.session.tick(.01)
	check(level.hud.aside.visible and not level.hud.panel.visible, "existing waiting event uses a non-modal remark")
	check(level.player.controls_enabled and level.player.mouse_captured, "short remark preserves camera and FPS controls")
	check(level.hud.aside.mouse_filter == Control.MOUSE_FILTER_IGNORE, "short remark cannot intercept mouse")
	check(JSON.stringify([level.session.cash.till, level.session.inventory.stock, level.session.inventory.reserved, level.session.stats]) == economy_before, "waiting remark introduces no fines, tips or resource cost")
	check(level.session.order_by_id(order_id).paid and level.session.order_by_id(order_id).status == "paid", "waiting never cancels paid order")
	level.hud._aside_words.reveal()
	await aim(level.machine_visual.global_position + Vector3(0,.35,0), Vector3(0,.4,-.3))
	check(level.hud.aside.size.y <= root.get_visible_rect().size.y * .2 and not level.hud.aside.get_global_rect().has_point(root.get_visible_rect().get_center()), "short remark stays compact and leaves the center of the world visible")
	await shot("05-brewing-aside-1280x720")
	var elapsed_before := float(level.session.preparation.current.elapsed)
	level.set_physics_process(true)
	await create_timer(.12).timeout
	level.set_physics_process(false)
	check(float(level.session.preparation.current.elapsed) > elapsed_before, "extraction timer advances during short remark")
	var yaw := level.player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(15,0)
	root.push_input(motion, true)
	await frames(2)
	check(not is_equal_approx(level.player.rotation.y, yaw), "camera rotates during short remark")
	await aim(level.new_assets.sink.get_node("HandReachFaucet").global_position, Vector3(0,.4,1.15))
	var faucet_before: bool = level.new_assets.sink.faucet_on
	await key(KEY_E)
	check(level.new_assets.sink.faucet_on != faucet_before, "E still operates equipment during short remark")
	await shot("06-equipment-aside-1280x720")
	level.hud._aside_time = .01
	level.hud._process(.1)
	check(not level.hud.aside.visible, "short remark expires without confirmation")
	level.session.tick(maxf(0, 10-float(level.session.preparation.current.elapsed)))
	for action in ["stop", "lid", "place"]: check(level.session.prepare_action(action), "finish genuine drink: " + action)
	check(level.session.call_order(order_id), "existing order call remains available")
	level.session.tick(10)
	await aim(Vector3(1.9,1.6,0))
	level._sync_customers(0)
	level.show_customer()
	await frames(6)
	root.size = Vector2i(1920,1080)
	await frames(6)
	await shot("07-customer-and-panel-1920x1080")
	await key(KEY_ENTER)
	check(level.session.order_by_id(order_id).status == "served" and level.session.stats.completed == 1, "drink handoff succeeds after dialogue")
	check(not level.hud.panel.visible and level.player.mouse_captured, "handoff returns input without stuck cursor")
	check(level.session.validate(level.session.snapshot()), "career invariants and schema still valid after full service")

	var settings := CoffeeShiftSettings.new()
	settings.dialogue_word_reveal = false
	settings.dialogue_word_interval = .21
	check(settings.save_to_disk() == OK, "global dialogue settings saved")
	var restored := CoffeeShiftSettings.new()
	restored.load_from_disk()
	check(not restored.dialogue_word_reveal and is_equal_approx(restored.dialogue_word_interval,.21), "dialogue preferences survive disk roundtrip")
	level.hud.show_aside("Покупатель", "Спасибо!")
	level.open_saves()
	check(not level.hud.aside.visible and not level.hud.panel.visible, "save menu clears transient UI")
	level._close_saves()
	check(level.player.mouse_captured and level.hud.control_hints.visible, "save menu returns cursor and control hints")
	print("DIALOGUE UI01: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
