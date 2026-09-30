class_name SeasonGearProgress
extends RefCounted
# gdlint: disable=max-returns
## Derived completed-game use, independent of copy ownership. No menu or win credit.

const FAMILIES: Array[String] = ["BAT-CON", "BAT-POW", "BALL-MOV", "BALL-VEL", "BALL-HYB"]
var enabled: bool = false
var start: Dictionary = {}
var games: Array[Dictionary] = []


func fork() -> SeasonGearProgress:
	var result: SeasonGearProgress = SeasonGearProgress.new()
	result.enabled = enabled
	result.start = start.duplicate()
	result.games = games.duplicate(true)
	return result


static func valid_counts(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for id: Variant in value:
		if not id is String or not tracked(id) or not SeasonOwnership._whole(value[id], 1, 12288):
			return false
	for family: String in FAMILIES:
		if value.get(family + "-02", 0) > 0 and value.get(family + "-01", 0) < 10:
			return false
	return true


static func tracked(id: String) -> bool:
	return id.left(-3) in FAMILIES and id.right(3) in ["-01", "-02"]


static func access(counts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for family: String in FAMILIES:
		if counts.get(family + "-01", 0) >= 10:
			result.append(family + "-02")
		if counts.get(family + "-02", 0) >= 20:
			result.append(family + "-03")
	return result


static func add(counts: Dictionary, evidence: Array) -> Dictionary:
	var result: Dictionary = counts.duplicate()
	for game: Dictionary in evidence:
		for id: String in game.items:
			result[id] = int(result.get(id, 0)) + 1
	return result


func counts() -> Dictionary:
	return add(start, games)


func eligible() -> Array[String]:
	var result: Array[String] = []
	if enabled:
		result = access(counts())
	return result


func settle(build: SeasonBuild, command: Dictionary) -> void:
	if not enabled:
		return
	# Called only after receipt-specific first-release/performance validation succeeds.
	var items: Array[String] = []
	for receipt: Dictionary in build._bank.view().gear.values():
		if not receipt.is_empty() and command.get("used_gear", []).has(receipt.id):
			if tracked(receipt.item):
				items.append(receipt.item)
	items.sort()
	if not items.is_empty():
		games.append({"game": int(command.game), "items": items})


static func valid_games(value: Variant, scores: Array, baseline: Dictionary) -> bool:
	if not value is Array or value.size() > 12:
		return false
	var previous: int = -1
	var counts: Dictionary = baseline.duplicate()
	for row: Variant in value:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["game", "items"]):
			return false
		if not SeasonOwnership._whole(row.game, 0, 32) or row.game <= previous:
			return false
		previous = int(row.game)
		var completed: bool = false
		for score: Array in scores:
			if score[0] == row.game and 0 in [int(score[1]), int(score[2])]:
				completed = true
		if not completed or not row.items is Array or row.items.is_empty() or row.items.size() > 2:
			return false
		var slots: Array[String] = []
		var sorted: Array = row.items.duplicate()
		for id: Variant in row.items:
			if not id is String or not tracked(id) or slots.has(id.left(3)):
				return false
			if id.ends_with("-02") and not access(counts).has(id):
				return false
			slots.append(id.left(3))
		sorted.sort()
		if sorted != row.items:
			return false
		counts = add(counts, [row])
	return valid_counts(counts)
