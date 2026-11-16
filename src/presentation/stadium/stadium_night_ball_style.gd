class_name StadiumNightBallStyle
extends RefCounted
## Mound-side pitch views get an interior dark rim against the lit receiver backdrop.

const VERSION: int = 1
const SOURCE: String = """shader_type spatial;
uniform vec4 ball_color : source_color = vec4(0.95, 0.95, 0.90, 1.0);
uniform float ball_roughness = 0.85;
void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float center = smoothstep(0.40, 0.65, facing);
	float mound_side = step(NODE_POSITION_WORLD.z, CAMERA_POSITION_WORLD.z);
	ALBEDO = mix(ball_color.rgb, mix(vec3(0.035), ball_color.rgb, center), mound_side);
	ROUGHNESS = ball_roughness;
}
"""


static func apply(ball: Node3D) -> void:
	if not is_instance_valid(ball) or ball.has_meta("night_ball_style"):
		return
	var captured: Array[Dictionary] = []
	for child: Node in ball.get_children():
		if (
			child is MeshInstance3D
			and (child.mesh is SphereMesh or (child is WiffleBallVisual and child.authored_mesh()))
			and child.material_override is StandardMaterial3D
		):
			var original: StandardMaterial3D = child.material_override
			var material: ShaderMaterial = ShaderMaterial.new()
			var shader: Shader = Shader.new()
			shader.code = SOURCE
			material.shader = shader
			material.set_shader_parameter("ball_color", original.albedo_color)
			material.set_shader_parameter("ball_roughness", original.roughness)
			captured.append(
				{"node": child, "mesh": child.mesh, "original": original, "working": material}
			)
			child.material_override = material
	ball.set_meta("night_ball_style_restore", captured)
	ball.set_meta("night_ball_style", VERSION)


static func restore(ball: Node3D) -> bool:
	if (
		not is_instance_valid(ball)
		or ball.get_meta("night_ball_style", 0) != VERSION
		or not ball.has_meta("night_ball_style_restore")
	):
		return false
	var captured: Variant = ball.get_meta("night_ball_style_restore")
	if not captured is Array:
		return false
	for row: Variant in captured:
		if (
			not row is Dictionary
			or row.size() != 4
			or not row.has_all(["node", "mesh", "original", "working"])
			or not is_instance_valid(row.node)
			or not row.node is MeshInstance3D
			or row.node.get_parent() != ball
			or row.node.mesh != row.mesh
			or row.node.material_override != row.working
		):
			return false
	for row: Dictionary in captured:
		row.node.material_override = row.original
	ball.remove_meta("night_ball_style_restore")
	ball.remove_meta("night_ball_style")
	return true
