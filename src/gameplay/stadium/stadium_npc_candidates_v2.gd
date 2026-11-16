class_name StadiumNpcCandidatesV2
extends RefCounted
## Isolated candidate lookup only. Not StadiumNpcVenues or production authority.


static func definition(id: String, revision: int = 2) -> Dictionary:
	if revision != 2:
		return {}
	var literal: Dictionary = {}
	match id:
		"AY-01":
			literal = StadiumNpcYardCandidateV2.payload()
		"AE-01":
			literal = StadiumNpcExpandedCandidateV2.payload()
		"AC-01":
			literal = StadiumNpcClubCandidateV2.payload()
	return StadiumNpcManifest.canonical_shape(literal)


static func normalized(value: Variant) -> Dictionary:
	var canonical: Dictionary = StadiumNpcManifest.canonical_shape(value)
	if canonical.is_empty():
		return {}
	return StadiumNpcVenues._normalized_against(
		canonical, definition(canonical.id, int(canonical.revision))
	)


static func valid_manifest(value: Variant) -> bool:
	return not normalized(value).is_empty()


static func key(value: Variant) -> String:
	var canonical: Dictionary = normalized(value)
	return "" if canonical.is_empty() else JSON.stringify(canonical, "", true, true).sha256_text()


static func payload_key(value: Variant) -> String:
	# Distinct pre-certificate hash domain: certificates are removed, not recursively signed.
	var canonical: Dictionary = normalized(value)
	if canonical.is_empty():
		return ""
	canonical.erase("environment_certificates")
	return JSON.stringify(canonical, "", true, true).sha256_text()


static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > StadiumNpcManifest.MAX_BYTES:
		return {}
	var parser: JSON = JSON.new()
	return normalized(parser.data) if parser.parse(text) == OK else {}
