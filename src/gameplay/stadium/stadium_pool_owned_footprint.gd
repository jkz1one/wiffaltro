class_name StadiumPoolOwnedFootprint
extends RefCounted
## Data-only generalization of BoundFootprint's conservative straight-boundary proof.
## Runtime must separately recheck actual actors, marker meshes and painted guides.
# gdlint: disable=max-returns

# Legacy persistence identity: this exact v1 signature remains in existing v16 saves/catalogs.
# Admission is separately versioned; no save schema, geometry or catalog hash migration.
const VERSION: int = 1
const ADMISSION_VERSION: int = 2
const PERSISTENCE_POLICY: String = "legacy-persistence-v1"
const ROUTE_RADIUS: float = StadiumPoolBoundFootprint.ROUTE_RADIUS
# Authored overhand/sidearm release maxima: .25m/.72m; fresh ball radius .0365m.
# Breaking reserve is a conservative placement policy, not an all-seed trajectory bound.
const DELIVERY_RELEASE_HALF_WIDTH: float = 0.72
const DELIVERY_BREAK_RESERVE: float = 2.0
const DELIVERY_BALL_RADIUS: float = 0.0365
const DELIVERY_SAFETY_MARGIN: float = 0.10


static func signature() -> String:
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	if field == null:
		return ""
	var anchors: Array = []
	for point: Vector3 in _anchors(field):
		anchors.append([point.x, point.y, point.z])
	return JSON.stringify({"version": VERSION, "boundary": StadiumBoundaryGraph.signature(),
		"anchors": anchors, "route_radius": ROUTE_RADIUS,
		"mound_charge": PitchBatLabDefenseSupport.CHARGE_RADIUS_M,
		"anchor_routes": "all-pairs-clear-v1", "reservation": "expanded-square-corners-v1",
		"painted_guides": "retain-noncolliding-ordinary-paint-v1"}, "", true, true).sha256_text()


static func reservation(pose: Transform3D) -> AABB:
	var radius: float = StadiumPoolContract.RESERVATION_RADIUS
	return AABB(pose.origin + Vector3(-radius, 0, -radius),
		Vector3(radius * 2, StadiumPoolContract.VISUAL_HEIGHT, radius * 2))


static func validate(pose: Transform3D, tier: String = "backyard",
	field: FieldDefinition = null) -> Dictionary:
	if tier != "backyard" or not canonical_pose(pose):
		return {}
	var source: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	if source == null:
		return {}
	if field == null:
		field = source
	if StadiumPoolPartyAssetIntegrity._value(field) != StadiumPoolPartyAssetIntegrity._value(source):
		return {}
	var center: Vector3 = pose.origin
	var reserved: AABB = reservation(pose)
	var expanded: AABB = reserved.grow(StadiumBoundaryGraph.DEFENDER_RADIUS)
	if not StadiumProperty.contains(tier, expanded):
		return {}
	for x: float in [expanded.position.x, expanded.end.x]:
		for z: float in [expanded.position.z, expanded.end.z]:
			if not StadiumBoundaryGraph.contains(Vector2(x, z)):
				return {}
	for row: Dictionary in StadiumBoundaryGraph.segments():
		if (Vector2(center.x, center.z) - row.a).dot(StadiumBoundaryGraph.inward(row)) < ROUTE_RADIUS:
			return {}
	var water: AABB = AABB(Vector3(-StadiumPoolContract.INNER_RADIUS, 0,
		-StadiumPoolContract.INNER_RADIUS), Vector3(StadiumPoolContract.INNER_RADIUS * 2,
		StadiumPoolContract.WATER_HEIGHT, StadiumPoolContract.INNER_RADIUS * 2))
	if not reserved.encloses(pose * StadiumPoolContract.LADDER) \
		or not reserved.encloses(pose * water):
		return {}
	var receiver: AABB = StadiumProperty.layout_bounds("ST-079", StadiumStarterLayout.RECEIVER)
	if reserved.intersects(receiver.grow(StadiumBoundaryGraph.DEFENDER_RADIUS)):
		return {}
	var anchors: Array[Vector3] = _anchors(field)
	var obstacles: Array[Dictionary] = [{"center": center, "radius": ROUTE_RADIUS}]
	var anchor_routes_clear: bool = true
	for point: Vector3 in anchors:
		if not StadiumPoolBoundFootprint._defender_inside(point) \
			or not StadiumDefenderRoutes.clear(point, point, obstacles):
			return {}
		for other: Vector3 in anchors:
			if not StadiumDefenderRoutes.clear(point, other, obstacles):
				anchor_routes_clear = false
	if DefenderSpacing.segment_distance_xz(center, PitchBatLab.MOUND_ORIGIN,
		PitchBatLab.MOUND_ORIGIN) <= ROUTE_RADIUS + PitchBatLabDefenseSupport.CHARGE_RADIUS_M:
		return {}
	# Preserve every v1-admitted pose. Newly admitted poses need an entire usable
	# circle, including the defender envelope, rather than all-pairs straight paths.
	var detour_ring_clear: bool = true
	var ring_radius: float = ROUTE_RADIUS + StadiumDefenderRoutes.POOL_RING_MARGIN
	for row: Dictionary in StadiumBoundaryGraph.segments():
		if (Vector2(center.x, center.z) - row.a).dot(StadiumBoundaryGraph.inward(row)) \
			< ring_radius + StadiumBoundaryGraph.DEFENDER_RADIUS:
			detour_ring_clear = false
	var receiver_radius: float = Vector2(0.30, 0.43).length() + StadiumDefenderRoutes.BODY_RADIUS
	if center.distance_to(StadiumStarterLayout.RECEIVER) < ring_radius + receiver_radius:
		detour_ring_clear = false
	# PitchFlightActor integrates directly through the scene; defender detours cannot
	# protect mound-to-plate delivery. Newly admitted sites must keep this capsule
	# free of the entire Pool visual/ladder envelope, regardless of pitch height.
	var delivery_radius: float = delivery_corridor_radius()
	var delivery_clear: bool = DefenderSpacing.segment_distance_xz(center,
		PitchBatLab.MOUND_ORIGIN, Vector3.ZERO) > delivery_radius
	if not anchor_routes_clear and (not detour_ring_clear or not delivery_clear):
		return {}
	return {"admission_version": ADMISSION_VERSION, "persistence_policy": PERSISTENCE_POLICY,
		"detour_ring_clear": detour_ring_clear, "reservation": reserved,
		"delivery_corridor_clear": delivery_clear, "delivery_corridor_radius": delivery_radius,
		"delivery_corridor_policy": "conservative-authored-pitch-reserve-v1",
		"defender_envelope": expanded, "route_radius": ROUTE_RADIUS,
		"anchor_count": anchors.size(), "anchor_routes_clear": anchor_routes_clear,
		"receiver_clear": true,
		"mound_charge_clear": true, "water_contained": true, "ladder_contained": true,
		"painted_guide_policy": "RETAIN_NONCOLLIDING_ORDINARY_PAINT_BELOW_PROP"}


static func canonical_pose(pose: Transform3D) -> bool:
	if not pose.is_finite() or pose.origin.y != 0 \
		or not StadiumPoolOwnedLayout._coordinate(pose.origin.x) \
		or not StadiumPoolOwnedLayout._coordinate(pose.origin.z):
		return false
	for yaw: int in [0, 90, 180, 270]:
		if pose == StadiumPoolOwnedLayout.transform(Vector2(pose.origin.x, pose.origin.z), yaw):
			return true
	return false


static func _anchors(field: FieldDefinition) -> Array[Vector3]:
	var result: Array[Vector3] = [PitchBatLab.MOUND_ORIGIN, Vector3.ZERO,
		Vector3(-0.82, 0, 0.34), Vector3(0.82, 0, 0.34)]
	for index in range(9):
		result.append(field.fielder_anchor(index))
	for point: Vector2 in StadiumInfieldAnchors.bases():
		result.append(Vector3(point.x, 0, point.y))
	return result


static func delivery_corridor_radius() -> float:
	# Full authored aim/release span + capped release shift + full-distance yaw fan.
	# The additional 2m reserve covers breaking movement conservatively as policy;
	# it does not claim to solve or certify every stochastic trajectory.
	var release_error: float = PitchExecutionModel.MAX_RELEASE_ERROR_M
	var lateral: float = maxf(DELIVERY_RELEASE_HALF_WIDTH,
		maxf(absf(PitchBatLab.PITCH_AIM_MIN_X), absf(PitchBatLab.PITCH_AIM_MAX_X)))
	lateral += release_error + (PitchBatLab.MOUND_ORIGIN.z + release_error) \
		* tan(PitchExecutionModel.MAX_DIRECTION_ERROR_RADIANS) + DELIVERY_BREAK_RESERVE
	return StadiumPoolContract.VISUAL_RADIUS + lateral + DELIVERY_BALL_RADIUS \
		+ DELIVERY_SAFETY_MARGIN
