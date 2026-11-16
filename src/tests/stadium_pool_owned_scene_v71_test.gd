extends Node
## V71 finite owner-scene controls; standalone genuine V68 paid setup projection.
## Genuine paid setup, fixed existing fixture/seed, no trajectory or outcome claim.
# gdlint: disable=max-file-lines,max-returns,function-arguments-number

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const MATCH_SEED: int = 314229
const SUMMARY_LIMIT: int = 262144
const EXPECTED_INSTALLATIONS: int = 9
const EXPECTED_NATIVE_CHECKS: int = 227
const EXPECTED_OBSERVATIONS: int = 75
const OBSERVATION_CAP: int = 192
const FAILURE_LABEL_CAP: int = 384
const FAILURE_LABEL_BYTES: int = 256
const OBSERVATION_ROW_BYTES: int = 1536
const NATIVE_VALUE_BYTES: int = 256
const CASE_EXPECTED_CHECKS: Dictionary = {
	"admission": 15, "ordered_topology": 32, "inventory_discovery": 18,
	"live_guards": 33, "helper_world_fallback": 20, "ancestor_fallback": 10,
	"schema_fallback": 15, "native_values": 20, "context_poison": 15
}
const AncestorHook = preload("res://src/tests/stadium_pool_scene_v71_ancestor_inherited.gd")
const WorldHook = preload("res://src/tests/stadium_pool_scene_v71_world.gd")
const DescendantScript = preload("res://src/tests/stadium_pool_scene_v71_descendant.gd")
const PlainSchema = preload("res://src/tests/stadium_pool_scene_v71_schema_plain.gd")
const SCHEMA_PROBES: Array[GDScript] = [
	preload("res://src/tests/stadium_pool_scene_v71_schema_instance_mode.gd"),
	preload("res://src/tests/stadium_pool_scene_v71_schema_instance_thread.gd"),
	preload("res://src/tests/stadium_pool_scene_v71_schema_static_mode.gd"),
	preload("res://src/tests/stadium_pool_scene_v71_schema_static_thread.gd")
]

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

class RouteProbe extends StadiumPoolOwnedIntegrity:
	var calls: Array[String] = []

	func valid_boundary(_boundary: Node3D) -> bool:
		calls.append("boundary")
		return true

	func valid_ground(_ground: StaticBody3D) -> bool:
		calls.append("ground")
		return true

	func valid_inventory(_lab_node: Node3D) -> bool:
		calls.append("inventory")
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
		if argument.begins_with("--pool-owned-scene-v71-dir="):
			_output = argument.trim_prefix("--pool-owned-scene-v71-dir=")
		if argument.begins_with("--pool-owned-scene-v71-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-owned-scene-v71-runtime=")
		if argument.begins_with("--pool-owned-scene-v71-execution="):
			_execution = argument.trim_prefix("--pool-owned-scene-v71-execution=")
		if argument.begins_with("--pool-owned-scene-v71-nonce="):
			_nonce = argument.trim_prefix("--pool-owned-scene-v71-nonce=")
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
		"reused_regressions": {"integrity": 569, "ledger": 190, "contact": 68, "field": 334},
		"scene_observations": _observations, "observations_complete": _observations_complete,
		"expected_observations": EXPECTED_OBSERVATIONS,
		"source_text_policy": "RESTORE_TEXT_WITHOUT_RELOADING_LIVE_SCRIPTS",
		"compiled_reload_history_qualified": false,
		"caps": {"observations": OBSERVATION_CAP, "row_bytes": OBSERVATION_ROW_BYTES,
			"native_value_bytes": NATIVE_VALUE_BYTES, "summary_bytes": SUMMARY_LIMIT,
			"failure_labels": FAILURE_LABEL_CAP, "failure_label_bytes": FAILURE_LABEL_BYTES},
		"qualification": "finite admitted owner-scene, original fallback, and restoration controls only",
		"production_qualified": false, "report_settlement_qualified": false,
		"performance_qualified": false, "rendered_qualified": false}
	if _output_admitted:
		var encoded: String = JSON.stringify(summary, "", true, true)
		if encoded.to_utf8_buffer().size() <= SUMMARY_LIMIT:
			var output: FileAccess = FileAccess.open(
				_output.path_join("pool-owned-scene-v71-summary.json"), FileAccess.WRITE)
			if output != null:
				output.store_string(encoded)
				if output.get_error() != OK:
					_check(false, "summary output write failed")
				output.close()
			else:
				_check(false, "summary output could not open")
		else:
			_check(false, "summary exceeds fixed byte cap")
	print("POOL_OWNED_SCENE_V71 checks=%d failures=%d starts=%d cleanups=%d source=%s" % [
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
	for method: StringName in [&"_admission", &"_ordered_topology", &"_inventory_discovery",
		&"_live_guards", &"_helper_world_fallback", &"_ancestor_fallback",
		&"_schema_fallback", &"_native_values", &"_context_poison"]:
		if not await call(method):
			return
	_all_preserved = (_starts == EXPECTED_INSTALLATIONS and _cleanups == EXPECTED_INSTALLATIONS
		and _rows.size() == EXPECTED_INSTALLATIONS and _reports == 0 and _runner_errors.is_empty()
		and _unchanged() and _ledger == null and StadiumPoolHotpathProfile.active == null
		and _observations_complete and _observations.size() == EXPECTED_OBSERVATIONS)
	_check(_all_preserved, "all disposable installations retire without settlement or caller mutation")


func _hot(helper: StadiumPoolOwnedIntegrity, lab: PitchBatLab,
	property: StadiumPoolOwnedProperty) -> bool:
	return StadiumPoolOwnedIntegrity.owner_scene_matches(helper, lab, property,
		property.boundary, property.ground_body, property._boundary_ids, property._ground_ids)


func _capture(lab: PitchBatLab, property: StadiumPoolOwnedProperty) -> StadiumPoolOwnedIntegrity:
	# Separate oracle for a deliberately unsupported or internal-child scene.
	# Never replace paid installation authority or original seals with this capture.
	return StadiumPoolOwnedIntegrity.capture(lab, property, property.pool_model,
		property.boundary, property.ground_body, property.receiver.chair)


func _admitted(lab: PitchBatLab, property: StadiumPoolOwnedProperty) -> bool:
	var helper: StadiumPoolOwnedIntegrity = property.integrity_policy2
	return _check(StadiumPoolOwnedIntegrity.owner_scene_admitted(helper)
		and helper.get_script() == StadiumPoolOwnedIntegrity
		and not helper._owner_scene_nodes.is_empty() and _hot(helper, lab, property),
		_case_name + ": exact paid installation actually selects nonempty optimized plan")


func _scene_result(label: String, lab: PitchBatLab,
	property: StadiumPoolOwnedProperty, expected: bool, cold_agrees: bool = true) -> void:
	var hot: bool = _hot(property.integrity_policy2, lab, property)
	var owner: bool = property.valid_owner(lab)
	var cold: bool = property.full_capture_valid(lab)
	_check(hot == expected and owner == expected and (not cold_agrees or cold == expected)
		and not _case_adapter._prepared.context._invalidated,
		label + ": direct finite/original owner predicates, without poisoning")
	_observe({"kind": "scene", "case": _case_name, "label": label,
		"hot": hot, "owner": owner, "cold": cold, "expected": expected,
		"cold_agrees": cold_agrees})


func _shadow_result(label: String, helper: StadiumPoolOwnedIntegrity, lab: PitchBatLab,
	property: StadiumPoolOwnedProperty, expected: bool) -> void:
	var hot: bool = _hot(helper, lab, property)
	var original: bool = helper.valid_inventory(lab)
	_check(hot == expected and original == expected,
		label + ": independent captured topology and original inventory agree")
	_observe({"kind": "topology", "case": _case_name, "label": label,
		"hot": hot, "original": original, "expected": expected})


func _admission() -> bool:
	var lab: PitchBatLab = _start_case("admission")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var helper: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var unique: Dictionary = {}
	for record: Dictionary in helper._owner_scene_nodes:
		unique[record.id] = true
	var role_count: int = helper._owner_scene_topology.size() + helper._owner_scene_boundary.size()
	for role: PackedInt32Array in helper._owner_scene_bodies.values():
		role_count += role.size()
	_check(unique.size() == helper._owner_scene_nodes.size()
		and helper._owner_scene_nodes.size() < role_count
		and unique.size() <= 4096 and role_count <= 16384,
		"actual finite plan reuses identities across overlapping roles")
	var grass: Node = property.get_node_or_null("OwnedSurfaceFinish/GrassTufts")
	var grass_id: int = grass.get_instance_id() if grass != null else 0
	var grass_index: int = helper._owner_scene_index.get(grass_id, -1)
	var authored_grass_in_plan: bool = grass != null \
		and grass.get_class() == "MultiMeshInstance3D" and grass.get_script() == null \
		and grass_index >= 0 and grass_index < helper._owner_scene_nodes.size() \
		and helper._owner_scene_nodes[grass_index].id == grass_id \
		and helper._owner_scene_nodes[grass_index].ref.get_ref() == grass \
		and helper._owner_scene_nodes[grass_index].native == "MultiMeshInstance3D" \
		and helper._owner_scene_nodes[grass_index].script == null \
		and helper._owner_scene_topology.has(grass_index)
	_check(authored_grass_in_plan,
		"authored plain GrassTufts MultiMesh is in optimized owner-scene identity and topology plan")
	_scene_result("unchanged first call", lab, property, true)
	_scene_result("unchanged independent next call", lab, property, true)
	_check(helper.valid_inventory(lab) and helper.valid_boundary(property.boundary)
		and helper.valid_ground(property.ground_body) and helper.valid_body(property.ground_body)
		and helper.valid_model(property.pool_model) and property.full_capture_valid(lab)
		and helper.audit_receipt().body_count == helper._body_bytes.size(),
		"independent original standalone methods, cold owner and installation receipt preserved")
	var script_id: int = helper.get_script().get_instance_id()
	var world_id: int = property.get_world_3d().get_instance_id()
	_check(script_id != 0 and world_id != 0 and typeof(script_id) == TYPE_INT
		and typeof(world_id) == TYPE_INT and var_to_bytes(script_id) == var_to_bytes(
			StadiumPoolOwnedIntegrity._script_id(helper)),
		"native RefCounted identifiers preserve signed int values without positivity assumptions")
	return await _finish_case(lab, {"optimized_selected": true, "fresh_calls": 2,
		"planned_nodes": unique.size(), "role_memberships": role_count,
		"authored_grass_in_plan": authored_grass_in_plan})


func _ordered_topology() -> bool:
	var lab: PitchBatLab = _start_case("ordered_topology")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var original: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var root: Node = Node.new()
	root.name = "V71OrderedProbe"
	property.add_child(root)
	var normal: Array[Node] = [Node.new(), Node.new()]
	var internal: Array[Node] = [Node.new(), Node.new()]
	normal[0].name = "NormalFirst"
	normal[1].name = "NormalSecond"
	internal[0].name = "InternalFirst"
	internal[1].name = "InternalSecond"
	for node: Node in normal:
		root.add_child(node)
	for node: Node in internal:
		root.add_child(node, false, Node.INTERNAL_MODE_BACK)
	var shadow: StadiumPoolOwnedIntegrity = _capture(lab, property)
	_check(shadow != null and StadiumPoolOwnedIntegrity.owner_scene_admitted(shadow)
		and _hot(shadow, lab, property) and shadow.valid_inventory(lab)
		and root.get_child_count(false) == 2 and root.get_child_count(true) == 4,
		"separate cold oracle admits both actual normal and internal ordered children")
	_check(property.integrity_policy2 == original and not _hot(original, lab, property),
		"probe capture never refreshes original installed authority or seals")
	for is_internal: bool in [false, true]:
		var children: Array[Node] = internal if is_internal else normal
		var mode: Node.InternalMode = (
			Node.INTERNAL_MODE_BACK if is_internal else Node.INTERNAL_MODE_DISABLED)
		var prefix: String = "internal" if is_internal else "normal"
		var added: Node = Node.new()
		root.add_child(added, false, mode)
		_shadow_result(prefix + " addition", shadow, lab, property, false)
		root.remove_child(added)
		added.free()
		_shadow_result(prefix + " addition restored", shadow, lab, property, true)
		root.remove_child(children[0])
		_shadow_result(prefix + " removal", shadow, lab, property, false)
		root.add_child(children[0], false, mode)
		root.move_child(children[0], 0)
		_shadow_result(prefix + " removal restored", shadow, lab, property, true)
		root.move_child(children[0], 1)
		_shadow_result(prefix + " reorder", shadow, lab, property, false)
		root.move_child(children[0], 0)
		_shadow_result(prefix + " reorder restored", shadow, lab, property, true)
		root.remove_child(children[0])
		children[1].add_child(children[0], false, mode)
		_shadow_result(prefix + " reparent", shadow, lab, property, false)
		children[1].remove_child(children[0])
		root.add_child(children[0], false, mode)
		root.move_child(children[0], 0)
		_shadow_result(prefix + " reparent restored", shadow, lab, property, true)
		var replacement: Node = Node.new()
		var original_name: StringName = children[0].name
		root.remove_child(children[0])
		replacement.name = original_name
		root.add_child(replacement, false, mode)
		root.move_child(replacement, 0)
		_shadow_result(prefix + " count-preserving replacement", shadow, lab, property, false)
		root.remove_child(replacement)
		replacement.free()
		root.add_child(children[0], false, mode)
		root.move_child(children[0], 0)
		_shadow_result(prefix + " replacement restored", shadow, lab, property, true)
	property.remove_child(root)
	root.free()
	_scene_result("original installed topology restored without resealing", lab, property, true)
	return await _finish_case(lab, {"child_classes": 2, "mutations": 10,
		"restorations": 10, "separate_captures": 1, "installed_helper_replaced": false})


func _inventory_discovery() -> bool:
	var lab: PitchBatLab = _start_case("inventory_discovery")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var area: Area3D = Area3D.new()
	lab.add_child(area)
	_scene_result("outside-property Area remains allowed", lab, property, true)
	lab.remove_child(area)
	area.free()
	_scene_result("outside-property Area removed", lab, property, true)
	var static_body: StaticBody3D = StaticBody3D.new()
	lab.add_child(static_body)
	_scene_result("new StaticBody outside property found by whole-lab discovery", lab, property, false)
	lab.remove_child(static_body)
	static_body.free()
	_scene_result("external StaticBody removed", lab, property, true)
	var inserted: Area3D = Area3D.new()
	property.add_child(inserted)
	_scene_result("property collision-object insertion", lab, property, false)
	property.remove_child(inserted)
	inserted.free()
	_scene_result("property collision-object removal", lab, property, true)
	var body: StaticBody3D = null
	for candidate: StaticBody3D in lab.find_children("*", "StaticBody3D", true, false):
		if candidate != property.ground_body and not property.boundary.is_ancestor_of(candidate):
			body = candidate
			break
	_check(body != null, "actual non-ground non-boundary inventoried body exists")
	if body != null:
		var original: Transform3D = body.transform
		body.position.x += 0.125
		_scene_result("non-boundary body pose", lab, property, false)
		body.transform = original
		_scene_result("non-boundary body pose restored", lab, property, true)
	return await _finish_case(lab, {"outside_area_allowed": true,
		"whole_lab_body_discovery": true, "property_collision_rejected": true,
		"non_boundary_body_restored": true})


func _live_guards() -> bool:
	# Move only the empty runner. Never reparent an installed paid property subtree.
	var ancestor: Node = Node.new()
	add_child(ancestor)
	_runner.reparent(ancestor)
	var lab: PitchBatLab = _start_case("live_guards")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var helper: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var sources: Array[GDScript] = [property.get_script(), property.get_script().get_base_script(),
		property.boundary.get_script(), get_script()]
	for script: GDScript in sources:
		var original: String = script.source_code
		script.source_code = original + "\n# V71 source-text-only guard probe\n"
		var changed: String = script.source_code
		var rejected: bool = not _hot(helper, lab, property) and not property.valid_owner(lab)
		# Always restore before assertions, observations, returns or yielding. No reload.
		script.source_code = original
		_check(changed != original and rejected, "live admitted source text rejects before payload")
		_check(script.source_code == original and _hot(helper, lab, property)
			and property.valid_owner(lab), "exact source text restoration accepts fresh call")
		_observe({"kind": "source", "case": _case_name,
			"path": script.resource_path, "rejected": rejected, "restored": script.source_code == original,
			"original_sha256": original.sha256_text(), "changed_sha256": changed.sha256_text(),
			"reload_performed": false})
	var model_ref: WeakRef = helper._model_ref
	helper._model_ref = weakref(property.receiver.chair)
	_scene_result("live helper model role corruption", lab, property, false, false)
	helper._model_ref = model_ref
	_scene_result("live helper model role restored", lab, property, true)
	for field: StringName in [&"_receiver_id", &"_receiver_visual_id"]:
		var original: int = helper.get(field)
		helper.set(field, 0)
		_scene_result("live helper " + String(field), lab, property, false, false)
		helper.set(field, original)
		_scene_result("restored helper " + String(field), lab, property, true)
	var node_id: int = property.boundary.get_instance_id()
	var original_script: int = helper._node_scripts[node_id]
	helper._node_scripts[node_id] = 0
	_scene_result("current script registry changed", lab, property, false)
	helper._node_scripts[node_id] = original_script
	_scene_result("current script registry value restored", lab, property, true)
	helper._node_scripts.erase(node_id)
	_scene_result("current script registry entry removed", lab, property, false)
	helper._node_scripts[node_id] = original_script
	_scene_result("current script registry entry restored", lab, property, true)
	var chair: Node3D = property.receiver.chair
	chair.set_script(DescendantScript)
	_scene_result("live planned node script attachment", lab, property, false)
	chair.set_script(null)
	_scene_result("live planned node script restored", lab, property, true)
	ancestor.set_script(AncestorHook)
	var before: int = ancestor.get("payload_reads")
	var ancestor_rejected: bool = not _hot(helper, lab, property) and not property.valid_owner(lab)
	var after: int = ancestor.get("payload_reads")
	ancestor.set_script(null)
	_check(ancestor_rejected and after == before,
		"live ancestor script attachment rejects before named-property hook reads")
	_scene_result("live ancestor script restored", lab, property, true)
	_observe({"kind": "guard", "case": _case_name, "label": "ancestor script",
		"rejected": ancestor_rejected, "reads_before": before, "reads_after": after})
	var world: World3D = property.get_world_3d()
	world.set_script(WorldHook)
	before = world.get("payload_reads")
	var world_rejected: bool = not _hot(helper, lab, property) and not property.valid_owner(lab)
	after = world.get("payload_reads")
	world.set_script(null)
	_check(world_rejected and after == before,
		"live world script attachment rejects before World3D.space hook reads")
	_scene_result("live world script restored", lab, property, true)
	_observe({"kind": "guard", "case": _case_name, "label": "world script",
		"rejected": world_rejected, "reads_before": before, "reads_after": after})
	var result: bool = await _finish_case(lab, {"source_edits": 4, "reloads": 0,
		"role_registry_mutations": 5, "node_script_mutations": 1, "guarded_hooks": 2})
	_runner.reparent(self)
	ancestor.free()
	return result


func _helper_world_fallback() -> bool:
	var lab: PitchBatLab = _start_case("helper_world_fallback")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var original: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var custom: RouteProbe = RouteProbe.new()
	custom._owner_scene_admitted = true
	_check(not StadiumPoolOwnedIntegrity.owner_scene_admitted(custom)
		and not _hot(custom, lab, property) and custom.calls.is_empty(),
		"nonexact helper rejected before reading deliberately empty optimized plan")
	property.integrity_policy2 = custom
	var fallback: bool = property._policy_scene_valid(lab, false)
	property.integrity_policy2 = original
	_check(fallback and custom.calls == ["boundary", "ground", "inventory"],
		"actual property seam preserves original custom-helper virtual route and order")
	_observe({"kind": "fallback", "case": _case_name, "label": "helper subclass",
		"admitted": false, "fallback": fallback, "calls": custom.calls})
	var child: Node3D = Node3D.new()
	child.set_script(DescendantScript)
	property.add_child(child)
	var unsupported: StadiumPoolOwnedIntegrity = _capture(lab, property)
	_check(unsupported != null and not StadiumPoolOwnedIntegrity.owner_scene_admitted(unsupported)
		and not _hot(unsupported, lab, property) and unsupported.valid_inventory(lab),
		"unknown scripted descendant captures original seals but cannot select finite route")
	property.integrity_policy2 = unsupported
	fallback = property._policy_scene_valid(lab, false)
	property.integrity_policy2 = original
	_check(fallback, "unsupported descendant installation uses complete original property seam")
	property.remove_child(child)
	child.free()
	_scene_result("unsupported descendant removed and original helper retained", lab, property, true)
	_observe({"kind": "fallback", "case": _case_name, "label": "scripted descendant",
		"admitted": false, "fallback": fallback, "calls": []})
	var marker: Marker3D = Marker3D.new()
	property.add_child(marker)
	unsupported = _capture(lab, property)
	_check(unsupported != null and not StadiumPoolOwnedIntegrity.owner_scene_admitted(unsupported)
		and not _hot(unsupported, lab, property) and unsupported.valid_inventory(lab),
		"unsupported native Marker3D captures original seals but cannot select finite route")
	property.integrity_policy2 = unsupported
	fallback = property._policy_scene_valid(lab, false)
	property.integrity_policy2 = original
	_check(fallback, "unsupported native descendant uses original property seam")
	property.remove_child(marker)
	marker.free()
	_scene_result("unsupported native descendant removed", lab, property, true)
	_observe({"kind": "fallback", "case": _case_name, "label": "native descendant",
		"admitted": false, "fallback": fallback, "calls": []})
	var world: World3D = property.get_world_3d()
	world.set_script(WorldHook)
	unsupported = _capture(lab, property)
	var before: int = world.get("payload_reads")
	var not_admitted: bool = unsupported != null \
		and not StadiumPoolOwnedIntegrity.owner_scene_admitted(unsupported)
	var finite_rejected: bool = not _hot(unsupported, lab, property)
	var after: int = world.get("payload_reads")
	property.integrity_policy2 = unsupported
	fallback = property._policy_scene_valid(lab, false)
	property.integrity_policy2 = original
	world.set_script(null)
	_check(not_admitted and finite_rejected and after == before,
		"scripted world installation rejects finite route before optimized payload reads")
	_check(fallback, "scripted world installation uses original complete scene route")
	_scene_result("plain world restored against original installed helper", lab, property, true)
	_observe({"kind": "fallback", "case": _case_name, "label": "scripted world",
		"admitted": not not_admitted, "fallback": fallback, "calls": [],
		"reads_before": before, "reads_after": after})
	return await _finish_case(lab, {"helper_subclass": true, "unknown_descendant": true,
		"scripted_world": true, "unsupported_native": true,
		"original_route_order": ["boundary", "ground", "inventory"]})


func _ancestor_fallback() -> bool:
	var ancestor: Node = AncestorHook.new()
	add_child(ancestor)
	_runner.reparent(ancestor)
	var lab: PitchBatLab = _start_case("ancestor_fallback")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var helper: StadiumPoolOwnedIntegrity = property.integrity_policy2
	var before: int = ancestor.get("payload_reads")
	var admitted: bool = StadiumPoolOwnedIntegrity.owner_scene_admitted(helper)
	var optimized: bool = _hot(helper, lab, property)
	var after: int = ancestor.get("payload_reads")
	_check(not admitted and not optimized and after == before,
		"real inherited ancestor _get installation falls back before optimized payload reads")
	var ancestor_script: GDScript = AncestorHook
	_check(ancestor_script.has_source_code() and ancestor_script.get_base_script().has_source_code()
		and helper.valid_inventory(lab) and property.valid_owner(lab)
		and property.full_capture_valid(lab),
		"source-bearing inherited hook retains actual complete original live and cold routes")
	_observe({"kind": "fallback", "case": _case_name, "label": "inherited ancestor hook",
		"admitted": admitted, "fallback": property._policy_scene_valid(lab, false), "calls": [],
		"reads_before": before, "reads_after": after})
	var result: bool = await _finish_case(lab, {"inherited_get": true,
		"optimized_hook_reads": after - before, "original_capture_reads_permitted": true})
	_runner.reparent(self)
	ancestor.free()
	return result


func _schema_fallback() -> bool:
	var lab: PitchBatLab = _start_case("schema_fallback")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var schema: StadiumPoolOwnedIntegrity = StadiumPoolOwnedIntegrity.new()
	var plain_script: GDScript = PlainSchema
	_check(plain_script.has_source_code() and plain_script.can_instantiate()
		and schema._owner_scene_ancestor_script(plain_script),
		"detached source-bearing plain RefCounted script passes ancestor schema control")
	for script: GDScript in SCHEMA_PROBES:
		var value: RefCounted = script.new()
		var before: int = script.get("reads")
		var source_valid: bool = script.has_source_code() and script.can_instantiate()
		var eligible: bool = schema._owner_scene_ancestor_script(script)
		var after: int = script.get("reads")
		_check(source_valid and not eligible and after == before and value != null,
			"actual instance/static process-property schema excluded without getters")
		_observe({"kind": "schema", "case": _case_name, "path": script.resource_path,
			"has_source": source_valid, "eligible": eligible,
			"reads_before": before, "reads_after": after})
	_scene_result("detached schema probes leave real admitted installation unchanged",
		lab, property, true)
	return await _finish_case(lab, {"detached_schema_probes": 4,
		"positive_schema_controls": 1, "getter_calls": 0, "native_shadow_declarations": false})


func _native_values() -> bool:
	var lab: PitchBatLab = _start_case("native_values")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var node: Node = Node.new()
	var positive: float = _runtime_float("0000000000000000")
	var negative: float = _runtime_float("0000000000000080")
	_check(_float_bytes(positive) == "0000000000000000"
		and _float_bytes(negative) == "0000000000000080",
		"signed-zero probes constructed from runtime IEEE64 bytes")
	for pair: Array in [[positive, negative], ["v71", StringName("v71")], [1, 1.0]]:
		node.set_meta(&"surface_id", pair[0])
		var first: PackedByteArray = var_to_bytes(StadiumPoolOwnedIntegrity._metadata_compact(node))
		node.set_meta(&"surface_id", pair[1])
		var second: PackedByteArray = var_to_bytes(StadiumPoolOwnedIntegrity._metadata_compact(node))
		_check(first != second and first.size() > 0 and second.size() > 0,
			"actual owner metadata serialization retains native type/signed-zero distinction")
		_observe({"kind": "native", "case": _case_name,
			"first": _native(pair[0]), "second": _native(pair[1]), "distinct": first != second})
	var descriptor: Dictionary = {}
	for index: int in range(12):
		descriptor[str(index)] = index
	node.set_meta(&"descriptor", descriptor)
	var compact: Array = StadiumPoolOwnedIntegrity._metadata_compact(node)
	var descriptor_index: int = StadiumPoolOwnedIntegrity.META_KEYS.find(&"descriptor") * 2 + 1
	descriptor["0"] = 7
	_check(not compact.is_empty() and compact[descriptor_index]["0"] == 7
		and StadiumPoolOwnedIntegrity._descriptor_shape(descriptor),
		"actual compact metadata retains descriptor alias before serialization")
	descriptor["0"] = StringName("invalid descriptor value")
	_check(StadiumPoolOwnedIntegrity._metadata_compact(node).is_empty(),
		"native StringName descriptor value rejected by unchanged descriptor semantics")
	descriptor["0"] = PackedVector2Array([Vector2(1, 2)])
	_check(not StadiumPoolOwnedIntegrity._metadata_compact(node).is_empty(),
		"native packed-vector descriptor encoding accepted")
	var box: BoxShape3D = BoxShape3D.new()
	var convex: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	convex.points = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK])
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP]))
	for shape: Shape3D in [box, convex, concave]:
		var encoded: Array = StadiumPoolOwnedIntegrity._shape(shape)
		_check(encoded.size() == 4 and encoded[0] == shape.get_class()
			and typeof(encoded[3]) == TYPE_ARRAY and not encoded[3].is_empty(),
			"unchanged actual supported native shape encoding")
		_observe({"kind": "shape", "case": _case_name, "native_class": shape.get_class(),
			"shape_id": str(shape.get_instance_id()), "encoded_bytes": var_to_bytes(encoded).size()})
	node.free()
	_scene_result("native serialization probes leave real paid authority unchanged",
		lab, property, true)
	return await _finish_case(lab, {"primitive_distinctions": 3, "descriptor_controls": 3,
		"shape_encodings": 3, "refcounted_ids_use_nonzero_not_positive": true})


func _context_poison() -> bool:
	var lab: PitchBatLab = _start_case("context_poison")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _admitted(lab, property):
		return await _finish_case(lab)
	var context: StadiumPoolInteriorV2 = _case_adapter._prepared.context
	var original: Transform3D = property.ground_body.transform
	property.ground_body.position.x += 0.125
	_scene_result("first direct ground mutation", lab, property, false)
	property.ground_body.transform = original
	_scene_result("first direct ground restoration", lab, property, true)
	property.ground_body.position.x += 0.125
	_scene_result("same-call-state second mutation has no cached success", lab, property, false)
	var observed: bool = context.valid(property.pool_model, _runtime)
	var poisoned: bool = context._invalidated
	property.ground_body.transform = original
	_check(not observed and poisoned, "actual InteriorV2 observation latches invalidation")
	_check(_hot(property.integrity_policy2, lab, property) and property.valid_owner(lab)
		and property.full_capture_valid(lab),
		"exact direct scene restoration recovers original seals without recapture")
	_check(not context.valid(property.pool_model, _runtime) and context._invalidated
		and not _case_adapter._prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime),
		"direct restoration cannot resurrect poisoned original prepared context")
	_observe({"kind": "poison", "case": _case_name, "direct_restored": true,
		"context_rejected": not observed, "invalidated": poisoned, "resealed": false})
	return await _finish_case(lab, {"mutations": 2, "direct_restorations": 2,
		"context_poisoned": true, "same_frame_fresh_validation": true})
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
