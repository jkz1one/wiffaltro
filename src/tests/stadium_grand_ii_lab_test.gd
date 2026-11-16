extends "res://src/tests/stadium_grand_i_lab_test.gd"
## Exact Grand I helper inheritance; only explicit Grand II orchestration is overridden.
## Frozen predecessor assertions and thresholds remain unchanged.


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(
		not StadiumGrandIILab.install(lab), "complete candidate requires explicit isolated opt-in"
	)
	lab.set_meta("stadium_grand_i_lab_only", true)
	_check(not StadiumGrandIILab.install(lab), "Grand I opt-in alone never authorizes Grand II")
	lab.remove_meta("stadium_grand_i_lab_only")
	lab.set_meta("stadium_grand_ii_lab_only", true)
	lab._camera_mode = 1
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var previous_shot: int = lab._camera_director.shot
	lab._managed_match = true
	_check(not StadiumGrandIILab.install(lab), "candidate cannot enter a managed fixture")
	lab._managed_match = false
	_check(
		StadiumGrandIILab.install(lab) and not StadiumGrandIILab.install(lab),
		"one complete assembly"
	)
	if _failures > 0:
		get_tree().quit(1)
		return
	_check(
		lab._camera_director.shot == previous_shot,
		"install preserves the current paused inspection shot"
	)
	lab._camera_director.restore_after_pause()
	_check(
		lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING and lab._camera_mode == 1,
		"closing paused inspection restores the pre-install role camera"
	)
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	_check(
		(
			property is StadiumGrandIIProperty
			and lab.has_meta("stadium_grand_ii_candidate")
			and not lab.has_meta("stadium_grand_i_candidate")
			and StadiumGrandIIFixtureStudy.valid(lab.get_meta("stadium_grand_ii_candidate"))
		),
		"installed adapter and source-bound authoring flag have only Grand II identity"
	)
	_check(
		PhysicalMatchReport.capture(lab).is_empty(),
		"candidate cannot produce a misleading ordinary-field production report"
	)
	_check(
		(
			property.get_meta("candidate_venue").items.size() == 85
			and not lab.has_meta("stadium_snapshot")
		),
		"complete NPC candidate grants no saved eligibility"
	)
	_check(
		(
			lab.get_node("StarterFieldGeometry").get_node_or_null("BackWall") == null
			and not property.has_node("TemplateBackWall")
		),
		"old infinite back collisions are absent"
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not property.configure_candidate(lab), "complete adapter cannot duplicate its receivers")
	_receiver_routes(property)
	lab._start_new_match()
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	lab._match_state.inning = 3
	lab._match_state.home_team.runs = 7
	property.display._process(0)
	_check(
		(
			property.display._match == lab._match_state
			and property.display.shown.inning == 3
			and property.display.shown.home == 7
		),
		"manual board follows the replacement match after restart"
	)
	_routes(lab, property)
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		for shot in range(MatchCameraDirector.Shot.size()):
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera, Vector3(0, 1, 5))
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			_check(
				_clear_camera(lab._camera), "all fixed views clear complete physical infrastructure"
			)
			if shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
				await _capture(
					(
						"grand-ii-field-%s-%s"
						% [
							"left" if left else "right",
							"batting" if shot == MatchCameraDirector.Shot.BATTING else "pitching"
						]
					)
				)
	for sample: Array in [
		[Vector3(0, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(1.5, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 4, 22.7), Vector3(0, 0, 36), false, BallPlayOutcome.Result.HOME_RUN]
	]:
		await _flight(lab, property, sample)
	for left in [false, true]:
		var inward: Vector3 = Vector3(-1 if left else 1, 0, 0)
		var from: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.5, left) + Vector3.UP * 0.6
		for foul in [false, true]:
			await _flight(
				lab,
				property,
				[
					from,
					inward * 8,
					foul,
					BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.SINGLE
				]
			)
	lab.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro complete Grand II lab passed: "
				+ "explicit assembly, contained routes and real outcomes."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)
