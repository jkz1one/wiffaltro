class_name StadiumYardFixtureStudy
extends RefCounted
## Exact installed-source candidate identity. Checksum is never production venue authority.

const KIND: String = "UNQUALIFIED_YARD_AUTHORING_FIXTURE"
const MAX_BYTES: int = 32768


static func capture(record: Variant) -> Dictionary:
	var canonical: Dictionary = StadiumYardVenueStudy.canonical()
	if not record is Dictionary or not ClubCareer.same(record, canonical):
		return {}
	return {"kind": KIND, "version": 1, "venue": canonical,
		"sha256": JSON.stringify(canonical, "", true, true).sha256_text()}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(
		value, ["kind", "version", "venue", "sha256"]) or value.get("kind") != KIND \
		or not SeasonOwnership._whole(value.get("version"), 1, 1):
		return false
	var expected: Dictionary = capture(value.get("venue"))
	return not expected.is_empty() and value.get("sha256") == expected.sha256


static func encode(value: Variant) -> String:
	return JSON.stringify(capture(value.venue), "", true, true) if valid(value) else ""


static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not valid(parser.data):
		return {}
	return capture(parser.data.venue)
