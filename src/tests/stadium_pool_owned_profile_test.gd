extends Node
## One diagnostic-only, predeclared owned fixture segment. Never completes a season game.
## Required accepted-fixture helpers are copied exactly; no complete test-scene inheritance.
# gdlint: disable=max-returns,max-file-lines

signal profile_window_finished

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024

const PROFILE_FRAMES: int = 1800
const PROFILE_SECONDS: float = 30.0
const PROFILE_EXPECTED_CHECKS: int = 59 # 58 path checks plus this exact-total guard.
const PROFILE_FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const PROFILE_SEED: int = 314229
const PROFILE_SUMMARY_CAP: int = 32768
const PROFILE_COUNTER_CAP: int = 131072

var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _output: String = ""
var _runtime: String = ""
var _expected_runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _app: ObservedApp
var _runner: PhysicalMatchRunner
var _funding: Dictionary = {}
var _placements: Array[Dictionary] = []
var _wall_start: int = 0
var _output_admitted: bool = false

var _profile_frames: int = 0
var _profile_seconds: float = 0.0
var _profile_frame_start: int = 0
var _profile_wall_start: int = 0
var _profile_wall_usec: int = 0
var _profile_active: bool = false
var _profile_clock_ok: bool = true
var _profile_reason: String = "not_started"
var _profile_report: Dictionary = {}
var _profile_errors: Array[String] = []
var _profile_ordinary_reports: int = 0
var _profile_private_reports: int = 0
var _profile_starts: int = 0
var _profile_progress: Array[Dictionary] = []
var _profile_checkpoint_attempts: int = 0
var _profile_checkpoint_count: int = 0
var _profile_checkpoint_ok: bool = true
var _profile_checkpoint_possible_overlap: bool = false
var _profile_checkpoint_capture_usec: int = 0
var _profile_checkpoint_io_usec: int = 0
var _profile_source: MatchState
var _profile_state: MatchState
var _profile_automation: MatchAutomation
var _profile_records: Array[PlayRecord] = []
var _profile_ledger: ClubAssetLedger
var _profile_season_bytes: PackedByteArray
var _profile_ledger_bytes: PackedByteArray
var _profile_source_bytes: PackedByteArray
var _profile_saved_files: Dictionary = {}
var _profile_request_key: String = ""
var _profile_lab_ref: WeakRef
var _profile_adapter: StadiumPoolControllerActive
var _profile_final: Dictionary = {}
var _profile_preserved: bool = false
var _profile_disposed: bool = false


class ObservedApp extends SeasonApp:
	var terminal_observer: Callable
	var pending_observer: Callable
	var last_observed_lab: int = 0

	func _commit_result() -> bool:
		var first: bool = not _result_recorded and lab != null \
			and lab._match_state.phase == MatchState.Phase.GAME_END
		if first and last_observed_lab != lab.get_instance_id():
			last_observed_lab = lab.get_instance_id()
			terminal_observer.call(self)
		var result: bool = super._commit_result()
		if first and _result_recorded and not season.physical.pending.is_empty():
			pending_observer.call(self)
		return result

func _purchase_and_place() -> bool:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var before: Dictionary = ledger.to_data()
	var balance: int = _app.season.career.balance()
	var revision: int = ledger.revision()
	var bought: Dictionary = ClubConstruction.buy_copy(_app.season, "ST-006", revision)
	if not _check(bought.get("ok", false) and not bought.get("replayed", true),
		"ordinary buy_copy pays unlocked full first-Pool price: " + str(bought.get("error", ""))):
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	if not _check(_app.season.career.balance() == balance - 700
		and ledger.revision() == revision + 1 and not ClubCareer.same(before, ledger.to_data()),
		"shared wallet decreases exactly700 and journal advances once"):
		return false
	var paid: Dictionary = ledger.to_data()
	var duplicate: Dictionary = ClubConstruction.buy_copy(_app.season, "ST-006", revision)
	if not _check(duplicate.get("ok", false) and duplicate.get("replayed", false)
		and ClubCareer.same(paid, ClubPlayers.assets(_app.season.career).to_data()),
		"same purchase command replays without another charge or copy"):
		return false
	var pool_copy: String = ""
	for id: String in ledger.construction().copies:
		if ledger.construction().copies[id].item == "ST-006":
			if not _check(pool_copy.is_empty(), "one paid Pool copy"):
				return false
			pool_copy = id
	if not _check(not pool_copy.is_empty(), "paid copy comes from actual journal stock"):
		return false
	if not _place_owned_receiver():
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	var base: Dictionary = ledger.view().stadium_active.duplicate(true)
	var layout: Dictionary = StadiumPoolOwnedLayout.upgrade(base, ledger.construction(),
		ledger.surface_owned(), ledger.view().land, pool_copy, Vector2(12, 18), 0)
	if layout.is_empty():
		_write("pool-owned-v28-failure-context.json", {"stage": "pool_upgrade",
			"base": base, "stock": ledger.construction().to_data(),
			"access": ledger.surface_owned(), "tier": ledger.view().land,
			"copy": pool_copy, "position": [12, 18], "yaw": 0,
			"migration_error": StadiumPoolOwnedLayout.migration_error(base,
				ledger.construction(), ledger.surface_owned(), ledger.view().land)})
	if not _check(not layout.is_empty(), "surface-preserving receiver layout upgrade"):
		return false
	var moved: Dictionary = StadiumPoolOwnedLayout.relocated(layout, ledger.construction(),
		ledger.surface_owned(), ledger.view().land, Vector2(-12, 18), 270)
	if not _check(not moved.is_empty() and moved.pool.copy == pool_copy
		and moved.surface == layout.surface, "second distinct legal pose preserves paid copy and finish"):
		return false
	for selected: Dictionary in [moved, layout]:
		ledger = ClubPlayers.assets(_app.season.career)
		var drafted: Dictionary = ClubConstruction.save_draft(_app.season, selected, ledger.revision())
		if not _check(drafted.get("ok", false),
			"ordinary validated draft transaction: " + str(drafted.get("error", ""))):
			return false
		ledger = ClubPlayers.assets(_app.season.career)
		var applied: Dictionary = ClubConstruction.apply_draft(_app.season, selected, ledger.revision())
		if not _check(applied.get("ok", false)
			and StadiumPoolOwnedSnapshot.matches(_app.season.home_property,
				ClubPlayers.assets(_app.season.career)),
			"ordinary atomic apply freezes paid Pool snapshot: " + str(applied.get("error", ""))):
			return false
		_placements.append(selected.pool.duplicate(true))
	var preserved: Dictionary = SeasonSave.snapshot(_app.season)
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SeasonSave.path)
	var invalid: Dictionary = layout.duplicate(true)
	invalid.pool.copy = "not-a-paid-copy"
	ledger = ClubPlayers.assets(_app.season.career)
	_check(not ClubConstruction.apply_draft(_app.season, invalid, ledger.revision()).ok,
		"unpaid copy cannot install")
	invalid = layout.duplicate(true)
	invalid.pool.position = [0, 0]
	_check(not ClubConstruction.apply_draft(_app.season, invalid, ledger.revision()).ok,
		"unsafe reserved placement cannot install")
	_check(not ClubConstruction.apply_draft(_app.season, layout, 0).ok,
		"stale unrelated revision cannot apply")
	_check(ClubCareer.same(preserved, SeasonSave.snapshot(_app.season))
		and save_bytes == FileAccess.get_file_as_bytes(SeasonSave.path),
		"rejected ownership, placement and revision transactions preserve live and saved bytes")
	var restored: SeasonState = SeasonSave.restore()
	if not _check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(_app.season)), "purchase and both placements durably replay"):
		return false
	_app.season = restored
	return true

func _owned_receiver_draft(base: Dictionary, copies: Dictionary) -> Dictionary:
	if not base.has("receiver") or not base.receiver is String \
		or not base.has("obstacles") or not base.obstacles is Array \
		or not base.obstacles.is_empty():
		return {}
	var selected: String = base.receiver
	if not selected.is_empty():
		if not copies.has(selected) or copies[selected].item != "ST-079":
			return {}
	else:
		for id: String in copies:
			if copies[id].item == "ST-079":
				if not selected.is_empty():
					return {}
				selected = id
	if selected.is_empty():
		return {}
	var draft: Dictionary = base.duplicate(true)
	draft.receiver = selected
	return draft

func _place_owned_receiver() -> bool:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var before: Dictionary = SeasonSave.snapshot(_app.season)
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(SeasonSave.path)
	var balance: int = _app.season.career.balance()
	var draft: Dictionary = _owned_receiver_draft(ledger.view().stadium_active,
		ledger.construction().copies)
	if not _check(not draft.is_empty()
		and ClubCareer.same(before, SeasonSave.snapshot(_app.season))
		and saved == FileAccess.get_file_as_bytes(SeasonSave.path),
		"select actual owned ST-079 receiver without live or saved mutation"):
		return false
	var drafted: Dictionary = ClubConstruction.save_draft(_app.season, draft, ledger.revision())
	if not _check(drafted.get("ok", false) and _app.season.career.balance() == balance,
		"ordinary receiver draft transaction: " + str(drafted.get("error", ""))):
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	var applied: Dictionary = ClubConstruction.apply_draft(_app.season, draft, ledger.revision())
	ledger = ClubPlayers.assets(_app.season.career)
	if not _check(applied.get("ok", false) and _app.season.career.balance() == balance
		and ClubCareer.same(ledger.view().stadium_active, draft)
		and _app.season.home_property.layout.receiver == draft.receiver
		and StadiumLayoutSnapshot.matches(_app.season.home_property, ledger),
		"ordinary receiver apply freezes owned snapshot: " + str(applied.get("error", ""))):
		return false
	return true

func _fixture(id: int) -> Dictionary:
	var found: Dictionary = {}
	for row: Dictionary in _app.season.schedule:
		if row.id == id:
			if not found.is_empty():
				return {}
			found = row.duplicate(true)
	return found

func _progress_write(name: String, value: Dictionary, cap: int) -> bool:
	# Success is uncounted: progress must not alter the fixed gameplay assertion denominator.
	# One atomic temporary preserves the previous observation on interrupted writes.
	if not _output_admitted:
		return false
	var encoded: String = JSON.stringify(value, "", true, true)
	if encoded.to_utf8_buffer().size() > cap:
		return _check(false, "progress artifact exceeds admitted byte cap")
	var destination: String = _output.path_join(name)
	var temporary: String = destination + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _check(false, "progress artifact cannot open")
	file.store_string(encoded)
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, destination) != OK:
		return _check(false, "progress artifact atomic write failed")
	return true

func _write(name: String, value: Dictionary) -> bool:
	if not _output_admitted:
		return false
	var encoded: String = JSON.stringify(value, "", true, true)
	if not _check(encoded.to_utf8_buffer().size() <= MAX_ARTIFACT_BYTES, "bounded evidence artifact"):
		return false
	var file: FileAccess = FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if not _check(file != null, "evidence file opened"):
		return false
	file.store_string(encoded)
	file.close()
	return true

func _hex(value: String, size: int) -> bool:
	if value.length() != size:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true

func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		_failed.append(label)
		push_error("POOL_OWNED_V28 " + label)
	return condition

func _ready() -> void:
	set_physics_process(false)
	# Only this passive observer moves after ordinary callbacks. Lab and actors keep priority zero.
	process_physics_priority = 1000000
	_wall_start = Time.get_ticks_usec()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-owned-v28-dir="):
			_output = argument.trim_prefix("--pool-owned-v28-dir=")
		if argument.begins_with("--pool-owned-v28-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-owned-v28-runtime=")
		if argument.begins_with("--pool-owned-v28-execution="):
			_execution = argument.trim_prefix("--pool-owned-v28-execution=")
		if argument.begins_with("--pool-owned-v28-nonce="):
			_nonce = argument.trim_prefix("--pool-owned-v28-nonce=")
	await _run_profile()
	if _profile_active:
		_stop_profile("fixture_aborted")
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_check(_checks + 1 == PROFILE_EXPECTED_CHECKS, "exact source-derived profile assertion count")
	var summary: Dictionary = _profile_identity()
	summary.merge(_profile_checkpoint_totals())
	summary.merge({
		"checks": _checks, "expected_checks": PROFILE_EXPECTED_CHECKS,
		"failures": _failures, "failed": _failed,
		"status": "DIAGNOSTIC_WINDOW_CAPTURED" if _failures == 0 else "FAILED",
		"natural_starts": _profile_starts, "physics_frames": _profile_frames,
		"physics_seconds": _profile_seconds, "fixed_1800_physics_frames": PROFILE_FRAMES,
		"terminal_reason": _profile_reason, "ordinary_reports": _profile_ordinary_reports,
		"private_reports": _profile_private_reports, "runner_errors": _profile_errors,
		"profile_bounded_ok": _profile_report.get("bounded_ok", false),
		"profile_entries": _profile_report.get("entries", 0),
		"preserved": _profile_preserved, "disposed": _profile_disposed,
		"progress_samples": _profile_progress.size(), "final": _profile_final,
		"placements": _placements, "fixture": PROFILE_FIXTURE, "match_seed": PROFILE_SEED,
		"funding_label": "deterministically simulated test career, seed42, at most18 seasons",
		"profile_wall_seconds": _profile_wall_usec / 1000000.0,
		"wall_seconds": (Time.get_ticks_usec() - _wall_start) / 1000000.0})
	if not _progress_write("pool-owned-v29-summary.json", summary, PROFILE_SUMMARY_CAP):
		push_error("POOL_OWNED_V29_PROFILE summary could not be retained")
	print("POOL_OWNED_V29_PROFILE checks=%d failures=%d frames=%d status=%s source=%s" % [
		_checks, _failures, _profile_frames, summary.status, _runtime])
	get_tree().quit(0 if _failures == 0 else 1)

func _run_profile() -> void:
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and OS.get_cmdline_user_args().has("--physical-in-process"),
		"explicit external output and no child-engine jobs"):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty(), "fresh empty admitted output directory"):
		return
	_output_admitted = true
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _check(_hex(_runtime, 64) and _runtime == _expected_runtime
		and _hex(_execution, 64) and _hex(_nonce, 32), "actual source and run identity bound"):
		return
	if not _check(_ordinary_clock(), "ordinary unpaused 60Hz Jolt clock"):
		return
	if not await _profile_genuine_setup():
		return
	var fixture: Dictionary = _fixture(3)
	if not _check(fixture == PROFILE_FIXTURE
		and SeasonPhysicalFixtures.seed_for(_app.season, fixture) == PROFILE_SEED
		and _app.season.pending_fixture().id == 0 and _app.season.round_index == 0,
		"actual unique scheduled fixture3: home0 away4 seed314229; chronology unchanged"):
		return
	_profile_source = SeasonPhysicalFixtures.match_for(_app.season, fixture)
	_profile_ledger = ClubPlayers.assets(_app.season.career)
	if not _check(_profile_source != null and _profile_ledger != null
		and _profile_source.stadium.get("version") == StadiumPoolOwnedSnapshot.FIXTURE_VERSION
		and StadiumPoolOwnedSnapshot.FIXTURE_VERSION == 17
		and StadiumPoolOwnedSnapshot.valid(_profile_source.stadium)
		and StadiumPoolOwnedSnapshot.matches(_profile_source.stadium, _profile_ledger)
		and _profile_source.stadium.environment.fixture == fixture.id
		and _profile_source.stadium.environment.seed == PROFILE_SEED
		and SeasonState.field_for_fixture(fixture).id == PitchBatLab.FIELD_ID,
		"actual paid fixture17 and held ledger validated before the sole runner start"):
		return
	_profile_saved_files = _profile_saved()
	_profile_season_bytes = var_to_bytes(SeasonSave.snapshot(_app.season))
	_profile_ledger_bytes = var_to_bytes(_profile_ledger.to_data())
	_profile_source_bytes = var_to_bytes(_profile_object_data(_profile_source))
	_profile_request_key = SeasonPhysicalFixtures.request_key(_app.season, fixture)
	if not _check(_profile_unchanged(), "genuine checkpoint and caller frozen before detached start"):
		return
	_runner = PhysicalMatchRunner.new()
	add_child(_runner)
	_runner.finished.connect(func(_report: Dictionary) -> void:
		_profile_ordinary_reports += 1
		if _profile_active:
			_stop_profile("natural_game_end"))
	_runner.private_finished.connect(func(_report: Dictionary) -> void:
		_profile_private_reports += 1
		if _profile_active:
			_stop_profile("unexpected_private_completion"))
	_runner.failed.connect(func(reason: String) -> void:
		_profile_errors.append(reason)
		if _profile_active:
			_stop_profile("runner_error"))
	var before_frame: int = Engine.get_physics_frames()
	if not _check(_runner.start(_profile_source, PROFILE_SEED, PitchBatLab.FIELD_ID,
		_profile_ledger), "sole ordinary genuine paid owned runner startup"):
		return
	_profile_starts += 1
	var lab: PitchBatLab = _runner._lab
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _check(lab != null and lab._match_state != null and lab._automation != null
		and lab._automation.seed == PROFILE_SEED and lab._automation.releases.is_empty()
		and lab._play_records.is_empty() and Engine.get_physics_frames() == before_frame
		and property != null and property.valid_owner(lab) and lab._stadium_ledger == _profile_ledger
		and lab.pool_controller_active != null and lab.pool_controller_active.enabled
		and not lab._debug_paused and lab.process_physics_priority == 0
		and lab._primary_fielder.process_physics_priority == 0,
		"real owned property, unchanged ordinary automation and zero releases before first tick"):
		return
	_profile_state = lab._match_state
	_profile_automation = lab._automation
	_profile_records = lab._play_records
	_profile_adapter = lab.pool_controller_active
	_profile_lab_ref = weakref(lab)
	_profile_frame_start = Engine.get_physics_frames()
	_profile_progress_capture()
	if not _check(StadiumPoolHotpathProfile.start_session(_profile_state),
		"bounded counters activate only after successful genuine startup"):
		return
	_profile_active = true
	_profile_wall_start = Time.get_ticks_usec()
	set_physics_process(true)
	await profile_window_finished
	# A runner may have already disposed its lab on a natural end or error.
	if not _profile_window_available():
		return
	# The terminal observer ends counters synchronously before any explicit cancellation.
	_profile_final = _profile_state_row()
	var releases: Array[Dictionary] = _profile_automation.releases.duplicate(true)
	var plays: Array[Dictionary] = []
	for play: PlayRecord in _profile_records:
		plays.append(play.to_dict())
	_check(_profile_frames == PROFILE_FRAMES and _profile_reason == "fixed_1800_physics_frames"
		and absf(_profile_seconds - PROFILE_SECONDS) < 0.000001 and _profile_clock_ok,
		"exactly1800 ordinary callback ticks,30 seconds of callback delta")
	_check(_profile_starts == 1 and _profile_ordinary_reports == 0 and _profile_private_reports == 0
		and _profile_errors.is_empty() and _runner._running
		and _profile_state.phase != MatchState.Phase.GAME_END,
		"sole segment has no natural completion, runner stall, error or extra start")
	_check(not releases.is_empty() and not plays.is_empty()
		and _profile_state.elapsed_seconds > 0.0,
		"actual ordinary release and PlayRecord progress observed without trajectory selection")
	_check(_profile_report.get("bounded_ok", false)
		and _profile_report.get("errors", ["missing"]).is_empty()
		and _profile_report.get("entries", 0) > 0 and StadiumPoolHotpathProfile.active == null
		and _profile_checkpoint_ok and _profile_checkpoint_attempts == 6
		and _profile_checkpoint_count == 6,
		"nonempty finite balanced counters and six bounded checkpoints ended before cancellation")
	_check(_profile_representative(),
		"predeclared window observes required owner, guard, adapter and live-phase work")
	_profile_preserved = _profile_unchanged()
	_check(_profile_preserved, "caller, held ledger, save bytes and season chronology unchanged")
	var evidence: Dictionary = _profile_identity()
	evidence.merge(_profile_checkpoint_totals())
	evidence.merge({"fixture": fixture, "match_seed": PROFILE_SEED,
		"fixture_version": _profile_source.stadium.version,
		"source_stadium": _profile_source.stadium, "held_ledger": _profile_ledger.to_data(),
		"season_sha256": _profile_sha(_profile_season_bytes),
		"ledger_sha256": _profile_sha(_profile_ledger_bytes),
		"source_sha256": _profile_sha(_profile_source_bytes),
		"save_files": _profile_save_hashes(), "request_key": _profile_request_key,
		"physics_frames": _profile_frames, "physics_seconds": _profile_seconds,
		"progress": _profile_progress, "final": _profile_final,
		"releases": releases, "plays": plays,
		"note": "Partial ordinary trajectory; pending PlayRecords are retained unchanged."})
	_runner.cancel()
	await get_tree().process_frame
	_profile_disposed = _profile_lab_ref.get_ref() == null and _runner._lab == null \
		and _runner._viewport == null and not _runner._running and _runner.get_child_count() == 0 \
		and not _profile_adapter.enabled and _profile_adapter._lab == null
	_check(_profile_disposed and _profile_unchanged() and StadiumPoolHotpathProfile.active == null,
		"cancel disposes sole partial runner without settlement or saved mutation")
	var counters: Dictionary = _profile_identity()
	counters.merge(_profile_checkpoint_totals())
	counters["profile"] = _profile_report
	_check(_progress_write("pool-owned-v29-profile.json", counters, PROFILE_COUNTER_CAP),
		"bounded source-bound diagnostic counters retained")
	_check(_progress_write("pool-owned-v29-segment.json", evidence, MAX_ARTIFACT_BYTES),
		"bounded source-bound actual partial releases and plays retained")

func _profile_window_available() -> bool:
	var lab: Variant = _profile_lab_ref.get_ref() if _profile_lab_ref != null else null
	if _profile_reason == "fixed_1800_physics_frames" and is_instance_valid(lab) \
		and _runner._lab == lab and _runner._running:
		return true
	_check(false, "predeclared window ended early; no extension, replacement or dead-lab access")
	_profile_final = _profile_state_row()
	var counters: Dictionary = _profile_identity()
	counters.merge(_profile_checkpoint_totals())
	counters["profile"] = _profile_report
	_progress_write("pool-owned-v29-profile.json", counters, PROFILE_COUNTER_CAP)
	var evidence: Dictionary = _profile_identity()
	evidence.merge(_profile_checkpoint_totals())
	var plays: Array[Dictionary] = []
	for play: PlayRecord in _profile_records:
		plays.append(play.to_dict())
	evidence.merge({"status": "FAILED", "terminal_reason": _profile_reason,
		"runner_errors": _profile_errors, "physics_frames": _profile_frames,
		"progress": _profile_progress, "final": _profile_final, "plays": plays,
		"releases": _profile_automation.releases.duplicate(true)
			if _profile_automation != null else []})
	_progress_write("pool-owned-v29-segment.json", evidence, MAX_ARTIFACT_BYTES)
	return false

func _profile_representative() -> bool:
	var calls: Dictionary = {"property.valid_owner": 0, "guard.valid": 0,
		"adapter._sample": 0, "controller.try_resolve": 0,
		"asset.snapshot": 0, "var_to_bytes": 0}
	var live_calls: int = 0
	for row: Dictionary in _profile_report.get("rows", []):
		if row.get("phase", "") == "live" and calls.has(row.get("site", "")):
			calls[row.site] += int(row.get("calls", 0))
		if row.get("phase", "") == "live":
			live_calls += int(row.get("calls", 0))
	for count: int in calls.values():
		if count <= 0:
			return false
	return live_calls > 0

func _profile_genuine_setup() -> bool:
	SeasonSave.path = _output.path_join("owned-career.json")
	PitchBatLabSettings.path = _output.path_join("owned-settings.cfg")
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if not _check(not FileAccess.file_exists(path + suffix), "new isolated save path"):
				return false
	var career = CareerFixture.new()
	_funding = career.fund(SeasonSave.path)
	var saved_funding: Dictionary = _funding.duplicate(true)
	saved_funding.erase("season")
	if not _write("pool-owned-v28-generated-career.json", saved_funding):
		return false
	if not _check(_funding.get("ok", false),
		"predeclared generated career earns ordinary eligibility"):
		return false
	_app = ObservedApp.new()
	add_child(_app)
	await get_tree().process_frame
	if not _check(_app.season != null and _app.season.phase == SeasonState.Phase.COMPLETE,
		"genuine funded completed career restored by ordinary SeasonApp"):
		return false
	_app.begin_season(SEED, true, true, true, true, false)
	if not _check(_app.season != null and _app.season.phase == SeasonState.Phase.DRAFT
		and _app.season.picks.is_empty() and _app.season.physical != null
		and _app.season.opponents._format == 13 and not _app.season.player_access.is_empty(),
		"normal new Working season opens the earned journal before drafting"):
		return false
	if not _purchase_and_place():
		return false
	for index: int in range(4):
		if not _check(_app.season.offers().size() == 3, "ordinary current draft offer"):
			return false
		var selected: String = _app.season.offers()[0]
		_app.choose_player(selected)
		if not _check(_app.season.picks.size() == index + 1
			and _app.season.picks[index] == selected, "unchanged first-offer draft selection"):
			return false
	return _check(_app.season.pending_fixture() == {"id": 0, "round": 0, "away": 0, "home": 5}
		and _app.season.results.is_empty(), "real opening fixture, no invented history")

func _physics_process(delta: float) -> void:
	if not _profile_active:
		return
	_profile_frames += 1
	_profile_seconds += delta
	_profile_clock_ok = _profile_clock_ok and _ordinary_clock() \
		and absf(delta - 1.0 / 60.0) < 0.00000001 \
		and Engine.get_physics_frames() == _profile_frame_start + _profile_frames
	if not _profile_clock_ok or not _runner._running or _runner._lab == null \
		or _profile_state.phase == MatchState.Phase.GAME_END:
		_stop_profile("clock_or_runner_ended_early")
		return
	if _profile_frames % 300 == 0:
		_profile_progress_capture()
		if not _profile_checkpoint_capture():
			_stop_profile("checkpoint_rejected")
			return
	if _profile_frames == PROFILE_FRAMES:
		_stop_profile("fixed_1800_physics_frames")

func _stop_profile(reason: String) -> void:
	if not _profile_active:
		return
	_profile_report = StadiumPoolHotpathProfile.finish_session(reason)
	_profile_wall_usec = Time.get_ticks_usec() - _profile_wall_start
	_profile_active = false
	_profile_reason = reason
	set_physics_process(false)
	profile_window_finished.emit()

func _ordinary_clock() -> bool:
	return Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 \
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics" \
		and not get_tree().paused

func _profile_state_row() -> Dictionary:
	if _profile_state == null:
		return {}
	return {"phase": _profile_state.phase, "inning": _profile_state.inning,
		"top_half": _profile_state.top_half, "away_runs": _profile_state.away_team.runs,
		"home_runs": _profile_state.home_team.runs, "outs": _profile_state.outs,
		"balls": _profile_state.balls, "strikes": _profile_state.strikes,
		"next_plate_appearance_counter": _profile_state.plate_appearance_number,
		"simulation_seconds": _profile_state.elapsed_seconds,
		"physics_frames": _profile_frames, "physics_seconds": _profile_seconds,
		"releases": _profile_automation.releases.size() if _profile_automation != null else -1,
		"plays": _profile_records.size(),
		"water_commits": _profile_adapter.commits if _profile_adapter != null else 0}

func _profile_progress_capture() -> void:
	_profile_progress.append(_profile_state_row())
	var value: Dictionary = _profile_identity()
	value.merge({"stage": "partial_owned_segment", "fixture": PROFILE_FIXTURE,
		"match_seed": PROFILE_SEED, "progress": _profile_progress,
		"wall_seconds": (Time.get_ticks_usec() - _wall_start) / 1000000.0})
	_progress_write("pool-owned-v29-progress.json", value, PROFILE_SUMMARY_CAP)

func _profile_checkpoint_capture() -> bool:
	# Only the existing late 300-tick boundaries call this. No measured span may be open.
	_profile_checkpoint_attempts += 1
	var capture_started: int = Time.get_ticks_usec()
	var checkpoint: Dictionary = StadiumPoolHotpathProfile.checkpoint("existing_300_tick_boundary")
	_profile_checkpoint_capture_usec += Time.get_ticks_usec() - capture_started
	_profile_checkpoint_possible_overlap = _profile_checkpoint_possible_overlap \
		or checkpoint.get("open_depth", -1) != 0
	var balanced: bool = checkpoint.get("bounded_ok", false) \
		and checkpoint.get("errors", ["missing"]).is_empty() \
		and checkpoint.get("open_depth", -1) == 0 \
		and checkpoint.get("entries", -1) == checkpoint.get("completed_entries", -2) \
		and checkpoint.get("rows", []).size() == 60
	var value: Dictionary = _profile_identity()
	value.merge({"stage": "partial_profile_checkpoint", "physics_frames": _profile_frames,
		"physics_seconds": _profile_seconds, "checkpoint_index": _profile_checkpoint_attempts,
		"checkpoint_capture_usec": _profile_checkpoint_capture_usec,
		"checkpoint_io_usec_before_current_write": _profile_checkpoint_io_usec,
		"checkpoint": checkpoint})
	# This fixed, atomic replacement retains the latest checkpoint, not a growing history.
	var written: bool = _progress_write("pool-owned-v29-partial-profile.json", value,
		PROFILE_COUNTER_CAP)
	_profile_checkpoint_io_usec += Time.get_ticks_usec() - capture_started
	if written:
		_profile_checkpoint_count += 1
	_profile_checkpoint_ok = _profile_checkpoint_ok and balanced and written
	return _profile_checkpoint_ok

func _profile_checkpoint_totals() -> Dictionary:
	return {"checkpoint_attempts": _profile_checkpoint_attempts,
		"checkpoint_count": _profile_checkpoint_count, "checkpoint_ok": _profile_checkpoint_ok,
		"checkpoint_capture_usec": _profile_checkpoint_capture_usec,
		"checkpoint_io_usec": _profile_checkpoint_io_usec,
		"checkpoint_io_scope": "Snapshot copy, counter-shape checks, JSON and atomic replacement",
		# True means possible overlap in a rejected or uncertain session, never qualified timing.
		"checkpoint_overhead_in_measured_spans": _profile_checkpoint_possible_overlap}

func _profile_identity() -> Dictionary:
	return {"version": 1, "pid": OS.get_process_id(), "runtime": _runtime,
		"execution": _execution, "nonce": _nonce, "diagnostic_only": true,
		"production_qualified": false, "rendered_performance_qualified": false,
		"complete_match_qualified": false, "performance_improvement_qualified": false}

func _profile_saved() -> Dictionary:
	var result: Dictionary = {}
	for base: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			var path: String = base + suffix
			result[path.get_file()] = FileAccess.get_file_as_bytes(path) \
				if FileAccess.file_exists(path) else null
	return result

func _profile_save_hashes() -> Dictionary:
	var result: Dictionary = {}
	for name: String in _profile_saved_files:
		var bytes: Variant = _profile_saved_files[name]
		result[name] = {"exists": bytes != null,
			"sha256": _profile_sha(bytes) if bytes != null else "",
			"bytes": bytes.size() if bytes != null else 0}
	return result

func _profile_unchanged() -> bool:
	return _app.lab == null and _app.season.round_index == 0 \
		and _app.season.pending_fixture().id == 0 \
		and _app.season.results.is_empty() and _app.season.player_results.is_empty() \
		and _app.season.physical.reports.is_empty() and _app.season.physical.pending.is_empty() \
		and _profile_saved() == _profile_saved_files \
		and var_to_bytes(SeasonSave.snapshot(_app.season)) == _profile_season_bytes \
		and var_to_bytes(_profile_ledger.to_data()) == _profile_ledger_bytes \
		and var_to_bytes(_profile_object_data(_profile_source)) == _profile_source_bytes \
		and SeasonPhysicalFixtures.request_key(_app.season, PROFILE_FIXTURE) == _profile_request_key

func _profile_object_data(value: Variant) -> Variant:
	# Read-only script-state capture, same recursive representation used by the V27 fixture.
	if value is RefCounted:
		var result: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				result[property.name] = _profile_object_data(value.get(property.name))
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_profile_object_data(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _profile_object_data(value[key])
		return result
	return value

func _profile_sha(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
