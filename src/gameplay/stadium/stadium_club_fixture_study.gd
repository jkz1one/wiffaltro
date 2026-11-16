class_name StadiumClubFixtureStudy
extends RefCounted
## Bounded authoring-only envelope. Its checksum detects edits, not authority or venue eligibility.

const KIND: String = "UNQUALIFIED_CLUB_AUTHORING_FIXTURE"
const MAX_BYTES: int = 131072
const RECORD_KEYS: Array[String] = ["version", "id", "status", "property", "source", "live_units",
	"items", "boundary", "catalog", "models", "environment_certificates", "blueprint_value",
	"copy_value", "land_value", "endowment_value"]


static func capture(record: Dictionary) -> Dictionary:
	if not _record(record):
		return {}
	var copy: Dictionary = _canonical(record)
	return {"kind": KIND, "version": 1, "venue": copy,
		"sha256": StadiumClubVenueStudy.encode(copy).sha256_text()}


static func valid(value: Variant) -> bool:
	return value is Dictionary \
		and SeasonOwnership._keys(value, ["kind", "version", "venue", "sha256"]) \
		and value.kind is String and value.kind == KIND and SeasonOwnership._whole(value.version, 1, 1) \
		and _record(value.venue) and value.sha256 is String \
		and value.sha256 == StadiumClubVenueStudy.encode(_canonical(value.venue)).sha256_text()


static func encode(value: Dictionary) -> String:
	return JSON.stringify(value, "", true, true) if valid(value) else ""


static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not valid(parser.data):
		return {}
	return capture(parser.data.venue)


static func save(path: String, value: Dictionary) -> bool:
	var text: String = encode(value)
	if text.is_empty() or not path.begins_with("user://") or path.contains("..") \
		or not path.ends_with(".json"):
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


static func _record(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, RECORD_KEYS):
		return false
	if not SeasonOwnership._whole(value.version, 1, 1) \
		or not value.id is String or not value.status is String \
		or not value.property is String or not value.source is String or value.id != "AC-01" \
		or value.status != "CANDIDATE" or value.property != "club" \
		or value.source != "npc-authored-candidate" \
		or not SeasonOwnership._whole(value.live_units, 0, 0) \
		or not value.environment_certificates is Array or not value.environment_certificates.is_empty():
		return false
	if not value.items is Array or value.items.size() != 68 \
		or not value.boundary is String or value.boundary.length() != 64 \
		or not value.catalog is String or value.catalog.length() != 64 \
		or not value.models is Dictionary \
		or not SeasonOwnership._keys(value.models, ["net", "pole", "dugout", "lower"]):
		return false
	for version: Variant in value.models.values():
		if not SeasonOwnership._whole(version, 1, 100):
			return false
	for key: String in ["blueprint_value", "copy_value", "land_value", "endowment_value"]:
		if not SeasonOwnership._whole(value[key], 0, 1000000):
			return false
	return value.endowment_value == value.blueprint_value + value.copy_value + value.land_value \
		and _items(value.items)


static func _items(items: Array) -> bool:
	var copies: Array[String] = []
	var sites: Array[String] = []
	var counts: Dictionary = {}
	for row: Variant in items:
		if not row is Dictionary \
			or not SeasonOwnership._keys(row, ["instance", "item", "site", "transform"]):
			return false
		if not row.instance is String or not row.instance.begins_with("npc-candidate:AC-01:") \
			or row.instance.length() > 128 or copies.has(row.instance) or not row.site is String \
			or row.site.is_empty() or row.site.length() > 128 or sites.has(row.site) \
			or not row.item is String or not StadiumClubVenueStudy.COUNTS.has(row.item) \
			or not row.transform is Array or row.transform.size() != 12:
			return false
		for component: Variant in row.transform:
			if not PhysicalMatchReport.number(component, -1000, 1000):
				return false
		copies.append(row.instance)
		sites.append(row.site)
		counts[row.item] = counts.get(row.item, 0) + 1
	return ClubCareer.same(counts, StadiumClubVenueStudy.COUNTS)


static func load_file(path: String) -> Dictionary:
	if not path.begins_with("user://") or path.contains("..") or not path.ends_with(".json"):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	return decode(file.get_as_text())


static func _canonical(record: Dictionary) -> Dictionary:
	# JSON changes integer types and may shift float64 parsing by an ulp. The scene uses float32.
	var result: Dictionary = record.duplicate(true)
	for key: String in ["version", "live_units", "blueprint_value", "copy_value", "land_value",
		"endowment_value"]:
		result[key] = int(result[key])
	for key: String in result.models:
		result.models[key] = int(result.models[key])
	for row: Dictionary in result.items:
		row.transform = Array(PackedFloat32Array(row.transform))
		for index in range(row.transform.size()):
			if row.transform[index] == 0:
				row.transform[index] = 0.0
	return result
