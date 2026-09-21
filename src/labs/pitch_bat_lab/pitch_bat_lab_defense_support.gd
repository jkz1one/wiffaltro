class_name PitchBatLabDefenseSupport
extends RefCounted

const CHARGE_RADIUS_M: float = 5.0
const CHARGE_REACTION_SECONDS: float = 0.20


static func advance_pitcher(lab: PitchBatLab, delta: float) -> void:
	var state: BallPlayState = lab._ball_play_resolver.state
	if lab._pitcher_attempted or state.defender_touched:
		return
	if state.elapsed_seconds < CHARGE_REACTION_SECONDS:
		return
	var ball: Vector3 = lab._batted_ball.global_position
	if lab._batted_ball.linear_velocity.length() <= lab.SETTLED_SPEED_MPS:
		return
	var speed: float = lerpf(3.6, 4.6, float(MatchLabSupport.pitcher_fielding_rating(lab)) / 10.0)
	var plan: FielderPlan = FielderPlanner.plan(ball, lab._batted_ball.linear_velocity,
		state.has_grounded, lab._pitcher_marker.global_position, speed, PitcherDefense.REACTION_RADIUS_M)
	var target: Vector3 = Vector3(plan.intercept_position.x, 0.0, plan.intercept_position.z)
	# Limited local pursuit of grounders and catchable air balls, never a Pitch.
	if not plan.reachable or target.distance_to(lab.MOUND_ORIGIN) > CHARGE_RADIUS_M:
		return
	lab._pitcher_marker.global_position = DefenderSpacing.step_around_mound(
		lab._pitcher_marker.global_position, target,
		lab._primary_fielder.global_position, speed * maxf(0.0, delta)
	)


static func try_pitcher(lab: PitchBatLab, previous: Vector3, current: Vector3) -> void:
	if lab._pitcher_attempted or lab._fielding_cooldown_seconds > 0.0:
		return
	var position: Vector3 = lab._pitcher_marker.global_position
	var ball: Vector3 = PitcherDefense.attempt_position(previous, current, position)
	if ball == Vector3.INF:
		return
	# Establish every floor reached before control, including a crossing in
	# this frame. Only the original mound envelope can override Single.
	lab._ball_play_resolver.observe_segment(previous, ball)
	if lab._ball_play_resolver.state.dead:
		return
	lab._pitcher_attempted = true
	var outcome: FieldingResolver.Outcome = PitcherDefense.resolve(
		ball, lab._batted_ball.linear_velocity, position,
		lab._ball_play_resolver.state.has_grounded, MatchLabSupport.pitcher_fielding_rating(lab)
	)
	lab._apply_fielding_outcome(&"pitcher", position, outcome, ball)
