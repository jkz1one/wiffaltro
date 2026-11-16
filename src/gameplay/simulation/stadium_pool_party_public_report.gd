class_name StadiumPoolPartyPublicReport
extends RefCounted
## Exact neutral-final qualification envelope; report7 remains the baseball authority.
## Binding names the neutral venue owner separately from the higher-seed batting home.
## This envelope does not release the Pool Party earned-final pairing or public selection.

const VERSION: int = 22
const MAX_BYTES: int = 16777216
const RESOLVER: String = "physical-ai-neutral-final-pool-party-v1"


static func supports_definition(id: String, revision: int) -> bool:
	return id == "POOL-PARTY" and revision == 1


static func capture(lab: PitchBatLab) -> Dictionary:
	return _capture_context(lab, {})


static func _capture_context(lab: PitchBatLab, context: Dictionary) -> Dictionary:
	if lab == null or not lab.is_inside_tree() \
		or lab._match_state == null or lab._automation == null \
		or lab._match_state.phase != MatchState.Phase.GAME_END \
		or lab._match_state.stadium.get("version") \
		!= StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION \
		or not StadiumNpcPublicRuntime.installed_bound(lab, lab._match_state.stadium) \
		or not StadiumPoolPartyRuntime.installed_bound(lab, lab._match_state.stadium):
		return {}
	var result: Dictionary = CurrentPhysicalStadiumEvidence.capture_base(lab, context)
	result.field = String(PitchBatLab.FIELD_ID)
	if result.get("version") != PhysicalMatchReport.BASE_VERSION \
		or not CurrentPhysicalStadiumEvidence.base_valid(result, context):
		return {}
	result.field = StadiumNpcSnapshot.FIELD
	result.version = VERSION
	result.resolver = RESOLVER
	result["property"] = StadiumNpcSnapshot.normalized(lab._match_state.stadium)
	result["surfaces"] = PhysicalStadiumContacts.capture(lab._play_records)
	result["yard"] = StadiumNpcPublicRuntime._property(lab).provenance.duplicate(true)
	result["pool"] = StadiumPoolPartyRuntime.capture_evidence(lab)
	if not _valid_context(result, context):
		return {}
	var decoded: Variant = JSON.parse_string(JSON.stringify(result, "", true, true))
	return result if _valid_context(decoded, context) and ClubCareer.same(result, decoded) else {}


static func valid(value: Variant) -> bool:
	return _valid_context(value, {})


static func _valid_context(value: Variant, context: Dictionary) -> bool:
	if not value is Dictionary or not SeasonOwnership._whole(value.get("version"), VERSION, VERSION) \
		or not StadiumNpcSnapshot._json_types(value) \
		or JSON.stringify(value, "", true, true).to_utf8_buffer().size() > MAX_BYTES \
		or not value.get("resolver") is String or value.resolver != RESOLVER \
		or not StadiumNpcSnapshot.valid(value.get("property")) \
		or value.property.version != StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION \
		or not supports_definition(value.property.manifest.id, value.property.manifest.revision) \
		or not StadiumNpcPublicContacts.matches(value.property) \
		or not value.get("field") is String or value.field != StadiumNpcSnapshot.FIELD \
		or not SeasonOwnership._whole(value.get("seed"), 0, 2147483647) \
		or value.seed != value.property.binding.match_seed \
		or not CurrentPhysicalStadiumEvidence.base_valid(_core(value), context):
		return false
	return StadiumPoolPartyPublicContacts.evidence_ai22(
		value.get("surfaces"), value.plays, value.get("yard"), value.property, value.get("pool"))


static func matches(value: Dictionary, expected: Dictionary) -> bool:
	return valid(value) and not expected.is_empty() \
		and StadiumNpcSnapshot.key(value.property) == StadiumNpcSnapshot.key(expected)


static func core(value: Dictionary) -> Dictionary:
	return _core(value) if valid(value) else {}


static func _core(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("pool")
	return StadiumNpcYardTwoReport._core(result)
