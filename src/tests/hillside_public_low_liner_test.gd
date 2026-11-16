extends Node3D
## Selected retained-recipe hypothesis: first six ordinary automated public releases.
## Only passive launch/ground witnesses and the existing reversible capture lock.
## No launch, contact, outcome, defender input, camera pose or production physics is authored.
# gdlint: disable=max-line-length,max-file-lines,max-returns

signal physics_observed
const F = preload("res://src/tests/hillside_public_fixture.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
const Freeze = preload("res://src/tests/stadium_long_yard_capture_freeze.gd")
const MAX_TICKS: int = 1800
const MAX_TRACE: int = 600
const EXPECTED_CHECKS: int = 31
const WORKING_SUPPORT_RAY_ERROR_M: float = 0.0002
const EXPECTED_PLAYS: Array[Dictionary] = [
	{
		"batter": "player.emery_lane",
		"contact": 0,
		"exit_speed": 0.0,
		"half": 0,
		"pitcher": "player.dakota_wells",
		"read": true,
		"recipe": "pitch.overhand_slider",
		"result": "swinging_strike",
		"swung": true
	},
	{
		"batter": "player.emery_lane",
		"contact": -1,
		"exit_speed": 0.0,
		"half": 0,
		"pitcher": "player.dakota_wells",
		"read": true,
		"recipe": "pitch.overhand_slider",
		"result": "ball",
		"swung": false
	},
	{
		"batter": "player.emery_lane",
		"contact": 2,
		"exit_speed": 9.25230884552002,
		"half": 0,
		"pitcher": "player.dakota_wells",
		"read": true,
		"recipe": "pitch.overhand_slider",
		"result": "out",
		"swung": true
	},
	{
		"batter": "player.indy_shaw",
		"contact": 0,
		"exit_speed": 0.0,
		"half": 0,
		"pitcher": "player.dakota_wells",
		"read": true,
		"recipe": "pitch.overhand_slider",
		"result": "swinging_strike",
		"swung": true
	},
	{
		"batter": "player.indy_shaw",
		"contact": 0,
		"exit_speed": 0.0,
		"half": 0,
		"pitcher": "player.dakota_wells",
		"read": true,
		"recipe": "pitch.overhand_slider",
		"result": "swinging_strike",
		"swung": true
	},
	{
		"batter": "player.indy_shaw",
		"contact": 2,
		"exit_speed": 26.922649383544922,
		"half": 0,
		"pitcher": "player.dakota_wells",
		"read": true,
		"recipe": "pitch.overhand_slider",
		"result": "double",
		"swung": true
	}
]
const EXPECTED_RELEASES: Array[Dictionary] = [
	{
		"half": 0,
		"pa": 1,
		"paid": 6.004689613978059,
		"player": "player.dakota_wells",
		"recipe": "pitch.overhand_slider"
	},
	{
		"half": 0,
		"pa": 1,
		"paid": 5.206707742479125,
		"player": "player.dakota_wells",
		"recipe": "pitch.overhand_slider"
	},
	{
		"half": 0,
		"pa": 1,
		"paid": 5.9072189927101135,
		"player": "player.dakota_wells",
		"recipe": "pitch.overhand_slider"
	},
	{
		"half": 0,
		"pa": 2,
		"paid": 5.731337527434022,
		"player": "player.dakota_wells",
		"recipe": "pitch.overhand_slider"
	},
	{
		"half": 0,
		"pa": 2,
		"paid": 5.260528246561677,
		"player": "player.dakota_wells",
		"recipe": "pitch.overhand_slider"
	},
	{
		"half": 0,
		"pa": 2,
		"paid": 5.2551653120252695,
		"player": "player.dakota_wells",
		"recipe": "pitch.overhand_slider"
	}
]
var _app: SeasonApp
var _season: SeasonState
var _match: MatchState
var _lab: PitchBatLab
var _owner: StadiumNpcPublicProperty
var _automation: MatchAutomation
var _native: Node
var _terrain: StaticBody3D
var _body: BattedBallBody
var _state: BallPlayState
var _resolver: BallPlayResolver
var _saved_path: String = ""
var _settings_path: String = ""
var _save_sha: String = ""
var _draft: Dictionary = {}
var _before_season: Dictionary = {}
var _paths_isolated: bool = false
var _capture_dir: String = ""
var _output: String = ""
var _output_admitted: bool = false
var _checks: int = 0
var _failed: Array[String] = []
var _tick: int = 0
var _capturing: bool = false
var _starts: int = 0
var _pre_ready: bool = false
var _prefix_checked: int = 0
var _target_launches: int = 0
var _trace: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _plays: Array[Dictionary] = []
var _releases: Array[Dictionary] = []
var _release: Dictionary = {}
var _launch: Dictionary = {}
var _ground: Dictionary = {}
var _terminal: Dictionary = {}
var _wall: Dictionary = {}
var _deferred_freeze: Dictionary = {}
var _last_target_record: Dictionary = {}
var _last_target_state: Dictionary = {}
var _admission: Dictionary = {}
var _ground_count: int = 0
var _identity_intact: bool = true
var _early_exit: String = ""
var _complete: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1000000
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
		elif argument.begins_with("--hillside-public-low-liner-output="):
			_output = argument.trim_prefix("--hillside-public-low-liner-output=")
		else:
			_check(false, "only exact output and capture-directory selectors are accepted")
	_run.call_deferred()


func _run() -> void:
	_output_admitted = _admit_output()
	_check(OS.get_cmdline_user_args().size() == 2 and _output_admitted \
		and _capture_dir.is_absolute_path() and _capture_dir.simplify_path() == _capture_dir \
		and DirAccess.dir_exists_absolute(_capture_dir), "two exact fresh output and root-owned capture arguments")
	_check(DisplayServer.get_name() != "headless" and Engine.physics_ticks_per_second == 60 \
		and Engine.time_scale == 1.0 and not get_tree().paused, "displayed ordinary unpaused fixed60 clock")
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
	SeasonSave.path = "user://hillside-low-liner-drafted-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://hillside-low-liner-settings-%d.cfg" % OS.get_process_id()
	_paths_isolated = true
	_check(not FileAccess.file_exists(SeasonSave.path) and not FileAccess.file_exists(SeasonSave.path + ".bak") \
		and not FileAccess.file_exists(SeasonSave.path + ".tmp") and not FileAccess.file_exists(PitchBatLabSettings.path) \
		and R.source_qualified() and F.ready(), "fresh isolated save/settings and accepted explicit public source")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	var prepared: SeasonState = F.season()
	_check(prepared != null and prepared.season_seed == 6 and prepared.results.is_empty() \
		and prepared.player_results.is_empty() and prepared.physical.reports.is_empty() \
		and prepared.physical.pending.is_empty() and prepared.final_fixture.is_empty() \
		and SeasonFinalVenue.matches_season(prepared), "same genuine completed draft and pre-draft fixed Hillside venue")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	_draft = SeasonSave.snapshot(prepared).duplicate(true)
	_check(_draft.version == 67 and _draft.opponents.policy == 13 and SeasonSave.save(prepared),
		"genuine current-policy drafted save67 written once")
	_save_sha = FileAccess.get_sha256(SeasonSave.path)
	_season = SeasonSave.restore()
	_check(_season != null and ClubCareer.same(_draft, SeasonSave.snapshot(_season)),
		"exact native canonical draft restore precedes explicit non-earned test binding")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	var fixture: Dictionary = F.fixture(_season, false)
	_season.phase = SeasonState.Phase.FINAL
	_match = SeasonPhysicalFixtures.match_for(_season, fixture)
	_check(_match != null and ClubCareer.same(fixture,
		{"id": 32, "round": 11, "away": 0, "home": 1, "neutral": true}) \
		and StadiumNpcSnapshot.matches_fixture(_match.stadium, _season, fixture) \
		and SeasonPhysicalFixtures.seed_for(_season, fixture) == 3351334,
		"same explicit fixture32, player-away roles and retained match seed3351334")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	_before_season = SeasonSave.snapshot(_season).duplicate(true)
	_app = SeasonApp.new()
	add_child(_app)
	# Hold only settlement polling, exactly as the accepted one-game qualification.
	_app.set_process(false)
	_app.season = _season
	_app._fixture_id = 32
	_app.notice = ""
	_app.child_entered_tree.connect(_configure_automation)
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
	_check(pending and _starts == 1 and _pre_ready and is_instance_valid(_lab) \
		and _app.lab == _lab and _app.notice.is_empty() and _public_identity() \
		and R.installed_bound(_lab, _match.stadium), "same SeasonApp asynchronous public admission with pre-ready ordinary automation")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	_terrain = _owner.construction.terrain.get_node("TerrainCollision")
	_check(_lab._automation == _automation and _automation.seed == 3351334 and _automation.presentation_enabled \
		and not _app.is_processing() and _lab.is_processing() and _lab.is_physics_processing() \
		and _lab._managed_match and _lab._npc_season == _season and not _lab._player_home \
		and _automation.releases.is_empty() and _lab._play_records.is_empty() \
		and _lab._throw_number == 3351334000 and not _lab._release_controller.active \
		and not _lab._match_presentation_director.blocks_gameplay(),
		"same initial six-release input state with only existing diagnostic presentation enabled")
	_check(_owner.objects.size() == 8 and _owner.display == null and _owner.score_display_intact() \
		and _owner.route_obstacles().is_empty() and _owner.public_automation == _automation \
		and _owner.boundary.get_script() == StadiumHillsidePublicContactAdapter \
		and _owner.boundary.contact_applied.get_connections().size() == 1 \
		and _owner.boundary.contact_applied.is_connected(_owner._club_contact),
		"sole ordinary public contact authority and unchanged venue objects")
	_admission = {"pending_observed": pending, "owner_id": _owner.get_instance_id(),
		"terrain_id": _terrain.get_instance_id(), "terrain_rid": _terrain.get_rid().get_id(),
		"app_id": _app.get_instance_id(), "lab_id": _lab.get_instance_id(), "match_id": _match.get_instance_id(),
		"automation_id": _automation.get_instance_id(), "seed": _automation.seed,
		"fixture": fixture.duplicate(true), "snapshot": _match.stadium.duplicate(true),
		"presentation_enabled": _automation.presentation_enabled,
		"saved_draft_sha256": _save_sha, "completed_games": 0}
	var start_tick: int = _tick
	for _frame in range(MAX_TICKS):
		await physics_observed
		if not _ordinary_running():
			_early_exit = "ordinary owner, clock or six-release bound changed"
			_check(false, _early_exit)
			break
		_observe()
		_check_prefix()
		if not _failed.is_empty():
			break
		if _state != null and not _state.dead:
			if _captures.is_empty() and not _state.has_grounded and _body.global_position.z >= 14.0:
				await _shot("hillside-low-liner-before-ground")
			elif _captures.size() == 1 and not _ground.is_empty():
				# This is the first late post-contact view, not a claim of an image inside the manifold callback.
				await _shot("hillside-low-liner-after-ground")
		if _lab._play_records.size() == 6:
			_terminal = _lab._play_records[5].to_dict()
			_wall = _live_row()
			if _captures.size() == 2:
				await _shot("hillside-low-liner-wall-terminal")
			break
		if not _failed.is_empty():
			break
	_retain_target_operands()
	_check(is_instance_valid(_lab) and _tick - start_tick <= MAX_TICKS and _prefix_checked == 6 and _lab._play_records.size() == 6 \
		and _automation.releases.size() == 6 and _target_launches == 1 and not _terminal.is_empty(),
		"exact six ordinary releases and records with one actual target launch within1800 unpaused ticks")
	_check(not _launch.is_empty() and _launch.get("ordinary_start", false) \
		and _launch.get("postlaunch_aero", false) and _identity_intact,
		"actual target pitch and AI swing own unchanged body, resolver and configured aero")
	_check(_ground_count == 1 and _ground.get("native", false) and _ground.get("first", false) \
		and _ground.get("ramp", false) and _ground.get("grounded", false) \
		and not _ground.get("defender_touched", true),
		"one genuine first ground uses exact native terrain manifold strictly inside ramp16to26 without defender touch")
	var events: Array = _terminal.get("stadium_contacts", [])
	var terminal_operands: bool = not _wall.is_empty() \
		and _wall.get("state") is Dictionary and _wall.get("ball") is Dictionary \
		and _wall.state.has("id") and _wall.ball.has("id") \
		and _launch.has_all(["body_id", "body_rid", "state_id", "resolver_id"]) \
		and _ground.has_all(["body_id", "body_rid", "state_id", "resolver_id"])
	_check(terminal_operands and _state != null and _state.dead and _state.has_grounded and not _state.defender_touched \
		and _terminal.get("has_first_ground", false) \
		and _terminal.get("resolution_reason") == "bounce_to_back_wall" and _terminal.get("result") == "double" \
		and _terminal.get("result_floor") == BallPlayState.ResultFloor.DOUBLE \
		and events.size() == 1 and events[0].source == "boundary" and events[0].surface == "BACK-02" \
		and events[0].role == "BACK_WALL_TERMINAL" and events[0].kind == "crossing" \
		and events[0].position[2] == 26.0 and _ground.get("elapsed", INF) < events[0].time \
		and _ground.get("tick", MAX_TICKS + 1) < _wall.get("tick", -1) \
		and _ground.get("engine_frame", INF) < _wall.get("engine_frame", -1) \
		and _lab._batted_ball == _body and _lab._ball_play_resolver == _resolver and _resolver.state == _state \
		and _ground.body_id == _launch.body_id and _ground.body_rid == _launch.body_rid \
		and _ground.state_id == _launch.state_id and _ground.resolver_id == _launch.resolver_id \
		and _wall.get("ball", {}).get("id") == _launch.body_id and _wall.state.id == _launch.state_id \
		and ClubCareer.same(_terminal.get("first_ground_position", []), _ground.get("point", [])),
		"same first-grounded untouched play reaches later ordinary BACK02 double rather than air-wall triple")
	_check(_captures.size() == 3 and not _captures[0].state.grounded \
		and not _captures[0].state.dead and _captures[1].state.grounded and not _captures[1].state.dead \
		and _captures[2].state.grounded and _captures[2].state.dead \
		and _captures[0].tick < _captures[1].tick and _captures[1].tick < _captures[2].tick \
		and _trace.size() <= MAX_TRACE, "three ordered normal-camera native views retain actual preground, postground and wall states")
	_releases = _automation.releases.duplicate(true)
	_complete = _failed.is_empty()
	await _dispose()
	_finish()


func _configure_automation(node: Node) -> void:
	if not node is PitchBatLab:
		return
	var lab: PitchBatLab = node
	_starts += 1
	_pre_ready = not lab.is_node_ready() and lab._automation == null and _starts == 1
	if not _pre_ready:
		return
	_automation = MatchAutomation.new()
	_automation.seed = SeasonPhysicalFixtures.seed_for(_app.season, _app.season.pending_fixture())
	_automation.presentation_enabled = true
	lab._automation = _automation
	lab.child_entered_tree.connect(_child_entered)


func _ordinary_running() -> bool:
	return _public_identity() and _lab._automation == _automation and not _app.is_processing() \
		and _lab.is_processing() and _lab.is_physics_processing() and not _app._result_recorded and not _app._result_saved \
		and Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 and not get_tree().paused \
		and _automation.releases.size() <= 6 and _lab._play_records.size() <= 6 \
		and not _lab.has_meta("stadium_npc_runtime_interrupted")


func _check_prefix() -> void:
	while _prefix_checked < _lab._play_records.size() and _prefix_checked < 6:
		var record: PlayRecord = _lab._play_records[_prefix_checked]
		_plays.append(record.to_dict())
		var compact: Dictionary = {"half": (record.inning - 1) * 2 + (0 if record.top_half else 1),
			"batter": String(record.batter_id), "pitcher": String(record.pitcher_id), "recipe": String(record.pitch_id),
			"read": record.ai_decision_recorded, "swung": record.ai_swung, "contact": record.contact_outcome,
			"exit_speed": record.exit_speed_mps, "result": String(record.result)}
		var same: bool = ClubCareer.same(compact, EXPECTED_PLAYS[_prefix_checked]) \
			and ClubCareer.same(_automation.releases[_prefix_checked], EXPECTED_RELEASES[_prefix_checked])
		_check(same, "native canonical ordinary compact play and release match retained prefix index%d" % _prefix_checked)
		_prefix_checked += 1
		if not same:
			_early_exit = "selected retained-recipe prefix diverged; actual records retained without retuning"
			return


func _child_entered(child: Node) -> void:
	if child is BattedBallBody and _automation.releases.size() == 6:
		child.launch_started.connect(_launched.bind(child))
		child.surface_contact.connect(_surface_observed.bind(child))


func _launched(point: Vector3, ball: BattedBallBody) -> void:
	_target_launches += 1
	_body = ball
	_resolver = _lab._ball_play_resolver
	_state = _resolver.state
	var contact: ContactResult = _lab._swing_tracker.result
	var ordinary: bool = contact != null and contact.outcome != ContactResult.Outcome.MISS \
		and ball == _lab._batted_ball and ball.get_parent() == _lab and ball.get_script() == BattedBallBody \
		and _lab._pitch_actor.state == null and not _lab._pitch_actor.running and _state != null \
		and _match.phase == MatchState.Phase.BALL_IN_PLAY and _lab._active_play_record != null \
		and not _lab._swing_tracker.active and _lab._swing_consumed \
		and _lab._active_play_record.contact_outcome == contact.outcome and ball._started \
		and point == contact.contact_position and ball.linear_velocity == contact.exit_velocity
	_launch = {"ordinary_start": ordinary, "postlaunch_aero": false, "tick": _tick,
		"engine_frame": Engine.get_physics_frames(), "position": _v(point), "velocity": _v(ball.linear_velocity),
		"angular_velocity": _v(ball.angular_velocity), "body_id": ball.get_instance_id(),
		"body_rid": ball.get_rid().get_id(), "state_id": _state.get_instance_id(),
		"resolver_id": _resolver.get_instance_id(), "owner_id": _owner.get_instance_id(),
		"grounded": _state.has_grounded, "defender_touched": _state.defender_touched}
	_release = _lab._active_play_record.to_dict()
	if contact != null:
		_launch.contact = {"id": contact.get_instance_id(), "outcome": contact.outcome,
			"quality": contact.quality, "spray": contact.spray_degrees, "angle": contact.launch_angle_degrees,
			"horizontal_error": contact.horizontal_error_m, "vertical_error": contact.vertical_error_m,
			"timing_error": contact.timing_error_m, "backspin": contact.backspin_rad_s}


func _surface_observed(surface: StringName, at: Vector3, ball: BattedBallBody) -> void:
	if surface != &"ground" or ball != _body or _state == null:
		return
	_ground_count += 1
	if not _ground.is_empty():
		return
	var native: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(ball.get_rid())
	var actual: bool = false
	var contacts: Array[Dictionary] = []
	if native != null:
		for index in range(native.get_contact_count()):
			var collider: Object = native.get_contact_collider_object(index)
			var rid: RID = native.get_contact_collider(index)
			var point: Vector3 = native.get_contact_collider_position(index)
			contacts.append({"collider_id": collider.get_instance_id() if is_instance_valid(collider) else 0,
				"rid": rid.get_id(), "point": _v(point)})
			actual = actual or (collider == _terrain and rid == _terrain.get_rid() and point == at)
	_ground = {"tick": _tick, "engine_frame": Engine.get_physics_frames(), "elapsed": _state.elapsed_seconds,
		"point": _v(at), "native": actual, "contacts": contacts, "grounded": _state.has_grounded,
		"defender_touched": _state.defender_touched, "first": _state.first_ground_position == at,
		"ramp": at.z > StadiumHillsideTerrain.START_Z and at.z < StadiumHillsideTerrain.END_Z,
		"body_id": ball.get_instance_id(), "body_rid": ball.get_rid().get_id(),
		"state_id": _state.get_instance_id(), "resolver_id": _resolver.get_instance_id(),
		"terrain_id": _terrain.get_instance_id(), "terrain_rid": _terrain.get_rid().get_id()}


func _physics_process(_delta: float) -> void:
	if _capturing or get_tree().paused:
		return
	_tick += 1
	physics_observed.emit()


func _observe() -> void:
	if _state == null or not is_instance_valid(_body):
		return
	if not _launch.postlaunch_aero:
		var setup: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
		_launch.postlaunch_aero = _body.ball_mass_kg == setup.aero_profile.mass_kg \
			and _body.mass == PackedFloat32Array([setup.aero_profile.mass_kg])[0] \
			and _body.radius_m == setup.aero_profile.radius_m \
			and _body.aero_drag_coefficient == setup.aero_profile.drag_coefficient * setup.drag_multiplier \
			and _body.aero_magnus_scale == setup.aero_profile.magnus_scale * setup.magnus_multiplier \
			and _body.aero_perforation_force_scale == setup.aero_profile.perforation_force_scale * setup.perforation_multiplier \
			and _body.linear_damp == 0.0 and _body.angular_damp == 0.0 and _body.continuous_cd
		_check(_launch.postlaunch_aero and _lab._primary_fielder.active \
			and not _launch.grounded and not _launch.defender_touched,
			"late observer confirms unchanged ordinary launched aero and untouched airborne initial state")
	if not _state.dead:
		_identity_intact = _identity_intact and _lab._batted_ball == _body \
			and _lab._ball_play_resolver == _resolver and _resolver.state == _state and _public_identity() \
			and _owner.boundary.binding_intact(_body, _resolver, _state) \
			and _owner.hillside_support.ground.public_binding_intact(_body, _state) \
			and _body.physics_contact_router == _owner._boundary_contact_batch.bind(_resolver)
	if _trace.size() < MAX_TRACE:
		_trace.append(_live_row())
	else:
		_check(false, "bounded target trace exceeds600 rows")
	if not _ground.is_empty() and (not _ground.native or not _ground.first or not _ground.ramp \
		or not _ground.grounded or _ground.defender_touched):
		_early_exit = "actual sixth play first ground does not prove untouched ramp-first; no input retuning"
		_check(false, _early_exit)


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


func _shot(label: String) -> void:
	_capturing = true
	var physical_before: bool = _physics_membership()
	var state: Dictionary = _lock_capture()
	var deferred_ok: bool = true
	if _captures.size() == 2:
		# Ordinary terminal stop queues freeze; drain it while the existing lock holds gameplay.
		deferred_ok = _public_identity() and is_instance_valid(_body) and _state != null \
			and _resolver != null and _lab._batted_ball == _body and _lab._ball_play_resolver == _resolver \
			and _resolver.state == _state and not _wall.is_empty()
		var queued_before: Dictionary = _live_row() if deferred_ok else {}
		var queued_snapshot: PackedByteArray = _capture_snapshot() if deferred_ok else PackedByteArray()
		var waited: int = 0
		for _frame in range(8):
			if not deferred_ok or _body.freeze:
				break
			await get_tree().process_frame
			waited += 1
			deferred_ok = _public_identity() and is_instance_valid(_body) and _lab._batted_ball == _body \
				and _lab._ball_play_resolver == _resolver and _resolver.state == _state
		var queued_after: Dictionary = _live_row() if deferred_ok else {}
		var only_freeze_changed: bool = false
		var wall_same: bool = false
		if deferred_ok:
			# Decoding creates independent copies; retained rows and pre-bytes stay untouched.
			var prior_rows: Array = bytes_to_var(queued_snapshot)
			var settled_rows: Array = bytes_to_var(_capture_snapshot())
			prior_rows[1].ball.frozen = settled_rows[1].ball.frozen
			only_freeze_changed = var_to_bytes(prior_rows) == var_to_bytes(settled_rows)
			var wall_row: Dictionary = _wall.duplicate(true)
			var before_row: Dictionary = queued_before.duplicate(true)
			wall_row.erase("engine_frame")
			before_row.erase("engine_frame")
			wall_same = var_to_bytes(wall_row) == var_to_bytes(before_row)
			deferred_ok = waited > 0 and waited <= 8 and not queued_before.ball.frozen \
				and queued_after.ball.frozen and queued_before.state.dead and queued_after.state.dead \
				and only_freeze_changed and wall_same
		_deferred_freeze = {"before": queued_before, "after": queued_after, "wait_frames": waited,
			"max_wait_frames": 8, "only_freeze_changed": only_freeze_changed,
			"wall_same": wall_same, "settled": deferred_ok}
	# A failed drain never establishes a stable capture baseline or takes a screenshot.
	var before: PackedByteArray = _capture_snapshot() if deferred_ok else PackedByteArray()
	var rendered_before: Dictionary = Freeze.snapshot(_lab, _lab._batted_ball) if deferred_ok \
		else {"bytes": PackedByteArray(), "unsupported": []}
	var sampled: Dictionary = _live_row() if deferred_ok else {}
	var captured: bool = false
	if deferred_ok:
		captured = await _native.capture(_capture_dir, label)
	var rendered_after: Dictionary = Freeze.snapshot(_lab, _lab._batted_ball) if deferred_ok \
		else {"bytes": PackedByteArray(), "unsupported": []}
	var flags_paused: bool = true
	for row: Dictionary in state.nodes:
		flags_paused = flags_paused and is_instance_valid(row.node) and Freeze._flags(row.node) == [false, false, false, false, false, false, false, false]
	var proof: Dictionary = {"membership_before": physical_before,
		"membership_after": deferred_ok and _physics_membership(),
		"state_equal": deferred_ok and _capture_snapshot() == before,
		"render_equal": rendered_before.bytes == rendered_after.bytes,
		"render_supported": rendered_before.unsupported.is_empty() and rendered_after.unsupported.is_empty(),
		"modes_intact": Freeze._modes_intact(state), "flags_paused": flags_paused,
		"tree_paused": get_tree().paused, "tweens_intact": deferred_ok and Freeze._tweens_intact(_lab, state, true)}
	proof.restored = _unlock_capture(state)
	_capturing = false
	var intact: bool = deferred_ok and proof.values().all(func(value: bool) -> bool: return value)
	var expected_shot: int = MatchCameraDirector.Shot.BALL_IN_PLAY
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
	var restored: bool = is_instance_valid(_lab) and Freeze._modes_intact(state) and Freeze._tweens_intact(_lab, state, true)
	for row: Dictionary in state.nodes:
		if not is_instance_valid(row.node):
			restored = false
			continue
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


func _v(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _retain_target_operands() -> void:
	if not is_instance_valid(_lab) or _state == null:
		return
	if not _public_identity():
		_last_target_state = _trace[-1].duplicate(true) if not _trace.is_empty() else {}
		return
	_last_target_state = _live_row()
	if _lab._play_records.size() == 6:
		_last_target_record = _lab._play_records[5].to_dict()
		if _terminal.is_empty():
			_terminal = _last_target_record.duplicate(true)
		if _wall.is_empty():
			_wall = _last_target_state.duplicate(true)
	elif _lab._active_play_record != null and _automation.releases.size() == 6:
		_last_target_record = _lab._active_play_record.to_dict()


func _dispose() -> void:
	_retain_target_operands()
	if is_instance_valid(_lab) and _automation != null:
		_releases = _automation.releases.duplicate(true)
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
		await get_tree().process_frame
	if _paths_isolated:
		var restored: SeasonState = SeasonSave.restore() if not _save_sha.is_empty() else null
		_check(not _save_sha.is_empty() and FileAccess.get_sha256(SeasonSave.path) == _save_sha \
			and restored != null and ClubCareer.same(_draft, SeasonSave.snapshot(restored)) \
			and restored.final_fixture.is_empty() and not FileAccess.file_exists(SeasonSave.path + ".bak") \
			and not FileAccess.file_exists(SeasonSave.path + ".tmp") \
			and (_before_season.is_empty() or ClubCareer.same(_before_season, SeasonSave.snapshot(_season))),
			"ordinary close preserves exact saved draft and in-memory fixture without season settlement")
		SeasonSave.path = _saved_path
		PitchBatLabSettings.path = _settings_path
		_paths_isolated = false
	await TestAudioDrain.finish(get_tree())


func _finish() -> void:
	_check(_checks + 1 == EXPECTED_CHECKS, "exact bounded six-release witness assertion inventory")
	var result: Dictionary = {"kind": "ordinary-public-hillside-six-release-low-liner-witness",
		"checks": _checks, "failures": _failed, "status": "passed" if _complete and _failed.is_empty() else "failed",
		"recipe_status": "selected retained-recipe hypothesis until actual native prefix comparison",
		"prefix_checked": _prefix_checked, "actual_plays": _plays, "actual_releases": _releases,
		"target_release": _release, "launch": _launch, "first_ground": _ground,
		"ground_count": _ground_count, "target_launches": _target_launches, "trace": _trace,
		"terminal": _terminal, "wall_state": _wall, "captures": _captures, "early_exit": _early_exit,
		"deferred_freeze": _deferred_freeze,
		"last_target_record": _last_target_record, "last_target_state": _last_target_state,
		"identity_intact": _identity_intact, "public_admission": _admission,
		"caps": {"releases": 6, "unpaused_physics_ticks": MAX_TICKS, "target_rows": MAX_TRACE, "captures": 3},
		"completed_games": 0, "earned_final": false, "settled": false, "manual_input_qualified": false,
		"public_selection": "HELD", "performance_claim": "NONE", "h3_repair_claim": false,
		"unobserved": "original report23 omits launch vector, swing aim, first-ground point and defender flags; no full report equality claim"}
	if _output_admitted:
		var file: FileAccess = FileAccess.open(_output, FileAccess.WRITE)
		if file == null:
			_check(false, "native JSON evidence file opens")
		else:
			file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
			file.close()
	print("HILLSIDE_PUBLIC_LOW_LINER checks=%d failures=%d captures=%d releases=%d target_launches=%d" %
		[_checks, _failed.size(), _captures.size(), _releases.size(), _target_launches])
	get_tree().quit(0 if _complete and _failed.is_empty() else 1)


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failed.append(message)
		push_error("HILLSIDE_PUBLIC_LOW_LINER " + message)
	return ok
