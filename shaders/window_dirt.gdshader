shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float cleaned : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float dust_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	// UV.y runs along the window: a widening wiped band exposes the actual glass.
	float dust = dust_noise(UV * vec2(9.0, 14.0));
	float fine = dust_noise(UV * vec2(110.0, 165.0));
	float streak = smoothstep(0.5, 0.85, dust_noise(vec2(UV.y * 43.0, UV.x * 0.7)));
	float remaining = step(cleaned, UV.y);
	ALBEDO = mix(vec3(0.29, 0.30, 0.25), vec3(0.53, 0.51, 0.42), dust);
	ALPHA = (0.62 + 0.18 * streak + 0.08 * fine) * remaining;
}
