extends SceneTree
## Integration checks on the real scene, input events, raycasts and physics.
## godot --headless --path . --fixed-fps 60 --script tests/dev01_smoke.gd

var checks := 0
var failures := 0
var level: Node3D
var player: CoffeeShiftPlayer
var state: RestorationState
var window: InspectablePart
var shots := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			shots = argument.trim_prefix("--screenshots=")
	call_deferred("_run")

func _run() -> void:
	level = load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	state = level.get_node("RestorationState")
	window = level.get_node("CoffeeTrailer/ServiceWindow")
	await _frames(5)
	_check(player.is_on_floor(), "spawn settles on the garage floor")
	_check(player.mouse_captured, "mouse capture requested at spawn")
	_check(int(InputMap.action_get_events("sprint")[0].physical_keycode) == KEY_SHIFT, "Shift binding")
	_check(not InputMap.has_action("vhs"), "obsolete effect binding removed")
	var viewport_size := root.get_visible_rect().size
	_check(level.hud.hint.get_global_rect().position.y > viewport_size.y * 0.5, "interaction hint anchored inside lower viewport")
	var reticle: InteractionReticle = level.hud.reticle
	_check(reticle.get_global_rect().get_center().is_equal_approx(viewport_size * 0.5), "geometric dot anchored at viewport centre")
	await _screenshot("01-garage")
	_geometry_checks()
	var before := player.position
	await _hold("forward", 12)
	_check(player.position.distance_to(before) > 0.35, "W moves the actual character")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(30, -12)
	Input.parse_input_event(mouse)
	await _frames(2)
	_check(absf(player.pitch) > 0.01, "mouse motion changes camera pitch")
	await _place(Vector3(2.5, 0.02, 0), Vector3(1.185, 1.65, 0))
	_check(player.get_interactable() == window, "ray reaches window from outside")
	await _tap("interact")
	_check(state.notebook_entries().is_empty(), "ordinary interaction cannot discover a defect")
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	q.pressed = true
	Input.parse_input_event(q)
	await _frames(2)
	q.pressed = false
	Input.parse_input_event(q)
	await _frames(2)
	_check(level.inspection_enabled and window.get_node("Highlight").visible, "physical Q enables inspection and highlight")
	await _tap("interact")
	_check(state.status_of(window.element_id) == RestorationState.Status.DEFECT_FOUND, "E discovers the dirty pane")
	_check(state.notebook_entries().size() == 1, "one task added to notebook")
	await _screenshot("02-dirty-window")
	await _hold("interact", 200)
	_check(is_zero_approx(window.work_progress), "cleaning without a tool is blocked")
	await _tap("notebook")
	_check(level.hud.notebook.visible and not player.controls_enabled, "N opens paper and blocks controls")
	_check(level.hud.notebook.paper.size.x > 600 and level.hud.notebook.paper.size.y > 350, "paper spread has readable viewport layout")
	before = player.position
	await _hold("forward", 20)
	_check(player.position.distance_to(before) < 0.02, "notebook prevents movement")
	var was_inspecting: bool = level.inspection_enabled
	await _tap("inspect_mode")
	_check(level.inspection_enabled == was_inspecting, "notebook blocks inspection toggles")
	await _tap("ui_cancel")
	_check(not level.hud.notebook.visible and player.controls_enabled, "Esc closes notebook and restores controls")
	await _tap("ui_cancel")
	_check(not player.mouse_captured, "Esc releases cursor")
	before = player.position
	await _hold("forward", 12)
	_check(player.position.distance_to(before) < 0.02, "released cursor prevents movement")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(2)
	click.pressed = false
	Input.parse_input_event(click)
	_check(player.mouse_captured, "left click recaptures cursor")
	await _place(Vector3(3.0, 0.02, -0.48), Vector3(4.12, 1.15, -0.48))
	var kit: WorkshopPickup = level.get_node("Garage/CleaningKit")
	_check(player.get_interactable() == kit, "cleaning kit reachable above workbench")
	await _tap("interact")
	_check(state.has_tool(&"cleaning_kit") and kit.taken and not kit.visible, "E physically picks up kit")
	_check(not state.acquire_tool(&"cleaning_kit"), "duplicate pickup rejected")
	await _place(Vector3(2.5, 0.02, 0), Vector3(1.185, 1.65, 0))
	_send_action("interact", true)
	await _frames(35)
	_check(window.work_progress > 0.10 and window.work_progress < 0.9, "holding E advances work")
	player.position = Vector3(4.8, 0.02, 0)
	await _frames(3)
	var paused := window.work_progress
	await _frames(30)
	_check(is_equal_approx(paused, window.work_progress), "losing target/range stops work")
	_send_action("interact", false)
	await _place(Vector3(2.5, 0.02, 0), Vector3(1.185, 1.65, 0))
	_send_action("interact", true)
	await _frames(15)
	await _tap("notebook")
	paused = window.work_progress
	await _frames(40)
	_check(is_equal_approx(paused, window.work_progress), "opening notebook interrupts cleaning")
	await _tap("notebook")
	await _frames(10)
	_check(is_equal_approx(paused, window.work_progress), "closing notebook cannot resume a stale E hold")
	_send_action("interact", false)
	await _frames(2)
	await _hold("interact", 200)
	_check(state.status_of(window.element_id) == RestorationState.Status.RESTORED, "cleaning finishes on the real pane")
	_check(not window.get_node("Dirt").visible, "3D dirt mesh removed on completion")
	_check(level.hud.notebook.entries.text.contains("[s]"), "paper task automatically struck through")
	await _tap("inspect_mode")
	_check(not window.get_node("Highlight").visible, "Q removes inspection highlight")
	await _screenshot("03-clean-window")
	await _tap("notebook")
	await _screenshot("04-completed-notebook")
	await _tap("notebook")
	await _hold("interact", 200)
	_check(state.notebook_entries().size() == 1 and not window.get_node("Dirt").visible, "repeat E cannot recreate task or dirt")
	_check(not level.hud.has_method("adjust_vhs"), "obsolete HUD effect removed")
	await _traversal_checks()
	await _reusable_trailer_check()
	level.queue_free()
	await _frames(3)
	var legacy: Node3D = load("res://scenes/legacy/cafe_prototype.tscn").instantiate()
	root.add_child(legacy)
	current_scene = legacy
	await _frames(4)
	_check(legacy.recipes.size() == 3 and legacy.player != null and legacy.game != null, "legacy cafe/economy/recipes still instantiate")
	legacy.queue_free()
	await _frames(3)
	print("DEV-01 RESULT: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _geometry_checks() -> void:
	var bounds := AABB()
	var first := true
	var shell: Node3D = level.get_node("CoffeeTrailer/Shell")
	for node in shell.get_node("ShellVisual").find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var transform: Transform3D = level.trailer.global_transform.affine_inverse() * mesh.global_transform
		var box := transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	# The 2.4 x 5.5 m body has projecting frames and trim in the original GLB.
	_check(bounds.size.x >= 2.4 and bounds.size.x < 2.53, "2.4 m body plus original window trim")
	_check(absf(bounds.size.z - 5.5) < 0.10, "5.5 m body plus original end trim; excludes chassis")
	_check(absf(bounds.end.y - 2.7) < 0.002, "measured roof elevation 2.7 m")
	var floor_mesh: MeshInstance3D = shell.get_node("ShellVisual").find_child("Rubber_Floor", true, false)
	_check(absf(floor_mesh.get_aabb().end.y - 0.4) < 0.001, "finished floor top elevation 0.40 m")
	var left: Node3D = level.trailer.get_node("OppositeWorktop")
	var right: Node3D = level.trailer.get_node("ServingWorktop")
	var left_edge: float = left.position.x + left.get_node("Mesh").mesh.size.x / 2.0
	var right_edge: float = right.position.x - right.get_node("Mesh").mesh.size.x / 2.0
	_check(absf(right_edge - left_edge - 0.95) < 0.001, "measured clear worktop aisle 0.95 m")
	var collision: CollisionShape3D = shell.get_node("FixedShellCollision/ShellCollider")
	var faces: PackedVector3Array = collision.shape.get_faces()
	var aperture_clear := true
	for index in range(0, faces.size(), 3):
		var center := (faces[index] + faces[index+1] + faces[index+2]) / 3
		if center.x > 1.13 and center.x < 1.21 and absf(center.z) < .77 and center.y > 1.23 and center.y < 2.07:
			aperture_clear = false
	_check(aperture_clear, "original 1.6 x .9 m window aperture remains open in shell collider")
	_check(absf(right.position.y + 0.03 - 1.20) < 0.001 and absf(left.position.y + 0.03 - 1.30) < 0.001, "approved serving/preparation worktop elevations")

func _traversal_checks() -> void:
	await _place(Vector3(0, 0.02, 4.7))
	await _hold("forward", 90)
	_check(player.position.z > 3.05 and player.position.z < 3.3, "closed rear door blocks entry")
	player.camera.look_at(Vector3(0, 1.35, 2.78))
	await _frames(2)
	var door: TrailerDoor = level.get_node("CoffeeTrailer/StaffDoor")
	_check(player.get_interactable() == door, "rear door interactable from ramp")
	await _tap("interact")
	await _frames(45)
	_check(door.opened, "E opens staff door")
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await _hold("forward", 60)
	_check(player.position.z < 1.0 and absf(player.position.y - 0.4) < 0.03, "actual character climbs ramp and enters trailer")
	await _place(Vector3(0, 0.41, 1.6))
	await _hold("forward", 64)
	_check(player.position.z < -1.45 and player.position.y > 0.38, "capsule walks full central aisle")
	await _place(Vector3(0, 0.41, 0))
	await _screenshot("05-trailer-interior")
	await _hold("right", 25)
	_check(player.position.x > 0.10 and player.position.x < 0.17, "serving furniture collision preserves aisle boundary")
	await _place(Vector3(0, 0.41, 0))
	await _hold("left", 25)
	_check(player.position.x < -0.10 and player.position.x > -0.17, "opposite furniture/fridge collision preserves aisle")
	await _place(Vector3(0, 0.41, 1.0), Vector3(0, 1.8, 5.0))
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await _hold("back", 85)
	_check(player.position.z > 4.9 and player.position.y < 0.03, "player exits via ramp without jump or teleport")
	await _place(Vector3(2.5, 0.02, -1.4))
	await _hold("left", 40)
	_check(player.position.x > 1.50 and player.position.x < 1.57, "trailer shell blocks walking through wall")
	await _place(Vector3(3.0, 0.02, -1.3))
	await _hold("right", 30)
	_check(player.position.x < 3.43 and player.position.x > 3.35, "workbench has solid collision")
	await _place(Vector3(-3, 0.02, 5))
	await _hold("left", 90)
	_check(player.position.x > -4.94 and player.position.x < -4.85, "garage wall contains character")
	await _place(Vector3(-2.0, 0.02, 0), Vector3(1.185, 1.65, 0))
	_check(player.get_interactable() != window, "ray cannot inspect through opposite metal wall")

func _reusable_trailer_check() -> void:
	var second: CoffeeTrailer = load("res://scenes/trailer/coffee_trailer.tscn").instantiate()
	second.trailer_id = &"trailer_02"
	second.position = Vector3(20, 0, 0)
	root.add_child(second)
	var pane: InspectablePart = second.get_node("ServiceWindow")
	pane.bind(state, second.trailer_id)
	_check(state.status_of(pane.element_id) == RestorationState.Status.UNINSPECTED, "second trailer has independent element identity")
	_check(pane.get_node("Dirt").visible and is_zero_approx(pane.work_progress), "reused scene does not inherit cleaned appearance")
	_check(pane.get_node("Dirt").material_override != window.get_node("Dirt").material_override, "dirt shader is local to each scene")
	second.queue_free()
	await _frames(2)

func _place(position: Vector3, aim: Vector3 = Vector3.ZERO) -> void:
	player.position = position
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	if aim != Vector3.ZERO:
		player.camera.look_at(aim)
	await _frames(4)

func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(action: StringName) -> void:
	_send_action(action, true)
	await _frames(2)
	_send_action(action, false)
	await _frames(2)

func _hold(action: StringName, frames: int) -> void:
	_send_action(action, true)
	await _frames(frames)
	_send_action(action, false)
	await _frames(2)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func _screenshot(label: String) -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots)
	root.get_texture().get_image().save_png(shots.path_join(label + ".png"))

