class_name FielderController
extends CharacterBody3D

const AC02_PASSIVE_18 = preload("res://src/diagnostics/ac02_passive_attribution.gd")

@export var move_speed_mps: float = 4.6
@export var fielding_rating: int = 6
@export var reach_m: float = 0.66

var anchor_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var active: bool = false
var stationary: bool = false
var first_step: Vector3 = Vector3.ZERO
var last_reaction_margin_seconds: float = 0.0
var handling_scale: float = 1.0
var reaction_delay_seconds: float = 0.11
var pitcher_lane_z: float = INF
var pitcher_defender: Node3D
# Two fixed per-play steering states; the shared begin/end hooks reset both actors.
var stadium_pool_fielder_route: Dictionary = {}
var stadium_pool_pitcher_route: Dictionary = {}
var stadium_obstacles: Array[Dictionary] = []:
	set(value):
		stadium_obstacles = value
		reset_stadium_pool_routes()
var stadium_boundary_clip: Callable
var stadium_waterfall_step: Callable
var stadium_waterfall_clip: Callable
# Explicit private support binding. Null preserves the ordinary controller.
var hillside_motion: StadiumHillsideDefenderMotion
var terrain_motion: StadiumSurfaceTerrainRuntime
var _base_reaction_delay: float = 0.11
var _sky_reader: bool = false
var _play_elapsed_seconds: float = 0.0
var _avatar: PlayerAvatar
var _reach_marker: MeshInstance3D


func _ready() -> void:
	_build_debug_fielder()


func set_anchor(new_anchor: Vector3) -> void:
	if not StadiumSurfaceTerrainRuntime.actor_allowed(self):
		return
	if terrain_motion != null:
		terrain_motion.set_anchor(self, new_anchor)
		return
	if hillside_motion != null:
		hillside_motion.set_anchor(self, new_anchor)
		return
	anchor_position = new_anchor
	if not active:
		global_position = new_anchor
	target_position = new_anchor


func bind_hillside_motion(
	field: FieldDefinition, terrain: Node3D, anchor_index: int, profile: String = "hill"
) -> bool:
	if hillside_motion == null:
		hillside_motion = StadiumHillsideDefenderMotion.new()
	return hillside_motion.configure(self, field, terrain, anchor_index, profile)


func hillside_motion_blocked() -> bool:
	return hillside_motion != null and hillside_motion.blocked


func set_pitcher_lane(pitcher_z: float) -> void:
	pitcher_lane_z = pitcher_z


func begin_play(
	anchored: bool = false, step: Vector3 = Vector3.ZERO, launch: BattedBallLaunch = null
) -> void:
	var ac02_token: int = AC02_PASSIVE_18.enter("fielder_controller.begin_play")
	_ac02_passive_18_begin_play(anchored, step, launch)
	AC02_PASSIVE_18.leave(ac02_token)


func _ac02_passive_18_begin_play(
	anchored: bool = false, step: Vector3 = Vector3.ZERO, launch: BattedBallLaunch = null
) -> void:
	if not StadiumSurfaceTerrainRuntime.actor_allowed(self):
		return
	if terrain_motion != null and not terrain_motion.guard_actor(self):
		return
	reset_stadium_pool_routes()
	if hillside_motion != null:
		if not hillside_motion.reset_anchor(self):
			return
		last_reaction_margin_seconds = 0.0
	if _sky_reader:
		reaction_delay_seconds = MatchAbilities.sky_delay(_base_reaction_delay, launch)
	active = true
	stationary = anchored
	first_step = Vector3.ZERO if anchored else step
	if not first_step.is_zero_approx():
		last_reaction_margin_seconds = 0.0
	if stationary:
		last_reaction_margin_seconds = 0.0
	_play_elapsed_seconds = 0.0
	global_position = anchor_position
	target_position = anchor_position


func end_play() -> void:
	if not StadiumSurfaceTerrainRuntime.actor_allowed(self):
		return
	if terrain_motion != null and not terrain_motion.guard_actor(self):
		return
	reset_stadium_pool_routes()
	active = false
	stationary = false
	first_step = Vector3.ZERO
	velocity = Vector3.ZERO
	if hillside_motion != null:
		last_reaction_margin_seconds = 0.0
		if not hillside_motion.reset_anchor(self):
			_play_elapsed_seconds = 0.0
			return
	global_position = anchor_position
	target_position = anchor_position
	_play_elapsed_seconds = 0.0


func reset_stadium_pool_routes() -> void:
	stadium_pool_fielder_route.clear()
	stadium_pool_pitcher_route.clear()


func configure_player(player: PlayerDefinition) -> void:
	if player == null:
		return
	fielding_rating = player.fielding
	set_meta(&"player_id", player.id)
	move_speed_mps = lerpf(3.80, 5.20, clampf(float(fielding_rating) / 10.0, 0.0, 1.0))
	move_speed_mps *= SeasonGearCatalog.factor(player, "speed")
	handling_scale = SeasonGearCatalog.factor(player, "handling")
	reach_m = lerpf(0.52, 0.76, clampf(float(fielding_rating) / 10.0, 0.0, 1.0))
	reaction_delay_seconds = lerpf(0.24, 0.09, clampf(float(fielding_rating) / 10.0, 0.0, 1.0))
	reaction_delay_seconds = SeasonGearCatalog.reaction_delay(reaction_delay_seconds, player)
	_base_reaction_delay = reaction_delay_seconds
	_sky_reader = player.season_abilities.has(SeasonAbilities.SKY)
	if _reach_marker != null:
		_reach_marker.scale = Vector3(reach_m, 1.0, reach_m)
	if _avatar != null:
		_avatar.configure(
			PlayerAvatar.Role.FIELDER,
			player.bats == PlayerDefinition.Handedness.LEFT,
			player.throws == PlayerDefinition.Handedness.LEFT,
			Color(0.18, 0.52, 0.95)
		)


func plan_for_ball(
	ball_position: Vector3, ball_velocity: Vector3, has_grounded: bool, physics_delta: float = 0.0
) -> void:
	var ac02_token: int = AC02_PASSIVE_18.enter("fielder_controller.plan_for_ball")
	_ac02_passive_18_plan_for_ball(ball_position, ball_velocity, has_grounded, physics_delta)
	AC02_PASSIVE_18.leave(ac02_token)


func _ac02_passive_18_plan_for_ball(
	ball_position: Vector3, ball_velocity: Vector3, has_grounded: bool, physics_delta: float = 0.0
) -> void:
	if not StadiumSurfaceTerrainRuntime.actor_allowed(self):
		return
	if not active:
		return
	if not pursuit_ready():
		return
	if terrain_motion != null:
		var providers: Dictionary = terrain_motion.planning_providers(self)
		if providers.is_empty():
			return
		var plan: FielderPlan = FielderPlanner.plan(
			ball_position,
			ball_velocity,
			has_grounded,
			global_position,
			move_speed_mps,
			reach_m,
			stationary,
			providers.support,
			providers.arrival
		)
		target_position = (
			anchor_position
			if stationary
			else (
				plan.supported_feet_position
				if plan.supported_feet_position.is_finite()
				else global_position
			)
		)
		last_reaction_margin_seconds = 0.0
		return
	_ac02_passive_18_plan_for_ball_remaining_checks(
		ball_position, ball_velocity, has_grounded, physics_delta
	)


func _ac02_passive_18_plan_for_ball_remaining_checks(
	ball_position: Vector3,
	ball_velocity: Vector3,
	has_grounded: bool,
	physics_delta: float
) -> void:
	if hillside_motion != null:
		if not hillside_motion.tracking_context_valid(self):
			if hillside_motion.last_tracking_plan != null:
				target_position = global_position
				last_reaction_margin_seconds = 0.0
			return
		if not hillside_motion.tracking_due(physics_delta):
			return
		var started_usec: int = Time.get_ticks_usec()
		var providers: Dictionary = hillside_motion.planning_providers(self, physics_delta)
		if providers.is_empty():
			target_position = global_position
			return
		var supported_plan: FielderPlan = FielderPlanner.plan(
			ball_position,
			ball_velocity,
			has_grounded,
			global_position,
			move_speed_mps,
			reach_m,
			stationary,
			providers.support,
			providers.arrival
		)
		hillside_motion.record_tracking_plan(supported_plan, Time.get_ticks_usec() - started_usec)
		if stationary:
			target_position = anchor_position
		elif supported_plan.supported_feet_position.is_finite():
			target_position = supported_plan.supported_feet_position
		else:
			target_position = global_position
		# Advisory arrival cannot supply a handling bonus to actual control.
		last_reaction_margin_seconds = 0.0
		return
	var plan_result: FielderPlan = FielderPlanner.plan(
		ball_position,
		ball_velocity,
		has_grounded,
		global_position,
		move_speed_mps,
		reach_m,
		stationary
	)
	target_position = anchor_position if stationary else plan_result.intercept_position
	last_reaction_margin_seconds = plan_result.reaction_margin_seconds


func reaction_ready() -> bool:
	return _play_elapsed_seconds >= reaction_delay_seconds


func pursuit_ready() -> bool:
	return (
		reaction_ready()
		and (
			first_step.is_zero_approx()
			or _play_elapsed_seconds + 0.000001 >= SeasonJumpstart.STEP_SECONDS
		)
	)


func horizontal_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _physics_process(delta: float) -> void:
	var ac02_token: int = AC02_PASSIVE_18.enter("fielder_controller._physics_process")
	_ac02_passive_18_private_physics_process(delta)
	AC02_PASSIVE_18.leave(ac02_token)


func _ac02_passive_18_private_physics_process(delta: float) -> void:
	if not StadiumSurfaceTerrainRuntime.actor_allowed(self):
		return
	if (
		terrain_motion != null
		and (
			not terrain_motion.guard_actor(self)
			or not is_finite(delta)
			or not is_finite(move_speed_mps)
			or move_speed_mps < 0
			or not target_position.is_finite()
		)
	):
		return
	if hillside_motion != null:
		if not hillside_motion.guard(self):
			return
		if (
			not is_finite(delta)
			or not is_finite(move_speed_mps)
			or move_speed_mps < 0
			or not target_position.is_finite()
		):
			hillside_motion.fail(self, "Movement needs finite timing, speed and target inputs.")
			return
	if not active:
		return
	_advance_fielding_motion(delta)


func _advance_fielding_motion(delta: float) -> void:
	var before: float = _play_elapsed_seconds
	_play_elapsed_seconds += maxf(0.0, delta)
	if not first_step.is_zero_approx() and before + 0.000001 < SeasonJumpstart.STEP_SECONDS:
		FielderFirstStep.advance(
			self, first_step, minf(maxf(0.0, delta), SeasonJumpstart.STEP_SECONDS - before)
		)
		return
	if not first_step.is_zero_approx() and before < reaction_delay_seconds:
		velocity = Vector3.ZERO
		return
	if stationary:
		velocity = Vector3.ZERO
		return
	if _play_elapsed_seconds < reaction_delay_seconds:
		velocity = Vector3.ZERO
		return
	_advance_fielding_motion_remaining_checks(delta)


func _advance_fielding_motion_remaining_checks(delta: float) -> void:
	var displacement: Vector3 = target_position - global_position
	displacement.y = 0.0
	if displacement.length() <= 0.05:
		velocity = Vector3.ZERO
		return
	var previous: Vector3 = global_position
	if hillside_motion != null:
		var step: Dictionary = hillside_motion.move_primary(
			self, target_position, move_speed_mps * maxf(0.0, delta)
		)
		if step.is_empty():
			return
		global_position = step.position
		velocity = (global_position - previous) / maxf(delta, 0.000001)
		return
	var next_position: Vector3 = previous.move_toward(
		previous + displacement, move_speed_mps * maxf(0.0, delta)
	)
	if pitcher_lane_z != INF:
		var obstacle: Vector3 = (
			pitcher_defender.global_position
			if is_instance_valid(pitcher_defender)
			else Vector3(0.0, 0.0, pitcher_lane_z)
		)
		next_position = DefenderSpacing.step_around_mound(
			previous, target_position, obstacle, move_speed_mps * delta
		)
	if not stadium_obstacles.is_empty():
		var obstacles: Array[Dictionary] = stadium_obstacles.duplicate(true)
		if pitcher_lane_z != INF:
			obstacles.append(
				{
					"center":
					(
						pitcher_defender.global_position
						if is_instance_valid(pitcher_defender)
						else Vector3(0, 0, pitcher_lane_z)
					),
					"radius": DefenderSpacing.MOUND_CLEARANCE_M
				}
			)
		next_position = StadiumDefenderRoutes.owned_pool_step(
			previous,
			target_position,
			move_speed_mps * maxf(delta, 0),
			obstacles,
			stadium_pool_fielder_route
		)
	if stadium_waterfall_step.is_valid():
		var actors: Array[Dictionary] = []
		if pitcher_lane_z != INF:
			actors.append(
				{
					"center":
					(
						pitcher_defender.global_position
						if is_instance_valid(pitcher_defender)
						else Vector3(0, 0, pitcher_lane_z)
					),
					"radius": DefenderSpacing.MOUND_CLEARANCE_M
				}
			)
		next_position = stadium_waterfall_step.call(
			previous, target_position, move_speed_mps * maxf(delta, 0), actors
		)
	if stadium_boundary_clip.is_valid():
		next_position = stadium_boundary_clip.call(previous, next_position)
	if terrain_motion != null:
		next_position = terrain_motion.finish_step(
			self, previous, next_position, move_speed_mps * maxf(delta, 0)
		)
		if not terrain_motion.guard_actor(self):
			return
	# No physical ball collider: FieldingResolver remains the control authority.
	global_position = next_position
	velocity = (next_position - previous) / maxf(delta, 0.000001)


func _build_debug_fielder() -> void:
	_avatar = PlayerAvatar.new()
	_avatar.name = "FielderAvatar"
	add_child(_avatar)
	_avatar.configure(PlayerAvatar.Role.FIELDER, false, false, Color(0.18, 0.52, 0.95))

	_reach_marker = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 0.018
	_reach_marker.mesh = cylinder
	_reach_marker.position.y = 0.018
	_reach_marker.scale = Vector3(reach_m, 1.0, reach_m)

	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.15, 0.55, 1.0, 0.16)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reach_marker.material_override = marker_material
	add_child(_reach_marker)
