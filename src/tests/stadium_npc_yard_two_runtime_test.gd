extends Node3D
## Fresh finite installed assertions. No old native results transfer to this scene.
# gdlint: disable=max-file-lines

const R = preload("res://src/presentation/stadium/stadium_npc_yard_two_runtime_v1.gd")
const Proof = preload("res://src/tests/stadium_npc_yard_two_installed_proof.gd")
const P: String = "npc:AY-02:r1:"
var _seen: Dictionary = {}
var _failures: int = 0
var _suite: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var allowed: Array[String] = [
		"admission", "lifecycle_integrity", "physics", "camera", "interruptions",
		"called_strike_hits", "called_strike_misses", "called_ball_hits", "called_resets"
	]
	if arguments.size() != 1 or not arguments[0].begins_with("--ay02-suite="):
		push_error("AY02 runtime requires exactly one --ay02-suite argument")
		get_tree().quit(2)
		return
	_suite = arguments[0].trim_prefix("--ay02-suite=")
	if not allowed.has(_suite):
		push_error("AY02 runtime suite is not allowlisted")
		get_tree().quit(2)
		return
	match _suite:
		"admission":
			Proof.report_controls(self)
			_guards()
			_stages()
		"lifecycle_integrity":
			await _lifecycle()
		"physics":
			await _installed_suite(false)
		"camera":
			await _installed_suite(true)
		"interruptions":
			await _removals()
			await _child_interruptions()
		"called_strike_hits":
			await Proof.called_strike_hits(self)
		"called_strike_misses":
			await Proof.called_strike_misses(self)
		"called_ball_hits":
			await Proof.called_ball_hits(self)
		"called_resets":
			await Proof.called_resets(self)
	await TestAudioDrain.finish(get_tree())
	Proof.finish(self, "runtime")


func _installed_suite(camera: bool) -> void:
	var lab: PitchBatLab = _lab()
	var original: Dictionary = _snapshot(lab)
	var installed: bool = R.install(lab)
	if not installed or not R.installed(lab):
		_failures += 1
		push_error("AY02 suite fresh install failed")
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if camera:
		Proof.camera_controls(self, lab, property)
	else:
		await Proof.physics_controls(self, lab, property)
	Proof.fresh(self, lab, false)
	var restored: bool = R.teardown(lab)
	if not restored or original != _snapshot(lab):
		_failures += 1
		push_error("AY02 suite teardown did not restore exact original snapshot")
	lab.free()
	await get_tree().process_frame


func _lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	lab.set_meta("stadium_npc_retained_lab_only", true)
	lab.set_meta("stadium_npc_ay02_installed_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	return lab


func _snapshot(lab: PitchBatLab) -> Dictionary:
	var host: Node3D
	for child: Node in lab.get_children():
		if child is StarterFieldLabGeometry:
			host = child
	var nodes: Array = []
	if host != null:
		for child: Node in host.find_children("*", "", true, false):
			nodes.append(
				[
					child,
					child.get_parent(),
					child.get_index(),
					child.transform if child is Node3D else null
				]
			)
	return {
		"nodes": nodes,
		"field": lab._field_definition,
		"field_id": lab._field_id,
		"observer": lab._ball_play_resolver.segment_observer,
		"receiver": lab._pitch_actor.receiver_router,
		"clip": lab._primary_fielder.stadium_boundary_clip,
		"routes": lab._primary_fielder.stadium_obstacles.duplicate(true),
		"camera": lab._camera_director,
		"visibility": lab._camera_director.tracking_visibility,
		"camera_pose": lab._camera.transform,
		"camera_mask": lab._camera.cull_mask,
		"camera_optics": Proof.camera_optics(lab._camera),
		"segments": lab._pitch_actor.segment_advanced.get_connections(),
		"stops": lab._pitch_actor.flight_stopped.get_connections()
	}


func _reject(lab: PitchBatLab, id: String = "AY-02", revision: int = 1) -> bool:
	var before: Dictionary = _snapshot(lab)
	return not R.install(lab, id, revision) and before == _snapshot(lab)


func _guards() -> void:
	_assert(
		"ADM-01/null",
		not R.install(null) and not R.installed(null) and not R.teardown(null),
		"Null authority refuses all entry points"
	)
	var unready: PitchBatLab = PitchBatLab.new()
	_assert("ADM-01/uninitialized", not R.install(unready), "Uninitialized lab cannot stage")
	unready.free()
	var lab: PitchBatLab = _lab()
	lab.remove_meta("stadium_npc_ay02_installed_lab_only")
	_assert("ADM-02/private_missing", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_ay02_installed_lab_only", false)
	_assert("ADM-02/private_false", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_ay02_installed_lab_only", 1)
	_assert("ADM-02/private_integer", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_ay02_installed_lab_only", "true")
	_assert("ADM-02/private_string", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_ay02_installed_lab_only", [])
	_assert("ADM-02/private_array", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_ay02_installed_lab_only", {})
	_assert("ADM-02/private_dictionary", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_ay02_installed_lab_only", true)
	lab.remove_meta("stadium_npc_retained_lab_only")
	_assert("ADM-02/persistent_missing", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_retained_lab_only", false)
	_assert("ADM-02/persistent_false", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_retained_lab_only", 1)
	_assert("ADM-02/persistent_integer", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_retained_lab_only", "true")
	_assert("ADM-02/persistent_string", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_retained_lab_only", [])
	_assert("ADM-02/persistent_array", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_retained_lab_only", {})
	_assert("ADM-02/persistent_dictionary", _reject(lab), "Exact true boolean opt-in required")
	lab.set_meta("stadium_npc_retained_lab_only", true)
	_assert("ADM-03/identity_00", _reject(lab, ""), "Private exact identity boundary")
	_assert("ADM-03/identity_01", _reject(lab, "ay-02"), "Private exact identity boundary")
	_assert("ADM-03/identity_02", _reject(lab, " AY-02"), "Private exact identity boundary")
	_assert("ADM-03/identity_03", _reject(lab, "AY-02 "), "Private exact identity boundary")
	_assert("ADM-03/identity_04", _reject(lab, "FOREIGN"), "Private exact identity boundary")
	_assert("ADM-03/identity_05", _reject(lab, "AY-01"), "Private exact identity boundary")
	_assert("ADM-03/identity_06", _reject(lab, "AY-03"), "Private exact identity boundary")
	_assert("ADM-03/identity_07", _reject(lab, "AE-01"), "Private exact identity boundary")
	_assert("ADM-03/identity_08", _reject(lab, "AE-02"), "Private exact identity boundary")
	_assert("ADM-03/identity_09", _reject(lab, "AE-03"), "Private exact identity boundary")
	_assert("ADM-03/identity_10", _reject(lab, "AC-01"), "Private exact identity boundary")
	_assert("ADM-03/identity_11", _reject(lab, "AC-02"), "Private exact identity boundary")
	_assert("ADM-03/identity_12", _reject(lab, "AC-03"), "Private exact identity boundary")
	_assert("ADM-03/identity_13", _reject(lab, "AM-01"), "Private exact identity boundary")
	_assert("ADM-03/identity_14", _reject(lab, "AM-02"), "Private exact identity boundary")
	_assert("ADM-03/identity_15", _reject(lab, "AM-03"), "Private exact identity boundary")
	_assert("ADM-03/identity_16", _reject(lab, "AF-01"), "Private exact identity boundary")
	_assert("ADM-03/identity_17", _reject(lab, "AF-02"), "Private exact identity boundary")
	_assert("ADM-03/identity_18", _reject(lab, "AF-03"), "Private exact identity boundary")
	_assert("ADM-03/identity_19", _reject(lab, "AF-04"), "Private exact identity boundary")
	_assert("ADM-03/revision_-1", _reject(lab, "AY-02", -1), "Exact revision boundary")
	_assert("ADM-03/revision_0", _reject(lab, "AY-02", 0), "Exact revision boundary")
	_assert("ADM-03/revision_2", _reject(lab, "AY-02", 2), "Exact revision boundary")
	_assert("ADM-03/revision_1000000", _reject(lab, "AY-02", 1000000), "Exact revision boundary")
	lab._managed_match = true
	_assert("ADM-04/managed", _reject(lab), "Managed match refuses")
	lab._managed_match = false
	lab._automation = MatchAutomation.new()
	_assert("ADM-04/automation", _reject(lab), "Automation refuses")
	lab._automation = null
	lab._field_id = &"field.foreign"
	_assert("ADM-05/field", _reject(lab), "Nonstarter field refuses")
	lab._field_id = PitchBatLab.FIELD_ID
	lab._match_state.stadium = {"foreign": true}
	_assert("ADM-05/fixture", _reject(lab), "Nonempty frozen fixture refuses")
	lab._match_state.stadium = {}
	lab.set_meta("stadium_property", {})
	_assert("ADM-05/property", _reject(lab), "Malformed property marker refuses")
	lab.remove_meta("stadium_property")
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var occupied: Node3D = Node3D.new()
	occupied.name = "HomeProperty"
	host.add_child(occupied)
	_assert("ADM-05/home_path", _reject(lab), "Occupied original name refuses")
	occupied.name = "AY02InstalledProperty"
	_assert("ADM-05/private_path", _reject(lab), "Occupied private name refuses")
	occupied.free()
	var observer: Callable = lab._ball_play_resolver.segment_observer
	lab._ball_play_resolver.segment_observer = _snapshot
	_assert("ADM-06/observer", _reject(lab), "Foreign observer refuses")
	lab._ball_play_resolver.segment_observer = observer
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	lab._primary_fielder.stadium_boundary_clip = _snapshot
	_assert("ADM-06/clip", _reject(lab), "Foreign clip refuses")
	lab._primary_fielder.stadium_boundary_clip = clip
	lab._primary_fielder.stadium_obstacles.append({"center": Vector3.ZERO, "radius": 1.0})
	_assert("ADM-06/routes", _reject(lab), "Foreign routes refuse")
	lab._primary_fielder.stadium_obstacles.clear()
	var director: MatchCameraDirector = lab._camera_director
	lab._camera_director = StadiumExpandedCameraDirector.new()
	_assert("ADM-06/camera", _reject(lab), "Foreign camera refuses")
	lab._camera_director = director
	var view: BallTrackingVisibility = director.tracking_visibility
	director.tracking_visibility = StadiumNpcRetainedVisibility.new()
	_assert("ADM-06/visibility", _reject(lab), "Foreign visibility refuses")
	director.tracking_visibility = view
	lab._pitch_actor.receiver_router = func(
		_actor: PitchFlightActor, _p: Vector3, _v: Vector3
	) -> bool:
		return false
	_assert("ADM-06/router", _reject(lab), "Already-owned actor refuses")
	lab._pitch_actor.receiver_router = Callable()
	lab._batted_ball = BattedBallBody.new()
	_assert("ADM-06/ball", _reject(lab), "Live ball reference refuses")
	lab._batted_ball.free()
	lab._batted_ball = null
	lab._release_controller.begin()
	_assert("ADM-06/release", _reject(lab), "Live release refuses")
	lab._release_controller.cancel()
	lab._at_bat_cadence.state = AtBatCadenceController.State.PITCH_LIVE
	_assert("ADM-06/cadence", _reject(lab), "Live cadence refuses")
	lab._at_bat_cadence.stop()
	lab._pitch_actor.start_pitch(Proof.parameters(0.65))
	_assert("ADM-06/pitch", lab._pitch_actor.running and _reject(lab), "Real actor flight refuses")
	lab._pitch_actor.reset_pitch()
	host.position.x = 1
	_assert("ADM-07/translation", _reject(lab), "Host translation refuses")
	host.position = Vector3.ZERO
	host.rotation.y = 0.1
	_assert("ADM-07/rotation", _reject(lab), "Host rotation refuses")
	host.rotation = Vector3.ZERO
	host.scale.x = 1.1
	_assert("ADM-07/scale", _reject(lab), "Host scale refuses")
	host.scale = Vector3.ONE
	var foreign: StaticBody3D = StaticBody3D.new()
	host.get_node("PitchReceiverDebug").add_child(foreign)
	_assert("ADM-07/body", _reject(lab), "Foreign body refuses")
	foreign.free()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	host.get_node("PitchReceiverDebug").add_child(shape)
	_assert("ADM-07/shape", _reject(lab), "Foreign shape refuses")
	shape.free()
	lab.set_meta("stadium_npc_runtime_restoring", true)
	_assert("ADM-08/restoring", _reject(lab), "Pending restore refuses")
	lab.remove_meta("stadium_npc_runtime_restoring")
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	_assert("ADM-08/interrupted", _reject(lab), "Interrupted authority cannot reinstall")
	lab.free()


func _stages() -> void:
	var lab: PitchBatLab = _lab()
	var before: Dictionary = _snapshot(lab)
	var raw: StadiumNpcYardTwoPropertyV1 = R._construct(lab)
	_assert(
		"LIFE-01/detached",
		raw != null and raw.get_parent() == null and before == _snapshot(lab),
		"Detached construction preserves all live bindings"
	)
	_assert(
		"LIFE-02/construction",
		R._construct(lab, "AY-03", 1) == null and before == _snapshot(lab),
		"Actual construction rejects foreign venue"
	)
	if raw != null:
		var chair: Node3D = raw.objects[P + "RECEIVER-PRIMARY"]
		chair.set_meta("stadium_item", "foreign")
		_assert(
			"LIFE-02/receiver_bind",
			not raw.receiver.configure_candidate(raw, lab._sounds) and before == _snapshot(lab),
			"Actual receiver configure call fails before commit"
		)
		_assert(
			"LIFE-02/receiver_pipeline",
			not R._bind_components(lab, raw) and before == _snapshot(lab),
			"Actual detached component pipeline refuses this receiver"
		)
		raw.free()
	raw = R._construct(lab)
	if raw != null:
		_assert(
			"LIFE-02/camera_first_bind",
			raw.camera.bind_candidate(raw),
			"Real first camera bind establishes the exact positive prerequisite"
		)
		_assert(
			"LIFE-02/camera_bind",
			not raw.camera.bind_candidate(raw) and before == _snapshot(lab),
			"Actual second bind refuses an already-bound camera"
		)
		_assert(
			"LIFE-02/camera_pipeline",
			(
				not R._bind_components(lab, raw)
				and raw.receiver_configured
				and before == _snapshot(lab)
			),
			"Actual pipeline reaches and refuses the already-bound camera after receiver admission"
		)
		raw.free()
	var staged: StadiumNpcYardTwoPropertyV1 = R._stage(lab)
	if staged != null:
		staged.construction.position.x = 1
		_assert(
			"LIFE-02/staged_geometry",
			not R._commit(lab, staged) and before == _snapshot(lab),
			"Actual stage mutation refuses before live write"
		)
		staged.free()
	staged = R._stage(lab)
	if staged != null:
		lab._managed_match = true
		_assert(
			"LIFE-02/admission_recheck",
			not R._commit(lab, staged) and before == _snapshot(lab),
			"Actual admission changes after stage refuse"
		)
		lab._managed_match = false
		staged.free()
	staged = R._stage(lab)
	if staged != null:
		var attempts: Array[bool] = []
		var host: Node = lab.get_node("StarterFieldGeometry")
		var callback: Callable = func(node: Node) -> void:
			if node == staged:
				attempts.append(R.install(lab))
		host.child_entered_tree.connect(callback)
		var committed: bool = R._commit(lab, staged)
		host.child_entered_tree.disconnect(callback)
		_assert(
			"ADM-08/reentrant",
			committed and attempts == [false] and R.installed(lab),
			"In-commit child-entry attempt is distinct from a repeat after install"
		)
		_assert("LIFE-01/committed", committed and R.installed(lab), "Genuine stage commits once")
		_assert("ADM-08/repeat", _reject(lab), "Already-installed repeat refuses without change")
		R.teardown(lab)
	staged = R._stage(lab)
	if staged != null:
		var callback: Callable = func() -> void: staged.construction.position.x = 1
		staged.tree_entered.connect(callback, CONNECT_ONE_SHOT)
		_assert(
			"LIFE-03/post_entry_rollback",
			not R._commit(lab, staged) and before == _snapshot(lab),
			"Mutation after actual tree entry restores originals exactly"
		)
		staged.free()
	lab.free()


# AY02_CASE_PHASE: LIFECYCLE
func _lifecycle() -> void:
	var lab: PitchBatLab = _lab()
	var original: Dictionary = _snapshot(lab)
	_assert("LIFE-01/install", R.install(lab) and R.installed(lab), "Fresh genuine install")
	if not R.installed(lab):
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var host: Node = lab.get_node("StarterFieldGeometry")
	_assert(
		"LIFE-06/private_path",
		(
			host.get_node_or_null("AY02InstalledProperty") == property
			and not host.has_node("HomeProperty")
		),
		"Exact private name excludes mutable shared authoring"
	)
	var chair: Node3D = property.objects[P + "RECEIVER-PRIMARY"]
	var chair_before: PackedByteArray = var_to_bytes(
		StadiumNpcYardTwoCorrespondence.snapshot(chair)
	)
	PitchBatLabPresentation.refresh_markers(lab)
	_assert(
		"LIFE-06/shared_markers",
		(
			R.installed(lab)
			and chair_before == var_to_bytes(StadiumNpcYardTwoCorrespondence.snapshot(chair))
		),
		"Shared markers preserve owner"
	)
	_assert(
		"QUA-02/installed", PhysicalMatchReport.capture(lab).is_empty(), "Installed report fence"
	)
	await preload("res://src/tests/ay02_current_integrity.gd").run(self)
	_rebind(lab, property)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Proof.fresh(self, lab, false)
	lab._release_controller.begin()
	_assert("LIFE-05/live_release", not R.rebind_match(lab) and not R.teardown(lab), "Busy release")
	lab._release_controller.cancel()
	lab._at_bat_cadence.state = AtBatCadenceController.State.PITCH_LIVE
	_assert("LIFE-05/live_cadence", not R.rebind_match(lab) and not R.teardown(lab), "Busy cadence")
	lab._at_bat_cadence.stop()
	lab._pitch_actor.start_pitch(Proof.parameters(0.65))
	_assert(
		"LIFE-05/running_pitch",
		lab._pitch_actor.running and not R.rebind_match(lab) and not R.teardown(lab),
		"Actual running pitch cannot be rebound or torn down"
	)
	lab._pitch_actor.reset_pitch()
	lab._batted_ball = BattedBallBody.new()
	_assert(
		"LIFE-05/live_ball", not R.rebind_match(lab) and not R.teardown(lab), "Live body reference"
	)
	lab._batted_ball.free()
	lab._batted_ball = null
	_assert(
		"LIFE-06/restore_exact",
		R.teardown(lab) and original == _snapshot(lab),
		"Original object IDs/order/transforms and every field/callback/camera binding restored"
	)
	_assert(
		"QUA-04/teardown_flags",
		(
			lab.get_meta("stadium_npc_retained_lab_only", false) == true
			and lab.get_meta("stadium_npc_ay02_installed_lab_only", false) == true
			and PhysicalMatchReport.capture(lab).is_empty()
		),
		"Persistent boolean fences survive teardown"
	)
	_assert(
		"LIFE-07/reinstall_one",
		R.install(lab) and R.installed(lab) and R.teardown(lab) and original == _snapshot(lab),
		"First clean reinstall has exact originals"
	)
	_assert(
		"LIFE-07/reinstall_two",
		R.install(lab) and R.installed(lab) and R.teardown(lab) and original == _snapshot(lab),
		"Second clean reinstall has no stale member authority"
	)
	var private_again: bool = R.install(lab)
	lab.remove_meta("stadium_npc_retained_lab_only")
	lab.set_meta("stadium_npc_ay02_installed_lab_only", false)
	_assert(
		"QUA-04/tampered_flags",
		(
			private_again
			and R.teardown(lab)
			and lab.get_meta("stadium_npc_retained_lab_only", false) == true
			and lab.get_meta("stadium_npc_ay02_installed_lab_only", false) == true
			and PhysicalMatchReport.capture(lab).is_empty()
		),
		"Teardown reasserts the original persistent quarantine after externally tampered flags"
	)

	lab.free()
	await get_tree().process_frame


# AY02_CASE_PHASE: REPORT
func _rebind(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> void:
	# Rejection audits own separate lifetimes; they cannot poison the supported positive rebind.
	_rebind_rejection("stale")
	_rebind_rejection("missing")
	_rebind_rejection("foreign")
	var old: MatchState = lab._match_state
	var accepted: bool = property.callback_intact()
	var generation: int = property.installation_generation
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	var replacement: MatchState = lab._match_state
	var auto_bound: bool = property.bound_state == replacement and property.callback_intact() \
		and property.installation_generation > generation
	var automatic_generation: int = property.installation_generation
	_assert("LIFE-04/explicit_idle", accepted and replacement != old and auto_bound
		and R.rebind_match(lab) and R.installed(lab) and property.bound_state == replacement
		and property.installation_generation > automatic_generation
		and not lab.has_meta("stadium_npc_runtime_interrupted"),
		"Fresh unretired idle replacement receives explicit new generation authority")


func _rebind_rejection(kind: String) -> void:
	var lab: PitchBatLab = _lab()
	if not R.install(lab):
		_failures += 1
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var old: MatchState = lab._match_state
	var accepted: bool = property.callback_intact()
	# Ordinary _start_new_match now rebinds automatically. This negative fixture deliberately
	# substitutes an independently constructed state without the supported binding operation.
	var replacement: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, PitchBatLab.PLAYER_TEAM_NAME, PitchBatLab.RIVAL_TEAM_NAME)
	lab._match_state = replacement
	if kind == "stale":
		var refused: bool = not R.installed(lab)
		_assert("QUA-03/stale_report", accepted and PhysicalMatchReport.capture(lab).is_empty()
			and property.bound_state == old, "Failed stale audit never rewrites report owner")
		lab._match_state = old
		_assert("LIFE-05/stale_state", accepted and replacement != old and refused
			and property.phase == &"retired" and not property.callback_intact(),
			"Actual stale installed audit retires authority; restoring old state cannot revive it")
	elif kind == "missing":
		lab._match_state = null
		_assert("LIFE-05/missing_state", accepted and not R.rebind_match(lab)
			and property.bound_state == old, "Fresh missing replacement refuses without rebinding")
		lab._match_state = replacement
	else:
		replacement.stadium = {"foreign": true}
		_assert("LIFE-05/foreign_state", accepted and not R.rebind_match(lab)
			and property.bound_state == old, "Fresh nonempty foreign fixture refuses rebinding")
	lab.free()


# AY02_CASE_PHASE: LIFECYCLE
func _removals() -> void:
	var row: Dictionary = await _remove("idle_detach")
	_assert(
		"LIFE-08/idle_detach", row.exact and row.owned_dead, "Idle detach restores exact originals"
	)
	_assert("QUA-03/detached_report", row.fenced, "Detached property cannot issue a public report")
	row = await _remove("idle_free")
	_assert("LIFE-09/idle_free", row.exact and row.owned_dead, "Idle free restores exact originals")
	_assert("QUA-03/freed_report", row.fenced, "Freed property cannot issue public report")
	row = await _remove("ball_detach")
	_assert(
		"LIFE-10/ball_detach",
		row.quarantined and row.no_outcome and row.owned_dead,
		"Actual live ball detach adds no synchronous/deferred outcome or completed play"
	)
	_assert("QUA-03/interrupted_report", row.fenced, "Interrupted live ball remains report-fenced")
	row = await _remove("ball_free")
	_assert(
		"LIFE-10/ball_free",
		row.quarantined and row.no_outcome and row.owned_dead,
		"Actual live ball free adds no synchronous/deferred outcome or completed play"
	)
	row = await _remove("pitch")
	_assert("LIFE-11/pitch", row.quarantined and row.no_outcome, "Real running pitch interruption")
	row = await _remove("follow")
	_assert(
		"LIFE-11/follow",
		row.sole_tween and row.quarantined and row.owned_dead and row.no_outcome,
		"Child-first exit records live follow before cancellation; no automation masks it"
	)
	row = await _remove("rock")
	_assert(
		"LIFE-11/rock",
		row.sole_tween and row.quarantined and row.owned_dead and row.no_outcome,
		"Genuine owned rock alone triggers quarantine and exact owned cleanup"
	)
	row = await _remove("paused_follow")
	_assert(
		"LIFE-11/paused_follow",
		(
			row.sole_tween
			and row.busy_refusal
			and row.quarantined
			and row.owned_dead
			and row.no_outcome
		),
		"Paused resumable owned follow refuses idle cleanup and quarantines on child-first exit"
	)
	row = await _remove("paused_rock")
	_assert(
		"LIFE-11/paused_rock",
		(
			row.sole_tween
			and row.busy_refusal
			and row.quarantined
			and row.owned_dead
			and row.no_outcome
		),
		"Paused resumable owned rock refuses idle cleanup and quarantines on removal"
	)
	row = await _dispose("lab_free")
	_assert(
		"LIFE-12/whole_lab",
		row.originals_freed,
		"Whole-lab destruction reclaims detached originals"
	)
	row = await _remove("actor")
	_assert("LIFE-13/actor", row.quarantined and row.no_outcome, "Destroyed actor safely restored")
	row = await _remove("release")
	_assert(
		"LIFE-13/release",
		row.quarantined and row.no_outcome,
		"Missing release controller tolerated"
	)
	row = await _remove("cadence")
	_assert(
		"LIFE-13/cadence",
		row.quarantined and row.no_outcome,
		"Missing cadence controller tolerated"
	)
	row = await _dispose("host_free")
	_assert(
		"LIFE-14/host_free", row.originals_freed and row.quarantined, "Host freed during restore"
	)
	row = await _dispose("host_remove")
	_assert(
		"LIFE-14/host_remove",
		row.originals_freed and row.quarantined,
		"Host detached during restore"
	)
	row = await _dispose("lab_free")
	_assert("LIFE-14/lab_free", row.originals_freed, "Lab freed before deferred restore")
	row = await _dispose("lab_remove")
	_assert(
		"LIFE-14/lab_remove", row.originals_freed and row.quarantined, "Lab detached before restore"
	)


func _remove(mode: String) -> Dictionary:
	var lab: PitchBatLab = _lab()
	var original: Dictionary = _snapshot(lab)
	var result: Dictionary = {
		"exact": false,
		"fenced": false,
		"quarantined": false,
		"no_outcome": false,
		"owned_dead": false,
		"sole_tween": false,
		"busy_refusal": false
	}
	if not R.install(lab):
		lab.free()
		return result
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	if mode.begins_with("ball"):
		lab._match_state.begin_pitch()
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(0, 3, 10)
		launch.velocity = Vector3(0, 2, 12)
		lab._start_ball_in_play(launch)
	elif mode in ["pitch", "follow", "rock", "paused_follow", "paused_rock"]:
		lab._match_state.begin_pitch()
		lab._pitch_actor.set_physics_process(false)
		lab._pitch_actor.start_pitch(Proof.parameters(0.65))
		if mode != "pitch":
			lab._pitch_actor._physics_process(0.2)
		if mode in ["rock", "paused_rock"]:
			for frame in range(40):
				await get_tree().create_timer(0.01).timeout
				if property.receiver.contacts.size() == 1:
					break
		lab._at_bat_cadence.stop()
	elif mode == "actor":
		lab._pitch_actor.free()
	elif mode == "release":
		lab._release_controller = null
	elif mode == "cadence":
		lab._at_bat_cadence = null
	var follow: Tween = property.receiver._follow
	var rock: Tween = property.receiver._owned_rock
	if mode == "paused_follow" and follow != null:
		follow.pause()
	if mode == "paused_rock" and rock != null:
		rock.pause()
	if mode in ["paused_follow", "paused_rock"]:
		result.busy_refusal = not R.rebind_match(lab) and not R.teardown(lab)
	result.sole_tween = (
		mode in ["follow", "rock", "paused_follow", "paused_rock"]
		and lab._automation == null
		and not is_instance_valid(lab._batted_ball)
		and StadiumPropertyRuntime.authoring_delivery_idle(lab)
		and ((follow != null and follow.is_valid()) or (rock != null and rock.is_valid()))
	)
	var state: PackedByteArray = Proof.game_state(lab)
	var outcomes: Array = []
	lab._ball_play_resolver.play_resolved.connect(
		func(value: BallPlayOutcome) -> void: outcomes.append([value.result, value.reason])
	)
	if mode.ends_with("detach"):
		property.get_parent().remove_child(property)
	else:
		property.free()
	result.no_outcome = outcomes.is_empty() and Proof.game_state(lab) == state
	await get_tree().process_frame
	result.no_outcome = result.no_outcome and outcomes.is_empty() and Proof.game_state(lab) == state
	result.owned_dead = (
		(follow == null or not follow.is_valid()) and (rock == null or not rock.is_valid())
	)
	result.fenced = (
		PhysicalMatchReport.capture(lab).is_empty()
		and lab.get_meta("stadium_npc_retained_lab_only", false) == true
		and lab.get_meta("stadium_npc_ay02_installed_lab_only", false) == true
	)
	result.quarantined = (
		lab.process_mode == Node.PROCESS_MODE_DISABLED
		and lab.get_meta("stadium_npc_runtime_interrupted", false) == true
		and not lab.has_meta("stadium_property")
		and not lab.has_meta("stadium_npc_runtime_restoring")
	)
	if mode.begins_with("idle"):
		result.exact = original == _snapshot(lab) and not R.installed(lab)
	if is_instance_valid(property):
		property.free()
	lab.free()
	return result


func _dispose(mode: String) -> Dictionary:
	var lab: PitchBatLab = _lab()
	if not R.install(lab):
		lab.free()
		return {"originals_freed": false, "quarantined": false}
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var originals: Array[Node] = property.old_nodes.duplicate()
	var host: Node = property.get_parent()
	host.remove_child(property)
	if mode == "lab_free":
		lab.free()
	elif mode == "lab_remove":
		lab.get_parent().remove_child(lab)
	elif mode == "host_free":
		host.free()
	else:
		host.get_parent().remove_child(host)
	await get_tree().process_frame
	var gone: bool = not originals.is_empty()
	for node: Node in originals:
		gone = gone and not is_instance_valid(node)
	var quarantined: bool = (
		is_instance_valid(lab)
		and lab.process_mode == Node.PROCESS_MODE_DISABLED
		and lab.get_meta("stadium_npc_runtime_interrupted", false) == true
		and not lab.has_meta("stadium_npc_runtime_restoring")
	)
	property.free()
	if is_instance_valid(lab):
		lab.free()
	if mode == "host_remove" and is_instance_valid(host):
		host.free()
	return {"originals_freed": gone, "quarantined": quarantined}


func _assert(id: String, ok: bool, detail: String) -> void:
	Proof.record(self, id, ok, detail)


# AY02_CASE_PHASE: LIFECYCLE
func _child_interruptions() -> void:
	var row: Dictionary
	row = await _child_interrupt("receiver", "follow", false)
	_assert(
		"LIFE-11/receiver_active_follow",
		(
			row.genuine
			and row.cancelled
			and row.latched
			and row.teardown
			and row.quarantined
			and row.fenced
			and row.silent
			and row.no_reinstall
		),
		"Genuine receiver child exit preserves owned interruption through explicit teardown"
	)
	row = await _child_interrupt("receiver", "follow", true)
	_assert(
		"LIFE-11/receiver_paused_follow",
		(
			row.genuine
			and row.cancelled
			and row.latched
			and row.teardown
			and row.quarantined
			and row.fenced
			and row.silent
			and row.no_reinstall
		),
		"Genuine receiver child exit preserves owned interruption through explicit teardown"
	)
	row = await _child_interrupt("receiver", "rock", false)
	_assert(
		"LIFE-11/receiver_active_rock",
		(
			row.genuine
			and row.cancelled
			and row.latched
			and row.teardown
			and row.quarantined
			and row.fenced
			and row.silent
			and row.no_reinstall
		),
		"Genuine receiver child exit preserves owned interruption through explicit teardown"
	)
	row = await _child_interrupt("receiver", "rock", true)
	_assert(
		"LIFE-11/receiver_paused_rock",
		(
			row.genuine
			and row.cancelled
			and row.latched
			and row.teardown
			and row.quarantined
			and row.fenced
			and row.silent
			and row.no_reinstall
		),
		"Genuine receiver child exit preserves owned interruption through explicit teardown"
	)
	row = await _child_interrupt("actor", "follow", false)
	_assert(
		"LIFE-11/actor_active_follow",
		(
			row.genuine
			and row.cancelled
			and row.latched
			and row.teardown
			and row.quarantined
			and row.fenced
			and row.silent
			and row.no_reinstall
		),
		"Genuine actor child exit preserves owned interruption through explicit teardown"
	)
	row = await _child_interrupt("actor", "follow", true)
	_assert(
		"LIFE-11/actor_paused_follow",
		(
			row.genuine
			and row.cancelled
			and row.latched
			and row.teardown
			and row.quarantined
			and row.fenced
			and row.silent
			and row.no_reinstall
		),
		"Genuine actor child exit preserves owned interruption through explicit teardown"
	)
	row = await _child_interrupt("actor", "rock", false)
	_assert(
		"LIFE-11/actor_active_rock",
		(
			row.genuine
			and row.cancelled
			and row.latched
			and row.teardown
			and row.quarantined
			and row.fenced
			and row.silent
			and row.no_reinstall
		),
		"Genuine actor child exit preserves owned interruption through explicit teardown"
	)
	row = await _child_interrupt("actor", "rock", true)
	_assert(
		"LIFE-11/actor_paused_rock",
		(
			row.genuine
			and row.cancelled
			and row.latched
			and row.teardown
			and row.quarantined
			and row.fenced
			and row.silent
			and row.no_reinstall
		),
		"Genuine actor child exit preserves owned interruption through explicit teardown"
	)
	row = await _child_interrupt("receiver", "idle", false)
	_assert(
		"LIFE-08/receiver_idle_cleanup",
		(
			row.genuine
			and row.cancelled
			and not row.latched
			and row.teardown
			and row.clean
			and row.fenced
			and row.silent
			and row.reinstalled
		),
		"Genuine idle receiver child exit retains exact cleanup and explicit reinstall positive"
	)
	row = await _child_interrupt("actor", "idle", false)
	_assert(
		"LIFE-08/actor_idle_cleanup",
		(
			row.genuine
			and row.cancelled
			and not row.latched
			and row.teardown
			and row.clean
			and row.fenced
			and row.silent
			and row.reinstalled
		),
		"Genuine idle actor child exit retains exact cleanup and explicit reinstall positive"
	)


func _child_interrupt(kind: String, work: String, paused: bool) -> Dictionary:
	var lab: PitchBatLab = _lab()
	var original: Dictionary = _snapshot(lab)
	var result: Dictionary = {
		"genuine": false,
		"cancelled": false,
		"latched": false,
		"teardown": false,
		"quarantined": false,
		"fenced": false,
		"silent": false,
		"no_reinstall": false,
		"clean": false,
		"reinstalled": false
	}
	if not R.install(lab):
		lab.free()
		return result
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var receiver: StadiumNpcYardTwoReceiverV1 = property.receiver
	var actor: PitchFlightActor = lab._pitch_actor
	actor.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if work != "idle":
		lab._match_state.begin_pitch()
		actor.start_pitch(Proof.parameters(0.65))
		actor._physics_process(0.2)
		if work == "rock":
			for frame in range(40):
				await get_tree().create_timer(0.01).timeout
				if receiver.contacts.size() == 1:
					break
		lab._at_bat_cadence.stop()
	var follow: Tween = receiver._follow
	var rock: Tween = receiver._owned_rock
	var active: Tween = follow if work == "follow" else rock
	var acquired: bool = work == "idle" and not receiver.has_owned_activity()
	if work != "idle":
		acquired = active != null and active.is_valid() and active.is_running()
		acquired = acquired and receiver.contacts.size() == (0 if work == "follow" else 1)
		if paused and acquired:
			active.pause()
			acquired = (
				active.is_valid() and not active.is_running() and receiver.has_owned_activity()
			)
	result.genuine = (
		acquired
		and lab._automation == null
		and not actor.running
		and not is_instance_valid(lab._batted_ball)
		and StadiumPropertyRuntime.authoring_delivery_idle(lab)
	)
	var state: PackedByteArray = Proof.game_state(lab)
	var contacts: PackedByteArray = var_to_bytes(receiver.contacts)
	var outcomes: Array = []
	lab._ball_play_resolver.play_resolved.connect(
		func(value: BallPlayOutcome) -> void:
			outcomes.append([value.result, value.reason, value.caught, value.resolution_position])
	)
	if kind == "receiver":
		property.remove_child(receiver)
	else:
		var actor_parent: Node = actor.get_parent()
		var actor_index: int = actor.get_index()
		actor_parent.remove_child(actor)
		actor_parent.add_child(actor)
		actor_parent.move_child(actor, actor_index)
	result.latched = property._exit_had_owned_activity
	result.cancelled = (
		(follow == null or not follow.is_valid())
		and (rock == null or not rock.is_valid())
		and not receiver.has_owned_activity()
		and not actor.segment_advanced.is_connected(receiver._segment_advanced)
		and not actor.flight_stopped.is_connected(receiver._flight_stopped)
		and not actor.tree_exiting.is_connected(receiver._actor_exiting)
		and not actor.receiver_router.is_valid()
	)
	result.silent = (
		outcomes.is_empty()
		and Proof.game_state(lab) == state
		and var_to_bytes(receiver.contacts) == contacts
	)
	result.teardown = R.teardown(lab)
	var immediate_quarantine: bool = (
		lab.process_mode == Node.PROCESS_MODE_DISABLED
		and lab.get_meta("stadium_npc_runtime_interrupted", false) == true
		and not lab.has_meta("stadium_property")
	)
	var immediate_fence: bool = (
		PhysicalMatchReport.capture(lab).is_empty()
		and lab.get_meta("stadium_npc_retained_lab_only", false) == true
		and lab.get_meta("stadium_npc_ay02_installed_lab_only", false) == true
	)
	result.silent = result.silent and outcomes.is_empty() and Proof.game_state(lab) == state
	await get_tree().process_frame
	result.silent = result.silent and outcomes.is_empty() and Proof.game_state(lab) == state
	result.quarantined = (
		immediate_quarantine
		and lab.process_mode == Node.PROCESS_MODE_DISABLED
		and lab.get_meta("stadium_npc_runtime_interrupted", false) == true
		and not lab.has_meta("stadium_property")
		and not lab.has_meta("stadium_npc_runtime_restoring")
	)
	result.fenced = (
		immediate_fence
		and PhysicalMatchReport.capture(lab).is_empty()
		and lab.get_meta("stadium_npc_retained_lab_only", false) == true
		and lab.get_meta("stadium_npc_ay02_installed_lab_only", false) == true
	)
	if work == "idle":
		result.clean = (
			not result.quarantined
			and not lab.has_meta("stadium_npc_runtime_interrupted")
			and original == _snapshot(lab)
		)
		result.reinstalled = (
			R.install(lab) and R.installed(lab) and R.teardown(lab) and original == _snapshot(lab)
		)
	else:
		var restored: Dictionary = _snapshot(lab)
		result.no_reinstall = not R.install(lab) and restored == _snapshot(lab)
	result.silent = result.silent and outcomes.is_empty() and Proof.game_state(lab) == state
	if kind == "receiver" and is_instance_valid(receiver):
		receiver.free()
	lab.free()
	return result
