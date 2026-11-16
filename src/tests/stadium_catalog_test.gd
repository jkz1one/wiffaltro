extends Node
## Data-only source reconciliation. Passing does not certify meshes, contacts or placement.

var _failures: int = 0


func _ready() -> void:
	var kinds: Dictionary = {"copy": 0, "style": 0, "reward": 0}
	_check(StadiumCatalog.ROWS.size() == 101, "all individual identities retained")
	var generous: Dictionary = {
		"seasons": 100, "wins": 1000, "strikeouts": 1000, "hits": 1000, "homers": 1000
	}
	for id: String in StadiumCatalog.ROWS:
		var item: Dictionary = StadiumCatalog.item(id)
		kinds[item.kind] += 1
		_check(
			not item.name.is_empty() and item.annex.begins_with("archive-s"),
			"each item retains name and exact technical reference"
		)
		_check(not item.placement_verified, "catalog count never certifies runtime placement")
		if item.kind == "reward":
			_check(not StadiumCatalog.eligible(id, generous), "history cannot be bought")
		else:
			_check(StadiumCatalog.eligible(id, generous), "ordinary authored access is reachable")
			for key: String in item.requires:
				var progress: Dictionary = generous.duplicate()
				progress[key] = item.requires[key] - 1
				_check(not StadiumCatalog.eligible(id, progress), "exact access threshold")
		if item.kind == "copy":
			_check(item.copy_price > 0, "physical copy price separate from blueprint")
		else:
			_check(item.copy_price == -1, "styles/rewards are not repeat purchasable copies")
	_check(kinds == {"copy": 84, "style": 14, "reward": 3}, "101-row source categories")
	_check(
		StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"],
		"only cone, lawn chair and backstop chair in new-club starter grant"
	)
	for id: String in StadiumCatalog.STARTERS:
		_check(
			StadiumCatalog.eligible(id, {}) and StadiumCatalog.item(id).blueprint_price == 0,
			"starter type entitlement distinguished from additional paid copies"
		)
	_check(
		not StadiumCatalog.item("ST-080").starter and not StadiumCatalog.item("ST-051").starter,
		"spectator chair and molded seat remain separate paid identities"
	)
	_check(
		not StadiumCatalog.eligible("ST-026", {"strikeouts": 40}),
		"stat gate also requires a completed season"
	)
	_check(
		not StadiumCatalog.eligible("ST-047", {"seasons": 1, "homers": 75}),
		"archived alternative blueprint proposal not silently enabled"
	)
	for value: Variant in [true, "100", NAN, INF, 2.5]:
		_check(
			not StadiumCatalog.eligible("ST-002", {"seasons": value}), "malformed progress rejected"
		)
	_check(
		(
			StadiumCatalog.land_eligible("expanded", 0, {"seasons": 4, "wins": 10})
			and not StadiumCatalog.land_eligible("mogul", 0, generous)
		),
		"land ladder cannot skip hosts"
	)
	_check(
		(
			(
				StadiumCatalog.LAND.expanded.price
				+ StadiumCatalog.LAND.club.price
				+ StadiumCatalog.LAND.mogul.price
			)
			== 6400
		),
		"incremental land cost preserved"
	)
	_check(
		StadiumCatalog.within_live_budget(["ST-001", "ST-001", "ST-003", "ST-008"]),
		"four small instances within four units"
	)
	_check(
		not StadiumCatalog.within_live_budget(["ST-001", "ST-001", "ST-001", "ST-001", "ST-001"]),
		"fifth instance rejected"
	)
	_check(
		(
			StadiumCatalog.within_live_budget(["ST-006"])
			and not StadiumCatalog.within_live_budget(["ST-006", "ST-001"])
		),
		"pool uses whole live budget"
	)
	_check(
		not StadiumCatalog.within_live_budget(["ST-079"]), "receiver cannot bypass obstacle sites"
	)
	var edited: Dictionary = StadiumCatalog.item("ST-002")
	edited.requires.seasons = 0
	_check(StadiumCatalog.item("ST-002").requires.seasons == 2, "returned metadata is isolated")
	if _failures == 0:
		print(
			"Wiffaltro stadium catalog checks passed:101 identities, prices and access-only rules."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
