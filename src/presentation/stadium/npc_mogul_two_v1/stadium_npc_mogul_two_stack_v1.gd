class_name StadiumNpcMogulTwoStackV1
extends RefCounted
## Isolated additive compatibility variants; no new catalog identities or venue grant.

const VERSION: int = 2
const ROOF_HEIGHT: float = 13.65


static func _variant(root: Node3D, variant: String) -> Node3D:
	root.set_meta("model_version", VERSION)
	root.set_meta("model_variant", variant)
	root.set_meta("authoring_status", "Working")
	return root


static func _concourse() -> Node3D:
	return _variant(StadiumNpcMogulTwoStraightV1._concourse(), "STRAIGHT-CONCOURSE-GUARD-v2")


static func _upper(occupied: bool = true) -> Node3D:
	return _variant(StadiumNpcMogulTwoStraightV1._upper(occupied), "STRAIGHT-UPPER-GUARD-v2")


static func _roof() -> Node3D:
	var root: Node3D = StadiumNpcMogulTwoStraightV1._root("ST-053")
	root.name = "ST053UpperCanopyV2Working"
	_variant(root, "STRAIGHT-UPPER-CANOPY-v2")
	root.set_meta("candidate_mount", "BASE-UPPER-ROOF-v1")
	root.set_meta("roof_state", "BASE-UPPER-ROOF-v1")
	for side: int in [-1, 1]:
		_box(root, "RoofPost%d" % side, Vector3(side * 2.6, 12.175, 7.7),
			Vector3(0.4, 2.15, 0.8), "64796e")
		_box(root, "RoofBeam%d" % side, Vector3(side * 2.6, 13.0, 5.05),
			Vector3(0.4, 0.5, 6.1), "64796e")
		_box(root, "FinishedRoofEnd%d" % side, Vector3(side * 2.875, 13.375, 5.05),
			Vector3(0.15, 0.55, 6.1), "c5b38d")
	_box(root, "RoofSlab", Vector3(0, 13.4, 5.05), Vector3(5.9, 0.3, 6.1), "507969")
	_box(root, "FrontRoofFascia", Vector3(0, 13.375, 2.075),
		Vector3(5.9, 0.55, 0.15), "c5b38d")
	_box(root, "RearRoofFascia", Vector3(0, 13.375, 8.025),
		Vector3(5.9, 0.55, 0.15), "c5b38d")
	return root


static func _box(root: Node3D, id: String, point: Vector3, size: Vector3,
	color: String) -> void:
	StadiumNpcMogulTwoStraightV1._box(root, id, point, size, color)


