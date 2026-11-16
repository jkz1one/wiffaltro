class_name WorkingPitchCareerProgress
extends RefCounted
## Career33 and Progress5 bind current recipes and earned Exotic evidence.

const CAREER_VERSION: int = 33  # 28–31 are already used by historical owner authority.
const PROGRESS_VERSION: int = 5


static func admit(season: SeasonState, career: ClubCareer) -> bool:
	if season == null or career == null or season.build == null or career.current != 0 \
		or (not career.runs.is_empty() and career._pitch_catalog.is_empty()) \
		or (not career._pitch_catalog.is_empty() and career._pitch_catalog != WorkingPitchCatalog.signature()) \
		or not season._dynasty_owner_binding.is_empty() or not season._dynasty_career_session.is_empty():
		return false
	if not season.build.enable_pitch_catalog():
		return false
	career._pitch_catalog = WorkingPitchCatalog.signature()
	return true


static func is_current(value: Variant) -> bool:
	return value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), PROGRESS_VERSION)


static func capture(season: SeasonState) -> Dictionary:
	if season == null or season.build == null or not season.build.pitch_catalog_current():
		return {}
	var result: Dictionary = ClubPlayerLegend.capture(season, true)
	if result.is_empty():
		return {}
	result.version = PROGRESS_VERSION
	result["pitch_catalog"] = WorkingPitchCatalog.signature()
	result["exotic"] = WorkingExoticEligibility.capture(season)
	return result if valid(result, ClubSeasonRecord.capture(season).scores) else {}


static func valid(value: Variant, scores: Array) -> bool:
	if not is_current(value) \
		or not SeasonOwnership._keys(value, ["version", "games", "development", "pitch_catalog", "exotic"]) \
		or not value.pitch_catalog is String or value.pitch_catalog != WorkingPitchCatalog.signature():
		return false
	if not value.games is Array or not WorkingExoticEligibility.valid(value.exotic) or value.exotic.games.size() != value.games.size():
		return false
	for index in range(value.games.size()):
		if not value.games[index] is Dictionary or value.games[index].get("game") != value.exotic.games[index].game:
			return false
		var players: Variant = value.games[index].get("players")
		if not players is Dictionary or players.size() != 4:
			return false
		for id: String in value.exotic.games[index].roster:
			if not players.get(id) is Dictionary:
				return false
			var count: int = 0
			for strikeout: Dictionary in value.exotic.games[index].strikeouts:
				count += 1 if strikeout.pitcher == id else 0
			if players[id].get("strikeouts") != count:
				return false
	var legacy: Dictionary = value.duplicate(true)
	legacy.erase("exotic")
	legacy.erase("pitch_catalog")
	legacy.version = ClubPlayerLegend.VERSION
	return valid_capture(legacy, scores)


static func valid_capture(value: Dictionary, scores: Array) -> bool:
	# Only shared aggregate/game validation is projected. Every full current lesson
	# is separately checked below; no serialized historical record uses this path.
	var development: Variant = value.get("development")
	if not development is Dictionary \
		or not SeasonOwnership._keys(development, ["mastery", "known", "lessons"]) \
		or not SeasonOwnership._whole(development.mastery, 0, 5) \
		or not SeasonOwnership._whole(development.known, 0, 8) \
		or not development.lessons is Array \
		or development.lessons.size() > WorkingPitchCatalog.known_ids().size():
		return false
	var previous: String = ""
	var historical: Array = []
	for id: Variant in development.lessons:
		if not id is String or id <= previous or not WorkingPitchCatalog.supports(id):
			return false
		previous = id
		if SeasonPlayerCatalog.RECIPES.values().has(id):
			historical.append(id)
	var legacy: Dictionary = value.duplicate(true)
	legacy.development.lessons = historical
	return ClubPlayerProgress.valid(legacy, scores)


static func wrap_career(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result["base_version"] = data.version
	result.version = CAREER_VERSION
	result["pitch_catalog"] = WorkingPitchCatalog.signature()
	return result


static func restore_career(value: Dictionary) -> ClubCareer:
	if not WorkingPitchProgression.is_version(value.get("version"), CAREER_VERSION) \
		or not SeasonOwnership._whole(value.get("base_version"), 22, 27) \
		or not value.get("pitch_catalog") is String or value.pitch_catalog != WorkingPitchCatalog.signature():
		return null
	var legacy: Dictionary = value.duplicate(true)
	legacy.version = int(legacy.base_version)
	legacy.erase("base_version")
	legacy.erase("pitch_catalog")
	return ClubCareer._decode_history(legacy, false, true)
