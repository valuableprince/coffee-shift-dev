class_name CoffeeShiftCabinet
extends Node3D
## Independent 105-degree hinged doors. Front of the cabinet is local +Z.
## The visuals are imported GLBs; only hinge nodes rotate.

signal door_state_changed(side: StringName, opened: bool)

@export var display_name: String = "шкафчик"
@export_range(75.0, 115.0, 1.0) var opening_degrees: float = 105.0
@export_range(0.1, 2.0, 0.05) var opening_seconds: float = 0.60
@export var allow_first_person_interaction: bool = true

var left_open: bool = false
var right_open: bool = false
var _left_tween: Tween
var _right_tween: Tween


func _ready() -> void:
	$LeftHinge.rotation.y = 0.0
	$RightHinge.rotation.y = 0.0


func is_door_open(side: StringName) -> bool:
	return left_open if side == &"left" else right_open


func toggle_door(side: StringName) -> void:
	if side != &"left" and side != &"right":
		return
	set_door_open(side, not is_door_open(side))


func open_door(side: StringName) -> void:
	set_door_open(side, true)


func close_door(side: StringName) -> void:
	set_door_open(side, false)


func set_door_open(side: StringName, opened: bool, animated: bool = true) -> void:
	if side != &"left" and side != &"right":
		return
	var is_left: bool = side == &"left"
	var hinge: Node3D = $LeftHinge if is_left else $RightHinge
	var angle: float = deg_to_rad(opening_degrees) * (-1.0 if is_left else 1.0) if opened else 0.0
	if is_left:
		if _left_tween != null:
			_left_tween.kill()
			_left_tween = null
		left_open = opened
	else:
		if _right_tween != null:
			_right_tween.kill()
			_right_tween = null
		right_open = opened
	if animated and is_inside_tree():
		var animation: Tween = create_tween()
		animation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		animation.tween_property(hinge, "rotation:y", angle, opening_seconds)
		if is_left:
			_left_tween = animation
		else:
			_right_tween = animation
	else:
		hinge.rotation.y = angle
	door_state_changed.emit(side, opened)


func get_door_prompt(side: StringName) -> String:
	var title: String = "левая" if side == &"left" else "правая"
	var action: String = "Закрыть" if is_door_open(side) else "Открыть"
	return "[E] %s %s (%s дверца)" % [action, display_name, title]


func _unhandled_input(event: InputEvent) -> void:
	# Asset-scene input adapter: DEV-03 currently dispatches only known classes.
	# Open only if the FPS crosshair targets OUR door, not nearby equipment.
	# Do not act while a menu has released the mouse.
	if not allow_first_person_interaction or not event.is_action_pressed("interact"):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin: Vector3 = camera.global_position
	var endpoint: Vector3 = origin - camera.global_transform.basis.z * 2.65
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, endpoint, 3)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Object = result.get("collider")
	if target is CoffeeShiftCabinetDoor:
		var door: CoffeeShiftCabinetDoor = target as CoffeeShiftCabinetDoor
		if door.get_parent().get_parent() == self:
			door.interact()
			get_viewport().set_input_as_handled()
