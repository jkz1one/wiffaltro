class_name StadiumRecipeFieldStyles
extends RefCounted
## Same original mowing patterns clipped to an exact recipe polygon; frozen styles stay unchanged.

const VERSION: int = 1
const CHANNELS: Dictionary = {"line": ["ST-062a", "ST-062b"],
	"grass": ["ST-063a", "ST-063b", "ST-063c", "ST-063d"]}
const DARK: Color = Color("315640")
const LIGHT: Color = Color("3d664a")


static func create(id: String, field: FieldDefinition,
	graph: StadiumRecipeBoundary) -> Node3D:
	if graph == null or (not CHANNELS.line.has(id) and not CHANNELS.grass.has(id)):
		return null
	var root: Node3D = Node3D.new()
	root.name = id.replace("-", "")
	root.set_meta("field_style", id)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if CHANNELS.line.has(id):
		_lines(surface, id, field, graph)
	elif id == "ST-063d":
		_arcs(surface, graph.polygon())
	else:
		_grid(surface, id, graph.polygon())
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "StyleVisual"
	mesh.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	return root


static func _grid(surface: SurfaceTool, id: String, mask: PackedVector2Array) -> void:
	var diamond: bool = id == "ST-063c"
	for x in range(-12, 12):
		for z in range(-12, 12):
			var points: PackedVector2Array = [Vector2(x, z) * 3, Vector2(x + 1, z) * 3,
				Vector2(x + 1, z + 1) * 3, Vector2(x, z + 1) * 3]
			if diamond:
				for index in range(points.size()):
					points[index] = points[index].rotated(PI / 4)
			var parity: int = posmod(z if id == "ST-063a" else x + z, 2)
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(points, mask):
				_polygon(surface, clipped, LIGHT if parity == 0 else DARK, 0.004)


static func _arcs(surface: SurfaceTool, mask: PackedVector2Array) -> void:
	for ring in range(12):
		var inner: float = ring * 3.0
		var outer: float = inner + 3.0
		for slice in range(96):
			var a: Vector2 = Vector2.RIGHT.rotated(slice * TAU / 96)
			var b: Vector2 = Vector2.RIGHT.rotated((slice + 1) * TAU / 96)
			var points: PackedVector2Array = [a * inner, a * outer, b * outer, b * inner]
			if ring == 0:
				points = PackedVector2Array([Vector2.ZERO, a * outer, b * outer])
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(points, mask):
				_polygon(surface, clipped, LIGHT if ring % 2 == 0 else DARK, 0.004)


static func foul_end(field: FieldDefinition, graph: StadiumRecipeBoundary, side: int) -> Vector3:
	var direction: Vector3 = Vector3(side * tan(deg_to_rad(field.fair_half_angle_degrees)), 0, 1)
	var event: Dictionary = graph.crossing(Vector3.ZERO, direction * 1000)
	return event.get("position", Vector3.ZERO)


static func _lines(surface: SurfaceTool, id: String, field: FieldDefinition,
	graph: StadiumRecipeBoundary) -> void:
	var chalk: bool = id == "ST-062a"
	for side in [-1, 1]:
		var point: Vector3 = foul_end(field, graph, side)
		var end: Vector2 = Vector2(point.x, point.z)
		var normal: Vector2 = Vector2(-end.y, end.x).normalized()
		var width: float = 0.035 if chalk else 0.055
		_polygon(surface, PackedVector2Array([-normal * width, end - normal * width,
			end + normal * width, normal * width]), Color("e9e5d5"), 0.04)
		if not chalk:
			continue
		# Authored deterministic edge chips, never random scoring-line displacement.
		for index in range(100):
			var along: Vector2 = end * (float(index) + 0.25) / 100.0
			var length: Vector2 = end.normalized() * (0.04 + (index % 4) * 0.01)
			var edge: Vector2 = normal * (0.044 + (index % 3) * 0.006)
			for sign_value in [-1, 1]:
				var center: Vector2 = along + edge * sign_value
				_polygon(surface, PackedVector2Array([center - length - normal * 0.014,
					center + length - normal * 0.014, center + length + normal * 0.014,
					center - length + normal * 0.014]), Color("cbc9b9"), 0.04)


static func _polygon(surface: SurfaceTool, points: PackedVector2Array,
	color: Color, height: float) -> void:
	StadiumFieldStyleModels._polygon(surface, points, color, height)


static func apply(property: StadiumPropertyGeometry, graph: StadiumRecipeBoundary,
	selection: Dictionary, ground: String, stock: StadiumStock) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(property):
		return false
	if property == null or graph == null or not StadiumFieldStylePrototype.validate(selection, stock):
		return false
	var masks: Array = []
	if not ground.is_empty():
		if not stock.styles.has(ground) or (not StadiumGroundModels.IDS.has(ground)
			and not StadiumInfieldModels.IDS.has(ground)):
			return false
		masks = StadiumInfieldModels.masks(ground) if StadiumInfieldModels.IDS.has(ground) \
			else StadiumGroundModels.masks(ground)
	var root: Node3D = Node3D.new()
	root.name = "FieldStylePreview"
	for channel: String in CHANNELS:
		var id: String = selection[channel]
		if id.is_empty():
			continue
		var model: Node3D = create(id, property.field, graph)
		if channel == "grass" and not masks.is_empty():
			StadiumSurfaceMask.clip_grass(model.get_node("StyleVisual"), masks)
		root.add_child(model)
	var previous: Node = property.get_node_or_null("FieldStylePreview")
	if previous != null:
		property.remove_child(previous)
		previous.queue_free()
	property.add_child(root)
	for side: int in [-1, 1]:
		var end: Vector3 = foul_end(property.field, graph, side)
		var line: Node3D = property.get_node("FoulLine" + str(side))
		line.position = end / 2 + Vector3(0, 0.02, 0)
		line.rotation.y = atan2(end.x, end.z)
		var mesh: MeshInstance3D = line.get_child(0)
		mesh.mesh.size = Vector3(0.055, 0.025, end.length())
		line.visible = selection.line.is_empty()
	return true
