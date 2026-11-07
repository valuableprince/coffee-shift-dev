extends "res://tests/dev03_integration.gd"
## Regression for the nine corrections from the first Windows playthrough.

func pool_has_loop() -> bool:
	for p in level.audio.players:
		if p.stream is AudioStreamWAV and p.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED: return true
	return false

func visible_mesh_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*","MeshInstance3D",true,false):
		if not child.visible: continue
		var relative: Transform3D = node.global_transform.affine_inverse() * child.global_transform
		var bounds: AABB = relative * child.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func run() -> void:
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	level.new_game(1)
	level.audio.playback_enabled = true
	check(not level.fridge.opened and not level.fridge.milk_accessible(), "milk inaccessible behind closed door")
	check(level.stations.milk.collision_layer == 0, "closed fridge cannot be raycast through for milk")
	check(level.fridge.milk.get_parent() == level.fridge, "milk actually belongs to fridge interior")
	check(level.fridge.milk.find_children("*","Label3D",true,false).is_empty(), "milk carton has no text or illustrations")
	var assets: Array = []
	for path in ["severny_coffee/coffee_bag", "water_15l/water_bottle", "utrenniy_lug/milk_carton"]:
		var model: Node3D = load("res://assets/models/" + path + ".tscn").instantiate()
		root.add_child(model)
		await frames()
		assets.append(model)
		var bounds := visible_mesh_bounds(model)
		check(bounds.position.y >= -.001 and bounds.size.y > .2 and bounds.size.y < .36, "complete package rests on its base: " + path)
		check(model.find_children("*","Label3D",true,false).is_empty(), "package uses geometry, not unreadable 3D lettering: " + path)
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var mat: Material = mesh.material_override
			check(not mat is StandardMaterial3D or mat.albedo_texture == null, "no obsolete printed SVG faces")
	for model in assets: model.queue_free()
	await use("fridge") # Complete the mandatory inspection before normal door use.
	await use("fridge")
	await frames(32)
	check(level.fridge.opened and level.fridge.milk_accessible(), "physical fridge handle opens door")
	check(level.stations.milk.collision_layer == 2, "milk becomes interactable only after opening")
	await aim(level.fridge.milk.global_position+Vector3(0,.12,0),Vector3(0,.4,-.18))
	await shot("12-fridge-open-milk")
	check(level.save_manager.save_slot("manual",1,true) == OK, "save opened fridge")
	await use("fridge")
	await frames(32)
	check(not level.fridge.opened, "same moving handle closes fridge")
	check(level.save_manager.load_slot(1,"manual",1) and level.fridge.opened, "fridge door state survives disk reload")
	var previous: Dictionary = level.capture_snapshot()
	previous.world.erase("fridge_opened")
	previous.world.erase("staff_door_opened")
	check(level.apply_snapshot(previous) and not level.fridge.opened, "older DEV-03 save without new door fields remains compatible")
	var door: TrailerDoor = level.trailer.get_node("StaffDoor")
	await aim(door.to_global(Vector3(.475,.95,0)), Vector3(0,.02,3.8))
	check(level.player.get_interactable() == door, "staff door reachable from outside")
	await key(KEY_E)
	await frames(42)
	check(door.opened, "staff door opens from outside")
	await aim(door.to_global(Vector3(.475,.95,0)), Vector3(1.2,.02,3.8))
	check(level.player.get_interactable() == door, "opened leaf remains reachable to close")
	await key(KEY_E)
	await frames(42)
	check(not door.opened and is_zero_approx(door.rotation.y), "staff door closes with physical E")
	await aim(door.to_global(Vector3(.475,.95,0)), Vector3(0,.4,1.8))
	await key(KEY_E)
	await frames(42)
	check(door.opened, "staff door opens from inside")
	check(level.save_manager.save_slot("manual",2,true) == OK, "save opened staff door")
	await aim(door.to_global(Vector3(.475,.95,0)), Vector3(0,.4,1.8))
	check(level.player.get_interactable() == door, "inside player can still target opened leaf")
	await key(KEY_E)
	await frames(42)
	check(not door.opened, "staff door closes from inside")
	check(level.save_manager.load_slot(1,"manual",2) and door.opened, "staff door open state survives reload")
	await aim(door.to_global(Vector3(.475,.95,0)),Vector3(0,.4,2.78))
	door.interact()
	check(door.opened and not door.moving, "closing cannot trap player in doorway")
	await aim(Vector3(0,1.4,-1),Vector3(0,.4,1.5))
	level.player.rotation.y = 0
	level.player.pitch = 0
	level.player.camera.rotation = Vector3.ZERO
	level._last_foot_position = level.player.position
	level._foot_distance = 0
	var step_index := level.audio._step_index
	var walk := InputEventKey.new()
	walk.physical_keycode = KEY_W
	walk.pressed = true
	Input.parse_input_event(walk)
	await frames(30)
	await key(KEY_W,false)
	check(level.audio._step_index > step_index, "real walking triggers recorded footsteps by travelled distance")
	check(level.audio.footstep_player.stream is AudioStreamOggVorbis and not level.audio.footstep_player.stream.loop, "footstep uses recorded non-looping OGG")
	step_index = level.audio._step_index
	await frames(32)
	check(level.audio._step_index == step_index, "standing still produces no steps")
	check(level.audio.footstep_variants.wood.size() == 5 and level.audio.footstep_variants.concrete.size() >= 4, "five wood and at least four approved public concrete variants; optional fifth may be absent")
	for device in ["machine","grinder","cash"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("window")
	await frames(54)
	check(absf(level.shutter.rotation.z-deg_to_rad(77)) < .001, "original awning reaches its specified +77 degree endpoint")
	check(level.trailer.get_node_or_null("TicketRail") == null and level.trailer.get_node_or_null("PaperOrders") == null, "no rail or floating order sheets block service window")
	await aim(Vector3(2.5,1.55,0),Vector3(0,.4,0))
	await shot("13-raised-window")
	await use("shift")
	await click("Открыть смену")
	level.session.catalog.config.customers.interval_seconds = 99999
	level.session.catalog.config.customers.profiles = [{"name":"Гость","color":"536f75","preferred":["espresso_small"],"greeting":"Здравствуйте"}]
	level.session.spawn_customer()
	var id := await take_payment()
	await select_from_sidebar(id,0)
	await prepare_filter()
	for action in ["cups","cup_tray","machine"]: await use(action)
	check(level.audio.process_player.playing and level.audio.last_process == "extract", "extraction has exactly one process channel")
	check(not pool_has_loop(), "one-shot pool never owns extraction or steam loop")
	await key(KEY_TAB)
	check(not level.audio.process_player.playing, "opening order menu immediately pauses machine sound")
	await key(KEY_ESCAPE)
	check(level.audio.process_player.playing, "closing order menu resumes running machine sound")
	await use("machine")
	check(not level.audio.process_player.playing and level.audio.last_process == "", "manual stop silences machine immediately")
	level.audio.set_process_sound("steam")
	level.audio.play_event("steam")
	check(level.audio.process_player.playing and not pool_has_loop(), "steam cannot start a duplicate endless one-shot")
	level.audio.set_process_sound("")
	check(not level.audio.process_player.playing and level.audio.process_player.stream == null, "steam stop clears stream")
	level.session.discard_drink(id,0)
	check(not level.audio.process_player.playing, "discard leaves no machine loop")
	for i in range(2):
		level.session.spawn_customer()
		await take_payment()
	check(level.hud.item_buttons.size() == 4, "three active orders with multiple items fit sidebar model")
	var sidebar := level.hud.orders_panel.get_global_rect()
	check(sidebar.position.x > root.size.x * .70 and not sidebar.has_point(root.size / 2), "orders remain entirely to right of central view")
	await aim(Vector3(2.4,1.55,0),Vector3(0,.4,0))
	await shot("14-three-orders-sidebar")
	await aim(Vector3(-.83,1.45,-1.55),Vector3(0,.4,-1.55))
	await shot("15-water-unlabelled")
	await aim(Vector3(-.83,1.43,-.9),Vector3(0,.4,-.9))
	await shot("16-coffee-pouch")
	level.audio.stop_all()
	await frames(3)
	level.save_manager.autosave_enabled = false
	level.queue_free()
	await frames(3)
	print("DEV03 FEEDBACK: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
