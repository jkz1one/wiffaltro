extends RefCounted
## Authored shell geometry and independent scalar ray controls.
# Pixel contrast/opaque raster coverage is not inferred.
const _SUPP_BODY = preload("res://src/presentation/ball/batted_ball_body.gd")
const _SUPP_VISUAL = preload("res://src/presentation/ball/wiffle_ball_visual.gd")
const _SUPP_OUTER: float = 0.075
const _SUPP_INNER: float = 0.0725
const _SUPP_GEOMETRY_EPS: float = 0.00001
# Witness-tested dimensionless scalar ray tolerances, not a geometry equivalence tolerance.
const _SUPP_REL_DET_EPS: float = 1.0e-12
const _SUPP_BARY_EPS: float = 1.0e-6


static func _supp_shell_geometry(visual: MeshInstance3D) -> Dictionary:
	var errors: Array[String] = []
	if (
		not visual is WiffleBallVisual
		or visual.get_script() != _SUPP_VISUAL
		or not visual.authored_mesh()
	):
		return {"errors": ["authored_identity"]}
	if (
		not visual.mesh is ArrayMesh
		or visual.mesh.get_surface_count() != 1
		or visual.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES
	):
		return {"errors": ["surface_contract"]}
	var arrays: Array = visual.mesh.surface_get_arrays(0)
	if (
		arrays.size() != Mesh.ARRAY_MAX
		or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array
		or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array
		or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
	):
		return {"errors": ["array_contract"]}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if (
		vertices.is_empty()
		or normals.size() != vertices.size()
		or indices.is_empty()
		or indices.size() % 3 != 0
	):
		return {"errors": ["array_lengths"]}
	var outer: int = 0
	var inner: int = 0
	var used: Dictionary = {}
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return {"errors": ["index_range"]}
		used[index] = true
	for index in range(vertices.size()):
		var vertex: Vector3 = vertices[index]
		if not vertex.is_finite() or not normals[index].is_finite():
			return {"errors": ["nonfinite_geometry"]}
		if not used.has(index):
			errors.append("unused_vertex")
		if absf(normals[index].length() - 1.0) > 0.0001:
			errors.append("normal_length")
		var radius: float = vertex.length()
		if absf(radius - _SUPP_OUTER) <= _SUPP_GEOMETRY_EPS:
			outer += 1
		elif absf(radius - _SUPP_INNER) <= _SUPP_GEOMETRY_EPS:
			inner += 1
		else:
			errors.append("shell_radius")
	var faces: PackedVector3Array = _supp_indexed_faces(visual.mesh)
	if faces.size() != indices.size():
		errors.append("face_count")
	for offset in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[offset]]
		var b: Vector3 = vertices[indices[offset + 1]]
		var c: Vector3 = vertices[indices[offset + 2]]
		if (b - a).cross(c - a).length_squared() <= 0.000000000000000001:
			errors.append("degenerate_triangle")
	if outer == 0 or inner == 0:
		errors.append("shell_populations")
	var apertures: Dictionary = _supp_apertures(faces)
	if apertures.open != 8 or apertures.closed != 8:
		errors.append("front_aperture_contract")
	return {
		"errors": errors,
		"vertices": vertices.size(),
		"indices": indices.size(),
		"outer_vertices": outer,
		"inner_vertices": inner,
		"apertures": apertures,
		"geometry_authority": "indexed_surface",
		"ray_method": "independent_normalized_scalar"
	}


static func _supp_apertures(faces: PackedVector3Array) -> Dictionary:
	var opened: int = 0
	var closed: int = 0
	# Independent authored-slot contract: mid-latitude0.84, eight centers45deg apart.
	# Stop inside the front shell so a hit on the rear wall cannot fake a closed aperture.
	for slot in range(8):
		for hole: bool in [true, false]:
			var phi: float = TAU * slot / 8.0 + (0.0 if hole else PI / 8.0)
			var direction: Vector3 = Vector3(cos(0.84), sin(0.84) * cos(phi), sin(0.84) * sin(phi))
			var start: Vector3 = direction * 0.15
			var finish: Vector3 = direction * 0.06525
			var hit: bool = false
			for index in range(0, faces.size() - 2, 3):
				if not (
					_supp_independent(
						start,
						finish,
						faces[index],
						faces[index + 1],
						faces[index + 2],
						1.0 / _SUPP_OUTER
					)
					. is_empty()
				):
					hit = true
					break
			if hole and not hit:
				opened += 1
			if not hole and hit:
				closed += 1
	return {"open": opened, "closed": closed}


static func _supp_current_shell(ball: BattedBallBody, mesh: MeshInstance3D) -> bool:
	return (
		ball.get_script() == _SUPP_BODY
		and mesh is WiffleBallVisual
		and mesh.get_script() == _SUPP_VISUAL
		and mesh.authored_mesh()
		and mesh.get_parent() == ball
		and mesh.visible
	)


static func _supp_indexed_faces(mesh: Mesh) -> PackedVector3Array:
	# get_faces() is a quantized derived representation in the pinned engine build.
	# Validate authoritative surface vertices/indices, without inventing an equivalence tolerance.
	var faces: PackedVector3Array = PackedVector3Array()
	if (
		not mesh is ArrayMesh
		or mesh.get_surface_count() != 1
		or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES
	):
		return faces
	var arrays: Array = mesh.surface_get_arrays(0)
	if (
		arrays.size() != Mesh.ARRAY_MAX
		or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array
		or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
	):
		return faces
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty() or indices.size() % 3 != 0:
		return faces
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return PackedVector3Array()
		faces.append(vertices[index])
	return faces


static func _supp_v(value: Vector3, scale: float = 1.0) -> Array:
	# Component arithmetic is scalar double, avoiding a normalized Vector3 round trip.
	return [float(value.x) * scale, float(value.y) * scale, float(value.z) * scale]


static func _supp_sub(a: Array, b: Array) -> Array:
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


static func _supp_cross(a: Array, b: Array) -> Array:
	return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


static func _supp_dot(a: Array, b: Array) -> float:
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


static func _supp_independent(
	start: Vector3, finish: Vector3, a: Vector3, b: Vector3, c: Vector3, scale: float
) -> Dictionary:
	var origin: Array = _supp_v(start, scale)
	var av: Array = _supp_v(a, scale)
	var direction: Array = _supp_sub(_supp_v(finish, scale), origin)
	var edge1: Array = _supp_sub(_supp_v(b, scale), av)
	var edge2: Array = _supp_sub(_supp_v(c, scale), av)
	var cross: Array = _supp_cross(direction, edge2)
	var determinant: float = _supp_dot(edge1, cross)
	var norm_product: float = sqrt(
		_supp_dot(edge1, edge1) * _supp_dot(edge2, edge2) * _supp_dot(direction, direction)
	)
	if norm_product == 0.0 or absf(determinant) <= _SUPP_REL_DET_EPS * norm_product:
		return {}
	var offset: Array = _supp_sub(origin, av)
	var u: float = _supp_dot(offset, cross) / determinant
	var q: Array = _supp_cross(offset, edge1)
	var v: float = _supp_dot(direction, q) / determinant
	var t: float = _supp_dot(edge2, q) / determinant
	if (
		u < -_SUPP_BARY_EPS
		or v < -_SUPP_BARY_EPS
		or u + v > 1.0 + _SUPP_BARY_EPS
		or t < 0.0
		or t > 1.0
	):
		return {}
	return {
		"t": t,
		"u": u,
		"v": v,
		"determinant": determinant,
		"relative_determinant": absf(determinant) / norm_product,
		"near_edge": minf(u, minf(v, 1.0 - u - v)) <= _SUPP_BARY_EPS
	}


static func _supp_ray_controls(owner: Node) -> void:
	# Positive controls prevent an always-miss implementation passing aperture centers.
	# Negative controls reject always-hit, infinite-line and degenerate-triangle behavior.
	var a: Vector3 = Vector3(0.0, -0.5, -0.5)
	var b: Vector3 = Vector3(0.0, 0.5, -0.5)
	var c: Vector3 = Vector3(0.0, 0.0, 0.5)
	var cases: Array = [
		["interior", Vector3(1, 0, 0), Vector3(-1, 0, 0), a, b, c, true],
		["reversed_winding", Vector3(1, 0, 0), Vector3(-1, 0, 0), a, c, b, true],
		["outside_triangle", Vector3(1, 2, 0), Vector3(-1, 2, 0), a, b, c, false],
		["outside_segment", Vector3(2, 0, 0), Vector3(1, 0, 0), a, b, c, false],
		["parallel", Vector3(1, 0, 0), Vector3(1, 0, 1), a, b, c, false],
		["degenerate", Vector3(1, 0, 0), Vector3(-1, 0, 0), a, b, b, false]
	]
	for scale: float in [0.001, 0.01, 0.075, 1.0, 10.0]:
		for row: Array in cases:
			var points: Array = [
				row[1] * scale, row[2] * scale, row[3] * scale, row[4] * scale, row[5] * scale
			]
			var hit: Dictionary = _supp_independent(
				points[0], points[1], points[2], points[3], points[4], 1.0 / scale
			)
			owner._check(
				(not hit.is_empty()) == bool(row[6]),
				(
					"supplementary R2 independent normalized ray %s at physical scale %s"
					% [row[0], scale]
				)
			)
