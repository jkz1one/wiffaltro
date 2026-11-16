class_name StadiumGroundModels
extends RefCounted
## Authored visual-only masks; no friction, scoring, field size or physical-copy change.

const VERSION: int = 1
const IDS: Array[String] = ["ST-063e", "ST-063f", "ST-063i"]
const HEIGHT: float = 0.008


static func masks(id: String) -> Array:
	if id == "ST-063e":
		return [_ellipse(Vector2(-1.0, 0), Vector2(0.55, 1.1)),
			_ellipse(Vector2(1.0, 0), Vector2(0.55, 1.1)),
			_ellipse(Vector2(0, PitchBatLab.MOUND_ORIGIN.z), Vector2(1.15, 1.35))]
	if id in ["ST-063f", "ST-063i"]:
		return [_ellipse(Vector2(0, 0.45), Vector2(2.1, 2.7))]
	return []


static func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for index in range(64):
		points.append(center + Vector2(cos(index * TAU / 64), sin(index * TAU / 64)) * radius)
	return points


static func create(id: String) -> Node3D:
	if not IDS.has(id):
		return null
	var root: Node3D = Node3D.new()
	root.name = "GroundTreatment"
	root.set_meta("ground_style", id)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color: Color = Color("876143") if id == "ST-063e" else (
		Color("a65038") if id == "ST-063f" else Color("c9b985"))
	for mask: PackedVector2Array in masks(id):
		StadiumFieldStyleModels._polygon(surface, mask, color, HEIGHT)
		# Fixed small tonal flecks stay inside their exact mask, never player-painted scatter.
		for x in range(-12, 12):
			for z in range(-4, 54):
				var center: Vector2 = Vector2(x * 0.25 + 0.07, z * 0.3 + 0.11)
				if posmod(x * 7 + z * 3, 5) != 0:
					continue
				var fleck: PackedVector2Array = _ellipse(center, Vector2(0.09, 0.05))
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(fleck, mask):
					StadiumFieldStyleModels._polygon(surface, clipped,
						color.lightened(0.055), HEIGHT + 0.0005)
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
	var previous: Node = property.get_node_or_null("GroundTreatment")
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
