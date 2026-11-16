extends Node
## One retained AC02 cold/public start and bounded genuine play. No full game,
## report fabrication, contact injection, time/phase edits, screenshots or source bypass.
const PERF = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const SETUP_RETURNS = preload("res://src/diagnostics/ac02_setup_return_diagnostics.gd")
const INPUT_SHA256: String = "91a8456218b62c6fffa171c97090fed1b2296da4161accbbef93bdab724f7524"
const PROFILE_PATH: String = "res://src/presentation/stadium/stadium_npc_current_source_profile.gd"
const ISSUED_PROFILE_PATH: String = \
	"res://src/presentation/stadium/stadium_npc_ac02_issued_runtime_profile_v1.gd"
const ISSUED_SCRIPT = preload("res://src/presentation/stadium/stadium_npc_ac02_issued_state_v1.gd")
const MAX_MOTION_FRAMES: int = 1800
const MAX_RELEASES: int = 16
const PRESENTATION_FRAMES: int = 30
const INTERNAL_WALL_USEC: int = 370000000

var _output: String = ""
var _input: String = ""
var _candidate: String = ""
var _profile_sha: String = ""
var _issued_profile_sha: String = ""
var _observed_issuer: WeakRef
var _observed_issuer_id: int = 0
var _observed_generation: int = 0
var _issued_active_throughout: bool = false
var _clock_valid_throughout: bool = true
var _live_checks: int = 0
var _run_mode: String = ""
var _started: int = 0
var _app: SeasonApp
var _failures: Array[String] = []
var _checks: int = 0
var _human_starts: int = 0
var _automation_ready: bool = true
var _motion_frames: int = 0
var _presentation_frames: int = 0
var _release_seen: bool = false
var _contact_seen: bool = false
var _defense_seen: bool = false
var _observed_defended_play_number: int = 0
var _resolved_contact: Dictionary = {}
var _initial: Dictionary = {}
var _evidence: Dictionary = {}


func _ready() -> void:
	_started = Time.get_ticks_usec()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--ac02-output="):
			_output = arg.trim_prefix("--ac02-output=")
		elif arg.begins_with("--ac02-input="):
			_input = arg.trim_prefix("--ac02-input=")
		elif arg.begins_with("--ac02-candidate="):
			_candidate = arg.trim_prefix("--ac02-candidate=")
		elif arg.begins_with("--ac02-profile-sha256="):
			_profile_sha = arg.trim_prefix("--ac02-profile-sha256=")
		elif arg.begins_with("--ac02-issued-profile-sha256="):
			_issued_profile_sha = arg.trim_prefix("--ac02-issued-profile-sha256=")
		elif arg.begins_with("--ac02-perf-mode="):
			_run_mode = arg.trim_prefix("--ac02-perf-mode=")
	if (
		_check(
			(
				args.size() == 7
				and args.has("--physical-in-process")
				and _run_mode in ["startup_only", "short_play"]
				and _candidate.length() == 64
				and _profile_sha.length() == 64
				and _issued_profile_sha.length() == 64
				and FileAccess.get_sha256(PROFILE_PATH) == _profile_sha
				and FileAccess.get_sha256(ISSUED_PROFILE_PATH) == _issued_profile_sha
			),
			"exact run/profile arguments"
		)
		and _check(
			(
				_output.is_absolute_path()
				and DirAccess.make_dir_recursive_absolute(_output) == OK
				and DirAccess.get_files_at(_output).is_empty()
				and DirAccess.get_directories_at(_output).is_empty()
			),
			"fresh isolated evidence directory"
		)
	):
		if _check(PERF.begin_session(_output), "single passive collector session"):
			await _run()
			PERF.checkpoint("cleanup_begin", {"failures": _failures}, "cleanup")
			if is_instance_valid(_app):
				if is_instance_valid(_app.round_ui):
					_app.round_ui.cancel()
				if (
					_app.is_inside_tree()
					and is_instance_valid(_app.loadout)
					and is_instance_valid(_app._continue)
					and is_instance_valid(_app.menu)
				):
					_app._close_match()
				_app.queue_free()
			await TestAudioDrain.finish(get_tree())
			# Discard harness-only weak reference; never call an issuer lifecycle method.
			_observed_issuer = null
			PERF.checkpoint("cleanup_complete", {"failures": _failures})
			var profile: Dictionary = PERF.finish_session()
			_check(
				(
					profile.errors.is_empty()
					and profile.open_scopes == 0
					and profile.entries == profile.completed
				),
				"balanced passive collector"
			)
			_evidence["profile"] = profile
			_evidence["checks"] = _checks
			_evidence["failures"] = _failures
			_evidence["passed"] = _failures.is_empty()
			_evidence["wall_usec"] = Time.get_ticks_usec() - _started
			_write("summary.json", _evidence)
	print("AC02_PASSIVE_ATTRIBUTION checks=", _checks, " failures=", _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	if not _check(
		(
			Engine.physics_ticks_per_second == 60
			and Engine.time_scale == 1.0
			and not get_tree().paused
		),
		"ordinary unpaused fixed60 physics, unchanged timescale"
	):
		return
	if not _check(
		_input.is_absolute_path() and FileAccess.get_sha256(_input) == INPUT_SHA256,
		"exact retained actual-round01 initial save bytes"
	):
		return
	var source: String = FileAccess.get_file_as_string(_input)
	var value: Variant = JSON.parse_string(source)
	if not _check(value is Dictionary and value.get("version") == 61, "retained save61 JSON"):
		return
	_initial = value
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	var file: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	if not _check(file != null, "isolated byte-preserving retained primary copy"):
		return
	file.store_string(source)
	file.flush()
	file.close()
	if not _check(
		FileAccess.get_sha256(SeasonSave.path) == INPUT_SHA256,
		"retained initial save copied without regeneration"
	):
		return
	# Leave the test root installation callback before adding another root child.
	# This scheduling yield is deliberately outside the cold-restore stage.
	await get_tree().process_frame
	PERF.checkpoint("retained_save_ready", {"input_sha256": INPUT_SHA256}, "cold_app_restore")
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	PERF.checkpoint("cold_app_restore_returned", {}, "cold_restore_verification")
	if not _check(
		(
			_app.season != null
			and _app.season.season_seed == 6
			and ClubCareer.same(_initial, SeasonSave.snapshot(_app.season))
			and _app.season.results.is_empty()
			and _app.season.player_results.is_empty()
			and _app.season.physical.pending.is_empty()
			and _app.season.physical.reports.is_empty()
			and ClubCareer.same(
				_app.season.pending_fixture(), {"id": 0, "round": 0, "away": 0, "home": 5}
			)
		),
		"ordinary restore recovers exact scheduled initial AC02 season"
	):
		return
	_app.child_entered_tree.connect(_configure_automation)
	PERF.checkpoint("public_play_begin", {}, "public_play")
	_app.play_season_game()
	PERF.checkpoint(
		"public_play_returned",
		{"lab_exists": is_instance_valid(_app.lab)},
		"public_entry_verification"
	)
	await _passive_human_lab()


func _passive_human_lab() -> void:
	if not _check(
		is_instance_valid(_app.lab) and _automation_ready and _human_starts == 1,
		"ordinary public Play creates one configured managed lab"
	):
		return
	var lab: PitchBatLab = _app.lab
	var state: MatchState = lab._match_state
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if not _check(
		(
			state != null
			and property != null
			and property.venue_id == "AC-02"
			and property.issued
			and not property.suspended
			and lab._managed_match
			and not lab._player_home
			and lab._npc_season == _app.season
			and property.bound_state == state
			and property.public_snapshot == state.stadium
			and state.stadium.get("version") == 19
			and state.stadium.manifest.id == "AC-02"
			and state.stadium.environment.mode == "day"
			and lab._automation.presentation_enabled
		),
		"public path admitted exact managed away AC02 Day with real presentation"
	):
		return
	_evidence = {
		"schema": "AC02-PASSIVE-BOUNDED-RUN-v1",
		"candidate_sha256": _candidate,
		"profile_sha256": _profile_sha,
		"input_sha256": INPUT_SHA256,
		"fixture": _app.season.pending_fixture().duplicate(true),
		"stadium": state.stadium.duplicate(true),
		"initial_automation": lab._automation.initial.duplicate(true),
		"automation_seed": lab._automation.seed,
		"presentation_enabled": true,
		"manual_input_qualified": false,
		"performance_qualified": false,
		"night_opened": false,
		"full_game": false,
		"settlement_run": false,
		"report_generated": false,
		"defense_scope":
		"ordinary automatic fielder after a genuine live contact; not manual defense certification"
	}
	# Post-entry read-only observation only. This never issues, qualifies or guards.
	_evidence["issued_runtime_profile_sha256"] = _issued_profile_sha
	_evidence["issued_runtime_profile_observed_sha256"] = FileAccess.get_sha256(ISSUED_PROFILE_PATH)
	_evidence["issued_runtime_profile_binding_ok"] = (
		_evidence.issued_runtime_profile_observed_sha256 == _issued_profile_sha
	)
	_evidence["issued_v1_initial"] = _observe_issued(lab, property, true)
	_issued_active_throughout = _evidence.issued_v1_initial.active
	_evidence["initial_clock"] = _clock_observation(lab)
	_evidence["run_mode"] = _run_mode
	_evidence["startup_passed"] = true
	_evidence["terminal_reason"] = "public_entry_verified_before_motion_wait"
	_evidence["motion_run"] = false
	_evidence["motion_gate_passed"] = null
	_evidence["motion_physics_frames"] = 0
	_evidence["presentation_process_frames"] = 0
	_evidence["startup_wall_usec"] = Time.get_ticks_usec() - _started
	_evidence["initial_state"] = {
		"phase": state.phase,
		"elapsed_seconds": state.elapsed_seconds,
		"issued": property.issued,
		"suspended": property.suspended,
		"release_count": lab._automation.releases.size(),
		"play_record_count": lab._play_records.size()
	}
	_evidence["setup_diagnostics"] = SETUP_RETURNS.snapshot()
	_record_motion(lab, state, property)
	_evidence["fixed_wrapper_target_count"] = 76
	_evidence["setup_passthrough_hook_count"] = 2
	_evidence["hook_overhead_scope"] = \
		("copy/append/counter body; excludes dispatch/return and snapshot/file " + "IO; not subtracted")
	_write("setup_diagnostics.json", _evidence.setup_diagnostics)
	PERF.checkpoint(
		"public_startup_complete",
		{
			"run_mode": _run_mode,
			"startup_passed": true,
			"setup_diagnostics": _evidence.setup_diagnostics,
			"issued_v1_initial": _evidence.issued_v1_initial,
			"issued_v1_terminal": _evidence.issued_v1_terminal,
			"issued_v1_active_throughout": _evidence.issued_v1_active_throughout,
			"initial_clock": _evidence.initial_clock,
			"terminal_clock": _evidence.terminal_clock
		},
		"startup_terminal"
	)
	_evidence["passed"] = _failures.is_empty()
	_evidence["failures"] = _failures.duplicate()
	_write("startup_result.json", _evidence)
	if _run_mode == "startup_only":
		return
	# Preserve a completed startup diagnostic when the issuance route is inactive.
	# The launcher rejects combined eligibility separately; never force activation.
	if not _issued_active_throughout:
		_evidence["terminal_reason"] = "issued_v1_inactive_before_motion"
		return
	_evidence["motion_run"] = true
	_evidence["motion_gate_passed"] = false
	_evidence["terminal_reason"] = "short_play_incomplete"
	PERF.checkpoint("genuine_motion_begin", {}, "genuine_motion")
	await _passive_motion_samples(lab, state, property)


func _passive_motion_samples(
	lab: PitchBatLab, state: MatchState, property: StadiumNpcPublicProperty
) -> void:
	for frame: int in range(MAX_MOTION_FRAMES):
		await get_tree().physics_frame
		_motion_frames = frame + 1
		if not _live(lab, state, property):
			return
		if not _release_seen and not lab._automation.releases.is_empty():
			_release_seen = true
			PERF.checkpoint("first_legal_release", {"release": lab._automation.releases[0]})
		if (
			state.phase == MatchState.Phase.BALL_IN_PLAY
			and is_instance_valid(lab._batted_ball)
			and lab._ball_play_resolver != null
			and lab._ball_play_resolver.state != null
			and not lab._ball_play_resolver.state.dead
		):
			if not _contact_seen:
				_contact_seen = true
				PERF.checkpoint(
					"first_live_contact", {"plate_appearance": state.plate_appearance_number}
				)
			if is_instance_valid(lab._primary_fielder) and lab._primary_fielder.active:
				_defense_seen = true
				if lab._active_play_record != null:
					_observed_defended_play_number = lab._active_play_record.play_number
		for play: PlayRecord in lab._play_records:
			if (
				_observed_defended_play_number > 0
				and play.play_number == _observed_defended_play_number
				and play.mode == "match"
				and (
					play.contact_outcome
					in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]
				)
				and is_finite(play.exit_speed_mps)
				and play.exit_speed_mps > 0.0
				and play.last_defender_touch == &"primary_fielder"
				and (
					(
						play.resolution_reason in [&"fly_catch", &"ground_control"]
						and play.result == &"out"
					)
					or (
						play.resolution_reason == &"controlled_after_safe"
						and play.result in [&"single", &"double", &"triple", &"home_run"]
					)
				)
			):
				_resolved_contact = play.to_dict()
				break
		# The release ceiling applies even when this frame resolves a genuine play.
		if lab._automation.releases.size() > MAX_RELEASES:
			_flush_motion(lab, state, property)
			_check(false, "short motion release ceiling exceeded")
			return
		if _release_seen and _contact_seen and _defense_seen and not _resolved_contact.is_empty():
			break
		if lab._automation.releases.size() >= MAX_RELEASES:
			_flush_motion(lab, state, property)
			_check(false, "short motion bound reached before resolved contact/defense")
			return
	_flush_motion(lab, state, property)
	if not _check(
		_release_seen and _contact_seen and _defense_seen and not _resolved_contact.is_empty(),
		"genuine legal pitch, live contact, active ordinary fielder and physical resolution"
	):
		return
	PERF.checkpoint(
		"genuine_resolution",
		{
			"record": _resolved_contact,
			"observed_defended_play_number": _observed_defended_play_number,
			"motion_physics_frames": _motion_frames,
			"presentation_process_frames": _presentation_frames,
			"release_seen": _release_seen,
			"contact_seen": _contact_seen,
			"defense_seen": _defense_seen,
			"release_count": _evidence.release_count,
			"play_record_count": _evidence.play_record_count,
			"releases": _evidence.releases,
			"play_records": _evidence.play_records,
			"motion_bounds": _evidence.motion_bounds,
			"terminal_clock": _evidence.terminal_clock,
			"issued_v1_terminal": _evidence.issued_v1_terminal,
			"issued_v1_active_throughout": _evidence.issued_v1_active_throughout
		},
		"presentation_window"
	)
	for frame: int in range(PRESENTATION_FRAMES):
		await get_tree().process_frame
		_presentation_frames = frame + 1
		if not _live(lab, state, property):
			return
	_record_motion(lab, state, property)
	PERF.checkpoint(
		"presentation_window_complete",
		{
			"process_frames": _presentation_frames,
			"release_count": _evidence.release_count,
			"terminal_clock": _evidence.terminal_clock,
			"issued_v1_terminal": _evidence.issued_v1_terminal,
			"issued_v1_active_throughout": _evidence.issued_v1_active_throughout
		},
		"final_observation"
	)
	_evidence["primary_save_sha256"] = FileAccess.get_sha256(SeasonSave.path)
	_check(
		(
			state.phase != MatchState.Phase.GAME_END
			and _app.season.results.is_empty()
			and _app.season.physical.pending.is_empty()
			and _app.season.physical.reports.is_empty()
		),
		"bounded slice stopped before game end, report, AI jobs or settlement"
	)
	_evidence["motion_gate_passed"] = _failures.is_empty()
	_evidence["terminal_reason"] = "bounded_short_play_complete"
	PERF.checkpoint("bounded_slice_complete", {"failures": _failures})


func _live(lab: PitchBatLab, state: MatchState, property: StadiumNpcPublicProperty) -> bool:
	var issued: Dictionary = _observe_issued(lab, property)
	var clock: Dictionary = _clock_observation(lab)
	_issued_active_throughout = (
		_issued_active_throughout
		and issued.active
		and issued.same_initial_issuer
		and issued.same_initial_generation
	)
	_clock_valid_throughout = (
		_clock_valid_throughout
		and clock.physics_ticks_per_second == 60
		and clock.time_scale == 1.0
		and not clock.paused
		and clock.presentation_enabled
	)
	_live_checks += 1
	_evidence["issued_v1_terminal"] = issued
	_evidence["issued_v1_active_throughout"] = _issued_active_throughout
	_evidence["terminal_clock"] = clock
	_evidence["clock_valid_throughout"] = _clock_valid_throughout
	_evidence["live_checks"] = _live_checks
	var live: bool = (
		is_instance_valid(lab)
		and _app.lab == lab
		and lab._match_state == state
		and is_instance_valid(property)
		and property.issued
		and not property.suspended
		and not lab.has_meta("stadium_npc_runtime_interrupted")
		and state.phase != MatchState.Phase.GAME_END
		and not get_tree().paused
		and _issued_active_throughout
		and _clock_valid_throughout
		and lab._automation != null
		and lab._automation.releases.size() <= MAX_RELEASES
		and Time.get_ticks_usec() - _started < INTERNAL_WALL_USEC
	)
	if not live:
		_flush_motion(lab, state, property)
	return _check(
		live,
		"unchanged active issued owners, fixed60 presentation and bounded pre-game-end live window"
	)


func _observe_issued(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, retain_initial: bool = false
) -> Dictionary:
	var observed: Dictionary = {
		"schema": "AC02-ISSUED-ACTIVE-OBSERVATION-v1",
		"family": ISSUED_SCRIPT.FAMILY,
		"version": ISSUED_SCRIPT.VERSION,
		"expected_script": "res://src/presentation/stadium/stadium_npc_ac02_issued_state_v1.gd",
		"present": false,
		"exact_script": false,
		"pin_matches": false,
		"issued_once": false,
		"property_generation": 0,
		"generation": 0,
		"generation_matches": false,
		"lab_owner_matches": false,
		"state": -1,
		"active": false,
		"reason": "public_property_unavailable",
		"issuer_reason": "",
		"instance_id": 0,
		"same_initial_issuer": false,
		"same_initial_generation": false
	}
	if not is_instance_valid(property):
		return observed
	var issuer: StadiumNpcAc02IssuedStateV1 = property._ac02_issue
	observed["issued_once"] = property._ac02_issued_once
	observed["property_generation"] = property._ac02_generation
	observed["present"] = is_instance_valid(issuer)
	if not observed.present:
		observed["reason"] = "issuer_absent"
		return observed
	# Object identity is established before reading ANY field from the issuer.
	if issuer.get_script() != ISSUED_SCRIPT:
		observed["reason"] = "issuer_script_not_exact"
		return observed
	observed["exact_script"] = true
	observed["pin_matches"] = issuer == property._ac02_issue_pin
	observed["generation"] = issuer.generation
	observed["generation_matches"] = (
		issuer.generation > 0 and issuer.generation == property._ac02_generation
	)
	observed["lab_owner_matches"] = is_instance_valid(lab) and lab._ac02_issued_owner == issuer
	observed["state"] = issuer.state
	observed["issuer_reason"] = issuer.reason
	observed["instance_id"] = issuer.get_instance_id()
	if retain_initial:
		_observed_issuer = weakref(issuer)
		_observed_issuer_id = issuer.get_instance_id()
		_observed_generation = issuer.generation
	observed["same_initial_issuer"] = (
		_observed_issuer != null
		and issuer == _observed_issuer.get_ref()
		and issuer.get_instance_id() == _observed_issuer_id
	)
	observed["same_initial_generation"] = (
		issuer.generation == _observed_generation and _observed_generation > 0
	)
	observed["active"] = (
		observed.pin_matches
		and observed.issued_once
		and observed.generation_matches
		and observed.lab_owner_matches
		and issuer.state == ISSUED_SCRIPT.Lifetime.ACTIVE
	)
	if not observed.pin_matches:
		observed["reason"] = "issuer_pin_mismatch"
	elif not observed.issued_once:
		observed["reason"] = "property_not_issued_once"
	elif not observed.generation_matches:
		observed["reason"] = "issuer_generation_mismatch"
	elif not observed.lab_owner_matches:
		observed["reason"] = "lab_issuer_owner_mismatch"
	elif issuer.state != ISSUED_SCRIPT.Lifetime.ACTIVE:
		observed["reason"] = "issuer_not_active"
	elif not observed.same_initial_issuer:
		observed["reason"] = "initial_issuer_identity_changed"
	elif not observed.same_initial_generation:
		observed["reason"] = "initial_issuer_generation_changed"
	else:
		observed["reason"] = "active"
	return observed


func _clock_observation(lab: PitchBatLab) -> Dictionary:
	return {
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"time_scale": Engine.time_scale,
		"paused": get_tree().paused,
		"presentation_enabled":
		is_instance_valid(lab) and lab._automation != null and lab._automation.presentation_enabled
	}


func _record_motion(
	lab: PitchBatLab, state: MatchState, property: StadiumNpcPublicProperty
) -> void:
	var lab_available: bool = is_instance_valid(lab)
	var automation_available: bool = lab_available and lab._automation != null
	var records: Array[Dictionary] = []
	if lab_available:
		for play: PlayRecord in lab._play_records:
			records.append(play.to_dict())
	_evidence["raw_motion_available"] = lab_available and automation_available and state != null
	_evidence["releases"] = lab._automation.releases.duplicate(true) if automation_available else []
	_evidence["play_records"] = records
	_evidence["resolved_contact"] = _resolved_contact
	_evidence["motion_physics_frames"] = _motion_frames
	_evidence["presentation_process_frames"] = _presentation_frames
	_evidence["simulation_seconds"] = state.elapsed_seconds if state != null else 0.0
	_evidence["phase"] = state.phase if state != null else -1
	_evidence["release_seen"] = _release_seen
	_evidence["contact_seen"] = _contact_seen
	_evidence["defense_seen"] = _defense_seen
	_evidence["observed_defended_play_number"] = _observed_defended_play_number
	_evidence["release_count"] = lab._automation.releases.size() if automation_available else -1
	_evidence["play_record_count"] = records.size() if lab_available else -1
	_evidence["motion_bounds"] = {
		"max_physics_frames": MAX_MOTION_FRAMES,
		"max_releases": MAX_RELEASES,
		"presentation_process_frames": PRESENTATION_FRAMES,
		"internal_wall_usec": INTERNAL_WALL_USEC
	}
	_evidence["issued_v1_terminal"] = _observe_issued(lab, property)
	_evidence["issued_v1_active_throughout"] = _issued_active_throughout
	_evidence["terminal_clock"] = _clock_observation(lab)
	_evidence["clock_valid_throughout"] = _clock_valid_throughout
	_evidence["live_checks"] = _live_checks


func _flush_motion(lab: PitchBatLab, state: MatchState, property: StadiumNpcPublicProperty) -> void:
	_record_motion(lab, state, property)
	_write("motion_partial.json", _evidence)


func _configure_automation(node: Node) -> void:
	if not node is PitchBatLab:
		return
	var lab: PitchBatLab = node
	_automation_ready = (
		_automation_ready
		and not lab.is_node_ready()
		and lab._match_state == null
		and lab._automation == null
	)
	lab._automation = MatchAutomation.new()
	lab._automation.seed = SeasonPhysicalFixtures.seed_for(
		_app.season, _app.season.pending_fixture()
	)
	lab._automation.presentation_enabled = true
	_human_starts += 1


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures.append(label)
		print("AC02_ATTRIBUTION_FAIL ", label)
	return ok


func _write(name: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if file == null:
		_check(false, "summary write failed")
		return
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.flush()
	file.close()
