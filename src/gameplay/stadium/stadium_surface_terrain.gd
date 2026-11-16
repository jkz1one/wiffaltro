class_name StadiumSurfaceTerrain
extends RefCounted
## One deterministic dirt patch. Working 5 mm / 2 m tuning, not a visual-disrepair claim.

const VERSION: int = 1
const ID: String = "owned-dirt-terrain-v1"
const MODES: Array[String] = ["rough", "leveled"]
const BOUNDS: Rect2 = Rect2(-26, -10, 52, 42)
const PATCH: Rect2 = Rect2(1, 10.5, 2, 2)
const HEIGHT: float = 0.005
const STEP: float = 0.125
const BOTTOM: float = -0.16
const QUERY_LAYER: int = 512


static func contract(mode: String) -> Dictionary:
	if not MODES.has(mode):
		return {}
	return {
		"version": VERSION,
		"id": ID,
		"mode": mode,
		"bounds": [-26, -10, 26, 32],
		"patch": [1, 10.5, 2, 2],
		"height": HEIGHT if mode == "rough" else 0.0,
		"step": STEP,
		"bottom": BOTTOM,
		"shape": "16*u*u*(1-u)*(1-u)*16*v*v*(1-v)*(1-v)",
		"topology": "clockwise-grid-diagonal-a-c-v1",
		"surface": "ordinary-ground-v1"
	}


static func valid(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.get("mode") is String
		and not contract(value.mode).is_empty()
		and ClubCareer.same(value, contract(value.mode))
	)


static func signature(mode: String) -> String:
	var data: Dictionary = contract(mode)
	return "" if data.is_empty() else JSON.stringify(data, "", true, true).sha256_text()


static func knots(axis: int) -> PackedFloat64Array:
	var result: PackedFloat64Array = [BOUNDS.position[axis]]
	for index in range(17):
		result.append(PATCH.position[axis] + float(index) * STEP)
	result.append(BOUNDS.end[axis])
	return result


static func _height(x: float, z: float, mode: String) -> float:
	if mode == "leveled":
		return 0.0
	var u: float = clampf((x - PATCH.position.x) / PATCH.size.x, 0.0, 1.0)
	var v: float = clampf((z - PATCH.position.y) / PATCH.size.y, 0.0, 1.0)
	return HEIGHT * 256.0 * u * u * (1.0 - u) * (1.0 - u) * v * v * (1.0 - v) * (1.0 - v)


static func _point(x: float, z: float, mode: String) -> Vector3:
	return Vector3(x, _height(x, z, mode), z)


static func support(at: Vector2, mode: String) -> Dictionary:
	if (
		not at.is_finite()
		or not MODES.has(mode)
		or at.x < BOUNDS.position.x
		or at.x > BOUNDS.end.x
		or at.y < BOUNDS.position.y
		or at.y > BOUNDS.end.y
	):
		return {}
	var xs: PackedFloat64Array = knots(0)
	var zs: PackedFloat64Array = knots(1)
	var ix: int = 0
	var iz: int = 0
	while ix < xs.size() - 2 and at.x >= xs[ix + 1]:
		ix += 1
	while iz < zs.size() - 2 and at.y >= zs[iz + 1]:
		iz += 1
	var a: Vector3 = _point(xs[ix], zs[iz], mode)
	var b: Vector3 = _point(xs[ix + 1], zs[iz], mode)
	var c: Vector3 = _point(xs[ix + 1], zs[iz + 1], mode)
	var d: Vector3 = _point(xs[ix], zs[iz + 1], mode)
	var u: float = inverse_lerp(a.x, b.x, at.x)
	var v: float = inverse_lerp(a.z, d.z, at.y)
	var normal: Vector3
	var y: float
	if v <= u:
		y = a.y * (1.0 - u) + b.y * (u - v) + c.y * v
		normal = (c - a).cross(b - a).normalized()
	else:
		y = a.y * (1.0 - v) + c.y * u + d.y * (v - u)
		normal = (d - a).cross(c - a).normalized()
	return {"position": Vector3(at.x, y, at.y), "normal": normal, "support_height": y}


static func geometry(mode: String) -> Dictionary:
	if not MODES.has(mode):
		return {}
	var data: Dictionary = {"faces": PackedVector3Array(), "normals": PackedVector3Array()}
	var xs: PackedFloat64Array = knots(0)
	var zs: PackedFloat64Array = knots(1)
	for iz in range(zs.size() - 1):
		for ix in range(xs.size() - 1):
			var a: Vector3 = _point(xs[ix], zs[iz], mode)
			var b: Vector3 = _point(xs[ix + 1], zs[iz], mode)
			var c: Vector3 = _point(xs[ix + 1], zs[iz + 1], mode)
			var d: Vector3 = _point(xs[ix], zs[iz + 1], mode)
			_triangle(data, a, b, c)
			_triangle(data, a, c, d)
	# Closed sides and bottom. Every perimeter top is exactly zero in both states.
	var lo: Vector3 = Vector3(BOUNDS.position.x, 0, BOUNDS.position.y)
	var hi: Vector3 = Vector3(BOUNDS.end.x, 0, BOUNDS.end.y)
	var top: Array[Vector3] = [lo, Vector3(hi.x, 0, lo.z), hi, Vector3(lo.x, 0, hi.z)]
	for index in range(4):
		var a: Vector3 = top[index]
		var b: Vector3 = top[(index + 1) % 4]
		var c: Vector3 = Vector3(b.x, BOTTOM, b.z)
		var d: Vector3 = Vector3(a.x, BOTTOM, a.z)
		_triangle(data, a, c, b)
		_triangle(data, a, d, c)
	_triangle(
		data, Vector3(lo.x, BOTTOM, lo.z), Vector3(hi.x, BOTTOM, hi.z), Vector3(hi.x, BOTTOM, lo.z)
	)
	_triangle(
		data, Vector3(lo.x, BOTTOM, lo.z), Vector3(lo.x, BOTTOM, hi.z), Vector3(hi.x, BOTTOM, hi.z)
	)
	return data


static func _triangle(data: Dictionary, a: Vector3, b: Vector3, c: Vector3) -> void:
	var outward: Vector3 = (c - a).cross(b - a).normalized()
	for point: Vector3 in [a, b, c]:
		data.faces.append(point)
		data.normals.append(outward)


static func build(mode: String) -> Node3D:
	var data: Dictionary = geometry(mode)
	if data.is_empty():
		return null
	var root: Node3D = Node3D.new()
	root.name = "OwnedSurfaceTerrain"
	root.set_meta("terrain", contract(mode))
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(data.faces.size()):
		tool.set_normal(data.normals[index])
		tool.add_vertex(data.faces[index])
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "TerrainVisual"
	mesh.mesh = tool.commit()
	mesh.material_override = StadiumSurfaceTexture.material(true, mode == "rough", 0.0, 0)
	(mesh.material_override as ShaderMaterial).set_shader_parameter("terrain_wear", true)
	root.add_child(mesh)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 1 | QUERY_LAYER
	body.collision_mask = 2
	body.set_meta("ball_surface", &"ground")
	var node: CollisionShape3D = CollisionShape3D.new()
	node.name = "ClosedTerrainShape"
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.margin = 0.0
	shape.backface_collision = false
	shape.set_faces(data.faces)
	node.shape = shape
	body.add_child(node)
	root.add_child(body)
	return root


static func path(from: Vector3, to: Vector3, budget: float, mode: String) -> Dictionary:
	if not from.is_finite() or not to.is_finite() or not is_finite(budget) or budget < 0:
		return {}
	var start: Dictionary = support(Vector2(from.x, from.z), mode)
	var goal: Dictionary = support(Vector2(to.x, to.z), mode)
	if start.is_empty() or goal.is_empty():
		return {}
	var delta: Vector2 = Vector2(to.x - from.x, to.z - from.z)
	var cuts: Array[float] = [0.0, 1.0]
	for axis in range(2):
		if delta[axis] == 0:
			continue
		for value: float in knots(axis):
			var fraction: float = (value - Vector2(from.x, from.z)[axis]) / delta[axis]
			if fraction > 0 and fraction < 1:
				cuts.append(fraction)
	cuts.sort()
	# Each grid-cell segment can cross its a-c diagonal once.
	var extra: Array[float] = []
	for index in range(cuts.size() - 1):
		var first: Vector2 = Vector2(from.x, from.z) + delta * cuts[index]
		var last: Vector2 = Vector2(from.x, from.z) + delta * cuts[index + 1]
		var middle: Vector2 = (first + last) * 0.5
		var xs: PackedFloat64Array = knots(0)
		var zs: PackedFloat64Array = knots(1)
		var ix: int = 0
		var iz: int = 0
		while ix < xs.size() - 2 and middle.x >= xs[ix + 1]:
			ix += 1
		while iz < zs.size() - 2 and middle.y >= zs[iz + 1]:
			iz += 1
		var a: float = (
			(first.x - xs[ix]) / (xs[ix + 1] - xs[ix]) - (first.y - zs[iz]) / (zs[iz + 1] - zs[iz])
		)
		var b: float = (
			(last.x - xs[ix]) / (xs[ix + 1] - xs[ix]) - (last.y - zs[iz]) / (zs[iz + 1] - zs[iz])
		)
		if a * b < 0:
			extra.append(lerpf(cuts[index], cuts[index + 1], a / (a - b)))
	cuts.append_array(extra)
	cuts.sort()
	var position: Vector3 = start.position
	var distance: float = 0.0
	var segments: int = 0
	for fraction: float in cuts:
		var sample: Dictionary = support(Vector2(from.x, from.z) + delta * fraction, mode)
		var next: Vector3 = sample.position
		var length: float = position.distance_to(next)
		if length > budget - distance:
			position = position.move_toward(next, maxf(0.0, budget - distance))
			distance = budget
			break
		position = next
		distance += length
		segments += 1
	return {"position": position, "distance": distance, "segments": segments}
