class_name StadiumPoolOwnedReport
extends RefCounted
## Public owned-Pool report wrapper. Shape evidence is not paid ownership authority.
## The ordinary expected fixture and paid ledger prefix govern replay/settlement.
# gdlint: disable=max-returns

const VERSION: int = 14
const RESOLVER: String = "physical-ai-owned-pool-v1"
const EVIDENCE_VERSION: int = 1
const MAX_JSON_BYTES: int = 16777216
const WATER_DOUBLE: String = "owned_pool_controller_water_double"
const WATER_FOUL: String = "owned_pool_controller_water_foul"
# Append-only reviewed report-producing source epochs, bound to exact geometry.
# V28-r4 is a bounded human-owned result, not production or shipping qualification.
const HISTORICAL_RUNTIME_CONTRACTS: Dictionary = {
	# Genuine completed current owned-human and AI14 producers; exact unchanged layout.
	"dcbccde54d9afcde87c40263208ac5ad3fa8764d8bbed486652f6a00f3c48081":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Genuine predecessor owned-human pending evidence; existing paid checks remain authoritative.
	"7fbe121edda3bcde3e79844cec10b75300fca46f4bf228a741b1886c4d34d437":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Preserve the accepted final placement epoch across the public AY-02 merge.
	"126169c1560f9f4255574f68dd9c68050667a595f2070449d7054f6173732633":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Last accepted integrated Pool epoch, preserved across public AY-02 source addition.
	"ff4995cc3e6b58450d304ba18d368c040d223c688aa83ba5799b21a757a99d93":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Preserve the accepted V83-r5 completed-report epoch through workshop-only changes.
	"c198e0d9555480658bb2db484866087300dedac9e379bb8cb4f083c3a726d1a3":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Preserve exact V80-r3 current-source admissibility; no completed-report claim.
	"f9f511051e05d83f952a582895513b7dc018e52fb33c60abcf3bbaed554aaedb":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Preserve exact accepted V77 current-source admissibility; no completed-report claim.
	"18deae5209bd7403d0bf964394822718d6303880e6b0560bc8339e94cad8add2":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Preserve V68-r2 current-source admissibility; no completed-report claim.
	"ecc624223c9f9b07677eea8fa34a0ab0a77178b2cc745f536c036c240dfad789":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Preserve V66-r2 current-source admissibility; no completed-report claim.
	"76790c0c7b28acd66f94f43f19b7bc4cf81243cd8d83f381b0bfa1385d55c7bd":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	"aafc6c19ba77e71681b0ea5191d3353ea1a3c546eb16c845bef58aa4af773882":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	"4a90e9de631715bab6b55e05c7888fd564109b27f9792d0da8117b88e4b7243f":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Preserve V71-r3 current-source admissibility; no completed-report claim.
	"b019020a75179a39233da974a461644cf1c1a0ca195f5357348f10e0883639bb":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	# Preserve V74-r2 current-source admissibility; no completed-report claim.
	"da2c0d0f05e94b59164c15a26e65d806165100cc5f27bca06d0c3b6b47f78153":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5"
}


# Exact completed AI-report producer; intentionally NOT owned-human evidence history.
# Retained only for the reviewed unchanged owned runtime and exact layout contract.
const HISTORICAL_AI_REPORT_RUNTIME_CONTRACTS: Dictionary = {
	"7fbe121edda3bcde3e79844cec10b75300fca46f4bf228a741b1886c4d34d437":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	"92774bb8aee1b4bc566beac4f1203b424508c99a371f725bb3839519d978dfea":
		"a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5"
}


static func capture(lab: PitchBatLab) -> Dictionary:
	return _capture_context(lab, {})


static func _capture_context(lab: PitchBatLab, context: Dictionary) -> Dictionary:
	if lab == null or not lab.is_inside_tree() or lab._match_state == null \
		or lab._automation == null or lab._match_state.phase != MatchState.Phase.GAME_END:
		return {}
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	var snapshot: Dictionary = lab._match_state.stadium
	if property == null or not property.valid_owner_full_ledger(lab) or adapter == null \
		or not property.owned_field_boundary_valid(lab) \
		or adapter._bound_profile != property or not adapter.enabled \
		or not adapter.freeflight_enabled or adapter.is_committing() \
		or not StadiumPoolOwnedSnapshot.matches(snapshot, lab._stadium_ledger) \
		or not StadiumBoundaryRuntime.installed(lab, snapshot):
		if property != null and property._owned_field_lease != null:
			property.revoke_owned_field("CAPTURE_OWNER_BOUNDARY_CHANGED")
		return {}
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	if adapter._source != source or adapter._model != property.pool_model \
		or adapter._prepared == null or not adapter._prepared.valid(
			property.pool_model, StadiumPoolContract.LIVE, source):
		if property._owned_field_lease != null:
			property.revoke_owned_field("CAPTURE_PREPARATION_BOUNDARY_CHANGED")
		return {}
	var result: Dictionary = CurrentPhysicalStadiumEvidence.capture_base(lab, context)
	if not CurrentPhysicalStadiumEvidence.base_valid(result, context) or result.version != PhysicalMatchReport.BASE_VERSION:
		return {}
	result.version = VERSION
	result.resolver = RESOLVER
	result["property"] = StadiumPoolOwnedSnapshot.normalized(snapshot)
	result["surfaces"] = PhysicalStadiumContacts.capture(lab._play_records)
	var outcomes: Array[Dictionary] = []
	for index in range(lab._play_records.size()):
		var play: PlayRecord = lab._play_records[index]
		if String(play.resolution_reason) in [WATER_DOUBLE, WATER_FOUL]:
			outcomes.append({"play": index, "reason": String(play.resolution_reason),
				"resolution_position": [play.resolution_position.x,
					play.resolution_position.y, play.resolution_position.z],
				"result_floor": play.result_floor,
				"last_defender_touch": String(play.last_defender_touch),
				"has_first_ground": play.has_first_ground, "result": String(play.result)})
	result["pool"] = {"version": EVIDENCE_VERSION, "copy": snapshot.layout.pool.copy,
		"pose": StadiumPoolMatchReport._pose(property.admitted_pose()),
		"geometry": StadiumPoolOwnedLayout.signature(), "source_sha256": source,
		"water_commits": adapter.commits, "water_outcomes": outcomes}
	if not _valid_context(result, context):
		return {}
	var encoded: String = JSON.stringify(result, "", true, true)
	var decoded: Variant = JSON.parse_string(encoded)
	return result if _valid_context(decoded, context) and ClubCareer.same(result, decoded) else {}


static func matches(value: Dictionary, expected: Dictionary, ledger: ClubAssetLedger) -> bool:
	# A parsed report is evidence, not a source of purchased ownership.
	return valid(value) and not expected.is_empty() \
		and StadiumPoolOwnedSnapshot.matches(expected, ledger) \
		and StadiumPoolOwnedSnapshot.key(value.property) == StadiumPoolOwnedSnapshot.key(expected) \
		and value.seed == expected.environment.seed


static func core(value: Dictionary) -> Dictionary:
	return _core(value) if valid(value) else {}


static func _core(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("property")
	result.erase("surfaces")
	result.erase("pool")
	result.version = PhysicalMatchReport.BASE_VERSION
	result.resolver = PhysicalMatchReport.BASE_RESOLVER
	return result


static func valid(value: Variant) -> bool:
	return _valid_context(value, {})


static func _valid_context(value: Variant, context: Dictionary) -> bool:
	if not value is Dictionary or not SeasonOwnership._whole(value.get("version"), VERSION, VERSION) \
		or value.get("resolver") != RESOLVER or not value.get("property") is Dictionary \
		or not value.get("pool") is Dictionary or not value.get("surfaces") is Array \
		or not value.get("plays") is Array or not CurrentPhysicalStadiumEvidence.base_valid(_core(value), context):
		return false
	var snapshot: Dictionary = value.property
	if not StadiumPoolOwnedSnapshot.valid(snapshot) \
		or snapshot.version != StadiumPoolOwnedSnapshot.FIXTURE_VERSION \
		or snapshot.environment.seed != value.seed or value.field != String(PitchBatLab.FIELD_ID):
		return false
	var evidence: Dictionary = value.pool
	if not SeasonOwnership._keys(evidence,
		["version", "copy", "pose", "geometry", "source_sha256", "water_commits", "water_outcomes"]) \
		or not SeasonOwnership._whole(evidence.version, EVIDENCE_VERSION, EVIDENCE_VERSION) \
		or not evidence.copy is String or evidence.copy != snapshot.layout.pool.copy \
		or evidence.geometry != StadiumPoolOwnedLayout.signature() \
		or not _ai_report_source_hash(evidence.source_sha256) \
		or not evidence.water_outcomes is Array \
		or not SeasonOwnership._whole(evidence.water_commits, 0, value.plays.size()) \
		or evidence.water_commits != evidence.water_outcomes.size() \
		or value.surfaces.size() != value.plays.size() or value.plays.size() > 9999:
		return false
	var pose: Transform3D = StadiumPoolOwnedLayout.pose(snapshot.layout)
	var expected: Array = StadiumPoolMatchReport._pose(pose)
	if not evidence.pose is Array or evidence.pose.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not PhysicalMatchReport.number(evidence.pose[index], expected[index], expected[index]):
			return false
	if not _rows(value.surfaces, value.plays, snapshot, evidence.copy,
		evidence.water_outcomes, pose):
		return false
	return JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= MAX_JSON_BYTES


static func _ai_report_source_hash(value: Variant) -> bool:
	# AI-only history never broadens the shared predicate used by human evidence.
	return _source_hash(value) or (_digest_shape(value)
		and HISTORICAL_AI_REPORT_RUNTIME_CONTRACTS.has(value)
		and HISTORICAL_AI_REPORT_RUNTIME_CONTRACTS[value] == StadiumPoolOwnedLayout.signature())


static func _source_hash(value: Variant) -> bool:
	# Current exact source or explicitly retained reviewed history only.
	# Neither source identity substitutes for expected fixture and paid-prefix checks.
	return _digest_shape(value) and (value == StadiumPoolPartyAssetIntegrity.source_sha256() or (
		HISTORICAL_RUNTIME_CONTRACTS.has(value) and HISTORICAL_RUNTIME_CONTRACTS[value]
		== StadiumPoolOwnedLayout.signature()))


static func _digest_shape(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _rows(value: Array, plays: Array, snapshot: Dictionary,
	owned_copy: String, outcomes: Array, pose: Transform3D) -> bool:
	var access: Array[String] = []
	access.assign(snapshot.surface_access)
	var layout: Dictionary = StadiumPoolOwnedLayout.validate(
		snapshot.layout, StadiumLayoutSnapshot.ownership(snapshot), access, snapshot.tier)
	if not layout.ok:
		return false
	var placements: Dictionary = {}
	for placed: Dictionary in layout.placements:
		placements[placed.copy] = placed
	var graph: StadiumRecipeBoundary = StadiumPoolOwnedLayout.graph_for(snapshot.layout)
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
				or not _water_outcome(outcomes[water_count], row, play, pose)):
				return false
			water_count += 1
		elif row.reason.begins_with("private_pool_") or row.reason.begins_with("owned_pool_"):
			return false
		var required: Array = PhysicalStadiumContacts._reason_roles(row.reason)
		if row.events.is_empty() and (not required.is_empty() or play.result in ["triple", "home_run"]):
			return false
		var last_time: float = -1
		for index in range(row.events.size()):
			var event: Variant = row.events[index]
			var accepted: bool = _pool_event(event, owned_copy, pose) if (
				event is Dictionary and event.get("id") == owned_copy
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


static func _pool_event(value: Variant, owned_copy: String, pose: Transform3D) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["source", "id", "surface", "role", "position", "time", "kind"]):
		return false
	for field: String in ["source", "id", "surface", "role", "kind"]:
		if not value[field] is String:
			return false
	if (value.source != "item" or value.id != owned_copy or value.kind != "contact"
		or value.role != "LIVE_RICOCHET" or not value.surface is String
		or (value.surface not in StadiumPoolContract.SURFACES and value.surface != "POOL_LADDER")
		or not PhysicalMatchReport.number(value.time, 0, 3600)
		or not _position_valid(value.position)):
		return false
	var point: Vector3 = Vector3(value.position[0], value.position[1], value.position[2])
	var local: Vector3 = pose.affine_inverse() * point
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


static func _water_outcome(value: Variant, row: Dictionary, play: Dictionary,
	pose: Transform3D) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, [
		"play", "reason", "resolution_position", "result_floor", "last_defender_touch",
		"has_first_ground", "result"
	]):
		return false
	if (
		not SeasonOwnership._whole(value.play, row.play, row.play) or value.reason != row.reason
		or not value.reason is String or not value.result is String
		or value.result != play.result or not _water_position_valid(value.resolution_position, pose)
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


static func _water_position_valid(value: Variant, pose: Transform3D) -> bool:
	if not _position_valid(value):
		return false
	var point: Vector3 = Vector3(value[0], value[1], value[2])
	var normalized: Vector3 = StadiumPoolContract.placement() * (pose.affine_inverse() * point)
	# Same supported terminal domain, normalized to the admitted rigid owned pose.
	# This does not independently replay a missing trajectory or manufacture its radius.
	return StadiumPoolMatchReport._water_position_valid(
		[normalized.x, normalized.y, normalized.z])


static func _position_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for coordinate: Variant in value:
		if not PhysicalMatchReport.number(coordinate, -1000, 1000):
			return false
	return true
