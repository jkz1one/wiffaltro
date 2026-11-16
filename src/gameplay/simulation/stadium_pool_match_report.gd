class_name StadiumPoolMatchReport
extends RefCounted
## Private, source-bound completed-match observation; never public ownership or settlement.
## Water terminal records are captured provenance, not an independent entry/history proof.
# gdlint: disable=max-returns

const VERSION: int = 1
const RESOLVER: String = "private-pool-bound-match-v1"
const MAX_JSON_BYTES: int = 16777216  # 16 MiB; overflow fails, never truncates evidence.
const WATER_DOUBLE: String = "private_pool_controller_water_double"
const WATER_FOUL: String = "private_pool_controller_water_foul"


static func capture(
	lab: PitchBatLab, entitlement: StadiumPoolBoundEntitlement, active_enabled: bool
) -> Dictionary:
	if (
		lab == null or entitlement == null or not lab.is_inside_tree()
		or lab._match_state == null or lab._automation == null
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or lab.pool_bound_startup_failed
		or lab.get_meta("stadium_candidate_only", false)
		or lab.get_meta("stadium_npc_retained_lab_only", false)
	):
		return {}
	var property: StadiumPoolBoundProperty = StadiumPoolBoundExtension.current(lab)
	var request: StadiumPoolBoundExtension = StadiumPoolBoundExtension._request(lab)
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	var snapshot: Dictionary = lab._match_state.stadium
	if (
		property == null or request == null or adapter == null
		or property.entitlement != entitlement or request._token != entitlement
		or request._enabled != active_enabled or adapter.enabled != active_enabled
		or not adapter.freeflight_enabled or adapter._lab != lab
		or adapter._bound_profile != property or adapter._model != property.pool_model
		or adapter._role != StadiumPoolContract.LIVE or adapter.is_committing()
		or not property.valid_owner(lab)
		or not entitlement.owns(lab, snapshot, property)
		or not StadiumPoolBoundEntitlement.exact_base(snapshot, lab._stadium_ledger)
	):
		return {}
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	var descriptor: Dictionary = entitlement.descriptor()
	if (
		source.length() != 64 or descriptor.source_sha256 != source or adapter._source != source
		or adapter._prepared == null
		or not adapter._prepared.valid(property.pool_model, StadiumPoolContract.LIVE, source)
	):
		return {}
	var core: Dictionary = PhysicalMatchReport._capture_core(lab)
	var outcomes: Array[Dictionary] = []
	for index in range(lab._play_records.size()):
		var play: PlayRecord = lab._play_records[index]
		if String(play.resolution_reason) in [WATER_DOUBLE, WATER_FOUL]:
			outcomes.append({
				"play": index, "reason": String(play.resolution_reason),
				"resolution_position": [play.resolution_position.x,
					play.resolution_position.y, play.resolution_position.z],
				"result_floor": play.result_floor,
				"last_defender_touch": String(play.last_defender_touch),
				"has_first_ground": play.has_first_ground, "result": String(play.result)
			})
	var result: Dictionary = {
		"version": VERSION, "resolver": RESOLVER, "core": core,
		"property": StadiumLayoutSnapshot.normalized(snapshot),
		"extension": {"entitlement": _encode_descriptor(descriptor),
			"geometry": _geometry(source), "active_enabled": active_enabled},
		"surfaces": PhysicalStadiumContacts.capture(lab._play_records),
		"water_commits": adapter.commits, "water_outcomes": outcomes
	}
	if not valid(result):
		return {}
	# Validate JSON export itself; never rely on engine-specific Transform3D serialization.
	var encoded: String = JSON.stringify(result, "", true, true)
	if encoded.to_utf8_buffer().size() > MAX_JSON_BYTES:
		return {}
	var restored: Variant = JSON.parse_string(encoded)
	return result if valid(restored) and ClubCareer.same(result, restored) else {}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, [
		"version", "resolver", "core", "property", "extension", "surfaces",
		"water_commits", "water_outcomes"
	]):
		return false
	if (
		not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not value.resolver is String or value.resolver != RESOLVER
		or not value.core is Dictionary
		or not SeasonOwnership._whole(value.core.get("version"),
			PhysicalMatchReport.BASE_VERSION, PhysicalMatchReport.BASE_VERSION)
		or not PhysicalMatchReport.valid(value.core)
		or value.core.field != String(PitchBatLab.FIELD_ID)
		or not _base_valid(value.property)
	):
		return false
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _extension_valid(value.extension, value.property, source):
		return false
	if (
		not value.surfaces is Array or value.surfaces.size() != value.core.plays.size()
		or value.core.plays.size() > 9999 or not value.water_outcomes is Array
		or not SeasonOwnership._whole(value.water_commits, 0, value.core.plays.size())
		or value.water_outcomes.size() != value.water_commits
		or (not value.extension.active_enabled and value.water_commits != 0)
	):
		return false
	if not _rows(value.surfaces, value.core.plays, value.property,
		value.extension.entitlement.copy, value.water_outcomes):
		return false
	return JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= MAX_JSON_BYTES


static func _base_valid(value: Variant) -> bool:
	return (
		value is Dictionary and StadiumLayoutSnapshot.valid(value)
		and SeasonOwnership._whole(value.version, 3, 3) and value.tier == "backyard"
		and ClubCareer.same(value, StadiumLayoutSnapshot.normalized(value))
		and ClubCareer.same(value.layout, StadiumPoolBoundEntitlement.base_layout())
		and value.boundary == StadiumBoundaryGraph.signature()
		and ClubCareer.same(value.inventory, StadiumStock.new_club().to_data())
	)


static func _extension_valid(value: Variant, snapshot: Dictionary, source: String) -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["entitlement", "geometry", "active_enabled"])
		or not value.active_enabled is bool or source.length() != 64
		or not _entitlement_valid(value.entitlement, snapshot, source)
		or not value.geometry is Dictionary
		or not ClubCareer.same(value.geometry, _geometry(source))
	):
		return false
	return true


static func _entitlement_valid(value: Variant, snapshot: Dictionary, source: String) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, StadiumPoolBoundEntitlement.FIELDS):
		return false
	for field: String in ["owner", "match", "serial"]:
		if not _decimal_id(value[field], field == "match"):
			return false
	for field: String in ["authority", "lifetime", "copy", "item", "role",
		"base_key", "source_sha256"]:
		if not value[field] is String:
			return false
	return (
		SeasonOwnership._whole(value.version, StadiumPoolBoundEntitlement.VERSION,
			StadiumPoolBoundEntitlement.VERSION)
		and value.authority == StadiumPoolBoundEntitlement.AUTHORITY
		and value.lifetime == StadiumPoolBoundEntitlement.LIFETIME
		and value.copy == "private-pool-v26:%s:%s" % [value.owner, value.serial]
		and value.item == "ST-006" and value.role == StadiumPoolContract.LIVE
		and value.base_key == StadiumLayoutSnapshot.key(snapshot)
		and value.source_sha256 == source
		and _pose_valid(value.pose)
		and SeasonOwnership._whole(value.capacity, 4, 4)
		and PhysicalMatchReport.number(value.reservation_radius,
			StadiumPoolContract.RESERVATION_RADIUS, StadiumPoolContract.RESERVATION_RADIUS)
	)


static func _decimal_id(value: Variant, signed: bool = false) -> bool:
	if not value is String or value.is_empty() or value.length() > 20:
		return false
	# Node owner/serial are positive; RefCounted match IDs may use the signed high bit.
	# Preserve the original signed decimal exactly, without numeric coercion or masking.
	var negative: bool = value.begins_with("-")
	if negative and not signed:
		return false
	var digits: String = value.substr(1) if negative else value
	var limit: String = "9223372036854775808" if negative else "9223372036854775807"
	if (digits.is_empty() or digits.length() > 19 or digits[0] == "0"
		or (digits.length() == 19 and digits > limit)):
		return false
	for character: String in digits:
		if character < "0" or character > "9":
			return false
	return true


static func _encode_descriptor(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for field: String in ["owner", "match", "serial"]:
		result[field] = str(value[field])
	result.pose = _pose(value.pose)
	return result


static func _pose(value: Transform3D) -> Array:
	return [value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z,
		value.origin.x, value.origin.y, value.origin.z]


static func _pose_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 12:
		return false
	var expected: Array = _pose(StadiumPoolContract.placement())
	for index in range(12):
		if not PhysicalMatchReport.number(value[index], expected[index], expected[index]):
			return false
	return true


static func _geometry(source: String) -> Dictionary:
	# The live exact model was checked by its bound preparation before capture.
	# This finite source-bound descriptor identifies authored geometry, not physics qualification.
	var interior: Dictionary = StadiumPoolInteriorV2.descriptor(source)
	var vertices: Array = []
	for vertex: Vector2 in interior.vertices_xz:
		vertices.append([vertex.x, vertex.y])
	interior.vertices_xz = vertices
	return {"model_id": StadiumPoolInteriorV2.MODEL_ID,
		"version": StadiumPoolInteriorV2.VERSION, "solid_id": StadiumPoolContract.ID,
		"source_sha256": source, "outer_radius": StadiumPoolContract.OUTER_RADIUS,
		"inner_radius": StadiumPoolContract.INNER_RADIUS,
		"wall_height": StadiumPoolContract.WALL_HEIGHT,
		"surfaces": StadiumPoolContract.SURFACES.duplicate(),
		"ladder": [StadiumPoolContract.LADDER.position.x, StadiumPoolContract.LADDER.position.y,
			StadiumPoolContract.LADDER.position.z, StadiumPoolContract.LADDER.size.x,
			StadiumPoolContract.LADDER.size.y, StadiumPoolContract.LADDER.size.z],
		"water": interior}


static func _rows(value: Array, plays: Array, snapshot: Dictionary,
	private_copy: String, outcomes: Array) -> bool:
	var layout: Dictionary = StadiumHomeLayout.validate(
		snapshot.layout, StadiumLayoutSnapshot.ownership(snapshot), snapshot.tier)
	if not layout.ok:
		return false
	var placements: Dictionary = {}
	for placed: Dictionary in layout.placements:
		placements[placed.copy] = placed
	var graph: StadiumRecipeBoundary = StadiumWallItems.graph_for(snapshot.layout)
	var previous: int = -1
	var water_count: int = 0
	for row: Variant in value:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["play", "reason", "events"]) \
			or not SeasonOwnership._whole(row.play, previous + 1, previous + 1) \
			or not row.events is Array or row.events.size() > 128 \
			or not row.reason is String or row.reason.length() > 80:
			return false
		previous = int(row.play)
		var play: Dictionary = plays[previous]
		if not row.events.is_empty() and (not SeasonOwnership._whole(play.get("contact"), 1, 3)
			or not PhysicalMatchReport.number(play.get("exit_speed"), 0.0001, 1000)):
			return false
		if row.reason in [WATER_DOUBLE, WATER_FOUL]:
			if (water_count >= outcomes.size() or not row.events.is_empty()
				or not _water_outcome(outcomes[water_count], row, play)):
				return false
			water_count += 1
		elif row.reason.begins_with("private_pool_"):
			return false
		var required: Array = PhysicalStadiumContacts._reason_roles(row.reason)
		if row.events.is_empty() and (not required.is_empty() or play.result in ["triple", "home_run"]):
			return false
		var last_time: float = -1
		for index in range(row.events.size()):
			var event: Variant = row.events[index]
			var accepted: bool = _pool_event(event, private_copy) if (
				event is Dictionary and event.get("id") == private_copy
			) else PhysicalStadiumContacts._event(event, placements, graph)
			if not accepted or event.time < last_time:
				return false
			last_time = float(event.time)
			if event.role not in ["SIDE_RETURN_LIVE", "LIVE_RICOCHET"]:
				if index != row.events.size() - 1 \
					or not PhysicalStadiumContacts._terminal(event.role, play) \
					or not required.has(event.role):
					return false
		if not required.is_empty() and not required.has(row.events[-1].role):
			return false
	return water_count == outcomes.size()


static func _pool_event(value: Variant, private_copy: String) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["source", "id", "surface", "role", "position", "time", "kind"]):
		return false
	for field: String in ["source", "id", "surface", "role", "kind"]:
		if not value[field] is String:
			return false
	if (value.source != "item" or value.id != private_copy or value.kind != "contact"
		or value.role != "LIVE_RICOCHET" or not value.surface is String
		or (value.surface not in StadiumPoolContract.SURFACES and value.surface != "POOL_LADDER")
		or not PhysicalMatchReport.number(value.time, 0, 3600)
		or not _position_valid(value.position)):
		return false
	var point: Vector3 = Vector3(value.position[0], value.position[1], value.position[2])
	var local: Vector3 = StadiumPoolContract.placement().affine_inverse() * point
	# Same 0.1 m positional provenance tolerance as ordinary item contacts: recorded rounded
	# ball center inside its authored solid-part AABB, not a triangle-exact contact witness.
	return _solid_bounds(value.surface).grow(0.1).has_point(local)


static func _solid_bounds(surface: String) -> AABB:
	if surface == "POOL_LADDER":
		return StadiumPoolContract.LADDER
	var faces: PackedVector3Array = StadiumPoolContract.faces(surface)
	var bounds: AABB = AABB(faces[0], Vector3.ZERO)
	for point: Vector3 in faces:
		bounds = bounds.expand(point)
	return bounds


static func _water_outcome(value: Variant, row: Dictionary, play: Dictionary) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, [
		"play", "reason", "resolution_position", "result_floor", "last_defender_touch",
		"has_first_ground", "result"
	]):
		return false
	if (
		not SeasonOwnership._whole(value.play, row.play, row.play) or value.reason != row.reason
		or not value.reason is String or not value.result is String
		or value.result != play.result or not _water_position_valid(value.resolution_position)
		or not value.has_first_ground is bool or value.has_first_ground
		or not value.last_defender_touch is String or not value.last_defender_touch.is_empty()
		or not SeasonOwnership._whole(value.result_floor, 0, BallPlayState.ResultFloor.DOUBLE)
		or not SeasonOwnership._whole(play.contact, 1, 3)
		or not PhysicalMatchReport.number(play.exit_speed, 0.0001, 1000)
	):
		return false
	if row.reason == WATER_DOUBLE:
		return (play.result == "double" and play.contact != ContactResult.Outcome.FOUL
			and value.result_floor == BallPlayState.ResultFloor.DOUBLE)
	return row.reason == WATER_FOUL and play.result == "foul" \
		and play.contact == ContactResult.Outcome.FOUL


static func _water_position_valid(value: Variant) -> bool:
	if not _position_valid(value):
		return false
	var point: Vector3 = Vector3(value[0], value[1], value[2])
	var minimum: float = StadiumPoolContract.WATER_HEIGHT + (
		StadiumPoolControllerActive.FreeflightEntry.MIN_RADIUS_M
		- StadiumPoolControllerActive.FreeflightEntry.WITNESS_DEPTH_M
		- StadiumPoolControllerActive.FreeflightEntry.CLEARANCE_PAD_M)
	var maximum: float = StadiumPoolContract.WATER_HEIGHT + (
		StadiumPoolControllerActive.FreeflightEntry.MAX_RADIUS_M
		- StadiumPoolControllerActive.FreeflightEntry.WITNESS_DEPTH_M
		+ StadiumPoolControllerActive.FreeflightEntry.CLEARANCE_PAD_M)
	# Terminal-domain consistency only. No per-play radius or missing trajectory is inferred.
	return (
		StadiumPoolControllerActive.FreeflightEntry.bounded_point(point)
		and PhysicalMatchReport.number(point.y, minimum, maximum)
		and StadiumPoolControllerActive.FreeflightEntry.interior_clear(point,
			StadiumPoolControllerActive.FreeflightEntry.MIN_RADIUS_M)
	)


static func _position_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for coordinate: Variant in value:
		if not PhysicalMatchReport.number(coordinate, -1000, 1000):
			return false
	return true
