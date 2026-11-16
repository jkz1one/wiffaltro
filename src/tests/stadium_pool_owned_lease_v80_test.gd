extends Node
## V80 exact-owned supported-writer lease controls; legacy full fixtures remain unchanged.
## Genuine paid setup, fixed existing fixture/seed, no trajectory or outcome claim.
# gdlint: disable=max-file-lines,max-returns,function-arguments-number

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const EnterProbe = preload("res://src/tests/stadium_pool_owned_lease_enter_probe_v80.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const MATCH_SEED: int = 314229
const SUMMARY_LIMIT: int = 262144
const EXPECTED_INSTALLATIONS: int = 31
const EXPECTED_NATIVE_CHECKS: int = 463
const EXPECTED_OBSERVATIONS: int = 31
const OBSERVATION_CAP: int = 128
const FAILURE_LABEL_CAP: int = 384
const FAILURE_LABEL_BYTES: int = 256
const OBSERVATION_ROW_BYTES: int = 1536
const NATIVE_VALUE_BYTES: int = 256
const MAX_GUARD_FRAMES: int = 1800
const MAX_CALLBACK_FRAMES: int = 2
const CASE_EXPECTED_CHECKS: Dictionary = {
	"authored_contract": 52,
	"static_boundary": 29,
	"install_body_pose": 11,
	"install_carrier_descriptor": 11,
	"install_carrier_pose": 11,
	"install_actor_binding": 11,
	"install_process_order": 11,
	"install_fixture_snapshot": 11,
	"install_paid_descriptor": 11,
	"install_ledger_generation": 12,
	"install_stale_generation": 11,
	"structure_nested_property": 13,
	"structure_nested_external_static": 11,
	"structure_moved_external_static": 11,
	"structure_runtime_script_attachment": 11,
	"structure_unsupported_native_timer": 11,
	"structure_reentrant_enter": 11,
	"structure_reentrant_reparent": 11,
	"structure_registered_static_remove": 11,
	"structure_registered_static_reparent": 11,
	"lifecycle_rollback": 11,
	"lifecycle_rematch": 11,
	"lifecycle_busy_revoke": 11,
	"play_ball_parameters": 12,
	"play_ordinary_router": 12,
	"play_signal_inventory": 12,
	"play_body_identity": 12,
	"play_body_parent": 12,
	"play_body_rid": 12,
	"launch_retirement": 15,
	"custom_fallback": 12
}

const BODY_CAP: int = 22
const MAX_TOTAL_GUARD_FRAMES: int = 18000

var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _output: String = ""
var _runtime: String = ""
var _expected_runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _app: SeasonApp
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
var _all_preserved: bool = false
var _observations: Array[Dictionary] = []
var _observations_complete: bool = true


var _case_property: WeakRef
var _case_token: StadiumPoolOwnedAuthority
var _case_lease: StadiumPoolOwnedFieldLease
var _guard_wait_frames: int = 0

class ExternalScript extends Node3D:
	var fixture_probe: bool = true


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
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
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
	_case_property = weakref(property)
	_case_token = property.entitlement as StadiumPoolOwnedAuthority
	_case_lease = property._owned_field_lease
	_check(_retired_token == null or not _retired_token.valid_for(
		lab, property.frozen_snapshot, "INSTALLED"),
		label + ": earlier retired token cannot authorize a fresh installation")
	return lab

func _finish_case(lab: PitchBatLab, detail: Dictionary = {}) -> bool:
	var live: WeakRef = weakref(lab)
	var adapter: StadiumPoolControllerActive = _case_adapter
	var property_live: WeakRef = _case_property
	var token: StadiumPoolOwnedAuthority = _case_token
	_runner.cancel()
	var synchronously_retired: bool = _case_lease == null or _case_lease.phase == "REVOKED"
	await get_tree().process_frame
	var cleared: bool = (live.get_ref() == null and property_live.get_ref() == null
		and _runner._lab == null and _runner._viewport == null and not _runner._running
		and _runner.get_child_count() == 0 and not adapter.enabled and adapter._lab == null
		and synchronously_retired)
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
	_observe({"case": _case_name, "disposed": cleared, "preserved": preserved,
		"synchronously_retired": synchronously_retired, "paid_token_owner_released": retired})
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

func _ready() -> void:
	_run_fixture.call_deferred()

func _run_fixture() -> void:
	_wall_start = Time.get_ticks_usec()
	var original_save_path: String = SeasonSave.path
	var original_settings_path: String = PitchBatLabSettings.path
	var original_last_error: String = SeasonSave.last_error
	var original_files: Dictionary = _saved()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-owned-lease-v80-dir="):
			_output = argument.trim_prefix("--pool-owned-lease-v80-dir=")
		if argument.begins_with("--pool-owned-lease-v80-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-owned-lease-v80-runtime=")
		if argument.begins_with("--pool-owned-lease-v80-execution="):
			_execution = argument.trim_prefix("--pool-owned-lease-v80-execution=")
		if argument.begins_with("--pool-owned-lease-v80-nonce="):
			_nonce = argument.trim_prefix("--pool-owned-lease-v80-nonce=")
	await _run_controls()
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	if is_instance_valid(_app):
		if _app.is_node_ready():
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
	var failure_bounds: bool = _failure_rows_bounded()
	if not failure_bounds:
		_check(false, "full failure diagnostics exceed declared bound; retained without truncation")
	var summary: Dictionary = {"version": 1, "status": "PASS" if _failures == 0 else "FAILED",
		"pid": OS.get_process_id(), "runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"checks": _checks, "expected_checks": EXPECTED_NATIVE_CHECKS,
		"failures": _failures, "failed": _failed, "cases": _rows,
		"failure_diagnostics_bounded": failure_bounds,
		"starts": _starts, "cleanups": _cleanups, "expected_installations": EXPECTED_INSTALLATIONS,
		"ordinary_reports": _reports, "all_preserved_and_disposed": _all_preserved,
		"preservation_hash_encoding": "SHA256_OF_LOWERCASE_HEX_NATIVE_BYTES",
		"season_sha256": _season_bytes.hex_encode().sha256_text(),
		"ledger_sha256": _ledger_bytes.hex_encode().sha256_text(),
		"source_request_sha256": _source_bytes.hex_encode().sha256_text(),
		"saved_files_sha256": var_to_bytes(_saved_files).hex_encode().sha256_text(),
		"runner_errors": _runner_errors, "fixture": FIXTURE, "match_seed": MATCH_SEED,
		"wall_seconds": (Time.get_ticks_usec() - _wall_start) / 1000000.0,
		"owner_scene_policy": StadiumPoolOwnedIntegrity.POLICY,
		"lease_policy": StadiumPoolOwnedFieldLease.POLICY,
		"guard_wait_frames": _guard_wait_frames,
		"preserved_legacy_fixture_checks": {"integrity": 569, "ledger": 190, "contact": 68,
			"field": 334, "scene": 227, "model": 187, "guard": 148},
		"lease_observations": _observations, "observations_complete": _observations_complete,
		"expected_observations": EXPECTED_OBSERVATIONS,
		"source_text_policy": "FULL_LEGACY_SOURCE_ORACLES_UNCHANGED;LEASE_RELOAD_UNSUPPORTED",
		"compiled_reload_history_qualified": false,
		"caps": {"observations": OBSERVATION_CAP, "row_bytes": OBSERVATION_ROW_BYTES,
			"native_value_bytes": NATIVE_VALUE_BYTES, "summary_bytes": SUMMARY_LIMIT,
			"failure_labels": FAILURE_LABEL_CAP, "failure_label_bytes": FAILURE_LABEL_BYTES},
		"qualification": "finite owned static-field lease; no genuine terminal report or settlement",
		"production_qualified": false, "report_settlement_qualified": false,
		"performance_qualified": false, "rendered_qualified": false}
	if _output_admitted:
		var encoded: String = JSON.stringify(summary, "", true, true)
		if encoded.to_utf8_buffer().size() <= SUMMARY_LIMIT:
			var output: FileAccess = FileAccess.open(
				_output.path_join("pool-owned-lease-v80-summary.json"), FileAccess.WRITE)
			if output != null:
				output.store_string(encoded)
				if output.get_error() != OK:
					_check(false, "summary output write failed")
				output.close()
			else:
				_check(false, "summary output could not open")
		else:
			_check(false, "summary exceeds fixed byte cap")
	print("POOL_OWNED_LEASE_V80 checks=%d failures=%d starts=%d cleanups=%d source=%s" % [
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
		"real scheduled paid fixture before disposable runner starts"):
		return
	_season_bytes = var_to_bytes(SeasonSave.snapshot(_app.season))
	_ledger_bytes = var_to_bytes(_caller_ledger.to_data())
	_caller_ledger_state = StadiumPoolOwnedAuthority._ledger_state(_caller_ledger)
	_caller_ledger_generation = _caller_ledger.mutation_generation()
	_source_bytes = var_to_bytes(_profile_object_data(_source))
	_saved_files = _saved()
	_runner = PhysicalMatchRunner.new()
	get_tree().root.add_child(_runner)
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
	if not await _lease_controls():
		return
	_all_preserved = (_starts == EXPECTED_INSTALLATIONS and _cleanups == EXPECTED_INSTALLATIONS
		and _rows.size() == EXPECTED_INSTALLATIONS and _reports == 0 and _runner_errors.is_empty()
		and _unchanged() and _ledger == null and StadiumPoolHotpathProfile.active == null
		and _observations_complete and _observations.size() == EXPECTED_OBSERVATIONS)
	_check(_all_preserved, "all disposable installations retire without settlement or caller mutation")

func _first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child: Node in root.get_children(true):
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null

func _shape(body: CollisionObject3D) -> CollisionShape3D:
	for child: Node in body.get_children(true):
		if child is CollisionShape3D:
			return child
	return null

func _observe(row: Dictionary) -> void:
	if _observations.size() >= OBSERVATION_CAP \
		or JSON.stringify(row, "", true, true).to_utf8_buffer().size() > OBSERVATION_ROW_BYTES:
		_observations_complete = false
		_check(false, "finite observation count or complete-row byte cap exceeded")
		return
	_observations.append(row)

func _failure_rows_bounded() -> bool:
	if _failed.size() > FAILURE_LABEL_CAP or _runner_errors.size() > 16:
		return false
	for label: String in _failed + _runner_errors:
		if JSON.stringify(label).to_utf8_buffer().size() > FAILURE_LABEL_BYTES:
			return false
	return true


func _lease_controls() -> bool:
	if not await _authored_contract() or not await _static_boundary():
		return false
	for kind: String in ["body_pose", "carrier_descriptor", "carrier_pose", "actor_binding",
		"process_order", "fixture_snapshot", "paid_descriptor", "ledger_generation", "stale_generation"]:
		if not await _installation_negative(kind):
			return false
	for kind: String in ["nested_property", "nested_external_static", "moved_external_static",
		"runtime_script_attachment", "unsupported_native_timer", "reentrant_enter",
		"reentrant_reparent", "registered_static_remove", "registered_static_reparent"]:
		if not await _structural_negative(kind):
			return false
	for kind: String in ["rollback", "rematch", "busy_revoke"]:
		if not await _lifecycle_negative(kind):
			return false
	for kind: String in ["ball_parameters", "ordinary_router", "signal_inventory",
		"body_identity", "body_parent", "body_rid"]:
		if not await _play_negative(kind):
			return false
	return await _launch_retirement() and await _custom_fallback()


func _admitted(lab: PitchBatLab) -> bool:
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	return _check(lease != null and lease.get_script() == StadiumPoolOwnedFieldLease
		and lease.phase == "INSTALLED" and lease.generation == 1
		and property._field_installation_sealed and not property._field_installation_retired
		and lease.valid_installation(property, lab) and property.valid_owner_leased(lab, lease)
		and _runner.get_parent() == get_tree().root and _app.get_script() == SeasonApp,
		_case_name + ": actual exact production ancestry admits installation lease")


func _original_seals(property: StadiumPoolOwnedProperty) -> PackedByteArray:
	return var_to_bytes([property._snapshot_bytes, property._field_bytes, property._pool_ids,
		property.integrity_policy2._body_bytes, property.integrity_policy2._inventory_ids,
		property.integrity_policy2._topology_bytes, property.integrity_policy2._model_bytes,
		property.integrity_policy2._boundary_bytes])


func _value_only(value: Variant) -> bool:
	if value is Object or value is Callable or value is Signal or value is RID:
		return false
	if value is Dictionary:
		for key: Variant in value:
			if not _value_only(key) or not _value_only(value[key]):
				return false
	if value is Array:
		for entry: Variant in value:
			if not _value_only(entry):
				return false
	return true


func _mutate_export(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value.keys():
			_mutate_export(value[key])
		value["fixture_external_write"] = [1, 2, 3]
	elif value is Array:
		for entry: Variant in value:
			_mutate_export(entry)
		value.clear()


func _authored_contract() -> bool:
	var lab: PitchBatLab = _start_case("authored_contract")
	if lab == null or not _admitted(lab):
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var seals: PackedByteArray = _original_seals(property)
	var exported: Dictionary = lease.descriptor()
	var exported_bytes: PackedByteArray = var_to_bytes(exported)
	var detached: bool = _value_only(exported)
	_mutate_export(exported)
	_check(detached and var_to_bytes(lease.descriptor()) == exported_bytes,
		"new lease descriptor recursively contains values only and returns detached copies")
	var forged: StadiumPoolOwnedFieldLease = StadiumPoolOwnedFieldLease.new()
	forged.generation = lease.generation
	forged.phase = lease.phase
	forged.play_generation = lease.play_generation
	_check(not forged.valid_installation(property, lab)
		and not property.valid_owner_leased(lab, forged)
		and property._owned_field_lease == lease and property.valid_owner_leased(lab, lease),
		"new exact-base lease with copied public state cannot forge installation authority")
	property.install_owned_field_lease(lab, _case_adapter)
	_check(property._owned_field_lease == lease and _original_seals(property) == seals,
		"repeat install cannot recapture or replace the original installed lease")
	var helper_results: Array[Dictionary] = _helper_refusals(lab, property)
	var visual: Node3D = property.receiver.chair.get_node("Visual") as Node3D
	var original_rotation: float = visual.rotation.z
	var mesh: MeshInstance3D = _first_mesh(property.receiver.chair)
	var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
	var original_color: Color = material.albedo_color
	visual.rotation.z += 0.125
	material.albedo_color = Color(0.7, 0.4, 0.2, 0.35)
	_check(property.valid_owner_leased(lab, lease) and property.valid_owner_full_ledger(lab),
		"authorized receiver rocking and render-only fading preserve leased and full gameplay checks")
	visual.rotation.z = original_rotation
	material.albedo_color = original_color
	_check(property.valid_owner_leased(lab, lease) and _original_seals(property) == seals,
		"visual restoration keeps original installation seals without recapture")
	# Removed before first launch; this does not weaken full preaward controller-tree equality.
	var external: Node3D = Node3D.new()
	lab.add_child(external)
	_check(property.valid_owner_leased(lab, lease) and lease.phase == "INSTALLED",
		"harmless exact native Node3D pre-launch addition preserves installed lease")
	lab.remove_child(external)
	external.free()
	_check(property.valid_owner_leased(lab, lease) and _original_seals(property) == seals,
		"harmless exact native Node3D pre-launch removal restores membership before any launch")
	var tabbar_control: Dictionary = _authored_tabbar_timer_controls(lab, property)
	if tabbar_control.is_empty():
		return false
	var timer_control: Dictionary = _internal_timer_inventory_negative(lab, property)
	if timer_control.is_empty():
		return false
	return await _finish_case(lab, {"lease_admitted": true,
		"exact_production_ancestors": true, "descriptor_value_only_detached": detached,
		"forged_public_state_rejected": true, "helper_refusals": helper_results,
		"legal_visuals_and_prelaunch_native_node_allowed": true, "original_seals_preserved": true,
		"internal_popup_timer": timer_control, "authored_tabbar_timer": tabbar_control})


func _authored_tabbar_timer_controls(lab: PitchBatLab,
	property: StadiumPoolOwnedProperty) -> Dictionary:
	# Isolated classifier/membership probes restore before any authority check.
	# They do not prove revocation; the later live-play control does that separately.
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var timer: Timer
	var recorded: Dictionary = {}
	for record: Dictionary in lease._external_nodes.values():
		var node: Node = record.ref.get_ref() as Node
		if is_instance_valid(node) and node.get_class() == "Timer" \
			and node.get_parent() != null and node.get_parent().get_class() == "TabBar":
			timer = node as Timer
			recorded = record
			break
	var tabs: TabBar = timer.get_parent() as TabBar if timer != null else null
	var panel: Node = tabs.get_parent().get_parent() if tabs != null else null
	var original: Array[Dictionary] = timer.get_signal_connection_list(&"timeout") \
		if timer != null else []
	var callback: Callable = original[0].callable if original.size() == 1 else Callable()
	if not _check(timer != null and timer.get_script() == null and timer.one_shot
		and tabs.get_script() == null and panel != null and panel.get_script() == MatchStatsPanel
		and (panel as MatchStatsPanel)._tabs == tabs
		and not tabs.get_children().has(timer) and tabs.get_children(true).has(timer)
		and original.size() == 1 and original == recorded.ui_timeout
		and callback.is_valid() and callback.is_custom() and callback.get_object() == tabs
		and callback.get_bound_arguments_count() == 0 and callback.get_unbound_arguments_count() == 0
		and callback.get_argument_count() == 0 and original[0].flags == 0
		and lease._native_ui_internal(timer) and lease._membership_valid(recorded)
		and property.valid_owner_leased(lab, lease) and property.valid_owner_full_ledger(lab),
		"actual authored MatchStatsPanel TabBar owns its recorded internal one-shot native Timer"):
		return {}
	timer.one_shot = false
	_check(not lease._native_ui_internal(timer) and not lease._membership_valid(recorded),
		"TabBar repeating Timer rejected by fresh classifier and recorded membership")
	timer.one_shot = true
	timer.timeout.disconnect(callback)
	_check(not lease._native_ui_internal(timer) and not lease._membership_valid(recorded),
		"TabBar missing timeout rejected by classifier and exact inventory")
	var alternate: Callable = Callable(tabs, &"queue_redraw")
	var connected: bool = timer.timeout.connect(alternate) == OK
	_check(connected and not lease._native_ui_internal(timer)
		and not lease._membership_valid(recorded),
		"TabBar same-parent standard callable cannot replace native method-pointer timeout")
	timer.timeout.disconnect(alternate)
	var bound: Callable = callback.bind(1)
	connected = timer.timeout.connect(bound) == OK
	_check(connected and not lease._native_ui_internal(timer)
		and not lease._membership_valid(recorded),
		"TabBar bound timeout callback rejected without invoking it")
	timer.timeout.disconnect(bound)
	var unbound: Callable = callback.unbind(1)
	connected = timer.timeout.connect(unbound) == OK
	_check(connected and not lease._native_ui_internal(timer)
		and not lease._membership_valid(recorded),
		"TabBar unbound timeout callback rejected without invoking it")
	timer.timeout.disconnect(unbound)
	var observer: Callable = func() -> void: pass
	connected = timer.timeout.connect(observer) == OK
	_check(connected and not lease._native_ui_internal(timer)
		and not lease._membership_valid(recorded),
		"TabBar foreign callable cannot become its sole timeout target")
	timer.timeout.disconnect(observer)
	connected = timer.timeout.connect(callback, CONNECT_DEFERRED) == OK
	_check(connected and not lease._native_ui_internal(timer)
		and not lease._membership_valid(recorded),
		"TabBar altered timeout flags rejected with unchanged callback identity")
	timer.timeout.disconnect(callback)
	connected = timer.timeout.connect(callback, original[0].flags) == OK
	_check(connected and timer.get_signal_connection_list(&"timeout") == original
		and lease._native_ui_internal(timer) and lease._membership_valid(recorded)
		and lease.phase == "INSTALLED" and not property._field_installation_retired
		and property.valid_owner_leased(lab, lease) and property.valid_owner_full_ledger(lab),
		"isolated TabBar probes restore before authority validation and keep the live lease")
	return {"actual_authored_tabbar": true, "original_timeout_count": original.size(),
		"one_shot_rejected": true, "missing_callback_rejected": true,
		"standard_callback_rejected": true, "bound_callback_rejected": true,
		"unbound_callback_rejected": true, "foreign_callback_rejected": true,
		"changed_flags_rejected": true, "original_inventory_restored": true,
		"helper_probes_only": true, "lease_still_installed": true}


func _internal_timer_inventory_negative(lab: PitchBatLab,
	property: StadiumPoolOwnedProperty, parent_class: String = "PopupMenu") -> Dictionary:
	# Use an actual admitted UI internal; never manufacture a Timer or emit timeout.
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var seals: PackedByteArray = _original_seals(property)
	var timer: Timer
	var recorded: Dictionary = {}
	for record: Dictionary in lease._external_nodes.values():
		var node: Node = record.ref.get_ref() as Node
		if is_instance_valid(node) and node.get_class() == "Timer" \
			and node.get_parent() != null and node.get_parent().get_class() == parent_class:
			timer = node as Timer
			recorded = record
			break
	var menu: Node = timer.get_parent() if timer != null else null
	var original: Array[Dictionary] = timer.get_signal_connection_list(&"timeout") \
		if timer != null else []
	var callback: Callable = original[0].callable if original.size() == 1 else Callable()
	if not _check(timer != null and timer.get_script() == null and menu != null
		and menu.get_class() == parent_class and menu.get_script() == null \
		and (parent_class != "TabBar" or (timer.one_shot and lease._native_ui_internal(timer)))
		and not menu.get_children().has(timer) and menu.get_children(true).has(timer)
		and recorded.ref.get_ref() == timer and recorded.parent == menu.get_instance_id()
		and original.size() == 1 and original == recorded.ui_timeout
		and callback.is_valid() and callback.get_object() == menu
		and callback.get_bound_arguments_count() == 0 and lease.phase == "INSTALLED"
		and property.valid_owner_leased(lab, lease) and property.valid_owner_full_ledger(lab),
		"actual recorded native internal " + parent_class + " Timer has original sole timeout inventory"):
		return {}
	var observer: Callable = func() -> void: pass
	var connected: bool = timer.timeout.connect(observer) == OK
	var before: String = lease.phase
	var changed: bool = timer.timeout.is_connected(observer) \
		and timer.get_signal_connection_list(&"timeout").size() == original.size() + 1
	var rejected: bool = not property.valid_owner_leased(lab, lease)
	_check(connected and changed and before == "INSTALLED" and rejected
		and lease.phase == "REVOKED" and property._field_installation_retired,
		"actual leased owner rejects an added internal Timer observer and permanently retires lease")
	if timer.timeout.is_connected(observer):
		timer.timeout.disconnect(observer)
	var restored: bool = timer.get_signal_connection_list(&"timeout") == original
	var full: bool = property.valid_owner_full_ledger(lab)
	_check(not timer.timeout.is_connected(observer) and restored and full
		and not property.valid_owner_leased(lab, lease) and lease.phase == "REVOKED"
		and property._field_installation_retired and property._owned_field_lease == lease
		and _original_seals(property) == seals,
		"disconnect restores original Timer inventory and full owner without lease revival")
	return {"recorded_native_internal_timer": true, "original_timeout_count": original.size(),
		"phase_before_validation": before, "observer_connected": connected and changed,
		"leased_owner_rejected": rejected, "one_way_retirement": true,
		"observer_disconnected": not timer.timeout.is_connected(observer),
		"original_inventory_restored": restored, "full_owner_restored": full}


func _helper_refusals(lab: PitchBatLab, property: StadiumPoolOwnedProperty) -> Array[Dictionary]:
	var base: Dictionary = StadiumPoolOwnedLayout.base(property.frozen_snapshot.layout)
	var stock: StadiumStock = StadiumLayoutSnapshot.ownership(property.frozen_snapshot)
	var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create("straight")
	var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	var calls: Array[Dictionary] = [
		{"name": "surface_layout", "call": func() -> bool:
			return StadiumSurfaceLayout.apply(property, base, stock)},
		{"name": "wall_items", "call": func() -> bool:
			return StadiumWallItems.apply(property, base, stock)},
		{"name": "infield_styles", "call": func() -> bool:
			return StadiumInfieldStyles.apply(property, base, stock)},
		{"name": "ground_models", "call": func() -> bool:
			return StadiumGroundModels.apply(property, "", base.styles, stock)},
		{"name": "field_style", "call": func() -> bool:
			return StadiumFieldStylePrototype.apply(property, base.styles, stock)},
		{"name": "receiver_configure", "call": func() -> bool:
			return property.receiver.configure(property.receiver.chair, lab._sounds)},
		{"name": "recipe_field_styles", "call": func() -> bool:
			return StadiumRecipeFieldStyles.apply(property, graph, base.styles, "", stock)},
		{"name": "base_marker_models", "call": func() -> bool:
			return StadiumBaseMarkerModels.apply(property, base.bases, stock)},
		{"name": "infield_models", "call": func() -> bool:
			return StadiumInfieldModels.apply(property, "", base.styles, stock)},
		{"name": "owned_build", "call": func() -> bool: return property.build_owned(lab, token)},
		{"name": "property_build", "call": func() -> bool:
			return property.build("backyard", base, stock)},
		{"name": "boundary_assemble", "call": func() -> Node3D:
			return StadiumBoundaryRuntime.assemble(property)}]
	var before: PackedByteArray = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(property))
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var rows: Array[Dictionary] = []
	for entry: Dictionary in calls:
		var operation: Callable = entry["call"]
		var result: Variant = operation.call()
		_check(result == false or result == null, entry.name + ": sealed owned helper refuses")
		var untouched: bool = before == var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(property))
		_check(untouched and property.valid_owner_leased(lab, lease),
			entry.name + ": refusal precedes every scene write and preserves healthy lease")
		rows.append({"helper": entry.name, "refused": result == false or result == null,
			"no_write": untouched, "lease_healthy": lease.phase == "INSTALLED"})
	return rows


func _first_guard(lab: PitchBatLab, leased: bool = true) -> StadiumPoolWaterGuard:
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	var start: int = Engine.get_physics_frames()
	for index: int in range(MAX_GUARD_FRAMES):
		if not _runner._running or _runner._lab != lab:
			_check(false, "genuine first-guard window ended without live installation")
			return null
		if adapter._guard != null and adapter._guard.generation == 1:
			break
		await get_tree().physics_frame
	_guard_wait_frames += Engine.get_physics_frames() - start
	var guard: StadiumPoolWaterGuard = adapter._guard
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var route_valid: bool = guard != null and guard.valid()
	if leased and guard != null:
		route_valid = route_valid and property._owned_field_lease.valid_play(adapter, guard) \
			and guard.valid_owned_lease(property._owned_field_lease) and adapter._owned()
	if not _check(route_valid and guard.generation == 1 and guard._ball == lab._batted_ball
		and guard._ball._started and not lab._automation.releases.is_empty()
		and Engine.get_physics_frames() - start <= MAX_GUARD_FRAMES
		and _guard_wait_frames <= MAX_TOTAL_GUARD_FRAMES,
		_case_name + ": finite genuine first automation guard, no trajectory selection"):
		return null
	return guard


func _static_pair(label: String, lab: PitchBatLab, property: StadiumPoolOwnedProperty,
	change: Callable, restore: Callable) -> Dictionary:
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var seals: PackedByteArray = _original_seals(property)
	change.call()
	var hot: bool = _case_adapter._owned()
	var full: bool = property.valid_owner_full_ledger(lab)
	_check(hot and not full and lease.phase == "INSTALLED",
		label + ": retained unsupported static mutation is leased hot but full boundary rejects")
	restore.call()
	var restored: bool = property.valid_owner_full_ledger(lab) and _case_adapter._owned()
	_check(restored and _original_seals(property) == seals,
		label + ": diagnostic restore preserves old seals without issuing fresh authority")
	return {"mutation": label, "hot_allowed": hot, "full_rejected": not full,
		"restored_without_reseal": restored}


func _static_boundary() -> bool:
	var lab: PitchBatLab = _start_case("static_boundary")
	if lab == null or not _admitted(lab):
		return false
	var guard: StadiumPoolWaterGuard = await _first_guard(lab)
	if guard == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var body: StaticBody3D = property.ground_body
	var shape: CollisionShape3D = _shape(body)
	var rows: Array[Dictionary] = []
	var old_surface: Variant = body.get_meta("ball_surface")
	rows.append(_static_pair("static_metadata", lab, property,
		func() -> void: body.set_meta("ball_surface", &"fixture_unsupported"),
		func() -> void: body.set_meta("ball_surface", old_surface)))
	var old_layer: int = body.collision_layer
	rows.append(_static_pair("static_collision_layer", lab, property,
		func() -> void: body.collision_layer = old_layer ^ 8,
		func() -> void: body.collision_layer = old_layer))
	var box: BoxShape3D = shape.shape as BoxShape3D
	var old_size: Vector3 = box.size
	rows.append(_static_pair("static_shape_geometry", lab, property,
		func() -> void: box.size = old_size + Vector3(0.25, 0, 0),
		func() -> void: box.size = old_size))
	var old_material: PhysicsMaterial = body.physics_material_override
	rows.append(_static_pair("static_physics_material", lab, property,
		func() -> void: body.physics_material_override = PhysicsMaterial.new(),
		func() -> void: body.physics_material_override = old_material))
	var owner: int = body.get_shape_owners()[0]
	var old_transform: Transform3D = body.shape_owner_get_transform(owner)
	rows.append(_static_pair("static_shape_owner_layout", lab, property,
		func() -> void: body.shape_owner_set_transform(owner,
			Transform3D(Basis.IDENTITY, old_transform.origin + Vector3(0.125, 0, 0))),
		func() -> void: body.shape_owner_set_transform(owner, old_transform)))
	for target: FieldDefinition in [property.field, lab._field_definition]:
		var old: float = target.safe_hit_z_m
		rows.append(_static_pair("property_field" if target == property.field else "runtime_field",
			lab, property, func() -> void: target.safe_hit_z_m = old + 0.125,
			func() -> void: target.safe_hit_z_m = old))
	# No supported writer, observer, physics step or full boundary occurs in this interval.
	body.collision_layer = old_layer ^ 8
	body.collision_layer = old_layer
	_check(_case_adapter._owned() and property.valid_owner_full_ledger(lab),
		"unsupported mutate-restore interval is not reconstructable; diagnostic limit, not safe gameplay")
	var sample: Dictionary = guard.sample_owned_lease(
		guard._ball.global_position, guard._ball.radius_m)
	_check(sample.get("valid", false)
		and sample.model_instance == property.pool_model.get_instance_id(),
		"actual authored Guard and Interior leased sampling route remains callable")
	var original: Shape3D = shape.shape
	var equal: Shape3D = original.duplicate(true)
	shape.shape = equal
	_check(equal.get_rid() != original.get_rid() and property.valid_owner_full_ledger(lab)
		and guard.valid_owned_lease(lease),
		"equal static shape geometry passes installation oracle and hot lease but changes launch RID")
	var commits: int = _case_adapter.commits
	var receipts: PackedByteArray = var_to_bytes(guard.receipts)
	_check(not _case_adapter._owned(true) and lease.phase == "REVOKED"
		and not guard.valid() and _case_adapter.commits == commits
		and var_to_bytes(guard.receipts) == receipts,
		"full preaward composite includes independent active Guard RID seal and retires failed lease")
	shape.shape = original
	property.install_owned_field_lease(lab, _case_adapter)
	_check(property.valid_owner_full_ledger(lab) and not _case_adapter._owned()
		and property._owned_field_lease == lease,
		"restoring failed full-boundary shape cannot resurrect or reseal admitted lease")
	return await _finish_case(lab, {"lease_admitted": true, "static_pairs": rows,
		"unsupported_transient_gap_documented": true, "active_guard_rid_boundary": true,
		"no_award_on_failed_boundary": true, "restoration_does_not_resurrect": true})

func _installation_negative(kind: String) -> bool:
	var lab: PitchBatLab = _start_case("install_" + kind)
	if lab == null or not _admitted(lab):
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var seals: PackedByteArray = _original_seals(property)
	var carrier: Node3D = property.pool_model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var change: Callable
	var restore: Callable
	var extra: Node
	match kind:
		"body_pose":
			var original: Vector3 = property.ground_body.position
			change = func() -> void: property.ground_body.position = original + Vector3(0.125, 0, 0)
			restore = func() -> void: property.ground_body.position = original
		"carrier_descriptor":
			var original: Dictionary = carrier.get_meta("descriptor")
			var changed: Dictionary = original.duplicate(true)
			changed.height_m += 0.125
			change = func() -> void: carrier.set_meta("descriptor", changed)
			restore = func() -> void: carrier.set_meta("descriptor", original)
		"carrier_pose":
			var original: Vector3 = carrier.position
			change = func() -> void: carrier.position = original + Vector3(0.125, 0, 0)
			restore = func() -> void: carrier.position = original
		"actor_binding":
			var original: Node3D = lab._pitcher_marker
			var replacement: Node3D = Node3D.new()
			extra = replacement
			change = func() -> void: lab._pitcher_marker = replacement
			restore = func() -> void: lab._pitcher_marker = original
		"process_order":
			var original: int = lab._primary_fielder.process_physics_priority
			change = func() -> void: lab._primary_fielder.process_physics_priority = original + 1
			restore = func() -> void: lab._primary_fielder.process_physics_priority = original
		"fixture_snapshot":
			var original: Dictionary = property.frozen_snapshot
			var changed: Dictionary = original.duplicate(true)
			changed.environment.seed += 1
			change = func() -> void: property.frozen_snapshot = changed
			restore = func() -> void: property.frozen_snapshot = original
		"paid_descriptor":
			var token: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
			var original: String = token._record.copy
			change = func() -> void: token._record.copy = original + "_unsupported"
			restore = func() -> void: token._record.copy = original
		"ledger_generation":
			var original: int = _ledger.mutation_generation()
			change = func() -> void:
				_ledger._initialize_surface_origin(StadiumSurfaceProgression.ROUGH_ORIGIN)
			# Never restore/reconstruct the mutated held ledger or its generation.
			restore = func() -> void: pass
			_check(_ledger.mutation_generation() == original, "held ledger pristine before writer")
		"stale_generation":
			var original: int = lease.generation
			change = func() -> void: lease.generation = original + 1
			restore = func() -> void: lease.generation = original
		_:
			return _check(false, "unknown finite installation mutation")
	change.call()
	var rejected: bool = not property.valid_owner_leased(lab, lease)
	_check(rejected and lease.phase == "REVOKED" and property._field_installation_retired,
		kind + ": retained dynamic or paid check rejects and permanently retires admitted authority")
	restore.call()
	if extra != null:
		extra.free()
	property.install_owned_field_lease(lab, _case_adapter)
	_check(not property.valid_owner_leased(lab, lease)
		and property._owned_field_lease == lease and _original_seals(property) == seals,
		kind + ": same values cannot resurrect or silently fall back/reseal after retirement")
	return await _finish_case(lab, {"lease_admitted": true, "mutation": kind,
		"retained_hot_rejected": rejected, "one_way_retirement": true,
		"original_seals_preserved": true, "held_ledger_restored": false})


func _structural_negative(kind: String) -> bool:
	var lab: PitchBatLab = _start_case("structure_" + kind)
	if lab == null or not _admitted(lab):
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var seals: PackedByteArray = _original_seals(property)
	var branch: Node3D = Node3D.new()
	var incoming: Node3D = Node3D.new()
	var original_parent: Node
	var native_timer_script_null: bool = false
	var reentrant_rows: Array[Dictionary] = []
	var moved_body: Node3D
	var original_index: int = -1
	match kind:
		"nested_property":
			original_parent = property.pool_model.get_node("Collision/POOL_INNER_WALL")
			original_parent.add_child(incoming)
		"nested_external_static":
			lab.add_child(branch)
			branch.add_child(incoming)
			var body: StaticBody3D = StaticBody3D.new()
			incoming.add_child(body)
		"moved_external_static":
			get_tree().root.add_child(branch)
			branch.add_child(incoming)
			var body: StaticBody3D = StaticBody3D.new()
			incoming.add_child(body)
			branch.reparent(lab)
		"runtime_script_attachment":
			lab.add_child(branch)
			branch.add_child(incoming)
			incoming.set_script(ExternalScript)
		"unsupported_native_timer":
			lab.add_child(branch)
			branch.add_child(incoming)
			var timer: Timer = Timer.new()
			native_timer_script_null = timer.get_script() == null
			incoming.add_child(timer)
		"reentrant_enter", "reentrant_reparent":
			lab.add_child(branch)
			incoming.free()
			var probe = EnterProbe.new()
			incoming = probe
			if kind == "reentrant_reparent":
				get_tree().root.add_child(incoming)
			probe.enter_hook = func(node: Node) -> void:
				var before: String = lease.phase
				var children: int = branch.get_child_count(true)
				var allowed: bool = property.valid_owner_leased(lab, lease)
				reentrant_rows.append({"entered_node_matches": node == incoming,
					"phase_before": before, "parent_children": children,
					"validator_allowed": allowed, "phase_after": lease.phase})
			if kind == "reentrant_enter":
				branch.add_child(incoming)
			else:
				incoming.reparent(branch)
		"registered_static_remove", "registered_static_reparent":
			moved_body = property.ground_body
			original_parent = moved_body.get_parent()
			original_index = moved_body.get_index()
			if kind == "registered_static_remove":
				original_parent.remove_child(moved_body)
			else:
				lab.add_child(branch)
				moved_body.reparent(branch)
		_:
			return _check(false, "unknown finite structural mutation")
	var synchronous: bool = lease.phase == "REVOKED"
	var reentrant_expected: Array = [{"entered_node_matches": true,
		"phase_before": "INSTALLED", "parent_children": 1,
		"validator_allowed": false, "phase_after": "REVOKED"}]
	var reentrant_exact: bool = reentrant_rows == reentrant_expected \
		if kind.begins_with("reentrant_") else reentrant_rows.is_empty()
	_check(synchronous and (kind != "unsupported_native_timer" or native_timer_script_null)
		and reentrant_exact and not property.valid_owner_leased(lab, lease),
		kind + ": finite structural or script event retires before subsequent authority check")
	if moved_body != null:
		if moved_body.get_parent() == null:
			original_parent.add_child(moved_body)
		else:
			moved_body.reparent(original_parent)
		original_parent.move_child(moved_body, original_index)
	if incoming.get_parent() != null:
		incoming.get_parent().remove_child(incoming)
	incoming.free()
	if branch.get_parent() != null:
		branch.get_parent().remove_child(branch)
	branch.free()
	_check(not property.valid_owner_leased(lab, lease)
		and property.valid_owner_full_ledger(lab) and _original_seals(property) == seals,
		kind + ": full diagnostic restoration succeeds while old lease remains revoked")
	var report_control: Dictionary = {}
	if kind == "nested_property":
		report_control = _revoked_report_refusal(lab, property)
	return await _finish_case(lab, {"lease_admitted": true, "mutation": kind,
		"synchronous_event_revocation": synchronous, "full_restoration_valid": true,
		"native_timer_script_null": native_timer_script_null,
		"reentrant_rows": reentrant_rows, "reentrant_exact": reentrant_exact,
		"registered_body_restored": moved_body != null,
		"lease_not_restored": true, "report_negative_entry": report_control})


func _revoked_report_refusal(lab: PitchBatLab, property: StadiumPoolOwnedProperty) -> Dictionary:
	# Negative-entry control only. This disposable phase assignment is not a played result.
	var original_phase: MatchState.Phase = lab._match_state.phase
	lab._match_state.phase = MatchState.Phase.GAME_END
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	var early: bool = lab.is_inside_tree() and lab._automation != null \
		and property.valid_owner_full_ledger(lab) and adapter != null \
		and adapter._bound_profile == property and adapter.enabled and adapter.freeflight_enabled \
		and not adapter.is_committing() \
		and StadiumPoolOwnedSnapshot.matches(lab._match_state.stadium, lab._stadium_ledger) \
		and StadiumBoundaryRuntime.installed(lab, lab._match_state.stadium)
	_check(early and property._owned_field_lease.phase == "REVOKED",
		"negative-only report entry reaches installed lease-health boundary with full paid owner valid")
	var result: Dictionary = StadiumPoolOwnedReport.capture(lab)
	lab._match_state.phase = original_phase
	_check(early and result.is_empty() and lab._play_records.is_empty()
		and _reports == 0 and _unchanged(),
		"revoked-restored report capture refuses; no played terminal or accepted report is manufactured")
	return {"synthetic_phase_gate_only": true, "all_other_early_gates": early,
		"capture_empty": result.is_empty(), "genuine_terminal": false, "settlement_claimed": false}


func _lifecycle_negative(kind: String) -> bool:
	var lab: PitchBatLab = _start_case("lifecycle_" + kind)
	if lab == null or not _admitted(lab):
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var busy_retained: bool = false
	match kind:
		"rollback":
			StadiumPoolOwnedExtension._rollback(lab, property._host, property)
		"rematch":
			lab._start_new_match()
		"busy_revoke":
			# Explicit busy-state control: not claimed as a naturally invoked callback.
			_case_adapter._busy = true
			StadiumPoolOwnedExtension._revoke(lab, property)
			busy_retained = _case_adapter._lab == lab and _case_adapter._busy
			_case_adapter._busy = false
		_:
			return _check(false, "unknown finite lifecycle mutation")
	_check(lease.phase == "REVOKED" and lease.generation > 1,
		kind + ": lifecycle entry retires installation synchronously before cleanup writes")
	_check((kind != "busy_revoke" or busy_retained)
		and not lease.valid_installation(_case_property.get_ref() as StadiumPoolOwnedProperty, lab),
		kind + ": refused busy detach cannot preserve authority and old owner never revalidates")
	return await _finish_case(lab, {"lease_admitted": true, "seam": kind,
		"synchronous_revocation": true, "busy_state_control": kind == "busy_revoke",
		"busy_detach_refused": busy_retained, "natural_callback_claimed": false})


func _extra_signal(_position: Vector3) -> void:
	pass


func _play_negative(kind: String) -> bool:
	var lab: PitchBatLab = _start_case("play_" + kind)
	if lab == null or not _admitted(lab):
		return false
	var guard: StadiumPoolWaterGuard = await _first_guard(lab)
	if guard == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var change: Callable
	var restore: Callable
	var entry: Dictionary = guard._bodies[property.ground_body.get_instance_id()]
	match kind:
		"ball_parameters":
			var old: float = guard._ball.radius_m
			change = func() -> void: guard._ball.radius_m = old + 0.125
			restore = func() -> void: guard._ball.radius_m = old
		"ordinary_router":
			var old: Callable = guard._ordinary_router
			change = func() -> void: guard._ordinary_router = Callable()
			restore = func() -> void: guard._ordinary_router = old
		"signal_inventory":
			change = func() -> void: guard._ball.launch_started.connect(_extra_signal)
			restore = func() -> void: guard._ball.launch_started.disconnect(_extra_signal)
		"body_identity":
			var old: StaticBody3D = entry.body
			change = func() -> void: entry.body = property.boundary.get_child(0)
			restore = func() -> void: entry.body = old
		"body_parent":
			var old: Node = entry.parent
			change = func() -> void: entry.parent = property.pool_model
			restore = func() -> void: entry.parent = old
		"body_rid":
			var old: RID = entry.rid
			change = func() -> void: entry.rid = RID()
			restore = func() -> void: entry.rid = old
		_:
			return _check(false, "unknown finite live-play mutation")
	var commits: int = _case_adapter.commits
	var receipts: PackedByteArray = var_to_bytes(guard.receipts)
	change.call()
	var rejected: bool = not _case_adapter._owned()
	_check(rejected and lease.phase == "REVOKED" and _case_adapter.commits == commits
		and var_to_bytes(guard.receipts) == receipts,
		kind + ": actual controller leased route retains dynamic rejection without an award")
	restore.call()
	_check(not _case_adapter._owned() and not lease.valid_play(_case_adapter, guard),
		kind + ": restoration cannot rebind or silently resurrect failed admitted play")
	return await _finish_case(lab, {"lease_admitted": true, "mutation": kind,
		"genuine_first_guard": true, "retained_hot_rejected": rejected,
		"guard_registry_diagnostic": kind.begins_with("body_"),
		"no_award": true, "restoration_does_not_resurrect": true})


func _launch_retirement() -> bool:
	var lab: PitchBatLab = _start_case("launch_retirement")
	if lab == null or not _admitted(lab):
		return false
	var guard: StadiumPoolWaterGuard = await _first_guard(lab)
	if guard == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var lease: StadiumPoolOwnedFieldLease = property._owned_field_lease
	var installation: int = lease.generation
	var play: int = lease.play_generation
	var seals: PackedByteArray = _original_seals(property)
	var start: int = Engine.get_physics_frames()
	for index: int in range(MAX_GUARD_FRAMES):
		if not _runner._running or _runner._lab != lab:
			break
		if _case_adapter.generation == 2 and _case_adapter._guard != null:
			break
		await get_tree().physics_frame
	_guard_wait_frames += Engine.get_physics_frames() - start
	var next_guard: StadiumPoolWaterGuard = _case_adapter._guard
	_check(next_guard != null and next_guard != guard and _case_adapter.generation == 2
		and not guard._bound and guard._samples > 0
		and guard._samples <= MAX_TOTAL_GUARD_FRAMES and lease.phase == "INSTALLED"
		and lease.generation == installation and property._owned_field_lease == lease
		and lease.valid_play(_case_adapter, next_guard) and _case_adapter._owned()
		and Engine.get_physics_frames() - start <= MAX_GUARD_FRAMES
		and _guard_wait_frames <= MAX_TOTAL_GUARD_FRAMES,
		"ordinary cleanup and next genuine launch preserve installation and bind a fresh play")
	_check(not guard.valid() and lease.phase == "INSTALLED"
		and lease.play_generation == 2 and _original_seals(property) == seals,
		"detached original Guard stays invalid while next launch uses unchanged static installation")
	# Both original live-play checks finish before this independent retirement control.
	var tabbar_control: Dictionary = _internal_timer_inventory_negative(lab, property, "TabBar")
	if tabbar_control.is_empty():
		return false
	return await _finish_case(lab, {"lease_admitted": true, "genuine_first_guard": true,
		"genuine_second_guard": true, "actual_first_guard_samples": guard._samples,
		"installation_generation_preserved": true,
		"retired_play_generation": play, "old_guard_rejected": true,
		"static_reconstruction": false, "internal_tabbar_timer": tabbar_control})


func _custom_fallback() -> bool:
	# A custom fixture ancestor is intentionally outside the exact production domain.
	get_tree().root.remove_child(_runner)
	add_child(_runner)
	var lab: PitchBatLab = _start_case("custom_fallback")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	_check(property._owned_field_lease == null and property.valid_owner_full_ledger(lab),
		"custom ancestor uses original full route before lease admission")
	var guard: StadiumPoolWaterGuard = await _first_guard(lab, false)
	if guard == null:
		return false
	var body: StaticBody3D = property.ground_body
	var original: int = body.collision_layer
	body.collision_layer = original ^ 8
	_check(not _case_adapter._owned() and property._owned_field_lease == null,
		"custom full route still immediately rejects retained static collision mutation")
	body.collision_layer = original
	_check(property.valid_owner_full_ledger(lab) and property._owned_field_lease == null,
		"legacy full diagnostic restoration never silently admits custom callback ancestry")
	var result: bool = await _finish_case(lab, {"lease_admitted": false,
		"custom_ancestor_full_fallback": true, "genuine_first_guard": true,
		"retained_static_immediate_rejection": true, "legacy_full_oracle_preserved": true})
	remove_child(_runner)
	get_tree().root.add_child(_runner)
	return result
