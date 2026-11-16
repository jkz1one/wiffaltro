extends "res://src/tests/stadium_physical_test.gd"
## Real 22-season ownership, two production games and exact report12 replay/authority.

var _owned_layout: Dictionary = {}
var _season: SeasonState


func _begin(app: SeasonApp) -> void:
	_check(StadiumScoreboardLayout.RUNTIME_READY, "complete scoreboard production gate is open")
	var helper: Node = load("res://src/tests/stadium_scoreboard_save_test.gd").new()
	app.season = helper._fund_boards()
	_check(helper._failures == 0, "actual22-season saved career funding validates")
	helper.free()
	var season: SeasonState = app.season
	_check(
		(
			ClubConstruction
			. buy_walls(season, "ST-024", 20, ClubPlayers.assets(season.career).revision())
			. ok
		),
		"paid standard wall and stored spare"
	)
	for row: Array in [["ST-024-L", 8], ["ST-024-T", 1]]:
		_check(
			(
				ClubConstruction
				. buy_wall_pieces(
					season, row[0], row[1], ClubPlayers.assets(season.career).revision()
				)
				. ok
			),
			"paid independent variant and spare"
		)
	for item: String in StadiumScoreboardCatalog.IDS:
		_check(
			(
				ClubConstruction
				. buy_scoreboard(
					season,
					item,
					2 if item == "ST-090" else 1,
					ClubPlayers.assets(season.career).revision()
				)
				. ok
			),
			"paid board tier and electronic spare"
		)
	app.begin_season(96, true)
	_season = app.season
	var ledger: ClubAssetLedger = ClubPlayers.assets(_season.career)
	_owned_layout = StadiumScoreboardLayout.upgrade(
		StadiumAdvancedWallLayout.upgrade(
			StadiumSurfaceLayout.upgrade(super._layout(), ledger.surface_owned(), true)
		)
	)
	var proposal: Dictionary = StadiumAdvancedWallManifest.suggest(
		"right_shelf", "ST-024", ledger.construction(), ledger.wall_pieces().stock
	)
	_check(proposal.ok, "exact paid height-wall manifest")
	if not proposal.ok:
		return
	_owned_layout.advanced_back = proposal.manifest
	_owned_layout.scoreboards = [
		{
			"copy": _copy(ledger.scoreboards().copies, "ST-090"),
			"item": "ST-090",
			"model": "electronic-v2",
			"site": "BOARD-RIGHT-v2"
		}
	]
	_check(
		(
			StadiumOwnedLayout
			. validate(
				_owned_layout,
				ledger.construction(),
				ledger.wall_pieces(),
				ledger.surface_owned(),
				ledger.view().land,
				ledger.scoreboards()
			)
			. ok
		),
		"complete paid property validates before production apply"
	)


func _layout() -> Dictionary:
	return _owned_layout.duplicate(true)


func _complete_boundary() -> bool:
	return true


func _report_version() -> int:
	return PhysicalStadiumReport.SCOREBOARD_VERSION


func _verification_seed(source: MatchState) -> int:
	return int(source.stadium.environment.seed)


func _tamper(report: Dictionary, source: MatchState) -> void:
	super._tamper(report, source)
	_check(
		(
			report.version == 12
			and report.resolver == PhysicalStadiumReport.SCOREBOARD_RESOLVER
			and report.property.version == 13
			and report.property.layout.version == 14
			and report.property.environment.mode == "day"
			and report.property.environment.profile == ""
		),
		"report12 binds the exact complete14 daylight fixture13"
	)
	var core: Dictionary = PhysicalStadiumReport.core(report)
	var expected_core: Dictionary = report.duplicate(true)
	expected_core.erase("property")
	expected_core.erase("surfaces")
	expected_core.version = PhysicalMatchReport.BASE_VERSION
	expected_core.resolver = PhysicalMatchReport.BASE_RESOLVER
	_check(
		(
			core.version == 7
			and core.resolver == PhysicalMatchReport.BASE_RESOLVER
			and PhysicalMatchReport.valid(core)
			and JSON.stringify(core, "", true, true)
			== JSON.stringify(expected_core, "", true, true)
		),
		"new venue preserves exact report7 keys and canonical baseball evidence"
	)
	_wrapper_edges(report)
	_inventory_edges(report)
	_contacts(report)
	_fixture_authority(report, source)
	_save_edges(source)
	_runner_edges(source)
	var metadata: Dictionary = PlayRecordExport.field_metadata(
		ContentDB.get_field(PitchBatLab.FIELD_ID), report.property
	)
	var graph: StadiumRecipeBoundary = StadiumOwnedLayout.graph_for(report.property.layout)
	_check(
		(
			metadata.get("wall_m") == 27.5
			and metadata.get("wall_sections", []).size() == graph.segments().size()
			and metadata.get("property_key") == StadiumLayoutSnapshot.key(report.property)
		),
		"QC export uses actual height-wall graph and frozen complete property"
	)


func _wrapper_edges(report: Dictionary) -> void:
	for version: int in [8, 9, 10, 11]:
		var bad: Dictionary = report.duplicate(true)
		bad.version = version
		bad.resolver = {
			8: PhysicalStadiumReport.LEGACY_RESOLVER,
			9: PhysicalStadiumReport.RESOLVER,
			10: PhysicalStadiumReport.RECIPE_RESOLVER,
			11: PhysicalStadiumReport.SURFACE_RESOLVER
		}[version]
		if version == 8:
			bad.erase("surfaces")
		_check(
			not PhysicalMatchReport.valid(bad) and PhysicalStadiumReport.core(bad).is_empty(),
			"older report wrapper cannot impersonate complete board ownership"
		)
	var bad: Dictionary = report.duplicate(true)
	bad.property.version = StadiumScoreboardSnapshot.VERSION
	bad.property.erase("environment")
	_check(
		StadiumLayoutSnapshot.valid(bad.property) and not PhysicalMatchReport.valid(bad),
		"entry12 is valid ownership but cannot impersonate fixture13"
	)
	for version: int in [10, 11]:
		var isolated: Dictionary = bad.property.duplicate(true)
		isolated.version = version
		isolated.layout = StadiumScoreboardLayout.base(isolated.layout)
		isolated.geometry = StadiumAdvancedWallLayout.geometry(isolated.tier)
		isolated.erase("scoreboard_inventory")
		if version == 11:
			isolated["environment"] = report.property.environment.duplicate(true)
		_check(
			StadiumAdvancedSnapshot.valid(isolated) and not StadiumLayoutSnapshot.valid(isolated),
			"isolated advanced10/11 and layout13 remain outside production admission"
		)
	for version: Variant in [true, 12.5, 13, 14]:
		bad = report.duplicate(true)
		bad.version = version
		_check(
			(
				not PhysicalMatchReport.valid(bad)
				and PhysicalStadiumReport.core(bad).is_empty()
				and not PhysicalStadiumReport.matches(bad, report.property)
			),
			"malformed and unsupported report ceilings reject consistently"
		)

	bad = report.duplicate(true)
	bad.teams = []
	_check(
		not PhysicalMatchReport.valid(bad) and not PhysicalStadiumReport.valid(bad),
		"validated venue shape never bypasses baseball-evidence validation"
	)


func _inventory_edges(report: Dictionary) -> void:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_season.career)
	for field: String in ["inventory", "wall_piece_inventory", "scoreboard_inventory"]:
		var bad: Dictionary = report.duplicate(true)
		bad.property.erase(field)
		_check(
			not PhysicalMatchReport.valid(bad) and PhysicalStadiumReport.core(bad).is_empty(),
			"validation and core extraction require all three frozen inventories"
		)
	var bad: Dictionary = report.duplicate(true)
	bad.property.layout.scoreboards[0].copy = "scoreboard:invented:0"
	_check(
		not PhysicalMatchReport.valid(bad) and PhysicalStadiumReport.core(bad).is_empty(),
		"validation and core extraction reject invented electronic copies"
	)
	bad = report.duplicate(true)
	bad.property.layout.scoreboards[0].model = "manual-v2"
	_check(not PhysicalMatchReport.valid(bad), "placed electronic model is exact")
	for field: String in ["inventory", "wall_piece_inventory", "scoreboard_inventory"]:
		bad = report.duplicate(true)
		var copies: Dictionary = (
			bad.property[field].stock.copies
			if (field == "wall_piece_inventory")
			else bad.property[field].copies
		)
		var chosen: String = _stored_copy(field, copies, bad.property.layout)
		_check(not chosen.is_empty(), "fixture keeps unused paid copies in every inventory")
		if chosen.is_empty():
			continue
		copies.erase(chosen)
		_check(
			(
				StadiumLayoutSnapshot.valid(bad.property)
				and not StadiumLayoutSnapshot.matches(bad.property, ledger)
				and not PhysicalStadiumReport.matches(bad, report.property)
			),
			"unused inventory is part of exact paid-prefix and frozen fixture identity"
		)


func _contacts(report: Dictionary) -> void:
	_check(
		report.surfaces.size() == report.plays.size(), "all physical plays have bounded contacts"
	)
	var index: int = -1
	for row in range(report.surfaces.size()):
		if not report.surfaces[row].events.is_empty():
			index = row
			break
	_check(index >= 0, "real complete14 game exercises a field surface")
	if index < 0:
		return
	for patch: Dictionary in [
		{"source": "foreign"},
		{"id": "not-owned"},
		{"surface": "unknown"},
		{"kind": "catch"},
		{"time": -1},
		{"time": true},
		{"position": [1000, 0, 0]},
		{"position": [0, NAN, 0]},
		{"extra": true}
	]:
		var bad: Dictionary = report.duplicate(true)
		bad.surfaces[index].events[0].merge(patch, true)
		_check(
			(
				not PhysicalMatchReport.valid(bad)
				and not PhysicalStadiumReport.valid(bad)
				and PhysicalStadiumReport.core(bad).is_empty()
			),
			"public report validation and core extraction reject malformed contacts"
		)
	var bad: Dictionary = report.duplicate(true)
	bad.surfaces[index].events[0].merge(
		{
			"source": "item",
			"id": report.property.layout.scoreboards[0].copy,
			"surface": "wood",
			"role": "DECORATIVE_AFTER_TERMINAL",
			"position": [20, 1, 29],
			"kind": "contact"
		},
		true
	)
	_check(
		not PhysicalMatchReport.valid(bad) and PhysicalStadiumReport.core(bad).is_empty(),
		"decorative primary board is never a contact target, including core extraction"
	)
	for missing: bool in [true, false]:
		bad = report.duplicate(true)
		if missing:
			bad.erase("surfaces")
		else:
			bad.surfaces = []
		_check(not PhysicalMatchReport.valid(bad), "new property cannot omit per-play evidence")


func _fixture_authority(report: Dictionary, source: MatchState) -> void:
	var fixture: Dictionary = {}
	for scheduled: Dictionary in _season.schedule:
		if int(scheduled.id) == int(source.stadium.environment.fixture):
			fixture = scheduled
			break
	_check(not fixture.is_empty(), "frozen fixture ID exists in interleaved schedule")
	if fixture.is_empty():
		return
	_check(
		fixture.id == source.stadium.environment.fixture and fixture.home == 0,
		"environment uses authoritative scheduled fixture index"
	)
	var row: Dictionary = {
		"fixture": fixture.id,
		"request": SeasonPhysicalFixtures.request_key(_season, fixture),
		"report": report
	}
	var resolver: SeasonPhysicalFixtures = SeasonPhysicalFixtures.new()
	resolver.reports.append(row.duplicate(true))
	_check(
		not resolver.resolve(_season, fixture).is_empty(),
		"real report resolves through scheduled request and frozen fixture authority"
	)
	var before: Dictionary = SeasonSave.snapshot(_season)
	for field: String in ["request", "fixture", "seed", "environment"]:
		var wrong: Dictionary = row.duplicate(true)
		match field:
			"request":
				wrong.request = "0".repeat(64)
			"fixture":
				wrong.fixture = (int(fixture.id) + 1) % 30
			"seed":
				wrong.report.seed += 1
			"environment":
				wrong.report.property.environment.fixture = (int(fixture.id) + 1) % 30
		resolver = SeasonPhysicalFixtures.new()
		resolver.reports.append(wrong)
		_check(
			resolver.resolve(_season, fixture).is_empty() and resolver.cursor == 0,
			"foreign request/fixture/seed never becomes reward-eligible"
		)
	_check(
		ClubCareer.same(before, SeasonSave.snapshot(_season)),
		"rejected fixture evidence leaves save and reward state untouched"
	)
	for field: String in ["seed", "mode", "profile"]:
		var bad: Dictionary = report.duplicate(true)
		match field:
			"seed":
				bad.property.environment.seed += 1
			"mode":
				bad.property.environment.mode = "night"
			"profile":
				bad.property.environment.profile = StadiumLightItems.PROFILE
		_check(not PhysicalMatchReport.valid(bad), "fixture remains exact seed and daylight-only")
	var neutral: Dictionary = fixture.duplicate(true)
	neutral["neutral"] = true
	_check(
		StadiumLayoutSnapshot.for_fixture(_season, neutral).is_empty(),
		"neutral playoff routing cannot inherit home construction"
	)
	for away: Dictionary in _season.schedule:
		if away.away == 0:
			var away_snapshot: Dictionary = StadiumLayoutSnapshot.for_fixture(_season, away)
			_check(
				(away_snapshot.is_empty() if _season.npc_venues.is_empty() else
					StadiumNpcSnapshot.matches_fixture(away_snapshot, _season, away))
				and not ClubCareer.same(away_snapshot, report.property),
				"away venue binds its NPC assignment, never the owned home field"
			)
			break


func _save_edges(source: MatchState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(_season)
	var ledger: ClubAssetLedger = ClubPlayers.assets(_season.career)
	_check(
		(
			saved.version == 63
			and saved.home_property.version == 12
			and StadiumLayoutSnapshot.matches(saved.home_property, ledger)
			and StadiumLayoutSnapshot.capture(ledger, false).is_empty()
		),
		"current schema63 owns exact entry12 and cannot lose its complete boundary"
	)
	var loaded: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(saved, "", true, true)))
	_check(
		(
			loaded != null
			and (
				StadiumLayoutSnapshot.key(loaded.home_property)
				== StadiumLayoutSnapshot.key(saved.home_property)
			)
		),
		"entry12 survives saved JSON replay"
	)
	for field: String in ["npc_venues", "final_venue"]:
		var missing: Dictionary = saved.duplicate(true)
		missing.erase(field)
		_check(SeasonSave._decode(missing) == null,
			"current63 cannot omit frozen venue authority: " + field)
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var restored: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(legacy, "", true, true)))
	_check(restored != null and restored.npc_venues.is_empty()
		and restored.final_venue.is_empty()
		and ClubCareer.same(restored.home_property, saved.home_property)
		and ClubCareer.same(restored.career.to_data(), _season.career.to_data()),
		"supported59 retains exact home and career without invented later venues")
	for field: String in ["npc_venues", "final_venue"]:
		var smuggled: Dictionary = legacy.duplicate(true)
		smuggled[field] = saved[field]
		_check(SeasonSave._decode(smuggled) == null,
			"legacy59 rejects later venue authority smuggling: " + field)
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property = source.stadium.duplicate(true)
	_check(SeasonSave._decode(bad) == null, "season home entry never accepts playable fixture13")
	bad = saved.duplicate(true)
	bad.home_property.layout.scoreboards[0].copy = "missing"
	_check(SeasonSave._decode(bad) == null, "unowned home board cannot restore")
	bad = saved.duplicate(true)
	bad.home_property.scoreboard_inventory.copies["scoreboard:invented:0"] = {
		"item": "ST-090", "paid": 160, "source": "purchase-scoreboard-v1"
	}
	_check(
		StadiumLayoutSnapshot.valid(bad.home_property) and SeasonSave._decode(bad) == null,
		"self-consistent unused electronic surplus has no saved purchase authority"
	)


func _runner_edges(source: MatchState) -> void:
	var probe: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(probe)
	_check(
		not probe.start(source, int(source.stadium.environment.seed) + 1),
		"runner refuses mismatched frozen seed before field mutation"
	)
	var entry: MatchState = PhysicalMatchRequest.capture(source)
	entry.stadium = _season.home_property.duplicate(true)
	_check(
		not probe.start(entry, int(source.stadium.environment.seed)),
		"runner refuses entry12 before field mutation"
	)
	_check(
		probe.start(source, int(source.stadium.environment.seed)),
		"normal automated production startup installs complete14 directly"
	)
	if probe._lab != null:
		var lab: PitchBatLab = probe._lab
		_check(
			StadiumBoundaryRuntime.installed(lab, source.stadium),
			"production boundary dispatch verifies exact new world integrity"
		)
		var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
		_check(
			(
				property.boundary is StadiumHeightBoundaryBody
				and lab._ball_play_resolver.segment_observer == property.observe
			),
			"complete property owns one height-aware production observer"
		)
		var model: Node3D = property.board_objects.values()[0]
		var original: Transform3D = model.transform
		model.position.x += 1
		_check(
			not StadiumBoundaryRuntime.installed(lab, source.stadium),
			"matching wall cannot authenticate displaced scoreboard"
		)
		model.transform = original
		lab.set_meta("stadium_candidate_only", false)
		_check(
			not StadiumBoundaryRuntime.installed(lab, source.stadium),
			"candidate marker presence never becomes reward-eligible"
		)
		lab.remove_meta("stadium_candidate_only")
		_check(
			StadiumBoundaryRuntime.installed(lab, source.stadium),
			"original installed property retains exact identity"
		)
	probe.cancel()
	probe.queue_free()


func _stored_copy(field: String, copies: Dictionary, layout: Dictionary) -> String:
	if field == "inventory":
		return _copy(copies, "ST-040")
	if field == "wall_piece_inventory":
		return _copy(copies, "ST-024-T")
	for copy: String in copies:
		if copy != layout.scoreboards[0].copy:
			return copy
	return ""


func _copy(copies: Dictionary, item: String) -> String:
	var keys: Array = copies.keys()
	keys.sort()
	for key: String in keys:
		if copies[key].item == item:
			return key
	return ""
