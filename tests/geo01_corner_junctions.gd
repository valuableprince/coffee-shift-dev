extends SceneTree
## GEO-01: real trailer asset, solid corner junctions and unobstructed portals.
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func has_collision(node: Node) -> bool:
	if node == null: return false
	for child in node.get_children():
		if child is CollisionShape3D and child.shape != null: return true
	return false

func run() -> void:
	var shell := load("res://assets/models/coffee_trailer/coffee_trailer.tscn").instantiate() as CoffeeShiftTrailerAsset
	root.add_child(shell)
	await physics_frame
	await physics_frame
	var junctions := shell.get_node_or_null("CornerJunctions")
	check(junctions != null, "solid corner-junction assembly created")
	if junctions == null:
		quit(1)
		return
	check(junctions.get_child_count() == 76, "four double-wall returns, four plinth corners and 64 ceiling connectors")
	for side in ["L", "R"]:
		for end in ["F", "R"]:
			var tag: String = str(side) + "_" + str(end)
			var end_return := junctions.get_node_or_null("EndReturn_" + tag)
			var side_return := junctions.get_node_or_null("SideReturn_" + tag)
			var base_return := junctions.get_node_or_null("BaseReturn_" + tag)
			check(end_return is StaticBody3D, "solid gable/wall return: " + tag)
			check(side_return is StaticBody3D, "solid side/wall return: " + tag)
			check(base_return != null, "continuous floor trim: " + tag)
			if end_return is StaticBody3D and side_return is StaticBody3D:
				check(has_collision(end_return) and has_collision(side_return),
					"both returns have physics collisions: " + tag)
	for end in ["F", "R"]:
		for i in range(32):
			var piece := junctions.get_node_or_null("RoofReturn_%s_%02d" % [end, i])
			check(piece is StaticBody3D and has_collision(piece),
				"continuous structural roof closure: %s/%d" % [end, i])
	check(is_equal_approx(shell._inner_roof_height(0.0), 2.64), "flat roof junction follows imported ceiling")
	check(absf(shell._inner_roof_height(1.14) - 2.15) < .001, "curved roof closure joins actual wall crown")
	check(shell.get_node("FixedShellCollision").get_child_count() == 1,
		"original imported GLB collider is retained once")
	check(shell.get_node("WindowHinge/HatchInteraction") != null and shell.get_node("RearDoorHinge/DoorInteraction") != null,
		"both original door interaction targets retained")
	# A ray through the actual staff-door opening must not strike the new
	# structural returns. No movable doorway leaf is included in layer 1.
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.4, 2.50), Vector3(0, 1.4, 2.95), 1)
	var hit := shell.get_world_3d().direct_space_state.intersect_ray(query)
	check(hit.is_empty(), "GEO-01 leaves the real staff doorway clear")
	# Open the actual service shutter before testing the aperture: the
	# closed shutter itself has a legitimate layer-1 interaction collider.
	shell.set_hatch_open(true, false)
	await physics_frame
	query = PhysicsRayQueryParameters3D.create(Vector3(1.00, 1.70, 0), Vector3(1.35, 1.70, 0), 1)
	hit = shell.get_world_3d().direct_space_state.intersect_ray(query)
	check(hit.is_empty(), "GEO-01 keeps the service hatch cut-out clear")
	shell.free()
	print("GEO01 CORNERS: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
