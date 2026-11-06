extends SceneTree
## Actual scene + physical key events + raycasts. Run headless or GL Compatibility.
var checks := 0
var failures := 0
var level: ShiftWorld
var screenshots := ""
var _shot_names: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots = arg.trim_prefix("--screenshots=")
	call_deferred("run")

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + text)

func frames(count: int = 2) -> void:
	for i in range(count): await physics_frame

func key(code: int, down: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	# Input accumulates until the next rendered frame. Catch-up physics ticks
	# alone can otherwise read the old state or deliver a press at the next aim.
	Input.flush_buffered_events()
	await process_frame
	await frames()
	if down: await key(code, false)

func click(text: String, root_node: Node = null) -> bool:
	var root_ui := root_node if root_node != null else level.hud.panel_content
	var found := find_button(root_ui, text)
	if found == null:
		check(false, "UI button exists: " + text)
		return false
	check(not found.disabled, "UI action enabled: " + text)
	if found.disabled: return false
	found.pressed.emit()
	await frames()
	return true

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text.begins_with(text): return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null

func aim(point: Vector3, standing: Vector3) -> void:
	level.player.position = standing
	level.player.velocity = Vector3.ZERO
	var direction := point - (standing + Vector3(0, 1.62, 0))
	level.player.rotation.y = atan2(-direction.x, -direction.z)
	level.player.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	level.player.camera.rotation = Vector3(level.player.pitch, 0, 0)
	await frames(3)

func use(action: String) -> void:
	if level.hud.panel.visible: level.hud.close_panel()
	var target: ShiftWorkstation = level.stations[action]
	await aim(target.global_position, Vector3(0, .4, clampf(target.global_position.z, -2.10, 2.0)))
	check(level.player.get_interactable() == target, "raycast reaches " + action)
	await key(KEY_E)

func shot(name: String) -> void:
	if screenshots == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await frames(3)
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_jpg(screenshots.path_join(name + ".jpg"), .90)
	check(result == OK, "real viewport screenshot " + name)
	_shot_names.append(name)

func wait_for_counter() -> void:
	for i in range(40):
		level.session.tick(.5)
		if not level.session.counter_customer().is_empty(): break
	await frames()

func take_payment() -> int:
	await wait_for_counter()
	await use("counter")
	check(level.hud.panel.visible, "Russian dialogue opens at counter")
	check(level.hud._is_typing(), "customer dialogue starts word-by-word reveal")
	# The real customer is still talking when captured; this is not a preview UI.
	if "05-dialogue-typing-720" not in _shot_names:
		root.size = Vector2i(1280,720)
		await shot("05-dialogue-typing-720")
		root.size = Vector2i(1920,1080)
		await shot("05-dialogue-typing-1080")
		root.size = Vector2i(1280,720)
	await key(KEY_SPACE)
	check(not level.hud._is_typing(), "Space reveals the complete order dialogue")
	if "05-text-order" not in _shot_names: await shot("05-text-order")
	await click("Повторить состав")
	check(not level.session.cash.payment.is_empty(), "confirmation creates sidebar order and cash operation")
	var id := int(level.session.cash.payment.get("order", 0))
	if id == 0: return 0
	await click("Принять купюры")
	if "06-cash-payment" not in _shot_names: await shot("06-cash-payment")
	# Save during tender escrow; restore through verified on-disk manager.
	check(level.save_manager.save_slot("manual", 2, true) == OK, "save during unfinished payment")
	var before: Dictionary = level.capture_snapshot()
	check(level.save_manager.load_slot(1, "manual", 2), "restore unfinished payment from disk")
	check(JSON.stringify(level.capture_snapshot()) == JSON.stringify(before), "payment restore is exact")
	var rest := int(level.session.cash.payment.tender) - int(level.session.cash.payment.total)
	for denomination in ShiftCashRegister.DENOMINATIONS:
		while rest >= denomination:
			await click("Ячейка %d ₽" % int(denomination))
			rest -= denomination
	await click("Передать сдачу")
	check(level.session.order_by_id(id).paid, "cash UI finalizes exactly once")
	check(level.hud.item_buttons.size() >= 1, "order visible in right sidebar")
	return id

func select_from_sidebar(id: int, index: int) -> void:
	await key(KEY_TAB)
	check(level._orders_editing and not level.player.controls_enabled, "Tab enables sidebar order selection")
	var button: Button = level.hud.item_buttons.get("%d:%d" % [id,index])
	check(button != null and not button.disabled, "paid item selectable in sidebar")
	if button != null: button.pressed.emit()
	await frames()
	check(not level._orders_editing and level.player.mouse_captured, "selecting item resumes physical work")

func cook(id: int, index: int) -> void:
	await select_from_sidebar(id, index)
	var order := level.session.order_by_id(id)
	var sequence := level.session.catalog.steps(order.items[index])
	var mapping := {"beans":"beans", "grind":"grinder", "filter":"filter", "dose":"dose", "install":"machine", "cup":"cups", "extract":"machine", "stop":"machine", "water":"water", "milk":"milk", "pitcher":"pitcher", "steam":"steam", "stop_steam":"steam", "pour":"pitcher", "sugar":"sugar", "syrup":"syrup", "lid":"lids", "place":"ready"}
	for step in sequence:
		if step == "milk" and not level.fridge.opened:
			await use("fridge")
			await frames(32)
		if step == "stop":
			level.session.tick(9)
			if "07-espresso" not in _shot_names: await shot("07-espresso")
		if step == "stop_steam":
			level.session.tick(4.5 if level.session.catalog.recipes[order.items[index].recipe].drink == "cappuccino" else 2.5)
			if "08-cappuccino" not in _shot_names: await shot("08-cappuccino")
		var before: Dictionary = level.session.snapshot()
		await use(str(mapping[step]))
		check(JSON.stringify(before) != JSON.stringify(level.session.snapshot()), "world operation progresses " + str(step))
		check(level.validate_snapshot(level.capture_snapshot()), "world save valid after " + str(step))
		if step == "extract":
			check(level.save_manager.save_slot("manual", 1, true) == OK, "save during extraction")
			var mid: Dictionary = level.capture_snapshot()
			check(level.save_manager.load_slot(1, "manual", 1), "load running extraction")
			check(JSON.stringify(level.capture_snapshot()) == JSON.stringify(mid), "running extraction restored without double use")
	check(level.session.order_by_id(id).items[index].ready, "manually prepared cup reaches rack")

func serve(id: int) -> void:
	var order := level.session.order_by_id(id)
	if order.items.size() > 1:
		for i in range(order.items.size()):
			await use("carrier")
			await click("В держатель: №%03d · стакан %d" % [id, i + 1])
	await key(KEY_TAB)
	var call: Button = level.hud.call_buttons.get(id)
	check(call != null and not call.disabled, "ready order can be called from sidebar")
	if call != null: call.pressed.emit()
	await frames()
	level.session.tick(12)
	await frames()
	await use("counter")
	if level.hud._is_typing(): await key(KEY_SPACE)
	if "10-handover" not in _shot_names: await shot("10-handover")
	await click("Передать через окно")
	check(level.session.order_by_id(id).status == "served", "handover UI serves appropriate customer")
	check(level.validate_snapshot(level.capture_snapshot()), "served world remains valid")

func run() -> void:
	level = load("res://scenes/first_shift.tscn").instantiate()
	var early := InputEventMouseMotion.new()
	level._input(early)
	check(level.main_menu == null, "early Windows-like input safely ignored")
	root.add_child(level)
	current_scene = level
	await frames(3)
	check(level.main_menu.visible and not level.player.controls_enabled, "starts in existing main menu")
	await shot("01-main-menu")
	await click("Настройки", level.main_menu)
	# Scroll to the *actual* word-effect checkbox and interval control before capturing.
	var settings_content: VBoxContainer = level.main_menu._content
	var settings_scroll := settings_content.get_parent() as ScrollContainer
	var interval_control: Control = null
	for setting in settings_content.get_children():
		if setting is Label and setting.text == "Интервал между словами (мс)":
			interval_control = settings_content.get_child(setting.get_index() + 1) as Control
	check(settings_scroll != null and interval_control != null, "word-effect setting controls are present in main menu")
	if settings_scroll != null and interval_control != null: settings_scroll.ensure_control_visible(interval_control)
	await frames(4)
	await shot("01-dialogue-settings-720")
	root.size = Vector2i(1920,1080)
	await frames(3)
	if settings_scroll != null and interval_control != null: settings_scroll.ensure_control_visible(interval_control)
	await frames(4)
	await shot("01-dialogue-settings-1080")
	root.size = Vector2i(1280,720)
	await click("Назад", level.main_menu)
	await click("Новая игра", level.main_menu)
	await click("Начать новую игру", level.main_menu)
	check(level._active and level.player.position.y > .3, "new career starts inside prepared trailer")
	check(not level.session.shift_open and not level.session.snapshot().prologue_completed, "prototype does not award prologue achievement")
	check(level.validate_snapshot(level.capture_snapshot()), "initial new-career snapshot valid")
	await aim(Vector3(0, 1.3, 0), Vector3(5, .02, 5))
	await shot("02-trading-location")
	await aim(Vector3(.8, 1.4, -1), Vector3(0, .4, 1.6))
	await shot("03-interior")
	for device in ["machine", "grinder", "fridge", "cash"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("window")
	await frames(54)
	check(level.session.window_open and absf(level.shutter.rotation.z-deg_to_rad(77)) < .001, "original hatch opens to its +77 degree endpoint")
	check(level.shutter.to_global(Vector3(0,-.896,0)).y > 1.89, "open hatch clears the coffee serving area")
	await use("shift")
	await click("Открыть смену")
	check(level.session.shift_open, "sign starts shift separately from window")
	# Deterministic customer profile fixture; all statuses come from real operations.
	level.session.catalog.config.customers.profiles = [{"name":"Офисник","color":"536f75","preferred":["espresso_small"],"greeting":"Здравствуйте! Мне, пожалуйста,"}]
	level.session.catalog.config.customers.interval_seconds = 99999
	level.session.spawn_customer()
	await wait_for_counter()
	await aim(Vector3(2, 1.6, 0), Vector3(0, .4, 0))
	await shot("04-customer-at-window")
	var id := await take_payment()
	if id == 0: quit(1); return
	await cook(id, 0)
	await aim(Vector3(.48, 1.79, 0), Vector3(0, .4, .6))
	await shot("09-orders-sidebar")
	await serve(id)
	level.session.catalog.config.customers.profiles[0].preferred = ["cappuccino_large"]
	level.session.spawn_customer()
	id = await take_payment()
	if id == 0: quit(1); return
	await cook(id, 0)
	await serve(id)
	level.session.catalog.config.customers.profiles[0].preferred = ["latte_standard"]
	level.session.spawn_customer()
	id = await take_payment()
	if id == 0: quit(1); return
	for i in range(level.session.order_by_id(id).items.size()): await cook(id, i)
	await serve(id)
	await use("shift")
	await click("Закрыть смену")
	check(not level.session.shift_open and level.session.stats.completed == 3, "full three-customer shift completed")
	await shot("11-shift-report")
	level.hud.close_panel()
	await key(KEY_ESCAPE)
	check(level.main_menu.visible, "physical Escape opens pause menu")
	await click("Сохранения / загрузка", level.main_menu)
	check(level.save_menu.visible, "same career save menu reused")
	check(level.save_manager.save_slot("manual", 3, true) == OK, "closed shift saved")
	var complete: Dictionary = level.capture_snapshot()
	check(level.save_manager.load_slot(1, "manual", 3), "closed shift reload")
	check(JSON.stringify(complete) == JSON.stringify(level.capture_snapshot()), "reload duplicates no cash, drinks or customers")
	level._close_saves()
	await click("Главное меню", level.main_menu)
	await click("Продолжить игру", level.main_menu)
	check(level.session.stats.completed == 3, "Continue restores latest good shift")
	level.return_to_title()
	level.new_game(2)
	check(level.save_manager.career == 2 and level.session.orders.is_empty(), "careers independent")
	level.return_to_title()
	level.continue_game(1)
	check(level.session.stats.completed == 3, "first career retained after second starts")
	# Real key motion checks both sensitivity axes, including formerly broken Y.
	var pointer := InputEventMouseMotion.new()
	pointer.relative = Vector2(10, 10)
	var old_pitch := level.player.pitch
	Input.parse_input_event(pointer)
	await frames()
	check(level.player.pitch < old_pitch, "real mouse motion updates pitch safely")
	level.save_manager.autosave_enabled = false
	level.queue_free()
	await frames(3)
	print("DEV03 INTEGRATION: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
