class_name StadiumNpcYardTwoReport
extends RefCounted
## Public AY-02 fixture wrapper; report7 still owns all baseball validation.

const VERSION: int = 15
const RESOLVER: String = "physical-ai-ay02-away-v1"


static func capture(lab: PitchBatLab) -> Dictionary:
	if lab == null or lab._match_state == null or lab._automation == null \
		or lab._match_state.phase != MatchState.Phase.GAME_END \
		or not StadiumNpcYardTwoRuntimeV1.installed_bound(lab, lab._match_state.stadium):
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
	result["yard"] = StadiumNpcYardTwoRuntimeV1._property(lab).provenance.duplicate(true)
	return result if valid(result) else {}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != VERSION \
		or value.get("resolver") != RESOLVER or not StadiumNpcSnapshot.valid(value.get("property")) \
		or value.property.version != StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION \
		or value.property.manifest.id != "AY-02" or value.property.manifest.revision != 1 \
		or value.get("field") != StadiumNpcSnapshot.FIELD \
		or value.get("seed") != value.property.binding.match_seed \
		or not PhysicalMatchReport.valid(_core(value)):
		return false
	return StadiumNpcYardTwoContacts.valid(value.get("surfaces"), value.plays, value.property) \
		and StadiumNpcYardTwoContacts.provenance(value.get("yard"), value.property)


static func matches(value: Dictionary, expected: Dictionary) -> bool:
	return valid(value) and not expected.is_empty() \
		and StadiumNpcSnapshot.key(value.property) == StadiumNpcSnapshot.key(expected)


static func core(value: Dictionary) -> Dictionary:
	return _core(value) if valid(value) else {}


static func _core(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for key: String in ["property", "surfaces", "yard"]:
		result.erase(key)
	# AY-02 uses the unchanged backyard baseball rules; venue identity was checked above.
	result.field = String(PitchBatLab.FIELD_ID)
	result.version = PhysicalMatchReport.BASE_VERSION
	result.resolver = PhysicalMatchReport.BASE_RESOLVER
	return result
