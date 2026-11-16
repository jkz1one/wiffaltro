extends "res://src/tests/hr_celebration07_test.gd"
## Cosmetic-only regression. Does not claim flight/landing or renderer acceptance.


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var lab: PitchBatLab = _fixture(0)
	lab._camera = Camera3D.new()
	lab.add_child(lab._camera)
	lab._batted_ball.position = Vector3(0, 0, -100)
	var ball: BattedBallBody = lab._batted_ball
	var visual: WiffleBallVisual = ball.get_child(1) as WiffleBallVisual
	var mesh: Mesh = visual.mesh
	var material: Material = visual.material_override
	var body_transform: Transform3D = ball.transform
	var collider: CollisionShape3D = ball.get_child(0) as CollisionShape3D
	var radius: float = (collider.shape as SphereShape3D).radius
	var camera_transform: Transform3D = lab._camera.transform
	_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
	_check(visual.scale == Vector3.ONE, "resolve starts at authored scale without a pop")
	lab._home_run._advance_ball_readability(lab, 1.0 / 60.0)
	var first: float = visual.scale.x
	_check(first > 1.0 and first < 2.0, "first frame eases into readability")
	for i: int in range(180):
		lab._home_run._advance_ball_readability(lab, 1.0 / 60.0)
	var projected: float = (
		lab._camera.unproject_position(ball.global_position).distance_to(
			lab._camera.unproject_position(
				ball.global_position + lab._camera.global_basis.x * WiffleBallVisual.RADIUS
			)
		)
		* 2.0
	)
	_check(
		absf(projected * visual.scale.x - 4.0) < 0.01,
		"stable active flight approaches four logical pixels"
	)
	_check(
		(
			ball.transform == body_transform
			and is_equal_approx(ball.radius_m, radius)
			and (collider.shape as SphereShape3D).radius == radius
			and collider.scale == Vector3.ONE
			and ball.linear_velocity == Vector3.ZERO
			and ball.angular_velocity == Vector3.ZERO
			and ball.freeze
			and lab._camera.transform == camera_transform
		),
		"cosmetic updates preserve body, collider, velocity, freeze and camera"
	)
	_check(
		visual.mesh == mesh and visual.material_override == material and visual.authored_mesh(),
		"original hollow shell and material remain unchanged"
	)
	var end_scale: float = visual.scale.x
	lab._home_run._finish_flight(lab, ball, &"timeout")
	lab._home_run._advance_ball_readability(lab, 0.0)
	_check(
		is_equal_approx(visual.scale.x, end_scale), "flight transition has no scale discontinuity"
	)
	lab._home_run.presentation_tail_elapsed = 0.175
	lab._home_run._advance_ball_readability(lab, 0.175)
	_check(
		is_equal_approx(visual.scale.x, (end_scale + 1.0) * 0.5), "return smoothly restores halfway"
	)
	lab._home_run.presentation_tail_elapsed = 0.35
	lab._home_run._advance_ball_readability(lab, 0.175)
	_check(visual.scale == Vector3.ONE, "return restores exact authored size before cleanup")
	_dispose(lab)

	for mutation: String in ["cancel", "replacement", "queued", "non_hr", "context"]:
		lab = _fixture(0)
		lab._camera = Camera3D.new()
		lab.add_child(lab._camera)
		ball = lab._batted_ball
		ball.position = Vector3(0, 0, -1000)
		visual = ball.get_child(1) as WiffleBallVisual
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
		lab._home_run._advance_ball_readability(lab, 10.0)
		_check(is_equal_approx(visual.scale.x, 8.0), "far flight has bounded cosmetic enlargement")
		match mutation:
			"cancel":
				lab._home_run.cancel()
			"replacement":
				lab._batted_ball = BattedBallBody.new()
				lab._batted_ball.freeze = true
				lab.add_child(lab._batted_ball)
				lab._home_run.advance(lab, 0.01)
				_check(
					(lab._batted_ball.get_child(1) as WiffleBallVisual).scale == Vector3.ONE,
					"replacement ball never inherits cosmetic scale"
				)
			"queued":
				visual.queue_free()
				lab._home_run._advance_ball_readability(lab, 0.01)
				lab._home_run.cancel()
			"non_hr":
				_resolve(lab, BallPlayOutcome.Result.DOUBLE, "DOUBLE")
			"context":
				lab._ball_play_resolver.state = BallPlayState.new()
				lab._home_run.advance(lab, 0.01)
		_check(
			visual.scale == Vector3.ONE and not lab._home_run.active,
			"restores old shell on " + mutation
		)
		_dispose(lab)

	var rate_scales: Array[float] = []
	for rate: int in [30, 60, 120]:
		lab = _fixture(0)
		lab._camera = Camera3D.new()
		lab.add_child(lab._camera)
		ball = lab._batted_ball
		ball.position = Vector3(0, 0, -100)
		visual = ball.get_child(1) as WiffleBallVisual
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
		for i: int in range(rate):
			lab._home_run._advance_ball_readability(lab, 1.0 / float(rate))
		rate_scales.append(visual.scale.x)
		_dispose(lab)
	_check(
		(
			absf(rate_scales[0] - rate_scales[1]) < 0.0001
			and absf(rate_scales[1] - rate_scales[2]) < 0.0001
		),
		"stationary target easing is independent of frame rate"
	)

	lab = _fixture(0)
	lab._camera = Camera3D.new()
	lab.add_child(lab._camera)
	ball = lab._batted_ball
	visual = ball.get_child(1) as WiffleBallVisual
	_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
	for depth: float in [-1.0, 100.0]:
		ball.position = Vector3(0, 0, depth)
		lab._home_run._advance_ball_readability(lab, 1.0)
		_check(visual.scale == Vector3.ONE, "near/behind camera shell stays authored size")
	ball.position = Vector3(0, 0, -100)
	lab._camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	lab._camera.size = 100.0
	lab._home_run._advance_ball_readability(lab, 10.0)
	projected = (
		lab._camera.unproject_position(ball.global_position).distance_to(
			lab._camera.unproject_position(
				ball.global_position + lab._camera.global_basis.x * WiffleBallVisual.RADIUS
			)
		)
		* 2.0
	)
	_check(
		absf(projected * visual.scale.x - 4.0) < 0.01, "orthographic projection targets four pixels"
	)
	# Same-body reentry resets before capturing another generation.
	if not ball.surface_contact.is_connected(lab._on_batted_surface_contact):
		ball.surface_contact.connect(lab._on_batted_surface_contact)
	_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
	_check(
		visual.scale == Vector3.ONE, "same-body new HR cannot capture previous enlarged baseline"
	)
	lab._home_run._advance_ball_readability(lab, 10.0)
	lab._home_run.cancel()
	_check(visual.scale == Vector3.ONE, "same-body repeat restores original scale")
	_dispose(lab)

	for extent: Vector2i in [
		Vector2i(1280, 720), Vector2i(640, 360), Vector2i(720, 1280), Vector2i(1920, 1080)
	]:
		get_window().size = extent
		await get_tree().process_frame
		lab = _fixture(3)
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
		var headline: Label = lab._hr_celebration_label
		var viewport_size: Vector2 = lab.get_viewport().get_visible_rect().size
		_check(
			(
				is_equal_approx(headline.position.y, viewport_size.y * 0.125)
				and is_equal_approx(
					headline.position.x + headline.size.x * 0.5, viewport_size.x * 0.5
				)
			),
			"responsive headline stays in upper viewport at " + str(extent)
		)
		_check(
			(
				headline.position.y + headline.size.y <= viewport_size.y
				and headline.size.x <= viewport_size.x
			),
			"headline fits viewport " + str(extent)
		)
		_dispose(lab)
	print("HR_READABILITY checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
