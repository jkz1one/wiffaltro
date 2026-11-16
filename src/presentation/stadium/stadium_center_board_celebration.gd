class_name StadiumCenterBoardCelebration
extends Node
## Deterministic post-score presentation only. Never changes the body or HR lifecycle.

signal handoff_started
signal wide_arrived

const POLICY: String = "raised-center-postflight-hr-arrival-bounded-v2"
var active: bool = false
var arrived: bool = false
var elapsed: float = 0
var starts: int = 0
var reason: String = ""
var wide_latch_at_start: bool = false
var start_pose: Transform3D
var target_pose: Transform3D
var _generation: int = 0
var _armed: bool = false
var _lab: PitchBatLab
var _candidate: Node3D
var _match: MatchState
var _ball_id: int = 0
var _velocity: Vector3 = Vector3.ZERO
var _turn_speed: float = 0


func configure(lab: PitchBatLab, candidate: Node3D) -> void:
	_lab = lab
	_candidate = candidate
	_match = lab._match_state
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = -100
	lab._ball_play_resolver.play_resolved.connect(_on_resolved)
	lab._camera_director.presentation_override = _update_camera


func bind_match(state: MatchState) -> void:
	if state != _match:
		reset()
		_match = state


func reset() -> void:
	_generation += 1
	active = false
	_armed = false
	arrived = false
	elapsed = 0
	reason = ""
	_ball_id = 0
	_velocity = Vector3.ZERO
	_turn_speed = 0


func _process(_delta: float) -> void:
	if (active or _armed) and not _hold_valid():
		reset()


func _hold_valid() -> bool:
	return _eligible() and _lab._match_state == _match and _post_score_phase() \
		and _lab._home_run.active and is_instance_valid(_lab._batted_ball) \
		and _lab._batted_ball.get_instance_id() == _ball_id


func return_pending(lab: PitchBatLab) -> bool:
	return lab == _lab and (_armed or active) and not arrived and _hold_valid()


func _on_resolved(outcome: BallPlayOutcome) -> void:
	# This signal runs after PitchBatLab's scoring listener. No forecast or
	# authoring flag can promote an unresolved/live ball into celebration.
	if outcome.result != BallPlayOutcome.Result.HOME_RUN or not _eligible() \
		or not _lab._home_run.active or not _lab._ball_play_resolver.state.dead \
		or not _post_score_phase() \
		or not is_instance_valid(_lab._batted_ball):
		return
	var id: int = _lab._batted_ball.get_instance_id()
	if (active or _armed) and _ball_id == id:
		return
	reset()
	_match = _lab._match_state
	_ball_id = id
	_armed = true


func _begin_handoff() -> void:
	if not _armed or not _hold_valid() or not _lab._home_run.flight_complete:
		return
	_armed = false
	starts += 1
	reason = "confirmed_home_run"
	wide_latch_at_start = _lab._home_run.wide_shot
	start_pose = _lab._camera.global_transform
	_velocity = _lab._camera_director._live_coverage._velocity
	_turn_speed = _lab._camera_director._live_coverage._turn_speed
	var handoff_generation: int = _generation
	var handoff_lab: PitchBatLab = _lab
	var handoff_match: MatchState = _match
	var handoff_ball_id: int = _ball_id
	var handoff_body: BattedBallBody = _lab._batted_ball
	var handoff_resolver: BallPlayResolver = _lab._ball_play_resolver
	var handoff_play: BallPlayState = handoff_resolver.state
	var handoff_director: MatchCameraDirector = _lab._camera_director
	var handoff_camera: Camera3D = _lab._camera
	handoff_started.emit()
	# A callback can reset and arm a valid replacement. It is not our handoff,
	# even when the same body/play is reused; never reset that newer generation.
	if not is_instance_valid(self) or is_queued_for_deletion() \
		or not is_instance_valid(handoff_lab) or handoff_lab.is_queued_for_deletion() \
		or not is_instance_valid(handoff_camera) or handoff_camera.is_queued_for_deletion() \
		or not is_instance_valid(handoff_body) or handoff_body.is_queued_for_deletion() \
		or _generation != handoff_generation or _lab != handoff_lab or _match != handoff_match \
		or _ball_id != handoff_ball_id \
		or handoff_lab._ball_play_resolver != handoff_resolver \
		or handoff_resolver.state != handoff_play \
		or handoff_lab._camera_director != handoff_director or handoff_lab._camera != handoff_camera:
		return
	if not _hold_valid():
		reset()
		return
	active = true
	_lab._camera_director.set_shot(MatchCameraDirector.Shot.ESTABLISHING)
	target_pose = _lab._camera_director._desired_transform(Vector3.ZERO, 0)
	# Capture motion at the real post-flight handoff, never at the scoring instant.


func _eligible() -> bool:
	return is_instance_valid(_lab) and is_instance_valid(_candidate) \
		and _lab._match_state != null and _lab._match_mode \
		and not _lab._managed_match and _lab._automation == null \
		and _lab.get_meta("stadium_center_board_lab_only", false) \
		and _lab.get_meta("stadium_candidate_only", false) \
		and _candidate.get_parent() == get_parent() \
		and _candidate.get_meta("center_board_study", "") == StadiumCenterBoardCandidate.ID \
		and _candidate.transform == StadiumCenterBoardCandidate.pose()


func _post_score_phase() -> bool:
	return _lab._match_state.phase in [MatchState.Phase.PLAY_DEAD,
		MatchState.Phase.INNING_TRANSITION, MatchState.Phase.GAME_END]


func _update_camera(director: MatchCameraDirector, camera: Camera3D, delta: float,
	_ball_live: bool, _ball_position: Vector3) -> bool:
	if _armed and is_instance_valid(_lab) \
		and director == _lab._camera_director and camera == _lab._camera:
		_begin_handoff()
	if not active:
		return false
	# Recheck synchronously: the ordinary lab can finish its HR hold or replace
	# the body after this node's early-priority lifecycle update in the same frame.
	if not _hold_valid():
		reset()
		return false
	if director.shot != MatchCameraDirector.Shot.ESTABLISHING:
		return false
	if _lab._debug_paused or delta <= 0:
		return true
	elapsed += delta
	var steps: int = maxi(1, int(ceil(delta * 120)))
	var dt: float = delta / steps
	for step in range(steps):
		_advance(camera, dt, director._standard_fov)
	if not arrived and camera.global_position.distance_to(target_pose.origin) < 0.12 \
		and camera.global_basis.get_rotation_quaternion().angle_to(
			target_pose.basis.get_rotation_quaternion()) < 0.012 \
		and absf(camera.fov - director._standard_fov) < 0.15:
		arrived = true
		wide_arrived.emit()
	return true


func _advance(camera: Camera3D, dt: float, fov: float) -> void:
	# Same critically damped, bounded translation/rotation used by live coverage.
	# Carry its current velocity into the result transition rather than snapping
	# or using the ordinary unbounded ESTABLISHING interpolation.
	var acceleration: Vector3 = ((target_pose.origin - camera.global_position) * 64 \
		- _velocity * 16).limit_length(BallInPlayCamera.MAX_ACCELERATION)
	_velocity = (_velocity + acceleration * dt).limit_length(BallInPlayCamera.MAX_SPEED)
	camera.global_position += _velocity * dt
	var current: Quaternion = camera.global_basis.get_rotation_quaternion()
	var target: Quaternion = target_pose.basis.get_rotation_quaternion()
	var angle: float = current.angle_to(target)
	var desired_speed: float = minf(BallInPlayCamera.MAX_TURN_SPEED,
		sqrt(2 * BallInPlayCamera.MAX_TURN_ACCELERATION * angle))
	_turn_speed = move_toward(_turn_speed, desired_speed,
		BallInPlayCamera.MAX_TURN_ACCELERATION * dt)
	if angle > 0.0001:
		camera.global_basis = Basis(current.slerp(target, minf(1, _turn_speed * dt / angle)))
	camera.fov = lerpf(camera.fov, fov, 1 - exp(-3 * dt))


func _exit_tree() -> void:
	reset()
	if not is_instance_valid(_lab):
		return
	if _lab._camera_director.presentation_override == _update_camera:
		_lab._camera_director.presentation_override = Callable()
	if _lab._ball_play_resolver.play_resolved.is_connected(_on_resolved):
		_lab._ball_play_resolver.play_resolved.disconnect(_on_resolved)
