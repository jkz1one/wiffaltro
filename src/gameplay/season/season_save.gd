class_name SeasonSave
extends RefCounted

static var path: String = "user://season-v1.json"
static var last_error: String = ""


static func save(season: SeasonState) -> bool:
	var data: Dictionary = {
		"version": 2,
		"seed": season.season_seed,
		"picks": season.picks,
		"results": season.player_results,
		"lineup": season.teams[0]["roster"],
		"starter": season.starter_index,
		"fielder": season.fielder_index,
		"pool": season.draft_pool,
		"difficulty": season.difficulty,
		"draws": season.teams.map(func(team: Dictionary) -> float: return team["draw"]),
		"strengths":
		season.teams.map(func(team: Dictionary) -> float: return team.get("strength", -1.0)),
	}
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not save season. Your current session is still available."
		return false
	file.store_string(JSON.stringify(data, "", true, true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	# Keep the last valid checkpoint; never replace it with a corrupt primary file.
	if error == OK and FileAccess.file_exists(path) and _read(path) != null:
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			last_error = "Could not back up the previous season save. Retry before closing."
			return false
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "Could not replace the season save. Retry before closing."
		return false
	last_error = ""
	return true


static func restore() -> SeasonState:
	last_error = ""
	var season: SeasonState = _read(path)
	if season == null:
		season = _read(path + ".bak")
		if season != null:
			last_error = "Recovered the previous checkpoint. The unreadable save was left untouched."
		elif FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			last_error = "Season save is invalid or incompatible. It has been left untouched."
	return season


static func _read(file_path: String) -> SeasonState:
	if not FileAccess.file_exists(file_path):
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 100000:
		return null
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	return _decode(json.data) if parse_error == OK else null


static func _decode(value: Variant) -> SeasonState:
	if not value is Dictionary:
		return null
	var data: Dictionary = value
	if not _integer(data.get("version"), 1, 2) or not _integer(data.get("seed"), 0, 2147483647):
		return null
	if not data.get("picks") is Array or data["picks"].size() > 4:
		return null
	if not data.get("results") is Array or data["results"].size() > 12:
		return null
	var season: SeasonState = SeasonState.create(int(data["seed"]), data["version"] == 1)
	if data["version"] == 2:
		if not _restore_pool(season, data):
			return null
	for id: Variant in data["picks"]:
		if not id is String or not season.choose_player(id):
			return null
	if data["version"] == 2:
		for index in range(6):
			var strength: Variant = data["strengths"][index]
			if not strength is float and not strength is int:
				return null
			if not is_finite(float(strength)) or strength < -1 or strength > 10:
				return null
			if (season.phase == SeasonState.Phase.DRAFT) != (strength == -1):
				return null
			if season.phase != SeasonState.Phase.DRAFT:
				season.teams[index]["strength"] = float(strength)
	for result: Variant in data["results"]:
		if not result is Dictionary:
			return null
		for key in ["id", "away_runs", "home_runs"]:
			if not _integer(result.get(key), 0, 9999):
				return null
		if not season.record_player_result(
			int(result["id"]), int(result["away_runs"]), int(result["home_runs"])
		):
			return null
	var lineup: Variant = data.get("lineup")
	if not lineup is Array:
		return null
	if season.picks.size() == 4:
		if lineup.size() != 4:
			return null
		var unique: Array = []
		for id: Variant in lineup:
			if not id is String or not season.picks.has(id) or unique.has(id):
				return null
			unique.append(id)
		season.teams[0]["roster"] = unique
	elif not lineup.is_empty():
		return null
	if not _integer(data.get("starter"), 0, 3) or not _integer(data.get("fielder"), 0, 3):
		return null
	season.starter_index = int(data["starter"])
	season.fielder_index = int(data["fielder"])
	if season.starter_index == season.fielder_index:
		return null
	return season


static func _restore_pool(season: SeasonState, data: Dictionary) -> bool:
	var pool: Variant = data.get("pool")
	if not pool is Array or pool.size() < 24 or pool.size() > 256:
		return false
	var ids: Array[String] = []
	for id: Variant in pool:
		if not id is String or ids.has(id) or id == String(PitchBatLab.DEBUG_PLAYER_ID):
			return false
		if not ContentDB.player_by_id.has(StringName(id)):
			return false
		ids.append(id)
	if not _integer(data.get("difficulty"), 0, 2):
		return false
	for key in ["draws", "strengths"]:
		if not data.get(key) is Array or data[key].size() != 6:
			return false
	for index in range(6):
		var draw: Variant = data["draws"][index]
		if not draw is float and not draw is int:
			return false
		if not is_finite(float(draw)) or draw < 0 or draw > 1:
			return false
		season.teams[index]["draw"] = float(draw)
	season.draft_pool = ids
	season.difficulty = int(data["difficulty"])
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= minimum
		and value <= maximum
		and float(value) == floorf(float(value))
	)
