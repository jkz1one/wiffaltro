extends Node3D
## Private geometry/entry tests. Ground state is supplied unit input, never collision proof.
# gdlint: disable=max-file-lines,max-line-length,max-returns

const FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
const LAB: Script = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd")
const FIELDER: Script = preload("res://src/presentation/fielding/fielder_controller.gd")
const BALL: Script = preload("res://src/presentation/ball/batted_ball_body.gd")
const RESOLVER: Script = preload("res://src/gameplay/ball_in_play/ball_play_resolver.gd")
const EXPECTED_CHECKS: int = 172
const EXPECTED_CASES: int = 32  # Finite control cases, not movement routes.
var _checks: int = 0
var _failures: int = 0
var _cases: int = 0
var _outcomes: Array[BallPlayOutcome] = []
var _graph: StadiumRecipeBoundary


var _observed_segments: Array = []

func _ready() -> void:
	_graph = StadiumRecipeBoundary.create("deeper_center")
	_resolver_contract()
	await _matrix("flat-control")
	await _matrix("hill")
	await _downhill()
	await _rays()
	await _refusals()
	await _chronology()
	_check(_cases == EXPECTED_CASES, "declared control-case inventory is exact")
	_check(_checks + 1 == EXPECTED_CHECKS, "declared assertion inventory is exact")
	print("HILLSIDE_CONTROL checks=%d failures=%d" % [_checks, _failures])
	print("HILLSIDE_CONTROL_CASE_COUNT %d" % _cases)
	get_tree().quit(0 if _failures == 0 else 1)


# Attach the exact production script after the host's ready notification. No method
# is overridden. Broad application startup is omitted; real actors/outcomes are used.
func _lab() -> PitchBatLab:
	var host: Node3D = Node3D.new()
	add_child(host)
	host.set_script(LAB)
	var lab: PitchBatLab = host as PitchBatLab
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.set_process_input(false)
	lab.set_process_unhandled_input(false)
	lab._match_mode = false
	lab._field_definition = FIELD.duplicate(true) as FieldDefinition
	lab._field_definition.middle_center_available = true
	lab._field_definition.shallow_center_available = true
	PitchBatLabPresentation.build_pitch_actor(lab)
	lab._pitch_actor.set_physics_process(false)
	PitchBatLabPresentation.build_defenders(lab)
	lab._primary_fielder.set_physics_process(false)
	lab._primary_fielder.stadium_boundary_clip = Callable(_graph, "clip")
	lab._sounds = PlaySounds.new()
	lab._sounds.muted = true
	lab.add_child(lab._sounds)
	lab._pitch_feedback = PitchFeedback.new()
	lab.add_child(lab._pitch_feedback)
	lab._ball_play_resolver = BallPlayResolver.new()
	lab._ball_play_resolver.start_play(lab._field_definition)
	lab._ball_play_resolver.state.dead = true
	lab._ball_play_resolver.play_resolved.connect(_capture_outcome)
	return lab


func _bind(lab: PitchBatLab, terrain: Node3D, profile: String, pitcher: bool = true) -> bool:
	if not lab._primary_fielder.bind_hillside_motion(lab._field_definition, terrain, 4, profile):
		return false
	lab._primary_fielder.set_anchor(Vector3(-7, 0, 17))
	return lab.bind_hillside_pitcher_motion() if pitcher else true


func _prepare(
	lab: PitchBatLab,
	role: String,
	feet: Vector3,
	ball: Vector3,
	grounded: bool = false,
	speed: float = 2.0
) -> void:
	lab._primary_fielder.active = false
	lab._primary_fielder.stationary = false
	lab._primary_fielder.first_step = Vector3.ZERO
	lab._primary_fielder._play_elapsed_seconds = 1.0
	lab._primary_fielder.fielding_rating = 6
	lab._primary_fielder.reach_m = 0.66
	lab._primary_fielder.handling_scale = 1.0
	lab._primary_fielder.last_reaction_margin_seconds = 0.0
	lab._primary_fielder.set_anchor(feet if role == "primary" else Vector3(-7, 0, 17))
	if lab.hillside_pitcher_motion != null:
		lab.reset_hillside_pitcher()
		if role == "pitcher":
			for step in range(5):
				if lab._pitcher_marker.global_position == feet:
					break
				lab._pitcher_marker.global_position = StadiumPropertyRuntime.pitcher_step(
					lab, feet, 8.0, lab._pitcher_marker.global_position
				)
	else:
		lab._pitcher_marker.position = feet if role == "pitcher" else lab.MOUND_ORIGIN
		lab._pitcher_marker.rotation = Vector3.ZERO
	if not is_instance_valid(lab._batted_ball):
		lab._batted_ball = BattedBallBody.new()
		lab._batted_ball.freeze = true
		lab.add_child(lab._batted_ball)
		lab._batted_ball.set_physics_process(false)
	lab._batted_ball.global_position = ball
	lab._batted_ball.linear_velocity = Vector3(0, 0, speed)
	lab._batted_ball.angular_velocity = Vector3.ZERO
	lab._ball_play_resolver.start_play(lab._field_definition)
	# Deliberately supplied fixture state; no contact callback or launched trajectory.
	lab._ball_play_resolver.state.has_grounded = grounded
	lab._ball_play_resolver.state.elapsed_seconds = 1.0
	lab._pitcher_attempted = false
	lab._primary_attempts = 0
	lab._fielding_cooldown_seconds = 0.0
	lab._previous_batted_position = ball
	lab._last_fielding_text = ""
	_outcomes.clear()


func _actor(lab: PitchBatLab, role: String) -> Node3D:
	return lab._primary_fielder if role == "primary" else lab._pitcher_marker


func _try(lab: PitchBatLab, role: String, ball: Vector3) -> void:
	if role == "primary":
		PitchBatLabDefenseSupport.try_primary(lab)
	else:
		PitchBatLabDefenseSupport.try_pitcher(lab, ball, ball)


func _attempted(lab: PitchBatLab, role: String) -> bool:
	return lab._primary_attempts == 1 if role == "primary" else lab._pitcher_attempted


func _capture_outcome(outcome: BallPlayOutcome) -> void:
	_outcomes.append(outcome)


func _resolver_contract() -> void:
	for grounded: bool in [false, true]:
		var cap: float = (
			FieldingResolver.MAX_GROUND_CONTROL_HEIGHT_M
			if grounded
			else FieldingResolver.MAX_AIR_CONTROL_HEIGHT_M
		)
		_check(
			FieldingResolver.resolve(0.0, 2.0, cap, grounded, 6) == FieldingResolver.Outcome.CLEAN,
			"ordinary exact inclusive resolver upper cap"
		)
		_check(
			(
				FieldingResolver.resolve(0.0, 2.0, cap + 0.01, grounded, 6)
				== FieldingResolver.Outcome.MISS
			),
			"ordinary resolver above-cap refusal"
		)
		_check(
			(
				(
					FieldingResolver.resolve(0.0, 2.0, -0.1, grounded, 6)
					== FieldingResolver.Outcome.MISS
				)
				and (
					FieldingResolver.resolve(0.0, 2.0, -0.1, grounded, 6, 0.0, 1.0, 0.0, -0.2)
					== FieldingResolver.Outcome.CLEAN
				)
			),
			"ordinary zero lower default and explicit signed interval remain distinct"
		)
		_check(
			(
				FieldingResolver.resolve(0.0, 2.0, -0.21, grounded, 6, 0.0, 1.0, 0.0, -0.2)
				== FieldingResolver.Outcome.MISS
			),
			"explicit lower face cannot admit below-terrain center"
		)
	for rating: int in [0, 6, 10]:
		var reach: float = 0.52 + float(rating) * 0.024
		_check(
			(
				(
					FieldingResolver.resolve(reach, 0.0, 0.5, false, rating, 2.0)
					== FieldingResolver.Outcome.CLEAN
				)
				and (
					FieldingResolver.resolve(reach + 0.01, 0.0, 0.5, false, rating, 2.0)
					== FieldingResolver.Outcome.MISS
				)
			),
			"exact rating reach survives independent of vertical frame"
		)
	for row: Dictionary in [
		{"distance": 0.0, "speed": 2.0, "margin": 0.0, "handling": 1.0, "bonus": 0.0},
		{"distance": 0.5, "speed": 15.0, "margin": -0.1, "handling": 1.2, "bonus": 0.0},
		{"distance": 0.6, "speed": 30.0, "margin": 0.2, "handling": 0.8, "bonus": 0.1},
	]:
		var ordinary: int = FieldingResolver.resolve(
			row.distance, row.speed, 0.5, false, 6, row.margin, row.handling, row.bonus
		)
		_check(
			(
				ordinary
				== FieldingResolver.resolve(
					row.distance,
					row.speed,
					-0.1,
					false,
					6,
					row.margin,
					row.handling,
					row.bonus,
					-0.2
				)
			),
			"height-frame substitution preserves all difficulty modifiers"
		)
	_check(
		(
			(
				FieldingResolver.resolve(0.0, 2.0, 0.5, false, 6, 0.0, 1.0, 0.0, NAN)
				== FieldingResolver.Outcome.MISS
			)
			and (
				FieldingResolver.resolve(0.0, 2.0, 0.5, false, 6, 0.0, 1.0, 0.0, INF)
				== FieldingResolver.Outcome.MISS
			)
		),
		"new explicit lower-bound parameter refuses nonfinite values"
	)
	var mound: Vector3 = PitchBatLab.MOUND_ORIGIN
	_check(
		(
			PitcherDefense.can_attempt(mound + Vector3(0, 1.8, 0), mound)
			and not PitcherDefense.can_attempt(mound + Vector3(0, 1.9, 0), mound)
			and not PitcherDefense.can_attempt(mound + Vector3(0, -0.1, 0), mound)
		),
		"ordinary pitcher world-height predicate remains unchanged"
	)
	for y: float in [0.1, 1.0, 1.8]:
		var base: Vector3 = Vector3(0, 0, 20)
		var raised: Vector3 = Vector3(0, 2, 27)
		var ordinary: Vector3 = base + Vector3(0.5, y, 0)
		var plateau: Vector3 = raised + Vector3(0.5, y, 0)
		_check(
			(
				PitcherDefense.resolve_supported(plateau, Vector3(0, 0, 2), raised, false, 5)
				== PitcherDefense.resolve_supported(ordinary, Vector3(0, 0, 2), base, false, 5)
			),
			"pure plateau translation keeps upright reach; no bound plateau admission is claimed"
		)


func _matrix(profile: String) -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create(profile)
	add_child(terrain)
	await _barrier()
	var lab: PitchBatLab = _lab()
	_check(_bind(lab, terrain, profile), profile + " real independent actor bindings")
	_check(
		(
			lab.get_script() == LAB
			and lab._primary_fielder.get_script() == FIELDER
			and lab._ball_play_resolver.get_script() == RESOLVER
			and lab._pitcher_marker.get_class() == "Node3D"
			and lab._pitcher_marker == lab.get_node("PitcherDefender")
			and lab._primary_fielder.hillside_motion != lab.hillside_pitcher_motion
		),
		"exact lab/controller/resolver/actual-marker identities without subclass outcome stubs"
	)
	for role: String in ["primary", "pitcher"]:
		var feet: Vector3 = StadiumHillsideTerrain.point(
			0, 21.2 if role == "primary" else 18.5, profile
		)
		var rows: Array[Dictionary] = [
			{
				"id": "high",
				"height": 2.0 if role == "primary" else 1.8,
				"distance": 0.5,
				"ground": false,
				"attempt": true,
				"outcome": FieldingResolver.Outcome.CLEAN
			},
			{
				"id": "above-air",
				"height": 2.1 if role == "primary" else 1.9,
				"distance": 0.0,
				"ground": false,
				"attempt": false
			},
			{
				"id": "ground",
				"height": 1.0,
				"distance": 0.5,
				"ground": true,
				"attempt": true,
				"outcome": FieldingResolver.Outcome.CLEAN
			},
			{
				"id": "above-ground",
				"height": 1.5,
				"distance": 0.0,
				"ground": true,
				"attempt": role == "pitcher",
				"outcome": FieldingResolver.Outcome.MISS
			},
			{"id": "lateral", "height": 0.5, "distance": 0.75, "ground": false, "attempt": false},
			{
				"id": "below-terrain",
				"height": -0.1,
				"distance": 0.0,
				"ground": false,
				"attempt": false
			},
		]
		for row: Dictionary in rows:
			var ball: Vector3 = feet + Vector3(row.distance, row.height, 0)
			_prepare(lab, role, feet, ball, row.ground)
			var frame: Dictionary = PitchBatLabDefenseSupport.control_frame(
				lab, _actor(lab, role), ball
			)
			_check(
				(
					_actor(lab, role).global_position == feet
					and not frame.is_empty()
					and frame.height_m == ball.y - feet.y
					and (
						frame.minimum_height_m
						== (
							StadiumHillsideTerrain.support_height(Vector2(ball.x, ball.z), profile)
							- feet.y
						)
					)
				),
				(
					"actual canonical feet/local height/lower face: "
					+ profile
					+ ":"
					+ role
					+ ":"
					+ row.id
				)
			)
			_try(lab, role, ball)
			_check(
				_attempted(lab, role) == row.attempt and lab._batted_ball.get_script() == BALL,
				(
					"actual entry consumes only eligible attempt: "
					+ profile
					+ ":"
					+ role
					+ ":"
					+ row.id
				)
			)
			var expected_name: String = FieldingResolver.outcome_name(
				row.get("outcome", FieldingResolver.Outcome.MISS)
			)
			_check(
				(
					(
						lab._last_fielding_text.ends_with(expected_name)
						if row.attempt
						else lab._last_fielding_text.is_empty()
					)
					and (
						lab._ball_play_resolver.state.dead
						if row.get("outcome") == FieldingResolver.Outcome.CLEAN and row.attempt
						else not lab._ball_play_resolver.state.dead
					)
					and (
						lab._fielding_cooldown_seconds == 0.35
						if row.attempt and row.get("outcome") == FieldingResolver.Outcome.MISS
						else lab._fielding_cooldown_seconds == 0.0
					)
				),
				(
					"real outcome/cooldown match predeclared control result: "
					+ profile
					+ ":"
					+ role
					+ ":"
					+ row.id
				)
			)
			_emit(profile + ":" + role + ":" + row.id, lab)
	# At a slope, an elevated high catch would fail the unchanged world-Y predicate.
	_prepare(
		lab,
		"primary",
		StadiumHillsideTerrain.point(0, 21.2, profile),
		StadiumHillsideTerrain.point(0, 21.2, profile) + Vector3(0.5, 2.0, 0)
	)
	_check(
		(
			(lab._batted_ball.position.y > FieldingResolver.MAX_AIR_CONTROL_HEIGHT_M)
			== (profile == "hill")
		),
		"elevated-slope high catch is genuinely outside old world-Y control"
	)
	lab.queue_free()
	terrain.queue_free()
	await _barrier()


func _downhill() -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create("hill")
	add_child(terrain)
	await _barrier()
	var lab: PitchBatLab = _lab()
	_check(_bind(lab, terrain, "hill"), "downhill actual bindings")
	for role: String in ["primary", "pitcher"]:
		var feet: Vector3 = StadiumHillsideTerrain.point(0, 21.2 if role == "primary" else 18.716)
		var center_z: float = 20.6 if role == "primary" else 18.126
		center_z = Vector3(0, 0, center_z).z  # Canonical engine XZ is the sampled input.
		var knots: PackedFloat64Array = StadiumHillsideTerrain.knots()
		var strip: int = StadiumHillsideTerrain.interval(center_z)
		var slope: float = (
			(
				StadiumHillsideTerrain.design_height(knots[strip + 1])
				- StadiumHillsideTerrain.design_height(knots[strip])
			)
			/ (knots[strip + 1] - knots[strip])
		)
		# Analytical single-planar-strip witness, not a collision/trajectory oracle.
		var ground: float = StadiumHillsideTerrain.support_height(Vector2(0, center_z))
		var ball: Vector3 = Vector3(0, ground + 0.0365 * sqrt(1.0 + slope * slope), center_z)
		_prepare(lab, role, feet, ball, true)
		var radius: float = lab._batted_ball.radius_m
		_check(
			(
				radius == 0.0365
				and ball.z - radius > knots[strip]
				and ball.z + radius < knots[strip + 1]
				and ball.y < feet.y
				and ball.y > ground
			),
			"legitimate one-strip downhill sphere witness is below feet and above terrain: " + role
		)
		var frame: Dictionary = PitchBatLabDefenseSupport.control_frame(
			lab, _actor(lab, role), ball
		)
		_check(
			(
				not frame.is_empty()
				and frame.height_m == ball.y - feet.y
				and frame.minimum_height_m == ground - feet.y
				and frame.height_m < 0.0
			),
			"downhill signed height is preserved without zero clamp: " + role
		)
		_try(lab, role, ball)
		_check(
			(
				_attempted(lab, role)
				and lab._last_fielding_text.ends_with("CLEAN")
				and _outcomes.size() == 1
				and _outcomes[0].resolution_position == ball
				and lab._ball_play_resolver.state.has_grounded
				and not lab._ball_play_resolver.state.caught
			),
			(
				"real ordinary outcome uses supplied ground state and actual below-feet candidate: "
				+ role
			)
		)
		_emit("downhill:" + role, lab)
		_prepare(lab, role, feet, ball, false)
		_try(lab, role, ball)
		_check(
			(
				_attempted(lab, role)
				and lab._ball_play_resolver.state.caught
				and not lab._ball_play_resolver.state.has_grounded
				and lab._ball_play_resolver.state.catch_position == ball
				and lab._ball_play_resolver.state.catch_time == 1.0
			),
			"negative local height never fabricates grounding or fractional catch time: " + role
		)
		var uphill: Vector3 = StadiumHillsideTerrain.point(0, feet.z + 0.5)
		uphill.y = feet.y + 0.01
		_prepare(lab, role, feet, uphill)
		_try(lab, role, uphill)
		_check(
			(
				not _attempted(lab, role)
				and _outcomes.is_empty()
				and uphill.y < StadiumHillsideTerrain.support_height(Vector2(uphill.x, uphill.z))
			),
			"uphill lower face rejects center under terrain despite positive feet height: " + role
		)
		uphill = feet + Vector3(0, 2.1 if role == "primary" else 1.9, 0.5)
		_prepare(lab, role, feet, uphill)
		_try(lab, role, uphill)
		_check(
			(
				not _attempted(lab, role)
				and uphill.y > StadiumHillsideTerrain.support_height(Vector2(uphill.x, uphill.z))
			),
			"uphill support cannot lift the retained feet-relative upper cap: " + role
		)
	# Existing independent primary reach remains narrower than a deliberately generous controller
	# value.
	var feet: Vector3 = StadiumHillsideTerrain.point(0, 21.2)
	var ball: Vector3 = feet + Vector3(0.6, 0.5, 0)
	_prepare(lab, "primary", feet, ball)
	lab._primary_fielder.fielding_rating = 0
	lab._primary_fielder.reach_m = 0.76
	PitchBatLabDefenseSupport.try_primary(lab)
	_check(
		(
			lab._primary_attempts == 1
			and lab._last_fielding_text.ends_with("MISS")
			and lab._fielding_cooldown_seconds == 0.35
			and not lab._ball_play_resolver.state.dead
		),
		"resolver rating reach consumes ordinary MISS even after primary controller reach passes"
	)
	for row: Dictionary in [
		{"role": "primary", "speed": 36.0, "name": "BOBBLE", "cooldown": 0.55},
		{"role": "primary", "speed": 50.0, "name": "MISS", "cooldown": 0.35},
		{"role": "pitcher", "speed": 30.0, "name": "BOBBLE", "cooldown": 0.55},
		{"role": "pitcher", "speed": 50.0, "name": "MISS", "cooldown": 0.35},
	]:
		feet = StadiumHillsideTerrain.point(0, 21.2 if row.role == "primary" else 18.5)
		ball = feet + Vector3(0, 0.5, 0)
		_prepare(lab, row.role, feet, ball, false, row.speed)
		_try(lab, row.role, ball)
		_check(
			(
				_attempted(lab, row.role)
				and lab._last_fielding_text.ends_with(row.name)
				and lab._fielding_cooldown_seconds == row.cooldown
				and not lab._ball_play_resolver.state.dead
			),
			"real nonterminal handling/cooldown outcome: " + row.role + ":" + row.name
		)
	lab.queue_free()
	terrain.queue_free()
	await _barrier()


func _rays() -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create("hill")
	add_child(terrain)
	await _barrier()
	var lab: PitchBatLab = _lab()
	_check(_bind(lab, terrain, "hill"), "clearance actual bindings")
	for role: String in ["primary", "pitcher"]:
		var feet: Vector3 = StadiumHillsideTerrain.point(0, 21.2 if role == "primary" else 18.5)
		var ball: Vector3 = feet + Vector3(0.5, 0.15, 0)
		_prepare(lab, role, feet, ball)
		var query: PhysicsRayQueryParameters3D = StadiumPropertyRuntime.control_ray(
			lab, _actor(lab, role), ball
		)
		var start: Vector3 = feet + Vector3.UP * maxf(0.3, ball.y - feet.y)
		_check(
			(
				query != null
				and query.from == start
				and query.to == ball
				and query.collision_mask == 1
				and query.exclude == ([lab._primary_fielder.get_rid()] if role == "primary" else [])
			),
			(
				"actual production clearance query exact endpoints, mask and limited self exclusion: "
				+ role
			)
		)
		_check(
			(
				not lab.has_meta("stadium_property")
				and StadiumPropertyRuntime.clear_control(lab, _actor(lab, role), ball)
			),
			"private no-property clear ray executes and permits unobstructed segment: " + role
		)
		var box: StaticBody3D = _occluder(start.lerp(ball, 0.5))
		await _barrier()
		_check(
			(
				not StadiumPropertyRuntime.clear_control(lab, _actor(lab, role), ball)
				and (
					lab.get_world_3d().direct_space_state.intersect_ray(query).get("collider")
					== box
				)
			),
			"private no-property branch actually rejects exact-ray object obstruction: " + role
		)
		_try(lab, role, ball)
		_check(
			not _attempted(lab, role) and _outcomes.is_empty(),
			"blocked actual entry consumes no attempt: " + role
		)
		if role == "primary":
			var forced: PhysicsRayQueryParameters3D = FielderFirstStep.control_ray(
				lab._primary_fielder, ball
			)
			_check(
				(
					forced != null
					and forced.from == query.from
					and forced.to == ball
					and forced.collision_mask == 1
					and forced.exclude == [lab._primary_fielder.get_rid()]
					and not FielderFirstStep.unobstructed(lab._primary_fielder, ball)
				),
				"actual forced-step query preserves identical supported ray and fielder RID exclusion"
			)
			var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
			lab.add_child(property)
			lab.set_meta("stadium_property", property)
			_check(
				not StadiumPropertyRuntime.clear_control(lab, lab._primary_fielder, ball),
				"same primary bound ray rejects object when property metadata is present"
			)
			lab.remove_meta("stadium_property")
			property.queue_free()
		_emit("ray-object:" + role, lab)
		box.queue_free()
		await _barrier()
		# Probe the real terrain with the actual ray helper, not a mocked ray result.
		var below: Vector3 = feet + Vector3(0.5, -0.1, 0)
		var terrain_query: PhysicsRayQueryParameters3D = StadiumPropertyRuntime.control_ray(
			lab, _actor(lab, role), below
		)
		_check(
			(
				terrain_query != null
				and not StadiumPropertyRuntime.clear_control(lab, _actor(lab, role), below)
				and (
					lab.get_world_3d().direct_space_state.intersect_ray(terrain_query).get(
						"collider"
					)
					== terrain.get_node("TerrainCollision")
				)
			),
			"mask-one bound clearance retains terrain occlusion: " + role
		)
		if role == "primary":
			_prepare(lab, role, feet, ball)
			lab._primary_fielder.first_step = Vector3.RIGHT
			lab._primary_fielder._play_elapsed_seconds = 0.0
			_try(lab, role, ball)
			_check(not _attempted(lab, role), "forced-step reaction guard remains before attempt")
			lab._primary_fielder._play_elapsed_seconds = 1.0
			_try(lab, role, ball)
			_check(
				_attempted(lab, role) and lab._last_fielding_text.ends_with("CLEAN"),
				"eligible forced-step entry uses actual unblocked supported ray"
			)
	lab.queue_free()
	terrain.queue_free()
	await _barrier()


func _occluder(at: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.06, 0.06, 0.06)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	return body


func _refusals() -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create("hill")
	add_child(terrain)
	await _barrier()
	var lab: PitchBatLab = _lab()
	_check(_bind(lab, terrain, "hill"), "refusal actual bindings")
	var body: StaticBody3D = terrain.get_node("TerrainCollision") as StaticBody3D
	var shape: CollisionShape3D = body.get_node("ClosedTerrainShape") as CollisionShape3D
	for role: String in ["primary", "pitcher"]:
		for fault: String in [
			"disabled", "layer", "signature", "raised-feet", "blocked", "foreign-field"
		]:
			var feet: Vector3 = StadiumHillsideTerrain.point(0, 21.2 if role == "primary" else 18.5)
			var ball: Vector3 = feet + Vector3(0.25, 0.5, 0)
			_prepare(lab, role, feet, ball)
			var motion: StadiumHillsideDefenderMotion = (
				lab._primary_fielder.hillside_motion
				if role == "primary"
				else lab.hillside_pitcher_motion
			)
			var original_field: FieldDefinition = lab._field_definition
			match fault:
				"disabled":
					shape.disabled = true
				"layer":
					body.collision_layer = 1
				"signature":
					terrain.set_meta("terrain_signature", "changed")
				"raised-feet":
					_actor(lab, role).global_position += Vector3.UP * 0.25
				"blocked":
					motion.blocked = true
				"foreign-field":
					lab._field_definition = FIELD.duplicate(true) as FieldDefinition
			await _barrier()
			var before: Dictionary = _snapshot(lab)
			var frame: Dictionary = PitchBatLabDefenseSupport.control_frame(
				lab, _actor(lab, role), ball
			)
			_try(lab, role, ball)
			_check(
				frame.is_empty() and _snapshot(lab) == before and not _attempted(lab, role),
				(
					"invalid actual support refuses without attempt, pose, path or latch mutation: "
					+ role
					+ ":"
					+ fault
				)
			)
			match fault:
				"disabled":
					shape.disabled = false
				"layer":
					body.collision_layer = 1 | StadiumHillsideTerrainModels.QUERY_LAYER
				"signature":
					terrain.set_meta("terrain_signature", StadiumHillsideTerrain.signature("hill"))
				"raised-feet":
					_actor(lab, role).global_position = feet
				"blocked":
					motion.blocked = false
				"foreign-field":
					lab._field_definition = original_field
			await _barrier()
	var feet: Vector3 = StadiumHillsideTerrain.point(0, 21.2)
	var ball: Vector3 = feet + Vector3(0.25, 0.5, 0)
	_prepare(lab, "primary", feet, ball)
	var motion: StadiumHillsideDefenderMotion = lab._primary_fielder.hillside_motion
	var before: Dictionary = _snapshot(lab)
	_check(
		(
			motion.support_record(lab._primary_fielder, Vector2.INF).is_empty()
			and motion.support_record(lab._primary_fielder, Vector2(33, 0)).is_empty()
			and _snapshot(lab) == before
		),
		"readonly query rejects nonfinite and unavailable ball support without state change"
	)
	var foreign: FielderController = FielderController.new()
	lab.add_child(foreign)
	foreign.set_physics_process(false)
	foreign.stadium_boundary_clip = lab._primary_fielder.stadium_boundary_clip
	foreign.hillside_motion = motion
	foreign.global_position = feet
	_check(
		(
			motion.support_record(foreign, Vector2(ball.x, ball.z)).is_empty()
			and _snapshot(lab) == before
		),
		"a foreign controller cannot borrow the successful actor binding"
	)
	var committed: FielderController = motion._bound_fielder
	_check(
		(
			not motion.configure(foreign, null, terrain, 4, "hill")
			and motion._bound_fielder == committed
			and committed == lab._primary_fielder
		),
		"failed configure cannot overwrite previously committed primary identity"
	)
	before = _snapshot(lab)
	_check(
		(
			motion.support_record(lab._primary_fielder, Vector2(ball.x, ball.z)).is_empty()
			and _snapshot(lab) == before
		),
		"query after failed configure is readonly and cannot revive blocked binding"
	)
	foreign.hillside_motion = null
	foreign.queue_free()
	_check(
		motion.configure(lab._primary_fielder, lab._field_definition, terrain, 4, "hill"),
		"explicit successful original configure restores the committed binding"
	)
	_prepare(lab, "primary", feet, ball)
	var primary_motion: StadiumHillsideDefenderMotion = lab._primary_fielder.hillside_motion
	lab._primary_fielder.hillside_motion = null
	before = _snapshot(lab)
	PitchBatLabDefenseSupport.try_primary(lab)
	_check(
		lab._primary_attempts == 0 and _snapshot(lab) == before,
		"partly bound lab cannot enter unbound primary control"
	)
	lab._primary_fielder.hillside_motion = primary_motion
	feet = StadiumHillsideTerrain.point(0, 18.5)
	ball = feet + Vector3(0.25, 0.5, 0)
	_prepare(lab, "pitcher", feet, ball)
	var pitcher_motion: StadiumHillsideDefenderMotion = lab.hillside_pitcher_motion
	lab.hillside_pitcher_motion = null
	before = _snapshot(lab)
	PitchBatLabDefenseSupport.try_pitcher(lab, ball, ball)
	_check(
		not lab._pitcher_attempted and _snapshot(lab) == before,
		"partly bound lab cannot enter unbound pitcher control"
	)
	lab.hillside_pitcher_motion = pitcher_motion
	_prepare(lab, "pitcher", feet, ball)
	pitcher_motion.begin_pitcher_presentation(lab)
	lab._pitcher_marker.position += Vector3.UP * 0.16
	before = _snapshot(lab)
	PitchBatLabDefenseSupport.try_pitcher(lab, ball, ball)
	_check(
		not lab._pitcher_attempted and _snapshot(lab) == before,
		"delivery lift is never accepted as supported pitcher feet"
	)
	lab.reset_hillside_pitcher()
	_prepare(lab, "primary", StadiumHillsideTerrain.point(0, 25.4), Vector3(0, 3.0, 27))
	var last_legal: Vector3 = lab._primary_fielder.global_position
	lab._primary_fielder.set_anchor(StadiumHillsideTerrain.point(0, 27))
	_check(
		(
			lab._primary_fielder.global_position == last_legal
			and StadiumHillsideTerrain.support_height(Vector2(0, 27)) == 2.0
			and not _graph.contains(Vector2(0, 27))
		),
		"retained boundary excludes plateau feet; high-catch fixture must not invent a plateau binding"
	)
	# Ordinary entry remains available when both actors really are unbound.
	lab._primary_fielder.hillside_motion = null
	lab.hillside_pitcher_motion = null
	_prepare(lab, "primary", Vector3(0, 0, 14), Vector3(0.5, 2.0, 14))
	PitchBatLabDefenseSupport.try_primary(lab)
	_check(
		(
			lab._primary_attempts == 1
			and lab._last_fielding_text.ends_with("CLEAN")
			and lab._ball_play_resolver.state.caught
		),
		"fully unbound ordinary high catch still uses its unchanged entry"
	)
	lab.queue_free()
	terrain.queue_free()
	await _barrier()


func _snapshot(lab: PitchBatLab) -> Dictionary:
	var primary: StadiumHillsideDefenderMotion = lab._primary_fielder.hillside_motion
	var pitcher: StadiumHillsideDefenderMotion = lab.hillside_pitcher_motion
	return {
		"primary_position": lab._primary_fielder.global_position,
		"pitcher_position": lab._pitcher_marker.global_position,
		"primary_basis": lab._primary_fielder.global_basis,
		"pitcher_basis": lab._pitcher_marker.global_basis,
		"primary_motion": _motion_state(primary),
		"pitcher_motion": _motion_state(pitcher),
		"primary_attempts": lab._primary_attempts,
		"pitcher_attempted": lab._pitcher_attempted,
		"cooldown": lab._fielding_cooldown_seconds,
		"text": lab._last_fielding_text,
		"floor": lab._ball_play_resolver.state.result_floor,
		"ground": lab._ball_play_resolver.state.has_grounded,
		"dead": lab._ball_play_resolver.state.dead,
		"touched": lab._ball_play_resolver.state.defender_touched,
		"outcomes": _outcomes.size()
	}


func _motion_state(motion: StadiumHillsideDefenderMotion) -> Dictionary:
	return (
		{}
		if motion == null
		else {
			"blocked": motion.blocked,
			"error": motion.last_error,
			"path": motion.last_path.duplicate(true),
			"accepted": motion._last_valid_position,
			"identity": motion._bound_fielder,
			"presentation": motion.presentation_active
		}
	)




func _chronology() -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create("hill")
	add_child(terrain)
	await _barrier()
	var lab: PitchBatLab = _lab()
	_check(_bind(lab, terrain, "hill"), "chronology actual bindings")
	var feet: Vector3 = StadiumHillsideTerrain.point(0, 18.5)
	var previous: Vector3 = feet + Vector3(-0.5, 0.5, 0)
	var current: Vector3 = feet + Vector3(0.5, 4.0, 0)
	_prepare(lab, "pitcher", feet, current)
	var closest: Vector3 = PitcherDefense.closest_position(previous, current, feet)
	_check(
		(
			closest == previous.lerp(current, 0.5)
			and closest.y - feet.y > PitcherDefense.MAX_REACTION_HEIGHT_M
			and (
				PitcherDefense.resolve_supported(previous, Vector3(0, 0, 2), feet, false, 5)
				== FieldingResolver.Outcome.CLEAN
			)
		),
		"closest-XZ candidate is high despite an eligible earlier nearby point"
	)
	PitchBatLabDefenseSupport.try_pitcher(lab, previous, current)
	_check(
		not lab._pitcher_attempted and _outcomes.is_empty(),
		"height elsewhere cannot rescue ineligible exact closest-XZ candidate"
	)
	_emit("closest-xz-height-miss", lab)
	# Exact degenerate-XZ alpha=0 behavior, including distinct vertical endpoints.
	_check(
		(
			PitcherDefense.closest_position(
				feet + Vector3(0, 0.5, 0), feet + Vector3(0, 4, 0), feet
			)
			== feet + Vector3(0, 0.5, 0)
		),
		"zero-XZ segment keeps retained alpha-zero timing"
	)
	for row: Dictionary in [
		{
			"id": "remote-safe-floor",
			"feet": Vector3(0, 0, 12),
			"previous": Vector3(0, 0.5, 11),
			"current": Vector3(0, 0.5, 12.5),
			"result": BallPlayOutcome.Result.SINGLE,
			"floor": BallPlayState.ResultFloor.SINGLE,
			"attempt": true
		},
		{
			"id": "original-mound-exception",
			"feet": lab.MOUND_ORIGIN,
			"previous": Vector3(0, 0.5, 10),
			"current": Vector3(0, 0.5, 14.5),
			"result": BallPlayOutcome.Result.OUT,
			"floor": BallPlayState.ResultFloor.SINGLE,
			"attempt": true
		},
		{
			"id": "dead-wall-prefix",
			"feet": StadiumHillsideTerrain.point(0, 24),
			"previous": Vector3(0, 2.0, 22.5),
			"current": Vector3(0, 2.0, 24.5),
			"result": BallPlayOutcome.Result.DOUBLE,
			"floor": BallPlayState.ResultFloor.DOUBLE,
			"attempt": false
		},
	]:
		feet = row.feet
		previous = row.previous
		current = row.current
		_prepare(lab, "pitcher", feet, current, true)
		closest = PitcherDefense.closest_position(previous, current, feet)
		PitchBatLabDefenseSupport.try_pitcher(lab, previous, current)
		_check(
			(
				lab._pitcher_attempted == row.attempt
				and lab._ball_play_resolver.state.dead
				and lab._ball_play_resolver.state.result_floor == row.floor
				and _outcomes.size() == 1
				and _outcomes[0].result == row.result
			),
			"actual prefix floors/dead decision precede attempt/outcome: " + row.id
		)
		_check(
			(
				_outcomes.size() == 1
				and (
					_outcomes[0].resolution_position == closest
					if row.attempt
					else (
						_outcomes[0].resolution_position
						== lab._ball_play_resolver._forward_plane_crossing(
							previous, closest, lab._field_definition.back_wall_z_m
						)
					)
				)
				and (
					lab._last_fielding_text.ends_with("CLEAN")
					if row.attempt
					else lab._last_fielding_text.is_empty()
				)
			),
			"actual outcome retains world candidate or real earlier terminal crossing: " + row.id
		)
		_emit(row.id, lab)
	# Trace observer calls, then pass each through the unchanged real ordinary observer.
	# This records no contact and supplies no floor, award, position or outcome.
	feet = StadiumHillsideTerrain.point(0, 16.5)
	previous = Vector3(0, 1.5, 11)
	current = Vector3(0, 1.5, 18)
	_prepare(lab, "pitcher", feet, current, true)
	closest = PitcherDefense.closest_position(previous, current, feet)
	lab._previous_batted_position = previous
	_observed_segments.clear()
	lab._ball_play_resolver.segment_observer = _record_segment
	lab._physics_process(0.125)
	_check(
		_observed_segments == [[previous, closest], [previous, current]],
		"actual physics loop observes prefix then full original segment after nonterminal MISS"
	)
	_check(
		(
			lab._pitcher_attempted
			and lab._last_fielding_text.ends_with("MISS")
			and not lab._ball_play_resolver.state.dead
			and lab._ball_play_resolver.state.result_floor == BallPlayState.ResultFloor.SINGLE
			and lab._ball_play_resolver.state.elapsed_seconds == 1.0 + 0.125
			and lab._fielding_cooldown_seconds == maxf(0.0, 0.35 - 0.125)
			and lab._previous_batted_position == current
			and lab._primary_attempts == 0
		),
		"real nonterminal loop keeps floor, time, cooldown and previous-position chronology"
	)
	feet = StadiumHillsideTerrain.point(0, 18)
	current = feet + Vector3(0.5, 1.0, 0)
	previous = Vector3(0.5, current.y, 10.5)
	_prepare(lab, "primary", feet, current)
	lab._pitcher_attempted = true
	lab._previous_batted_position = previous
	_observed_segments.clear()
	lab._physics_process(0.125)
	_check(
		(
			_observed_segments == [[previous, current]]
			and lab._primary_attempts == 1
			and lab._ball_play_resolver.state.result_floor == BallPlayState.ResultFloor.DOUBLE
		),
		"primary remains current-position control after ordinary full-segment safe/deep observation"
	)
	_check(
		(
			lab._ball_play_resolver.state.caught
			and lab._ball_play_resolver.state.catch_position == current
			and lab._ball_play_resolver.state.catch_time == 1.0 + 0.125
			and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.OUT
		),
		"actual primary catch preserves tick time and ordinary airborne award despite earned floor"
	)
	lab._ball_play_resolver.segment_observer = Callable()
	for gate: String in ["two-attempts", "cooldown", "stationary-reaction"]:
		_prepare(lab, "primary", feet, current)
		match gate:
			"two-attempts":
				lab._primary_attempts = 2
			"cooldown":
				lab._fielding_cooldown_seconds = 0.25
			"stationary-reaction":
				lab._primary_fielder.stationary = true
				lab._primary_fielder._play_elapsed_seconds = 0.0
		var before: Dictionary = _snapshot(lab)
		PitchBatLabDefenseSupport.try_primary(lab)
		_check(_snapshot(lab) == before, "ordinary primary pre-entry gate preserved: " + gate)
	lab.queue_free()
	terrain.queue_free()
	await _barrier()


func _record_segment(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> void:
	_observed_segments.append([previous, current])
	resolver.segment_observer = Callable()
	resolver.observe_segment(previous, current)
	resolver.segment_observer = _record_segment


func _barrier() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _emit(id: String, lab: PitchBatLab) -> void:
	_cases += 1
	print(
		"HILLSIDE_CONTROL_CASE ",
		JSON.stringify(
			{
				"id": id,
				"ball":
				[
					lab._batted_ball.position.x,
					lab._batted_ball.position.y,
					lab._batted_ball.position.z
				],
				"primary_attempts": lab._primary_attempts,
				"pitcher_attempted": lab._pitcher_attempted,
				"ground_state_supplied": lab._ball_play_resolver.state.has_grounded,
				"floor": int(lab._ball_play_resolver.state.result_floor),
				"dead": lab._ball_play_resolver.state.dead,
				"outcome": lab._last_fielding_text
			}
		)
	)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("HILLSIDE_CONTROL_CHECK " + message)
