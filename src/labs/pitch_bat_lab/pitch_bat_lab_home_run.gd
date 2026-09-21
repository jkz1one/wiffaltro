class_name PitchBatLabHomeRun
extends RefCounted

const CARRY_SECONDS: float = 1.25
const HOLD_SECONDS: float = 4.40

var active: bool = false
var elapsed: float = 0.0
var wide_shot: bool = false


func resolve_ball(lab: PitchBatLab, outcome: BallPlayOutcome) -> void:
	active = outcome.result == BallPlayOutcome.Result.HOME_RUN
	elapsed = 0.0
	wide_shot = false
	if lab._batted_ball == null:
		return
	if active:
		# Scoring is already final. Let the real body visibly clear the wall;
		# later contacts must never create another result or ground record.
		lab._batted_ball.surface_contact.disconnect(lab._on_batted_surface_contact)
		lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	else:
		lab._batted_ball.global_position = outcome.resolution_position
		lab._batted_ball.stop_and_freeze()


func advance(lab: PitchBatLab, delta: float) -> void:
	if not active:
		return
	elapsed += maxf(0.0, delta)
	if elapsed >= CARRY_SECONDS and not wide_shot:
		wide_shot = true
		if lab._batted_ball != null:
			lab._batted_ball.stop_and_freeze()
		lab._camera_director.set_shot(MatchCameraDirector.Shot.ESTABLISHING)
	if elapsed >= HOLD_SECONDS:
		active = false
