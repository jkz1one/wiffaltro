extends "res://src/tests/stadium_complete_physical_test.gd"
## Paid poles through two actual seeded night games, with exact replay and report binding.


var _light_receipt_start: int = 4


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_net_ui_test.gd").new()
	var completed: SeasonState = helper._fund_net()
	_check(helper._failures == 0, "synthetic closed light funding validates")
	helper.free()
	app.season = completed
	app.begin_season(96, true)
	for index in range(4):
		_check(ClubConstruction.buy_copy(app.season, "ST-037", _light_receipt_start + index).ok,
			"separately earned yard pole purchase")

	_check(app.season.career.balance() == 245
		and ClubPlayers.assets(app.season.career).revision() == 8,
		"four paid poles cost560 after four earned pennants")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumLightItems.upgrade(super._layout())
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	for index in range(4):
		layout.lights.append({"copy": "purchase:stadium-buy:%d:0" % (_light_receipt_start + index),
			"site": sites[index]})
	return layout


func _verification_seed(source: MatchState) -> int:
	return int(source.stadium.environment.seed)


func _select_fixture(season: SeasonState, game: Dictionary) -> bool:
	return game.home == 0 and StadiumFixtureEnvironment.is_night_seed(
		SeasonPhysicalFixtures.seed_for(season, game))


func _tamper(report: Dictionary, source: MatchState) -> void:
	super._tamper(report, source)
	_check(report.property.version == 5 and report.property.environment.mode == "night"
		and report.seed == report.property.environment.seed, "night fixture environment is frozen")
	var bad: Dictionary = report.duplicate(true)
	var wrong_seed: int = int(report.seed) + 1
	while not StadiumFixtureEnvironment.is_night_seed(wrong_seed):
		wrong_seed += 1
	bad.property.environment = StadiumFixtureEnvironment.capture(
		bad.property, wrong_seed, int(report.property.environment.fixture))
	_check(StadiumLayoutSnapshot.valid(bad.property) and not PhysicalMatchReport.valid(bad),
		"otherwise eligible different night seed rejects")
	var probe: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(probe)
	_check(not probe.start(source, wrong_seed), "runner cannot start an alternate seeded environment")
	probe.cancel()
	probe.queue_free()
	bad = report.duplicate(true)
	bad.property.environment.mode = "day"
	_check(not PhysicalMatchReport.valid(bad), "night cannot be relabeled after play")
