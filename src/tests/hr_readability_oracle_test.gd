extends "res://src/tests/hr_celebration07_test.gd"
## The oracle exempts only the captured authentic HR shell at its exact owned scale.
const Audit = preload("res://src/tests/stadium_yard_two_visibility_audit.gd")


func _ready() -> void:
	var lab: PitchBatLab = _fixture(0)
	lab._camera = Camera3D.new()
	lab.add_child(lab._camera)
	lab._batted_ball.position = Vector3(0, 0, -100)
	var visual: WiffleBallVisual = lab._batted_ball.get_child(1) as WiffleBallVisual
	var reference: WiffleBallVisual = WiffleBallVisual.create(0.78)
	var row: Dictionary = Audit._source_binding(visual, reference)
	_check(not row.is_empty() and Audit._self_intact(lab, visual, row), "canonical shell binds")
	_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
	lab._home_run._advance_ball_readability(lab, 1.0)
	var expected: Vector3 = visual.scale
	_check(expected.x > 1.0 and Audit._self_intact(lab, visual, row), "owned HR scale remains self")
	visual.scale.x += 0.01
	_check(not Audit._self_intact(lab, visual, row), "arbitrary scale remains invalid")
	visual.scale = expected
	visual.position.x = 0.01
	_check(not Audit._self_intact(lab, visual, row), "translation remains invalid")
	visual.position = Vector3.ZERO
	visual.rotation.y = 0.01
	_check(not Audit._self_intact(lab, visual, row), "rotation remains invalid")
	visual.rotation = Vector3.ZERO
	var exact_basis: Basis = visual.basis
	var sheared_basis: Basis = exact_basis
	sheared_basis.x += Vector3(0, 0.01, 0)
	visual.basis = sheared_basis
	_check(not Audit._self_intact(lab, visual, row), "sheared basis remains invalid")
	visual.basis = exact_basis
	var saved_binding: WeakRef = lab._home_run._ball_visual
	lab._home_run._ball_visual = weakref(reference)
	_check(not Audit._self_intact(lab, visual, row), "wrong HR visual cannot authorize scale")
	lab._home_run._ball_visual = saved_binding
	var material: StandardMaterial3D = visual.material_override
	var color: Color = material.albedo_color
	material.albedo_color = Color.MAGENTA
	_check(not Audit._self_intact(lab, visual, row), "owned scale cannot exempt material tampering")
	material.albedo_color = color
	lab._home_run._finish_flight(lab, lab._batted_ball, &"timeout")
	lab._home_run.presentation_tail_elapsed = 0.175
	lab._home_run._advance_ball_readability(lab, 0.175)
	_check(Audit._self_intact(lab, visual, row), "owned return scale remains self")
	lab._home_run.cancel()
	_check(
		visual.scale == Vector3.ONE and Audit._self_intact(lab, visual, row),
		"cancel restores canonical self"
	)
	reference.free()
	_dispose(lab)
	print("HR_READABILITY_ORACLE failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)
