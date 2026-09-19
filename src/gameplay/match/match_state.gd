class_name MatchState
extends RefCounted

enum Phase {
	PRE_PITCH,
	PITCH_IN_FLIGHT,
	BALL_IN_PLAY,
	PLAY_DEAD,
	INNING_TRANSITION,
	GAME_END,
}

const REGULATION_INNINGS: int = 5
const OUTS_PER_HALF: int = 3
const BALLS_FOR_WALK: int = 4
const STRIKES_FOR_OUT: int = 3
const MERCY_RUNS: int = 10

var away_team: TeamMatchState
var home_team: TeamMatchState
var bases: BaseState = BaseState.new()
var phase: Phase = Phase.PRE_PITCH
var inning: int = 1
var top_half: bool = true
var outs: int = 0
var balls: int = 0
var strikes: int = 0
var plate_appearance_number: int = 1
var elapsed_seconds: float = 0.0
var between_batters: bool = true
var last_event: String = "Game ready"
var winner_name: String = ""

static func create(
	away: TeamMatchState,
	home: TeamMatchState
) -> MatchState:
	var result: MatchState = MatchState.new()
	result.away_team = away
	result.home_team = home
	return result

func batting_team() -> TeamMatchState:
	return away_team if top_half else home_team

func defensive_team() -> TeamMatchState:
	return home_team if top_half else away_team

func batter() -> PlayerMatchState:
	return batting_team().current_batter()

func on_deck_batter() -> PlayerMatchState:
	return batting_team().on_deck_batter()

func pitcher() -> PlayerMatchState:
	return defensive_team().current_pitcher()

func fielder() -> PlayerMatchState:
	return defensive_team().current_fielder()

func begin_pitch() -> bool:
	if phase != Phase.PRE_PITCH:
		return false
	phase = Phase.PITCH_IN_FLIGHT
	between_batters = false
	return true

func begin_ball_in_play() -> void:
	phase = Phase.BALL_IN_PLAY

func record_called_pitch(is_strike: bool) -> StringName:
	if is_strike:
		return record_strike(false)
	return record_ball()

func record_ball() -> StringName:
	balls += 1
	if balls >= BALLS_FOR_WALK:
		var batter_id: StringName = batter().definition.id
		var runs_scored: int = bases.advance_for_walk(batter_id)
		_add_runs(runs_scored)
		_complete_plate_appearance("Walk")
		return &"walk"
	phase = Phase.PLAY_DEAD
	last_event = "Ball"
	return &"ball"

func record_strike(swinging: bool = true) -> StringName:
	strikes += 1
	if strikes >= STRIKES_FOR_OUT:
		outs += 1
		_complete_plate_appearance(
			"Strikeout swinging" if swinging else "Called strikeout"
		)
		return &"strikeout"
	phase = Phase.PLAY_DEAD
	last_event = "Swinging strike" if swinging else "Called strike"
	return &"strike"

func record_foul() -> StringName:
	if strikes < STRIKES_FOR_OUT - 1:
		strikes += 1
	phase = Phase.PLAY_DEAD
	last_event = "Foul"
	return &"foul"

func record_ball_in_play_out(
	runs_scored: int = 0,
	description: String = "Out"
) -> void:
	_add_runs(runs_scored)
	outs += 1
	_complete_plate_appearance(description)

func record_hit(result: BallPlayOutcome.Result) -> int:
	var batter_id: StringName = batter().definition.id
	var runs_scored: int = bases.advance_for_hit(result, batter_id)
	_add_runs(runs_scored)
	_complete_plate_appearance(_hit_name(result))
	return runs_scored

func continue_after_dead_ball() -> void:
	if phase == Phase.GAME_END:
		return
	if phase == Phase.INNING_TRANSITION:
		_advance_half_inning()
		return
	if phase == Phase.PLAY_DEAD:
		phase = Phase.PRE_PITCH

func can_change_defense() -> bool:
	return (
		between_batters
		and (phase == Phase.PRE_PITCH or phase == Phase.PLAY_DEAD)
	)

func half_label() -> String:
	return ("TOP" if top_half else "BOT") + " %d" % inning

func score_label() -> String:
	return "%s %d  |  %s %d" % [
		away_team.display_name,
		away_team.runs,
		home_team.display_name,
		home_team.runs,
	]

func _add_runs(amount: int) -> void:
	if amount <= 0:
		return
	batting_team().runs += amount
	if (
		not top_half
		and inning >= REGULATION_INNINGS
		and home_team.runs > away_team.runs
	):
		_finish_game("Walk-off")
	elif (
		_mercy_available()
		and _run_difference() >= MERCY_RUNS
		and (not top_half or home_team.runs > away_team.runs)
	):
		_finish_game("Mercy rule")

func _complete_plate_appearance(description: String) -> void:
	last_event = description
	batting_team().advance_batter()
	plate_appearance_number += 1
	balls = 0
	strikes = 0
	between_batters = true
	if phase == Phase.GAME_END:
		return
	if outs >= OUTS_PER_HALF:
		phase = Phase.INNING_TRANSITION
	else:
		phase = Phase.PLAY_DEAD

func _advance_half_inning() -> void:
	if top_half:
		if (
			_mercy_available()
			and home_team.runs - away_team.runs >= MERCY_RUNS
		):
			_finish_game("Mercy rule")
			return
		if (
			inning >= REGULATION_INNINGS
			and home_team.runs > away_team.runs
		):
			_finish_game("Home team leads after top half")
			return
		top_half = false
	else:
		if inning >= REGULATION_INNINGS and home_team.runs != away_team.runs:
			_finish_game("Final")
			return
		if _mercy_available() and _run_difference() >= MERCY_RUNS:
			_finish_game("Mercy rule")
			return
		top_half = true
		inning += 1

	outs = 0
	balls = 0
	strikes = 0
	bases.clear()
	between_batters = true
	phase = Phase.PRE_PITCH
	last_event = half_label()
	if inning > REGULATION_INNINGS:
		bases.second = StringName(
			"extra_runner.%s.%d" % [
				"away" if top_half else "home",
				inning,
			]
		)

func _mercy_available() -> bool:
	var completed_innings: int = inning - 1 if top_half else inning
	return completed_innings >= 3

func _run_difference() -> int:
	return absi(away_team.runs - home_team.runs)

func _finish_game(reason: String) -> void:
	phase = Phase.GAME_END
	winner_name = (
		away_team.display_name
		if away_team.runs > home_team.runs
		else home_team.display_name
	)
	last_event = "%s: %s wins" % [reason, winner_name]

func _hit_name(result: BallPlayOutcome.Result) -> String:
	match result:
		BallPlayOutcome.Result.SINGLE:
			return "Single"
		BallPlayOutcome.Result.DOUBLE:
			return "Double"
		BallPlayOutcome.Result.TRIPLE:
			return "Triple"
		BallPlayOutcome.Result.HOME_RUN:
			return "Home Run"
		_:
			return "Ball in play"
