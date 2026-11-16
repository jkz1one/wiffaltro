extends RefCounted
## Shared real paid fixture and immutable settlement audits for the normal season tests.

var entry: Dictionary = {}
var journal: Dictionary = {}
var history: Array = []
var played: Dictionary = {}
var balance: int = 0
var home_reports: int = 0
var _tampered_home: bool = false


func prepare(app: SeasonApp, check: Callable, legacy_venues: bool = false) -> void:
	check.call(StadiumScoreboardLayout.RUNTIME_READY, "production complete14 gate is enabled")
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
	if legacy_venues:
		_retain_historical_venues(app, check)
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
	layout.scoreboards = [{"copy": _copy(ledger.scoreboards().copies, "ST-090"),
		"item": "ST-090", "model": "electronic-v2", "site": "BOARD-RIGHT-v2"}]
	check.call(StadiumOwnedLayout.validate(layout, ledger.construction(), ledger.wall_pieces(),
		ledger.surface_owned(), ledger.view().land, ledger.scoreboards()).ok,
		"complete14 validates against three separately paid inventories")
	var revision: int = ledger.revision()
	check.call(ClubConstruction.save_draft(season, layout, revision).ok,
		"normal public workflow persists the exact complete14 draft")
	check.call(ClubConstruction.apply_draft(season, layout, revision + 1).ok,
		"normal public Apply freezes entry12 without direct snapshot injection")
	ledger = ClubPlayers.assets(season.career)
	entry = season.home_property.duplicate(true)
	journal = ledger.to_data()
	balance = season.career.balance()
	check.call(entry.get("version") == 12 and entry.layout.version == 14
		and ClubCareer.same(entry.layout, layout) and StadiumLayoutSnapshot.matches(entry, ledger),
		"applied entry12 is exactly bound to the paid journal prefix")
	check.call(ledger.construction().paid_count() == 23
		and ledger.construction().pennant_count() == 22
		and ledger.construction().copies.size() == 45
		and ledger.wall_pieces().stock.copies.size() == 9 and ledger.scoreboards().copies.size() == 2
		and balance < 4315, "paid copies and unused spares exist without invented currency")
	var restored: SeasonState = SeasonSave.restore()
	check.call(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(season)), "public Apply survives a real pre-draft save/reload")
	if restored != null:
		app.season = restored


func observe(season: SeasonState, fixture: Dictionary, report: Dictionary,
	before: Dictionary, check: Callable) -> void:
	check.call(ClubCareer.same(before, SeasonSave.snapshot(season)),
		"a completed human physical report alone cannot settle or pay the live season")
	check.call(PhysicalMatchReport.valid(report), "normal human physical report validates")
	if report.is_empty():
		return
	var expected: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
	check.call(PhysicalStadiumReport.matches(report, expected)
		and report.seed == SeasonPhysicalFixtures.seed_for(season, fixture)
		and report.field == String(SeasonState.field_for_fixture(fixture).id),
		"real human game preserves the scheduled field, fixture seed and exact property")
	if not expected.is_empty():
		home_reports += 1
		check.call(report.version == 12 and report.property.version == 13
			and report.property.layout.version == 14
			and report.property.environment.fixture == fixture.id
			and report.property.environment.seed == SeasonPhysicalFixtures.seed_for(season, fixture)
			and report.property.environment.mode == "day" and report.property.environment.profile == "",
			"human home executes actual daylight report12 on the exact scheduled fixture13")
		check.call(StadiumLayoutSnapshot.key(report.property) != StadiumLayoutSnapshot.key(entry)
			and StadiumLayoutSnapshot.matches(report.property, ClubPlayers.assets(season.career)),
			"fixture-specific played key differs from entry key while retaining paid ownership")
		check.call(PhysicalStadiumReport.core(report).version == 7
			and report.surfaces.size() == report.plays.size(),
			"report12 retains full original baseball and per-play surface evidence")
	else:
		check.call(report.version == 7 and not report.has("property"),
			"away and neutral human games retain the ordinary park and report7")
	check.call(not played.has(int(fixture.id)), "each human fixture executes once for settlement")
	played[int(fixture.id)] = {"property": StadiumLayoutSnapshot.key(expected),
		"away_runs": report.away_runs, "home_runs": report.home_runs,
		"performance": report.performance.duplicate(true)}


func checkpoint(season: SeasonState, check: Callable) -> void:
	check.call(ClubCareer.same(entry, season.home_property)
		and ClubCareer.same(journal, ClubPlayers.assets(season.career).to_data()),
		"pending process checkpoint retains exact entry12 and every paid inventory")
	var pending: Dictionary = season.physical.pending
	check.call(not pending.is_empty() and pending.human.size() == 15,
		"pending round persists the normal complete-property human payload")
	if pending.is_empty():
		return
	var fixture: Dictionary = season.pending_fixture()
	check.call(pending.human[0] == fixture.id and pending.human[14]
		== StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(season, fixture)),
		"pending home key is the exact scheduled fixture13 identity")
	for row: Dictionary in pending.reports:
		check.call(row.report.version == 7 and not row.report.has("property"),
			"real opponent child replays entry12 checkpoint without borrowing the human venue")
	var restored: SeasonState = SeasonSave.restore()
	check.call(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(season)), "pending child evidence and owned entry reload together")


func audit(season: SeasonState, check: Callable) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	check.call(saved.version == 59 and ClubCareer.same(entry, season.home_property)
		and StadiumLayoutSnapshot.matches(season.home_property, ledger),
		"settled schema59 keeps immutable complete14 entry12 and exact paid-prefix authority")
	check.call(ClubCareer.same(journal, ledger.to_data())
		and ClubCareer.same(entry.inventory, ledger.construction().to_data())
		and ClubCareer.same(entry.wall_piece_inventory, ledger.wall_pieces().to_data())
		and ClubCareer.same(entry.scoreboard_inventory, ledger.scoreboards().to_data()),
		"rounds neither duplicate, consume nor silently edit paid placed or stored copies")
	check.call(ClubCareer.same(history, season.career.runs.slice(0, history.size())),
		"new physical results cannot rewrite any of the twenty-two funding archives")
	var rewards: Dictionary = {}
	var cash: int = 0
	for result: Dictionary in season.player_results:
		var fixture: Dictionary = _fixture(season, int(result.id))
		check.call(not fixture.is_empty(), "played ID resolves by identity in interleaved schedule")
		if fixture.is_empty():
			continue
		var key: String = StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(season, fixture))
		check.call(result.property == key and played.has(int(result.id)),
			"settled human result binds the exact observed home, away or neutral fixture")
		if played.has(int(result.id)):
			for field: String in ["property", "away_runs", "home_runs", "performance"]:
				check.call(ClubCareer.same(result[field], played[int(result.id)][field]),
					"settlement preserves actual human physical evidence: " + field)
		var won: bool = SeasonState._winner(result) == 0
		rewards[str(int(result.id))] = won
		cash += 18 if won else 12
	check.call(ClubCareer.same(rewards, season.build._bank.view().rewards)
		and season.cash() == cash, "each actual human game earns its ordinary reward exactly once")
	for row: Dictionary in season.physical.reports:
		var fixture: Dictionary = _fixture(season, int(row.fixture))
		check.call(not fixture.is_empty() and fixture.home != 0 and fixture.away != 0
			and row.report.version == 7 and not row.report.has("property"),
			"opponent physical archives remain separate from the human-owned home")
	var stored: Dictionary = season.career.runs[-1].player_progress
	var progress: Dictionary = ClubPlayerProgress.capture_for(season, stored)
	check.call(stored.get("version") == ClubPlayerLegend.VERSION,
		"current complete14 results retain full Legend player evidence")
	check.call(not progress.is_empty() and progress.games.size() == season.player_results.size()
		and ClubCareer.same(progress, season.career.runs[-1].player_progress),
		"actual complete14 games retain exact career player-unlock evidence")
	var receipt: Dictionary = season.career.runs[-1].receipt
	check.call(season.career.balance() == balance + int(receipt.get("total", 0)),
		"paid inventory debit remains fixed and only the derived finish can award Club Bucks")
	if home_reports > 0 and not _tampered_home:
		_tampered_home = true
		_reject_tampering(saved, check)
	if season.phase == SeasonState.Phase.COMPLETE:
		_complete(season, saved, check)
	print("SCOREBOARD_SEASON games=", season.player_results.size(), " home_report12=", home_reports,
		" child_report7=", season.physical.reports.size(), " entry=", StadiumLayoutSnapshot.key(entry))


func _complete(season: SeasonState, saved: Dictionary, check: Callable) -> void:
	check.call(home_reports == 5 and season.results.size() == 33,
		"full real bracket includes all five owned-home report12 games")
	var run: Dictionary = season.career.runs[-1]
	check.call(run.status == "completed" and not run.receipt.is_empty()
		and ClubCareer.same(run.proof, ClubSeasonRecord.capture(season))
		and ClubCareer.same(run.receipt, ClubSeasonRecord.receipt(run.proof, false)),
		"completed archive and repeat-career reward derive only from the actual physical bracket")
	var club: ClubCareer = season.career.fork()
	check.call(club.close(season) and club.current == 0,
		"closing the completed career archives it without abandonment or another reward")
	var restored: ClubCareer = ClubCareer.from_data(club.to_data())
	check.call(restored != null and ClubCareer.same(restored.runs, season.career.runs)
		and restored.balance() == season.career.balance()
		and ClubCareer.same(ClubPlayers.assets(restored).to_data(), journal),
		"closed career independently replays archive, earned reward and original paid inventory")
	var before: int = season.career.balance()
	check.call(SeasonSave.save(season) and SeasonSave.save(season)
		and season.career.balance() == before
		and ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"repeated complete-season saves cannot repay or alter the owner")
	var loaded: SeasonState = SeasonSave.restore()
	check.call(loaded != null and ClubCareer.same(saved, SeasonSave.snapshot(loaded)),
		"full bracket and owned complete14 field restore through the normal save reader")


func _reject_tampering(saved: Dictionary, check: Callable) -> void:
	var bad: Dictionary = saved.duplicate(true)
	for result: Dictionary in bad.results:
		if not result.property.is_empty():
			result.property = StadiumLayoutSnapshot.key(entry)
			break
	check.call(SeasonSave._decode(bad) == null,
		"entry12 identity cannot replace the settled fixture13 played key")
	bad = saved.duplicate(true)
	bad.results[-1].erase("property")
	check.call(SeasonSave._decode(bad) == null,
		"new-schema settled result cannot omit its field key")
	for field: String in ["inventory", "wall_piece_inventory", "scoreboard_inventory"]:
		bad = saved.duplicate(true)
		bad.home_property.erase(field)
		check.call(SeasonSave._decode(bad) == null,
			"settled save cannot discard frozen paid ownership: " + field)
	bad = saved.duplicate(true)
	bad.home_property.layout.scoreboards[0].copy = "scoreboard:unpaid:0"
	check.call(SeasonSave._decode(bad) == null,
		"settled field cannot substitute an unowned electronic")


func _fixture(season: SeasonState, id: int) -> Dictionary:
	for fixture: Dictionary in season.schedule + season.semifinals + [season.final_fixture]:
		if int(fixture.get("id", -1)) == id:
			return fixture
	return {}


func _copy(copies: Dictionary, item: String) -> String:
	var keys: Array = copies.keys()
	keys.sort()
	for key: String in keys:
		if copies[key].item == item:
			return key
	return ""


func _retain_historical_venues(app: SeasonApp, check: Callable) -> void:
	# This process test explicitly qualifies report7 parks and complete14 report12 home.
	# Current NPC human settlement has its own terminal-evidence contract: never synthesize it
	# from an automated preparation report. Exercise the supported historical save59 profile.
	var current: Dictionary = SeasonSave.snapshot(app.season)
	check.call(current.version == 63 and not app.season.npc_venues.is_empty()
		and not app.season.final_venue.is_empty(), "current startup freezes both venue authorities")
	var cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(current, "", true, true)))
	check.call(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), current),
		"current63 fixture cold-reloads before explicit historical projection")
	for field: String in ["npc_venues", "final_venue"]:
		var bad: Dictionary = current.duplicate(true)
		bad.erase(field)
		check.call(SeasonSave._decode(bad) == null,
			"current63 cannot silently drop frozen venue authority: " + field)
	var legacy: Dictionary = current.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var restored: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(legacy, "", true, true)))
	check.call(restored != null, "historical complete14 process fixture decodes exact save59")
	for field: String in ["npc_venues", "final_venue"]:
		var smuggled: Dictionary = legacy.duplicate(true)
		smuggled[field] = current[field]
		check.call(SeasonSave._decode(smuggled) == null,
			"historical59 rejects later venue authority smuggling: " + field)
	if restored == null:
		return
	check.call(restored.npc_venues.is_empty() and restored.final_venue.is_empty()
		and ClubCareer.same(restored.home_property, app.season.home_property)
		and ClubCareer.same(restored.career.to_data(), app.season.career.to_data())
		and ClubCareer.same(restored.schedule, app.season.schedule),
		"legacy59 preserves exact owned home, paid/earned career and schedule without venues")
	check.call(SeasonSave.save(restored), "explicit historical fixture persists through public save")
	app.season = restored
