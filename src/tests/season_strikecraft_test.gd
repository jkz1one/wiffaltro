extends "res://src/tests/season_sponsor_test.gd"

const RECIPES: Array[StringName] = [
	&"pitch.overhand_four_seam",
	&"pitch.overhand_sinker",
	&"pitch.overhand_slider",
	&"pitch.sidearm_slider",
	&"pitch.drop"
]


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_refund_contracts()
	_attribution_and_boundaries()
	_migrate_paid_gameplay_sponsor()
	await _actual_release_costs()
	await _sponsor_ui(SeasonSponsorCatalog.SEQUENCE_ITEMS)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Strikecraft checks passed: actual costs, attribution, caps, paid UI and migration."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _strikecraft_fixture() -> MatchState:
	var state: MatchState = _fixture()
	for team: TeamMatchState in [state.home_team, state.away_team]:
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors = {"B03": true}
	return state


func _paid_pitch(state: MatchState, recipe: StringName, cost: float) -> void:
	state.continue_after_dead_ball()
	_check(state.begin_pitch(), "actual pitch begins")
	var pitcher: PlayerMatchState = state.pitcher()
	var before: float = pitcher.stamina_remaining
	pitcher.spend_stamina(cost)
	state.note_pitch_released(recipe, before - pitcher.stamina_remaining)


func _sequence(state: MatchState, costs: Array) -> void:
	for index in range(costs.size()):
		_paid_pitch(state, RECIPES[index], costs[index])
		state.record_foul()
	state.continue_after_dead_ball()


func _refund_contracts() -> void:
	for cost: float in [0.0, 6.0, 8.0, 10.0]:
		for swinging: bool in [false, true]:
			var state: MatchState = _strikecraft_fixture()
			_sequence(state, [cost, cost, cost])
			var pitcher: PlayerMatchState = state.pitcher()
			var before: float = pitcher.stamina_remaining
			var pitches: int = pitcher.pitch_count
			state.strikes = 2
			state.record_strike(swinging)
			_check(
				is_equal_approx(pitcher.stamina_remaining - before, minf(6.0, cost * 0.75)),
				"25% actual first-three cost, capped at6; called and swinging K"
			)
			_check(
				state.defensive_team().strikecraft_uses == 1 and pitcher.pitch_count == pitches,
				"one qualifying use, no fabricated pitch"
			)
			_check(
				state.pitch_ledger.first_costs(pitcher.definition.id).is_empty(), "PA costs cleared"
			)
			var line: Dictionary = state.performance.snapshot(state)[String(pitcher.definition.id)]
			_check(line.p_k == 1, "refund does not create extra Ks")
	var state: MatchState = _strikecraft_fixture()
	for index in [0, 0, 1, 1, 2, 3, 4]:
		_paid_pitch(state, RECIPES[index], 2.0 if index < 3 else 20.0)
		state.note_pitch_released(RECIPES[4], 99.0)
		state.record_foul()
	_check(
		state.pitch_ledger.first_costs(state.pitcher().definition.id) == [2.0, 2.0, 2.0],
		"first occurrences only; repeat events and fourth/fifth recipes add nothing"
	)
	var before: float = state.pitcher().stamina_remaining
	state.record_strike()
	_check(
		is_equal_approx(state.pitcher().stamina_remaining - before, 1.5), "no pitch-wasting bonus"
	)
	state = _strikecraft_fixture()
	state.pitcher().stamina_remaining = 1.0
	_sequence(state, [10.0, 10.0, 10.0])
	state.record_strike()
	_check(
		is_equal_approx(state.pitcher().stamina_remaining, 0.25),
		"exhausted pitcher refunds only actual spending, never nominal cost"
	)
	state = _strikecraft_fixture()
	_sequence(state, [8.0, 8.0, 8.0])
	state.pitcher().stamina_remaining = state.pitcher().stamina_max - 1.0
	state.record_strike()
	_check(
		(
			state.pitcher().stamina_remaining == state.pitcher().stamina_max
			and state.defensive_team().strikecraft_refunded == 1.0
		),
		"ordinary maximum bounds recovery"
	)


func _attribution_and_boundaries() -> void:
	for ending: String in ["walk", "hit", "out", "two recipes", "unowned"]:
		var state: MatchState = _strikecraft_fixture()
		_sequence(state, [4.0, 4.0] if ending == "two recipes" else [4.0, 4.0, 4.0])
		if ending == "unowned":
			state.pitcher().definition.season_sponsors = {}
		var before: float = state.pitcher().stamina_remaining
		match ending:
			"walk":
				state.balls = 3
				state.record_ball()
			"hit":
				state.record_hit(BallPlayOutcome.Result.SINGLE)
			"out":
				state.record_ball_in_play_out()
			_:
				state.strikes = 2
				state.record_strike()
		_check(
			(
				state.pitcher().stamina_remaining == before
				and state.defensive_team().strikecraft_uses == 0
			),
			ending + " earns no refund"
		)
	var state: MatchState = _strikecraft_fixture()
	_check(state.begin_pitch(), "cancelable windup")
	state.cancel_pitch()
	state.note_pitch_released(RECIPES[0], 6.0)
	_check(
		state.pitch_ledger.first_costs(state.pitcher().definition.id).is_empty(),
		"no canceled release credit"
	)
	_sequence(state, [4.0, 4.0, 4.0])
	var former: PlayerMatchState = state.pitcher()
	# Attribution must remain correct if a future legal rule permits a mid-PA change.
	# This fixture uses the team primitive; no production substitution gate is relaxed.
	_check(state.defensive_team().select_pitcher(2), "controlled attribution replacement")
	_paid_pitch(state, RECIPES[0], 4.0)
	var before: float = state.pitcher().stamina_remaining
	var former_before: float = former.stamina_remaining
	state.record_strike()
	_check(
		state.pitcher().stamina_remaining == before and former.stamina_remaining == former_before,
		"credited pitcher cannot borrow former pitcher's three recipes"
	)
	state.continue_after_dead_ball()
	state.inning = 6
	for trigger in range(3):
		_sequence(state, [4.0, 4.0, 4.0])
		before = state.pitcher().stamina_remaining
		state.record_strike()
		_check(
			is_equal_approx(
				state.pitcher().stamina_remaining - before, 3.0 if trigger < 2 else 0.0
			),
			"twice per team, not per pitcher"
		)
		# Keep the test in the same defense across an extra inning; game counter stays.
		state.outs = 0
		state.phase = MatchState.Phase.PLAY_DEAD
		state.inning += 1
		state.continue_after_dead_ball()
		if trigger == 0:
			_check(state.defensive_team().select_pitcher(3), "legal next-batter replacement")
	_check(
		state.defensive_team().strikecraft_uses == 2, "extras and pitcher change do not reset cap"
	)
	state.phase = MatchState.Phase.INNING_TRANSITION
	state.continue_after_dead_ball()
	_check(state.defensive_team().strikecraft_uses == 0, "opponent has an independent game counter")
	_sequence(state, [4.0, 4.0, 4.0])
	state.record_strike()
	_check(state.defensive_team().strikecraft_uses == 1, "opponent may earn its own refund")
	_check(_strikecraft_fixture().home_team.strikecraft_uses == 0, "new game resets cap")
	_check(
		SeasonSponsorCatalog.earnings([{"item": "B03"}], ROSTER, {}).is_empty(), "no Cash payout"
	)


func _migrate_paid_gameplay_sponsor() -> void:
	SeasonSave.path = "user://strikecraft-migration-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(_seed_for("A07", 7), false, true)
	for _pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 7
	_record(season)
	season.build.commit(_command(season.build, "open"))
	_check(
		(
			season
			. build
			. commit(
				_command(
					season.build,
					"sponsor_buy",
					{"offer": _offer(season.build, "A07"), "replace": ""}
				)
			)
			. ok
		),
		"buy actual old-format Deli"
	)
	var before: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save genuine schema11")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == before, "preserve paid copy and current stock"
	)
	_check(FileAccess.get_file_as_string(SeasonSave.path) == bytes, "no load-only rewrite")
	_check(restored.build.to_data().sequence_sponsor_from == 2, "new pool starts next visit")
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		restored.build.view().shop.offers == season.build.view().shop.offers,
		"frozen same-visit rerolls"
	)
	_check(
		SeasonSave.save(restored) and SeasonSave.restore() != null, "migrated current visit replays"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		SeasonSave.save(restored) and SeasonSave.restore() != null, "expanded next visit replays"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _actual_release_costs() -> void:
	for human: bool in [true, false]:
		var lab: PitchBatLab = PitchBatLab.new()
		lab._configured_match = _strikecraft_fixture()
		var pitcher: PlayerMatchState = lab._configured_match.pitcher()
		pitcher.definition.starting_pitches = []
		for recipe: StringName in RECIPES.slice(0, 3):
			pitcher.definition.starting_pitches.append(ContentDB.get_pitch(recipe))
		pitcher.definition.natural_delivery = (
			pitcher.definition.starting_pitches[0].delivery_profile
		)
		pitcher.definition.season_sponsors.B02 = 4
		_equip(pitcher, "D02")
		lab._player_home = human
		add_child(lab)
		await _frames(4)
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		var paid: float = 0.0
		for index in range(3):
			lab._match_state.continue_after_dead_ball()
			lab._pitch_actor.reset_pitch()
			lab._selected_pitch_index = index
			lab._ai_pitch_preselected = true
			lab._pitch_effort = 1.0
			lab._pending_release_quality = 1.0
			lab._pending_release_overdrive = 0.2
			lab._pitch_target = Vector2(0, 1.05)
			lab._refresh_config()
			var before: float = pitcher.stamina_remaining
			lab._throw_pitch()
			_check(lab._pitch_actor.running, "actual human/AI recipe released")
			var cost: float = before - pitcher.stamina_remaining
			var expected: float = MatchLabSupport.stamina_cost(
				ContentDB.get_pitch(RECIPES[index]), 1.0
			)
			expected *= 0.85 * 0.88 * (1.016 if human else 1.0)
			_check(is_equal_approx(cost, expected), "Kit/College/overdrive costs paid once")
			paid += cost
			if index < 2:
				lab._match_state.record_foul()
		var before: float = pitcher.stamina_remaining
		lab._match_state.strikes = 2
		lab._match_state.record_strike()
		_check(
			is_equal_approx(pitcher.stamina_remaining - before, minf(6.0, paid * 0.25)),
			"refund derives from actual discounted physical releases"
		)
		_check(pitcher.first_batter_completed, "refund does not reset Kit's first-batter window")
		lab.queue_free()
		await _frames()
