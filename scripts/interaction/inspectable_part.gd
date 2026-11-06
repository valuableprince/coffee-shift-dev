class_name InspectablePart
extends StaticBody3D
## Shared physical interaction for the original window and every data-driven part.

@export var part_key: StringName = &"service_window"
@export var task: RestorationTask
var element_id: StringName
var state: RestorationState
var inspection_enabled := false
var work_progress := 0.0

func _ready() -> void:
	add_to_group("inspectable_parts")
	set_meta("action", "restore_part")

func bind(session_state: RestorationState, trailer_id: StringName) -> void:
	state = session_state
	element_id = StringName("%s.%s" % [trailer_id, part_key])
	state.register_part(element_id, task)
	state.part_changed.connect(_on_part_changed)
	state.progress_changed.connect(_on_progress_changed)
	work_progress = state.progress_of(element_id)
	_apply_status(state.status_of(element_id))

func set_inspection(enabled: bool) -> void:
	inspection_enabled = enabled
	_update_highlight()

func get_prompt() -> String:
	return InteractionPrompt.text(get_interaction_name(), get_available_action())

func get_interaction_name() -> String:
	return task.title if task != null else str(name)

func get_available_action() -> String:
	if state == null: return ""
	if state.status_of(element_id) == RestorationState.Status.UNINSPECTED:
		return "[E] Осмотреть" if inspection_enabled else "[Q] Включить режим осмотра"
	if state.status_of(element_id) == RestorationState.Status.INSPECTED:
		return "Проверено. Дефектов нет."
	if state.status_of(element_id) == RestorationState.Status.RESTORED:
		return "Готово"
	var reason := state.block_reason(element_id)
	if reason != "":
		return reason
	return "Удерживайте [E] — " + str(state.current_step(element_id).get("label", task.title))

func interact() -> bool:
	if state.status_of(element_id) == RestorationState.Status.UNINSPECTED:
		if inspection_enabled:
			state.inspect(element_id)
		else:
			state.feedback_requested.emit("Сначала включите режим осмотра [Q].")
		return false
	var reason := state.block_reason(element_id)
	if reason != "":
		state.feedback_requested.emit(reason)
		return false
	return true

func advance_work(delta: float) -> bool:
	return state.advance_work(element_id, delta)

func _on_part_changed(changed_id: StringName, status: int) -> void:
	if changed_id == element_id:
		work_progress = state.progress_of(element_id)
		_apply_status(status)
		_update_highlight()

func _on_progress_changed(changed_id: StringName) -> void:
	if changed_id == element_id:
		work_progress = state.progress_of(element_id)
		_apply_progress(work_progress)

func _apply_status(_status: int) -> void:
	pass

func _apply_progress(_progress: float) -> void:
	pass

func _update_highlight() -> void:
	pass

