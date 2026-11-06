class_name RestorationSaveMenu
extends Control

signal career_requested(career_id: int)
signal close_requested
var manager: RestorationSaveManager
var careers: OptionButton
var rows: VBoxContainer
var feedback_label: Label
var confirmation: ConfirmationDialog
var _pending_slot := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.06,.08,.07,.96)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := VBoxContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 125
	panel.offset_right = -125
	panel.offset_top = 65
	panel.offset_bottom = -45
	panel.add_theme_constant_override("separation",16)
	var title := Label.new()
	title.text = "СОХРАНЕНИЯ ВОССТАНОВЛЕНИЯ"
	title.add_theme_font_size_override("font_size",28)
	panel.add_child(title)
	careers = OptionButton.new()
	for i in range(1,4):
		careers.add_item("Карьера %d" % i,i)
	careers.item_selected.connect(func(index: int) -> void: career_requested.emit(index+1))
	panel.add_child(careers)
	var note := Label.new()
	note.text = "У каждой карьеры свои 3 ручные и 3 автоматические точки.\nПри смене карьеры текущий прогресс сохраняется автоматически."
	panel.add_child(note)
	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color",Color("e2cf95"))
	feedback_label.custom_minimum_size.y = 24
	panel.add_child(feedback_label)
	rows = VBoxContainer.new()
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",10)
	panel.add_child(rows)
	var back := Button.new()
	back.text = "Вернуться в гараж [F6 / Esc]"
	back.pressed.connect(func() -> void: close_requested.emit())
	panel.add_child(back)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Заменить ручное сохранение?"
	confirmation.dialog_text = "Содержимое выбранной ручной ячейки будет заменено текущим прогрессом этой карьеры."
	confirmation.ok_button_text = "Заменить"
	confirmation.cancel_button_text = "Отмена"
	confirmation.confirmed.connect(func() -> void: _save(_pending_slot,true))
	add_child(confirmation)
	hide()

func bind(save_manager: RestorationSaveManager) -> void:
	manager = save_manager
	manager.slots_changed.connect(refresh)
	manager.feedback.connect(func(message: String) -> void: feedback_label.text = message)
	refresh()

func refresh() -> void:
	if manager == null:
		return
	careers.select(manager.career-1)
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for data in manager.list_slots(manager.career):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",16)
		rows.add_child(row)
		var caption := Label.new()
		var text := "Пусто"
		if data.occupied:
			text = str(data.timestamp).replace("T","  ") if data.valid else "Повреждено / другая версия"
		if data.recovered:
			text += " · резервная копия"
		caption.text = "%s %d    ·    %s" % ["Ручная" if data.kind=="manual" else "Авто",data.slot,text]
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		if data.kind == "manual":
			var save_button := Button.new()
			save_button.text = "Сохранить"
			save_button.pressed.connect(_save.bind(int(data.slot),false))
			row.add_child(save_button)
		var load_button := Button.new()
		load_button.text = "Загрузить"
		load_button.disabled = not data.valid
		load_button.pressed.connect(func() -> void: manager.load_slot(manager.career,data.kind,int(data.slot)))
		row.add_child(load_button)

func _save(slot: int, confirmed: bool) -> void:
	if manager.occupied(manager.career,"manual",slot) and not confirmed:
		_pending_slot = slot
		confirmation.popup_centered(Vector2i(570,180))
		return
	var error := manager.save_slot("manual",slot,confirmed)
	manager.feedback.emit("Прогресс сохранён." if error == OK else "Не удалось сохранить. Проверьте доступ к диску. Код: %d" % error)
