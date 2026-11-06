shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float brightness : hint_range(0.75, 1.25) = 1.0;

void fragment() {
	COLOR = vec4(texture(screen_texture, SCREEN_UV).rgb * brightness, 1.0);
}
