class_name RestorationState
extends Node
## Authority shared by DEV-01 window, new parts, notebook and saves.

signal tasks_changed
signal part_changed(element_id: StringName, status: int)
signal progress_changed(element_id: StringName)
signal tools_changed
signal feedback_requested(message: String)
signal checkpoint(reason: String)
signal readiness_changed(ready: bool)
signal first_shift_available(trailer_id: StringName)

# Preserve DEV-01 numeric values; INSPECTED is a healthy inspection result.
enum Status { UNINSPECTED, DEFECT_FOUND, RESTORED, INSPECTED }
var _records: Dictionary = {}
var belt := ToolBelt.new()
var materials: Dictionary = {}
var collected: Array[String] = []
var ready_for_opening := false
var _restoring := false

func _init() -> void:
	belt.changed.connect(func() -> void: tools_changed.emit())
	belt.selected_changed.connect(func() -> void: tools_changed.emit())

func register_part(element_id: StringName, task: RestorationTask) -> void:
	if task == null or _records.has(element_id):
		return
	_records[element_id] = {"task": task, "status": Status.UNINSPECTED, "phase": 0, "progress": 0.0}
	_update_readiness()

func status_of(element_id: StringName) -> int:
	return int(_records.get(element_id, {}).get("status", Status.UNINSPECTED))

func phase_of(element_id: StringName) -> int:
	return int(_records.get(element_id, {}).get("phase", 0))

func progress_of(element_id: StringName) -> float:
	return float(_records.get(element_id, {}).get("progress", 0.0))

func current_step(element_id: StringName) -> Dictionary:
	if not _records.has(element_id):
		return {}
	var task: RestorationTask = _records[element_id].task
	var steps := task.steps()
	return steps[mini(phase_of(element_id), steps.size() - 1)]

func inspect(element_id: StringName) -> bool:
	if not _records.has(element_id) or status_of(element_id) != Status.UNINSPECTED:
		return false
	var task: RestorationTask = _records[element_id].task
	_set_status(element_id, Status.INSPECTED if task.healthy else Status.DEFECT_FOUND)
	feedback_requested.emit(task.finding + (" Проверка завершена." if task.healthy else " Записано в блокнот [N]."))
	checkpoint.emit("Осмотр: " + task.title)
	return true

func block_reason(element_id: StringName, check_tool: bool = true) -> String:
	if not _records.has(element_id):
		return "Неизвестный элемент"
	if status_of(element_id) != Status.DEFECT_FOUND:
		return "Сначала осмотрите элемент [Q] → [E]" if status_of(element_id) == Status.UNINSPECTED else "Работа уже завершена"
	var task: RestorationTask = _records[element_id].task
	var prefix := str(element_id).get_slice(".", 0) + "."
	for dependency in task.dependencies:
		var key := StringName(prefix + dependency)
		if status_of(key) != Status.RESTORED:
			var required: RestorationTask = _records.get(key, {}).get("task")
			return "Сначала: " + (required.title if required != null else dependency)
	var step := current_step(element_id)
	var material_id := str(step.get("material", ""))
	if material_id != "" and int(materials.get(material_id, 0)) < int(step.get("amount", 1)):
		return "Нужен материал: " + str(step.get("material_title", material_id)) + " — на полках гаража"
	var tool_id := StringName(step.get("tool", ""))
	if check_tool and tool_id != &"" and belt.active_tool() != tool_id:
		return "Выберите: " + ToolDefinition.title(tool_id) if has_tool(tool_id) else "Возьмите в гараже: " + ToolDefinition.title(tool_id)
	return ""

func advance_work(element_id: StringName, delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0 or block_reason(element_id) != "":
		return false
	var step := current_step(element_id)
	_records[element_id].progress = minf(1.0, progress_of(element_id) + delta / maxf(0.1, float(step.get("seconds", 3.0))))
	progress_changed.emit(element_id)
	if progress_of(element_id) >= 1.0:
		return finish(element_id)
	return false

func finish(element_id: StringName) -> bool:
	# Direct callers also cannot skip work, dependencies, tool or material checks.
	if block_reason(element_id) != "" or progress_of(element_id) < 1.0:
		return false
	var task: RestorationTask = _records[element_id].task
	var step := current_step(element_id)
	var material_id := str(step.get("material", ""))
	if material_id != "":
		materials[material_id] = int(materials[material_id]) - int(step.get("amount", 1))
	_records[element_id].phase = phase_of(element_id) + 1
	if phase_of(element_id) >= task.steps().size():
		_records[element_id].progress = 1.0
		_set_status(element_id, Status.RESTORED)
		feedback_requested.emit("Выполнено: " + task.title + ". Запись зачёркнута в блокноте.")
	else:
		_records[element_id].progress = 0.0
		part_changed.emit(element_id, Status.DEFECT_FOUND)
		progress_changed.emit(element_id)
		tasks_changed.emit()
		feedback_requested.emit("Операция выполнена. Далее: " + str(current_step(element_id).get("label", "Проверка")))
	_update_readiness()
	checkpoint.emit(task.title)
	return true

func _set_status(element_id: StringName, status: int) -> void:
	_records[element_id].status = status
	part_changed.emit(element_id, status)
	tasks_changed.emit()

func has_tool(tool_id: StringName) -> bool:
	return belt.contains(tool_id)

func acquire_tool(tool_id: StringName, replace_active: bool = false) -> bool:
	var result := belt.take(tool_id, replace_active)
	if result:
		checkpoint.emit("Взят инструмент: " + ToolDefinition.title(tool_id))
	return result

func collect(source_id: String, material_id: String, amount: int) -> bool:
	if source_id in collected or amount <= 0:
		return false
	collected.append(source_id)
	materials[material_id] = int(materials.get(material_id, 0)) + amount
	tools_changed.emit()
	checkpoint.emit("Подготовлены материалы")
	return true

func notebook_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for element_id in _records:
		if status_of(element_id) in [Status.UNINSPECTED, Status.INSPECTED]:
			continue
		entries.append({"element_id": element_id, "task": _records[element_id].task,
			"done": status_of(element_id) == Status.RESTORED, "phase": phase_of(element_id)})
	return entries

func readiness() -> Dictionary:
	var result := {"exterior": false, "windows": false, "interior": false, "seals": false,
		"repair": false, "preparation": false, "installation": false, "checking": false}
	var seen := {}
	for key in _records:
		var task: RestorationTask = _records[key].task
		if not task.mandatory or task.healthy:
			continue
		if task.category == "equipment":
			if not seen.has("equipment"):
				result.installation = true
				result.checking = true
				seen.equipment = true
			result.installation = result.installation and phase_of(key) >= 1
			result.checking = result.checking and status_of(key) == Status.RESTORED
		elif result.has(task.category):
			if not seen.has(task.category):
				result[task.category] = true
				seen[task.category] = true
			result[task.category] = result[task.category] and status_of(key) == Status.RESTORED
	return result

func _update_readiness() -> void:
	var ready := not _records.is_empty() and not readiness().values().has(false)
	if ready == ready_for_opening:
		return
	ready_for_opening = ready
	readiness_changed.emit(ready)
	if ready and not _restoring:
		feedback_requested.emit("Трейлер готов к открытию кофейни")
		first_shift_available.emit(&"trailer_01")

func snapshot() -> Dictionary:
	var records := {}
	for key in _records:
		records[str(key)] = {"status": status_of(key), "phase": phase_of(key), "progress": progress_of(key)}
	return {"records": records, "belt": belt.snapshot(), "materials": materials.duplicate(),
		"collected": collected.duplicate(), "ready_for_opening": ready_for_opening}

func validate(data: Dictionary) -> bool:
	if not data.get("records") is Dictionary or not data.get("belt") is Dictionary or not belt.valid(data.belt):
		return false
	if data.records.size() != _records.size() or not data.get("materials") is Dictionary or not data.get("collected") is Array:
		return false
	for key in _records:
		var row = data.records.get(str(key))
		if not row is Dictionary:
			return false
		for field in ["status", "phase", "progress"]:
			if not row.get(field) is float and not row.get(field) is int:
				return false
		var task: RestorationTask = _records[key].task
		var status := int(row.status)
		var phase := int(row.phase)
		if row.status != status or row.phase != phase or status < 0 or status > Status.INSPECTED:
			return false
		if not is_finite(float(row.progress)) or row.progress < 0 or row.progress > 1 or phase < 0 or phase > task.steps().size():
			return false
		if status == Status.RESTORED and (phase != task.steps().size() or row.progress != 1):
			return false
		if status == Status.DEFECT_FOUND and (task.healthy or phase >= task.steps().size()):
			return false
		if task.healthy and status not in [Status.UNINSPECTED,Status.INSPECTED]:
			return false
		if status == Status.INSPECTED and not task.healthy:
			return false
		if status in [Status.UNINSPECTED, Status.INSPECTED] and (phase != 0 or row.progress != 0):
			return false
	for amount in data.materials.values():
		if (not amount is int and not amount is float) or amount != int(amount) or amount < 0 or amount > 100:
			return false
	var seen := {}
	for source in data.collected:
		if not source is String or seen.has(source):
			return false
		seen[source] = true
	# Validate material conservation and technical dependencies before mutating anything.
	var expected := {}
	var sources := {}
	for source in RestorationCatalog.data().sources:
		sources[source.id] = source
	for source_id in data.collected:
		if not sources.has(source_id):
			return false
		var source: Dictionary = sources[source_id]
		expected[source.material] = int(expected.get(source.material,0))+int(source.amount)
	for key in _records:
		var task: RestorationTask = _records[key].task
		var row: Dictionary = data.records[str(key)]
		var steps := task.steps()
		for i in range(int(row.phase)):
			var material := str(steps[i].get("material",""))
			if material != "":
				expected[material] = int(expected.get(material,0))-int(steps[i].get("amount",1))
		if int(row.phase)>0 or float(row.progress)>0:
			for dependency in task.dependencies:
				var id := str(key).get_slice(".",0)+"."+dependency
				if int(data.records.get(id,{}).get("status",Status.UNINSPECTED)) != Status.RESTORED:
					return false
	for material in expected:
		if int(expected[material])<0 or int(data.materials.get(material,-1)) != int(expected[material]):
			return false
	for material in data.materials:
		if not expected.has(material):
			return false
	return true

func restore(data: Dictionary) -> bool:
	if not validate(data):
		return false
	_restoring = true
	materials = data.materials.duplicate()
	collected.assign(data.collected)
	belt.restore(data.belt)
	for key in _records:
		var row: Dictionary = data.records[str(key)]
		_records[key].phase = int(row.phase)
		_records[key].progress = float(row.progress)
		_set_status(key, int(row.status))
		progress_changed.emit(key)
	_update_readiness()
	_restoring = false
	return true

func reset() -> void:
	var empty := snapshot()
	for row in empty.records.values():
		row.status = Status.UNINSPECTED
		row.phase = 0
		row.progress = 0.0
	empty.belt = {"slots": ["", "", "", "", ""], "selected": 0}
	empty.materials = {}
	empty.collected = []
	restore(empty)
