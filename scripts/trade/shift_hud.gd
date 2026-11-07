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
var extraction_timer: Label
var next_step_hint: Label
var _action_panel: PanelContainer
var _timer_panel: PanelContainer
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
var _words := DialogueWordReveal.new()
var _word_ends: Array[int]:
	get: return _words.word_ends
var _word_index: int:
	get: return _words.index
var _dialogue_buttons: Array[Button] = []
var _modal_style: StyleBoxFlat
var _dialogue_style: StyleBoxFlat
var _dialogue_mode := false
var _dialogue_text_scroll: ScrollContainer
var _dialogue_indicator: Label
var _dialogue_navigation: Array[Button] = []
var _dialogue_actions_scroll: ScrollContainer
var _dialogue_actions: VBoxContainer
var _dialogue_back: Button
var _dialogue_header: HBoxContainer
var _dialogue_footer: HBoxContainer
var _dialogue_generation := 0
var _dialogue_action_used := false
var _dialogue_can_close := true
var _skip_release := 0
var aside: PanelContainer
var _aside_speaker: Label
var _aside_copy: Label
var _aside_words := DialogueWordReveal.new()
var _aside_time := 0.0

func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var status_panel := _overlay(Vector2i(14, 9))
	status_panel.position = Vector2(20, 16)
	status_panel.custom_minimum_size.x = 305
	var status_lines := VBoxContainer.new()
	status_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(status_lines)
	business = _label(Vector2.ZERO, 18)
	business.reparent(status_lines, false)
	business.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	business.add_theme_color_override("font_color", Color("eed7a6"))
	status = _label(Vector2.ZERO, 15)
	status.reparent(status_lines, false)
	message = _label(Vector2(20, 113), 16)
	message.size = Vector2(440, 90)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_outline_color", Color("202923"))
	message.add_theme_constant_override("outline_size", 4)
	guide = _label(Vector2.ZERO, 14)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_color_override("font_color", Color("f0dcab"))
	_timer_panel = _overlay(Vector2i(16, 8))
	_timer_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_panel.offset_left = -161
	_timer_panel.offset_right = 161
	_timer_panel.offset_top = 22
	_timer_panel.offset_bottom = 64
	extraction_timer = _label(Vector2.ZERO, 21)
	extraction_timer.name = "ExtractionTimer"
	extraction_timer.reparent(_timer_panel, false)
	extraction_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extraction_timer.hide()
	_timer_panel.hide()
	_action_panel = _overlay(Vector2i(16, 9))
	_action_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_action_panel.offset_left = -244
	_action_panel.offset_right = 244
	_action_panel.offset_bottom = -48
	_action_panel.offset_top = -90
	var action_lines := VBoxContainer.new()
	action_lines.add_theme_constant_override("separation", 4)
	action_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel.add_child(action_lines)
	next_step_hint = _label(Vector2.ZERO, 16)
	next_step_hint.name = "NextStepHint"
	next_step_hint.reparent(action_lines, false)
	next_step_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_step_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_step_hint.add_theme_color_override("font_color", Color("f4ead3"))
	next_step_hint.hide()
	hint = _label(Vector2.ZERO, 15)
	hint.name = "ContextHint"
	hint.reparent(action_lines, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("bedfcd"))
	_action_panel.hide()
	reticle = InteractionReticle.new()
	root.add_child(reticle)
	var controls := _label(Vector2.ZERO, 12)
	control_hints = controls
	controls.name = "ControlHints"
	controls.text = "WASD — ходьба   E — взаимодействовать   Tab — заказы   N — справочник   F6 — сохранения   Esc — меню"
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
	_dialogue_style = DialogueStyle.surface()
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
	panel.visibility_changed.connect(_update_overlays)
	_build_aside()
	get_viewport().size_changed.connect(func() -> void:
		if panel.visible:
			_layout_panel(_dialogue_mode)
			if _dialogue_mode: call_deferred("_fit_dialogue_panel")
		if aside.visible: _layout_aside())

func _overlay(inset: Vector2i) -> PanelContainer:
	var overlay := PanelContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.075, .126, .112, .94)
	style.border_color = Color(.56, .63, .50, .37)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0, 0, 0, .3)
	style.shadow_size = 4
	style.content_margin_left = inset.x
	style.content_margin_right = inset.x
	style.content_margin_top = inset.y
	style.content_margin_bottom = inset.y
	overlay.add_theme_stylebox_override("panel", style)
	root.add_child(overlay)
	return overlay

func _update_overlays() -> void:
	var available := not panel.visible and not orders_editing
	hint.visible = not hint.text.is_empty()
	_action_panel.visible = available and (next_step_hint.visible or hint.visible)
	if _action_panel.visible:
		_action_panel.offset_top = _action_panel.offset_bottom - _action_panel.get_combined_minimum_size().y
	_timer_panel.visible = available and extraction_timer.visible

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
	_outline(orders_hint)
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
	_outline(guide)
	order_cards = VBoxContainer.new()
	order_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_cards.add_theme_constant_override("separation", 5)
	column.add_child(order_cards)

func set_orders_editing(value: bool) -> void:
	orders_editing = value
	orders_hint.text = "ЗАКАЗЫ   ·   [Tab/Esc] вернуться" if value else "ЗАКАЗЫ   ·   [Tab] выбрать"
	_update_overlays()

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
		_outline(heading)
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
			call.disabled = order.status != "ready" or (order.items.size() > 1 and order.packed.size() != order.items.size())
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

func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(.07, .10, .08, .92))
	label.add_theme_constant_override("outline_size", 3)

func say(value: String) -> void:
	message.text = value
	_message_time = 7.0

func set_dialogue_preferences(enabled: bool, word_interval: float) -> void:
	dialogue_word_reveal = enabled
	dialogue_word_interval = clampf(word_interval, 0.06, 0.25)
	if not enabled and _is_typing(): _reveal_dialogue()
	if not enabled: _aside_words.reveal()

func _layout_panel(is_dialogue: bool) -> void:
	_dialogue_mode = is_dialogue
	panel.theme = DialogueStyle.theme() if is_dialogue else null
	if is_dialogue:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		var viewport_size := get_viewport().get_visible_rect().size
		var factor := _dialogue_scale()
		var width := minf(760.0 * factor, viewport_size.x - 32.0)
		panel.offset_left = -width * .5
		panel.offset_right = width * .5
		panel.offset_bottom = -22.0 * factor
		panel.offset_top = panel.offset_bottom - 136.0 * factor
		_dialogue_style.content_margin_left = 20 * factor
		_dialogue_style.content_margin_right = 20 * factor
		_dialogue_style.content_margin_top = 13 * factor
		_dialogue_style.content_margin_bottom = 12 * factor
		panel_content.add_theme_constant_override("separation", roundi(7 * factor))
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
	# canvas_items already scales the logical viewport at 1080p.
	var view := get_viewport().get_visible_rect().size
	return clampf(minf(view.x / 1280.0, view.y / 720.0), .8, 1.5)

func _fit_dialogue_panel() -> void:
	if not _dialogue_mode or not panel.visible: return
	var factor := _dialogue_scale()
	for label in panel_content.find_children("*", "Label", true, false):
		label.add_theme_font_size_override("font_size", roundi((12 if label == _dialogue_indicator else 17 if label.name == "Speaker" else 19) * factor))
	for button in _dialogue_navigation:
		button.add_theme_font_size_override("font_size", roundi((12 if button == _dialogue_back else 16) * factor))
		button.custom_minimum_size.y = (25 if button == _dialogue_back else 34) * factor
	if _dialogue_text_scroll != null:
		var line_height := float(_dialogue_copy.get_line_height())
		var three_lines := line_height * 3 + _dialogue_copy.get_theme_constant("line_spacing") * 2
		_dialogue_text_scroll.custom_minimum_size.y = clampf(_dialogue_copy.get_combined_minimum_size().y, line_height, three_lines)
	if _dialogue_actions_scroll != null:
		_dialogue_actions_scroll.custom_minimum_size.y = minf(_dialogue_actions.get_combined_minimum_size().y, 122 * factor)
	var view_height := get_viewport().get_visible_rect().size.y
	var content_height := panel_content.get_combined_minimum_size().y + 25.0 * factor
	var desired := clampf(content_height, 136.0 * factor, minf(300.0 * factor, view_height * .43))
	panel.offset_top = panel.offset_bottom - desired

func _is_typing() -> bool:
	return _dialogue_mode and panel.visible and _words.is_typing()

func _reveal_dialogue() -> void:
	_words.reveal()
	for button in _dialogue_buttons:
		if is_instance_valid(button): button.disabled = _dialogue_action_used
	_update_dialogue_indicator()
	if not _dialogue_buttons.is_empty() and not _dialogue_action_used: _dialogue_buttons[0].grab_focus()

func _update_dialogue_indicator() -> void:
	if not is_instance_valid(_dialogue_indicator): return
	_dialogue_indicator.text = "Space / ЛКМ — весь текст" if _is_typing() else "↑ ↓  выбор     Enter / ЛКМ  ответ"
	if _dialogue_copy != null and _dialogue_text_scroll != null and _dialogue_copy.size.y > _dialogue_text_scroll.size.y + 1:
		_dialogue_indicator.text += "     PgUp / PgDn  текст"

func _activate_dialogue_action(generation: int, callback: Callable) -> void:
	if generation != _dialogue_generation or _dialogue_action_used or _is_typing() or not panel.visible: return
	_dialogue_action_used = true
	for button in _dialogue_buttons: button.disabled = true
	# Only the authoritative callback applies order / story / economy effects.
	callback.call()

func show_panel(title: String, body: String, actions: Array = [], is_dialogue: bool = false, can_close: bool = true) -> void:
	clear_aside()
	_dialogue_generation += 1
	var generation := _dialogue_generation
	_dialogue_action_used = false
	_dialogue_can_close = can_close
	_layout_panel(is_dialogue)
	_dialogue_copy = null
	_words.clear()
	_dialogue_buttons.clear()
	_dialogue_navigation.clear()
	_dialogue_text_scroll = null
	_dialogue_actions_scroll = null
	_dialogue_indicator = null
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.name = "Speaker"
	heading.text = title
	heading.add_theme_font_size_override("font_size", 17 if is_dialogue else 26)
	if is_dialogue:
		heading.add_theme_color_override("font_color", DialogueStyle.NAME)
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dialogue_header = HBoxContainer.new()
		panel_content.add_child(_dialogue_header)
		_dialogue_header.add_child(heading)
	else: panel_content.add_child(heading)
	var copy := Label.new()
	copy.text = body
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size", 19 if is_dialogue else 18)
	if is_dialogue:
		_dialogue_copy = copy
		_words.start(copy, dialogue_word_reveal)
		_dialogue_text_scroll = ScrollContainer.new()
		_dialogue_text_scroll.name = "DialogueText"
		_dialogue_text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_dialogue_text_scroll.custom_minimum_size.y = 27 * _dialogue_scale()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel_content.add_child(_dialogue_text_scroll)
		_dialogue_text_scroll.add_child(copy)
		_dialogue_actions_scroll = ScrollContainer.new()
		_dialogue_actions_scroll.name = "DialogueReplies"
		_dialogue_actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_dialogue_actions_scroll.follow_focus = true
		panel_content.add_child(_dialogue_actions_scroll)
		_dialogue_actions = VBoxContainer.new()
		_dialogue_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dialogue_actions.add_theme_constant_override("separation", 2)
		_dialogue_actions_scroll.add_child(_dialogue_actions)
	else: panel_content.add_child(copy)
	var grid: GridContainer
	for action in actions:
		var button: Button = DialogueChoice.new() if is_dialogue else Button.new()
		button.text = str(action.label)
		button.custom_minimum_size.y = 34 if is_dialogue else 40
		button.disabled = bool(action.get("disabled", false))
		if is_dialogue:
			if not button.disabled:
				_dialogue_buttons.append(button)
				button.disabled = _words.is_typing()
			var callback: Callable = action.call
			button.pressed.connect(func() -> void: _activate_dialogue_action(generation, callback))
			_dialogue_navigation.append(button)
			_dialogue_actions.add_child(button)
		elif action.get("grid", false):
			button.pressed.connect(action.call)
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
			button.pressed.connect(action.call)
			grid = null
			panel_content.add_child(button)
	var back := Button.new()
	back.text = "К работе [Esc]" if is_dialogue else "Вернуться к работе [Esc]"
	back.custom_minimum_size.y = 25 if is_dialogue else 42
	back.pressed.connect(request_close_panel)
	back.visible = can_close
	if is_dialogue:
		_dialogue_back = back
		_dialogue_footer = HBoxContainer.new()
		panel_content.add_child(_dialogue_footer)
		_dialogue_indicator = Label.new()
		_dialogue_indicator.add_theme_color_override("font_color", Color("e1dcd3"))
		_dialogue_indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dialogue_footer.add_child(_dialogue_indicator)
		_dialogue_footer.add_child(back)
		if can_close: _dialogue_navigation.append(back)
	else: panel_content.add_child(back)
	panel.show()
	if is_dialogue:
		_update_dialogue_indicator()
		_fit_dialogue_panel()
		call_deferred("_fit_dialogue_panel")
		if not _is_typing() and not _dialogue_buttons.is_empty(): _dialogue_buttons[0].grab_focus()

func request_close_panel() -> void:
	if _dialogue_mode and not _dialogue_can_close: return
	close_panel()

func close_panel() -> void:
	dismiss_panel()
	panel_closed.emit()

func dismiss_panel() -> void:
	# Menu/load transitions clear the view without briefly recapturing the mouse.
	panel.hide()
	control_hints.visible = true
	_dialogue_copy = null
	_words.clear()
	_dialogue_buttons.clear()
	_dialogue_navigation.clear()
	_dialogue_mode = false
	_dialogue_generation += 1
	_skip_release = 0

func _input(event: InputEvent) -> void:
	if not _dialogue_mode or not panel.visible: return
	if _skip_release != 0:
		var released: bool = (event is InputEventKey and not event.pressed and event.keycode == _skip_release) or (event is InputEventMouseButton and not event.pressed and _skip_release == -1 and event.button_index == MOUSE_BUTTON_LEFT)
		if released:
			_skip_release = 0
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed:
		if event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN] and _dialogue_text_scroll != null:
			_dialogue_text_scroll.scroll_vertical += roundi(_dialogue_text_scroll.size.y) * (1 if event.keycode == KEY_PAGEDOWN else -1)
			get_viewport().set_input_as_handled()
			return
		if not _is_typing() and event.keycode in [KEY_UP, KEY_DOWN]:
			var available := _dialogue_navigation.filter(func(b: Button) -> bool: return not b.disabled and b.visible)
			if not available.is_empty():
				var index := available.find(get_viewport().gui_get_focus_owner())
				var step := 1 if event.keycode == KEY_DOWN else -1
				available[posmod(index + step, available.size())].grab_focus()
			get_viewport().set_input_as_handled()
			return
	if not _is_typing(): return
	var skip := false
	if event is InputEventKey:
		skip = event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]
		if skip: _skip_release = event.keycode
	elif event is InputEventMouseButton:
		skip = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if skip: _skip_release = -1
	if skip:
		_reveal_dialogue()
		get_viewport().set_input_as_handled()

func _advance_dialogue(delta: float) -> void:
	if not _is_typing(): return
	_words.advance(delta, dialogue_word_interval)
	if not _words.is_typing(): _reveal_dialogue()

func _build_aside() -> void:
	aside = PanelContainer.new()
	aside.name = "CustomerAside"
	aside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.theme = DialogueStyle.theme()
	aside.add_theme_stylebox_override("panel", DialogueStyle.surface())
	root.add_child(aside)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.add_child(column)
	_aside_speaker = Label.new()
	_aside_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aside_speaker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_aside_speaker.add_theme_color_override("font_color", DialogueStyle.NAME)
	column.add_child(_aside_speaker)
	_aside_copy = Label.new()
	_aside_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aside_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_aside_copy)
	aside.hide()

func _layout_aside() -> void:
	var factor := _dialogue_scale()
	aside.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	var width := minf(620 * factor, root.size.x - 32)
	aside.offset_left = -width * .5
	aside.offset_right = width * .5
	aside.offset_bottom = -65 * factor
	_aside_speaker.add_theme_font_size_override("font_size", roundi(14 * factor))
	_aside_copy.add_theme_font_size_override("font_size", roundi(17 * factor))
	# Do not measure a hidden wrapping Label before its first layout: at width
	# zero its cached minimum height can inflate the panel above the viewport.
	aside.offset_top = aside.offset_bottom - 100 * factor

func show_aside(speaker: String, body: String, duration: float = 6.0) -> bool:
	if panel.visible or body.strip_edges().is_empty(): return false
	_aside_speaker.text = speaker
	_aside_copy.text = body
	_aside_words.start(_aside_copy, dialogue_word_reveal)
	# Read time begins after reveal; slow typing cannot expire a half-read line.
	_aside_time = maxf(3.0, duration)
	_layout_aside()
	aside.show()
	return true

func clear_aside() -> void:
	if aside != null: aside.hide()
	_aside_words.clear()
	_aside_time = 0

func refresh(session: CoffeeShiftSession, operation_hint: String = "") -> void:
	_refresh_orders(session)
	tasks.sync(session)
	orders_hint.visible = session.shift_open or not session.active_orders().is_empty()
	var minutes := int(session.clock) / 60
	business.text = session.business_name.to_upper()
	status.text = "ДЕНЬ %d   ·   %02d:%02d   ·   %s\nКасса: %d ₽   ·   Заказы: %d / 3" % [
		session.day, minutes / 60, minutes % 60,
		"СМЕНА ОТКРЫТА" if session.accepting else ("ЗАКАНЧИВАЕМ СМЕНУ" if session.shift_open else "СМЕНА ЗАКРЫТА"), session.cash.balance(), session.paid_orders().size()]
	guide.text = ""
	extraction_timer.hide()
	next_step_hint.hide()
	if not session.preparation.current.is_empty():
		var w: Dictionary = session.preparation.current
		var next_step := session.preparation.next_step(session.catalog)
		var instruction := operation_hint if not operation_hint.is_empty() else ShiftWorld.handling_hint(w, next_step)
		if instruction.is_empty():
			instruction = str(ShiftWorld.STEP_HINTS.get(next_step, ""))
		next_step_hint.text = instruction
		next_step_hint.show()
		guide.text = "ЗАКАЗ №%03d\n%s" % [int(w.order), session.catalog.caption(w.item)]
		if w.running in ["extract", "steam"]:
			var recipe: Dictionary = session.catalog.recipes[w.recipe]
			var limits: Array = recipe.foam if w.running == "steam" else recipe.extraction
			var title := "ПАР" if w.running == "steam" else "ЭКСТРАКЦИЯ"
			var elapsed := ("%.1f" % float(w.elapsed)).replace(".", ",")
			extraction_timer.text = "%s — %s с  ·  %d–%d с" % [title, elapsed, int(limits[0]), int(limits[1])]
			extraction_timer.add_theme_color_override("font_color", Color("a6d6b0") if float(w.elapsed) >= float(limits[0]) and float(w.elapsed) <= float(limits[1]) else (Color("f3b1a6") if float(w.elapsed) > float(limits[1]) else Color("f4ead3")))
			extraction_timer.show()
	elif session.selected_order > 0:
		var order := session.order_by_id(session.selected_order)
		if not order.is_empty() and session.selected_item < order.items.size():
			if order.status == "ready":
				var needs_carrier: bool = order.items.size() > 1 and order.packed.size() != order.items.size()
				next_step_hint.text = "Соберите стаканы заказа №%03d в картонный держатель" % int(order.id) if needs_carrier else "Заказ №%03d готов. Нажмите Tab и вызовите покупателя" % int(order.id)
				if needs_carrier and not order.carrier:
					next_step_hint.text = "Возьмите картонный держатель для заказа №%03d" % int(order.id)
				next_step_hint.show()
				guide.text = "Соберите напитки в держатель" if needs_carrier else "Вызвать №%03d через Tab" % int(order.id)
			elif order.status == "called":
				next_step_hint.text = "Дождитесь покупателя и наведите на него прицел"
				next_step_hint.show()
				guide.text = "Покупатель идёт к окну"
			elif order.items[session.selected_item].ready:
				next_step_hint.text = "Нажмите Tab и выберите следующий напиток"
				next_step_hint.show()
			else:
				guide.text = "Выбран №%03d\n%s" % [session.selected_order, session.catalog.caption(order.items[session.selected_item])]
				next_step_hint.text = "Возьмите рожок у кофемашины"
				next_step_hint.show()
	elif session.shift_open:
		guide.text = "[E] — покупатель у окна\n[Tab] — выбрать напиток или вызвать номер\n[N] — справочник бариста"
	else:
		guide.text = "Откройте створку за ручку.\nСмена — переключатель справа от окна." if not session.window_open else "Смена — переключатель справа от окна."
	if not operation_hint.is_empty():
		next_step_hint.text = operation_hint
		next_step_hint.show()
	guide.visible = not guide.text.is_empty()
	_update_overlays()

func _process(delta: float) -> void:
	_update_overlays()
	# Keep an empty or short order list compact; long lists still scroll.
	var available := maxf(120, root.size.y - orders_panel.offset_top - 58)
	if _dialogue_mode and panel.visible:
		available = maxf(40, panel.get_global_rect().position.y - orders_panel.offset_top - 12)
		_update_dialogue_indicator()
	orders_panel.size.y = minf(available, orders_column.get_combined_minimum_size().y + 14)
	_advance_dialogue(delta)
	if aside.visible:
		if _aside_words.is_typing(): _aside_words.advance(delta, dialogue_word_interval)
		else: _aside_time -= delta
		if _aside_time <= 0: clear_aside()
	_message_time -= delta
	if _message_time <= 0:
		message.text = ""
