class_name EquipmentTaskList
extends VBoxContainer
const DEVICES := {"machine":"Осмотреть кофемашину", "grinder":"Осмотреть кофемолку", "fridge":"Осмотреть холодильник", "cash":"Осмотреть кассу"}
var rows: Dictionary = {}
var heading: Label
var _signature := ""
var _collapse: Tween
var collapsed := false

func _ready() -> void:
	name = "EquipmentTasks"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	add_theme_constant_override("separation",2)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",13)
	heading.add_theme_color_override("font_color",Color("e2d1a7"))
	heading.add_theme_color_override("font_shadow_color",Color("182722"))
	heading.add_theme_constant_override("shadow_offset_y",1)
	add_child(heading)
	for id in DEVICES:
		var row := EquipmentTaskRow.new()
		add_child(row)
		row.configure(DEVICES[id])
		rows[id] = row

func sync(session: CoffeeShiftSession, immediate: bool = false) -> void:
	var signature := JSON.stringify([session.equipment,session.shift_open])
	if signature == _signature and not immediate: return
	_signature = signature
	if _collapse != null: _collapse.kill()
	collapsed = false
	modulate.a = 1
	show()
	var count := 0
	for id in DEVICES:
		var done := session.equipment_status(id) == "COMPLETED"
		rows[id].set_completed(done,immediate)
		if done: count += 1
	heading.text = "ПОДГОТОВКА К СМЕНЕ   %d / 4" % count
	if count == 4 or session.shift_open:
		if immediate or session.shift_open: _hide_completed()
		else:
			_collapse = create_tween()
			# Leave all four strikes readable before automatically folding the list.
			_collapse.tween_interval(.9)
			_collapse.tween_property(self,"modulate:a",0.0,.28)
			_collapse.tween_callback(_hide_completed)

func _hide_completed() -> void:
	collapsed = true
	hide()
