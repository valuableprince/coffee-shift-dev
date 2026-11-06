class_name CoffeeShiftMainMenu
extends Control
## Front-end for prototype careers, global settings and in-game pause.

signal continue_requested(career_id: int)
signal new_game_requested(career_id: int, overwrite: bool)
signal settings_updated
signal resume_requested
signal open_saves_requested
signal title_requested
signal exit_requested

var manager: RestorationSaveManager
var settings: CoffeeShiftSettings
var _mode := "title"
var _return_mode := "title"
var _stack: VBoxContainer
var _content: VBoxContainer
var _notice: Label
var _career_selector: OptionButton
var _new_career_selector: OptionButton
var _confirm_replace: ConfirmationDialog

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025,0.041,0.043,0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centered := CenterContainer.new()
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centered)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(550,570)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07,0.115,0.119,0.96)
	style.border_color = Color("bdac81")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 35
	style.content_margin_right = 35
	style.content_margin_top = 27
	style.content_margin_bottom = 23
	frame.add_theme_stylebox_override("panel",style)
	centered.add_child(frame)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation",14)
	frame.add_child(_stack)
	var heading := Label.new()
	heading.text = "COFFEE SHIFT"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",41)
	heading.add_theme_color_override("font_color",Color("f3e4bf"))
	_stack.add_child(heading)
	var tagline := Label.new()
	tagline.text = "КОФЕЙНЫЙ ТРЕЙЛЕР   ·   РОССИЯ, НАЧАЛО 2010-Х"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size",15)
	tagline.add_theme_color_override("font_color",Color("b4c6b9"))
	_stack.add_child(tagline)
	_stack.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stack.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation",12)
	scroll.add_child(_content)
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_color_override("font_color",Color("f2c58d"))
	_notice.add_theme_font_size_override("font_size",15)
	_notice.custom_minimum_size.y = 37
	_stack.add_child(_notice)
	_confirm_replace = ConfirmationDialog.new()
	_confirm_replace.title = "Начать новую игру?"
	_confirm_replace.ok_button_text = "Удалить и начать"
	_confirm_replace.cancel_button_text = "Отмена"
	_confirm_replace.confirmed.connect(_confirm_new_game)
	add_child(_confirm_replace)
	hide()

func configure(save_manager: RestorationSaveManager, preferences: CoffeeShiftSettings) -> void:
	manager = save_manager
	settings = preferences

func show_title() -> void:
	_mode = "title"
	_render()
	show()

func show_pause() -> void:
	_mode = "pause"
	_render()
	show()

func show_error(message: String) -> void:
	if _notice != null:
		_notice.text = message

func _render() -> void:
	if _content == null or manager == null or settings == null:
		return
	_career_selector = null
	_new_career_selector = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_notice.text = ""
	match _mode:
		"title":
			_render_title()
		"pause":
			_render_pause()
		"new_game":
			_render_new_game()
		"settings":
			_render_settings()

func _heading(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",23)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(label)

func _description(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",Color("c3cdbd"))
	label.add_theme_font_size_override("font_size",15)
	_content.add_child(label)

func _button(value: String, action: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 47
	button.add_theme_font_size_override("font_size",19)
	button.disabled = not enabled
	button.pressed.connect(action)
	_content.add_child(button)
	return button

func _any_save(career_id: int) -> bool:
	for row in manager.list_slots(career_id):
		if row.occupied:
			return true
	return false

func _valid_careers() -> Array[int]:
	var result: Array[int] = []
	for i in range(1,4):
		if not manager.latest(i).is_empty():
			result.append(i)
	return result

func _render_title() -> void:
	_heading("ГЛАВНОЕ МЕНЮ")
	_description("Первая торговая смена: готовый трейлер у городского сквера, ручное приготовление кофе и наличный расчёт.")
	var valid := _valid_careers()
	_career_selector = OptionButton.new()
	_career_selector.custom_minimum_size.y = 35
	for i in valid:
		_career_selector.add_item("Карьера %d — последнее сохранение" % i,i)
	_content.add_child(_career_selector)
	if not valid.is_empty():
		var preferred := valid.find(settings.last_career)
		_career_selector.select(maxi(0,preferred))
	else:
		_career_selector.add_item("Сохранений пока нет",0)
		_career_selector.disabled = true
	_button("Продолжить игру",_continue_game,not valid.is_empty())
	_button("Новая игра",_show_new_game)
	_button("Настройки",_show_settings_from_title)
	_button("Выход",func() -> void: exit_requested.emit())

func _render_pause() -> void:
	_heading("ПАУЗА")
	_button("Вернуться в игру",func() -> void: resume_requested.emit())
	_button("Сохранения / загрузка [F6]",func() -> void: open_saves_requested.emit())
	_button("Настройки",_show_settings_from_pause)
	_button("Главное меню",func() -> void: title_requested.emit())
	_button("Выход",func() -> void: exit_requested.emit())

func _render_new_game() -> void:
	_heading("НОВАЯ ИГРА")
	_description("Выберите карьеру. В одной карьере — три ручных и три автоматических сохранения.")
	_new_career_selector = OptionButton.new()
	_new_career_selector.custom_minimum_size.y = 40
	var initial := 0
	var found_free := false
	for i in range(1,4):
		var used := _any_save(i)
		_new_career_selector.add_item("Карьера %d — %s" % [i,"занята" if used else "свободна"],i)
		if not used and not found_free:
			initial = i-1
			found_free = true
	_new_career_selector.select(initial)
	_content.add_child(_new_career_selector)
	_description("Новая карьера начнётся в готовом трейлере на торговой площадке. Пролог в прототипе пропущен. Сохранения старого гаража сохраняются отдельно.")
	_button("Начать новую игру",_request_new_game)
	_button("Назад",_back_to_title)

func _continue_game() -> void:
	if _career_selector != null:
		continue_requested.emit(_career_selector.get_selected_id())

func _request_new_game() -> void:
	if _new_career_selector == null:
		return
	var id := _new_career_selector.get_selected_id()
	if id < 1 or id > 3:
		return
	if _any_save(id):
		_confirm_replace.dialog_text = "Сохранения карьеры %d будут удалены без возможности восстановления. Остальные карьеры не изменятся." % id
		_confirm_replace.popup_centered(Vector2i(510,180))
	else:
		new_game_requested.emit(id,false)

func _confirm_new_game() -> void:
	if _new_career_selector != null:
		new_game_requested.emit(_new_career_selector.get_selected_id(),true)

func _setting_slider(title: String, initial: float, minimum: float, maximum: float, step: float, change: Callable) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size",16)
	_content.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(change)
	_content.add_child(slider)

func _render_settings() -> void:
	_heading("НАСТРОЙКИ")
	_setting_slider("Общая громкость",settings.master_volume,0,100,5,func(value: float) -> void:
		settings.master_volume = roundi(value)
		settings_updated.emit())
	_setting_slider("Громкость эффектов",settings.effects_volume,0,100,5,func(value: float) -> void:
		settings.effects_volume = roundi(value)
		settings_updated.emit())
	var enabled := CheckBox.new()
	enabled.text = "Фоновая музыка"
	enabled.button_pressed = settings.music_enabled
	enabled.toggled.connect(func(value: bool) -> void:
		settings.music_enabled = value
		settings_updated.emit())
	_content.add_child(enabled)
	_setting_slider("Громкость музыки",settings.music_volume,0,100,5,func(value: float) -> void:
		settings.music_volume = roundi(value)
		settings_updated.emit())
	_setting_slider("Яркость",settings.brightness * 100,75,125,5,func(value: float) -> void:
		settings.brightness = value / 100.0
		settings_updated.emit())
	_description("Качество теней")
	var shadows := OptionButton.new()
	for caption in ["Выключены", "Обычные", "Высокие"]:
		shadows.add_item(caption)
	shadows.select(settings.shadow_quality)
	shadows.item_selected.connect(func(index: int) -> void:
		settings.shadow_quality = index
		settings_updated.emit())
	_content.add_child(shadows)
	var dialogue_toggle := CheckBox.new()
	dialogue_toggle.text = "Постепенное появление текста"
	dialogue_toggle.button_pressed = settings.dialogue_word_reveal
	dialogue_toggle.toggled.connect(func(value: bool) -> void:
		settings.dialogue_word_reveal = value
		settings_updated.emit())
	_content.add_child(dialogue_toggle)
	_setting_slider("Интервал между словами (мс)",settings.dialogue_word_interval * 1000.0,60,250,10,func(value: float) -> void:
		settings.dialogue_word_interval = value / 1000.0
		settings_updated.emit())
	_setting_slider("Чувствительность мыши",settings.mouse_sensitivity * 1000,0.8,5.0,0.2,func(value: float) -> void:
		settings.mouse_sensitivity = value / 1000.0
		settings_updated.emit())
	var fullscreen_toggle := CheckBox.new()
	fullscreen_toggle.text = "Полноэкранный режим"
	fullscreen_toggle.button_pressed = settings.fullscreen
	fullscreen_toggle.toggled.connect(func(value: bool) -> void:
		settings.fullscreen = value
		settings_updated.emit())
	_content.add_child(fullscreen_toggle)
	_description("Разрешение оконного режима")
	var sizes := OptionButton.new()
	for i in range(3):
		sizes.add_item("%d × %d" % [CoffeeShiftSettings.WIDTHS[i],CoffeeShiftSettings.HEIGHTS[i]],i)
	sizes.select(settings.resolution_index)
	sizes.item_selected.connect(func(index: int) -> void:
		settings.resolution_index = index
		settings_updated.emit())
	_content.add_child(sizes)
	_button("Назад",_back_from_settings)

func back() -> void:
	if _mode == "settings":
		_mode = _return_mode
		_render()
	elif _mode == "new_game":
		_mode = "title"
		_render()
	elif _mode == "pause":
		resume_requested.emit()

func _show_new_game() -> void:
	_mode = "new_game"
	_render()

func _show_settings_from_title() -> void:
	_return_mode = "title"
	_mode = "settings"
	_render()

func _show_settings_from_pause() -> void:
	_return_mode = "pause"
	_mode = "settings"
	_render()

func _back_to_title() -> void:
	_mode = "title"
	_render()

func _back_from_settings() -> void:
	_mode = _return_mode
	_render()

