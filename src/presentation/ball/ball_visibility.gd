class_name BallVisibility
extends Node3D

# Historical ball positions only. Never predicts a landing or a Pitch path.
const TRAIL_SECONDS: float = 0.065
const TRAIL_LENGTH_M: float = 0.9
var _shadow: MeshInstance3D
var _trail: MeshInstance3D
var _mesh: ImmediateMesh = ImmediateMesh.new()
var _history: Array[Vector3] = []
var _ages: Array[float] = []


func _ready() -> void:
	_shadow = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(0.46, 0.46)
	_shadow.mesh = plane
	var shader: Shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	ALBEDO = vec3(0.015, 0.025, 0.02);
	ALPHA = (1.0 - smoothstep(0.15, 0.5, length(UV - vec2(0.5)))) * 0.32;
}"""
	var shadow_material: ShaderMaterial = ShaderMaterial.new()
	shadow_material.shader = shader
	_shadow.material_override = shadow_material
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_trail = MeshInstance3D.new()
	_trail.mesh = _mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	clear()


func clear() -> void:
	_history.clear()
	_ages.clear()
	_mesh.clear_surfaces()
	visible = false


func update_ball(ball: BattedBallBody, camera: Camera3D, delta: float, wall_z: float) -> void:
	if ball == null:
		clear()
		return
	visible = true
	var point: Vector3 = ball.global_position
	_shadow.visible = point.y > 0.12 and point.z <= wall_z
	_shadow.position = Vector3(point.x, 0.018, point.z)
	_shadow.scale = Vector3.ONE * clampf(1.0 + point.y * 0.025, 1.0, 1.5)
	_mesh.clear_surfaces()
	if ball.freeze or ball.linear_velocity.length() < 12.0:
		_history.clear()
		_ages.clear()
		return
	for index in range(_ages.size()):
		_ages[index] += delta
	while not _ages.is_empty() and (
		_ages[0] > TRAIL_SECONDS or _history[0].distance_to(point) > TRAIL_LENGTH_M
	):
		_ages.pop_front()
		_history.pop_front()
	_history.append(point)
	_ages.append(0.0)
	if _history.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1, _history.size()):
		var start: Vector3 = _history[index - 1]
		var end: Vector3 = _history[index]
		var side: Vector3 = (end - start).cross(camera.global_position - end).normalized()
		var fade: float = 1.0 - _ages[index - 1] / TRAIL_SECONDS
		var width: Vector3 = side * 0.035 * fade
		_mesh.surface_set_color(Color(1.0, 0.96, 0.76, 0.22 * fade))
		for vertex in [start - width, start + width, end + width,
			start - width, end + width, end - width]:
			_mesh.surface_add_vertex(vertex)
	_mesh.surface_end()
