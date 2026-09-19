class_name TrajectoryDebugDraw
extends MeshInstance3D

var _immediate_mesh := ImmediateMesh.new()

func _ready() -> void:
	mesh = _immediate_mesh

func clear() -> void:
	_immediate_mesh.clear_surfaces()

func draw_polyline(points: Array[Vector3]) -> void:
	clear()
	if points.size() < 2:
		return

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in points:
		_immediate_mesh.surface_add_vertex(point)
	_immediate_mesh.surface_end()
