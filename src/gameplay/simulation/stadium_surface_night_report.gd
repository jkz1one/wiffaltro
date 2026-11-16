class_name StadiumSurfaceNightReport
extends RefCounted
## New immutable night wrapper; unchanged report7 core and physical contacts.

const TIME_VERSION: int = 25
const TIME_RESOLVER: String = "physical-ai-owned-surface-time-v2"
const VERSION: int = 24
const RESOLVER: String = "physical-ai-owned-surface-night-v1"


static func capture(lab: PitchBatLab) -> Dictionary:
	return _capture_context(lab, {})


static func _capture_context(lab: PitchBatLab, context: Dictionary) -> Dictionary:
	if (
		is_instance_valid(lab)
		and lab._match_state != null
		and (
			lab._match_state.stadium.get("version")
			== StadiumSurfaceNightSnapshot.TIME_FIXTURE_VERSION
		)
	):
		return _capture_time(lab, context)
	if not is_instance_valid(lab) or lab._automation == null or lab._match_state == null:
		return {}
	var proof: Dictionary = StadiumSurfaceNightRuntime.capture_proof(lab)
	if proof.is_empty():
		return {}
	var result: Dictionary = CurrentPhysicalStadiumEvidence.capture_base(lab, context)
	if (
		result.get("version") != PhysicalMatchReport.BASE_VERSION
		or not CurrentPhysicalStadiumEvidence.base_valid(result, context)
	):
		return {}
	result.version = VERSION
	result.resolver = RESOLVER
	result["property"] = StadiumSurfaceNightSnapshot.normalized(lab._match_state.stadium)
	result["surfaces"] = PhysicalStadiumContacts.capture(lab._play_records)
	result["night"] = proof
	return result if _valid_context(result, context) else {}


static func valid(value: Variant) -> bool:
	return _valid_context(value, {})


static func _valid_context(value: Variant, context: Dictionary) -> bool:
	if (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), TIME_VERSION, TIME_VERSION)
	):
		return _valid_time(value, context)
	if value is Dictionary and not StadiumSurfaceNightSnapshot.is_fixed(value.get("property")):
		return false
	if (
		not value is Dictionary
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._whole(value.get("version"), VERSION, VERSION)
		or value.get("resolver") != RESOLVER
		or not value.get("property") is Dictionary
		or not StadiumSurfaceNightSnapshot.valid(value.property)
		or not StadiumSurfaceNightSnapshot.proof_valid(value.get("night"), value.property)
		or value.get("field") != String(PitchBatLab.FIELD_ID)
		or value.get("seed") != value.property.binding.match_seed
		or not value.get("plays") is Array
		or not PhysicalStadiumContacts.valid(value.get("surfaces"), value.plays, value.property)
	):
		return false
	return (
		CurrentPhysicalStadiumEvidence.base_valid(_core(value), context)
		and JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= 16 * 1024 * 1024
	)


static func core(value: Dictionary) -> Dictionary:
	if SeasonOwnership._whole(value.get("version"), TIME_VERSION, TIME_VERSION):
		return _time_core(value) if _valid_time(value) else {}
	return _core(value) if valid(value) else {}


static func _core(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for field: String in ["property", "surfaces", "night"]:
		result.erase(field)
	result.version = PhysicalMatchReport.BASE_VERSION
	result.resolver = PhysicalMatchReport.BASE_RESOLVER
	return result


static func matches(value: Dictionary, expected: Dictionary, paid: ClubAssetLedger = null) -> bool:
	if (
		not valid(value)
		or (
			StadiumSurfaceNightSnapshot.key(value.property)
			!= StadiumSurfaceNightSnapshot.key(expected)
		)
	):
		return false
	return (
		paid == null
		or (
			StadiumSurfaceNightSnapshot.matches(expected, paid)
			and ClubCareer.same(
				value.night, StadiumSurfaceNightSnapshot.proof(expected, value.night.policy, paid)
			)
		)
	)


static func _capture_time(lab: PitchBatLab, context: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(lab) or lab._automation == null or lab._match_state == null:
		return {}
	var proof: Dictionary = StadiumSurfaceNightRuntime.capture_proof(lab)
	if proof.is_empty():
		return {}
	var result: Dictionary = CurrentPhysicalStadiumEvidence.capture_base(lab, context)
	if (
		result.get("version") != PhysicalMatchReport.BASE_VERSION
		or not CurrentPhysicalStadiumEvidence.base_valid(result, context)
	):
		return {}
	result.version = TIME_VERSION
	result.resolver = TIME_RESOLVER
	result["property"] = StadiumSurfaceNightSnapshot.normalized(lab._match_state.stadium)
	result["surfaces"] = PhysicalStadiumContacts.capture(lab._play_records)
	result["night"] = proof
	result["clock"] = StadiumSurfaceNightSnapshot.clock_evidence(
		result.property,
		result.plays,
		int(result.tactics.base.final.half) + (1 if int(result.tactics.base.final.outs) == 3 else 0)
	)
	return result if _valid_context(result, context) else {}


static func _valid_time(value: Variant, context: Dictionary = {}) -> bool:
	if (
		not value is Dictionary
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._whole(value.get("version"), TIME_VERSION, TIME_VERSION)
		or value.get("resolver") != TIME_RESOLVER
		or not value.get("property") is Dictionary
		or not SeasonOwnership._whole(
			value.property.get("version"),
			StadiumSurfaceNightSnapshot.TIME_FIXTURE_VERSION,
			StadiumSurfaceNightSnapshot.TIME_FIXTURE_VERSION
		)
		or not StadiumSurfaceNightSnapshot.valid(value.property)
		or not StadiumSurfaceNightSnapshot.proof_valid(value.get("night"), value.property)
		or value.get("field") != String(PitchBatLab.FIELD_ID)
		or value.get("seed") != value.property.binding.match_seed
		or not value.get("plays") is Array
		or not PhysicalStadiumContacts.valid(value.get("surfaces"), value.plays, value.property)
	):
		return false
	return (
		CurrentPhysicalStadiumEvidence.base_valid(_time_core(value), context)
		and value.tactics.base.final.half == (int(value.inning) - 1) * 2 + (0 if value.top else 1)
		and StadiumSurfaceNightSnapshot.clock_valid(
			value.get("clock"),
			value.property,
			value.plays,
			(
				int(value.tactics.base.final.half)
				+ (1 if int(value.tactics.base.final.outs) == 3 else 0)
			)
		)
		and JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= 16 * 1024 * 1024
	)


static func _time_core(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("clock")
	return _core(result)
