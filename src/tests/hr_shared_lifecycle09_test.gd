extends "res://src/tests/hr_celebration07_test.gd"
## Explicit v2 lifecycle successor. Synthetic contract controls, not paid-world admission evidence.


class LifecycleLab:
	extends PitchBatLab
	var cleanup_calls: int = 0
	var refuse_cleanup: bool = false

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass

	func _cleanup_batted_ball(preserve_yard_launch: bool = false) -> void:
		cleanup_calls += 1
		if not refuse_cleanup:
			super._cleanup_batted_ball(preserve_yard_launch)


class ContractBoard:
	extends StadiumScoreboardCelebrationCore

	func _eligible() -> bool:
		return true


func _ready() -> void:
	for phase: MatchState.Phase in [MatchState.Phase.PLAY_DEAD, MatchState.Phase.GAME_END]:
		var lab: LifecycleLab = _lifecycle_fixture(phase)
		var state: BallPlayState = lab._ball_play_resolver.state
		var ball: BattedBallBody = lab._batted_ball
		lab._home_run.advance(lab, 6.0)
		_check(
			lab._home_run.flight_complete and lab._home_run.flight_end_reason == &"timeout",
			"unknown native surface uses honest flight timeout"
		)
		_check(
			lab._batted_ball == ball and not ball.is_queued_for_deletion(),
			"body retained through return tail"
		)
		lab._home_run.advance(lab, 0.7)
		_check(
			not lab._home_run.active and lab._batted_ball == null and ball.is_queued_for_deletion(),
			"supported body cleanup completes for phase %s" % phase
		)
		_check(
			(
				lab.cleanup_calls == 1
				and lab._ball_play_resolver.state == state
				and state.dead
				and state.result_floor == BallPlayState.ResultFloor.HOME_RUN
			),
			"single cleanup preserves terminal resolver evidence"
		)
		_dispose(lab)

	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
	lab._home_run._ground_seen = true
	lab._batted_ball.sleeping = true
	lab._home_run.advance(lab, 0.7)
	_check(
		lab._home_run.flight_end_reason == &"rest",
		"native ground history plus resting body ends flight"
	)
	_dispose(lab)

	lab = _lifecycle_fixture(MatchState.Phase.GAME_END)
	lab.refuse_cleanup = true
	lab._home_run.advance(lab, 6.0)
	lab._home_run.advance(lab, 0.7)
	lab._home_run.advance(lab, 10.0)
	_check(
		(
			lab.cleanup_calls == 1
			and lab._home_run.cleanup_refused
			and lab._home_run.presentation_pending(lab)
			and lab._batted_ball != null
		),
		"refused cleanup stays pending and never retries venue side effects"
	)
	_dispose(lab)

	lab = _lifecycle_fixture(MatchState.Phase.GAME_END)
	var previous: BattedBallBody = lab._batted_ball
	var replacement: BattedBallBody = BattedBallBody.new()
	lab.add_child(replacement)
	lab._batted_ball = replacement
	lab._home_run.advance(lab, 10.0)
	_check(
		(
			not lab._home_run.active
			and lab.cleanup_calls == 0
			and lab._batted_ball == replacement
			and not replacement.is_queued_for_deletion()
			and not previous.is_queued_for_deletion()
		),
		"changed context cannot dispose replacement or reclaim detached presentation body"
	)
	_dispose(lab)

	for new_hr: bool in [false, true]:
		lab = _lifecycle_fixture(MatchState.Phase.GAME_END)
		lab._ball_visibility = BallVisibility.new()
		lab.add_child(lab._ball_visibility)
		lab._ball_visibility.visible = true
		lab._ball_visibility.visibility_changed.connect(
			_replace_during_cleanup.bind(lab, new_hr), CONNECT_ONE_SHOT
		)
		var old_ball: BattedBallBody = lab._batted_ball
		lab._home_run.advance(lab, 6.0)
		lab._home_run.advance(lab, 0.7)
		_check(
			(
				lab._batted_ball != null
				and lab._batted_ball != old_ball
				and not lab._batted_ball.is_queued_for_deletion()
				and not old_ball.is_queued_for_deletion()
			),
			"visibility callback replacement survives supported cleanup"
		)
		if new_hr:
			_check(
				(
					lab._home_run.active
					and not lab._home_run.cleanup_refused
					and not lab._home_run.cleanup_attempted
					and lab._home_run.flight_end_reason == &""
				),
				"old completion cannot overwrite new HR lifecycle"
			)
		_dispose(lab)

	for arrival: bool in [false, true]:
		lab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
		var board: ContractBoard = ContractBoard.new()
		lab.add_child(board)
		board._configure(lab, Node3D.new())
		var outcome: BallPlayOutcome = BallPlayOutcome.new()
		outcome.result = BallPlayOutcome.Result.HOME_RUN
		board._on_resolved(outcome)
		_check(
			board._armed and not board.active and board.starts == 0,
			"v2 score arms without camera handoff"
		)
		board._begin_handoff()
		_check(board.starts == 0, "v2 live flight cannot begin mounted handoff")
		lab._home_run.advance(lab, 6.0)
		board._begin_handoff()
		_check(
			board.starts == 1 and board.active and board.wide_latch_at_start,
			"v2 handoff starts exactly once after flight complete"
		)
		lab._home_run.advance(lab, 0.7)
		_check(
			lab._home_run.active and lab._batted_ball != null,
			"fixed tail alone cannot retire mounted return body"
		)
		lab._debug_paused = true
		var elapsed: float = board.elapsed
		board._update_camera(lab._camera_director, lab._camera, 1.0, false, Vector3.ZERO)
		_check(board.elapsed == elapsed, "paused mounted integrator does not consume return clock")
		lab._debug_paused = false
		# Explicit synthetic arrival toggles test lifecycle gate, not camera pixel arrival.
		board.arrived = arrival
		lab._home_run.advance(lab, 0.01 if arrival else 3.4)
		_check(
			not lab._home_run.active and lab._batted_ball == null,
			"mounted arrival or bounded deadline releases supported lifecycle"
		)
		_check(
			(
				lab._home_run.return_end_reason
				== (&"return_complete" if arrival else &"return_timeout")
			),
			"mounted timeout is distinguished from completed return"
		)
		board._board.free()
		_dispose(lab)

	print("HR_SHARED09 checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _lifecycle_fixture(phase: MatchState.Phase) -> LifecycleLab:
	var lab: LifecycleLab = LifecycleLab.new()
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(lab)
	lab._match_state = MatchState.new()
	lab._match_state.phase = phase
	lab._camera_director = MatchCameraDirector.new()
	lab._camera_director._standard_fov = 75.0
	lab._camera = Camera3D.new()
	lab.add_child(lab._camera)
	lab._ball_play_resolver = BallPlayResolver.new()
	lab._ball_play_resolver.state = BallPlayState.new()
	lab._ball_play_resolver.state.dead = true
	lab._ball_play_resolver.state.result_floor = BallPlayState.ResultFloor.HOME_RUN
	lab._batted_ball = BattedBallBody.new()
	lab._batted_ball.freeze = true
	lab.add_child(lab._batted_ball)
	lab._batted_ball.surface_contact.connect(lab._on_batted_surface_contact)
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	lab._home_run.resolve_ball(lab, outcome)
	return lab


func _replace_during_cleanup(lab: LifecycleLab, new_hr: bool) -> void:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	if new_hr:
		lab._ball_play_resolver.state = BallPlayState.new()
		lab._ball_play_resolver.state.dead = true
		lab._ball_play_resolver.state.result_floor = BallPlayState.ResultFloor.HOME_RUN
		ball.surface_contact.connect(lab._on_batted_surface_contact)
		var outcome: BallPlayOutcome = BallPlayOutcome.new()
		outcome.result = BallPlayOutcome.Result.HOME_RUN
		lab._home_run.resolve_ball(lab, outcome)
