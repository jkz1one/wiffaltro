class_name StadiumGrandThreeStackModels
extends RefCounted
## Isolated additive compatibility variants; no new catalog identities or venue grant.

const S = preload("res://src/gameplay/stadium/stadium_grand_three_stack_sites.gd")
const VERSION: int = 2
const ROOF_HEIGHT: float = 13.65


static func create_concourse(lower: Node3D, site: String) -> Node3D:
	if not S.valid_lower(lower, site) or not S.vacant(lower, site, [lower]):
		return null
	var root: Node3D = _concourse()
	_bind(root, lower, site, S.INTERFACE)
	return root


static func create_upper(lower: Node3D, concourse: Node3D, site: String,
	occupied: bool = true) -> Node3D:
	if not S.valid_concourse(lower, concourse, site) \
		or not S.vacant(lower, site, [lower, concourse]):
		return null
	var root: Node3D = _upper(occupied)
	_bind(root, lower, site, S.UPPER_INTERFACE)
	root.set_meta("concourse_instance", concourse.get_instance_id())
	return root


static func create_roof(lower: Node3D, concourse: Node3D, upper: Node3D,
	site: String) -> Node3D:
	if not S.valid_upper(lower, concourse, upper, site) \
		or not S.vacant(lower, site, [lower, concourse, upper]):
		return null
	var root: Node3D = _roof()
	_bind(root, lower, site, S.ROOF_INTERFACE)
	root.set_meta("concourse_instance", concourse.get_instance_id())
	root.set_meta("upper_instance", upper.get_instance_id())
	return root


static func create_transition(site: String, join: Node3D, bowl: Node3D,
	curved: Node3D, base: Node3D, straight: Node3D) -> Node3D:
	if not S.valid_transition_hosts(site, join, bowl, curved, base, straight):
		return null
	var root: Node3D = _transition(site)
	root.set_meta("lower_instance", join.get_instance_id())
	root.set_meta("bowl_instance", bowl.get_instance_id())
	root.set_meta("curved_concourse_instance", curved.get_instance_id())
	root.set_meta("baseline_instance", base.get_instance_id())
	root.set_meta("straight_concourse_instance", straight.get_instance_id())
	return root


static func _bind(root: Node3D, lower: Node3D, site: String, interface: String) -> void:
	root.transform = StadiumBaselineSites.pose(site)
	root.set_meta("lower_instance", lower.get_instance_id())
	root.set_meta("site", site)
	root.set_meta("interface", interface)


static func _variant(root: Node3D, variant: String) -> Node3D:
	root.set_meta("model_version", VERSION)
	root.set_meta("model_variant", variant)
	root.set_meta("authoring_status", "Working")
	return root


static func _concourse() -> Node3D:
	return _variant(StadiumStraightStackModels._concourse(), "STRAIGHT-CONCOURSE-GUARD-v2")


static func _upper(occupied: bool = true) -> Node3D:
	return _variant(StadiumStraightStackModels._upper(occupied), "STRAIGHT-UPPER-GUARD-v2")


static func _transition(site: String) -> Node3D:
	var root: Node3D = StadiumTransitionConcourseModels._model(site)
	if root == null:
		return null
	_variant(root, "TRANSITION-ROOF-NEIGHBOR-v2")
	root.set_meta("interface", S.TRANSITION_INTERFACE)
	return root


static func _roof() -> Node3D:
	var root: Node3D = StadiumStraightStackModels._root("ST-053")
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
	StadiumStraightStackModels._box(root, id, point, size, color)


static func _curved_roof_reference() -> Node3D:
	# Explicit frozen ST084 art correspondence, tested against its original real factory.
	# No live host is altered or substituted to satisfy the old admission validator.
	var root: Node3D = StadiumCurvedStackModels._root("ST-084")
	root.set_meta("roof_state", "BOWL-UPPER-ROOF-v1")
	for side: int in [-1, 1]:
		var angle: float = side * 12.7 - 0.55
		StadiumCurvedStackModels._band(root, "RoofPost%d" % side,
			25.20, 26.00, angle, angle + 1.1, 8.15, 10.25, "64796e")
		StadiumCurvedStackModels._band(root, "RoofBeam%d" % side,
			19.90, 26.30, angle, angle + 1.1, 9.80, 10.25, "64796e")
		var end: float = -14.7 if side == -1 else 14.05
		StadiumCurvedStackModels._band(root, "FinishedRoofEnd%d" % side,
			19.90, 26.30, end, end + 0.65, 10.10, 10.65, "c5b38d")
	StadiumCurvedStackModels._band(root, "RoofSlab", 19.90, 26.30,
		-14.7, 14.7, 10.25, 10.55, "507969")
	StadiumCurvedStackModels._band(root, "FrontRoofFascia", 19.90, 20.10,
		-14.7, 14.7, 10.10, 10.65, "c5b38d")
	StadiumCurvedStackModels._band(root, "RearRoofFascia", 26.10, 26.30,
		-14.7, 14.7, 10.10, 10.65, "c5b38d")
	return root
