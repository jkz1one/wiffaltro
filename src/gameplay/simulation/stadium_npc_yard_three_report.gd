class_name StadiumNpcYardThreeReport
extends RefCounted
## Exact AY03 envelope over the existing baseball report and shared Yard envelope removal.

const VERSION: int = 16
const RESOLVER: String = "physical-ai-ay03-away-v1"


static func capture(lab: PitchBatLab) -> Dictionary:
	if lab == null or lab._match_state == null or lab._automation == null \
		or lab._match_state.phase != MatchState.Phase.GAME_END \
		or not StadiumNpcYardThreeRuntimeV1.installed_bound(lab, lab._match_state.stadium):
		return {}
	var result: Dictionary = PhysicalMatchReport._capture_core(lab)
	result.field = String(PitchBatLab.FIELD_ID)
	if result.get("version") != PhysicalMatchReport.BASE_VERSION \
		or not PhysicalMatchReport.valid(result):
		return {}
	result.field = StadiumNpcSnapshot.FIELD
	result.version = VERSION
	result.resolver = RESOLVER
	result["property"] = StadiumNpcSnapshot.normalized(lab._match_state.stadium)
	result["surfaces"] = PhysicalStadiumContacts.capture(lab._play_records)
	result["yard"] = StadiumNpcYardThreeRuntimeV1._property(lab).provenance.duplicate(true)
	return result if valid(result) else {}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != VERSION \
		or value.get("resolver") != RESOLVER or not StadiumNpcSnapshot.valid(value.get("property")) \
		or not StadiumNpcYardThreeContacts.matches(value.property) \
		or value.property.version != StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION \
		or value.get("field") != StadiumNpcSnapshot.FIELD \
		or value.get("seed") != value.property.binding.match_seed \
		or not PhysicalMatchReport.valid(StadiumNpcYardTwoReport._core(value)):
		return false
	return StadiumNpcYardThreeContacts.valid(value.get("surfaces"), value.plays, value.property) \
		and StadiumNpcYardThreeContacts.provenance(value.get("yard"), value.property)


static func matches(value: Dictionary, expected: Dictionary) -> bool:
	return valid(value) and not expected.is_empty() \
		and StadiumNpcSnapshot.key(value.property) == StadiumNpcSnapshot.key(expected)


static func core(value: Dictionary) -> Dictionary:
	return StadiumNpcYardTwoReport._core(value) if valid(value) else {}
