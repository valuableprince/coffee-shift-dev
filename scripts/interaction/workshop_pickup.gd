class_name WorkshopPickup
extends StaticBody3D
## A unique physical source. Full-belt replacement returns the previous tool home.
@export var tool_id: StringName = &"cleaning_kit"
var material_id := ""
var source_id := ""
var title := ""
var amount := 1
var taken := false
var state: RestorationState

func _ready() -> void:
	set_meta("action", "pickup")
	add_to_group("workshop_pickups")

func bind(session_state: RestorationState) -> void:
	state = session_state
	state.tools_changed.connect(sync)
	sync()

func sync() -> void:
	taken = state.has_tool(tool_id) if material_id == "" else source_id in state.collected
	visible = not taken
	collision_layer = 0 if taken else 2
	collision_mask = 0

func get_prompt() -> String:
	return InteractionPrompt.text(get_interaction_name(), get_available_action())

func get_interaction_name() -> String:
	return ToolDefinition.title(tool_id) if material_id == "" else title

func get_available_action() -> String:
	if taken: return ""
	if material_id == "" and state != null and not state.belt.slots.has(""):
		return "[Shift + E] Заменить активный инструмент"
	return "[E] Взять"

func interact(session_state: RestorationState, replace_active: bool = false) -> void:
	if state == null:
		bind(session_state)
	if taken:
		return
	if material_id != "":
		if state.collect(source_id,material_id,amount):
			state.feedback_requested.emit("Подготовлено: " + title + ". Установите на выделенное место в трейлере.")
	elif state.acquire_tool(tool_id,replace_active):
		state.feedback_requested.emit("Взят инструмент: " + ToolDefinition.title(tool_id) + ". Переключение: 1–5 / колесо.")
	else:
		state.feedback_requested.emit("Пояс заполнен: 5 слотов. Выберите заменяемый слот и нажмите Shift + E. Снятый инструмент вернётся на своё место в гараже.")
	sync()

