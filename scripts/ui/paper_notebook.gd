class_name PaperNotebook
extends Control
## Physical paper spread with a binding, animated page turns and automatic ink strikes.

var state: RestorationState
var entries: RichTextLabel
var notes: RichTextLabel
var paper: PanelContainer
var footer: Label
var spread := 0
var turning := false
var previous: Button
var next: Button

class RuledPaper extends Control:
	func _draw() -> void:
		var ink := Color(0.29, 0.36, 0.29, 0.16)
		for y in range(60, int(size.y) - 16, 30):
			draw_line(Vector2(0, y), Vector2(size.x, y), ink, 1.0)
		draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, size.y), Color(0.34, 0.27, 0.17, 0.45), 3.0)
		for y in range(30, int(size.y) - 16, 58):
			draw_circle(Vector2(size.x / 2.0 - 6, y), 2.3, Color("71654c"))
			draw_circle(Vector2(size.x / 2.0 + 6, y), 2.3, Color("71654c"))

	func _ready() -> void:
		resized.connect(queue_redraw)

func _ready() -> void:
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/paper_regular.ttf")
	theme.default_font_size = 18
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.09, 0.07, 0.80)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper = PanelContainer.new()
	add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.anchor_left = 0.13
	paper.anchor_right = 0.87
	paper.anchor_top = 0.12
	paper.anchor_bottom = 0.88
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e2d6b5")
	style.border_color = Color("786342")
	style.set_border_width_all(5)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 16
	style.content_margin_left = 42
	style.content_margin_right = 38
	style.content_margin_top = 28
	style.content_margin_bottom = 22
	paper.add_theme_stylebox_override("panel", style)
	var ruled := RuledPaper.new()
	ruled.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(ruled)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	paper.add_child(rows)
	var title := Label.new()
	title.text = "БЛОКНОТ ВОССТАНОВЛЕНИЯ"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("373f36"))
	rows.add_child(title)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 30)
	rows.add_child(columns)
	notes = _page()
	columns.add_child(notes)
	var binding := VSeparator.new()
	columns.add_child(binding)
	entries = _page()
	columns.add_child(entries)
	var navigation := HBoxContainer.new()
	rows.add_child(navigation)
	previous = Button.new()
	previous.text = "← Перелистнуть назад"
	previous.pressed.connect(turn.bind(-1))
	navigation.add_child(previous)
	footer = Label.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("625c48"))
	navigation.add_child(footer)
	next = Button.new()
	next.text = "Перелистнуть дальше →"
	next.pressed.connect(turn.bind(1))
	navigation.add_child(next)
	hide()

func _page() -> RichTextLabel:
	var page := RichTextLabel.new()
	page.bbcode_enabled = true
	page.add_theme_font_override("normal_font",preload("res://assets/fonts/paper_regular.ttf"))
	page.add_theme_font_override("bold_font",preload("res://assets/fonts/paper_bold.ttf"))
	page.scroll_active = false
	page.scroll_following = false
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_font_size_override("normal_font_size", 18)
	page.add_theme_font_size_override("bold_font_size", 18)
	page.add_theme_color_override("default_color", Color("394236"))
	return page

func bind(session_state: RestorationState) -> void:
	state = session_state
	state.tasks_changed.connect(refresh)
	refresh()

func page_count() -> int:
	var count := state.notebook_entries().size()
	return 1 + ceili(maxf(0,count-1)/2.0)

func refresh() -> void:
	if state == null:
		return
	var discovered := state.notebook_entries()
	spread = clampi(spread,0,page_count()-1)
	if spread == 0:
		notes.text = "[b]Гараж · порядок работ[/b]\n\nОсмотр: [Q] → [E]. Записи появляются сами.\n\nСовет: корпус и окна → интерьер → ремонт → поверхности → оборудование.\n\nРаботы можно выбирать свободно. Монтаж требует готового основания.\n\nИнструменты справа. Материалы и комплекты — на левых полках.\n\nПояс: 1–5 / колесо. Замена: Shift + E.\n\n[F6] Карьеры и сохранения."
		entries.text = _entry_text(discovered[0]) if not discovered.is_empty() else "[b]Найденные работы[/b]\n\nПока записей нет. Осмотрите трейлер в режиме [Q]. Исправные элементы не создают ремонтных записей."
	else:
		var index := 1+(spread-1)*2
		notes.text = _entry_text(discovered[index]) if index < discovered.size() else ""
		entries.text = _entry_text(discovered[index+1]) if index+1 < discovered.size() else "[b]Место для следующих записей[/b]"
	footer.text = "%d — %d   ·   [← / →]   ·   [N / Esc] Убрать" % [spread*2+1,spread*2+2]
	previous.disabled = spread == 0
	next.disabled = spread >= page_count()-1
	for page in [notes,entries]:
		page.add_theme_font_size_override("normal_font_size",18)
		page.add_theme_font_size_override("bold_font_size",18)
	call_deferred("_fit_pages")

func _entry_text(entry: Dictionary) -> String:
	var task: RestorationTask = entry.task
	var title := task.title
	if entry.done:
		title = "[s]"+title+"[/s]"
	var text := "[b]"+title+"[/b]\n"+task.finding+"\n\n"
	var tools: Array[String] = []
	for step in task.steps():
		var tool := StringName(step.get("tool",""))
		if tool != &"" and not ToolDefinition.title(tool) in tools:
			tools.append(ToolDefinition.title(tool))
	text += "Инструменты: "+(", ".join(tools) if not tools.is_empty() else "проверка вручную")+"\n"
	text += "Материалы: "+task.materials+"\n\n"
	var index := 0
	for step in task.steps():
		var label := str(step.get("label",task.title))
		if index < int(entry.phase):
			label = "[s]"+label+"[/s]"
		text += label+"\n"
		index += 1
	if entry.done:
		text += "\n[b]Выполнено. Отмечено автоматически.[/b]"
	else:
		var reason := state.block_reason(entry.element_id,false)
		text += "\n"+("Доступно. Выберите нужный инструмент и удерживайте E." if reason == "" else "[b]Пока недоступно:[/b] "+reason)
	return text

func turn(direction: int) -> void:
	if turning or state == null:
		return
	var target := clampi(spread+direction,0,page_count()-1)
	if target == spread:
		return
	turning = true
	paper.pivot_offset = paper.size/2
	var tween := create_tween()
	tween.tween_property(paper,"scale:x",.89,.11)
	tween.parallel().tween_property(paper,"rotation",float(direction)*.012,.11)
	tween.tween_callback(func() -> void:
		spread = target
		refresh()
		notes.scroll_to_line(0)
		entries.scroll_to_line(0))
	tween.tween_property(paper,"scale:x",1.0,.17)
	tween.parallel().tween_property(paper,"rotation",0.0,.17)
	tween.tween_callback(func() -> void: turning = false)

func _fit_pages() -> void:
	# Text belongs to a fixed sheet of paper; do not turn the page into a scrolling list.
	for page in [notes,entries]:
		if page == null or page.size.y <= 0:
			continue
		var height: int = page.get_content_height()
		if height > page.size.y:
			var current: int = page.get_theme_font_size("normal_font_size")
			var font := clampi(floori(float(current)*page.size.y/float(height)),15,18)
			page.add_theme_font_size_override("normal_font_size",font)
			page.add_theme_font_size_override("bold_font_size",font)
