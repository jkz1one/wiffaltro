extends Node
## V77 finite same-call guard body coverage; exact standalone paid setup projection.
## Genuine paid setup, fixed existing fixture/seed, no trajectory or outcome claim.
# gdlint: disable=max-file-lines,max-returns,function-arguments-number

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const MATCH_SEED: int = 314229
const SUMMARY_LIMIT: int = 262144
const EXPECTED_INSTALLATIONS: int = 1
const EXPECTED_NATIVE_CHECKS: int = 148
const EXPECTED_OBSERVATIONS: int = 43
const OBSERVATION_CAP: int = 128
const FAILURE_LABEL_CAP: int = 384
const FAILURE_LABEL_BYTES: int = 256
const OBSERVATION_ROW_BYTES: int = 1536
const NATIVE_VALUE_BYTES: int = 256
const MAX_GUARD_FRAMES: int = 1800
const MAX_CALLBACK_FRAMES: int = 2
const CASE_EXPECTED_CHECKS: Dictionary = {"guard_coverage": 99}

const BODY_CAP: int = 22
const EXTRA_PROBES: int = 34

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
var _all_preserved: bool = false
var _observations: Array[Dictionary] = []
var _observations_complete: bool = true

var _callback_seen: bool = false
var _callback_frame: int = -1
var _callback_before: PackedByteArray
var _callback_after: PackedByteArray


var _probes: Array[Dictionary] = []
var _probe_cursor: int = 0
var _active_context: StadiumPoolInteriorV2
var _active_plan: Dictionary

class HookAuthority extends StadiumPoolOwnedAuthority:
	var original: StadiumPoolOwnedAuthority
	var hook: Callable
	var calls: int = 0

	func descriptor() -> Dictionary:
		calls += 1
		if hook.is_valid():
			hook.call()
		return original.descriptor()

	func owns(lab: PitchBatLab, snapshot: Dictionary, property: Node) -> bool:
		return original.owns(lab, snapshot, property)


class ForwardingHelper extends StadiumPoolOwnedIntegrity:
	var original: StadiumPoolOwnedIntegrity
	var calls: Array[String] = []

	func valid_boundary(boundary: Node3D) -> bool:
		calls.append("boundary")
		return original.valid_boundary(boundary)

	func valid_ground(ground: StaticBody3D) -> bool:
		calls.append("ground")
		return original.valid_ground(ground)

	func valid_inventory(lab: Node3D) -> bool:
		calls.append("inventory")
		return original.valid_inventory(lab)

	func valid_model(model: Node3D) -> bool:
		calls.append("model")
		return original.valid_model(model)

	func valid_body(body: StaticBody3D) -> bool:
		calls.append("body")
		return original.valid_body(body)


class InteriorDispatchProbe extends StadiumPoolInteriorV2:
	var original: StadiumPoolInteriorV2
	var calls: int = 0

	func valid(model: Node3D, source: String) -> bool:
		calls += 1
		return original.valid(model, source)

	func owned_integrity_policy() -> StadiumPoolOwnedIntegrity:
		return original.owned_integrity_policy()


class GuardDispatchProbe extends StadiumPoolWaterGuard:
	var body_calls: int = 0

	func _body_snapshot_valid(body: StaticBody3D, original: PackedByteArray) -> bool:
		body_calls += 1
		return super._body_snapshot_valid(body, original)


class BodyScript extends StaticBody3D:
	var mutation_probe: bool = true


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

func _ready() -> void:
	_wall_start = Time.get_ticks_usec()
	var original_save_path: String = SeasonSave.path
	var original_settings_path: String = PitchBatLabSettings.path
	var original_last_error: String = SeasonSave.last_error
	var original_files: Dictionary = _saved()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-guard-body-v77-dir="):
			_output = argument.trim_prefix("--pool-guard-body-v77-dir=")
		if argument.begins_with("--pool-guard-body-v77-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-guard-body-v77-runtime=")
		if argument.begins_with("--pool-guard-body-v77-execution="):
			_execution = argument.trim_prefix("--pool-guard-body-v77-execution=")
		if argument.begins_with("--pool-guard-body-v77-nonce="):
			_nonce = argument.trim_prefix("--pool-guard-body-v77-nonce=")
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
		"reused_regressions": {"integrity": 569, "ledger": 190, "contact": 68,
			"field": 334, "scene": 227, "model": 187},
		"guard_observations": _observations, "observations_complete": _observations_complete,
		"expected_observations": EXPECTED_OBSERVATIONS,
		"source_text_policy": "RESTORE_TEXT_WITHOUT_RELOADING_LIVE_SCRIPTS",
		"compiled_reload_history_qualified": false,
		"caps": {"observations": OBSERVATION_CAP, "row_bytes": OBSERVATION_ROW_BYTES,
			"native_value_bytes": NATIVE_VALUE_BYTES, "summary_bytes": SUMMARY_LIMIT,
			"failure_labels": FAILURE_LABEL_CAP, "failure_label_bytes": FAILURE_LABEL_BYTES},
		"qualification": "finite same-call guard body coverage and original fallback controls only",
		"production_qualified": false, "report_settlement_qualified": false,
		"performance_qualified": false, "rendered_qualified": false}
	if _output_admitted:
		var encoded: String = JSON.stringify(summary, "", true, true)
		if encoded.to_utf8_buffer().size() <= SUMMARY_LIMIT:
			var output: FileAccess = FileAccess.open(
				_output.path_join("pool-guard-body-v77-summary.json"), FileAccess.WRITE)
			if output != null:
				output.store_string(encoded)
				if output.get_error() != OK:
					_check(false, "summary output write failed")
				output.close()
			else:
				_check(false, "summary output could not open")
		else:
			_check(false, "summary exceeds fixed byte cap")
	print("POOL_GUARD_BODY_V77 checks=%d failures=%d starts=%d cleanups=%d source=%s" % [
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
	for method: StringName in [&"_guard_coverage"]:
		if not await call(method):
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

func _request(guard: StadiumPoolWaterGuard) -> Dictionary:
	return StadiumPoolOwnedIntegrity.guard_body_request(guard._guard_body_plan, guard)


func _capture_probes(lab: PitchBatLab, property: StadiumPoolOwnedProperty,
	guard: StadiumPoolWaterGuard) -> bool:
	_active_context = guard._context
	_active_plan = guard._guard_body_plan
	var captured: bool = guard._bodies.size() == BODY_CAP
	captured = captured and property.boundary.get_child_count() == 6 \
		and property.receiver.chair.get_node("Collision").get_child_count() == 10 \
		and property.pool_model.get_node("Collision").get_child_count() == 5
	if not captured:
		return _check(false, "finite complete registry must fit probe bound before any mutation")
	for index: int in range(guard._bodies.size() + EXTRA_PROBES):
		var context: StadiumPoolInteriorV2 = StadiumPoolInteriorV2.capture_owned(
			property.pool_model, _runtime, property, lab)
		if context == null:
			captured = false
			break
		guard._context = context
		var plan: Dictionary = StadiumPoolOwnedIntegrity.capture_guard_body_plan(guard, context)
		guard._guard_body_plan = plan
		var request: Dictionary = _request(guard)
		captured = captured and not plan.is_empty() and not request.is_empty() \
			and not request.get("source_breach", false) and not context._invalidated
		_probes.append({"context": context, "plan": plan})
	guard._context = _active_context
	guard._guard_body_plan = _active_plan
	return _check(captured and _probes.size() == guard._bodies.size() + EXTRA_PROBES
		and guard.valid(), "all exact independent probe contexts captured pristine before mutations")


func _activate_probe(guard: StadiumPoolWaterGuard) -> bool:
	if _probe_cursor >= _probes.size():
		return false
	var probe: Dictionary = _probes[_probe_cursor]
	_probe_cursor += 1
	guard._context = probe.context
	guard._guard_body_plan = probe.plan
	return not guard._context._invalidated


func _restore_active(guard: StadiumPoolWaterGuard) -> void:
	guard._context = _active_context
	guard._guard_body_plan = _active_plan


func _probe(guard: StadiumPoolWaterGuard, change: Callable, restore: Callable,
	poison_expected: bool = true) -> Dictionary:
	var selected: bool = _activate_probe(guard)
	var request: Dictionary = _request(guard)
	var admitted: bool = selected and not request.is_empty() \
		and not request.get("source_breach", false)
	change.call()
	var accepted: bool = guard.valid()
	var poisoned: bool = guard._context._invalidated
	restore.call()
	_restore_active(guard)
	var restored: bool = guard.valid() and not guard._context._invalidated
	return {"admitted_before_mutation": admitted, "rejected": not accepted,
		"context_poisoned": poisoned, "poison_expected": poison_expected,
		"restored": restored, "actual_guard_called": true}


func _record_probe(label: String, guard: StadiumPoolWaterGuard,
	change: Callable, restore: Callable, poison_expected: bool = true) -> void:
	var result: Dictionary = _probe(guard, change, restore, poison_expected)
	_check(result.admitted_before_mutation and result.rejected
		and result.context_poisoned == poison_expected,
		label + ": retained mutation rejects at original latch boundary")
	_check(result.restored, label + ": original active context restores without resealing")
	result.merge({"kind": "mutation", "label": label})
	_observe(result)


func _fresh_coverage(property: StadiumPoolOwnedProperty, guard: StadiumPoolWaterGuard) -> void:
	var request: Dictionary = _request(guard)
	var accepted: bool = not request.is_empty() \
		and guard._context.valid_guard_body(guard._model, guard._source, request)
	_check(accepted and request.get("observed", false) and request.get("complete", false)
		and request.policy == property.integrity_policy2
		and request.bodies.size() == guard._bodies.size(),
		"actual complete Interior path issues fresh same-call whole-registry coverage")
	var all_bodies: bool = true
	for id: int in guard._bodies:
		all_bodies = all_bodies and request.bodies.get(id) == guard._bodies[id].body
	_check(all_bodies and guard.valid() and guard.valid(),
		"receipt binds exact current body references and independent later calls remain fresh")
	_observe({"kind": "coverage", "observed": request.get("observed", false),
		"complete": request.get("complete", false), "all_registry_bodies": all_bodies,
		"body_count": guard._bodies.size(), "fresh_guard_calls": 2,
		"probe_contexts": _probes.size(), "captures_before_mutations": true})


func _guard_seals(property: StadiumPoolOwnedProperty, guard: StadiumPoolWaterGuard) -> void:
	var body: StaticBody3D = property.ground_body
	var entry: Dictionary = guard._bodies[body.get_instance_id()]
	for key: String in ["parent", "rid", "pose", "owner_bytes"]:
		var original: Variant = entry[key]
		var changed: Variant
		match key:
			"parent": changed = property.pool_model
			"rid": changed = RID()
			"pose": changed = Transform3D(Basis.IDENTITY, Vector3(100, 0, 0))
			"owner_bytes": changed = PackedByteArray([1])
		_record_probe("guard " + key, guard,
			func() -> void: entry[key] = changed, func() -> void: entry[key] = original, false)
	var shape: CollisionShape3D = _shape(body)
	var original_shape: Shape3D = shape.shape
	var equal_shape: Shape3D = original_shape.duplicate(true)
	shape.shape = equal_shape
	var policy_allowed: bool = property.integrity_policy2.valid_body(body)
	shape.shape = original_shape
	_check(policy_allowed and equal_shape.get_rid() != original_shape.get_rid(),
		"equal geometry preserves policy body seal but has distinct shape-resource RID")
	_record_probe("equal geometry new RID", guard,
		func() -> void: shape.shape = equal_shape,
		func() -> void: shape.shape = original_shape, false)


func _all_body_metadata(guard: StadiumPoolWaterGuard) -> void:
	var rejected: int = 0
	var restored: int = 0
	var failed_ids: Array[int] = []
	for id: int in guard._bodies:
		var body: StaticBody3D = guard._bodies[id].body
		var present: bool = body.has_meta("surface_role")
		var original: Variant = body.get_meta("surface_role") if present else null
		var result: Dictionary = _probe(guard,
			func() -> void: body.set_meta("surface_role", "V77_ALL_BODY_MUTATION"),
			func() -> void:
				if present:
					body.set_meta("surface_role", original)
				else:
					body.remove_meta("surface_role"))
		if result.admitted_before_mutation and result.rejected and result.context_poisoned:
			rejected += 1
		else:
			failed_ids.append(id)
		if result.restored:
			restored += 1
	_check(rejected == guard._bodies.size() and failed_ids.is_empty(),
		"every currently registered body is freshly rejected after retained metadata mutation")
	_check(restored == guard._bodies.size(),
		"every body restores against original policy and active context")
	_observe({"kind": "all_body_metadata", "body_count": guard._bodies.size(),
		"rejected": rejected, "restored": restored, "failed_ids": failed_ids,
		"registry_cap": BODY_CAP})


func _body_policy(property: StadiumPoolOwnedProperty, guard: StadiumPoolWaterGuard) -> void:
	var body: StaticBody3D = property.ground_body
	for key: String in ["collision_layer", "collision_mask", "collision_priority", "disable_mode",
		"constant_linear_velocity", "constant_angular_velocity"]:
		var old: Variant = body.get(key)
		var changed: Variant = old
		match key:
			"collision_layer", "collision_mask": changed = int(old) ^ 4
			"collision_priority": changed = float(old) + 0.25
			"disable_mode": changed = (int(old) + 1) % 3
			"constant_linear_velocity", "constant_angular_velocity":
				changed = old + Vector3(0.125, 0, 0)
		_record_probe(key, guard,
			func() -> void: body.set(key, changed), func() -> void: body.set(key, old))
	var material: PhysicsMaterial = body.physics_material_override
	var replacement: PhysicsMaterial = PhysicsMaterial.new()
	replacement.friction = 0.625
	replacement.bounce = 0.375
	_record_probe("material", guard,
		func() -> void: body.physics_material_override = replacement,
		func() -> void: body.physics_material_override = material)
	var other: StaticBody3D = property.pool_model.get_node("Collision/POOL_INNER_WALL")
	_record_probe("collision exception", guard,
		func() -> void: body.add_collision_exception_with(other),
		func() -> void: body.remove_collision_exception_with(other))
	var local_pose: Transform3D = body.transform
	_record_probe("body transform", guard,
		func() -> void: body.position.x += 0.125,
		func() -> void: body.transform = local_pose)
	_record_probe("body script", guard,
		func() -> void: body.set_script(BodyScript), func() -> void: body.set_script(null))
	var mode: int = body.process_mode
	_record_probe("body process mode", guard,
		func() -> void: body.process_mode = Node.PROCESS_MODE_DISABLED,
		func() -> void: body.process_mode = mode)
	var shape: CollisionShape3D = _shape(body)
	var child_index: int = shape.get_index()
	_record_probe("ordered child topology", guard,
		func() -> void: body.move_child(shape, body.get_child_count() - 1),
		func() -> void: body.move_child(shape, child_index))
	var shape_pose: Transform3D = shape.transform
	_record_probe("shape transform", guard,
		func() -> void: shape.position.x += 0.125,
		func() -> void: shape.transform = shape_pose)
	var disabled: bool = shape.disabled
	_record_probe("shape disabled", guard,
		func() -> void: shape.disabled = not disabled, func() -> void: shape.disabled = disabled)
	var original_shape: Shape3D = shape.shape
	_record_probe("unsupported native geometry", guard,
		func() -> void: shape.shape = SphereShape3D.new(),
		func() -> void: shape.shape = original_shape)
	var box: BoxShape3D = original_shape as BoxShape3D
	var size: Vector3 = box.size
	_record_probe("box geometry size", guard,
		func() -> void: box.size = size + Vector3(0.125, 0, 0),
		func() -> void: box.size = size)
	var margin: float = original_shape.margin
	_record_probe("shape geometry margin", guard,
		func() -> void: original_shape.margin = margin + 0.01,
		func() -> void: original_shape.margin = margin)
	var owner: int = body.get_shape_owners()[0]
	var owner_pose: Transform3D = body.shape_owner_get_transform(owner)
	_record_probe("shape owner pose", guard,
		func() -> void: body.shape_owner_set_transform(owner,
			Transform3D(Basis.IDENTITY, Vector3(0.125, 0, 0))),
		func() -> void: body.shape_owner_set_transform(owner, owner_pose))
	var owner_disabled: bool = body.is_shape_owner_disabled(owner)
	_record_probe("shape owner disabled", guard,
		func() -> void: body.shape_owner_set_disabled(owner, not owner_disabled),
		func() -> void: body.shape_owner_set_disabled(owner, owner_disabled))
	var detached: BoxShape3D = BoxShape3D.new()
	_record_probe("owner child attachment", guard,
		func() -> void:
			body.shape_owner_clear_shapes(owner)
			body.shape_owner_add_shape(owner, detached),
		func() -> void:
			body.shape_owner_clear_shapes(owner)
			body.shape_owner_add_shape(owner, original_shape))
	var extra: Array[int] = [-1]
	_record_probe("shape owner count", guard,
		func() -> void:
			extra[0] = body.create_shape_owner(body)
			body.shape_owner_add_shape(extra[0], BoxShape3D.new()),
		func() -> void: body.remove_shape_owner(extra[0]))
	var extra_body: StaticBody3D = StaticBody3D.new()
	var lab: Node = guard._context._owned_lab.get_ref()
	_record_probe("whole lab new body", guard,
		func() -> void: lab.add_child(extra_body), func() -> void: lab.remove_child(extra_body))
	extra_body.free()
	var parent: Node = body.get_parent()
	var sibling: int = body.get_index()
	_record_probe("body removed", guard,
		func() -> void: parent.remove_child(body),
		func() -> void:
			parent.add_child(body)
			parent.move_child(body, sibling))
	var helper: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var id: int = body.get_instance_id()
	var sealed: PackedByteArray = helper._body_bytes[id]
	_record_probe("policy current body seal", guard,
		func() -> void: helper._body_bytes[id] = PackedByteArray([1]),
		func() -> void: helper._body_bytes[id] = sealed)
	var role: PackedInt32Array = helper._owner_scene_bodies[id]
	_record_probe("policy body coverage identity", guard,
		func() -> void: helper._owner_scene_bodies[id] = PackedInt32Array(),
		func() -> void: helper._owner_scene_bodies[id] = role)


func _tail_and_reuse(property: StadiumPoolOwnedProperty, guard: StadiumPoolWaterGuard) -> void:
	_activate_probe(guard)
	var request: Dictionary = _request(guard)
	var carrier: WeakRef = guard._context._carrier
	guard._context._carrier = weakref(property.ground_body)
	var accepted: bool = guard._context.valid_guard_body(guard._model, guard._source, request)
	guard._context._carrier = carrier
	_check(not accepted and request.observed and not request.complete
		and guard._context._invalidated,
		"successful combined observation cannot mint receipt before Interior carrier tail succeeds")
	_observe({"kind": "interior_tail", "observed": request.observed,
		"complete": request.complete, "rejected": not accepted,
		"context_poisoned": guard._context._invalidated})
	_restore_active(guard)
	_activate_probe(guard)
	request = _request(guard)
	var lab: PitchBatLab = guard._context._owned_lab.get_ref()
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	lab._primary_fielder.stadium_boundary_clip = Callable()
	accepted = guard._context.valid_guard_body(guard._model, guard._source, request)
	lab._primary_fielder.stadium_boundary_clip = clip
	_check(not accepted and request.observed and not request.complete
		and guard._context._invalidated,
		"successful scene observation cannot mint receipt before original owner router tail")
	_observe({"kind": "owner_tail", "observed": request.observed,
		"complete": request.complete, "rejected": not accepted,
		"context_poisoned": guard._context._invalidated})
	_restore_active(guard)
	_activate_probe(guard)
	request = _request(guard)
	var first: bool = guard._context.valid_guard_body(guard._model, guard._source, request)
	var first_complete: bool = request.get("complete", false)
	var body: StaticBody3D = property.ground_body
	var old: Vector3 = body.constant_linear_velocity
	body.constant_linear_velocity = old + Vector3(0.125, 0, 0)
	accepted = guard._context.valid_guard_body(guard._model, guard._source, request)
	body.constant_linear_velocity = old
	_check(first and first_complete and not accepted and not request.observed
		and not request.complete and guard._context._invalidated,
		"retained prior receipt is cleared and a fresh independent invocation rejects mutation")
	_observe({"kind": "receipt_reuse", "first_complete": first_complete,
		"second_rejected": not accepted, "observed": request.observed,
		"complete": request.complete, "context_poisoned": guard._context._invalidated})
	_restore_active(guard)
	_check(guard.valid() and not guard._context._invalidated,
		"pristine original context survives independent poisoned probe disposal")


func _coverage_miss(property: StadiumPoolOwnedProperty, guard: StadiumPoolWaterGuard) -> void:
	var request: Dictionary = _request(guard)
	var body: StaticBody3D = property.ground_body
	request.bodies[body.get_instance_id()] = property.pool_model.get_node("Collision/POOL_INNER_WALL")
	var lab: PitchBatLab = guard._context._owned_lab.get_ref()
	var owner_model: bool = StadiumPoolOwnedIntegrity.owner_scene_matches(
		property.integrity_policy2, lab, property, property.boundary, body,
		property._boundary_ids, property._ground_ids, true, property.pool_model,
		guard._context._identities, request)
	_check(owner_model and not request.observed and not request.complete,
		"direct collector guard-only identity miss preserves complete original owner/model result")
	var interior: bool = guard._context.valid_guard_body(guard._model, guard._source, request)
	_check(interior and not request.observed and not request.complete
		and not guard._context._invalidated and guard.valid(),
		"withdrawn coverage preserves Interior validity; later fresh guard validation succeeds")
	_observe({"kind": "coverage_miss", "owner_model_valid": owner_model,
		"interior_valid": interior, "observed": request.observed, "complete": request.complete,
		"context_poisoned": guard._context._invalidated, "direct_collector_control": true})


func _domain_fallback(property: StadiumPoolOwnedProperty, guard: StadiumPoolWaterGuard) -> void:
	var body: StaticBody3D = property.ground_body
	var id: int = body.get_instance_id()
	var entry: Dictionary = guard._bodies[id]
	var malformed: Array = [null, 7, {}, {"body": body}, entry.duplicate()]
	malformed[4].body = property.pool_model
	var all_fallback: bool = true
	for value: Variant in malformed:
		guard._bodies[id] = value
		all_fallback = all_fallback and _request(guard).is_empty()
	guard._bodies[id] = entry
	_check(all_fallback and guard.valid() and not guard._context._invalidated,
		"malformed registry shapes withdraw coverage before any reduced-path consumption")
	_observe({"kind": "malformed_domain", "variants": malformed.size(),
		"all_fallback": all_fallback, "live_malformed_validation_invoked": false,
		"restored": true})
	var unknown: StaticBody3D = StaticBody3D.new()
	var unknown_id: int = unknown.get_instance_id()
	var unknown_entry: Dictionary = entry.duplicate()
	unknown_entry.body = unknown
	unknown_entry.rid = unknown.get_rid()
	guard._bodies[unknown_id] = unknown_entry
	var fallback: bool = _request(guard).is_empty()
	var accepted: bool = guard.valid()
	guard._bodies.erase(unknown_id)
	unknown.free()
	_check(fallback and not accepted and not guard._context._invalidated and guard.valid(),
		"unknown off-tree body uses full registry rejection without new Interior latch")
	guard._bodies[-1] = entry
	fallback = _request(guard).is_empty()
	accepted = guard.valid()
	guard._bodies.erase(-1)
	_check(fallback and accepted and guard.valid(),
		"unsupported alias key keeps original value-based full-registry semantics")
	var probe: Dictionary = _probes[_probe_cursor]
	_probe_cursor += 1
	guard._context = probe.context
	fallback = _request(guard).is_empty()
	accepted = guard.valid()
	_restore_active(guard)
	_check(fallback and accepted and not probe.context._invalidated,
		"replacement exact Interior does not inherit prior guard plan coverage")
	var custom_context: InteriorDispatchProbe = InteriorDispatchProbe.new()
	custom_context.original = _active_context
	guard._context = custom_context
	fallback = _request(guard).is_empty()
	accepted = guard.valid()
	_restore_active(guard)
	_check(fallback and accepted and custom_context.calls == 1,
		"custom Interior retains original virtual validity dispatch")
	var custom_guard: GuardDispatchProbe = GuardDispatchProbe.new()
	custom_guard._context = _active_context
	_check(StadiumPoolOwnedIntegrity.capture_guard_body_plan(custom_guard, _active_context).is_empty()
		and custom_guard._body_snapshot_valid(body, entry.bytes) and custom_guard.body_calls == 1,
		"custom WaterGuard is ineligible and retains virtual body-snapshot dispatch")
	var original: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var helper: ForwardingHelper = ForwardingHelper.new()
	helper.original = original
	property.integrity_policy2 = helper
	fallback = _request(guard).is_empty()
	accepted = guard.valid()
	property.integrity_policy2 = original
	var expected: Array[String] = ["boundary", "ground", "inventory", "model"]
	for index: int in range(guard._bodies.size()):
		expected.append("body")
	_check(fallback and accepted and helper.calls == expected and guard.valid(),
		"custom policy retains full original boundary ground inventory model and body dispatch")
	var legacy: PackedByteArray = entry.bytes
	var legacy_allowed: bool = custom_guard._body_snapshot_valid(body, legacy)
	custom_guard._context = null
	var legacy_snapshot: bool = custom_guard._body_snapshot_valid(body, legacy)
	_check(legacy_allowed and legacy_snapshot,
		"unowned private snapshot route remains callable without guard coverage plan")
	_observe({"kind": "fallback", "unknown_offtree_rejected": true,
		"alias_value_semantics_preserved": true, "replacement_context_fallback": true,
		"custom_interior_calls": custom_context.calls, "custom_guard_ineligible": true,
		"custom_policy_calls": helper.calls.size(), "body_calls": guard._bodies.size(),
		"legacy_snapshot_valid": legacy_snapshot})


func _guard_source_records(guard: StadiumPoolWaterGuard) -> void:
	var plan: Dictionary = guard._guard_body_plan
	var original_base: Variant = plan.base
	plan.base = StadiumPoolOwnedIntegrity
	var base_request: Dictionary = _request(guard)
	var base_accepted: bool = guard.valid()
	plan.base = original_base
	_check(base_request.get("source_breach", false) and not base_accepted
		and not guard._context._invalidated and guard.valid(),
		"independent guard base-script closure rejects without adding Interior latch")
	var original_script: GDScript = plan.script
	plan.script = StadiumPoolOwnedIntegrity
	var identity_request: Dictionary = _request(guard)
	var identity_accepted: bool = guard.valid()
	plan.script = original_script
	_check(identity_request.get("source_breach", false) and not identity_accepted
		and not guard._context._invalidated and guard.valid(),
		"independent guard script identity closure rejects without resealing")
	_observe({"kind": "guard_source_records", "base_rejected": not base_accepted,
		"identity_rejected": not identity_accepted, "context_poisoned": false,
		"restored": true, "reload_performed": false})


func _early_hooks(property: StadiumPoolOwnedProperty, guard: StadiumPoolWaterGuard) -> void:
	var original: StadiumPoolOwnedAuthority = property.entitlement as StadiumPoolOwnedAuthority
	var hook: HookAuthority = HookAuthority.new()
	hook.original = original
	property.entitlement = hook
	var request: Dictionary = _request(guard)
	var accepted: bool = guard._context.valid_guard_body(guard._model, guard._source, request)
	_check(accepted and request.observed and request.complete and hook.calls > 0,
		"forwarding authority hook remains genuinely admitted before mutation seam")
	var body: StaticBody3D = property.ground_body
	var entry: Dictionary = guard._bodies[body.get_instance_id()]
	hook.hook = func() -> void: guard._bodies[-1] = entry
	request = _request(guard)
	var selected: bool = not request.is_empty()
	accepted = guard._context.valid_guard_body(guard._model, guard._source, request)
	guard._bodies.erase(-1)
	hook.hook = Callable()
	_check(selected and accepted and not request.observed and not request.complete
		and not guard._context._invalidated,
		"early registry mutation withdraws receipt while V74 Interior completion remains valid")
	_observe({"kind": "early_registry", "selected_before_hook": selected,
		"context_valid": accepted, "observed": request.observed, "complete": request.complete,
		"context_poisoned": guard._context._invalidated})
	var helper: ForwardingHelper = ForwardingHelper.new()
	helper.original = property.integrity_policy2
	hook.hook = func() -> void: property.integrity_policy2 = helper
	request = _request(guard)
	selected = not request.is_empty()
	accepted = guard._context.valid_guard_body(guard._model, guard._source, request)
	property.integrity_policy2 = helper.original
	hook.hook = Callable()
	_check(selected and accepted and not request.observed and not request.complete
		and helper.calls == ["boundary", "ground", "inventory", "model"],
		"early helper replacement selects original virtual route before scene observation")
	_observe({"kind": "early_helper", "selected_before_hook": selected,
		"context_valid": accepted, "observed": request.observed, "complete": request.complete,
		"calls": helper.calls})
	var script: GDScript = StadiumPoolWaterGuard
	var text: String = script.source_code
	hook.hook = func() -> void:
		script.source_code = text + "\n# V77_EARLY_GUARD_SOURCE_BREACH\n"
		guard._bodies[-1] = entry
	request = _request(guard)
	selected = not request.is_empty()
	accepted = guard._context.valid_guard_body(guard._model, guard._source, request)
	var source_breach: bool = request.get("source_breach", false)
	script.source_code = text
	guard._bodies.erase(-1)
	hook.hook = Callable()
	_check(selected and accepted and source_breach and not request.observed and not request.complete
		and not guard._context._invalidated,
		"early source breach survives unsupported registry fallback without poisoning valid Interior")
	hook.hook = func() -> void:
		script.source_code = text + "\n# V77_EARLY_GUARD_SOURCE_BREACH\n"
		guard._bodies[-1] = entry
	var guard_accepted: bool = guard.valid()
	script.source_code = text
	guard._bodies.erase(-1)
	hook.hook = Callable()
	property.entitlement = original
	_check(not guard_accepted and not guard._context._invalidated and guard.valid(),
		"actual enclosing guard rejects early source breach and exact restoration remains valid")
	_observe({"kind": "early_source", "selected_before_hook": selected,
		"context_valid": accepted, "source_breach": source_breach,
		"observed": request.observed, "complete": request.complete,
		"guard_rejected": not guard_accepted, "context_poisoned": guard._context._invalidated,
		"reload_performed": false, "restored_before_checks": true})


func _guard_coverage() -> bool:
	var lab: PitchBatLab = _start_case("guard_coverage")
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
		await get_tree().physics_frame
	var guard: StadiumPoolWaterGuard = adapter._guard
	if not _check(guard != null and guard.generation == 1 and guard.valid()
		and guard._ball == lab._batted_ball and guard._ball._started
		and not lab._automation.releases.is_empty()
		and Engine.get_physics_frames() - wait_start <= MAX_GUARD_FRAMES,
		"bounded genuine automation creates real launched ball/guard without trajectory selection"):
		return false
	var observed_frame: int = Engine.get_physics_frames()
	if not _capture_probes(lab, property, guard):
		return await _finish_case(lab)
	var original_seals: PackedByteArray = var_to_bytes([
		property.integrity_policy2._body_bytes, property.integrity_policy2._inventory_ids,
		property.integrity_policy2._model_bytes, property.integrity_policy2._topology_bytes])
	_fresh_coverage(property, guard)
	_guard_seals(property, guard)
	_all_body_metadata(guard)
	_body_policy(property, guard)
	_tail_and_reuse(property, guard)
	_coverage_miss(property, guard)
	_domain_fallback(property, guard)
	_guard_source_records(guard)
	_early_hooks(property, guard)
	_check(original_seals == var_to_bytes([
		property.integrity_policy2._body_bytes, property.integrity_policy2._inventory_ids,
		property.integrity_policy2._model_bytes, property.integrity_policy2._topology_bytes])
		and _probe_cursor == guard._bodies.size() + 34
		and _probe_cursor <= _probes.size() and guard._context == _active_context
		and not _active_context._invalidated and guard.valid(),
		"all synchronous controls preserve original seals and active context without recapture")
	var registered: StaticBody3D = property.ground_body
	var velocity: Vector3 = registered.constant_linear_velocity
	var downstream: Callable = guard._downstream
	var commits: int = adapter.commits
	var receipts: PackedByteArray = var_to_bytes(guard.receipts)
	var nested_valid: Array[bool] = [false]
	_callback_seen = false
	_callback_frame = -1
	guard._downstream = func(ball: BattedBallBody, batch: Array[Dictionary]) -> void:
		downstream.call(ball, batch)
		if _callback_seen:
			return
		_callback_seen = true
		_callback_frame = Engine.get_physics_frames()
		nested_valid[0] = guard.valid()
		_callback_before = var_to_bytes(StadiumPoolWaterGuard._state_parameters(guard._state))
		registered.constant_linear_velocity = velocity + Vector3(0.125, 0, 0)
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
	_check(_callback_seen and nested_valid[0] and _callback_frame >= armed_frame
		and Engine.get_physics_frames() - armed_frame <= MAX_CALLBACK_FRAMES
		and Engine.get_physics_frames() - wait_start <= MAX_GUARD_FRAMES + MAX_CALLBACK_FRAMES
		and _callback_before == _callback_after and rejected_same_tick
		and guard._generation_invalid and guard._context._invalidated
		and adapter.commits == commits and var_to_bytes(guard.receipts) == receipts,
		"real postcallback check rejects body mutation after independent nested validity in same tick")
	registered.constant_linear_velocity = velocity
	guard._downstream = downstream
	_check(property.valid_owner(lab) and not guard.valid() and guard._context._invalidated,
		"body restoration cannot revive active Interior after postcallback poison")
	_observe({"kind": "callback", "wait_start_frame": wait_start,
		"guard_observed_frame": observed_frame, "armed_frame": armed_frame,
		"mutation_frame": _callback_frame, "observed_frame": Engine.get_physics_frames(),
		"wait_frames": observed_frame - wait_start, "max_wait_frames": MAX_GUARD_FRAMES,
		"callback_frames": Engine.get_physics_frames() - armed_frame,
		"max_callback_frames": MAX_CALLBACK_FRAMES, "same_tick_rejected": rejected_same_tick,
		"nested_valid_before_mutation": nested_valid[0], "context_poisoned": guard._context._invalidated,
		"generation_invalid": guard._generation_invalid,
		"state_before_sha256": _callback_before.hex_encode().sha256_text(),
		"state_after_sha256": _callback_after.hex_encode().sha256_text(),
		"commits_unchanged": adapter.commits == commits,
		"receipts_unchanged": var_to_bytes(guard.receipts) == receipts})
	var captured: int = _probes.size()
	var used: int = _probe_cursor
	_probes.clear()
	_active_context = null
	_active_plan = {}
	return await _finish_case(lab, {"ordinary_first_guard": true,
		"captures_before_mutations": true, "probe_contexts": captured, "probes_consumed": used,
		"probe_references_released": _probes.is_empty(), "original_seals_preserved": true,
		"active_context_poisoned_at_teardown": true, "same_tick_rejection": rejected_same_tick})
