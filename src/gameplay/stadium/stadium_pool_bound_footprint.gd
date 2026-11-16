class_name StadiumPoolBoundFootprint
extends RefCounted
## Conservative fixed-site proof using the ordinary boundary and route predicates.
## Painted field guides may continue below a prop; that overlap is reported, never erased.
# gdlint: disable=max-returns

const ROUTE_RADIUS: float = (
	StadiumPoolContract.RESERVATION_RADIUS + StadiumBoundaryGraph.DEFENDER_RADIUS
)


static func reservation() -> AABB:
	var radius: float = StadiumPoolContract.RESERVATION_RADIUS
	return AABB(
		StadiumPoolContract.placement().origin + Vector3(-radius, 0, -radius),
		Vector3(radius * 2, StadiumPoolContract.VISUAL_HEIGHT, radius * 2)
	)


static func validate(property: StadiumPropertyGeometry, lab: PitchBatLab) -> Dictionary:
	if (
		property == null
		or lab == null
		or property.is_inside_tree()
		or property.transform != Transform3D.IDENTITY
		or property.field == null
		or property.tier != "backyard"
		or lab._field_definition == null
	):
		return {}
	if (
		StadiumPoolPartyAssetIntegrity._value(property.field)
		!= StadiumPoolPartyAssetIntegrity._value(lab._field_definition)
	):
		return {}
	var center: Vector3 = StadiumPoolContract.placement().origin
	var reserved: AABB = reservation()
	var expanded: AABB = reserved.grow(StadiumBoundaryGraph.DEFENDER_RADIUS)
	if not StadiumProperty.contains("backyard", expanded):
		return {}
	# Convex straight polygon: all four expanded corners prove the full reservation
	# and the largest ordinary defender envelope, not merely its center.
	for x: float in [expanded.position.x, expanded.end.x]:
		for z: float in [expanded.position.z, expanded.end.z]:
			if not StadiumBoundaryGraph.contains(Vector2(x, z)):
				return {}
	for row: Dictionary in StadiumBoundaryGraph.segments():
		if (
			(Vector2(center.x, center.z) - row.a).dot(StadiumBoundaryGraph.inward(row))
			< ROUTE_RADIUS
		):
			return {}
	var envelope: AABB = StadiumPoolContract.placement() * StadiumPoolContract.LADDER
	if not reserved.encloses(envelope):
		return {}
	var receiver: AABB = StadiumProperty.layout_bounds("ST-079", StadiumStarterLayout.RECEIVER)
	if reserved.intersects(receiver.grow(StadiumBoundaryGraph.DEFENDER_RADIUS)):
		return {}
	var anchors: Array[Vector3] = [
		PitchBatLab.MOUND_ORIGIN, Vector3.ZERO, Vector3(-0.82, 0, 0.34), Vector3(0.82, 0, 0.34)
	]
	for index in range(9):
		anchors.append(property.field.fielder_anchor(index))
	for point: Vector2 in StadiumInfieldAnchors.bases():
		anchors.append(Vector3(point.x, 0, point.y))
	var obstacle: Array[Dictionary] = [{"center": center, "radius": ROUTE_RADIUS}]
	for point: Vector3 in anchors:
		if (
			not point.is_finite()
			or not _defender_inside(point)
			or not StadiumDefenderRoutes.clear(point, point, obstacle)
		):
			return {}
		for other: Vector3 in anchors:
			if not StadiumDefenderRoutes.clear(point, other, obstacle):
				return {}
	# Full ordinary pitcher charge area, including avatar spacing, must remain usable.
	if (
		DefenderSpacing.segment_distance_xz(
			center, PitchBatLab.MOUND_ORIGIN, PitchBatLab.MOUND_ORIGIN
		)
		<= ROUTE_RADIUS + PitchBatLabDefenseSupport.CHARGE_RADIUS_M
	):
		return {}
	if not is_instance_valid(lab._primary_fielder) or not is_instance_valid(lab._pitcher_marker):
		return {}
	for spawn: Vector3 in [
		lab._primary_fielder.global_position,
		lab._primary_fielder.anchor_position,
		lab._pitcher_marker.global_position
	]:
		if not _defender_inside(spawn) or not StadiumDefenderRoutes.clear(spawn, spawn, obstacle):
			return {}
	for id: String in ["Plate", "Mound"]:
		var marker: Node3D = property.get_node_or_null(NodePath(id))
		if (
			marker == null
			or marker is CollisionObject3D
			or marker.get_child_count() != 1
			or not marker.get_child(0) is MeshInstance3D
		):
			return {}
		var mesh: MeshInstance3D = marker.get_child(0)
		if (
			not mesh.mesh is BoxMesh
			or reserved.intersects(marker.transform * AABB(-mesh.mesh.size / 2, mesh.mesh.size))
		):
			return {}
	var painted_overlaps: Array[String] = []
	for id: String in ["Safe", "Deep", "FoulLine-1", "FoulLine1"]:
		var guide: Node3D = property.get_node_or_null(NodePath(id))
		if (
			guide == null
			or guide is CollisionObject3D
			or guide.get_child_count() != 1
			or not guide.get_child(0) is MeshInstance3D
		):
			return {}
		var mesh: MeshInstance3D = guide.get_child(0)
		if (
			not mesh.mesh is BoxMesh
			or guide.position.y > 0.025
			or mesh.mesh.size.y != Vector3(0, 0.025, 0).y
		):
			return {}
		var half: Vector3 = Vector3(mesh.mesh.size.x / 2, 0, 0)
		var width: float = mesh.mesh.size.z / 2
		if id.begins_with("FoulLine"):
			half = Vector3(0, 0, mesh.mesh.size.z / 2)
			width = mesh.mesh.size.x / 2
		if (
			DefenderSpacing.segment_distance_xz(
				center, guide.transform * -half, guide.transform * half
			)
			<= StadiumPoolContract.RESERVATION_RADIUS + width
		):
			painted_overlaps.append(id)
	return {
		"reservation": reserved,
		"defender_envelope": expanded,
		"route_radius": ROUTE_RADIUS,
		"anchor_count": anchors.size(),
		"anchor_routes_clear": true,
		"receiver_clear": true,
		"mound_charge_clear": true,
		"painted_guide_overlaps": painted_overlaps,
		"painted_guide_policy": "RETAIN_NONCOLLIDING_ORDINARY_PAINT_BELOW_PROP"
	}


static func _defender_inside(point: Vector3) -> bool:
	if not point.is_finite() or not StadiumBoundaryGraph.contains(Vector2(point.x, point.z)):
		return false
	for row: Dictionary in StadiumBoundaryGraph.segments():
		if (
			(Vector2(point.x, point.z) - row.a).dot(StadiumBoundaryGraph.inward(row))
			< StadiumBoundaryGraph.DEFENDER_RADIUS
		):
			return false
	return true
