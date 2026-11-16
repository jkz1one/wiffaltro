shader_type spatial;
render_mode cull_disabled;

uniform vec4 grass_color : source_color = vec4(0.25, 0.36, 0.16, 1.0);

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float detail = 1.0 - smoothstep(8.0, 18.0, distance(world, CAMERA_POSITION_WORLD));
	VERTEX.xz *= detail;
	VERTEX.y *= detail;
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = grass_color.rgb * COLOR.rgb * mix(0.86, 1.04, UV.y);
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}
