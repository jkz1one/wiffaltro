extends "res://src/tests/season_tactical_test.gd"

const HEAT: String = SeasonTacticalCatalog.HEAT
const BASE: String = SeasonTacticalCatalog.BASE


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_distribution()
	_heat_lifetime()
	_heat_physics()
	_base_contract()
	_expanded_migration()
	await _expanded_shop_ui()
	await _heat_ui()
	await _base_walkoff_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro expanded tactical checks passed: Heat physics, base scoring, paid UI and replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _distribution() -> void:
	var weights: Dictionary = SeasonTacticalCatalog.weights()
	var total: float = 0.0
	for value: float in weights.values():
		total += value
	_check(is_equal_approx(weights[BASE] / total, 0.05), "Base has5% tactical subweight")
	for id: String in ["A10", "C02", "C03", HEAT]:
		_check(is_equal_approx(weights[id] / total, 0.2375), "ordinary supplies share95%")
	var probe: SeasonBuild = _unit_build([])
	var counts: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value in range(2000):
		probe._seed = seed_value
		for id: String in probe._offers(0).values():
			if weights.has(id):
				counts[id] = counts.get(id, 0) + 1
		rng.seed = seed_value
		for id: String in DevelopmentShopCatalog.pack(probe._book, probe.roster(), rng):
			_check(not weights.has(id), "fixed development pack excludes all tactics")
	_check(counts.size() == 5 and counts[BASE] < counts[HEAT], "all five reachable; Base rarer")
	print("TACTICAL_STOCK 2000 four-offer visits: ", counts)
	var pair: SeasonBuild = _unit_build(["J02"])
	var before: int = pair.cash()
	_check(
		pair.commit(_pair(pair, HEAT, HEAT)).ok and pair.cash() == before - 9,
		"two Heat copies Wholesale cost9"
	)


func _heat_lifetime() -> void:
	var state: MatchState = _fixture()
	var team: TeamMatchState = state.defensive_team()
	_supply(team, HEAT)
	_supply(team, HEAT, "second")
	_check(team.tactics.activate(state, team, "copy"), "Heat at defensive readiness")
	var source: PitchDefinition = state.pitcher().definition.starting_pitches[0]
	var before: float = source.nominal_velocity_mps
	_check(
		is_equal_approx(MatchTactics.pitch(source, state).nominal_velocity_mps, before * 1.05),
		"Heat velocity parameter once"
	)
	_check(source.nominal_velocity_mps == before, "authored/mastered recipe unchanged")
	state.begin_pitch()
	state.cancel_pitch()
	_check(team.tactics.active(state) == HEAT, "canceled first delivery keeps paid Heat")
	state.begin_pitch()
	state.record_foul()
	state.continue_after_dead_ball()
	_check(
		team.tactics.active(state) == HEAT and not team.tactics.activate(state, team, "second"),
		"foul keeps effect but closes activation"
	)
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	state.continue_after_dead_ball()
	_check(team.tactics.active(state) == "", "completed PA ends Heat")
	_check(team.tactics.activate(state, team, "second"), "new PA can use another copy")
	var original: int = team.pitcher_index
	_check(team.select_pitcher((original + 1) % 4), "separately legal change")
	_check(team.tactics.active(state) == "", "substitution ends Heat")
	team.select_pitcher(original)
	_check(team.tactics.active(state) == "", "returning a zero-pitch starter cannot bank Heat")
	_check(team.tactics.consumed.size() == 2, "no substitution refund")


func _heat_physics() -> void:
	var state: MatchState = _fixture()
	var team: TeamMatchState = state.defensive_team()
	_supply(team, HEAT)
	team.tactics.activate(state, team, "copy")
	var setup: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
	var slowest: float = INF
	var fastest: float = 0.0
	var samples: int = 0
	for recipe_id: String in DevelopmentShopCatalog.LESSON_PRICES:
		for level: int in [1, 5]:
			var recipe: PitchDefinition = PitchMastery.apply(
				ContentDB.get_pitch(StringName(recipe_id)), level
			)
			for ball: String in ["", "BALL-VEL-01", "BALL-HYB-01"]:
				var player: PlayerDefinition = SeasonGearCatalog.equip(
					state.pitcher().definition, {"ball": {"item": ball}}
				)
				var normal: PitchDefinition = MatchLabSupport.rated_pitch(recipe, player, 1.12, 1.0)
				var heated: PitchDefinition = MatchTactics.pitch(normal, state)
				_check(
					is_equal_approx(
						heated.nominal_velocity_mps / normal.nominal_velocity_mps, 1.05
					),
					"all recipe families receive Heat"
				)
				_check(
					(
						heated.stamina_cost == normal.stamina_cost
						and heated.control_difficulty == normal.control_difficulty
						and heated.instability_strength == normal.instability_strength
						and heated.mastery_movement_scale == normal.mastery_movement_scale
					),
					"no added costs, command bonus or identity changes"
				)
				for left: bool in [false, true]:
					var launch: PitchLaunchParameters = PitchAimSolver.solve(
						heated, setup, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), left, 55
					)
					var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
						launch, 0
					)
					_check(
						(
							crossing.crossed
							and crossing.point.y > 0.12
							and crossing.velocity.is_finite()
						),
						"Heat reaches plate through shared physical solver"
					)
					slowest = minf(slowest, crossing.velocity.length())
					fastest = maxf(fastest, crossing.velocity.length())
					var exhausted: PitchLaunchParameters = PitchExecutionModel.apply(
						launch,
						1.0,
						1.0,
						heated.control_difficulty,
						heated.execution_difficulty,
						heated.category,
						21
					)
					_check(
						exhausted.velocity.length() < launch.velocity.length(),
						"Heat cannot bypass exhaustion"
					)
					samples += 1
	print("HEAT_PHYSICS samples=", samples, " measured_plate_mps=", slowest, "..", fastest)


func _base_contract() -> void:
	for mask in range(8):
		var state: MatchState = _fixture()
		var team: TeamMatchState = state.batting_team()
		_supply(team, BASE)
		state.bases.first = &"first" if mask & 1 else &""
		state.bases.second = &"second" if mask & 2 else &""
		state.bases.third = &"third" if mask & 4 else &""
		var target: Dictionary = TacticalBaseAdvance.target(state.bases)
		var allowed: bool = mask in [1, 2, 4, 5]
		var stats: Dictionary = state.performance.snapshot(state)
		var pa: int = state.plate_appearance_number
		_check(
			team.tactics.activate(state, team, "copy") == allowed, "all eight occupancy patterns"
		)
		_check(
			state.plate_appearance_number == pa and state.performance.snapshot(state) == stats,
			"no phantom PA, hit, walk, steal, tag or RBI"
		)
		_check(team.runs == (1 if mask == 4 else 0), "only lone trailing third runner scores")
		_check(
			team.tactics.held.size() == (0 if allowed else 1), "invalid occupancy spends nothing"
		)
		if allowed:
			_check(team.tactics.consumed[0].advance == target, "exact consumable advance logged")
			_check(not team.tactics.activate(state, team, "copy"), "advance cannot replay")
		if mask == 5:
			_check(
				state.bases.third == &"third" and state.bases.second == &"first",
				"never advance another runner"
			)
		if mask == 3 or mask == 7:
			_check(
				state.bases.first == &"first" and state.bases.second == &"second",
				"no blocked-runner substitute or force chain"
			)
	var state: MatchState = _fixture()
	state.top_half = false
	state.inning = 5
	_supply(state.home_team, BASE)
	state.bases.third = state.home_team.roster[0].definition.id
	state.home_team.tactics.activate(state, state.home_team, "copy")
	_check(
		(
			state.phase == MatchState.Phase.GAME_END
			and state.home_team.runs == 1
			and state.plate_appearance_number == 1
		),
		"walkoff immediate with no phantom PA"
	)


func _expanded_migration() -> void:
	SeasonSave.path = "user://expanded-migrate-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(14, false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 14
	_record(season)
	season.build.commit(_command(season.build, "open"))
	for attempt in range(10):
		var stock: Dictionary = season.build.view().shop.offers
		for offer: String in stock:
			if SeasonTacticalCatalog.ITEMS.has(stock[offer]):
				season.build.commit(_command(season.build, "tactical_buy", {"offer": offer}))
				break
		if not season.build.view().wallet.held.is_empty():
			break
		season.build.commit(_command(season.build, "reroll"))
	_check(not season.build.view().wallet.held.is_empty(), "actual old paid tactical receipt")
	_check(SeasonSave.save(season), "old schema18 saves")
	var before: Dictionary = season.build.view()
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and restored.build.view() == before
			and restored.build._expanded_tactical_from == 2
		),
		"old paid supply and stock exact; expansion next visit"
	)
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		season.build.view().shop.offers == restored.build.view().shop.offers,
		"old core-only rerolls frozen"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		(
			restored.build._tactical_catalog_version() == 2
			and SeasonSave.save(restored)
			and SeasonSave.restore() != null
		),
		"expanded next visit journal replays"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _expanded_shop_ui() -> void:
	SeasonSave.path = "user://expanded-shop-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _paid_tactics([HEAT, BASE])
	_check(app._checkpoint(), "save genuinely offered expansion")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	for id: String in [HEAT, BASE]:
		var before: Dictionary = app.season.build.view()
		var quote: String = _offer(app.season.build, id)
		await _click(_meta_exact(window, "tactical_offer", quote))
		await _shop_bounds(window, "expanded-" + id)
		await _click(window._confirm.get_cancel_button())
		_check(app.season.build.view() == before, "cancel expansion unchanged")
		await _click(_meta_exact(window, "tactical_offer", quote))
		await _click(window._confirm.get_ok_button())
		_check(
			app.season.build.cash() == before.wallet.cash - SeasonTacticalCatalog.item(id).price,
			"full paid expansion price"
		)
	_check(
		SeasonSave.restore().build.view() == app.season.build.view(),
		"both paid expansion copies replay"
	)
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _heat_ui() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _fixture()
	lab._player_home = true
	_supply(lab._configured_match.home_team, HEAT)
	add_child(lab)
	await _frames(4)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var controls: MatchTacticalControls = lab.get_node("TacticalControls")
	await _frames()
	await _click(controls._entry)
	await _click(controls._choices.get_child(0))
	_check(controls._detail.text.contains("×1.05"), "Heat review describes parameter and limits")
	await _click(controls._dialog.get_ok_button())
	var before: float = lab._match_state.pitcher().stamina_remaining
	var cost: float = MatchLabSupport.stamina_cost(lab._selected_pitch(), lab._pitch_effort)
	lab._throw_pitch()
	_check(
		(
			lab._pitch_actor.running
			and is_equal_approx(before - lab._match_state.pitcher().stamina_remaining, cost)
		),
		"real Heat delivery with ordinary workload"
	)
	_check(
		lab._last_executed_release_speed_mps > 0 and lab._last_expected_plate_speed_mps > 0,
		"actual Heat flight telemetry"
	)
	lab.queue_free()
	await _frames()


func _base_walkoff_ui() -> void:
	SeasonSave.path = "user://base-walkoff-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _paid_tactics([BASE])
	app.season.build.commit(
		_command(app.season.build, "tactical_buy", {"offer": _offer(app.season.build, BASE)})
	)
	_check(app._checkpoint(), "save paid Base before game")
	var before: Dictionary = app.season.build.view()
	var state: MatchState = app.season.make_match()
	# Controlled match-state scoring fixture; the separate live scene supplies physical-game evidence.
	state.top_half = false
	state.inning = 5
	state.record_hit(BallPlayOutcome.Result.TRIPLE)
	state.continue_after_dead_ball()
	var pa: int = state.plate_appearance_number
	var stats: Dictionary = state.performance.snapshot(state)
	app._fixture_id = app.season.pending_fixture().id
	app._open_match(state, true, true)
	await _frames(4)
	PitchBatLabFeelSupport.skip_match_presentation(app.lab)
	var controls: MatchTacticalControls = app.lab.get_node("TacticalControls")
	await _frames()
	await _click(controls._entry)
	await _click(controls._choices.get_child(0))
	_check(controls._detail.text.contains("HOME (+1 run)"), "exact scoring runner reviewed")
	await _click(controls._dialog.get_cancel_button())
	_check(
		state.home_team.runs == 0 and controls.team().tactics.held.size() == 1,
		"cancel scoring card unchanged"
	)
	await _click(controls._entry)
	await _click(controls._choices.get_child(0))
	var runner: StringName = state.bases.third
	state.bases.third = state.home_team.roster[2].definition.id
	await _click(controls._dialog.get_ok_button())
	_check(
		state.home_team.runs == 0 and controls.team().tactics.held.size() == 1,
		"stale runner confirmation spends nothing"
	)
	state.bases.third = runner
	await _click(controls._entry)
	await _click(controls._choices.get_child(0))
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(controls._dialog.get_ok_button())
	_check(
		state.phase == MatchState.Phase.GAME_END and state.home_team.runs == 1,
		"UI card ends game immediately"
	)
	_check(
		state.plate_appearance_number == pa and state.performance.snapshot(state) == stats,
		"no phantom batter or RBI on walkoff"
	)
	_check(
		app.lab._match_presentation_director.blocks_gameplay() and not app.lab._pitch_actor.running,
		"walkoff starts outro without delivery"
	)
	_check(not app._commit_result() and app._result_recorded, "failed walkoff write is retryable")
	var after: Dictionary = app.season.build.view()
	SeasonSave.path = path
	_check(
		(
			FileAccess.get_file_as_string(path) == bytes
			and SeasonSave.restore().build.view() == before
		),
		"failed walkoff write retains full pregame snapshot"
	)
	_check(
		app._commit_result() and app.season.build.view() == after and after.wallet.held.is_empty(),
		"retry persists score and exact consumption once"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and restored.player_results[-1].home_runs == 1
			and restored.build.view() == after
		),
		"walkoff replay accepts uncompleted readiness PA"
	)
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
