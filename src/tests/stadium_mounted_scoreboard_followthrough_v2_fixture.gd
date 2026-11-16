extends RefCounted
## Explicit followthrough-v2 earned fixture. Historical season fixture remains unchanged.
## Same 22 funded seasons and public purchase/apply operations, current earned pennant counts.

var entry: Dictionary = {}
var journal: Dictionary = {}
var history: Array = []
var played: Dictionary = {}
var balance: int = 0
var home_games: int = 0
var _tampered_home: bool = false


func prepare(app: SeasonApp, check: Callable) -> void:
	check.call(StadiumMountedScoreboardLayout.RUNTIME_READY, "production mounted15 gate is enabled")
	var helper: Node = load("res://src/tests/stadium_scoreboard_save_test.gd").new()
	app.season = helper._fund_boards()
	check.call(helper._failures == 0, "twenty-two scheduled career seasons fund actual purchases")
	helper.free()
	var season: SeasonState = app.season
	check.call(season.career.runs.size() == 22 and season.career.balance() == 4315,
		"funding is exactly the existing earned career fixture")
	check.call(ClubConstruction.buy_walls(season, "ST-024", 20,
		ClubPlayers.assets(season.career).revision()).ok, "actual standard wall copies purchased")
	for row: Array in [["ST-024-L", 8], ["ST-024-T", 1]]:
		check.call(ClubConstruction.buy_wall_pieces(season, row[0], row[1],
			ClubPlayers.assets(season.career).revision()).ok, "actual independent wall pieces purchased")
	check.call(ClubConstruction.buy_scoreboard(season, "ST-090", 2,
		ClubPlayers.assets(season.career).revision()).ok, "qualified electronic and spare purchased")
	history = season.career.runs.duplicate(true)
	app.begin_season(443, true, true, true)
	season = app.season
	check.call(season.phase == SeasonState.Phase.DRAFT and season.season_seed == 443
		and season.career.runs.size() == 23, "normal owned-player season starts before any draft pick")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	layout = StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(layout, ledger.surface_owned(), true)))
	var proposal: Dictionary = StadiumAdvancedWallManifest.suggest(
		"right_shelf", "ST-024", ledger.construction(), ledger.wall_pieces().stock)
	check.call(proposal.ok, "paid exact-height wall recipe has all required owned copies")
	if not proposal.ok:
		return
	layout.advanced_back = proposal.manifest
	layout = StadiumMountedScoreboardLayout.upgrade(layout, ledger.construction(),
		ledger.wall_pieces(), ledger.surface_owned(), ledger.view().land, ledger.scoreboards())
	layout.scoreboards = [{"copy": _copy(ledger.scoreboards().copies, "ST-090"),
		"item": "ST-090", "model": "electronic-v2", "site": StadiumScoreboardMountCatalog.CENTER_SITE,
		"mount_profile": StadiumScoreboardMountCatalog.CENTER_PROFILE}]
	check.call(StadiumOwnedLayout.validate(layout, ledger.construction(), ledger.wall_pieces(),
		ledger.surface_owned(), ledger.view().land, ledger.scoreboards()).ok,
		"mounted15 validates against three separately paid inventories")
	var revision: int = ledger.revision()
	check.call(ClubConstruction.save_draft(season, layout, revision).ok,
		"normal public workflow persists the exact mounted15 draft")
	check.call(ClubConstruction.apply_draft(season, layout, revision + 1).ok,
		"normal public Apply freezes entry14 without direct snapshot injection")
	ledger = ClubPlayers.assets(season.career)
	entry = season.home_property.duplicate(true)
	journal = ledger.to_data()
	balance = season.career.balance()
	check.call(entry.get("version") == 14 and entry.layout.version == 15
		and ClubCareer.same(entry.layout, layout) and StadiumLayoutSnapshot.matches(entry, ledger),
		"applied entry14 is exactly bound to the paid journal prefix")
	_validate_inventory(season, check)
	var restored: SeasonState = SeasonSave.restore()
	check.call(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(season)), "public Apply survives a real pre-draft save/reload")
	if restored != null:
		app.season = restored


func _copy(copies: Dictionary, item: String) -> String:
	var keys: Array = copies.keys()
	keys.sort()
	for key: String in keys:
		if copies[key].item == item:
			return key
	return ""


func validate_prepared(season: SeasonState, check: Callable) -> void:
	check.call(season != null, "checkpoint restores through the ordinary validated save reader")
	if season == null:
		return
	check.call(season.season_seed == 443 and season.phase == SeasonState.Phase.DRAFT
		and season.career.runs.size() == 23 and season.picks.is_empty(),
		"checkpoint is the exact earned pre-draft mounted fixture")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	check.call(ledger != null and StadiumLayoutSnapshot.matches(season.home_property, ledger),
		"checkpoint retains exact paid-prefix ownership")
	if ledger == null:
		return
	check.call(season.home_property.get("version") == 14
		and season.home_property.get("layout", {}).get("version") == 15,
		"checkpoint preserves mounted entry14 / layout15")
	_validate_inventory(season, check)


func _validate_inventory(season: SeasonState, check: Callable) -> void:
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var stock: StadiumStock = ledger.construction()
	var counts: Dictionary = {}
	for copy: Dictionary in stock.copies.values():
		counts[copy.source] = int(counts.get(copy.source, 0)) + 1
	# ClubCareer.start now adopts prospective pennants; every one of the 22
	# ordinary champion saves delivers one. Historical total23 excluded these22.
	check.call(counts == {"starter-v1": 3, "purchase-v1": 20,
		StadiumPennantRewards.SOURCE: 22} and stock.copies.size() == 45,
		"v2 owns exactly three starters, twenty paid walls and twenty-two earned pennants")
	for id: String in StadiumCatalog.STARTERS:
		check.call(stock.copies.get("starter-v1:" + id, {}).get("item") == id,
			"original starter identity retained: " + id)
	for copy: Dictionary in stock.copies.values():
		if copy.source == "purchase-v1":
			check.call(copy.item == "ST-024", "all twenty construction purchases are standard walls")
	check.call(StadiumPennantRewards.delivered(season.career, ledger)
		and stock.pennant_count() == 22 and stock.plaque_count() == 0,
		"earned pennants match all authoritative championship records, with no invented awards")
	check.call(ledger.wall_pieces().stock.copies.size() == 9
		and ledger.scoreboards().copies.size() == 2 and season.career.balance() < 4315,
		"paid wall pieces and scoreboard spare retain original exact counts and earned balance")
	print("MOUNTED_V2 inventory=", JSON.stringify({"construction": stock.copies.size(),
		"sources": counts, "wall_pieces": ledger.wall_pieces().stock.copies.size(),
		"scoreboards": ledger.scoreboards().copies.size(), "balance": season.career.balance()}))
