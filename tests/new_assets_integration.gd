extends "res://tests/asset_integration.gd"
## Real DEV-03 scene, physical E, original GLBs, persistence and latte handover.

func shot(name: String) -> void:
	if name in ["05-text-order", "06-cash-payment", "10-handover"]: return
	root.size = Vector2i(1280,720)
	await super.shot(name)
	root.size = Vector2i(384,216)
	await frames(2)

func door_target(cabinet: CoffeeShiftCabinet, side: String) -> CoffeeShiftCabinetDoor:
	return cabinet.get_node(("LeftHinge" if side == "left" else "RightHinge") + "/DoorInteractable")

func use_door(cabinet: CoffeeShiftCabinet, side: String) -> void:
	var target := door_target(cabinet,side)
	var point: Vector3 = target.get_node("Shape").global_position
	await aim(point,Vector3(0,.4,clampf(point.z,-2.10,2.0)))
	check(level.player.get_interactable() == target, "ray identifies exact " + cabinet.name + "/" + side)
	check(level.hud.hint.text.contains("дверца"), "door has contextual prompt")
	await key(KEY_E)

func assert_cup(model: Node3D, capped: bool) -> void:
	check(model != null,"original cup instance exists")
	if model == null: return
	var body: Node3D = model.get_node("Cup") if capped else model
	check(body.get_node("Model").scene_file_path.ends_with("coffee_shift_paper_cup_350ml.glb"),"uses original cup GLB")
	check(body.get_node("Model").find_children("*","MeshInstance3D",true,false).size() == 13,"all 13 source cup parts imported")
	check(model.has_node("Lid") == capped,"lid exists only after existing lid step")
	if capped:
		var lid: Node3D = model.get_node("Lid")
		check(lid.get_node("Model").scene_file_path.ends_with("coffee_shift_sip_lid_90mm.glb"),"separate original lid GLB")
		check(lid.global_position.distance_to(body.get_node("LidSocket").global_position) < .00001,"lid seats exactly at original rim socket")
	for collider in model.find_children("*","StaticBody3D",true,false):
		check(collider.collision_layer in [0,2] and collider.collision_mask == 0,"cup never physically pushes character")

func save_roundtrip(slot: int, message: String) -> Dictionary:
	var expected: Dictionary = level.capture_snapshot()
	check(level.save_manager.save_slot("manual",slot,true) == OK,message + " written to disk")
	level.new_assets.restore()
	check(level.save_manager.load_slot(1,"manual",slot),message + " loaded from disk")
	check(JSON.stringify(expected) == JSON.stringify(level.capture_snapshot()),message + " restored exactly")
	await frames(3)
	return expected

func run() -> void:
	root.size = Vector2i(384,216)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	check(level.new_game(1),"existing new-career entry works")
	var assets := level.new_assets
	var register := assets.register
	var source_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/new_assets_sources.json"))
	for source in source_data.sources:
		if source.path.ends_with(".glb"):
			check(FileAccess.get_sha256("res://"+source.path) == source.sha256,"source GLB bytes preserved: " + str(source.path))
	check(assets.cabinets.size() == 7,"five replacement base cabinets and two wall cabinets")
	check(not register.crosshair_interaction_enabled,"asset E adapter disabled in trade scene")
	for node in level.trailer.get_children():
		check(not str(node.name).begins_with("OppositeCabinets") and not str(node.name).begins_with("PreparationCabinet") and node.name != "ServingBase","no old cabinet envelope: " + node.name)
	for name in ["CupStack","Lids","CashDrawer"]:
		check(level.trailer.get_node_or_null(name) == null,"old primitive removed: " + name)
	check(register.get_node("BodyVisual").scene_file_path.ends_with("cash_register_body.glb"),"original register body imported")
	check(register.get_node("DrawerAssembly/DrawerVisual").scene_file_path.ends_with("cash_drawer.glb"),"separate original drawer imported")
	check(register.get_node("ReceiptPaper").scene_file_path.ends_with("receipt_paper.glb"),"original receipt retained")
	check(register.global_basis.z.dot(Vector3.LEFT) > .999,"keys and screen face player aisle")
	check(is_equal_approx(bounds(register).position.y,1.30),"register rests on existing worktop")
	check(not bounds(register).intersects(bounds(level.machine_visual)),"cash and coffee machine do not intersect")
	await view(Vector3(.03,1.35,-.55),Vector3(0,.4,1.96),75)
	await shot("01-after-work-area")
	for id in assets.cabinets:
		var cabinet: CoffeeShiftCabinet = assets.cabinets[id]
		var wall: bool = str(id).begins_with("Wall")
		var box := bounds(cabinet)
		check(not cabinet.allow_first_person_interaction,"single E dispatcher: " + id)
		check(cabinet.global_basis.get_scale().is_equal_approx(Vector3.ONE),"hinges use unscaled axes: " + id)
		check(is_equal_approx(box.position.y,1.70 if wall else .4),"correct cabinet bottom: " + id)
		check(box.position.x >= .475-.012 if cabinet.position.x > 0 else box.end.x <= -.475+.012,"closed cabinet preserves staff aisle: " + id)
		if wall:
			check(is_equal_approx(cabinet.to_global(Vector3(0,.3,-.33)).x,-1.10),"wall cabinet back clears curved roof shoulder")
			check(box.end.x < -.66 and box.end.y < 2.4,"wall cabinets clear window, lamp and roof")
		else:
			check(is_equal_approx(box.end.y,1.14 if id == "BaseServing" else 1.24),"base cabinet meets underside of retained worktop")
		check(cabinet.get_node("BodyCollider").get_child_count() == (5 if id == "BaseOppositeRear" else 6),"hollow shell has correct panels and basin cabinet lacks obstructing top collider")
		for side in ["left","right"]:
			var other := "right" if side == "left" else "left"
			var hinge: Node3D = cabinet.get_node("LeftHinge" if side == "left" else "RightHinge")
			var pivot := hinge.global_position
			await use_door(cabinet,side)
			check(cabinet.is_door_open(side) and not cabinet.is_door_open(other),"one E changes only targeted leaf")
			await frames(12)
			check(absf(hinge.rotation.y) > .05 and absf(hinge.rotation.y) < deg_to_rad(104),"hinge animates smoothly before .6 seconds")
			await frames(28)
			check(is_equal_approx(absf(hinge.rotation.y),deg_to_rad(105)),"leaf reaches 105 degrees after .6 seconds")
			check(hinge.global_basis.get_scale().is_equal_approx(Vector3.ONE),"opening has no shear or scale distortion")
			check(hinge.global_position.is_equal_approx(pivot),"hinge pivot stays at original jamb")
			check(door_target(cabinet,side).collision_layer == 2,"door cannot physically push character")
			await use_door(cabinet,side)
			await frames(40)
			check(not cabinet.is_door_open(side) and is_zero_approx(hinge.rotation.y),"second E closes targeted leaf")
	var base: CoffeeShiftCabinet = assets.cabinets.BasePreparationRear
	await view(Vector3(.58,.87,1.4),Vector3(-.03,.4,1.4),60)
	await shot("04-base-cabinet-closed")
	for side in ["left","right"]: await use_door(base,side)
	await frames(40)
	await view(Vector3(.82,.87,1.4),Vector3(-.03,.4,1.4),60)
	await shot("05-base-cabinet-open")
	var wall: CoffeeShiftCabinet = assets.cabinets.WallFront
	for side in ["left","right"]: await use_door(wall,side)
	await frames(40)
	await view(Vector3(-.96,1.98,.55),Vector3(.02,.4,.55),66)
	await shot("06-wall-cabinet-open")
	await use_door(assets.cabinets.WallRear,"right")
	await frames(40)
	await shot("09-context-door")
	await use("cash")
	check(not register.drawer_open and level.session.equipment.cash,"physical cash inspection checks keys without opening drawer")
	await use("cash")
	check(register.drawer_open,"checked cash E retains ordinary drawer operation")
	await frames(32)
	check(is_equal_approx(level.cash_drawer.position.z,.17),"drawer moves exactly 17 cm independently of register")
	var fixed_position := register.global_position
	await view(register.to_global(Vector3(0,.13,.08)),Vector3(0,.4,1.38),42)
	await shot("08-cash-drawer-open")
	await use("cash")
	await frames(32)
	check(not register.drawer_open and is_zero_approx(level.cash_drawer.position.z),"second physical cash E closes drawer once")
	check(register.global_position.is_equal_approx(fixed_position),"fixed register body does not move")
	await view(register.to_global(Vector3(0,.13,.03)),Vector3(0,.4,1.38),42)
	await shot("07-cash-drawer-closed")
	await use("cash")
	await frames(32)
	var saved := await save_roundtrip(1,"independent doors and drawer")
	check(assets.cabinets.BasePreparationRear.left_open and assets.cabinets.BasePreparationRear.right_open,"both saved base leaves restore")
	check(assets.cabinets.WallRear.right_open and not assets.cabinets.WallRear.left_open,"asymmetric wall state restores")
	check(register.drawer_open and is_equal_approx(level.cash_drawer.position.z,.17),"saved drawer restores at endpoint")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.world.erase("assets")
	check(level.apply_snapshot(legacy),"older DEV-03 saves lacking assets still load")
	check(not register.drawer_open and not base.left_open and not wall.right_open,"legacy cosmetic state defaults closed")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.world.assets.drawer_open = "yes"
	var unchanged: Dictionary = level.capture_snapshot()
	check(not level.apply_snapshot(corrupt) and level.capture_snapshot() == unchanged,"bad asset state rejected without changing trade")
	await view(Vector3(0,2.8,-2),Vector3(0,.4,0),75)
	check(level.player.get_interactable() == null and level.hud.hint.text.is_empty(),"looking away removes contextual text")
	check(level.hud.reticle.is_visible_in_tree(),"small center dot remains when no target")
	var before := assets.snapshot()
	await key(KEY_E)
	check(assets.snapshot() == before,"proximity alone does not interact")
	await aim(Vector3(.80,1.47,1.38),Vector3(-4,.02,1.38))
	check(level.player.get_interactable() == null,"interaction cannot pass wall or exceed ray distance")
	await key(KEY_E)
	check(assets.snapshot() == before,"distant E does nothing")
	await use("cash")
	await frames(32)
	level.show_pause()
	before = assets.snapshot()
	await key(KEY_E)
	check(assets.snapshot() == before,"pause menu blocks asset input")
	level.resume_game()
	assets.restore()
	for device in ["machine","grinder","fridge"]:
		await use(device)
		if level.hud.panel.visible: level.hud.close_panel()
	await use("window")
	await frames(42)
	await use("shift")
	await click("Открыть смену")
	level.session.catalog.config.customers.interval_seconds = 99999
	level.session.catalog.config.customers.profiles = [{"name":"Гость","color":"536f75","preferred":["latte_large"],"greeting":"Здравствуйте"}]
	level.session.spawn_customer()
	var id := await take_payment()
	check(id > 0,"existing cash payment completed")
	check(register.get_node("DisplayText").text == "140.00","LCD shows the existing order total")
	check(level.session.cash.balance() == 4540,"only the existing cash transaction changes till balance")
	await frames(32)
	check(not register.drawer_open,"cash UI closes animated drawer after settlement")
	if id > 0:
		await select_from_sidebar(id,0)
		for action in ["beans","grinder","filter","dose","machine","cups"]: await use(action)
		assert_cup(level.preparation_visual.get_node_or_null("CupUnderGroup"),false)
		var cup: Node3D = level.preparation_visual.get_node("CupUnderGroup")
		check(is_equal_approx(bounds(cup).position.y,level.machine_visual.cup_base().y),"cup foot touches drip-tray marker")
		check(bounds(cup).end.y < level.machine_visual.spout().y,"350 ml cup clears source spouts")
		var step: int = level.session.preparation.current.step
		await use("lids")
		check(level.session.preparation.current.step == step,"lid cannot be installed before brewing")
		# View from beside the protruding handle, which legitimately occludes
		# the cup when looking straight down the axis of the portafilter.
		await view(cup.global_position+Vector3(0,.065,0),Vector3(0,.4,-1.0),36)
		check(level.player.get_interactable() == null,"opaque cup blocks targets behind it")
		await shot("02-cup-under-machine")
		await use("machine")
		await save_roundtrip(2,"extraction without lid")
		assert_cup(level.preparation_visual.get_node_or_null("CupUnderGroup"),false)
		level.session.tick(9)
		await use("machine")
		if not level.fridge.opened:
			await use("fridge")
			await frames(35)
		for action in ["milk","pitcher","steam"]: await use(action)
		level.session.tick(2.5)
		for action in ["steam","pitcher"]: await use(action)
		await frames(45)
		check(level.session.preparation.next_step(level.session.catalog) == "lid","existing latte reaches its existing lid step")
		await use("lids")
		assert_cup(level.held.get_node_or_null("CupWithLid"),true)
		check(level.preparation_visual.get_node_or_null("CupUnderGroup") == null,"capped hand-held cup does not duplicate tray cup")
		await view(Vector3(.73,1.52,-1.47),Vector3(-.10,.4,-1.46),75)
		await shot("03-cup-with-lid")
		var hand_state := await save_roundtrip(3,"capped cup before serving")
		assert_cup(level.held.get_node_or_null("CupWithLid"),true)
		# New actual scene instance, same saved career, no re-consumption.
		var directory: String = level.save_manager.directory
		level.audio.stop_all()
		level.queue_free()
		await frames(3)
		level = load("res://scenes/first_shift.tscn").instantiate()
		root.add_child(level)
		current_scene = level
		await frames(4)
		level.save_manager.directory = directory
		level.save_manager.career = 1
		check(level.save_manager.load_slot(1,"manual",3),"new gameplay scene loads saved capped cup")
		var reloaded: Dictionary = level.capture_snapshot()
		check(JSON.stringify(reloaded) == JSON.stringify(hand_state),"fresh scene restores cup, inventory, quality, money and cabinet state exactly")
		if JSON.stringify(reloaded) != JSON.stringify(hand_state):
			print("FRESH EXPECTED: ",JSON.stringify(hand_state))
			print("FRESH ACTUAL: ",JSON.stringify(reloaded))
		level.resume_game()
		await frames(3)
		assert_cup(level.held.get_node_or_null("CupWithLid"),true)
		await use("ready")
		var finished: Node3D = level.drinks_root.get_node("Cup_%d_0" % id)
		assert_cup(finished,true)
		check(is_equal_approx(bounds(finished.get_node("Cup")).position.y,1.20),"finished cup touches serving worktop")
		await view(finished.global_position+Vector3(0,.065,0),Vector3(0,.4,finished.global_position.z),38)
		await shot("10-finished-cup")
		await save_roundtrip(2,"finished cup on serving rack")
		assert_cup(level.drinks_root.get_node("Cup_%d_0" % id),true)
		await serve(id)
		check(level.drinks_root.get_child_count() == 0,"handed-over cup disappears from rack")
		check(level.session.order_by_id(id).items[0].cup.quality.good,"new visuals preserve latte quality")
	check(level.session.stats.completed == 1,"latte, cash, change and customer handover complete")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await frames(2)
		check(level.hud.reticle.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()),"original dot remains centered at " + str(resolution))
	root.size = Vector2i(384,216)
	await view(Vector3(.03,1.35,-.55),Vector3(0,.4,1.96),75)
	check(not InputMap.has_action("vhs"),"obsolete effect action removed")
	await shot("11-work-area-cozy")
	check(level.validate_snapshot(level.capture_snapshot()),"final save validates")
	level.save_manager.autosave_enabled = false
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	print("NEW ASSETS INTEGRATION: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
