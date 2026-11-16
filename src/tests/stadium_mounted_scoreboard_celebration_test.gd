extends "res://src/tests/stadium_mounted_scoreboard_runtime_test.gd"
## Exact paid center presentation. Positive HR evidence comes only from real physical scoring.

# Pinned contract budgets, independent of production constants.
const FLIGHT_LIMIT: float = 6.0
const LANDING_CONTEXT: float = 0.65
const HOLD_MINIMUM: float = 4.4
const TAIL_MINIMUM: float = 0.65
const RETURN_LIMIT: float = 4.0
const SAMPLE_SLACK: float = 0.1
var _carries: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_motion_selection()
	await _presentation_contract()
	await _real_carry(false)
	await _real_carry(true)
	_check(_carries == 2, "ordinary and managed/automated scored-HR lifecycles both exercised")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard celebration passed: exact binding and genuine HR lifecycle.")
	get_tree().quit(0 if _failures == 0 else 1)


func _motion_selection() -> void:
	var legacy: BallInPlayCamera = BallInPlayCamera.new()
	var mounted: StadiumMountedCameraMotion = StadiumMountedCameraMotion.new()
	for defense: bool in [false, true]:
		for launch: Vector3 in [Vector3(-4, 18, 30), Vector3(4, 18, 30),
			Vector3(0, 18, 30), Vector3(4, 2, 30), Vector3(4, 18, -30), Vector3(1, 18, 30)]:
			legacy.prepare(defense, Vector3(0, 1, 0.28), launch)
			mounted.prepare(defense, Vector3(0, 1, 0.28), launch)
			var side: float = signf(launch.x) if defense and launch.z > 0 \
				and launch.y > 3 and absf(launch.x) > 1 else legacy._side
			_check(mounted._side == side, "same-side exception applies only to exact defense-air corridor")
			for field: String in ["_carry", "_ground_coverage", "_air_coverage", "_age",
				"_velocity", "_turn_speed", "_previous_ball", "_height", "_clearance_offset"]:
				_check(mounted.get(field) == legacy.get(field), "existing motion math remains exact: " + field)


func _presentation_contract() -> void:
	var data: Dictionary = _fixture("straight")
	if data.is_empty() or data.fixture.is_empty():
		return
	var lab: PitchBatLab = _lab(data.fixture, true)
	lab._camera_director.presentation_override = _foreign_override
	_refused(lab, data.ledger, "preexisting presentation override")
	lab._camera_director.presentation_override = Callable()
	var motion: BallInPlayCamera = lab._camera_director._live_coverage
	lab._camera_director._live_coverage = null
	_refused(lab, data.ledger, "missing live motion object")
	lab._camera_director._live_coverage = motion
	motion.framing_lead_degrees = 1
	_refused(lab, data.ledger, "unqualified preexisting motion configuration")
	motion.framing_lead_degrees = 0
	_startup_presentation_guards(lab, data)
	_check(StadiumScoreboardRuntime.install_mounted_bound(lab, data.ledger),
		"managed/automated startup binds exact center presentation without authoring flags")
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var helper: StadiumMountedScoreboardCelebration = property.celebration
	_check(helper != null and helper._eligible() and _valid(lab, data)
		and lab._camera_director._live_coverage is StadiumMountedCameraMotion
		and lab._camera_director.presentation_override == helper._update_camera
		and lab._ball_play_resolver.play_resolved.is_connected(helper._on_resolved),
		"normal owned helper owns exact center, motion, callback and scored listener")
	if helper == null:
		lab.free()
		return
	var pose: Transform3D = lab._camera.global_transform
	for result: int in [BallPlayOutcome.Result.HOME_RUN, BallPlayOutcome.Result.OUT,
		BallPlayOutcome.Result.FOUL, BallPlayOutcome.Result.SINGLE]:
		var unconfirmed: BallPlayOutcome = BallPlayOutcome.new()
		unconfirmed.result = result as BallPlayOutcome.Result
		helper._on_resolved(unconfirmed)
	_check(not helper.active and helper.starts == 0 and lab._camera.global_transform == pose,
		"unconfirmed HR and non-HR events cannot move the camera or start celebration")
	_tamper_motion(lab, data)
	_tamper_helper(lab, data, helper)
	_tamper_callback(lab, data, helper)
	_presentation_ids(lab, data)
	_native_scoring_order(lab, data, helper)
	_callback_safe_origins(lab, data, helper)
	_camera_target_guards(lab, data, true)
	_legacy_override_rejection(lab, data)
	var callback: Callable = helper._update_camera
	helper.free()
	property.celebration = null
	_check(lab._camera_director.presentation_override.is_null() and not callback.is_valid(),
		"helper teardown clears its exact callback without leaving a stale node target")
	lab.free()
	await get_tree().process_frame


func _startup_presentation_guards(lab: PitchBatLab, data: Dictionary) -> void:
	var director: MatchCameraDirector = lab._camera_director
	lab._camera_director = DifferentDirector.new()
	_refused(lab, data.ledger, "subclassed director cannot claim exact qualified script")
	lab._camera_director = director
	var scorer: Callable = lab._on_ball_play_resolved
	lab._ball_play_resolver.play_resolved.disconnect(scorer)
	_refused(lab, data.ledger, "missing native scoring listener before helper installation")
	lab._ball_play_resolver.play_resolved.connect(scorer, Object.CONNECT_DEFERRED)
	_refused(lab, data.ledger, "deferred native scorer cannot authorize same-frame handoff")
	lab._ball_play_resolver.play_resolved.disconnect(scorer)
	lab._ball_play_resolver.play_resolved.connect(scorer)
	_camera_target_guards(lab, data, false)


func _camera_target_guards(lab: PitchBatLab, data: Dictionary, installed: bool) -> void:
	var camera: Camera3D = lab._camera
	var index: int = camera.get_index()
	var pose: Transform3D = camera.transform
	var holder: Node3D = Node3D.new()
	lab.add_child(holder)
	for change: String in ["detached", "reparented", "renamed"]:
		match change:
			"detached": lab.remove_child(camera)
			"reparented": camera.reparent(holder)
			"renamed": camera.name = "WrongCamera"
		if installed:
			_rejected(lab, data, "actual camera target is " + change)
		else:
			_refused(lab, data.ledger, "startup camera target is " + change)
		if camera.get_parent() != lab:
			if camera.get_parent() != null:
				camera.get_parent().remove_child(camera)
			lab.add_child(camera)
		camera.name = "LabCamera"
		camera.transform = pose
		lab.move_child(camera, index)
	holder.free()
	if installed:
		_check(_valid(lab, data), "original named direct-child camera target restores")


func _native_scoring_order(lab: PitchBatLab, data: Dictionary,
	helper: StadiumMountedScoreboardCelebration) -> void:
	var scorer: Callable = lab._on_ball_play_resolved
	var resolved: Signal = lab._ball_play_resolver.play_resolved
	resolved.connect(_observe_outcome)
	_check(_valid(lab, data), "unrelated telemetry listener remains allowed")
	resolved.disconnect(scorer)
	_rejected(lab, data, "installed helper lost its authoritative native scorer")
	resolved.connect(scorer)
	_rejected(lab, data, "helper listener precedes native scoring after reorder")
	resolved.disconnect(helper._on_resolved)
	resolved.disconnect(scorer)
	resolved.connect(scorer)
	resolved.connect(helper._on_resolved)
	_check(_valid(lab, data) and resolved.is_connected(_observe_outcome),
		"native scorer-before-helper order restores without touching telemetry")
	resolved.disconnect(_observe_outcome)


func _callback_safe_origins(lab: PitchBatLab, data: Dictionary,
	helper: StadiumMountedScoreboardCelebration) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var snapshot: Variant = lab.get_meta("stadium_snapshot")
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	var pose: Transform3D = lab._camera.global_transform
	for malformed: Variant in [Vector3.ZERO, "forged", [], 15]:
		lab.set_meta("stadium_snapshot", malformed)
		_check(not helper._eligible(), "unlike-type snapshot rejects before callback dictionary access")
		helper._on_resolved(outcome)
		_check(not helper.active and helper.starts == 0 and lab._camera.global_transform == pose,
			"corrupt metadata cannot promote an unscored event or move the camera")
	lab.set_meta("stadium_snapshot", snapshot)
	var copy: String = data.fixture.layout.scoreboards[0].copy
	var board: Variant = property.objects[copy]
	for malformed: Variant in [Vector3.ZERO, "forged", {}, 17]:
		property.objects[copy] = malformed
		_check(not helper._eligible(), "corrupted complete-object map fails callback eligibility safely")
		helper._on_resolved(outcome)
		_check(not helper.active and helper.starts == 0 and lab._camera.global_transform == pose,
			"unlike-type model reference cannot promote an unscored event")
	property.objects[copy] = board
	_check(_valid(lab, data), "safe origin-negative controls restore the genuine binding")


func _tamper_motion(lab: PitchBatLab, data: Dictionary) -> void:
	var motion: BallInPlayCamera = lab._camera_director._live_coverage
	for replacement: BallInPlayCamera in [BallInPlayCamera.new(), StadiumMountedCameraMotion.new()]:
		lab._camera_director._live_coverage = replacement
		_rejected(lab, data, "replacement motion type or identical-looking instance")
	lab._camera_director._live_coverage = motion
	motion.framing_lead_degrees = 1
	_rejected(lab, data, "unexpected framing-lead configuration")
	motion.framing_lead_degrees = 0
	motion.position_filter = _pass_position
	_rejected(lab, data, "unexpected motion-filter callback")
	motion.position_filter = Callable()
	_check(_valid(lab, data), "exact qualified motion object and static configuration restore")


func _tamper_helper(lab: PitchBatLab, data: Dictionary,
	helper: StadiumMountedScoreboardCelebration) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	for field: String in ["_lab", "_board", "_property", "_director", "_resolver",
		"_camera", "_match"]:
		var original: Variant = helper.get(field)
		helper.set(field, null)
		_rejected(lab, data, "helper binding removed: " + field)
		helper.set(field, original)
	var frozen: Dictionary = helper._frozen.duplicate(true)
	helper._frozen.revision += 1
	_rejected(lab, data, "helper frozen snapshot differs from installed paid prefix")
	helper._frozen = frozen
	var mode: int = helper.process_mode
	helper.process_mode = Node.PROCESS_MODE_ALWAYS
	_rejected(lab, data, "helper cannot bypass ordinary tree pause")
	helper.process_mode = mode as Node.ProcessMode
	var priority: int = helper.process_priority
	helper.process_priority = 0
	_rejected(lab, data, "helper lifecycle priority changed")
	helper.process_priority = priority
	helper.set_process(false)
	_rejected(lab, data, "helper lifecycle process disabled")
	helper.set_process(true)
	var replacement: StadiumMountedScoreboardCelebration = DifferentCelebration.new()
	property.add_child(replacement)
	property.celebration = replacement
	_rejected(lab, data, "replacement celebration helper cannot impersonate installed identity")
	property.celebration = helper
	replacement.free()
	_check(_valid(lab, data), "helper references, snapshot and configuration restore")


func _tamper_callback(lab: PitchBatLab, data: Dictionary,
	helper: StadiumMountedScoreboardCelebration) -> void:
	var director: MatchCameraDirector = lab._camera_director
	for callback: Callable in [Callable(), _foreign_override, helper.reset,
		helper._update_camera.bind(17)]:
		director.presentation_override = callback
		_rejected(lab, data, "callback missing or has wrong target/method/bound arguments")
	director.presentation_override = helper._update_camera
	lab._ball_play_resolver.play_resolved.disconnect(helper._on_resolved)
	_rejected(lab, data, "scored-event listener disconnected")
	lab._ball_play_resolver.play_resolved.connect(helper._on_resolved, Object.CONNECT_DEFERRED)
	_rejected(lab, data, "scoring listener unexpectedly deferred")
	lab._ball_play_resolver.play_resolved.disconnect(helper._on_resolved)
	lab._ball_play_resolver.play_resolved.connect(helper._on_resolved)
	var replacement: Callable = helper._on_resolved.bind(17)
	lab._ball_play_resolver.play_resolved.disconnect(helper._on_resolved)
	var connected: Error = lab._ball_play_resolver.play_resolved.connect(replacement)
	_check(connected == OK, "bound-argument replacement listener connects after original removal")
	if connected == OK:
		_rejected(lab, data, "replacement helper listener has unexpected bound arguments")
		lab._ball_play_resolver.play_resolved.disconnect(replacement)
	_check(lab._ball_play_resolver.play_resolved.connect(helper._on_resolved) == OK,
		"original scored listener restores after bound-argument negative")
	var identity: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	var bad: Dictionary = identity.duplicate(true)
	bad.mounted_presentation = {}
	lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
	_rejected(lab, data, "missing complete presentation certificate")
	lab.set_meta(StadiumScoreboardRuntime.IDENTITY, identity)
	_check(_valid(lab, data), "callback ownership and listener restore exactly")


func _presentation_ids(lab: PitchBatLab, data: Dictionary) -> void:
	var identity: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	for section: String in ["motion", "helper"]:
		for key: String in (["id", "script", "camera"] if section == "helper" else ["id", "script"]):
			var bad: Dictionary = identity.duplicate(true)
			bad.mounted_presentation[section][key] = float(bad.mounted_presentation[section][key])
			lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
			_rejected(lab, data, "strict presentation object/script identity " + section + "/" + key)
	for key: String in ["director", "camera", "script"]:
		var bad: Dictionary = identity.duplicate(true)
		bad.mounted_presentation[key] = float(bad.mounted_presentation[key])
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected(lab, data, "strict director identity " + key)
	lab.set_meta(StadiumScoreboardRuntime.IDENTITY, identity)
	_check(_valid(lab, data), "strict presentation certificates restore")


func _legacy_override_rejection(center: PitchBatLab, data: Dictionary) -> void:
	var ledger: ClubAssetLedger = data.ledger
	_check(Data.apply(ledger, Data.layout14(ledger)), "old14 control is genuinely drafted and applied")
	var fixture: Dictionary = StadiumScoreboardSnapshot.fixture(
		StadiumScoreboardSnapshot.capture(ledger), 47, 0)
	var lab: PitchBatLab = _lab(fixture)
	_check(StadiumScoreboardRuntime.install_bound(lab)
		and StadiumScoreboardRuntime.installed(lab, fixture),
		"old14 control retains ordinary presentation")
	lab._camera_director.presentation_override = center._camera_director.presentation_override
	_check(not StadiumScoreboardRuntime.installed(lab, fixture),
		"old14 installed runtime rejects an unexpected nonempty presentation override")
	lab._camera_director.presentation_override = Callable()
	_check(StadiumScoreboardRuntime.installed(lab, fixture), "old14 empty override restores")
	lab.free()


func _real_carry(managed: bool) -> void:
	_check(PitchBatLabHomeRun.MAX_FLIGHT_SECONDS == FLIGHT_LIMIT
		and PitchBatLabHomeRun.LANDING_CONTEXT_SECONDS == LANDING_CONTEXT
		and PitchBatLabHomeRun.HOLD_SECONDS == HOLD_MINIMUM
		and PitchBatLabHomeRun.PRESENTATION_TAIL_SECONDS == TAIL_MINIMUM
		and PitchBatLabHomeRun.MAX_RETURN_SECONDS == RETURN_LIMIT,
		"observed-flight and return budgets retain the pinned lifecycle contract")
	var data: Dictionary = _fixture("straight")
	if data.is_empty() or data.fixture.is_empty():
		return
	var lab: PitchBatLab = _carry_lab(data, managed)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	_carries += 1
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var helper: StadiumMountedScoreboardCelebration = property.celebration
	if managed:
		lab._automation.presentation_enabled = true
	else:
		lab._automation = null
	lab._player_home = managed
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if managed \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	lab._apply_role_camera()
	lab._camera_director.snap(lab._camera)
	var record_path: String = "user://mounted-scoreboard-carry-%d-%s.json" % [
		OS.get_process_id(), managed]
	lab._record_export.path = record_path
	await get_tree().physics_frame
	await get_tree().physics_frame
	var probe: MountedCarryProbe = MountedCarryProbe.new()
	probe.lab = lab
	probe.helper = helper
	probe.process_priority = 1000
	probe.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(probe)
	lab._ball_play_resolver.play_resolved.connect(probe.note_outcome)
	helper.handoff_started.connect(probe.note_handoff)
	helper.wide_arrived.connect(probe.note_arrival)
	lab._active_play_record = PlayRecord.new()
	_check(lab._match_state.begin_pitch(), "actual scored-HR flight begins a genuine pitch")
	lab._at_bat_cadence.mark_pitch_live()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1, 0.28)
	launch.velocity = Vector3(4 if managed else -4, 18, 30)
	launch.orientation = Quaternion.IDENTITY
	launch.angular_velocity = Vector3.ZERO
	lab._start_ball_in_play(launch)
	var body: BattedBallBody = lab._batted_ball
	var physical: Array = [body.radius_m, body.mass, body.gravity_scale,
		body.collision_layer, body.collision_mask]
	lab.set_process(true)
	lab.set_physics_process(true)
	probe.physical = physical
	var paused_once: bool = false
	var return_paused: bool = false
	# Approach, bounded flight, bounded return and both real pauses.
	for frame in range(13 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		if not paused_once and lab._home_run.active and lab._home_run.elapsed >= 0.1:
			paused_once = true
			_live_binding_cancellation(lab, data, helper, false)
			await _pause_real_carry(lab, data, helper)
		if not return_paused and helper.active:
			return_paused = true
			_live_binding_cancellation(lab, data, helper, true)
			await _pause_real_carry(lab, data, helper)
		if probe.hold_end >= 0:
			break
	lab.set_process(false)
	lab.set_physics_process(false)
	probe.set_process(false)
	await get_tree().process_frame
	print("MOUNTED_CARRY managed=", managed, " scored=", probe.results.size(),
		" flight_end=", probe.first_wide, " ground=", probe.first_ground,
		" freeze=", probe.first_freeze, " arrival=", probe.arrival_time,
		" cleanup=", probe.hold_end, " starts=", helper.starts,
		" speed=", probe.max_speed, " turn=", probe.max_turn,
		" armed_at_score=", probe.armed_at_score, " handoff=", probe.valid_handoff,
		" signals=", [probe.handoffs, probe.arrivals, probe.signal_order_valid],
		" notice=", probe.score_notice_visible, " tracking=", probe.flight_tracking_correct)
	_check(not helper.active and not helper._armed,
		"retired HR cannot retain an armed or active presentation callback")
	_check(probe.results == [BallPlayOutcome.Result.HOME_RUN] and probe.armed_at_score
		and probe.valid_handoff and not probe.early_handoff and helper.starts == 1
		and probe.handoffs == 1 and probe.arrivals == 1 and probe.signal_order_valid
		and probe.score_notice_visible and probe.flight_tracking_correct,
		"actual HR arms once at score and hands off only after physical flight completes")
	_check(probe.score.x + probe.score.y == 1 and not probe.score_changed
		and lab._play_records.size() == 1 and lab._play_records[0].result == &"home_run",
		"presentation never changes real score or creates a second record")
	_check(probe.moving_frames > 0 and probe.saw_freeze and not probe.early_freeze
		and probe.first_wide >= 0 and probe.first_wide <= FLIGHT_LIMIT + SAMPLE_SLACK
		and probe.valid_flight_end and probe.first_freeze >= probe.first_wide
		and probe.first_freeze <= probe.first_wide + SAMPLE_SLACK,
		"real body freezes only after independently observed landing or bounded timeout")
	_check(probe.hold_end >= HOLD_MINIMUM
		and probe.hold_end >= probe.first_wide + TAIL_MINIMUM
		and probe.hold_end >= probe.arrival_time
		and probe.hold_end <= maxf(HOLD_MINIMUM, probe.first_wide + RETURN_LIMIT) + SAMPLE_SLACK
		and lab._batted_ball == null and lab._home_run.cleanup_attempted
		and not lab._home_run.cleanup_refused,
		"ordinary cleanup follows flight, minimum tail and completed bounded return")
	_check(probe.finite and probe.max_speed <= BallInPlayCamera.MAX_SPEED + 0.1
		and probe.max_turn <= BallInPlayCamera.MAX_TURN_SPEED + 0.02 and probe.arrived,
		"actual camera transition stays finite and bounded and reaches celebration")
	_check(probe.contacts > 0
		and lab._ball_play_resolver.state.stadium_contacts.size() == probe.contacts
		and not lab._ball_play_resolver.state.has_grounded,
		"post-terminal carry changes no scoring contacts")
	_check(probe.physics_unchanged,
		"presentation preserves original ball physics and collision parameters until retirement")
	_check(paused_once and return_paused and _valid(lab, data),
		"real flight and return pauses retain exact runtime binding")
	_carry_public_check(lab, managed)
	probe.free()
	lab._managed_match = false
	lab._configured_match = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD")
	lab._configured_match.stadium = data.fixture.duplicate(true)
	lab._start_new_match()
	_check(not helper.active and helper.reason.is_empty() and helper.elapsed == 0
		and helper._match == lab._match_state and _valid(lab, data),
		"ordinary actual restart rebinds helper and clears prior handoff")
	lab.free()
	DirAccess.remove_absolute(record_path)
	await get_tree().process_frame


func _live_binding_cancellation(lab: PitchBatLab, data: Dictionary,
	helper: StadiumMountedScoreboardCelebration, returning: bool) -> void:
	var phase_valid: bool = helper.active == returning and helper._armed == (not returning)
	_check(lab._home_run.active and phase_valid and lab._ball_play_resolver.state.dead
		and lab._home_run.flight_complete == returning
		and helper.starts == int(returning)
		and helper.reason == ("confirmed_home_run" if returning else ""),
		"cancellation negatives start from genuine armed flight or active return")
	if not phase_valid:
		return
	# Preserve this same genuine scored hold while exercising synchronous cancellation paths.
	# No score, outcome, body or timer is synthesized or replaced to create a positive control.
	var dynamic: Dictionary = {}
	for key: String in ["active", "_armed", "arrived", "elapsed", "reason", "_ball_id", "_velocity",
		"_turn_speed"]:
		dynamic[key] = helper.get(key)
	var director: MatchCameraDirector = lab._camera_director
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var callback: Callable = director.presentation_override
	var body: BattedBallBody = lab._batted_ball
	var pose: Transform3D = body.global_transform
	var velocity: Vector3 = body.linear_velocity
	var clock: float = lab._home_run.elapsed
	var play: BallPlayState = resolver.state
	var state: MatchState = lab._match_state
	var starts: int = helper.starts
	var camera_node: Camera3D = lab._camera
	var camera_index: int = camera_node.get_index()
	var camera_local: Transform3D = camera_node.transform
	var holder: Node3D = Node3D.new()
	lab.add_child(holder)
	for binding: String in ["director", "resolver", "callback", "camera_detached",
		"camera_reparented", "camera_renamed"]:
		match binding:
			"director": lab._camera_director = MatchCameraDirector.new()
			"resolver": lab._ball_play_resolver = BallPlayResolver.new()
			"callback": director.presentation_override = _foreign_override
			"camera_detached": lab.remove_child(camera_node)
			"camera_reparented": camera_node.reparent(holder)
			"camera_renamed": camera_node.name = "WrongCamera"
		# Compare around the handler, after the test's deliberate parent/target mutation.
		# Local and world coordinates are separate, and off-tree nodes have no world read.
		var camera_inside: bool = camera_node.is_inside_tree()
		var camera_before: Transform3D = camera_node.transform
		var world_before: Transform3D = camera_node.global_transform \
			if camera_inside else Transform3D.IDENTITY
		var generation: int = helper._generation
		helper._process(0)
		_check(not helper.active and not helper._armed and not helper.arrived and helper.elapsed == 0
			and helper.reason.is_empty() and helper._ball_id == 0
			and helper._generation == generation + 1 and helper.starts == starts,
			"lifecycle cancels stale " + binding + " without invoking its old callback")
		_check(body.global_transform == pose and body.linear_velocity == velocity
			and camera_node.is_inside_tree() == camera_inside and camera_node.transform == camera_before
			and (not camera_inside or camera_node.global_transform == world_before)
			and lab._home_run.elapsed == clock,
			"binding cancellation leaves body, camera and hold clock untouched: " + binding)
		lab._camera_director = director
		lab._ball_play_resolver = resolver
		director.presentation_override = callback
		if camera_node.get_parent() != lab:
			if camera_node.get_parent() != null:
				camera_node.get_parent().remove_child(camera_node)
			lab.add_child(camera_node)
		camera_node.name = "LabCamera"
		camera_node.transform = camera_local
		lab.move_child(camera_node, camera_index)
		var binding_restored: bool = _valid(lab, data) and lab._batted_ball == body \
			and resolver.state == play and lab._match_state == state \
			and lab._home_run.active and lab._home_run.elapsed == clock
		_check(binding_restored, "original live ownership restores before phase state")
		if not binding_restored:
			break
		# Do not rewind the generation: cancelled callbacks cannot regain authority.
		for key: String in dynamic:
			helper.set(key, dynamic[key])
		_check(helper.active == returning and helper._armed == (not returning)
			and helper._hold_valid() and helper.starts == starts,
			"same genuine flight or return resumes after synchronous test restoration")
	holder.free()


func _pause_real_carry(lab: PitchBatLab, data: Dictionary,
	helper: StadiumMountedScoreboardCelebration) -> void:
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	var clock: float = lab._home_run.elapsed
	var transition: float = helper.elapsed
	var armed: bool = helper._armed
	var active: bool = helper.active
	var body: Transform3D = lab._batted_ball.global_transform
	var camera: Transform3D = lab._camera.global_transform
	for frame in range(8):
		await get_tree().physics_frame
	_check(lab._home_run.elapsed == clock and helper.elapsed == transition
		and helper._armed == armed and helper.active == active
		and lab._batted_ball.global_transform == body and lab._camera.global_transform == camera
		and _valid(lab, data), "real pause freezes carry, hold, camera and helper with valid runtime")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)


func _observe_outcome(_outcome: BallPlayOutcome) -> void:
	return


func _pass_position(point: Vector3, _ball: Vector3) -> Vector3:
	return point


func _foreign_override(_director: MatchCameraDirector, _camera: Camera3D,
	_delta: float, _ball_live: bool, _ball_position: Vector3) -> bool:
	return false


class DifferentDirector extends MatchCameraDirector:
	var test_script_variant: bool = true


class DifferentCelebration extends StadiumMountedScoreboardCelebration:
	var test_script_variant: bool = true


class MountedCarryProbe extends Node:
	var lab: PitchBatLab
	var helper: StadiumMountedScoreboardCelebration
	var results: Array[int] = []
	var score: Vector2i = Vector2i.ZERO
	var score_changed: bool = false
	var handoffs: int = 0
	var arrivals: int = 0
	var signal_order_valid: bool = true
	var armed_at_score: bool = false
	var valid_handoff: bool = false
	var early_handoff: bool = false
	var score_notice_visible: bool = false
	var flight_tracking_correct: bool = true
	var valid_flight_end: bool = false
	var first_ground: float = -1
	var first_freeze: float = -1
	var arrival_time: float = -1
	var physical: Array = []
	var physics_unchanged: bool = true
	var contacts: int = 0
	var moving_frames: int = 0
	var saw_freeze: bool = false
	var early_freeze: bool = false
	var first_wide: float = -1
	var hold_end: float = -1
	var finite: bool = true
	var max_speed: float = 0
	var max_turn: float = 0
	var arrived: bool = false
	var _previous: Transform3D
	var _has_previous: bool = false

	func note_outcome(outcome: BallPlayOutcome) -> void:
		results.append(outcome.result)
		score = Vector2i(lab._match_state.away_team.runs, lab._match_state.home_team.runs)
		contacts = lab._ball_play_resolver.state.stadium_contacts.size()
		armed_at_score = helper._armed and not helper.active and helper.starts == 0
		armed_at_score = armed_at_score and not lab._home_run.flight_complete \
			and not lab._home_run.wide_shot and not lab._batted_ball.freeze
		score_notice_visible = lab._status_label.is_visible_in_tree() \
			and lab._event_panel.is_visible_in_tree() and "HOME RUN" in lab._status_label.text

	func note_handoff() -> void:
		handoffs += 1
		signal_order_valid = signal_order_valid and results == [BallPlayOutcome.Result.HOME_RUN] \
			and lab._home_run.flight_complete and lab._home_run.wide_shot \
			and lab._batted_ball.sleeping and lab._batted_ball.linear_velocity == Vector3.ZERO \
			and lab._batted_ball.angular_velocity == Vector3.ZERO \
			and not helper._armed and handoffs == 1
		# stop_and_freeze queues freeze; the frame probe separately requires it within 0.1s.

	func note_arrival() -> void:
		arrivals += 1
		signal_order_valid = signal_order_valid and handoffs == 1 and arrivals == 1 \
			and lab._home_run.active and helper.active and helper.arrived

	func _process(delta: float) -> void:
		if not results.is_empty() and not lab._home_run.active and hold_end < 0:
			hold_end = lab._home_run.elapsed
		if hold_end >= 0 or not is_instance_valid(lab._batted_ball):
			return
		var pose: Transform3D = lab._camera.global_transform
		finite = finite and pose.is_finite() and lab._batted_ball.global_position.is_finite()
		if _has_previous and delta > 0:
			max_speed = maxf(max_speed, pose.origin.distance_to(_previous.origin) / delta)
			max_turn = maxf(max_turn, pose.basis.get_rotation_quaternion().angle_to(
				_previous.basis.get_rotation_quaternion()) / delta)
		_previous = pose
		_has_previous = true
		if not lab._home_run.active:
			return
		var body: BattedBallBody = lab._batted_ball
		physics_unchanged = physics_unchanged and physical == [body.radius_m, body.mass,
			body.gravity_scale, body.collision_layer, body.collision_mask]
		var ground_now: bool = false
		for contact: Node3D in body.get_colliding_bodies():
			ground_now = ground_now or contact.get_meta(&"ball_surface", &"") == &"ground"
		if ground_now and first_ground < 0:
			first_ground = lab._home_run.elapsed
		if not lab._home_run.flight_complete:
			flight_tracking_correct = flight_tracking_correct \
				and lab._camera_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
		early_handoff = early_handoff or (helper.active and not lab._home_run.flight_complete)
		if first_wide < 0 and lab._home_run.wide_shot:
			first_wide = lab._home_run.elapsed
			var reason: StringName = lab._home_run.flight_end_reason
			valid_flight_end = lab._home_run.flight_complete and (
				(reason == &"timeout" and first_wide >= FLIGHT_LIMIT)
				or (reason in [&"landed", &"rest"] and first_ground >= 0
					and first_wide - first_ground + SAMPLE_SLACK >= LANDING_CONTEXT
					and (ground_now or body.sleeping)))
		if helper.active and not valid_handoff:
			valid_handoff = helper.starts == 1 and helper.wide_latch_at_start \
				and helper.reason == "confirmed_home_run" and lab._home_run.flight_complete \
				and body.freeze and first_wide >= 0 \
				and lab._home_run.elapsed <= first_wide + SAMPLE_SLACK
		if body.freeze:
			if first_freeze < 0:
				first_freeze = lab._home_run.elapsed
			saw_freeze = true
			early_freeze = early_freeze or not lab._home_run.flight_complete
		elif body.linear_velocity.length() > 0:
			moving_frames += 1
		if helper.arrived and arrival_time < 0:
			arrival_time = lab._home_run.elapsed
		score_changed = score_changed or score != Vector2i(
			lab._match_state.away_team.runs, lab._match_state.home_team.runs)
		arrived = arrived or helper.arrived


func _carry_lab(data: Dictionary, managed: bool) -> PitchBatLab:
	var lab: PitchBatLab = _lab(data.fixture, managed)
	_check(StadiumScoreboardRuntime.install_mounted_bound(lab, data.ledger),
		"paid HR runtime installs")
	return lab


func _carry_public_check(lab: PitchBatLab, managed: bool) -> void:
	if managed:
		_check(PhysicalMatchReport.capture(lab).is_empty(),
			"public automated report refuses missing retained ownership proof")
	else:
		_check(not StadiumBoundaryRuntime.installed(lab, lab._match_state.stadium),
			"public ordinary installed-world check refuses missing retained ownership proof")
