extends "res://src/tests/doubleheader_detached_workload_live_test.gd"
## Actual full all-zero game. Debt is synthetic maximal preparation, not earned season fatigue.


func _ready() -> void:
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("doubleheader"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "exhausted diagnostic draft")
	var source: MatchState = MatchState.create(season._make_team(1, 0), season._make_team(0, 0))
	source.league_rules = LeagueRules.capture("doubleheader")
	source.home_team.track_bases = true
	for team: TeamMatchState in [source.away_team, source.home_team]:
		var debt: Dictionary = {}
		for player: PlayerMatchState in team.roster:
			debt[String(player.definition.id)] = player.stamina_max + 20.0
		_bind(team, _paid_bank([]), 3, debt)
		check(team.tactics.held.is_empty(), "no recovery supply can refill exhausted fixture")
		for player: PlayerMatchState in team.roster:
			check(player.stamina_remaining == 0.0, "all eight players start at zero")
	var report: Dictionary = await _run(source, 443 + 3 * 104729)
	check(not report.is_empty(), "all-zero actual physical game completes without refill")
	if not report.is_empty():
		check(
			report.physical.releases.size() > 0,
			"completed exhausted fixture released actual pitches"
		)
		for index in range(2):
			check(report.uses[index].is_empty(), "no C02 or other supply used")
			for event: Dictionary in report.workload[index].events:
				check(event.kind != "recovery", "no recovery event in exhausted game")
				if event.kind == "release":
					check(
						event.before == 0.0 and event.paid == 0.0 and event.after == 0.0,
						"real exhausted release remains zero and incurs no fabricated charge"
					)
			for remaining: float in report.workload[index].remaining.values():
				check(remaining == 0.0, "no hidden refill across completed exhausted game")
	print("Doubleheader exhausted live checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
