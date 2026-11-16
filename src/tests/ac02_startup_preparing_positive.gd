extends Node
## Genuine manual public startup only. No listeners, automation, issuer fabrication,
## clock edits, intermediate-state observers, full-game result, or timing claim.
const ATTEMPT = preload("res://src/presentation/stadium/stadium_npc_ac02_startup_preparing_v1.gd")
const PERF = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const INPUT_SHA: String = "91a8456218b62c6fffa171c97090fed1b2296da4161accbbef93bdab724f7524"
var _app: SeasonApp
var _output: String = ""
var _input: String = ""
var _failures: Array[String] = []
var _evidence: Dictionary = {
	"schema": "STARTUP-PREPARING-POSITIVE-v1",
	"native_visual_acceptance": false,
	"performance_qualified": false,
	"natural_play": false,
	"full_game": false,
	"intermediate_state_sampled": false
}
var _collecting: bool = false
var _inventory_requested: bool = false
var _edge_controls_requested: bool = false
var _mutation_requested: bool = false
var _fallback_requested: bool = false
var _fallback_notifications: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--startup-preproof-mutation":
			_mutation_requested = true
		elif argument == "--startup-unknown-listener-fallback":
			_fallback_requested = true
		elif argument == "--startup-native-edge-controls":
			_edge_controls_requested = true
		elif argument == "--startup-inventory":
			_inventory_requested = true
		elif argument.begins_with("--startup-input="):
			_input = argument.trim_prefix("--startup-input=")
		elif argument.begins_with("--startup-output="):
			_output = argument.trim_prefix("--startup-output=")
	await _run()
	if _collecting:
		PERF.checkpoint("cleanup_begin", {}, "cleanup")
	if is_instance_valid(_app):
		var closed_lab: PitchBatLab = _app.lab
		_need(_app._close_match(), "ordinary close accepted during separate cleanup")
		_need(
			(
				_app.lab == null
				and (
					not is_instance_valid(closed_lab)
					or (closed_lab.get_parent() == null and closed_lab.is_queued_for_deletion())
				)
			),
			"ordinary close released captured lab without following disposed owners"
		)
		_app.queue_free()
		await TestAudioDrain.finish(get_tree())
	if _collecting:
		var profile: Dictionary = PERF.finish_session()
		_need(
			(
				profile.errors.is_empty()
				and profile.open_scopes == 0
				and profile.entries == profile.completed
			),
			"balanced passive collector after cleanup"
		)
		_evidence["all_stages_profile"] = profile
	_evidence["failures"] = _failures
	_evidence["passed"] = _failures.is_empty()
	if _collecting:
		var file: FileAccess = FileAccess.open(_output.path_join("summary.json"), FileAccess.WRITE)
		if _need(file != null, "summary evidence writable"):
			file.store_string(JSON.stringify(_evidence, "\t", true, true) + "\n")
			file.close()
	print("STARTUP_PREPARING positive complete failures=", _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	if not _need(
		(
			_input.is_absolute_path()
			and FileAccess.get_sha256(_input) == INPUT_SHA
			and _output.is_absolute_path()
			and OS.get_cmdline_user_args().has("--physical-in-process")
		),
		"exact retained input and explicit isolated output"
	):
		return
	if not _need(
		(
			DirAccess.make_dir_recursive_absolute(_output) == OK
			and DirAccess.get_files_at(_output).is_empty()
			and DirAccess.get_directories_at(_output).is_empty()
		),
		"fresh empty output"
	):
		return
	if not _need(
		(
			Engine.physics_ticks_per_second == 60
			and Engine.time_scale == 1.0
			and not get_tree().paused
		),
		"ordinary unpaused fixed60 clock"
	):
		return
	if not _need(
		(
			StadiumNpcAc02IssuedQualificationV1.eligible()
			and StadiumNpcPublicRuntime.source_qualified()
		),
		"exact reviewed qualification before startup"
	):
		return
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	var initial: String = FileAccess.get_file_as_string(_input)
	var file: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	if not _need(file != null, "retained primary copy writable"):
		return
	file.store_string(initial)
	file.close()
	if not _need(
		FileAccess.get_sha256(SeasonSave.path) == INPUT_SHA, "byte-preserved retained save"
	):
		return
	await _startup_positive_collect(initial)


func _startup_positive_collect(initial: String) -> void:
	if not _need(PERF.begin_session(_output), "existing passive collector started"):
		return
	_collecting = true
	await get_tree().process_frame
	PERF.checkpoint("cold_restore_begin", {}, "cold_restore")
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	if not _need(
		(
			_app.season != null
			and ClubCareer.same(JSON.parse_string(initial), SeasonSave.snapshot(_app.season))
			and ClubCareer.same(
				_app.season.pending_fixture(), {"id": 0, "round": 0, "away": 0, "home": 5}
			)
		),
		"ordinary cold restore of exact pending AC02 fixture"
	):
		return
	if _mutation_requested:
		_coordinator_preproof_mutation()
		return
	if _fallback_requested:
		_public_unknown_listener_fallback()
		return
	if _edge_controls_requested:
		_evidence["mode"] = "native_app_edge_component_controls_no_Play"
		_native_edge_controls()
		return
	if _inventory_requested:
		# Explicit read-only admission diagnostic BEFORE Play. Never enroll or attach.
		var detached: PitchBatLab = PitchBatLab.new()
		var tree_signals: Array[StringName] = [
			&"tree_entered",
			&"tree_exiting",
			&"tree_exited",
			&"child_entered_tree",
			&"child_exiting_tree",
			&"child_order_changed",
			&"ready"
		]
		_evidence["mode"] = "read_only_preplay_admission_inventory"
		_evidence["admission_inventory"] = {
			"app": _named_edges(_app, tree_signals),
			"default_unconfigured_detached_lab": _named_edges(detached, tree_signals),
			"scene_tree": _named_edges(get_tree(), [&"node_added", &"node_removed"])
		}
		detached.free()
		print("STARTUP_PREPARING read-only admission inventory complete; Play not called")
		return
	PERF.checkpoint("public_startup_begin", {}, "public_startup")
	_app.play_season_game()
	if not is_instance_valid(_app.lab):
		_evidence["failed_startup_post_disposal"] = _failed_startup_observation()
	_startup_positive_profile()


func _startup_positive_profile() -> void:
	var startup_profile: Dictionary = PERF.snapshot()
	PERF.checkpoint("public_startup_returned", {}, "post_startup_observation")
	_evidence["startup_profile"] = startup_profile
	if not _need(is_instance_valid(_app.lab), "genuine public Play retained lab"):
		return
	var lab: PitchBatLab = _app.lab
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	var attempt: RefCounted = lab._ac02_startup_attempt
	if not _need(
		(
			is_instance_valid(property)
			and attempt != null
			and attempt.get_script() == ATTEMPT
			and lab._ac02_startup_enrolled
			and lab._ac02_startup_committed
			and property._ac02_startup_enrolled
			and property._ac02_startup_committed
			and property._ac02_startup_attempt == attempt
			and attempt.state == ATTEMPT.State.COMMITTED
			and attempt.setup_complete
			and not attempt.executing
		),
		"executed PREPARING committed exactly captured attempt"
	):
		return
	if not _need(
		(
			lab._match_state != null
			and lab._field_definition != null
			and lab._match_presentation_director != null
			and is_instance_valid(lab._presentation_backdrop)
			and is_instance_valid(lab._presentation_title)
			and is_instance_valid(lab._presentation_subtitle)
			and is_instance_valid(lab._camera)
			and lab._camera_director != null
			and is_instance_valid(property.ac02_guides)
			and is_instance_valid(property.receiver)
		),
		"captured match and presentation owners present before readback"
	):
		return
	var issue: StadiumNpcAc02IssuedStateV1 = property._ac02_issue
	_need(
		(
			issue != null
			and issue == property._ac02_issue_pin
			and issue == lab._ac02_issued_owner
			and issue.state == StadiumNpcAc02IssuedStateV1.Lifetime.ACTIVE
			and issue.generation == 1
			and property._ac02_generation == 1
			and issue._bindings_pin.get("lab") == lab
			and issue._bindings_pin.get("match") == lab._match_state
			and issue._bindings_pin.get("automation") == null
			and issue._bindings_pin.get("property") == property
			and issue._bindings_pin.get("camera") == lab._camera
			and issue._bindings_pin.get("director") == lab._camera_director
			and issue._bindings_pin.get("guides") == property.ac02_guides
			and issue._bindings_pin.get("receiver") == property.receiver
		),
		"genuine ACTIVE issued owner after committed proof path"
	)
	for label: String in [
		"stadium_npc_public_runtime._complete",
		"stadium_npc_public_runtime._construction_same",
		"stadium_npc_ac02_public_construction.same"
	]:
		_need(
			(
				_count(startup_profile, label, "calls") == 1
				and _count(startup_profile, label, "completed") == 1
			),
			"one completed startup comparison: " + label
		)
	for label: String in [
		"stadium_npc_public_runtime._stage", "stadium_npc_public_runtime._commit"
	]:
		_need(_count(startup_profile, label, "calls") == 0, "no historical startup stage: " + label)
	_need(
		(
			startup_profile.errors.is_empty()
			and startup_profile.open_scopes == 0
			and startup_profile.entries == startup_profile.completed
		),
		"startup comparison scopes completed"
	)
	_need(
		(
			lab._automation == null
			and lab._managed_match
			and not lab._player_home
			and lab._batted_ball == null
			and lab._active_play_record == null
			and lab._play_records.is_empty()
			and lab._throw_number == 0
			and lab._match_state.stadium.manifest.id == "AC-02"
			and lab._match_state.stadium.environment.mode == "day"
			and property.public_snapshot == lab._match_state.stadium
			and property.bound_state == lab._match_state
		),
		"normal manual AC02 Day canonical startup state"
	)
	_need(
		(
			lab._match_presentation_director.blocks_gameplay()
			and lab._presentation_backdrop.visible
			and lab._presentation_title.text == "GAME START"
			and (
				lab._presentation_subtitle.text
				== (
					"%s at %s\n%s"
					% [
						lab._match_state.away_team.display_name,
						lab._match_state.home_team.display_name,
						lab._field_definition.display_name
					]
				)
			)
		),
		"ordinary manual intro presentation state"
	)
	_evidence["attempt_state"] = attempt.state
	_evidence["issuer_state"] = issue.state if issue != null else -1
	_evidence["active_order_evidence"] = \
		("Executed COMMITTED attempt plus exactly one completed deep " + \
		"comparison; independent source review establishes assignment-only " + \
		"ACTIVE-last ordering. No intermediate state sampled.")
	_evidence["fixture"] = _app.season.pending_fixture().duplicate(true)
	_evidence["stadium"] = lab._match_state.stadium.duplicate(true)
	_evidence["input_sha256"] = INPUT_SHA


func _count(profile: Dictionary, label: String, field: String) -> int:
	var result: int = 0
	for row: Dictionary in profile.rows:
		if row.stage == "public_startup" and row.label == label:
			result += int(row[field])
	return result


func _need(ok: bool, message: String) -> bool:
	print("STARTUP_PREPARING ", "PASS " if ok else "FAIL ", message)
	if not ok:
		_failures.append(message)
	return ok


func _named_edges(emitter: Object, names: Array[StringName]) -> Dictionary:
	# Fixed admission emitters only; no callback execution, connection, or graph walk.
	var result: Dictionary = {}
	for signal_name: StringName in names:
		var rows: Array[Dictionary] = []
		for edge: Dictionary in emitter.get_signal_connection_list(signal_name):
			var callback: Callable = edge.callable
			var target: Object = callback.get_object()
			var target_script: Script = target.get_script() if is_instance_valid(target) else null
			var argument_types: Array[String] = []
			var argument_identity: Array[Dictionary] = []
			for argument: Variant in callback.get_bound_arguments():
				argument_types.append(type_string(typeof(argument)))
				argument_identity.append(
					{
						"same_emitter": is_same(argument, emitter),
						"same_app": is_same(argument, _app)
					}
				)
			rows.append(
				{
					"target_id": callback.get_object_id(),
					"target_class": target.get_class() if is_instance_valid(target) else "<none>",
					"target_script": target_script.resource_path if target_script != null else "",
					"method": String(callback.get_method()),
					"flags": int(edge.flags),
					"custom_callable": callback.is_custom(),
					"bound_argument_types": argument_types,
					"target_is_app_viewport": is_same(target, _app.get_viewport()),
					"target_is_tree_root": is_same(target, get_tree().root),
					"bound_argument_identity": argument_identity,
					"unbound_argument_count": callback.get_unbound_arguments_count()
				}
			)
		result[String(signal_name)] = rows
	return result


func _native_edge_controls() -> void:
	# Explicit component mode, separate from the read-only inventory mode.
	# The second ordinary app supplies a genuine native edge bound to another parent.
	var donor: SeasonApp = SeasonApp.new()
	get_tree().root.add_child(donor)
	var edges: Array = _app.get_signal_connection_list(&"child_order_changed")
	var donor_edges: Array = donor.get_signal_connection_list(&"child_order_changed")
	if not _need(
		edges.size() == 1 and donor_edges.size() == 1,
		"one native app edge for each captured parent"
	):
		donor.queue_free()
		return
	var edge: Dictionary = edges[0]
	_need(ATTEMPT._tree_edges(_app, _app), "genuine observed app native edge accepted")
	_need(
		not ATTEMPT._tree_edges(_app),
		"native exception not available to ordinary emitter admission"
	)
	_need(
		not ATTEMPT._app_canvas_edge(donor, _app, &"child_order_changed", edge),
		"wrong emitter refused"
	)
	_need(
		not ATTEMPT._app_canvas_edge(_app, _app, &"child_order_changed", donor_edges[0]),
		"genuine native edge bound to wrong parent refused"
	)
	var altered: Dictionary = edge.duplicate()
	altered.flags = 0
	_need(
		not ATTEMPT._app_canvas_edge(_app, _app, &"child_order_changed", altered),
		"altered native flags refused"
	)
	altered = edge.duplicate()
	var original: Callable = edge.callable
	altered.callable = original.unbind(1)
	_need(
		not ATTEMPT._app_canvas_edge(_app, _app, &"child_order_changed", altered),
		"nonzero unbound count refused"
	)
	var unknown: Callable = Callable(self, "_unexpected_tree_edge")
	var connected: int = _app.child_order_changed.connect(unknown)
	_need(connected == OK, "unknown-listener fixture connected without emission")
	if connected == OK:
		_need(not ATTEMPT._tree_edges(_app, _app), "additional unknown listener refuses admission")
		_app.child_order_changed.disconnect(unknown)
	_need(
		ATTEMPT._tree_edges(_app, _app), "native-only edge restored after exact fixture disconnect"
	)
	donor.queue_free()
	print("STARTUP_PREPARING native edge component controls complete; Play not called")


func _unexpected_tree_edge() -> void:
	_need(false, "component fixture listener must never execute")


func _failed_startup_observation() -> Dictionary:
	# Synchronous after SeasonApp disposed the attempt, before await/frame drain.
	# This is first-reason evidence only, not pre-disposal guide/receiver state.
	var rows: Array[Dictionary] = []
	for child: Node in _app.get_children():
		if child.get_script() != PitchBatLab or not child.is_queued_for_deletion():
			continue
		var lab: PitchBatLab = child as PitchBatLab
		var captured: RefCounted = lab._ac02_startup_attempt
		if captured == null or captured.get_script() != ATTEMPT:
			continue
		var property: StadiumNpcPublicProperty = captured.property
		rows.append(
			{
				"reason": captured.reason,
				"state": int(captured.state),
				"setup_complete": captured.setup_complete,
				"executing": captured.executing,
				"captured_app_is_app": captured.app == _app,
				"captured_lab_is_child": captured.lab == lab,
				"lab_parent_is_app": lab.get_parent() == _app,
				"lab_enrolled": lab._ac02_startup_enrolled,
				"lab_committed": lab._ac02_startup_committed,
				"property_valid": is_instance_valid(property),
				"property_detached": is_instance_valid(property) and property.get_parent() == null,
				"original_count": captured.originals.size()
			}
		)
	return {
		"scope": "synchronous_post_disposal_before_frame_drain", "queued_captured_attempts": rows
	}


func _coordinator_preproof_mutation() -> void:
	_evidence["mode"] = "real_coordinator_setup_then_preproof_native_mesh_mutation"
	if not _need(SeasonPregameCommit.save(_app), "coordinator ordinary pregame checkpoint"):
		return
	var checkpoint_sha: String = FileAccess.get_sha256(SeasonSave.path)
	var fixture: Dictionary = _app.season.pending_fixture()
	var field: FieldDefinition = SeasonState.field_for_fixture(fixture, _app.season)
	var state: MatchState = _app.season.make_match()
	if not _need(
		(
			field != null
			and state != null
			and fixture.home != 0
			and StadiumNpcSnapshot.matches_fixture(state.stadium, _app.season, fixture)
		),
		"coordinator exact ordinary away-match inputs"
	):
		return
	# Same ordinary app/lab setup assignments; only the final continuation is held by test.
	_app._fixture_id = fixture.id
	state.performance.track_fielding = ClubPlayerLegend.enabled(_app.season)
	_app.sales.reset()
	state.inventory_boundary.connect(_app.sales.apply_pending.bind(_app))
	_app._season_game = true
	_app._busy = false
	_app._result_recorded = false
	_app._result_saved = false
	_app._ac02_settlement_ticket.clear()
	_app.loadout.close()
	_app.loadout.match_snapshot = SeasonLoadoutData.capture(_app.season)
	_app.menu.hide()
	var lab: PitchBatLab = PitchBatLab.new()
	_app.lab = lab
	lab.name = "ActiveMatch"
	lab._configured_match = state
	lab._npc_season = _app.season
	lab._stadium_ledger = null
	lab._field_id = field.id
	lab._player_home = false
	lab._managed_match = true
	lab.match_return_requested.connect(_app.finish_game)
	lab.menu_exit_requested.connect(_app.ask_leave_game)
	var attempt: RefCounted = ATTEMPT.new()
	PERF.checkpoint("coordinator_setup_begin", {}, "public_startup")
	if not _need(attempt.enroll(_app, lab), "coordinator genuine single-use enrollment"):
		_app.lab = null
		lab.free()
		return
	_app.add_child(lab)
	var property: StadiumNpcPublicProperty = attempt.property
	if not _need(
		(
			attempt.setup_complete
			and attempt.state == ATTEMPT.State.PREPARING
			and attempt.setup_owners(property)
		),
		"coordinator full actual ready setup completed before mutation"
	):
		attempt.dispose()
		return
	var model: Node3D = property.objects.get("npc:AC-02:r1:FOUL-POLE-L")
	var meshes: Array[Node] = (
		model.get_node("Visual").find_children("*", "MeshInstance3D", true, false)
		if is_instance_valid(model) and model.has_node("Visual")
		else []
	)
	if not _need(
		not meshes.is_empty() and meshes[0].get_script() == null,
		"coordinator exact native foul-pole visual mutation target"
	):
		attempt.dispose()
		return
	var mesh: MeshInstance3D = meshes[0] as MeshInstance3D
	var before: Vector3 = mesh.position
	mesh.position = before + Vector3(0.125, 0, 0)
	var published: bool = attempt.validate_and_publish()
	var profile: Dictionary = PERF.snapshot()
	PERF.checkpoint("coordinator_proof_returned", {}, "post_startup_observation")
	_evidence["startup_profile"] = profile
	_evidence["before_disposal"] = {
		"reason": attempt.reason,
		"state": int(attempt.state),
		"setup_complete": attempt.setup_complete,
		"published": published,
		"attempt_committed": lab._ac02_startup_committed,
		"issue_state": int(attempt.issue.state) if attempt.issue != null else -1,
		"native_mesh_path": String(property.get_path_to(mesh)),
		"local_x_delta": mesh.position.x - before.x
	}
	_need(
		(
			not published
			and attempt.state == ATTEMPT.State.ABORTED
			and attempt.reason == "final actual proof refused"
			and not lab._ac02_startup_committed
			and attempt.issue != null
			and attempt.issue.state != StadiumNpcAc02IssuedStateV1.Lifetime.ACTIVE
		),
		"actual native geometry mismatch rejected by final proof without publication"
	)
	for label: String in [
		"stadium_npc_public_runtime._complete",
		"stadium_npc_public_runtime._construction_same",
		"stadium_npc_ac02_public_construction.same"
	]:
		_need(
			_count(profile, label, "calls") == 1 and _count(profile, label, "completed") == 1,
			"mutated coordinator reaches exactly one complete comparison " + label
		)
	_need(
		(
			not StadiumNpcPublicRuntime.installed(lab)
			and not PitchBatLabFeelSupport._public_export_intact(lab)
			and not StadiumNpcAc02IssuedStateV1.before_settlement(lab)
			and lab._active_play_record == null
			and lab._play_records.is_empty()
		),
		"failed coordinator denies public/export/settlement without records"
	)
	attempt.dispose()
	_evidence["after_disposal"] = {
		"app_lab_cleared": _app.lab == null,
		"captured_lab_queued": lab.is_queued_for_deletion(),
		"checkpoint_sha256": FileAccess.get_sha256(SeasonSave.path)
	}
	_need(
		(
			_app.lab == null
			and lab.is_queued_for_deletion()
			and FileAccess.get_sha256(SeasonSave.path) == checkpoint_sha
		),
		"failed coordinator captured disposal preserves ordinary pregame checkpoint"
	)


func _public_unknown_listener_fallback() -> void:
	_evidence["mode"] = "public_play_unknown_app_listener_historical_fallback"
	var listener: Callable = _fallback_notification
	_app.child_order_changed.connect(listener)
	PERF.checkpoint("fallback_public_startup_begin", {}, "public_startup")
	_app.play_season_game()
	var profile: Dictionary = PERF.snapshot()
	_app.child_order_changed.disconnect(listener)
	PERF.checkpoint("fallback_public_startup_returned", {}, "post_startup_observation")
	_evidence["startup_profile"] = profile
	_evidence["benign_listener_notifications"] = _fallback_notifications
	if not _need(is_instance_valid(_app.lab), "historical fallback retains real public lab"):
		return
	_need(
		not _app.lab._ac02_startup_enrolled and _app.lab._ac02_startup_attempt == null,
		"unknown listener never enrolls PREPARING"
	)
	for label: String in [
		"stadium_npc_public_runtime._stage", "stadium_npc_public_runtime._commit"
	]:
		_need(
			_count(profile, label, "calls") == 1 and _count(profile, label, "completed") == 1,
			"literal historical fallback " + label
		)
	_need(
		(
			_count(profile, "stadium_npc_ac02_public_construction.same", "calls") == 7
			and _count(profile, "stadium_npc_ac02_public_construction.same", "completed") == 7
		),
		"historical public fallback retains seven complete comparisons"
	)


func _fallback_notification() -> void:
	_fallback_notifications += 1
