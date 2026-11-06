extends SceneTree
## Read-only diagnostics except isolated --test-mode careers. Observations are
## evidence for the audit, not acceptance tests that require bugs to remain.
var output := ""
var observations := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func frames(count: int = 4) -> void:
	for i in range(count): await physics_frame

func customer_at_counter(session: CoffeeShiftSession) -> Dictionary:
	var customer := session.spawn_customer()
	session.tick(20)
	return customer

func ready_session() -> CoffeeShiftSession:
	var session := CoffeeShiftSession.new()
	session.catalog.config.customers.interval_seconds = 999999
	session.catalog.config.customers.profiles = [{"name":"Аудит","color":"536f75", "preferred":["espresso_small"],"greeting":"Здравствуйте"}]
	for device in session.equipment: session.prepare_equipment(device)
	session.toggle_window()
	session.open_shift()
	session.spawn_elapsed = 0
	return session

func buy_and_serve(session: CoffeeShiftSession) -> bool:
	var customer := customer_at_counter(session)
	if customer.is_empty() or not session.confirm_order(int(customer.id)): return false
	session.cash.request_exact()
	if not session.accept_cash() or not session.finalize_payment(): return false
	var order := session.order_by_id(int(customer.order))
	for index in range(order.items.size()):
		if not session.select_item(int(order.id), index): return false
		for step in session.catalog.steps(order.items[index]):
			if step == "stop": session.tick(9)
			if not session.prepare_action(step): return false
		if order.items.size() > 1 and not session.pack_cup(int(order.id), index): return false
	if not session.call_order(int(order.id)): return false
	session.tick(20)
	if not session.serve_order(int(order.id), int(customer.id)): return false
	session.tick(20)
	return true

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-mode"):
		push_error("Audit diagnostics require isolated --test-mode")
		quit(2)
		return
	var world: ShiftWorld = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	world.new_game(1)
	world.set_physics_process(false)
	var manager := world.save_manager
	manager.save_slot("manual", 1, true)
	var original := manager.latest(1)
	var before_files := manager.list_slots(1).filter(func(row: Dictionary) -> bool: return row.valid).size()
	# Original A01 obstacle. New-game staging must no longer delete these files.
	var obstacle := manager.slot_path(1, "auto", 1) + ".tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(obstacle))
	var overwritten := world.new_game(1, true, false)
	var after_files := manager.list_slots(1).filter(func(row: Dictionary) -> bool: return row.valid).size()
	var archived_files := 0
	var archive := manager.slot_path(1, "auto", 1).get_base_dir() + ".previous"
	for kind in ["manual", "auto"]:
		for slot in range(1, 4):
			if not manager._read_file(archive.path_join("%s_%d.json" % [kind, slot]), 1, kind, slot).is_empty(): archived_files += 1
	observations.new_game_original_obstacle = {"old_valid_files":before_files, "new_game_returned":overwritten,
		"active_valid_files_after":after_files, "archived_valid_files":archived_files, "old_payload_was_valid":not original.is_empty()}
	manager.save_slot("manual", 1, true)
	var stage_path := manager.slot_path(1, "auto", 1).get_base_dir() + ".pending"
	var stage_obstacle := FileAccess.open(stage_path, FileAccess.WRITE)
	stage_obstacle.store_string("occupied staging path")
	stage_obstacle.close()
	var before_world := world.capture_snapshot()
	before_files = manager.list_slots(1).filter(func(row: Dictionary) -> bool: return row.valid).size()
	overwritten = world.new_game(1, true, false)
	after_files = manager.list_slots(1).filter(func(row: Dictionary) -> bool: return row.valid).size()
	observations.new_game_preparation_failure = {"old_valid_files":before_files, "new_game_returned":overwritten,
		"valid_files_after":after_files, "world_unchanged":JSON.stringify(world.capture_snapshot()) == JSON.stringify(before_world)}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage_path))
	world.main_menu.hide()
	world.new_game(2)
	world.game_settings.shadow_quality = 2
	world.game_settings.brightness = 1.05
	world.apply_settings()
	var old_career := world.capture_snapshot()
	old_career.world.vhs_enabled = true
	old_career.world.vhs_strength = .4
	var restored := world.apply_snapshot(old_career)
	observations.legacy_graphics = {"load_succeeded":restored, "brightness":world.game_settings.brightness, "shadow_quality":world.game_settings.shadow_quality, "obsolete_hud_removed":not world.hud.has_method("adjust_vhs")}
	var guide_before := world.hud.guide.text
	for device in world.session.equipment: world.session.prepare_equipment(device)
	observations.preparation_guide = {"unchanged_after_all_checks":guide_before == world.hud.guide.text,
		"all_devices_ready":not false in world.session.equipment.values(), "text":world.hud.guide.text}
	var cabinet: CoffeeShiftCabinet = world.new_assets.cabinets.BaseOppositeFront
	var leaf := cabinet.get_node("LeftHinge/DoorInteractable") as StaticBody3D
	cabinet.set_door_open(&"left", true, false)
	observations.cabinet_leaf = {"layer":leaf.collision_layer,"player_mask":world.player.collision_mask,
		"ray_mask":world.player.ray.collision_mask, "blocks_player":bool(leaf.collision_layer & world.player.collision_mask),
		"ray_detects":bool(leaf.collision_layer & world.player.ray.collision_mask)}
	var session := ready_session()
	var bytes_before := JSON.stringify(session.snapshot()).length()
	var transactions := 0
	for i in range(20):
		if buy_and_serve(session): transactions += 1
	observations.order_retention = {"completed_transactions":transactions,"retained_orders":session.orders.size(),
		"active_orders":session.active_orders().size(),"bytes_before":bytes_before,"bytes_after":JSON.stringify(session.snapshot()).length()}
	# Show the same cup asset for two genuinely different recipe sizes.
	var cup_a := world.new_assets.cup(world.trailer, "AuditEspressoCup", Vector3.ZERO)
	var cup_b := world.new_assets.cup(world.trailer, "AuditLargeLatteCup", Vector3.ZERO)
	observations.cup_sizes = {"espresso_ml":session.catalog.recipes.espresso_small.ml,"large_latte_ml":session.catalog.recipes.latte_large.ml,
		"same_scene":cup_a.scene_file_path == cup_b.scene_file_path,"same_scale":cup_a.scale == cup_b.scale,"scene":cup_a.scene_file_path}
	cup_a.free()
	cup_b.free()
	# Spawn recipes at both price extremes; demand code never receives price.
	var low := ready_session()
	var high := ready_session()
	low.set_price("espresso_small", 10)
	high.set_price("espresso_small", 500)
	var low_customer := customer_at_counter(low)
	var high_customer := customer_at_counter(high)
	observations.price_response = {"low_price":low.prices.espresso_small,"high_price":high.prices.espresso_small,
		"same_customer_items":low_customer.items == high_customer.items,"interval_seconds":low.catalog.config.customers.interval_seconds}
	world.player.position = Vector3(0,.4,2)
	world.player.rotation.y = 0
	await frames(12)
	observations.performance = {"renderer":DisplayServer.get_name(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"render_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	var text := JSON.stringify(observations, "\t")
	print("AUDIT OBSERVATIONS: " + text)
	if output != "":
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(text + "\n")
	quit(0)
