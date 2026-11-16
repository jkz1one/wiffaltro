extends "res://src/tests/stadium_yard_two_native_pixel_diagnostic.gd"
## Same six exact source poses under the authentic runtime lease, never test-only antialiasing.

var _prior_msaa: int = 0
var _accepted_pairs: int = 0


func _pixel_before_install(_lab: PitchBatLab) -> void:
	_prior_msaa = int(get_viewport().msaa_3d)
	_check(
		not get_viewport().has_meta(StadiumWallRenderQuality.META),
		"quality diagnostic starts with no unowned preexisting lease"
	)


func _pixel_profile_begin(lab: PitchBatLab) -> void:
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var boundary: Node3D = property.get_node("BoundaryGraph")
	var state: Dictionary = get_viewport().get_meta(StadiumWallRenderQuality.META, {}).duplicate(
		true
	)
	_check(
		(
			get_viewport().msaa_3d >= Viewport.MSAA_4X
			and state.get("owners", {}).has(boundary.get_instance_id())
			and (
				property.get_meta("candidate_venue").render_profile.id
				== "AY02-WALL-MSAA4X-VIEWPORT-LEASE-v1"
			)
		),
		"actual authorized AY02 installation owns unchanged shared native quality lease"
	)
	_check(
		(
			not StadiumYardTwoLab.install(lab)
			and get_viewport().get_meta(StadiumWallRenderQuality.META) == state
		),
		"repeated candidate install rejects without acquiring or leaking a second lease"
	)
	print(
		"AY02_RUNTIME_QUALITY_PROFILE original=",
		_prior_msaa,
		" actual=",
		get_viewport().msaa_3d,
		" owner=",
		boundary.get_instance_id(),
		" source=StadiumWallRenderQuality unchanged=true"
	)


func _pixel_expect_sample(contrast: float, _extent: Vector2i) -> void:
	_check(contrast >= 0.03, "actual installed quality meets unchanged11x11 contrast threshold")
	_accepted_pairs += int(contrast >= 0.03)


func _pixel_expected_negative(_extent: Vector2i) -> bool:
	return false


func _pixel_after_samples(lab: PitchBatLab) -> void:
	_check(
		_diagnostic_pairs == 6 and _accepted_pairs == 6,
		"all six original source poses meet the same native threshold"
	)
	var viewport: Viewport = get_viewport()
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var boundary: Node3D = property.get_node("BoundaryGraph")
	var first_id: int = boundary.get_instance_id()
	var retained: Dictionary = viewport.get_meta(StadiumWallRenderQuality.META).duplicate(true)
	for shot: int in [
		MatchCameraDirector.Shot.BATTING,
		MatchCameraDirector.Shot.PITCHING,
		MatchCameraDirector.Shot.FIELD_SETUP,
		MatchCameraDirector.Shot.BALL_IN_PLAY
	]:
		lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
		_check(
			(
				viewport.get_meta(StadiumWallRenderQuality.META) == retained
				and viewport.msaa_3d >= Viewport.MSAA_4X
			),
			"role and inspection views retain the same authentic quality owner"
		)
	var replacement: PitchBatLab = _quality_new_lab()
	var second: StadiumYardTwoProperty = replacement.get_meta("stadium_property")
	var second_id: int = second.get_node("BoundaryGraph").get_instance_id()
	var owners: Dictionary = viewport.get_meta(StadiumWallRenderQuality.META).owners.duplicate(true)
	_check(
		owners.size() == 2 and owners.has(first_id) and owners.has(second_id),
		"coexisting actual candidates own distinct references to one viewport lease"
	)
	_check(
		(
			not StadiumYardTwoLab.install(replacement)
			and viewport.get_meta(StadiumWallRenderQuality.META).owners == owners
		),
		"replacement repeat install is also ownership-idempotent"
	)
	property.get_parent().remove_child(property)
	lab.remove_meta("stadium_property")
	property.queue_free()
	owners = viewport.get_meta(StadiumWallRenderQuality.META).owners
	_check(
		(
			not owners.has(first_id)
			and owners.has(second_id)
			and owners.size() == 1
			and viewport.msaa_3d >= Viewport.MSAA_4X
		),
		"detaching old property cannot undo its live replacement's rendering quality"
	)
	await _pixel_dispose_lab(replacement)
	_check(
		(
			int(viewport.msaa_3d) == _prior_msaa
			and not viewport.has_meta(StadiumWallRenderQuality.META)
		),
		"last actual scene teardown restores exact prior viewport quality and removes lease"
	)
	# Ownership controls only. No native contrast is captured under these external choices.
	viewport.msaa_3d = Viewport.MSAA_4X
	var adequate: PitchBatLab = _quality_new_lab()
	await _pixel_dispose_lab(adequate)
	_check(
		(
			viewport.msaa_3d == Viewport.MSAA_4X
			and not viewport.has_meta(StadiumWallRenderQuality.META)
		),
		"adequate preexisting rendering quality survives actual candidate teardown"
	)
	viewport.set("msaa_3d", _prior_msaa)
	var externally_changed: PitchBatLab = _quality_new_lab()
	viewport.msaa_3d = Viewport.MSAA_2X
	await _pixel_dispose_lab(externally_changed)
	_check(
		(
			viewport.msaa_3d == Viewport.MSAA_2X
			and not viewport.has_meta(StadiumWallRenderQuality.META)
		),
		"later external quality choice is preserved by unchanged shared lease semantics"
	)
	viewport.set("msaa_3d", _prior_msaa)
	print(
		"AY02_RUNTIME_QUALITY_LIFECYCLE repeated_install=true role_retained=true",
		" coexistence=true detach=true scene_teardown=true prior_adequate=true",
		" external_choice=true exact_original_restored=",
		int(viewport.msaa_3d) == _prior_msaa
	)


func _quality_new_lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_two_lab_only", true)
	lab._sky_backdrop_enabled = false
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(StadiumYardTwoLab.install(lab), "independent actual candidate quality owner installs")
	return lab


func _pixel_after_cleanup() -> void:
	_check(
		(
			int(get_viewport().msaa_3d) == _prior_msaa
			and not get_viewport().has_meta(StadiumWallRenderQuality.META)
		),
		"complete diagnostic scene teardown leaves no quality lease or setting behind"
	)


func _pixel_emit_result() -> void:
	print(
		"AY02_NATIVE_QUALITY_DIAGNOSTIC accepted_pairs=",
		_accepted_pairs,
		" threshold=0.03 full_qualification=false failures=",
		_failures
	)
