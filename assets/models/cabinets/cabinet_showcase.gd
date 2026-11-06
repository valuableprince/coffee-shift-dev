extends Node3D
## Press Enter/Space (ui_accept) in this standalone preview to toggle all doors.
## These controls do not need to be added to the production game's player script.

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		for cabinet in [$BaseCabinet, $WallCabinet]:
			cabinet.toggle_door(&"left")
			cabinet.toggle_door(&"right")
		get_viewport().set_input_as_handled()
