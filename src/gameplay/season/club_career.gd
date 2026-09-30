class_name ClubCareer
extends RefCounted
# gdlint: disable=max-returns
## One persistent ledger, embedded atomically with its active season. No power carries over.

const MAX_RUNS: int = 1024
var current: int = 0
var runs: Array[Dictionary] = []


func fork() -> ClubCareer:
	var result: ClubCareer = ClubCareer.new()
	result.current = current
	result.runs = runs.duplicate(true)
	return result


func start(season: SeasonState) -> bool:
	if season.phase != SeasonState.Phase.DRAFT or not season.picks.is_empty():
		return false
	if current != 0 or runs.size() >= MAX_RUNS or season.build == null or season.opponents == null:
		return false
	season.build._gear_progress.enabled = true
	season.build._gear_progress.start = gear_counts()
	current = runs.size() + 1
	runs.append(
		{
			"id": current,
			"seed": season.season_seed,
			"league": "standard",
			"tier": 0,
			"status": "active",
			"proof": ClubSeasonRecord.capture(season),
			"receipt": {},
			"gear": []
		}
	)
	return true


func sync(season: SeasonState) -> bool:
	if current == 0:
		return season.build == null
	if current != runs.size() or season.season_seed != runs[-1].seed:
		return false
	var run: Dictionary = runs[-1]
	if not gear_matches(season, false):
		return false
	var gear: Variant = (
		season.build._gear_progress.games.duplicate(true) if run.gear != null else null
	)
	var proof: Dictionary = ClubSeasonRecord.capture(season)
	if run.status == "completed":
		return (
			season.phase == SeasonState.Phase.COMPLETE
			and same(run.proof, proof)
			and same(run.gear, gear)
		)
	if run.status != "active":
		return false
	if season.phase == SeasonState.Phase.COMPLETE:
		var award: Dictionary = ClubSeasonRecord.receipt(proof, not cleared())
		if award.is_empty():
			return false
		run.receipt = award
		run.status = "completed"
	run.proof = proof
	run.gear = gear
	return true


func close(season: SeasonState) -> bool:
	if not sync(season):
		return false
	if current > 0 and runs[-1].status == "active":
		runs[-1].status = "abandoned"
	current = 0
	return true


func balance() -> int:
	var total: int = 0
	for run: Dictionary in runs:
		total += int(run.receipt.get("total", 0))
	return total


func cleared() -> bool:
	for run: Dictionary in runs:
		if run.receipt.get("finish") == "champion":
			return true
	return false


func to_data() -> Dictionary:
	return {"version": 2, "current": current, "runs": runs.duplicate(true)}


static func same(a: Variant, b: Variant) -> bool:
	return (
		JSON.parse_string(JSON.stringify(a, "", true, true))
		== JSON.parse_string(JSON.stringify(b, "", true, true))
	)


static func from_data(value: Variant) -> ClubCareer:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "current", "runs"]):
		return null
	if (
		not SeasonOwnership._whole(value.version, 1, 2)
		or not value.runs is Array
		or value.runs.size() > MAX_RUNS
	):
		return null
	if not SeasonOwnership._whole(value.current, 0, value.runs.size()):
		return null
	if value.current != 0 and value.current != value.runs.size():
		return null
	var result: ClubCareer = ClubCareer.new()
	result.current = int(value.current)
	for row: Variant in value.runs:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(
				row,
				(
					["id", "seed", "league", "tier", "status", "proof", "receipt"]
					+ (["gear"] if value.version >= 2 else [])
				)
			)
		):
			return null
		if row.id != result.runs.size() + 1 or not SeasonOwnership._whole(row.seed, 0, 2147483647):
			return null
		if (
			row.league != "standard"
			or row.tier != 0
			or row.status not in ["active", "completed", "abandoned"]
		):
			return null
		if not row.receipt is Dictionary:
			return null
		var record: Dictionary = ClubSeasonRecord.analyze(row.proof)
		if record.is_empty():
			return null
		if row.status == "completed":
			var expected: Dictionary = ClubSeasonRecord.receipt(row.proof, not result.cleared())
			if expected.is_empty() or not same(row.receipt, expected):
				return null
		elif not row.receipt.is_empty() or record.finish != "unfinished":
			return null
		if row.status == "active" and row.id != result.current:
			return null
		if row.status == "abandoned" and row.id == result.current:
			return null
		var migrated: Dictionary = row.duplicate(true)
		if value.version == 1:
			migrated["gear"] = null
		if (
			migrated.gear != null
			and not SeasonGearProgress.valid_games(
				migrated.gear, row.proof.scores, result.gear_counts()
			)
		):
			return null
		result.runs.append(migrated)
	return result


func matches(season: SeasonState) -> bool:
	if current == 0:
		return season.build == null
	if season.build == null or season.opponents == null or current != runs.size():
		return false
	var run: Dictionary = runs[-1]
	return (
		run.seed == season.season_seed
		and (run.status == "completed") == (season.phase == SeasonState.Phase.COMPLETE)
		and same(run.proof, ClubSeasonRecord.capture(season))
		and gear_matches(season, true)
	)


func gear_counts(before_current: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for run: Dictionary in runs:
		if before_current and run.id == current:
			break
		if run.gear != null:
			result = SeasonGearProgress.add(result, run.gear)
	return result


func gear_matches(season: SeasonState, exact: bool) -> bool:
	if season.build == null:
		return false
	var run: Dictionary = runs[-1]
	var progress: SeasonGearProgress = season.build._gear_progress
	if (run.gear != null) != progress.enabled:
		return false
	if not progress.enabled:
		return true
	return (
		same(progress.start, gear_counts(true))
		and SeasonGearProgress.valid_games(
			progress.games, ClubSeasonRecord.capture(season).scores, progress.start
		)
		and (not exact or same(run.gear, progress.games))
	)
