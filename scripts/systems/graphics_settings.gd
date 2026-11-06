class_name CoffeeShiftGraphics
extends CanvasLayer
## Neutral brightness works in Godot 4.3 Compatibility; UI stays on higher layers.
var correction: ColorRect

func _ready() -> void:
	layer = 0
	correction = ColorRect.new()
	correction.name = "Brightness"
	correction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/brightness.gdshader")
	correction.material = material
	add_child(correction)
	correction.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	correction.hide()

func apply(preferences: CoffeeShiftSettings) -> void:
	(correction.material as ShaderMaterial).set_shader_parameter("brightness", preferences.brightness)
	correction.visible = not is_equal_approx(preferences.brightness, 1.0)
	get_viewport().positional_shadow_atlas_size = [512, 1024, 2048][preferences.shadow_quality]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][preferences.shadow_quality], false)
	for light in get_parent().find_children("*", "Light3D", true, false):
		if not light.has_meta("designed_shadow"):
			light.set_meta("designed_shadow", light.shadow_enabled)
		light.shadow_enabled = preferences.shadow_quality > 0 and bool(light.get_meta("designed_shadow"))
