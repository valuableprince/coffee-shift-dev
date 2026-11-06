class_name InteractionReticle
extends Control
## One geometric dot, in logical 1280x720 HUD units: 3.75 px at 1080p.
const DIAMETER := 2.5
const OUTLINE := .75
var hint: Label
var player: CoffeeShiftPlayer

func _ready() -> void:
	name = "InteractionReticle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint = Label.new()
	hint.name = "ContextHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_shadow_color", Color(.03, .05, .04, .95))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(hint)
	resized.connect(_layout_hint)
	_layout_hint()
	visible = false

func bind(owner_player: CoffeeShiftPlayer) -> void:
	player = owner_player
	_sync_visibility()

func _process(_delta: float) -> void:
	_sync_visibility()

func _sync_visibility() -> void:
	visible = is_instance_valid(player) and player.controls_enabled and player.mouse_captured
	if not visible: hint.text = ""

func _layout_hint() -> void:
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var half_width := minf(460, maxf(0, size.x / 2 - 16))
	hint.offset_left = -half_width
	hint.offset_right = half_width
	hint.offset_top = 16
	hint.offset_bottom = 78
	queue_redraw()

func _draw() -> void:
	draw_circle(size / 2, DIAMETER / 2 + OUTLINE, Color(.035, .045, .04, .96))
	draw_circle(size / 2, DIAMETER / 2, Color(.97, .97, .95))
