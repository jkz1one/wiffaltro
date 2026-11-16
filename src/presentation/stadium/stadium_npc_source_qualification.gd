class_name StadiumNpcSourceQualification
extends RefCounted

const AC02_PASSIVE_0 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Whole-source alternatives only. No fixture schema, snapshot or gameplay bypass.

const PROFILE = preload("res://src/presentation/stadium/stadium_npc_current_source_profile.gd")


static func baseline_digest(baseline: Dictionary) -> String:
	var paths: Array = baseline.keys()
	paths.sort()
	var lines: String = ""
	for path: String in paths:
		lines += path + ":" + str(baseline[path]) + "\n"
	return lines.sha256_text()


static func matches_original(baseline: Dictionary) -> bool:
	var ac02_token: int = AC02_PASSIVE_0.enter("stadium_npc_source_qualification.matches_original")
	var ac02_result: bool = _ac02_passive_00_matches_original(baseline)
	AC02_PASSIVE_0.leave(ac02_token)
	return ac02_result


static func _ac02_passive_00_matches_original(baseline: Dictionary) -> bool:
	return not baseline.is_empty() and _matches(baseline)


static func matches_current(baseline: Dictionary) -> bool:
	var ac02_token: int = AC02_PASSIVE_0.enter("stadium_npc_source_qualification.matches_current")
	var ac02_result: bool = _ac02_passive_00_matches_current(baseline)
	AC02_PASSIVE_0.leave(ac02_token)
	return ac02_result


static func _ac02_passive_00_matches_current(baseline: Dictionary) -> bool:
	if PROFILE.REVIEW_STATUS != "reviewed" or PROFILE.PROFILE_ID.is_empty() \
		or PROFILE.BASELINE_SHA256 != baseline_digest(baseline) \
		or PROFILE.REPLACEMENTS.is_empty() or PROFILE.DEPENDENCIES.is_empty():
		return false
	var expected: Dictionary = baseline.duplicate()
	for path: String in PROFILE.REPLACEMENTS:
		if not baseline.has(path) or PROFILE.REPLACEMENTS[path] == baseline[path]:
			return false
		expected[path] = PROFILE.REPLACEMENTS[path]
	for path: String in PROFILE.DEPENDENCIES:
		if baseline.has(path):
			return false
		expected[path] = PROFILE.DEPENDENCIES[path]
	return _matches(expected)


static func _matches(expected: Dictionary) -> bool:
	var ac02_token: int = AC02_PASSIVE_0.enter("stadium_npc_source_qualification._matches")
	var ac02_result: bool = _ac02_passive_00_private_matches(expected)
	AC02_PASSIVE_0.leave(ac02_token)
	return ac02_result


static func _ac02_passive_00_private_matches(expected: Dictionary) -> bool:
	for path: String in expected:
		if not path.begins_with("res://") or not expected[path] is String \
			or expected[path].length() != 64 or not FileAccess.file_exists(path) \
			or FileAccess.get_sha256(path) != expected[path]:
			return false
	return true
