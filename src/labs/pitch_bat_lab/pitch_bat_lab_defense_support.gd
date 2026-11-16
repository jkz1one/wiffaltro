class_name PitchBatLabDefenseSupport
extends RefCounted

const CHARGE_RADIUS_M: float = 5.0
const CHARGE_REACTION_SECONDS: float = 0.20


static func try_primary(lab: PitchBatLab) -> void:
	if (
		StadiumSurfaceTerrainRuntime.requested(lab)
		or lab.hillside_pitcher_motion != null
		or (
			is_instance_valid(lab._primary_fielder) and lab._primary_fielder.hillside_motion != null
		)
	):
		_try_primary_supported(lab)
		return
	if lab._primary_attempts >= 2 or lab._fielding_cooldown_seconds > 0.0:
		return
	if lab._primary_fielder.stationary and not lab._primary_fielder.reaction_ready():
		return
	var ball_position: Vector3 = lab._batted_ball.global_position
	if not StadiumPropertyRuntime.clear_control(lab, lab._primary_fielder, ball_position):
		return
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
	if StadiumSurfaceTerrainRuntime.requested(lab):
		_advance_terrain_pitcher(lab, ball, state.has_grounded, speed, delta)
		return
	if lab.hillside_pitcher_motion != null:
		_advance_supported_pitcher(lab, ball, state.has_grounded, speed, delta)
		return
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
	var next_position: Vector3 = DefenderSpacing.step_around_mound(
		lab._pitcher_marker.global_position,
		target,
		lab._primary_fielder.global_position,
		speed * maxf(0.0, delta)
	)

	lab._pitcher_marker.global_position = StadiumPropertyRuntime.pitcher_step(
		lab, target, speed * maxf(0, delta), next_position
	)


static func try_pitcher(lab: PitchBatLab, previous: Vector3, current: Vector3) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	var night_state: MatchState = lab._match_state
	if (
		StadiumSurfaceTerrainRuntime.requested(lab)
		or lab.hillside_pitcher_motion != null
		or (
			is_instance_valid(lab._primary_fielder) and lab._primary_fielder.hillside_motion != null
		)
	):
		_try_pitcher_supported(lab, previous, current)
		return
	if lab._pitcher_attempted or lab._fielding_cooldown_seconds > 0.0:
		return
	var position: Vector3 = lab._pitcher_marker.global_position
	var ball: Vector3 = PitcherDefense.attempt_position(previous, current, position)
	if (
		ball == Vector3.INF
		or not StadiumPropertyRuntime.clear_control(lab, lab._pitcher_marker, ball)
	):
		return
	# Establish every floor reached before control, including a crossing in
	# this frame. Only the original mound envelope can override Single.
	lab._ball_play_resolver.observe_segment(previous, ball)
	if (
		not StadiumSurfaceNightRuntime.continue_action(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state)
	):
		return
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


static func control_frame(lab: PitchBatLab, defender: Node3D, ball: Vector3) -> Dictionary:
	if StadiumSurfaceTerrainRuntime.requested(lab):
		var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
		return {} if owner == null else owner.control_frame(defender, ball)
	# Select only the actual actor's independent binding; no unbound fallback in a bound lab.
	if (
		not is_instance_valid(lab)
		or not is_instance_valid(defender)
		or not is_instance_valid(lab._primary_fielder)
		or not ball.is_finite()
		or not defender.global_position.is_finite()
	):
		return {}
	var context: FielderController = lab._primary_fielder
	var motion: StadiumHillsideDefenderMotion
	if defender == context:
		motion = context.hillside_motion
	elif defender == lab._pitcher_marker:
		motion = lab.hillside_pitcher_motion
	else:
		return {}
	if motion == null or motion._field != lab._field_definition or defender.get_parent() != lab:
		return {}
	var record: Dictionary = motion.support_record(context, Vector2(ball.x, ball.z))
	if record.is_empty():
		return {}
	var height_m: float = ball.y - defender.global_position.y
	var minimum_height_m: float = float(record.support_height) - defender.global_position.y
	if not is_finite(height_m) or not is_finite(minimum_height_m):
		return {}
	return {"height_m": height_m, "minimum_height_m": minimum_height_m}


static func _try_primary_supported(lab: PitchBatLab) -> void:
	if lab._primary_attempts >= 2 or lab._fielding_cooldown_seconds > 0.0:
		return
	if not is_instance_valid(lab._primary_fielder) or not is_instance_valid(lab._batted_ball):
		return
	if lab._primary_fielder.stationary and not lab._primary_fielder.reaction_ready():
		return
	var ball_position: Vector3 = lab._batted_ball.global_position
	var frame: Dictionary = control_frame(lab, lab._primary_fielder, ball_position)
	if frame.is_empty():
		return
	if not StadiumPropertyRuntime.clear_control(lab, lab._primary_fielder, ball_position):
		return
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
	if (
		float(frame.height_m) < float(frame.minimum_height_m)
		or float(frame.height_m) > allowed_height
	):
		return
	var distance: float = lab._primary_fielder.horizontal_distance_to(ball_position)
	if distance > lab._primary_fielder.reach_m:
		return

	var outcome: FieldingResolver.Outcome = FieldingResolver.resolve(
		distance,
		lab._batted_ball.linear_velocity.length(),
		float(frame.height_m),
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
		),
		float(frame.minimum_height_m)
	)
	lab._primary_attempts += 1
	lab._apply_fielding_outcome(&"primary_fielder", lab._primary_fielder.global_position, outcome)


static func _try_pitcher_supported(lab: PitchBatLab, previous: Vector3, current: Vector3) -> void:
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	var terrain_state: MatchState = lab._match_state
	if lab._pitcher_attempted or lab._fielding_cooldown_seconds > 0.0:
		return
	if not is_instance_valid(lab._pitcher_marker) or not is_instance_valid(lab._batted_ball):
		return
	var position: Vector3 = lab._pitcher_marker.global_position
	if not previous.is_finite() or not current.is_finite() or not position.is_finite():
		return
	var ball: Vector3 = PitcherDefense.closest_position(previous, current, position)
	var frame: Dictionary = control_frame(lab, lab._pitcher_marker, ball)
	if frame.is_empty():
		return
	var horizontal_distance: float = Vector2(ball.x - position.x, ball.z - position.z).length()
	if (
		horizontal_distance > PitcherDefense.REACTION_RADIUS_M
		or float(frame.height_m) < float(frame.minimum_height_m)
		or float(frame.height_m) > PitcherDefense.MAX_REACTION_HEIGHT_M
	):
		return
	if (
		ball == Vector3.INF
		or not StadiumPropertyRuntime.clear_control(lab, lab._pitcher_marker, ball)
	):
		return
	# Establish every floor reached before control, including a crossing in
	# this frame. Only the original mound envelope can override Single.
	lab._ball_play_resolver.observe_segment(previous, ball)
	if not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, terrain_state):
		return
	if lab._ball_play_resolver.state.dead:
		return
	lab._pitcher_attempted = true
	var outcome: FieldingResolver.Outcome = PitcherDefense.resolve_supported(
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
		),
		float(frame.minimum_height_m)
	)
	lab._apply_fielding_outcome(&"pitcher", position, outcome, ball)


static func _advance_supported_pitcher(
	lab: PitchBatLab, ball: Vector3, has_grounded: bool, speed: float, delta: float
) -> void:
	var motion: StadiumHillsideDefenderMotion = lab.hillside_pitcher_motion
	if not motion.guard_pitcher(lab):
		return
	if not is_finite(delta) or not is_finite(speed) or speed < 0:
		motion.fail_pitcher("Pitcher movement needs finite timing and speed.")
		return
	var target: Vector3 = lab.hillside_pitcher_target
	if target != Vector3.INF:
		# A diagnostic target is an explicit selection, never an automatic override.
		if not target.is_finite():
			motion.fail_pitcher("The explicit pitcher target must be finite.")
			return
	else:
		if not motion.tracking_context_valid(lab._primary_fielder, lab):
			return
		if motion.tracking_due(delta):
			var started_usec: int = Time.get_ticks_usec()
			var providers: Dictionary = motion.planning_providers(lab._primary_fielder, delta, lab)
			if providers.is_empty():
				return
			var plan: FielderPlan = FielderPlanner.plan(
				ball,
				lab._batted_ball.linear_velocity,
				has_grounded,
				lab._pitcher_marker.global_position,
				speed,
				PitcherDefense.REACTION_RADIUS_M,
				false,
				providers.support,
				providers.arrival
			)
			motion.record_tracking_plan(plan, Time.get_ticks_usec() - started_usec)
		# Pitcher keeps reachable-only pursuit. Ball-center Y is never a feet goal.
		var retained_plan: FielderPlan = motion.last_tracking_plan
		if (
			retained_plan == null
			or not retained_plan.reachable
			or not retained_plan.supported_feet_position.is_finite()
		):
			return
		target = retained_plan.supported_feet_position
	# Original target-eligibility disk in XZ, not a 3D charge or path leash.
	if (
		Vector2(target.x - lab.MOUND_ORIGIN.x, target.z - lab.MOUND_ORIGIN.z).length()
		> CHARGE_RADIUS_M
	):
		return
	lab._pitcher_marker.global_position = StadiumPropertyRuntime.pitcher_step(
		lab, target, speed * maxf(0.0, delta), lab._pitcher_marker.global_position
	)


static func _advance_terrain_pitcher(
	lab: PitchBatLab, ball: Vector3, has_grounded: bool, speed: float, delta: float
) -> void:
	var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	if owner == null:
		return
	var providers: Dictionary = owner.planning_providers(lab._pitcher_marker)
	if providers.is_empty():
		return
	var plan: FielderPlan = FielderPlanner.plan(
		ball,
		lab._batted_ball.linear_velocity,
		has_grounded,
		lab._pitcher_marker.global_position,
		speed,
		PitcherDefense.REACTION_RADIUS_M,
		false,
		providers.support,
		providers.arrival
	)
	var target: Vector3 = plan.supported_feet_position
	if (
		not plan.reachable
		or not target.is_finite()
		or (
			Vector2(target.x - lab.MOUND_ORIGIN.x, target.z - lab.MOUND_ORIGIN.z).length()
			> CHARGE_RADIUS_M
		)
	):
		return
	lab._pitcher_marker.global_position = StadiumPropertyRuntime.pitcher_step(
		lab, target, speed * maxf(delta, 0), lab._pitcher_marker.global_position
	)
