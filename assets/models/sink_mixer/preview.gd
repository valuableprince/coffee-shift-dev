extends Node3D
## Run standalone preview scene (F6). Enter/Space toggles the faucet handle.
## This does NOT simulate a water supply or gameplay washing state.


func _ready() -> void:
	$Camera.look_at(Vector3(0, 0.048, 0), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		$Sink.toggle_faucet()
		get_viewport().set_input_as_handled()
