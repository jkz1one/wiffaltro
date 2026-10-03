class_name SeasonOpponentMarket
extends RefCounted
## Market1 remains frozen. Market2 adds the initial passive Gear contract.


static func cards(build: SeasonBuild) -> Array[String]:
	var result: Array[String] = []
	for stat: String in SeasonPlayerCatalog.STATS:
		var id: String = "development." + stat
		if not build.targets(id).is_empty():
			result.append(id)
	return result


static func offers(build: SeasonBuild, roll: int) -> Dictionary:
	if build._market == 2:
		return SeasonOpponentGear.offers(build, roll)
	var pool: Array[String] = cards(build)
	var result: Dictionary = {}
	var rng: RandomNumberGenerator = build._rng(roll)
	if pool.is_empty():
		return result
	for index in range(4):
		result["visit:%d:roll:%d:%d" % [build._visit.number, roll, index]] = (pool[rng.randi_range(
			0, pool.size() - 1
		)])
	return result


static func pack(build: SeasonBuild) -> Array:
	var pool: Array[String] = cards(build)
	var result: Array = []
	var rng: RandomNumberGenerator = build._rng(-1)
	for index in range(mini(3, pool.size())):
		var chosen: int = rng.randi_range(0, pool.size() - 1)
		result.append(pool[chosen])
		pool.remove_at(chosen)
	return result
