extends "res://src/tests/season_opponent_tactics_test.gd"
## Focused paid-copy physics reproduction; budget is a disclosed synthetic unit fixture.


func _ready() -> void:
	_tactical_probe = preload("res://src/tests/ai_swing_plan_timing_probe.gd").new()
	_buy_tactical("C03")
	await _tactical_game("C03")
	var probe: RefCounted = _tactical_probe
	_check(not probe.samples.is_empty(), "at least one actual locked physical swing observed")
	var path: String = OS.get_environment("AI_TIMING_EVIDENCE")
	if not path.is_empty():
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"samples": probe.samples, "failures": _failures}, "\t"))
	print("AI_TIMING samples=", probe.samples, " failures=", _failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _tactical_game(item: String) -> void:
	var build: SeasonBuild = _paid[item].build
	var club: Dictionary = _paid[item].club
	var away: Array[PlayerDefinition] = []
	var home: Array[PlayerDefinition] = []
	for id: String in build.roster():
		away.append(build.definition(id))
	for id: String in [
		"player.dakota_wells", "player.mika_reed", "player.jamie_nash", "player.quinn_riley"
	]:
		home.append(SeasonBuild.new(9, [id]).definition(id))
	var state: MatchState = MatchState.create(
		TeamMatchState.create("Paid supply diagnostic", away),
		TeamMatchState.create("Ordinary opposition", home)
	)
	state.away_team.ai_sponsor_choices = true
	state.away_team.ai_tactical_hitter = club.roles.hitter
	state.away_team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	state.away_team.ai_tactical_initial.assign(state.away_team.tactics.held.duplicate(true))
	var before: Dictionary = build.to_data()
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var failures: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: failures.append(reason))
	_check(runner.start(state, 67), "paid supply actual physical game starts")
	for frame in range(300000):
		await get_tree().physics_frame
		_tactical_probe.observe(runner._lab, _check)
		if not report.is_empty() or not failures.is_empty():
			break
	_check(
		failures.is_empty() and PhysicalMatchReport.valid(report),
		"complete paid supply physics balances"
	)
	if not report.is_empty():
		var evidence: String = OS.get_environment("AI_TIMING_EVIDENCE")
		if not evidence.is_empty():
			var output: FileAccess = FileAccess.open(evidence + ".report.json", FileAccess.WRITE)
			output.store_string(JSON.stringify(report, "\t", true, true))
		_check(PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true))),
			"complete report survives the actual JSON boundary")
		_check(
			report.version == 3 and PhysicalTacticalEvidence.report_matches(report, state),
			"report3 binds complete held/consumed/remaining copies"
		)
		var row: Dictionary = report.tactics.teams[0]
		_check(
			(
				row.consumed.size() == 1
				and row.remaining.is_empty()
				and row.consumed[0].player == club.roles.hitter
			),
			"exact paid copy consumed at featured PA once"
		)
		for corruption: String in [
			"missing", "duplicate", "foreign", "swing", "pa", "paid", "remaining"
		]:
			var bad: Dictionary = report.duplicate(true)
			var proof: Dictionary = bad.tactics.teams[0]
			match corruption:
				"missing":
					proof.consumed.clear()
				"duplicate":
					proof.consumed.append(proof.consumed[0])
				"foreign":
					proof.consumed[0].receipt = "foreign"
				"swing":
					proof.consumed[0].swing = "swing.illegal"
				"pa":
					proof.consumed[0].pa += 1
				"paid":
					proof.initial[0].paid = 0
				"remaining":
					proof.remaining = proof.initial.duplicate(true)
			_check(
				not PhysicalMatchReport.valid(bad), "altered tactical " + corruption + " rejects"
			)
		var unpaid: MatchState = PhysicalMatchRequest.capture(state)
		unpaid.away_team.ai_tactical_initial.clear()
		_check(
			not PhysicalTacticalEvidence.report_matches(report, unpaid),
			"unowned-copy binding rejects"
		)
		var reward: Dictionary = SeasonOpponentPolicy.command(
			build,
			"reward",
			{
				"game": 1,
				"win": report.away_runs > report.home_runs,
				"performance": report.performance,
				"tactics": row.consumed
			}
		)
		var invalid: Dictionary = reward.duplicate(true)
		invalid.tactics[0].receipt = "foreign"
		_check(not build.commit(invalid).ok and ClubCareer.same(before, build.to_data()),
			"invalid copy evidence atomically rolls back reward and consumption")
		_check(
			build.commit(reward).ok and build._bank.view().held.is_empty(),
			"completed use settles shared bag"
		)
		var saved: Dictionary = build.to_data()
		_check(
			build.commit(reward).replayed and ClubCareer.same(saved, build.to_data()),
			"completed game retry cannot pay or consume twice"
		)
		_check(
			SeasonBuild.from_data(saved, build._seed, build.roster()) != null,
			"paid then consumed copy replays from purchase journal"
		)
	_check(
		(
			ClubCareer.same(before.events, build.to_data().events.slice(0, before.events.size()))
			and state.away_team.tactics.consumed.is_empty()
			and state.away_team.tactics.held.size() == 1
		),
		"physical request isolates original held copy and natural resources"
	)
	_check(
		_tactical_probe.tape_frames > 0 if item == "A10" else _tactical_probe.plan_frames > 0,
		"actual shared swing exercises supply " + item
	)
	print(
		"NPC_PAID_TACTICAL item=",
		item,
		" releases=",
		report.get("releases", []).size(),
		" ",
		_tactical_probe.summary()
	)
	runner.queue_free()
	await _frames()



func _build(seed_value: int) -> SeasonBuild:
	if OS.get_environment("AI_TIMING_CONTACT") != "1":
		return super._build(seed_value)
	var build: SeasonBuild = SeasonBuild.new(seed_value, ["player.alex_finch",
		"player.lee_stone", "player.ash_cole", "player.gray_west"])
	build._market = 8
	_check(build.commit(SeasonOpponentPolicy.command(build, "reward", {
		"game": 0, "win": true, "performance": _performance(build, 0, 0)})).ok,
		"Contact diagnostic uses synthetic budget, not earned career evidence")
	return build
