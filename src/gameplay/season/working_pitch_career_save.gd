class_name WorkingPitchCareerSave
extends RefCounted
## Save98: explicit current-catalog ordinary Standard career authority.
## Owned Dynasty and alternate League wrappers are not admitted by this schema.

const VERSION: int = 98
const WORKER_VERSION: int = 8


static func leaf_valid(data: Variant, catalog: String) -> bool:
	return data is Dictionary and catalog == WorkingPitchCatalog.signature() \
		and SeasonOwnership._whole(data.get("version"), 57, 71) \
		and data.get("career") is Dictionary \
		and WorkingPitchProgression.is_version(data.career.get("version"), WorkingPitchCareerProgress.CAREER_VERSION) \
		and data.career.get("pitch_catalog") is String and data.career.pitch_catalog == catalog \
		and ordinary_base_valid(data.career) \
		and data.get("build") is Dictionary \
		and not WorkingPitchProgression.unwrap_build(data.build).is_empty()


static func ordinary_base_valid(career: Dictionary) -> bool:
	if SeasonOwnership._whole(career.get("base_version"), 22, 26):
		return true
	# A current mixed career may return to Standard without losing its earlier
	# alternate history. The active run alone must be Standard; full career and
	# Standard-only season authority still pass the ordinary98 replay below.
	if not WorkingPitchProgression.is_version(career.get("base_version"), 27) \
		or not career.get("runs") is Array or career.runs.is_empty() \
		or not SeasonOwnership._whole(career.get("current"), career.runs.size(), career.runs.size()):
		return false
	var active: Variant = career.runs[-1]
	return active is Dictionary and active.get("league") == "standard" \
		and not active.has("league_rules")


static func parts(value: Variant) -> Dictionary:
	if not value is Dictionary \
		or not SeasonOwnership._keys(value, ["version", "pitch_catalog", "checkpoint"]) \
		or not WorkingPitchProgression.is_version(value.version, VERSION) \
		or not value.pitch_catalog is String or value.pitch_catalog != WorkingPitchCatalog.signature() \
		or not value.checkpoint is Dictionary:
		return {}
	var data: Dictionary = value.checkpoint.duplicate(true)
	var terrain: bool = WorkingPitchProgression.is_version(data.get("version"), 74)
	if terrain:
		if not SeasonOwnership._whole(data.get("terrain_save_version"), 57, 73) \
			or not SeasonSave._contains_terrain(data):
			return {}
		data.version = int(data.terrain_save_version)
		data.erase("terrain_save_version")
	var policy: Dictionary = {}
	if SeasonSave.OwnedDraftSave.version_in(data.get("version"), [72, 73]):
		var expected: int = StadiumSurfaceNightSnapshot.VERSION if data.version == 72 \
			else StadiumSurfaceNightSnapshot.TIME_VERSION
		if not SeasonOwnership._whole(data.get("legacy_save_version"), 59, 71) \
			or not data.get("owned_surface_night") is Dictionary \
			or not WorkingPitchProgression.is_version(data.owned_surface_night.get("version"), expected) \
			or not StadiumSurfaceNightSnapshot.policy_shape(data.owned_surface_night) \
			or StadiumLayoutSnapshot.is_terrain(data.get("home_property")) or data.has("ownership"):
			return {}
		policy = data.owned_surface_night.duplicate(true)
		data.version = int(data.legacy_save_version)
		data.erase("legacy_save_version")
		data.erase("owned_surface_night")
	if not leaf_valid(data, value.pitch_catalog):
		return {}
	return {"data": data, "policy": policy, "terrain": terrain}


static func capture(season: SeasonState) -> Dictionary:
	if season == null or season.career == null or season.build == null \
		or not season.build.pitch_catalog_current() \
		or season.career._pitch_catalog != WorkingPitchCatalog.signature() \
		or not season.league_rules.is_empty() or season.league_career \
		or not season._dynasty_owner_binding.is_empty() or not season._dynasty_career_session.is_empty() \
		or not season._standard_live_context.is_empty() or not season._league_home_context.is_empty() \
		or not season._closed_access.is_empty() or not season._dynasty_start.is_empty():
		return {}
	var checkpoint: Dictionary = SeasonSave._ac02_passive_15_snapshot(season)
	var result: Dictionary = {"version": VERSION,
		"pitch_catalog": WorkingPitchCatalog.signature(), "checkpoint": checkpoint}
	return result if not parts(result).is_empty() else {}


static func restore(value: Dictionary) -> SeasonState:
	var unpacked: Dictionary = parts(value)
	if unpacked.is_empty():
		return null
	var season: SeasonState = SeasonSave.Operations1._ac02_passive_15_private_decode_payload_terrain(
		unpacked.data, unpacked.policy, unpacked.terrain, {}, false, {}, null, {}, null,
		[], {}, {}, null, value.pitch_catalog, VERSION)
	if season == null or season.career == null or capture(season).is_empty():
		return null
	return season


static func header_projection(data: Dictionary) -> Dictionary:
	# Only price/draft header validation uses this view. Full builds and journals
	# are replayed untouched under Save98, never through a historical decoder.
	var result: Dictionary = data.duplicate(true)
	result.build = WorkingPitchProgression.unwrap_build(result.get("build", {}))
	if result.get("opponents", {}).get("clubs") is Dictionary:
		for key: String in result.opponents.clubs:
			var club: Variant = result.opponents.clubs[key]
			if not club is Dictionary or not club.get("build") is Dictionary:
				return {}
			club.build = WorkingPitchProgression.unwrap_build(club.build)
	return result


static func decode_worker(value: Dictionary, token: String) -> SeasonState:
	if not SeasonOwnership._keys(value,
		["version", "token", "request", "fixture", "season", "pitch_catalog"]) \
		or not WorkingPitchProgression.is_version(value.version, WORKER_VERSION) \
		or not value.token is String or value.token != token \
		or not value.request is String or value.request.length() != 64 \
		or not SeasonOwnership._whole(value.fixture, 0, 32) \
		or not value.pitch_catalog is String or value.pitch_catalog != WorkingPitchCatalog.signature() \
		or parts(value.season).is_empty():
		return null
	return restore(value.season)
