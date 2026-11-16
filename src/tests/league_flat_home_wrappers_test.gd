extends Node
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
const Fixture = preload("res://src/tests/league_flat_home_fixture.gd")
var checks: int = 0
var failures: int = 0
var completed: Array = []
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	for version: int in Fixture.ADAPTERS:
		var before: int = failures
		var paid: ClubAssetLedger = Fixture.ledger(version)
		if not check(paid != null, "real paid journal wrapper " + str(version)):
			continue
		var home: Dictionary = StadiumLayoutSnapshot.capture(paid, true)
		if not check(not home.is_empty() and home.get("version") == 8, "complete snapshot8 " + str(version)):
			continue
		check(home.layout.version == version and home.layout.family == Live.FLAT_FAMILIES[version]
			and Assets.layout_adapted(home.layout) and Live.flat_shared_home(home), "exact named flat family " + str(version))
		check(StadiumLayoutSnapshot.matches(home, paid) and home.boundary == StadiumOwnedLayout.boundary_signature(home.layout)
			and home.geometry == StadiumOwnedLayout.geometry(home.tier, home.layout), "full paid geometry and boundary " + str(version))
		var extra: int = 1 if version >= 29 and version <= 38 or version >= 40 else 0
		var cost: int = 600 if version >= 29 and version <= 38 else (190 if version >= 40 else 0)
		check(paid.revision() == 3 + extra and paid.balance() == 9960 - cost and home.layout.obstacles.size() == 1
			and home.inventory.copies.has("purchase:flat-obstacle:0"), "same paid40CB copy retained " + str(version))
		if version >= 40:
			check(home.layout.salvage_cars.is_empty() and home.inventory.copies.has(StadiumStock.SALVAGE_COPY) and paid.view().salvage_cleared, "modern wrappers retain paid-clear original car ownership " + str(version))
		check(Live.flat_shared_home(JSON.parse_string(JSON.stringify(home, "", true, true))), "complete JSON named wrapper " + str(version))
		for field: String in ["inventory", "surface_access", "boundary", "geometry", "revision"]:
			var bad: Dictionary = home.duplicate(true)
			bad.erase(field)
			check(not Live.flat_shared_home(bad), "missing complete " + field + " " + str(version))
		var bad: Dictionary = home.duplicate(true)
		bad.layout.family += "-foreign"
		check(not Live.flat_shared_home(bad), "wrong family identity " + str(version))
		bad = home.duplicate(true)
		bad.layout.version = 18 if version != 18 else 19
		check(not Live.flat_shared_home(bad), "numeric version cannot replace named adapter " + str(version))
		bad = home.duplicate(true)
		bad.layout.obstacles[0].copy = "not-owned"
		check(not Live.flat_shared_home(bad), "unowned installed copy " + str(version))
		bad = home.duplicate(true)
		bad.inventory.copies.erase("purchase:flat-obstacle:0")
		check(not Live.flat_shared_home(bad), "lost installed paid copy " + str(version))
		if version != 12:
			bad = home.duplicate(true)
			bad.layout.base_version = 17
			check(not Live.flat_shared_home(bad), "inherited physical-terrain base excluded " + str(version))
		for wrong: int in [9, 13, 28, 29, 46, 47, 51]:
			bad = home.duplicate(true)
			bad.version = wrong
			check(not Live.flat_shared_home(bad), "separate snapshot contract " + str(wrong))
		if before == failures: completed.append(version)
		print("FLAT_WRAPPER ", version, " complete=", before == failures)
	check(completed.size() == 29, "all29 named wrappers qualified")
	print("FLAT_HOME_WRAPPERS checks=", checks, " failures=", failures, " wrappers=", completed.size(), " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)
