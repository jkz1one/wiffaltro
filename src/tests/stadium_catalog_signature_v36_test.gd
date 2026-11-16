extends Node
## Finite catalog parity and one genuine paid zero-release installation.
# gdlint: disable=max-returns,max-file-lines

const Oracle = preload("res://src/tests/stadium_catalog_signature_oracle.gd")
const Inherited = preload("res://src/tests/stadium_catalog_signature_inherited.gd")
const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MATCH_SEED: int = 314229
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const HISTORICAL: String = "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f"
const EXPECTED_CHECKS: int = 109
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const SUMMARY_CAP: int = 65536
const GENERATION_CAP: int = 8192
const READONLY_NODE_CAP: int = 4096
const READONLY_DEPTH_CAP: int = 16
const INPUT_NAMES: Array[String] = ["VERSION", "ROWS", "STARTERS", "LIVE_UNITS", "LAND"]
const HISTORICAL_HOME: Dictionary = {
	"boundary": "93859ee6fb839243e6ac471b45027547e4a47e09e7e57bc957f19c7410b542e9",
	"geometry": "589f262382192d29175a1e9866ce9aeb07d807a122b2cde8d91247ce3aee0985",
	"inventory": {
		"blueprints": [
			"ST-001",
			"ST-003",
			"ST-006",
			"ST-079"
		],
		"catalog": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
		"copies": {
			"purchase:stadium-buy:0:0": {
				"item": "ST-006",
				"paid": 160,
				"source": "purchase-v1"
			},
			"starter-v1:ST-001": {
				"item": "ST-001",
				"paid": 0,
				"source": "starter-v1"
			},
			"starter-v1:ST-003": {
				"item": "ST-003",
				"paid": 0,
				"source": "starter-v1"
			},
			"starter-v1:ST-079": {
				"item": "ST-079",
				"paid": 0,
				"source": "starter-v1"
			}
		},
		"starter": "granted",
		"styles": [],
		"version": 1
	},
	"layout": {
		"bases": "",
		"bleachers": [],
		"displays": [],
		"family": "reference-owned-pool-v16",
		"ground": "",
		"lights": [],
		"net": "",
		"obstacles": [],
		"pool": {
			"copy": "purchase:stadium-buy:0:0",
			"position": [
				12.0,
				18.0
			],
			"yaw": 0
		},
		"receiver": "starter-v1:ST-079",
		"seating": [],
		"styles": {
			"grass": "",
			"line": ""
		},
		"surface": {
			"condition": "prepared",
			"foundation": "grass",
			"height": "short"
		},
		"target": "",
		"version": 16,
		"walls": {
			"back": {},
			"left": [],
			"right": []
		}
	},
	"revision": 7,
	"scoreboard_inventory": {
		"blueprints": [],
		"catalog": "efd9053c016cefeb36e21324193906734c57ea70cd62560fc4f19dfc335460dc",
		"copies": {},
		"version": 1
	},
	"surface_access": [
		"grass",
		"ground_prep"
	],
	"tier": "backyard",
	"version": 16,
	"wall_piece_inventory": {
		"blueprints": [],
		"catalog": "3c544a7d07a07a76fe24bce6234c4c469f097eb8dec455d25a9e40b1b6ea9620",
		"stock": {
			"catalog": "fc95048f0179e7d18a58d0a6f50bfbf1a18bfc036f1ce4d8ddbf6076cc6b1383",
			"copies": {},
			"version": 1
		},
		"version": 1
	}
}

var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _output: String = ""
var _runtime: String = ""
var _expected_runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _generation_dir: String = ""
var _generation_written: bool = false
var _app: ObservedApp
var _runner: PhysicalMatchRunner
var _funding: Dictionary = {}
var _placements: Array[Dictionary] = []
var _output_admitted: bool = false
var _source: MatchState
var _ledger: ClubAssetLedger
var _season_bytes: PackedByteArray
var _ledger_bytes: PackedByteArray
var _source_bytes: PackedByteArray
var _saved_files: Dictionary = {}
var _reports: int = 0
var _runner_errors: Array[String] = []
var _starts: int = 0
var _cleanups: int = 0
var _disposed: bool = false
var _preserved: bool = false
var _token_retired: bool = false
var _releases: int = -1
var _plays: int = -1
var _physics_start: int = -1
var _physics_end: int = -1
var _groups: Array[Dictionary] = []
var _mutations: Array[Dictionary] = []
var _signatures: Dictionary = {}
var _readonly_rows: Array[Dictionary] = []
var _readonly_nodes: int = 0
var _readonly_containers: int = 0
var _readonly_max_depth: int = 0
var _readonly_exhausted: bool = false

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


func _unchanged() -> bool:
	return var_to_bytes(SeasonSave.snapshot(_app.season)) == _season_bytes \
		and var_to_bytes(_ledger.to_data()) == _ledger_bytes \
		and var_to_bytes(_profile_object_data(_source)) == _source_bytes \
		and var_to_bytes(_saved()) == var_to_bytes(_saved_files) \
		and _app.season.pending_fixture().id == 0 and _app.season.round_index == 0


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
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--catalog-signature-v36-dir="):
			_output = argument.trim_prefix("--catalog-signature-v36-dir=")
		if argument.begins_with("--catalog-signature-v36-runtime="):
			_expected_runtime = argument.trim_prefix("--catalog-signature-v36-runtime=")
		if argument.begins_with("--catalog-signature-v36-execution="):
			_execution = argument.trim_prefix("--catalog-signature-v36-execution=")
		if argument.begins_with("--catalog-signature-v36-nonce="):
			_nonce = argument.trim_prefix("--catalog-signature-v36-nonce=")
		if argument.begins_with("--catalog-generation-dir="):
			_generation_dir = argument.trim_prefix("--catalog-generation-dir=")
	await _run()
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_check(_checks + 1 == EXPECTED_CHECKS, "exact catalog unit assertion count")
	var summary: Dictionary = {
		"version": 1, "pid": OS.get_process_id(), "runtime": _runtime,
		"execution": _execution, "nonce": _nonce,
		"status": "PASS" if _failures == 0 else "FAILED", "checks": _checks,
		"expected_checks": EXPECTED_CHECKS, "failures": _failures, "failed": _failed,
		"groups": _groups, "signatures": _signatures, "readonly_rows": _readonly_rows,
		"readonly_nodes": _readonly_nodes, "readonly_containers": _readonly_containers,
		"readonly_max_depth": _readonly_max_depth, "readonly_exhausted": _readonly_exhausted,
		"mutations": _mutations, "starts": _starts, "cleanups": _cleanups,
		"reports": _reports, "runner_errors": _runner_errors,
		"releases": _releases, "plays": _plays, "disposed": _disposed,
		"preserved": _preserved, "token_retired": _token_retired,
		"physics_frame_start": _physics_start, "physics_frame_end": _physics_end,
		"generation_requested": not _generation_dir.is_empty(),
		"generation_written": _generation_written,
		"season_sha256": _season_bytes.hex_encode().sha256_text(),
		"ledger_sha256": _ledger_bytes.hex_encode().sha256_text(),
		"source_sha256": _source_bytes.hex_encode().sha256_text(),
		"saved_files_sha256": var_to_bytes(_saved_files).hex_encode().sha256_text(),
		"hash_encoding": "SHA256_OF_LOWERCASE_HEX_NATIVE_BYTES",
		"performance_qualified": false, "production_qualified": false}
	var encoded: String = JSON.stringify(summary, "", true, true)
	if _output_admitted and encoded.to_utf8_buffer().size() <= SUMMARY_CAP:
		var file: FileAccess = FileAccess.open(
			_output.path_join("catalog-signature-v36-summary.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(encoded)
			file.close()
		else:
			_check(false, "summary output could not open")
	else:
		_check(false, "summary unavailable or exceeds cap")
	print("CATALOG_SIGNATURE_V36 checks=%d failures=%d starts=%d cleanups=%d source=%s" % [
		_checks, _failures, _starts, _cleanups, _runtime])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and OS.get_cmdline_user_args().has("--physical-in-process"), "explicit isolated output"):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty(), "fresh empty output directory"):
		return
	_output_admitted = true
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _check(_hex(_runtime, 64) and _runtime == _expected_runtime
		and _hex(_execution, 64) and _hex(_nonce, 32), "source and execution identity bound"):
		return
	if not _check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
		and not get_tree().paused and StadiumPoolHotpathProfile.active == null,
		"ordinary clock, Jolt and inactive profiler"):
		return
	_group("admission", 0)
	var start: int = _checks
	_catalog_controls()
	_group("catalog", start)
	if _failures > 0:
		return
	start = _checks
	if not await _profile_genuine_setup():
		return
	var fixture: Dictionary = _fixture(3)
	_source = SeasonPhysicalFixtures.match_for(_app.season, fixture)
	_ledger = ClubPlayers.assets(_app.season.career)
	if not _check(fixture == FIXTURE
		and SeasonPhysicalFixtures.seed_for(_app.season, fixture) == MATCH_SEED
		and _source != null and _ledger != null
		and StadiumPoolOwnedSnapshot.matches(_source.stadium, _ledger), "genuine paid request"):
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
	_physics_start = Engine.get_physics_frames()
	if not _check(_runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger),
		"one actual disposable paid installation"):
		return
	_starts += 1
	var lab: PitchBatLab = _runner._lab
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _check(property != null and property.valid_owner(lab)
		and lab.pool_controller_active._prepared.valid(property.pool_model,
			StadiumPoolContract.LIVE, _runtime) and _unchanged(), "ordinary authority before mutations"):
		return
	_group("paid_setup", start)
	start = _checks
	var matrix_ok: bool = _paid_mutations(property, lab)
	_group("paid_mutations", start)
	if not matrix_ok:
		_runner.cancel()
		return
	_check(property.valid_owner(lab) and lab.pool_controller_active._prepared.valid(
		property.pool_model, StadiumPoolContract.LIVE, _runtime), "restored ordinary authority")
	_releases = lab._automation.releases.size()
	_plays = lab._play_records.size()
	_physics_end = Engine.get_physics_frames()
	_check(_releases == 0 and _plays == 0 and _physics_start == _physics_end,
		"zero release controls finish before any physics signal")
	var lab_ref: WeakRef = weakref(lab)
	var property_ref: WeakRef = weakref(property)
	var token: StadiumPoolBoundEntitlement = property.entitlement
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	_runner.cancel()
	await get_tree().process_frame
	_disposed = (lab_ref.get_ref() == null and property_ref.get_ref() == null
		and _runner._lab == null and _runner._viewport == null and not _runner._running
		and _runner.get_child_count() == 0 and not adapter.enabled and adapter._lab == null)
	_preserved = _unchanged()
	_check(_disposed and _preserved and _reports == 0, "disposal preserves original paid bytes")
	if _disposed:
		_cleanups += 1
	_token_retired = token._owner != null and token._owner.get_ref() == null
	_check(_token_retired, "paid token owner retired")
	_check(_starts == 1 and _cleanups == 1 and _runner_errors.is_empty() and _reports == 0,
		"single clean installation without settlement")


func _group(label: String, start: int) -> void:
	_groups.append({"name": label, "checks": _checks - start})


func _catalog_controls() -> void:
	_signatures = {"builder": Oracle.signature(), "production": StadiumCatalog.signature(),
		"historical": HISTORICAL, "inherited": Inherited.signature(),
		"inherited_unqualified": Inherited.inherited_signature(),
		"wall": StadiumWallPieceCatalog.signature(), "ownership": StadiumWallPieceOwnership.signature(),
		"scoreboard": StadiumScoreboardCatalog.signature()}
	if not _generation_dir.is_empty() and not _generation_diagnostic():
		_check(false, "explicit generation diagnostic failed")
	_check(_signatures.builder == _signatures.production and _signatures.builder == HISTORICAL,
		"native uncached builder equals generated return and retained historical catalog")
	_check(_signatures.inherited == HISTORICAL, "legal class-qualified inherited static call")
	_check(_signatures.inherited_unqualified == HISTORICAL, "legal unqualified inherited static call")
	_check(_signatures.wall == HISTORICAL_HOME.wall_piece_inventory.stock.catalog,
		"composed wall signature preserves retained old save")
	_check(_signatures.ownership == HISTORICAL_HOME.wall_piece_inventory.catalog,
		"composed wall ownership signature preserves retained old save")
	_check(_signatures.scoreboard == HISTORICAL_HOME.scoreboard_inventory.catalog,
		"scoreboard signature preserves retained old save")
	var stock: StadiumStock = StadiumStock.from_data(HISTORICAL_HOME.inventory)
	var wall: StadiumWallPieceOwnership = StadiumWallPieceOwnership.from_data(
		HISTORICAL_HOME.wall_piece_inventory)
	var pieces: StadiumWallPieceStock = StadiumWallPieceStock.from_data(
		HISTORICAL_HOME.wall_piece_inventory.stock)
	var board: StadiumScoreboardOwnership = StadiumScoreboardOwnership.from_data(
		HISTORICAL_HOME.scoreboard_inventory)
	_check(stock != null and _json_same(stock.to_data(), HISTORICAL_HOME.inventory),
		"actual old stock validator exact serialized roundtrip")
	_check(wall != null and _json_same(wall.to_data(), HISTORICAL_HOME.wall_piece_inventory),
		"actual old wall validator exact serialized roundtrip")
	_check(pieces != null and _json_same(pieces.to_data(), HISTORICAL_HOME.wall_piece_inventory.stock),
		"actual old wall-stock validator exact serialized roundtrip")
	_check(board != null and _json_same(board.to_data(), HISTORICAL_HOME.scoreboard_inventory),
		"actual old scoreboard validator exact serialized roundtrip")
	var damaged: Dictionary = HISTORICAL_HOME.inventory.duplicate(true)
	damaged.catalog = "changed-catalog"
	_check(StadiumStock.from_data(damaged) == null, "stock rejects changed saved catalog")
	damaged = HISTORICAL_HOME.wall_piece_inventory.duplicate(true)
	damaged.catalog = "changed-catalog"
	_check(StadiumWallPieceOwnership.from_data(damaged) == null, "wall rejects changed saved catalog")
	damaged = HISTORICAL_HOME.wall_piece_inventory.stock.duplicate(true)
	damaged.catalog = "changed-catalog"
	_check(StadiumWallPieceStock.from_data(damaged) == null,
		"wall stock rejects changed saved catalog")
	damaged = HISTORICAL_HOME.scoreboard_inventory.duplicate(true)
	damaged.catalog = "changed-catalog"
	_check(StadiumScoreboardOwnership.from_data(damaged) == null,
		"board rejects changed saved catalog")
	_check(StadiumPoolOwnedSnapshot.valid(HISTORICAL_HOME), "retained historical full owned snapshot")
	var inputs: Array = [StadiumCatalog.VERSION, StadiumCatalog.ROWS, StadiumCatalog.STARTERS,
		StadiumCatalog.LIVE_UNITS, StadiumCatalog.LAND]
	for index: int in range(inputs.size()):
		var before: int = _readonly_nodes
		var containers: int = _readonly_containers
		var valid: bool = _readonly(inputs[index], 0)
		_readonly_rows.append({"input": INPUT_NAMES[index], "valid": valid,
			"nodes": _readonly_nodes - before, "containers": _readonly_containers - containers})
		_check(valid, "recursive readonly constant " + INPUT_NAMES[index])
	_check(_readonly_nodes == 1341 and _readonly_containers == 210
		and _readonly_max_depth == 3 and not _readonly_exhausted, "exact finite immutable literal graph")
	for id: String in ["ST-001", "ST-006", "ST-024"]:
		var item: Dictionary = StadiumCatalog.item(id)
		var before: PackedByteArray = var_to_bytes(item)
		var original: PackedByteArray = var_to_bytes(StadiumCatalog.ROWS[id])
		_check(not item.is_read_only() and not item.requires.is_read_only(),
			id + ": returned item and requirements are writable duplicates")
		item.name = "changed duplicate"
		item.copy_price += 1
		item.requires["seasons"] = 999
		_check(var_to_bytes(StadiumCatalog.ROWS[id]) == original
			and var_to_bytes(StadiumCatalog.item(id)) == before
			and Oracle.signature() == HISTORICAL and StadiumCatalog.signature() == HISTORICAL,
			id + ": duplicate mutation cannot alter original graph or signature")


func _json_same(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left, "", true, true) == JSON.stringify(right, "", true, true)


func _readonly(value: Variant, depth: int) -> bool:
	_readonly_nodes += 1
	_readonly_max_depth = maxi(_readonly_max_depth, depth)
	if _readonly_nodes > READONLY_NODE_CAP or depth > READONLY_DEPTH_CAP:
		_readonly_exhausted = true
		return false
	if value is Array or value is Dictionary:
		_readonly_containers += 1
		if not value.is_read_only():
			return false
		for key: Variant in value:
			if not _readonly(key, depth + 1):
				return false
			if value is Dictionary and not _readonly(value[key], depth + 1):
				return false
		return true
	return typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]


func _paid_mutations(property: StadiumPoolOwnedProperty, lab: PitchBatLab) -> bool:
	if not _check(not _ledger._stock.copies.is_empty() and not _ledger._events.is_empty()
		and not _ledger._requests.is_empty() and not _ledger._progress.is_empty()
		and not _ledger._credits.is_empty(), "actual paid mutation targets exist"):
		return false
	var copy_key: String = _ledger._stock.copies.keys()[0]
	var paid: Variant = _ledger._stock.copies[copy_key].paid
	if not _negative(property, lab, "owned_copy",
		func() -> void: _ledger._stock.copies[copy_key].paid = paid + 1,
		func() -> void: _ledger._stock.copies[copy_key].paid = paid):
		return false
	if not _negative(property, lab, "blueprints",
		func() -> void: _ledger._stock.blueprints.append("unowned-blueprint-probe"),
		func() -> void: _ledger._stock.blueprints.pop_back()):
		return false
	if not _negative(property, lab, "styles",
		func() -> void: _ledger._stock.styles.append("unowned-style-probe"),
		func() -> void: _ledger._stock.styles.pop_back()):
		return false
	var event_id: Variant = _ledger._events[0].id
	if not _negative(property, lab, "events",
		func() -> void: _ledger._events[0].id = event_id + "-probe",
		func() -> void: _ledger._events[0].id = event_id):
		return false
	var request_key: String = _ledger._requests.keys()[0]
	var request_id: Variant = _ledger._requests[request_key].id
	if not _negative(property, lab, "requests",
		func() -> void: _ledger._requests[request_key].id = request_id + "-probe",
		func() -> void: _ledger._requests[request_key].id = request_id):
		return false
	var wins: Variant = _ledger._progress[0].wins
	if not _negative(property, lab, "progress",
		func() -> void: _ledger._progress[0].wins = wins + 1,
		func() -> void: _ledger._progress[0].wins = wins):
		return false
	var credit: int = _ledger._credits[0]
	if not _negative(property, lab, "credits",
		func() -> void: _ledger._credits[0] = credit + 1,
		func() -> void: _ledger._credits[0] = credit):
		return false
	if not _negative(property, lab, "wall_blueprints",
		func() -> void: _ledger._wall_pieces.blueprints.append("unowned-wall-probe"),
		func() -> void: _ledger._wall_pieces.blueprints.pop_back()):
		return false
	if not _negative(property, lab, "wall_copies",
		func() -> void: _ledger._wall_pieces.stock.copies["catalog-unit-probe"] = {"probe": true},
		func() -> void: _ledger._wall_pieces.stock.copies.erase("catalog-unit-probe")):
		return false
	if not _negative(property, lab, "scoreboard_blueprints",
		func() -> void: _ledger._scoreboards.blueprints.append("unowned-scoreboard-probe"),
		func() -> void: _ledger._scoreboards.blueprints.pop_back()):
		return false
	if not _negative(property, lab, "scoreboard_copies",
		func() -> void: _ledger._scoreboards.copies["catalog-unit-probe"] = {"probe": true},
		func() -> void: _ledger._scoreboards.copies.erase("catalog-unit-probe")):
		return false
	var snapshots: Array[Dictionary] = [lab._match_state.stadium, property.frozen_snapshot,
		lab.get_meta("stadium_snapshot")]
	var labels: Array[String] = ["held_match_snapshot", "property_snapshot", "lab_metadata_snapshot"]
	for index: int in range(snapshots.size()):
		var snapshot: Dictionary = snapshots[index]
		var geometry: Variant = snapshot.geometry
		if not _negative(property, lab, labels[index],
			func() -> void: snapshot.geometry = geometry + "-probe",
			func() -> void: snapshot.geometry = geometry):
			return false
	return _check(_mutations.size() == 14 and _unchanged()
		and not lab.pool_controller_active._prepared.context._invalidated,
		"all direct-property cases restore without touching the context latch")


func _negative(property: StadiumPoolOwnedProperty, lab: PitchBatLab,
	label: String, change: Callable, restore: Callable) -> bool:
	var revision: int = _ledger.revision()
	var before: PackedByteArray = StadiumPoolOwnedAuthority._ledger_state(_ledger)
	var seal: PackedByteArray = property._snapshot_bytes.duplicate()
	change.call()
	var mutated_revision: int = _ledger.revision()
	var rejected: bool = not property.valid_owner(lab)
	_check(rejected and mutated_revision == revision and StadiumCatalog.signature() == HISTORICAL,
		label + ": actual direct property rejects mutation without revision bump")
	restore.call()
	var after: PackedByteArray = StadiumPoolOwnedAuthority._ledger_state(_ledger)
	var seal_preserved: bool = property._snapshot_bytes == seal
	var restored: bool = property.valid_owner(lab) and after == before and seal_preserved \
		and _ledger.revision() == revision and _unchanged() \
		and not lab.pool_controller_active._prepared.context._invalidated
	_check(restored, label + ": exact original state restores under nonpoisoning direct contract")
	_mutations.append({"label": label, "rejected": rejected, "restored": restored,
		"revision_before": revision, "revision_mutated": mutated_revision,
		"revision_after": _ledger.revision(), "seal_preserved": seal_preserved,
		"ledger_state_sha256": before.hex_encode().sha256_text(),
		"restored_ledger_sha256": after.hex_encode().sha256_text()})
	return rejected and restored and mutated_revision == revision


func _generation_diagnostic() -> bool:
	if not _generation_dir.is_absolute_path() or _generation_dir == _output \
		or DirAccess.make_dir_recursive_absolute(_generation_dir) != OK \
		or not DirAccess.get_files_at(_generation_dir).is_empty():
		return false
	var source: String = FileAccess.get_file_as_string("res://src/gameplay/stadium/stadium_catalog.gd")
	var oracle: String = FileAccess.get_file_as_string(
		"res://src/tests/stadium_catalog_signature_oracle.gd")
	var declarations: Dictionary = {}
	for name: String in INPUT_NAMES:
		var declaration: String = _declaration(source, name)
		if declaration.is_empty():
			return false
		declarations[name] = declaration.sha256_text()
	var header: String = "static func signature() -> String:\n"
	var start: int = oracle.find(header)
	if start < 0 or oracle.find(header, start + 1) >= 0:
		return false
	var body: String = oracle.substr(start).strip_edges(false, true) + "\n"
	var info: Dictionary = Engine.get_version_info()
	var engine_version: String = "%d.%d.%d.%s.%s.%s" % [
		info.major, info.minor, info.patch, info.status, info.build, String(info.hash).left(9)]
	var diagnostic: Dictionary = {"builder_signature": _signatures.builder,
		"declarations_sha256": declarations, "original_builder_sha256": body.sha256_text(),
		"engine_version": engine_version, "engine_version_string": info.string,
		"engine_version_info": info}
	var encoded: String = JSON.stringify(diagnostic, "", true, true)
	if encoded.to_utf8_buffer().size() > GENERATION_CAP:
		return false
	var path: String = _generation_dir.path_join("catalog-signature-generation.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(encoded)
	file.close()
	_generation_written = true
	return true


func _declaration(source: String, name: String) -> String:
	# Mirrors the check-only tool's declaration boundary; never evaluates or repairs source.
	var lines: PackedStringArray = source.split("\n")
	var found: int = -1
	var prefix: String = "const " + name
	for index: int in range(lines.size()):
		if lines[index].begins_with(prefix) and lines[index].length() > prefix.length() \
			and lines[index][prefix.length()] in [":", "=", " ", "\t"]:
			if found != -1:
				return ""
			found = index
	if found == -1:
		return ""
	var result: String = lines[found] + "\n"
	var index: int = found + 1
	while index < lines.size():
		var line: String = lines[index]
		if not line.strip_edges().is_empty() and not line.begins_with(" ") \
			and not line.begins_with("\t") and not line.begins_with("}") and not line.begins_with("]"):
			break
		result += line + "\n"
		index += 1
	return result.strip_edges(false, true) + "\n"
