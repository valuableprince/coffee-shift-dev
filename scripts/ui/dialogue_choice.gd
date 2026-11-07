class_name DialogueChoice
extends Button
## Button semantics and accessibility with a quiet row and a drawn pointer.
func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		if not disabled: grab_focus()
		queue_redraw())
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	if disabled or not (has_focus() or is_hovered()): return
	var y := size.y * .5
	draw_colored_polygon(PackedVector2Array([Vector2(11, y - 4), Vector2(16, y), Vector2(11, y + 4)]), DialogueStyle.NAME)
