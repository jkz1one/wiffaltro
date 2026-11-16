extends Node3D
## One genuine SeasonApp neutral admission, ordinary pitch/contact/defense, then next release.
## Reuses the accepted private rendered witness without changing its pitch/swing input recipe.
## Test-only inputs and passive witnesses. Native execution remains root-owned.
# gdlint: disable=max-line-length,max-file-lines,max-returns

signal physics_observed

const F = preload("res://src/tests/hillside_public_fixture.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
const Freeze = preload("res://src/tests/stadium_long_yard_capture_freeze.gd")
const TARGET: Vector2 = Vector2(-0.75, 1.85)
const AIM_DELTA: Vector2 = Vector2(0.15136215502694095, -0.10606738638321112)
const PROFILE: StringName = &"swing.power"
const MAX_TICKS: int = 1800
const EXPECTED_CHECKS: int = 31
# Retained working terrain ray allowance; active positions use exact committed endpoints.
const WORKING_SUPPORT_RAY_ERROR_M: float = 0.0002
var _app: SeasonApp
var _season: SeasonState
var _match: MatchState
var _before_season: Dictionary = {}
var _admission: Dictionary = {}
var _participants: Dictionary = {}
var _saved_path: String = ""
var _settings_path: String = ""
var _paths_isolated: bool = false
var _lab: PitchBatLab
var _owner: StadiumNpcPublicProperty
var _native: Node
var _capture_dir: String = ""
var _output: String = ""
var _output_admitted: bool = false
var _checks: int = 0
var _failed: Array[String] = []
var _tick: int = 0
var _capturing: bool = false
var _captures: Array[Dictionary] = []
var _release: Dictionary = {}
var _requested: Dictionary = {}
var _launch: Dictionary = {}
var _terminal: Dictionary = {}
var _next: Dictionary = {}
var _trace: Array[Dictionary] = []
var _body: BattedBallBody
var _state: BallPlayState
var _swing_sent: bool = false
var _launches: int = 0
var _start_time: float = -1.0
var _aim: Vector2 = Vector2.ZERO
var _primary_start: Vector3
var _pitcher_start: Vector3
var _uphill: bool = false
var _supported: bool = true
var _identity_intact: bool = true
var _saw_ground: bool = false
var _max_primary_y: float = -INF
var _max_pitcher_y: float = -INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1000000
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
		elif argument.begins_with("--hillside-public-play-output="):
			_output = argument.trim_prefix("--hillside-public-play-output=")
		else:
			_check(false, "only exact output and capture-directory selectors are accepted")
	_run.call_deferred()


func _run() -> void:
	_output_admitted = _admit_output()
	_check(_output_admitted and _capture_dir.is_absolute_path()
		and _capture_dir.simplify_path() == _capture_dir and DirAccess.dir_exists_absolute(_capture_dir),
		"root-owned existing capture directory and fresh canonical absolute JSON output")
	_check(DisplayServer.get_name() != "headless" and Engine.physics_ticks_per_second == 60,
		"one real displayed 60 Hz ordinary run is required")
	if not _failed.is_empty():
		_finish()
		return
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0 and await _native.resize(Vector2i(1280, 800)),
		"native startup and one 1280 by 800 window handshake")
	_saved_path = SeasonSave.path
	_settings_path = PitchBatLabSettings.path
	SeasonSave.path = "user://hillside-public-play-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://hillside-public-play-%d.cfg" % OS.get_process_id()
	_paths_isolated = true
	_check(not FileAccess.file_exists(SeasonSave.path)
		and not FileAccess.file_exists(SeasonSave.path + ".bak")
		and not FileAccess.file_exists(PitchBatLabSettings.path) and R.source_qualified() and F.ready(),
		"isolated absent save/settings inputs and exact explicit public-final source")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	_season = F.season()
	if _season != null:
		F.fixture(_season, false)
		_season.phase = SeasonState.Phase.FINAL
		_match = _season.make_match()
	if not _check(_season != null and _match != null
		and _match.stadium.get("version") == StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
		and StadiumNpcSnapshot.matches_fixture(_match.stadium, _season, _season.pending_fixture()),
		"real draft and existing explicit neutral fixture supply the ordinary public match"):
		await _dispose()
		_finish()
		return
	_before_season = _season_data()
	_app = SeasonApp.new()
	add_child(_app)
	_app.season = _season
	_app._fixture_id = 32
	_app.notice = ""
	_app._open_match(_match, false, true, &"field.npc_venue")
	_lab = _app.lab
	_owner = R._property(_lab) if is_instance_valid(_lab) else null
	var pending: bool = is_instance_valid(_owner) and R.pending_hillside(_lab)
	for _frame in range(180):
		await physics_observed
		if not is_instance_valid(_lab) or _app.lab != _lab:
			break
		if is_instance_valid(_owner) and _owner.issued and _lab.hillside_public_pending == null:
			break
	if not _check(pending and is_instance_valid(_lab) and is_instance_valid(_owner)
		and _app.lab == _lab and _app.notice.is_empty() and _public_identity()
		and R.installed_bound(_lab, _match.stadium),
		"actual SeasonApp pending entry issues the same captured public property"):
		await _dispose()
		_finish()
		return
	_check(_lab.get_script() == PitchBatLab and _lab.is_processing() and _lab.is_physics_processing()
		and _lab._automation == null and _lab._managed_match and _lab._configured_match == null
		and _lab._npc_season == _season and not _lab._player_home and _lab._field_id == &"field.npc_venue"
		and _lab.hillside_private_runtime == null and _lab._hillside_private_owner_identity == null
		and not _lab.has_node("HillsidePrivateRuntime"),
		"normal processing retains actual managed neutral context and no private authority")
	var batter: PlayerMatchState = _match.batter()
	var pitcher: PlayerMatchState = _match.pitcher()
	var fielder: PlayerMatchState = _match.fielder()
	_participants = {"season_seed": _season.season_seed, "picks": _season.picks.duplicate(),
		"batter_id": String(batter.definition.id), "batter_left": batter.bats_left(),
		"batter_contact": batter.definition.contact, "batter_power": batter.definition.power,
		"pitcher_id": String(pitcher.definition.id), "pitcher_control": pitcher.definition.control,
		"fielder_id": String(fielder.definition.id), "fielder_fielding": fielder.definition.fielding,
		"pitch_id": String(pitcher.definition.starting_pitches[0].id)}
	_check(String(batter.definition.id) == _season.teams[0].roster[0]
		and String(pitcher.definition.id) == _season.opponents.clubs["1"].roles.pitcher
		and String(fielder.definition.id) == _season.opponents.clubs["1"].roles.fielder
		and _lab._fielder_anchor_index == 7 and _lab._throw_number == 0,
		"unchanged actual drafted roster, eligible first pitch and deep-center anchor seven")
	_check(_owner.objects.size() == 8 and _owner.display == null and _owner.score_display_intact()
		and _owner.route_obstacles().is_empty() and _owner.receiver.get_script() == StadiumHillsidePublicReceiver
		and _owner.hillside_support.primary_motion != _owner.hillside_support.pitcher_motion
		and _owner.boundary.get_script() == StadiumHillsidePublicContactAdapter
		and _owner.boundary.contact_applied.get_connections().size() == 1
		and _owner.boundary.contact_applied.is_connected(_owner._club_contact),
		"one public property retains eight copies, independent terrain support and sole contact authority")
	_admission = {"pending_observed": pending, "owner_id": _owner.get_instance_id(),
		"support_id": _owner.hillside_support.get_instance_id(),
		"ground_id": _owner.hillside_support.ground.get_instance_id(),
		"adapter_id": _owner.boundary.get_instance_id(), "terrain_id": _owner.construction.terrain.get_instance_id(),
		"app_id": _app.get_instance_id(), "lab_id": _lab.get_instance_id(), "match_id": _match.get_instance_id(),
		"fixture": _season.pending_fixture().duplicate(true), "snapshot": _match.stadium.duplicate(true),
		"venue_owner": _match.stadium.binding.venue_owner, "ordinary_callbacks": _owner.ordinary_callbacks(),
		"environment_profile": _match.stadium.environment.profile, "completed_games": 0}
	_lab.child_entered_tree.connect(_child_entered)
	_lab._pitch_actor.segment_advanced.connect(_pitch_segment)
	# Existing ordinary intro-skip and ready actions; no role, roster or camera override.
	PitchBatLabFeelSupport.skip_match_presentation(_lab)
	_lab._selected_pitch_index = 0
	_lab._pitch_target = TARGET
	_lab._pitch_effort = 1.0
	_lab._ai_pitch_preselected = true
	_primary_start = _lab._primary_fielder.global_position
	_pitcher_start = _lab._pitcher_marker.global_position
	_check(_lab._player_is_batting() and _lab._awaiting_batter_confirm
		and _lab._match_state.phase == MatchState.Phase.PRE_PITCH,
		"normal batting ready state is available before ordinary confirmation")
	_lab._handle_match_advance()
	_check(_lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY,
		"normal ready action starts unmodified ordinary delivery cadence")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	var first_capture_tick: int = -1
	for _frame in range(MAX_TICKS):
		await physics_observed
		_observe()
		if not _failed.is_empty():
			break
		if not _launch.is_empty() and not _state.dead:
			if first_capture_tick < 0 and _uphill and _body.global_position.z >= 17.0:
				first_capture_tick = _tick
				await _shot("hillside-ordinary-uphill-a")
			elif first_capture_tick >= 0 and _tick == first_capture_tick + 3:
				await _shot("hillside-ordinary-uphill-b")
		if _lab._play_records.size() == 1:
			_terminal = _lab._play_records[0].to_dict()
			break
	_check(not _terminal.is_empty() and _launches == 1 and _swing_sent
		and _launch.get("ordinary_start", false) and _launch.get("postlaunch_aero", false),
		"one authentic pitch and swing reaches ordinary launch and terminal PlayRecord")
	_check(_state != null and _state.is_fair and not _state.is_foul_play
		and _terminal.get("swing_profile_id", "") == String(PROFILE)
		and _terminal.get("contact_outcome", -1) >= 1
		and _terminal.get("last_defender_touch", "") == "primary_fielder"
		and _state.defender_touched,
		"real fair contact, requested swing and automatic primary control reach the terminal record")
	_check(_uphill and _supported and _identity_intact and _max_primary_y > _primary_start.y,
		"original automatic primary moves uphill on exact committed supported terrain poses")
	_check(_captures.size() == 2 and _captures[1].tick - _captures[0].tick == 3
		and not _captures[0].state.dead and not _captures[1].state.dead,
		"two normal live views are exactly three unpaused ordinary physics ticks apart")
	if _failed.is_empty():
		await _next_pitch()
	_check(_captures.size() == 3 and not _next.is_empty(),
		"exactly three native views and actual normal next-release evidence")
	await _dispose()
	_finish()


func _pitch_segment(_previous: Vector3, _previous_time: float) -> void:
	if _lab._throw_number != 1 or _lab._pitch_actor.state == null:
		return
	if _release.is_empty():
		var parameters: PitchLaunchParameters = _lab._pitch_actor.parameters
		_check(String(parameters.pitch_id) == _participants.pitch_id and parameters.seed == 1009,
			"first actual release retains its real eligible repertoire slot and ordinary seed")
		var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
			parameters, ContactResolver.CONTACT_PLANE_Z)
		var profile: SwingProfileDefinition = SeasonSponsorEffects.swing(ContentDB.get_swing(PROFILE), _lab._match_state)
		_start_time = crossing.elapsed_seconds - profile.sweet_spot_seconds
		_aim = Vector2(crossing.point.x, crossing.point.y) + AIM_DELTA
		_check(crossing.crossed and _start_time >= 0 and SwingIntent.reachable_aim(_aim) == _aim,
			"actual released-parameter prediction supplies reachable ordinary swing input")
		_release = {"position": _v(parameters.position), "velocity": _v(parameters.velocity),
			"angular_velocity": _v(parameters.angular_velocity), "orientation": _q(parameters.orientation),
			"pitch_id": String(parameters.pitch_id), "seed": parameters.seed,
			"batter_id": String(_lab._match_state.batter().definition.id),
			"pitcher_id": String(_lab._match_state.pitcher().definition.id),
			"parameters_id": parameters.get_instance_id(), "pitch_state_id": _lab._pitch_actor.state.get_instance_id()}
		_requested = {"target": [TARGET.x, TARGET.y], "pitch_index": 0, "effort": 1.0,
			"profile": String(PROFILE), "aim_delta": [AIM_DELTA.x, AIM_DELTA.y], "offset": 0.0,
			"aim": [_aim.x, _aim.y], "start_time": _start_time,
			"crossing": _v(crossing.point), "crossing_time": crossing.elapsed_seconds}
	if _swing_sent or not _failed.is_empty() or _lab._pitch_actor.state.elapsed_time < _start_time:
		return
	_swing_sent = true
	_lab._resolve_swing(PROFILE, _aim)
	_check(_lab._swing_tracker.active and _lab._swing_tracker.intent != null
		and _lab._swing_tracker.intent.handedness_left == _match.batter().bats_left(),
		"ordinary begin-swing owns the actual drafted batter handedness")
	if _lab._swing_tracker.intent != null:
		_requested.actual_start_time = _lab._swing_tracker.intent.start_time_seconds
		_requested.intent_id = _lab._swing_tracker.intent.get_instance_id()


func _child_entered(child: Node) -> void:
	if child is BattedBallBody:
		child.launch_started.connect(_launched.bind(child))


func _launched(point: Vector3, ball: BattedBallBody) -> void:
	_launches += 1
	_body = ball
	_state = _lab._ball_play_resolver.state
	var contact: ContactResult = _lab._swing_tracker.result
	var ordinary: bool = contact != null and contact.outcome != ContactResult.Outcome.MISS \
		and ball == _lab._batted_ball and ball.get_parent() == _lab and ball.get_script() == BattedBallBody \
		and _lab._pitch_actor.state == null and not _lab._pitch_actor.running \
		and _state != null and _lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY \
		and _lab._active_play_record != null and not _lab._swing_tracker.active \
		and _lab._swing_consumed and _lab._active_play_record.contact_outcome == contact.outcome \
		and ball._started and point == contact.contact_position and ball.linear_velocity == contact.exit_velocity
	_launch = {"ordinary_start": ordinary, "postlaunch_aero": false,
		"engine_frame": Engine.get_physics_frames(), "position": _v(point),
		"velocity": _v(ball.linear_velocity), "angular_velocity": _v(ball.angular_velocity),
		"body_id": ball.get_instance_id(), "state_id": _state.get_instance_id(),
		"resolver_id": _lab._ball_play_resolver.get_instance_id(), "owner_id": _owner.get_instance_id()}
	if contact != null:
		_launch.contact = {"id": contact.get_instance_id(), "outcome": contact.outcome,
			"quality": contact.quality, "spray": contact.spray_degrees, "angle": contact.launch_angle_degrees,
			"horizontal_error": contact.horizontal_error_m, "vertical_error": contact.vertical_error_m,
			"timing_error": contact.timing_error_m, "backspin": contact.backspin_rad_s}


func _physics_process(_delta: float) -> void:
	if _capturing or get_tree().paused:
		return
	_tick += 1
	physics_observed.emit()


func _observe() -> void:
	if _state == null or not is_instance_valid(_body):
		return
	# First late observer runs after _start_ball_in_play returns. The launch signal is too early.
	if not _launch.postlaunch_aero:
		var setup: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
		_launch.postlaunch_aero = _body.ball_mass_kg == setup.aero_profile.mass_kg \
			and _body.mass == PackedFloat32Array([setup.aero_profile.mass_kg])[0] \
			and _body.radius_m == setup.aero_profile.radius_m \
			and _body.aero_drag_coefficient == setup.aero_profile.drag_coefficient * setup.drag_multiplier \
			and _body.aero_magnus_scale == setup.aero_profile.magnus_scale * setup.magnus_multiplier \
			and _body.aero_perforation_force_scale == setup.aero_profile.perforation_force_scale * setup.perforation_multiplier \
			and _body.linear_damp == 0.0 and _body.angular_damp == 0.0 and _body.continuous_cd
		_check(_launch.postlaunch_aero and _lab._primary_fielder.active,
			"late ordinary observer witnesses configured aero and actual begin-play after launch returns")
	if not _state.dead:
		_identity_intact = _identity_intact and _lab._batted_ball == _body \
			and _lab._ball_play_resolver.state == _state and _public_identity() \
			and _owner.boundary.binding_intact(_body, _lab._ball_play_resolver, _state) \
			and _owner.hillside_support.ground.public_binding_intact(_body, _state) \
			and _body.physics_contact_router == _owner._boundary_contact_batch.bind(_lab._ball_play_resolver)
	var primary: Vector3 = _lab._primary_fielder.global_position
	var pitcher: Vector3 = _lab._pitcher_marker.global_position
	_max_primary_y = maxf(_max_primary_y, primary.y)
	_max_pitcher_y = maxf(_max_pitcher_y, pitcher.y)
	_uphill = _uphill or (primary.y > _primary_start.y and primary.z > _primary_start.z)
	if not _state.dead:
		_supported = _supported and _support(primary, _lab._primary_fielder.hillside_motion) \
			and _support(pitcher, _lab.hillside_pitcher_motion)
	_saw_ground = _saw_ground or _state.has_grounded
	if _trace.size() < 600:
		_trace.append(_live_row())
	else:
		_check(false, "one live-play passive trace exceeded its bounded 600-row inventory")


func _support(at: Vector3, motion: StadiumHillsideDefenderMotion) -> bool:
	if motion == null or motion.blocked or not motion._has_valid_position:
		return false
	var expected: Vector3 = StadiumHillsideTerrain.point(at.x, at.z)
	var committed: Vector3 = motion.last_path.get("position", motion._last_valid_position) \
		if _lab._primary_fielder.active else expected
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		expected + Vector3.UP * 3.0, expected - Vector3.UP * 3.0, StadiumHillsideTerrainModels.QUERY_LAYER)
	var hit: Dictionary = _lab.get_world_3d().direct_space_state.intersect_ray(query)
	return at == committed and at == motion._last_valid_position \
		and motion._physical_support(_lab._primary_fielder, at) and not hit.is_empty() \
		and hit.collider == _owner.construction.terrain.get_node("TerrainCollision") \
		and (hit.position as Vector3).distance_to(expected) <= WORKING_SUPPORT_RAY_ERROR_M


func _live_row() -> Dictionary:
	var batter: PlayerMatchState = _lab._match_state.batter()
	var pitcher: PlayerMatchState = _lab._match_state.pitcher()
	# Read-only expected text mirrors MatchScorebug.update_match; no refresh is forced.
	var expected_batter: String = "BAT %s  %s" % ["L" if batter.bats_left() else "R", batter.definition.display_name]
	var expected_pitcher: String = "PIT  %s" % pitcher.definition.display_name
	if not _lab._player_is_pitching():
		expected_pitcher = "PIT  %s   P:%d   STA %.0f%%" % [pitcher.definition.display_name,
			pitcher.pitch_count, pitcher.stamina_percent() * 100.0]
	var row: Dictionary = {"tick": _tick, "engine_frame": Engine.get_physics_frames(),
		"primary": _v(_lab._primary_fielder.global_position), "pitcher": _v(_lab._pitcher_marker.global_position),
		"primary_plans": _lab._primary_fielder.hillside_motion.tracking_plan_count,
		"pitcher_plans": _lab.hillside_pitcher_motion.tracking_plan_count,
		"camera": _v(_lab._camera.global_position), "camera_shot": _lab._camera_director.shot,
		"phase": _lab._match_state.phase, "throw_number": _lab._throw_number,
		"records": _lab._play_records.size(), "hud_visible": _lab._scorebug.visible,
		"batter_text": _lab._scorebug._batter.text, "pitcher_text": _lab._scorebug._pitcher.text,
		"batter_id": String(batter.definition.id), "pitcher_id": String(pitcher.definition.id),
		"batter_name": batter.definition.display_name, "pitcher_name": pitcher.definition.display_name,
		"batter_left": batter.bats_left(), "pitcher_pitch_count": pitcher.pitch_count,
		"pitcher_stamina_percent": pitcher.stamina_percent(),
		"role": "pitching" if _lab._player_is_pitching() else "batting",
		"expected_batter_text": expected_batter, "expected_pitcher_text": expected_pitcher,
		"hud_matches": _lab._scorebug.visible and _lab._scorebug._batter.text == expected_batter
			and _lab._scorebug._pitcher.text == expected_pitcher}
	if _state != null:
		row.state = {"id": _state.get_instance_id(), "elapsed": _state.elapsed_seconds,
			"dead": _state.dead, "fair": _state.is_fair, "grounded": _state.has_grounded,
			"caught": _state.caught, "last_touch": String(_state.last_defender_touch),
			"catch_position": _v(_state.catch_position), "first_ground": _v(_state.first_ground_position),
			"defender_touched": _state.defender_touched, "stadium_contacts": _state.stadium_contacts.duplicate(true)}
	if is_instance_valid(_body) and _lab._batted_ball == _body:
		row.ball = {"id": _body.get_instance_id(), "position": _v(_body.global_position),
			"velocity": _v(_body.linear_velocity), "frozen": _body.freeze}
	row.public_owner = {"id": _owner.get_instance_id(), "issued": _owner.issued,
		"suspended": _owner.suspended, "identity_intact": _public_identity(),
		"ordinary_callbacks": _owner.ordinary_callbacks(),
		"adapter_id": _owner.boundary.get_instance_id(),
		"ground_id": _owner.hillside_support.ground.get_instance_id(),
		"contact_listener_count": _owner.boundary.contact_applied.get_connections().size(),
		"bound_ball_count": _owner.bound_balls.size()}
	return row


func _next_pitch() -> void:
	for _frame in range(600):
		await physics_observed
		if _lab._match_state.phase == MatchState.Phase.PRE_PITCH and _lab._batted_ball == null:
			break
	_check(_lab._match_state.phase == MatchState.Phase.PRE_PITCH and _lab._batted_ball == null
		and _owner.bound_balls.is_empty() and _owner.boundary._bindings.is_empty()
		and _owner.hillside_support.ground._ball == null and not _lab._primary_fielder.active
		and _public_identity() and _lab._awaiting_batter_confirm and _lab._play_records.size() == 1
		and _lab._play_records[0].to_dict() == _terminal,
		"ordinary dead-ball cadence cleans the original ball and preserves its sole terminal record")
	_check(_lab._primary_fielder.hillside_motion.tracking_plan_count == 0
		and _lab.hillside_pitcher_motion.tracking_plan_count == 0
		and _support(_lab._primary_fielder.global_position, _lab._primary_fielder.hillside_motion)
		and _support(_lab._pitcher_marker.global_position, _lab.hillside_pitcher_motion),
		"ordinary next-pitch reset clears both cadence states and restores supported actors")
	if not _failed.is_empty():
		return
	# Let the original role-camera transition proceed normally before the ready image.
	for _frame in range(30):
		await physics_observed
	await _shot("hillside-ordinary-next-ready")
	var ready: Dictionary = _live_row()
	_lab._handle_match_advance()
	for _frame in range(600):
		await physics_observed
		if _lab._throw_number == 2:
			break
	_check(_lab._throw_number == 2 and _lab._pitch_actor.running and _lab._pitch_actor.parameters != null
		and _lab._pitch_actor.state != null and _lab._batted_ball == null
		and _lab._play_records.size() == 1 and _launches == 1
		and _public_identity() and _lab.is_processing() and _lab.is_physics_processing(),
		"normal next ready action and delivery produce the second real release with no second swing")
	_next = {"ready": ready, "release": _live_row(),
		"pitch_id": String(_lab._pitch_actor.parameters.pitch_id),
		"parameters_id": _lab._pitch_actor.parameters.get_instance_id(),
		"state_id": _lab._pitch_actor.state.get_instance_id(), "seed": _lab._pitch_actor.parameters.seed}


func _shot(label: String) -> void:
	_capturing = true
	var physical_before: bool = _physics_membership()
	var state: Dictionary = _lock_capture()
	var before: PackedByteArray = _capture_snapshot()
	var rendered_before: Dictionary = Freeze.snapshot(_lab, _lab._batted_ball)
	var sampled: Dictionary = _live_row()
	var captured: bool = await _native.capture(_capture_dir, label)
	var rendered_after: Dictionary = Freeze.snapshot(_lab, _lab._batted_ball)
	var flags_paused: bool = true
	for row: Dictionary in state.nodes:
		flags_paused = flags_paused and Freeze._flags(row.node) == [false, false, false, false, false, false, false, false]
	var proof: Dictionary = {"membership_before": physical_before,
		"membership_after": _physics_membership(), "state_equal": _capture_snapshot() == before,
		"render_equal": rendered_before.bytes == rendered_after.bytes,
		"render_supported": rendered_before.unsupported.is_empty() and rendered_after.unsupported.is_empty(),
		"modes_intact": Freeze._modes_intact(state), "flags_paused": flags_paused,
		"tree_paused": get_tree().paused, "tweens_intact": Freeze._tweens_intact(_lab, state, true)}
	proof.restored = _unlock_capture(state)
	_capturing = false
	var intact: bool = proof.values().all(func(value: bool) -> bool: return value)
	var expected_shot: int = MatchCameraDirector.Shot.BALL_IN_PLAY if _captures.size() < 2 else MatchCameraDirector.Shot.BATTING
	_check(captured and intact and sampled.hud_matches and sampled.role == "batting"
		and sampled.camera_shot == expected_shot,
		"native capture preserves paused state and ordinary current-player HUD/camera, then resumes exact flags")
	if captured:
		var extent: Vector2i = _native._expected_content_size(get_window().size)
		var filename: String = "%s-%dx%d.png" % [label, extent.x, extent.y]
		var path: String = _capture_dir.path_join(filename)
		var image: Image = Image.load_from_file(path)
		_check(image != null and image.get_size() == extent and extent == Vector2i(1280, 720),
			"saved native PNG has the single exact 1280 by 720 content extent")
		sampled.label = label
		sampled.file = filename
		sampled.proof = proof
		sampled.png_bytes = FileAccess.get_file_as_bytes(path).size()
		sampled.png_sha256 = FileAccess.get_sha256(path)
		_captures.append(sampled)


func _lock_capture() -> Dictionary:
	var state: Dictionary = {"paused": get_tree().paused, "nodes": [], "ancestors": [],
		"tweens": [], "tween_breach": false}
	var ancestor: Node = _lab.get_parent()
	while ancestor != null:
		state.ancestors.append({"node": ancestor, "mode": ancestor.process_mode})
		ancestor = ancestor.get_parent()
	for node: Node in Freeze._nodes(_lab):
		state.nodes.append({"node": node, "mode": node.process_mode,
			"disable": node.disable_mode if node is CollisionObject3D else -1, "flags": Freeze._flags(node)})
		Freeze._set_flags(node, [false, false, false, false, false, false, false, false])
	for tween: Tween in get_tree().get_processed_tweens():
		state.tweens.append({"tween": tween, "id": tween.get_instance_id(), "valid": tween.is_valid(),
			"running": tween.is_running(), "elapsed": tween.get_total_elapsed_time()})
		if tween.is_valid():
			tween.pause()
	get_tree().paused = true
	return state


func _unlock_capture(state: Dictionary) -> bool:
	var restored: bool = Freeze._modes_intact(state) and Freeze._tweens_intact(_lab, state, true)
	for row: Dictionary in state.nodes:
		Freeze._set_flags(row.node, row.flags)
		restored = restored and Freeze._flags(row.node) == row.flags
	get_tree().paused = state.paused
	for row: Dictionary in state.tweens:
		if row.valid and row.running:
			row.tween.play()
	return restored and Freeze._tweens_intact(_lab, state, false) and _physics_membership()


func _capture_snapshot() -> PackedByteArray:
	var rows: Array = [_tick, _live_row(), _lab._at_bat_cadence.state,
		_lab._at_bat_cadence.elapsed_seconds, _lab._camera.global_transform, _lab._camera.fov]
	# Engine wall-frame counters can advance while SceneTree is paused; exclude only that counter.
	rows[1].erase("engine_frame")
	return var_to_bytes(rows)


func _physics_membership() -> bool:
	var space: RID = _lab.get_world_3d().space
	for node: Node in Freeze._nodes(_lab):
		if node is PhysicsBody3D and PhysicsServer3D.body_get_space(node.get_rid()) != space:
			return false
	var at: Vector3 = _lab._primary_fielder.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 3.0, at - Vector3.UP * 3.0, StadiumHillsideTerrainModels.QUERY_LAYER)
	var hit: Dictionary = _lab.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _owner.construction.terrain.get_node("TerrainCollision") \
		and _support(at, _lab._primary_fielder.hillside_motion) \
		and _support(_lab._pitcher_marker.global_position, _lab.hillside_pitcher_motion)


func _admit_output() -> bool:
	return not _output.is_empty() and _output.is_absolute_path() and _output.simplify_path() == _output \
		and _output.ends_with(".json") and not FileAccess.file_exists(_output) \
		and DirAccess.dir_exists_absolute(_output.get_base_dir())


func _public_identity() -> bool:
	# Read-only captured identities. No contact, resolve, bind, refresh or admission call.
	return is_instance_valid(_app) and is_instance_valid(_lab) and is_instance_valid(_owner) \
		and _app.lab == _lab and _app.season == _season and _lab._match_state == _match \
		and R._property(_lab) == _owner and _owner.get_script() == StadiumNpcPublicProperty \
		and _owner.issued and not _owner.suspended and _owner.venue_id == "HILLSIDE" \
		and _owner.bound_state == _match and _owner.public_season == _season \
		and _owner.public_snapshot == _match.stadium and _owner.public_fixture == _season.pending_fixture() \
		and _owner.lab_ref != null and _owner.lab_ref.get_ref() == _lab \
		and _owner.ordinary_callbacks() and _owner._boundary_intact(false) \
		and _owner.routing_intact() and _owner.hillside_support.bound_intact() \
		and _owner.boundary.dynamic_intact() and _lab.hillside_private_runtime == null \
		and _lab._hillside_private_owner_identity == null


func _season_data() -> Dictionary:
	if _season == null:
		return {}
	return {"final_venue": _season.final_venue.duplicate(true),
		"npc_venues": _season.npc_venues.duplicate(true), "home_property": _season.home_property.duplicate(true),
		"fixture": _season.final_fixture.duplicate(true), "phase": _season.phase,
		"results": _season.results.duplicate(true), "player_results": _season.player_results.duplicate(true),
		"physical": _season.physical.to_data(), "career": _season.career.to_data(),
		"build": _season.build.to_data(), "opponents": _season.opponents.to_data()}


func _dispose() -> void:
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
		await get_tree().process_frame
	if _paths_isolated:
		_check(not FileAccess.file_exists(SeasonSave.path)
			and not FileAccess.file_exists(SeasonSave.path + ".bak")
			and (_before_season.is_empty() or ClubCareer.same(_before_season, _season_data())),
			"bounded explicit play never persists or settles a season result, award or assignment")
		SeasonSave.path = _saved_path
		PitchBatLabSettings.path = _settings_path
		_paths_isolated = false
	await TestAudioDrain.finish(get_tree())

func _finish() -> void:
	_check(_checks + 1 == EXPECTED_CHECKS, "exact single-play native assertion inventory")
	var result: Dictionary = {"kind": "one-ordinary-public-rendered-hillside-play", "checks": _checks,
		"failures": _failed, "requested": _requested, "release": _release, "launch": _launch,
		"trace": _trace, "terminal": _terminal, "next_pitch": _next, "captures": _captures,
		"uphill": _uphill, "supported": _supported, "identity_intact": _identity_intact,
		"saw_ground": _saw_ground, "max_primary_y": _max_primary_y if is_finite(_max_primary_y) else null,
		"max_pitcher_y": _max_pitcher_y if is_finite(_max_pitcher_y) else null,
		"primary_start": _v(_primary_start), "pitcher_start": _v(_pitcher_start),
		"public_admission": _admission, "participants": _participants,
		"public_selection": "HELD", "earned_final_assignment": "HELD", "performance_claim": "NONE"}
	if _output_admitted:
		var file: FileAccess = FileAccess.open(_output, FileAccess.WRITE)
		if file == null:
			_check(false, "native JSON evidence file opens")
		else:
			file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
			file.close()
	print("HILLSIDE_PUBLIC_PLAY checks=%d failures=%d captures=%d launches=%d" %
		[_checks, _failed.size(), _captures.size(), _launches])
	get_tree().quit(0 if _failed.is_empty() else 1)


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failed.append(message)
		push_error("HILLSIDE_PUBLIC_PLAY " + message)
	return ok


func _v(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _q(value: Quaternion) -> Array[float]:
	return [value.x, value.y, value.z, value.w]
