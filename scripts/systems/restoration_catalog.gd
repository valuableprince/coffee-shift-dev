class_name RestorationCatalog
extends RefCounted

static func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/restoration/garage_tasks.json"))

static func build_parts(parent: Node3D) -> void:
	for definition in data().parts:
		var part: RepairablePart
		if definition.kind == "equipment":
			part = EquipmentInstallation.new()
		else:
			part = RepairablePart.new()
		part.configure(definition)
		parent.add_child(part)

static func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
