class_name StadiumBaseMarkerModels
extends RefCounted
## Complete three-base visual sets; the existing home plate and logical bases stay unchanged.

const VERSION: int = 1
const IDS: Array[String] = ["ST-062c", "ST-062d"]


static func create(id: String) -> Node3D:
	if not IDS.has(id):
		return null
	var root: Node3D = Node3D.new()
	root.name = "BaseMarkerSet"
	root.set_meta("base_style", id)
	var raised: bool = id == "ST-062d"
	var index: int = 0
	for point: Vector2 in StadiumInfieldAnchors.bases():
		index += 1
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.name = "Base%d" % index
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.55, 0.075 if raised else 0.022, 0.55)
		marker.mesh = mesh
		marker.position = Vector3(point.x, 0.009 + mesh.size.y / 2, point.y)
		marker.rotation.y = PI / 4
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("eee8d7") if raised else Color("c5c5b5")
		material.roughness = 0.92
		marker.material_override = material
		root.add_child(marker)
	return root


static func apply(property: StadiumPropertyGeometry, id: String, stock: StadiumStock) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(property):
		return false
	if property == null or (not id.is_empty() and (
		not IDS.has(id) or stock == null or not stock.styles.has(id))):
		return false
	var previous: Node = property.get_node_or_null("BaseMarkerSet")
	if previous != null:
		property.remove_child(previous)
		previous.queue_free()
	if not id.is_empty():
		property.add_child(create(id))
	return true
