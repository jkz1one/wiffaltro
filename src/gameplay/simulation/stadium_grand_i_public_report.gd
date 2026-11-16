class_name StadiumGrandIPublicReport
extends RefCounted
## Exact neutral-final qualification envelope; report7 remains the baseball authority.
## Binding names the neutral venue owner separately from the higher-seed batting home.
## This envelope does not release the Standard day0–1 pairing or public selection.

const VERSION: int = 19
const RESOLVER: String = "physical-ai-neutral-final-grand-i-v1"


static func supports_definition(id: String, revision: int) -> bool:
	return id == "GRAND-I" and revision == 1


static func capture(lab: PitchBatLab) -> Dictionary:
	return _capture_context(lab, {})


static func _capture_context(lab: PitchBatLab, context: Dictionary) -> Dictionary:
	if lab == null or lab._match_state == null or lab._automation == null \
		or lab._match_state.phase != MatchState.Phase.GAME_END \
		or lab._match_state.stadium.get("version") != StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION \
		or not StadiumNpcPublicRuntime.installed_bound(lab, lab._match_state.stadium):
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
	return result if _valid_context(result, context) else {}


static func valid(value: Variant) -> bool:
	return _valid_context(value, {})


static func _valid_context(value: Variant, context: Dictionary) -> bool:
	if not value is Dictionary or not SeasonOwnership._whole(value.get("version"), VERSION, VERSION) \
		or value.get("resolver") != RESOLVER or not StadiumNpcSnapshot.valid(value.get("property")) \
		or value.property.version != StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION \
		or not supports_definition(value.property.manifest.id, value.property.manifest.revision) \
		or not StadiumNpcPublicContacts.matches(value.property) \
		or value.get("field") != StadiumNpcSnapshot.FIELD \
		or value.get("seed") != value.property.binding.match_seed \
		or not CurrentPhysicalStadiumEvidence.base_valid(StadiumNpcYardTwoReport._core(value), context):
		return false
	return StadiumNpcPublicContacts.evidence(
		value.get("surfaces"), value.plays, value.get("yard"), value.property)


static func matches(value: Dictionary, expected: Dictionary) -> bool:
	return valid(value) and not expected.is_empty() \
		and StadiumNpcSnapshot.key(value.property) == StadiumNpcSnapshot.key(expected)


static func core(value: Dictionary) -> Dictionary:
	return StadiumNpcYardTwoReport._core(value) if valid(value) else {}
