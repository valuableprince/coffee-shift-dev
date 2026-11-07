class_name CoffeeShiftTrailerAsset
extends Node3D
## Reusable 5.5 m trailer shell asset. Origin: ground at the geometric body centre.
## Local +X: service window. Local +Z: staff entry. Neither includes kitchen equipment.
## Interaction targets are on layer 2, while shell collision is on layer 1.
const G := preload("res://scripts/prototype/prototype_geometry.gd")

signal hatch_state_changed(opened: bool)
signal rear_door_state_changed(opened: bool)

@export var hatch_starts_open: bool = false
@export var rear_door_starts_open: bool = false
@export_range(0.2, 2.0, 0.05) var hatch_seconds: float = 0.85
@export_range(0.2, 2.0, 0.05) var door_seconds: float = 0.68
@export var handle_first_person_input: bool = true

var hatch_open: bool = false
var rear_door_open: bool = false
var _hatch_tween: Tween
var _door_tween: Tween


func _ready() -> void:
	_build_corner_junctions()
	_build_shell_collision()
	set_hatch_open(hatch_starts_open, false)
	set_rear_door_open(rear_door_starts_open, false)


# Close the four actual wall-to-gable joints and the curved roof-to-end
# joints. These are solid, overlapping return panels with their own collisions,
# not uncollidable visual strips pasted across empty holes. The original
# window, staff doorway, shell GLB and shell collision remain unchanged.
static func _inner_roof_height(x: float) -> float:
	var shoulder := maxf(0.0, absf(x) - .65)
	return 2.15 + sqrt(maxf(0.0, .49 * .49 - shoulder * shoulder))


func _build_corner_junctions() -> void:
	var junctions := Node3D.new()
	junctions.name = "CornerJunctions"
	add_child(junctions)
	var wall_color := Color("d8d9ca")
	var ceiling_color := Color("e6e6d6")
	var base_color := Color("9ba69b")
	# The inner longitudinal skin ends at X ~= +/-1.14; the gables meet
	# the inner lining at Z ~= +/-2.69. Each pair of returns overlaps both
	# skins, including the lower wall and the start of the roof shoulder.
	for side in [-1, 1]:
		for end in [-1, 1]:
			var tag := ("%s_%s" % ["L" if side < 0 else "R", "F" if end < 0 else "R"])
			G.box(junctions, "EndReturn_" + tag,
				Vector3(float(side) * 1.035, 1.275, float(end) * 2.675),
				Vector3(.23, 1.75, .14), wall_color)
			G.box(junctions, "SideReturn_" + tag,
				Vector3(float(side) * 1.12, 1.275, float(end) * 2.56),
				Vector3(.085, 1.75, .30), wall_color)
			# The lower return also joins the existing floor trim at 90 degrees.
			G.box(junctions, "BaseReturn_" + tag,
				Vector3(float(side) * 1.035, .43, float(end) * 2.64),
				Vector3(.23, .06, .22), base_color, false)
	# Carry the joint continuously over the inner roof's original 0.49 m
	# quarter-circle shoulders and the flat centre. In particular, the
	# rear cross-piece is entirely ABOVE the 2.30 m staff-door head.
	var source := $ShellVisual.find_child("Inner_Ceiling", true, false) as MeshInstance3D
	var roof_material: Material = null
	if source != null and source.mesh != null and source.mesh.get_surface_count() > 0:
		# Read the import resource, not RenderingServer active material; headless
		# tests run on the dummy renderer without live mesh material storage.
		roof_material = source.mesh.surface_get_material(0)
	var sections := 32
	for end in [-1, 1]:
		for i in range(sections):
			var x0 := -1.14 + 2.28 * float(i) / float(sections)
			var x1 := -1.14 + 2.28 * float(i + 1) / float(sections)
			var y0 := _inner_roof_height(x0)
			var y1 := _inner_roof_height(x1)
			var piece := G.box(junctions, "RoofReturn_%s_%02d" % ["F" if end < 0 else "R", i],
				Vector3((x0 + x1) * .5, (y0 + y1) * .5 - .028, float(end) * 2.68),
				Vector3(Vector2(x1 - x0, y1 - y0).length() + .012, .065, .16), ceiling_color)
			piece.rotation.z = atan2(y1 - y0, x1 - x0)
			if roof_material != null:
				(piece.get_node("Mesh") as MeshInstance3D).material_override = roof_material


func _build_shell_collision() -> void:
	# One fixed collider follows the original art exactly, including roof shoulders,
	# door header and the complete floor. No old or overlapping graybox colliders.
	var faces := PackedVector3Array()
	for visual in $ShellVisual.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = global_transform.affine_inverse() * visual.global_transform
		for vertex in visual.mesh.get_faces():
			faces.append(local * vertex)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.name = "ShellCollider"
	collider.shape = shape
	$FixedShellCollision.add_child(collider)


func set_hatch_open(value: bool, animated: bool = true) -> void:
	if _hatch_tween != null and _hatch_tween.is_running():
		_hatch_tween.kill()
	hatch_open = value
	# Only the closed endpoint blocks the player; the moving leaf has ray targets
	# without a physical sweep, like the established safe staff-door controller.
	$WindowHinge/HatchInteraction.collision_layer = 2
	# Around the horizontal Z hinge: +77 degrees lifts the bottom outward (+X).
	var angle: float = deg_to_rad(77.0) if value else 0.0
	if animated and is_inside_tree():
		_hatch_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hatch_tween.tween_property($WindowHinge, "rotation:z", angle, hatch_seconds)
		_hatch_tween.finished.connect(func() -> void:
			$WindowHinge/HatchInteraction.collision_layer = 2 if hatch_open else 3)
	else:
		$WindowHinge.rotation.z = angle
		$WindowHinge/HatchInteraction.collision_layer = 2 if value else 3
	hatch_state_changed.emit(hatch_open)


func set_rear_door_open(value: bool, animated: bool = true) -> void:
	if _door_tween != null and _door_tween.is_running():
		_door_tween.kill()
	rear_door_open = value
	# Door extends +X from the left hinge: negative Y rotation opens outside (+Z).
	var angle: float = deg_to_rad(-100.0) if value else 0.0
	if animated and is_inside_tree():
		_door_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_door_tween.tween_property($RearDoorHinge, "rotation:y", angle, door_seconds)
	else:
		$RearDoorHinge.rotation.y = angle
	rear_door_state_changed.emit(rear_door_open)


func toggle_hatch() -> void:
	set_hatch_open(not hatch_open)


func toggle_rear_door() -> void:
	set_rear_door_open(not rear_door_open)


func target_prompt(part: StringName) -> String:
	if part == &"window":
		return "[E] Закрыть окно выдачи" if hatch_open else "[E] Открыть окно выдачи"
	if part == &"rear_door":
		return "[E] Закрыть входную дверь" if rear_door_open else "[E] Открыть входную дверь"
	return ""


func toggle_target(part: StringName) -> void:
	match part:
		&"window":
			toggle_hatch()
		&"rear_door":
			toggle_rear_door()


func _physics_process(_delta: float) -> void:
	# Self-contained compatibility adapter for an FPS controller using "interact".
	# The main game may instead call CoffeeShiftTrailerTarget.interact().
	if not handle_first_person_input or not Input.is_action_just_pressed("interact"):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin: Vector3 = camera.global_position
	var endpoint: Vector3 = origin - camera.global_transform.basis.z * 2.7
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, endpoint, 3)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Object = result.get("collider")
	if target is CoffeeShiftTrailerTarget:
		var interact_target: CoffeeShiftTrailerTarget = target as CoffeeShiftTrailerTarget
		if interact_target.trailer() == self:
			interact_target.interact()
