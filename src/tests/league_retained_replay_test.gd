extends Node
## Current-source negative/replay checks using retained real physical evidence.
var failures: int = 0
var checks: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var directory: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			directory = arg.trim_prefix("--evidence-dir=")
	var saved: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(directory.path_join("completed-round76.json"))
	)
	var season: SeasonState = SeasonSave._decode(saved)
	check(season != null and season.league_live, "current source restores real completed round76")
	if season == null:
		get_tree().quit(1)
		return
	check(
		season.player_results.size() == 1 and season.results.size() == 3,
		"three results exactly once"
	)
	var earned_ai: SeasonBuild = season.opponents.clubs["4"].build
	check(
		earned_ai._bank.view().held.size() == 3,
		"AI naturally acquires third held item after real first round"
	)
	check(
		(
			(
				earned_ai
				. to_data()
				. events
				. filter(func(event: Dictionary) -> bool: return event.op == "tactical_buy")
				. size()
			)
			== 3
		),
		"three AI purchases replay from actual generated stock and earned reward"
	)
	check(
		ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"whole saved snapshot reconstructs exactly"
	)
	check(SeasonSave._decode(saved.checkpoint) == null, "legacy envelope rejects Build45")
	var bad: Dictionary = saved.duplicate(true)
	bad.version = 75
	check(SeasonSave._decode(bad) == null, "checkpoint75 cannot carry results")
	bad = saved.duplicate(true)
	bad.league_rules = LeagueRules.capture("standard")
	check(SeasonSave._decode(bad) == null, "root profile substitution rejected")
	season.build._market = 12
	check(
		not season.league_context_consistent() and SeasonSave.snapshot(season).is_empty(),
		"human market12 refused"
	)
	season.build._market = 0
	var own: SeasonBuild = season.build
	season.build = null
	season.league_rules = {}
	season.league_live = false
	check(not season.league_context_consistent(), "surviving league AI cannot become legacy")
	season.build = own
	season.league_rules = LeagueRules.capture("dugout")
	season.league_live = true
	var rules: Dictionary = season.opponents.clubs["1"].build._league_rules
	season.opponents.clubs["1"].build._league_rules = {}
	check(
		season.make_match() == null and SeasonSave.snapshot(season).is_empty(),
		"AI header stripping refuses runtime/save"
	)
	season.opponents.clubs["1"].build._league_rules = rules
	season.home_property = {"unqualified": true}
	check(season.make_match() == null, "unqualified venue extension closed")
	season.home_property = {}
	check(
		PhysicalMatchRequest.capture(MatchState.new()) == null, "null request teams reject cleanly"
	)
	var pending: SeasonState = SeasonSave._decode(
		JSON.parse_string(
			FileAccess.get_file_as_string(directory.path_join("pending-human76.json"))
		)
	)
	check(pending != null, "retained pending76 restores")
	var projection: Dictionary = SeasonRoundSettlement.project(pending)
	check(projection.has("fixture"), "pending discovers exact first AI fixture")
	if projection.has("fixture"):
		var row: Dictionary = saved.checkpoint.physical.reports[0]
		var state: MatchState = SeasonPhysicalFixtures.match_for(
			projection.candidate, projection.fixture
		)
		check(
			PhysicalLeagueReport.matches(row.report, state),
			"retained real AI report matches reconstructed paid request"
		)
		check(
			(
				row.request
				== SeasonPhysicalFixtures.request_key(projection.candidate, projection.fixture)
			),
			"retained request hash matches"
		)
		var legacy: Dictionary = row.report.physical.duplicate(true)
		legacy.erase("league_bound")
		check(PhysicalMatchReport.valid(legacy), "empty-bag core can have valid legacy shape")
		check(
			not PhysicalLeagueReport.matches(legacy, state),
			"legacy shape cannot enter league context"
		)
		var probe: SeasonPhysicalFixtures = SeasonPhysicalFixtures.new()
		probe.reports = [{"fixture": row.fixture, "request": row.request, "report": legacy}]
		check(
			probe.resolve(projection.candidate, projection.fixture).is_empty(),
			"league resolver rejects stripped wrapper and marker"
		)
		state.league_rules = {}
		check(
			not PhysicalLeagueReport.matches(row.report, state), "league report rejects legacy root"
		)
	check(
		ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"negative checks preserve restored owner"
	)
	print("League retained replay checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
