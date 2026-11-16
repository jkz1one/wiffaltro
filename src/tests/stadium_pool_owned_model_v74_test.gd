extends Node
## V74 finite combined owner/model controls; exact standalone V71 paid setup projection.
## Genuine paid setup, fixed existing fixture/seed, no trajectory or outcome claim.
# gdlint: disable=max-file-lines,max-returns,function-arguments-number

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const MATCH_SEED: int = 314229
const SUMMARY_LIMIT: int = 262144
const EXPECTED_INSTALLATIONS: int = 8
const EXPECTED_NATIVE_CHECKS: int = 187
const EXPECTED_OBSERVATIONS: int = 26
const OBSERVATION_CAP: int = 128
const FAILURE_LABEL_CAP: int = 384
const FAILURE_LABEL_BYTES: int = 256
const OBSERVATION_ROW_BYTES: int = 1536
const NATIVE_VALUE_BYTES: int = 256
const MAX_GUARD_FRAMES: int = 1800
const MAX_CALLBACK_FRAMES: int = 2
const CASE_EXPECTED_CHECKS: Dictionary = {
	"admission": 16, "model_roles": 31, "model_seals": 15, "source_guards": 21,
	"domain_fallback": 19, "helper_late_mutation": 12, "model_poison": 12,
	"natural_model_callback": 12
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

var _callback_seen: bool = false
var _callback_frame: int = -1
var _callback_before: PackedByteArray
var _callback_after: PackedByteArray

class ForwardingHelper extends StadiumPoolOwnedIntegrity:
	var original: StadiumPoolOwnedIntegrity
	var target: Node3D
	var mutate: bool = false
	var calls: Array[String] = []

	func valid_boundary(boundary: Node3D) -> bool:
		calls.append("boundary")
		return original.valid_boundary(boundary)

	func valid_ground(ground: StaticBody3D) -> bool:
		calls.append("ground")
		return original.valid_ground(ground)

	func valid_inventory(lab: Node3D) -> bool:
		calls.append("inventory")
		var result: bool = original.valid_inventory(lab)
		if mutate:
			target.set_meta("volume_role", "V74_LATE_HELPER_MUTATION")
		return result

	func valid_model(model: Node3D) -> bool:
		calls.append("model")
		return original.valid_model(model)


class CustomField extends FieldDefinition:
	@export var marker: int:
		get:
			reads += 1
			if is_instance_valid(target):
				target.set_meta("volume_role", "V74_FIELD_GETTER_MUTATION")
			return 0
	var target: Node3D
	var reads: int = 0


class CustomFieldHelper extends StadiumPoolOwnedFieldIntegrity:
	var calls: int = 0

	func matches(_field: FieldDefinition, _original: PackedByteArray, _full: bool = false) -> bool:
		calls += 1
		return false


class CustomFielder extends FielderController:
	var custom_domain: bool = true


class CustomResolver extends BallPlayResolver:
	var custom_domain: bool = true


class InteriorDispatchProbe extends StadiumPoolInteriorV2:
	var calls: Array[String] = []

	func _pose_authorized() -> bool:
		calls.append("pose")
		return super._pose_authorized()

	func _model_snapshot_valid(model: Node3D) -> bool:
		calls.append("model")
		return super._model_snapshot_valid(model)


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
		if argument.begins_with("--pool-owned-model-v74-dir="):
			_output = argument.trim_prefix("--pool-owned-model-v74-dir=")
		if argument.begins_with("--pool-owned-model-v74-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-owned-model-v74-runtime=")
		if argument.begins_with("--pool-owned-model-v74-execution="):
			_execution = argument.trim_prefix("--pool-owned-model-v74-execution=")
		if argument.begins_with("--pool-owned-model-v74-nonce="):
			_nonce = argument.trim_prefix("--pool-owned-model-v74-nonce=")
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
			"field": 334, "scene": 227},
		"scene_observations": _observations, "observations_complete": _observations_complete,
		"expected_observations": EXPECTED_OBSERVATIONS,
		"source_text_policy": "RESTORE_TEXT_WITHOUT_RELOADING_LIVE_SCRIPTS",
		"compiled_reload_history_qualified": false,
		"caps": {"observations": OBSERVATION_CAP, "row_bytes": OBSERVATION_ROW_BYTES,
			"native_value_bytes": NATIVE_VALUE_BYTES, "summary_bytes": SUMMARY_LIMIT,
			"failure_labels": FAILURE_LABEL_CAP, "failure_label_bytes": FAILURE_LABEL_BYTES},
		"qualification": "finite combined owner/model and original fallback controls only",
		"production_qualified": false, "report_settlement_qualified": false,
		"performance_qualified": false, "rendered_qualified": false}
	if _output_admitted:
		var encoded: String = JSON.stringify(summary, "", true, true)
		if encoded.to_utf8_buffer().size() <= SUMMARY_LIMIT:
			var output: FileAccess = FileAccess.open(
				_output.path_join("pool-owned-model-v74-summary.json"), FileAccess.WRITE)
			if output != null:
				output.store_string(encoded)
				if output.get_error() != OK:
					_check(false, "summary output write failed")
				output.close()
			else:
				_check(false, "summary output could not open")
		else:
			_check(false, "summary exceeds fixed byte cap")
	print("POOL_OWNED_MODEL_V74 checks=%d failures=%d starts=%d cleanups=%d source=%s" % [
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
	for method: StringName in [&"_admission", &"_model_roles", &"_model_seals", &"_source_guards",
		&"_domain_fallback", &"_helper_late_mutation", &"_model_poison",
		&"_natural_model_callback"]:
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

func _route(context: StadiumPoolInteriorV2) -> int:
	if context._owner_model_plan.is_empty():
		return 0
	return StadiumPoolOwnedIntegrity.owner_model_route(context._owner_model_plan, context)


func _combined(lab: PitchBatLab, property: StadiumPoolOwnedProperty,
	context: StadiumPoolInteriorV2) -> bool:
	var request: Dictionary = {"plan": context._owner_model_plan, "interior": context,
		"model": property.pool_model, "combined": false}
	return property.valid_owner_model(lab, request) and request.combined


func _admitted(lab: PitchBatLab, property: StadiumPoolOwnedProperty) -> bool:
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	return _check(_route(context) == 1 and _combined(lab, property, context)
		and context.valid(property.pool_model, _runtime) and not context._invalidated,
		_case_name + ": actual installed combined owner/model route selected")


func _admission() -> bool:
	var lab: PitchBatLab = _start_case("admission")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	var helper: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var original_tree: int = 0
	var model_only: int = 0
	var ids: PackedInt64Array = []
	for index: int in helper._owner_scene_model:
		var row: Dictionary = helper._owner_scene_nodes[index]
		ids.append(row.id)
		if row.tree:
			original_tree += 1
		elif row.model_tree:
			model_only += 1
	_check(ids == context._identities and ids.size() == 27
		and original_tree == 10 and model_only == 17,
		"separate model DFS has27 nodes:10 original tree and17 model-only members")
	_check(property.valid_owner(lab) and property.full_capture_valid(lab)
		and helper.valid_model(property.pool_model), "original live and cold predicates agree")
	_check(_combined(lab, property, context) and context.valid(property.pool_model, _runtime),
		"independent next validation observes current model without success reuse")
	var material: StandardMaterial3D = _first_mesh(property.pool_model).material_override
	var color: Color = material.albedo_color
	material.albedo_color = Color(0.8, 0.2, 0.6, 0.4)
	var allowed: bool = property.valid_owner(lab) and _combined(lab, property, context) \
		and context.valid(property.pool_model, _runtime)
	material.albedo_color = color
	_check(allowed, "policy2 continues excluding render-resource color from gameplay authority")
	var virtual_context: InteriorDispatchProbe = InteriorDispatchProbe.new()
	for member: StringName in [&"_model", &"_carrier", &"_parent_id", &"_source", &"_pose",
		&"_snapshot", &"_identities", &"_source_inputs", &"_owned_profile", &"_owned_lab",
		&"_owner_model_plan"]:
		virtual_context.set(member, context.get(member))
	_check(_route(virtual_context) == 0 and virtual_context.valid(property.pool_model, _runtime)
		and virtual_context.calls == ["pose", "model"],
		"Interior subclass keeps original virtual pose and final model dispatch")
	var private_model: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	private_model.transform = StadiumPoolContract.placement()
	add_child(private_model)
	var private_context: StadiumPoolInteriorV2 = StadiumPoolInteriorV2.capture(private_model, _runtime)
	_check(private_context != null and private_context._owner_model_plan.is_empty()
		and private_context.valid(private_model, _runtime),
		"unowned exact model retains original private capture and validity")
	private_model.get_node(StadiumPoolInteriorV2.VOLUME_ID).set_meta("volume_role", "V74_PRIVATE")
	_check(not private_context.valid(private_model, _runtime) and private_context._invalidated,
		"unowned private final model check still rejects and poisons")
	private_model.free()
	_observe({"kind": "admission", "route": _route(context), "model_nodes": ids.size(),
		"original_tree": original_tree, "model_only": model_only, "render_edit_allowed": allowed})
	return await _finish_case(lab, {"combined_selected": true, "model_nodes": 27,
		"original_tree": 10, "model_only": 17, "fresh_calls": 2})


func _mutation(lab: PitchBatLab, property: StadiumPoolOwnedProperty, label: String,
	owner_expected: bool, change: Callable, restore: Callable) -> void:
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	change.call()
	var owner: bool = property.valid_owner(lab)
	var combined: bool = _combined(lab, property, context)
	var model: bool = property.integrity_policy2.valid_model(property.pool_model)
	restore.call()
	_check(owner == owner_expected and not combined and not model,
		label + ": original owner scope preserved and combined rejects model mutation")
	_check(property.valid_owner(lab) and _combined(lab, property, context)
		and context.valid(property.pool_model, _runtime) and not context._invalidated,
		label + ": exact direct restoration restores original seals without recapture")
	_observe({"kind": "mutation", "label": label, "owner": owner,
		"combined": combined, "original_model": model, "restored": true})


func _model_roles() -> bool:
	var lab: PitchBatLab = _start_case("model_roles")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var model: Node3D = property.pool_model
	var carrier: Node3D = model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var visual: Node3D = model.get_node("Visual")
	var mesh: MeshInstance3D = _first_mesh(visual)
	var body: StaticBody3D = model.get_node("Collision/POOL_LADDER")
	var shape: CollisionShape3D = _shape(body)
	for node: Node3D in [model, carrier, visual, mesh]:
		var had: bool = node.has_meta("surface_id")
		var old: Variant = node.get_meta("surface_id") if had else null
		_mutation(lab, property, String(node.name) + " metadata", true,
			func() -> void: node.set_meta("surface_id", "V74_CHANGED"),
			func() -> void:
				if had:
					node.set_meta("surface_id", old)
				else:
					node.remove_meta("surface_id"))
	for node: Node3D in [carrier, visual, mesh]:
		var old: Transform3D = node.transform
		_mutation(lab, property, String(node.name) + " local pose", true,
			func() -> void: node.position.x += 0.125,
			func() -> void: node.transform = old)
	var global_pose: Transform3D = mesh.global_transform
	_mutation(lab, property, "visual global pose", true,
		func() -> void: mesh.global_position.y += 0.125,
		func() -> void: mesh.global_transform = global_pose)
	var root_pose: Transform3D = model.transform
	_mutation(lab, property, "root pose", false,
		func() -> void: model.position.x += 0.125,
		func() -> void: model.transform = root_pose)
	var velocity: Vector3 = body.constant_linear_velocity
	_mutation(lab, property, "body velocity", false,
		func() -> void: body.constant_linear_velocity = velocity + Vector3(0.125, 0, 0),
		func() -> void: body.constant_linear_velocity = velocity)
	var box: BoxShape3D = shape.shape
	var size: Vector3 = box.size
	_mutation(lab, property, "shape geometry", false,
		func() -> void: box.size = size + Vector3(0.125, 0, 0),
		func() -> void: box.size = size)
	return await _finish_case(lab, {"mutations": 11, "direct_restorations": 11,
		"default_owner_model_only_mutations_allowed": 8})


func _model_seals() -> bool:
	var lab: PitchBatLab = _start_case("model_seals")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	var helper: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var probes: Array[StadiumPoolInteriorV2] = []
	for index: int in range(3):
		probes.append(StadiumPoolInteriorV2.capture_owned(property.pool_model, _runtime, property, lab))
	if not _check(probes[0] != null and probes[1] != null and probes[2] != null
		and _route(probes[0]) == 1 and _route(probes[1]) == 1 and _route(probes[2]) == 1,
		"three independent exact contexts captured while pristine before any seal corruption"):
		return await _finish_case(lab)
	var original_id: int = helper._model_id
	helper._model_id = 0
	var id_rejected: bool = not _combined(lab, property, context) \
		and not helper.valid_model(property.pool_model) \
		and not probes[0].valid(property.pool_model, _runtime) and probes[0]._invalidated
	helper._model_id = original_id
	_check(id_rejected and _combined(lab, property, context)
		and not probes[0].valid(property.pool_model, _runtime),
		"current original model ID seal retained")
	var ids: PackedInt64Array = context._identities
	context._identities = PackedInt64Array([0])
	probes[1]._identities = PackedInt64Array([0])
	var identities_rejected: bool = not _combined(lab, property, context) \
		and not probes[1].valid(property.pool_model, _runtime) and probes[1]._invalidated
	context._identities = ids
	probes[1]._identities = ids
	_check(identities_rejected and _combined(lab, property, context)
		and not probes[1].valid(property.pool_model, _runtime),
		"current Interior identity seal retained independently of property pool IDs")
	var pool_ids: PackedInt64Array = property._pool_ids
	property._pool_ids = PackedInt64Array([0])
	var property_ids_rejected: bool = not property.valid_owner(lab) \
		and not _combined(lab, property, context)
	property._pool_ids = pool_ids
	_check(property_ids_rejected and _combined(lab, property, context),
		"earlier property pool-ID walk retained independently of Interior IDs")
	var original: PackedByteArray = helper._model_bytes
	helper._model_bytes = PackedByteArray([1])
	var bytes_rejected: bool = not _combined(lab, property, context) \
		and not helper.valid_model(property.pool_model) \
		and not probes[2].valid(property.pool_model, _runtime) and probes[2]._invalidated
	helper._model_bytes = original
	_check(bytes_rejected and _combined(lab, property, context)
		and not probes[2].valid(property.pool_model, _runtime), "original model byte seal retained")
	_check(context.valid(property.pool_model, _runtime) and not context._invalidated,
		"direct seal controls restore without poisoning actual untouched Interior")
	_observe({"kind": "seals", "model_id": id_rejected, "interior_ids": identities_rejected,
		"property_ids": property_ids_rejected, "model_bytes": bytes_rejected, "restored": true,
		"independent_contexts_poisoned": 3, "captures_before_mutations": true})
	return await _finish_case(lab, {"original_seals": 4, "resealed": false,
		"independent_contexts_poisoned": 3, "captures_before_mutations": true})


func _source_guards() -> bool:
	var lab: PitchBatLab = _start_case("source_guards")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	var scripts: Array[GDScript] = [StadiumPoolOwnedFieldIntegrity,
		StadiumPoolOwnedFieldIntegrity.FIELD_SCRIPT, StadiumPoolOwnedFieldIntegrity.BASE_SCRIPT,
		FielderController, BallPlayResolver, PitchBatLab, StadiumPoolOwnedLayout, SeasonOwnership]
	for script: GDScript in scripts:
		var original: String = script.source_code
		script.source_code = original + "\n# v74 combined source-text control\n"
		var rejected: bool = _route(context) == -1
		var changed: String = script.source_code.sha256_text()
		script.source_code = original
		_check(rejected and _route(context) == 1,
			"captured reviewed tail source rejects edited text and accepts exact restoration")
		_observe({"kind": "source", "path": script.resource_path,
			"original_sha256": original.sha256_text(), "changed_sha256": changed,
			"rejected": rejected, "restored": true, "reload_performed": false})
	var record: Dictionary = context._owner_model_plan.sources[0]
	var base: Variant = record.base
	record.base = StadiumPoolOwnedFieldIntegrity
	var base_rejected: bool = _route(context) == -1
	record.base = base
	_check(base_rejected and _route(context) == 1,
		"recorded base-chain predicate is live; no compiled reload performed")
	var script: GDScript = record.script
	record.script = StadiumPoolOwnedFieldIntegrity
	var identity_rejected: bool = _route(context) == -1
	record.script = script
	_check(identity_rejected and _route(context) == 1,
		"captured script identity/source pair cannot be substituted")
	var original_helper: StadiumPoolOwnedFieldIntegrity = property._field_integrity_v68
	property._field_integrity_v68 = null
	var field_script: GDScript = StadiumPoolOwnedFieldIntegrity.BASE_SCRIPT
	var original_source: String = field_script.source_code
	field_script.source_code = original_source + "\n# v74 corruption cannot hide behind fallback\n"
	var corrupt_route: int = _route(context)
	var observed: bool = context.valid(property.pool_model, _runtime)
	field_script.source_code = original_source
	property._field_integrity_v68 = original_helper
	_check(corrupt_route == -1 and not observed and context._invalidated,
		"admitted source corruption rejects and poisons before unsupported-helper fallback")
	_check(property.valid_owner(lab) and not context.valid(property.pool_model, _runtime),
		"source restoration recovers direct owner but cannot revive poisoned Interior")
	_observe({"kind": "source_precedence", "route": corrupt_route,
		"base_predicate_rejected": base_rejected, "identity_rejected": identity_rejected,
		"context_poisoned": context._invalidated, "reload_performed": false})
	return await _finish_case(lab, {"source_text_edits": 9, "reloads": 0,
		"recorded_base_predicate": true, "corruption_precedes_fallback": true})
func _domain_fallback() -> bool:
	var lab: PitchBatLab = _start_case("domain_fallback")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	var original: FieldDefinition = property.field
	var equivalent: FieldDefinition = original.duplicate(true) as FieldDefinition
	property.field = equivalent
	_check(equivalent != original and _route(context) == 1 and property.valid_owner(lab)
		and context.valid(property.pool_model, _runtime),
		"same-value plain property.field replacement preserves original valid semantics")
	property.field = original
	var runtime: FieldDefinition = lab._field_definition
	lab._field_definition = equivalent
	_check(not property.valid_owner(lab), "original runtime field identity requirement retained")
	lab._field_definition = runtime
	var original_helper: StadiumPoolOwnedFieldIntegrity = property._field_integrity_v68
	property._field_integrity_v68 = null
	_check(_route(context) == 0 and property.valid_owner(lab)
		and context.valid(property.pool_model, _runtime),
		"missing field helper selects and accepts original full Resource fallback")
	var custom_helper: CustomFieldHelper = CustomFieldHelper.new()
	property._field_integrity_v68 = custom_helper
	_check(_route(context) == 0 and context.valid(property.pool_model, _runtime)
		and custom_helper.calls == 0,
		"custom field helper uses original Resource fallback without virtual helper call")
	property._field_integrity_v68 = original_helper
	var fielder: FielderController = lab._primary_fielder
	var custom_fielder: CustomFielder = CustomFielder.new()
	lab._primary_fielder = custom_fielder
	_check(_route(context) == 0 and not property.valid_owner(lab),
		"custom fielder selects original route then original actor-ID guard rejects before tail")
	lab._primary_fielder = fielder
	custom_fielder.free()
	var resolver: BallPlayResolver = lab._ball_play_resolver
	lab._ball_play_resolver = CustomResolver.new()
	_check(_route(context) == 0 and not property.valid_owner(lab),
		"custom resolver selects original route then original actor-ID guard rejects before tail")
	lab._ball_play_resolver = resolver
	_check(_route(context) == 1 and context.valid(property.pool_model, _runtime),
		"restored domain objects retain original unpoisoned context")
	var carrier: Node3D = property.pool_model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var role: Variant = carrier.get_meta("volume_role")
	var custom_field: CustomField = CustomField.new()
	for name: StringName in [&"id", &"display_name", &"environment_style",
		&"fair_half_angle_degrees", &"safe_hit_z_m", &"deep_air_z_m", &"back_wall_z_m",
		&"home_run_height_m", &"dead_ball_z_m", &"shallow_anchor_z_m", &"middle_anchor_z_m",
		&"middle_center_anchor_z_m", &"deep_anchor_z_m", &"side_anchor_x_m",
		&"shallow_center_available", &"middle_center_available"]:
		custom_field.set(name, original.get(name))
	custom_field.target = carrier
	property.field = custom_field
	var before: int = custom_field.reads
	var route: int = _route(context)
	_check(route == 0 and custom_field.reads == before and carrier.get_meta("volume_role") == role,
		"unsupported custom field chooses fallback before getter or combined observation")
	var accepted: bool = context.valid(property.pool_model, _runtime)
	var after: int = custom_field.reads
	var mutated: bool = carrier.get_meta("volume_role") == "V74_FIELD_GETTER_MUTATION"
	property.field = original
	carrier.set_meta("volume_role", role)
	_check(not accepted and after > before and mutated and context._invalidated,
		"actual original full Resource getter runs, mutates model, rejects and poisons")
	_check(property.valid_owner(lab) and not context.valid(property.pool_model, _runtime),
		"restored field and model recover owner but cannot revive original context")
	_observe({"kind": "domain", "same_value_property_field": true,
		"custom_field_route": route, "getter_reads": after - before,
		"getter_mutated_model": mutated, "actor_tail_reached": false,
		"custom_field_helper_calls": custom_helper.calls, "context_poisoned": true})
	return await _finish_case(lab, {"plain_replacement_preserved": true,
		"original_helper_fallbacks": 2, "custom_actor_original_guard_rejections": 2,
		"field_getter_at_original_boundary": true})


func _helper_late_mutation() -> bool:
	var lab: PitchBatLab = _start_case("helper_late_mutation")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	var original: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var custom: ForwardingHelper = ForwardingHelper.new()
	custom.original = original
	custom.target = property.pool_model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var role: Variant = custom.target.get_meta("volume_role")
	property.integrity_policy2 = custom
	var accepted: bool = context.valid(property.pool_model, _runtime)
	var clean_calls: Array[String] = custom.calls.duplicate()
	_check(_route(context) == 0 and accepted and not context._invalidated
		and clean_calls == ["boundary", "ground", "inventory", "model"],
		"supported custom integrity replacement retains actual original virtual route and order")
	custom.calls.clear()
	custom.mutate = true
	var rejected: bool = not context.valid(property.pool_model, _runtime)
	var dirty_calls: Array[String] = custom.calls.duplicate()
	var mutated: bool = custom.target.get_meta("volume_role") == "V74_LATE_HELPER_MUTATION"
	custom.target.set_meta("volume_role", role)
	property.integrity_policy2 = original
	_check(rejected and mutated and context._invalidated
		and dirty_calls == ["boundary", "ground", "inventory", "model"],
		"late custom inventory mutation reaches original final model validator and poisons")
	_check(property.valid_owner(lab) and original.valid_model(property.pool_model)
		and not context.valid(property.pool_model, _runtime),
		"original helper and model restoration cannot revive poisoned Interior")
	_observe({"kind": "helper", "clean_accepted": accepted, "clean_calls": clean_calls,
		"mutated": mutated, "rejected": rejected, "dirty_calls": dirty_calls,
		"context_poisoned": context._invalidated})
	return await _finish_case(lab, {"custom_replacement_accepted": true,
		"late_inventory_mutation_rejected": true, "virtual_order_preserved": true})


func _model_poison() -> bool:
	var lab: PitchBatLab = _start_case("model_poison")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	var carrier: Node3D = property.pool_model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var role: Variant = carrier.get_meta("volume_role")
	carrier.set_meta("volume_role", "V74_MODEL_ONLY_MUTATION")
	_check(property.valid_owner(lab) and not context._invalidated,
		"default owner remains valid for model-only metadata before actual Interior boundary")
	var observed: bool = context.valid(property.pool_model, _runtime)
	carrier.set_meta("volume_role", role)
	_check(not observed and context._invalidated,
		"actual combined Interior valid rejects model-only mutation and permanently poisons")
	_check(property.valid_owner(lab) and property.integrity_policy2.valid_model(property.pool_model)
		and not context.valid(property.pool_model, _runtime)
		and not _case_adapter._prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime),
		"direct restoration preserves owner parity while original prepared context stays poisoned")
	_observe({"kind": "poison", "default_owner_allowed": true,
		"combined_rejected": not observed, "context_poisoned": context._invalidated,
		"direct_restored": true, "resealed": false})
	return await _finish_case(lab, {"model_only_poison": true, "direct_restoration": true})


func _natural_model_callback() -> bool:
	var lab: PitchBatLab = _start_case("natural_model_callback")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
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
	var carrier: Node3D = property.pool_model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var role: Variant = carrier.get_meta("volume_role")
	var downstream: Callable = guard._downstream
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
		carrier.set_meta("volume_role", "V74_POSTCALLBACK_MODEL_MUTATION")
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
	var original_owner: bool = property.valid_owner(lab)
	_check(_callback_seen and _callback_frame >= armed_frame
		and Engine.get_physics_frames() - armed_frame <= MAX_CALLBACK_FRAMES
		and Engine.get_physics_frames() - wait_start <= MAX_GUARD_FRAMES + MAX_CALLBACK_FRAMES
		and _callback_before == _callback_after and rejected_same_tick and original_owner
		and guard._generation_invalid and guard._context._invalidated
		and adapter.commits == commits and var_to_bytes(guard.receipts) == receipts,
		"real postcallback check freshly detects model-only mutation in the same physics tick")
	carrier.set_meta("volume_role", role)
	guard._downstream = downstream
	_check(property.valid_owner(lab) and not guard.valid() and guard._context._invalidated,
		"model restoration preserves owner but cannot revive guard after postcallback poison")
	_observe({"kind": "callback", "wait_start_frame": wait_start,
		"guard_observed_frame": observed_frame, "armed_frame": armed_frame,
		"mutation_frame": _callback_frame, "observed_frame": Engine.get_physics_frames(),
		"wait_frames": observed_frame - wait_start, "max_wait_frames": MAX_GUARD_FRAMES,
		"callback_frames": Engine.get_physics_frames() - armed_frame,
		"max_callback_frames": MAX_CALLBACK_FRAMES, "same_tick_rejected": rejected_same_tick,
		"original_owner_allowed": original_owner, "context_poisoned": guard._context._invalidated,
		"generation_invalid": guard._generation_invalid,
		"state_before_sha256": _callback_before.hex_encode().sha256_text(),
		"state_after_sha256": _callback_after.hex_encode().sha256_text(),
		"commits_unchanged": adapter.commits == commits, "receipts_unchanged":
			var_to_bytes(guard.receipts) == receipts})
	return await _finish_case(lab, {"ordinary_first_guard": true,
		"model_only_postcallback_mutation": true, "same_tick_rejection": rejected_same_tick})
