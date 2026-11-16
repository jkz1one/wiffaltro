class_name StadiumNpcPublicReport
extends RefCounted

const AC02_PASSIVE_11 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Exact ordinary public envelope; report7 remains the baseball authority.
## AM01 and AM02 add their frozen r1 identities without changing prior r2 report identities.
## AE02 adds its exact two live cones through the same report17 and baseball authority.
## AC02 adds its frozen RightShelf r1 definition with authentic Club boundary rows.

const VERSION: int = 17
const RESOLVER: String = "physical-ai-npc-public-v1"


static func supports_definition(id: String, revision: int) -> bool:
	return (id in ["AY-01", "AE-01", "AC-01"] and revision == 2) \
		or (id in ["AM-01", "AM-02", "AE-02", "AC-02"] and revision == 1)


static func capture(lab: PitchBatLab) -> Dictionary:
	var ac02_token: int = AC02_PASSIVE_11.enter("stadium_npc_public_report.capture")
	var ac02_result: Dictionary = _ac02_passive_11_capture(lab)
	AC02_PASSIVE_11.leave(ac02_token)
	return ac02_result


static func _ac02_passive_11_capture(lab: PitchBatLab) -> Dictionary:
	return _capture_context(lab, {})


static func _capture_context(lab: PitchBatLab, context: Dictionary) -> Dictionary:
	if lab == null or lab._match_state == null or lab._automation == null \
		or lab._match_state.phase != MatchState.Phase.GAME_END \
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
	if not value is Dictionary or value.get("version") != VERSION \
		or value.get("resolver") != RESOLVER or not StadiumNpcSnapshot.valid(value.get("property")) \
		or not StadiumNpcPublicContacts.matches(value.property) \
		or value.property.version != StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION \
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
