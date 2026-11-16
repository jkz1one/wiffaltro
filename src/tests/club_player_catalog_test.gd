extends Node

var _failures: int = 0


func _ready() -> void:
	var all_ids: Array[String] = ClubPlayerCatalog.initial_owned()
	all_ids.append_array(ClubPlayerCatalog.PACK_POOL)
	all_ids.append_array(ClubPlayerCatalog.EARNED.keys())
	all_ids.sort()
	_check(all_ids == SeasonPlayerCatalog.ids(), "12 starters,18 packs,18 feats partition all48 once")
	_check(ClubPlayerCatalog.STARTERS.size() == 12 and ClubPlayerCatalog.PACK_POOL.size() == 18
		and ClubPlayerCatalog.EARNED.size() == 18, "explicit three acquisition routes")
	var owned: Array[String] = ClubPlayerCatalog.initial_owned()
	var before: Array[String] = owned.duplicate()
	var exposed: Array[String] = []
	for seed_value in range(128):
		var cards: Array[String] = ClubPlayerCatalog.offers(owned, seed_value, 0)
		_check(cards.size() == 3 and cards == ClubPlayerCatalog.offers(owned, seed_value, 0),
			"reveal is fixed and reproducible")
		var unique: Array = []
		for id: String in cards:
			_check(ClubPlayerCatalog.PACK_POOL.has(id) and not unique.has(id) and not owned.has(id),
				"pack never contains an owned,duplicate or feat-only character")
			unique.append(id)
			if not exposed.has(id):
				exposed.append(id)
	_check(exposed.size() == 18 and owned == before,
		"whole pack pool reachable without mutating owner")
	for count in range(19):
		owned = ClubPlayerCatalog.initial_owned()
		owned.append_array(ClubPlayerCatalog.PACK_POOL.slice(0, count))
		owned.sort()
		_check(ClubPlayerCatalog.offers(owned, 17, count).size() == mini(3, 18 - count),
			"fewer real choices near exhaustion; empty means no purchasable pack")
	_check(not ClubPlayerCatalog.valid_ids(["player.unknown"]) and
		ClubPlayerCatalog.offers([], 1, 0).is_empty(), "invalid entitlement is not a fresh paid pool")
	var metrics: Dictionary = {}
	var families: Array = []
	for id: String in ClubPlayerCatalog.EARNED:
		var rule: Array = ClubPlayerCatalog.EARNED[id]
		_check(not ClubPlayerCatalog.earned(metrics).has(id), "no unearned card")
		metrics[rule[0]] = int(rule[1]) - 1
		_check(not ClubPlayerCatalog.earned(metrics).has(id), "exact threshold has no early award")
		metrics[rule[0]] = rule[1]
		_check(ClubPlayerCatalog.earned(metrics).has(id), "exact threshold earns the named character")
		var view: Dictionary = ClubPlayerCatalog.progress(id, metrics)
		_check(view.current == view.goal and not view.requirement.is_empty(), "visible progress and goal")
		if not families.has(rule[2]):
			families.append(rule[2])
	_check(families.size() >= 6, "unlock design spans distinct play and build families")
	for value: Variant in [true, "5", -1, 4.5, NAN, INF]:
		_check(not ClubPlayerCatalog.earned({"mastery_max": value}).has("player.alex_finch"),
			"malformed progress cannot earn a character")
	var switch_hitters: int = 0
	var left_hitters: int = 0
	for id: String in ClubPlayerCatalog.STARTERS:
		var player: PlayerDefinition = ContentDB.get_player(StringName(id))
		switch_hitters += 1 if player.switch_hitter else 0
		left_hitters += 1 if player.bats == PlayerDefinition.Handedness.LEFT else 0
	_check(switch_hitters == 1 and left_hitters >= 3, "starting roster includes handedness variety")
	if _failures == 0:
		print("Wiffaltro player catalog checks passed:48 distinct routes and duplicate-free packs.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
