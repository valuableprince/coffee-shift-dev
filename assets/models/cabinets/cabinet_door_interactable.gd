class_name CoffeeShiftCabinetDoor
extends StaticBody3D
## Crosshair raycast target that rides along with its hinge.
## Layer 2 is detectable by the existing player raycast (collision_mask 3).
## Physical blocking of the player is handled by the cabinet body, not the leaf.

@export_enum("left", "right") var side: String = "left"


func _ready() -> void:
	set_meta("action", "cabinet_door")


func _cabinet() -> CoffeeShiftCabinet:
	return get_parent().get_parent() as CoffeeShiftCabinet


func get_prompt() -> String:
	var cabinet: CoffeeShiftCabinet = _cabinet()
	return cabinet.get_door_prompt(StringName(side)) if cabinet != null else ""


func interact() -> void:
	var cabinet: CoffeeShiftCabinet = _cabinet()
	if cabinet != null:
		cabinet.toggle_door(StringName(side))
