extends Node
## V68 finite native field semantics; standalone exact V61 helper projection.
## Genuine paid setup, fixed existing fixture/seed, no trajectory or outcome claim.
# gdlint: disable=max-file-lines,max-returns,function-arguments-number

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const MATCH_SEED: int = 314229
const SUMMARY_LIMIT: int = 262144
const EXPECTED_INSTALLATIONS: int = 8
const EXPECTED_NATIVE_CHECKS: int = 334
const EXPECTED_OBSERVATIONS: int = 68
const OBSERVATION_CAP: int = 80
const FAILURE_LABEL_CAP: int = 384
const FAILURE_LABEL_BYTES: int = 256
const OBSERVATION_ROW_BYTES: int = 1536
const NATIVE_VALUE_BYTES: int = 256
const FIELD_NAMES: Array[StringName] = [
    &"id", &"display_name", &"environment_style", &"fair_half_angle_degrees",
    &"safe_hit_z_m", &"deep_air_z_m", &"back_wall_z_m", &"home_run_height_m",
    &"dead_ball_z_m", &"shallow_anchor_z_m", &"middle_anchor_z_m",
    &"middle_center_anchor_z_m", &"deep_anchor_z_m", &"side_anchor_x_m",
    &"shallow_center_available", &"middle_center_available"
]
const FIELD_TYPES: Array[int] = [TYPE_STRING_NAME, TYPE_STRING, TYPE_INT,
    TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT,
    TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_BOOL, TYPE_BOOL]
const CASE_EXPECTED_CHECKS: Dictionary = {
    "primitive_matrix": 138, "native_semantics": 38, "incidental_resources": 33,
    "replacement_and_helper": 20, "custom_fallback": 14, "source_text": 16,
    "poison_property": 13, "poison_lab": 13
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
var _all_preserved: bool = false
var _observations: Array[Dictionary] = []
var _observations_complete: bool = true

class CustomField extends FieldDefinition:
	@export var custom_marker: int = 0


class PermissiveHelper extends StadiumPoolOwnedFieldIntegrity:
	func matches(_field: FieldDefinition, _original: PackedByteArray, _full: bool = false) -> bool:
		return true


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
		if argument.begins_with("--pool-owned-field-v68-dir="):
			_output = argument.trim_prefix("--pool-owned-field-v68-dir=")
		if argument.begins_with("--pool-owned-field-v68-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-owned-field-v68-runtime=")
		if argument.begins_with("--pool-owned-field-v68-execution="):
			_execution = argument.trim_prefix("--pool-owned-field-v68-execution=")
		if argument.begins_with("--pool-owned-field-v68-nonce="):
			_nonce = argument.trim_prefix("--pool-owned-field-v68-nonce=")
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
		"field_policy": StadiumPoolOwnedFieldIntegrity.POLICY,
		"field_names": FIELD_NAMES, "field_types": FIELD_TYPES,
		"field_observations": _observations, "observations_complete": _observations_complete,
		"expected_observations": EXPECTED_OBSERVATIONS,
		"source_text_policy": "RESTORE_TEXT_WITHOUT_RELOADING_LIVE_SCRIPTS",
		"compiled_reload_history_qualified": false,
		"caps": {"observations": OBSERVATION_CAP, "row_bytes": OBSERVATION_ROW_BYTES,
			"native_value_bytes": NATIVE_VALUE_BYTES, "summary_bytes": SUMMARY_LIMIT,
			"failure_labels": FAILURE_LABEL_CAP, "failure_label_bytes": FAILURE_LABEL_BYTES},
		"qualification": "finite disposable field-value and original cold-oracle controls only",
		"production_qualified": false, "report_settlement_qualified": false,
		"performance_qualified": false, "rendered_qualified": false}
	if _output_admitted:
		var encoded: String = JSON.stringify(summary, "", true, true)
		if encoded.to_utf8_buffer().size() <= SUMMARY_LIMIT:
			var output: FileAccess = FileAccess.open(
				_output.path_join("pool-owned-field-v68-summary.json"), FileAccess.WRITE)
			if output != null:
				output.store_string(encoded)
				if output.get_error() != OK:
					_check(false, "summary output write failed")
				output.close()
			else:
				_check(false, "summary output could not open")
		else:
			_check(false, "summary exceeds fixed byte cap")
	print("POOL_OWNED_FIELD_V68 checks=%d failures=%d starts=%d cleanups=%d source=%s" % [
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
	for method: StringName in [&"_primitive_matrix", &"_native_semantics", &"_incidental_resources",
		&"_replacement_and_helper", &"_custom_fallback", &"_source_text"]:
		if not await call(method):
			return
	if not await _poison("property") or not await _poison("lab"):
		return
	_all_preserved = (_starts == EXPECTED_INSTALLATIONS and _cleanups == EXPECTED_INSTALLATIONS
		and _rows.size() == EXPECTED_INSTALLATIONS and _reports == 0 and _runner_errors.is_empty()
		and _unchanged() and _ledger == null and StadiumPoolHotpathProfile.active == null
		and _observations_complete and _observations.size() == EXPECTED_OBSERVATIONS)
	_check(_all_preserved, "all disposable installations retire without settlement or caller mutation")


func _primitive_matrix() -> bool:
	var lab: PitchBatLab = _start_case("primitive_matrix")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var declared: Array[StringName] = []
	for row: Dictionary in property.field.get_property_list():
		if int(row.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			declared.append(StringName(row.name))
	declared.sort()
	var wanted: Array[StringName] = FIELD_NAMES.duplicate()
	wanted.sort()
	_check(declared == wanted and declared.size() == 16,
		"exact declared inherited FieldDefinition and DefinitionBase primitive set")
	property.field = property.field.duplicate(true) as FieldDefinition
	_check(property.field != lab._field_definition and property.valid_owner_full_ledger(lab),
		"value-equivalent property clone isolates property and lab field mutations")
	for owner: String in ["property", "lab"]:
		var field: FieldDefinition = property.field if owner == "property" else lab._field_definition
		for name: StringName in FIELD_NAMES:
			var original: Variant = field.get(name)
			var replacement: Variant = _changed(original)
			field.set(name, replacement)
			_check(var_to_bytes(field.get(name)) != var_to_bytes(original),
				owner + "/" + String(name) + ": actual native value changed")
			_check(not property.valid_owner(lab) and not property.valid_owner_full_fields(lab)
				and not property.valid_owner_full_ledger(lab) and not property.full_capture_valid(lab),
				owner + "/" + String(name) + ": live and original cold oracles reject")
			_check(not _case_adapter._prepared.context._invalidated,
				owner + "/" + String(name) + ": direct predicates do not poison InteriorV2")
			_observe({"kind": "primitive", "owner": owner, "field": String(name),
				"original": _native(original), "changed": _native(field.get(name))})
			field.set(name, original)
			_check(var_to_bytes(field.get(name)) == var_to_bytes(original)
				and property.valid_owner(lab) and property.valid_owner_full_ledger(lab)
				and _case_adapter._prepared.context.valid(property.pool_model, _runtime),
				owner + "/" + String(name) + ": exact direct restoration remains valid")
	return await _finish_case(lab, {"fields": 16, "owners": 2, "mutations": 32})


func _changed(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return StringName(String(value) + "-v68")
		TYPE_STRING:
			return value + "-v68"
		TYPE_INT:
			return value + 1
		TYPE_FLOAT:
			return value + 0.25
		TYPE_BOOL:
			return not value
	return null


func _native_semantics() -> bool:
	var lab: PitchBatLab = _start_case("native_semantics")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var values: Array = StadiumPoolOwnedFieldIntegrity._values(property.field)
	for index: int in range(16):
		_check(typeof(values[index]) == FIELD_TYPES[index]
			and var_to_bytes(values[index]) == var_to_bytes(property.field.get(FIELD_NAMES[index])),
			"native field type and exact descriptor value: " + String(FIELD_NAMES[index]))
		_observe({"kind": "declared_type", "field": String(FIELD_NAMES[index]),
			"value": _native(values[index])})
	# Runtime IEEE decode avoids relying on signed-zero literal encoding.
	var positive_zero: float = _runtime_float("0000000000000000")
	var negative_zero: float = _runtime_float("0000000000000080")
	var zero_encoding_exact: bool = (
		_float_bytes(positive_zero) == "0000000000000000"
		and _float_bytes(negative_zero) == "0000000000000080"
		and var_to_bytes(positive_zero).hex_encode() == "0300000000000000"
		and var_to_bytes(negative_zero).hex_encode() == "0300000000000080")
	for pair: Array in [[1, 1.0], [StringName("v68"), "v68"],
		[false, 0], [positive_zero, negative_zero]]:
		var zero_pair: bool = typeof(pair[0]) == TYPE_FLOAT and typeof(pair[1]) == TYPE_FLOAT
		_check(var_to_bytes(pair[0]) != var_to_bytes(pair[1])
			and (not zero_pair or zero_encoding_exact),
			"native bytes preserve primitive type or signed-zero representation")
		_observe({"kind": "native_distinction", "first": _native(pair[0]),
			"second": _native(pair[1])})
	if not zero_encoding_exact:
		# The preceding native assertion failed; never test production with malformed probe values.
		return await _finish_case(lab, {"declared_types": 16, "native_distinctions": 4,
			"nonfinite_replacements": 0})
	var field: FieldDefinition = property.field.duplicate(true) as FieldDefinition
	field.safe_hit_z_m = positive_zero
	var assigned_positive: float = field.safe_hit_z_m
	var seal: StadiumPoolOwnedFieldIntegrity = StadiumPoolOwnedFieldIntegrity.capture(field)
	var original: PackedByteArray = var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field))
	_check(_float_bytes(assigned_positive) == "0000000000000000"
		and var_to_bytes(assigned_positive).hex_encode() == "0300000000000000"
		and seal._admitted and seal.matches(field, original), "positive-zero field admitted")
	field.safe_hit_z_m = negative_zero
	var hot_matches: bool = seal.matches(field, original)
	var cold_matches: bool = seal.matches(field, original, true)
	var original_oracle_matches: bool = (
		var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field)) == original)
	_check(_float_bytes(field.safe_hit_z_m) == "0000000000000080"
		and var_to_bytes(field.safe_hit_z_m).hex_encode() == "0300000000000080"
		and not hot_matches and not cold_matches and not original_oracle_matches,
		"production helper and cold oracle reject negative zero against positive-zero seal")
	_observe({"kind": "signed_zero",
		"constructed_positive": _native(positive_zero), "constructed_negative": _native(negative_zero),
		"positive_ieee64": _float_bytes(positive_zero), "negative_ieee64": _float_bytes(negative_zero),
		"assigned_positive": _native(assigned_positive),
		"assigned_positive_ieee64": _float_bytes(assigned_positive),
		"changed": _native(field.safe_hit_z_m),
		"assigned_negative_ieee64": _float_bytes(field.safe_hit_z_m),
		"hot_matches": hot_matches, "cold_matches": cold_matches,
		"original_oracle_matches": original_oracle_matches})
	field.safe_hit_z_m = positive_zero
	_check(_float_bytes(field.safe_hit_z_m) == "0000000000000000"
		and var_to_bytes(field.safe_hit_z_m).hex_encode() == "0300000000000000"
		and seal.matches(field, original) and seal.matches(field, original, true),
		"signed-zero byte restoration accepts unchanged primitive seal")
	for nonfinite: float in [INF, -INF, NAN]:
		field.safe_hit_z_m = nonfinite
		_check(not is_finite(field.safe_hit_z_m) and not seal.matches(field, original)
			and not seal.matches(field, original, true),
			"nonfinite native replacement rejected against original finite field seal")
		_observe({"kind": "nonfinite", "changed": _native(field.safe_hit_z_m)})
		field.safe_hit_z_m = positive_zero
		_check(seal.matches(field, original) and seal.matches(field, original, true),
			"exact finite restoration after nonfinite replacement accepts original seal")
	_check(property.valid_owner_full_ledger(lab) and _unchanged(),
		"standalone native-value probe leaves actual installation untouched")
	return await _finish_case(lab, {"declared_types": 16, "native_distinctions": 4,
		"nonfinite_replacements": 3})


func _incidental_resources() -> bool:
	var lab: PitchBatLab = _start_case("incidental_resources")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	property.field = property.field.duplicate(true) as FieldDefinition
	_check(property.field != lab._field_definition and property.valid_owner_full_ledger(lab),
		"incidental field Resource probes use separated equivalent property value")
	for owner: String in ["property", "lab"]:
		var field: FieldDefinition = property.field if owner == "property" else lab._field_definition
		for name: StringName in [&"resource_name", &"resource_local_to_scene", &"metadata"]:
			var original: Variant = field.get(name) if name != &"metadata" else null
			if name == &"metadata":
				field.set_meta(&"v68_incidental", "probe")
			elif name == &"resource_name":
				field.set(name, String(original) + "-v68")
			else:
				field.set(name, not original)
			var changed: PackedByteArray = var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field))
			_check(changed != property._field_bytes, "incidental original Resource oracle differs")
			_check(property.valid_owner(lab)
				and _case_adapter._prepared.context.valid(property.pool_model, _runtime),
				"incidental Resource data remains acceptable to direct live property and context")
			_check(not property.valid_owner_full_fields(lab)
				and not property.valid_owner_full_ledger(lab) and not property.full_capture_valid(lab),
				"incidental Resource change rejected at original cold boundaries")
			_observe({"kind": "incidental_resource", "owner": owner, "field": String(name),
				"original_resource_bytes": property._field_bytes.size(),
				"changed_resource_bytes": changed.size(),
				"original_resource_sha256": property._field_bytes.hex_encode().sha256_text(),
				"changed_resource_sha256": changed.hex_encode().sha256_text()})
			if name == &"metadata":
				field.remove_meta(&"v68_incidental")
			else:
				field.set(name, original)
			_check(property.valid_owner_full_ledger(lab) and property.full_capture_valid(lab)
				and not _case_adapter._prepared.context._invalidated,
				"exact incidental Resource restoration preserves live and cold authority")
	return await _finish_case(lab, {"owners": 2, "incidental_fields": 3})


func _replacement_and_helper() -> bool:
	var lab: PitchBatLab = _start_case("replacement_and_helper")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var original: FieldDefinition = property.field
	var equivalent: FieldDefinition = original.duplicate(true) as FieldDefinition
	var helper: StadiumPoolOwnedFieldIntegrity = property._field_integrity_v68
	_check(equivalent != original and helper.matches(equivalent, property._field_bytes, true),
		"distinct equivalent FieldDefinition retains original full Resource bytes")
	property.field = equivalent
	var property_equivalent_accepted: bool = (
		property.valid_owner(lab) and property.valid_owner_full_ledger(lab))
	_check(property_equivalent_accepted,
		"value-equivalent property field replacement accepted")
	property.field = original
	_check(property.valid_owner_full_ledger(lab), "original property field restoration accepted")
	var runtime: FieldDefinition = lab._field_definition
	var replacement: FieldDefinition = runtime.duplicate(true) as FieldDefinition
	_check(replacement != runtime and helper.matches(replacement, property._field_bytes),
		"equivalent runtime field passes descriptor comparison alone")
	lab._field_definition = replacement
	var lab_equivalent_rejected: bool = (
		not property.valid_owner(lab) and not property.valid_owner_full_ledger(lab))
	_check(lab_equivalent_rejected,
		"lab runtime field identity replacement still rejected")
	lab._field_definition = runtime
	_check(property.valid_owner_full_ledger(lab), "original runtime identity restored")
	_observe({"kind": "identity_split", "property_equivalent_accepted": property_equivalent_accepted,
		"lab_equivalent_rejected": lab_equivalent_rejected, "native_equivalent":
		var_to_bytes(StadiumPoolPartyAssetIntegrity._value(equivalent)) == property._field_bytes})
	property._field_integrity_v68 = null
	_check(property.valid_owner(lab), "missing helper falls back to full original Resource oracle")
	property.field = equivalent
	equivalent.resource_name += "-v68"
	_check(not property.valid_owner(lab), "missing helper rejects incidental full Resource mutation")
	property.field = original
	property._field_integrity_v68 = helper
	_check(property.valid_owner_full_ledger(lab), "missing-helper probe restoration accepted")
	var overridden: PermissiveHelper = PermissiveHelper.new()
	_check(overridden.matches(equivalent, property._field_bytes),
		"fixture override really attempts permissive helper admission")
	property._field_integrity_v68 = overridden
	property.field = equivalent
	_check(not property.valid_owner(lab) and not property.valid_owner_full_fields(lab),
		"overridden helper cannot bypass direct original Resource fallback")
	property.field = original
	property._field_integrity_v68 = helper
	_check(property.valid_owner_full_ledger(lab) and not _case_adapter._prepared.context._invalidated,
		"original exact helper and resource restored without context poisoning")
	return await _finish_case(lab, {"property_value_equivalence": true,
		"runtime_identity_required": true, "override_fallback": true})


func _custom_fallback() -> bool:
	var lab: PitchBatLab = _start_case("custom_fallback")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var field: CustomField = CustomField.new()
	for name: StringName in FIELD_NAMES:
		field.set(name, property.field.get(name))
	var helper: StadiumPoolOwnedFieldIntegrity = StadiumPoolOwnedFieldIntegrity.capture(field)
	var original: PackedByteArray = var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field))
	_check(not StadiumPoolOwnedFieldIntegrity._plain_definition(field) and not helper._admitted
		and helper.matches(field, original) and helper.matches(field, original, true),
		"custom field bypasses finite admission and uses original Resource oracle")
	field.custom_marker += 1
	_check(not helper.matches(field, original) and not helper.matches(field, original, true),
		"custom extra script property rejected by full fallback")
	field.custom_marker -= 1
	_check(helper.matches(field, original), "custom extra property direct restoration accepted")
	field.resource_name = "v68-custom"
	_check(not helper.matches(field, original), "custom incidental Resource field remains full-sealed")
	field.resource_name = ""
	_check(helper.matches(field, original, true), "custom incidental Resource field restored")
	_check(not property._field_integrity_v68.matches(field, property._field_bytes)
		and property.valid_owner_full_ledger(lab),
		"custom equal primitive values cannot inherit plain FieldDefinition Resource seal")
	_observe({"kind": "custom_fallback", "admitted": helper._admitted,
		"original_resource_bytes": original.size(),
		"original_resource_sha256": original.hex_encode().sha256_text()})
	return await _finish_case(lab, {"custom_full_fallback": true})


func _source_text() -> bool:
	var lab: PitchBatLab = _start_case("source_text")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	for script: GDScript in [StadiumPoolOwnedFieldIntegrity.FIELD_SCRIPT,
		StadiumPoolOwnedFieldIntegrity.BASE_SCRIPT]:
		var original: String = script.source_code
		var label: String = "field" if script == StadiumPoolOwnedFieldIntegrity.FIELD_SCRIPT else "base"
		# Text setter only. Never reload a globally live or cached script.
		script.source_code = original + "\n# v68 finite source-text probe\n"
		var changed: String = script.source_code
		var live_rejected: bool = not property.valid_owner(lab)
		var oracle_matches: bool = var_to_bytes(
			StadiumPoolPartyAssetIntegrity._value(property.field)) == property._field_bytes
		var cold_matches: bool = property.valid_owner_full_fields(lab)
		var context_clean: bool = not _case_adapter._prepared.context._invalidated
		var sources_current: bool = StadiumPoolOwnedFieldIntegrity.sources_current(
			property._field_integrity_v68, property.field)
		# Restore before assertions, evidence writing, yielding, or any exit.
		script.source_code = original
		_check(changed != original and live_rejected,
			label + ": changed source text rejected by actual live owner")
		_check(not sources_current and not cold_matches,
			label + ": explicit nonvirtual source guard rejects the exact cold field route")
		_check(script.source_code == original and property.valid_owner(lab)
			and property.valid_owner_full_ledger(lab), label + ": exact source text restored")
		_check(context_clean and _case_adapter._prepared.context.valid(property.pool_model, _runtime),
			label + ": direct source probe restored without InteriorV2 poisoning")
		_observe({"kind": "source_text", "script": label, "live_rejected": live_rejected,
			"cold_matches": cold_matches, "original_oracle_matches": oracle_matches,
			"sources_current": sources_current,
			"original_source_sha256": original.sha256_text(),
			"changed_source_sha256": changed.sha256_text(), "restored": script.source_code == original,
			"reload_performed": false})
	return await _finish_case(lab, {"source_text_edits": 2, "reloads": 0,
		"compiled_reload_history_qualified": false})


func _poison(owner: String) -> bool:
	var lab: PitchBatLab = _start_case("poison_" + owner)
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	property.field = property.field.duplicate(true) as FieldDefinition
	_check(property.field != lab._field_definition and property.valid_owner_full_ledger(lab)
		and context.valid(property.pool_model, _runtime) and not context._invalidated,
		owner + ": original actual InteriorV2 context valid")
	var field: FieldDefinition = property.field if owner == "property" else lab._field_definition
	var original: float = field.safe_hit_z_m
	field.safe_hit_z_m += 0.25
	_check(not property.valid_owner(lab) and not context._invalidated,
		owner + ": direct field rejection alone leaves context unpoisoned")
	var valid_changed: bool = context.valid(property.pool_model, _runtime)
	var poisoned: bool = context._invalidated
	field.safe_hit_z_m = original
	_check(not valid_changed and poisoned,
		owner + ": actual InteriorV2 valid call observes mutation and permanently poisons")
	_check(property.valid_owner(lab) and property.valid_owner_full_ledger(lab),
		owner + ": direct property authority restores after exact primitive restoration")
	_check(not context.valid(property.pool_model, _runtime) and context._invalidated
		and not _case_adapter._prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime)
		and _unchanged(), owner + ": restored field never resurrects invalidated actual context")
	_observe({"kind": "context_poison", "owner": owner,
		"actual_context_rejected": not valid_changed, "invalidated": poisoned,
		"field_restored": _native(field.safe_hit_z_m)})
	return await _finish_case(lab, {"actual_interior_poison": true, "primitive_restored": true})


func _native(value: Variant) -> Dictionary:
	var encoded: PackedByteArray = var_to_bytes(value)
	if encoded.size() > NATIVE_VALUE_BYTES:
		_observations_complete = false
		_check(false, "native observation exceeds fixed complete-value byte cap")
		return {}
	return {"type_id": typeof(value), "type": type_string(typeof(value)),
		"native_bytes": encoded.size(), "native_hex": encoded.hex_encode()}


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


func _runtime_float(hex: String) -> float:
	var source: PackedByteArray = hex.hex_decode()
	var runtime: PackedByteArray = PackedByteArray()
	runtime.resize(8)
	runtime.fill(0)
	for index: int in range(8):
		runtime[index] = source[index]
	return runtime.decode_double(0)


func _float_bytes(value: float) -> String:
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(8)
	raw.encode_double(0, value)
	return raw.hex_encode()
