extends Node
## Complete separate-contract shape fixtures, not paid owner grants or physical play.
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	var legacy: ClubAssetLedger = ClubAssetLedger.new()
	legacy._stadium_active = StadiumAdvancedWallLayout.upgrade(StadiumSurfaceLayout.upgrade(legacy.view().stadium_active, legacy.surface_owned()))
	_exclude(StadiumAdvancedSnapshot.capture(legacy), 10, 13, "closed advanced13")
	var modern: ClubAssetLedger = ClubAssetLedger.new_club()
	modern._stadium_active = StadiumLowWallLayout.upgrade(modern.view().stadium_active, modern.surface_owned())
	_exclude(StadiumLowWallSnapshot.capture(modern), 32, 46, "closed low-wall46")
	modern = ClubAssetLedger.new_club()
	modern._stadium_active = StadiumWaterfallAnimationLayout.upgrade(modern.view().stadium_active, modern.surface_owned())
	_exclude(StadiumWaterfallAnimationSnapshot.capture(modern), 34, 47, "separate animation47")
	var pool: ClubAssetLedger = ClubAssetLedger.new(79, [10000, 10000, 10000, 10000, 10000, 10000],
		[{"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}])
	for item: String in ["ST-079", "ST-006"]:
		var catalog: Dictionary = ClubConstruction.copy_catalog(item)
		var command: Dictionary = {"id": item, "rev": pool.revision(), "op": "stadium_buy", "item": item,
			"quantity": 1, "price_version": catalog.price_version, "through": 6}
		if catalog.progress: command.progress_through = 6
		if not check(pool.commit(command).ok, "actual paid separate Pool fixture copy " + item):
			get_tree().quit(1)
			return
	var base: Dictionary = StadiumSurfaceLayout.upgrade(pool.view().stadium_active, pool.surface_owned())
	base.receiver = "purchase:ST-079:0"
	pool._stadium_active = StadiumPoolOwnedLayout.upgrade(base, pool.construction(), pool.surface_owned(), "backyard", "purchase:ST-006:0")
	_exclude(StadiumPoolOwnedSnapshot.capture(pool), 16, 16, "separate Pool16")
	print("FLAT_HOME_EXCLUSIONS checks=", checks, " failures=", failures, " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)
func _exclude(home: Dictionary, snapshot: int, layout: int, label: String) -> void:
	var valid: bool = false
	match snapshot:
		10: valid = StadiumAdvancedSnapshot.valid(home)
		32: valid = StadiumLowWallSnapshot.valid(home)
		34: valid = StadiumWaterfallAnimationSnapshot.valid(home)
		16: valid = StadiumPoolOwnedSnapshot.valid(home)
	if not check(not home.is_empty() and home.version == snapshot and home.layout.version == layout and valid, label + " complete valid separate snapshot"):
		return
	check(not Live.flat_shared_home(home), label + " stays excluded from flat snapshot8 grammar")
	check(Live.supported(home, {"league": "dugout", "tier": 0}) == (layout in [16, 47]), label + " exact separate-contract admission only")
	var disguised: Dictionary = home.duplicate(true)
	disguised.version = 8
	check(not Live.flat_shared_home(disguised), label + " snapshot renumber cannot bypass named adapter")
