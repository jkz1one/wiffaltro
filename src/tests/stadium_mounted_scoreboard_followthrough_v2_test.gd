extends Node3D
## Explicit v2 successor: earned mounted startup, genuine physics, postflight return.
## Historical celebration tests remain unchanged. No synthetic scored event or timer advance.

const EarnedFixture = preload(
	"res://src/tests/stadium_mounted_scoreboard_followthrough_v2_fixture.gd"
)
const FLIGHT_TEST_SECONDS: float = 16.0
var _failures: int = 0
var _earned: Dictionary = {}
var _flights: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var old_save: String = SeasonSave.path
	var old_settings: String = PitchBatLabSettings.path
	SeasonSave.path = "user://mounted-followthrough-v2-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://mounted-followthrough-v2-%d.cfg" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	var earned: EarnedFixture = EarnedFixture.new()
	print("MOUNTED_V2 stage=earned_fixture_start")
	var reuse: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mounted-v2-reuse-fixture="):
			reuse = argument.trim_prefix("--mounted-v2-reuse-fixture=")
	if reuse.is_empty():
		earned.prepare(app, _check)
	else:
		var working_path: String = SeasonSave.path
		SeasonSave.path = reuse
		var restored: SeasonState = SeasonSave.restore()
		SeasonSave.path = working_path
		_check(restored != null, "explicit retained fixture restores without refunding")
		if restored != null:
			app.season = restored
	earned.validate_prepared(app.season, _check)
	if _failures == 0:
		var checkpoint: String = "user://mounted-followthrough-v2-earned-checkpoint.json"
		var checkpoint_file: FileAccess = FileAccess.open(checkpoint, FileAccess.WRITE)
		_check(checkpoint_file != null, "validated earned checkpoint can be retained")
		if checkpoint_file != null:
			checkpoint_file.store_string(
				JSON.stringify(SeasonSave.snapshot(app.season), "", true, true)
			)
			checkpoint_file.close()
			print(
				"MOUNTED_V2 checkpoint=",
				ProjectSettings.globalize_path(checkpoint),
				" sha256=",
				FileAccess.get_sha256(checkpoint)
			)
	print("MOUNTED_V2 stage=earned_fixture_ready failures=", _failures)
	var scheduled: Dictionary = {}
	for candidate: Dictionary in app.season.schedule:
		if candidate.home == 0:
			scheduled = candidate
			break
	_earned = {
		"ledger": ClubPlayers.assets(app.season.career),
		"fixture": StadiumLayoutSnapshot.for_fixture(app.season, scheduled)
	}
	var before: Dictionary = SeasonSave.snapshot(app.season)
	app.menu.hide()
	if not _earned.fixture.is_empty():
		await _real_flight(false)
		await _real_flight(true)
	_check(
		_flights == 2 and ClubCareer.same(before, SeasonSave.snapshot(app.season)),
		"ordinary and terminal flights preserve earned career and cannot settle or reward it"
	)
	app.queue_free()
	await get_tree().process_frame
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)
	SeasonSave.path = old_save
	PitchBatLabSettings.path = old_settings
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro mounted followthrough v2 passed: earned real flight, postflight return and "
				+ "terminal cleanup."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _new_lab(terminal: bool) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD"
	)
	lab._configured_match.stadium = _earned.fixture.duplicate(true)
	lab._stadium_ledger = _earned.ledger
	lab._automation = MatchAutomation.new()
	lab._automation.seed = int(_earned.fixture.environment.seed)
	lab._managed_match = terminal
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(
		(
			lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
			and not lab._pitch_actor.running
			and StadiumBoundaryRuntime.installed(lab, _earned.fixture)
		),
		"ordinary ready binds earned mounted proof, complete world and native scorer"
	)
	if terminal:
		lab._automation.presentation_enabled = true
		# Fixture precondition only: the real resolver and native scorer must earn the walk-off.
		lab._match_state.inning = MatchState.REGULATION_INNINGS
		lab._match_state.top_half = false
	else:
		lab._automation = null
	return lab


func _real_flight(terminal: bool) -> void:
	print("MOUNTED_V2 stage=flight_start terminal=", terminal)
	var lab: PitchBatLab = _new_lab(terminal)
	if not lab.has_meta("stadium_property"):
		_check(false, "earned mounted startup produced its property")
		lab.free()
		return
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var helper: StadiumMountedScoreboardCelebration = property.celebration
	_check(helper != null and helper._eligible(), "actual mounted helper is eligible")
	if helper == null:
		lab.free()
		return
	_flights += 1
	lab._player_home = terminal
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = (
		PlayerDefinition.Handedness.LEFT if terminal else PlayerDefinition.Handedness.RIGHT
	)
	PitchBatLabPresentation.sync_players(lab)
	lab._apply_role_camera()
	lab._camera_director.snap(lab._camera)
	var record_path: String = (
		"user://mounted-followthrough-v2-record-%d-%s.json" % [OS.get_process_id(), terminal]
	)
	lab._record_export.path = record_path
	await get_tree().physics_frame
	await get_tree().physics_frame
	var probe: FlightProbe = FlightProbe.new()
	probe.lab = lab
	probe.helper = helper
	probe.process_priority = 1000
	probe.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(probe)
	lab._ball_play_resolver.play_resolved.connect(probe.note_score)
	helper.handoff_started.connect(probe.note_handoff)
	lab._active_play_record = PlayRecord.new()
	_check(lab._match_state.begin_pitch(), "real flight starts a genuine pitch")
	lab._at_bat_cadence.mark_pitch_live()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1, 0.28)
	launch.velocity = Vector3(4 if terminal else -4, 18, 30)
	launch.orientation = Quaternion.IDENTITY
	launch.angular_velocity = Vector3.ZERO
	lab._start_ball_in_play(launch)
	var body: BattedBallBody = lab._batted_ball
	probe.body = body
	probe.physical = probe.body_parameters()
	lab.set_process(true)
	lab.set_physics_process(true)
	var paused_once: bool = false
	for frame in range(int(FLIGHT_TEST_SECONDS * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		if not terminal and not paused_once and helper._armed and lab._home_run.elapsed >= 0.1:
			paused_once = true
			await _pause_flight(lab, helper)
		if probe.completed:
			break
	lab.set_process(false)
	lab.set_physics_process(false)
	probe.set_process(false)
	print(
		"MOUNTED_V2 flight=",
		JSON.stringify(
			{
				"terminal": terminal,
				"results": probe.results,
				"armed_at_score": probe.armed_at_score,
				"handoffs": probe.handoffs,
				"starts": helper.starts,
				"postflight_handoff": probe.postflight_handoff,
				"flight_reason": probe.flight_reason,
				"flight_end": probe.flight_end,
				"arrived": probe.arrived,
				"return_reason": probe.return_reason,
				"return_elapsed": probe.return_elapsed,
				"completed": probe.completed,
				"moving_frames": probe.moving_frames,
				"deferred_freeze": probe.saw_deferred_freeze,
				"early_freeze": probe.early_freeze,
				"body_survived_return": probe.body_survived_return,
				"max_speed": probe.max_speed,
				"max_turn": probe.max_turn,
				"records": lab._play_records.size(),
				"contacts": probe.contacts.size(),
				"cleanup_attempted": lab._home_run.cleanup_attempted,
				"cleanup_refused": lab._home_run.cleanup_refused,
				"phase_at_score": probe.phase_at_score
			}
		)
	)
	_check(
		probe.results == [BallPlayOutcome.Result.HOME_RUN] and probe.armed_at_score,
		"native confirmed score arms exactly once without premature handoff"
	)
	_check(
		probe.handoffs == 1 and probe.postflight_handoff and helper.starts == 1,
		"mounted handoff starts exactly once only after physical flight completion"
	)
	_check(
		(
			probe.moving_frames > 0
			and not probe.early_freeze
			and probe.physics_preserved
			and probe.saw_deferred_freeze
		),
		"real body keeps physical followthrough until observed landing or bounded flight timeout"
	)
	_check(
		(
			probe.flight_reason in [&"landed", &"rest", &"timeout"]
			and probe.flight_end > 0
			and probe.flight_end <= PitchBatLabHomeRun.MAX_FLIGHT_SECONDS + 0.15
		),
		"flight ends for an explicit physical condition or bounded timeout"
	)
	_check(
		(
			probe.completed
			and probe.return_reason == &"return_complete"
			and probe.arrived
			and probe.body_survived_return
			and probe.return_elapsed <= PitchBatLabHomeRun.MAX_RETURN_SECONDS + 0.15
		),
		"real mounted camera arrives and retires body within bounded postflight return"
	)
	_check(
		(
			probe.finite
			and probe.max_speed <= BallInPlayCamera.MAX_SPEED + 0.1
			and probe.max_turn <= BallInPlayCamera.MAX_TURN_SPEED + 0.02
		),
		"postflight camera remains finite with bounded translation and turn speed"
	)
	_check(
		(
			probe.score.x + probe.score.y == 1
			and not probe.score_changed
			and lab._play_records.size() == 1
			and not probe.record.is_empty()
			and ClubCareer.same(probe.record, lab._play_records[0].to_dict())
		),
		"presentation preserves one native scored HR and its entire retained physical record"
	)
	_check(
		(
			probe.contacts.size() > 0
			and ClubCareer.same(probe.contacts, lab._ball_play_resolver.state.stadium_contacts)
			and not lab._ball_play_resolver.state.has_grounded
		),
		"post-score collisions and cleanup do not rewrite resolver contact evidence"
	)
	_check(
		(
			lab._batted_ball == null
			and not lab._home_run.active
			and not lab._camera_director._live_coverage.home_run_follow
			and lab._home_run.cleanup_attempted
			and not lab._home_run.cleanup_refused
		),
		"supported cleanup retires captured ball and clears presentation without refusal"
	)
	await get_tree().process_frame
	_check(
		(
			not is_instance_valid(body)
			and not helper.active
			and not helper._armed
			and helper._ball_id == 0
		),
		"queued physical body and mounted lifecycle both retire"
	)
	_check(
		(
			StadiumBoundaryRuntime.installed(lab, _earned.fixture)
			and lab._stadium_ledger == _earned.ledger
		),
		"public installed-world ownership survives followthrough"
	)
	if terminal:
		_check(
			(
				probe.phase_at_score == MatchState.Phase.GAME_END
				and lab._match_state.phase == MatchState.Phase.GAME_END
			),
			"genuine walk-off completes cleanup in GAME_END without requiring a next pitch"
		)
	else:
		_check(paused_once, "ordinary genuine flight exercised pause and resume")
		lab._configured_match = MatchLabSupport.create_match(
			PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD"
		)
		lab._configured_match.stadium = _earned.fixture.duplicate(true)
		lab._start_new_match()
		_check(
			(
				not helper.active
				and not helper._armed
				and helper.reason.is_empty()
				and helper.elapsed == 0
				and helper._match == lab._match_state
				and StadiumBoundaryRuntime.installed(lab, _earned.fixture)
			),
			"ordinary restart clears prior handoff and rebinds exact earned mounted world"
		)
	probe.free()
	lab.free()
	DirAccess.remove_absolute(record_path)
	await get_tree().process_frame


func _pause_flight(lab: PitchBatLab, helper: StadiumMountedScoreboardCelebration) -> void:
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	var clock: float = lab._home_run.elapsed
	var flight_clock: float = lab._home_run.flight_elapsed
	var transition: float = helper.elapsed
	var body_pose: Transform3D = lab._batted_ball.global_transform
	var camera_pose: Transform3D = lab._camera.global_transform
	for frame in range(8):
		await get_tree().physics_frame
	_check(
		(
			lab._home_run.elapsed == clock
			and lab._home_run.flight_elapsed == flight_clock
			and helper.elapsed == transition
			and lab._batted_ball.global_transform == body_pose
			and lab._camera.global_transform == camera_pose
			and StadiumBoundaryRuntime.installed(lab, _earned.fixture)
		),
		"actual pause freezes physics, camera and both lifecycle clocks without losing ownership"
	)
	PitchBatLabFeelSupport.toggle_debug_pause(lab)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error("Mounted followthrough v2: " + message)


class FlightProbe:
	extends Node
	var lab: PitchBatLab
	var helper: StadiumMountedScoreboardCelebration
	var body: BattedBallBody
	var physical: Array = []
	var results: Array[int] = []
	var score: Vector2i
	var record: Dictionary = {}
	var contacts: Array = []
	var phase_at_score: int = -1
	var armed_at_score: bool = false
	var handoffs: int = 0
	var postflight_handoff: bool = false
	var score_changed: bool = false
	var physics_preserved: bool = true
	var body_survived_return: bool = true
	var early_freeze: bool = false
	var saw_deferred_freeze: bool = false
	var moving_frames: int = 0
	var flight_reason: StringName = &""
	var return_reason: StringName = &""
	var flight_end: float = -1
	var return_elapsed: float = -1
	var completed: bool = false
	var arrived: bool = false
	var finite: bool = true
	var max_speed: float = 0
	var max_turn: float = 0
	var _previous: Transform3D
	var _has_previous: bool = false

	func body_parameters() -> Array:
		return [
			body.radius_m, body.mass, body.gravity_scale, body.collision_layer, body.collision_mask
		]

	func note_score(outcome: BallPlayOutcome) -> void:
		results.append(outcome.result)
		score = Vector2i(lab._match_state.away_team.runs, lab._match_state.home_team.runs)
		phase_at_score = lab._match_state.phase
		contacts = lab._ball_play_resolver.state.stadium_contacts.duplicate(true)
		if lab._play_records.size() == 1:
			record = lab._play_records[0].to_dict().duplicate(true)
		armed_at_score = (
			helper._armed
			and not helper.active
			and helper.starts == 0
			and lab._home_run.active
			and not lab._home_run.flight_complete
			and not body.freeze
		)

	func note_handoff() -> void:
		handoffs += 1
		postflight_handoff = (
			lab._home_run.flight_complete
			and lab._home_run.wide_shot
			and helper.wide_latch_at_start
			and body.sleeping
			and body.linear_velocity == Vector3.ZERO
			and body.angular_velocity == Vector3.ZERO
		)
		_previous = lab._camera.global_transform
		_has_previous = true

	func _process(delta: float) -> void:
		if results.is_empty() or completed:
			return
		score_changed = (
			score_changed
			or score != Vector2i(lab._match_state.away_team.runs, lab._match_state.home_team.runs)
		)
		arrived = arrived or helper.arrived
		if lab._home_run.flight_complete and flight_end < 0:
			flight_end = lab._home_run.flight_elapsed
			flight_reason = lab._home_run.flight_end_reason
		if not lab._home_run.active:
			completed = true
			return_elapsed = lab._home_run.presentation_tail_elapsed
			return_reason = lab._home_run.return_end_reason
			return
		if helper.active and not helper.arrived:
			body_survived_return = (
				body_survived_return
				and is_instance_valid(body)
				and lab._batted_ball == body
				and not body.is_queued_for_deletion()
			)
		var pose: Transform3D = lab._camera.global_transform
		finite = finite and pose.is_finite()
		if helper.active and _has_previous and delta > 0:
			max_speed = maxf(max_speed, pose.origin.distance_to(_previous.origin) / delta)
			max_turn = maxf(
				max_turn,
				(
					pose.basis.get_rotation_quaternion().angle_to(
						_previous.basis.get_rotation_quaternion()
					)
					/ delta
				)
			)
		_previous = pose
		if is_instance_valid(body):
			finite = finite and body.global_position.is_finite()
			physics_preserved = physics_preserved and body_parameters() == physical
			saw_deferred_freeze = (
				saw_deferred_freeze or (body.freeze and lab._home_run.flight_complete)
			)
			early_freeze = early_freeze or (body.freeze and not lab._home_run.flight_complete)
			if not body.freeze and body.linear_velocity.length() > 0:
				moving_frames += 1
