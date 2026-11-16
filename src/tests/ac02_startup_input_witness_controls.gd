extends Node
## Bounded component controls plus one actual pending setup, not native acceptance,
## full gameplay, or performance qualification. Never restore the installed attempt.
const ATTEMPT = preload("res://src/presentation/stadium/stadium_npc_ac02_startup_preparing_v1.gd")
const PERF = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const INPUT_SHA: String = "91a8456218b62c6fffa171c97090fed1b2296da4161accbbef93bdab724f7524"


class CustomAdmissionLab:
	extends PitchBatLab


var _app: SeasonApp
var _input: String = ""
var _output: String = ""
var _collecting: bool = false
var _failures: Array[String] = []
var _evidence: Dictionary = {
	"schema": "STARTUP-INPUT-WITNESS-CONTROLS-v1",
	"native_visual_acceptance": false,
	"performance_qualified": false,
	"full_game": false,
	"installed_attempt_restored": false,
	"actual_geometry_installs": 0,
	"pure_controls_are_sticky_abort_evidence": false
}


func _ready() -> void:
	# A real scene load and helper instantiation, before input IO, owners or setup.
	if OS.get_cmdline_user_args().has("--parse-only"):
		var parsed: RefCounted = ATTEMPT.new()
		var valid: bool = (
			parsed != null
			and parsed.get_script() == ATTEMPT
			and parsed.CONTRACT == "ac02-native-manual-startup-preparing-v2"
		)
		print(
			"STARTUP_INPUT_WITNESS parse-only loaded=true helper_instantiated=",
			valid,
			" setup_started=false"
		)
		get_tree().quit(0 if valid else 1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--startup-input="):
			_input = argument.trim_prefix("--startup-input=")
		elif argument.begins_with("--startup-output="):
			_output = argument.trim_prefix("--startup-output=")
	await _run()
	if _collecting:
		PERF.checkpoint("cleanup_begin", {}, "cleanup")
	if is_instance_valid(_app):
		if is_instance_valid(_app.lab):
			_app._close_match()
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
	print("STARTUP_INPUT_WITNESS controls complete failures=", _failures.size())
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
		"exact reviewed qualification before setup"
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
	await _startup_witness_collect(initial)


func _startup_witness_collect(initial: String) -> void:
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
	_coordinator_controls()
	_need(
		FileAccess.get_sha256(_input) == INPUT_SHA,
		"retained input still byte-identical after controls"
	)


func _coordinator_controls() -> void:
	# Literal actual pending setup from ac02_startup_preparing_positive.gd, with only
	# the final continuation held by this test. Three earlier labs stay unattached.
	if not _need(SeasonPregameCommit.save(_app), "coordinator ordinary pregame checkpoint"):
		return
	var checkpoint_sha: String = FileAccess.get_sha256(SeasonSave.path)
	var fixture: Dictionary = _app.season.pending_fixture()
	var field: FieldDefinition = SeasonState.field_for_fixture(fixture, _app.season)
	var match_state: MatchState = _app.season.make_match()
	if not _need(
		(
			field != null
			and match_state != null
			and fixture.home != 0
			and StadiumNpcSnapshot.matches_fixture(match_state.stadium, _app.season, fixture)
		),
		"coordinator exact ordinary away-match inputs"
	):
		return
	_app._fixture_id = fixture.id
	match_state.performance.track_fielding = ClubPlayerLegend.enabled(_app.season)
	_app.sales.reset()
	match_state.inventory_boundary.connect(_app.sales.apply_pending.bind(_app))
	_app._season_game = true
	_app._busy = false
	_app._result_recorded = false
	_app._result_saved = false
	_app._ac02_settlement_ticket.clear()
	_app.loadout.close()
	_app.loadout.match_snapshot = SeasonLoadoutData.capture(_app.season)
	_app.menu.hide()
	_custom_owner_admission(match_state, field)
	for slot: String in ["_witness", "_sources", "snapshot"]:
		_unattached_pin_control(match_state, field, slot)
	if not _failures.is_empty():
		return
	var lab: PitchBatLab = _configured_lab(match_state, field)
	var attempt: RefCounted = ATTEMPT.new()
	PERF.checkpoint("coordinator_setup_begin", {}, "public_startup")
	if not _need(attempt.enroll(_app, lab), "coordinator genuine single-use enrollment"):
		_app.lab = null
		lab.free()
		return
	_app.add_child(lab)
	_evidence["actual_geometry_installs"] = 1
	var property: StadiumNpcPublicProperty = attempt.property
	if not _need(
		(
			attempt.setup_complete
			and attempt.state == ATTEMPT.State.PREPARING
			and attempt.setup_owners(property)
		),
		"full actual ready setup completed before witness controls"
	):
		attempt.dispose()
		return
	var before: Dictionary = _semantic_calls(PERF.snapshot())
	_need(attempt.context(), "genuine pending context positive")
	_need(
		_semantic_calls(PERF.snapshot()) == before,
		"positive routine context performs no normalized or matches_fixture calls"
	)
	_readonly_and_alias_controls(attempt)
	_detached_content_controls(attempt)
	_detached_identity_controls(attempt)
	_type_and_budget_controls(attempt)
	_need(
		attempt.context() and attempt.state == ATTEMPT.State.PREPARING,
		"detached pure controls leave actual pending attempt unchanged"
	)
	_camera_guard_refusal(attempt, checkpoint_sha)


func _configured_lab(
	match_state: MatchState, field: FieldDefinition, candidate: PitchBatLab = null
) -> PitchBatLab:
	var lab: PitchBatLab = candidate if candidate != null else PitchBatLab.new()
	_app.lab = lab
	lab.name = "ActiveMatch"
	lab._configured_match = match_state
	lab._npc_season = _app.season
	lab._stadium_ledger = null
	lab._field_id = field.id
	lab._player_home = false
	lab._managed_match = true
	lab.match_return_requested.connect(_app.finish_game)
	lab.menu_exit_requested.connect(_app.ask_leave_game)
	return lab


func _custom_owner_admission(match_state: MatchState, field: FieldDefinition) -> void:
	# Empty subclass only. No custom gameplay, tree insertion, or geometry fixture.
	var lab: PitchBatLab = _configured_lab(match_state, field, CustomAdmissionLab.new())
	var attempt: RefCounted = ATTEMPT.new()
	var raw: Dictionary = match_state.stadium
	var selected: Dictionary = _app.season.pending_fixture()
	_need(
		(
			lab.get_script() != PitchBatLab
			and lab.get_parent() == null
			and not attempt.enroll(_app, lab)
		),
		"custom-owner admission declines otherwise valid configured lab"
	)
	_need(
		(
			not attempt._enrolled
			and not lab._ac02_startup_enrolled
			and lab._ac02_startup_attempt == null
			and attempt.app == null
			and attempt.lab == null
			and attempt._witness.is_empty()
			and attempt._sources.is_empty()
			and _app.lab == lab
			and lab._configured_match == match_state
			and is_same(match_state.stadium, raw)
			and is_same(_app.season.pending_fixture(), selected)
		),
		"custom-owner decline has no enrollment markers or owner/input replacement"
	)
	_evidence["custom_owner_admission"] = \
		"Pre-enrollment decline only; never attached and no historical gameplay claim."
	_app.lab = null
	lab.free()


func _unattached_pin_control(match_state: MatchState, field: FieldDefinition, slot: String) -> void:
	var lab: PitchBatLab = _configured_lab(match_state, field)
	var attempt: RefCounted = ATTEMPT.new()
	if not _need(
		attempt.enroll(_app, lab) and attempt.context(),
		"genuine unattached enrollment positive before " + slot + " replacement"
	):
		_app.lab = null
		lab.free()
		return
	var original: Dictionary = attempt.get(slot)
	# Equal-content replacement has the same readonly property, so identity pinning
	# rather than mere mutability is what this observed mismatch exercises.
	var replacement: Dictionary = original.duplicate()
	replacement.make_read_only()
	attempt.set(slot, replacement)
	_need(
		(
			not is_same(original, replacement)
			and not attempt.context()
			and attempt.state == ATTEMPT.State.ABORTED
			and attempt.reason == "startup context changed"
		),
		"equal-content " + slot + " replacement immediately aborts unattached enrollment"
	)
	# Explicitly limited to this never-installed aborted component. No production
	# attempt is restored, and these assignments never manufacture a new lifetime.
	attempt.set(slot, original)
	_need(
		(
			not attempt.context()
			and not attempt.validate_and_publish()
			and attempt.state == ATTEMPT.State.ABORTED
			and not attempt.committed()
			and attempt.issue == null
			and not lab._ac02_startup_committed
		),
		"restored " + slot + " cannot revive an aborted unattached enrollment"
	)
	_need(
		(
			not StadiumNpcPublicRuntime.installed(lab)
			and not PitchBatLabFeelSupport._public_export_intact(lab)
			and not StadiumNpcAc02IssuedStateV1.before_settlement(lab)
		),
		"unattached " + slot + " refusal keeps public/export/settlement denial"
	)
	attempt.dispose()
	_need(
		_app.lab == null and lab.is_queued_for_deletion() and lab.get_parent() == null,
		"unattached " + slot + " refusal releases only its captured lab"
	)


func _readonly_and_alias_controls(attempt: RefCounted) -> void:
	var expected: Dictionary = attempt._witness
	_need(
		(
			is_same(expected, attempt._witness_pin)
			and expected.is_read_only()
			and is_same(attempt._sources, attempt._sources_pin)
			and attempt._sources.is_read_only()
		),
		"real witness and source-table pins are readonly original identities"
	)
	_need(
		is_same(attempt.snapshot, attempt._snapshot_pin) and attempt.snapshot.is_read_only(),
		"canonical setup snapshot also retains its readonly identity pin"
	)
	_need(
		_detached_readonly(attempt.snapshot, attempt.snapshot.duplicate(true)),
		"canonical snapshot is deeply readonly without raw representation assumptions"
	)
	for key: String in ATTEMPT.INPUT_ROOTS:
		_need(
			_detached_readonly(expected[key], attempt._sources[key]),
			"every witness container detached and deeply readonly: " + key
		)
		_need(not attempt._sources[key].is_read_only(), "live input root remains mutable: " + key)
	_need(
		ATTEMPT._same_input(expected.duplicate(true), expected),
		"deep detached typed witness copy matches real expected contents"
	)


func _detached_readonly(expected: Variant, actual: Variant) -> bool:
	if typeof(expected) != typeof(actual):
		return false
	if expected is Dictionary:
		if (
			not expected.is_read_only()
			or is_same(expected, actual)
			or expected.size() != actual.size()
		):
			return false
		for key: String in expected:
			if not actual.has(key) or not _detached_readonly(expected[key], actual[key]):
				return false
	elif expected is Array:
		if (
			not expected.is_read_only()
			or is_same(expected, actual)
			or expected.size() != actual.size()
		):
			return false
		for index in range(expected.size()):
			if not _detached_readonly(expected[index], actual[index]):
				return false
	return true


func _detached_content_controls(attempt: RefCounted) -> void:
	var expected: Dictionary = attempt._witness
	var candidate: Dictionary = expected.duplicate(true)
	candidate.stadium.environment.mode = "witness-negative-mode"
	_need(
		not ATTEMPT._same_input(candidate, expected),
		"nested raw stadium change refused by pure comparer"
	)
	var unused_club: String = _other_key(
		expected.npc_venues.assignments, str(expected.pending.home)
	)
	var unused_environment: String = _other_key(
		expected.npc_venues.environments, str(expected.pending.id)
	)
	if not _need(
		not unused_club.is_empty() and not unused_environment.is_empty(),
		"retained fixture has nonselected assignment and unused environment"
	):
		return
	candidate = expected.duplicate(true)
	candidate.npc_venues.assignments[unused_club]["witness_negative"] = true
	_need(not ATTEMPT._same_input(candidate, expected), "nonselected assignment contents refused")
	candidate = expected.duplicate(true)
	candidate.npc_venues.environments[unused_environment]["mode"] = "witness-negative-mode"
	_need(not ATTEMPT._same_input(candidate, expected), "unused environment contents refused")
	for key: String in ["quota", "streams"]:
		candidate = expected.duplicate(true)
		candidate.npc_venues[key]["witness_negative"] = true
		_need(
			not ATTEMPT._same_input(candidate, expected),
			"complete assignment metadata refused: " + key
		)
	for key: String in ["season_seed", "run", "phase", "round_index"]:
		candidate = expected.duplicate(true)
		candidate[key] = int(candidate[key]) + 1
		_need(not ATTEMPT._same_input(candidate, expected), "captured scalar value refused: " + key)
		candidate = expected.duplicate(true)
		candidate[key] = float(candidate[key])
		_need(
			not ATTEMPT._same_input(candidate, expected),
			"captured scalar numeric type refused: " + key
		)
	if _need(expected.schedule.size() > 1, "retained schedule has row/order controls"):
		candidate = expected.duplicate(true)
		candidate.schedule[1]["round"] = int(candidate.schedule[1].round) + 1
		_need(
			not ATTEMPT._same_input(candidate, expected), "nonselected schedule row content refused"
		)
		candidate = expected.duplicate(true)
		var row: Dictionary = candidate.schedule[0]
		candidate.schedule[0] = candidate.schedule[1]
		candidate.schedule[1] = row
		_need(not ATTEMPT._same_input(candidate, expected), "schedule row order refused")
		candidate = expected.duplicate(true)
		candidate.schedule.insert(0, expected.pending.duplicate(true))
		_need(
			not ATTEMPT._same_input(candidate, expected),
			"earlier duplicate fixture insertion refused"
		)
	for key: String in ["semifinals", "final_fixture", "final_venue"]:
		candidate = expected.duplicate(true)
		if candidate[key] is Array:
			candidate[key].append(expected.pending.duplicate(true))
		else:
			candidate[key]["witness_negative"] = true
		_need(
			not ATTEMPT._same_input(candidate, expected),
			"complete conservative root refused: " + key
		)
	_evidence["content_controls"] = \
		("Detached copies only; whole assignments/environments/quota/streams, " + \
		"scalars, schedule and conservative roots. No production context was " + "changed.")


func _detached_identity_controls(attempt: RefCounted) -> void:
	# A never-enrolled, never-installed plain view uses the real frozen expected data.
	# Its owners and source table are test inputs only; it is never given authority.
	var expected: Dictionary = attempt._witness
	var view: SeasonState = SeasonState.new()
	var match_view: MatchState = MatchState.new()
	var career_view: ClubCareer = ClubCareer.new()
	career_view.current = expected.run
	view.career = career_view
	view.season_seed = expected.season_seed
	view.phase = expected.phase
	view.round_index = expected.round_index
	match_view.stadium = expected.stadium.duplicate(true)
	view.npc_venues = expected.npc_venues.duplicate(true)
	view.schedule.assign(expected.schedule.duplicate(true))
	view.semifinals.assign(expected.semifinals.duplicate(true))
	view.final_fixture = expected.final_fixture.duplicate(true)
	view.final_venue = expected.final_venue.duplicate(true)
	var sources: Dictionary = attempt._sources.duplicate()
	sources.match = match_view
	sources.season = view
	sources.career = career_view
	sources.stadium = match_view.stadium
	for key: String in ["npc_venues", "schedule", "semifinals", "final_fixture", "final_venue"]:
		sources[key] = view.get(key)
	sources.pending = view.pending_fixture()
	sources.selected = ATTEMPT._selected_source(view, expected.pending.id)
	if not _need(
		ATTEMPT._inputs_match(match_view, view, sources, expected),
		"detached plain owner view matches real frozen witness"
	):
		return
	var match_swap: MatchState = MatchState.new()
	match_swap.stadium = match_view.stadium
	_need(
		not ATTEMPT._inputs_match(match_swap, view, sources, expected),
		"same-root exact-script match owner replacement refused in pure view"
	)
	var season_swap: SeasonState = SeasonState.new()
	for key: String in [
		"season_seed",
		"phase",
		"round_index",
		"career",
		"npc_venues",
		"schedule",
		"semifinals",
		"final_fixture",
		"final_venue"
	]:
		season_swap.set(key, view.get(key))
	_need(
		not ATTEMPT._inputs_match(match_view, season_swap, sources, expected),
		"same-input exact-script season owner replacement refused in pure view"
	)
	for key: String in [
		"stadium", "npc_venues", "schedule", "semifinals", "final_fixture", "final_venue"
	]:
		var owner: Object = match_view if key == "stadium" else view
		var original: Variant = owner.get(key)
		owner.set(key, original.duplicate(true))
		_need(
			not ATTEMPT._inputs_match(match_view, view, sources, expected),
			"equal-content root identity replacement refused in pure view: " + key
		)
		owner.set(key, original)
	for key: String in ["pending", "selected"]:
		var replaced_sources: Dictionary = sources.duplicate()
		replaced_sources[key] = sources[key].duplicate(true)
		_need(
			not ATTEMPT._inputs_match(match_view, view, replaced_sources, expected),
			"equal-content row identity replacement refused in pure view: " + key
		)
	var pending_index: int = -1
	for index in range(view.schedule.size()):
		if is_same(view.schedule[index], sources.pending):
			pending_index = index
			break
	if _need(pending_index >= 0, "retained pending row resides in regular schedule"):
		var original_row: Dictionary = view.schedule[pending_index]
		view.schedule[pending_index] = original_row.duplicate(true)
		_need(
			not ATTEMPT._inputs_match(match_view, view, sources, expected),
			"equal-content actual schedule row replacement refused in pure view"
		)
		view.schedule[pending_index] = original_row
	for key: String in ["season_seed", "phase", "round_index"]:
		var original: int = view.get(key)
		view.set(key, original + 1)
		_need(
			not ATTEMPT._inputs_match(match_view, view, sources, expected),
			"live scalar accessor refused in pure view: " + key
		)
		view.set(key, original)
	career_view.current += 1
	_need(
		not ATTEMPT._inputs_match(match_view, view, sources, expected),
		"career current run change refused in pure view"
	)
	career_view.current = expected.run
	var replacement_career: ClubCareer = ClubCareer.new()
	replacement_career.current = expected.run
	view.career = replacement_career
	_need(
		not ATTEMPT._inputs_match(match_view, view, sources, expected),
		"equal-run career identity swap refused in pure view"
	)
	view.career = null
	sources.career = null
	view._npc_replay_run = expected.run
	_need(
		ATTEMPT._inputs_match(match_view, view, sources, expected),
		"null-career effective replay run positive in pure view"
	)
	view._npc_replay_run += 1
	_need(
		not ATTEMPT._inputs_match(match_view, view, sources, expected),
		"null-career replay run change refused in pure view"
	)
	_evidence["identity_controls"] = ("Never-enrolled detached owner view only; six roots, " + \
		"pending/selected/actual row, seed/phase/round and career/current or " + \
		"null-career replay run.")


func _type_and_budget_controls(attempt: RefCounted) -> void:
	var expected: Dictionary = attempt._witness
	var candidate: Dictionary = expected.duplicate(true)
	candidate.stadium.version = float(candidate.stadium.version)
	_need(
		not ATTEMPT._same_input(candidate, expected),
		"equal numeric int-to-float stadium value refused"
	)
	candidate = expected.duplicate(true)
	var before: float = candidate.stadium.manifest.instances[0].transform[0]
	var after: float = before + 0.000000000001
	candidate.stadium.manifest.instances[0].transform[0] = after
	_need(
		(
			before != after
			and PackedFloat32Array([before])[0] == PackedFloat32Array([after])[0]
			and not ATTEMPT._same_input(candidate, expected)
		),
		"raw transform change erased by float32 remains refused by exact witness"
	)
	candidate = expected.duplicate(true)
	candidate.stadium.environment.mode = RefCounted.new()
	_need(
		not ATTEMPT._same_input(candidate, expected),
		"introduced opaque value refused without reflection"
	)
	candidate = expected.duplicate(true)
	var authority: String = candidate.stadium.authority
	candidate.stadium.erase("authority")
	candidate.stadium[19] = authority
	_need(
		not ATTEMPT._same_input(candidate, expected), "non-string key with unchanged size refused"
	)
	candidate = expected.duplicate(true)
	var cycle: Dictionary = candidate.stadium.environment
	cycle.mode = cycle
	_need(
		not ATTEMPT._same_input(candidate, expected),
		"introduced cyclic value refused through finite expected tree"
	)
	cycle.mode = "cycle released"
	candidate = expected.duplicate(true)
	candidate.stadium.manifest.instances[0].transform[0] = NAN
	_need(not ATTEMPT._same_input(candidate, expected), "nonfinite primitive refused")
	var unfrozen: Dictionary = expected.duplicate(true)
	_need(
		not ATTEMPT._same_input(unfrozen, unfrozen),
		"unfrozen replacement cannot be used as expected tree"
	)
	var entry_budget: Array[int] = [0, StadiumNpcAc02IssuedStateV1.MAX_STRING_BYTES]
	var entry_copy: Variant = StadiumNpcAc02IssuedStateV1._copy_canonical(expected, entry_budget)
	_need(
		entry_copy == null and entry_budget[0] < 0,
		"unchanged copier exhausted entry budget refused"
	)
	var string_budget: Array[int] = [StadiumNpcAc02IssuedStateV1.MAX_ENTRIES, 0]
	var string_copy: Variant = StadiumNpcAc02IssuedStateV1._copy_canonical(expected, string_budget)
	_need(
		string_copy == null and string_budget[1] < 0,
		"unchanged copier exhausted string budget refused"
	)
	var cyclic_input: Dictionary = {"cycle": null}
	cyclic_input.cycle = cyclic_input
	var cycle_budget: Array[int] = [
		StadiumNpcAc02IssuedStateV1.MAX_ENTRIES, StadiumNpcAc02IssuedStateV1.MAX_STRING_BYTES
	]
	var cycle_copy: Variant = StadiumNpcAc02IssuedStateV1._copy_canonical(
		cyclic_input, cycle_budget
	)
	_need(
		cycle_copy == null and cycle_budget[0] < 0,
		"unchanged copier cyclic depth exhausted and refused"
	)
	cyclic_input.clear()
	var opaque_budget: Array[int] = [
		StadiumNpcAc02IssuedStateV1.MAX_ENTRIES, StadiumNpcAc02IssuedStateV1.MAX_STRING_BYTES
	]
	var opaque_copy: Variant = StadiumNpcAc02IssuedStateV1._copy_canonical(
		{"opaque": RefCounted.new()}, opaque_budget
	)
	_need(
		opaque_copy == null and opaque_budget[0] < 0,
		"unchanged copier opaque input admission component refused"
	)
	_evidence["type_and_budget_controls"] = \
		("Pure comparer/copier components, not public historical fallback or " + "revived contexts.")


func _camera_guard_refusal(attempt: RefCounted, checkpoint_sha: String) -> void:
	var lab: PitchBatLab = attempt.lab
	var property: StadiumNpcPublicProperty = attempt.property
	var unused_club: String = _other_key(
		attempt._witness.npc_venues.assignments, str(attempt._witness.pending.home)
	)
	if not _need(
		not unused_club.is_empty(), "real callback mutation has nonselected assignment target"
	):
		attempt.dispose()
		return
	var raw_before: Dictionary = attempt.match_state.stadium.duplicate(true)
	var row_before: Dictionary = attempt.season.pending_fixture().duplicate(true)
	var counts_before: Dictionary = _semantic_calls(PERF.snapshot())
	attempt.season.npc_venues.assignments[unused_club]["witness_negative"] = true
	_need(
		(
			ATTEMPT._same_input(attempt.match_state.stadium, attempt._witness.stadium)
			and ATTEMPT._same_input(attempt.season.pending_fixture(), attempt._witness.pending)
		),
		"live nonselected mutation leaves raw stadium and pending row unchanged"
	)
	# A genuine ordinary guard caller. Deliberately discard its false return;
	# context itself must abort in this same synchronous callback chain.
	lab._camera_director._snap_startup(attempt, lab._camera)
	_need(
		(
			attempt.state == ATTEMPT.State.ABORTED
			and attempt.reason == "startup context changed"
			and not lab._ac02_startup_committed
			and not property._ac02_startup_committed
			and property.suspended
			and not property.issued
			and (
				attempt.issue == null
				or attempt.issue.state != StadiumNpcAc02IssuedStateV1.Lifetime.ACTIVE
			)
		),
		"ignored-false genuine camera guard immediately retires changed pending input"
	)
	_need(
		_semantic_calls(PERF.snapshot()) == counts_before,
		"mismatch guard performs no normalized or matches_fixture calls"
	)
	_need(
		(
			not attempt.context()
			and not attempt.validate_and_publish()
			and attempt.state == ATTEMPT.State.ABORTED
			and attempt.reason == "startup context changed"
		),
		"installed refusal remains sticky without restoring or retrying production context"
	)
	_need(
		(
			not StadiumNpcPublicRuntime.installed(lab)
			and not PitchBatLabFeelSupport._public_export_intact(lab)
			and not StadiumNpcAc02IssuedStateV1.before_settlement(lab)
			and lab._active_play_record == null
			and lab._play_records.is_empty()
			and not _app._result_recorded
			and not _app._result_saved
		),
		"real refused attempt has no public/export/settlement or record publication"
	)
	_evidence["actual_callback_refusal"] = {
		"reason": attempt.reason,
		"state": int(attempt.state),
		"caller": "StadiumNpcAc02PublicCamera._snap_startup",
		"false_return_discarded": true,
		"unused_club": unused_club,
		"source_restored": false,
		"committed": lab._ac02_startup_committed,
		"issue_state": int(attempt.issue.state) if attempt.issue != null else -1,
		"raw_stadium_unchanged": ClubCareer.same(raw_before, attempt.match_state.stadium),
		"pending_row_unchanged": ClubCareer.same(row_before, attempt.season.pending_fixture())
	}
	attempt.dispose()
	_need(
		(
			_app.lab == null
			and lab.is_queued_for_deletion()
			and FileAccess.get_sha256(SeasonSave.path) == checkpoint_sha
		),
		"refused actual coordinator disposal preserves pregame checkpoint"
	)
	_evidence["checkpoint_sha256"] = checkpoint_sha
	_evidence["input_sha256"] = INPUT_SHA


func _other_key(values: Dictionary, selected: String) -> String:
	for key: String in values:
		if key != selected:
			return key
	return ""


func _semantic_calls(profile: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"stadium_npc_snapshot.normalized": 0, "stadium_npc_snapshot.matches_fixture": 0
	}
	for row: Dictionary in profile.rows:
		if result.has(row.label):
			result[row.label] += int(row.calls)
	return result


func _need(ok: bool, label: String) -> bool:
	print("STARTUP_INPUT_WITNESS ", "PASS " if ok else "FAIL ", label)
	if not ok:
		_failures.append(label)
	return ok
