class_name PitchBatLabDefenseSupport
extends RefCounted

const CHARGE_RADIUS_M: float = 5.0
const CHARGE_REACTION_SECONDS: float = 0.20


static func try_primary(lab: PitchBatLab) -> void:
	if lab._primary_attempts >= 2 or lab._fielding_cooldown_seconds > 0.0:
		return
	if lab._primary_fielder.stationary and not lab._primary_fielder.reaction_ready():
		return
	var ball_position: Vector3 = lab._batted_ball.global_position
	if not lab._primary_fielder.first_step.is_zero_approx():
		if not lab._primary_fielder.reaction_ready():
			return
		if not FielderFirstStep.unobstructed(lab._primary_fielder, ball_position):
			return
	var allowed_height: float = (
		FieldingResolver.MAX_GROUND_CONTROL_HEIGHT_M
		if lab._ball_play_resolver.state.has_grounded
		else FieldingResolver.MAX_AIR_CONTROL_HEIGHT_M
	)
	if ball_position.y < 0.0 or ball_position.y > allowed_height:
		return
	var distance: float = lab._primary_fielder.horizontal_distance_to(ball_position)
	if distance > lab._primary_fielder.reach_m:
		return

	var outcome: FieldingResolver.Outcome = FieldingResolver.resolve(
		distance,
		lab._batted_ball.linear_velocity.length(),
		ball_position.y,
		lab._ball_play_resolver.state.has_grounded,
		lab._primary_fielder.fielding_rating,
		lab._primary_fielder.last_reaction_margin_seconds,
		lab._primary_fielder.handling_scale,
		(
			(
				SeasonSponsorEffects.ground_margin(
					lab._match_state.fielder().definition,
					lab._ball_play_resolver.state.has_grounded
				)
				+ SeasonCornerstone.margin(lab._match_state, lab._primary_fielder)
				+ MatchAbilities.ground_margin(
					lab._match_state.fielder().definition,
					lab._ball_play_resolver.state.has_grounded,
					(
						lab._primary_fielder.last_reaction_margin_seconds
						if lab._primary_fielder.reaction_ready()
						else -1.0
					)
				)
			)
			if lab._match_mode
			else 0.0
		)
	)
	lab._primary_attempts += 1
	lab._apply_fielding_outcome(&"primary_fielder", lab._primary_fielder.global_position, outcome)


static func advance_pitcher(lab: PitchBatLab, delta: float) -> void:
	var state: BallPlayState = lab._ball_play_resolver.state
	if lab._pitcher_attempted or state.defender_touched:
		return
	if state.elapsed_seconds < reaction_delay(lab):
		return
	var ball: Vector3 = lab._batted_ball.global_position
	if lab._batted_ball.linear_velocity.length() <= lab.SETTLED_SPEED_MPS:
		return
	var speed: float = lerpf(3.6, 4.6, float(MatchLabSupport.pitcher_fielding_rating(lab)) / 10.0)
	speed *= gear_factor(lab, "speed")
	var plan: FielderPlan = FielderPlanner.plan(
		ball,
		lab._batted_ball.linear_velocity,
		state.has_grounded,
		lab._pitcher_marker.global_position,
		speed,
		PitcherDefense.REACTION_RADIUS_M
	)
	var target: Vector3 = Vector3(plan.intercept_position.x, 0.0, plan.intercept_position.z)
	# Limited local pursuit of grounders and catchable air balls, never a Pitch.
	if not plan.reachable or target.distance_to(lab.MOUND_ORIGIN) > CHARGE_RADIUS_M:
		return
	lab._pitcher_marker.global_position = DefenderSpacing.step_around_mound(
		lab._pitcher_marker.global_position,
		target,
		lab._primary_fielder.global_position,
		speed * maxf(0.0, delta)
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
		ball,
		lab._batted_ball.linear_velocity,
		position,
		lab._ball_play_resolver.state.has_grounded,
		MatchLabSupport.pitcher_fielding_rating(lab),
		gear_factor(lab, "handling"),
		(
			MatchAbilities.ground_margin(
				lab._match_state.pitcher().definition,
				lab._ball_play_resolver.state.has_grounded,
				lab._ball_play_resolver.state.elapsed_seconds - reaction_delay(lab)
			)
			if lab._match_mode
			else 0.0
		)
	)
	lab._apply_fielding_outcome(&"pitcher", position, outcome, ball)


static func reaction_delay(lab: PitchBatLab) -> float:
	if lab._match_mode and lab._match_state != null:
		return SeasonGearCatalog.reaction_delay(
			CHARGE_REACTION_SECONDS, lab._match_state.pitcher().definition
		)
	return CHARGE_REACTION_SECONDS


static func gear_factor(lab: PitchBatLab, key: String) -> float:
	if lab._match_mode and lab._match_state != null:
		return SeasonGearCatalog.factor(lab._match_state.pitcher().definition, key)
	return 1.0
