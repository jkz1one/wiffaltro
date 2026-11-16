extends "res://src/tests/hr_celebration07_test.gd"
## Lifecycle/fade regression; real visual blocker tests live in hr_visual_occlusion_test.


func _ready() -> void:
	for rate: int in [30, 60, 120]:
		var cue := HomeRunOcclusionMarker.new()
		for step: int in range(rate):
			cue.advance_fade(1.0 / rate, true)
		_check(is_equal_approx(cue.opacity, 1.0), "fade reaches full opacity at every rate")
		cue.advance_fade(0.05, false)
		_check(is_equal_approx(cue.opacity, 0.75), "fade out is smooth and bounded")
		cue.advance_fade(-1.0, false)
		_check(is_equal_approx(cue.opacity, 0.75), "negative time cannot change opacity")
		cue.advance_fade(1.0, false)
		_check(cue.opacity == 0.0, "fade out terminates exactly")
		cue.free()
	await _check_terrain_queries()
	for mutation: String in ["cancel", "replacement", "camera", "context", "non_hr"]:
		var lab: PitchBatLab = _fixture(0)
		lab._camera = Camera3D.new()
		lab.add_child(lab._camera)
		var body: BattedBallBody = lab._batted_ball
		body.position = Vector3(0, 1, -10)
		var pose: Transform3D = body.transform
		var mass: float = body.mass
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
		var cue: HomeRunOcclusionMarker = lab._home_run._occlusion_marker
		_check(is_instance_valid(cue), "HR owns one marker")
		cue.opacity = 1.0
		cue.show()
		match mutation:
			"cancel":
				lab._home_run.cancel()
			"replacement":
				lab._batted_ball = BattedBallBody.new()
				lab._batted_ball.freeze = true
				lab.add_child(lab._batted_ball)
				cue._process(0.01)
			"camera":
				lab._camera = Camera3D.new()
				lab.add_child(lab._camera)
				cue._process(0.01)
			"context":
				lab._ball_play_resolver.state = BallPlayState.new()
				cue._process(0.01)
			"non_hr":
				_resolve(lab, BallPlayOutcome.Result.DOUBLE, "DOUBLE")
		_check(
			not cue.visible and cue.opacity == 0.0, "invalid context hides immediately: " + mutation
		)
		_check(not cue.is_processing(), "invalid context stops sampling: " + mutation)
		if mutation != "non_hr":
			_check(
				body.transform == pose and body.mass == mass and body.freeze,
				"marker preserves physics"
			)
		_dispose(lab)
	var lab: PitchBatLab = _fixture(0)
	lab._camera = Camera3D.new()
	lab.add_child(lab._camera)
	for repeat: int in range(12):
		# resolve disconnects the contact listener; cancellation does not reconnect it.
		if not lab._batted_ball.surface_contact.is_connected(lab._on_batted_surface_contact):
			lab._batted_ball.surface_contact.connect(lab._on_batted_surface_contact)
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
		var old: HomeRunOcclusionMarker = lab._home_run._occlusion_marker
		lab._home_run.cancel()
		_check(not old.visible and not old.is_processing(), "repeated cancel leaves no live marker")
		await get_tree().process_frame
		_check(not is_instance_valid(old), "queued overlay is reclaimed")
	_dispose(lab)
	for event: String in ["hide", "attach"]:
		lab = _fixture(0)
		lab._camera = Camera3D.new()
		lab.add_child(lab._camera)
		var replacement: Array[HomeRunOcclusionMarker] = []
		if event == "hide":
			_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
			var old: HomeRunOcclusionMarker = lab._home_run._occlusion_marker
			old.visibility_changed.connect(func(): _reenter(lab, replacement), CONNECT_ONE_SHOT)
			lab._home_run.cancel()
		else:
			lab.child_entered_tree.connect(
				func(_node: Node): _reenter(lab, replacement), CONNECT_ONE_SHOT
			)
			_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
		_check(
			replacement.size() == 1 and lab._home_run._occlusion_marker == replacement[0],
			"newer reentrant marker retained: " + event
		)
		_check(
			lab._home_run.presentation_pending(lab),
			"newer reentrant owner state retained: " + event
		)
		await get_tree().process_frame
		var layers: int = 0
		for child: Node in lab.get_children():
			if child is CanvasLayer:
				for overlay: Node in child.get_children():
					if overlay is HomeRunOcclusionMarker:
						layers += 1
		_check(layers == 1, "only newer cue layer survives: " + event)
		_dispose(lab)
	for mutation: String in ["owner", "camera", "director", "queued_layer"]:
		lab = _fixture(0)
		lab._camera = Camera3D.new()
		lab.add_child(lab._camera)
		var original_owner: PitchBatLabHomeRun = lab._home_run
		var original_motion: BallInPlayCamera = lab._camera_director._live_coverage
		lab.child_entered_tree.connect(
			func(node: Node): _mutate_attachment(node, lab, mutation), CONNECT_ONE_SHOT
		)
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
		_check(
			not is_instance_valid(original_owner._occlusion_marker),
			"invalid attachment cannot become owned: " + mutation
		)
		if mutation != "queued_layer":
			_check(
				not original_motion.home_run_follow,
				"invalid attachment cannot change old camera follow: " + mutation
			)
		original_owner.cancel()
		_dispose(lab)
	print("HR_OCCLUSION_MARKER checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _reenter(lab: PitchBatLab, replacement: Array[HomeRunOcclusionMarker]) -> void:
	if not lab._batted_ball.surface_contact.is_connected(lab._on_batted_surface_contact):
		lab._batted_ball.surface_contact.connect(lab._on_batted_surface_contact)
	_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
	replacement.append(lab._home_run._occlusion_marker)


func _mutate_attachment(node: Node, lab: PitchBatLab, mutation: String) -> void:
	match mutation:
		"owner":
			lab._home_run = PitchBatLabHomeRun.new()
		"camera":
			lab._camera = Camera3D.new()
			lab.add_child(lab._camera)
		"director":
			lab._camera_director = MatchCameraDirector.new()
		"queued_layer":
			node.queue_free()


func _check_terrain_queries() -> void:
	var lab: PitchBatLab = _fixture(0)
	lab.process_mode = Node.PROCESS_MODE_INHERIT
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._camera = Camera3D.new()
	lab.add_child(lab._camera)
	lab._camera.position = Vector3(0, 6, 3)
	var ground: StaticBody3D = _terrain_box(lab, Vector3(0, 4, 0), Vector3(4, 0.2, 4), true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var probe := HomeRunOcclusionMarker.new()
	lab._batted_ball.position = Vector3(0, 5, 0)
	lab._camera.look_at(lab._batted_ball.position)
	_check(probe._terrain_clear(lab, lab._camera, lab._batted_ball), "above raised terrain allowed")
	lab._batted_ball.position.y = 3
	lab._camera.look_at(lab._batted_ball.position)
	_check(
		not probe._terrain_clear(lab, lab._camera, lab._batted_ball), "below raised terrain refused"
	)
	lab._camera.position = Vector3(0, 3, 1)
	lab._camera.look_at(lab._batted_ball.position)
	_check(not probe._terrain_clear(lab, lab._camera, lab._batted_ball), "both below slab refused")
	lab._batted_ball.position.y = 4
	lab._camera.look_at(lab._batted_ball.position)
	_check(not probe._terrain_clear(lab, lab._camera, lab._batted_ball), "inside slab refused")
	lab._batted_ball.position = Vector3(5, 5, 0)
	lab._camera.position = Vector3(5, 6, 3)
	lab._camera.look_at(lab._batted_ball.position)
	_check(probe._terrain_clear(lab, lab._camera, lab._batted_ball), "off finite terrain allowed")
	_check(
		not HomeRunOcclusionMarker.Occlusion.blocked(lab, lab._camera, lab._batted_ball),
		"off-field clear corridor has no visual blocker"
	)
	_terrain_box(lab, Vector3(5, 5.5, 1.5), Vector3(1, 2, 0.2), true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		probe._ground_segment_clear(
			lab,
			lab._batted_ball,
			lab._batted_ball.position,
			lab._batted_ball.position + Vector3.UP * 1000
		),
		"LOS terrain control has clear upward query"
	)
	_check(
		not probe._terrain_clear(lab, lab._camera, lab._batted_ball),
		"intervening actual terrain refuses cue even with no terrain above body"
	)
	var scenery := _terrain_box(lab, Vector3(0, 3.5, 0), Vector3(1, 0.1, 1), false)
	ground.rotation.z = 0.1
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._batted_ball.position = Vector3(0, 3, 0)
	lab._camera.position = Vector3(0, 3, 1)
	lab._camera.look_at(lab._batted_ball.position)
	_check(
		not probe._terrain_clear(lab, lab._camera, lab._batted_ball),
		"nonground scenery cannot mask raised sloped ground"
	)
	_check(
		probe._ground_segment_clear(lab, lab._batted_ball, Vector3(0, 3, 0), Vector3(0, 3.8, 0)),
		"nonground hit is skipped"
	)
	_check(
		not probe._ground_segment_clear(lab, lab._batted_ball, Vector3(NAN, 0, 0), Vector3.ZERO),
		"nonfinite query refused"
	)
	_check_bad_hits(probe, scenery)
	for index: int in range(HomeRunOcclusionMarker.TERRAIN_QUERY_LIMIT):
		_terrain_box(lab, Vector3(10, index + 10, 0), Vector3(1, 0.1, 1), false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		not probe._ground_segment_clear(
			lab, lab._batted_ball, Vector3(10, 9, 0), Vector3(10, 50, 0)
		),
		"32-hit budget exhaustion refuses cue"
	)
	_check(
		probe._ground_segment_clear(
			lab, lab._batted_ball, Vector3(10, 10.5, 0), Vector3(10, 50, 0)
		),
		"31 hits then clear is permitted"
	)
	probe.free()
	_dispose(lab)


func _terrain_box(lab: PitchBatLab, position: Vector3, size: Vector3, ground: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta(&"ball_surface", &"ground" if ground else &"stadium_scenery")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = position
	lab.add_child(body)
	return body


func _check_bad_hits(probe: HomeRunOcclusionMarker, scenery: StaticBody3D) -> void:
	var excluded: Array[RID] = []
	for hit: Dictionary in [
		{},
		{"collider": scenery},
		{"collider": scenery, "rid": RID()},
		{"collider": scenery, "rid": 1},
		{"collider": self, "rid": scenery.get_rid()},
		{"collider": 1, "rid": scenery.get_rid()},
		{"collider": scenery, "rid": get_viewport().get_viewport_rid()}
	]:
		_check(not probe._skip_non_ground_hit(hit, excluded), "malformed terrain-query hit refused")
	_check(
		probe._skip_non_ground_hit({"collider": scenery, "rid": scenery.get_rid()}, excluded),
		"valid nonground RID accepted once"
	)
	_check(
		not probe._skip_non_ground_hit({"collider": scenery, "rid": scenery.get_rid()}, excluded),
		"repeated nonground RID refused"
	)
