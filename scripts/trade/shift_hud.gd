class_name ShiftHUD
extends CanvasLayer
signal panel_closed
signal order_selected(order_id: int, item_index: int)
signal order_called(order_id: int)
var status: Label
var business: Label
var hint: Label
var reticle: InteractionReticle
var message: Label
var guide: Label
var tasks: EquipmentTaskList
var panel: PanelContainer
var panel_content: VBoxContainer
var root: Control
var _message_time := 0.0
var orders_panel: PanelContainer
var order_cards: VBoxContainer
var item_buttons: Dictionary = {}
var call_buttons: Dictionary = {}
var orders_hint: Label
var orders_column: VBoxContainer
var control_hints: Label
var _orders_signature := ""
var orders_editing := false
var dialogue_word_reveal := true
var dialogue_word_interval := 0.12
var _dialogue_copy: Label
var _word_ends: Array[int] = []
var _word_index := 0
var _word_elapsed := 0.0
var _dialogue_buttons: Array[Button] = []
var _modal_style: StyleBoxFlat
var _dialogue_style: StyleBoxFlat
var _dialogue_mode := false
var _dialogue_text_scroll: ScrollContainer
var _dialogue_indicator: Label
var _dialogue_navigation: Array[Button] = []

func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	business = _label(Vector2(20, 16), 18)
	business.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	business.offset_left = 20
	business.offset_right = -330
	business.offset_top = 16
	business.offset_bottom = 42
	business.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status = _label(Vector2(20, 46), 16)
	message = _label(Vector2(20, 104), 16)
	message.size = Vector2(440, 90)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide = _label(Vector2.ZERO, 14)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_color_override("font_color", Color("f0dcab"))
	reticle = InteractionReticle.new()
	root.add_child(reticle)
	hint = reticle.hint
	var controls := _label(Vector2.ZERO, 12)
	control_hints = controls
	controls.name = "ControlHints"
	controls.text = "WASD — ходьба   E — предмет / радио   Tab — заказы   N — справочник   F6 — сохранения   Esc — меню"
	controls.add_theme_color_override("font_color", Color("c5ccc4"))
	controls.add_theme_constant_override("shadow_offset_y", 1)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 20
	controls.offset_top = -46
	controls.offset_right = -20
	controls.offset_bottom = -8
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_orders_panel()
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -365
	panel.offset_right = 365
	panel.offset_top = -305
	panel.offset_bottom = 305
	var style := StyleBoxFlat.new()
	style.bg_color = Color("183d3a")
	style.border_color = Color("bcaa7e")
	style.set_border_width_all(2)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_modal_style = style
	_dialogue_style = style.duplicate() as StyleBoxFlat
	_dialogue_style.bg_color = Color(0.055, 0.105, 0.104, 0.93)
	_dialogue_style.set_border_width_all(1)
	_dialogue_style.set_corner_radius_all(4)
	_dialogue_style.content_margin_left = 12
	_dialogue_style.content_margin_right = 12
	_dialogue_style.content_margin_top = 8
	_dialogue_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", _modal_style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	panel_content = VBoxContainer.new()
	panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_theme_constant_override("separation", 12)
	scroll.add_child(panel_content)
	panel.hide()
	get_viewport().size_changed.connect(func() -> void:
		if panel.visible:
			_layout_panel(_dialogue_mode)
			if _dialogue_mode: call_deferred("_fit_dialogue_panel"))

func _build_orders_panel() -> void:
	orders_panel = PanelContainer.new()
	orders_panel.name = "OrdersSidebar"
	root.add_child(orders_panel)
	orders_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	orders_panel.offset_left = -290
	orders_panel.offset_right = -12
	orders_panel.offset_top = 104
	orders_panel.offset_bottom = 310
	orders_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	orders_panel.add_child(scroll)
	var column := VBoxContainer.new()
	orders_column = column
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	scroll.add_child(column)
	orders_hint = Label.new()
	orders_hint.text = "ЗАКАЗЫ   ·   [Tab] выбрать"
	orders_hint.add_theme_font_size_override("font_size", 14)
	column.add_child(orders_hint)
	tasks = EquipmentTaskList.new()
	column.add_child(tasks)
	guide.reparent(column)
	guide.position = Vector2.ZERO
	guide.custom_minimum_size = Vector2(238,0)
	guide.size = Vector2(238, 0)
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.add_theme_font_size_override("font_size", 14)
	guide.add_theme_constant_override("line_spacing", 0)
	guide.add_theme_constant_override("shadow_offset_x", 0)
	guide.add_theme_constant_override("shadow_offset_y", 0)
	order_cards = VBoxContainer.new()
	order_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_cards.add_theme_constant_override("separation", 5)
	column.add_child(order_cards)

func set_orders_editing(value: bool) -> void:
	orders_editing = value
	orders_hint.text = "ЗАКАЗЫ   ·   [Tab/Esc] вернуться" if value else "ЗАКАЗЫ   ·   [Tab] выбрать"

func _refresh_orders(session: CoffeeShiftSession) -> void:
	var active := session.active_orders()
	var signature := JSON.stringify([active,session.selected_order,session.selected_item])
	if signature == _orders_signature: return
	_orders_signature = signature
	item_buttons.clear()
	call_buttons.clear()
	for child in order_cards.get_children():
		order_cards.remove_child(child)
		child.queue_free()
	for order in active:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 3)
		order_cards.add_child(card)
		var heading := Label.new()
		var status_text: String = {"awaiting_payment":"Оплата", "paid":"В работе", "ready":"Готов", "called":"Вызван"}.get(order.status,"В работе")
		heading.text = "№%03d   ·   %s" % [int(order.id),status_text]
		heading.add_theme_color_override("font_color",Color("ead5a3"))
		heading.add_theme_font_size_override("font_size",14)
		card.add_child(heading)
		for i in range(order.items.size()):
			var id := int(order.id)
			var index := i
			var item: Dictionary = order.items[index]
			var button := Button.new()
			button.name = "Order_%d_Item_%d" % [id,index]
			button.text = ("✓ " if item.ready else "○ ") + session.catalog.caption(item).replace(" · сахар", "\nсахар").replace(" · ваниль", "\nваниль")
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y = 32
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size",14)
			button.disabled = not order.paid or item.ready
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func() -> void: order_selected.emit(id,index))
			card.add_child(button)
			item_buttons["%d:%d" % [id,index]] = button
		if order.status in ["ready","called"]:
			var id := int(order.id)
			var call := Button.new()
			call.text = "Вызвать №%03d" % id if order.status == "ready" else "Покупатель идёт к окну"
			call.disabled = order.status != "ready"
			call.focus_mode = Control.FOCUS_NONE
			call.custom_minimum_size.y = 32
			call.pressed.connect(func() -> void: order_called.emit(id))
			card.add_child(call)
			call_buttons[id] = call

func _label(point: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color("182722"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label)
	return label

func say(value: String) -> void:
	message.text = value
	_message_time = 7.0

func set_dialogue_preferences(enabled: bool, word_interval: float) -> void:
	dialogue_word_reveal = enabled
	dialogue_word_interval = clampf(word_interval, 0.06, 0.25)
	if not enabled and _is_typing():
		_reveal_dialogue()

func _layout_panel(is_dialogue: bool) -> void:
	_dialogue_mode = is_dialogue
	if is_dialogue:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		var viewport_size := get_viewport().get_visible_rect().size
		var factor := _dialogue_scale()
		var width := minf(720.0 * factor, viewport_size.x - 32.0)
		panel.offset_left = -width * .5
		panel.offset_right = width * .5
		panel.offset_bottom = -22.0 * factor
		panel.offset_top = panel.offset_bottom - 112.0 * factor
		_dialogue_style.content_margin_left = 12 * factor
		_dialogue_style.content_margin_right = 12 * factor
		_dialogue_style.content_margin_top = 8 * factor
		_dialogue_style.content_margin_bottom = 8 * factor
		panel_content.add_theme_constant_override("separation", roundi(4 * factor))
		panel.add_theme_stylebox_override("panel", _dialogue_style)
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		panel.offset_left = -365
		panel.offset_right = 365
		panel.offset_top = -305
		panel.offset_bottom = 305
		panel_content.add_theme_constant_override("separation", 12)
		panel.add_theme_stylebox_override("panel", _modal_style)
	control_hints.visible = not is_dialogue

func _dialogue_scale() -> float:
	var view := get_viewport().get_visible_rect().size
	return clampf(minf(view.x / 1280.0, view.y / 720.0), .8, 1.5)

func _fit_dialogue_panel() -> void:
	if not _dialogue_mode or not panel.visible: return
	var factor := _dialogue_scale()
	for label in panel_content.find_children("*", "Label", true, false):
		label.add_theme_font_size_override("font_size", roundi((12 if label == _dialogue_indicator else 16 if label.name == "Speaker" else 17) * factor))
	for button in _dialogue_navigation:
		button.add_theme_font_size_override("font_size", roundi(14 * factor))
		button.custom_minimum_size.y = 28 * factor
	if _dialogue_text_scroll != null:
		_dialogue_text_scroll.custom_minimum_size.y = clampf(_dialogue_copy.get_combined_minimum_size().y, 28 * factor, 60 * factor)
	var view_height := get_viewport().get_visible_rect().size.y
	var content_height := panel_content.get_combined_minimum_size().y + 16.0 * factor
	var desired := clampf(content_height, 112.0 * factor, minf(270.0 * factor, view_height * .43))
	panel.offset_top = panel.offset_bottom - desired

func _is_typing() -> bool:
	return _dialogue_mode and panel.visible and _dialogue_copy != null and _word_index < _word_ends.size()

func _reveal_dialogue() -> void:
	if _dialogue_copy != null:
		_dialogue_copy.visible_characters = -1
	_word_index = _word_ends.size()
	for button in _dialogue_buttons:
		if is_instance_valid(button):
			button.disabled = false
	_update_dialogue_indicator()
	if not _dialogue_buttons.is_empty(): _dialogue_buttons[0].grab_focus()

func _update_dialogue_indicator() -> void:
	if not is_instance_valid(_dialogue_indicator): return
	_dialogue_indicator.text = "Space / ЛКМ — весь текст" if _is_typing() else "↑/↓ — выбор · Enter / ЛКМ"
	if not _is_typing() and _dialogue_copy != null and _dialogue_copy.get_line_count() > 3:
		_dialogue_indicator.text += " · PgUp/PgDn — текст"

func show_panel(title: String, body: String, actions: Array = [], is_dialogue: bool = false) -> void:
	_layout_panel(is_dialogue)
	_dialogue_copy = null
	_word_ends.clear()
	_word_index = 0
	_word_elapsed = 0.0
	_dialogue_buttons.clear()
	_dialogue_navigation.clear()
	_dialogue_text_scroll = null
	_dialogue_indicator = null
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.name = "Speaker"
	heading.text = title
	heading.add_theme_font_size_override("font_size", 16 if is_dialogue else 26)
	if is_dialogue:
		heading.add_theme_color_override("font_color", Color("e4c78d"))
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var header := HBoxContainer.new()
		panel_content.add_child(header)
		header.add_child(heading)
		_dialogue_indicator = Label.new()
		_dialogue_indicator.add_theme_color_override("font_color", Color("a5b4ad"))
		header.add_child(_dialogue_indicator)
	else: panel_content.add_child(heading)
	var copy := Label.new()
	copy.text = body
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size", 17 if is_dialogue else 18)
	if is_dialogue:
		_dialogue_copy = copy
		if dialogue_word_reveal:
			var word_regex := RegEx.new()
			word_regex.compile("\\S+")
			for word in word_regex.search_all(body):
				_word_ends.append(word.get_end())
			copy.visible_characters = 0 if not _word_ends.is_empty() else -1
	if is_dialogue:
		_dialogue_text_scroll = ScrollContainer.new()
		_dialogue_text_scroll.name = "DialogueText"
		_dialogue_text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_dialogue_text_scroll.custom_minimum_size.y = 60 * _dialogue_scale()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel_content.add_child(_dialogue_text_scroll)
		_dialogue_text_scroll.add_child(copy)
	else: panel_content.add_child(copy)
	var dialogue_actions: Container
	if is_dialogue:
		dialogue_actions = HBoxContainer.new() if actions.size() <= 2 else VBoxContainer.new()
		dialogue_actions.add_theme_constant_override("separation", 6)
		panel_content.add_child(dialogue_actions)
	var grid: GridContainer
	for action in actions:
		var button := Button.new()
		button.text = str(action.label)
		button.custom_minimum_size.y = 28 if is_dialogue else 40
		if is_dialogue:
			button.add_theme_font_size_override("font_size", 14)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = bool(action.get("disabled", false))
		if is_dialogue and not button.disabled:
			_dialogue_buttons.append(button)
			if not _word_ends.is_empty():
				button.disabled = true
		button.pressed.connect(action.call)
		if is_dialogue:
			_dialogue_navigation.append(button)
			dialogue_actions.add_child(button)
		elif action.get("grid", false):
			if grid == null:
				grid = GridContainer.new()
				grid.columns = 4
				grid.add_theme_constant_override("h_separation", 8)
				grid.add_theme_constant_override("v_separation", 8)
				panel_content.add_child(grid)
			button.custom_minimum_size = Vector2(155, 52)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(button)
		else:
			grid = null
			panel_content.add_child(button)
	var back := Button.new()
	back.text = "К работе [Esc]" if is_dialogue else "Вернуться к работе [Esc]"
	back.custom_minimum_size.y = 28 if is_dialogue else 42
	back.pressed.connect(close_panel)
	if is_dialogue:
		back.add_theme_font_size_override("font_size", 14)
		dialogue_actions.add_child(back)
		_dialogue_navigation.append(back)
	else: panel_content.add_child(back)
	panel.show()
	if is_dialogue:
		_update_dialogue_indicator()
		call_deferred("_fit_dialogue_panel")
		if not _is_typing() and not _dialogue_buttons.is_empty(): _dialogue_buttons[0].grab_focus()

func close_panel() -> void:
	panel.hide()
	control_hints.visible = true
	_dialogue_copy = null
	_word_ends.clear()
	_dialogue_buttons.clear()
	_dialogue_navigation.clear()
	_dialogue_mode = false
	panel_closed.emit()

func _input(event: InputEvent) -> void:
	if _dialogue_mode and panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN] and _dialogue_text_scroll != null:
			_dialogue_text_scroll.scroll_vertical += roundi(_dialogue_text_scroll.size.y) * (1 if event.keycode == KEY_PAGEDOWN else -1)
			get_viewport().set_input_as_handled()
			return
		if not _is_typing() and event.keycode in [KEY_UP, KEY_DOWN]:
			var available := _dialogue_navigation.filter(func(b: Button) -> bool: return not b.disabled)
			if not available.is_empty():
				var index := available.find(get_viewport().gui_get_focus_owner())
				var step := 1 if event.keycode == KEY_DOWN else -1
				available[posmod(index + step, available.size())].grab_focus()
			get_viewport().set_input_as_handled()
			return
	if not _is_typing():
		return
	var skip := false
	if event is InputEventKey:
		skip = event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]
	elif event is InputEventMouseButton:
		skip = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if skip:
		_reveal_dialogue()
		get_viewport().set_input_as_handled()

func _advance_dialogue(delta: float) -> void:
	if not _is_typing():
		return
	_word_elapsed -= delta
	while _word_elapsed <= 0.0 and _word_index < _word_ends.size():
		var end_char := _word_ends[_word_index]
		_dialogue_copy.visible_characters = end_char
		_word_index += 1
		_word_elapsed += dialogue_word_interval
		var word_so_far := _dialogue_copy.text.substr(0, end_char).strip_edges()
		if word_so_far.ends_with(".") or word_so_far.ends_with("!") or word_so_far.ends_with("?"):
			_word_elapsed += 0.17
		elif word_so_far.ends_with(","):
			_word_elapsed += 0.08
	if _word_index >= _word_ends.size():
		_reveal_dialogue()

func refresh(session: CoffeeShiftSession) -> void:
	_refresh_orders(session)
	tasks.sync(session)
	orders_hint.visible = session.shift_open or not session.active_orders().is_empty()
	var minutes := int(session.clock) / 60
	business.text = session.business_name.to_upper()
	status.text = "ДЕНЬ %d   ·   %02d:%02d   ·   %s\nКасса: %d ₽   ·   Заказы: %d / 3" % [
		session.day, minutes / 60, minutes % 60,
		"СМЕНА ОТКРЫТА" if session.accepting else ("ЗАКАНЧИВАЕМ СМЕНУ" if session.shift_open else "СМЕНА ЗАКРЫТА"), session.cash.balance(), session.paid_orders().size()]
	guide.text = ""
	if not session.preparation.current.is_empty():
		var w: Dictionary = session.preparation.current
		guide.text = "ЗАКАЗ №%03d\n%s\n%s" % [int(w.order), session.catalog.caption(w.item), ShiftWorld.STEP_HINTS.get(session.preparation.next_step(session.catalog), "")]
		if w.running != "":
			guide.text += "\nТаймер: %.1f с" % float(w.elapsed)
			var r: Dictionary = session.catalog.recipes[w.recipe]
			var limits: Array = r.foam if w.running == "steam" else r.extraction
			guide.text += "\nОриентир: %d–%d с" % [int(limits[0]), int(limits[1])]
	elif session.selected_order > 0:
		var order := session.order_by_id(session.selected_order)
		if not order.is_empty():
			guide.text = "Выбран №%03d\n%s\nНачните с пакета кофе слева." % [session.selected_order, session.catalog.caption(order.items[session.selected_item])]
	elif session.shift_open:
		guide.text = "[E] — покупатель у окна\n[Tab] — выбрать напиток или вызвать номер\n[N] — справочник бариста"
	else:
		guide.text = "Откройте створку за ручку.\nСмена — переключатель справа от окна." if not session.window_open else "Смена — переключатель справа от окна."
	guide.visible = not guide.text.is_empty()

func _process(delta: float) -> void:
	# Keep an empty or short order list compact; long lists still scroll.
	var available := maxf(120, root.size.y - orders_panel.offset_top - 58)
	if _dialogue_mode and panel.visible:
		available = maxf(40, panel.get_global_rect().position.y - orders_panel.offset_top - 12)
		_update_dialogue_indicator()
	orders_panel.size.y = minf(available, orders_column.get_combined_minimum_size().y + 14)
	_advance_dialogue(delta)
	_message_time -= delta
	if _message_time <= 0:
		message.text = ""
