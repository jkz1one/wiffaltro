class_name StadiumLongYardLowerRoofModels
extends RefCounted
## Explicit guard-v2 lower canopy with one bounded right-post support correction.

const VERSION: int = 2
const VARIANT: String = "BASE-LOWER-CANOPY-GUARD-v2"
const ENVELOPE: AABB = AABB(Vector3(-3.25, 5.7, 0), Vector3(6.5, 2.94, 7))


static func canopy_reference() -> Node3D:
	var roof: Node3D = StadiumBaselineStandModels.lower_canopy()
	var mesh: MeshInstance3D = roof.get_node("Visual/RearColumn1")
	var body: StaticBody3D = roof.get_node("Collision/RearColumn1")
	var shape: CollisionShape3D = body.get_child(0)
	if mesh.position != Vector3(2.7, 7.2, 6.6) or body.position != mesh.position \
		or not mesh.mesh is BoxMesh or not shape.shape is BoxShape3D \
		or mesh.mesh.size != Vector3(0.18, 2.4, 0.18) or shape.shape.size != mesh.mesh.size:
		roof.free()
		return null
	# Its original y6 foot floats above the outer stair. Retain the upper endpoint8.4,
	# but extend only this post down to stair37(y5.7), embedding0.15 into stair38.
	mesh.position = Vector3(2.7, 7.05, 6.6)
	(mesh.mesh as BoxMesh).size = Vector3(0.18, 2.7, 0.18)
	body.position = mesh.position
	(shape.shape as BoxShape3D).size = mesh.mesh.size
	roof.set_meta("model_version", VERSION)
	roof.set_meta("model_variant", VARIANT)
	roof.set_meta("authoring_status", "Working")
	return roof


static func create(lower: Node3D, site: String) -> Node3D:
	if not StadiumLongYardLowerRoofSites.valid_lower(lower, site):
		return null
	if not StadiumLongYardLowerRoofSites.vacant(lower, null, site):
		return null
	var roof: Node3D = canopy_reference()
	if roof == null:
		return null
	roof.transform = StadiumBaselineSites.pose(site)
	roof.set_meta("lower_instance", lower.get_instance_id())
	roof.set_meta("site", site)
	roof.set_meta("interface", StadiumLongYardLowerRoofSites.INTERFACE)
	return roof
