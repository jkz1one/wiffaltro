class_name SeasonOpponentMarket
extends RefCounted
## Explicit version dispatch preserves historical stock and pack generation.


static func cards(build: SeasonBuild) -> Array[String]:
	var result: Array[String] = []
	for stat: String in SeasonPlayerCatalog.STATS:
		var id: String = "development." + stat
		if not build.targets(id).is_empty():
			result.append(id)
	return result


static func offers(build: SeasonBuild, roll: int) -> Dictionary:
	if build._market in [6, 7, 8, 9]:
		return SeasonOpponentSponsors.offers(build, roll)
	if build._market == 5:
		return SeasonOpponentAbilities.offers(build, roll)
	if build._market == 4:
		return SeasonOpponentLessons.offers(build, roll)
	if build._market == 3:
		return SeasonOpponentMastery.offers(build, roll)
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
	if build._market in [3, 4, 5, 6, 7, 8, 9]:
		return DevelopmentShopCatalog.pack(build._book, build.roster(), build._rng(-1))
	var pool: Array[String] = cards(build)
	var result: Array = []
	var rng: RandomNumberGenerator = build._rng(-1)
	for index in range(mini(3, pool.size())):
		var chosen: int = rng.randi_range(0, pool.size() - 1)
		result.append(pool[chosen])
		pool.remove_at(chosen)
	return result
