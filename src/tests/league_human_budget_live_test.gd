extends "res://src/tests/league_physical_proof_test.gd"
## Actual physical game with human inventory API; test driver supplies inputs.
## Paid journals use synthetic reward preparation, not earned season progression or UI acceptance.


func _ready() -> void:
	var native: bool = OS.get_cmdline_user_args().has("--league-native-preview")
	var capture_dir: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			capture_dir = argument.trim_prefix("--ui-capture-dir=")
	if native and (DisplayServer.get_name() == "headless" or capture_dir.is_empty()):
		check(false, "native preview requires a native display and explicit capture directory")
		get_tree().quit(1)
		return
	var preview: Node
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("dugout"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "human detached roster draft")
	var state: MatchState = MatchState.create(season._make_team(1, 8), season._make_team(0, 8))
	state.league_rules = LeagueRules.capture("dugout")
	state.home_team.track_bases = true
	var human_bank: SeasonOwnership = fixture("dugout", 3, [])
	var ai_bank: SeasonOwnership = fixture("dugout", 2)
	var row: Dictionary = budget_row(ai_bank)
	state.away_team.league_ownership = ai_bank.to_data()
	state.away_team.ai_budget = row.budget.duplicate(true)
	state.away_team.ai_tactical_initial.assign(row.initial.duplicate(true))
	state.away_team.tactics.held.assign(row.initial.duplicate(true))
	state.home_team.league_ownership = human_bank.to_data()
	state.home_team.tactics.held.assign(SeasonTacticalCatalog.held(human_bank.view()))
	MatchFieldSupply.sync_capacity(state.home_team, human_bank.view())
	check(
		(
			state.away_team.ai_budget.before.size() == 2
			and row.initial.size() == 3
			and row.budget.outcome == "granted"
		),
		"Budget Bites commits third slot from two"
	)
	check(PhysicalMatchRequest.capture(state) != null, "human3 versus Budget3 request admitted")
	var before: Array = [human_bank.to_data(), ai_bank.to_data()]
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	runner.presentation_enabled = native
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started_ms: int = Time.get_ticks_msec()
	var frames: int = 0
	var activations: int = 0
	var observed_swings: Dictionary = {}
	var played: MatchState
	var started: bool = runner.start(state, 443)
	check(started, "human third-slot physical game starts")
	if started:
		played = runner._lab._match_state
		if native:
			preview = preload("res://src/tests/league_human_native_preview.gd").new()
			add_child(preview)
			await preview.setup(runner, season, human_bank.view(), capture_dir)
			runner.finished.connect(func(_value: Dictionary) -> void: preview.detach())
			runner.failed.connect(func(_reason: String) -> void: preview.detach())
			check(
				await preview.capture("01-equipped-three-held"),
				"native actual Equipped shows three held"
			)
		for frame in range(300000):
			await get_tree().physics_frame
			frames += 1
			if not report.is_empty() or not errors.is_empty():
				break
			var human: TeamMatchState = played.home_team
			if played.phase == MatchState.Phase.PRE_PITCH and played.between_batters:
				for copy: Dictionary in human.tactics.held.duplicate(true):
					if human.tactics.activate(played, human, copy.id):
						activations += 1
						if native and activations == 1:
							check(
								await preview.capture("02-first-use-field", false),
								"native physical field during paid use"
							)
							check(
								await preview.capture("03-equipped-after-first-use"),
								"native remaining and spent inventory"
							)
						elif native and activations == 3:
							check(
								await preview.capture("04-equipped-three-used"),
								"native third copy consumed"
							)
			if (
				played.batting_team() == human
				and runner._lab._swing_tracker != null
				and runner._lab._swing_tracker.active
				and human.tactics.active(played) == "A10"
			):
				check(
					is_equal_approx(runner._lab._swing_tracker.profile.gear_fair_exit_scale, 0.95),
					"human paid Tape modifies actual physical swing"
				)
				observed_swings[played.plate_appearance_number] = true
	check(
		errors.is_empty() and not report.is_empty(), "human/Budget game completes: " + str(errors)
	)
	if not report.is_empty():
		check(
			PhysicalMatchReport.valid(report) and PhysicalLeagueReport.matches(report, state),
			"human/Budget report27 matches immutable request"
		)
		check(
			PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report))),
			"human/Budget JSON replay"
		)
		var human: TeamMatchState = played.home_team
		check(
			not human.ai_base and human.ai_tactical_hitter.is_empty(),
			"human uses are not AI policy uses"
		)
		check(
			(
				activations == 3
				and human.tactics.consumed.size() == 3
				and human.tactics.held.is_empty()
			),
			"all three paid human copies activate and consume"
		)
		var receipts: Array = human_bank.view().held.map(
			func(copy: Dictionary) -> String: return copy.id
		)
		var used: Array = []
		var pas: Array = []
		for action: Dictionary in human.tactics.consumed:
			check(
				(
					receipts.has(action.receipt)
					and not used.has(action.receipt)
					and not pas.has(action.pa)
				),
				"exact paid human receipts consumed once in distinct legal PAs"
			)
			used.append(action.receipt)
			pas.append(action.pa)
		check(observed_swings.size() > 0, "human third-slot game exercises actual modified swings")
		var ai: Dictionary = report.physical.tactics.teams[0]
		check(
			(
				ai.initial.size() == 3
				and ai.budget.before.size() == 2
				and ai.budget.outcome == "granted"
			),
			"real report preserves Budget two-to-three outcome"
		)
		check(
			ai.consumed.any(func(action: Dictionary) -> bool: return action.receipt == "budget:8"),
			"AI actually consumes generated third Swing Plan"
		)
		check(ai.consumed.size() + ai.remaining.size() == 3, "AI grant reconciles exactly")
		print(
			"LEAGUE_HUMAN_BUDGET wall_ms=",
			Time.get_ticks_msec() - started_ms,
			" physics_frames=",
			frames,
			" releases=",
			report.physical.releases.size(),
			" score=",
			report.physical.away_runs,
			"-",
			report.physical.home_runs,
			" human_initial=3 human_consumed=",
			human.tactics.consumed.size(),
			" human_remaining=",
			human.tactics.held.size(),
			" human_receipts=",
			human.tactics.consumed,
			" ai_initial=",
			ai.initial.size(),
			" ai_consumed=",
			ai.consumed.size(),
			" ai_remaining=",
			ai.remaining.size(),
			" ai_receipts=",
			ai.consumed,
			" observed_swing_pas=",
			observed_swings.keys()
		)
	check(
		before == [human_bank.to_data(), ai_bank.to_data()],
		"physical use does not mutate paid journals"
	)
	if preview != null:
		preview.detach()
		preview.queue_free()
	runner.queue_free()
	await get_tree().process_frame
	print("League human/Budget live checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
