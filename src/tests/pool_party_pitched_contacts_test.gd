extends Node3D
## Native-only, one genuine released pitch and untouched contact/launch/defense flow.
## Calibration and probe selectors are explicitly NOT target qualifications.
# gdlint: disable=max-file-lines,max-returns

signal physics_observed

const F = preload("res://src/tests/pool_party_public_fixture.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const MAX_FRAMES: int = 1800
const MAX_TRACE: int = 900
const MAX_SOLID_EVENTS: int = 512
const MAX_EVIDENCE_BYTES: int = 2 * 1024 * 1024
const CASES: Array[String] = ["calibrate-left", "calibrate-right", "probe-left", "probe-right",
	"left-water", "right-water", "left-solid", "right-solid"]

var _case: String = "probe-left"
var _offset: float = 0.0
var _aim_delta: Vector2 = Vector2.ZERO
var _pitch_target: Vector2 = Vector2(0, 1.15)
var _profile_id: StringName = &"swing.power"
var _pitch_index: int = 0
var _batter_source_mode: String = "saved"
var _batter_source: Dictionary = {}
var _authored_definition: PlayerDefinition
var _authored_snapshot: Dictionary = {}
var _output: String = ""
var _output_admitted: bool = false
var _checks: int = 0
var _failed: Array[String] = []
var _lab: PitchBatLab
var _property: StadiumNpcPublicProperty
var _boundary: StadiumPoolPartyPublicBoundary
var _season: SeasonState
var _before: Dictionary = {}
var _trace: Array[Dictionary] = []
var _solid_events: Array[Dictionary] = []
var _launch: Dictionary = {}
var _release: Dictionary = {}
var _terminal: Dictionary = {}
var _requested: Dictionary = {}
var _launch_count: int = 0
var _swing_sent: bool = false
var _start_time: float = -1
var _aim: Vector2 = Vector2.ZERO
var _body: BattedBallBody
var _state: BallPlayState
var _route_checks: int = 0
var _route_clear: bool = true
var _authority_clear: bool = true
var _closest_pool: float = INF
var _closest_point: Vector3 = Vector3.ZERO
var _last_fielder: Vector3
var _last_pitcher: Vector3
var _water_seen: int = 0
var _water_frames: Array[int] = []
var _water_receipts: Array[Dictionary] = []
var _observe_enabled: bool = false
var _receipt_seen: int = 0
var _trace_overflow: bool = false
var _solid_overflow: bool = false
var _provenance_used: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Only this external test observer runs late. Production timing stays unchanged.
	process_physics_priority = 1000000
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-party-contact-case="):
			_case = argument.trim_prefix("--pool-party-contact-case=")
		elif argument.begins_with("--pool-party-contact-time-offset="):
			_offset = argument.trim_prefix("--pool-party-contact-time-offset=").to_float()
		elif argument.begins_with("--pool-party-contact-aim-dx="):
			_aim_delta.x = argument.trim_prefix("--pool-party-contact-aim-dx=").to_float()
		elif argument.begins_with("--pool-party-contact-aim-dy="):
			_aim_delta.y = argument.trim_prefix("--pool-party-contact-aim-dy=").to_float()
		elif argument.begins_with("--pool-party-contact-target-x="):
			_pitch_target.x = argument.trim_prefix("--pool-party-contact-target-x=").to_float()
		elif argument.begins_with("--pool-party-contact-target-y="):
			_pitch_target.y = argument.trim_prefix("--pool-party-contact-target-y=").to_float()
		elif argument.begins_with("--pool-party-contact-profile="):
			_profile_id = StringName(argument.trim_prefix("--pool-party-contact-profile="))
		elif argument.begins_with("--pool-party-contact-pitch-index="):
			_pitch_index = argument.trim_prefix("--pool-party-contact-pitch-index=").to_int()
		elif argument.begins_with("--pool-party-contact-batter-source="):
			_batter_source_mode = argument.trim_prefix("--pool-party-contact-batter-source=")
		elif argument.begins_with("--pool-party-contact-output="):
			_output = argument.trim_prefix("--pool-party-contact-output=")
	_run.call_deferred()


func _run() -> void:
	_output_admitted = _admit_output()
	_check(_output_admitted, "fresh canonical absolute JSON output in existing root-owned directory")
	_check(_case in CASES, "one exact genuine-pitch selector")
	_check(is_finite(_offset) and absf(_offset) <= 0.2 and _aim_delta.is_finite()
		and absf(_aim_delta.x) <= 0.6 and absf(_aim_delta.y) <= 0.6
		and SwingIntent.reachable_aim(_pitch_target) == _pitch_target
		and _profile_id in [&"swing.power", &"swing.contact"] and _pitch_index in range(6)
		and _batter_source_mode in ["saved", "authored-frankie", "authored-mika"],
		"bounded real input controls")
	_check(R.source_qualified() and F.ready(), "current composed public source and final recipe")
	if not _failed.is_empty():
		_finish()
		return
	var original: SeasonState = F.season()
	if not _check(original != null, "canonical season fixture available"):
		_finish()
		return
	# Save66 restores the assigned neutral venue, not synthetic final participants.
	_before = SeasonSave.snapshot(original)
	_season = SeasonSave._decode(JSON.parse_string(JSON.stringify(_before, "", true, true)))
	if not _check(_season != null, "full precision save66 final5 snapshot24 restored"):
		_finish()
		return
	var fixture: Dictionary = F.fixture(_season, false)
	var source: MatchState = SeasonPhysicalFixtures.match_for(_season, fixture)
	if not _select_saved_hand(source) or not _apply_batter_source(source):
		_finish()
		return
	_lab = PitchBatLab.new()
	_lab._configured_match = source
	_lab._npc_season = _season
	_lab._field_id = &"field.npc_venue"
	_lab._managed_match = true
	_lab._player_home = false
	_lab.child_entered_tree.connect(_child_entered)
	add_child(_lab)
	_property = R._property(_lab)
	if not _check(not _lab.yard_bound_startup_failed and _property != null
		and _property.issued, "ordinary exact-script lab installed saved neutral authority"):
		await _dispose()
		_finish()
		return
	_boundary = _property.boundary as StadiumPoolPartyPublicBoundary
	_check(_lab.get_script() == PitchBatLab and _boundary != null
		and _property.venue_id == "POOL-PARTY" and _property.tier == "expanded"
		and _property.objects.size() == 65 and _lab._stadium_ledger == null,
		"exact65 Expanded neutral installation without paid stock or lab subclass")
	_check(_lab._match_state.stadium.version == 24
		and _lab._match_state.stadium.environment.version == 6
		and _lab._match_state.stadium.environment.time == "13:10",
		"saved Pool Party fixture and daytime environment retained")
	PitchBatLabFeelSupport.skip_match_presentation(_lab)
	_lab._at_bat_cadence.stop()
	_lab._sounds.set_muted(true)
	_check(_boundary.contact_applied.get_connections().size() == 1
		and _boundary.contact_applied.is_connected(_property._club_contact)
		and _property.ordinary_callbacks(), "production boundary and outcome listeners remain exact")
	_check(process_physics_priority == 1000000 and _lab.process_physics_priority == 0
		and _lab._primary_fielder.process_physics_priority == 0,
		"only the external read-only observer has late physics priority")
	_lab._pitch_actor.segment_advanced.connect(_pitch_segment)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_geometry_guards()
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	# These are normal pre-release Pitch inputs. No state/velocity/outcome is authored.
	if not _check(_pitch_index < _lab._current_pitch_options().size(),
		"requested recipe belongs to the actual saved pitcher"):
		await _dispose()
		_finish()
		return
	_lab._selected_pitch_index = _pitch_index
	_lab._pitch_target = _pitch_target
	_lab._ai_pitch_preselected = true
	_lab._throw_pitch()
	_lab._at_bat_cadence.stop()
	if not _check(_lab._pitch_actor.running and _lab._pitch_actor.parameters != null
		and _lab._pitch_actor.state != null and _lab._throw_number == 1,
		"one actual _throw_pitch release with real PitchLaunchParameters"):
		await _dispose()
		_finish()
		return
	var parameters: PitchLaunchParameters = _lab._pitch_actor.parameters
	var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
		parameters, ContactResolver.CONTACT_PLANE_Z)
	var profile: SwingProfileDefinition = ContentDB.get_swing(_profile_id)
	profile = SeasonSponsorEffects.swing(profile, _lab._match_state)
	_check(crossing.crossed and profile != null, "real released parameters predict reachable plane")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	_start_time = crossing.elapsed_seconds - profile.sweet_spot_seconds + _offset
	_aim = Vector2(crossing.point.x, crossing.point.y) + _aim_delta
	if not _check(_start_time >= 0 and SwingIntent.reachable_aim(_aim) == _aim,
		"requested real swing timing and aim are reachable without hidden clamping"):
		await _dispose()
		_finish()
		return
	_requested = {"profile": String(_profile_id), "time_offset": _offset,
		"aim_delta": [_aim_delta.x, _aim_delta.y], "start_time": _start_time,
		"aim": [_aim.x, _aim.y], "pitch_index": _pitch_index,
		"predicted_crossing": _v(crossing.point),
		"predicted_crossing_time": crossing.elapsed_seconds}
	_release = {"position": _v(parameters.position), "velocity": _v(parameters.velocity),
		"angular_velocity": _v(parameters.angular_velocity), "orientation": _q(parameters.orientation),
		"pitch_id": String(parameters.pitch_id), "seed": parameters.seed,
		"batter_id": String(_lab._match_state.batter().definition.id),
		"batter_left": _lab._match_state.batter().bats_left(),
		"contact_rating": _lab._match_state.batter().definition.contact,
		"power_rating": _lab._match_state.batter().definition.power,
		"profile": _profile_data(profile), "target": [_pitch_target.x, _pitch_target.y],
		"batter_source": _batter_source}
	var setup: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
	_release["batted_aero"] = {"mass": setup.aero_profile.mass_kg,
		"radius": setup.aero_profile.radius_m,
		"drag": setup.aero_profile.drag_coefficient * setup.drag_multiplier,
		"magnus": setup.aero_profile.magnus_scale * setup.magnus_multiplier,
		"perforation": setup.aero_profile.perforation_force_scale * setup.perforation_multiplier}
	_trace.append(_pitch_row(_lab._pitch_actor.state))
	_last_fielder = _lab._primary_fielder.global_position
	_last_pitcher = _lab._pitcher_marker.global_position
	_observe_enabled = true
	var completed: bool = false
	for frame in range(MAX_FRAMES):
		await physics_observed
		_lab._at_bat_cadence.stop()
		_observe_live()
		if not _failed.is_empty():
			break
		if _lab._play_records.size() == 1:
			_terminal = _lab._play_records[0].to_dict()
			completed = true
			break
		if not _property.issued or _property.suspended or _lab._throw_number != 1:
			break
	_check(completed, "real ordinary PlayRecord completes within one bounded live play")
	_check(_authority_clear and _property.issued and not _property.suspended
		and _property.callback_intact(), "issued common authority stayed intact through live play")
	_check(_route_clear and _route_checks > 0,
		"every observed real defender movement remained outside full Pool envelope")
	_check(not _trace_overflow and not _solid_overflow, "complete bounded native observations")
	_audit_observed_receipts()
	if _case.begins_with("calibrate"):
		_check(_launch_count == 0 and not _swing_sent and _trace.size() > 10,
			"calibration is only an actual released pitch trace, never water qualification")
	else:
		_check(_launch_count == 1 and _swing_sent and not _launch.is_empty(),
			"exactly one authentic pitched contact reaches ordinary launch")
		_check(_launch.get("real_start_ball_in_play", false) and _launch.get("real_aero", false),
			"real_start_ball_in_play and real_aero witnessed on actual emitted launch")
		_check(_terminal.get("contact_outcome", -1) >= 1
			and _terminal.get("swing_profile_id", "") == String(_profile_id),
			"ordinary play record retains actual swing and ContactResolver output")
		if _case.ends_with("water"):
			_audit_water()
		elif _case.ends_with("solid"):
			_audit_solid()
	var held: Dictionary = _terminal.duplicate(true)
	var water_count: int = _boundary.water_commits.size()
	for frame in range(6):
		await physics_observed
		_lab._at_bat_cadence.stop()
	_check(_lab._play_records.size() == 1 and ClubCareer.same(held,
		_lab._play_records[0].to_dict()) and _boundary.water_commits.size() == water_count,
		"terminal ordinary record and water receipt are stable, with no later reaward")
	_audit_batter_source()
	_check(ClubCareer.same(_before, SeasonSave.snapshot(_season))
		and PhysicalMatchReport.capture(_lab).is_empty(),
		"one-pitch fixture does not mutate season, fabricate full game or settle a final")
	await _dispose()
	_finish()


func _left() -> bool:
	return _case.begins_with("left") or _case.ends_with("left")


func _select_saved_hand(source: MatchState) -> bool:
	var team: TeamMatchState = source.away_team
	var candidate: int = -1
	var roster: Array = []
	for index in range(team.roster.size()):
		var player: PlayerMatchState = team.roster[index]
		roster.append({"id": String(player.definition.id), "left": player.bats_left()})
		if player.bats_left() == _left() and candidate < 0:
			candidate = index
	print("POOL_PARTY_SAVED_ROSTER ", JSON.stringify(roster))
	if not _check(candidate >= 0, "requested hand exists in actual saved batting roster"):
		return false
	# A controlled pre-install batting-order input, preserving every saved player and rating.
	# Both stances therefore use begin_swing's real batter handedness without modifying intent.
	if candidate != 0:
		var first: PlayerMatchState = team.roster[0]
		team.roster[0] = team.roster[candidate]
		team.roster[candidate] = first
		team.pitcher_index = _swap_index(team.pitcher_index, candidate)
		team.fielder_index = _swap_index(team.fielder_index, candidate)
	return _check(source.batter().bats_left() == _left() and R._fresh_match(source),
		"existing requested-hand batter leads a fresh preserved roster")


func _apply_batter_source(source: MatchState) -> bool:
	var batter: PlayerMatchState = source.batter()
	var pitcher: PlayerMatchState = source.pitcher()
	var saved: PlayerDefinition = batter.definition
	var pitcher_definition: PlayerDefinition = pitcher.definition
	var away_before: Array = source.away_team.roster.duplicate()
	var home_before: Array = source.home_team.roster.duplicate()
	_batter_source = {"mode": _batter_source_mode, "player_id": String(saved.id),
		"replaced_saved_id": String(saved.id), "pitcher_id": String(pitcher_definition.id),
		"saved_contact": saved.contact, "saved_power": saved.power,
		"actual_contact": saved.contact, "actual_power": saved.power,
		"resource_path": "", "source_sha256": "", "definition_unchanged": true,
		"career_claim": false}
	if _batter_source_mode == "saved":
		return true
	var mika: bool = _batter_source_mode == "authored-mika"
	var allowed: bool = not _left() and _case == "right-water" \
		and saved.id == &"player.emery_lane" and saved.contact == 2 and saved.power == 2 \
		and pitcher_definition.id == &"player.dakota_wells"
	if not mika:
		allowed = _batter_source_mode == "authored-frankie" and _left() \
			and saved.id == &"player.frankie_bell" and saved.contact == 1 and saved.power == 4
	if not _check(allowed and batter != pitcher,
		"explicit isolated authored mode retains the selected saved handed slot and pitcher"):
		return false
	var id: StringName = &"player.mika_reed" if mika else saved.id
	for team: TeamMatchState in [source.away_team, source.home_team]:
		for other: PlayerMatchState in team.roster:
			if other != batter and not _check(other.definition.id != id,
				"authored isolated batter ID is absent from every other player slot"):
				return false
	var authored: PlayerDefinition = ContentDB.get_player(id)
	var path: String = "res://src/content/players/mika_reed.tres" if mika \
		else "res://src/content/players/frankie_bell.tres"
	var source_sha: String = "c78ef608ac854158cccac186ff618a4d50f056739d25a7e5366601e02812a58f" \
		if mika else "65b629f7befeefedb699340a4a994664a6ac66a883a42a91aa32dccc9377d1b7"
	if not _check(authored != null and authored.id == id and authored.bats == saved.bats
		and authored.resource_path == path and FileAccess.get_sha256(path) == source_sha
		and authored.contact == (7 if mika else 5) and authored.power == (7 if mika else 9)
		and not authored.progression_test,
		"unchanged authored normal player resource has exact source provenance"):
		return false
	_authored_definition = authored
	_authored_snapshot = SeasonPhysicalFixtures._resource(authored)
	if mika:
		# Normal fresh PlayerMatchState factory preserves all authored ratings and stamina.
		batter = PlayerMatchState.create(authored)
		source.away_team.roster[0] = batter
	else:
		batter.definition = authored
	_batter_source.player_id = String(authored.id)
	_batter_source.actual_contact = authored.contact
	_batter_source.actual_power = authored.power
	_batter_source.resource_path = path
	_batter_source.source_sha256 = source_sha
	var others_unchanged: bool = true
	for index in range(4):
		others_unchanged = others_unchanged and source.home_team.roster[index] == home_before[index]
		if index != 0:
			others_unchanged = others_unchanged \
				and source.away_team.roster[index] == away_before[index]
	return _check(source.batter() == batter and batter.definition == authored
		and source.batter().bats_left() == _left() and source.pitcher() == pitcher
		and pitcher.definition == pitcher_definition and others_unchanged and R._fresh_match(source)
		and ClubCareer.same(_before, SeasonSave.snapshot(_season)),
		"only isolated batter slot selected before install; all others and saved season unchanged")


func _audit_batter_source() -> void:
	if _batter_source_mode == "saved":
		return
	_batter_source.definition_unchanged = _authored_definition != null \
		and String(_authored_definition.id) == _batter_source.player_id \
		and ContentDB.get_player(_authored_definition.id) == _authored_definition \
		and ClubCareer.same(_authored_snapshot,
			SeasonPhysicalFixtures._resource(_authored_definition)) \
		and FileAccess.get_sha256(_batter_source.resource_path) == _batter_source.source_sha256
	_check(_batter_source.definition_unchanged,
		"complete authored resource snapshot unchanged after the isolated live play")


func _swap_index(value: int, candidate: int) -> int:
	return candidate if value == 0 else (0 if value == candidate else value)


func _pitch_segment(_previous: Vector3, _previous_time: float) -> void:
	if _lab._pitch_actor.state == null:
		return
	var pitch: PitchState = _lab._pitch_actor.state
	if _trace.size() < MAX_TRACE:
		_trace.append(_pitch_row(pitch))
	elif not _trace_overflow:
		_trace_overflow = true
		_check(false, "complete actual pitch trace exceeded its hard row cap")
	if _case.begins_with("calibrate") or _swing_sent or pitch.elapsed_time < _start_time:
		return
	_swing_sent = true
	_lab._resolve_swing(_profile_id, _aim)
	_check(_lab._swing_tracker.active and _lab._swing_tracker.intent != null
		and _lab._swing_tracker.intent.handedness_left == _left(),
		"normal begin_swing created real requested-hand SwingIntent")
	if _lab._swing_tracker.intent != null:
		_requested["actual_start_time"] = _lab._swing_tracker.intent.start_time_seconds


func _child_entered(child: Node) -> void:
	if child is BattedBallBody:
		child.launch_started.connect(_launched.bind(child))


func _launched(point: Vector3, ball: BattedBallBody) -> void:
	_launch_count += 1
	_body = ball
	_state = _lab._ball_play_resolver.state
	var contact: ContactResult = _lab._swing_tracker.result
	var setup: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
	var real_start: bool = contact != null and contact.outcome != ContactResult.Outcome.MISS \
		and _lab.get_script() == PitchBatLab and ball.get_script() == BattedBallBody \
		and ball == _lab._batted_ball and ball.get_parent() == _lab \
		and _lab._pitch_actor.state == null and not _lab._pitch_actor.running \
		and _state != null and _lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY \
		and _lab._active_play_record != null and not _lab._swing_tracker.active \
		and _lab._swing_consumed \
		and _lab._active_play_record.contact_outcome == contact.outcome \
		and _lab._active_play_record.contact_quality == contact.quality \
		and ball._started and point == contact.contact_position \
		and ball.linear_velocity == contact.exit_velocity
	var aero_observation: Dictionary = _aero_observation(ball, setup)
	var real_aero: bool = aero_observation.comparisons.values().all(func(value: bool) -> bool:
		return value)
	_launch = {"real_start_ball_in_play": real_start, "real_aero": real_aero,
		"frame": Engine.get_physics_frames(), "position": _v(point),
		"velocity": _v(ball.linear_velocity), "angular_velocity": _v(ball.angular_velocity),
		"orientation": _q(ball.quaternion), "body_id": ball.get_instance_id(),
		"resolver_id": _lab._ball_play_resolver.get_instance_id(),
		"state_id": _state.get_instance_id() if _state != null else 0,
		"aero_observation": aero_observation}
	if contact != null:
		_launch["contact"] = {"outcome": contact.outcome, "quality": contact.quality,
			"spray": contact.spray_degrees, "angle": contact.launch_angle_degrees,
			"horizontal_error": contact.horizontal_error_m, "vertical_error": contact.vertical_error_m,
			"timing_error": contact.timing_error_m, "backspin": contact.backspin_rad_s}


func _aero_observation(ball: BattedBallBody, setup: BallSetupDefinition) -> Dictionary:
	var aero: BallAeroProfileDefinition = setup.aero_profile
	var actual: Dictionary = {"script_mass": ball.ball_mass_kg, "native_mass": ball.mass,
		"radius": ball.radius_m, "drag": ball.aero_drag_coefficient,
		"magnus": ball.aero_magnus_scale, "perforation": ball.aero_perforation_force_scale,
		"linear_damp": ball.linear_damp, "angular_damp": ball.angular_damp,
		"continuous_cd": ball.continuous_cd, "ready": ball.is_node_ready()}
	# Expected-only native float32 conversion follows the retained Pool interior
	# radius and premium light-tower exact-storage contracts. No tolerance is used.
	var expected: Dictionary = {"script_mass": aero.mass_kg,
		"native_mass": PackedFloat32Array([aero.mass_kg])[0], "radius": aero.radius_m,
		"drag": aero.drag_coefficient * setup.drag_multiplier,
		"magnus": aero.magnus_scale * setup.magnus_multiplier,
		"perforation": aero.perforation_force_scale * setup.perforation_multiplier,
		"linear_damp": 0.0, "angular_damp": 0.0, "continuous_cd": true, "ready": true}
	var comparisons: Dictionary = {}
	for key: String in expected:
		comparisons[key] = actual[key] == expected[key]
	return {"actual": actual, "expected": expected, "comparisons": comparisons}


func _physics_process(_delta: float) -> void:
	if _observe_enabled:
		_observe_contact_receipts()
	physics_observed.emit()


func _observe_contact_receipts() -> void:
	if _state == null or not is_instance_valid(_lab) \
		or not is_instance_valid(_boundary):
		return
	var resolver: BallPlayResolver = _lab._ball_play_resolver
	var receipts: Array[Dictionary] = _state.stadium_contacts
	if receipts.size() < _receipt_seen:
		_check(false, "production stadium receipt history cannot shrink")
		_observe_enabled = false
		return
	while _receipt_seen < receipts.size():
		var index: int = _receipt_seen
		_receipt_seen += 1
		if _solid_events.size() >= MAX_SOLID_EVENTS:
			if not _solid_overflow:
				_solid_overflow = true
				_check(false, "complete actual stadium receipt history exceeded its hard row cap")
			continue
		var owner: bool = is_instance_valid(_body) and resolver.state == _state \
			and _body == _lab._batted_ball and _body.get_parent() == _lab \
			and _boundary.actual_ball(resolver) == _body and _property.callback_intact()
		var live: String = String(_boundary.last_live.get(resolver.get_instance_id(), ""))
		var producer: Dictionary = _matching_provenance(receipts[index])
		_solid_events.append({"frame": Engine.get_physics_frames(),
			"resolver_id": resolver.get_instance_id(), "state_id": _state.get_instance_id(),
			"body_id": _body.get_instance_id() if is_instance_valid(_body) else 0,
			"receipt_index": index, "receipt": receipts[index].duplicate(true),
			"solid_frame": _boundary._solid_frame, "last_live": live,
			"dead_observed": _state.dead, "water_count": _boundary.water_commits.size(),
			"owner_intact": owner, "provenance_index": producer.index,
			"provenance": producer.receipt})


func _matching_provenance(receipt: Dictionary) -> Dictionary:
	for index in range(_property.provenance.size()):
		if _provenance_used.has(index):
			continue
		var producer: Dictionary = _property.provenance[index]
		if producer.instance == receipt.id and producer.surface == receipt.surface \
			and snappedf(float(producer.elapsed), 0.0001) == receipt.time:
			_provenance_used[index] = true
			return {"index": index, "receipt": producer.duplicate(true)}
	return {"index": -1, "receipt": {}}


func _audit_observed_receipts() -> void:
	var contacts: Array = _terminal.get("stadium_contacts", [])
	_check(_solid_events.size() == contacts.size() and _receipt_seen == contacts.size(),
		"late observer captured the complete ordinary terminal stadium receipt sequence")
	var pool_observed: int = 0
	for row: Dictionary in _solid_events:
		var index: int = row.receipt_index
		_check(index >= 0 and index < contacts.size() and row.receipt == contacts[index],
			"observed native receipt matches exact indexed ordinary PlayRecord receipt")
		_check(row.owner_intact and row.resolver_id == _launch.get("resolver_id", 0)
			and row.state_id == _launch.get("state_id", 0)
			and row.body_id == _launch.get("body_id", 0),
			"actual issued ball, resolver and state owned every observed native receipt")
		if row.receipt.id == StadiumPoolPartyRuntime.COPY:
			pool_observed += 1
			_check(_pool_receipt(row.receipt),
				"raw Pool receipt identifies an actual unchanged Pool body surface")
			_check(_pool_provenance(row),
				"sole original callback proves actual Pool preterminal producer provenance")
	var pool_producers: Array = _property.provenance.filter(func(row: Dictionary) -> bool:
		return row.instance == StadiumPoolPartyRuntime.COPY)
	_check(pool_producers.size() == pool_observed,
		"all genuine Pool producer receipts have corresponding observed ordinary contacts")


func _pool_provenance(row: Dictionary) -> bool:
	var index: int = row.provenance_index
	if index < 0 or index >= _property.provenance.size() or row.provenance.is_empty():
		return false
	var producer: Dictionary = row.provenance
	return producer == _property.provenance[index] and producer.preterminal \
		and producer.instance == StadiumPoolPartyRuntime.COPY \
		and producer.instance == row.receipt.id and producer.surface == row.receipt.surface \
		and snappedf(float(producer.elapsed), 0.0001) == row.receipt.time


func _pool_receipt(receipt: Dictionary) -> bool:
	return receipt.source == "item" and receipt.id == StadiumPoolPartyRuntime.COPY \
		and receipt.role == "LIVE_RICOCHET" and receipt.kind == "contact" \
		and _boundary.pool_model == _property.objects[StadiumPoolPartyRuntime.COPY] \
		and _boundary.pool_bodies.any(func(body: StaticBody3D) -> bool:
			return is_instance_valid(body) and String(body.name) == receipt.surface \
				and _boundary.pool_model.is_ancestor_of(body))


func _observe_live() -> void:
	_authority_clear = _authority_clear and _property.issued and not _property.suspended
	var routes: Array[Dictionary] = _pool_routes()
	var fielder: Vector3 = _lab._primary_fielder.global_position
	var pitcher: Vector3 = _lab._pitcher_marker.global_position
	_route_clear = _route_clear and StadiumDefenderRoutes.clear(_last_fielder, fielder, routes) \
		and StadiumDefenderRoutes.clear(_last_pitcher, pitcher, routes)
	_route_checks += 2
	_last_fielder = fielder
	_last_pitcher = pitcher
	if is_instance_valid(_body):
		var distance: float = _body.global_position.distance_to(Vector3(12, 1, 18))
		if distance < _closest_pool:
			_closest_pool = distance
			_closest_point = _body.global_position
	while _water_seen < _boundary.water_commits.size():
		_water_frames.append(Engine.get_physics_frames())
		_water_seen += 1


func _pool_routes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _property.route_obstacles():
		if row.copy == StadiumPoolPartyRuntime.COPY:
			result.append(row)
	return result


func _geometry_guards() -> void:
	var routes: Array[Dictionary] = _pool_routes()
	_check(routes.size() == 1 and routes[0].center == Vector3(12, 0, 18)
		and is_equal_approx(routes[0].radius, 2.82), "full Pool plus real defender clearance retained")
	_check(not StadiumDefenderRoutes.clear(Vector3(8, 0, 18), Vector3(16, 0, 18), routes)
		and StadiumDefenderRoutes.clear(Vector3(8, 0, 14), Vector3(16, 0, 14), routes),
		"ordinary routing refuses through-Pool path and admits adjacent open path")
	# Read-only probe of the same solid-ray API used by real catches; no actor or collider moves.
	var probe: Node3D = Node3D.new()
	add_child(probe)
	probe.global_position = Vector3(8, 0, 18)
	var through_target: Vector3 = Vector3(16, 0.4, 18)
	var through_clear: bool = StadiumPropertyRuntime.clear_control(_lab, probe, through_target)
	if through_clear:
		_ray_diagnostic(probe, through_target)
	_check(not through_clear, "ordinary catch-control ray refuses a through-Pool-wall reach")
	probe.global_position = Vector3(8, 0, 14)
	_check(StadiumPropertyRuntime.clear_control(_lab, probe, Vector3(16, 0.4, 14)),
		"ordinary catch-control ray retains adjacent open reach")
	probe.free()


func _audit_water() -> void:
	_check(_boundary.water_commits.size() == 1, "one actual descending top-water commit")
	if _boundary.water_commits.size() != 1:
		return
	var receipt: Dictionary = _boundary.water_commits[0]
	var values: Array = receipt.position
	var position: Vector3 = Vector3(values[0], values[1], values[2])
	var local: Vector3 = StadiumPoolContract.placement().affine_inverse() * position
	var radius: float = _body.radius_m if is_instance_valid(_body) else 0
	var interior: Dictionary = StadiumPoolInteriorV2.sample_local(local, radius)
	_check(radius > 0 and interior.valid and interior.positive_overlap
		and position.y < StadiumPoolContract.WATER_HEIGHT + radius,
		"actual water receipt overlaps unchanged authored interior using real ball radius")
	var foul: bool = bool(receipt.foul)
	var reason: String = "pool_party_controller_water_foul" if foul \
		else "pool_party_controller_water_double"
	_check(_state != null and _state.dead and not _state.caught
		and _terminal.get("resolution_reason", "") == reason
		and _terminal.get("result", "") == ("foul" if foul else "double"),
		"actual water latch reaches ordinary foul/double PlayRecord without catch theft")
	_check(receipt.play_sequence == 0 and receipt.generation == _boundary.generation
		and receipt.entry_fraction >= 0 and receipt.entry_fraction <= 1,
		"water receipt belongs to this exact issued ball generation and first real play")
	_check(foul == bool(_launch.get("contact", {}).get("outcome") == ContactResult.Outcome.FOUL),
		"water preserves actual ContactResolver foulness rather than assigning a synthetic result")
	_check(not foul or int(_terminal.get("result_floor", -1)) == 0,
		"genuine foul-water contact cannot award a fair result floor")


func _audit_solid() -> void:
	var pool_events: Array = _solid_events.filter(func(row: Dictionary) -> bool:
		return row.receipt.id == StadiumPoolPartyRuntime.COPY)
	_check(not pool_events.is_empty(), "actual pitched ball reaches immutable Pool solid")
	_check(_boundary.water_commits.is_empty(), "solid-first trial cannot borrow a water receipt")
	for row: Dictionary in pool_events:
		_check(_pool_receipt(row.receipt) and _pool_provenance(row) and row.owner_intact
			and row.water_count == 0 and row.solid_frame == row.frame,
			"real Pool solid and unchanged latch witnessed in the exact same physics frame")
	var contacts: Array = _terminal.get("stadium_contacts", [])
	_check(contacts.any(func(row: Dictionary) -> bool:
		return row.id == StadiumPoolPartyRuntime.COPY and row.role == "LIVE_RICOCHET"),
		"ordinary PlayRecord retains actual Pool solid receipt")


func _pitch_row(pitch: PitchState) -> Dictionary:
	return {"time": pitch.elapsed_time, "position": _v(pitch.position),
		"velocity": _v(pitch.velocity), "orientation": _q(pitch.orientation)}


func _profile_data(profile: SwingProfileDefinition) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["contact_radius_x_m", "contact_radius_y_m", "contact_depth_m",
		"contact_window_start_seconds", "contact_window_end_seconds", "sweet_spot_seconds",
		"bat_speed_mps", "attack_angle_degrees", "exit_velocity_multiplier",
		"minimum_contact_quality", "gear_fair_exit_scale", "tactical_quality_exit_scale",
		"gear_line_drive_calibrated", "gear_line_drive_strength", "gear_timing_scale"]:
		result[key] = profile.get(key)
	return result


func _dispose() -> void:
	_observe_enabled = false
	if is_instance_valid(_boundary):
		_water_receipts.assign(_boundary.water_commits.duplicate(true))
	if is_instance_valid(_lab):
		if _lab._at_bat_cadence != null:
			_lab._at_bat_cadence.stop()
		_lab.queue_free()
		await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())


func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _q(value: Quaternion) -> Array:
	return [value.x, value.y, value.z, value.w]


func _check(value: bool, label: String) -> bool:
	_checks += 1
	if not value:
		_failed.append(label)
		push_error("POOL_PARTY_PITCHED: " + label)
	return value


func _admit_output() -> bool:
	# The root runner separately admits this path beneath its own output root.
	# Refuse accidental project/user paths, traversal, oversized receipts or overwrites.
	return _output.is_absolute_path() and _output.begins_with("/") \
		and _output.length() <= 512 and _output.to_utf8_buffer().size() <= 1024 \
		and _output.simplify_path() == _output \
		and _output.get_extension() == "json" and not _output.contains("://") \
		and not _output.contains("\n") and not _output.contains("\r") \
		and DirAccess.dir_exists_absolute(_output.get_base_dir()) \
		and not FileAccess.file_exists(_output)


func _finish() -> void:
	var water: Array = _boundary.water_commits.duplicate(true) if is_instance_valid(_boundary) \
		else _water_receipts
	var evidence: Dictionary = {"case": _case, "qualification": _case.ends_with("water")
		or _case.ends_with("solid"), "checks": _checks, "failures": _failed,
		"native_target_passed": _failed.is_empty() and (_case.ends_with("water")
			or _case.ends_with("solid")), "requested_inputs": _requested,
		"release": _release, "launch": _launch, "pitch_trace": _trace,
		"solid_events": _solid_events, "water_commits": water, "water_observed_frames": _water_frames,
		"terminal": _terminal, "route_checks": _route_checks,
		"closest_pool_distance": _closest_pool if is_finite(_closest_pool) else -1,
		"closest_pool_position": _v(_closest_point)}
	var encoded: String = JSON.stringify(evidence, "", true, true)
	if encoded.to_utf8_buffer().size() > MAX_EVIDENCE_BYTES:
		_check(false, "bounded two-MiB genuine native evidence")
		encoded = JSON.stringify({"case": _case, "failures": _failed,
			"native_target_passed": false, "evidence_overflow": true})
	var receipt: Dictionary = {"case": _case, "written": false}
	if _output_admitted:
		var file: FileAccess = FileAccess.open(_output, FileAccess.WRITE)
		if _check(file != null, "complete native evidence JSON file opened"):
			file.store_string(encoded)
			file.flush()
			var error: Error = file.get_error()
			file.close()
			if _check(error == OK, "complete native evidence JSON file flushed"):
				receipt = {"case": _case, "written": true, "path": _output,
					"bytes": encoded.to_utf8_buffer().size(),
					"sha256": FileAccess.get_sha256(_output)}
	print("POOL_PARTY_PITCHED_EVIDENCE ", JSON.stringify(receipt, "", true, true))
	print("POOL_PARTY_PITCHED_CONTACTS case=%s checks=%d failures=%d" % [
		_case, _checks, _failed.size()])
	get_tree().quit(0 if _failed.is_empty() else 1)


func _ray_diagnostic(probe: Node3D, target: Vector3) -> void:
	# One failure-only read of actual authority/native-space and exact unchanged ray operands.
	var start: Vector3 = probe.global_position + Vector3.UP * maxf(0.3, target.y)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, target, 1)
	var hit: Dictionary = probe.get_world_3d().direct_space_state.intersect_ray(query)
	var bodies: Array[Dictionary] = []
	for body: StaticBody3D in _boundary.pool_bodies:
		var shapes: Array[bool] = []
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				shapes.append(child.disabled)
		bodies.append({"name": String(body.name), "layer": body.collision_layer,
			"mask": body.collision_mask, "disable_mode": body.disable_mode,
			"inside_tree": body.is_inside_tree(), "can_process": body.can_process(),
			"native_space_matches": PhysicsServer3D.body_get_space(body.get_rid())
				== probe.get_world_3d().space, "shapes_disabled": shapes})
	print("POOL_PARTY_RAY_DIAGNOSTIC ", JSON.stringify({"issued": _property.issued,
		"suspended": _property.suspended, "retirement_reason": _property.retirement_reason,
		"lab_process_mode": _lab.process_mode, "has_stadium_property": _lab.has_meta("stadium_property"),
		"boundary_connections": _boundary.contact_applied.get_connections().size(),
		"start": _v(start), "target": _v(target), "mask": query.collision_mask,
		"hit_back_faces": query.hit_back_faces, "hit_from_inside": query.hit_from_inside,
		"native_hit": String(hit.collider.name) if hit.has("collider") else "",
		"bodies": bodies}))
