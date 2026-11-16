class_name StadiumCareerProgress
extends RefCounted
## Closed career prefixes are authoritative input, never purchase-command claims.


static func capture(career: ClubCareer) -> Array:
	var result: Array = []
	for run: Dictionary in career.runs:
		if run.status == "active":
			break
		var summary: Dictionary = ClubSeasonRecord.analyze(run.proof)
		if summary.is_empty() or run.status not in ["completed", "abandoned"]:
			return []
		# The current stadium register defines W as regular-season wins, not playoff wins.
		var row: Dictionary = {
			"seasons": 1 if run.status == "completed" else 0, "wins": int(summary.wins)
		}
		var details: Variant = run.get("player_progress")
		if details != null:
			if not (WorkingPitchCareerProgress.valid(details, run.proof.scores) if not career._pitch_catalog.is_empty() and WorkingPitchCareerProgress.is_current(details) else ClubPlayerProgress.valid(details, run.proof.scores)):
				return []
			var homers: int = 0
			var strikeouts: int = 0
			var hits: int = 0
			for game: Dictionary in details.games:
				if game.stats != null:
					homers += int(game.stats.homers)
					strikeouts += int(game.stats.strikeouts)
					if (
						details.version
						in [ClubPlayerProgress.HITS_VERSION, ClubPlayerLegend.VERSION]
						or (not career._pitch_catalog.is_empty() and WorkingPitchCareerProgress.is_current(details))
					):
						hits += int(game.stats.hits)
			if homers > 0:
				row["homers"] = homers
			if strikeouts > 0:
				row["strikeouts"] = strikeouts
			if hits > 0:
				row["hits"] = hits
		result.append(row)
	return result


static func valid(rows: Variant, credits: Array) -> bool:
	if not rows is Array or rows.size() > credits.size():
		return false
	for index in range(rows.size()):
		var row: Variant = rows[index]
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(
				row,
				(
					["seasons", "wins"]
					+ (["strikeouts"] if row.has("strikeouts") else [])
					+ (["hits"] if row.has("hits") else [])
					+ (["homers"] if row.has("homers") else [])
				)
			)
		):
			return false
		if (
			not SeasonOwnership._whole(row.seasons, 0, 1)
			or not SeasonOwnership._whole(row.wins, 0, 10)
			or (row.seasons == 1) != (credits[index] > 0)
			or not SeasonOwnership._whole(row.get("strikeouts", 0), 0, 12 * 9999)
			or not SeasonOwnership._whole(row.get("hits", 0), 0, 12 * 4 * 1000000)
			or not SeasonOwnership._whole(row.get("homers", 0), 0, 12 * 9999)
		):
			return false
	return true


static func metrics(rows: Array, through: int) -> Dictionary:
	if through < 0 or through > rows.size():
		return {}
	var result: Dictionary = {"seasons": 0, "wins": 0}
	for index in range(through):
		result.seasons += int(rows[index].seasons)
		result.wins += int(rows[index].wins)
		if rows[index].has("homers"):
			result["homers"] = int(result.get("homers", 0)) + int(rows[index].homers)
		if rows[index].has("strikeouts"):
			result["strikeouts"] = int(result.get("strikeouts", 0)) + int(rows[index].strikeouts)
		if rows[index].has("hits"):
			result["hits"] = int(result.get("hits", 0)) + int(rows[index].hits)
	return result
