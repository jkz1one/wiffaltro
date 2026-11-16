class_name StadiumHillsidePublicContacts
extends RefCounted
## Cold validation of actual Hillside member contacts and terrain-relative graph crossings.
## Capture remains the installed public property's responsibility; these checks issue no play.
# gdlint: disable=max-returns

const GRAPH: String = "PERIM-HILLSIDE-TIMBER-DEEPER-CENTER-v1"


static func matches(snapshot: Dictionary) -> bool:
	return StadiumNpcSnapshot.valid(snapshot) \
		and snapshot.version == StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION \
		and snapshot.manifest.id == "HILLSIDE" and snapshot.manifest.revision == 1


static func evidence(value: Variant, plays: Array, observed: Variant,
	snapshot: Dictionary) -> bool:
	if not matches(snapshot) or not StadiumNpcSnapshot._json_types(value) \
		or not StadiumNpcSnapshot._json_types(observed):
		return false
	var reference: Dictionary = _reference(snapshot)
	return not reference.is_empty() and _rows(value, plays, observed, reference)


static func _rows(value: Variant, plays: Array, observed: Variant, reference: Dictionary) -> bool:
	if not value is Array or value.size() != plays.size() or value.size() > 9999 \
		or not observed is Array or observed.size() > 4096:
		return false
	var receipts: Array = []
	for index in range(value.size()):
		var row: Variant = value[index]
		var play: Variant = plays[index]
		if not StadiumNpcSnapshot._keys(row, ["play", "reason", "events"]) \
			or not SeasonOwnership._whole(row.play, index, index) \
			or not row.reason is String or row.reason.length() > 80 \
			or row.reason.begins_with("owned_pool_") or row.reason.begins_with("private_pool_") \
			or row.reason.begins_with("pool_party_") \
			or not row.events is Array or row.events.size() > 128 \
			or not play is Dictionary or not play.get("result") is String:
			return false
		if not row.events.is_empty() and (not SeasonOwnership._whole(play.get("contact"), 1, 3)
			or not PhysicalMatchReport.number(play.get("exit_speed"), 0.0001, 1000)):
			return false
		var required: Array = _reason_roles(row.reason)
		if row.events.is_empty() and (not required.is_empty() or play.result in ["triple", "home_run"]):
			return false
		var last_time: float = -1
		for event_index in range(row.events.size()):
			var event: Variant = row.events[event_index]
			var proof: Dictionary = _event(event, reference)
			if proof.is_empty() or event.time < last_time:
				return false
			last_time = float(event.time)
			if not proof.instance.is_empty():
				receipts.append({"instance": proof.instance, "surface": proof.surface,
					"preterminal": true, "elapsed": event.time})
			if event.role not in StadiumNpcPublicContacts.LIVE:
				if event_index != row.events.size() - 1 or not required.has(event.role) \
					or not StadiumNpcPublicContacts._terminal(event.role, play, row.reason):
					return false
		if play.result in ["triple", "home_run"] \
			and row.events[-1].role in StadiumNpcPublicContacts.LIVE:
			return false
		if not required.is_empty() and not required.has(row.events[-1].role):
			return false
	# No arbitrary list of known copies qualifies a contact: the ordered actual asset
	# events must account for every issued preterminal receipt, with exact elapsed time.
	if observed.size() != receipts.size():
		return false
	for index in range(observed.size()):
		if not StadiumNpcSnapshot._keys(observed[index],
			["instance", "surface", "preterminal", "elapsed"]) \
			or not StadiumHillsideEnvironmentV1._same_profile(observed[index], receipts[index]):
			return false
	return true


static func _reason_roles(reason: String) -> Array:
	var roles: Array = PhysicalStadiumContacts._reason_roles(reason)
	match reason:
		"back_wall_on_fly", "bounce_to_back_wall":
			roles.append_array(["FOUL_POLE_LOWER", "FOUL_POLE_UPPER"])
		"foul_pole_upper": return ["FOUL_POLE_UPPER"]
		"stadium_receiver": return ["RECEIVER_CONTAINMENT_FOUL"]
		"dugout_opening_dead": return ["DUGOUT_OPENING_DEAD"]
		"dugout_exterior_dead": return ["DUGOUT_EXTERIOR_DEAD"]
		"dugout_terminal": return ["DUGOUT_EXTERIOR_DEAD", "DECORATIVE_AFTER_TERMINAL"]
	return roles


static func _event(value: Variant, reference: Dictionary) -> Dictionary:
	if not StadiumNpcSnapshot._keys(value,
		["source", "id", "surface", "role", "position", "time", "kind"]):
		return {}
	for key: String in ["source", "id", "surface", "role", "kind"]:
		if not value[key] is String:
			return {}
	if value.source != "boundary" or value.id != GRAPH \
		or value.kind not in ["contact", "crossing"] \
		or not PhysicalMatchReport.number(value.time, 0, 3600) \
		or not StadiumPoolOwnedReport._position_valid(value.position):
		return {}
	var point: Vector3 = Vector3(value.position[0], value.position[1], value.position[2])
	for body: Dictionary in reference.bodies:
		if body.segment != value.surface or not _contains(body, point):
			continue
		var role: String = body.role
		if body.kind == "pole":
			var local: Vector3 = body.model_inverse * point
			role = StadiumFoulPoleModels.role_at(clampf(
				local.y, 0, StadiumFoulPoleSites.HEIGHT), body.split)
		if value.role != role:
			continue
		if not body.instance.is_empty() and value.kind != "contact":
			continue
		return {"instance": body.instance, "surface": body.surface}
	# A graph-only crossing cannot acquire an asset/copy receipt or assert a timber face hit.
	if value.kind == "crossing" and _crossing(value, point, reference):
		return {"instance": "", "surface": ""}
	return {}


static func _crossing(value: Dictionary, point: Vector3, reference: Dictionary) -> bool:
	var segment: Dictionary = reference.segments.get(value.surface, {})
	if segment.is_empty():
		return false
	var planar: Vector2 = Vector2(point.x, point.z)
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(planar, segment.a, segment.b)
	var support: float = StadiumHillsideTerrain.support_height(planar, "hill")
	if not is_finite(support) or closest.distance_to(planar) > StadiumRecipeBoundary.EPS \
		or point.y < support - StadiumRecipeBoundary.EPS:
		return false
	var top: float = reference.boundary_graph.top_height(value.surface, planar)
	var role: String = segment.role
	if point.y > top + StadiumRecipeBoundary.EPS:
		match role:
			"SIDE_RETURN_LIVE", "DUGOUT_FACE_LIVE": role = "SIDE_EXIT_DEAD"
			"BACK_WALL_TERMINAL": role = "BACK_CLEAR"
			"DUGOUT_OPENING_DEAD": role = "DUGOUT_EXTERIOR_DEAD"
	elif role == "DUGOUT_FACE_LIVE":
		return false
	return value.role == role


static func _contains(body: Dictionary, point: Vector3) -> bool:
	for row: Dictionary in body.shapes:
		var local: Vector3 = row.inverse * point
		if row.shape is ConvexPolygonShape3D:
			if _closed_prism_contains(row.shape.points, local):
				return true
		elif row.shape is ConcavePolygonShape3D:
			var faces: PackedVector3Array = row.shape.get_faces()
			for index in range(0, faces.size(), 3):
				if StadiumNpcPublicContacts._cone_triangle_near(
					local, faces[index], faces[index + 1], faces[index + 2]):
					return true
		else:
			var single: Dictionary = body.duplicate()
			single.shapes = [row]
			if StadiumNpcPublicContacts._contains(single, point):
				return true
	return false


static func _closed_prism_contains(points: PackedVector3Array, point: Vector3) -> bool:
	# Hillside slices have two ordered terrain-following rings. Validate the actual closed
	# faces, retaining the shared contact-center tolerance, never a flat min/max-Y box.
	if points.size() < 6 or points.size() % 2 != 0:
		return false
	var count: int = int(points.size() / 2)
	var center: Vector3 = Vector3.ZERO
	for vertex: Vector3 in points:
		center += vertex / points.size()
	var triangles: Array[PackedVector3Array] = []
	for index in range(1, count - 1):
		triangles.append(PackedVector3Array([points[0], points[index], points[index + 1]]))
		triangles.append(PackedVector3Array([
			points[count], points[count + index], points[count + index + 1]]))
	for index in range(count):
		var next: int = (index + 1) % count
		triangles.append(PackedVector3Array([points[index], points[next], points[count + index]]))
		triangles.append(PackedVector3Array([
			points[next], points[count + next], points[count + index]]))
	var inside: bool = true
	var near: bool = false
	var plane_count: int = 0
	for triangle: PackedVector3Array in triangles:
		var normal: Vector3 = (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])
		if normal == Vector3.ZERO:
			continue
		plane_count += 1
		if normal.dot(center - triangle[0]) > 0:
			normal = -normal
		inside = inside and normal.dot(point - triangle[0]) <= 0
		near = near or StadiumNpcPublicContacts._cone_triangle_near(
			point, triangle[0], triangle[1], triangle[2])
	return plane_count >= 4 and (inside or near)


static func _reference(snapshot: Dictionary) -> Dictionary:
	if not matches(snapshot) or not StadiumNpcPublicRuntime.source_qualified():
		return {}
	var construction: StadiumHillsidePublicConstruction = StadiumHillsidePublicConstruction.build()
	if construction == null:
		return {}
	var boundary: StadiumHillsidePublicBoundarySource = construction.boundary
	if boundary == null or boundary.graph.identity() != GRAPH or boundary.bodies.size() != 10 \
		or construction.objects.size() != 8 or not construction.route_obstacles().is_empty():
		construction.free()
		return {}
	var reference: Dictionary = {"graph": GRAPH, "boundary_graph": boundary.graph,
		"segments": {}, "bodies": []}
	for segment: Dictionary in boundary.graph.segments():
		reference.segments[segment.id] = segment
	for body: StaticBody3D in boundary.member_bodies:
		var row: Dictionary = StadiumNpcPublicContacts._body(body, construction)
		if row.is_empty() or row.segment.is_empty() or row.role.is_empty():
			construction.free()
			return {}
		if not row.instance.is_empty():
			var model: Node3D = construction.objects.get(row.instance) as Node3D
			if model == null or not model.is_ancestor_of(body) or row.surface.is_empty():
				construction.free()
				return {}
			row["model_inverse"] = model.transform.affine_inverse()
		reference.bodies.append(row)
	construction.free()
	return reference
