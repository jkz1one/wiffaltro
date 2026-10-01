class_name SeasonSave
extends RefCounted

static var path: String = "user://season-v1.json"
static var last_error: String = ""


static func save(season: SeasonState) -> bool:
	var data: Dictionary = {
		"version": 4,
		"ownership": season.ownership.to_data(),
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
	if season.build != null:
		data.version = 4 + season.build.to_data().version
		data.erase("ownership")
		data["build"] = season.build.to_data()
	if season.opponents != null:
		data["opponents"] = season.opponents.to_data()
	var career: ClubCareer
	if season.career != null:
		career = season.career.fork()
		if not career.sync(season):
			last_error = "Club history does not match this season. The previous save was preserved."
			return false
		data["career"] = career.to_data()
	if _decode(data) == null:
		last_error = "Season data failed validation. The previous save was preserved."
		return false
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
	season.career = career
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
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return null
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	return _decode(json.data) if parse_error == OK else null


static func _decode(value: Variant) -> SeasonState:
	if not value is Dictionary:
		return null
	var data: Dictionary = value
	if not _integer(data.get("version"), 1, 38) or not _integer(data.get("seed"), 0, 2147483647):
		return null
	# Unknown ownership/storage fields require an explicit migration, never deletion.
	var allowed: Array[String] = [
		"version",
		"seed",
		"picks",
		"results",
		"lineup",
		"starter",
		"fielder",
		"pool",
		"difficulty",
		"draws",
		"strengths",
		"ownership",
		"build",
		"opponents",
		"career"
	]
	if data.has("opponents") and (data.version < 23 or not data.opponents is Dictionary):
		return null
	if data.has("career") and data.version < 4:
		return null
	for key: Variant in data:
		if not key is String or not allowed.has(key):
			return null
	if data["version"] < 4 and data.has("ownership"):
		return null
	if (data.version < 5 and data.has("build")) or (data.version >= 5 and data.has("ownership")):
		return null
	if not data.get("picks") is Array or data["picks"].size() > 4:
		return null
	if not data.get("results") is Array or data["results"].size() > 12:
		return null
	var season: SeasonState = SeasonState.create(
		int(data["seed"]), data["version"] == 1, data["version"] >= 5, data.has("opponents")
	)
	if data["version"] >= 2:
		if not _restore_pool(season, data):
			return null
	for id: Variant in data["picks"]:
		if not id is String or not season.choose_player(id):
			return null
	if data["version"] >= 2:
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
	var restored: SeasonBuild
	if data.version >= 5:
		if not data.get("build") is Dictionary or data.build.get("version") != data.version - 4:
			return null
		var roster: Array[String] = []
		if season.picks.size() == 4:
			roster.assign(season.picks)
		restored = SeasonBuild.from_data(
			data.build, season.season_seed, roster, season.draft_pool, season.recruit_blocked()
		)
		if restored == null or restored._market != 0:
			return null
	for result: Variant in data["results"]:
		if not result is Dictionary:
			return null
		for key in ["id", "away_runs", "home_runs"]:
			if not _integer(result.get(key), 0, 9999):
				return null
		var performance: Variant = result.get("performance", {}) if data["version"] >= 3 else {}
		if not performance is Dictionary or (result.has("performance") and performance.is_empty()):
			return null
		if restored != null:
			var actual_roster: Array = restored.roster_for_game(int(result.id))
			if actual_roster.size() != 4:
				return null
			season.teams[0].roster = actual_roster
		if not season.record_player_result(
			int(result["id"]), int(result["away_runs"]), int(result["home_runs"]), performance
		):
			return null
		if result.has("used_gear"):
			if data.version < 14 or not result.used_gear is Array:
				return null
			season.player_results[-1]["used_gear"] = result.used_gear.duplicate()
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["used_gear"] = result.used_gear.duplicate()
		if result.has("tactics"):
			if data.version < 18 or not result.tactics is Array:
				return null
			season.player_results[-1]["tactics"] = result.tactics.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["tactics"] = result.tactics.duplicate(true)
		if result.has("batting"):
			if data.version < 33 or not result.batting is Dictionary:
				return null
			season.player_results[-1]["batting"] = result.batting.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["batting"] = result.batting.duplicate(true)
		if result.has("stances"):
			if data.version < 34 or not result.stances is Array:
				return null
			if not SeasonLeftRight.own_halves(result.stances, season.player_results[-1].home == 0):
				return null
			season.player_results[-1]["stances"] = result.stances.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["stances"] = result.stances.duplicate(true)
		if result.has("fielding"):
			if data.version < 35 or not result.fielding is Array:
				return null
			if not SeasonLeftRight.own_halves(result.fielding, season.player_results[-1].home != 0):
				return null
			season.player_results[-1]["fielding"] = result.fielding.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["fielding"] = result.fielding.duplicate(true)
		if result.has("pitching"):
			if data.version < 37 or not result.pitching is Dictionary:
				return null
			if not SeasonSureShot.own_halves(result.pitching, season.player_results[-1].home != 0):
				return null
			season.player_results[-1]["pitching"] = result.pitching.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["pitching"] = result.pitching.duplicate(true)
		if result.has("field_supply"):
			if data.version < 38 or not result.field_supply is Dictionary:
				return null
			season.player_results[-1]["field_supply"] = result.field_supply.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["field_supply"] = result.field_supply.duplicate(true)
	var lineup: Variant = data.get("lineup")
	if not lineup is Array:
		return null
	if season.picks.size() == 4:
		if lineup.size() != 4:
			return null
		var unique: Array = []
		var active: Array = season.picks if restored == null else restored.roster()
		for id: Variant in lineup:
			if not id is String or not active.has(id) or unique.has(id):
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
	if data["version"] == 4:
		var owned: SeasonOwnership = SeasonOwnership.from_data(data.get("ownership"))
		# Production currently has result income only. Require the exact derived journal;
		# fixture items or invented rewards cannot enter a real season save.
		if owned == null or owned.to_data() != season.ownership.to_data():
			return null
		season.ownership = owned
	if restored != null:
		if not _build_history_valid(season, restored):
			return null
		restored.migrate()
		season.build = restored
	if data.has("opponents"):
		var expected: Variant = JSON.parse_string(JSON.stringify(season.opponents.to_data()))
		if JSON.parse_string(JSON.stringify(data.opponents)) != expected:
			return null
	if data.has("career"):
		season.career = ClubCareer.from_data(data.career)
		if season.career == null or not season.career.matches(season):
			return null
	elif (
		season.build != null
		and (
			season.build._gear_progress.enabled
			or season.build._sponsor_progress.enabled
			or season.build._order_start != null
			or season.build._rain_start != null
			or season.build._transfer_start != null
			or season.build._supply_start != null
			or season.build._checkout_start != null
			or season.build._association_start != null
			or season.build._freezer_start != null
			or season.build._sides_start != null
			or season.build._field_start != null
			or season.build._sure_start != null
			or season.build._jump_start != null
			or season.build._batch_start != null
		)
	):
		return null
	return season


static func _build_history_valid(season: SeasonState, build: SeasonBuild) -> bool:
	var cursor: int = 0
	for event: Dictionary in build.to_data().events:
		if event.op in ["pregame", "scout", "insure", "match_inventory", "match_sell"]:
			var expected: int = (
				int(season.player_results[cursor].id)
				if cursor < season.player_results.size()
				else int(season.pending_fixture().get("id", -1))
			)
			if event.game != expected:
				return false
			if event.op == "scout":
				var fixture: Dictionary = (
					season.player_results[cursor]
					if cursor < season.player_results.size()
					else season.pending_fixture()
				)
				if not SeasonFilmRoom.choices(season, fixture).has(event.recipe):
					return false
		elif event.op == "reward":
			if cursor >= season.player_results.size():
				return false
			var result: Dictionary = season.player_results[cursor]
			if event.game != result.id or event.win != (SeasonState._winner(result) == 0):
				return false
			if event.get("used_gear", []) != result.get("used_gear", []):
				return false
			if event.get("tactics", []) != result.get("tactics", []):
				return false
			if event.get("batting", {}) != result.get("batting", {}):
				return false
			if event.get("stances", []) != result.get("stances", []):
				return false
			if event.get("field_supply", {}) != result.get("field_supply", {}):
				return false
			if event.get("pitching", {}) != result.get("pitching", {}):
				return false
			if event.get("fielding", []) != result.get("fielding", []):
				return false
			if event.has("performance"):
				var saved: Variant = JSON.parse_string(JSON.stringify(event.performance))
				var actual: Variant = JSON.parse_string(
					JSON.stringify(result.get("performance", {}))
				)
				if saved != actual:
					return false
			cursor += 1
		elif cursor == season.player_results.size() and season.phase == SeasonState.Phase.COMPLETE:
			# Final income is retained, but creates no new purchasing window.
			return false
	return cursor == season.player_results.size()


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
