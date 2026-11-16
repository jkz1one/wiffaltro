extends "res://src/tests/stadium_target_camera_test.gd"
## Real scored HR handoff/lifecycle. Physical cabinet entry remains in honest telemetry.

# Pinned contract budgets: changing production constants must not widen this oracle.
const FLIGHT_LIMIT: float = 6.0
const LANDING_CONTEXT: float = 0.65
const HOLD_MINIMUM: float = 4.40
const TAIL_MINIMUM: float = 0.65
const RETURN_LIMIT: float = 4.0
const SAMPLE_SLACK: float = 0.1
const LAUNCH_X: Array[float] = [-8, -4, -2, 0, 2, 4, 8]
var _physics_fps: int = 60
var _process_fps: int = 60
var _all_shapes: bool = false
var _cases: int = 0
var _opaque_cases: int = 0
var _inside_cases: int = 0
var _cue_frames: int = 0
var _sustained_cue_frames: int = 0
var _terrain_refusal_frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
		elif argument == "--hr-physics-fps=120":
			_physics_fps = 120
		elif argument in ["--hr-process-fps=30", "--hr-process-fps=60", "--hr-process-fps=120"]:
			_process_fps = int(argument.trim_prefix("--hr-process-fps="))
		elif argument == "--hr-all-shapes":
			_all_shapes = true
	var previous_ticks: int = Engine.physics_ticks_per_second
	var previous_fps: int = Engine.max_fps
	Engine.physics_ticks_per_second = _physics_fps
	Engine.max_fps = _process_fps
	get_window().size = Vector2i(1280, 720)
	_check(PitchBatLabHomeRun.MAX_FLIGHT_SECONDS == FLIGHT_LIMIT
		and PitchBatLabHomeRun.LANDING_CONTEXT_SECONDS == LANDING_CONTEXT
		and PitchBatLabHomeRun.HOLD_SECONDS == HOLD_MINIMUM
		and PitchBatLabHomeRun.PRESENTATION_TAIL_SECONDS == TAIL_MINIMUM
		and PitchBatLabHomeRun.MAX_RETURN_SECONDS == RETURN_LIMIT,
		"observed-flight and return budgets retain the pinned lifecycle contract")
	await _negative_controls()
	_cue_oracle_controls()
	await _terrain_oracle_controls()
	var shapes: Array[String] = ["straight"]
	if _all_shapes:
		shapes.assign(StadiumCenterBoardCandidate.SHAPES)
	var hands: Array[bool] = [false]
	if _all_shapes:
		hands.assign([false, true])
	for shape: String in shapes:
		for left: bool in hands:
			for defense: bool in [false, true]:
				for vx: float in LAUNCH_X:
					await _carry_case(shape, left, defense, vx)
	Engine.physics_ticks_per_second = previous_ticks
	Engine.max_fps = previous_fps
	_check(_inside_cases > 0, "honest telemetry retains genuine cabinet entry during flight")
	_check(_cue_frames > 0 and _sustained_cue_frames > 0,
		"actual scored flight exercises sustained visible aligned location cues")
	_check(_terrain_refusal_frames > 0, "actual flight exercises witnessed terrain cue refusal")
	await TestAudioDrain.finish(get_tree())
	print("CENTER_BOARD_HR_CARRY_SUMMARY cases=", _cases, " opaque_cases=", _opaque_cases,
		" inside_cases=", _inside_cases,
		" physics_fps=", _physics_fps, " requested_process_fps=", _process_fps, " shapes=", shapes)
	if _failures == 0:
		print("Wiffaltro center board HR carry passed: actual scoring, camera/body carry, "
			+ "bounded post-flight celebration, honest opacity telemetry and observed flight completion.")
	get_tree().quit(0 if _failures == 0 else 1)


func _carry_case(shape: String, left: bool, defense: bool, vx: float) -> void:
	_cases += 1
	var id: String = "%s-%s-%s-vx%s" % [shape, "left" if left else "right",
		"pitching" if defense else "batting", str(vx).replace("-", "minus")]
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_meta("stadium_center_board_lab_only", true)
	_check(StadiumCenterBoardLab.install(lab, shape), "real HR probe field installs while idle")
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	lab._player_home = defense
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	lab._apply_role_camera()
	lab._camera_director.snap(lab._camera)
	lab._record_export.path = "user://center-board-hr-%d-%s.json" % [OS.get_process_id(), id]
	var record_path: String = lab._record_export.path
	await get_tree().physics_frame
	await get_tree().physics_frame
	var property: StadiumCenterBoardProperty = lab.get_meta("stadium_property")
	var celebration: StadiumCenterBoardCelebration = property.celebration
	celebration.handoff_started.connect(_capture_before.bind(id))
	celebration.wide_arrived.connect(_capture_phase.bind("wide-complete", id))
	var probe: CarryProbe = CarryProbe.new()
	probe.celebration = celebration
	probe.process_mode = Node.PROCESS_MODE_PAUSABLE
	probe.transition_sample.connect(_capture_phase.bind("transition", id))
	probe.lab = lab
	probe.process_priority = 1000
	probe.witness.connect(_capture_witness.bind(id))
	add_child(probe)
	lab._ball_play_resolver.play_resolved.connect(probe.note_outcome)
	lab._active_play_record = PlayRecord.new()
	_check(lab._match_state.begin_pitch(), "real HR launch starts a normal pitch state")
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1, 0.28)
	launch.velocity = Vector3(vx, 18, 30)
	launch.orientation = Quaternion.IDENTITY
	launch.angular_velocity = Vector3.ZERO
	lab._start_ball_in_play(launch)
	_check(lab.is_processing() and lab.is_physics_processing(),
		"ordinary presentation camera and physical ball stay enabled through scoring")
	var paused_once: bool = false
	var return_paused: bool = false
	var continuation_checked: bool = false
	# Includes genuine scoring approach, six-second flight, four-second return and pauses.
	for frame in range(_physics_fps * 13):
		await get_tree().physics_frame
		if not continuation_checked and celebration.active:
			continuation_checked = true
			_continuation_controls(lab, property)
		if not paused_once and vx == -4 and not defense and not left \
			and lab._home_run.active and lab._home_run.elapsed >= 0.1:
			paused_once = true
			await _pause_carry(lab, celebration)
		if not return_paused and vx == -4 and not defense and not left and celebration.active:
			return_paused = true
			await _pause_carry(lab, celebration)
		if probe.hold_end >= 0:
			break
	# Observe normal post-hold cleanup without replacing either timer or body.
	await get_tree().physics_frame
	await get_tree().process_frame
	probe.set_process(false)
	var report: Dictionary = probe.report()
	report["id"] = id
	report["physics_fps"] = _physics_fps
	report["requested_process_fps"] = _process_fps
	report["launch"] = [vx, 18, 30]
	print("CENTER_BOARD_HR_CARRY ", JSON.stringify(report, "", true, true))
	_check(probe.results.size() == 1 and probe.results[0].result == BallPlayOutcome.Result.HOME_RUN,
		id + ": actual fair airborne clearance scores exactly one HR")
	_check(lab._play_records.size() == 1 and lab._play_records[0].result == &"home_run"
		and probe.score == Vector2i(lab._match_state.away_team.runs, lab._match_state.home_team.runs)
		and probe.score.x + probe.score.y == 1 and not probe.score_changed,
		id + ": carry cannot change the scored HR or add another record")
	_check(probe.post_frames > 0 and probe.moving_post_frames > 0
		and probe.first_wide >= 0 and probe.first_wide <= FLIGHT_LIMIT + SAMPLE_SLACK
		and probe.saw_freeze and not probe.early_freeze and probe.valid_flight_end
		and probe.first_freeze >= probe.first_wide
		and probe.first_freeze <= probe.first_wide + SAMPLE_SLACK,
		id + ": real body freezes only after observed landing context or bounded timeout")
	_check(probe.contact_count > 0
		and lab._ball_play_resolver.state.stadium_contacts.size() == probe.contact_count
		and not lab._ball_play_resolver.state.has_grounded,
		id + ": post-terminal motion adds no scoring contacts or ground record")
	_check(probe.finite and probe.max_speed <= BallInPlayCamera.MAX_SPEED + 0.1
		and probe.max_turn <= BallInPlayCamera.MAX_TURN_SPEED + 0.02,
		id + ": every live and celebration transition frame stays speed/turn bounded")
	_check(probe.armed_at_score and probe.valid_handoff and not probe.early_handoff
		and probe.score_notice_visible and probe.flight_tracking_correct
		and celebration.starts == 1
		and probe.transition_progress and probe.wide_completion >= probe.first_wide
		and probe.wide_context_visible and continuation_checked,
		id + ": confirmed HR tracks physical flight before bounded visible celebration return")
	_check(probe.tracked_outside_frames == 0
		and probe.uncovered_frames == probe.terrain_uncovered_frames
		and probe.terrain_fade_failures == 0,
		id + ": tracked occlusion has an aligned cue or witnessed terrain with bounded refusal")
	_check(probe.hold_end >= HOLD_MINIMUM
		and probe.hold_end >= probe.first_wide + TAIL_MINIMUM
		and probe.hold_end >= probe.wide_completion
		and probe.hold_end <= maxf(HOLD_MINIMUM, probe.first_wide + RETURN_LIMIT) + SAMPLE_SLACK
		and lab._batted_ball == null and not lab._home_run.cleanup_refused,
		id + ": ordinary cleanup follows flight, minimum tail and completed bounded return")
	_cue_frames += probe.cue_frames
	_sustained_cue_frames += probe.sustained_cue_frames
	_terrain_refusal_frames += probe.terrain_refusal_frames
	_check(vx != -4 or defense or left or (paused_once and return_paused),
		id + ": designated pause case exercises both flight and return pauses")
	_check(PhysicalMatchReport.capture(lab).is_empty(), "HR probe remains candidate-only")
	_opaque_cases += int(probe.inside_frames > 0 or probe.raw_blocked_frames > 0)
	_inside_cases += int(probe.inside_frames > 0)
	probe.free()
	lab._start_new_match()
	_check(not celebration.active and celebration.reason.is_empty() and celebration.elapsed == 0
		and lab._camera_director.presentation_override == celebration._update_camera,
		"ordinary restart clears handoff state while retaining only its valid owned callback")
	lab.free()
	DirAccess.remove_absolute(record_path)
	await get_tree().process_frame


func _capture_witness(_sample: Dictionary, id: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join("center-board-live-hr-inside-" + id + ".png")) == OK,
		"actual HR cabinet-entry frame saved without stopping the body or camera")


func _capture_before(id: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	# The last completed native frame is genuinely before the scored-event handoff.
	_check(get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(
		"center-board-live-hr-before-handoff-" + id + ".png")) == OK,
		"last completed tracked-flight frame saved before handoff")


func _capture_phase(phase: String, id: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(
		"center-board-live-hr-" + phase + "-" + id + ".png")) == OK,
		"actual bounded celebration phase saved without stopping the body")


func _pause_carry(lab: PitchBatLab, celebration: StadiumCenterBoardCelebration) -> void:
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	var clock: float = lab._home_run.elapsed
	var transition: float = celebration.elapsed
	var ball: Transform3D = lab._batted_ball.global_transform
	var camera: Transform3D = lab._camera.global_transform
	for frame in range(8):
		await get_tree().physics_frame
	_check(lab._home_run.elapsed == clock and celebration.elapsed == transition
		and lab._batted_ball.global_transform == ball and lab._camera.global_transform == camera,
		"pause freezes physical carry, original HR time and candidate transition together")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)


func _negative_controls() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var original_director: MatchCameraDirector = lab._camera_director
	_check(not original_director.presentation_override.is_valid(),
		"ordinary no-center camera starts with an empty presentation override")
	lab.set_meta("stadium_center_board_lab_only", true)
	_check(StadiumCenterBoardLab.install(lab), "negative-control candidate installs")
	var property: StadiumCenterBoardProperty = lab.get_meta("stadium_property")
	var celebration: StadiumCenterBoardCelebration = property.celebration
	_check(lab._camera_director == original_director
		and lab._camera_director.presentation_override == celebration._update_camera,
		"candidate keeps director identity and owns its exact opt-in callback")
	var before: Transform3D = lab._camera.global_transform
	var shot: int = lab._camera_director.shot
	for result: int in [BallPlayOutcome.Result.HOME_RUN, BallPlayOutcome.Result.OUT,
		BallPlayOutcome.Result.FOUL, BallPlayOutcome.Result.SINGLE]:
		var outcome: BallPlayOutcome = BallPlayOutcome.new()
		outcome.result = result as BallPlayOutcome.Result
		celebration._on_resolved(outcome)
	_check(not celebration.active and celebration.starts == 0
		and lab._camera.global_transform == before and lab._camera_director.shot == shot,
		"an unconfirmed HR or non-HR cannot start celebration or move its camera")
	_inactive_camera_parity(celebration)
	var callback: Callable = celebration._update_camera
	celebration.free()
	_check(not lab._camera_director.presentation_override.is_valid() and not callback.is_valid(),
		"teardown clears only the exact owned callback and leaves no stale node target")
	lab.free()
	await get_tree().process_frame


func _cue_oracle_controls() -> void:
	_check(HomeRunOcclusionMarker.SAMPLE_SECONDS == 0.10
		and HomeRunOcclusionMarker.FADE_IN_SECONDS == 0.15
		and HomeRunOcclusionMarker.FADE_OUT_SECONDS == 0.20,
		"location-cue response budgets remain pinned")
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var marker: HomeRunOcclusionMarker = HomeRunOcclusionMarker.new()
	marker.set_process(false)
	marker._layer = layer
	layer.add_child(marker)
	marker._point = Vector2(640, 360)
	marker.opacity = 1.0
	_check(CarryProbe._cue_visible(marker, marker._point), "cue oracle accepts visible aligned ring")
	_check(not CarryProbe._cue_visible(null, marker._point), "missing cue fails coverage")
	marker.hide()
	_check(not CarryProbe._cue_visible(marker, marker._point), "hidden cue fails coverage")
	marker.show()
	_check(not CarryProbe._cue_visible(marker, Vector2(680, 360)), "misaligned cue fails coverage")
	marker.opacity = 0.0
	_check(not CarryProbe._cue_visible(marker, marker._point), "transparent cue fails coverage")
	layer.free()


func _terrain_oracle_controls() -> void:
	var fixture: Node3D = Node3D.new()
	add_child(fixture)
	fixture.position = Vector3(500, 0, 0)
	var ground: StaticBody3D = _oracle_box(fixture, Vector3(0, 3, 0), &"ground")
	var foreground: StaticBody3D = _oracle_box(fixture, Vector3(0, 4.5, 0), &"wall")
	await get_tree().physics_frame
	var start: Vector3 = Vector3(500, 5, 0)
	var target: Vector3 = Vector3(500, 1, 0)
	var proof: Dictionary = CarryProbe._terrain_witness(fixture, start, target)
	_check(not proof.is_empty() and proof.collider_path == str(ground.get_path()),
		"positive-y raised actual ground proves interception despite nonground foreground")
	_check(CarryProbe._terrain_witness(fixture, Vector3(520, -8, 0),
		Vector3(520, -10, 0)).is_empty(),
		"below-zero off-footprint clear segments never earn a terrain exemption")
	_check(CarryProbe._terrain_witness(fixture, start, Vector3(500, 4, 0)).is_empty(),
		"foreground nonground alone never earns a terrain exemption")
	ground.set_meta(&"ball_surface", &"wall")
	_check(CarryProbe._terrain_witness(fixture, start, target).is_empty(),
		"live ground metadata withdrawal removes the terrain witness")
	ground.set_meta(&"ball_surface", &"ground")
	var marker: HomeRunOcclusionMarker = HomeRunOcclusionMarker.new()
	add_child(marker)
	marker.set_process(false)
	marker.opacity = 1.0
	_check(not CarryProbe._terrain_fade_valid(marker, 0.41, 1.0),
		"visible ghost cue beyond the refusal budget fails")
	marker.opacity = 0.0
	marker.hide()
	_check(CarryProbe._terrain_fade_valid(marker, 0.41, 0.0),
		"fully faded hidden cue satisfies witnessed refusal")
	_check(not CarryProbe._terrain_fade_valid(null, 0.41, 0.0),
		"missing marker is not a successful terrain refusal")
	marker.show()
	marker.opacity = 0.5
	_check(not CarryProbe._terrain_fade_valid(marker, 0.21, 0.25),
		"cue cannot brighten after the terrain sampling window")
	var probe: CarryProbe = CarryProbe.new()
	probe._observe_terrain(marker, proof, 0.05)
	probe._observe_terrain(marker, proof, 0.05)
	_check(probe.terrain_seconds > 0, "actual retained terrain proof advances refusal clock")
	probe._observe_terrain(marker, {}, 0.05)
	_check(probe.terrain_seconds == 0, "disappearing proof resets the continuous refusal clock")
	probe.free()
	marker.free()
	fixture.remove_child(ground)
	await get_tree().physics_frame
	_check(CarryProbe._terrain_witness(fixture, start, target).is_empty(),
		"removed actual ground cannot leave a stale terrain exemption")
	ground.free()
	foreground.free()
	fixture.free()


func _oracle_box(parent: Node3D, point: Vector3, surface: StringName) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.set_meta(&"ball_surface", surface)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 0.2, 2)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.position = point
	return body


func _inactive_camera_parity(celebration: StadiumCenterBoardCelebration) -> void:
	var first: Camera3D = Camera3D.new()
	var second: Camera3D = Camera3D.new()
	add_child(first)
	add_child(second)
	var ordinary: MatchCameraDirector = MatchCameraDirector.new()
	var installed: MatchCameraDirector = MatchCameraDirector.new()
	installed.presentation_override = celebration._update_camera
	for shot: int in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING,
		MatchCameraDirector.Shot.SIDE, MatchCameraDirector.Shot.ESTABLISHING]:
		ordinary.set_shot(shot as MatchCameraDirector.Shot)
		installed.set_shot(shot as MatchCameraDirector.Shot)
		ordinary.snap(first)
		installed.snap(second)
		for fps: int in [30, 60, 120]:
			for frame in range(12):
				ordinary.update(first, 1.0 / fps, false, Vector3(0, 1, 5))
				installed.update(second, 1.0 / fps, false, Vector3(0, 1, 5))
				_check(first.global_transform == second.global_transform and first.fov == second.fov,
					"inactive callback is effect-equivalent to default empty camera behavior")
	first.free()
	second.free()


func _continuation_controls(lab: PitchBatLab, property: StadiumCenterBoardProperty) -> void:
	# Exercise each same-frame rejection against an otherwise genuine scored HR.
	# A separate handler and scratch camera keep the real presentation untouched.
	var test: StadiumCenterBoardCelebration = StadiumCenterBoardCelebration.new()
	property.add_child(test)
	test._lab = lab
	test._candidate = property.candidate
	var body: BattedBallBody = lab._batted_ball
	var state: MatchState = lab._match_state
	var scratch: Camera3D = Camera3D.new()
	add_child(scratch)
	var camera: Transform3D = lab._camera.global_transform
	var body_pose: Transform3D = body.global_transform
	var velocity: Vector3 = body.linear_velocity
	var handler: Callable = lab._camera_director.presentation_override
	var arm: Callable = func() -> void:
		test.active = true
		test._match = state
		test._ball_id = body.get_instance_id()
	arm.call()
	_check(test._update_camera(lab._camera_director, scratch, 0, true, body.global_position),
		"continuation controls begin from eligible genuine scored-HR state")
	lab._home_run.active = false
	_check(not test._update_camera(lab._camera_director, scratch, 0, true, body.global_position)
		and not test.active, "same-frame hold end clears override before camera movement")
	lab._home_run.active = true
	arm.call()
	lab._match_mode = false
	_check(not test._update_camera(lab._camera_director, scratch, 0, true, body.global_position)
		and not test.active, "mechanics mode cannot retain a scored-match celebration")
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	test._on_resolved(outcome)
	_check(not test.active and test.starts == 0, "mechanics HR cannot start a match celebration")
	lab._match_mode = true
	arm.call()
	var phase: int = state.phase
	state.phase = MatchState.Phase.PRE_PITCH
	_check(not test._update_camera(lab._camera_director, scratch, 0, true, body.global_position)
		and not test.active, "stale pre-pitch state cannot retain post-score presentation")
	state.phase = phase as MatchState.Phase
	arm.call()
	var replacement: BattedBallBody = BattedBallBody.new()
	lab._batted_ball = replacement
	_check(not test._update_camera(lab._camera_director, scratch, 0, true, body.global_position)
		and not test.active, "replaced body cannot inherit a different HR's handoff")
	lab._batted_ball = body
	replacement.free()
	arm.call()
	var freed: BattedBallBody = BattedBallBody.new()
	lab._batted_ball = freed
	test._ball_id = freed.get_instance_id()
	freed.free()
	_check(not test._update_camera(lab._camera_director, scratch, 0, true, body.global_position)
		and not test.active, "freed body clears callback before stale access")
	lab._batted_ball = body
	arm.call()
	var replacement_state: MatchState = MatchState.new()
	replacement_state.phase = MatchState.Phase.PLAY_DEAD
	lab._match_state = replacement_state
	_check(not test._update_camera(lab._camera_director, scratch, 0, true, body.global_position)
		and not test.active, "new match cannot inherit an old HR's handoff")
	lab._match_state = state
	test.free()
	scratch.free()
	_check(lab._camera.global_transform == camera and body.global_transform == body_pose
		and body.linear_velocity == velocity and lab._camera_director.presentation_override == handler,
		"all same-frame controls preserve real body, camera and independently owned handler")


class CarryProbe extends Node:
	signal witness(sample: Dictionary)
	signal transition_sample
	var lab: PitchBatLab
	var celebration: StadiumCenterBoardCelebration
	var results: Array[Dictionary] = []
	var score: Vector2i = Vector2i.ZERO
	var score_changed: bool = false
	var contact_count: int = 0
	var post_frames: int = 0
	var moving_post_frames: int = 0
	var inside_frames: int = 0
	var raw_blocked_frames: int = 0
	var blocked_frames: int = 0
	var outside_frames: int = 0
	var tracked_blocked_frames: int = 0
	var tracked_outside_frames: int = 0
	var finite: bool = true
	var max_speed: float = 0
	var max_turn: float = 0
	var first_wide: float = -1
	var first_inside: Dictionary = {}
	var first_blocked: Dictionary = {}
	var armed_at_score: bool = false
	var score_notice_visible: bool = false
	var flight_tracking_correct: bool = true
	var valid_handoff: bool = false
	var early_handoff: bool = false
	var valid_flight_end: bool = false
	var first_ground: float = -1
	var ground_now: bool = false
	var cue_frames: int = 0
	var sustained_cue_frames: int = 0
	var first_freeze: float = -1
	var uncovered_frames: int = 0
	var terrain_uncovered_frames: int = 0
	var terrain_refusal_frames: int = 0
	var terrain_fade_failures: int = 0
	var terrain_seconds: float = 0
	var first_terrain_uncovered: Dictionary = {}
	var blocked_seconds: float = 0
	var first_uncovered: Dictionary = {}
	var transition_progress: bool = false
	var transition_pose: Dictionary = {}
	var wide_completion: float = -1
	var wide_context_visible: bool = false
	var saw_freeze: bool = false
	var early_freeze: bool = false
	var hold_end: float = -1
	var _terrain_previous: bool = false
	var _previous_opacity: float = 0
	var _elapsed: float = 0
	var _delta_count: int = 0
	var _delta_sum: float = 0
	var _delta_min: float = INF
	var _delta_max: float = 0
	var _previous_camera: Transform3D
	var _previous_valid: bool = false
	var _transition_shot: bool = false

	func note_outcome(outcome: BallPlayOutcome) -> void:
		score = Vector2i(lab._match_state.away_team.runs, lab._match_state.home_team.runs)
		contact_count = lab._ball_play_resolver.state.stadium_contacts.size()
		armed_at_score = celebration._armed and not celebration.active and celebration.starts == 0 \
			and not lab._home_run.flight_complete and not lab._home_run.wide_shot \
			and not lab._batted_ball.freeze
		score_notice_visible = lab._status_label.is_visible_in_tree() \
			and lab._event_panel.is_visible_in_tree() and "HOME RUN" in lab._status_label.text
		results.append({"result": outcome.result, "reason": String(outcome.reason),
			"play_time": lab._ball_play_resolver.state.elapsed_seconds,
			"process_time": _elapsed, "position": _vector(outcome.resolution_position),
			"score": [score.x, score.y], "armed_at_score": armed_at_score})

	func _process(delta: float) -> void:
		_elapsed += delta
		if delta > 0:
			_delta_count += 1
			_delta_sum += delta
			_delta_min = minf(_delta_min, delta)
			_delta_max = maxf(_delta_max, delta)
		if not results.is_empty() and not lab._home_run.active and hold_end < 0:
			hold_end = lab._home_run.elapsed
		if not is_instance_valid(lab._batted_ball) or hold_end >= 0:
			return
		var camera: Transform3D = lab._camera.global_transform
		var ball: Vector3 = lab._batted_ball.global_position
		finite = finite and camera.is_finite() and ball.is_finite()
		# Measure across the actual early handoff and complete wide approach. Do not
		# exclude transition frames because their shot enum has already changed.
		if _previous_valid and delta > 0:
			max_speed = maxf(max_speed, camera.origin.distance_to(_previous_camera.origin) / delta)
			max_turn = maxf(max_turn, camera.basis.get_rotation_quaternion().angle_to(
				_previous_camera.basis.get_rotation_quaternion()) / delta)
		_previous_camera = camera
		_previous_valid = true
		if not lab._home_run.active:
			return
		ground_now = false
		for contact: Node3D in lab._batted_ball.get_colliding_bodies():
			ground_now = ground_now or contact.get_meta(&"ball_surface", &"") == &"ground"
		if ground_now and first_ground < 0:
			first_ground = lab._home_run.elapsed
		if not lab._home_run.flight_complete:
			flight_tracking_correct = flight_tracking_correct \
				and lab._camera_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
		early_handoff = early_handoff or (celebration.active and not lab._home_run.flight_complete)
		if first_wide < 0 and lab._home_run.wide_shot:
			first_wide = lab._home_run.elapsed
			var reason: StringName = lab._home_run.flight_end_reason
			valid_flight_end = lab._home_run.flight_complete and (
				(reason == &"timeout" and first_wide >= FLIGHT_LIMIT)
				or (reason in [&"landed", &"rest"] and first_ground >= 0
					and first_wide - first_ground + SAMPLE_SLACK >= LANDING_CONTEXT
					and (ground_now or lab._batted_ball.sleeping)))
		if celebration.active and not valid_handoff:
			valid_handoff = celebration.starts == 1 and celebration.wide_latch_at_start \
				and celebration.reason == "confirmed_home_run" and lab._home_run.flight_complete \
				and lab._batted_ball.freeze and first_wide >= 0 \
				and lab._home_run.elapsed <= first_wide + SAMPLE_SLACK
		if lab._batted_ball.freeze:
			if first_freeze < 0:
				first_freeze = lab._home_run.elapsed
			saw_freeze = true
			early_freeze = early_freeze or not lab._home_run.flight_complete
		if score != Vector2i(lab._match_state.away_team.runs, lab._match_state.home_team.runs):
			score_changed = true
		if celebration.active and celebration.elapsed >= 0.2 and not _transition_shot:
			_transition_shot = true
			transition_progress = camera.origin.distance_to(celebration.start_pose.origin) > 0.05
			transition_pose = _sample(ball, camera, "", "")
			transition_sample.emit()
		if celebration.arrived and wide_completion < 0:
			wide_completion = lab._home_run.elapsed
			var focus: Vector3 = Vector3(0, 1.1, 12)
			wide_context_visible = not lab._camera.is_position_behind(focus) \
				and lab._camera.get_viewport().get_visible_rect().grow(-24).has_point(
					lab._camera.unproject_position(focus)) \
				and lab._camera_director.shot == MatchCameraDirector.Shot.ESTABLISHING
		if lab._home_run.wide_shot:
			return
		post_frames += 1
		moving_post_frames += int(not lab._batted_ball.freeze
			and lab._batted_ball.linear_velocity.length() > 0.1)
		var visibility: StadiumCenterBoardVisibility = lab._camera_director.tracking_visibility \
			as StadiumCenterBoardVisibility
		var raw: Dictionary = visibility.candidate_blocker(camera.origin, ball, 0)
		var padded: Dictionary = visibility.candidate_blocker(camera.origin, ball)
		var blocked: bool = not padded.is_empty()
		raw_blocked_frames += int(not raw.is_empty())
		blocked_frames += int(blocked)
		var screen: Vector2 = lab._camera.unproject_position(ball)
		var outside: bool = lab._camera.is_position_behind(ball) \
			or not lab._camera.get_viewport().get_visible_rect().grow(-24).has_point(screen)
		outside_frames += int(outside)
		if lab._camera_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY:
			tracked_blocked_frames += int(blocked)
			tracked_outside_frames += int(outside)
			blocked_seconds = blocked_seconds + delta if blocked else 0.0
			var marker: HomeRunOcclusionMarker = lab._home_run._occlusion_marker
			var covered: bool = _cue_visible(marker, screen)
			var near_point: Vector3 = lab._camera.project_position(screen, lab._camera.near)
			var terrain: Dictionary = _terrain_witness(lab, near_point, ball)
			_observe_terrain(marker, terrain, delta)
			cue_frames += int(blocked and covered)
			sustained_cue_frames += int(blocked_seconds > 0.25 and covered)
			# Preserve all uncovered telemetry; only an actual terrain hit can classify refusal.
			if blocked_seconds > 0.10 + 0.15 and not covered:
				uncovered_frames += 1
				if not terrain.is_empty():
					terrain_uncovered_frames += 1
					if first_terrain_uncovered.is_empty():
						first_terrain_uncovered = terrain.duplicate(true)
						first_terrain_uncovered["carry_time"] = lab._home_run.elapsed
						first_terrain_uncovered["continuous_seconds"] = terrain_seconds
				if first_uncovered.is_empty():
					first_uncovered = _sample(ball, camera, padded.path, raw.get("path", ""))
					first_uncovered["cue"] = _cue_observation(marker, screen, ball)
		if blocked and first_blocked.is_empty():
			first_blocked = _sample(ball, camera, padded.path, raw.get("path", ""))
		for proxy: Dictionary in visibility._candidate_meshes:
			if proxy.bounds.has_point(proxy.inverse * ball):
				inside_frames += 1
				if first_inside.is_empty():
					first_inside = _sample(ball, camera, proxy.path, raw.get("path", ""))
					witness.emit(first_inside)
				break

	# Independent oracle: enumerate this fixture's current nonground collision RIDs,
	# then ask native physics directly. Never call production terrain/eligibility helpers.
	static func _terrain_witness(root: Node3D, start: Vector3, target: Vector3) -> Dictionary:
		if not is_instance_valid(root) or not start.is_finite() or not target.is_finite():
			return {}
		var bodies: Array[Node] = root.find_children("*", "CollisionObject3D", true, false)
		if bodies.size() > 1024:
			return {}
		var excluded: Array[RID] = []
		for node: Node in bodies:
			if not is_instance_valid(node) or not root.is_ancestor_of(node):
				return {}
			var body: CollisionObject3D = node as CollisionObject3D
			if not body.is_inside_tree() or not body.get_rid().is_valid():
				return {}
			if body.get_meta(&"ball_surface", &"") != &"ground":
				excluded.append(body.get_rid())
		var segments: Array[Vector3] = [target, target + Vector3.UP * 1000.0, start, target]
		for index: int in [0, 2]:
			var ray := PhysicsRayQueryParameters3D.create(segments[index], segments[index + 1], 1)
			ray.exclude = excluded
			ray.hit_from_inside = true
			ray.hit_back_faces = true
			var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():
				continue
			var collider: CollisionObject3D = hit.get("collider") as CollisionObject3D
			if not is_instance_valid(collider) or not root.is_ancestor_of(collider) \
				or not collider.is_inside_tree() or collider.get_rid() != hit.get("rid") \
				or collider.get_meta(&"ball_surface", &"") != &"ground":
				return {}
			return {"collider_path": str(collider.get_path()), "rid": collider.get_rid().get_id(),
				"surface": "ground", "position": _vector(hit.position),
				"from": _vector(segments[index]), "to": _vector(segments[index + 1]),
				"segment": "upward" if index == 0 else "camera_to_body"}
		return {}

	func _observe_terrain(marker: HomeRunOcclusionMarker, proof: Dictionary, delta: float) -> void:
		if proof.is_empty():
			terrain_seconds = 0
			_terrain_previous = false
			return
		terrain_seconds = terrain_seconds + delta if _terrain_previous else 0.0
		_terrain_previous = true
		terrain_fade_failures += int(not _terrain_fade_valid(marker,
			terrain_seconds, _previous_opacity))
		if is_instance_valid(marker):
			_previous_opacity = marker.opacity
			terrain_refusal_frames += int(terrain_seconds > 0.10 + 0.20 + 0.10
				and marker.opacity == 0.0 and not marker.is_visible_in_tree())

	static func _terrain_fade_valid(marker: HomeRunOcclusionMarker, seconds: float,
		previous_opacity: float) -> bool:
		if not is_instance_valid(marker):
			return false
		if seconds > 0.10 + 0.10 and marker.opacity > previous_opacity + 0.000001:
			return false
		return seconds <= 0.10 + 0.20 + 0.10 \
			or (marker.opacity == 0.0 and not marker.is_visible_in_tree())

	func _cue_observation(marker: HomeRunOcclusionMarker, projected: Vector2,
		ball: Vector3) -> Dictionary:
		var ray := PhysicsRayQueryParameters3D.create(ball, ball + Vector3.DOWN * 1000.0, 1)
		ray.exclude = [lab._batted_ball.get_rid()]
		var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(ray)
		return {"exists": is_instance_valid(marker),
			"visible": marker.is_visible_in_tree() if is_instance_valid(marker) else false,
			"opacity": marker.opacity if is_instance_valid(marker) else 0.0,
			"screen_error": marker._point.distance_to(projected) if is_instance_valid(marker) else -1,
			"ground_ray_hit": not hit.is_empty(),
			"ground_surface": String(hit.collider.get_meta(&"ball_surface", &""))
				if not hit.is_empty() and hit.collider is Node else ""}

	static func _cue_visible(marker: HomeRunOcclusionMarker, projected: Vector2) -> bool:
		if not is_instance_valid(marker) or not marker.is_visible_in_tree():
			return false
		return marker.opacity > 0.0 and marker.modulate.a > 0.0 and marker.self_modulate.a > 0.0 \
			and marker._layer != null and marker._layer.visible \
			and marker._layer.transform == Transform2D.IDENTITY \
			and marker._point.distance_to(projected) <= 0.01 \
			and marker.get_viewport_rect().grow(-7.0).has_point(marker._point) \
			and marker.transform == Transform2D.IDENTITY \
			and HomeRunOcclusionMarker.RADIUS_PIXELS == 5.0

	func _sample(ball: Vector3, camera: Transform3D, mesh: String, raw: String) -> Dictionary:
		return {"time": _elapsed, "carry_time": lab._home_run.elapsed,
			"position": _vector(ball), "velocity": _vector(lab._batted_ball.linear_velocity),
			"camera": _vector(camera.origin), "mesh": mesh, "raw_blocker": raw,
			"shot": lab._camera_director.shot, "celebration_active": celebration.active,
			"handoff_elapsed": celebration.elapsed,
			"wide_distance_remaining": camera.origin.distance_to(celebration.target_pose.origin),
			"wide_distance_start": celebration.start_pose.origin.distance_to(
				celebration.target_pose.origin),
			"wide_angle_remaining": camera.basis.get_rotation_quaternion().angle_to(
				celebration.target_pose.basis.get_rotation_quaternion()),
			"wide_angle_start": celebration.start_pose.basis.get_rotation_quaternion().angle_to(
				celebration.target_pose.basis.get_rotation_quaternion()),
			"wide_focus_in_frame": not lab._camera.is_position_behind(Vector3(0, 1.1, 12))
				and lab._camera.get_viewport().get_visible_rect().grow(-24).has_point(
					lab._camera.unproject_position(Vector3(0, 1.1, 12))),
			"home_run_label_visible": lab._status_label.is_visible_in_tree()
				and lab._event_panel.is_visible_in_tree() and "HOME RUN" in lab._status_label.text,
			"render_position": _vector(lab._batted_ball.get_global_transform_interpolated().origin)}

	func report() -> Dictionary:
		return {"results": results, "post_frames": post_frames, "moving_frames": moving_post_frames,
			"process_delta_count": _delta_count,
			"process_delta_min": _delta_min if _delta_count > 0 else 0,
			"process_delta_max": _delta_max,
			"process_delta_mean": _delta_sum / _delta_count if _delta_count > 0 else 0,
			"observed_process_fps": _delta_count / _delta_sum if _delta_sum > 0 else 0,
			"inside_mesh_frames": inside_frames, "raw_blocked_frames": raw_blocked_frames,
			"ball_margin_blocked_frames": blocked_frames, "outside_frames": outside_frames,
			"tracked_blocked_frames": tracked_blocked_frames,
			"tracked_outside_frames": tracked_outside_frames, "armed_at_score": armed_at_score,
			"transition_progress": transition_progress, "transition_pose": transition_pose,
			"wide_completion": wide_completion, "valid_handoff": valid_handoff,
			"early_handoff": early_handoff, "score_notice_visible": score_notice_visible,
			"flight_tracking_correct": flight_tracking_correct, "valid_flight_end": valid_flight_end,
			"first_ground": first_ground, "cue_frames": cue_frames,
			"sustained_cue_frames": sustained_cue_frames, "first_freeze": first_freeze,
			"uncovered_frames": uncovered_frames, "first_uncovered": first_uncovered,
			"terrain_uncovered_frames": terrain_uncovered_frames,
			"terrain_refusal_frames": terrain_refusal_frames,
			"terrain_fade_failures": terrain_fade_failures,
			"first_terrain_uncovered": first_terrain_uncovered,
			"wide_context_visible": wide_context_visible, "hold_end": hold_end,
			"saw_freeze": saw_freeze, "early_freeze": early_freeze,
			"first_inside": first_inside, "first_blocked": first_blocked,
			"first_wide_elapsed": first_wide, "max_speed": max_speed, "max_turn": max_turn,
			"finite": finite, "score_changed": score_changed, "contacts_at_score": contact_count}

	static func _vector(value: Vector3) -> Array[float]:
		return [value.x, value.y, value.z]
