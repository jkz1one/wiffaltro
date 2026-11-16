extends "res://src/tests/hr_shared_lifecycle09_test.gd"
## Focused synthetic callback regressions only. No scored-play/venue admission claims.


class LegacyContractBoard:
	extends StadiumCenterBoardCelebration

	func _eligible() -> bool:
		return true


class FielderProbe:
	extends FielderController
	var endings: int = 0

	func _ready() -> void:
		pass

	func end_play() -> void:
		endings += 1


func _ready() -> void:
	for legacy: bool in [false, true]:
		for replace: bool in [false, true]:
			_handoff_reentry(legacy, replace)
	for replace: bool in [false, true]:
		_resolve_reentry(replace)
	for new_hr: bool in [false, true]:
		_cleanup_reentry(new_hr)
	for queued: bool in [false, true]:
		for legacy: bool in [false, true]:
			for target: String in ["ball", "camera", "lab"]:
				_handoff_disposal(legacy, target, queued)
		for target: String in ["ball", "camera", "lab"]:
			# The lab owns the emitting Label: immediate subtree free is engine-invalid.
			# Its supported queue_free case remains; excluded work earns no pass check.
			if target == "lab" and not queued:
				continue
			_resolve_disposal(target, queued)
		for target: String in ["fielder", "lab"]:
			if target == "lab" and not queued:
				continue
			_cleanup_disposal(target, queued)
	_ordinary_controls()
	print("HR_REENTRY10 checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _headline(lab: LifecycleLab) -> Label:
	var label: Label = Label.new()
	lab.add_child(label)
	lab._hr_celebration_label = label
	lab._home_run._celebration_label = label
	label.text = "OLD HOME RUN"
	label.visible = true
	return label


func _replacement_hr(lab: LifecycleLab, replace: bool) -> void:
	if replace:
		var ball: BattedBallBody = BattedBallBody.new()
		ball.freeze = true
		lab.add_child(ball)
		lab._batted_ball = ball
		lab._ball_play_resolver.state = BallPlayState.new()
		lab._ball_play_resolver.state.dead = true
		lab._ball_play_resolver.state.result_floor = BallPlayState.ResultFloor.HOME_RUN
	var current: BattedBallBody = lab._batted_ball
	if not current.surface_contact.is_connected(lab._on_batted_surface_contact):
		current.surface_contact.connect(lab._on_batted_surface_contact)
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	lab._home_run.resolve_ball(lab, outcome)
	lab._home_run.elapsed = 0.37
	lab._home_run.flight_elapsed = 0.13
	current.global_position = Vector3(7, 2, 13)
	if lab._hr_celebration_label != null:
		lab._hr_celebration_label.text = "REPLACEMENT"
		lab._hr_celebration_label.visible = true


func _handoff_reentry(legacy: bool, replace: bool) -> void:
	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
	var board: Variant = LegacyContractBoard.new() if legacy else ContractBoard.new()
	lab.add_child(board)
	var model: Node3D = Node3D.new()
	lab.add_child(model)
	if legacy:
		board.configure(lab, model)
	else:
		board._configure(lab, model)
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	board._on_resolved(outcome)
	lab._home_run.flight_complete = true
	lab._home_run.wide_shot = true
	var old_body: BattedBallBody = lab._batted_ball
	var old_play: BallPlayState = lab._ball_play_resolver.state
	board.handoff_started.connect(_rearm_during_handoff.bind(lab, board, replace), CONNECT_ONE_SHOT)
	board._begin_handoff()
	_check(
		(
			board._armed
			and not board.active
			and board.starts == 1
			and is_equal_approx(board.elapsed, 0.27)
			and not lab._home_run.flight_complete
		),
		(
			"old handoff cannot activate/reset callback-rearmed generation legacy=%s replace=%s"
			% [legacy, replace]
		)
	)
	_check(
		lab._camera_director.shot == MatchCameraDirector.Shot.BATTING,
		"old handoff cannot overwrite callback camera choice"
	)
	_check(
		(
			not lab._batted_ball.is_queued_for_deletion()
			and (
				(lab._batted_ball != old_body and lab._ball_play_resolver.state != old_play)
				if replace
				else (lab._batted_ball == old_body and lab._ball_play_resolver.state == old_play)
			)
		),
		"handoff preserves callback-selected body/play including same-body generation"
	)
	lab._home_run.flight_complete = true
	lab._home_run.wide_shot = true
	board._begin_handoff()
	_check(
		board.active and not board._armed and board.starts == 2,
		"replacement generation can subsequently begin its own ordinary handoff"
	)
	_dispose(lab)


func _rearm_during_handoff(lab: LifecycleLab, board: Variant, replace: bool) -> void:
	if replace:
		_replacement_hr(lab, true)
	lab._home_run.flight_complete = false
	lab._home_run.wide_shot = false
	board.reset()
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	board._on_resolved(outcome)
	board.elapsed = 0.27
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)


func _resolve_reentry(replace: bool) -> void:
	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
	var label: Label = _headline(lab)
	var original: BattedBallBody = lab._batted_ball
	var original_play: BallPlayState = lab._ball_play_resolver.state
	label.visibility_changed.connect(_replacement_hr.bind(lab, replace), CONNECT_ONE_SHOT)
	var incoming: BallPlayOutcome = BallPlayOutcome.new()
	incoming.result = BallPlayOutcome.Result.DOUBLE
	incoming.resolution_position = Vector3(-5, 0, -5)
	lab._home_run.resolve_ball(lab, incoming)
	_check(
		(
			lab._home_run.presentation_pending(lab)
			and lab._home_run.active
			and is_equal_approx(lab._home_run.elapsed, 0.37)
			and is_equal_approx(lab._home_run.flight_elapsed, 0.13)
		),
		"old resolve cannot reset same-body or replacement HR from headline visibility"
	)
	_check(
		(
			lab._batted_ball.global_position == Vector3(7, 2, 13)
			and not lab._batted_ball.is_queued_for_deletion()
			and label.visible
			and label.text == "REPLACEMENT"
		),
		"old non-HR resolve cannot freeze/reposition/hide replacement"
	)
	_check(
		(
			(lab._batted_ball != original and lab._ball_play_resolver.state != original_play)
			if replace
			else (lab._batted_ball == original and lab._ball_play_resolver.state == original_play)
		),
		"resolve callback deliberately covers both identity replacement and same-context reentry"
	)
	_dispose(lab)


func _cleanup_reentry(new_hr: bool) -> void:
	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.GAME_END)
	var label: Label = _headline(lab)
	var fielder: FielderProbe = FielderProbe.new()
	lab.add_child(fielder)
	lab._primary_fielder = fielder
	var old_body: BattedBallBody = lab._batted_ball
	label.visibility_changed.connect(
		_replace_from_headline_cleanup.bind(lab, new_hr), CONNECT_ONE_SHOT
	)
	lab._cleanup_batted_ball()
	_check(
		(
			old_body.is_queued_for_deletion()
			and lab._batted_ball != null
			and lab._batted_ball != old_body
			and not lab._batted_ball.is_queued_for_deletion()
		),
		"headline cleanup callback replacement survives original body retirement"
	)
	_check(
		fielder.endings == 0 and is_equal_approx(lab._settled_seconds, 19.0),
		"old cleanup cannot end replacement fielder or reset its settled clock"
	)
	if new_hr:
		_check(
			(
				lab._home_run.presentation_pending(lab)
				and is_equal_approx(lab._home_run.elapsed, 0.37)
				and not lab._home_run.cleanup_attempted
				and not lab._home_run.cleanup_refused
			),
			"headline cleanup callback new HR stays active and unmodified"
		)
	_dispose(lab)


func _replace_from_headline_cleanup(lab: LifecycleLab, new_hr: bool) -> void:
	if new_hr:
		_replacement_hr(lab, true)
	else:
		var ball: BattedBallBody = BattedBallBody.new()
		ball.freeze = true
		lab.add_child(ball)
		lab._batted_ball = ball
	lab._settled_seconds = 19.0


func _ordinary_controls() -> void:
	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
	var fielder: FielderProbe = FielderProbe.new()
	lab.add_child(fielder)
	lab._primary_fielder = fielder
	lab._settled_seconds = 19.0
	_headline(lab)
	lab._cleanup_batted_ball()
	_check(
		(
			lab._batted_ball == null
			and not lab._home_run.active
			and fielder.endings == 1
			and lab._settled_seconds == 0.0
		),
		"ordinary cleanup retains historical fielder/timer completion"
	)
	_dispose(lab)
	lab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
	_headline(lab)
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.DOUBLE
	outcome.resolution_position = Vector3(1, 2, 3)
	lab._home_run.resolve_ball(lab, outcome)
	_check(
		(
			not lab._home_run.active
			and lab._batted_ball.global_position == outcome.resolution_position
		),
		"ordinary non-HR resolve retains historical position and inactive state"
	)
	_dispose(lab)


func _dispose_on_callback(target: Node, queued: bool, lab: LifecycleLab) -> void:
	lab._settled_seconds = 19.0
	lab._home_run.elapsed = 19.0
	if queued:
		target.queue_free()
	else:
		target.free()


func _handoff_disposal(legacy: bool, target_name: String, queued: bool) -> void:
	print(
		"HR_REENTRY10_DISPOSAL handoff legacy=", legacy, " target=", target_name, " queued=", queued
	)
	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
	# Keep the synthetic handler outside the lab to observe a disposed-lab callback.
	var board: Variant = LegacyContractBoard.new() if legacy else ContractBoard.new()
	add_child(board)
	var model: Node3D = Node3D.new()
	add_child(model)
	if legacy:
		board.configure(lab, model)
	else:
		board._configure(lab, model)
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	board._on_resolved(outcome)
	lab._home_run.flight_complete = true
	lab._home_run.wide_shot = true
	var target: Node = (
		lab
		if target_name == "lab"
		else (lab._camera if target_name == "camera" else lab._batted_ball)
	)
	board.handoff_started.connect(_dispose_on_callback.bind(target, queued, lab), CONNECT_ONE_SHOT)
	board._begin_handoff()
	_check(
		(
			(is_instance_valid(target) and target.is_queued_for_deletion())
			if queued
			else not is_instance_valid(target)
		),
		"handoff callback actually disposed/queued the selected target"
	)
	_check(
		not board.active and not board._armed and board.starts == 1,
		(
			"handoff aborts native disposal legacy=%s target=%s queued=%s"
			% [legacy, target_name, queued]
		)
	)
	# Avoid historical teardown helpers dereferencing deliberately disposed fixture fields.
	if legacy:
		board._lab = null
	else:
		board._lab = null
		board._camera = null
	board.free()
	model.free()
	if is_instance_valid(lab) and not lab.is_queued_for_deletion():
		_dispose(lab)


func _resolve_disposal(target_name: String, queued: bool) -> void:
	print("HR_REENTRY10_DISPOSAL resolve target=", target_name, " queued=", queued)
	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
	var label: Label = _headline(lab)
	var hr: PitchBatLabHomeRun = lab._home_run
	var target: Node = (
		lab
		if target_name == "lab"
		else (lab._camera if target_name == "camera" else lab._batted_ball)
	)
	label.visibility_changed.connect(
		_dispose_on_callback.bind(target, queued, lab), CONNECT_ONE_SHOT
	)
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.DOUBLE
	outcome.resolution_position = Vector3(5, 0, 5)
	hr.resolve_ball(lab, outcome)
	_check(
		(
			(is_instance_valid(target) and target.is_queued_for_deletion())
			if queued
			else not is_instance_valid(target)
		),
		"resolve callback actually disposed/queued the selected target"
	)
	_check(
		not hr.active and hr.elapsed == 19.0,
		"old resolve aborts native disposal target=%s queued=%s" % [target_name, queued]
	)
	if is_instance_valid(lab) and not lab.is_queued_for_deletion():
		_dispose(lab)


func _cleanup_disposal(target_name: String, queued: bool) -> void:
	print("HR_REENTRY10_DISPOSAL cleanup target=", target_name, " queued=", queued)
	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.GAME_END)
	var label: Label = _headline(lab)
	var fielder: FielderProbe = FielderProbe.new()
	lab.add_child(fielder)
	lab._primary_fielder = fielder
	var target: Node = lab if target_name == "lab" else fielder
	label.visibility_changed.connect(
		_dispose_on_callback.bind(target, queued, lab), CONNECT_ONE_SHOT
	)
	lab._cleanup_batted_ball()
	_check(
		(
			(is_instance_valid(target) and target.is_queued_for_deletion())
			if queued
			else not is_instance_valid(target)
		),
		"cleanup callback actually disposed/queued the selected target"
	)
	_check(
		not is_instance_valid(lab) or lab._settled_seconds == 19.0,
		"old cleanup aborts native disposal target=%s queued=%s" % [target_name, queued]
	)
	if is_instance_valid(lab) and not lab.is_queued_for_deletion():
		_dispose(lab)
