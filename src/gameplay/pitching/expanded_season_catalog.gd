class_name ExpandedSeasonCatalog
extends RefCounted
## Persisted standalone-season identity. Never a preview context or v5 migration.
const VERSION: int = 6
const PURPOSE: String = "standalone_season"
const Provider = preload("res://src/gameplay/pitching/working_pitch_catalog_v6.gd")
const RESERVED_EXOTICS: Dictionary = WorkingPitchCatalog.RESERVED_EXOTICS

static func recipes() -> Array[PitchDefinition]:
	return Provider.recipes()

static func ids() -> Array[String]:
	return Provider.ids()

static func known_ids() -> Array[String]:
	return Provider.known_ids()

static func get_recipe(id: String) -> PitchDefinition:
	return Provider.get_recipe(id)

static func supports(id: String) -> bool:
	return get_recipe(id) != null

static func is_active(id: String) -> bool:
	return ids().has(id)

static func lesson_price(id: String) -> int:
	return Provider.lesson_price(id)

static func mastered(id: String, level: int) -> PitchDefinition:
	return Provider.mastered(id, level)

static func signature() -> String:
	var source: String = Provider.signature()
	if source.is_empty():
		return ""
	var parts: Array[String] = ["expanded-standalone-season-v6", source]
	for path: String in [
		"res://src/gameplay/pitching/expanded_season_catalog.gd",
		"res://src/gameplay/pitching/expanded_called_proof.gd",
		"res://src/gameplay/pitching/expanded_exotic_eligibility.gd",
		"res://src/gameplay/season/expanded_exotic_access.gd",
		"res://src/gameplay/season/expanded_season_progression.gd"]:
		var digest: String = FileAccess.get_sha256(path)
		if digest.is_empty():
			return ""
		parts.append(digest)
	return "|".join(parts).sha256_text()

static func descriptor() -> Dictionary:
	var digest: String = signature()
	return {} if digest.is_empty() else {"version": VERSION, "signature": digest, "purpose": PURPOSE}

static func valid_descriptor(value: Variant) -> bool:
	return value is Dictionary and SeasonOwnership._keys(value, ["version", "signature", "purpose"]) \
		and SeasonOwnership._whole(value.version, VERSION, VERSION) \
		and value.signature is String and not value.signature.is_empty() \
		and value.signature == signature() and value.purpose is String and value.purpose == PURPOSE
