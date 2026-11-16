extends "res://src/tests/stadium_advanced_lab_test.gd"
## Actual isolated matches. The same boundary without the visual is the control.

var _compared_flights: int = 0
var _baseline_results: Array[Dictionary] = []
var _last_outcome: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(not StadiumCenterBoardLab.install(null), "null lab refuses")
	for shape: String in StadiumCenterBoardCandidate.SHAPES:
		await _center_shape(shape)
	_check(_compared_flights > 40 and _flights == _compared_flights * 2,
		"all five shapes compare actual terminal/clear/side/rear flights")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro center board gameplay passed: guarded opt-in, restart binding, "
			+ "held display and unchanged actual contacts/routes.")
	print("CENTER_BOARD_GAMEPLAY_FLIGHTS ", _flights, " compared=", _compared_flights)
	get_tree().quit(0 if _failures == 0 else 1)


func _new_lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	return lab


func _center_shape(shape: String) -> void:
	_baseline_results.clear()
	var reference: PitchBatLab = _new_lab()
	var plain: StadiumCenterBoardProperty = StadiumCenterBoardProperty.new()
	_check(plain.build_authoring_field(shape), "complete no-board authoring control builds")
	_check(StadiumPropertyRuntime._attach(reference, reference.get_node("StarterFieldGeometry"),
		plain, StadiumStarterLayout.empty()), "control uses the same ordinary field attachment")
	reference.set_meta("stadium_candidate_only", true)
	reference._ball_play_resolver.segment_observer = plain.observe
	reference._primary_fielder.stadium_boundary_clip = plain.boundary.graph.clip
	await get_tree().physics_frame
	await get_tree().physics_frame
	var routes: Array[Vector3] = _route_trace(reference, plain.boundary.graph)
	var physics: Array[String] = _physical_nodes(plain)
	await _contact_matrix(reference, plain.boundary.graph, false)
	reference.free()
	await get_tree().process_frame
	var lab: PitchBatLab = _new_lab()
	_reject(lab, shape, "opt-in is explicit")
	lab.set_meta("stadium_center_board_lab_only", true)
	_center_guards(lab, shape)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var camera: Transform3D = lab._camera.transform
	var shot: int = lab._camera_director.shot
	_check(StadiumCenterBoardLab.install(lab, shape), "complete center-board authoring field installs")
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumCenterBoardProperty = lab.get_meta("stadium_property")
	_check(lab._camera_director.shot == shot and lab._camera.transform == camera,
		"installation retains paused camera selection and transform")
	_reject(lab, shape, "duplicate refuses without changing live field or callbacks")
	lab._camera_director.restore_after_pause()
	_check(lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING,
		"paused role restores without replacement of camera director")
	var property_node: Node = property
	_check(property.objects.is_empty() and not property_node is StadiumScoreboardPropertyGeometry,
		"candidate is outside ordinary objects and frozen board_objects")
	_check(property.get_meta("center_board_authoring_source") == StadiumCenterBoardProperty.PROVENANCE
		and property.candidate.get_meta("center_board_study") == StadiumCenterBoardCandidate.ID,
		"new-instance authoring provenance is explicit")
	_check(property.candidate.transform == StadiumCenterBoardCandidate.pose()
		and property.candidate.global_transform * StadiumCenterBoardCandidate.ENVELOPE
		== StadiumCenterBoardCandidate.pose() * StadiumCenterBoardCandidate.ENVELOPE,
		"exact raised candidate pose and reservation are retained")
	_check(_physical_nodes(property) == physics and _physical_nodes(property.candidate).is_empty(),
		"candidate adds no body, area, collision shape or trigger to complete field")
	_check(not property.candidate.has_meta("owned_copy") and not property.candidate.has_meta("site")
		and not property.candidate.has_meta("surface_id"), "candidate is not an owned/report surface")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_route_trace(lab, property.boundary.graph) == routes,
		"actual defender paths match the same field without the decorative candidate")
	_center_guards(lab, shape)
	_display_lifecycle(lab, property)
	await _real_pitches(lab, property)
	await _real_ball_hold(lab, property)
	await _views(lab, "center-board-" + shape)
	await _contact_matrix(lab, property.boundary.graph, true)
	lab._match_mode = false
	_check(PhysicalMatchReport.capture(lab).is_empty(),
		"mechanics mode cannot promote authoring proof")
	lab._match_mode = true
	lab._start_new_match()
	_check(lab.get_meta("stadium_candidate_only", false)
		and PhysicalMatchReport.capture(lab).is_empty(),
		"ordinary mode/restart paths retain top-level report suppression")
	lab.free()
	await get_tree().process_frame


func _display_lifecycle(lab: PitchBatLab, property: StadiumCenterBoardProperty) -> void:
	var display: StadiumScoreboardTierDisplay = StadiumCenterBoardCandidate.display(property.candidate)
	var old: MatchState = lab._match_state
	old.home_team.runs = 4
	display._process(0)
	_check(display._match == old and display.shown.home == 4, "actual MatchState is bound")
	lab._start_new_match()
	# No manual refresh/rebind here: _start_new_match's ordinary marker/role path owns it.
	_check(display._match == lab._match_state and display._match != old and display.shown.home == 0,
		"ordinary restart immediately binds a fresh match without test-only refresh")
	old.home_team.runs = 999
	display._process(0)
	_check(display.shown.home == 0, "old MatchState cannot leak into a restarted display")
	lab._match_state.home_team.runs = 4
	lab._match_state.balls = 2
	display._process(0)
	for phase: int in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]:
		lab._match_state.phase = phase
		lab._match_state.home_team.runs = 5
		lab._match_state.balls = 3
		display._process(0)
		_check(display.shown.home == 4 and display.details.balls == "2", "whole display holds live data")
	lab._match_state.phase = MatchState.Phase.PLAY_DEAD
	display._process(0)
	_check(display.shown.home == 5 and display.details.balls == "3",
		"safe dead play refreshes whole board")
	property.rebind_displays(null)
	_check(display._match == null and display.shown.is_empty() and display.details.is_empty()
		and display._pending.is_empty() and not display.is_processing(),
		"null unbind clears all stale data")
	for label: Label3D in display._labels.values() + display._detail_labels.values():
		_check(label.text == "—", "null unbind blanks each readout")
	lab._start_new_match()
	_check(display._match == lab._match_state and display.shown.home == 0,
		"ordinary restart recovers a null-unbound display")


func _real_pitches(lab: PitchBatLab, property: StadiumCenterBoardProperty) -> void:
	var display: StadiumScoreboardTierDisplay = StadiumCenterBoardCandidate.display(property.candidate)
	for left: bool in [false, true]:
		lab._start_new_match()
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
			else PlayerDefinition.Handedness.RIGHT
		PitchBatLabPresentation.sync_players(lab)
		var actor: PitchFlightActor = lab._pitch_actor
		actor.set_physics_process(false)
		var parameters: PitchLaunchParameters = PitchLaunchParameters.new()
		parameters.pitch_id = &"pitch.overhand_four_seam"
		parameters.position = Vector3(0, 1.05 + 4.903325 * 0.04 * 0.04, 0.4)
		parameters.velocity = Vector3(0, 0, -10)
		parameters.drag_coefficient = 0
		parameters.magnus_scale = 0
		parameters.perforation_force_scale = 0
		parameters.seed = 51
		_check(lab._match_state.begin_pitch(), "actual pitch begins")
		actor.start_pitch(parameters)
		lab._match_state.home_team.runs = 6
		display._process(0)
		_check(actor.running and display.shown.home == 0, "real flying pitch holds score")
		actor._physics_process(0.2)
		var call: Vector2i = Vector2i(lab._match_state.balls, lab._match_state.strikes)
		_check(call == Vector2i(0, 1), "actual strike call is unchanged for each batting hand")
		actor.reset_pitch()
		lab._match_state.phase = MatchState.Phase.PLAY_DEAD
		display._process(0)
		_check(display.shown.home == 6, "called-pitch safe boundary refreshes held score")


func _real_ball_hold(lab: PitchBatLab, property: StadiumCenterBoardProperty) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var display: StadiumScoreboardTierDisplay = StadiumCenterBoardCandidate.display(property.candidate)
	var graph: StadiumRecipeBoundary = property.boundary.graph
	var row: Dictionary = {}
	for segment: Dictionary in graph.segments():
		if segment.role == "BACK_WALL_TERMINAL":
			row = segment
			break
	var normal: Vector2 = graph.inward(row)
	var center: Vector2 = (row.a + row.b) / 2 + normal * 0.7
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(center.x, row.height - 0.2, center.y)
	launch.velocity = Vector3(-normal.x, 0, -normal.y) * 36
	_check(lab._match_state.begin_pitch(), "actual held-score ball pitch begins")
	lab._start_ball_in_play(launch)
	lab._match_state.home_team.runs = 7
	display._process(0)
	_check(is_instance_valid(lab._batted_ball)
		and lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY and display.shown.home == 0,
		"actual live BattedBallBody holds the board's score")
	lab.set_physics_process(true)
	for frame in range(120):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	lab.set_physics_process(false)
	display._process(0)
	_check(not property.celebration.active, "non-HR terminal ball never starts candidate celebration")
	_check(lab._ball_play_resolver.state.dead
		and lab._match_state.phase != MatchState.Phase.BALL_IN_PLAY and display.shown.home == 7,
		"actual terminal resolution safely releases held score")
	lab._cleanup_batted_ball()


func _contact_matrix(lab: PitchBatLab, graph: StadiumRecipeBoundary, compare: bool) -> void:
	var index: int = 0
	for row: Dictionary in graph.segments():
		if row.role == "SIDE_RETURN_LIVE" and not String(row.id).begins_with("SIDE"):
			continue
		var normal: Vector2 = graph.inward(row)
		var center: Vector2 = (row.a + row.b) / 2 + normal * 0.7
		var variants: Array[bool] = [true]
		if row.role == "BACK_WALL_TERMINAL":
			variants.assign([false, true])
		for clear: bool in variants:
			var role: String = "BACK_CLEAR" if clear and row.role == "BACK_WALL_TERMINAL" else (
				"SIDE_EXIT_DEAD" if row.role == "SIDE_RETURN_LIVE" else row.role)
			var callback: Callable = func(outcome: BallPlayOutcome) -> void:
				_last_outcome = {"result": outcome.result, "reason": outcome.reason}
			lab._ball_play_resolver.play_resolved.connect(callback)
			await _flight(lab, graph,
				Vector3(center.x, row.height + 0.6 if clear else row.height - 0.2, center.y),
				Vector3(-normal.x, 0, -normal.y) * 36, role)
			lab._ball_play_resolver.play_resolved.disconnect(callback)
			var result: Dictionary = _last_outcome.duplicate()
			var contacts: Array[Dictionary] = []
			for event: Dictionary in lab._ball_play_resolver.state.stadium_contacts:
				contacts.append({"source": event.source, "id": event.id, "surface": event.surface,
					"role": event.role, "kind": event.kind})
			result["contacts"] = contacts
			if compare:
				_compared_flights += 1
				_check(index < _baseline_results.size() and result == _baseline_results[index],
					"real terminal/clear/side/rear contact outcome is unchanged by center board")
				_check(PhysicalMatchReport.capture(lab).is_empty(), "played candidate never emits reward proof")
			else:
				_baseline_results.append(result)
			index += 1


func _route_trace(lab: PitchBatLab, graph: StadiumRecipeBoundary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var fielder: FielderController = lab._primary_fielder
	fielder.set_physics_process(false)
	for target: Vector3 in [Vector3(-100, 0, 20), Vector3(100, 0, 20), Vector3(0, 0, 100)]:
		fielder.set_anchor(Vector3(0, 0, 10))
		fielder.begin_play()
		fielder.target_position = target
		for step in range(100):
			fielder._physics_process(1.0 / 30)
			result.append(fielder.global_position)
			_check(graph.contains(Vector2(fielder.global_position.x, fielder.global_position.z)),
				"defender clips to actual wall recipe")
		fielder.end_play()
	return result


func _physical_nodes(node: Node, prefix: String = "") -> Array[String]:
	var result: Array[String] = []
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		result.append(prefix + ":" + node.get_class())
	for child: Node in node.get_children():
		result.append_array(_physical_nodes(child, prefix + "/" + str(child.get_index())))
	return result


func _center_guards(lab: PitchBatLab, shape: String) -> void:
	lab._managed_match = true
	_reject(lab, shape, "managed match refuses")
	lab._managed_match = false
	lab._automation = MatchAutomation.new()
	_reject(lab, shape, "production automation refuses")
	lab._automation = null
	var state: MatchState = lab._match_state
	lab._match_state = null
	_reject(lab, shape, "absent match refuses")
	lab._match_state = state
	for phase: int in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY,
		MatchState.Phase.PLAY_DEAD, MatchState.Phase.INNING_TRANSITION, MatchState.Phase.GAME_END]:
		state.phase = phase
		_reject(lab, shape, "non-pre-pitch phase refuses")
	state.phase = MatchState.Phase.PRE_PITCH
	lab._batted_ball = BattedBallBody.new()
	_reject(lab, shape, "physical live ball refuses even with stale pre-pitch phase")
	lab._batted_ball.free()
	lab._batted_ball = null
	lab._release_controller.begin()
	_reject(lab, shape, "release gesture refuses before flight")
	lab._release_controller.cancel()
	lab._at_bat_cadence.begin_delivery(19)
	_reject(lab, shape, "active cadence refuses")
	lab._at_bat_cadence.stop()
	lab._match_mode = false
	_reject(lab, shape, "mechanics mode refuses")
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "guard test launches an actual mechanics pitch")
	lab._match_mode = true
	_reject(lab, shape, "actual flying actor refuses despite pre-pitch state")
	lab._pitch_actor.reset_pitch()
	var field: StringName = lab._field_id
	lab._field_id = &"unknown.field"
	_reject(lab, shape, "foreign field refuses")
	lab._field_id = field
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	host.position.x = 1
	_reject(lab, shape, "transformed host refuses")
	host.position.x = 0
	_reject(lab, "unknown-shape", "invalid candidate build preserves original field")
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)


func _reject(lab: PitchBatLab, shape: String, message: String) -> void:
	var before: Dictionary = _guard_state(lab)
	_check(not StadiumCenterBoardLab.install(lab, shape), message)
	_check(_guard_state(lab) == before, message + " without changing field, callbacks or camera")


func _guard_state(lab: PitchBatLab) -> Dictionary:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	return {"children": host.get_children(), "field_pose": host.transform,
		"property": lab.get_meta("stadium_property") if lab.has_meta("stadium_property") else null,
		"candidate": lab.get_meta("stadium_candidate_only", false),
		"receiver": lab._pitch_actor.receiver_router,
		"observer": lab._ball_play_resolver.segment_observer,
		"clip": lab._primary_fielder.stadium_boundary_clip,
		"routes": lab._primary_fielder.stadium_obstacles.duplicate(true),
		"director": lab._camera_director, "motion": lab._camera_director._live_coverage,
		"presentation_override": lab._camera_director.presentation_override,
		"camera": lab._camera.transform,
		"shot": lab._camera_director.shot, "visibility": lab._camera_director.tracking_visibility,
		"bounds": lab._camera_director.tracking_visibility._obstacles.duplicate(),
		"uprights": lab._camera_director.tracking_visibility._uprights.duplicate()}
