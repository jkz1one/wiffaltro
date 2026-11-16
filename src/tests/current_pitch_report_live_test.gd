extends "res://src/tests/doubleheader_detached_workload_live_test.gd"
## Authored finite native gate. No owner saves, publication or external writes.


func _ready() -> void:
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("doubleheader"), true)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "isolated fixture draft")
	var source: MatchState = MatchState.create(season._make_team(1, 0), season._make_team(0, 0))
	source.league_rules = LeagueRules.capture("doubleheader")
	source.pitch_catalog = WorkingPitchCatalog.signature()
	source.home_team.track_bases = true
	_bind(source.away_team, _paid_bank(["C02", "A10"]), 0, {})
	_bind(source.home_team, _paid_bank(["C02", "C02"]), 0, {})
	for team: TeamMatchState in [source.away_team, source.home_team]:
		team.pitch_catalog = source.pitch_catalog
		for player: PlayerMatchState in team.roster:
			player.definition = player.definition.duplicate(true) as PlayerDefinition
			player.definition.starting_pitches.assign([
				WorkingPitchCatalog.get_recipe(WorkingPitchCatalog.new_ids()[0])])
	var copied: MatchState = PhysicalMatchRequest.capture(source)
	check(copied != null and copied.pitch_catalog == source.pitch_catalog,
		"public request retains catalog through cloned teams")
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started: bool = runner.start(source, 443)
	check(started, "current public runner starts")
	if started:
		for frame in range(300000):
			await get_tree().physics_frame
			if not report.is_empty() or not errors.is_empty():
				break
	check(not report.is_empty() and errors.is_empty(), "finite current completion " + str(errors))
	if not report.is_empty():
		check(report.version == CurrentPhysicalMatchReport.VERSION, "public capture dispatches29")
		check(CurrentPhysicalMatchReport.matches(report, source), "actual releases bind source")
		check(CurrentPhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true)),
			source.pitch_catalog), "actual release JSON")
		check(not PhysicalDoubleheaderReport.valid(report), "new release not old report28")
		var bad_source: MatchState = PhysicalMatchRequest.capture(source)
		bad_source.pitch_catalog = "wrong"
		check(not CurrentPhysicalMatchReport.matches(report, bad_source), "source catalog mismatch")
		bad_source = PhysicalMatchRequest.capture(source)
		bad_source.away_team.roster[0].definition.starting_pitches.assign([
			ContentDB.get_pitch(&"pitch.overhand_four_seam")])
		check(not CurrentPhysicalMatchReport.matches(report, bad_source), "source recipe mismatch")
		var archive: SeasonPhysicalFixtures = SeasonPhysicalFixtures.new()
		archive.reports = [{"fixture": 0, "request": "wrong", "report": report}]
		check(archive.resolve(season, {"id": 0, "away": 1, "home": 0, "round": 0}).is_empty(),
			"current report cannot publish with old source or wrong request")
	runner.cancel()
	runner.queue_free()
	print("Current pitch live report checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
