extends Node3D
## Actual neutral entry and staged public-owner lifecycle only. Zero games or contacts.
## Explicit test fixture participants are never saved as earned progression.

const F = preload("res://src/tests/hillside_public_fixture.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
@export_enum("roles", "lifecycle") var suite: String = "roles"
var _checks: int = 0
var _failures: int = 0
var _starts: int = 0
var _admitted: int = 0
var _refusals: int = 0
var _rollbacks: int = 0
var _app: SeasonApp


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var saved_path: String = SeasonSave.path
	var settings_path: String = PitchBatLabSettings.path
	SeasonSave.path = "user://hillside-public-admission-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://hillside-public-admission-%d.cfg" % OS.get_process_id()
	_check(
		(
			OS.get_cmdline_user_args().is_empty()
			and (
				(
					suite == "roles"
					and scene_file_path == "res://src/tests/hillside_public_admission_test.tscn"
				)
				or (
					suite == "lifecycle"
					and scene_file_path == "res://src/tests/hillside_public_lifecycle_test.tscn"
				)
			)
		),
		"exact scene-bound suite with no selectors or alternate inputs"
	)
	_check(
		(
			not FileAccess.file_exists(SeasonSave.path)
			and not FileAccess.file_exists(SeasonSave.path + ".bak")
		),
		"isolated absent save inputs"
	)
	_check(R.source_qualified() and F.ready(), "exact composed source and explicit final ready")
	if _failures == 0:
		_freed_adapter_references()
	if _failures == 0:
		_app = SeasonApp.new()
		add_child(_app)
		_app.set_process(false)
		_app.child_entered_tree.connect(
			func(node: Node) -> void:
				if node is PitchBatLab:
					_starts += 1
		)
		if suite == "roles":
			for home: bool in [true, false]:
				await _orientation(home)
				if _failures > 0:
					break
		else:
			if _failures == 0:
				await _cancel_pending_app()
			if _failures == 0:
				await _replace_pending_season()
			if _failures == 0:
				for deferred: bool in [false, true]:
					await _replace_pending_context(deferred)
					if _failures > 0:
						break
			if _failures == 0:
				for mode: String in ["support", "remove"]:
					await _rollback(mode)
					if _failures > 0:
						break
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
		await get_tree().process_frame
	_check(
		(
			not FileAccess.file_exists(SeasonSave.path)
			and not FileAccess.file_exists(SeasonSave.path + ".bak")
		),
		"explicit admission participants were never persisted or rewarded"
	)
	SeasonSave.path = saved_path
	PitchBatLabSettings.path = settings_path
	await TestAudioDrain.finish(get_tree())
	if suite == "roles":
		_check(
			_starts == 2 and _admitted == 2 and _refusals == 7 and _rollbacks == 0,
			"exact two admissions and seven pre-entry refusals"
		)
	else:
		_check(
			_starts == 2 and _admitted == 0 and _refusals == 0 and _rollbacks == 2,
			"exact close/replacement cancellations and two rollbacks without admitted play"
		)
	var summary: String = (
		"HILLSIDE_PUBLIC_ADMISSION" if suite == "roles" else "HILLSIDE_PUBLIC_LIFECYCLE"
	)
	print(
		(
			summary
			+ (
				" checks=%d failures=%d starts=%d admitted=%d refusals=%d rollbacks=%d games=0"
				% [_checks, _failures, _starts, _admitted, _refusals, _rollbacks]
			)
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _freed_adapter_references() -> void:
	var adapter: StadiumHillsidePublicContactAdapter = StadiumHillsidePublicContactAdapter.new()
	var freed_source: Variant = StadiumHillsidePublicBoundarySource.new()
	var freed_owner: Variant = StadiumNpcPublicProperty.new()
	freed_source.free()
	freed_owner.free()
	var source_refused: bool = not adapter.configure(freed_source)
	var owner_refused: bool = not adapter.bind_public_property(freed_owner)
	_check(
		source_refused and owner_refused and not adapter.dynamic_intact(),
		"freed raw source/owner arguments refuse before typed dereference"
	)
	adapter.free()
	var construction: StadiumHillsidePublicConstruction = StadiumHillsidePublicConstruction.build()
	var owner: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	owner.venue_id = "HILLSIDE"
	owner.construction = construction
	owner.add_child(construction)
	adapter = StadiumHillsidePublicContactAdapter.new()
	owner.add_child(adapter)
	owner.boundary = adapter
	var configured: bool = (
		adapter.configure(construction.boundary) and adapter.bind_public_property(owner)
	)
	var initial: bool = configured and adapter.dynamic_intact()
	# The graph is RefCounted, strongly retained by both source and adapter; normal lifetime
	# cannot free it independently. A missing graph still must reject before method access.
	var graph: StadiumHillsidePublicBoundary = adapter.graph
	adapter.graph = null
	var graph_refused: bool = not adapter.dynamic_intact()
	adapter.graph = graph
	construction.free()
	var construction_refused: bool = not adapter.dynamic_intact()
	_check(
		initial and graph_refused and construction_refused,
		"captured adapter rejects missing graph and freed construction without engine errors"
	)
	owner.free()


func _season(home: bool) -> SeasonState:
	var season: SeasonState = F.season()
	if season != null:
		F.fixture(season, home)
		season.phase = SeasonState.Phase.FINAL
	return season


func _orientation(home: bool) -> void:
	var season: SeasonState = _season(home)
	_check(season != null, "actual draft and explicit pre-draft final exist")
	if season == null:
		return
	_app.season = season
	_app._fixture_id = 32
	var state: MatchState = season.make_match()
	_check(
		(
			state != null
			and state.stadium.get("version") == 25
			and StadiumNpcSnapshot.matches_fixture(state.stadium, season, season.pending_fixture())
		),
		"exact neutral snapshot25 binds this participant orientation"
	)
	if state == null:
		return
	_check(
		(
			(
				SeasonPages.venue(season.pending_fixture(), season)
				== "Neutral final • Hillside • " + ("You pitch first" if home else "You bat first")
			)
			and StadiumFixtureEnvironment.label(season, season.pending_fixture()) == "13:10 • Clear"
		),
		"ordinary labels preserve exact venue, fixed daytime and independent batting order"
	)
	_reject(state, not home, true, &"field.npc_venue", "wrong player orientation")
	if home:
		_reject(
			state, home, false, &"field.npc_venue", "exhibition cannot borrow neutral authority"
		)
		_reject(state, home, true, PitchBatLab.FIELD_ID, "wrong field")
		var original: Dictionary = state.stadium.duplicate(true)
		for key: String in ["version", "venue_owner", "profile"]:
			match key:
				"version":
					state.stadium.version = 24
				"venue_owner":
					state.stadium.binding.venue_owner = "npc-owner:1"
				"profile":
					state.stadium.environment.profile = "foreign"
			_reject(state, home, true, &"field.npc_venue", "changed " + key)
			state.stadium = original.duplicate(true)
	if _failures > 0:
		return
	state.stadium = JSON.parse_string(JSON.stringify(state.stadium, "", true, true))
	_check(
		(
			typeof(state.stadium.version) == TYPE_FLOAT
			and StadiumNpcSnapshot.matches_fixture(state.stadium, season, season.pending_fixture())
		),
		"full precision decoded snapshot retains strict native fixture binding"
	)
	var before: Dictionary = _season_data(season)
	_app.notice = ""
	_app._open_match(state, home, true, &"field.npc_venue")
	var lab: PitchBatLab = _app.lab
	var property: StadiumNpcPublicProperty = R._property(lab) if is_instance_valid(lab) else null
	_check(
		(
			is_instance_valid(lab)
			and is_instance_valid(property)
			and not lab.yard_bound_startup_failed
		),
		"actual SeasonApp creates the pending captured lab"
	)
	if not is_instance_valid(lab) or not is_instance_valid(property):
		return
	_pending(lab, property)
	var completion: Dictionary = {"values": []}
	lab.hillside_public_install_finished.connect(
		func(success: bool) -> void: completion.values.append(success)
	)
	await _wait_completion(completion)
	_check(
		completion.values == [true] and _app.lab == lab and _app.notice.is_empty(),
		"one successful registration completes the same app entry"
	)
	if not is_instance_valid(lab) or completion.values != [true]:
		return
	_check(
		(
			property.issued
			and not property.suspended
			and lab.hillside_public_pending == null
			and R.installed_bound(lab, state.stadium)
			and StadiumPropertyRuntime.npc_installed_bound(lab, state.stadium)
		),
		"cold and issued public authorities agree only after support registration"
	)
	_check(
		(
			lab._managed_match
			and lab._npc_season == season
			and lab._player_home == home
			and lab._stadium_ledger == null
			and property.objects.size() == 8
			and property.venue_id == "HILLSIDE"
			and property.tier == "expanded"
			and typeof(property.field.id) == TYPE_STRING_NAME
			and _app._played_field_matches()
		),
		"issued eight-copy neutral park uses actual app ownership and typed field"
	)
	_check(
		(
			lab.hillside_private_runtime == null
			and lab._hillside_private_owner_identity == null
			and not lab.has_node("HillsidePrivateRuntime")
			and property.hillside_support.bound_intact()
			and property.hillside_support.primary_motion != property.hillside_support.pitcher_motion
		),
		"one public owner binds independent primary and pitcher support without private authority"
	)
	var primary: FielderController = lab._primary_fielder
	_check(
		(
			(
				primary.anchor_position
				== StadiumHillsideTerrain.point(0, property.field.deep_anchor_z_m)
			)
			and (
				lab._pitcher_marker.global_position
				== StadiumHillsideTerrain.point(0, lab.MOUND_ORIGIN.z)
			)
			and lab._fielder_anchor_index == 7
		),
		"actual starting feet use the retained available slots"
	)
	var anchors: bool = true
	var supported_slots: Array[int] = []
	var anchor_records: int = 0
	for index in range(StadiumHillsideAnchorContract.SLOT_COUNT):
		var record: Dictionary = StadiumHillsideAnchorContract.anchor(property.field, index, "hill")
		anchors = (
			anchors
			and not record.is_empty()
			and typeof(record.get("available")) == TYPE_BOOL
			and record.available == property.field.is_fielder_anchor_available(index)
		)
		if record.is_empty():
			continue
		anchor_records += 1
		if not record.get("available", false):
			continue
		supported_slots.append(index)
		anchors = (
			anchors
			and property.hillside_support.primary_motion._physical_support(primary, record.position)
		)
	_check(
		anchors and anchor_records == 9 and supported_slots == [0, 2, 3, 5, 6, 7, 8],
		"all nine records retain exact availability; seven selectable rays include deep-left slot8"
	)
	var motion: StadiumHillsideDefenderMotion = property.hillside_support.primary_motion
	var original_pose: Transform3D = primary.transform
	var original_anchor: Vector3 = primary.anchor_position
	var original_target: Vector3 = primary.target_position
	var original_velocity: Vector3 = primary.velocity
	for unavailable: int in [1, 4]:
		var refused: bool = not motion.set_anchor(
			primary, property.field.fielder_anchor(unavailable)
		)
		lab._select_fielder_anchor(unavailable)
		_check(
			(
				refused
				and not property.field.is_fielder_anchor_available(unavailable)
				and motion.last_error.contains("unavailable")
				and not motion.blocked
				and primary.hillside_motion == motion
				and primary.transform == original_pose
				and primary.anchor_position == original_anchor
				and primary.target_position == original_target
				and primary.velocity == original_velocity
				and motion.anchor_index == 7
				and lab._fielder_anchor_index == 7
				and property.issued
				and not property.suspended
			),
			(
				"disabled slot%d refuses through actual motion and lab selection without changing default7"
				% unavailable
			)
		)
	_check(
		(
			property.display == null
			and property.score_display_intact()
			and property.route_obstacles().is_empty()
			and property.receiver.get_script() == StadiumHillsidePublicReceiver
		),
		"HUD-only exact recipe retains paired receiver and no optional live obstacles"
	)
	_check(
		(
			StadiumHillsideEnvironmentV1.installed(lab, property.environment_lease)
			and state.stadium.environment.profile == StadiumHillsideEnvironmentV1.PROFILE
			and state.stadium.binding.venue_owner == SeasonFinalVenue.HILLSIDE_OWNER
		),
		"same-origin lighting lease and exact saved neutral owner are installed"
	)
	_check(
		(
			(
				PhysicalStadiumReport.npc_resolver(state.stadium)
				== StadiumHillsidePublicReport.RESOLVER
			)
			and StadiumNpcYardTwoHumanEvidence.expected(season, season.pending_fixture())
		),
		"actual snapshot selects Hillside report and human evidence contracts"
	)
	_check(
		(
			ClubCareer.same(before, _season_data(season))
			and lab._play_records.is_empty()
			and PhysicalMatchReport.capture(lab).is_empty()
			and StadiumNpcYardTwoHumanEvidence.capture(lab, season).is_empty()
		),
		"entry creates no play history, full report, award or season settlement"
	)
	if _failures == 0:
		_admitted += 1
	var live: WeakRef = weakref(lab)
	_app._close_match()
	await get_tree().process_frame
	_check(_app.lab == null and live.get_ref() == null, "ordinary app close disposes issued lab")


func _pending(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	_check(
		(
			R.pending_hillside(lab)
			and lab.hillside_public_pending == property
			and not property.issued
			and not R.installed(lab)
		),
		"pending geometry cannot claim issued admission"
	)
	_check(
		(
			lab.process_mode == Node.PROCESS_MODE_DISABLED
			and property.construction.process_mode == Node.PROCESS_MODE_ALWAYS
			and property.hillside_support.pending
		),
		"static collision registration runs while gameplay is held"
	)
	_check(
		(
			not is_instance_valid(lab._batted_ball)
			and lab._play_records.is_empty()
			and not R.admits_action(lab)
		),
		"no delivery or action is admitted pending support"
	)


func _wait_completion(completion: Dictionary) -> void:
	for _frame in range(8):
		await get_tree().physics_frame
		await get_tree().process_frame
		if not completion.values.is_empty():
			return


func _cancel_pending_app() -> void:
	var season: SeasonState = _season(false)
	_check(season != null, "cancel control has a real drafted season")
	if season == null:
		return
	_app.season = season
	_app._fixture_id = 32
	var before: Dictionary = _season_data(season)
	_app._open_match(season.make_match(), false, true, &"field.npc_venue")
	var lab: PitchBatLab = _app.lab
	var property: StadiumNpcPublicProperty = R._property(lab) if is_instance_valid(lab) else null
	_check(
		is_instance_valid(lab) and is_instance_valid(property) and R.pending_hillside(lab),
		"cancel starts during exact pending phase"
	)
	if not is_instance_valid(lab) or not is_instance_valid(property):
		return
	var lab_ref: WeakRef = weakref(lab)
	var property_ref: WeakRef = weakref(property)
	var completion: Dictionary = {"values": []}
	lab.hillside_public_install_finished.connect(
		func(success: bool) -> void: completion.values.append(success)
	)
	_app._close_match()
	for _frame in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame
	_check(
		(
			_app.lab == null
			and lab_ref.get_ref() == null
			and property_ref.get_ref() == null
			and not completion.values.has(true)
		),
		"cancelled captured owner never issues or resumes later"
	)
	_check(
		ClubCareer.same(before, _season_data(season)),
		"pending cancel leaves actual season unchanged"
	)


func _replace_pending_season() -> void:
	var original: SeasonState = _season(false)
	var replacement: SeasonState = _season(true)
	_check(
		original != null and replacement != null and original != replacement,
		"replacement control has two independent real drafted season objects"
	)
	if original == null or replacement == null:
		return
	_app.season = original
	_app._fixture_id = 32
	var before_original: Dictionary = _season_data(original)
	var before_replacement: Dictionary = _season_data(replacement)
	_app.notice = ""
	_app._open_match(original.make_match(), false, true, &"field.npc_venue")
	var captured: PitchBatLab = _app.lab
	var property: StadiumNpcPublicProperty = (
		R._property(captured) if is_instance_valid(captured) else null
	)
	_check(
		(
			is_instance_valid(captured)
			and is_instance_valid(property)
			and R.pending_hillside(captured)
		),
		"season replacement occurs only after the original pending lab is captured"
	)
	if not is_instance_valid(captured) or not is_instance_valid(property):
		return
	var captured_ref: WeakRef = weakref(captured)
	var property_ref: WeakRef = weakref(property)
	var completion: Dictionary = {"values": []}
	captured.hillside_public_install_finished.connect(
		func(success: bool) -> void: completion.values.append(success)
	)
	_app.season = replacement
	await _wait_completion(completion)
	await get_tree().process_frame
	_check(
		(
			completion.values.size() == 1
			and _app.lab == null
			and _app.season == replacement
			and _app.notice == "The neutral field could not start. Your saved season is unchanged."
		),
		"captured pending completion cannot admit its lab into a replacement season"
	)
	_check(
		captured_ref.get_ref() == null and property_ref.get_ref() == null,
		"stale captured lab and its property are both disposed before another entry"
	)
	_check(
		(
			ClubCareer.same(before_original, _season_data(original))
			and ClubCareer.same(before_replacement, _season_data(replacement))
		),
		"late completion changes neither original nor replacement season history"
	)


func _replace_pending_context(deferred: bool) -> void:
	# Adversarial ownership mutation on a real pending lab, not a replacement admission.
	var season: SeasonState = _season(false)
	_check(season != null, "reused-lab replacement begins with actual drafted season")
	if season == null:
		return
	var before: Dictionary = _season_data(season)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = season.make_match()
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	lab._player_home = false
	add_child(lab)
	var captured: StadiumNpcPublicProperty = R._property(lab)
	_check(
		is_instance_valid(captured) and R.pending_hillside(lab),
		"reused-lab mutation occurs before the captured property is issued"
	)
	if not is_instance_valid(captured):
		lab.queue_free()
		await get_tree().process_frame
		return
	var captured_ref: WeakRef = weakref(captured)
	var originals: Array[WeakRef] = []
	for node: Node in captured.old_nodes:
		originals.append(weakref(node))
	var host: Node = lab.get_node("StarterFieldGeometry")
	var expected_children: Array[Node] = host.get_children()
	expected_children.erase(captured)
	var replacement_state: MatchState = season.make_match()
	var replacement_owner: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	replacement_owner.venue_id = "HILLSIDE"
	replacement_owner.bound_state = replacement_state
	var replacement_field: FieldDefinition = captured.field.duplicate(true)
	var replacement_automation: MatchAutomation = MatchAutomation.new()
	var replacement_environment: Environment = Environment.new()
	var replacement_camera: StadiumExpandedCameraDirector = StadiumExpandedCameraDirector.new()
	var sun: DirectionalLight3D = captured.environment_lease.sun
	if deferred:
		# Begin valid owned teardown, then replace context before its queued restoration.
		R._restore(lab, captured)
		captured.queue_free()
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._match_state = replacement_state
	for marker: String in ["stadium_npc_runtime_interrupted", "stadium_npc_runtime_restoring"]:
		if lab.has_meta(marker):
			lab.remove_meta(marker)
	lab.set_meta("stadium_property", replacement_owner)
	lab.hillside_public_pending = replacement_owner
	lab._hillside_public_install_state = replacement_state
	lab._hillside_public_install_reported = false
	lab._automation = replacement_automation
	lab._field_definition = replacement_field
	lab._field_id = &"field.npc_venue"
	lab._camera_director = replacement_camera
	lab._camera.cull_mask = 321
	lab._ball_play_resolver.segment_observer = _replacement_observer
	lab._primary_fielder.stadium_boundary_clip = _replacement_clip
	lab._pitch_actor.receiver_router = _replacement_receiver
	lab._primary_fielder.position = Vector3(2, 1, 3)
	lab._primary_fielder.anchor_position = Vector3(4, 1, 5)
	lab._pitcher_marker.position = Vector3(-2, 0, 6)
	lab.hillside_pitcher_target = Vector3(3, 1, 8)
	lab._fielder_anchor_index = 4
	lab.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	lab._world_environment.environment = replacement_environment
	sun.rotation = Vector3(0.1, 0.2, 0.3)
	var sun_rotation: Vector3 = sun.rotation
	var completion: Dictionary = {"values": []}
	lab.hillside_public_install_finished.connect(
		func(success: bool) -> void: completion.values.append(success)
	)
	for _frame in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame
	_check(captured_ref.get_ref() == null, "only the stale captured property is disposed")
	_check(
		(
			lab._match_state == replacement_state
			and R._property(lab) == replacement_owner
			and not replacement_owner.issued
			and not replacement_owner.suspended
		),
		"late cleanup leaves replacement state and non-issued owner sentinel untouched"
	)
	_check(
		(
			lab._primary_fielder.position == Vector3(2, 1, 3)
			and lab._primary_fielder.anchor_position == Vector3(4, 1, 5)
			and lab._pitcher_marker.position == Vector3(-2, 0, 6)
			and lab.hillside_pitcher_target == Vector3(3, 1, 8)
			and lab._fielder_anchor_index == 4
		),
		"late cleanup cannot overwrite reused actor poses, targets or anchor selection"
	)
	_check(
		(
			lab._field_definition == replacement_field
			and lab._field_id == &"field.npc_venue"
			and lab._camera_director == replacement_camera
			and lab._camera.cull_mask == 321
			and lab._ball_play_resolver.segment_observer == _replacement_observer
			and lab._primary_fielder.stadium_boundary_clip == _replacement_clip
			and lab._pitch_actor.receiver_router == _replacement_receiver
		),
		"late cleanup cannot overwrite replacement field, camera or callbacks"
	)
	_check(
		(
			lab._world_environment.environment == replacement_environment
			and sun.rotation == sun_rotation
		),
		"stale lease abandonment never writes replacement environment resources"
	)
	_check(
		(
			lab.process_mode == Node.PROCESS_MODE_WHEN_PAUSED
			and lab._automation == replacement_automation
			and lab.hillside_public_pending == replacement_owner
			and lab._hillside_public_install_state == replacement_state
			and not lab._hillside_public_install_reported
			and completion.values.is_empty()
			and not lab.has_meta("stadium_npc_runtime_interrupted")
			and not lab.has_meta("stadium_npc_runtime_restoring")
		),
		"replacement processing, pending handshake and authority markers are not rewritten"
	)
	var disposed: bool = true
	for reference: WeakRef in originals:
		disposed = disposed and reference.get_ref() == null
	_check(
		disposed and host.get_children() == expected_children,
		"detached captured originals are disposed without inserting stale host geometry"
	)
	_check(
		(
			ClubCareer.same(before, _season_data(season))
			and lab._play_records.is_empty()
			and not is_instance_valid(lab._batted_ball)
		),
		"ownership mutation creates no play or season history"
	)
	lab.remove_meta("stadium_property")
	lab.hillside_public_pending = null
	lab._automation = null
	replacement_owner.free()
	lab.queue_free()
	await get_tree().process_frame


func _replacement_observer(
	_resolver: BallPlayResolver, _previous: Vector3, _current: Vector3
) -> Dictionary:
	return {}


func _replacement_clip(_from: Vector3, to: Vector3) -> Vector3:
	return to


func _replacement_receiver(_actor: PitchFlightActor, _start: Vector3, _velocity: Vector3) -> bool:
	return false


func _rollback(mode: String) -> void:
	var season: SeasonState = _season(false)
	_check(season != null, mode + " rollback uses actual drafted state")
	if season == null:
		return
	var before: Dictionary = _season_data(season)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = season.make_match()
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	lab._player_home = false
	add_child(lab)
	var property: StadiumNpcPublicProperty = R._property(lab)
	_check(
		is_instance_valid(property) and R.pending_hillside(lab), mode + " is captured before issue"
	)
	if not is_instance_valid(property):
		lab.queue_free()
		await get_tree().process_frame
		return
	var support: StadiumHillsidePublicSupport = property.hillside_support
	var lease: Dictionary = property.environment_lease.duplicate(false)
	var old_nodes: Array[Node] = property.host_children.duplicate()
	var old_field: FieldDefinition = property.old_field
	var old_observer: Callable = property.old_observer
	var old_clip: Callable = property.old_clip
	var old_receiver: Callable = property.old_receiver
	var completion: Dictionary = {"values": []}
	lab.hillside_public_install_finished.connect(
		func(success: bool) -> void: completion.values.append(success)
	)
	if mode == "support":
		var body: StaticBody3D = property.construction.terrain.get_node("TerrainCollision")
		body.collision_layer = 0
	else:
		property.get_parent().remove_child(property)
		property.queue_free()
	await _wait_completion(completion)
	await get_tree().process_frame
	_check(
		(
			completion.values == [false]
			and not R.installed(lab)
			and lab.hillside_public_pending == null
		),
		mode + " reports one refusal and never issues"
	)
	_check(
		(
			lab.process_mode == Node.PROCESS_MODE_DISABLED
			and lab.has_meta("stadium_npc_runtime_interrupted")
			and not lab.has_meta("stadium_npc_runtime_restoring")
			and not lab.has_meta("stadium_property")
		),
		mode + " restoration remains safely held"
	)
	_check(
		(
			lab.get_node("StarterFieldGeometry").get_children() == old_nodes
			and lab._field_definition == old_field
			and lab._ball_play_resolver.segment_observer == old_observer
			and lab._primary_fielder.stadium_boundary_clip == old_clip
			and lab._pitch_actor.receiver_router == old_receiver
		),
		mode + " restores exact original host order, field and ordinary callbacks"
	)
	_check(
		(
			lab._primary_fielder.hillside_motion == support._old_primary_motion
			and lab.hillside_pitcher_motion == support._old_pitcher_motion
			and lab._primary_fielder.transform == support._before.transform
			and lab._primary_fielder.anchor_position == support._before.anchor_position
			and lab._pitcher_marker.transform == support._old_pitcher_transform
			and lab.hillside_pitcher_target == support._old_pitcher_target
		),
		mode + " restores exact captured actor poses and independent motion identities"
	)
	_check(
		(
			lab._world_environment.environment == lease.before_environment
			and lease.sun.rotation == lease.before_rotation
			and lease.sun.light_energy == lease.before_energy
			and lease.sun.light_color == lease.before_color
			and lease.sun.shadow_enabled == lease.before_shadows
		),
		mode + " restores the captured light and same-origin environment"
	)
	_check(
		(
			ClubCareer.same(before, _season_data(season))
			and lab._play_records.is_empty()
			and PhysicalMatchReport.capture(lab).is_empty()
			and not is_instance_valid(lab._batted_ball)
		),
		mode + " cannot fabricate contact, report or season history"
	)
	if _failures == 0:
		_rollbacks += 1
	lab.queue_free()
	await get_tree().process_frame


func _reject(
	state: MatchState, home: bool, managed: bool, field: StringName, label: String
) -> void:
	var before: Dictionary = _season_data(_app.season)
	var children: Array[Node] = _app.get_children()
	var starts: int = _starts
	_app.notice = ""
	_app._open_match(state, home, managed, field)
	var refused: bool = _app.lab == null and _starts == starts and not _app.notice.is_empty()
	_check(
		(
			refused
			and _app.get_children() == children
			and ClubCareer.same(before, _season_data(_app.season))
		),
		"pre-entry refusal: " + label
	)
	if refused:
		_refusals += 1


func _season_data(season: SeasonState) -> Dictionary:
	if season == null:
		return {}
	return {
		"final_venue": season.final_venue.duplicate(true),
		"npc_venues": season.npc_venues.duplicate(true),
		"home_property": season.home_property.duplicate(true),
		"fixture": season.final_fixture.duplicate(true),
		"phase": season.phase,
		"results": season.results.duplicate(true),
		"player_results": season.player_results.duplicate(true),
		"physical": season.physical.to_data(),
		"career": season.career.to_data(),
		"build": season.build.to_data(),
		"opponents": season.opponents.to_data()
	}


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("HILLSIDE_PUBLIC_ADMISSION " + label)
