extends "res://tests/asset_integration.gd"
## The real game camera and viewport, same poses before and after visual changes.
const OVERVIEW_TARGET := Vector3(.73, 1.52, -1.47)
const OVERVIEW_STAND := Vector3(-.10, .4, -1.46)
var baseline := false
var metrics: Dictionary = {}

func shot(name: String) -> void:
	if name in ["05-text-order", "06-cash-payment", "10-handover"]: return
	await super.shot(name)

func measure_overview() -> Dictionary:
	await frames(12)
	var times: Array[float] = []
	for i in range(24):
		var start := Time.get_ticks_usec()
		await process_frame
		times.append(float(Time.get_ticks_usec() - start) / 1000)
	times.sort()
	return {"median_frame_ms": times[times.size()/2], "p95_frame_ms": times[22],
		"camera_transform": str(level.player.camera.global_transform), "fov": level.player.camera.fov,
		"panel_rect": str(level.hud.orders_panel.get_global_rect()),
		"panel_area": level.hud.orders_panel.size.x * level.hud.orders_panel.size.y,
		"guide_lines": level.hud.guide.get_line_count()}

func run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	check(level.new_game(1), "existing new game starts")
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		await view(OVERVIEW_TARGET, OVERVIEW_STAND, 65)
		await frames(5)
		metrics[str(resolution.x)] = await measure_overview()
		await shot(("00-before-work-area-" if baseline else "01-after-work-area-") + str(resolution.x))
	if not baseline:
		await check_polish()
	var output := screenshots.path_join("before-metrics.json" if baseline else "after-metrics.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(metrics, "\t"))
	level.save_manager.autosave_enabled = false
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	print("VISUAL POLISH %s: %d checks; %d failures" % ["BASELINE" if baseline else "AFTER", checks, failures])
	quit(0 if failures == 0 else 1)

func check_polish() -> void:
	var a := level.accessories
	check(level.player.find_children("*", "RayCast3D", true, false).size() == 1, "original single RayCast retained")
	var mat_box := bounds(level.trailer.get_node("TampingMat"))
	check(is_equal_approx(mat_box.position.y, 1.3), "mat underside rests on tabletop")
	check(is_equal_approx(mat_box.end.y - mat_box.position.y, .024), "simple raised mat has 24 mm thickness")
	check(is_equal_approx(a.tamper.get_node("PressContact").global_position.y, mat_box.end.y), "tamper contacts raised rubber top")
	check(a.tamper.global_basis.y.dot(Vector3.UP) > .999, "tamper remains upright")
	check(is_equal_approx(a.pitcher.get_node("BaseContact").global_position.y, 1.30), "pitcher rests on table")
	var pitcher_box := bounds(a.pitcher)
	check(pitcher_box.position.x > .475 and pitcher_box.end.x < 1.205 and pitcher_box.position.z > -1.95 and pitcher_box.end.z < -.85, "pitcher footprint stays over worktop")
	check(not pitcher_box.intersects(bounds(a.tamper)), "accessories do not overlap")
	check(not pitcher_box.intersects(bounds(level.grinder_visual)), "pitcher clears grinder")
	for mesh in level.machine_visual.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree():
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			check(not pitcher_box.intersects(box), "pitcher clears machine: " + mesh.name)
	no_duplicate_filter()
	check(not level.trailer.get_node("PortableWorkLight").shadow_enabled, "overhead lamp no longer casts duplicate point shadows")
	check(level.find_children("*", "Light3D", true, false).size() == 8, "one daylight, original workspace/fridge, two worktop and three street sources; no duplicates")
	var task_lights := level.trailer.get_children().filter(func(node: Node) -> bool: return node is OmniLight3D and node.name != "PortableWorkLight")
	check(task_lights.size() == 2, "two local lights mounted by working surfaces")
	for task in task_lights:
		check(not task.shadow_enabled and task.omni_range <= 2.0 and task.light_energy <= .3, "worktop fill stays local and adds no shadow map")
	var street_lights := level.get_tree().get_nodes_in_group("street_lamps")
	check(street_lights.size() == 3, "three existing street fixtures have matching light sources")
	for street in street_lights:
		check(not street.shadow_enabled and street.omni_range <= 6.0, "street fill has limited range without extra shadow maps")
	check(level.get_node("Daylight").shadow_enabled, "daylight still casts grounding shadows")
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		await frames(5)
		check_layout()
		var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/screenshots/visual-polish/before-metrics.json"))
		check(float(metrics[str(resolution.x)].panel_area) < float(before[str(resolution.x)].panel_area) * .9, "preparation panel area reduced at least 10 percent")
		check(metrics[str(resolution.x)].camera_transform == before[str(resolution.x)].camera_transform, "before/after camera transform exactly matches")
		check(metrics[str(resolution.x)].fov == before[str(resolution.x)].fov, "before/after FOV matches")
	root.size = Vector2i(1280,720)
	await view(Vector3(.69,1.56,-1.60), Vector3(-.06,.4,-1.64), 42)
	await shot("02-machine-lighting")
	await view(Vector3(.61,1.38,-1.07), Vector3(-.03,.4,-1.35), 35)
	await shot("03-pitcher-tamper-mat")
	for action in ["pitcher", "dose"]:
		await use(action)
		check(a.inspected == action, "E reaches and takes accessory: " + action)
		await use(action)
		check(a.inspected.is_empty(), "E returns accessory: " + action)
	await view(Vector3(0,2.35,-2.78), Vector3(0,.4,-1.4), 65)
	check(level.player.get_interactable() == null and level.hud.hint.text.is_empty(), "only dot when aiming at plain wall")
	await check_dot_pixels()
	await shot("04-reticle-wall-no-target")
	await view(Vector3(-.88,1.3,-1.14), Vector3(0,.4,-1.14), 65)
	check(level.player.get_interactable() == null and level.hud.hint.text.is_empty(), "only dot on light countertop")
	await check_dot_pixels()
	await shot("04-reticle-counter-no-target")
	await aim(level.stations.machine.global_position, Vector3(0,.4,level.stations.machine.global_position.z))
	check(level.player.get_interactable() == level.stations.machine, "hover uses unchanged machine RayCast handler")
	check(level.hud.hint.text == "Кофемашина — [E] Использовать", "name and action appear only on hover")
	await shot("05-machine-hover")
	await view(OVERVIEW_TARGET, OVERVIEW_STAND, 65)
	check(level.get_node("GraphicsSettings") != null, "neutral graphics controls available")
	await shot("07-work-area-cozy")
	for device in ["machine", "grinder", "fridge", "cash"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("window")
	await frames(42)
	await use("shift")
	await click("Открыть смену")
	level.session.catalog.config.customers.interval_seconds = 99999
	level.session.catalog.config.customers.profiles = [{"name":"Гость", "color":"536f75", "preferred":["latte_large"], "greeting":"Здравствуйте"}]
	var last_id := 0
	for i in range(2):
		level.session.spawn_customer()
		last_id = await take_payment()
	check(last_id > 0 and level.session.paid_orders().size() == 2, "sidebar shows two real paid orders")
	if last_id > 0: await select_from_sidebar(last_id, 0)
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		await view(OVERVIEW_TARGET, OVERVIEW_STAND, 65)
		await frames(5)
		check_layout()
		check(level.hud.item_buttons.size() == 2, "both original order buttons preserved")
		for button in level.hud.item_buttons.values():
			check(button.get_global_rect().size.x <= level.hud.orders_panel.size.x, "long order captions wrap within sidebar")
		await shot("06-orders-panel-" + str(resolution.x))
	check(level.validate_snapshot(level.capture_snapshot()), "existing save schema stays valid")

func check_layout() -> void:
	var visible := root.get_visible_rect()
	var panel := level.hud.orders_panel.get_global_rect()
	var controls := level.hud.control_hints.get_global_rect()
	check(visible.encloses(panel), "sidebar stays inside viewport: " + str(root.size))
	check(visible.grow(.01).encloses(controls), "bottom controls stay inside viewport: " + str(root.size) + " " + str(controls))
	check(panel.end.y < controls.position.y - 8, "orders leave space above control hints")
	check(level.hud.control_hints.get_line_count() <= 2, "bottom controls fit in two lines")
	check(level.hud.reticle.is_visible_in_tree(), "small dot stays present in FPS gameplay")
	check(level.hud.reticle.get_global_rect().get_center().is_equal_approx(visible.get_center()), "dot remains at actual viewport center")
	check(level.hud.status.text.contains("ДЕНЬ") and level.hud.status.text.contains("Касса:") and level.hud.status.text.contains("Заказы:"), "left information block preserved")

func check_dot_pixels() -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var center := image.get_size()/2
	var scale := float(image.get_width()) / root.get_visible_rect().size.x
	var white := image.get_pixel(center.x, center.y)
	var outline := image.get_pixel(center.x + int(1.5 * scale), center.y)
	check(white.r > .85 and white.g > .85 and white.b > .85, "dot core is light on actual scene background")
	check(outline.r < .2 and outline.g < .2 and outline.b < .2, "thin dark outline visible beside core")
