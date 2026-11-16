shader_type sky;
// Fixed decorative sky only. No time uniform, atmospheric model or field illumination.
uniform vec4 top_color : source_color = vec4(0.03137, 0.05882, 0.13333, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.07843, 0.14902, 0.23922, 1.0);
uniform vec4 ground_color : source_color = vec4(0.05490, 0.10431, 0.16745, 1.0);
uniform float star_strength : hint_range(0.0, 0.04) = 0.0;

void sky() {
	float height = max(EYEDIR.y, 0.0);
	vec3 base = mix(horizon_color.rgb, top_color.rgb, pow(height, 0.45));
	if (EYEDIR.y < 0.0) {
		base = mix(horizon_color.rgb, ground_color.rgb, min(-EYEDIR.y * 3.0, 1.0));
	}
	vec2 grid = SKY_COORDS * vec2(720.0, 360.0);
	vec2 cell = floor(grid);
	float fixed_seed = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	vec2 center = fract(grid) - vec2(0.5);
	float point = 1.0 - smoothstep(0.025, 0.12, length(center));
	float stars = step(0.995, fixed_seed) * point * smoothstep(0.08, 0.30, height);
	COLOR = base + vec3(0.70, 0.79, 1.0) * stars * star_strength;
}
