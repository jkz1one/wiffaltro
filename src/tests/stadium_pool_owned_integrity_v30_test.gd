extends Node
## Owned policy2 finite controls on the genuine paid fixture. No fabricated baseball outcomes.
## Every mutation installation is disposable; ordinary preparation/context/guard paths decide.
# gdlint: disable=max-file-lines,max-returns,function-arguments-number

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const MATCH_SEED: int = 314229
const MAX_GUARD_FRAMES: int = 1800
const MAX_CALLBACK_FRAMES: int = 2
const SUMMARY_LIMIT: int = 262144
const EXPECTED_INSTALLATIONS: int = 16
const EXPECTED_NATIVE_CHECKS: int = 569
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
	"direct_restore_matrix": 350,
	"visual_positive_pool": 17,
	"visual_positive_ground": 14,
	"visual_positive_boundary": 14,
	"early_preparation_restore": 7,
	"context_poison_descriptor": 8,
	"context_poison_carrier_transform": 8,
	"context_poison_model_transform": 7,
	"context_poison_model_scale": 7,
	"context_poison_carrier_replacement": 7,
	"context_poison_model_parent": 7,
	"context_poison_wrong_source": 7,
	"context_poison_water_metadata": 7,
	"context_poison_root_metadata": 7,
	"observable_world_change": 6,
	"natural_guard_and_same_tick_callback": 48
}
const ResourceProbe = preload(
	"res://src/tests/stadium_pool_owned_integrity_v30_resource_probe.gd")
const MutationScript = preload("res://src/tests/stadium_pool_owned_integrity_v30_probe.gd")

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
var _callback_seen: bool = false
var _callback_frame: int = -1
var _callback_before: PackedByteArray
var _callback_after: PackedByteArray
var _live_guard: StadiumPoolWaterGuard
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


func _ready() -> void:
	_wall_start = Time.get_ticks_usec()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-owned-integrity-v30-dir="):
			_output = argument.trim_prefix("--pool-owned-integrity-v30-dir=")
		if argument.begins_with("--pool-owned-integrity-v30-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-owned-integrity-v30-runtime=")
		if argument.begins_with("--pool-owned-integrity-v30-execution="):
			_execution = argument.trim_prefix("--pool-owned-integrity-v30-execution=")
		if argument.begins_with("--pool-owned-integrity-v30-nonce="):
			_nonce = argument.trim_prefix("--pool-owned-integrity-v30-nonce=")
	await _run_controls()
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
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
		"qualification": "disposable gameplay-integrity controls only",
		"production_qualified": false, "report_settlement_qualified": false,
		"performance_qualified": false, "rendered_qualified": false}
	if _output_admitted:
		var encoded: String = JSON.stringify(summary, "", true, true)
		if encoded.to_utf8_buffer().size() <= SUMMARY_LIMIT:
			var output: FileAccess = FileAccess.open(
				_output.path_join("pool-owned-integrity-v30-summary.json"), FileAccess.WRITE)
			if output != null:
				output.store_string(encoded)
				output.close()
			else:
				_check(false, "summary output could not open")
		else:
			_check(false, "summary exceeds fixed byte cap")
	print("POOL_OWNED_INTEGRITY_V30 checks=%d failures=%d starts=%d cleanups=%d source=%s" % [
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
	_ledger = ClubPlayers.assets(_app.season.career)
	if not _check(fixture == FIXTURE
		and SeasonPhysicalFixtures.seed_for(_app.season, fixture) == MATCH_SEED
		and _source != null and _ledger != null
		and StadiumPoolOwnedSnapshot.valid(_source.stadium)
		and StadiumPoolOwnedSnapshot.matches(_source.stadium, _ledger)
		and _source.stadium.environment.fixture == fixture.id
		and _source.stadium.environment.seed == MATCH_SEED,
		"real scheduled paid fixture17 before disposable runner starts"):
		return
	_season_bytes = var_to_bytes(SeasonSave.snapshot(_app.season))
	_ledger_bytes = var_to_bytes(_ledger.to_data())
	_source_bytes = var_to_bytes(_profile_object_data(_source))
	_saved_files = _saved()
	_runner = PhysicalMatchRunner.new()
	add_child(_runner)
	_runner.finished.connect(func(_report: Dictionary) -> void: _reports += 1)
	_runner.private_finished.connect(func(_report: Dictionary) -> void: _reports += 1)
	_runner.failed.connect(func(reason: String) -> void: _runner_errors.append(reason))
	if not _check(not _runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID)
		and _runner._lab == null and _runner._viewport == null,
		"paid fixture refuses missing held ledger without creating a lab"):
		return
	var forged: MatchState = PhysicalMatchRequest.capture(_source)
	forged.stadium.layout.pool.copy = "not-a-paid-copy"
	if not _check(not _runner.start(forged, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger)
		and _runner._lab == null and _runner._viewport == null and _unchanged(),
		"forged owned copy refuses before installation and preserves paid original"):
		return
	if not await _direct_controls():
		return
	for target: String in ["pool", "ground", "boundary"]:
		if not await _visual_controls(target):
			return
	if not await _early_preparation_restore():
		return
	for mutation: String in ["descriptor", "carrier_transform", "model_transform",
		"model_scale", "carrier_replacement", "model_parent", "wrong_source",
		"water_metadata", "root_metadata"]:
		if not await _context_poison(mutation):
			return
	if not await _world_poison():
		return
	if not await _natural_guard_controls():
		return
	_all_preserved = (_starts == EXPECTED_INSTALLATIONS and _cleanups == EXPECTED_INSTALLATIONS
		and _rows.size() == EXPECTED_INSTALLATIONS and _reports == 0 and _runner_errors.is_empty()
		and _unchanged() and StadiumPoolHotpathProfile.active == null)
	_check(_all_preserved,
		"all disposable installations cleanly retired without settlement or caller mutation")


func _start_case(label: String) -> PitchBatLab:
	_case_name = label
	_case_check_start = _checks
	_case_failure_start = _failures
	var frame: int = Engine.get_physics_frames()
	if not _check(_runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger),
		label + ": fresh actual paid runner start"):
		return null
	_starts += 1
	var lab: PitchBatLab = _runner._lab
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _check(property != null and property.valid_owner(lab)
		and lab._stadium_ledger == _ledger and lab._automation.releases.is_empty()
		and lab._play_records.is_empty() and Engine.get_physics_frames() == frame
		and lab.pool_controller_active != null and lab.pool_controller_active.enabled
		and lab.pool_controller_active._prepared != null
		and lab.pool_controller_active._prepared.valid(property.pool_model,
			StadiumPoolContract.LIVE, _runtime) and _unchanged(),
		label + ": actual ordinary authority valid before first physics tick"):
		return null
	return lab


func _finish_case(lab: PitchBatLab, detail: Dictionary = {}) -> bool:
	var live: WeakRef = weakref(lab)
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var property_live: WeakRef = weakref(property)
	var token: StadiumPoolBoundEntitlement = property.entitlement
	_runner.cancel()
	await get_tree().process_frame
	var cleared: bool = (live.get_ref() == null and property_live.get_ref() == null
		and _runner._lab == null and _runner._viewport == null and not _runner._running
		and _runner.get_child_count() == 0 and not adapter.enabled and adapter._lab == null)
	var preserved: bool = _unchanged() if cleared else false
	_check(cleared and preserved and _reports == 0,
		_case_name + ": cancellation disposes authority and leaves season/save/ledger unchanged")
	if cleared:
		_cleanups += 1
	# Never dereference a freed scene node; the retained token is a RefCounted lifetime object.
	var retired: bool = token._owner != null and token._owner.get_ref() == null
	_check(retired,
		_case_name + ": retired paid token cannot authorize a later installation")
	_check(CASE_EXPECTED_CHECKS.has(_case_name)
		and _checks - _case_check_start + 1 == CASE_EXPECTED_CHECKS[_case_name],
		_case_name + ": exact source-derived successful case check total")
	detail.merge({"disposed": cleared, "source_save_ledger_season_preserved": preserved,
		"paid_token_owner_released": retired})
	_rows.append({"case": _case_name, "checks": _checks - _case_check_start,
		"failures": _failures - _case_failure_start, "detail": detail})
	return _failures == _case_failure_start


func _saved() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			var target: String = path + suffix
			result[target] = FileAccess.get_file_as_bytes(target) \
				if FileAccess.file_exists(target) else null
	return result


func _unchanged() -> bool:
	return var_to_bytes(SeasonSave.snapshot(_app.season)) == _season_bytes \
		and var_to_bytes(_ledger.to_data()) == _ledger_bytes \
		and var_to_bytes(_profile_object_data(_source)) == _source_bytes \
		and var_to_bytes(_saved()) == var_to_bytes(_saved_files) \
		and _app.season.pending_fixture().id == 0 and _app.season.round_index == 0


func _originals(property: StadiumPoolOwnedProperty) -> Array:
	return [property._ground_bytes.duplicate(), property._boundary_bytes.duplicate(),
		property._static_bytes.duplicate()]


func _first_body(root: Node) -> StaticBody3D:
	if root is StaticBody3D:
		return root
	for child: Node in root.get_children(true):
		var found: StaticBody3D = _first_body(child)
		if found != null:
			return found
	return null


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


func _direct_reject(property: StadiumPoolOwnedProperty, lab: PitchBatLab,
	label: String, change: Callable, restore: Callable) -> void:
	change.call()
	_check(not property.valid_owner(lab), label + ": direct property rejects retained mutation")
	restore.call()
	var restored: bool = property.valid_owner(lab)
	_check(restored, label + ": direct property restores without context poison")
	if not restored:
		_record_restore_diagnostic(property, lab, label)

func _direct_controls() -> bool:
	var lab: PitchBatLab = _start_case("direct_restore_matrix")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var originals: Array = _originals(property)
	var targets: Array[StaticBody3D] = [property.ground_body, _first_body(property.boundary),
		_first_body(property.receiver.chair), property.pool_model.get_node("Collision/POOL_INNER_WALL")]
	for body: StaticBody3D in targets:
		if not _check(body != null and _shape(body) != null, "source-authored static target exists"):
			return false
		_body_fields(property, lab, body)
		_shape_fields(property, lab, body)
		_contact_fields(property, lab, body)
	_physics_material_descriptor_fields(property, lab, property.ground_body)
	_topology_fields(property, lab)
	_direct_new_capture_controls(property, lab)
	_fixed_placement_and_receiver_controls(property, lab)
	_check(var_to_bytes(_originals(property)) == var_to_bytes(originals)
		and not lab.pool_controller_active._prepared.context._invalidated
		and lab._automation.releases.is_empty(),
		"direct restorative matrix never refreshes installation bytes or reaches context latch")
	return await _finish_case(lab, {"target_bodies": targets.size(),
		"authority_path": "ordinary property.valid_owner, no context.valid during mutations"})


func _body_fields(property: StadiumPoolOwnedProperty, lab: PitchBatLab, body: StaticBody3D) -> void:
	var tag: String = String(body.name)
	for key: String in ["collision_layer", "collision_mask", "collision_priority", "disable_mode",
		"constant_linear_velocity", "constant_angular_velocity"]:
		var old: Variant = body.get(key)
		var changed: Variant = old
		match key:
			"collision_layer", "collision_mask": changed = int(old) ^ 4
			"collision_priority": changed = float(old) + 0.25
			"disable_mode": changed = (int(old) + 1) % 3
			"constant_linear_velocity", "constant_angular_velocity": changed = old + Vector3(0.125, 0, 0)
		_direct_reject(property, lab, tag + ":" + key,
			func() -> void: body.set(key, changed), func() -> void: body.set(key, old))
	var position_x: float = body.position.x
	_direct_reject(property, lab, tag + ":body_pose",
		func() -> void: body.position.x += 0.125, func() -> void: body.position.x = position_x)
	var mode: int = body.process_mode
	_direct_reject(property, lab, tag + ":process_mode",
		func() -> void: body.process_mode = Node.PROCESS_MODE_DISABLED,
		func() -> void: body.process_mode = mode)
	var group: int = body.process_thread_group
	_direct_reject(property, lab, tag + ":thread_group",
		func() -> void: body.process_thread_group = Node.PROCESS_THREAD_GROUP_SUB_THREAD,
		func() -> void: body.process_thread_group = group)
	var script: Script = body.get_script()
	_direct_reject(property, lab, tag + ":direct_script",
		func() -> void: body.set_script(MutationScript), func() -> void: body.set_script(script))
	var other: StaticBody3D = property.ground_body if body != property.ground_body \
		else property.pool_model.get_node("Collision/POOL_INNER_WALL")
	_direct_reject(property, lab, tag + ":collision_exception",
		func() -> void: body.add_collision_exception_with(other),
		func() -> void: body.remove_collision_exception_with(other))
	var material: PhysicsMaterial = body.physics_material_override
	var replacement: PhysicsMaterial = PhysicsMaterial.new()
	replacement.friction = 0.625
	replacement.bounce = 0.375
	replacement.rough = true
	replacement.absorbent = true
	_direct_reject(property, lab, tag + ":physics_material_null_class_and_values",
		func() -> void: body.physics_material_override = replacement,
		func() -> void: body.physics_material_override = material)


func _shape_fields(property: StadiumPoolOwnedProperty,
	lab: PitchBatLab, body: StaticBody3D) -> void:
	var shape: CollisionShape3D = _shape(body)
	var tag: String = String(body.name)
	var position_x: float = shape.position.x
	_direct_reject(property, lab, tag + ":shape_pose",
		func() -> void: shape.position.x += 0.125, func() -> void: shape.position.x = position_x)
	var disabled: bool = shape.disabled
	_direct_reject(property, lab, tag + ":shape_disabled",
		func() -> void: shape.disabled = not disabled, func() -> void: shape.disabled = disabled)
	var owner: int = body.get_shape_owners()[0]
	var owner_pose: Transform3D = body.shape_owner_get_transform(owner)
	_direct_reject(property, lab, tag + ":actual_owner_pose",
		func() -> void: body.shape_owner_set_transform(owner,
			Transform3D(Basis.IDENTITY, Vector3(0.125, 0, 0))),
		func() -> void: body.shape_owner_set_transform(owner, owner_pose))
	var owner_disabled: bool = body.is_shape_owner_disabled(owner)
	_direct_reject(property, lab, tag + ":actual_owner_disabled",
		func() -> void: body.shape_owner_set_disabled(owner, not owner_disabled),
		func() -> void: body.shape_owner_set_disabled(owner, owner_disabled))
	var extra_owner: int = body.create_shape_owner(body)
	body.shape_owner_add_shape(extra_owner, BoxShape3D.new())
	_check(not property.valid_owner(lab), tag + ":extra actual owner rejects")
	body.remove_shape_owner(extra_owner)
	_check(property.valid_owner(lab), tag + ":removed extra actual owner restores")
	var original: Shape3D = shape.shape
	var old_script: Script = original.get_script()
	_direct_reject(property, lab, tag + ":shape_resource_script",
		func() -> void: original.set_script(ResourceProbe),
		func() -> void: original.set_script(old_script))
	var margin: float = original.margin
	_direct_reject(property, lab, tag + ":shape_margin",
		func() -> void: original.margin = margin + 0.01,
		func() -> void: original.margin = margin)
	# Solver bias stays production-sealed; changing it is unsupported by pinned Jolt.
	# Coverage of that getter is source-only, never a warning-waived native mutation.
	if original is BoxShape3D:
		var size: Vector3 = original.size
		_direct_reject(property, lab, tag + ":box_size_in_place",
			func() -> void: original.size = size + Vector3(0.125, 0, 0),
			func() -> void: original.size = size)
	elif original is ConvexPolygonShape3D:
		var points: PackedVector3Array = original.points.duplicate()
		var changed: PackedVector3Array = points.duplicate()
		changed[0].x += 0.125
		_direct_reject(property, lab, tag + ":convex_points_in_place",
			func() -> void: original.points = changed, func() -> void: original.points = points)
	elif original is ConcavePolygonShape3D:
		var faces: PackedVector3Array = original.get_faces().duplicate()
		var changed: PackedVector3Array = faces.duplicate()
		changed[0].x += 0.125
		_direct_reject(property, lab, tag + ":concave_faces_in_place",
			func() -> void: original.set_faces(changed), func() -> void: original.set_faces(faces))
		var backface: bool = original.backface_collision
		_direct_reject(property, lab, tag + ":concave_backface",
			func() -> void: original.backface_collision = not backface,
			func() -> void: original.backface_collision = backface)
	else:
		_check(false, tag + ":unreviewed authored shape class")
	var equal_shape: Shape3D = original.duplicate(true)
	shape.shape = equal_shape
	_check(property.valid_owner(lab), tag + ":equal-content pre-guard shape replacement parity")
	shape.shape = original
	_check(property.valid_owner(lab), tag + ":original shape restored before any guard seal")
	_direct_reject(property, lab, tag + ":unsupported_native_shape_class",
		func() -> void: shape.shape = SphereShape3D.new(),
		func() -> void: shape.shape = original)


func _contact_fields(property: StadiumPoolOwnedProperty,
	lab: PitchBatLab, body: StaticBody3D) -> void:
	var metadata: Array = _ordered_metadata(body)
	var original_snapshot: PackedByteArray = var_to_bytes(
		StadiumPoolPartyAssetIntegrity.snapshot(body))
	for key: String in ["surface_id", "surface_role", "stadium_item", "owned_copy",
		"ball_surface", "boundary_segment"]:
		var present: bool = body.has_meta(key)
		var old: Variant = body.get_meta(key) if present else null
		var label: String = String(body.name) + ":metadata:" + key
		if present:
			_direct_reject(property, lab, label + ":presence",
				func() -> void: body.remove_meta(key),
				func() -> void: _restore_ordered_metadata(body, metadata))
			var changed: Variant = StringName(old) if old is String else String(old)
			_direct_reject(property, lab, label + ":exact_type",
				func() -> void: body.set_meta(key, changed), func() -> void: body.set_meta(key, old))
			_direct_reject(property, lab, label + ":value",
				func() -> void: body.set_meta(key, "changed-gameplay-authority"),
				func() -> void: body.set_meta(key, old))
		else:
			_direct_reject(property, lab, label + ":absent_to_present",
				func() -> void: body.set_meta(key, "injected-gameplay-authority"),
				func() -> void: body.remove_meta(key))
	var exact: bool = (var_to_bytes(_ordered_metadata(body)) == var_to_bytes(metadata)
		and var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(body)) == original_snapshot)
	_check(exact, String(body.name)
		+ ": metadata key order and original full snapshot restore exactly")
	if not exact:
		_record_restore_diagnostic(property, lab, String(body.name) + ":metadata restoration",
			metadata, _ordered_metadata(body))


func _topology_fields(property: StadiumPoolOwnedProperty, lab: PitchBatLab) -> void:
	for kind: String in ["static_body", "area", "rigid_body", "internal_script"]:
		var added: Node3D
		match kind:
			"static_body": added = StaticBody3D.new()
			"area": added = Area3D.new()
			"rigid_body": added = RigidBody3D.new()
			"internal_script":
				added = Node3D.new()
				added.set_script(MutationScript)
		property.add_child(added, false, Node.INTERNAL_MODE_BACK)
		_check(not property.valid_owner(lab), "sealed property rejects added internal " + kind)
		property.remove_child(added)
		added.free()
		_check(property.valid_owner(lab), "removal restores sealed property topology " + kind)
	var external: Area3D = Area3D.new()
	lab.add_child(external)
	_check(property.valid_owner(lab),
		"non-Static exclusion is scoped to owned field subtrees, outside area is not rejected here")
	lab.remove_child(external)
	external.free()
	var static_external: StaticBody3D = StaticBody3D.new()
	lab.add_child(static_external)
	_check(not property.valid_owner(lab),
		"all-lab StaticBody inventory still rejects outside addition")
	lab.remove_child(static_external)
	static_external.free()
	_check(property.valid_owner(lab), "all-lab StaticBody inventory restores after outside removal")
	var visual: Node3D = property.pool_model.get_node("Visual")
	var marker_idbefore: StringName = visual.name
	_direct_reject(property, lab, "retained visual node name",
		func() -> void: visual.name = "RenamedVisual", func() -> void: visual.name = marker_idbefore)
	var script: Script = visual.get_script()
	_direct_reject(property, lab, "retained visual node direct script",
		func() -> void: visual.set_script(MutationScript), func() -> void: visual.set_script(script))
	var model_parent: Node = property.pool_model.get_parent()
	var ancestor_mode: int = model_parent.process_mode
	_direct_reject(property, lab, "relevant gameplay ancestor process mode",
		func() -> void: model_parent.process_mode = Node.PROCESS_MODE_DISABLED,
		func() -> void: model_parent.process_mode = ancestor_mode)

func _visual_controls(target: String) -> bool:
	var lab: PitchBatLab = _start_case("visual_positive_" + target)
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var prepared: StadiumPoolModelPreparation = lab.pool_controller_active._prepared
	var selected: Node3D = property.pool_model if target == "pool" else (
		property.ground_body if target == "ground" else property.boundary)
	var mesh: MeshInstance3D = _first_mesh(selected)
	if not _check(mesh != null and mesh.material_override is StandardMaterial3D,
		target + ": actual authored material is present"):
		return false
	var material: StandardMaterial3D = mesh.material_override
	var originals: Array = _originals(property)
	var capture_receipt: Dictionary = prepared.context.binding_receipt()
	var snapshot: PackedByteArray = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(selected))
	var gameplay: Dictionary = property.integrity_policy2.audit_receipt()
	var color: Color = material.albedo_color
	var roughness: float = material.roughness
	var emission: Color = material.emission
	var emission_enabled: bool = material.emission_enabled
	var visible: bool = mesh.visible
	var layers: int = mesh.layers
	var shadow: int = mesh.cast_shadow
	material.albedo_color = Color(0.8, 0.2, 0.4, 0.5)
	material.roughness = 0.125
	material.emission_enabled = true
	material.emission = Color(0.1, 0.2, 0.3)
	mesh.visible = not visible
	mesh.layers = layers ^ 4
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta("policy2_fixture_inert_editor_note", "cosmetic only")
	_check(var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(selected)) != snapshot,
		target + ": full stored rendering snapshot actually changed")
	_check(property.valid_owner(lab)
		and prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime)
		and prepared.context.valid(property.pool_model, _runtime)
		and not prepared.context._invalidated,
		target + ": rendering-only changes preserve existing ordinary gameplay authority")
	_check(var_to_bytes(_originals(property)) == var_to_bytes(originals)
		and prepared.context.binding_receipt().snapshot_sha256 == capture_receipt.snapshot_sha256,
		target + ": complete original installation provenance is never recaptured")
	_check(StadiumPoolModelPreparation.capture_owned(property, lab, _runtime) == null,
		target + ": NEW capture rejects changed authored art against original full validation")
	_check(prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime)
		and not prepared.context._invalidated,
		target + ": rejected NEW capture does not poison prior live authority")
	material.albedo_color = color
	material.roughness = roughness
	material.emission = emission
	material.emission_enabled = emission_enabled
	mesh.visible = visible
	mesh.layers = layers
	mesh.cast_shadow = shadow
	mesh.remove_meta("policy2_fixture_inert_editor_note")
	_check(var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(selected)) == snapshot,
		target + ": exact authored rendering bytes restored")
	var fresh: StadiumPoolModelPreparation = StadiumPoolModelPreparation.capture_owned(
		property, lab, _runtime)
	_check(fresh != null and fresh != prepared and fresh.context != prepared.context
		and fresh.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime)
		and prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime),
		target + ": a genuinely NEW capture is allowed after art restoration in the same live lifetime")
	if target == "pool":
		_visual_mesh_content(property, lab, prepared, mesh)
	_check(lab._automation.releases.is_empty() and lab._play_records.is_empty()
		and lab.pool_controller_active.commits == 0 and _unchanged(),
		target + ": zero-release visual controls manufacture no baseball result")
	return await _finish_case(lab, {"installation_full_capture": capture_receipt,
		"finite_policy_receipt": gameplay,
		"live_finite_comparison": "ordinary property/preparation/context predicates true",
		"full_new_capture_with_visual_mutation": "rejected"})


func _visual_mesh_content(property: StadiumPoolOwnedProperty, lab: PitchBatLab,
	prepared: StadiumPoolModelPreparation, mesh: MeshInstance3D) -> void:
	var original: Mesh = mesh.mesh
	var edited: Mesh = original.duplicate(true)
	if edited is ArrayMesh:
		var arrays: Array = edited.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		vertices[0].x += 0.0625
		arrays[Mesh.ARRAY_VERTEX] = vertices
		edited.clear_surfaces()
		edited.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	elif edited is BoxMesh:
		edited.size.x += 0.0625
	else:
		_check(false, "unreviewed authored visual mesh class")
		return
	mesh.mesh = edited
	_check(property.valid_owner(lab)
		and prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime),
		"visual mesh geometry change alone preserves ordinary live gameplay authority")
	_check(StadiumPoolModelPreparation.capture_owned(property, lab, _runtime) == null,
		"visual mesh geometry change still fails full NEW capture")
	mesh.mesh = original
	_check(prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime),
		"restoring original mesh retains existing authority")


func _early_preparation_restore() -> bool:
	var lab: PitchBatLab = _start_case("early_preparation_restore")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var prepared: StadiumPoolModelPreparation = lab.pool_controller_active._prepared
	var body: StaticBody3D = property.ground_body
	var old: Vector3 = body.constant_linear_velocity
	body.constant_linear_velocity = old + Vector3(0.125, 0, 0)
	_check(not prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime)
		and not prepared.context._invalidated,
		"retained ground mutation fails preparation pose owner check before context.valid")
	body.constant_linear_velocity = old
	_check(prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime)
		and not prepared.context._invalidated,
		"same preparation restores when its original path never reached the context latch")
	return await _finish_case(lab)


func _context_poison(mutation: String) -> bool:
	var lab: PitchBatLab = _start_case("context_poison_" + mutation)
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var model: Node3D = property.pool_model
	var prepared: StadiumPoolModelPreparation = lab.pool_controller_active._prepared
	var carrier: Node3D = model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var descriptor: Dictionary = carrier.get_meta("descriptor").duplicate(true)
	var carrier_position_x: float = carrier.position.x
	var model_position_x: float = model.position.x
	var model_scale: Vector3 = model.scale
	var old_parent: Node = model.get_parent()
	var old_index: int = model.get_index()
	var carrier_index: int = carrier.get_index()
	var replacement: Node3D
	var volume_role: Variant = carrier.get_meta("volume_role")
	var root_source: Variant = model.get_meta("water_source_sha256")
	match mutation:
		"descriptor":
			var changed: Dictionary = descriptor.duplicate(true)
			changed.height_m = float(changed.height_m) + 0.125
			carrier.set_meta("descriptor", changed)
		"carrier_transform": carrier.position.x += 0.125
		"model_transform": model.position.x += 0.125
		"model_scale": model.scale *= 1.125
		"carrier_replacement":
			replacement = carrier.duplicate()
			model.remove_child(carrier)
			model.add_child(replacement)
			replacement.name = StadiumPoolInteriorV2.VOLUME_ID
			model.move_child(replacement, carrier_index)
		"model_parent": model.reparent(lab, true)
		"wrong_source": pass
		"water_metadata": carrier.set_meta("volume_role", StringName(volume_role))
		"root_metadata": model.set_meta("water_source_sha256", StringName(root_source))
	var source: String = "0".repeat(64) if mutation == "wrong_source" else _runtime
	if mutation in ["descriptor", "carrier_transform"]:
		_check(property.valid_owner(lab),
			mutation + ": unchanged earlier owner predicates allow the context boundary to run")
		_check(not prepared.valid(model, StadiumPoolContract.LIVE, source)
			and prepared.context._invalidated,
			mutation + ": actual preparation reaches and permanently poisons context")
	else:
		_check(not prepared.context.valid(model, source) and prepared.context._invalidated,
			mutation + ": explicit existing context boundary permanently poisons")
	if mutation == "carrier_replacement":
		model.remove_child(replacement)
		replacement.free()
		model.add_child(carrier)
		model.move_child(carrier, carrier_index)
	if mutation == "model_parent":
		model.reparent(old_parent, true)
		old_parent.move_child(model, old_index)
	match mutation:
		"descriptor": carrier.set_meta("descriptor", descriptor)
		"carrier_transform": carrier.position.x = carrier_position_x
		"model_transform": model.position.x = model_position_x
		"model_scale": model.scale = model_scale
		"water_metadata": carrier.set_meta("volume_role", volume_role)
		"root_metadata": model.set_meta("water_source_sha256", root_source)
	_check(property.valid_owner(lab) and not prepared.valid(model, StadiumPoolContract.LIVE, _runtime)
		and prepared.context._invalidated and lab._automation.releases.is_empty(),
		mutation + ": restored bytes cannot revive poisoned context; installation is disposed")
	return await _finish_case(lab)

func _natural_guard_controls() -> bool:
	var lab: PitchBatLab = _start_case("natural_guard_and_same_tick_callback")
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
		"bounded genuine automation creates real launched ball/guard without trajectory selection"):
		return false
	_live_guard = guard
	var guard_observed_frame: int = Engine.get_physics_frames()
	_guard_progress(lab, "real_guard_captured", wait_start)
	_ball_controls(property, lab, guard)
	var registered: StaticBody3D = property.ground_body
	var shape: CollisionShape3D = _shape(registered)
	var resource: Shape3D = shape.shape
	shape.shape = resource.duplicate(true)
	_check(property.valid_owner(lab) and not guard.valid() and not guard._context._invalidated,
		"equal-content static shape preserves property parity but guard retains original owner RID seal")
	shape.shape = resource
	_check(guard.valid(), "restoring exact guarded shape resource restores non-latched owner failure")
	var mesh: MeshInstance3D = _first_mesh(property.pool_model)
	var material: StandardMaterial3D = mesh.material_override
	var color: Color = material.albedo_color
	var state: PackedByteArray = var_to_bytes(StadiumPoolWaterGuard._state_parameters(guard._state))
	var commits: int = adapter.commits
	var receipts: PackedByteArray = var_to_bytes(guard.receipts)
	material.albedo_color = Color(0.9, 0.1, 0.6, 0.4)
	_check(guard.valid() and property.valid_owner(lab)
		and adapter._prepared.valid(property.pool_model, StadiumPoolContract.LIVE, _runtime)
		and var_to_bytes(StadiumPoolWaterGuard._state_parameters(guard._state)) == state
		and adapter.commits == commits and var_to_bytes(guard.receipts) == receipts,
		"live visual edit preserves real ball authority, current baseball state and outcome receipts")
	material.albedo_color = color
	var downstream: Callable = guard._downstream
	var old_velocity: Vector3 = registered.constant_linear_velocity
	_callback_seen = false
	_callback_frame = -1
	guard._downstream = func(ball: BattedBallBody, batch: Array[Dictionary]) -> void:
		downstream.call(ball, batch)
		if _callback_seen:
			return
		_callback_seen = true
		_callback_frame = Engine.get_physics_frames()
		_callback_before = var_to_bytes(StadiumPoolWaterGuard._state_parameters(guard._state))
		registered.constant_linear_velocity = old_velocity + Vector3(0.125, 0, 0)
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
	_check(_callback_seen and _callback_frame >= armed_frame
		and Engine.get_physics_frames() - armed_frame <= MAX_CALLBACK_FRAMES
		and Engine.get_physics_frames() - wait_start <= MAX_GUARD_FRAMES + MAX_CALLBACK_FRAMES
		and _callback_before == _callback_after and rejected_same_tick
		and guard._generation_invalid and guard._context._invalidated
		and adapter.commits == commits and var_to_bytes(guard.receipts) == receipts,
		"real engine route catches retained mutation after ordinary downstream in the same tick")
	registered.constant_linear_velocity = old_velocity
	guard._downstream = downstream
	_check(not guard.valid() and guard._context._invalidated,
		"same-tick context poisoning survives field restoration and original callback restoration")
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
		"releases": lab._automation.releases.duplicate(true), "plays": plays,
		"guard_records": guard.records.duplicate(true),
		"guard_unsupported": guard.unsupported.duplicate(true),
		"water_receipts": guard.receipts.duplicate(true), "commits": adapter.commits,
		"note": "Actual partial ordinary trajectory; no report, settlement or performance claim."}
	if not _check(detail.releases.size() <= MAX_TRAJECTORY_ROWS
		and plays.size() <= MAX_TRAJECTORY_ROWS and guard.records.size() <= MAX_GUARD_ROWS
		and guard.unsupported.size() <= MAX_GUARD_ROWS
		and guard.receipts.size() <= MAX_TRAJECTORY_ROWS,
		"fixed raw trajectory and guard row caps preserve complete untruncated evidence"):
		return false
	_write("pool-owned-integrity-v30-guard-raw.json", detail)
	return await _finish_case(lab, {"mutation_physics_frame": _callback_frame,
		"same_tick_rejection": rejected_same_tick,
		"actual_releases": detail.releases.size(), "actual_plays": plays.size()})


func _ball_controls(property: StadiumPoolOwnedProperty, lab: PitchBatLab,
	guard: StadiumPoolWaterGuard) -> void:
	var ball: BattedBallBody = guard._ball
	for key: String in ["mass", "radius_m", "collision_layer", "collision_mask", "continuous_cd",
		"contact_monitor", "max_contacts_reported", "custom_integrator", "gravity_scale",
		"linear_damp", "angular_damp"]:
		var old: Variant = ball.get(key)
		var changed: Variant = old
		match typeof(old):
			TYPE_BOOL: changed = not old
			TYPE_INT: changed = int(old) + 1
			TYPE_FLOAT: changed = float(old) + 0.125
		ball.set(key, changed)
		_check(not guard.valid() and not guard._context._invalidated,
			"ball " + key + " rejects before context boundary")
		ball.set(key, old)
		_check(guard.valid(), "ball " + key + " restores original non-latched guard path")
	for key: String in ["friction", "bounce"]:
		var old: float = ball.physics_material_override.get(key)
		ball.physics_material_override.set(key, old + 0.125)
		_check(not guard.valid() and not guard._context._invalidated,
			"ball PhysicsMaterial " + key + " retained")
		ball.physics_material_override.set(key, old)
		_check(guard.valid(), "ball PhysicsMaterial " + key + " restores")
	var shape: CollisionShape3D = guard._ball_shape
	var resource: Shape3D = shape.shape
	shape.shape = resource.duplicate(true)
	_check(not guard.valid() and not guard._context._invalidated,
		"ball equal-content SphereShape replacement still rejects original resource identity")
	shape.shape = resource
	_check(guard.valid(), "ball original sphere resource restored")
	var position_x: float = shape.position.x
	shape.position.x += 0.125
	_check(not guard.valid(), "ball actual shape owner pose retained")
	shape.position.x = position_x
	_check(guard.valid(), "ball actual shape owner pose restores")
	var owner: int = ball.get_shape_owners()[0]
	ball.shape_owner_set_disabled(owner, true)
	_check(not guard.valid(), "ball actual owner disabled flag retained")
	ball.shape_owner_set_disabled(owner, false)
	_check(guard.valid(), "ball owner enabled state restores")
	var extra: int = ball.create_shape_owner(ball)
	ball.shape_owner_add_shape(extra, SphereShape3D.new())
	_check(not guard.valid(), "ball extra actual shape owner rejects")
	ball.remove_shape_owner(extra)
	_check(guard.valid() and property.valid_owner(lab), "ball original owner layout restores")


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
		_output.path_join("pool-owned-integrity-v30-progress.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(encoded)
		file.close()
	else:
		_check(false, "bounded guard progress could not open")

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


func _physics_material_descriptor_fields(property: StadiumPoolOwnedProperty,
	lab: PitchBatLab, body: StaticBody3D) -> void:
	# Authored static materials are null. Do not invent an admitted nonnull baseline.
	# The actual production collector separately proves each nonnull field is encoded.
	var original: PhysicsMaterial = body.physics_material_override
	if not _check(original == null, "authored static material baseline is null"):
		return
	var physical: PhysicsMaterial = PhysicsMaterial.new()
	body.physics_material_override = physical
	var baseline: PackedByteArray = var_to_bytes(StadiumPoolOwnedIntegrity._body(body))
	for key: String in ["friction", "bounce", "rough", "absorbent"]:
		var old: Variant = physical.get(key)
		physical.set(key, not old if old is bool else float(old) + 0.125)
		_check(var_to_bytes(StadiumPoolOwnedIntegrity._body(body)) != baseline,
			"actual finite body collector encodes PhysicsMaterial " + key)
		_check(not property.valid_owner(lab),
			"nonnull PhysicsMaterial variant remains unadmitted: " + key)
		physical.set(key, old)
		_check(var_to_bytes(StadiumPoolOwnedIntegrity._body(body)) == baseline,
			"actual finite body collector restores PhysicsMaterial " + key)
	physical.set_script(ResourceProbe)
	_check(StadiumPoolOwnedIntegrity._body(body).is_empty(),
		"actual finite body collector rejects scripted PhysicsMaterial")
	physical.set_script(null)
	body.physics_material_override = original
	_check(property.valid_owner(lab),
		"actual authored null PhysicsMaterial restores ordinary authority")


func _world_poison() -> bool:
	var lab: PitchBatLab = _start_case("observable_world_change")
	if lab == null:
		return false
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var old_world: World3D = property.ground_body.get_world_3d()
	var viewport: SubViewport = _runner._viewport
	viewport.own_world_3d = false
	viewport.world_3d = World3D.new()
	_check(property.ground_body.get_world_3d() != old_world
		and not property.valid_owner(lab) and lab._automation.releases.is_empty(),
		"observable current World3D and space membership change rejects before any release")
	# World replacement is deliberately not restored or relabeled as a valid lifetime.
	return await _finish_case(lab, {"scope": "node-observable World3D/space only",
		"raw_physics_server_writes_covered": false})

func _direct_new_capture_controls(property: StadiumPoolOwnedProperty, lab: PitchBatLab) -> void:
	var model: Node3D = property.pool_model
	_assert_original_capture_snapshots(property, lab, "before untouched direct NEW capture")
	_check(StadiumPoolInteriorV2.capture_owned(model, _runtime, property, lab) != null,
		"untouched direct NEW InteriorV2.capture_owned succeeds")
	var body: StaticBody3D = property.ground_body
	var other: StaticBody3D = model.get_node("Collision/POOL_INNER_WALL")
	body.add_collision_exception_with(other)
	_check(StadiumPoolInteriorV2.capture_owned(model, _runtime, property, lab) == null,
		"direct NEW InteriorV2 capture rejects newly sealed collision exception")
	body.remove_collision_exception_with(other)
	_assert_original_capture_snapshots(property, lab, "before restored exception NEW capture")
	_check(StadiumPoolInteriorV2.capture_owned(model, _runtime, property, lab) != null,
		"restored direct exception permits NEW capture on unpoisoned original lifetime")
	var owner: int = body.get_shape_owners()[0]
	var pose: Transform3D = body.shape_owner_get_transform(owner)
	body.shape_owner_set_transform(owner, Transform3D(Basis.IDENTITY, Vector3(0.125, 0, 0)))
	_check(StadiumPoolInteriorV2.capture_owned(model, _runtime, property, lab) == null,
		"direct NEW InteriorV2 capture rejects actual owner transform outside node snapshot")
	body.shape_owner_set_transform(owner, pose)
	_assert_original_capture_snapshots(property, lab, "before restored actual owner NEW capture")
	_check(StadiumPoolInteriorV2.capture_owned(model, _runtime, property, lab) != null
		and not lab.pool_controller_active._prepared.context._invalidated,
		"restored actual owner permits NEW capture without reviving a poisoned context")

func _fixed_placement_and_receiver_controls(property: StadiumPoolOwnedProperty,
	lab: PitchBatLab) -> void:
	for marker_id: String in ["Plate", "Mound", "Safe", "Deep", "FoulLine-1", "FoulLine1"]:
		var marker: Node3D = property.get_node(marker_id)
		var position_x: float = marker.position.x
		_direct_reject(property, lab, marker_id + ":fixed authored marker transform",
			func() -> void: marker.position.x += 0.125,
			func() -> void: marker.position.x = position_x)
	var chair: Node3D = property.receiver.chair
	for key: String in ["owned_copy", "stadium_item"]:
		var old: Variant = chair.get_meta(key)
		_direct_reject(property, lab, "receiver root metadata " + key,
			func() -> void: chair.set_meta(key, "forged-receiver"),
			func() -> void: chair.set_meta(key, old))
	var visual: Node3D = chair.get_node("Visual")
	var visual_pose: Transform3D = visual.transform
	var visual_position_x: float = visual.position.x
	var visual_rotation_z: float = visual.rotation.z
	var visual_channels: PackedByteArray = var_to_bytes(
		[visual.position, visual.scale, visual.rotation])
	var child: Node3D = visual.get_child(0)
	var child_position_x: float = child.position.x
	_direct_reject(property, lab, "receiver visual child transform",
		func() -> void: child.position.x += 0.125,
		func() -> void: child.position.x = child_position_x)
	_direct_reject(property, lab, "receiver visual root translation remains fixed",
		func() -> void: visual.position.x += 0.125,
		func() -> void: visual.position.x = visual_position_x)
	StadiumStarterModels.receiver_rock(chair, 0.1, 0.07, 0)
	_check(visual.transform != visual_pose and property.valid_owner(lab)
		and lab.pool_controller_active._prepared.valid(property.pool_model,
			StadiumPoolContract.LIVE, _runtime),
		"actual ordinary receiver rocking remains allowed without moving collider or child local pose")
	visual.rotation.z = visual_rotation_z
	var restored: bool = (property.valid_owner(lab)
		and var_to_bytes([visual.position, visual.scale, visual.rotation]) == visual_channels)
	_check(restored, "receiver authored rest transform and cached channels restore exactly")
	if not restored:
		_record_restore_diagnostic(property, lab, "receiver cached channel restoration")


func _ordered_metadata(node: Node) -> Array:
	var rows: Array = []
	for key: StringName in node.get_meta_list():
		rows.append([key, node.get_meta(key)])
	return rows


func _restore_ordered_metadata(node: Node, original: Array) -> void:
	# A removed key cannot be inserted back into its old position individually.
	# Replay the captured original order and typed values; never sort or recapture it.
	for key: StringName in node.get_meta_list():
		node.remove_meta(key)
	for row: Array in original:
		node.set_meta(row[0], row[1])


func _assert_original_capture_snapshots(property: StadiumPoolOwnedProperty,
	lab: PitchBatLab, label: String) -> void:
	var prepared: StadiumPoolModelPreparation = lab.pool_controller_active._prepared
	var original: Array = [property._ground_bytes, property._boundary_bytes,
		property._static_bytes, prepared._snapshot]
	var current: Array = [var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(property.ground_body)),
		property._boundary_geometry(), property._static_inventory(lab),
		var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(property.pool_model))]
	var exact: bool = var_to_bytes(current) == var_to_bytes(original)
	_check(exact, label + ": all original installation snapshots match exactly")
	if not exact:
		var expected_fields: Array = []
		var actual_fields: Array = []
		for index: int in range(original.size()):
			expected_fields.append(bytes_to_var(original[index]))
			actual_fields.append(bytes_to_var(current[index]))
		_record_restore_diagnostic(property, lab, label, expected_fields, actual_fields)


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
