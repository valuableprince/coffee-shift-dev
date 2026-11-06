class_name RestorationTask
extends Resource
## Work description, independent of UI and of a particular trailer instance.

@export var title: String = ""
@export_multiline var finding: String = ""
@export var required_tool: StringName = &"cleaning_kit"
@export var materials: String = "Ветошь и средство для стёкол"
@export_range(0.5, 20.0) var prototype_work_seconds: float = 3.0
@export var category: String = "windows"
@export var mandatory: bool = true
@export var healthy: bool = false
@export var dependencies: Array[String] = []
@export var phases: Array[Dictionary] = []

static func from_data(data: Dictionary) -> RestorationTask:
	var result := RestorationTask.new()
	result.title = data.get("title", "Осмотреть элемент")
	result.finding = data.get("finding", "Требуется подготовка.")
	result.materials = data.get("materials", "Инструменты на верстаке и полках гаража")
	result.category = data.get("category", "repair")
	result.mandatory = data.get("mandatory", true)
	result.healthy = data.get("healthy", false)
	for key in data.get("dependencies", []):
		result.dependencies.append(str(key))
	for phase in data.get("phases", []):
		result.phases.append(phase.duplicate(true))
	return result

func steps() -> Array[Dictionary]:
	if not phases.is_empty():
		return phases
	return [{"label": title, "tool": str(required_tool), "seconds": prototype_work_seconds}]
