extends Node

var _failures: int = 0


func _ready() -> void:
	for run_seed in range(100):
		var first: Dictionary = _play_match(run_seed)
		var replay: Dictionary = _play_match(run_seed)
		_check(first == replay, "same seed must reproduce the complete match: %d" % run_seed)
	_test_extra_inning_walkoff()
	if _failures == 0:
		print("Wiffaltro match soak passed: 100 seeded state-machine matches plus replays.")
	get_tree().quit(0 if _failures == 0 else 1)


func _play_match(run_seed: int) -> Dictionary:
	var state: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, "Away", "Home"
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed
	var pitches: int = 0
	while state.phase != MatchState.Phase.GAME_END and pitches < 2000:
		state.continue_after_dead_ball()
		if state.phase == MatchState.Phase.GAME_END:
			break
		_check(state.phase == MatchState.Phase.PRE_PITCH, "match must return to pre-Pitch")
		var prior_total: int = state.away_team.runs + state.home_team.runs
		var prior_pa: int = state.plate_appearance_number
		_check(state.begin_pitch(), "ready match must accept a pitch")
		_check(not state.begin_pitch(), "live match must reject duplicate pitch starts")
		var roll: int = rng.randi_range(0, 99)
		if roll < 25:
			state.record_ball()
		elif roll < 53:
			state.record_strike(roll % 2 == 0)
		elif roll < 65:
			var prior_strikes: int = state.strikes
			state.record_foul()
			_check(state.strikes == mini(2, prior_strikes + 1), "foul must preserve two-strike cap")
		elif roll < 85:
			state.begin_ball_in_play()
			state.record_ball_in_play_out()
		else:
			state.begin_ball_in_play()
			var hit: BallPlayOutcome.Result = [
				BallPlayOutcome.Result.SINGLE, BallPlayOutcome.Result.DOUBLE,
				BallPlayOutcome.Result.TRIPLE, BallPlayOutcome.Result.HOME_RUN,
			][rng.randi_range(0, 3)]
			var runs: int = state.record_hit(hit)
			_check(
				state.away_team.runs + state.home_team.runs == prior_total + runs,
				"hit scoring must agree with returned runner advancement"
			)
		pitches += 1
		_check(state.balls >= 0 and state.balls < 4, "ball count must remain legal")
		_check(state.strikes >= 0 and state.strikes < 3, "strike count must remain legal")
		_check(state.outs >= 0 and state.outs <= 3, "outs must remain legal")
		_check(state.away_team.runs + state.home_team.runs >= prior_total, "runs cannot decrease")
		_check(
			state.plate_appearance_number in [prior_pa, prior_pa + 1],
			"one pitch cannot advance multiple batters"
		)
	_check(state.phase == MatchState.Phase.GAME_END, "seed %d must finish within budget" % run_seed)
	_check(not state.winner_name.is_empty(), "finished match must identify its winner")
	var result: Dictionary = {
		"away": state.away_team.runs, "home": state.home_team.runs,
		"inning": state.inning, "winner": state.winner_name, "pitches": pitches,
	}
	state.continue_after_dead_ball()
	_check(state.phase == MatchState.Phase.GAME_END, "continue cannot restart a completed match")
	_check(not state.begin_pitch(), "completed match cannot accept a pitch")
	return result


func _test_extra_inning_walkoff() -> void:
	var state: MatchState = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "Away", "Home")
	# Ten scoreless half-innings, without assigning inning/score fields directly.
	for half in range(10):
		for out in range(3):
			_check(state.begin_pitch(), "scripted out must start from pre-Pitch")
			state.begin_ball_in_play()
			state.record_ball_in_play_out()
			state.continue_after_dead_ball()
	_check(state.inning == 6 and state.top_half, "tied regulation must enter extras")
	_check(not state.bases.second.is_empty(), "extra inning must start with runner on second")
	for out in range(3):
		state.begin_pitch()
		state.begin_ball_in_play()
		state.record_ball_in_play_out()
		state.continue_after_dead_ball()
	_check(
		not state.top_half and not state.bases.second.is_empty(),
		"both sides receive extra runner"
	)
	state.begin_pitch()
	state.begin_ball_in_play()
	state.record_hit(BallPlayOutcome.Result.HOME_RUN)
	_check(state.phase == MatchState.Phase.GAME_END, "extra-inning home lead must walk off")
	_check(
		state.home_team.runs == 2 and state.winner_name == "Home",
		"walkoff must score both runners"
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
