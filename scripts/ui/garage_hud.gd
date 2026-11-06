class_name GarageHUD
extends CanvasLayer

var state: RestorationState
var notebook: PaperNotebook
var status: Label
var hint: Label
var reticle: InteractionReticle
var message: Label
var progress: ProgressBar
var belt_panel: HBoxContainer
var belt_labels: Array[Label] = []
var _belt_time := 0.0
var _message_time := 0.0
var inspection_enabled := false

func _ready() -> void:
	var root := Control.new()
	root.name = "Interface"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Build the essential notebook before optional HUD decoration. This avoids
	# a null notebook if a later widget fails to initialize on a target PC.
	notebook = PaperNotebook.new()
	root.add_child(notebook)
	var header := Label.new()
	header.text = "COFFEE SHIFT    /    ГАРАЖ"
	header.position = Vector2(28, 24)
	header.add_theme_font_size_override("font_size", 24)
	root.add_child(header)
	status = Label.new()
	status.position = Vector2(28, 62)
	status.add_theme_font_size_override("font_size", 17)
	root.add_child(status)
	message = Label.new()
	message.position = Vector2(28, 122)
	message.size = Vector2(450, 120)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color("eee1b5"))
	message.add_theme_font_size_override("font_size", 19)
	root.add_child(message)
	reticle = InteractionReticle.new()
	root.add_child(reticle)
	hint = reticle.hint
	progress = ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.show_percentage = false
	root.add_child(progress)
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	progress.offset_left = -160
	progress.offset_right = 160
	progress.offset_top = -76
	progress.offset_bottom = -64
	progress.hide()
	var controls := Label.new()
	controls.name = "Controls"
	controls.text = "WASD — ходьба    Shift — быстрее    E — действие    Q — осмотр    N — блокнот    1–5 / колесо — пояс\nF6 — сохранения    M — музыка    P — мелодия    - / = — громкость"
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color("dedcc6"))
	root.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 28
	controls.offset_right = 1100
	controls.offset_top = -51
	controls.offset_bottom = -8
	var build_label := Label.new()
	build_label.text = "DEV-02 · ГАРАЖ"
	build_label.add_theme_font_size_override("font_size", 14)
	root.add_child(build_label)
	build_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	build_label.offset_left = -177
	build_label.offset_right = -20
	build_label.offset_top = 28
	build_label.offset_bottom = 51
	for label in [header, status, message, hint, controls, build_label]:
		label.add_theme_color_override("font_shadow_color", Color(0.04, 0.05, 0.04, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
	belt_panel = HBoxContainer.new()
	root.add_child(belt_panel)
	belt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	belt_panel.offset_left = -400
	belt_panel.offset_right = 400
	belt_panel.offset_top = -185
	belt_panel.offset_bottom = -132
	belt_panel.add_theme_constant_override("separation",6)
	for i in range(5):
		var slot := Label.new()
		slot.custom_minimum_size = Vector2(154,49)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size",15)
		belt_panel.add_child(slot)
		belt_labels.append(slot)
	belt_panel.hide()
	# Keep the notebook above HUD labels and overlays when it is opened.
	root.move_child(notebook,root.get_child_count()-1)

func bind(session_state: RestorationState) -> void:
	state = session_state
	state.tasks_changed.connect(refresh_status)
	state.tools_changed.connect(refresh_status)
	state.belt.selection_requested.connect(show_belt)
	notebook.bind(state)
	refresh_status()

func refresh_status() -> void:
	var completed := 0
	var entries := state.notebook_entries()
	for entry in entries:
		if entry["done"]:
			completed += 1
	status.text = "Осмотр: %s    ·    Найдено: %d    ·    Выполнено: %d" % [
		"включён [Q]" if inspection_enabled else "выключен [Q]", entries.size(), completed]
	if state.ready_for_opening:
		status.text = "Трейлер готов к открытию кофейни"

func say(text: String) -> void:
	message.text = text
	_message_time = 8.0

func set_inspection(enabled: bool) -> void:
	inspection_enabled = enabled
	refresh_status()

func set_work(value: float, active: bool) -> void:
	progress.value = value
	progress.visible = active

func show_belt() -> void:
	_belt_time = 2.8
	for i in range(5):
		var label := belt_labels[i]
		label.text = "%d  ·  %s" % [i+1,ToolDefinition.title(StringName(state.belt.slots[i]))]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4c6559") if i == state.belt.selected else Color(.12,.17,.14,.92)
		style.border_color = Color("d2bd83") if i == state.belt.selected else Color("526456")
		style.set_border_width_all(2)
		label.add_theme_stylebox_override("normal",style)
	belt_panel.show()

func _process(delta: float) -> void:
	_belt_time -= delta
	_message_time -= delta
	if _belt_time <= 0:
		belt_panel.hide()
	if notebook != null and notebook.visible:
		belt_panel.hide()
	if _message_time <= 0:
		message.text = ""

