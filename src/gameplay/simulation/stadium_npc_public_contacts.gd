class_name StadiumNpcPublicContacts
extends RefCounted

const AC02_PASSIVE_9 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Public contacts use each frozen family's graph and actual collision-body identities.
## AM01 keeps its deeper-center graph; AM02 keeps all 91 r1 LeftLoft identities and heights.
## AE02 admits only its authored cone and paired-receiver item contacts.
## AC02 keeps its exact RightShelf graph and Club boundary-only contact provenance.
## LONG-YARD uses its exact original Deeper Center graph and public67-copy body identities.
## No Yard adapter substitution, current catalog, historical certificate extension or live cache.
# gdlint: disable=max-returns

const LIVE: Array[String] = ["SIDE_RETURN_LIVE", "LIVE_RICOCHET", "DUGOUT_FACE_LIVE"]
const TOLERANCE: float = 0.1


static func matches(snapshot: Dictionary) -> bool:
	if not StadiumNpcSnapshot.valid(snapshot):
		return false
	if snapshot.get("version") == StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION:
		return StadiumHillsidePublicReport.supports_definition(
			snapshot.manifest.id, snapshot.manifest.revision)
	if snapshot.get("version") == StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION:
		return StadiumPoolPartyPublicReport.supports_definition(
			snapshot.manifest.id, snapshot.manifest.revision)
	if snapshot.get("version") == StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION:
		return StadiumGrandIIIPublicReport.supports_definition(
			snapshot.manifest.id, snapshot.manifest.revision)
	if snapshot.get("version") == StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION:
		return StadiumGrandIIPublicReport.supports_definition(
			snapshot.manifest.id, snapshot.manifest.revision)
	if snapshot.get("version") == StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION:
		return StadiumGrandIPublicReport.supports_definition(
			snapshot.manifest.id, snapshot.manifest.revision)
	return StadiumLongYardPublicReport.supports_definition(
		snapshot.manifest.id, snapshot.manifest.revision) \
		if snapshot.get("version") == StadiumNpcSnapshot.FINAL_FIXTURE_VERSION else (
		StadiumNpcPublicReport.supports_definition(snapshot.manifest.id, snapshot.manifest.revision))


static func valid(value: Variant, plays: Array, snapshot: Dictionary) -> bool:
	var reference: Dictionary = _reference(snapshot)
	return not reference.is_empty() and _rows(value, plays, reference)


static func provenance(value: Variant, snapshot: Dictionary) -> bool:
	var reference: Dictionary = _reference(snapshot)
	return not reference.is_empty() and _provenance(value, reference)


static func evidence(value: Variant, plays: Array, observed: Variant,
	snapshot: Dictionary) -> bool:
	var reference: Dictionary = _reference(snapshot)
	return not reference.is_empty() and _rows(value, plays, reference) \
		and _provenance(observed, reference)


static func _rows(value: Variant, plays: Array, reference: Dictionary) -> bool:
	if not value is Array or value.size() != plays.size() or value.size() > 9999:
		return false
	for index in range(value.size()):
		var row: Variant = value[index]
		var play: Variant = plays[index]
		if not row is Dictionary or not SeasonOwnership._keys(row, ["play", "reason", "events"]) \
			or not SeasonOwnership._whole(row.play, index, index) \
			or not row.reason is String or row.reason.length() > 80 \
			or row.reason.begins_with("owned_pool_") or row.reason.begins_with("private_pool_") \
			or not row.events is Array or row.events.size() > 128 \
			or not play is Dictionary or not play.get("result") is String:
			return false
		if not row.events.is_empty() and (not SeasonOwnership._whole(play.get("contact"), 1, 3)
			or not PhysicalMatchReport.number(play.get("exit_speed"), 0.0001, 1000)):
			return false
		var required: Array = _reason_roles(row.reason, reference.id)
		if row.events.is_empty() and (not required.is_empty() or play.result in ["triple", "home_run"]):
			return false
		var last_time: float = -1.0
		for event_index in range(row.events.size()):
			var event: Variant = row.events[event_index]
			if not _event(event, reference) or event.time < last_time:
				return false
			last_time = float(event.time)
			if event.role not in LIVE:
				if event_index != row.events.size() - 1 or not required.has(event.role) \
					or not _terminal(event.role, play, row.reason):
					return false
		if play.result in ["triple", "home_run"] and row.events[-1].role in LIVE:
			return false
		if not required.is_empty() and not required.has(row.events[-1].role):
			return false
	return true


static func _event(value: Variant, reference: Dictionary) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["source", "id", "surface", "role", "position", "time", "kind"]):
		return false
	for key: String in ["source", "id", "surface", "role", "kind"]:
		if not value[key] is String:
			return false
	if not PhysicalMatchReport.number(value.time, 0, 3600) \
		or not value.position is Array or value.position.size() != 3:
		return false
	for coordinate: Variant in value.position:
		if not PhysicalMatchReport.number(coordinate, -1000, 1000):
			return false
	var point: Vector3 = Vector3(value.position[0], value.position[1], value.position[2])
	if value.source == "item":
		# Club uses its boundary adapter. Expanded uses unchanged SurfaceRules callbacks.
		if reference.id not in ["AE-01", "AE-02"] or value.kind != "contact":
			return false
		if value.role != "RECEIVER_CONTAINMENT_FOUL" and (reference.id != "AE-02" \
			or value.role != "LIVE_RICOCHET" or value.surface not in ["CONE_BASE", "CONE_BODY"]):
			return false
		for body: Dictionary in reference.items:
			if body.instance == value.id and body.surface == value.surface \
				and body.role == value.role and _contains(body, point):
				return true
		return false
	if value.source != "boundary" or value.id != reference.graph \
		or value.kind not in ["contact", "crossing"]:
		return false
	if value.kind == "contact":
		for body: Dictionary in reference.bodies:
			if body.segment != value.surface or not _contains(body, point):
				continue
			var role: String = body.role
			if body.kind == "pole":
				role = StadiumNpcClubPoleV1.role_at(
					clampf(point.y, 0, StadiumNpcClubFoulSitesV1.HEIGHT), body.split)
			if value.role == role:
				return true
		return false
	# The retained Club base graph labels swept slab hits as crossings because they
	# contain a fraction. Accept only the actual slab volume and its unchanged role.
	if reference.id in ["AC-01", "AC-02", "AM-01", "AM-02", "LONG-YARD",
		"GRAND-I", "GRAND-II", "GRAND-III"]:
		for body: Dictionary in reference.bodies:
			if body.kind == "boundary" and body.segment == value.surface \
				and body.role == value.role and _contains(body, point):
				return true
	return _crossing(value, point, reference)


static func _crossing(value: Dictionary, point: Vector3, reference: Dictionary) -> bool:
	var segment: Dictionary = reference.segments.get(value.surface, {})
	if segment.is_empty():
		return false
	var planar: Vector2 = Vector2(point.x, point.z)
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(planar, segment.a, segment.b)
	if closest.distance_to(planar) > 0.05 or point.y < -0.05:
		return false
	var role: String = segment.role
	if point.y > segment.height + 0.00001:
		if role in ["SIDE_RETURN_LIVE", "DUGOUT_FACE_LIVE"]:
			role = "SIDE_EXIT_DEAD"
		elif role == "BACK_WALL_TERMINAL":
			role = "BACK_CLEAR"
		elif role == "DUGOUT_OPENING_DEAD":
			role = "DUGOUT_EXTERIOR_DEAD"
	return value.role == role


static func _reason_roles(reason: String, id: String) -> Array:
	var roles: Array = PhysicalStadiumContacts._reason_roles(reason)
	if id not in ["AC-01", "AC-02", "AM-01", "AM-02", "LONG-YARD",
		"GRAND-I", "GRAND-II", "GRAND-III"]:
		return roles
	match reason:
		"back_wall_on_fly", "bounce_to_back_wall":
			roles.append_array(["FOUL_POLE_LOWER", "FOUL_POLE_UPPER"])
		"foul_pole_upper": return ["FOUL_POLE_UPPER"]
		"stadium_receiver": return ["RECEIVER_CONTAINMENT_FOUL"]
		"dugout_opening_dead": return ["DUGOUT_OPENING_DEAD"]
		"dugout_exterior_dead": return ["DUGOUT_EXTERIOR_DEAD"]
		"dugout_terminal":
			return ["DUGOUT_ROOF_TERMINAL", "DUGOUT_EXTERIOR_DEAD", "DECORATIVE_AFTER_TERMINAL"]
	return roles


static func _terminal(role: String, play: Dictionary, reason: String) -> bool:
	if role in ["FOUL_POLE_UPPER", "FOUL_POLE_LOWER"]:
		# A pole contact sets the play fair even when the original launch was foul.
		return play.result == "home_run" if reason == "foul_pole_upper" else (
			play.result in ["double", "triple"])
	if role in ["DUGOUT_OPENING_DEAD", "DUGOUT_EXTERIOR_DEAD", "DUGOUT_ROOF_TERMINAL",
		"DECORATIVE_AFTER_TERMINAL"]:
		return play.result == "foul" if play.contact == ContactResult.Outcome.FOUL else (
			play.result in ["single", "double"])
	return PhysicalStadiumContacts._terminal(role, play)


static func _provenance(value: Variant, reference: Dictionary) -> bool:
	if not value is Array or value.size() > 4096:
		return false
	for row: Variant in value:
		if not row is Dictionary or not SeasonOwnership._keys(row,
			["instance", "surface", "preterminal", "elapsed"]) \
			or not row.instance is String or not reference.provenance.has(row.instance) \
			or not row.surface is String or not reference.provenance[row.instance].has(row.surface) \
			or not row.preterminal is bool or not row.preterminal \
			or not PhysicalMatchReport.number(row.elapsed, 0, 3600):
			return false
	return true


static func _reference(snapshot: Dictionary) -> Dictionary:
	var ac02_token: int = AC02_PASSIVE_9.enter("stadium_npc_public_contacts._reference")
	var ac02_result: Dictionary = _ac02_passive_09_private_reference(snapshot)
	AC02_PASSIVE_9.leave(ac02_token)
	return ac02_result


static func _ac02_passive_09_private_reference(snapshot: Dictionary) -> Dictionary:
	if snapshot.get("version") == StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION:
		return {}
	# Pool evidence requires its distinct commits/outcomes and immutable factory mapping.
	if snapshot.get("version") == StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION:
		return {}
	if not matches(snapshot) or not StadiumNpcPublicRuntime.source_qualified():
		return {}
	var property: StadiumNpcRetainedProperty = StadiumNpcRetainedProperty.new()
	property.venue_id = snapshot.manifest.id
	property.construction = StadiumLongYardPublicConstruction.build() \
		if property.venue_id == "LONG-YARD" else (
		StadiumNpcYardV1.build() if property.venue_id == "AY-01" else (
		StadiumNpcExpandedV1.build() if property.venue_id == "AE-01" else (
		StadiumNpcAe02PublicConstruction.build() if property.venue_id == "AE-02" else (
		StadiumNpcAc02PublicConstruction.build() if property.venue_id == "AC-02" else (
		StadiumNpcMogulOneV1.build() if property.venue_id == "AM-01" else (
		StadiumNpcMogulTwoV1.build() if property.venue_id == "AM-02" else StadiumNpcClubV1.build()))))))
	if property.venue_id == "GRAND-I":
		property.construction.free()
		property.construction = StadiumGrandIPublicConstruction.build()
	if property.venue_id == "GRAND-II":
		property.construction.free()
		property.construction = StadiumGrandIIPublicConstruction.build()
	if property.venue_id == "GRAND-III":
		property.construction.free()
		property.construction = StadiumGrandIIIPublicConstruction.build()
	if property.construction == null:
		property.free()
		return {}
	property.add_child(property.construction)
	property.objects = property.construction.objects
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		model.set_meta("owned_copy", identity)
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			body.set_meta("owned_copy", body.get_meta("npc_instance", identity))
	if property.venue_id not in ["AM-01", "AM-02", "AE-02", "AC-02",
		"LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III"] \
		and not StadiumNpcCandidateConstructionV2.remap(property):
		property.free()
		return {}
	var graph: StadiumRecipeBoundary = StadiumDugoutBoundary.candidate("deeper_center") \
		if property.venue_id == "LONG-YARD" else (StadiumNpcAc02PublicGraph.new() \
		if property.venue_id == "AC-02" else (StadiumNpcMogulOneV1.TemplateView.new() \
		if property.venue_id == "AM-01" else (StadiumNpcMogulTwoV1.TemplateView.new() \
		if property.venue_id == "AM-02" else property.view_graph())))
	if property.venue_id in ["GRAND-I", "GRAND-II", "GRAND-III"]:
		graph = StadiumDugoutBoundary.candidate("straight")
	var reference: Dictionary = {"id": property.venue_id, "graph": graph.identity(),
		"segments": {}, "items": [], "bodies": [], "provenance": {}}
	for segment: Dictionary in graph.segments():
		reference.segments[segment.id] = segment
	var club_bodies: Array = []
	if property.venue_id in ["AC-01", "AC-02", "AM-01", "AM-02", "LONG-YARD",
		"GRAND-I", "GRAND-II", "GRAND-III"]:
		club_bodies = property.construction.get_node("ClubBoundary").bodies
	for body: StaticBody3D in property.find_children("*", "StaticBody3D", true, false):
		var row: Dictionary = _body(body, property)
		if row.is_empty():
			property.free()
			return {}
		if not row.instance.is_empty() and (
			property.venue_id not in ["AC-01", "AC-02", "AM-01", "AM-02",
			"LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III"] \
			or club_bodies.has(body)):
			if not reference.provenance.has(row.instance):
				reference.provenance[row.instance] = []
			reference.provenance[row.instance].append(row.surface)
		if body.has_meta("boundary_segment"):
			row.segment = body.get_meta("boundary_segment")
			row.role = reference.segments[row.segment].role
			reference.bodies.append(row)
		elif club_bodies.has(body):
			reference.bodies.append(row)
		elif property.venue_id in ["AE-01", "AE-02"] \
			and row.role == "RECEIVER_CONTAINMENT_FOUL":
			reference.items.append(row)
		elif property.venue_id == "AE-02" and _ae02_cone(row):
			reference.items.append(row)
	property.free()
	return reference


static func _body(body: StaticBody3D, root: Node3D) -> Dictionary:
	var shapes: Array = []
	for collider: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
		if collider.disabled or collider.shape == null:
			return {}
		var pose: Transform3D = collider.transform
		var parent: Node = collider.get_parent()
		while parent != root:
			if not parent is Node3D:
				return {}
			pose = parent.transform * pose
			parent = parent.get_parent()
		shapes.append({"inverse": pose.affine_inverse(), "shape": collider.shape})
	if shapes.is_empty():
		return {}
	return {"instance": body.get_meta("npc_instance", ""),
		"surface": body.get_meta("surface_id", ""), "segment": body.get_meta("club_surface", ""),
		"role": body.get_meta("surface_role", ""), "kind": body.get_meta("surface_kind", ""),
		"split": body.get_meta("wall_cap_height", 0.0), "shapes": shapes}


static func _contains(body: Dictionary, point: Vector3) -> bool:
	for row: Dictionary in body.shapes:
		var local: Vector3 = row.inverse * point
		var shape: Shape3D = row.shape
		if shape is BoxShape3D:
			if AABB(-shape.size / 2, shape.size).grow(TOLERANCE).has_point(local):
				return true
		elif shape is CylinderShape3D:
			if absf(local.y) <= shape.height / 2 + TOLERANCE \
				and Vector2(local.x, local.z).length() <= shape.radius + TOLERANCE:
				return true
		elif shape is CapsuleShape3D:
			var half: float = maxf(0, shape.height / 2 - shape.radius)
			var nearest: Vector3 = Vector3(0, clampf(local.y, -half, half), 0)
			if local.distance_to(nearest) <= shape.radius + TOLERANCE:
				return true
		elif shape is ConvexPolygonShape3D:
			if _ae02_cone(body) and body.surface == "CONE_BODY":
				if _cone_contains(shape.points, local):
					return true
			elif _prism_contains(shape.points, local):
				return true
	return false


static func _ae02_cone(body: Dictionary) -> bool:
	return body.instance in ["npc:AE-02:r1:O-L1", "npc:AE-02:r1:O-R1"] \
		and body.surface in ["CONE_BASE", "CONE_BODY"] and body.role == "LIVE_RICOCHET"


static func _cone_contains(points: PackedVector3Array, point: Vector3) -> bool:
	# This finite hull is only the unchanged ST-001 factory's two interleaved 12-point rings.
	# A callback records the ball center, not the surface point: retain the existing tolerance
	# as distance to the exact hull, including cap/edge/corner contacts, never a cylinder/AABB.
	if points.size() != 24:
		return false
	for step in range(12):
		var angle: float = TAU * step / 12.0
		for ring_index in range(2):
			var ring: Vector2 = Vector2(0.15, -0.23) if ring_index == 0 else Vector2(0.025, 0.23)
			var expected: Vector3 = Vector3(cos(angle) * ring.x, ring.y, sin(angle) * ring.x)
			if points[step * 2 + ring_index] != expected:
				return false
	if absf(point.y) > 0.23 + TOLERANCE \
		or Vector2(point.x, point.z).length() > 0.15 + TOLERANCE:
		return false
	var inside: bool = absf(point.y) <= 0.23
	var near: bool = false
	for step in range(12):
		var next: int = (step + 1) % 12
		var lower: Vector3 = points[step * 2]
		var upper: Vector3 = points[step * 2 + 1]
		var next_lower: Vector3 = points[next * 2]
		var next_upper: Vector3 = points[next * 2 + 1]
		var normal: Vector3 = (upper - lower).cross(next_lower - lower)
		inside = inside and normal.dot(point - lower) <= 0.0
		near = near or _cone_triangle_near(point, lower, upper, next_lower) \
			or _cone_triangle_near(point, upper, next_upper, next_lower) \
			or _cone_triangle_near(point, Vector3(0, -0.23, 0), lower, next_lower) \
			or _cone_triangle_near(point, Vector3(0, 0.23, 0), upper, next_upper)
	return inside or near


static func _cone_triangle_near(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	# All triangles are nondegenerate because _cone_contains first checks the exact vertices.
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var normal: Vector3 = ab.cross(ac)
	var projected: Vector3 = point - normal * ((point - a).dot(normal) / normal.length_squared())
	var relative: Vector3 = projected - a
	var denominator: float = ab.dot(ab) * ac.dot(ac) - ab.dot(ac) * ab.dot(ac)
	var u: float = (ac.dot(ac) * relative.dot(ab) - ab.dot(ac) * relative.dot(ac)) / denominator
	var v: float = (ab.dot(ab) * relative.dot(ac) - ab.dot(ac) * relative.dot(ab)) / denominator
	if u >= 0.0 and v >= 0.0 and u + v <= 1.0 \
		and point.distance_squared_to(projected) <= TOLERANCE * TOLERANCE:
		return true
	return point.distance_to(Geometry3D.get_closest_point_to_segment(point, a, b)) <= TOLERANCE \
		or point.distance_to(Geometry3D.get_closest_point_to_segment(point, b, c)) <= TOLERANCE \
		or point.distance_to(Geometry3D.get_closest_point_to_segment(point, c, a)) <= TOLERANCE


static func _prism_contains(points: PackedVector3Array, point: Vector3) -> bool:
	# Other retained convex bodies are vertical joined-wall prisms; preserve their polygon.
	if points.size() != 8:
		return false
	var planar: PackedVector2Array = []
	var low: float = INF
	var high: float = -INF
	for vertex: Vector3 in points:
		planar.append(Vector2(vertex.x, vertex.z))
		low = minf(low, vertex.y)
		high = maxf(high, vertex.y)
	if point.y < low - TOLERANCE or point.y > high + TOLERANCE:
		return false
	var polygon: PackedVector2Array = Geometry2D.convex_hull(planar)
	var position: Vector2 = Vector2(point.x, point.z)
	if Geometry2D.is_point_in_polygon(position, polygon):
		return true
	for index in range(polygon.size() - 1):
		if position.distance_to(Geometry2D.get_closest_point_to_segment(
			position, polygon[index], polygon[index + 1])) <= TOLERANCE:
			return true
	return false
