extends "res://tests/dev03_integration.gd"
## Real AnimationPlayer time, physical E input, disk saves, two shifts and HUD QA.
var completions: Array = []

func capture(name: String) -> void:
	if screenshots == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	check(frame.get_size() == root.size,"screenshot uses complete native window: " + name)
	check(frame.save_png(screenshots.path_join(name + ".png")) == OK,"actual Godot viewport: " + name)

func begin_inspection(id: String) -> void:
	var target: Node3D = level.stations[id]
	await aim(target.global_position,Vector3(0,.4,clampf(target.global_position.z,-2.1,2.0)))
	check(level.player.get_interactable() == target,"physical ray reaches " + id)
	check(target.get_prompt().ends_with("[E] Осмотреть"),"uninspected device offers E inspection: " + id)
	await key(KEY_E)
	check(level.inspection.busy and not level.player.controls_enabled,"inspection locks movement: " + id)
	check(not level.session.equipment[id],"start never completes task: " + id)

func inspect(id: String, photograph: bool = false) -> void:
	var money := JSON.stringify(level.session.cash.till)
	await begin_inspection(id)
	if photograph:
		await create_timer(.40).timeout
		check(level.inspection.hand.visible and level.inspection.animation.is_playing(),"real clip visible: " + id)
		await capture("animation-" + id)
	# A held/repeated E cannot start another transaction, even on another device.
	await key(KEY_E)
	level.interact_station(level.stations.cash if id != "cash" else level.stations.grinder)
	check(level.inspection.device == id,"repeat interaction cannot replace active clip")
	await wait_inspection()
	check(level.session.equipment_status(id) == "COMPLETED","natural completion marks " + id)
	check(level.hud.tasks.rows[id].completed,"HUD observes completed " + id)
	check(level.player.controls_enabled and level.player.mouse_captured,"controls restored after " + id)
	check(not level.inspection.hand.visible,"inspection hand holstered after " + id)
	check(JSON.stringify(level.session.cash.till) == money and level.session.cash.payment.is_empty(),"inspection creates no transaction")

func check_layout() -> void:
	var rect := level.hud.tasks.get_global_rect()
	check(rect.position.x > root.get_visible_rect().size.x * .65,"tasks stay to right of crosshair")
	check(rect.position.y > level.hud.status.get_global_rect().end.y,"tasks clear top HUD")
	check(root.get_visible_rect().encloses(rect),"tasks fit viewport " + str(root.size))
	check(level.hud.orders_panel.get_theme_stylebox("panel") is StyleBoxEmpty,"sidebar has no background or border")
	check(not rect.intersects(level.hud.reticle.hint.get_global_rect()),"tasks clear crosshair context hint")
	level._panel("Покупатель", "Добрый день! Один капучино, пожалуйста.",[],true)
	await frames(4)
	check(not rect.intersects(level.hud.panel.get_global_rect()),"tasks clear actual dialogue panel")
	await capture("hud-dialogue-%d" % root.size.x)
	level.hud.close_panel()

func run() -> void:
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	check(level.new_game(1),"new isolated test career")
	level.inspection.finished.connect(func(id: String, done: bool) -> void:
		if done: completions.append(id))
	for resolution in [Vector2i(1920,1080),Vector2i(1366,768)]:
		root.size = resolution
		await frames(5)
		await check_layout()
		await capture("hud-pending-%d" % resolution.x)
	root.size = Vector2i(1920,1080)
	await frames(4)
	check(not level.session.open_shift(),"four inspections gate opening")
	await inspect("machine",true)
	await frames(24)
	check(is_equal_approx(level.hud.tasks.rows.machine.progress,1),"completed task has full drawn strike")
	check(not level.hud.tasks.rows.grinder.completed and level.hud.tasks.visible,"pending tasks and completed task remain visible")
	await capture("hud-one-completed")
	check(completions.count("machine") == 1,"exactly one completion event for machine")
	await inspect("grinder",true)
	check(level.save_manager.save_slot("manual",1,true) == OK,"partial preparation saved to disk")
	var directory := level.save_manager.directory
	var saved := level.capture_snapshot()
	await inspect("fridge",true)
	check(not level.fridge.opened and not level.fridge.moving,"fridge inspection closes the real door")
	check(level.save_manager.load_slot(1,"manual",1),"disk reload restores partial progress")
	check(level.session.equipment.machine and level.session.equipment.grinder and not level.session.equipment.fridge,"only completed saved devices restored")
	check(level.hud.tasks.rows.machine.progress == 1 and level.hud.tasks.rows.fridge.progress == 0,"load immediately reconstructs strikes")
	# Save during a moving fridge door: no transient open state and no false completion.
	await begin_inspection("fridge")
	await create_timer(.55).timeout
	check(level.save_manager.save_slot("manual",2,true) == OK,"mid-animation save remains valid")
	check(not level.capture_snapshot().world.fridge_opened and not level.capture_snapshot().trade.equipment.fridge,"transient pose is excluded from saves")
	check(level.save_manager.load_slot(1,"manual",2),"load cancels in-flight animation")
	check(not level.inspection.busy and not level.session.equipment.fridge and level.player.controls_enabled,"load restores control without completing animation")
	await frames(100)
	check(not level.session.equipment.fridge,"cancelled callback never completes later")
	# An unchecked device can already be open from the previous shift / old save.
	level.fridge.restore_opened(true)
	await begin_inspection("fridge")
	check(is_equal_approx(level.fridge.hinge.rotation.y,-ShiftFridge.OPEN_ANGLE),"already-open fridge keeps its starting angle")
	level.inspection.cancel()
	check(level.fridge.opened and not level.fridge.moving,"cancel restores originally open door")
	level.fridge.restore_opened(false)
	# Escape, F6, focus loss and an external AnimationPlayer stop cancel safely.
	for mode in ["pause","saves","focus","stop"]:
		await begin_inspection("cash")
		match mode:
			"pause": await key(KEY_ESCAPE)
			"saves": await key(KEY_F6)
			"focus": level._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"stop":
				level.inspection.animation.stop()
				await process_frame
				await process_frame
				await frames(3)
		check(not level.inspection.busy and not level.session.equipment.cash,"interruption rolls back: " + mode)
		if mode != "stop": check(not level.player.controls_enabled,"menu retains input lock: " + mode)
		level.resume_game()
		check(level.player.controls_enabled,"resume restores controls: " + mode)
	print("DEV05: interruption checks complete")
	# Fresh scene uses the actual on-disk save, not live in-memory state.
	level.music.stop_all()
	level.audio.stop_all()
	level.free()
	await frames(3)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	level.save_manager.directory = directory
	check(level.save_manager.load_slot(1,"manual",1),"fresh scene loads partial preparation")
	level.resume_game()
	check(level.session.equipment.machine and not level.session.equipment.cash,"progress survives scene restart")
	print("DEV05: fresh-scene load complete")
	await inspect("cash",true)
	check(not level.new_assets.register.drawer_open,"cash inspection presses keys without opening drawer")
	await use("cash")
	check(level.new_assets.register.drawer_open,"checked cash retains normal drawer operation")
	await use("cash")
	await inspect("fridge")
	await frames(26)
	await capture("hud-all-completed")
	await frames(65)
	check(level.hud.tasks.collapsed and not level.hud.tasks.visible,"all four strikes automatically fold away")
	await capture("hud-collapsed")
	await use("fridge")
	await frames(32)
	check(level.fridge.opened and level.fridge.milk_accessible(),"checked fridge opens normally for milk")
	await use("fridge")
	await frames(32)
	check(not level.session.prepare_equipment("machine"),"repeat completion rejected")
	await use("window")
	await frames(50)
	check(level.session.open_shift(),"four completed inspections permit first shift")
	print("DEV05: first shift opened")
	# Complete the existing paid recipe/payment/serving path during shift one.
	level.session.catalog.config.customers.interval_seconds = 99999
	level.session.catalog.config.customers.profiles = [{"name":"Гость","color":"536f75","preferred":["espresso_small"],"greeting":"Здравствуйте"}]
	level.session.spawn_customer()
	var id := await take_payment()
	if id != 0:
		await cook(id,0)
		await serve(id)
	check(level.session.close_shift(),"first serviced shift closes")
	check(not level.session.equipment_ready() and level.session.equipment.values().count(false) == 4,"next shift resets all four devices")
	check(not level.session.open_shift(),"second shift is gated again")
	check(level.hud.tasks.visible and not level.hud.tasks.collapsed,"reset shows task list again")
	await frames(5)
	await capture("hud-next-shift")
	# Different order on the next shift exercises independent completion.
	for device in ["cash","fridge","grinder","machine"]: await inspect(device)
	check(level.session.open_shift(),"arbitrary order permits second shift")
	check(level.session.close_shift() and level.session.history.size() == 2,"two consecutive shifts complete")
	check(level.validate_snapshot(level.capture_snapshot()),"final snapshot passes existing validator")
	check(level.apply_snapshot(saved),"pre-DEV05 schema-2 shape stays compatible")
	check(level.player.controls_enabled,"no stranded control lock")
	level.audio.stop_all()
	level.music.stop_all()
	level.free()
	await frames(4)
	print("DEV05 INSPECTION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
