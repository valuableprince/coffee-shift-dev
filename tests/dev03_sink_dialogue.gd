extends SceneTree
## Original sink in a running trade world; real Godot GL frames only.
var checks := 0
var failures := 0
var screenshots := ""
var level: ShiftWorld

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots = arg.trim_prefix("--screenshots=")
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int = 2) -> void:
	for i in range(count): await physics_frame

func aim(point: Vector3, standing: Vector3) -> void:
	level.player.position = standing
	level.player.velocity = Vector3.ZERO
	var vector := point - (standing + Vector3(0,1.62,0))
	level.player.rotation.y = atan2(-vector.x,-vector.z)
	level.player.pitch = atan2(vector.y,Vector2(vector.x,vector.z).length())
	level.player.camera.rotation = Vector3(level.player.pitch,0,0)
	await frames(4)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func shot(name: String) -> void:
	if screenshots == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await frames(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots.path_join(name + ".png")) == OK,
		"real GL viewport PNG: " + name)

func run() -> void:
	root.size = Vector2i(1280,720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	check(level.new_game(1), "start normal trade scene")
	var assets := level.new_assets
	var sink: CoffeeShiftSinkMixer = assets.sink
	check(sink != null, "one original sink is mounted in trade scene")
	if sink == null:
		quit(1)
		return
	check(sink.scene_file_path.ends_with("assets/models/sink_mixer/sink_with_mixer.tscn"), "reuses complete original scene from PR 76")
	check(sink.get_node("Basin").scene_file_path.ends_with("stainless_sink_basin.glb"), "reuses original basin GLB")
	check(sink.get_node("FaucetBody").scene_file_path.ends_with("gooseneck_mixer_body.glb"), "reuses original faucet GLB")
	check(sink.get_node("LeverPivot/MixerLever").scene_file_path.ends_with("mixer_lever.glb"), "reuses original lever GLB")
	check(sink.position.is_equal_approx(Vector3(-.86,1.30,1.35)), "sink occupies approved original station")
	check(sink.scale.is_equal_approx(Vector3.ONE), "sink imported at true metre scale")
	check(level.trailer.get_node_or_null("OppositeWorktop") == null, "solid old countertop removed, including collider")
	var slabs := ["SinkWorktopBefore","SinkWorktopAfter","SinkWorktopLeft","SinkWorktopRight"]
	var cutout := Rect2(Vector2(-1.0425,1.165),Vector2(.365,.370))
	var surface_area := 0.0
	for id in slabs:
		var plate := level.trailer.get_node_or_null(id) as StaticBody3D
		check(plate != null, id + " is a physical countertop plate")
		if plate == null: continue
		var box := (plate.get_node("Mesh") as MeshInstance3D).mesh as BoxMesh
		var size: Vector3 = box.size
		var rect := Rect2(Vector2(plate.position.x-size.x*.5,plate.position.z-size.z*.5),Vector2(size.x,size.z))
		check(rect.intersection(cutout).get_area() < 0.000001, id + " mesh does not fill basin opening")
		check(plate.find_children("*", "CollisionShape3D", false, false).size() == 1, id + " has matching physics collider")
		surface_area += size.x * size.z
	check(absf(surface_area - (.665*3.7 - .370*.365)) < .0001, "four plates exactly account for original top minus cutout")
	check(level.trailer.get_children().filter(func(n: Node) -> bool: return n is CoffeeShiftSinkMixer).size() == 1, "no duplicate sink")
	var basin_cabinet: CoffeeShiftCabinet = assets.cabinets["BaseOppositeRear"]
	check(basin_cabinet.get_node("BodyCollider").get_child_count() == 5, "cabinet upper shelf physics collider removed below bowl")
	var body_visual: Node3D = basin_cabinet.get_node("BodyVisual")
	var roof_triangles := 0
	for mesh_node in body_visual.find_children("*", "MeshInstance3D", true, false):
		var imported_mesh: Mesh = (mesh_node as MeshInstance3D).mesh
		for surface in range(imported_mesh.get_surface_count()):
			var arr := imported_mesh.surface_get_arrays(surface)
			var pts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var faces: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for i in range(0, faces.size(), 3):
				if pts[faces[i]].y > .77 and pts[faces[i + 1]].y > .77 and pts[faces[i + 2]].y > .77:
					roof_triangles += 1
	check(roof_triangles == 0, "original cabinet visual adapted without upper shelf covering sink bowl")
	check(not sink.enable_fps_input_adapter, "single global E dispatcher")
	check(sink.get_node("LeverPivot/LeverInteractable").collision_layer == 2, "faucet lever is targeted by player ray")
	check(level.stations.has("syrup") and is_equal_approx(level.stations.syrup.position.z,.38), "syrup shifted clear of sink")
	check(level.stations.has("carrier") and is_equal_approx(level.stations.carrier.position.z,.08), "carrier shifted clear of sink")
	await aim(sink.get_node("Basin").global_position, Vector3(0,.4,1.8))
	await shot("sink-01-workstation-720")
	root.size = Vector2i(1920,1080)
	await shot("sink-01-workstation-1080")
	root.size = Vector2i(1280,720)
	await aim(sink.to_global(Vector3(0,-.08,.03)),Vector3(0,.4,1.35))
	await shot("sink-02-recessed-bowl")
	var target := sink.get_node("LeverPivot/LeverInteractable") as CoffeeShiftSinkMixerTarget
	await aim(sink.get_node("HandReachFaucet").global_position,Vector3(0,.4,1.15))
	check(level.player.get_interactable() == target,"crosshair reaches lever from working aisle")
	check(level.hud.hint.text.contains("смеситель"),"lever prompt appears on center crosshair only")
	check(level.hud.reticle.is_visible_in_tree(), "permanent center dot is retained")
	await shot("sink-03-lever-hover")
	var before := sink.faucet_on
	await key(KEY_E)
	check(sink.faucet_on != before,"one E toggles faucet exactly once")
	await frames(23)
	check(absf(sink.get_node("LeverPivot").rotation.x + deg_to_rad(28)) < .005,"28 degree lever motion finishes in 0.30 s")
	await shot("sink-04-lever-on")
	var saved: Dictionary = level.capture_snapshot()
	check(bool(saved.world.assets.faucet_on),"faucet state included in career snapshot")
	check(level.save_manager.save_slot("manual",1,true) == OK, "faucet state written to saved career")
	sink.set_faucet_on(false,false)
	check(level.save_manager.load_slot(1,"manual",1), "career save reload succeeds")
	check(sink.faucet_on and JSON.stringify(level.capture_snapshot()) == JSON.stringify(saved),"faucet state restored exactly")
	var legacy := saved.duplicate(true)
	legacy.world.assets.erase("faucet_on")
	check(level.apply_snapshot(legacy) and not sink.faucet_on,"old career save without faucet field still loads")
	var invalid := saved.duplicate(true)
	invalid.world.assets.faucet_on = "yes"
	var unchanged := level.capture_snapshot()
	check(not level.apply_snapshot(invalid) and level.capture_snapshot() == unchanged,"invalid faucet state rejected atomically")
	var global_settings := CoffeeShiftSettings.new()
	global_settings.dialogue_word_reveal = false
	global_settings.dialogue_word_interval = .21
	global_settings.last_career = 3
	check(global_settings.save_to_disk() == OK,"dialogue preferences saved outside career data")
	var restored_settings := CoffeeShiftSettings.new()
	restored_settings.load_from_disk()
	check(not restored_settings.dialogue_word_reveal and is_equal_approx(restored_settings.dialogue_word_interval,.21),"word effect and interval survive restart")
	check(restored_settings.last_career == 3,"dialogue preferences do not overwrite career selection")
	level.game_settings.dialogue_word_reveal = false
	level.game_settings.dialogue_word_interval = .21
	level.apply_settings()
	check(not level.hud.dialogue_word_reveal and is_equal_approx(level.hud.dialogue_word_interval,.21),"menu applies dialogue settings to live HUD")
	await aim(Vector3(0,2.3,-1),Vector3(0,.4,1.15))
	check(level.player.get_interactable() != target,"lever cannot be toggled without aiming")
	var state := sink.faucet_on
	await key(KEY_E)
	check(sink.faucet_on == state,"E does not toggle mixer without hover")
	print("DEV03 SINK DIALOGUE: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
