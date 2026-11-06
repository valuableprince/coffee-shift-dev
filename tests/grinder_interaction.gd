extends "res://tests/dev03_integration.gd"
## Real raycasts/input, imported composite model, stateful prompts and HUD modes.

func capture(name: String) -> void:
	if screenshots.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await frames(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots.path_join(name + ".png")) == OK, "viewport screenshot " + name)

func check_center() -> void:
	var reticle := level.hud.reticle
	var viewport_center := root.get_visible_rect().get_center()
	var dot_center := reticle.get_global_transform_with_canvas() * (reticle.size / 2)
	check(dot_center.distance_to(viewport_center) < .01, "dot exactly centered at " + str(root.size))
	var projected := level.player.camera.project_ray_normal(dot_center)
	var actual := (level.player.ray.to_global(level.player.ray.target_position) - level.player.ray.global_position).normalized()
	check(projected.distance_to(actual) < .0001, "dot and existing camera ray agree at " + str(root.size))
	# CanvasItem transforms use logical coordinates; include Window stretch
	# when measuring physical pixels at the supported 16:9 resolutions.
	var diameter := InteractionReticle.DIAMETER * root.size.x / root.get_visible_rect().size.x
	if root.size == Vector2i(1920, 1080):
		check(diameter >= 3 and diameter <= 4, "1080p dot is 3–4 physical pixels")
	check(reticle.hint.get_global_transform_with_canvas().origin.y > dot_center.y, "context hint sits below central dot")

func run() -> void:
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	check(not level.hud.reticle.is_visible_in_tree(), "title hides dot")
	await click("Новая игра", level.main_menu)
	await click("Начать новую игру", level.main_menu)
	await frames(3)
	check(level.hud.reticle.is_visible_in_tree(), "ordinary first-person gameplay shows permanent dot")
	check(level.player.find_children("*", "RayCast3D", true, false).size() == 1, "interaction reuses single existing ray")
	for station in level.stations.values():
		check(station.find_children("*", "Label3D", true, false).is_empty(), "no constant equipment nameplate: " + station.action)
		check(station.get_node_or_null("Tag") == null, "no artificial tag mesh: " + station.action)
	var original_bytes := FileAccess.get_file_as_bytes("res://assets/models/coffee_grinder/coffee_grinder.glb")
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(original_bytes)
	check(original_bytes.size() == 534424 and digest.finish().hex_encode() == "2e71ca2eb9f0051a6edf8f14fab69adb70f0a44b186383c1c813a29eb0c3f8e5", "existing approved GLB includes the half-full dark beans from PR 63")
	check(level.grinder_visual.find_children("*", "MeshInstance3D", true, false).size() == 34, "approved model retains all 34 mesh parts")
	var model: Node3D = level.grinder_visual.get_node("CoffeeGrinder")
	check(is_equal_approx(model.global_position.y, 1.30), "grinder base rests on approved worktop")
	check(is_equal_approx(model.scale.x, .60), "approved metre-scale model fitted uniformly")
	check((model.global_basis * Vector3(0,0,1)).normalized().dot(Vector3.LEFT) > .99, "model front faces aisle")
	check(model.get_node("Model").scene_file_path.ends_with("coffee_grinder.glb"), "actual scene instances original GLB")
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
		root.size = resolution
		await frames(5)
		check_center()
	await aim(Vector3(0, 2.8, -2), Vector3(0, .4, 0))
	await frames(3)
	check(level.hud.hint.text.is_empty() and level.hud.reticle.is_visible_in_tree(), "looking at noninteractive ceiling hides hint but keeps dot")
	await capture("01-free-look-1080")
	await aim(level.stations.grinder.global_position, Vector3(0, .4, -1))
	await frames(3)
	check(level.player.get_interactable() == level.stations.grinder, "hover reaches existing grinder interaction")
	check(level.hud.hint.text == "Кофемолка — [E] Использовать", "hover shows noun and real action below dot")
	await capture("02-grinder-hover-1080")
	await aim(Vector3(.83, 1.73, -1), Vector3(0, .4, -1))
	check(level.player.ray.get_collider() == model.get_node("StaticBody3D"), "ray hits imported nested collider rather than proxy")
	check(level.player.get_interactable() == level.stations.grinder, "nested imported collider resolves to same interaction owner")
	await key(KEY_E)
	check(level.session.equipment.grinder, "E through nested collider checks actual grinder")
	check(not level.stations.grinder.get_available_action().contains("[E]"), "checked grinder does not offer unavailable grinding without beans")
	# Occlusion: first ray hit is a real solid wall, not a hidden second query.
	var wall := level.G.box(level, "TestOccluder", Vector3(.3, 1.80, -1), Vector3(.15, .8, .5), Color.DIM_GRAY)
	await frames(4)
	check(level.player.get_interactable() == null and level.hud.hint.text.is_empty(), "obstacle hides target and hint")
	check(level.hud.reticle.is_visible_in_tree(), "occlusion never hides central dot")
	wall.queue_free()
	await frames(3)
	var far_target := ShiftWorkstation.new()
	far_target.configure(level, "grinder", "Кофемолка", Vector3(7,1.5,7), Vector3(.12,.3,.3))
	level.add_child(far_target)
	await aim(far_target.global_position, Vector3(4.5,.02,7))
	check(level.player.get_interactable() == far_target, "unobstructed object inside interaction range is reachable")
	await aim(far_target.global_position, Vector3(3.5,.02,7))
	check(level.player.get_interactable() == null and level.hud.hint.text.is_empty(), "out-of-range object has no hint")
	far_target.queue_free()
	await use("fridge")
	check(not level.stations.fridge.get_available_action().contains("[E]"), "moving fridge door offers no unavailable E action")
	await frames(32)
	check(level.stations.fridge.get_prompt() == "Холодильник — [E] Закрыть", "open fridge changes contextual action")
	await aim(level.stations.fridge.global_position, Vector3(0,.4,-.18))
	await capture("03-fridge-open-1080")
	await use("fridge")
	await frames(32)
	check(level.stations.fridge.get_prompt() == "Холодильник — [E] Открыть", "closed fridge changes contextual action back")
	var door: TrailerDoor = level.trailer.get_node("StaffDoor")
	await aim(door.to_global(Vector3(.475,.95,0)), Vector3(0,.4,1.8))
	check(level.hud.hint.text == "Задняя дверь — [E] Открыть", "rear door uses same contextual interface")
	await key(KEY_E)
	await frames(42)
	check(door.get_prompt() == "Задняя дверь — [E] Закрыть", "rear door action changes on actual opening")
	for menu_key in [KEY_TAB, KEY_N, KEY_F6, KEY_ESCAPE]:
		await key(menu_key)
		check(not level.hud.reticle.is_visible_in_tree(), "system-cursor UI hides dot: " + str(menu_key))
		check(level.hud.hint.text.is_empty(), "cursor UI clears stale target prompt")
		if menu_key == KEY_ESCAPE:
			await click("Вернуться в игру", level.main_menu)
		else:
			await key(KEY_ESCAPE)
		check(level.hud.reticle.is_visible_in_tree(), "return to gameplay restores dot")
	level.return_to_title()
	await frames(3)
	check(not level.hud.reticle.is_visible_in_tree(), "returning to title hides dot")
	# Existing real payment and complete espresso path verify integration mechanics.
	level.continue_game(1)
	for device in ["machine", "grinder", "cash"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("window")
	await frames(42)
	await use("shift")
	await click("Открыть смену")
	level.session.catalog.config.customers.interval_seconds = 99999
	level.session.catalog.config.customers.profiles = [{"name":"Гость","color":"536f75","preferred":["espresso_small"],"greeting":"Здравствуйте"}]
	level.session.spawn_customer()
	var id := await take_payment()
	if id != 0:
		await cook(id, 0)
		await serve(id)
	check(level.session.stats.completed == 1, "grinder integration preserves payment, manual recipe and physical serving")
	level.save_manager.autosave_enabled = false
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	var garage = load("res://scenes/main.tscn").instantiate()
	root.add_child(garage)
	current_scene = garage
	await frames(5)
	check(garage.hud.reticle.is_visible_in_tree(), "garage uses same permanent dot")
	check(garage.hud.reticle.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()), "garage dot also centered after resolution change")
	for part in garage.parts:
		if not part is EquipmentInstallation: continue
		check(part.find_children("*", "Label3D", true, false).is_empty(), "garage equipment has no permanent nameplate")
		check(part.get_node_or_null("MountingTag") == null and part.indicator != null, "name tag removed while actual status indicator retained")
		if part.definition.device == "grinder":
			check(part.get_prompt().begins_with("Кофемолка —"), "garage equipment uses same name/action interface")
			check(part.equipment.get_node("CoffeeGrinder/StaticBody3D").collision_layer == 0, "uninstalled imported grinder cannot occlude garage interactions")
	for pickup in garage.pickups:
		check(pickup.find_children("*", "Label3D", true, false).is_empty(), "garage supplies and tools have no constant name labels")
	garage._show_pause()
	await frames(3)
	check(not garage.hud.reticle.is_visible_in_tree(), "garage pause also hides dot")
	garage._resume_game()
	await frames(3)
	check(garage.hud.reticle.is_visible_in_tree(), "garage resume restores dot")
	garage.save_manager.autosave_enabled = false
	garage.queue_free()
	await frames(3)
	print("GRINDER INTERACTION: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
