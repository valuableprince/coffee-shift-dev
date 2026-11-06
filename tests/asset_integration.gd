extends "res://tests/dev03_integration.gd"
## Runs the real first-shift scene, E input, camera rays and existing recipes.

func shot(name: String) -> void:
	if screenshots.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_width() >= 1280 and image.get_height() >= 720, "real gameplay capture meets resolution")
	check(image.save_png(screenshots.path_join(name + ".png")) == OK, "PNG from running Godot: " + name)
	_shot_names.append(name)

func view(point: Vector3, standing: Vector3, fov: float = 60) -> void:
	level.player.camera.fov = fov
	await aim(point, standing)

func bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		var part: AABB = mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box

func no_duplicate_filter() -> void:
	for mesh in level.machine_visual.get_node("Model").find_children("Portafilter_Left_*", "MeshInstance3D", true, false):
		check(not mesh.visible, "embedded old working filter stays hidden: " + mesh.name)
	check(level.machine_visual.portafilter.visible != level.accessories.filter.visible, "exactly one working filter is visible")

func run() -> void:
	root.size = Vector2i(1280,720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	check(level.new_game(1), "new game starts through existing career lifecycle")
	var a := level.accessories
	for entry in [[a.filter, "portafilter", 22, 113320], [a.tamper, "tamper", 13, 131028], [a.pitcher, "milk_pitcher", 9, 109836]]:
		var model: Node3D = entry[0]
		var resource: String = model.get_node("Model").scene_file_path
		check(resource.begins_with("res://assets/models/" + str(entry[1])) and resource.ends_with(".glb"), "uses original GLB: " + str(entry[1]))
		check(FileAccess.get_file_as_bytes(resource).size() == entry[3], "original binary size preserved")
		check(model.get_node("Model").find_children("*", "MeshInstance3D", true, false).size() == entry[2], "all imported mesh parts present")
		check(model.global_basis.get_scale().is_equal_approx(Vector3.ONE), "accessory remains metre scale 1:1")
		check(model.has_node("HandGrip"), "source HandGrip retained")
	check(is_equal_approx(a.tamper.get_node("PressContact").global_position.y, bounds(level.trailer.get_node("TampingMat")).end.y), "tamper sole touches mat geometry")
	check(is_equal_approx(a.pitcher.get_node("BaseContact").global_position.y, 1.30), "pitcher foot touches existing worktop")
	check(a.tamper.global_basis.y.dot(Vector3.UP) > .999, "tamper stands upright")
	var tamper_box := bounds(a.tamper)
	var pitcher_box := bounds(a.pitcher)
	for box in [tamper_box, pitcher_box]:
		check(box.position.x >= .475 and box.end.x < 1.205 and box.position.z >= -1.95 and box.end.z <= -.85, "whole accessory footprint stays over existing worktop")
	check(not tamper_box.intersects(pitcher_box), "tamper and pitcher do not overlap")
	check(not tamper_box.intersects(bounds(level.grinder_visual)), "tamper clears original grinder")
	check(not pitcher_box.intersects(bounds(level.grinder_visual)), "pitcher clears original grinder")
	for mesh in level.machine_visual.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		check(not pitcher_box.intersects(box), "countertop pitcher clears machine part: " + mesh.name)
	print("ACCESSORY BOUNDS: ", tamper_box, " / ", pitcher_box)
	check(a.pitcher.has_node("PourSpout") and a.pitcher.has_node("SteamWandTarget"), "pitcher source markers retained")
	check(level.trailer.get_node_or_null("Pitcher") == null, "old primitive countertop pitcher removed")
	for station in level.stations.values():
		check(station.find_children("*", "Label3D", true, false).is_empty(), "no equipment nameplates")
	await view(Vector3(.73,1.52,-1.47), Vector3(-.10,.4,-1.46), 65)
	await shot("01-work-area")
	await view(Vector3(.69,1.56,-1.60), Vector3(-.06,.4,-1.64), 42)
	await shot("02-portafilter-installed")
	no_duplicate_filter()
	var idle := level.session.snapshot()
	await use("filter")
	check(a.inspected == "filter" and a.filter.visible, "real E removes filter into hand")
	check(a.filter.get_node("HandGrip").global_position.distance_to(a.grip.global_position) < .0001, "held filter uses source grip")
	no_duplicate_filter()
	await view(Vector3(.69,1.56,-1.60), Vector3(-.06,.4,-1.64), 65)
	await shot("03-portafilter-removed")
	await use("filter")
	check(a.inspected == "", "E returns filter to group")
	no_duplicate_filter()
	await view(Vector3(.59,1.37,-.94), Vector3(0,.4,-.77), 28)
	await shot("04-tamper-on-counter")
	await use("dose")
	check(a.inspected == "dose", "E takes original tamper")
	check(a.tamper.get_node("HandGrip").global_position.distance_to(a.grip.global_position) < .0001, "tamper held by HandGrip")
	await use("dose")
	await view(Vector3(.60,1.36,-1.17), Vector3(-.03,.4,-1.39), 29)
	await shot("05-milk-pitcher")
	await use("pitcher")
	check(a.inspected == "pitcher", "E takes original pitcher")
	check(a.pitcher.get_node("HandGrip").global_position.distance_to(a.grip.global_position) < .0001, "pitcher held by handle grip")
	await view(Vector3(.72,1.55,-1.45), Vector3(-.03,.4,-1.40), 65)
	check(level.hud.reticle.is_visible_in_tree(), "permanent center dot visible with item held")
	check(level.hud.reticle.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()), "dot stays centered")
	await shot("06-first-person-held-pitcher")
	await use("pitcher")
	var after := level.session.snapshot()
	check(after.inventory == idle.inventory and after.till == idle.till and after.orders == idle.orders and after.preparation.is_empty(), "idle pick up/return never changes money, stock, orders or recipes")
	await view(Vector3(0,2.8,-2), Vector3(0,.4,0))
	check(level.hud.hint.text.is_empty(), "looking away clears contextual item text")
	check(level.hud.reticle.is_visible_in_tree(), "dot remains while looking away")
	await view(Vector3(.73,1.52,-1.47), Vector3(-.10,.4,-1.46), 65)
	await shot("07-work-area-cozy")
	level.player.camera.fov = 75
	for device in ["machine", "grinder", "fridge", "cash"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("window")
	await frames(42)
	await use("shift")
	await click("Открыть смену")
	level.session.catalog.config.customers.interval_seconds = 99999
	level.session.catalog.config.customers.profiles = [{"name":"Гость", "color":"536f75", "preferred":["cappuccino_standard"], "greeting":"Здравствуйте"}]
	level.session.spawn_customer()
	var id := await take_payment()
	if id != 0:
		await select_from_sidebar(id, 0)
		for action in ["beans", "grinder", "filter"]: await use(action)
		no_duplicate_filter()
		await use("dose")
		check(level.session.preparation.next_step(level.session.catalog) == "install", "original combined dosing/tamping step advances once")
		check(a._animation == "dose", "source tamper presents existing tamping action")
		await frames(45)
		check(is_equal_approx(a.tamper.get_node("PressContact").global_position.y, bounds(level.trailer.get_node("TampingMat")).end.y), "tamper returns upright to mat geometry after pressing")
		await use("machine")
		no_duplicate_filter()
		await use("cups")
		await use("machine")
		level.session.tick(9)
		await use("machine")
		if not level.fridge.opened:
			await use("fridge")
		await frames(35)
		await use("milk")
		check(level.session.preparation.next_step(level.session.catalog) == "pitcher", "existing fridge milk step preserved")
		await use("pitcher")
		check(a.milk.visible, "existing consumed milk appears inside original hollow pitcher")
		await use("steam")
		check(a.pitcher.get_node("SteamWandTarget").global_position.distance_to(level.machine_visual.steam_tip()) < .0001, "source SteamWandTarget aligns to real nozzle")
		check(a.pitcher.get_node("BaseContact").global_position.y > 1.40, "steaming pitcher clears tray and countertop")
		await view(Vector3(.53,1.49,-1.24), Vector3(-.03,.4,-1.08), 40)
		await shot("08-existing-milk-steaming")
		level.player.camera.fov = 75
		level.session.tick(4.5)
		await use("steam")
		check(level.session.preparation.next_step(level.session.catalog) == "pour", "existing steam stop preserved")
		await use("pitcher")
		check(a._animation == "pour", "PourSpout presents existing milk pour")
		await frames(45)
		for action in ["lids", "ready"]: await use(action)
		await serve(id)
	check(level.session.stats.completed == 1, "original cappuccino cycle, payment and serving complete")
	check(level.validate_snapshot(level.capture_snapshot()), "existing save schema remains valid")
	level.save_manager.autosave_enabled = false
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	print("ASSET INTEGRATION: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
