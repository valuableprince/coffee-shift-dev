class_name ToolBelt
extends RefCounted
## Replacement returns the old physical tool to its original garage stand.

signal changed
signal selected_changed
signal selection_requested
const CAPACITY := 5
var slots: Array[String] = ["", "", "", "", ""]
var selected := 0

func active_tool() -> StringName:
	return StringName(slots[selected])

func contains(tool_id: StringName) -> bool:
	return str(tool_id) in slots

func take(tool_id: StringName, replace_active: bool = false) -> bool:
	if not ToolDefinition.known(tool_id) or contains(tool_id):
		return false
	var index := slots.find("")
	if index == -1:
		if not replace_active:
			return false
		index = selected
	slots[index] = str(tool_id)
	selected = index
	changed.emit()
	selected_changed.emit()
	selection_requested.emit()
	return true

func select_slot(index: int) -> bool:
	if index < 0 or index >= CAPACITY:
		return false
	var different := selected != index
	selected = index
	selection_requested.emit()
	if different:
		selected_changed.emit()
	return true

func cycle(direction: int) -> void:
	select_slot(posmod(selected + direction, CAPACITY))

func snapshot() -> Dictionary:
	return {"slots": slots.duplicate(), "selected": selected}

func valid(data: Dictionary) -> bool:
	var values = data.get("slots")
	if not values is Array or values.size() != CAPACITY:
		return false
	var seen := {}
	for value in values:
		if not value is String or (value != "" and (not ToolDefinition.known(value) or seen.has(value))):
			return false
		if value != "":
			seen[value] = true
	var index = data.get("selected", -1)
	return (index is int or index is float) and is_finite(float(index)) and index == int(index) and int(index) >= 0 and int(index) < CAPACITY

func restore(data: Dictionary) -> bool:
	if not valid(data):
		return false
	slots.assign(data["slots"])
	selected = int(data["selected"])
	changed.emit()
	selected_changed.emit()
	selection_requested.emit()
	return true
