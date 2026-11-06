extends Node3D
## F6 standalone visual preview; no DEV gameplay scenes or placeholders touched.

var inside: bool = false


func _ready() -> void:
	$OutsideCamera.look_at(Vector3(0, 1.5, 0), Vector3.UP)
	$InsideCamera.look_at(Vector3(0, 1.72, -1.4), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		$Trailer.toggle_hatch()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		$Trailer.toggle_rear_door()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		inside = not inside
		$InsideCamera.current = inside
		$OutsideCamera.current = not inside
		get_viewport().set_input_as_handled()
