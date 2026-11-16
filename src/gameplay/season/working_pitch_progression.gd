class_name WorkingPitchProgression
extends RefCounted
## Explicit fresh-season catalog boundary. Historical tables and signatures stay frozen.

const SEASON_VERSION: int = 97
const BUILD_VERSION: int = 48
const DEVELOPMENT_VERSION: int = 5
const PROFILE_VERSION: int = 3
const ACCESS_PROFILE_VERSION: int = 4


static func recipe(id: String) -> PitchDefinition:
	# Presentation/evidence identity only. Learning and ownership remain book-scoped.
	return WorkingPitchCatalog.get_recipe(id)


static func lesson(id: String) -> Dictionary:
	var pitch: PitchDefinition = recipe(id)
	var price: int = WorkingPitchCatalog.lesson_price(id)
	if price < 0 and pitch != null:
		price = WorkingExoticAccess.price(id)
	if pitch == null or pitch.delivery_profile == null or price < 0:
		return {}
	return {"name": pitch.display_name + " Lesson", "price": price, "op": "learn",
		"recipe": id, "family": "lesson"}


static func display_item(id: String) -> Dictionary:
	return lesson(id.trim_prefix("lesson.")) if id.begins_with("lesson.") \
		else DevelopmentShopCatalog.item(id)


static func signature(base: String) -> String:
	return ("pitch-progression-v1:" + base + ":" + WorkingPitchCatalog.signature()).sha256_text()


static func wrap_build(data: Dictionary, exotic_start: Array = []) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result["exotic_start"] = exotic_start.duplicate(true)
	result["base_version"] = data.version
	result.version = BUILD_VERSION
	result["pitch_catalog"] = WorkingPitchCatalog.signature()
	result.catalog = signature(data.catalog)
	return result


static func unwrap_build(value: Dictionary) -> Dictionary:
	if not WorkingExoticAccess.valid_history(value.get("exotic_start")):
		return {}
	if not is_version(value.get("version"), BUILD_VERSION) \
		or not SeasonOwnership._whole(value.get("base_version"), 41, 46) \
		or not value.get("pitch_catalog") is String \
		or value.pitch_catalog != WorkingPitchCatalog.signature():
		return {}
	var base: String = SeasonBuild._signature(int(value.base_version), value.get("league_rules"))
	if base.is_empty() or not value.get("catalog") is String or value.catalog != signature(base):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = int(value.base_version)
	result.catalog = base
	result.erase("exotic_start")
	result.erase("base_version")
	result.erase("pitch_catalog")
	return result


static func wrap_development(data: Dictionary, exotic_start: Array = [], exotic_current: Dictionary = {}) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result["exotic_current"] = exotic_current.duplicate(true)
	result["exotic_start"] = exotic_start.duplicate(true)
	result["base_version"] = data.version
	result.version = DEVELOPMENT_VERSION
	result["pitch_catalog"] = WorkingPitchCatalog.signature()
	result.catalog = signature(data.catalog)
	return result


static func unwrap_development(value: Dictionary) -> Dictionary:
	if not value.get("exotic_current") is Dictionary or (not value.exotic_current.is_empty() and not WorkingExoticEligibility.valid(value.exotic_current)):
		return {}
	if not WorkingExoticAccess.valid_history(value.get("exotic_start")):
		return {}
	if not is_version(value.get("version"), DEVELOPMENT_VERSION) \
		or not SeasonOwnership._whole(value.get("base_version"), 1, 3) \
		or not value.get("pitch_catalog") is String \
		or value.pitch_catalog != WorkingPitchCatalog.signature() \
		or not value.get("catalog") is String \
		or value.catalog != signature(SeasonPlayerCatalog.signature()):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = int(value.base_version)
	result.catalog = SeasonPlayerCatalog.signature()
	result.erase("exotic_current")
	result.erase("exotic_start")
	result.erase("base_version")
	result.erase("pitch_catalog")
	return result


static func base_build_version(value: Variant) -> int:
	if not value is Dictionary or not SeasonOwnership._whole(value.get("version"), 1, BUILD_VERSION):
		return -1
	if is_version(value.version, BUILD_VERSION):
		return int(value.base_version) if SeasonOwnership._whole(value.get("base_version"), 41, 46) else -1
	return int(value.version)


static func create_season(seed_value: int) -> SeasonState:
	# A real season: unchanged authored draft, earned rewards, ordinary paid shop.
	# Deliberately not attached to an existing owner's historical career contract.
	var season: SeasonState = SeasonState.create(seed_value, false, true, true)
	if not season.build.enable_pitch_catalog():
		return null
	season.opponents._format = 13
	season.physical = SeasonPhysicalFixtures.new()
	return season


static func neutral_pitch_property(value: Resource, name: String) -> bool:
	if not value is PitchDefinition:
		return false
	match name:
		"offering_id", "design_status": return str(value.get(name)).is_empty()
		"source_urls": return value.source_urls.is_empty()
		"movement_start": return value.movement_start == Vector2.ZERO
		"movement_end": return value.movement_end == Vector2.ONE
		"movement_initial_scale": return value.movement_initial_scale == Vector2.ONE
		"exotic_shape": return value.get(name) == &""
		"exotic_strength": return value.get(name) == 0.0
	return false


static func contains_current_build(value: Variant) -> bool:
	# Only known checkpoint nesting, never an arbitrary scan of user data.
	var cursor: Variant = value
	for _depth in range(8):
		if not cursor is Dictionary:
			return false
		if cursor.get("build") is Dictionary and is_version(cursor.build.get("version"), BUILD_VERSION):
			return true
		cursor = cursor.get("checkpoint")
	return false


static func season_envelope_valid(value: Variant) -> bool:
	return value is Dictionary \
		and SeasonOwnership._keys(value, ["version", "pitch_catalog", "checkpoint"]) \
		and SeasonOwnership._whole(value.version, SEASON_VERSION, SEASON_VERSION) \
		and value.pitch_catalog is String and value.pitch_catalog == WorkingPitchCatalog.signature() \
		and value.checkpoint is Dictionary and is_version(value.checkpoint.get("version"), 57) \
		and not value.checkpoint.has("career") \
		and value.checkpoint.get("build") is Dictionary \
		and is_version(value.checkpoint.build.get("version"), BUILD_VERSION) \
		and not unwrap_build(value.checkpoint.build).is_empty() \
		and value.checkpoint.build.exotic_start.is_empty()


static func capture_season(season: SeasonState) -> Dictionary:
	if season.career != null or not season._dynasty_owner_binding.is_empty() \
		or not season._league_home_context.is_empty() or not season._dynasty_career_session.is_empty() \
		or not season._standard_live_context.is_empty() or not season.league_rules.is_empty() \
		or not season.home_property.is_empty() or not season.player_access.is_empty():
		return {}  # Owner/career successors have not been admitted by this schema.
	if not WorkingExoticAccess.current_matches(season):
		return {}
	var payload: Dictionary = SeasonSave._ac02_passive_15_snapshot(season)
	var result: Dictionary = {"version": SEASON_VERSION,
		"pitch_catalog": WorkingPitchCatalog.signature(), "checkpoint": payload}
	return result if season_envelope_valid(result) else {}


static func restore_season(value: Dictionary) -> SeasonState:
	if not season_envelope_valid(value):
		return null
	var season: SeasonState = SeasonSave.Operations1._ac02_passive_15_private_decode_payload_terrain(
		value.checkpoint, {}, false, {}, false, {}, null, {}, null, [], {}, {}, null,
		value.pitch_catalog
	)
	if season == null or season.build == null or not season.build.pitch_catalog_current():
		return null
	return season if season_envelope_valid(capture_season(season)) and WorkingExoticAccess.current_matches(season) else null


static func decode_worker_request(value: Dictionary, token: String) -> SeasonState:
	if not SeasonOwnership._keys(value,
		["version", "token", "request", "fixture", "season", "pitch_catalog"]) \
		or not SeasonOwnership._whole(value.version, 7, 7) \
		or not value.token is String or value.token != token or not value.request is String or value.request.length() != 64 \
		or not SeasonOwnership._whole(value.fixture, 0, 32) \
		or not value.pitch_catalog is String or value.pitch_catalog != WorkingPitchCatalog.signature() \
		or not season_envelope_valid(value.season):
		return null
	return restore_season(value.season)


static func is_version(value: Variant, expected: int) -> bool:
	return SeasonOwnership._whole(value, expected, expected)
