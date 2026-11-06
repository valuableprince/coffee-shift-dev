class_name EquipmentTaskRow
extends Control
## Text with an animated strike; no rectangle or background is drawn.
var label: Label
var completed := false
var _tween: Tween
var strike: Line2D
var strike_shadow: Line2D
var progress := 0.0:
	set(value):
		progress = clampf(value,0,1)
		if is_instance_valid(label): label.modulate = Color.WHITE.lerp(Color(.58,.63,.59,.8),progress)
		_update_strike()

func configure(copy: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(246,26)
	label = Label.new()
	label.text = copy
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",15)
	label.add_theme_color_override("font_color",Color("eeeade"))
	label.add_theme_color_override("font_shadow_color",Color(.06,.08,.07,.9))
	label.add_theme_constant_override("shadow_offset_y",1)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strike_shadow = Line2D.new()
	strike_shadow.width = 2.4
	strike_shadow.default_color = Color(.06,.08,.07,.85)
	add_child(strike_shadow)
	strike = Line2D.new()
	strike.width = 1.2
	strike.antialiased = true
	strike.default_color = Color(.72,.76,.69)
	add_child(strike)
	resized.connect(_update_strike)

func set_completed(value: bool, immediate: bool = false) -> void:
	if value == completed and not immediate: return
	completed = value
	if _tween != null: _tween.kill()
	if immediate or not value: progress = 1.0 if value else 0.0
	else:
		_tween = create_tween()
		_tween.tween_property(self,"progress",1.0,.32).set_trans(Tween.TRANS_SINE)

func _update_strike() -> void:
	if not is_instance_valid(strike): return
	strike.visible = progress > 0
	strike_shadow.visible = progress > 0
	var font := label.get_theme_font("font")
	var width := minf(size.x,font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)
	var baseline := size.y * .51
	strike.points = PackedVector2Array([Vector2(0,baseline),Vector2(width * progress,baseline)])
	strike_shadow.points = strike.points
