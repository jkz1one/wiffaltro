class_name ClubPlayerLegend
extends RefCounted
## ST066 prospective evidence evaluator. StadiumPlaqueRewards owns delivery; no invented numbers.
# gdlint: disable=max-returns

const VERSION: int = 3
const KEYS: Array = ["pa", "pitches", "hits", "strikeouts", "outs", "fielded", "clean_outs"]
const DynastyCareerSave = preload("res://src/gameplay/season/dynasty_career_save.gd")


static func enabled(season: SeasonState) -> bool:
	if season != null and not season._standard_live_context.is_empty():
		return load("res://src/gameplay/season/dynasty_standard_runtime.gd").paid_ledger(season) != null
	if season != null and not season._dynasty_career_session.is_empty():
		var context: Dictionary = DynastyCareerSave.binding(season._dynasty_career_session)
		return DynastyCareerSave._matches(season, context)
	return (
		season != null
		and season.career != null
		and season.career.current > 0
		and season.career.current == season.career.runs.size()
		and season.career.runs[-1].get("status") == "active"
		and season.career.runs[-1].get("player_progress") is Dictionary
		and (season.career.runs[-1].player_progress.get("version") == VERSION
			or (not season.career._pitch_catalog.is_empty() and WorkingPitchCareerProgress.is_current(season.career.runs[-1].player_progress)))
	)


static func capture(season: SeasonState, current_pitches: bool = false) -> Dictionary:
	var result: Dictionary = ClubPlayerProgress.capture_with_hits(season, current_pitches)
	if result.is_empty():
		return {}
	for index in range(result.games.size()):
		var row: Dictionary = result.games[index]
		var game: Dictionary = season.player_results[index]
		row["players"] = null
		# Missing historic provenance is unknown, not the current roster or club totals.
		if row.stats == null or not game.has("club_roster"):
			continue
		var own: Variant = game.club_roster
		var source: Variant = game.get("performance")
		if (
			not _roster(own)
			or not source is Dictionary
			or not SeasonPerformance.valid(source, source.keys())
		):
			return {}
		var fielding: Variant = game.get("fielding")
		var known_fielding: bool = fielding != null
		if (
			known_fielding
			and (
				not fielding is Array
				or not SeasonLeftRight.own_halves(fielding, game.home != 0)
				or not SeasonJumpstart.valid_roster(own, fielding, source)
			)
		):
			return {}
		var players: Dictionary = {}
		for id: String in own:
			if not source.has(id):
				return {}
			var line: Dictionary = source[id]
			var clean: Variant = 0 if known_fielding else null
			var fielded: Variant = line.get("fielding_v1")
			if known_fielding:
				for play: Dictionary in fielding:
					if play.player == id:
						if fielded == false:
							return {}
						fielded = true
						clean += 1 if play.clean else 0
			players[id] = {
				"pa": int(line.pa),
				"pitches": int(line.pitches),
				"hits": int(line.h),
				"strikeouts": int(line.p_k),
				"outs": int(line.outs),
				"fielded": fielded,
				"clean_outs": clean
			}
		row.players = players
	result.version = VERSION
	return result if (WorkingPitchCareerProgress.valid_capture(result, ClubSeasonRecord.capture(season).scores) if current_pitches else valid(result, ClubSeasonRecord.capture(season).scores)) else {}


static func _roster(value: Variant) -> bool:
	if not value is Array or value.size() != 4:
		return false
	var seen: Array = []
	for id: Variant in value:
		if not id is String or not SeasonPlayerCatalog.ROWS.has(id) or seen.has(id):
			return false
		seen.append(id)
	return true


static func valid(value: Variant, scores: Array) -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["version", "games", "development"])
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not value.games is Array
	):
		return false
	var legacy: Dictionary = value.duplicate(true)
	legacy.version = ClubPlayerProgress.HITS_VERSION
	for row: Variant in legacy.games:
		if not row is Dictionary or not row.has("players"):
			return false
		row.erase("players")
	# Reject malformed aggregate shapes/types before comparing individual totals.
	if not ClubPlayerProgress.valid(legacy, scores):
		return false
	for row: Dictionary in value.games:
		var players: Variant = row.players
		if players != null:
			if (
				not players is Dictionary
				or not _roster(players.keys())
				or not row.get("stats") is Dictionary
			):
				return false
			var hits: int = 0
			var strikeouts: int = 0
			var hitters: int = 0
			var three_k: int = 0
			var clean: int = 0
			var outs: int = 0
			for line: Variant in players.values():
				if not _line(line):
					return false
				clean += int(line.clean_outs) if line.clean_outs != null else 0
				outs += int(line.outs)
				hits += int(line.hits)
				strikeouts += int(line.strikeouts)
				hitters += 1 if line.hits > 0 else 0
				three_k += 1 if line.strikeouts >= 3 else 0
			# Reuse the official game's known defensive chronology, not arbitrary totals.
			if SeasonOwnership._whole(row.get("end_half"), 0, 19997):
				var score: Array = []
				for candidate: Variant in scores:
					if (
						candidate is Array
						and candidate.size() == 5
						and candidate[0] == row.get("game")
					):
						score = candidate
						break
				if score.is_empty():
					return false
				var halves: int = (int(row.end_half) + (2 if score[2] == 0 else 1)) / 2
				if outs > halves * 3:
					return false
			if (
				clean > outs - strikeouts
				or row.stats.get("hits") != hits
				or row.stats.get("strikeouts") != strikeouts
				or row.stats.get("hitters") != hitters
				or row.stats.get("three_k") != three_k
			):
				return false
	return true


static func _line(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, KEYS):
		return false
	for key: String in ["pa", "pitches", "hits", "strikeouts", "outs"]:
		if not SeasonOwnership._whole(value[key], 0, 1000000):
			return false
	if value.hits > value.pa or value.strikeouts > value.outs:
		return false
	if value.fielded != null and not value.fielded is bool:
		return false
	return (
		value.clean_outs == null
		or (
			SeasonOwnership._whole(value.clean_outs, 0, 9999)
			and (value.clean_outs == 0 or value.fielded == true)
		)
	)


static func evaluate(career: ClubCareer) -> Dictionary:
	if career == null:
		return {}
	var checked: ClubCareer = ClubCareer.from_data(career.to_data())
	if checked == null:
		return {}
	return _evaluate_runs(checked.runs, not checked._pitch_catalog.is_empty())


static func _evaluate_runs(runs: Array, current_pitches: bool = false) -> Dictionary:
	# Internal aggregation of already validated career rows; no roster-at-award gate.
	var players: Dictionary = {}
	for run: Dictionary in runs:
		var progress: Variant = run.get("player_progress")
		if not progress is Dictionary or not (WorkingPitchProgression.is_version(progress.get("version"), VERSION) or (current_pitches and WorkingPitchCareerProgress.is_current(progress))):
			continue
		var credits: Dictionary = {}
		for game: Dictionary in progress.games:
			if game.players == null:
				continue
			for id: String in game.players:
				var line: Dictionary = game.players[id]
				if not players.has(id):
					players[id] = {
						"hits": 0,
						"strikeouts": 0,
						"clean_outs": 0,
						"completed_seasons": [],
						"credited_games": {},
						"eligible": false,
						"evidence": "prospective-known-minimum"
					}
				var record: Dictionary = players[id]
				for key: String in ["hits", "strikeouts", "clean_outs"]:
					if line[key] != null:
						record[key] += int(line[key])
				if line.pa > 0 or line.pitches > 0 or line.fielded == true:
					credits[id] = int(credits.get(id, 0)) + 1
		for id: String in credits:
			players[id].credited_games[str(int(run.id))] = credits[id]
			if run.status == "completed" and credits[id] >= 5:
				players[id].completed_seasons.append(int(run.id))
	for record: Dictionary in players.values():
		record.eligible = (
			record.completed_seasons.size() >= 3
			and (record.hits >= 40 or record.strikeouts >= 60 or record.clean_outs >= 40)
		)
	return players
