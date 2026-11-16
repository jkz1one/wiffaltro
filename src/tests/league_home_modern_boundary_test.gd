extends Node
## Fully valid alternate-family fixtures are shape examples, never paid owner grants.
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var origin: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	var session: Dictionary = {"league": "dugout", "tier": 0}
	check(origin.get("version") == 8 and origin.get("layout", {}).get("version") == 40
		and origin.layout.base_version == 12, "actual constructor is flat surface8/family40/base12")
	check(StadiumLayoutSnapshot.valid(origin) and Live.modern_origin(origin), "complete exact modern origin")
	check(Live.modern_origin(JSON.parse_string(JSON.stringify(origin, "", true, true))), "JSON origin equality")
	for league: String in Live.BASE_LEAGUES:
		session.league = league
		check(Live.supported(origin, session), league + " explicit Base scope")
	session.league = "dugout"
	var changed: ClubAssetLedger = ledger.fork()
	changed._stadium_active = StadiumMasteryBannerItems.upgrade(origin.layout)
	var later: Dictionary = StadiumLayoutSnapshot.capture(changed, true)
	check(StadiumLayoutSnapshot.valid(later) and later.layout.version == 41, "valid later family41 fixture")
	check(Live.supported(later, session) and not Live.modern_origin(later),
		"named complete flat41 shape admitted; exact paid grant still required")
	changed = ledger.fork()
	var base: Dictionary = StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), [])
	base = StadiumSurfaceLayout.terrain_upgrade(base, [])
	changed._stadium_active = StadiumSalvageCarItems.upgrade(base)
	changed._stadium_active.salvage_cars = origin.layout.salvage_cars.duplicate(true)
	var terrain: Dictionary = StadiumLayoutSnapshot.capture(changed, true)
	check(StadiumLayoutSnapshot.terrain_valid(terrain) and terrain.get("version") == 28
		and terrain.layout.version == 40, "valid explicit terrain28/family40 fixture")
	check(not Live.supported(terrain, session), "valid physical terrain needs separate composition")
	changed = ledger.fork()
	changed._stadium_active.salvage_cars = []
	var empty_car: Dictionary = StadiumLayoutSnapshot.capture(changed, true)
	check(StadiumLayoutSnapshot.valid(empty_car), "valid independently stripped placement shape")
	check(Live.supported(empty_car, session) and not Live.paid_modern_clearance(changed),
		"cleared shape alone lacks paid replay admission authority")
	var fixture: Dictionary = origin.duplicate(true)
	fixture.version = 9
	fixture.environment = StadiumFixtureEnvironment.capture(origin, 38200, 3)
	check(StadiumLayoutSnapshot.valid(fixture), "valid surface9 day fixture")
	check(not Live.supported(fixture, session), "fixture cannot impersonate season entry")
	var legacy: Dictionary = StadiumLayoutSnapshot.capture(ClubAssetLedger.new(), true)
	check(legacy.version == 3 and legacy.layout.version == 1 and Live.supported(legacy, session),
		"historical original complete home admission unchanged")
	for tier in range(1, 5):
		session.tier = tier
		check(Live.supported(origin, session), "proven modern tier shape; earned authority still required")
	session.tier = 0
	for league: String in ["standard", "dynasty", "unknown"]:
		session.league = league
		check(not Live.supported(origin, session), "separate league route " + league)
	check(ClubCareer.same(origin, StadiumLayoutSnapshot.capture(ledger, true)),
		"negative shape fixtures never mutate source ledger")
	print("MODERN_HOME_BOUNDARY: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
