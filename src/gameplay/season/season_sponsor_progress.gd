class_name SeasonSponsorProgress
extends RefCounted
# gdlint: disable=max-returns
## Prospective completed-game evidence; inherited access never grants a copy.

const HITS: Array[String] = ["double", "hr", "single", "triple"]
var enabled: bool = false
var start: Dictionary = {"hits": [], "encore": false}
var games: Array[Dictionary] = []


func fork() -> SeasonSponsorProgress:
	var result: SeasonSponsorProgress = SeasonSponsorProgress.new()
	result.enabled = enabled
	result.start = start.duplicate(true)
	result.games = games.duplicate(true)
	return result


static func valid_hits(value: Variant) -> bool:
	if not value is Array or value.size() > 4:
		return false
	var seen: Array = []
	for id: Variant in value:
		if not id is String or not HITS.has(id) or seen.has(id):
			return false
		seen.append(id)
	seen.sort()
	return seen == value


static func valid_state(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._keys(value, ["hits", "encore"])
		and valid_hits(value.hits)
		and value.encore is bool
	)


static func hit_types(performance: Dictionary, roster: Array) -> Array[String]:
	var result: Array[String] = []
	for id: String in roster:
		var line: Dictionary = performance.get(id, {})
		for kind: String in ["double", "triple", "hr"]:
			if int(line.get(kind, 0)) > 0 and not result.has(kind):
				result.append(kind)
		var singles: int = (
			int(line.get("h", 0))
			- int(line.get("double", 0))
			- int(line.get("triple", 0))
			- int(line.get("hr", 0))
		)
		if singles > 0 and not result.has("single"):
			result.append("single")
	result.sort()
	return result


static func add(baseline: Dictionary, evidence: Array) -> Dictionary:
	var result: Dictionary = baseline.duplicate(true)
	for game: Dictionary in evidence:
		for kind: String in game.hits:
			if not result.hits.has(kind):
				result.hits.append(kind)
		result.encore = result.encore or (game.win and game.multi_k)
	result.hits.sort()
	return result


func state() -> Dictionary:
	return add(start, games)


func eligible() -> Array[String]:
	var result: Array[String] = []
	if not enabled:
		return result
	var progress: Dictionary = state()
	if progress.hits.size() >= 3:
		result.append("E05")
	if progress.encore:
		result.append("G05")
	return result


func settle(build: SeasonBuild, command: Dictionary) -> void:
	if not enabled:
		return
	var stats: Dictionary = command.get("performance", {})
	var pitchers: int = 0
	for id: String in build.roster():
		if stats.get(id, {}).get("p_k", 0) > 0:
			pitchers += 1
	games.append(
		{
			"game": int(command.game),
			"hits": hit_types(stats, build.roster()),
			"win": command.win,
			"multi_k": pitchers >= 2
		}
	)


static func valid_games(value: Variant, scores: Array) -> bool:
	if not value is Array or value.size() > 12:
		return false
	var own: Array = []
	for score: Array in scores:
		if 0 in [int(score[1]), int(score[2])]:
			own.append(score)
	if own.size() != value.size():
		return false
	for index in range(own.size()):
		var row: Variant = value[index]
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(row, ["game", "hits", "win", "multi_k"])
		):
			return false
		if (
			not SeasonOwnership._whole(row.game, 0, 32)
			or row.game != own[index][0]
			or not valid_hits(row.hits)
			or not row.win is bool
			or not row.multi_k is bool
		):
			return false
		var winner: int = int(own[index][1] if own[index][3] > own[index][4] else own[index][2])
		if row.win != (winner == 0):
			return false
	return true
