class_name StadiumInfieldModels
extends RefCounted
## Three original dirt footprints. Convex component masks preserve genuine grass holes.

const VERSION: int = 1
const IDS: Array[String] = ["ST-063g", "ST-063h", "ST-063j"]
const HEIGHT: float = 0.008


static func masks(id: String) -> Array:
	var result: Array = []
	if id == "ST-063g":
		var diamond: Array[Vector2] = StadiumInfieldAnchors.diamond()
		for index in range(4):
			var a: Vector2 = diamond[index]
			var b: Vector2 = diamond[(index + 1) % 4]
			var n: Vector2 = Vector2(-(b - a).y, (b - a).x).normalized() * 0.65
			result.append(PackedVector2Array([a - n, b - n, b + n, a + n]))
		for point: Vector2 in StadiumInfieldAnchors.bases():
			result.append(StadiumGroundModels._ellipse(point, Vector2(1.25, 1.25)))
		result.append(StadiumGroundModels._ellipse(Vector2.ZERO, Vector2(1.8, 2.25)))
		result.append(StadiumGroundModels._ellipse(
			Vector2(0, PitchBatLab.MOUND_ORIGIN.z), Vector2(1.2, 1.4)))
	elif id == "ST-063h":
		var fan: PackedVector2Array = [Vector2.ZERO]
		for index in range(49):
			var angle: float = deg_to_rad(48.0 - index * 2.0)
			fan.append(Vector2(sin(angle), cos(angle)) * 21.5)
		result.append(fan)
		result.append(StadiumGroundModels._ellipse(Vector2.ZERO, Vector2(2.1, 2.7)))
	elif id == "ST-063j":
		var points: PackedVector2Array = []
		for point: Vector2 in StadiumInfieldAnchors.diamond():
			points.append_array(StadiumGroundModels._ellipse(point, Vector2(2.2, 2.2)))
		var hull: PackedVector2Array = Geometry2D.convex_hull(points)
		if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]):
			hull.remove_at(hull.size() - 1)
		result.append(hull)
	var clipped: Array = []
	for mask: PackedVector2Array in result:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(
			mask, StadiumFieldStyleModels.polygon()):
			clipped.append(_ccw(piece))
	return clipped


static func _ccw(points: PackedVector2Array) -> PackedVector2Array:
	var signed_area: float = 0
	for index in range(points.size()):
		signed_area += points[index].cross(points[(index + 1) % points.size()])
	if signed_area < 0:
		points.reverse()
	return points


static func pieces(id: String) -> Array:
	var result: Array = []
	var previous: Array = []
	for mask: PackedVector2Array in masks(id):
		result.append_array(StadiumSurfaceMask.subtract(mask, previous))
		previous.append(mask)
	return result


static func create(id: String) -> Node3D:
	if not IDS.has(id):
		return null
	var root: Node3D = Node3D.new()
	root.name = "InfieldTreatment"
	root.set_meta("ground_style", id)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color: Color = Color("876143") if id == "ST-063g" else (
		Color("a65038") if id == "ST-063h" else Color("c9b985"))
	var ground: Array = pieces(id)
	for piece: PackedVector2Array in ground:
		StadiumFieldStyleModels._polygon(surface, piece, color, HEIGHT)
	if id == "ST-063j":
		for row in range(-16, 120):
			var z: float = row * 0.2
			var stripe: PackedVector2Array = [Vector2(-24, z), Vector2(24, z),
				Vector2(24, z + 0.018), Vector2(-24, z + 0.018)]
			for piece: PackedVector2Array in ground:
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(stripe, piece):
					StadiumFieldStyleModels._polygon(surface, clipped, color.darkened(0.055),
						HEIGHT + 0.0005)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "SurfaceVisual"
	mesh.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	return root


static func apply(property: StadiumPropertyGeometry, id: String, selection: Dictionary,
	stock: StadiumStock) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(property):
		return false
	if property == null or (not id.is_empty() and (
		not IDS.has(id) or stock == null or not stock.styles.has(id))):
		return false
	if not StadiumFieldStylePrototype.apply(property, selection, stock):
		return false
	for name_value: String in ["InfieldTreatment", "GroundTreatment"]:
		var previous: Node = property.get_node_or_null(NodePath(name_value))
		if previous != null:
			property.remove_child(previous)
			previous.queue_free()
	if id.is_empty():
		return true
	if not selection.grass.is_empty():
		var path: String = "FieldStylePreview/" + selection.grass.replace("-", "") + "/StyleVisual"
		StadiumSurfaceMask.clip_grass(property.get_node(path), masks(id))
	property.add_child(create(id))
	return true
