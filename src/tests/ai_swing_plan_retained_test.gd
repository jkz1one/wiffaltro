extends "res://src/tests/season_opponent_tactics_test.gd"
## Cold old-report admission, exact request binding and paid-consumption journal replay.


func _ready() -> void:
	_buy_tactical("C03")
	var build: SeasonBuild = _paid.C03.build
	var club: Dictionary = _paid.C03.club
	var away: Array[PlayerDefinition] = []
	var home: Array[PlayerDefinition] = []
	for id: String in build.roster():
		away.append(build.definition(id))
	for id: String in ["player.dakota_wells", "player.mika_reed",
		"player.jamie_nash", "player.quinn_riley"]:
		home.append(SeasonBuild.new(9, [id]).definition(id))
	var state: MatchState = MatchState.create(
		TeamMatchState.create("Paid supply diagnostic", away),
		TeamMatchState.create("Ordinary opposition", home))
	state.away_team.ai_sponsor_choices = true
	state.away_team.ai_tactical_hitter = club.roles.hitter
	state.away_team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	state.away_team.ai_tactical_initial.assign(state.away_team.tactics.held.duplicate(true))
	var path: String = OS.get_environment("AI_OLD_REPORT")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(PhysicalMatchReport.valid(report), "unchanged old completed physical report admits")
	_check(PhysicalTacticalEvidence.report_matches(report, state),
		"old report binds exact paid request after timing fix")
	var row: Dictionary = report.tactics.teams[0]
	var reward: Dictionary = SeasonOpponentPolicy.command(build, "reward", {
		"game": 1, "win": report.away_runs > report.home_runs,
		"performance": report.performance, "tactics": row.consumed})
	_check(build.commit(reward).ok, "old completed report settles exact original paid copy")
	var saved: Dictionary = build.to_data()
	_check(build.commit(reward).replayed and ClubCareer.same(saved, build.to_data()),
		"old report retry does not pay or consume twice")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(saved, "", true, true))
	var restored: SeasonBuild = SeasonBuild.from_data(roundtrip, build._seed, build.roster())
	_check(restored != null and ClubCareer.same(restored.view(), build.view()),
		"old report journal cold-restores exact wallet and consumed inventory")
	print("AI_PLAN_RETAINED failures=", _failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
