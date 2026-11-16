class_name PhysicalBaseFlow
extends RefCounted
## Replay actual base occupancy and separate supply runs from credited batting runs.
# gdlint: disable=max-returns

const SNAPSHOT_KEYS: Array = ["pa", "half", "player", "pitcher", "outs", "away", "home", "bases"]
const HITS: Dictionary = {"single": BallPlayOutcome.Result.SINGLE,
	"double": BallPlayOutcome.Result.DOUBLE, "triple": BallPlayOutcome.Result.TRIPLE,
	"hr": BallPlayOutcome.Result.HOME_RUN}

var bases: BaseState = BaseState.new()
var rosters: Array = []
var scores: Array[int] = [0, 0]
var batting: Array[int] = [0, 0]
var half: int = 0
var pa: int = 1
var outs: int = 0
var ended: bool = false
var stats: MatchPerformance = MatchPerformance.new()
var supply_runs: Array[int] = [0, 0]


static func valid(value: Variant, teams: Array, performance: Dictionary) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["version", "ready", "results", "tags", "advances", "final"]) or value.version != 1:
		return false
	for key: String in ["ready", "results", "tags", "advances"]:
		if not value[key] is Array or value[key].size() > 99999:
			return false
	if value.ready.is_empty() or value.results.is_empty() \
		or value.ready.size() < value.results.size() or value.ready.size() > value.results.size() + 1:
		return false
	if teams.size() != 2 or not teams[0] is Array or not teams[1] is Array \
		or teams[0].size() != 4 or teams[1].size() != 4:
		return false
	var ids: Array = teams[0] + teams[1]
	if not SeasonPerformance.valid(performance, ids):
		return false
	var replay: PhysicalBaseFlow = PhysicalBaseFlow.new()
	replay.rosters = teams
	for id: Variant in ids:
		if not id is String or id.is_empty() or ids.count(id) != 1:
			return false
		replay.stats.players[id] = MatchPerformance.empty_line()
	return replay._replay(value, performance)


func _replay(value: Dictionary, performance: Dictionary) -> bool:
	var tags: Dictionary = _indexed(value.tags)
	var advances: Dictionary = _indexed(value.advances, true)
	if tags.size() != value.tags.size() or advances.size() != value.advances.size():
		return false
	for index in range(value.ready.size()):
		if ended or not _snapshot(value.ready[index]):
			return false
		if advances.has(pa):
			if not _advance(advances[pa], performance):
				return false
			advances.erase(pa)
		if ended:
			if index != value.ready.size() - 1 or value.results.size() != index or tags.has(pa):
				return false
			break
		if index >= value.results.size() or not _result(value.results[index], tags.get(pa)):
			return false
		tags.erase(pa)
		batting[half % 2] += 1
		pa += 1
		if not ended and outs == MatchState.OUTS_PER_HALF:
			ended = _half_end()
			if not ended:
				half += 1
				outs = 0
				bases.clear()
				if half >= MatchState.REGULATION_INNINGS * 2:
					bases.second = StringName("extra_runner.%s.%d" % [
						"away" if half % 2 == 0 else "home", int(half / 2) + 1])
	if not ended or not tags.is_empty() or not advances.is_empty() or not _snapshot(value.final):
		return false
	for id: String in performance:
		for key: String in MatchPerformance.KEYS:
			if key != "pitches" and stats.players[id][key] != performance[id][key]:
				return false
	return true


func _snapshot(value: Variant, extra: Array = []) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, SNAPSHOT_KEYS + extra):
		return false
	if not SeasonOwnership._whole(value.pa, pa, pa) \
		or not SeasonOwnership._whole(value.half, half, half) \
		or not SeasonOwnership._whole(value.outs, outs, outs) \
		or not SeasonOwnership._whole(value.away, scores[0], scores[0]) \
		or not SeasonOwnership._whole(value.home, scores[1], scores[1]) \
		or not value.player is String or value.player != rosters[half % 2][batting[half % 2] % 4] \
		or not value.pitcher is String or not rosters[1 - half % 2].has(value.pitcher):
		return false
	return ClubCareer.same(value.bases,
		[String(bases.first), String(bases.second), String(bases.third)])


static func _indexed(rows: Array, advance: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for row: Variant in rows:
		if not row is Dictionary:
			return {}
		var source: Variant = row.get("after") if advance else row
		if not source is Dictionary or not SeasonOwnership._whole(source.get("pa"), 1, 99999) \
			or result.has(int(source.pa)):
			return {}
		result[int(source.pa)] = row
	return result


func _advance(row: Dictionary, performance: Dictionary) -> bool:
	if not SeasonOwnership._keys(row, ["receipt", "advance", "after"]) \
		or not row.receipt is String or row.receipt.is_empty() \
		or not TacticalBaseAdvance.valid(row.advance, rosters[half % 2], performance):
		return false
	var expected: Dictionary = TacticalBaseAdvance.target(bases)
	if expected.is_empty():
		return false
	if String(expected.runner).begins_with("extra_runner."):
		expected["context"] = {"half": half,
			"bases": [String(bases.first), String(bases.second), String(bases.third)]}
	if not ClubCareer.same(expected, row.advance):
		return false
	match int(expected.from):
		1:
			bases.second = bases.first
			bases.first = &""
		2:
			bases.third = bases.second
			bases.second = &""
		3:
			bases.third = &""
			scores[half % 2] += 1
			supply_runs[half % 2] += 1
			ended = _scored_end()
	return _snapshot(row.after)


func _result(row: Variant, tag: Variant) -> bool:
	if not row is Dictionary or not row.get("outcome") is String \
		or row.outcome not in ["walk", "strikeout", "out", "single", "double", "triple", "hr"]:
		return false
	var runs: int = 0
	var batter: String = rosters[half % 2][batting[half % 2] % 4]
	if tag != null:
		if row.outcome != "out" or outs >= 2 or not _tag_shape(tag):
			return false
		var position: Vector3 = Vector3(tag.position[0], tag.position[1], tag.position[2])
		runs = TagAdvanceResolver.resolve(bases, position, int(tag.rating),
			float(tag.gather), float(tag.travel)).runs_scored
	if row.outcome == "walk":
		runs = bases.advance_for_walk(StringName(batter))
	elif HITS.has(row.outcome):
		runs = bases.advance_for_hit(HITS[row.outcome], StringName(batter))
	else:
		outs += 1
	scores[half % 2] += runs
	ended = runs > 0 and _scored_end()
	if not _snapshot(row, ["outcome", "rbi"]) or not SeasonOwnership._whole(row.rbi, runs, runs):
		return false
	stats.complete(StringName(batter), StringName(row.pitcher), row.outcome, runs)
	return true


func _tag_shape(tag: Variant) -> bool:
	if not tag is Dictionary or not SeasonOwnership._keys(tag,
		["pa", "half", "defender", "position", "rating", "gather", "travel"]):
		return false
	if not SeasonOwnership._whole(tag.pa, pa, pa) \
		or not SeasonOwnership._whole(tag.half, half, half) \
		or not tag.defender is String or not rosters[1 - half % 2].has(tag.defender) \
		or not tag.position is Array or tag.position.size() != 3 \
		or not SeasonOwnership._whole(tag.rating, 1, 100):
		return false
	for coordinate: Variant in tag.position:
		if not PhysicalMatchReport.number(coordinate, -100000.0, 100000.0):
			return false
	return (PhysicalMatchReport.number(tag.gather, 0.75, 1.0)
		and (is_equal_approx(tag.gather, 1.0) or is_equal_approx(tag.gather, 0.75))
		and PhysicalMatchReport.number(tag.travel, 0.88, 1.0)
		and (is_equal_approx(tag.travel, 1.0) or is_equal_approx(tag.travel, 0.88)))


func _scored_end() -> bool:
	var inning: int = int(half / 2) + 1
	return ((half % 2 == 1 and inning >= MatchState.REGULATION_INNINGS and scores[1] > scores[0])
		or (inning - (1 if half % 2 == 0 else 0) >= 3
			and absi(scores[0] - scores[1]) >= MatchState.MERCY_RUNS
			and (half % 2 == 1 or scores[1] > scores[0])))


func _half_end() -> bool:
	var inning: int = int(half / 2) + 1
	if half % 2 == 0:
		return ((inning - 1 >= 3 and scores[1] - scores[0] >= MatchState.MERCY_RUNS)
			or (inning >= MatchState.REGULATION_INNINGS and scores[1] > scores[0]))
	return ((inning >= MatchState.REGULATION_INNINGS and scores[0] != scores[1])
		or (inning >= 3 and absi(scores[0] - scores[1]) >= MatchState.MERCY_RUNS))
