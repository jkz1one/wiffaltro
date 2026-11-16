extends Node
## Exercise the actual audit intersection path at physical and normalized scales.
const Audit = preload("res://src/tests/stadium_yard_two_visibility_audit.gd")
var failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var host: Node3D = Node3D.new()
	add_child(host)
	var a: Vector3 = Vector3(0, -0.5, -0.5)
	var b: Vector3 = Vector3(0, 0.5, -0.5)
	var c: Vector3 = Vector3(0, 0, 0.5)
	var cases: Array = [
		["interior", Vector3(1, 0, 0), Vector3(-1, 0, 0), a, b, c, true],
		["reversed", Vector3(1, 0, 0), Vector3(-1, 0, 0), a, c, b, true],
		["outside_triangle", Vector3(1, 2, 0), Vector3(-1, 2, 0), a, b, c, false],
		["outside_segment", Vector3(2, 0, 0), Vector3(1, 0, 0), a, b, c, false],
		["parallel", Vector3(1, 0, 0), Vector3(1, 0, 1), a, b, c, false],
		["degenerate", Vector3(1, 0, 0), Vector3(-1, 0, 0), a, b, b, false],
	]
	var count: int = 0
	for scale_value: float in [0.001, 0.01, 0.075, 1.0, 10.0]:
		for row: Array in cases:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
				[row[3] * scale_value, row[4] * scale_value, row[5] * scale_value]
			)
			var geometry: ArrayMesh = ArrayMesh.new()
			geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.mesh = geometry
			host.add_child(mesh)
			mesh.position = Vector3(3, -4, 5)
			mesh.basis = Basis(Vector3.UP, 0.37).scaled(Vector3(2, 0.5, 3))
			var from: Vector3 = mesh.global_transform * (row[1] * scale_value)
			var to: Vector3 = mesh.global_transform * (row[2] * scale_value)
			var hits: Array[Dictionary] = Audit._intersections(mesh, from, to, {})
			var passed: bool = (not hits.is_empty()) == bool(row[6])
			if passed and row[6]:
				passed = absf(hits[0].distance - from.distance_to(mesh.global_position)) < 0.00001
			count += 1
			if not passed:
				failures += 1
				push_error("Triangle normalization failed: %s scale=%s" % [row[0], scale_value])
			mesh.free()
	host.free()
	print("AY02_TRIANGLE_SCALE_CONTROLS cases=", count, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
