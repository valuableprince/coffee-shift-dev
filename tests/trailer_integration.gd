extends "res://tests/asset_integration.gd"
## Real DEV-03 scene: original shell, safe moving leaves, traversal, disk saves.

func shot(name: String) -> void:
	root.size = Vector2i(1280,720)
	await super.shot(name)
	root.size = Vector2i(384,216)
	await frames(2)

func shell_ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	var exclusions: Array[RID] = []
	for body in level.find_children("*", "PhysicsBody3D", true, false):
		if body != level.trailer.shell.get_node("FixedShellCollision"):
			exclusions.append(body.get_rid())
	query.exclude = exclusions
	return level.get_world_3d().direct_space_state.intersect_ray(query)

func hold(action: String, count: int) -> void:
	Input.action_press(action)
	await frames(count)
	Input.action_release(action)
	await frames(2)

func run() -> void:
	root.size = Vector2i(384,216)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	check(level.main_menu.visible, "existing title menu starts")
	check(level.new_game(1), "new career starts inside unchanged world")
	var shell := level.trailer.shell
	var door: TrailerDoor = level.trailer.get_node("StaffDoor")
	check(level.trailer.transform == Transform3D.IDENTITY, "trailer world placement unchanged")
	check(shell.scene_file_path == "res://assets/models/coffee_trailer/coffee_trailer.tscn", "real scene uses original packed asset")
	check(not shell.handle_first_person_input, "imported autonomous E handler disabled")
	check(shell.get_node("ShellVisual").scene_file_path.ends_with("coffee_trailer_shell.glb"), "original shell GLB")
	check(shell.get_node("ChassisVisual").scene_file_path.ends_with("coffee_trailer_chassis.glb"), "original chassis GLB")
	check(level.shutter.get_node("HatchVisual").scene_file_path.ends_with("coffee_trailer_window_hatch.glb"), "original hatch GLB")
	check(door.get_node("DoorVisual").scene_file_path.ends_with("coffee_trailer_rear_door.glb"), "original rear door GLB")
	check(shell.get_node("FixedShellCollision").get_child_count() == 1, "exactly one static shell collider")
	check(shell.get_node("FixedShellCollision/ShellCollider").shape.get_faces().size() == 1880*3, "all original shell triangles included once")
	check(shell.get_node("RearDoorHinge").get_child_count() == 0, "no duplicate moving door or door target")
	for name in ["RoundedRoof","RoundedEnds","FinishedFloor","LeftWall","FrontEnd","WindowSillPanel","ServiceShutter","DoorLeaf","Chassis","Tyre","DoorFrame"]:
		check(level.trailer.find_child(name,true,false) == null,"old geometry absent: " + name)
	for z in [-2.40,-1.2,0.0,1.2,2.40]:
		for x in [-.40,0.0,.40]:
			var hit := shell_ray(Vector3(x,.8,z), Vector3(x,0,z))
			check(not hit.is_empty() and absf(hit.position.y-.4)<.001,"floor remains at .4 throughout: " + str(Vector2(x,z)) + " hit=" + str(hit))
			hit = shell_ray(Vector3(x,2.4,z),Vector3(x,3,z))
			check(not hit.is_empty() and absf(hit.position.y-2.64)<.001,"ceiling is level along length: " + str(Vector2(x,z)))
	for z in [-2.0,-1.0,0.0,1.0,2.0]:
		var hit := shell_ray(Vector3(-1.0,1.7,z),Vector3(-2,1.7,z))
		check(not hit.is_empty() and hit.position.x < -1.13,"left wall blocks: " + str(z))
	for y in [1.25,1.65,2.05]:
		for z in [-.74,0.0,.74]:
			check(shell_ray(Vector3(1.0,y,z),Vector3(1.3,y,z)).is_empty(),"window aperture clear: " + str(Vector2(y,z)))
	for z in [-1.3,1.3]:
		check(not shell_ray(Vector3(1.0,1.65,z),Vector3(1.4,1.65,z)).is_empty(),"side wall still blocks beyond window")
	for x in [-.43,0.0,.43]:
		check(shell_ray(Vector3(x,2.20,2.5),Vector3(x,2.20,2.95)).is_empty(),"1.9 m rear headroom remains clear: " + str(shell_ray(Vector3(x,2.20,2.5),Vector3(x,2.20,2.95))))
	for id in ["WallFront","WallRear"]:
		var cabinet: Node3D = level.new_assets.cabinets[id]
		var box := bounds(cabinet)
		var hit := shell_ray(Vector3(box.position.x+.001,box.end.y+.001,cabinet.position.z), Vector3(box.position.x+.001,3,cabinet.position.z))
		check(not hit.is_empty() and hit.position.y > box.end.y+.01, "cabinet top clears new roof shoulder: " + id)
	check(level.trailer.get_node("PortableWorkLight").shadow_enabled == false,"PR70 lighting retained")
	check(level.new_assets.cabinets.size() == 7 and level.new_assets.register != null, "all seven independent cabinets and register retained")
	await view(Vector3(0,2.38,-2.60),Vector3(0,.4,1.80),75)
	await shot("01-after-ceiling-front")
	await view(Vector3(0,2.38,2.60),Vector3(0,.4,-1.90),75)
	await shot("02-after-ceiling-rear")
	await view(Vector3(.03,1.35,-.55),Vector3(0,.4,1.96),75)
	await shot("03-interior")
	await view(Vector3(1.2,1.65,0),Vector3(0,.4,0),75)
	await shot("04-service-window-closed")
	await view(Vector3(0,1.4,0),Vector3(5.5,.02,5.5),75)
	await shot("05-exterior")
	# The complete moving hatch delegates into CoffeeShiftSession, never a second state.
	var hatch_target: CoffeeShiftTrailerTarget = shell.get_node("WindowHinge/HatchInteraction")
	check(hatch_target.interaction_delegate == level.stations.window,"moving leaf uses existing authoritative window operation")
	await aim(hatch_target.get_node("Hitbox").global_position,Vector3(0,.4,0))
	check(level.player.get_interactable() == hatch_target,"crosshair targets original closed hatch")
	check(level.hud.hint.text.contains("Створка окна"),"moving hatch has existing contextual caption")
	await key(KEY_E)
	check(level.session.window_open and shell.hatch_open,"one physical E opens window exactly once")
	await frames(54)
	check(absf(level.shutter.rotation.z-deg_to_rad(77))<.001,"original +77 degree hinge endpoint")
	check(hatch_target.collision_layer==2,"open hatch has no physical sweep collider")
	await view(Vector3(1.2,1.9,0),Vector3(0,.4,.6),75)
	await shot("06-window-open-inside")
	await view(Vector3(1.2,1.55,0),Vector3(4.3,.02,2.4),75)
	await shot("07-window-open-outside")
	# Close and reopen through the existing fixed frame latch.
	await use("window")
	await frames(54)
	check(not level.session.window_open and not shell.hatch_open and hatch_target.collision_layer==3,"same E closes hatch and restores closed blocking")
	await use("window")
	await frames(54)
	# Door keeps existing save key and player obstruction guard.
	await aim(door.to_global(Vector3(.466,.94,0)),Vector3(0,.4,1.8))
	check(level.player.get_interactable()==door,"door physical E reachable inside")
	await key(KEY_E)
	check(door.opened and door.moving and door.collision_layer==0,"door starts once without pushing player")
	await frames(44)
	check(door.opened and not door.moving and absf(door.rotation.y-deg_to_rad(-100))<.001,"new door reaches -100 degrees")
	await view(Vector3(0,1.38,2.78),Vector3(1.8,.02,4.7),75)
	await shot("08-staff-door-open")
	await aim(Vector3(0,1.4,0),Vector3(0,.02,4.7))
	level.player.rotation.y=0
	level.player.pitch=0
	level.player.camera.rotation=Vector3.ZERO
	await hold("forward",100)
	check(level.player.position.z < 1.6 and absf(level.player.position.y-.4)<.03,"physical W climbs retained ramp into original doorway")
	await hold("forward",85)
	check(level.player.position.z < -1.35 and level.player.position.y>.38,"physical W crosses whole aisle without invisible obstacles")
	await hold("back",205)
	check(level.player.position.z>4.8 and level.player.position.y<.03,"physical S exits via doorway without jump")
	await aim(Vector3(0,1.4,-1),Vector3(0,.4,2.78))
	var stationary: Vector3 = level.player.position
	door.interact()
	await frames(45)
	check(door.opened and not door.moving and level.player.position.distance_to(stationary)<.03,"closing blocked in portal; no physical jerk")
	await aim(Vector3(0,1.4,-1),Vector3(0,.4,1.5))
	var saved: Dictionary=level.capture_snapshot()
	check(level.save_manager.save_slot("manual",1,true)==OK,"save original open hatch/door")
	door.restore_opened(false)
	level.session.toggle_window()
	await frames(12)
	check(level.save_manager.load_slot(1,"manual",1),"load through existing save manager")
	check(JSON.stringify(level.capture_snapshot())==JSON.stringify(saved) and shell.hatch_open and door.opened,"save restores authoritative window, door and equipment states")
	check(absf(level.shutter.rotation.z-deg_to_rad(77))<.001,"save restores hatch instantly during previous animation")
	level.show_pause()
	await key(KEY_E)
	check(JSON.stringify(level.capture_snapshot())==JSON.stringify(saved),"pause blocks imported input adapters")
	level.return_to_title()
	level.continue_game(1)
	check(level._active and door.opened and shell.hatch_open,"title Continue restores scene and states")
	# A pre-integration DEV-03 save uses exactly the same fields.
	var legacy: Dictionary=saved.duplicate(true)
	legacy.world.position=[0,.4,2.78]
	legacy.world.erase("staff_door_opened")
	check(level.apply_snapshot(legacy),"old save without door state loads")
	check(door.opened,"old saved portal position opens door safely")
	await aim(Vector3(0,1.4,-1),Vector3(0,.4,1.5))
	for device in ["machine","grinder","fridge","cash"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("shift")
	await click("Открыть смену")
	check(level.session.shift_open,"existing shift starts with original hatch")
	await use("window")
	check(level.session.window_open and shell.hatch_open,"shift restrictions prevent closing same hatch")
	level.session.accepting=false
	await use("shift")
	await click("Закрыть смену")
	check(not level.session.shift_open,"existing shift ends normally")
	if level.hud.panel.visible: level.hud.close_panel()
	# Existing independent cabinet/register controls and visible reticle.
	await view(Vector3(.32,1.38,1.1),Vector3(0,.4,-.75),75)
	await shot("09-cabinets-and-register")
	await aim(level.stations.cash.global_position,Vector3(0,.4,1.38))
	check(level.player.get_interactable()==level.stations.cash,"contextual crosshair reaches existing register")
	await shot("10-crosshair-interaction")
	await aim(Vector3(0,2.6,-2),Vector3(0,.4,0))
	check(level.hud.reticle.is_visible_in_tree() and level.hud.hint.text.is_empty(),"permanent center dot without permanent equipment label")
	check(not InputMap.has_action("vhs"),"obsolete effect action removed")
	await view(Vector3(.03,1.35,-.55),Vector3(0,.4,1.96),75)
	await shot("11-interior-cozy")
	level.save_manager.autosave_enabled=false
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	print("TRAILER INTEGRATION: %d checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
