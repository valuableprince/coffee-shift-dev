class_name BaristaAccessories
extends Node3D
## Presentation of existing DEV-03 steps; never owns ingredients or recipes.
const G := preload("res://scripts/prototype/prototype_geometry.gd")
const FILTER := preload("res://assets/models/portafilter/portafilter.tscn")
const TAMPER := preload("res://assets/models/tamper/tamper.tscn")
const PITCHER := preload("res://assets/models/milk_pitcher/milk_pitcher.tscn")
const TAMPER_BASE := Vector3(.59, 1.324, -.94)
const PITCHER_BASE := Vector3(.608, 1.30, -1.166)
const PITCHER_YAW := PI/2 - .10
var world: Node3D
var filter: Node3D
var tamper: Node3D
var pitcher: Node3D
var grip: Node3D
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
	tamper = TAMPER.instantiate()
	add_child(tamper)
	pitcher = PITCHER.instantiate()
	add_child(pitcher)
	grip = Node3D.new()
	grip.name = "AccessoryHandGrip"
	grip.position = Vector3(.15, -.045, -.46)
	world.player.camera.add_child(grip)
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
	_remaining = .65

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
	_align(model, "HandGrip", grip.global_position, grip.global_basis * Basis.from_euler(angles))

func sync() -> void:
	var current: Dictionary = world.session.preparation.current
	var step: String = world.session.preparation.next_step(world.session.catalog)
	if not current.is_empty(): inspected = ""
	var filter_in_hand := step in ["dose", "install"] or inspected == "filter"
	filter.visible = filter_in_hand
	world.machine_visual.portafilter.visible = not filter_in_hand
	_in_hand(filter, Vector3(-.12, -.35, -.12))
	_align(tamper, "PressContact", TAMPER_BASE, Basis.IDENTITY)
	_align(pitcher, "BaseContact", PITCHER_BASE, Basis(Vector3.UP, PITCHER_YAW))
	if inspected == "dose": _in_hand(tamper, Vector3(.08, 0, .16))
	if inspected == "pitcher" or step in ["steam", "pour"]:
		_in_hand(pitcher, Vector3(.04, PI - .4, -.12))
	if step == "stop_steam":
		_align(pitcher, "SteamWandTarget", world.machine_visual.steam_tip(), Basis(Vector3.UP, -PI/2))
	if _animation == "dose" and filter_in_hand:
		# PressContact meets the existing dose inside the basket; no new step.
		var depth := .035 - sin((.65 - _remaining) / .65 * PI) * .050
		var target: Vector3 = filter.get_node("GroupLockOrigin").global_position + filter.global_basis.y * depth
		_align(tamper, "PressContact", target, filter.global_basis)
	if _animation == "pour" and not current.is_empty():
		var target: Vector3 = world.machine_visual.cup_base() + Vector3(0, .15, 0)
		_align(pitcher, "PourSpout", target, Basis(Vector3.FORWARD, -.7) * Basis(Vector3.UP, PI/2))
	milk.visible = not current.is_empty() and int(current.get("consumed", {}).get("milk", 0)) > 0 and (step in ["steam", "stop_steam", "pour"] or _animation == "pour")
	if milk.visible:
		var origin: Vector3 = pitcher.get_node("MilkSurfaceOrigin").position
		milk.position = origin + Vector3.UP * clampf(float(current.consumed.milk) / 600.0 * .10, .025, .070)
	# Keep the existing home targets for returning an inspected item and for
	# the existing pour operation. No second copy is left on the countertop.
	if world.stations.has("dose"):
		world.stations.dose.collision_layer = 0 if _animation == "dose" else 2
		world.stations.pitcher.collision_layer = 0 if step in ["steam", "stop_steam"] or _animation == "pour" else 2
