extends Node
## V61 finite supported-ledger lifetime and explicit cold-boundary controls.
## Genuine paid setup; disposable installations; no fabricated baseball outcomes.
## Exact standalone helper projection from V30, never test-scene inheritance.
# gdlint: disable=max-file-lines,max-returns,function-arguments-number

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const MATCH_SEED: int = 314229
const MAX_GUARD_FRAMES: int = 1800
const MAX_CALLBACK_FRAMES: int = 2
const SUMMARY_LIMIT: int = 262144
const EXPECTED_INSTALLATIONS: int = 9
const EXPECTED_NATIVE_CHECKS: int = 190
const PROGRESS_LIMIT: int = 8192
const MAX_PROGRESS_WRITES: int = 7
const MAX_GUARD_ROWS: int = 256
const MAX_TRAJECTORY_ROWS: int = 128
const DIAGNOSTIC_REPORT_CAP: int = 8
const DIAGNOSTIC_ROW_CAP: int = 24
const DIAGNOSTIC_FIELD_CAP: int = 4096
const DIAGNOSTIC_DEPTH_CAP: int = 8
const DIAGNOSTIC_NODE_CAP: int = 256
const DIAGNOSTIC_LEAF_BYTES: int = 64
const DIAGNOSTIC_BYTE_CAP: int = 65536
const CASE_EXPECTED_CHECKS: Dictionary = {
    "fast_unchanged": 16,
    "supported_commit": 13,
    "surface_origin": 12,
    "direct_reinitialization": 12,
    "equal_revision_replacement": 12,
    "private_rematch_retirement": 13,
    "match_identity_rematch": 12,
    "private_cold_boundary_matrix": 36,
    "natural_guard_supported_callback": 15
}

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
var _source: MatchState
var _ledger: ClubAssetLedger
var _caller_ledger: ClubAssetLedger
var _caller_ledger_state: PackedByteArray
var _caller_ledger_generation: int = 0
var _case_adapter: StadiumPoolControllerActive
var _season_bytes: PackedByteArray
var _ledger_bytes: PackedByteArray
var _source_bytes: PackedByteArray
var _saved_files: Dictionary = {}
var _rows: Array[Dictionary] = []
var _starts: int = 0
var _cleanups: int = 0
var _reports: int = 0
var _runner_errors: Array[String] = []
var _case_name: String = ""
var _case_check_start: int = 0
var _case_failure_start: int = 0
var _retired_token: StadiumPoolOwnedAuthority
var _callback_seen: bool = false
var _callback_frame: int = -1
var _callback_before: PackedByteArray
var _callback_after: PackedByteArray
var _callback_result: Dictionary = {}
var _progress_writes: int = 0
var _all_preserved: bool = false
var _restoration_diagnostics: Array[Dictionary] = []
var _diagnostics_exhausted: bool = false
var _diagnostics_write_failed: bool = false

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

func _saved() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			var target: String = path + suffix
			result[target] = FileAccess.get_file_as_bytes(target) \
				if FileAccess.file_exists(target) else null
	return result

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

func _ready() -> void:
	_wall_start = Time.get_ticks_usec()
	var original_save_path: String = SeasonSave.path
	var original_settings_path: String = PitchBatLabSettings.path
	var original_last_error: String = SeasonSave.last_error
	var original_files: Dictionary = _saved()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-owned-ledger-v61-dir="):
			_output = argument.trim_prefix("--pool-owned-ledger-v61-dir=")
		if argument.begins_with("--pool-owned-ledger-v61-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-owned-ledger-v61-runtime=")
		if argument.begins_with("--pool-owned-ledger-v61-execution="):
			_execution = argument.trim_prefix("--pool-owned-ledger-v61-execution=")
		if argument.begins_with("--pool-owned-ledger-v61-nonce="):
			_nonce = argument.trim_prefix("--pool-owned-ledger-v61-nonce=")
	await _run_controls()
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
	_ledger = null
	await TestAudioDrain.finish(get_tree())
	SeasonSave.path = original_save_path
	PitchBatLabSettings.path = original_settings_path
	SeasonSave.last_error = original_last_error
	_check(var_to_bytes(original_files) == var_to_bytes(_saved()),
		"original caller save/settings files and path selectors preserved")
	_check(_checks + 1 == EXPECTED_NATIVE_CHECKS, "exact source-derived successful check total")
	var summary: Dictionary = {"version": 1, "status": "PASS" if _failures == 0 else "FAILED",
		"pid": OS.get_process_id(), "runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"checks": _checks, "expected_checks": EXPECTED_NATIVE_CHECKS,
		"failures": _failures, "failed": _failed, "cases": _rows,
		"starts": _starts, "cleanups": _cleanups, "expected_installations": EXPECTED_INSTALLATIONS,
		"progress_writes": _progress_writes, "ordinary_reports": _reports,
		"all_preserved_and_disposed": _all_preserved,
		"restoration_diagnostic_reports": _restoration_diagnostics.size(),
		"restoration_diagnostics_exhausted": _diagnostics_exhausted,
		"restoration_diagnostics_write_failed": _diagnostics_write_failed,
		"preservation_hash_encoding": "SHA256_OF_LOWERCASE_HEX_NATIVE_BYTES",
		"season_sha256": _season_bytes.hex_encode().sha256_text(),
		"ledger_sha256": _ledger_bytes.hex_encode().sha256_text(),
		"source_request_sha256": _source_bytes.hex_encode().sha256_text(),
		"saved_files_sha256": var_to_bytes(_saved_files).hex_encode().sha256_text(),
		"runner_errors": _runner_errors, "fixture": FIXTURE, "match_seed": MATCH_SEED,
		"wall_seconds": (Time.get_ticks_usec() - _wall_start) / 1000000.0,
		"ledger_policy": StadiumPoolOwnedAuthority.LEDGER_POLICY,
		"private_write_guarantee": "FAST_GENERATION_MAY_PASS_FULL_COLD_BOUNDARIES_REJECT",
		"qualification": "finite disposable ledger-lifetime controls only",
		"production_qualified": false, "report_settlement_qualified": false,
		"performance_qualified": false, "rendered_qualified": false}
	if _output_admitted:
		var encoded: String = JSON.stringify(summary, "", true, true)
		if encoded.to_utf8_buffer().size() <= SUMMARY_LIMIT:
			var output: FileAccess = FileAccess.open(
				_output.path_join("pool-owned-ledger-v61-summary.json"), FileAccess.WRITE)
			if output != null:
				output.store_string(encoded)
				if output.get_error() != OK:
					_check(false, "summary output write failed")
				output.close()
			else:
				_check(false, "summary output could not open")
		else:
			_check(false, "summary exceeds fixed byte cap")
	print("POOL_OWNED_LEDGER_V61 checks=%d failures=%d starts=%d cleanups=%d source=%s" % [
		_checks, _failures, _starts, _cleanups, _runtime])
	get_tree().quit(0 if _failures == 0 else 1)


func _run_controls() -> void:
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
	if not _check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
		and not get_tree().paused and StadiumPoolHotpathProfile.active == null,
		"ordinary unpaused 60Hz Jolt clock with profiler inactive"):
		return
	if not await _profile_genuine_setup():
		return
	var fixture: Dictionary = _fixture(3)
	_source = SeasonPhysicalFixtures.match_for(_app.season, fixture)
	_caller_ledger = ClubPlayers.assets(_app.season.career)
	if not _check(fixture == FIXTURE
		and SeasonPhysicalFixtures.seed_for(_app.season, fixture) == MATCH_SEED
		and _source != null and _caller_ledger != null
		and StadiumPoolOwnedSnapshot.valid(_source.stadium)
		and StadiumPoolOwnedSnapshot.matches(_source.stadium, _caller_ledger)
		and _source.stadium.environment.fixture == fixture.id
		and _source.stadium.environment.seed == MATCH_SEED,
		"real scheduled paid fixture17 before disposable runner starts"):
		return
	_season_bytes = var_to_bytes(SeasonSave.snapshot(_app.season))
	_ledger_bytes = var_to_bytes(_caller_ledger.to_data())
	_caller_ledger_state = StadiumPoolOwnedAuthority._ledger_state(_caller_ledger)
	_caller_ledger_generation = _caller_ledger.mutation_generation()
	_source_bytes = var_to_bytes(_profile_object_data(_source))
	_saved_files = _saved()
	_runner = PhysicalMatchRunner.new()
	add_child(_runner)
	_runner.finished.connect(func(_report: Dictionary) -> void: _reports += 1)
	_runner.private_finished.connect(func(_report: Dictionary) -> void: _reports += 1)
	_runner.failed.connect(func(reason: String) -> void: _runner_errors.append(reason))
	if not _check(not _runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID)
		and _runner._lab == null and _runner._viewport == null,
		"paid fixture refuses missing held ledger before creating a lab"):
		return
	var forged: MatchState = PhysicalMatchRequest.capture(_source)
	forged.stadium.layout.pool.copy = "not-a-paid-copy"
	if not _check(not _runner.start(forged, MATCH_SEED, PitchBatLab.FIELD_ID, _caller_ledger)
		and _runner._lab == null and _runner._viewport == null and _unchanged(),
		"forged owned copy refuses before installation and preserves paid original"):
		return
	if not await _fast_unchanged():
		return
	if not await _supported_commit():
		return
	if not await _surface_origin():
		return
	if not await _direct_reinitialization():
		return
	if not await _equal_revision_replacement():
		return
	if not await _private_rematch_retirement():
		return
	if not await _match_identity_rematch():
		return
	if not await _private_cold_boundary_matrix():
		return
	if not await _natural_guard_supported_callback():
		return
	_all_preserved = (_starts == EXPECTED_INSTALLATIONS and _cleanups == EXPECTED_INSTALLATIONS
		and _rows.size() == EXPECTED_INSTALLATIONS and _reports == 0 and _runner_errors.is_empty()
		and _unchanged() and _ledger == null and StadiumPoolHotpathProfile.active == null)
	_check(_all_preserved, "all disposable installations retire without settlement or caller mutation")


func _start_case(label: String) -> PitchBatLab:
	_case_name = label
	_case_check_start = _checks
	_case_failure_start = _failures
	# Never restore a mutated held ledger or refresh its authority. Replay the saved career.
	_ledger = ClubPlayers.assets(_app.season.career)
	if not _check(_ledger != null and _ledger != _caller_ledger
		and var_to_bytes(_ledger.to_data()) == _ledger_bytes and _unchanged(),
		label + ": fresh disposable paid ledger reconstructed through ClubPlayers.assets"):
		return null
	var frame: int = Engine.get_physics_frames()
	if not _check(_runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger),
		label + ": fresh actual paid runner start"):
		return null
	_starts += 1
	var lab: PitchBatLab = _runner._lab
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _check(property != null and property.valid_owner_full_ledger(lab)
		and lab._stadium_ledger == _ledger and lab._automation.releases.is_empty()
		and lab._play_records.is_empty() and Engine.get_physics_frames() == frame
		and lab.pool_controller_active != null and lab.pool_controller_active.enabled
		and lab.pool_controller_active._prepared != null
		and lab.pool_controller_active._prepared.valid(property.pool_model,
			StadiumPoolContract.LIVE, _runtime) and _unchanged(),
		label + ": ordinary full authority valid before first physics tick"):
		return null
	_case_adapter = lab.pool_controller_active
	_check(_retired_token == null or not _retired_token.valid_for(
		lab, property.frozen_snapshot, "INSTALLED"),
		label + ": earlier retired token cannot authorize a fresh installation")
	return lab


func _finish_case(lab: PitchBatLab, detail: Dictionary = {}) -> bool:
	var live: WeakRef = weakref(lab)
	var adapter: StadiumPoolControllerActive = _case_adapter
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var property_live: WeakRef = weakref(property)
	var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	_runner.cancel()
	await get_tree().process_frame
	var cleared: bool = (live.get_ref() == null and property_live.get_ref() == null
		and _runner._lab == null and _runner._viewport == null and not _runner._running
		and _runner.get_child_count() == 0 and not adapter.enabled and adapter._lab == null)
	var preserved: bool = _unchanged() if cleared else false
	_check(cleared and preserved and _reports == 0,
		_case_name + ": cancellation disposes authority and preserves all caller state")
	if cleared:
		_cleanups += 1
	var retired: bool = token._owner != null and token._owner.get_ref() == null
	_check(retired, _case_name + ": paid token owner released permanently")
	_retired_token = token
	_ledger = null
	var rebuilt: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	_check(rebuilt != null and var_to_bytes(rebuilt.to_data()) == _ledger_bytes,
		_case_name + ": pristine career replay independent of disposed mutation")
	_check(CASE_EXPECTED_CHECKS.has(_case_name)
		and _checks - _case_check_start + 1 == CASE_EXPECTED_CHECKS[_case_name],
		_case_name + ": exact source-derived successful case check total")
	detail.merge({"disposed": cleared, "source_save_ledger_season_preserved": preserved,
		"paid_token_owner_released": retired})
	_rows.append({"case": _case_name, "checks": _checks - _case_check_start,
		"failures": _failures - _case_failure_start, "detail": detail})
	return _failures == _case_failure_start


func _unchanged() -> bool:
	return var_to_bytes(SeasonSave.snapshot(_app.season)) == _season_bytes \
		and var_to_bytes(_caller_ledger.to_data()) == _ledger_bytes \
		and StadiumPoolOwnedAuthority._ledger_state(_caller_ledger) == _caller_ledger_state \
		and _caller_ledger.mutation_generation() == _caller_ledger_generation \
		and var_to_bytes(_profile_object_data(_source)) == _source_bytes \
		and var_to_bytes(_saved()) == var_to_bytes(_saved_files) \
		and _app.season.pending_fixture().id == 0 and _app.season.round_index == 0


func _draft_request(id: String) -> Dictionary:
	return {"id": id, "rev": _ledger.revision(), "op": "stadium_draft",
		"layout": _ledger.view().stadium_active.duplicate(true)}


func _fast_unchanged() -> bool:
	var lab: PitchBatLab = _start_case("fast_unchanged")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	var generation: int = _ledger.mutation_generation()
	var full_bytes: PackedByteArray = StadiumPoolOwnedAuthority._ledger_state(_ledger)
	_check(generation > 0 and token.valid_for(lab, property.frozen_snapshot, "INSTALLED")
		and token.full_valid_for(lab, property.frozen_snapshot, "INSTALLED"),
		"unchanged issued token passes generation and exact original cold seal")
	_check(property.valid_owner(lab) and property.ledger_boundary_valid(lab)
		and property.valid_owner_full_ledger(lab), "unchanged property passes both policy paths")
	for index: int in range(3):
		_check(property.valid_owner(lab) and _ledger.mutation_generation() == generation
			and StadiumPoolOwnedAuthority._ledger_state(_ledger) == full_bytes,
			"repeated unchanged fast admission has no generation or state side effects")
	var preview: Dictionary = _ledger.preview(_draft_request("v61-preview-only"))
	_check(preview.ok and _ledger.mutation_generation() == generation
		and StadiumPoolOwnedAuthority._ledger_state(_ledger) == full_bytes,
		"valid draft preview preserves issued ledger seal")
	var rejected: Dictionary = _ledger.commit({"op": "not-a-supported-command"})
	_check(not rejected.ok and _ledger.mutation_generation() == generation
		and property.valid_owner_full_ledger(lab), "rejected command does not invalidate unchanged owner")
	_check(_unchanged(), "positive finite controls preserve caller source/save/season/ledger")
	return await _finish_case(lab)


func _supported_commit() -> bool:
	var lab: PitchBatLab = _start_case("supported_commit")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	var generation: int = _ledger.mutation_generation()
	var revision: int = _ledger.revision()
	var request: Dictionary = _draft_request("v61-held-supported-draft")
	var result: Dictionary = _ledger.commit(request)
	_check(result.ok and not result.replayed and _ledger.mutation_generation() == generation + 1
		and _ledger.revision() == revision + 1, "ordinary successful draft advances both counters once")
	_check(not token.valid_for(lab, property.frozen_snapshot, "INSTALLED")
		and not token.full_valid_for(lab, property.frozen_snapshot, "INSTALLED"),
		"supported held-ledger commit invalidates issued authority")
	_check(not property.valid_owner(lab) and not property.valid_owner_full_ledger(lab),
		"supported held-ledger commit invalidates property without a refreshed baseline")
	var replay: Dictionary = _ledger.commit(request)
	_check(replay.ok and replay.replayed and _ledger.mutation_generation() == generation + 1
		and _ledger.revision() == revision + 1, "exact replay advances neither counter again")
	_check(not property.ledger_boundary_valid(lab) and _unchanged(),
		"replay never revives stale authority or publishes disposable journal to career")
	return await _finish_case(lab)


func _surface_origin() -> bool:
	var lab: PitchBatLab = _start_case("surface_origin")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	var generation: int = _ledger.mutation_generation()
	var revision: int = _ledger.revision()
	_ledger._initialize_surface_origin(StadiumSurfaceProgression.ROUGH_ORIGIN)
	_check(_ledger.mutation_generation() == generation + 1 and _ledger.revision() == revision,
		"surface origin writer changes generation even without a journal event")
	_check(not token.valid_for(lab, property.frozen_snapshot, "INSTALLED"),
		"equal event revision cannot conceal supported origin reinitialization")
	_check(not property.valid_owner(lab) and not property.ledger_boundary_valid(lab),
		"surface origin change refuses both fast and cold authority")
	_check(_unchanged(), "surface origin reinitialization remains disposable")
	return await _finish_case(lab)


func _direct_reinitialization() -> bool:
	var lab: PitchBatLab = _start_case("direct_reinitialization")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var generation: int = _ledger.mutation_generation()
	var revision: int = _ledger.revision()
	_ledger._init()
	_check(_ledger.mutation_generation() == generation + 1 and _ledger.revision() == revision,
		"manual callable initialization advances generation without resetting its old seal")
	_check(not property.entitlement.valid_for(lab, property.frozen_snapshot, "INSTALLED"),
		"equal-revision manually reinitialized ledger loses issued authority")
	_check(not property.valid_owner(lab) and not property.valid_owner_full_ledger(lab),
		"manual reinitialization refuses fast and full owner checks")
	_check(_unchanged(), "manual reinitialization never mutates saved career or caller ledger")
	return await _finish_case(lab)


func _equal_revision_replacement() -> bool:
	var lab: PitchBatLab = _start_case("equal_revision_replacement")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var replacement: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	_check(replacement != null and replacement != _ledger
		and replacement.revision() == _ledger.revision()
		and replacement.mutation_generation() == _ledger.mutation_generation()
		and var_to_bytes(replacement.to_data()) == var_to_bytes(_ledger.to_data()),
		"independent paid replay has equal journal revision/generation/content but distinct identity")
	lab._stadium_ledger = replacement
	_check(not property.entitlement.valid_for(lab, property.frozen_snapshot, "INSTALLED"),
		"equal-content equal-revision replacement cannot inherit original token")
	_check(not property.valid_owner(lab) and not property.valid_owner_full_ledger(lab),
		"identity replacement refuses both fast and full property checks")
	_check(_unchanged(), "replacement stays confined to disposable runner")
	return await _finish_case(lab)


func _private_rematch_retirement() -> bool:
	var lab: PitchBatLab = _start_case("private_rematch_retirement")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	var generation: int = _ledger.mutation_generation()
	var spent: int = _ledger._spent
	_ledger._spent += 1
	_check(_ledger.mutation_generation() == generation and property.valid_owner(lab),
		"unsupported private nonjournal write deliberately passes fast generation policy")
	_check(not property.valid_owner_full_ledger(lab),
		"cold rematch owner predicate rejects private write")
	_check(not StadiumPoolOwnedExtension.prepare_match_start(lab),
		"actual existing-property rematch entry refuses private ledger corruption")
	_check(not token.valid_for(lab, property.frozen_snapshot, "INSTALLED")
		and lab.pool_controller_active == null and not _case_adapter.enabled,
		"failed rematch retires token and detaches controller")
	# Retirement, unlike a direct predicate failure, must survive direct byte restoration.
	_ledger._spent = spent
	_check(not token.valid_for(lab, property.frozen_snapshot, "INSTALLED")
		and not property.valid_owner_full_ledger(lab) and _unchanged(),
		"restored private field cannot resurrect token retired by actual rematch entry")
	return await _finish_case(lab)


func _match_identity_rematch() -> bool:
	var lab: PitchBatLab = _start_case("match_identity_rematch")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	var original: MatchState = lab._match_state
	var replacement: MatchState = PhysicalMatchRequest.capture(_source)
	_check(replacement != null and replacement != original
		and var_to_bytes(replacement.stadium) == var_to_bytes(original.stadium),
		"rematch uses a distinct actual request capture with the same paid snapshot")
	lab._match_state = replacement
	_check(not token.valid_for(lab, property.frozen_snapshot, "INSTALLED"),
		"new MatchState cannot inherit issued lifetime")
	_check(not StadiumPoolOwnedExtension.prepare_match_start(lab)
		and lab.pool_controller_active == null and not _case_adapter.enabled,
		"actual changed-match rematch entry revokes")
	lab._match_state = original
	_check(not token.valid_for(lab, property.frozen_snapshot, "INSTALLED") and _unchanged(),
		"returning original MatchState does not reauthorize retired token")
	return await _finish_case(lab)


func _private_cold_boundary_matrix() -> bool:
	var lab: PitchBatLab = _start_case("private_cold_boundary_matrix")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var spent: int = _ledger._spent
	_private_direct(property, lab, "private nonjournal spent",
		func() -> void: _ledger._spent = spent + 1,
		func() -> void: _ledger._spent = spent)
	var copy: String = property.frozen_snapshot.layout.pool.copy
	var paid: int = _ledger._stock.copies[copy].paid
	_private_direct(property, lab, "private nested paid-copy row",
		func() -> void: _ledger._stock.copies[copy].paid = paid + 1,
		func() -> void: _ledger._stock.copies[copy].paid = paid)
	_private_direct(property, lab, "private nested wall stock",
		func() -> void: _ledger._wall_pieces.stock.copies["v61-private-only"] = {"paid": 1},
		func() -> void: _ledger._wall_pieces.stock.copies.erase("v61-private-only"))
	var stock: StadiumStock = _ledger._stock
	_private_direct(property, lab, "equal-content private stock replacement",
		func() -> void: _ledger._stock = StadiumStock.from_data(stock.to_data()),
		func() -> void: _ledger._stock = stock)
	return await _finish_case(lab, {"private_variants": 4,
		"meaning": "direct cold predicate rejection does not universally poison context"})


func _private_direct(property: StadiumPoolOwnedProperty, lab: PitchBatLab,
	label: String, change: Callable, restore: Callable) -> void:
	var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	var generation: int = _ledger.mutation_generation()
	var journal: PackedByteArray = var_to_bytes(_ledger.to_data())
	var full_bytes: PackedByteArray = StadiumPoolOwnedAuthority._ledger_state(_ledger)
	change.call()
	_check(_ledger.mutation_generation() == generation and var_to_bytes(_ledger.to_data()) == journal,
		label + ": private write bypasses generation and journal serialization as declared")
	_check(token.valid_for(lab, property.frozen_snapshot, "INSTALLED"),
		label + ": fast installed entitlement deliberately passes")
	_check(property.valid_owner(lab), label + ": unchanged live-node fast owner deliberately passes")
	_check(not token.full_valid_for(lab, property.frozen_snapshot, "INSTALLED"),
		label + ": full entitlement rejects original state mismatch")
	_check(not property.ledger_boundary_valid(lab),
		label + ": explicit property ledger boundary rejects")
	_check(not property.valid_owner_full_ledger(lab), label + ": live owner plus cold ledger rejects")
	restore.call()
	var restored: bool = (StadiumPoolOwnedAuthority._ledger_state(_ledger) == full_bytes
		and _ledger.mutation_generation() == generation
		and token.full_valid_for(lab, property.frozen_snapshot, "INSTALLED")
		and property.valid_owner(lab) and property.valid_owner_full_ledger(lab)
		and not lab.pool_controller_active._prepared.context._invalidated)
	_check(restored, label + ": direct restoration parity without claiming universal context poison")
	if not restored:
		_record_restore_diagnostic(property, lab, label, [bytes_to_var(full_bytes)],
			[bytes_to_var(StadiumPoolOwnedAuthority._ledger_state(_ledger))])


func _natural_guard_supported_callback() -> bool:
	var lab: PitchBatLab = _start_case("natural_guard_supported_callback")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	var wait_start: int = Engine.get_physics_frames()
	for index: int in range(MAX_GUARD_FRAMES):
		if not _runner._running or _runner._lab != lab:
			_check(false, "genuine guard window ended without a live installation")
			return false
		if adapter._guard != null and adapter._guard.generation == 1:
			break
		if index % 300 == 0:
			_guard_progress(lab, "waiting_for_first_natural_guard", wait_start)
		await get_tree().physics_frame
	var guard: StadiumPoolWaterGuard = adapter._guard
	if not _check(guard != null and guard.generation == 1 and guard.valid()
		and guard._ball == lab._batted_ball and guard._ball._started
		and not lab._automation.releases.is_empty()
		and Engine.get_physics_frames() - wait_start <= MAX_GUARD_FRAMES,
		"bounded genuine automation creates first actual guard without trajectory selection"):
		return false
	var guard_observed_frame: int = Engine.get_physics_frames()
	_guard_progress(lab, "real_guard_captured", wait_start)
	var downstream: Callable = guard._downstream
	var generation: int = _ledger.mutation_generation()
	var revision: int = _ledger.revision()
	var request: Dictionary = _draft_request("v61-natural-downstream-draft")
	var commits: int = adapter.commits
	var receipts: PackedByteArray = var_to_bytes(guard.receipts)
	_callback_seen = false
	_callback_frame = -1
	guard._downstream = func(ball: BattedBallBody, batch: Array[Dictionary]) -> void:
		downstream.call(ball, batch)
		if _callback_seen:
			return
		_callback_seen = true
		_callback_frame = Engine.get_physics_frames()
		_callback_before = var_to_bytes(StadiumPoolWaterGuard._state_parameters(guard._state))
		_callback_result = _ledger.commit(request)
		_callback_after = var_to_bytes(StadiumPoolWaterGuard._state_parameters(guard._state))
	var armed_frame: int = Engine.get_physics_frames()
	for index: int in range(MAX_CALLBACK_FRAMES):
		await get_tree().physics_frame
		if _callback_seen:
			break
	var rejected_same_tick: bool = false
	for row: Dictionary in guard.unsupported:
		if row.get("reason") == "DOWNSTREAM_NOT_OBSERVATIONAL" \
			and row.get("physics_frame") == _callback_frame:
			rejected_same_tick = true
	_check(_callback_seen and _callback_result.get("ok", false)
		and not _callback_result.get("replayed", true)
		and _ledger.mutation_generation() == generation + 1 and _ledger.revision() == revision + 1,
		"actual first guard downstream performs successful supported journal commit")
	_check(_callback_frame >= armed_frame
		and Engine.get_physics_frames() - armed_frame <= MAX_CALLBACK_FRAMES
		and Engine.get_physics_frames() - wait_start <= MAX_GUARD_FRAMES + MAX_CALLBACK_FRAMES
		and _callback_before == _callback_after and rejected_same_tick
		and guard._generation_invalid and guard._context._invalidated
		and adapter.commits == commits and var_to_bytes(guard.receipts) == receipts,
		"real post-downstream callback rejects supported mutation in the same physics tick")
	guard._downstream = downstream
	_check(not guard.valid() and not property.valid_owner_full_ledger(lab)
		and guard._context._invalidated and _unchanged(),
		"restoring callback never refreshes changed ledger generation or poisoned context")
	var plays: Array[Dictionary] = []
	for play: PlayRecord in lab._play_records:
		plays.append(play.to_dict())
	var detail: Dictionary = {"version": 1, "pid": OS.get_process_id(),
		"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"wait_start_physics_frame": wait_start, "guard_observed_physics_frame": guard_observed_frame,
		"callback_armed_physics_frame": armed_frame,
		"callback_observed_physics_frame": Engine.get_physics_frames(),
		"wait_physics_frames": guard_observed_frame - wait_start,
		"callback_physics_frames": Engine.get_physics_frames() - armed_frame,
		"max_wait_physics_frames": MAX_GUARD_FRAMES, "max_callback_physics_frames": MAX_CALLBACK_FRAMES,
		"callback_before_state_sha256": _callback_before.hex_encode().sha256_text(),
		"callback_after_state_sha256": _callback_after.hex_encode().sha256_text(),
		"mutation_physics_frame": _callback_frame, "same_tick_rejection": rejected_same_tick,
		"issued_ledger_generation": generation,
		"observed_ledger_generation": _ledger.mutation_generation(),
		"callback_commit": _callback_result.duplicate(true),
		"releases": lab._automation.releases.duplicate(true), "plays": plays,
		"guard_records": guard.records.duplicate(true),
		"guard_unsupported": guard.unsupported.duplicate(true),
		"water_receipts": guard.receipts.duplicate(true), "commits": adapter.commits,
		"note": "Actual partial ordinary trajectory; no full-game, settlement or performance claim."}
	if not _check(detail.releases.size() <= MAX_TRAJECTORY_ROWS
		and plays.size() <= MAX_TRAJECTORY_ROWS and guard.records.size() <= MAX_GUARD_ROWS
		and guard.unsupported.size() <= MAX_GUARD_ROWS
		and guard.receipts.size() <= MAX_TRAJECTORY_ROWS,
		"fixed raw trajectory/guard row caps preserve complete untruncated evidence"):
		return false
	_write("pool-owned-ledger-v61-guard-raw.json", detail)
	return await _finish_case(lab, {"mutation_physics_frame": _callback_frame,
		"same_tick_rejection": rejected_same_tick,
		"actual_releases": detail.releases.size(), "actual_plays": plays.size()})


func _guard_progress(lab: PitchBatLab, stage: String, start: int) -> void:
	var progress: Dictionary = {"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"stage": stage, "physics_frames": Engine.get_physics_frames() - start,
		"releases": lab._automation.releases.size(), "plays": lab._play_records.size(),
		"phase": lab._match_state.phase, "source_unchanged": _unchanged()}
	var encoded: String = JSON.stringify(progress, "", true, true)
	if _progress_writes >= MAX_PROGRESS_WRITES or encoded.to_utf8_buffer().size() > PROGRESS_LIMIT:
		_check(false, "bounded progress write or byte cap exceeded")
		return
	_progress_writes += 1
	var file: FileAccess = FileAccess.open(
		_output.path_join("pool-owned-ledger-v61-progress.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(encoded)
		if file.get_error() != OK:
			_check(false, "bounded guard progress write failed")
		file.close()
	else:
		_check(false, "bounded guard progress could not open")


func _record_restore_diagnostic(property: StadiumPoolOwnedProperty, lab: PitchBatLab,
	label: String, expected_extra: Array = [], actual_extra: Array = []) -> void:
	# Failure-only observation. It never asks any authority predicate to run again.
	# Diff/normalization budgets do not bound whole fixed-block collection/serialization.
	if _restoration_diagnostics.size() >= DIAGNOSTIC_REPORT_CAP:
		_diagnostics_exhausted = true
		_write_restore_diagnostics()
		return
	var report: Dictionary = {"label": label, "case": _case_name,
		"physics_frame": Engine.get_physics_frames(), "visited_fields": 0,
		"exhausted_budget": false, "differences": []}
	if not expected_extra.is_empty() or not actual_extra.is_empty():
		_diagnostic_diff(expected_extra, actual_extra, "original_snapshot_or_metadata", 0, report)
	var policy: StadiumPoolOwnedIntegrity = property.integrity_policy2
	if policy != null:
		var original: Array = bytes_to_var(policy._topology_bytes)
		var current: Array = policy._topology(property)
		_diagnostic_diff(_normalized_diagnostic_rows(original, "topology", report),
			_normalized_diagnostic_rows(current, "topology", report), "finite_topology", 0, report)
		if _diagnostic_available(report, 0):
			_diagnostic_diff(bytes_to_var(policy._ancestor_bytes),
				StadiumPoolOwnedIntegrity._ancestors(property), "finite_ancestors", 0, report)
		if _diagnostic_available(report, 0):
			_diagnostic_diff(
				_normalized_diagnostic_rows(bytes_to_var(policy._model_bytes), "tree", report),
				_normalized_diagnostic_rows(policy._tree(property.pool_model), "tree", report),
				"finite_model", 0, report)
		if _diagnostic_available(report, 0):
			_diagnostic_diff(
				_normalized_diagnostic_rows(bytes_to_var(policy._boundary_bytes), "tree", report),
				_normalized_diagnostic_rows(policy._tree(property.boundary), "tree", report),
				"finite_boundary", 0, report)
		var body_count: int = 0
		for id: int in policy._body_bytes:
			if body_count >= 64 or not _diagnostic_available(report, 0):
				report.exhausted_budget = true
				break
			body_count += 1
			var body: StaticBody3D = instance_from_id(id) as StaticBody3D
			var rows: Array = policy._tree(body) if is_instance_valid(body) else []
			_diagnostic_diff(
				_normalized_diagnostic_rows(bytes_to_var(policy._body_bytes[id]), "tree", report),
				_normalized_diagnostic_rows(rows, "tree", report),
				"finite_body/" + str(id), 0, report)
	report["lab_instance"] = lab.get_instance_id()
	_restoration_diagnostics.append(report)
	_write_restore_diagnostics()

func _normalized_diagnostic_rows(rows: Array, kind: String, report: Dictionary) -> Array:
	# Give fixed descriptor positions field names, preserving every native value/type.
	var result: Array = []
	if rows.size() > DIAGNOSTIC_NODE_CAP:
		report.exhausted_budget = true
	for index: int in range(mini(rows.size(), DIAGNOSTIC_NODE_CAP)):
		var row: Array = rows[index]
		var node: Array = row[0]
		var item: Dictionary = {"node": {"instance": node[0], "parent": node[1],
			"native_class": node[2], "name": node[3], "script": node[4],
			"process_mode": node[5], "process_thread_group": node[6], "world": node[7]}}
		if kind == "topology":
			if row.size() > 1 and row[1].size() == 4:
				item["receiver_visual"] = {"position": row[1][0], "scale": row[1][1],
					"rotation_x": row[1][2], "rotation_y": row[1][3]}
			elif row.size() > 1:
				item["local_transform"] = row[1]
			if row.size() > 2:
				item["metadata_rows"] = row[2]
		else:
			item["metadata_rows"] = row[1]
			if row.size() > 2:
				item["local_global_transforms"] = row[2]
			if row.size() > 3:
				item["physics_or_shape"] = row[3]
		result.append(item)
	return result

func _diagnostic_available(report: Dictionary, depth: int) -> bool:
	var available: bool = (report.visited_fields < DIAGNOSTIC_FIELD_CAP
		and report.differences.size() < DIAGNOSTIC_ROW_CAP and depth <= DIAGNOSTIC_DEPTH_CAP)
	if not available:
		report.exhausted_budget = true
	return available

func _diagnostic_diff(expected: Variant, actual: Variant, path: String,
	depth: int, report: Dictionary) -> void:
	if not _diagnostic_available(report, depth):
		return
	report.visited_fields += 1
	if var_to_bytes(expected) == var_to_bytes(actual):
		return
	if typeof(expected) == typeof(actual) and expected is Dictionary:
		_diagnostic_diff(expected.keys(), actual.keys(), path + "/ordered_keys", depth + 1, report)
		for key: Variant in expected:
			if not _diagnostic_available(report, depth + 1):
				break
			if not actual.has(key):
				_diagnostic_leaf(expected[key], null, path + "/missing:" + str(key), report)
			else:
				_diagnostic_diff(expected[key], actual[key], path + "/" + str(key), depth + 1, report)
		return
	if typeof(expected) == typeof(actual) and expected is Array:
		if expected.size() != actual.size():
			_diagnostic_leaf(expected.size(), actual.size(), path + "/length", report)
		for index: int in range(mini(expected.size(), actual.size())):
			if not _diagnostic_available(report, depth + 1):
				break
			_diagnostic_diff(expected[index], actual[index],
				path + "/" + str(index), depth + 1, report)
		return
	_diagnostic_leaf(expected, actual, path, report)

func _diagnostic_leaf(expected: Variant, actual: Variant, path: String,
	report: Dictionary) -> void:
	if not _diagnostic_available(report, 0):
		return
	report.differences.append({"field": path,
		"expected": _diagnostic_native(expected, report),
		"actual": _diagnostic_native(actual, report)})

func _diagnostic_native(value: Variant, report: Dictionary) -> Dictionary:
	var encoded: PackedByteArray = var_to_bytes(value)
	var result: Dictionary = {"type_id": typeof(value), "type": type_string(typeof(value)),
		"native_bytes": encoded.size(), "native_hex_sha256": encoded.hex_encode().sha256_text()}
	if encoded.size() <= DIAGNOSTIC_LEAF_BYTES:
		result["native_hex"] = encoded.hex_encode()
	else:
		result["native_hex_omitted_by_byte_cap"] = true
		report.exhausted_budget = true
	return result

func _write_restore_diagnostics() -> void:
	for report: Dictionary in _restoration_diagnostics:
		_diagnostics_exhausted = _diagnostics_exhausted or report.exhausted_budget
	var payload: Dictionary = {"version": 1, "pid": OS.get_process_id(), "runtime": _runtime,
		"execution": _execution, "nonce": _nonce, "failure_only": true,
		"budget_scope": "RETAINED_DIFF_VISITOR_AND_ARTIFACT_NOT_FULL_BLOCK_COLLECTION",
		"exhausted_budget": _diagnostics_exhausted, "reports": _restoration_diagnostics,
		"caps": {"reports": DIAGNOSTIC_REPORT_CAP, "rows_per_report": DIAGNOSTIC_ROW_CAP,
			"fields_per_report": DIAGNOSTIC_FIELD_CAP, "depth": DIAGNOSTIC_DEPTH_CAP,
			"nodes_per_block": DIAGNOSTIC_NODE_CAP, "bodies_per_report": 64,
			"native_leaf_bytes": DIAGNOSTIC_LEAF_BYTES, "artifact_bytes": DIAGNOSTIC_BYTE_CAP}}
	var encoded: String = JSON.stringify(payload, "", true, true)
	# Only diagnostic differences can be shortened, always explicitly marked incomplete.
	while encoded.to_utf8_buffer().size() > DIAGNOSTIC_BYTE_CAP:
		_diagnostics_exhausted = true
		payload.exhausted_budget = true
		var last: Dictionary = _restoration_diagnostics[-1]
		last.exhausted_budget = true
		if last.differences.is_empty():
			_diagnostics_write_failed = true
			return
		last.differences.pop_back()
		encoded = JSON.stringify(payload, "", true, true)
	var output: FileAccess = FileAccess.open(_output.path_join(
		"pool-owned-integrity-v30-restoration-diagnostics.json"), FileAccess.WRITE)
	if output == null:
		_diagnostics_write_failed = true
		return
	output.store_string(encoded)
	_diagnostics_write_failed = _diagnostics_write_failed or output.get_error() != OK
	output.close()

