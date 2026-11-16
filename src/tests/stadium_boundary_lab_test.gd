extends "res://src/tests/stadium_contacts_test.gd"
## Real isolated lab integration; saved/managed fixtures remain gated off.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	_check(StadiumPropertyRuntime.install_lab(lab, layout, StadiumStock.new_club()), "owned property")
	_check(not StadiumBoundaryLab.install(lab), "candidate boundary needs an explicit isolated opt-in")
	lab.set_meta("stadium_boundary_lab_only", true)
	lab._managed_match = true
	_check(not StadiumBoundaryLab.install(lab), "managed matches cannot bypass frozen geometry")
	lab._managed_match = false
	_check(StadiumBoundaryLab.install(lab) and not StadiumBoundaryLab.install(lab),
		"explicit lab installs one graph and cannot duplicate it")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: StadiumBoundaryPrototype = property.get_node("BoundaryGraph")
	_check(not property.has_node("TemplateBackWall")
		and lab._ball_play_resolver.segment_observer.is_valid(), "old wall and scalar observer replaced")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _routes_in_graph()
	_camera_clearance(lab, boundary)
	await _capture_lab(lab, lab.get_node("StarterFieldGeometry"))
	for sample: Array in [[Vector3(23, 2, 22.7), Vector3(0, 0, 36), false,
		BallPlayOutcome.Result.SINGLE], [Vector3(23, 2, 22.7), Vector3(0, 0, 36), true,
		BallPlayOutcome.Result.FOUL], [Vector3(0, 2, -5.5), Vector3(0, 0, -36), false,
		BallPlayOutcome.Result.FOUL], [Vector3(0, 4, 22.7), Vector3(0, 0, 36), false,
		BallPlayOutcome.Result.HOME_RUN], [Vector3(0, 0.05, 23), Vector3(0, 0, 12), false,
		BallPlayOutcome.Result.DOUBLE]]:
		await _lab_flight(lab, sample)
	var from: Vector3 = Vector3(0, 0, 14)
	lab._pitcher_marker.global_position = from
	var next: Vector3 = StadiumPropertyRuntime.pitcher_step(lab, Vector3(100, 0, 14), 100,
		Vector3(100, 0, 14))
	_assert_contained(next)
	_check(next.distance_to(from) <= 100, "pitcher uses boundary clipping within movement budget")
	lab.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro boundary lab checks passed: "
			+ "real outcomes, contained defenders and camera clearance.")
	get_tree().quit(0 if _failures == 0 else 1)


func _routes_in_graph() -> void:
	var fielder: FielderController = FielderController.new()
	add_child(fielder)
	fielder.set_physics_process(false)
	fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
	fielder.reaction_delay_seconds = 0
	for target: Vector3 in [Vector3(100, 0, 10), Vector3(-100, 0, 10),
		Vector3(0, 0, 100), Vector3(0, 0, -100), Vector3(100, 0, 100)]:
		var start: Vector3 = Vector3(0, 0, 10)
		fielder.set_anchor(start)
		fielder.begin_play()
		fielder.target_position = target
		fielder._physics_process(20)
		_assert_contained(fielder.global_position)
		_check(fielder.global_position.distance_to(start) <= fielder.move_speed_mps * 20,
			"large timestep cannot tunnel or increase movement budget")
		for mesh: MeshInstance3D in fielder._avatar._body_root.get_children():
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			for corner in range(8):
				var point: Vector3 = box.get_endpoint(corner)
				_check(StadiumBoundaryGraph.contains(Vector2(point.x, point.z)),
					"actual neutral avatar hands and torso remain inside walls")
		fielder.end_play()
		fielder.set_anchor(start)
		fielder.begin_play(false, (target - start).normalized())
		FielderFirstStep.advance(fielder, (target - start).normalized(), 20)
		_assert_contained(fielder.global_position)
		_check(fielder.global_position.distance_to(start) <= fielder.move_speed_mps * 20,
			"forced first step clips without steering or exceeding speed")
	fielder.queue_free()
	await get_tree().process_frame


func _assert_contained(point: Vector3) -> void:
	for row: Dictionary in StadiumBoundaryGraph.segments():
		_check((Vector2(point.x, point.z) - row.a).dot(StadiumBoundaryGraph.inward(row))
			>= StadiumBoundaryGraph.DEFENDER_RADIUS - 0.00002,
			"defender's full boundary envelope remains inside every face")


func _camera_clearance(lab: PitchBatLab, boundary: StadiumBoundaryPrototype) -> void:
	for box: AABB in boundary.visibility_bounds():
		_check(box.size.x < 1.5 and box.size.z < 1.5,
			"slanted wall never registers a giant false solid box through the field")
	var visibility: BallTrackingVisibility = lab._camera_director.tracking_visibility
	_check(not visibility._blocked(Vector3(0, 6, -3), Vector3(0, 1, 14)),
		"ordinary in-field view stays clear")
	for sign_value: int in [-1, 1]:
		for z: float in [1.0, 8.0, 15.0, 21.0]:
			var x: float = 8 + 16 * (z + 6) / 29.4
			var ball: Vector3 = Vector3(sign_value * (x - 2), 0.6, z)
			_check(visibility.lateral_clearance(ball) == 0,
				"segmented wall bounds do not masquerade as a narrow upright")
			var desired: Vector3 = Vector3(sign_value * (x + 6), 1.0, z)
			var clear: Vector3 = visibility.clear_position(desired, ball)
			_check(clear != desired and not visibility._blocked(clear, ball),
				"tracking recovers from either real side wall without touching its collision")


func _lab_flight(lab: PitchBatLab, sample: Array) -> void:
	_outcomes.clear()
	var callback: Callable = func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	lab._ball_play_resolver.play_resolved.connect(callback)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = sample[0]
	launch.velocity = sample[1]
	launch.is_foul = sample[2]
	lab._start_ball_in_play(launch)
	_check(lab._batted_ball.physics_contact_router.is_valid(), "real lab ball has the contact router")
	for frame in range(80):
		await get_tree().physics_frame
		lab._physics_process(1.0 / 60.0)
		if lab._ball_play_resolver.state.dead:
			break
	_check(_outcomes.size() == 1 and _outcomes[0].result == sample[3],
		"actual lab resolves the correct graph-specific outcome exactly once")
	lab._ball_play_resolver.play_resolved.disconnect(callback)
	lab._cleanup_batted_ball()
	await get_tree().physics_frame
