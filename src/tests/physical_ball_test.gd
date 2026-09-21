extends Node

var _failures: int = 0
var _result: BallPlayOutcome
var _ground_contacts: int = 0
var _wall_contacts: int = 0


func _ready() -> void:
	_check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "require Jolt")
	await _launch_case("short settle", Vector3(3, 0.2, 3), Vector3.ZERO,
		BallPlayOutcome.Result.SINGLE, true)
	await _launch_case("rolling Single crossing", Vector3(3, 0.08, 9.8), Vector3(0, 0, 2),
		BallPlayOutcome.Result.SINGLE, true)
	await _launch_case("grounded wall", Vector3(3, 0.08, 22), Vector3(0, 0, 8),
		BallPlayOutcome.Result.DOUBLE, true)
	await _launch_case("wall on fly", Vector3(3, 2, 21), Vector3(0, 0, 15),
		BallPlayOutcome.Result.TRIPLE, false)
	await _launch_case("wall clearance", Vector3(3, 4.5, 21), Vector3(0, 0, 15),
		BallPlayOutcome.Result.HOME_RUN, false)
	await _launch_case("untouched Deep Air", Vector3(3, 1.5, 16), Vector3(0, 0, 3),
		BallPlayOutcome.Result.DOUBLE, true)
	await _launch_case("pitcher charges before Single", Vector3(0, 0.04, 9), Vector3(0, 0, 1),
		BallPlayOutcome.Result.OUT, true, "CLEAN")
	await _launch_case("pitcher charges after Single", Vector3(0, 0.04, 9.8), Vector3(0, 0, 6),
		BallPlayOutcome.Result.SINGLE, true, "CLEAN")
	await _launch_case("pitcher nearby air catch", Vector3(2, 2.5, 12.5), Vector3(-0.7, -0.2, 1),
		BallPlayOutcome.Result.OUT, false, "CLEAN")
	await _launch_case("pitcher clean grounder", Vector3(0, 0.04, 12.95), Vector3(0, 0, 6),
		BallPlayOutcome.Result.OUT, true, "CLEAN")
	await _launch_case("pitcher bobble", Vector3(0.45, 0.04, 9.8), Vector3(0, 0, 16),
		BallPlayOutcome.Result.SINGLE, true, "BOBBLE")
	await _launch_case("pitcher miss", Vector3(0.45, 0.04, 9.8), Vector3(0, 0, 30),
		BallPlayOutcome.Result.SINGLE, true, "MISS")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical ball checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _launch_case(
	label: String, position: Vector3, velocity: Vector3,
	expected: BallPlayOutcome.Result, grounded: bool, pitcher_outcome: String = ""
) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab._match_mode = false
	lab.set_process(false)
	# Isolate scoring/pitcher behavior from primary defense; leave the actual
	# Jolt body, field colliders, contact signals and lab physics loop active.
	lab._primary_fielder.set_anchor(Vector3(-5.5, 0, 19.5))
	lab._primary_fielder.set_physics_process(false)
	_result = null
	_ground_contacts = 0
	_wall_contacts = 0
	lab._ball_play_resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
		_result = outcome)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = position
	launch.velocity = velocity
	lab._start_ball_in_play(launch)
	if label == "pitcher clean grounder":
		# This isolated comebacker enters just before the fixed mound envelope,
		# having already earned Single on its earlier travel from home.
		lab._ball_play_resolver.state.raise_result_floor(BallPlayState.ResultFloor.SINGLE)
	lab._primary_attempts = 2
	lab._pitcher_attempted = pitcher_outcome.is_empty()
	lab._batted_ball.surface_contact.connect(func(surface: StringName, _point: Vector3) -> void:
		if surface == &"ground":
			_ground_contacts += 1
		elif surface == &"back_wall":
			_wall_contacts += 1)
	var furthest_z: float = position.z
	var airborne_double_seen: bool = false
	for frame in range(660):
		await get_tree().physics_frame
		furthest_z = maxf(furthest_z, lab._batted_ball.global_position.z)
		if (
			not lab._ball_play_resolver.state.has_grounded
			and lab._ball_play_resolver.state.result_floor == BallPlayState.ResultFloor.DOUBLE
		):
			airborne_double_seen = true
		if _result != null:
			break
	_check(_result != null, "%s must resolve within the physics-frame budget" % label)
	if _result != null:
		print("PHYSICAL ", label, " result=", _result.display_name(),
			" reason=", _result.reason, " ground_contacts=", _ground_contacts,
			" wall_contacts=", _wall_contacts, " max_z=", furthest_z,
			" defense=", lab._last_fielding_text)
		if pitcher_outcome in ["BOBBLE", "MISS"]:
			_check(_result.result in [BallPlayOutcome.Result.SINGLE, BallPlayOutcome.Result.DOUBLE],
				"%s must remain a fair safe result" % label)
		else:
			_check(_result.result == expected, "%s produced unexpected result" % label)
	_check((_ground_contacts > 0) == grounded, "%s ground contact evidence mismatch" % label)
	if label == "rolling Single crossing":
		_check(furthest_z > lab._field_definition.deep_air_z_m, "roller must cross both internal lines")
	if label in ["grounded wall", "wall on fly"]:
		_check(_wall_contacts > 0, "%s must have actual Jolt wall-contact evidence" % label)
	if label == "untouched Deep Air":
		_check(airborne_double_seen, "Deep Air must establish Double before ground or wall contact")
	if not pitcher_outcome.is_empty():
		_check(lab._pitcher_attempted, "moving grounder must trigger mound-envelope attempt")
		_check(pitcher_outcome in lab._last_fielding_text, "%s defense outcome mismatch" % label)
	if label == "pitcher charges before Single" and _result != null:
		_check(_result.resolution_position.z < lab._field_definition.safe_hit_z_m,
			"charging pitcher must physically control this grounder before Single")
		_check(lab._pitcher_marker.position.z < lab._field_definition.safe_hit_z_m,
			"pitcher must reach the grounder rather than extending the mound envelope")
	if label == "pitcher nearby air catch" and _result != null:
		_check(_result.caught and lab._pitcher_marker.position.x > 0.5,
			"pitcher must move to catch the nearby air ball without waiting for ground contact")
	if label == "pitcher clean grounder":
		_check(
			lab._ball_play_resolver.state.result_floor == BallPlayState.ResultFloor.SINGLE,
			"pitcher clean exception must be exercised after crossing Single"
		)
	lab.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
