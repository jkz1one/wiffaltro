class_name PitchBatLabHomeRun
extends RefCounted

# Historical reference only; no longer a physical-flight deadline.
const CARRY_SECONDS: float = 1.25
# Text-only timings. These never extend flight, camera or at-bat cadence deadlines.
const NOTICE_FADE_IN_SECONDS: float = 0.25
const NOTICE_FADE_OUT_SECONDS: float = 0.60
const NOTICE_SECONDS: float = 4.40
const CELEBRATION_FADE_IN_SECONDS: float = 0.20
const CELEBRATION_HOLD_SECONDS: float = 1.20
const CELEBRATION_FADE_OUT_SECONDS: float = 0.50
const CELEBRATION_SECONDS: float = (
	CELEBRATION_FADE_IN_SECONDS + CELEBRATION_HOLD_SECONDS + CELEBRATION_FADE_OUT_SECONDS
)
const HOLD_SECONDS: float = 4.40
const MAX_FLIGHT_SECONDS: float = 6.0
const LANDING_CONTEXT_SECONDS: float = 0.65
const PRESENTATION_TAIL_SECONDS: float = 0.65
const MAX_RETURN_SECONDS: float = 4.0
# Presentation only: retain the authored shell/material and all body/collider operands.
const BALL_TARGET_PIXELS: float = 4.0
const BALL_MAX_SCALE: float = 8.0
const BALL_SCALE_RESPONSE: float = 12.0
const BALL_RESTORE_SECONDS: float = 0.35

var active: bool = false
var elapsed: float = 0.0
var wide_shot: bool = false
var flight_complete: bool = false
var flight_end_reason: StringName = &""
var flight_elapsed: float = 0.0
var landing_elapsed: float = 0.0
var presentation_tail_elapsed: float = 0.0
var return_end_reason: StringName = &""
var cleanup_attempted: bool = false
var cleanup_refused: bool = false
var celebration_text: String = ""
var _generation: int = 0
var _ground_seen: bool = false
var _body: WeakRef
var _resolver: BallPlayResolver
var _play: BallPlayState
var _match: MatchState
var _motion: BallInPlayCamera
var _notice_play: BallPlayState
var _notice_payload: String = ""
var _celebration_label: Label
var _ball_visual: WeakRef
var _ball_visual_scale: Vector3 = Vector3.ONE
var _ball_scale_factor: float = 1.0
var _ball_restore_factor: float = 1.0
var _occlusion_marker: HomeRunOcclusionMarker


func resolve_ball(lab: PitchBatLab, outcome: BallPlayOutcome) -> void:
	var incoming_ball: BattedBallBody = lab._batted_ball
	var incoming_resolver: BallPlayResolver = lab._ball_play_resolver
	var incoming_play: BallPlayState = (
		incoming_resolver.state if incoming_resolver != null else null
	)
	var incoming_match: MatchState = lab._match_state
	var incoming_camera: Camera3D = lab._camera
	var incoming_had_camera: bool = incoming_camera != null
	var incoming_had_ball: bool = incoming_ball != null
	var incoming_director: MatchCameraDirector = lab._camera_director
	var incoming_motion: BallInPlayCamera = (
		incoming_director._live_coverage if incoming_director != null else null
	)
	var cancelled_generation: int = _generation + 1
	cancel()
	# Hiding the old headline may synchronously resolve or replace another play.
	# Even same-body/same-play reentry owns a newer generation than this call.
	if (
		not is_instance_valid(lab)
		or lab.is_queued_for_deletion()
		or (
			incoming_had_ball
			and (not is_instance_valid(incoming_ball) or incoming_ball.is_queued_for_deletion())
		)
		or (
			incoming_had_camera
			and (not is_instance_valid(incoming_camera) or incoming_camera.is_queued_for_deletion())
		)
		or _generation != cancelled_generation
		or lab._camera != incoming_camera
		or lab._home_run != self
		or lab._batted_ball != incoming_ball
		or lab._ball_play_resolver != incoming_resolver
		or lab._match_state != incoming_match
		or lab._camera_director != incoming_director
		or (incoming_resolver != null and incoming_resolver.state != incoming_play)
		or (incoming_director != null and incoming_director._live_coverage != incoming_motion)
	):
		return
	active = outcome.result == BallPlayOutcome.Result.HOME_RUN
	elapsed = 0.0
	wide_shot = false
	flight_complete = false
	flight_end_reason = &""
	flight_elapsed = 0.0
	landing_elapsed = 0.0
	presentation_tail_elapsed = 0.0
	_ground_seen = false
	return_end_reason = &""
	cleanup_attempted = false
	cleanup_refused = false
	_notice_play = null
	_notice_payload = ""
	if lab._batted_ball == null:
		active = false
		return
	if active:
		# The resolver result is final. Let the real body visibly clear the wall;
		# later contacts must never create another result or ground record.
		lab._batted_ball.surface_contact.disconnect(lab._on_batted_surface_contact)
		_body = weakref(lab._batted_ball)
		for child: Node in lab._batted_ball.get_children():
			if child is WiffleBallVisual:
				_ball_visual = weakref(child)
				_ball_visual_scale = child.scale
				break
		_resolver = lab._ball_play_resolver
		_play = _resolver.state
		_match = lab._match_state
		# resolve_ball runs before record_hit / advance_for_hit mutates the bases.
		# Match bases are authoritative; never infer a slam from runs or status text.
		var bases_before: BaseState = lab._base_state
		if lab._match_mode:
			bases_before = _match.bases if _match != null else null
		celebration_text = (
			"GRAND SLAM"
			if bases_before != null and bases_before.occupied_count() == 3
			else "HOME RUN"
		)
		_celebration_label = lab._hr_celebration_label
		_motion = lab._camera_director._live_coverage
		var attachment_generation: int = _generation
		var attached: HomeRunOcclusionMarker = HomeRunOcclusionMarker.attach(lab, self)
		if (
			_generation != attachment_generation
			or not is_instance_valid(lab)
			or lab.is_queued_for_deletion()
			or lab._home_run != self
			or lab._camera != incoming_camera
			or lab._camera_director != incoming_director
			or not presentation_pending(lab)
		):
			if is_instance_valid(attached):
				attached.dispose()
			return
		_occlusion_marker = attached
		_motion.home_run_follow = true
		lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	else:
		lab._batted_ball.global_position = outcome.resolution_position
		lab._batted_ball.stop_and_freeze()


func advance(lab: PitchBatLab, delta: float) -> void:
	if not active:
		StadiumRisingAppleRuntime.sync_clock(lab, self)
		return
	if not presentation_pending(lab):
		flight_end_reason = &"cancelled_context"
		cancel()
		StadiumRisingAppleRuntime.sync_clock(lab, self)
		return
	var step: float = maxf(0.0, delta)
	elapsed += step
	if not flight_complete:
		flight_elapsed += step
		var ball: BattedBallBody = _body.get_ref() as BattedBallBody
		var ground_now: bool = false
		for contact: Node3D in ball.get_colliding_bodies():
			if contact.get_meta(&"ball_surface", &"") == &"ground":
				ground_now = true
				break
		_ground_seen = _ground_seen or ground_now
		if _ground_seen:
			landing_elapsed += step
		# A slow apex or wall graze cannot qualify as a landing. Keep the real
		# body through the landing observation, including any first bounce.
		if (
			_ground_seen
			and landing_elapsed >= LANDING_CONTEXT_SECONDS
			and (ground_now or ball.sleeping)
		):
			_finish_flight(lab, ball, &"rest" if ball.sleeping else &"landed")
		elif flight_elapsed >= MAX_FLIGHT_SECONDS:
			_finish_flight(lab, ball, &"timeout")
	else:
		presentation_tail_elapsed += step
	_advance_ball_readability(lab, step)
	if (
		flight_complete
		and elapsed >= HOLD_SECONDS
		and presentation_tail_elapsed >= PRESENTATION_TAIL_SECONDS
		and (not _return_pending(lab) or presentation_tail_elapsed >= MAX_RETURN_SECONDS)
	):
		if return_end_reason == &"":
			return_end_reason = &"return_timeout" if _return_pending(lab) else &"return_complete"
		_complete(lab)
	StadiumRisingAppleRuntime.sync_clock(lab, self)


func _return_pending(lab: PitchBatLab) -> bool:
	var callback: Callable = lab._camera_director.presentation_override
	if not callback.is_valid():
		return false
	var owner: Object = callback.get_object()
	return (
		(owner is StadiumScoreboardCelebrationCore or owner is StadiumCenterBoardCelebration)
		and owner.return_pending(lab)
	)


func _complete(lab: PitchBatLab) -> void:
	if cleanup_attempted:
		return
	cleanup_attempted = true
	# Supported venue cleanup owns body retirement, including terminal GAME_END.
	# Keep presentation/support captured until it succeeds; never bypass a refusal.
	var ball: BattedBallBody = _body.get_ref() as BattedBallBody
	var play: BallPlayState = _play
	var resolver: BallPlayResolver = _resolver
	var match_state: MatchState = _match
	lab._cleanup_batted_ball()
	if (
		_play == play
		and _resolver == resolver
		and _match == match_state
		and lab._batted_ball == ball
		and active
		and presentation_pending(lab)
		and is_instance_valid(ball)
		and not ball.is_queued_for_deletion()
	):
		cleanup_refused = true
		flight_end_reason = &"cleanup_refused"


func presentation_pending(lab: PitchBatLab) -> bool:
	var ball: BattedBallBody = _body.get_ref() as BattedBallBody if _body != null else null
	return (
		active
		and is_instance_valid(lab)
		and is_instance_valid(ball)
		and not ball.is_queued_for_deletion()
		and ball.get_parent() == lab
		and lab._batted_ball == ball
		and lab._ball_play_resolver == _resolver
		and _resolver != null
		and _resolver.state == _play
		and _play != null
		and _play.dead
		and _play.result_floor == BallPlayState.ResultFloor.HOME_RUN
		and lab._match_state == _match
		and lab._camera_director != null
		and lab._camera_director._live_coverage == _motion
	)


func _finish_flight(lab: PitchBatLab, ball: BattedBallBody, reason: StringName) -> void:
	_ball_restore_factor = _ball_scale_factor
	flight_complete = true
	flight_end_reason = reason
	wide_shot = true
	presentation_tail_elapsed = 0.0
	_motion.home_run_follow = false
	ball.stop_and_freeze()
	lab._camera_director.set_shot(MatchCameraDirector.Shot.ESTABLISHING)


func cancel() -> void:
	_generation += 1
	var cancelled_generation: int = _generation
	active = false
	var marker: HomeRunOcclusionMarker = _occlusion_marker
	_occlusion_marker = null
	# Cancellation/replacement cannot leave a changed shell on a reused body.
	var visual: WiffleBallVisual = (
		_ball_visual.get_ref() as WiffleBallVisual if _ball_visual != null else null
	)
	_ball_visual = null
	if is_instance_valid(visual):
		visual.scale = _ball_visual_scale
	_ball_scale_factor = 1.0
	_ball_restore_factor = 1.0
	celebration_text = ""
	var headline: Label = _celebration_label
	_celebration_label = null
	if _motion != null:
		_motion.home_run_follow = false
	_body = null
	_resolver = null
	_play = null
	_match = null
	_motion = null
	# Hiding a cue emits visibility_changed synchronously, like the headline.
	# Clear old ownership first and never overwrite a newer reentrant resolve.
	if is_instance_valid(marker):
		marker.dispose()
	if _generation != cancelled_generation:
		return
	# Clear captured state before visibility/removal callbacks; never overwrite a new play.
	if is_instance_valid(headline):
		headline.text = ""
		if (
			_generation != cancelled_generation
			or not is_instance_valid(headline)
			or headline.is_queued_for_deletion()
		):
			return
		headline.visible = false


func compact_notice(lab: PitchBatLab, payload: String) -> bool:
	# Keep suppression after natural completion, but never claim a new play/status.
	if _notice_play != null:
		return (
			lab._ball_play_resolver != null
			and lab._ball_play_resolver.state == _notice_play
			and payload == _notice_payload
		)
	if not presentation_pending(lab) or not payload.begins_with("HOME RUN"):
		return false
	_notice_play = _play
	_notice_payload = payload
	return true


func _advance_ball_readability(lab: PitchBatLab, step: float) -> void:
	var visual: WiffleBallVisual = (
		_ball_visual.get_ref() as WiffleBallVisual if _ball_visual != null else null
	)
	var ball: BattedBallBody = _body.get_ref() as BattedBallBody if _body != null else null
	if (
		not is_instance_valid(visual)
		or visual.is_queued_for_deletion()
		or not is_instance_valid(ball)
		or visual.get_parent() != ball
	):
		return
	if flight_complete:
		_ball_scale_factor = lerpf(
			_ball_restore_factor,
			1.0,
			smoothstep(0.0, BALL_RESTORE_SECONDS, presentation_tail_elapsed)
		)
	else:
		var target: float = 1.0
		var camera: Camera3D = lab._camera
		if (
			is_instance_valid(camera)
			and camera.is_inside_tree()
			and not camera.is_position_behind(ball.global_position)
		):
			# Projection honors viewport aspect, camera keep_aspect and orthographic views.
			# Measure the original cosmetic shell, never the smaller physics radius.
			var radius: float = WiffleBallVisual.RADIUS * _ball_visual_scale.x
			var center: Vector2 = camera.unproject_position(ball.global_position)
			var edge: Vector2 = camera.unproject_position(
				ball.global_position + camera.global_basis.x * radius
			)
			var diameter: float = center.distance_to(edge) * 2.0
			if diameter > 0.0:
				target = clampf(BALL_TARGET_PIXELS / diameter, 1.0, BALL_MAX_SCALE)
		_ball_scale_factor = lerpf(
			_ball_scale_factor, target, 1.0 - exp(-BALL_SCALE_RESPONSE * step)
		)
	visual.scale = _ball_visual_scale * _ball_scale_factor
