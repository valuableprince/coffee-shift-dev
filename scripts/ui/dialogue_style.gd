class_name DialogueStyle
extends RefCounted
## Local to dialogue UI; equipment, cash and DEV-05 themes stay independent.
const FONT := preload("res://assets/fonts/rubik/Rubik-Medium.ttf")
const FONT_NOTICE := preload("res://assets/fonts/rubik/license_notice.tres")
const TEXT := Color("f5f0e8")
const NAME := Color("e8c89c")
const SECONDARY := Color("e1dcd3")

static func surface() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Color("45413c"), .94)
	box.set_corner_radius_all(8)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 13
	box.content_margin_bottom = 12
	box.shadow_color = Color(0, 0, 0, .18)
	box.shadow_size = 4
	return box

static func choice_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Color("655747"), .94) if selected else Color(0, 0, 0, 0)
	box.set_corner_radius_all(4)
	box.content_margin_left = 27
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	# An exported resource dependency keeps the complete OFL notice in the PCK.
	result.set_meta("font_license", FONT_NOTICE)
	result.default_font_size = 18
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", SECONDARY)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_focus_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", TEXT)
	result.set_color("font_disabled_color", "Button", Color(Color("e1dcd3"), .40))
	for state in ["normal", "disabled", "hover", "pressed", "focus", "hover_pressed"]:
		result.set_stylebox(state, "Button", choice_style(state not in ["normal", "disabled"]))
	# Quiet scrollbar, with no stock arrows, border or blue focus frame.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(Color("706a60"), .20)
	track.content_margin_left = 3
	track.content_margin_right = 3
	result.set_stylebox("scroll", "VScrollBar", track)
	var grip := StyleBoxFlat.new()
	grip.bg_color = Color(Color("e8c89c"), .55)
	grip.set_corner_radius_all(3)
	grip.content_margin_left = 3
	grip.content_margin_right = 3
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		result.set_stylebox(state, "VScrollBar", grip)
	var empty := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		result.set_icon(icon, "VScrollBar", empty)
	return result
