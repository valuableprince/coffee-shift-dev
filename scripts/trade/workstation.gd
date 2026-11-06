class_name ShiftWorkstation
extends StaticBody3D
## Raycast target delegates to world; no business rules in rendering nodes.
var action := ""
var caption := ""
var order_id := 0
var item_index := 0
var world: Node3D

func configure(owner_world: Node3D, operation: String, label: String, point: Vector3, size: Vector3) -> void:
	world = owner_world
	action = operation
	caption = label
	position = point
	name = operation.validate_node_name()
	set_meta("action", operation)
	collision_layer = 2
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

func get_prompt() -> String:
	return InteractionPrompt.text(get_interaction_name(), get_available_action())

func get_interaction_name() -> String:
	return caption

func get_available_action() -> String:
	return world.station_available_action(self)

func interact() -> void:
	if get_available_action().begins_with("[E]"):
		world.interact_station(self)
