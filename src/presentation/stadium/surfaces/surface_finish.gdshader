shader_type spatial;
render_mode cull_disabled;

uniform sampler2D surface_noise : filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.22, 0.34, 0.16, 1.0);
uniform bool dirt_surface = false;
uniform bool terrain_wear = false;
uniform bool use_vertex_color = false;
uniform float vertex_pigment_scale = 1.0;
uniform float condition = 0.0;
uniform float grass_height = 0.025;
uniform int mowing_pattern = 0;
uniform float mowing_width = 1.2;
varying vec3 surface_world;

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Fixed, softly edged foot/traffic marks, used only by the owned dirt terrain.
float terrain_scuff_zone(vec2 p, vec2 center, vec2 radius, float grain) {
	return 1.0 - smoothstep(0.35, 1.0, length((p - center) / radius) + grain * 0.12);
}

void fragment() {
	vec2 p = surface_world.xz;
	vec4 fine = texture(surface_noise, p * 3.0);
	float broad = texture(surface_noise, p * 0.07).a;
	float grain = fine.r - 0.5;
	vec2 gradient = (fine.gb - vec2(0.5)) * 2.0;
	float direction = 0.0;
	vec2 axis = vec2(0.0, 1.0);
	vec2 mow = p / mowing_width;
	if (mowing_pattern == 1) {
		direction = smoothstep(-0.08, 0.08, sin(mow.y * PI)) * 2.0 - 1.0;
	} else if (mowing_pattern == 2) {
		direction = (smoothstep(-0.08, 0.08, sin(mow.x * PI)) * 2.0 - 1.0)
			* (smoothstep(-0.08, 0.08, sin(mow.y * PI)) * 2.0 - 1.0);
	} else if (mowing_pattern == 3) {
		mow = vec2(mow.x + mow.y, mow.y - mow.x) * 0.70710678;
		direction = (smoothstep(-0.08, 0.08, sin(mow.x * PI)) * 2.0 - 1.0)
			* (smoothstep(-0.08, 0.08, sin(mow.y * PI)) * 2.0 - 1.0);
		axis = vec2(0.70710678);
	} else if (mowing_pattern == 4) {
		direction = smoothstep(-0.08, 0.08, sin(length(mow) * PI)) * 2.0 - 1.0;
		axis = p / max(length(p), 0.001);
	}
	float relief = dirt_surface ? mix(0.05, 0.24, condition)
		: mix(0.07, 0.22, clamp(grass_height / 0.06, 0.0, 1.0));
	float mowing_lean = mix(0.045, 0.105, clamp(grass_height / 0.06, 0.0, 1.0));
	vec2 lean = dirt_surface ? vec2(0.0) : axis * direction * mowing_lean;
	vec3 world_normal = normalize(vec3(gradient.x * relief + lean.x, 1.0,
		gradient.y * relief + lean.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	float variation = dirt_surface ? grain * 0.17 + (broad - 0.5) * (0.10 + condition * 0.25)
		: grain * 0.08 + (broad - 0.5) * 0.07;
	vec3 pigment = use_vertex_color ? COLOR.rgb * vertex_pigment_scale : base_color.rgb;
	ALBEDO = pigment * (1.0 + variation);
	if (terrain_wear && dirt_surface) {
		// Working pigment tuning. No added broad cloud term, displacement or normal change.
		float traffic = terrain_scuff_zone(p, vec2(2.0, 11.5), vec2(1.8, 1.4), grain);
		float pitcher = terrain_scuff_zone(p, vec2(0.0, 13.2), vec2(0.75, 1.15), grain);
		float batter = terrain_scuff_zone(vec2(abs(p.x), p.y), vec2(0.75, 0.1), vec2(0.5, 0.95), grain);
		float zone = max(traffic, max(pitcher, batter));
		float flecks = texture(surface_noise, p * 0.75 + vec2(0.19, 0.43)).r;
		float drag = texture(surface_noise, p * vec2(0.55, 2.4) + vec2(0.63, 0.11)).r;
		float scuff = smoothstep(0.28, 0.72, flecks) * 0.7 + smoothstep(0.35, 0.7, drag) * 0.3;
		float wear = mix(0.12, 1.0, clamp(condition, 0.0, 1.0));
		ALBEDO *= 1.0 - zone * scuff * wear * 0.20;
	}
	ROUGHNESS = dirt_surface ? 0.98 : 0.92;
	SPECULAR = dirt_surface ? 0.03 : 0.12;
}
