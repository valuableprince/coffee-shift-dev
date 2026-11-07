class_name BaristaAccessories
extends Node3D
## Presentation of existing DEV-03 steps; never owns ingredients or recipes.
const G := preload("res://scripts/prototype/prototype_geometry.gd")
const FILTER := preload("res://assets/models/portafilter/portafilter.tscn")
const TAMPER := preload("res://assets/models/tamper/tamper.tscn")
const PITCHER := preload("res://assets/models/milk_pitcher/milk_pitcher.tscn")
const MAT_CENTER := Vector3(-.635, 1.305, -.80)
const TAMPER_BASE := Vector3(-.78, 1.301, -.71)
const PITCHER_BASE := Vector3(.608, 1.30, -1.166)
const PITCHER_YAW := PI/2 - .10
const ANIMATION_SECONDS := .65
const FILTER_GRIP_ANGLES := Vector3(-.18, .68, -.12)
var world: Node3D
var filter: Node3D
var tamper: Node3D
var pitcher: Node3D
var grip: Node3D
var hand: Node3D
var grounds: Node3D
var milk: Node3D
var inspected := ""
var _animation := ""
var _remaining := 0.0

func configure(owner_world: Node3D) -> void:
	world = owner_world
	name = "BaristaAccessories"
	world.machine_visual.fit_accessories(FILTER)
	filter = FILTER.instantiate()
	filter.name = "HeldPortafilter"
	add_child(filter)
	grounds = G.cylinder(filter, "CoffeeGrounds", Vector3(0, .006, 0), .027, .005, Color("543425"), false)
	tamper = TAMPER.instantiate()
	add_child(tamper)
	pitcher = PITCHER.instantiate()
	add_child(pitcher)
	grip = Node3D.new()
	grip.name = "AccessoryHandGrip"
	grip.position = Vector3(.29, -.19, -.46)
	world.player.camera.add_child(grip)
	hand = Node3D.new()
	grip.add_child(hand)
	hand.scale = Vector3(.83, .86, .83)
	BaristaHand.build(hand)
	milk = G.cylinder(pitcher, "ExistingRecipeMilk", Vector3.ZERO, .038, .0015, Color("eee3cb"), false)
	# A satin adaptation for the prototype's colour-only ambient lighting.
	# Materials are duplicated per instance; imported GLBs remain untouched.
	for model in [filter, tamper, pitcher, world.machine_visual.portafilter]:
		for mesh in model.get_node("Model").find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var source := mesh.get_active_material(surface) as StandardMaterial3D
				if source != null and source.metallic > .5:
					var satin := source.duplicate() as StandardMaterial3D
					satin.metallic = minf(satin.metallic, .65)
					satin.roughness = maxf(satin.roughness, .38)
					mesh.set_surface_override_material(surface, satin)
	sync()

func reset() -> void:
	inspected = ""
	_animation = ""
	_remaining = 0

func take_or_return(action: String) -> void:
	inspected = "" if inspected == action else action
	sync()

func play(action: String) -> void:
	_animation = action
	_remaining = ANIMATION_SECONDS
	sync()

func _process(delta: float) -> void:
	if _remaining <= 0: return
	if not world.player.controls_enabled or not world.player.mouse_captured: return
	_remaining = maxf(0, _remaining - delta)
	if _remaining == 0: _animation = ""
	sync()

func _align(model: Node3D, marker: String, target: Vector3, orientation: Basis) -> void:
	model.global_basis = orientation
	model.global_position += target - model.get_node(marker).global_position

func _in_hand(model: Node3D, angles: Vector3) -> void:
	if model.get_parent() != grip: model.reparent(grip, false)
	_align(model, "HandGrip", grip.global_position, grip.global_basis * Basis.from_euler(angles))

func _on_station(model: Node3D, marker: String, point: Vector3, orientation: Basis) -> void:
	if model.get_parent() != self: model.reparent(self, false)
	_align(model, marker, point, orientation)

func _grinder_basket() -> Vector3:
	var grinder: Node3D = world.grinder_visual.get_node("CoffeeGrinder")
	return grinder.to_global(Vector3(0, .263, .222))

func grinder_grip_point() -> Vector3:
	return _grinder_basket() + Vector3(-.134, -.013, 0)

func _mat_basket() -> Vector3:
	return world.trailer.to_global(MAT_CENTER + Vector3(-.027, .089, 0))

func mat_grip_point() -> Vector3:
	return _mat_basket() + Vector3(.10, -.019, 0)

func sync() -> void:
	var current: Dictionary = world.session.preparation.current
	var step: String = world.session.preparation.next_step(world.session.catalog)
	if not current.is_empty(): inspected = ""
	var placement := str(current.get("portafilter", ""))
	var filter_in_hand := placement == "in_hand" or inspected == "filter" or (placement == "" and step in ["dose", "install"])
	var tamper_in_hand := inspected == "dose" or bool(current.get("tamper_held", false))
	var filter_visible := filter_in_hand or placement in ["in_grinder", "on_tamping_mat"] or _animation == "install"
	filter.visible = filter_visible
	world.machine_visual.portafilter.visible = not filter_visible
	grounds.visible = filter_visible and int(current.get("step", 0)) >= 2 and current.get("running", "") != "grind"
	grounds.position.y = -.007 if int(current.get("step", 0)) >= 4 else .006
	if filter_in_hand: _in_hand(filter, FILTER_GRIP_ANGLES)
	if placement == "in_grinder": _on_station(filter, "GroupLockOrigin", _grinder_basket(), Basis(Vector3.UP, -PI/2))
	if placement == "on_tamping_mat": _on_station(filter, "GroupLockOrigin", _mat_basket(), Basis(Vector3.UP, PI/2))
	_on_station(tamper, "PressContact", world.trailer.to_global(TAMPER_BASE), Basis.IDENTITY)
	_on_station(pitcher, "BaseContact", world.trailer.to_global(PITCHER_BASE), Basis(Vector3.UP, PITCHER_YAW))
	if tamper_in_hand: _in_hand(tamper, Vector3(.08, 0, .16))
	if inspected == "pitcher" or step in ["steam", "pour"]:
		_in_hand(pitcher, Vector3(.04, PI - .4, -.12))
	if step == "stop_steam":
		_on_station(pitcher, "SteamWandTarget", world.machine_visual.steam_tip(), Basis(Vector3.UP, -PI/2))
	hand.visible = filter_in_hand or tamper_in_hand or _animation in ["dose", "install"]
	hand.position = Vector3(0, .035, 0)
	hand.rotation = Vector3(0, .34, 0)
	var progress := 1.0 - _remaining / ANIMATION_SECONDS
	if _animation == "dose" and placement == "on_tamping_mat":
		var basket := _mat_basket()
		var top := basket + Vector3.UP * .07
		var press := grip.global_position - Vector3.UP * .084
		if progress < .28:
			press = press.lerp(top, smoothstep(0, .28, progress))
		elif progress < .72:
			press = top - Vector3.UP * .066 * sin(PI * inverse_lerp(.28, .72, progress))
		else:
			press = top.lerp(world.trailer.to_global(TAMPER_BASE), smoothstep(.72, 1, progress))
		_on_station(tamper, "PressContact", press, Basis.IDENTITY)
		var side: Vector3 = world.player.camera.global_basis.x * .033
		hand.global_position = tamper.get_node("HandGrip").global_position + side + Vector3.UP * .030
		hand.global_rotation = Vector3(-.13, world.player.rotation.y - .92, .16)
	if _animation == "install":
		var target: Node3D = world.machine_visual.portafilter
		_in_hand(filter, FILTER_GRIP_ANGLES)
		var initial: Vector3 = filter.get_node("GroupLockOrigin").global_position
		var locked: Vector3 = target.get_node("GroupLockOrigin").global_position
		var lock_turn := smoothstep(.6, 1.0, progress)
		var aligned := target.global_basis.orthonormalized().rotated(Vector3.UP, -.52 * (1.0 - lock_turn))
		var reach := smoothstep(0, .65, progress)
		var angle := filter.global_basis.orthonormalized().slerp(aligned, reach)
		var point := initial.lerp(locked - Vector3.UP * .038 * (1.0 - lock_turn), reach)
		_on_station(filter, "GroupLockOrigin", point, angle)
		hand.global_position = filter.get_node("HandGrip").global_position + Vector3.UP * .035
	if _animation == "pour" and not current.is_empty():
		var target: Vector3 = world.machine_visual.cup_base() + Vector3(0, .15, 0)
		_on_station(pitcher, "PourSpout", target, Basis(Vector3.FORWARD, -.7) * Basis(Vector3.UP, PI/2))
	milk.visible = not current.is_empty() and int(current.get("consumed", {}).get("milk", 0)) > 0 and (step in ["steam", "stop_steam", "pour"] or _animation == "pour")
	if milk.visible:
		var origin: Vector3 = pitcher.get_node("MilkSurfaceOrigin").position
		milk.position = origin + Vector3.UP * clampf(float(current.consumed.milk) / 600.0 * .10, .025, .070)
	# Keep the existing home targets for returning an inspected item and for
	# the existing pour operation. No second copy is left on the countertop.
	if world.stations.has("dose"):
		world.stations.filter.collision_layer = 2 if placement in ["", "at_machine_storage"] and not filter_in_hand else 0
		if inspected == "filter": world.stations.filter.collision_layer = 2
		world.stations.dose.collision_layer = 0 if _animation == "dose" or (tamper_in_hand and inspected == "") else 2
		world.stations.pitcher.collision_layer = 0 if step in ["steam", "stop_steam"] or _animation == "pour" else 2
