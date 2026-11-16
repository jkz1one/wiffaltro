class_name StadiumGrassFinish
extends RefCounted
## Small original tufts, never a collision or friction modifier. Clipped to the same grass mask.

const HEIGHTS: Dictionary = {"very_short": 0.015, "short": 0.025,
	"medium": 0.04, "long": 0.06}
const SPACING: float = 0.22


static func create(polygon: PackedVector2Array, masks: Array,
	length: String) -> MultiMeshInstance3D:
	if not HEIGHTS.has(length):
		return null
	var holes: Array = [PackedVector2Array([Vector2(-0.42, -0.30), Vector2(0.42, -0.30),
		Vector2(0.42, 0.30), Vector2(-0.42, 0.30)])]
	var mound: Vector2 = Vector2(PitchBatLab.MOUND_ORIGIN.x, PitchBatLab.MOUND_ORIGIN.z)
	holes.append(PackedVector2Array([mound + Vector2(-0.47, -0.47),
		mound + Vector2(0.47, -0.47), mound + Vector2(0.47, 0.47), mound + Vector2(-0.47, 0.47)]))
	for mask: PackedVector2Array in masks:
		holes.append_array(Geometry2D.offset_polygon(mask, 0.06))
	var interior: Array = Geometry2D.offset_polygon(polygon, -0.06)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 6100520
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var bounds: Rect2 = Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(point)
	for x in range(floori(bounds.position.x / SPACING), ceili(bounds.end.x / SPACING)):
		for z in range(floori(bounds.position.y / SPACING), ceili(bounds.end.y / SPACING)):
			# Per-cell seed keeps existing grass fixed when another region is cut or expanded.
			random.seed = (6100520 ^ (x * 73856093) ^ (z * 19349663)) & 0x7fffffff
			var point: Vector2 = (Vector2(x, z) + Vector2(
				random.randf_range(0.1, 0.9), random.randf_range(0.1, 0.9))) * SPACING
			if not _inside(point, interior) or _inside(point, holes):
				continue
			var basis: Basis = Basis(Vector3.UP, random.randf_range(0, TAU))
			basis = basis.scaled_local(Vector3(1, HEIGHTS[length] * random.randf_range(0.8, 1), 1))
			transforms.append(Transform3D(basis, Vector3(point.x, 0.004, point.y)))
			var shade: float = random.randf_range(0.92, 1.04)
			colors.append(Color(shade, shade, shade))
	var mesh: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mesh.name = "GrassTufts"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.multimesh = MultiMesh.new()
	mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.multimesh.use_colors = true
	mesh.multimesh.mesh = _mesh()
	mesh.multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		mesh.multimesh.set_instance_transform(index, transforms[index])
		mesh.multimesh.set_instance_color(index, colors[index])
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://src/presentation/stadium/surfaces/grass_blades.gdshader")
	material.set_shader_parameter("grass_color", Color("4b6e37"))
	mesh.material_override = material
	mesh.set_meta("grass_height", HEIGHTS[length])
	mesh.set_meta("authored_transforms", transforms)
	return mesh


static func _inside(point: Vector2, polygons: Array) -> bool:
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


static func _mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(8):
		var angle: float = index * 2.39996323
		var rotation: Basis = Basis(Vector3.UP, angle)
		var center: Vector3 = Vector3(cos(angle), 0, sin(angle)) * (0.012 + index * 0.004)
		var height: float = 0.79 + index * 0.03
		for row: Array in [[Vector3(-0.0025, 0, 0), Vector2(0, 0)],
			[Vector3(0.003, height, 0.006), Vector2(0.5, 1)],
			[Vector3(0.0025, 0, 0), Vector2(1, 0)]]:
			surface.set_uv(row[1])
			surface.set_normal(Vector3.UP)
			surface.add_vertex(center + rotation * row[0])
	return surface.commit()
