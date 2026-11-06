class_name CoffeeShiftSinkMixerTarget
extends StaticBody3D
## RayCast target for the tap's physical lever; no permanent world label.


func _ready() -> void:
	set_meta("action", "sink_mixer_lever")


func sink() -> CoffeeShiftSinkMixer:
	var item: Node = self
	while item != null:
		if item is CoffeeShiftSinkMixer:
			return item as CoffeeShiftSinkMixer
		item = item.get_parent()
	return null


func get_prompt() -> String:
	var mixer: CoffeeShiftSinkMixer = sink()
	return mixer.get_prompt() if mixer != null else ""


func interact() -> void:
	var mixer: CoffeeShiftSinkMixer = sink()
	if mixer != null:
		mixer.toggle_faucet()
