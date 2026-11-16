class_name StadiumNpcVenues
extends RefCounted
## Immutable NPC definition authority, separate from paid human ownership.
## Explicit immutable definitions; installed daylight authority is checked separately.


static func definition(id: String, revision: int) -> Dictionary:
	var value: Dictionary = _definition_from(_definitions(), id, revision)
	if revision == 2 and not StadiumNpcDaylightEvidenceV2.matches(value):
		return {}
	if id == "AY-02" and JSON.stringify(value, "", true, true).sha256_text() \
		!= StadiumNpcYardTwoCandidateV1.SHA256:
		return {}
	if id == "AY-03" and JSON.stringify(value, "", true, true).sha256_text() \
		!= StadiumNpcYardThreeCandidateV1.SHA256:
		return {}
	if id == "AM-01" and JSON.stringify(value, "", true, true).sha256_text() \
		!= StadiumNpcMogulOneCandidateV1.SHA256:
		return {}
	if id == "AM-02" and JSON.stringify(value, "", true, true).sha256_text() \
		!= StadiumNpcMogulTwoCandidateV1.SHA256:
		return {}
	if id == "AE-02" and JSON.stringify(value, "", true, true).sha256_text() \
		!= StadiumNpcExpandedTwoDefinitionV1.SHA256:
		return {}
	if id == "AC-02" and JSON.stringify(value, "", true, true).sha256_text() \
		!= StadiumNpcClubTwoDefinitionV1.SHA256:
		return {}
	return value


static func valid_manifest(value: Variant) -> bool:
	return not normalized(value).is_empty()


static func normalized(value: Variant) -> Dictionary:
	var canonical: Dictionary = StadiumNpcManifest.canonical_shape(value)
	if canonical.is_empty():
		return {}
	var expected: Dictionary = definition(canonical.id, int(canonical.revision))
	# No status flag, checksum, well-formed candidate or player inventory grants authority.
	return _normalized_against(canonical, expected)


static func key(value: Variant) -> String:
	var canonical: Dictionary = normalized(value)
	return "" if canonical.is_empty() else JSON.stringify(canonical, "", true, true).sha256_text()


static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > StadiumNpcManifest.MAX_BYTES:
		return {}
	var parser: JSON = JSON.new()
	return normalized(parser.data) if parser.parse(text) == OK else {}


static func _definitions() -> Dictionary:
	# Retain every historical literal. Candidates add exact immutable data only;
	# this explicit registry branch grants membership, never a candidate status flag.
	return {"AY-01": {"1": StadiumNpcYardDefinitionV1.payload(),
			"2": StadiumNpcYardDefinitionV2.payload()},
		"AE-01": {"1": StadiumNpcExpandedDefinitionV1.payload(),
			"2": StadiumNpcExpandedDefinitionV2.payload()},
		"AC-01": {"1": StadiumNpcClubDefinitionV1.payload(),
			"2": StadiumNpcClubDefinitionV2.payload()},
		"AY-02": {"1": StadiumNpcYardTwoCandidateV1.payload()},
		"AY-03": {"1": StadiumNpcYardThreeCandidateV1.payload()},
		"AM-01": {"1": StadiumNpcMogulOneCandidateV1.payload()},
		"AM-02": {"1": StadiumNpcMogulTwoCandidateV1.payload()},
		"AE-02": {"1": StadiumNpcExpandedTwoDefinitionV1.payload()},
		"AC-02": {"1": StadiumNpcClubTwoDefinitionV1.payload()}}


static func _definition_from(records: Dictionary, id: String, revision: int) -> Dictionary:
	# Pure lookup seam, not authority injection: production always supplies _definitions().
	# Tests can prove copy/revision isolation without inventing a publishable venue.
	if revision < 1 or not records.get(id) is Dictionary:
		return {}
	var value: Variant = records[id].get(str(revision))
	var canonical: Dictionary = StadiumNpcManifest.canonical_shape(value)
	if canonical.is_empty() or canonical.id != id or canonical.revision != revision:
		return {}
	return canonical


static func _normalized_against(value: Variant, expected: Variant) -> Dictionary:
	# Equality seam is testable with inert schema probes; it never publishes its inputs.
	var canonical: Dictionary = StadiumNpcManifest.canonical_shape(value)
	var reference: Dictionary = StadiumNpcManifest.canonical_shape(expected)
	if canonical.is_empty() or reference.is_empty():
		return {}
	return canonical if JSON.stringify(canonical, "", true, true) == JSON.stringify(
		reference, "", true, true) else {}
