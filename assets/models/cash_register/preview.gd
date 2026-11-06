extends Node3D
## Standalone F6 preview. Enter/Space toggles the mechanical drawer.

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		$Register.toggle_drawer()
		get_viewport().set_input_as_handled()
