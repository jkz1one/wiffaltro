class_name SeasonGearProgress
extends RefCounted
# gdlint: disable=max-returns
## Derived completed-game use, independent of copy ownership. No menu or win credit.

const FAMILIES: Array[String] = ["BAT-CON", "BAT-POW", "BALL-MOV", "BALL-VEL", "BALL-HYB"]
var enabled: bool = false
var alley_from: int = 0
var start: Dictionary = {}
var games: Array[Dictionary] = []


func fork() -> SeasonGearProgress:
	var result: SeasonGearProgress = SeasonGearProgress.new()
	result.enabled = enabled
	result.alley_from = alley_from
	result.start = start.duplicate()
	result.games = games.duplicate(true)
	return result


static func valid_counts(value: Variant, allow_alley: bool = true) -> bool:
	if not value is Dictionary:
		return false
	for id: Variant in value:
		if (
			not id is String
			or not tracked(id, allow_alley)
			or not SeasonOwnership._whole(value[id], 1, 12288)
		):
			return false
	if value.get(SeasonAlleyGear.GAP, 0) > 0 and value.get(SeasonAlleyGear.BASE, 0) < 10:
		return false
	for family: String in FAMILIES:
		if value.get(family + "-02", 0) > 0 and value.get(family + "-01", 0) < 10:
			return false
	return true


static func tracked(id: String, allow_alley: bool = true) -> bool:
	return (
		(allow_alley and id in [SeasonAlleyGear.BASE, SeasonAlleyGear.GAP])
		or (id.left(-3) in FAMILIES and id.right(3) in ["-01", "-02"])
	)


static func access(counts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for family: String in FAMILIES:
		if counts.get(family + "-01", 0) >= 10:
			result.append(family + "-02")
		if counts.get(family + "-02", 0) >= 20:
			result.append(family + "-03")
	if counts.get(SeasonAlleyGear.BASE, 0) >= 10:
		result.append(SeasonAlleyGear.GAP)
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
	for receipt: Dictionary in SeasonMatchInventory.gear(build).values():
		if not receipt.is_empty() and command.get("used_gear", []).has(receipt.id):
			var allow_alley: bool = build._format >= 40 and build.revision() >= alley_from
			if tracked(receipt.item, allow_alley):
				items.append(receipt.item)
	items.sort()
	if not items.is_empty():
		games.append({"game": int(command.game), "items": items})


static func valid_games(
	value: Variant, scores: Array, baseline: Dictionary, allow_alley: bool = true
) -> bool:
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
			if not id is String or not tracked(id, allow_alley):
				return false
			var slot: String = SeasonGearCatalog.item(id).slot
			if slots.has(slot):
				return false
			if id.ends_with("-02") and not access(counts).has(id):
				return false
			slots.append(slot)
		sorted.sort()
		if sorted != row.items:
			return false
		counts = add(counts, [row])
	return valid_counts(counts, allow_alley)
