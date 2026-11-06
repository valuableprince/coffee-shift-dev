class_name CoffeeShiftTrailerTarget
extends StaticBody3D
## Context-sensitive target only; the moving door/hatch target never pushes the player.
## Layer 2 lets the existing player raycast see the component (mask 3).

@export_enum("window", "rear_door") var part: String = "window"

var interaction_delegate: Node3D


func _ready() -> void:
	set_meta("action", "trailer_" + part)


func trailer() -> CoffeeShiftTrailerAsset:
	var current: Node = self
	while current != null:
		if current is CoffeeShiftTrailerAsset:
			return current as CoffeeShiftTrailerAsset
		current = current.get_parent()
	return null


func get_prompt() -> String:
	if is_instance_valid(interaction_delegate):
		return interaction_delegate.get_prompt()
	var owner: CoffeeShiftTrailerAsset = trailer()
	return owner.target_prompt(StringName(part)) if owner != null else ""


func interact() -> void:
	if is_instance_valid(interaction_delegate):
		interaction_delegate.interact()
		return
	var owner: CoffeeShiftTrailerAsset = trailer()
	if owner != null:
		owner.toggle_target(StringName(part))


func get_interaction_name() -> String:
	if is_instance_valid(interaction_delegate):
		return interaction_delegate.get_interaction_name()
	return "Створка окна" if part == "window" else "Задняя дверь"


func get_available_action() -> String:
	if is_instance_valid(interaction_delegate):
		return interaction_delegate.get_available_action()
	return get_prompt()
