class_name StadiumNpcMogulOneStandV1
extends RefCounted
## Retained AM-01/r1 correspondence. Original: stadium_baseline_sightline_models.gd
## Working ST029 lower-only v2. Frozen v1, all decks/people and site frames remain untouched.

const VERSION: int = 2
const VARIANT: String = "BASE-LOWER-SIGHTLINE-v2"
const GUARD_CENTER: Vector3 = Vector3(-0.35, 3.45, 0.06)
const GUARD_SIZE: Vector3 = Vector3(5.3, 0.9, 0.12)


static func lower(occupied: bool = true) -> Node3D:
	var root: Node3D = StadiumNpcClubStandV1.lower(occupied)
	var mesh: MeshInstance3D = root.get_node("Visual/FrontGuard")
	var body: StaticBody3D = root.get_node("Collision/FrontGuard")
	var shape: CollisionShape3D = body.get_child(0)
	# This bounded variant is valid only for the frozen predecessor's actual one-meter guard.
	if (
		mesh.position != Vector3(-0.35, 3.5, 0.06)
		or body.position != mesh.position
		or not mesh.mesh is BoxMesh
		or not shape.shape is BoxShape3D
		or mesh.mesh.size != Vector3(5.3, 1, 0.12)
		or shape.shape.size != mesh.mesh.size
	):
		root.free()
		return null
	mesh.position = GUARD_CENTER
	(mesh.mesh as BoxMesh).size = GUARD_SIZE
	body.position = GUARD_CENTER
	(shape.shape as BoxShape3D).size = GUARD_SIZE
	root.name = "ST029LowerSightlineV2Working"
	root.set_meta("model_version", VERSION)
	root.set_meta("model_variant", VARIANT)
	root.set_meta("authoring_status", "Working")
	return root
