extends "res://src/tests/physical_report_version_guard_test.gd"
## Bounded source fixture only. New recipes are installed synthetically, not earned.
const Fixture = preload("res://src/tests/ac02_public_fixture.gd")


func _ready() -> void:
	var season: SeasonState = Fixture.season()
	check(season != null, "isolated scheduled NPC source")
	if season == null:
		get_tree().quit(1)
		return
	var fixture: Dictionary = Fixture.fixture(season)
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	check(state != null and not state.stadium.is_empty(), "real fixture has retained geometry")
	if state == null:
		get_tree().quit(1)
		return
	state.pitch_catalog = WorkingPitchCatalog.signature()
	for team: TeamMatchState in [state.away_team, state.home_team]:
		team.pitch_catalog = state.pitch_catalog
		for player: PlayerMatchState in team.roster:
			player.definition = player.definition.duplicate(true) as PlayerDefinition
			player.definition.starting_pitches.assign([
				WorkingPitchCatalog.get_recipe(WorkingPitchCatalog.new_ids()[0])])
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started: bool = runner.start(state, SeasonPhysicalFixtures.seed_for(season, fixture),
		&"field.npc_venue", null, {}, season)
	check(started, "current NPC public runner starts")
	if started:
		for frame in range(300000):
			await get_tree().physics_frame
			if not report.is_empty() or not errors.is_empty():
				break
	check(not report.is_empty() and errors.is_empty(), "finite NPC completion " + str(errors))
	if not report.is_empty():
		check(report.version == 29 and report.has("venue") and report.venue.version == 17,
			"public capture carries explicit current NPC component")
		check(CurrentPhysicalMatchReport.matches(report, state), "current source binding")
		check(CurrentPhysicalStadiumEvidence.matches_source(report.venue, season, fixture, state),
			"saved NPC assignment retained")
		check(CurrentPhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true)),
			state.pitch_catalog), "actual new-release venue JSON")
		var stripped: Dictionary = report.duplicate(true)
		stripped.erase("venue")
		check(not CurrentPhysicalMatchReport.matches(stripped, state), "no no-stadium fallback")
		check(not PhysicalMatchReport.valid(report.venue), "component not historical accepted report")
	runner.cancel()
	runner.queue_free()
	print("Current stadium live checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
