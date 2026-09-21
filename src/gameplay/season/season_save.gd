class_name SeasonSave
extends RefCounted

static var path: String = "user://season-v1.json"
static var last_error: String = ""


static func save(season: SeasonState) -> bool:
	var data: Dictionary = {
		"version": 1,
		"seed": season.season_seed,
		"picks": season.picks,
		"results": season.player_results,
		"lineup": season.teams[0]["roster"],
		"starter": season.starter_index,
		"fielder": season.fielder_index,
	}
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not save season. Your current session is still available."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "Could not replace the season save. Retry before closing."
		return false
	last_error = ""
	return true


static func restore() -> SeasonState:
	last_error = ""
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 100000:
		last_error = "Season save could not be read. It has been left untouched."
		return null
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	var season: SeasonState = _decode(json.data) if parse_error == OK else null
	if season == null:
		last_error = "Season save is invalid or incompatible. It has been left untouched."
	return season


static func _decode(value: Variant) -> SeasonState:
	if not value is Dictionary:
		return null
	var data: Dictionary = value
	if data.get("version") != 1 or not _integer(data.get("seed"), 0, 2147483647):
		return null
	if not data.get("picks") is Array or data["picks"].size() > 4:
		return null
	if not data.get("results") is Array or data["results"].size() > 12:
		return null
	var season: SeasonState = SeasonState.create(int(data["seed"]))
	for id: Variant in data["picks"]:
		if not id is String or not season.choose_player(id):
			return null
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


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= minimum
		and value <= maximum
		and float(value) == floorf(float(value))
	)
