extends "res://tests/dev03_integration.gd"
## Imported geometry, real camera rays and one complete existing recipe.

func shot(name: String) -> void:
	if screenshots.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await frames(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_jpg(screenshots.path_join(name + ".jpg"), .94) == OK, "real Godot viewport " + name)
	_shot_names.append(name)

func run() -> void:
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	level.new_game(1)
	var bytes := FileAccess.get_file_as_bytes("res://assets/models/espresso_machine/coffee_shift_espresso_machine.glb")
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	check(bytes.size() == 123852 and digest.finish().hex_encode() == "23aef64bab1d8b44e800c32c608379002428a13533d000f93b1211ca356052fa", "supplied espresso GLB is byte-for-byte preserved")
	var machine := level.machine_visual
	check(machine.get_node("Model").find_children("*", "MeshInstance3D", true, false).size() == 147, "all supplied machine parts imported")
	check(is_equal_approx(machine.global_position.y, 1.30), "machine feet sit on existing worktop")
	check((machine.global_basis * Vector3(0,0,1)).normalized().dot(Vector3.LEFT) > .99, "machine front faces aisle")
	check(machine.spout().y - machine.cup_base().y > .115, "largest in-progress cup clears real spouts")
	check(level.grinder_visual.global_position.is_equal_approx(Vector3(.83,1.48,-1.0)), "existing grinder position retained")
	check(level.grinder_visual.find_children("*", "MeshInstance3D", true, false).size() == 34, "existing grinder, including revised beans, retained")
	for control in ["power", "brew_left", "brew_right", "group"]:
		var point := machine.control_point(control)
		await aim(point, Vector3(0,.4,point.z))
		check(level.player.get_interactable() == level.stations.machine, "physical machine control reaches existing handler: " + control)
		check(level.hud.hint.text.begins_with("Кофемашина"), "existing contextual name at " + control)
		if control == "power":
			await key(KEY_E)
			await wait_inspection()
			check(level.session.equipment.machine, "model power control prepares existing equipment")
	for action in ["filter", "water", "steam"]:
		await aim(level.stations[action].global_position, Vector3(0,.4,level.stations[action].global_position.z))
		check(level.player.get_interactable() == level.stations[action], "physical model target reachable: " + action)
	for station in level.stations.values():
		check(station.find_children("*", "Label3D", true, false).is_empty(), "equipment keeps contextual-only labels: " + station.action)
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		await frames(5)
		check(level.hud.reticle.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()), "existing dot remains centered at " + str(resolution))
		check(level.hud.orders_panel.get_global_rect().end.y <= root.get_visible_rect().end.y - 55, "sidebar leaves control hints clear")
		check(level.hud.orders_panel.size.y < 300, "preparation sidebar follows content without empty padding")
		await aim(Vector3(.79,1.61,-1.39), Vector3(-.08,.4,-1.37))
		await shot("01-countertop-" + str(resolution.x))
	await aim(Vector3(.79,1.64,-1.36), Vector3(-.08,.4,-1.37))
	await shot("02-countertop")
	for device in ["grinder", "fridge", "cash"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("window")
	await frames(42)
	await use("shift")
	await click("Открыть смену")
	level.session.catalog.config.customers.interval_seconds = 99999
	level.session.catalog.config.customers.profiles = [{"name":"Гость", "color":"536f75", "preferred":["espresso_small"], "greeting":"Здравствуйте"}]
	level.session.spawn_customer()
	var id := await take_payment()
	if id != 0:
		await select_from_sidebar(id, 0)
		for action in ["beans", "grinder", "filter", "dose"]: await use(action)
		check(not machine.find_child("Portafilter_Left_Basket",true,false).visible, "taking model portafilter removes it from group")
		await use("machine")
		check(machine.portafilter.visible and not machine.find_child("Portafilter_Left_Basket",true,false).visible, "installation returns separate imported portafilter without source overlap")
		await use("cups")
		await use("machine")
		check(level.session.preparation.current.running == "extract", "model button starts existing extraction")
		level.session.tick(9)
		await aim(Vector3(.79,1.61,-1.39),Vector3(-.08,.4,-1.37))
		await shot("03-extraction-both-models")
		await use("machine")
		for action in ["lids", "ready"]: await use(action)
		await serve(id)
	check(level.session.stats.completed == 1, "model integration preserves payment, preparation and handover")
	await use("shift")
	await click("Закрыть смену")
	check(not level.session.shift_open, "existing shift closes normally")
	level.save_manager.autosave_enabled = false
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	print("ESPRESSO INTEGRATION: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
