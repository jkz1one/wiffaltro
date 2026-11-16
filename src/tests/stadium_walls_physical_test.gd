extends "res://src/tests/stadium_physical_test.gd"
## Two real paid deeper-center games with exact report10 ownership and geometry replay.

var _owned_layout: Dictionary = {}


func _complete_boundary() -> bool:
	return true


func _tamper(report: Dictionary, source: MatchState) -> void:
	super._tamper(report, source)
	_check(report.version == 10 and report.surfaces.size() == report.plays.size(),
		"every play carries an explicit boundary/owned-surface record")
	var index: int = -1
	for row in range(report.surfaces.size()):
		if not report.surfaces[row].events.is_empty():
			index = row
			break
	_check(index >= 0, "real game actually exercises at least one field surface")
	if index < 0:
		return
	for patch: Dictionary in [{"source": "foreign"}, {"id": "not-owned"},
		{"surface": "unknown"}, {"kind": "catch"}, {"time": -1}, {"time": true},
		{"position": [1000, 0, 0]}, {"position": [0, NAN, 0]}, {"extra": true}]:
		var bad: Dictionary = report.duplicate(true)
		bad.surfaces[index].events[0].merge(patch, true)
		_check(not PhysicalMatchReport.valid(bad), "malformed or foreign surface event rejects")
	var bad: Dictionary = report.duplicate(true)
	bad.erase("surfaces")
	_check(not PhysicalMatchReport.valid(bad), "complete-boundary report requires its event records")
	bad = report.duplicate(true)
	bad.surfaces = []
	_check(not PhysicalMatchReport.valid(bad), "surface records cannot be stripped from the game")
	bad = report.duplicate(true)
	bad.version = 8
	bad.resolver = PhysicalStadiumReport.LEGACY_RESOLVER
	bad.erase("surfaces")
	_check(not PhysicalMatchReport.valid(bad), "old report version cannot impersonate new boundaries")
	bad = report.duplicate(true)
	bad.property.boundary = "different-graph"
	_check(not PhysicalMatchReport.valid(bad), "unrecognized boundary signature rejects")
	var metadata: Dictionary = PlayRecordExport.field_metadata(
		ContentDB.get_field(PitchBatLab.FIELD_ID), report.property)
	_check(metadata.wall_m == 26 and metadata.wall_sections.size() == 8
		and metadata.property_key == StadiumLayoutSnapshot.key(report.property),
		"QC exports describe actual segmented wall distances and frozen geometry")
	_check(report.property.version == 7 and report.property.environment.mode == "day",
		"wall fixture environment is explicitly frozen and daylight-qualified only")
	bad = report.duplicate(true)
	bad.version = 9
	bad.resolver = PhysicalStadiumReport.RESOLVER
	_check(not PhysicalMatchReport.valid(bad), "report9 cannot carry a recipe-bound wall fixture")
	bad = report.duplicate(true)
	bad.property.version = 6
	bad.property.erase("environment")
	_check(StadiumLayoutSnapshot.valid(bad.property) and not PhysicalMatchReport.valid(bad),
		"season-entry geometry is not a playable fixture environment")
	bad = report.duplicate(true)
	bad.property.layout.walls.back.copies.pop_back()
	_check(not PhysicalMatchReport.valid(bad), "incomplete paid wall invalidates physical evidence")
	bad = report.duplicate(true)
	bad.property.environment.mode = "night"
	_check(not PhysicalMatchReport.valid(bad), "unverified walls cannot claim night eligibility")
	bad = report.duplicate(true)
	bad.property.layout.walls = StadiumWallLayout.propose(bad.property.layout.walls,
		StadiumLayoutSnapshot.ownership(bad.property), "back", "ST-024", "straight").walls
	bad.property.boundary = StadiumWallItems.boundary_signature(bad.property.layout)
	_check(StadiumLayoutSnapshot.valid(bad.property)
		and not PhysicalStadiumReport.matches(bad, source.stadium),
		"another fully owned shape cannot impersonate the frozen match")



func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_infield_ui_test.gd").new()
	var completed: SeasonState = helper._fund_infield()
	_check(helper._failures == 0, "closed funded wall career validates")
	helper.free()
	app.season = completed
	app.begin_season(96, true)
	for row: Array in [["ST-024", 23], ["ST-022", 19], ["ST-023", 19]]:
		_check(ClubConstruction.buy_walls(app.season, row[0], row[1],
			ClubPlayers.assets(app.season.career).revision()).ok, "exact wall-set purchase")
	for id: String in ["ST-063b", "ST-063g"]:
		_check(ClubConstruction.buy_style(app.season, id,
			ClubPlayers.assets(app.season.career).revision()).ok, "independent appearance purchase")
	_owned_layout = StadiumWallItems.upgrade(super._layout())
	var stock: StadiumStock = ClubPlayers.assets(app.season.career).construction()
	for row: Array in [["back", "ST-024"], ["left", "ST-022"], ["right", "ST-023"]]:
		var proposal: Dictionary = StadiumWallLayout.propose(
			_owned_layout.walls, stock, row[0], row[1], "deeper_center")
		_check(proposal.ok, "complete exact owned recipe")
		_owned_layout.walls = proposal.walls
	_owned_layout.styles = {"line": "", "grass": "ST-063b"}
	_owned_layout.ground = "ST-063g"


func _layout() -> Dictionary:
	return _owned_layout.duplicate(true)


func _report_version() -> int:
	return 10


func _verification_seed(source: MatchState) -> int:
	return int(source.stadium.environment.seed)
