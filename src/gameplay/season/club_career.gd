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
	current = runs.size() + 1
	runs.append(
		{
			"id": current,
			"seed": season.season_seed,
			"league": "standard",
			"tier": 0,
			"status": "active",
			"proof": ClubSeasonRecord.capture(season),
			"receipt": {}
		}
	)
	return true


func sync(season: SeasonState) -> bool:
	if current == 0:
		return season.build == null
	if current != runs.size() or season.season_seed != runs[-1].seed:
		return false
	var run: Dictionary = runs[-1]
	var proof: Dictionary = ClubSeasonRecord.capture(season)
	if run.status == "completed":
		return season.phase == SeasonState.Phase.COMPLETE and same(run.proof, proof)
	if run.status != "active":
		return false
	if season.phase == SeasonState.Phase.COMPLETE:
		var award: Dictionary = ClubSeasonRecord.receipt(proof, not cleared())
		if award.is_empty():
			return false
		run.receipt = award
		run.status = "completed"
	run.proof = proof
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
	return {"version": 1, "current": current, "runs": runs.duplicate(true)}


static func same(a: Variant, b: Variant) -> bool:
	return (
		JSON.parse_string(JSON.stringify(a, "", true, true))
		== JSON.parse_string(JSON.stringify(b, "", true, true))
	)


static func from_data(value: Variant) -> ClubCareer:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "current", "runs"]):
		return null
	if value.version != 1 or not value.runs is Array or value.runs.size() > MAX_RUNS:
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
				row, ["id", "seed", "league", "tier", "status", "proof", "receipt"]
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
		result.runs.append(row.duplicate(true))
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
	)
