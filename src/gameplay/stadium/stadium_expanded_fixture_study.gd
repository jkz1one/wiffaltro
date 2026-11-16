class_name StadiumExpandedFixtureStudy
extends RefCounted
## Exact installed-source candidate identity. Checksum is never production venue authority.

const KIND: String = "UNQUALIFIED_EXPANDED_AUTHORING_FIXTURE"
const MAX_BYTES: int = 65536


static func capture(record: Variant) -> Dictionary:
	var canonical: Dictionary = StadiumExpandedVenueStudy.canonical()
	if not record is Dictionary or not ClubCareer.same(record, canonical):
		return {}
	return {
		"kind": KIND,
		"version": 1,
		"venue": canonical,
		"sha256": JSON.stringify(canonical, "", true, true).sha256_text()
	}


static func valid(value: Variant) -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["kind", "version", "venue", "sha256"])
		or value.get("kind") != KIND
		or not SeasonOwnership._whole(value.get("version"), 1, 1)
	):
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


static func save(path: String, value: Dictionary) -> bool:
	var text: String = encode(value)
	if (
		text.is_empty()
		or not path.begins_with("user://")
		or path.contains("..")
		or not path.ends_with(".json")
	):
		return false
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	if not valid(decode(FileAccess.get_file_as_string(temporary))):
		DirAccess.remove_absolute(temporary)
		return false
	return DirAccess.rename_absolute(temporary, path) == OK


static func load_file(path: String) -> Dictionary:
	if not path.begins_with("user://") or path.contains("..") or not path.ends_with(".json"):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	return decode(file.get_as_text())
