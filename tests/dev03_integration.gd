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

func aim_station(action: String) -> ShiftWorkstation:
	if level.hud.panel.visible: level.hud.close_panel()
	var target: ShiftWorkstation = level.stations[action]
	var standing := Vector3(0, .4, clampf(target.global_position.z, -2.10, 2.0))
	if level.session.equipment.has(action) and not level.session.equipment[action]:
		standing.x = .08 if target.global_position.x > 0 else -.08
		if action == "fridge" and level.fridge.opened: standing = Vector3(-.12,.4,0)
	await aim(target.global_position, standing)
	return target

func use(action: String) -> void:
	var target := await aim_station(action)
	var actual := level.player.get_interactable()
	check(actual == target, "raycast reaches %s (hit %s)" % [action, actual.name if actual != null else "nothing"])
	await key(KEY_E)
	await wait_inspection()

func wait_inspection() -> void:
	for i in range(150):
		if not level.inspection.busy: return
		await physics_frame
	check(false, "equipment animation finishes within 2.5 seconds")

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

func customer_at_window() -> Dictionary:
	for customer in level.session.customers:
		if level.customer_action(int(customer.id)) != "": return customer
	return {}

func aim_customer() -> ShiftCustomerVisual:
	var customer := customer_at_window()
	check(not customer.is_empty(), "eligible customer reaches the window")
	if customer.is_empty(): return null
	var visual := level.npc_visuals.get(int(customer.id)) as ShiftCustomerVisual
	check(visual != null, "live customer has a 3D model")
	if visual == null: return null
	await aim(visual.global_position + Vector3.UP * 1.55, Vector3(0, .4, .13))
	check(level.player.get_interactable() == visual, "center ray reaches the actual customer")
	return visual

func proof(name: String, dimensions: Vector2i = Vector2i(1280, 720)) -> void:
	if screenshots.is_empty() or name in _shot_names: return
	var previous := root.size
	root.size = dimensions
	await shot(name)
	root.size = previous

func take_payment() -> int:
	await wait_for_counter()
	var visual := await aim_customer()
	if visual == null: return 0
	check(visual.get_prompt() == "[E] Принять заказ", "NPC offers the order from its body")
	await key(KEY_E)
	check(level.hud.panel.visible, "Russian dialogue opens from the NPC")
	check(level.hud._is_typing(), "customer dialogue starts word-by-word reveal")
	await key(KEY_SPACE)
	check(not level.hud._is_typing(), "Space reveals the complete order dialogue")
	var copy: String = level.hud._dialogue_copy.text if level.hud._dialogue_copy != null else ""
	check(not copy.is_empty() and "Всё верно?" not in copy and "·" not in copy and "•" not in copy, "spoken copy is free of technical separators")
	await proof("01-order-1920x1080", Vector2i(1920, 1080))
	check(not level.hud._action_panel.visible, "modal dialogue hides preparation prompts")
	await click("Подтвердить заказ")
	var id := int(level.session.cash.payment.get("order", 0))
	check(id > 0, "confirmation creates one unpaid order and cash operation")
	if id == 0: return 0
	var total := int(level.session.cash.payment.total)
	var before_revenue := int(level.session.stats.revenue)
	var before_till := level.session.cash.balance()
	check(find_button(level.hud.panel_content, "Ячейка") == null, "cash UI has no change denominations")
	check(level.save_manager.save_slot("manual", 2, true) == OK, "save pending payment")
	var before: Dictionary = level.capture_snapshot()
	check(level.save_manager.load_slot(1, "manual", 2), "restore pending payment from disk")
	check(JSON.stringify(level.capture_snapshot()) == JSON.stringify(before), "payment restore is exact")
	await key(KEY_ESCAPE)
	visual = await aim_customer()
	if visual == null: return 0
	check(visual.get_prompt() == "[E] Продолжить оплату", "same customer resumes pending payment")
	await key(KEY_E)
	await click("Принять оплату")
	check(level.session.order_by_id(id).paid and level.session.cash.payment.is_empty(), "one payment action settles the order")
	check(level.session.cash.balance() == before_till + total and int(level.session.stats.revenue) == before_revenue + total, "the till and revenue increase by the exact price once")
	check(not level.session.finalize_payment(true), "repeating payment does not charge again")
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

func roundtrip_work(label: String) -> void:
	var before := level.capture_snapshot()
	check(level.validate_snapshot(before), label + " is a valid save")
	check(level.save_manager.save_slot("manual", 1, true) == OK, label + " is written to disk")
	check(level.save_manager.load_slot(1, "manual", 1), label + " loads from disk")
	check(JSON.stringify(level.capture_snapshot()) == JSON.stringify(before), label + " restores exactly")

func phase() -> String:
	return str(level.session.preparation.current.get("handling", ""))

func prepare_filter(capture: bool = false) -> void:
	await aim_station("filter")
	if capture:
		var previous_size := root.size
		for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = resolution
			await frames(3)
			var panel_rect := level.hud._action_panel.get_global_rect()
			check(level.hud._action_panel.visible and panel_rect.end.y <= level.hud.control_hints.get_global_rect().position.y, "action panel sits above controls at " + str(resolution))
			check(not panel_rect.has_point(root.get_visible_rect().get_center()), "HUD leaves center reticle clear at " + str(resolution))
		root.size = previous_size
		await proof("02-task-hud-1280x720")
	check(not level.stations.machine.get_available_action().begins_with("[E]"), "brew button cannot start without the prepared filter")
	await use("filter")
	check(level.session.preparation.current.get("portafilter") == "in_hand" and level.accessories.filter.visible, "take the original filter into the camera hand")
	check(not level.machine_visual.portafilter.visible, "storage copy disappears when the filter is taken")
	if capture:
		await proof("03-filter-in-hand-1280x720")
		roundtrip_work("filter in hand")
	await use("grinder_fork")
	check(level.session.preparation.current.get("portafilter") == "in_grinder", "E seats the filter in the grinder fork")
	await use("beans")
	await use("grinder_button")
	check(level.session.preparation.current.get("running") == "grind" and not level.accessories.grounds.visible, "grind starts before grounds appear")
	check(not level.stations.grinder_fork.get_available_action().begins_with("[E]"), "running grinder keeps the filter seated")
	if capture: roundtrip_work("filter under the running grinder")
	await frames(46)
	check(level.accessories.grounds.visible, "ground coffee appears in the basket when grinding completes")
	if capture:
		var legacy := level.capture_snapshot()
		legacy.trade.preparation.erase("portafilter")
		check(level.apply_snapshot(legacy), "legacy progress loads without a stored filter position")
		check(level.session.preparation.current.get("portafilter") == "in_grinder" and level.accessories.grounds.visible, "legacy ground coffee is recovered in the grinder without another dose")
	await aim_station("grinder_fork")
	if capture: await proof("04-filter-in-grinder-1920x1080", Vector2i(1920, 1080))
	await use("grinder_fork")
	check(level.session.preparation.current.get("portafilter") == "in_hand", "E removes the dosed filter")
	await use("tamping_mat")
	check(level.session.preparation.current.get("portafilter") == "on_tamping_mat", "E places filter on the actual mat")
	await use("dose")
	check(level.session.preparation.current.get("tamper_held", false), "E picks up the separate tamper")
	await use("tamping_mat")
	check(level.accessories._animation == "dose" and level.session.preparation.current.get("portafilter") == "on_tamping_mat", "tamping animates while the basket stays seated")
	if capture:
		await aim(level.accessories.filter.get_node("GroupLockOrigin").global_position, Vector3(.06, .4, -1.09))
		await frames(11)
		await proof("05-tamping-1920x1080", Vector2i(1920, 1080))
	await frames(42)
	await use("tamping_mat")
	await use("group")
	check(level.accessories._animation == "install", "group E starts the locking animation")
	await frames(42)
	check(level.machine_visual.portafilter.visible and not level.accessories.filter.visible, "the installed filter is the only visible copy")
	check(level.session.preparation.current.get("portafilter") == "installed", "preparation records the installed filter")

func cook(id: int, index: int, capture: bool = false) -> void:
	await select_from_sidebar(id, index)
	await prepare_filter(capture)
	var order := level.session.order_by_id(id)
	var sequence := level.session.catalog.steps(order.items[index])
	var drink: String = level.session.catalog.recipes[order.items[index].recipe].drink
	var mapping := {"extract":"machine", "stop":"machine", "water":"water", "milk":"milk", "pitcher":"pitcher",
		"steam":"steam", "stop_steam":"steam", "pour":"pitcher", "sugar":"sugar", "syrup":"syrup"}
	await use("cups")
	check(phase() == "cup_held" and level.held.has_node("HeldEmptyCup") and not level.preparation_visual.has_node("CupUnderGroup"), "empty cup exists only in the hand after pickup")
	if capture:
		await proof("06-empty-cup-in-hand-1280x720")
		roundtrip_work("empty cup in hand")
	await use("cup_tray")
	check(phase() == "cup_in_machine" and level.preparation_visual.has_node("CupUnderGroup"), "E places the cup under the actual spout")
	for step in sequence.slice(sequence.find("extract"), sequence.find("lid")):
		if step == "milk" and not level.fridge.opened:
			await use("fridge")
			await frames(36)
		if step == "stop":
			check(level.hud.extraction_timer.visible and "ЭКСТРАКЦИЯ" in level.hud.extraction_timer.text, "dedicated extraction stopwatch is visible")
			if capture:
				roundtrip_work("running extraction")
				await key(KEY_ESCAPE)
				var paused_at := float(level.session.preparation.current.elapsed)
				await frames(12)
				check(is_equal_approx(paused_at, float(level.session.preparation.current.elapsed)), "pause freezes extraction time")
				await click("Вернуться в игру", level.main_menu)
			level.session.tick(8.8)
			if capture:
				await aim(level.machine_visual.cup_base() + Vector3.UP * .13, Vector3(-.06, .4, -1.28))
				await proof("07-extraction-1920x1080", Vector2i(1920, 1080))
		if step == "water":
			await use("cup_tray")
			check(phase() == "water_held", "espresso is picked up to move to the hot water tap")
			await use("water_tray")
			check(phase() == "cup_at_water_tap", "cup rests under the actual hot water tap")
		if step == "stop_steam":
			check(level.hud.extraction_timer.visible and "ПАР" in level.hud.extraction_timer.text, "milk has a recipe-specific stopwatch")
			level.session.tick(4.5 if drink == "cappuccino" else 2.5)
		await use(str(mapping[step]))
		if step == "water": await frames(42)
		if step == "pour": await frames(42)
		if step in ["water", "pour"] or (step == "stop" and drink == "espresso"):
			await use("water_tray" if step == "water" else "cup_tray")
			check(phase() == "cup_full_held" and level.held.has_node("HeldFilledCup"), "filled cup appears in hand after pickup")
			if capture: roundtrip_work("filled cup in hand")
			await use("countertop")
			check(phase() == "cup_on_counter" and level.preparation_visual.has_node("CupOnCounter"), "filled cup is physically placed on the worktop")
			if capture: await proof("08-filled-cup-on-worktop-1280x720")
		check(level.validate_snapshot(level.capture_snapshot()), "save valid after " + str(step))
	await use("lids")
	check(phase() == "lid_held" and level.held.has_node("HeldLid"), "lid appears in hand before closing")
	if capture:
		await aim_station("countertop")
		await proof("09-lid-in-hand-1920x1080", Vector2i(1920, 1080))
		roundtrip_work("lid in hand")
	var contents: Dictionary = level.session.preparation.current.consumed.duplicate()
	await use("countertop")
	check(level.new_assets.is_playing("lid"), "attaching the lid moves the hand and lid")
	await frames(42)
	check(phase() == "lid_attached" and level.preparation_visual.has_node("CappedCupOnCounter"), "capped cup remains on the counter")
	check(not level.stations.ready.get_available_action().begins_with("[E]"), "capping alone cannot send the cup to the rack")
	check(level.stations.countertop.get_available_action() == "[E] Взять стакан", "closed cup offers the pickup action")
	if capture:
		roundtrip_work("capped cup on worktop")
		var modern := level.capture_snapshot()
		var legacy := modern.duplicate(true)
		legacy.trade.preparation.erase("portafilter")
		legacy.trade.preparation.erase("handling")
		check(level.apply_snapshot(legacy) and phase() == "capped_held", "older finished drink resumes in hand")
		check(level.apply_snapshot(modern) and phase() == "lid_attached", "current save keeps the capped cup on the worktop")
	await use("countertop")
	check(phase() == "capped_held" and level.held.has_node("HeldCappedCup"), "capped cup can be physically picked up")
	check(not level.preparation_visual.has_node("CappedCupOnCounter"), "pickup removes the original worktop prop")
	for key_name in contents:
		check(level.session.preparation.current.consumed[key_name] == contents[key_name], "capping preserves contents " + key_name)
	if capture:
		await proof("10-capped-cup-in-hand-1280x720")
		roundtrip_work("capped cup in hand")
	await use("ready")
	check(level.session.order_by_id(id).items[index].ready, "ready cup is placed on the serving rack")
	check(level.session.order_by_id(id).status != "served", "rack placement never serves the customer")
	check(not level.hud.extraction_timer.visible, "stopwatch hides after operation")
	check(level.session.order_by_id(id).items[index].cup.quality.good, "recipe quality stays in range: " + drink)
	if capture: await proof("11-ready-order-1920x1080", Vector2i(1920, 1080))

func serve(id: int) -> void:
	var order := level.session.order_by_id(id)
	if order.items.size() > 1:
		check(level.hud.call_buttons[id].disabled, "multi-order requires a holder before calling")
		var stock := int(level.session.inventory.stock.carriers)
		await use("carrier")
		await frames(42)
		check(order.carrier and int(level.session.inventory.stock.carriers) == stock - 1, "physical E takes one cardboard holder from stock")
		for i in range(order.items.size()):
			var cup := level.drinks_root.get_node("Cup_%d_%d" % [id, i]) as Node3D
			await aim(cup.global_position + Vector3.UP * .061, Vector3(0, .4, cup.global_position.z))
			var target := level.player.get_interactable() as ShiftWorkstation
			check(target != null and target.order_id == id and target.item_index == i and target.action == "pack_cup", "aim identifies the exact finished cup for packing")
			await key(KEY_E)
			check(i in order.packed, "E places selected cup in the cardboard holder")
			await frames(42)
	await key(KEY_TAB)
	var call: Button = level.hud.call_buttons.get(id)
	check(call != null and not call.disabled, "ready order can be called from sidebar")
	if call != null and not call.disabled: call.pressed.emit()
	await frames()
	level.session.tick(12)
	await frames()
	var visual := await aim_customer()
	if visual == null: return
	check(visual.get_prompt() == "[E] Выдать заказ", "called customer's body offers order handover")
	await key(KEY_E)
	if level.hud._is_typing(): await key(KEY_SPACE)
	await click("Передать через окно")
	check(level.session.order_by_id(id).status == "called" and level.session.customer_by_id(visual.customer_id).state == "pickup", "customer waits until the drink reaches the window")
	check(is_instance_valid(level.new_assets._handover), "handover moves the original cup model toward the customer")
	check(not level.drinks_root.has_node("Cup_%d_0" % id), "no second copy remains on the rack during handover")
	await frames(19)
	await proof("12-handover-1920x1080", Vector2i(1920, 1080))
	await frames(42)
	check(level.session.order_by_id(id).status == "served", "handover serves the appropriate customer once")
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
	if screenshots.is_empty(): root.size = Vector2i(640, 360)
	await click("Настройки", level.main_menu)
	check(find_button(level.main_menu, "Назад") != null, "settings screen remains available")
	await click("Назад", level.main_menu)
	await click("Новая игра", level.main_menu)
	await click("Начать новую игру", level.main_menu)
	check(level._active and level.player.position.y > .3, "new career starts inside prepared trailer")
	check(not level.session.shift_open and not level.session.snapshot().prologue_completed, "prototype does not award prologue achievement")
	check(level.validate_snapshot(level.capture_snapshot()), "initial new-career snapshot valid")
	for device in ["machine", "grinder", "fridge", "cash"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("window")
	await frames(54)
	check(level.session.window_open and absf(level.shutter.rotation.z-deg_to_rad(77)) < .001, "original hatch opens to its +77 degree endpoint")
	await use("shift")
	await click("Открыть смену")
	check(level.session.shift_open, "sign starts shift separately from the window")
	level.session.catalog.config.customers.interval_seconds = 99999
	var catalog := level.session.catalog
	var fixture := [
		[{"recipe":"americano_standard", "sugar":false, "syrup":false}],
		[{"recipe":"espresso_small", "sugar":true, "syrup":false}],
		[{"recipe":"cappuccino_large", "sugar":true, "syrup":true}, {"recipe":"latte_standard", "sugar":false, "syrup":false}]
	]
	var dialogue := CustomerDialogue.order_request(catalog.config.customers.profiles[1].greeting, fixture[2], catalog)
	check(dialogue == "Добрый день! Можно большой капучино с сахаром и ванильным сиропом и стандартный латте?", "natural dialogue retains greeting and inflects sizes and extras")
	for visit in range(fixture.size()):
		var customer := level.session.spawn_customer()
		check(not customer.is_empty(), "customer spawns through the shift queue")
		if customer.is_empty(): break
		customer.items = fixture[visit]
		await wait_for_counter()
		if visit == 0:
			var visual := await aim_customer()
			if visual == null: quit(1); return
			await aim(visual.global_position + Vector3.UP * 1.65, Vector3(0, .4, 0))
			check(level.player.get_interactable() == visual, "customer head and body are both targetable")
			await aim(Vector3(1.9, 1.55, 0), Vector3(0, .4, 2.1))
			check(level.player.get_interactable() != visual, "solid shell occludes the customer from the rear")
			await aim(Vector3(1.9, 1.55, 0), Vector3(5.2, .02, 0))
			check(level.player.get_interactable() != visual, "customer cannot be targeted beyond interaction reach")
			level.session.window_open = false
			level.trailer.shell.set_hatch_open(false, false)
			await aim(Vector3(1.9, 1.55, 0), Vector3(0, .4, .1))
			check(level.player.get_interactable() != visual and visual.get_prompt().is_empty(), "closed hatch blocks customer interaction")
			await key(KEY_E)
			check(not level.hud.panel.visible, "E on a closed hatch never opens customer dialogue")
			level.session.window_open = true
			level.trailer.shell.set_hatch_open(true, false)
		var id := await take_payment()
		if id == 0: quit(1); return
		if visit == 1:
			await use("filter")
			await use("bin")
			check(level.session.preparation.current.is_empty() and level.session.can_begin_drink(), "discard allows restarting the same paid drink")
		for index in range(fixture[visit].size()): await cook(id, index, visit == 0)
		await serve(id)
	await use("shift")
	await click("Закрыть смену")
	check(not level.session.shift_open and level.session.stats.completed == 3, "full three-customer shift completed")
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
	root.push_input(pointer, true)
	check(level.player.pitch < old_pitch, "viewport mouse motion updates pitch safely")
	level.save_manager.autosave_enabled = false
	level.queue_free()
	await frames(3)
	print("DEV03 INTEGRATION: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
