class_name CoffeeShiftTrailerAsset
extends Node3D
## Reusable 5.5 m trailer shell asset. Origin: ground at the geometric body centre.
## Local +X: service window. Local +Z: staff entry. Neither includes kitchen equipment.
## Interaction targets are on layer 2, while shell collision is on layer 1.

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
	_build_shell_collision()
	set_hatch_open(hatch_starts_open, false)
	set_rear_door_open(rear_door_starts_open, false)


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
