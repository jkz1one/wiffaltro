class_name StadiumRoofOwnedModels
extends RefCounted
## Additive owned assembly art. Shared runtime owns admission, copies and site poses.
## Frozen factories retain their old geometry and their old compatibility contracts.

const VERSION: int = 1
const ITEMS: Array[String] = [
	"ST-081", "ST-083", "ST-082", "ST-084", "ST-085", "ST-086", "ST-088", "ST-089", "ST-053"
]
const CURVED_HALF: float = 14.3
const CURVED_LOWER_OFFSET: Vector3 = Vector3(0, -3.75, -0.845)
const CURVED_PAD_BOTTOM: float = 4.39
const CURVED_PAD_TOP: float = 4.40
const STRAIGHT_WIDTH: float = 5.90


static func create(item: String, state: String = "lower") -> Node3D:
	# A typo must never silently produce a lower roof for an upper owned placement.
	if item in ["ST-053", "ST-084"] and state not in ["lower", "upper"]:
		return null
	match item:
		"ST-081": return StadiumCurvedLowerModels.create(true)
		"ST-083": return StadiumCurvedStackModels._concourse()
		"ST-082": return StadiumCurvedStackModels._upper(true)
		"ST-085": return StadiumLowerTransitionModels.create_right(true)
		"ST-088": return StadiumLowerTransitionModels.create_left(true)
		"ST-086": return StadiumTransitionConcourseModels._model("JOIN-R")
		"ST-089": return StadiumTransitionConcourseModels._model("JOIN-L")
		"ST-084": return _curved_roof(state)
		"ST-053": return _straight_roof(state)
	return null


static func envelope(item: String, state: String = "lower") -> AABB:
	# Canonical host-local envelopes; handed JOIN art is already world-authored.
	if item in ["ST-053", "ST-084"] and state not in ["lower", "upper"]:
		return AABB()
	match item:
		"ST-081": return StadiumCurvedLowerSites.LOWER_BOUNDS
		"ST-083": return AABB(Vector3(-7.10, 0, 24.20), Vector3(14.20, 5.35, 3.66))
		"ST-082": return AABB(Vector3(-6.40, 4.55, 19.55), Vector3(12.80, 4.75, 7.90))
		"ST-085", "ST-088": return _join_bounds(item == "ST-088", false)
		"ST-086", "ST-089": return _join_bounds(item == "ST-089", true)
		"ST-053":
			if state == "upper":
				return AABB(Vector3(-2.95, 11.10, 2), Vector3(5.90, 2.55, 6.10))
			return AABB(Vector3(-2.95, 5.70, 0), Vector3(5.90, 2.94, 7))
		"ST-084":
			if state == "upper":
				return AABB(Vector3(-6.50, 8.15, 19.28), Vector3(13, 2.50, 7.02))
			return AABB(Vector3(-6.50, 4.39, 18.435), Vector3(13, 2.51, 7.02))
	return AABB()


static func _curved_roof(state: String) -> Node3D:
	# This surviving canonical art reference corresponds to the real upper factory.
	# Reuse its exact post/beam chain; replace only the five owned edge members.
	var root: Node3D = StadiumGrandThreeStackModels._curved_roof_reference()
	for member: String in ["FinishedRoofEnd-1", "FinishedRoofEnd1", "RoofSlab",
		"FrontRoofFascia", "RearRoofFascia"]:
		if not _remove_member(root, member):
			root.free()
			return null
	for side: int in [-1, 1]:
		var start: float = -CURVED_HALF if side == -1 else CURVED_HALF - 0.65
		StadiumCurvedStackModels._band(root, "FinishedRoofEnd%d" % side,
			19.90, 26.30, start, start + 0.65, 10.10, 10.65, "c5b38d")
	StadiumCurvedStackModels._band(root, "RoofSlab", 19.90, 26.30,
		-CURVED_HALF, CURVED_HALF, 10.25, 10.55, "507969")
	StadiumCurvedStackModels._band(root, "FrontRoofFascia", 19.90, 20.10,
		-CURVED_HALF, CURVED_HALF, 10.10, 10.65, "c5b38d")
	StadiumCurvedStackModels._band(root, "RearRoofFascia", 26.10, 26.30,
		-CURVED_HALF, CURVED_HALF, 10.10, 10.65, "c5b38d")
	if state == "lower":
		for side: int in [-1, 1]:
			var start: float = side * 12.7 - 0.55
			# Full .8m radial post footprint, shallow-seated 0.01m into the rear rim.
			# Clears the last seatback top4.38 by0.01m. The rim embed is intentional.
			StadiumCurvedStackModels._band(root, "LowerRoofBearing%d" % side,
				25.20, 26.00, start, start + 1.1,
				CURVED_PAD_BOTTOM - CURVED_LOWER_OFFSET.y,
				CURVED_PAD_TOP - CURVED_LOWER_OFFSET.y, "64796e")
		# Runtime owns the root site pose and requires identity container branches.
		# Move each matching visual/physical member by the same authored offset.
		for branch: String in ["Visual", "Collision"]:
			for member: Node3D in root.get_node(branch).get_children():
				member.position += CURVED_LOWER_OFFSET
	return _owned_roof(root, "BOWL", state, "OWNED-CURVED-CANOPY-TRIM-v1")


static func _straight_roof(state: String) -> Node3D:
	if state == "upper":
		# Preserve the independently authored upper canopy and its complete pylon caps.
		return _owned_roof(StadiumGrandThreeStackModels._roof(), "BASE", state,
			"OWNED-STRAIGHT-UPPER-CANOPY-v1")
	var root: Node3D = StadiumBaselineStandModels.lower_canopy()
	if not _resize_box(root, "Canopy", Vector3(6.5, 0.06, 7),
		Vector3(STRAIGHT_WIDTH, 0.06, 7)) \
		or not _resize_box(root, "FrontFascia", Vector3(6.5, 0.24, 0.12),
			Vector3(STRAIGHT_WIDTH, 0.24, 0.12)):
		root.free()
		return null
	# Exact right-column footprint over the real stair37/38 split. A separate
	# purchased bearing fills y5.7..6; the original post and stair lane stay intact.
	StadiumStraightStackModels._box(root, "LowerRoofBearing1",
		Vector3(2.7, 5.85, 6.6), Vector3(0.18, 0.30, 0.18), "6c7e80")
	return _owned_roof(root, "BASE", state, "OWNED-STRAIGHT-LOWER-CANOPY-v1")


static func _owned_roof(root: Node3D, family: String, state: String,
	variant: String) -> Node3D:
	if root == null:
		return null
	root.name = str(root.get_meta("stadium_item")).replace("-", "") + "OwnedCanopy"
	root.set_meta("owned_geometry_version", VERSION)
	root.set_meta("model_variant", variant)
	root.set_meta("authoring_status", "Working")
	root.set_meta("roof_state", family + "-" + state.to_upper() + "-ROOF-v1")
	root.set_meta("candidate_mount", root.get_meta("roof_state"))
	return root


static func _remove_member(root: Node3D, member: String) -> bool:
	var visual: MeshInstance3D = root.get_node_or_null("Visual/" + member) as MeshInstance3D
	var collision: StaticBody3D = root.get_node_or_null("Collision/" + member) as StaticBody3D
	if visual == null or collision == null:
		return false
	visual.free()
	collision.free()
	return true


static func _resize_box(root: Node3D, member: String, expected: Vector3,
	size: Vector3) -> bool:
	var visual: MeshInstance3D = root.get_node_or_null("Visual/" + member) as MeshInstance3D
	var body: StaticBody3D = root.get_node_or_null("Collision/" + member) as StaticBody3D
	if visual == null or body == null or body.get_child_count() != 1:
		return false
	var collider: CollisionShape3D = body.get_child(0) as CollisionShape3D
	if not visual.mesh is BoxMesh or collider == null or not collider.shape is BoxShape3D:
		return false
	if visual.mesh.size != expected or collider.shape.size != expected \
		or visual.transform != body.transform:
		return false
	# Resources are freshly created by the surviving factory, never shared definitions.
	(visual.mesh as BoxMesh).size = size
	(collider.shape as BoxShape3D).size = size
	return true


static func _join_bounds(left: bool, concourse: bool) -> AABB:
	var site: String = "JOIN-L" if left else "JOIN-R"
	var height: float = 7.85 if concourse else 7.30
	var low_u: float = 6.75 if concourse else 0.0
	var high_u: float = 10.0 if concourse else 7.0
	var points: PackedVector3Array = []
	for t: float in [0.0, 1.0]:
		for u: float in [low_u, high_u]:
			points.append(StadiumLowerTransitionSites.point(site, t, u))
	if concourse:
		# Include the actual separate cap-crossing reservations, not just the patch.
		for radius: float in [26.20, 27.40]:
			for angle: float in [105.0, 108.3]:
				var point: Vector3 = StadiumCurvedLowerModels.polar(radius, angle, 0)
				point.x *= -1.0 if left else 1.0
				points.append(point)
		var pose: Transform3D = StadiumBaselineSites.pose("BASE-L1" if left else "BASE-R1")
		for x: float in ([-3.05, -1.45] if left else [2.40, 3.05]):
			for z: float in ([8.30, 9.50] if left else [8.20, 9.65]):
				points.append(pose * Vector3(x, 0, z))
	var bounds: AABB = AABB(points[0], Vector3(0, height, 0))
	for point: Vector3 in points:
		bounds = bounds.expand(point)
		bounds = bounds.expand(point + Vector3.UP * height)
	return bounds.grow(0.001)
