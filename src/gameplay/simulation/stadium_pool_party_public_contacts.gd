class_name StadiumPoolPartyPublicContacts
extends RefCounted
## Neutral authored Pool Party evidence; never paid inventory or an owned-Pool relabel.
## Completed play rows and genuine commit receipts bind to the same exact fixture and factory.
# gdlint: disable=max-returns

const COPY: String = "npc:POOL-PARTY:r1:OL-R"
const WATER_DOUBLE: String = "pool_party_controller_water_double"
const WATER_FOUL: String = "pool_party_controller_water_foul"
const GRAPH: String = "PERIM-POOL-PARTY-TIMBER-STRAIGHT-v1"


static func matches(snapshot: Dictionary) -> bool:
	return StadiumNpcSnapshot.valid(snapshot) \
		and snapshot.version == StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION \
		and snapshot.manifest.id == "POOL-PARTY" and snapshot.manifest.revision == 1


static func geometry(source: String) -> Dictionary:
	var result: Dictionary = StadiumPoolInteriorV2.descriptor(source)
	var vertices: Array = []
	for vertex: Vector2 in result.vertices_xz:
		vertices.append([vertex.x, vertex.y])
	result.vertices_xz = vertices
	return result


static func evidence(value: Variant, plays: Array, observed: Variant,
	snapshot: Dictionary, pool: Variant) -> bool:
	if not matches(snapshot) or not _pool(pool, plays):
		return false
	var reference: Dictionary = _reference(snapshot)
	return not reference.is_empty() and _rows(value, plays, reference, pool) \
		and StadiumNpcPublicContacts._provenance(observed, reference)


# Historical producer admission here is specific to automated report22.
static func evidence_ai22(value: Variant, plays: Array, observed: Variant,
	snapshot: Dictionary, pool: Variant) -> bool:
	if not matches(snapshot) or not _pool_contents(pool, plays):
		return false
	if pool.source_sha256 != StadiumPoolPartyAssetIntegrity.source_sha256() \
		and not StadiumPoolPartyAI22RetainedContract.accepts(pool.source_sha256):
		return false
	var reference: Dictionary = _reference(snapshot)
	return not reference.is_empty() and _rows(value, plays, reference, pool) \
		and StadiumNpcPublicContacts._provenance(observed, reference)


# Called only by the validated version6 neutral-final human envelope.
# Legacy evidence() and _pool() remain current-only; AI epochs are not human authority.
static func evidence_human6(value: Variant, plays: Array, observed: Variant,
	snapshot: Dictionary, pool: Variant) -> bool:
	if not matches(snapshot) or not _pool_contents(pool, plays):
		return false
	if pool.source_sha256 != StadiumPoolPartyAssetIntegrity.source_sha256() \
		and not StadiumPoolPartyAI22RetainedContract.accepts_human6(pool.source_sha256):
		return false
	var reference: Dictionary = _reference(snapshot)
	return not reference.is_empty() and _rows(value, plays, reference, pool) \
		and StadiumNpcPublicContacts._provenance(observed, reference)


static func _pool(value: Variant, plays: Array) -> bool:
	return _pool_contents(value, plays) \
		and value.source_sha256 == StadiumPoolPartyAssetIntegrity.source_sha256()


static func _pool_contents(value: Variant, plays: Array) -> bool:
	if not StadiumNpcSnapshot._keys(value, ["version", "copy", "pose", "geometry",
		"source_sha256", "water_commits", "water_outcomes"]) \
		or not SeasonOwnership._whole(value.version, 1, 1) \
		or not value.copy is String or value.copy != COPY \
		or not StadiumNpcManifest._hash(value.source_sha256) \
		or not StadiumNpcSnapshot._json_types(value) \
		or not StadiumPoolPartyEnvironmentV1._same_profile(value.pose, [12, 0, 18, 0]) \
		or not _geometry_matches(value.geometry, value.source_sha256) \
		or not value.water_commits is Array or not value.water_outcomes is Array \
		or value.water_commits.size() != value.water_outcomes.size() \
		or value.water_commits.size() > plays.size() or plays.size() > 9999:
		return false
	var generation: int = 0
	var previous: int = -1
	for index in range(value.water_commits.size()):
		var commit: Variant = value.water_commits[index]
		if not StadiumNpcSnapshot._keys(commit,
			["generation", "position", "foul", "entry_fraction", "play_sequence"]) \
			or not SeasonOwnership._whole(commit.generation, generation + 1, 2147483647) \
			or not SeasonOwnership._whole(commit.play_sequence, previous + 1, plays.size() - 1) \
			or not commit.foul is bool \
			or not PhysicalMatchReport.number(commit.entry_fraction, 0, 1) \
			or not _water_position(commit.position):
			return false
		var outcome: Variant = value.water_outcomes[index]
		var row: Dictionary = {"play": int(commit.play_sequence),
			"reason": WATER_FOUL if commit.foul else WATER_DOUBLE}
		if not _water_outcome(outcome, row, plays[int(commit.play_sequence)]) \
			or not StadiumPoolPartyEnvironmentV1._same_profile(
				commit.position, outcome.resolution_position):
			return false
		generation = int(commit.generation)
		previous = int(commit.play_sequence)
	return true


static func _geometry_matches(value: Variant, source: String) -> bool:
	# Use the existing full-precision engine JSON canonical form, retaining strict leaf types.
	return StadiumNpcSnapshot._json_types(value) \
		and StadiumPoolPartyEnvironmentV1._same_profile(
			JSON.parse_string(JSON.stringify(value, "", true, true)),
			JSON.parse_string(JSON.stringify(geometry(source), "", true, true)))


static func _rows(value: Variant, plays: Array, reference: Dictionary, pool: Dictionary) -> bool:
	if not value is Array or value.size() != plays.size() or value.size() > 9999:
		return false
	var water: int = 0
	for index in range(value.size()):
		var row: Variant = value[index]
		var play: Variant = plays[index]
		if not StadiumNpcSnapshot._keys(row, ["play", "reason", "events"]) \
			or not SeasonOwnership._whole(row.play, index, index) \
			or not row.reason is String or row.reason.length() > 80 \
			or not row.events is Array or row.events.size() > 128 \
			or not play is Dictionary or not play.get("result") is String:
			return false
		if row.reason in [WATER_DOUBLE, WATER_FOUL]:
			if water >= pool.water_outcomes.size() or not row.events.is_empty() \
				or not _water_outcome(pool.water_outcomes[water], row, play):
				return false
			water += 1
			continue
		if row.reason.begins_with("owned_pool_") or row.reason.begins_with("private_pool_") \
			or row.reason.begins_with("pool_party_"):
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
			if not _event(event, reference) or event.time < last_time:
				return false
			last_time = float(event.time)
			if event.role not in StadiumNpcPublicContacts.LIVE:
				if event_index != row.events.size() - 1 or not required.has(event.role) \
					or not StadiumNpcPublicContacts._terminal(event.role, play, row.reason):
					return false
		if play.result in ["triple", "home_run"] \
			and row.events[-1].role in StadiumNpcPublicContacts.LIVE:
			return false
		if not required.is_empty() and not required.has(row.events[-1].role):
			return false
	return water == pool.water_outcomes.size()


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


static func _event(value: Variant, reference: Dictionary) -> bool:
	if not StadiumNpcSnapshot._keys(value,
		["source", "id", "surface", "role", "position", "time", "kind"]):
		return false
	for key: String in ["source", "id", "surface", "role", "kind"]:
		if not value[key] is String:
			return false
	if not PhysicalMatchReport.number(value.time, 0, 3600) \
		or not StadiumPoolOwnedReport._position_valid(value.position):
		return false
	var point: Vector3 = Vector3(value.position[0], value.position[1], value.position[2])
	if value.source == "item":
		if value.kind != "contact":
			return false
		for row: Dictionary in reference.items:
			if row.instance == value.id and row.surface == value.surface and row.role == value.role \
				and _contains(row, point):
				return true
		return false
	if value.source != "boundary" or value.id != GRAPH \
		or value.kind not in ["contact", "crossing"]:
		return false
	for row: Dictionary in reference.bodies:
		var role: String = StadiumNpcClubPoleV1.role_at(
			clampf(point.y, 0, StadiumNpcClubFoulSitesV1.HEIGHT), row.split) \
			if row.kind == "pole" else row.role
		if row.segment == value.surface and role == value.role \
			and StadiumNpcPublicContacts._contains(row, point):
			return true
	return value.kind == "crossing" and StadiumNpcPublicContacts._crossing(value, point, reference)


static func _contains(body: Dictionary, point: Vector3) -> bool:
	if StadiumNpcPublicContacts._contains(body, point):
		return true
	# Exact authored concave solid faces; preserve the shared 0.1 m ball-center tolerance.
	for row: Dictionary in body.shapes:
		if not row.shape is ConcavePolygonShape3D:
			continue
		var local: Vector3 = row.inverse * point
		var faces: PackedVector3Array = row.shape.get_faces()
		for index in range(0, faces.size(), 3):
			if StadiumNpcPublicContacts._cone_triangle_near(
				local, faces[index], faces[index + 1], faces[index + 2]):
				return true
	return false


static func _reference(snapshot: Dictionary) -> Dictionary:
	if not matches(snapshot) or not StadiumNpcPublicRuntime.source_qualified():
		return {}
	var construction: StadiumPoolPartyPublicConstruction = StadiumPoolPartyPublicConstruction.build()
	if construction == null:
		return {}
	var boundary: StadiumPoolPartyPublicBoundarySource = (
		construction.get_node_or_null("ClubBoundary") as StadiumPoolPartyPublicBoundarySource)
	if boundary == null or boundary.graph.identity() != GRAPH:
		construction.free()
		return {}
	var reference: Dictionary = {"id": "POOL-PARTY", "graph": GRAPH,
		"segments": {}, "items": [], "bodies": [], "provenance": {}}
	for segment: Dictionary in boundary.graph.segments():
		reference.segments[segment.id] = segment
	var pool: Node3D = construction.objects.get(COPY) as Node3D
	if pool == null:
		construction.free()
		return {}
	for body: StaticBody3D in construction.find_children("*", "StaticBody3D", true, false):
		var is_pool: bool = pool.is_ancestor_of(body)
		if not is_pool and not boundary.bodies.has(body):
			continue
		var row: Dictionary = StadiumNpcPublicContacts._body(body, construction)
		if row.is_empty():
			construction.free()
			return {}
		# External mapping only: exact factory metadata and mesh remain untouched.
		if is_pool:
			row.instance = COPY
			row.surface = String(body.name)
		if not row.instance.is_empty():
			if not reference.provenance.has(row.instance):
				reference.provenance[row.instance] = []
			reference.provenance[row.instance].append(row.surface)
		if boundary.bodies.has(body):
			reference.bodies.append(row)
		else:
			reference.items.append(row)
	if not reference.provenance.has(COPY):
		construction.free()
		return {}
	reference.provenance[COPY].append(StadiumPoolInteriorV2.VOLUME_ID)
	construction.free()
	return reference


static func _water_outcome(value: Variant, row: Dictionary, play: Dictionary) -> bool:
	if not StadiumNpcSnapshot._keys(value, ["play", "reason", "resolution_position",
		"result_floor", "last_defender_touch", "has_first_ground", "result"]) \
		or not SeasonOwnership._whole(value.play, row.play, row.play) \
		or not value.reason is String or value.reason != row.reason \
		or not value.result is String or value.result != play.get("result") \
		or not _water_position(value.resolution_position) \
		or not value.has_first_ground is bool or value.has_first_ground \
		or not value.last_defender_touch is String or not value.last_defender_touch.is_empty() \
		or not SeasonOwnership._whole(value.result_floor, 0, BallPlayState.ResultFloor.DOUBLE) \
		or not SeasonOwnership._whole(play.get("contact"), 1, 3) \
		or not PhysicalMatchReport.number(play.get("exit_speed"), 0.0001, 1000):
		return false
	if row.reason == WATER_DOUBLE:
		return play.result == "double" and play.contact != ContactResult.Outcome.FOUL \
			and value.result_floor == BallPlayState.ResultFloor.DOUBLE
	return row.reason == WATER_FOUL and play.result == "foul" \
		and play.contact == ContactResult.Outcome.FOUL


static func _water_position(value: Variant) -> bool:
	if not StadiumPoolOwnedReport._position_valid(value):
		return false
	var local: Vector3 = Vector3(value[0] - 12, value[1], value[2] - 18)
	var normalized: Vector3 = StadiumPoolContract.placement() * local
	# This pure terminal-domain check neither borrows ownership nor infers a missing trajectory.
	return StadiumPoolMatchReport._water_position_valid([normalized.x, normalized.y, normalized.z])
