class_name StadiumSurfaceMask
extends RefCounted
## Convex-mask subtraction without hole triangulation or hidden grass overlap.


static func subtract(points: PackedVector2Array, masks: Array) -> Array:
	var pieces: Array = [points]
	for mask: PackedVector2Array in masks:
		var next: Array = []
		for piece: PackedVector2Array in pieces:
			next.append_array(_outside(piece, mask))
		pieces = next
	return pieces


static func _outside(points: PackedVector2Array, mask: PackedVector2Array) -> Array:
	var result: Array = []
	var remaining: PackedVector2Array = points
	for index in range(mask.size()):
		if remaining.size() < 3:
			break
		var a: Vector2 = mask[index]
		var b: Vector2 = mask[(index + 1) % mask.size()]
		var outside: PackedVector2Array = _half(remaining, a, b, false)
		if outside.size() >= 3 and area(outside) > 0.000000001:
			result.append(outside)
		remaining = _half(remaining, a, b, true)
	return result


static func _half(points: PackedVector2Array, a: Vector2, b: Vector2,
	inside: bool) -> PackedVector2Array:
	var result: PackedVector2Array = []
	if points.is_empty():
		return result
	var sign_value: float = 1.0 if inside else -1.0
	var previous: Vector2 = points[-1]
	var previous_side: float = (b - a).cross(previous - a) * sign_value
	for point: Vector2 in points:
		var side: float = (b - a).cross(point - a) * sign_value
		if (side >= 0) != (previous_side >= 0):
			result.append(previous.lerp(point, previous_side / (previous_side - side)))
		if side >= 0:
			result.append(point)
		previous = point
		previous_side = side
	return result


static func clip_grass(mesh: MeshInstance3D, masks: Array) -> void:
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(0, vertices.size(), 3):
		var triangle: PackedVector2Array = []
		for offset in range(3):
			triangle.append(Vector2(vertices[index + offset].x, vertices[index + offset].z))
		for piece: PackedVector2Array in subtract(triangle, masks):
			StadiumFieldStyleModels._polygon(surface, piece, colors[index], vertices[index].y)
	mesh.mesh = surface.commit()


static func area(points: PackedVector2Array) -> float:
	var result: float = 0
	for index in range(points.size()):
		result += points[index].cross(points[(index + 1) % points.size()])
	return absf(result) / 2
