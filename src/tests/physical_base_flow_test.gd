extends "res://src/tests/tactical_base_context_test.gd"
## Real physical scoring and tags, contrasted against an identical telemetry-disabled match.


func _ready() -> void:
	for seed_value: int in [47, 67]:
		await _physical(seed_value)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical base-flow checks passed: exact scoring, tags and telemetry parity.")
	get_tree().quit(0 if _failures == 0 else 1)


func _physical(seed_value: int) -> void:
	var reports: Array = []
	for enabled: bool in [false, true]:
		var state: MatchState = _fixture()
		state.away_team.track_bases = enabled
		state.home_team.track_bases = enabled
		var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
		add_child(runner)
		var report: Dictionary = {}
		var errors: Array[String] = []
		runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
		runner.failed.connect(func(reason: String) -> void: errors.append(reason))
		_check(runner.start(state, seed_value), "physical occupancy fixture starts fresh")
		var live: MatchState = null
		for frame in range(300000):
			if runner._lab != null and runner._lab._match_state != null:
				live = runner._lab._match_state
			await get_tree().physics_frame
			if not report.is_empty() or not errors.is_empty():
				break
		_check(errors.is_empty() and PhysicalMatchReport.valid(report), "physical report balances")
		if not report.is_empty() and live != null:
			if enabled:
				var flow: Dictionary = live.base_flow.evidence(live)
				var teams: Array = [report.teams[0].roster, report.teams[1].roster]
				_check(PhysicalBaseFlow.valid(flow, teams, report.performance),
					"real field outcomes exactly replay base occupancy")
				_check(PhysicalBaseFlow.valid(JSON.parse_string(JSON.stringify(flow)),
					teams, report.performance), "real occupancy proof survives JSON")
				print("PHYSICAL_BASE_FLOW seed=", seed_value, " results=", flow.results.size(),
					" tags=", flow.tags.size(), " releases=", report.releases.size())
			else:
				_check(live.base_flow.ready.is_empty() and live.base_flow.results.is_empty(),
					"historical policies add no occupancy telemetry")
			reports.append(report)
		runner.queue_free()
		await _frames()
	_check(reports.size() == 2 and ClubCareer.same(reports[0], reports[1]),
		"telemetry changes no pitch, result, stat, RNG, report or old policy")
