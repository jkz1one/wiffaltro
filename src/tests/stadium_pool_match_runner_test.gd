extends Node
## One predeclared detached scheduled fixture. All other starts cancel before physics.
## Never launches/settles a SeasonApp game or changes ordinary automation/cadence.
# gdlint: disable=max-returns,max-file-lines

const REQUEST: Dictionary = {
	"version": 1, "authority": "EXPLICIT_PRIVATE_POOL_V27_DETACHED_MATCH", "enabled": true
}
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const SEASON_SEED: int = 42
const MATCH_SEED: int = 314229
const MAX_PHYSICS_FRAMES: int = 144120
const MAX_SUMMARY_BYTES: int = 8192
const MAX_PROVENANCE_BYTES: int = 1024 * 1024
const EXPECTED_NATIVE_CHECKS: int = 89 # Derived by recovery/test_pool_match_v27_fixture.py.

var _checks: int = 0
var _failures: int = 0
var _failed_labels: Array[String] = []
var _ordinary_reports: Array[Dictionary] = []
var _private_reports: Array[Dictionary] = []
var _errors: Array[String] = []
var _output_dir: String = ""
var _output_admitted: bool = false
var _expected_runtime: String = ""
var _actual_runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _app: SeasonApp
var _runner: PhysicalMatchRunner
var _ledger: ClubAssetLedger
var _source: MatchState
var _fixture: Dictionary = {}
var _request_key: String = ""
var _base_key: String = ""
var _save_files: Dictionary = {}
var _season_bytes: PackedByteArray
var _ledger_bytes: PackedByteArray
var _source_bytes: PackedByteArray
var _descriptor: Dictionary = {}
var _provenance: Dictionary = {}
var _played: MatchState
var _automation: MatchAutomation
var _records: Array[PlayRecord] = []
var _adapter: StadiumPoolControllerActive
var _live_lab: WeakRef
var _live_property: WeakRef
var _live_token: StadiumPoolBoundEntitlement
var _natural_starts: int = 0
var _observed_release_samples: int = 0
var _during_unchanged: bool = true
var _solid_contacts: int = 0
var _water_commits: int = 0
var _wall_start_usec: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-match-v27-dir="):
			_output_dir = argument.trim_prefix("--pool-match-v27-dir=")
		if argument.begins_with("--pool-match-v27-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-match-v27-runtime=")
		if argument.begins_with("--pool-match-v27-execution="):
			_execution = argument.trim_prefix("--pool-match-v27-execution=")
		if argument.begins_with("--pool-match-v27-nonce="):
			_nonce = argument.trim_prefix("--pool-match-v27-nonce=")
	_wall_start_usec = Time.get_ticks_usec()
	await _run()
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	if is_instance_valid(_app):
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_check(_checks + 1 == EXPECTED_NATIVE_CHECKS, "exact source-derived success assertion count")
	_write_summary()
	print(("POOL_MATCH_V27_OBSERVATION checks=%d failures=%d natural_starts=%d "
		+ "private=%d ordinary=%d solid=%d water=%d") % [
		_checks, _failures, _natural_starts, _private_reports.size(), _ordinary_reports.size(),
		_solid_contacts, _water_commits])
	print("POOL_MATCH_V27 checks=%d failures=%d source=%s" % [
		_checks, _failures, _actual_runtime])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	if not _check(not _output_dir.is_empty() and _output_dir.is_absolute_path(),
		"explicit absolute external evidence directory supplied"):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output_dir) == OK
		and not FileAccess.file_exists(_output_dir.path_join("pool-match-v27-envelope.json"))
		and not FileAccess.file_exists(_output_dir.path_join("pool-match-v27-provenance.json"))
		and not FileAccess.file_exists(_output_dir.path_join("pool-match-v27-summary.json")),
		"evidence destination has no prior fixture artifacts"):
		return
	_output_admitted = true
	_actual_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _check(_valid_hex(_expected_runtime, 64) and _valid_hex(_execution, 64)
		and _valid_hex(_nonce, 32) and _actual_runtime == _expected_runtime,
		"required runtime/execution/nonce bindings match the actual loaded Pool source"):
		return
	if not _check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
		and not get_tree().paused, "ordinary Jolt, 60 Hz and unpaused time-scale-one clock"):
		return
	if not await _genuine_setup():
		return
	_runner = PhysicalMatchRunner.new()
	add_child(_runner)
	_runner.finished.connect(func(report: Dictionary) -> void: _ordinary_reports.append(report))
	_runner.private_finished.connect(func(report: Dictionary) -> void: _private_reports.append(report))
	_runner.failed.connect(func(reason: String) -> void: _errors.append(reason))
	await _ordinary_probe(false)
	await _ordinary_probe(true)
	_rejected_requests()
	_pre_tree_controls()
	await _disabled_probe()
	await _rematch_controls()
	if not _check(_failures == 0 and _unchanged() and _private_reports.is_empty()
		and _ordinary_reports.is_empty() and _errors.is_empty(),
		"all bounded controls preserve checkpoint with no completed matches"):
		return
	if not _check(_runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger, REQUEST),
		"sole natural detached private match starts"):
		return
	_natural_starts += 1
	var lab: PitchBatLab = _runner._lab
	if not _installed(lab):
		_runner.cancel()
		return
	_played = lab._match_state
	_automation = lab._automation
	_records = lab._play_records
	_adapter = lab.pool_controller_active
	var property: StadiumPoolBoundProperty = StadiumPoolBoundExtension.current(lab)
	_live_token = property.entitlement
	_descriptor = _live_token.descriptor()
	_live_lab = weakref(lab)
	_live_property = weakref(property)
	_provenance["live_entitlement"] = {
		"owner": str(_descriptor.owner), "match": str(_descriptor.match),
		"serial": str(_descriptor.serial), "copy": _descriptor.copy,
		"source_sha256": _descriptor.source_sha256, "base_key": _descriptor.base_key
	}
	if not _write_json("pool-match-v27-provenance.json", _provenance, MAX_PROVENANCE_BYTES):
		_runner.cancel()
		return
	_check(not _runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger, REQUEST)
		and _runner._lab == lab and _live_token == property.entitlement,
		"running job cannot be overwritten or issued another token")
	await _complete()
	_observe_counts()
	_check(_natural_starts == 1 and _private_reports.size() == 1
		and _ordinary_reports.is_empty() and _errors.is_empty(),
		"exactly one private completion and no public completion or runner failure")
	_check(_played.phase == MatchState.Phase.GAME_END
		and _automation.releases.size() > 0 and _observed_release_samples > 0,
		"one complete natural GAME_END with real releases observed while running")
	_check(_during_unchanged and _unchanged(),
		"caller, held ledger, checkpoint and scheduled chronology unchanged during and after job")
	_check(_runner._lab == null and _runner._viewport == null and not _runner._running
		and _runner.get_child_count() == 0 and _live_lab.get_ref() == null
		and _live_property.get_ref() == null and not _adapter.enabled
		and _adapter._lab == null and _adapter._bound_profile == null,
		"completed private world, property and adapter fully cleaned up")
	if _private_reports.size() != 1:
		return
	_audit_report(_private_reports[0])
	await _ordinary_probe(true)
	await _fresh_private_probe()
	_check(_unchanged() and _private_reports.size() == 1 and _ordinary_reports.is_empty()
		and _errors.is_empty(), "postcompletion reuse remains detached and signal-isolated")
	_write_json("pool-match-v27-envelope.json",
		_private_reports[0], StadiumPoolMatchReport.MAX_JSON_BYTES)


func _genuine_setup() -> bool:
	var nonce: String = "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	SeasonSave.path = "user://pool-match-v27-" + nonce + ".json"
	PitchBatLabSettings.path = "user://pool-match-v27-settings-" + nonce + ".cfg"
	var fresh: bool = true
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			fresh = fresh and not FileAccess.file_exists(path + suffix)
	if not _check(fresh and not OS.get_environment("XDG_DATA_HOME").is_empty()
		and not OS.get_environment("XDG_CONFIG_HOME").is_empty()
		and not OS.get_environment("XDG_CACHE_HOME").is_empty()
		and ProjectSettings.globalize_path(SeasonSave.path).begins_with(OS.get_user_data_dir() + "/"),
		"fresh isolated primary, backup, temp and settings paths before app enters tree"):
		return false
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	if not _check(_app.season == null and SeasonSave.last_error.is_empty() and _app.lab == null,
		"fresh SeasonApp ready has no restored game or checkpoint error"):
		return false
	_app.begin_season(42, true, true, true, true, false)
	if not _check(_app.season != null and _app.season.season_seed == SEASON_SEED
		and _app.season.phase == SeasonState.Phase.DRAFT and _app.season.picks.is_empty()
		and _app.season.opponents != null and _app.season.opponents._format == 13
		and _app.season.physical != null and _app.season.career != null
		and not _app.season.player_access.is_empty()
		and ClubCareer.same(_app.season.player_access, ClubPlayers.owned(_app.season.career))
		and _app.season.home_property.get("version") == 3
		and _app.season.home_property.has("boundary") and SeasonSave.last_error.is_empty(),
		"actual Working policy13 permanent ownership, career and complete legacy property"):
		return false
	var assets: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var revision: int = assets.revision()
	var draft: Dictionary = ClubConstruction.save_draft(
		_app.season, StadiumPoolBoundEntitlement.base_layout(), revision)
	if not _check(draft.get("ok", false) and not draft.get("replayed", true),
		"actual pre-draft receiver-only save_draft commits at current revision"):
		return false
	assets = ClubPlayers.assets(_app.season.career)
	if not _check(assets.revision() == revision + 1,
		"reacquired actual ledger reflects draft transaction"):
		return false
	var applied: Dictionary = ClubConstruction.apply_draft(
		_app.season, StadiumPoolBoundEntitlement.base_layout(), assets.revision())
	if not _check(applied.get("ok", false) and not applied.get("replayed", true)
		and StadiumPoolBoundEntitlement.exact_base(
			_app.season.home_property, ClubPlayers.assets(_app.season.career)),
		"actual apply_draft freezes the exact owned receiver-only base"):
		return false
	var restored: SeasonState = SeasonSave.restore()
	if not _check(restored != null and SeasonSave.last_error.is_empty()
		and ClubCareer.same(SeasonSave.snapshot(restored), SeasonSave.snapshot(_app.season)),
		"normal checkpoint reload preserves exact committed draft/apply state"):
		return false
	_app.season = restored
	for pick: int in range(4):
		if not _check(_app.season.offers().size() == 3,
			"real current draft offer exists for pick %d" % pick):
			return false
		var selected: String = _app.season.offers()[0]
		_app.choose_player(selected)
		restored = SeasonSave.restore()
		if not _check(_app.season.picks.size() == pick + 1 and _app.season.picks[pick] == selected
			and restored != null and SeasonSave.last_error.is_empty()
			and ClubCareer.same(SeasonSave.snapshot(restored), SeasonSave.snapshot(_app.season)),
			"actual first-offer pick checkpoints exactly %d" % pick):
			return false
	# This exact final object is retained for the runner/token. No later save or reacquisition.
	_ledger = ClubPlayers.assets(_app.season.career)
	if not _check(_app.season.phase == SeasonState.Phase.REGULAR and _app.lab == null
		and _ledger.revision() == revision + 2
		and StadiumPoolBoundEntitlement.exact_base(_app.season.home_property, _ledger),
		"draft complete with one held actual ledger and no app lab"):
		return false
	for row: Dictionary in _app.season.schedule:
		if row.id == FIXTURE.id:
			_fixture = row.duplicate(true)
	if not _check(_fixture == FIXTURE and _app.season.round_index == 0
		and _app.season.pending_fixture() == {"id": 0, "round": 0, "away": 0, "home": 5}
		and _app.season.results.is_empty() and _app.season.player_results.is_empty()
		and _app.season.physical.reports.is_empty() and _app.season.physical.pending.is_empty(),
		"exact scheduled fixture3 is detached from unchanged pending fixture0 and round0"):
		return false
	_source = SeasonPhysicalFixtures.match_for(_app.season, _fixture)
	_request_key = SeasonPhysicalFixtures.request_key(_app.season, _fixture)
	_base_key = StadiumLayoutSnapshot.key(_source.stadium)
	if not _check(SeasonPhysicalFixtures.seed_for(_app.season, _fixture) == MATCH_SEED
		and SeasonState.field_for_fixture(_fixture).id == PitchBatLab.FIELD_ID
		and _source.away_team.ai_base and not _source.home_team.ai_base
		and _source.away_team.ai_budget.get("game") == 3
		and _source.home_team.ai_budget.is_empty() and _request_key.length() == 64
		and PhysicalMatchRequest.capture(_source) != null
		and StadiumPoolBoundEntitlement.exact_base(_source.stadium, _ledger),
		"real scheduled factory seed314229, home venue, away AI-Base and actual game3 budget"):
		return false
	_save_files = _saved_files()
	_season_bytes = var_to_bytes(SeasonSave.snapshot(_app.season))
	_ledger_bytes = var_to_bytes(_ledger.to_data())
	var source_data: Dictionary = _object_data(_source)
	_source_bytes = var_to_bytes(source_data)
	_provenance = {
		"source": _actual_runtime, "execution": _execution, "nonce": _nonce, "pid": OS.get_process_id(),
		"route": "DETACHED_SCHEDULED_FIXTURE_NO_SETTLEMENT", "season_seed": SEASON_SEED,
		"fixture": _fixture, "pending_fixture": _app.season.pending_fixture(), "round_index": 0,
		"match_seed": MATCH_SEED, "field": String(PitchBatLab.FIELD_ID), "request_key": _request_key,
		"private_request": REQUEST, "picks": _app.season.picks.duplicate(), "policy": 13,
		"base_key": _base_key, "base_property": _source.stadium.duplicate(true),
		"ledger_revision": _ledger.revision(), "ledger_sha256": _sha(_ledger_bytes),
		"caller_state_sha256": _sha(_source_bytes), "season_sha256": _sha(_season_bytes),
		"save_sha256": _sha(_save_files[""]),
		"resolved_save": ProjectSettings.globalize_path(SeasonSave.path),
		"resolved_settings": ProjectSettings.globalize_path(PitchBatLabSettings.path),
		"source_teams": [_object_data(_source.away_team), _object_data(_source.home_team)],
		"ai_tactical_quality": _source.ai_tactical_quality,
		"pre_tree_failure_coverage":
			"Direct configure rejection; runner cleanup branch source-audited only."
	}
	return _check(_unchanged() and source_data.get("phase") == MatchState.Phase.PRE_PITCH
		and source_data.has("stadium")
		and source_data.get("away_team", {}).get("roster", []).size() == 4
		and source_data.get("home_team", {}).get("roster", []).size() == 4
		and not FileAccess.get_file_as_string(SeasonSave.path).contains("private-pool-")
		and _ledger.construction().to_data() == StadiumStock.new_club().to_data(),
		"baseline checkpoint and stock contain no private Pool grant or evidence")


func _ordinary_probe(explicit_empty: bool) -> void:
	var frame: int = Engine.get_physics_frames()
	var started: bool = _runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger, {}) \
		if explicit_empty else _runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger)
	if not _check(started, "ordinary absent or empty request starts"):
		return
	var lab: PitchBatLab = _runner._lab
	var old: WeakRef = weakref(lab)
	_check(lab._stadium_ledger == null and lab.pool_controller_active == null
		and not lab.has_meta(StadiumPoolBoundExtension.REQUEST)
		and StadiumPoolBoundExtension.current(lab) == null and lab._automation.releases.is_empty()
		and Engine.get_physics_frames() == frame,
		"ordinary startup retains no private state before physics")
	_runner.cancel()
	await get_tree().process_frame
	_check(old.get_ref() == null and _runner.get_child_count() == 0
		and _runner._lab == null and _runner._viewport == null,
		"ordinary start cancels before release and frees viewport")


func _rejected_requests() -> void:
	var bad: Array[Dictionary] = [
		{"version": 1},
		{"version": 2, "authority": REQUEST.authority, "enabled": true},
		{"version": 1.0, "authority": REQUEST.authority, "enabled": true},
		{"version": true, "authority": REQUEST.authority, "enabled": true},
		{"version": 1, "authority": "FOREIGN", "enabled": true},
		{"version": 1, "authority": StringName(REQUEST.authority), "enabled": true},
		{"version": 1, "authority": REQUEST.authority, "enabled": 1},
		{"version": 1, "authority": REQUEST.authority, "enabled": "true"},
		{"version": 1, "authority": REQUEST.authority, "enabled": true, "extra": 1}
	]
	for request: Dictionary in bad:
		_reject(_source, _ledger, request, PitchBatLab.FIELD_ID)
	_reject(_source, null, REQUEST, PitchBatLab.FIELD_ID)
	_reject(_source, ClubAssetLedger.new(42, [0]), REQUEST, PitchBatLab.FIELD_ID)
	_reject(_source, _ledger, REQUEST, SeasonState.AWAY_FIELD_ID)
	var unsupported: MatchState = PhysicalMatchRequest.capture(_source)
	unsupported.stadium = {}
	_reject(unsupported, _ledger, REQUEST, PitchBatLab.FIELD_ID)


func _reject(source: MatchState, ledger: ClubAssetLedger,
	request: Dictionary, field: StringName) -> void:
	var frame: int = Engine.get_physics_frames()
	var serial: int = StadiumPoolBoundEntitlement._serial
	_check(not _runner.start(source, MATCH_SEED, field, ledger, request)
		and _runner._lab == null and _runner._viewport == null and not _runner._running
		and _runner.get_child_count() == 0 and Engine.get_physics_frames() == frame
		and StadiumPoolBoundEntitlement._serial == serial,
		"invalid request, ledger, base or field rejects before viewport and issuance")


func _pre_tree_controls() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = PhysicalMatchRequest.capture(_source)
	lab._stadium_ledger = _ledger
	var token: StadiumPoolBoundEntitlement = StadiumPoolBoundEntitlement.issue_private(
		lab, lab._configured_match.stadium, _ledger)
	if not _check(token != null and lab.get_parent() == null and not lab.is_inside_tree(),
		"direct pre-tree control obtains real captured-match entitlement"):
		lab.free()
		return
	# Direct existing configure rejection, not a runner hook or native runner-branch claim.
	lab._match_mode = false
	_check(not StadiumPoolBoundExtension.configure(lab, token, true)
		and not lab.has_meta(StadiumPoolBoundExtension.REQUEST),
		"direct pre-tree invalid mode rejects configuration without installation")
	token.retire()
	_check(not token.valid_for(lab, lab._configured_match.stadium, "ISSUED"),
		"failed direct configuration explicitly retires its issued token")
	var old: WeakRef = weakref(lab)
	lab.free()
	StadiumPoolBoundEntitlement._prune()
	_check(old.get_ref() == null, "failed direct pre-tree lab is freed without orphan")


func _disabled_probe() -> void:
	var request: Dictionary = REQUEST.duplicate(true)
	request.enabled = false
	var frame: int = Engine.get_physics_frames()
	if not _check(_runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger, request),
		"explicit disabled private mode starts with installed geometry"):
		return
	var lab: PitchBatLab = _runner._lab
	var property: StadiumPoolBoundProperty = StadiumPoolBoundExtension.current(lab)
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	var old: WeakRef = weakref(lab)
	_check(property != null and property.valid_owner(lab) and adapter != null
		and not adapter.enabled and adapter.freeflight_enabled and adapter._bound_profile == property
		and lab._stadium_ledger == _ledger and lab._automation.releases.is_empty()
		and adapter.commits == 0 and Engine.get_physics_frames() == frame,
		"disabled mode keeps exact private owner and zero water/release activity before physics")
	_runner.cancel()
	await get_tree().process_frame
	_check(old.get_ref() == null and _runner.get_child_count() == 0
		and adapter._lab == null and adapter._bound_profile == null,
		"disabled private start cancels and detaches without running a game")


func _rematch_controls() -> void:
	var frame: int = Engine.get_physics_frames()
	if not _check(_runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger, REQUEST),
		"bounded private rematch-ownership control starts"):
		return
	var lab: PitchBatLab = _runner._lab
	if not _installed(lab):
		_runner.cancel()
		return
	var property: StadiumPoolBoundProperty = StadiumPoolBoundExtension.current(lab)
	var token: StadiumPoolBoundEntitlement = property.entitlement
	var old: WeakRef = weakref(lab)
	var foreign: PitchBatLab = PitchBatLab.new()
	foreign._configured_match = PhysicalMatchRequest.capture(_source)
	foreign._stadium_ledger = _ledger
	_check(not StadiumPoolBoundExtension.configure(foreign, token, true),
		"installed token cannot configure a foreign fresh lab")
	foreign.free()
	lab._start_new_match()
	_check(lab.pool_bound_startup_failed and lab.pool_controller_active == null
		and not token.valid_for(lab, _source.stadium, "INSTALLED")
		and lab._automation.releases.is_empty() and Engine.get_physics_frames() == frame,
		"same-lab rematch revokes stale owner before first physics/release")
	_runner.cancel()
	await get_tree().process_frame
	_check(old.get_ref() == null and _runner.get_child_count() == 0,
		"rematch control cleanup frees stale private world")


func _installed(lab: PitchBatLab) -> bool:
	var property: StadiumPoolBoundProperty = StadiumPoolBoundExtension.current(lab)
	if not _check(property != null and property.valid_owner(lab) and property.plain_actors(lab)
		and not lab.pool_bound_startup_failed, "private property owns exact ordinary lab and actors"):
		return false
	var descriptor: Dictionary = property.entitlement.descriptor()
	_check(lab._match_state != _source and lab._stadium_ledger == _ledger
		and descriptor.owner == lab.get_instance_id()
		and descriptor.match == lab._match_state.get_instance_id()
		and descriptor.match != _source.get_instance_id() and descriptor.base_key == _base_key
		and descriptor.source_sha256 == _actual_runtime
		and property.entitlement.owns(lab, lab._match_state.stadium, property),
		"entitlement binds runner-captured state and exact held ledger, never caller state")
	_check(lab.pool_controller_active != null and lab.pool_controller_active.enabled
		and lab.pool_controller_active.freeflight_enabled
		and lab.pool_controller_active._bound_profile == property
		and lab._automation.get_script() == preload("res://src/gameplay/simulation/match_automation.gd")
		and lab._automation.seed == MATCH_SEED and not lab._automation.presentation_enabled
		and lab._at_bat_cadence.get_script() == preload(
			"res://src/labs/pitch_bat_lab/at_bat_cadence_controller.gd")
		and lab.is_physics_processing() and lab._primary_fielder.is_physics_processing()
		and not lab._debug_paused and lab._automation.releases.is_empty(),
		"active bound mode uses untouched ordinary automation, cadence and physics before release")
	return _failures == 0


func _complete() -> void:
	var previous_releases: int = 0
	for frame: int in range(MAX_PHYSICS_FRAMES):
		await get_tree().physics_frame
		if not _runner._running:
			break
		if _automation.releases.size() != previous_releases:
			previous_releases = _automation.releases.size()
			_observed_release_samples += 1
			_during_unchanged = _during_unchanged and _unchanged()
	_check(not _runner._running,
		"natural match reaches terminal runner state within unchanged simulation bound")
	if _runner._running:
		_runner.cancel()
	await get_tree().process_frame
	await get_tree().process_frame


func _audit_report(report: Dictionary) -> void:
	_check(StadiumPoolMatchReport.valid(report) and not PhysicalMatchReport.valid(report)
		and not SeasonPhysicalFixtures.envelope(
			{"fixture": 3, "request": _request_key, "report": report}),
		"private envelope validates only privately and cannot enter public season archive")
	var text: String = JSON.stringify(report, "", true, true)
	var decoded: Variant = JSON.parse_string(text)
	_check(StadiumPoolMatchReport.valid(decoded) and ClubCareer.same(report, decoded),
		"complete private envelope survives exact JSON roundtrip")
	var core: Dictionary = report.core
	var entitlement: Dictionary = report.extension.entitlement
	_check(core.seed == MATCH_SEED and core.field == String(PitchBatLab.FIELD_ID)
		and core.version == PhysicalMatchReport.BASE_VERSION and PhysicalMatchReport.valid(core)
		and core.releases.size() == _automation.releases.size()
		and ClubCareer.same(core.releases, _automation.releases)
		and PhysicalBaseReport.matches(core, _source) and _rosters_match(core)
		and core.away_runs == _played.away_team.runs and core.home_runs == _played.home_team.runs,
		"actual complete core preserves natural score, real pitches and ordinary report7 evidence")
	_check(entitlement.owner == str(_descriptor.owner) and entitlement.match == str(_descriptor.match)
		and entitlement.serial == str(_descriptor.serial) and entitlement.copy == _descriptor.copy
		and entitlement.base_key == _base_key and entitlement.source_sha256 == _descriptor.source_sha256
		and StadiumLayoutSnapshot.key(report.property) == _base_key and report.extension.active_enabled,
		"exported private entitlement correlates with the captured live owner and exact source")
	var reported_solids: int = 0
	var water_reasons: int = 0
	for row: Dictionary in report.surfaces:
		if row.reason in ["private_pool_controller_water_double", "private_pool_controller_water_foul"]:
			water_reasons += 1
		for event: Dictionary in row.events:
			if event.source == "item" and event.id == entitlement.copy:
				reported_solids += 1
	_check(report.surfaces.size() == core.plays.size() and _water_commits == _adapter.commits
		and water_reasons == _water_commits and report.water_commits == _water_commits
		and reported_solids == _solid_contacts
		and ClubCareer.same(report.surfaces, PhysicalStadiumContacts.capture(_records)),
		"all natural surface rows and actual water counts retained, including honest zero counts")


func _observe_counts() -> void:
	_solid_contacts = 0
	_water_commits = _adapter.commits
	for row: Dictionary in PhysicalStadiumContacts.capture(_records):
		for event: Dictionary in row.events:
			if event.source == "item" and event.id == _descriptor.copy:
				_solid_contacts += 1


func _rosters_match(core: Dictionary) -> bool:
	for index: int in range(2):
		var team: TeamMatchState = _source.away_team if index == 0 else _source.home_team
		var row: Dictionary = core.teams[index]
		if row.name != team.display_name or row.roster.size() != team.roster.size():
			return false
		for slot: int in range(4):
			var player: PlayerMatchState = team.roster[slot]
			var id: String = String(player.definition.id)
			var recipes: Array[String] = []
			for recipe: PitchDefinition in player.definition.starting_pitches:
				recipes.append(String(recipe.id))
			if row.roster[slot] != id or not ClubCareer.same(row.recipes[id], recipes) \
				or row.workload[id].capacity != player.stamina_max \
				or row.workload[id].initial != player.stamina_remaining:
				return false
	return true


func _fresh_private_probe() -> void:
	var frame: int = Engine.get_physics_frames()
	if not _check(_runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger, REQUEST),
		"fresh private lab can start after completed teardown"):
		return
	var lab: PitchBatLab = _runner._lab
	var property: StadiumPoolBoundProperty = StadiumPoolBoundExtension.current(lab)
	if not _installed(lab):
		_runner.cancel()
		return
	_check(property.entitlement != _live_token
		and property.entitlement.descriptor().copy != _descriptor.copy
		and not _live_token.valid_for(lab, lab._match_state.stadium, "INSTALLED")
		and Engine.get_physics_frames() == frame and lab._automation.releases.is_empty(),
		"fresh match owns new token and cannot replay completed entitlement before physics")
	var old: WeakRef = weakref(lab)
	_runner.cancel()
	await get_tree().process_frame
	_check(old.get_ref() == null and _runner.get_child_count() == 0,
		"fresh private rematch cancels without running another game")


func _saved_files() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["", ".bak", ".tmp"]:
		result[suffix] = FileAccess.get_file_as_bytes(SeasonSave.path + suffix) \
			if FileAccess.file_exists(SeasonSave.path + suffix) else null
	return result


func _unchanged() -> bool:
	return _app.lab == null and _app.season.round_index == 0 \
		and _app.season.pending_fixture().id == 0 \
		and _app.season.results.is_empty() and _app.season.player_results.is_empty() \
		and _app.season.physical.reports.is_empty() and _app.season.physical.pending.is_empty() \
		and _saved_files() == _save_files and not FileAccess.file_exists(PitchBatLabSettings.path) \
		and var_to_bytes(SeasonSave.snapshot(_app.season)) == _season_bytes \
		and var_to_bytes(_ledger.to_data()) == _ledger_bytes \
		and var_to_bytes(_object_data(_source)) == _source_bytes \
		and SeasonPhysicalFixtures.request_key(_app.season, _fixture) == _request_key


func _object_data(value: Variant) -> Variant:
	# Read every script variable, including non-exported match/team state; never deserialize.
	if value is RefCounted:
		var result: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				result[property.name] = _object_data(value.get(property.name))
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_object_data(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _object_data(value[key])
		return result
	return value


func _valid_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _sha(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _write_json(name: String, data: Dictionary, cap: int) -> bool:
	var text: String = JSON.stringify(data, "", true, true)
	if not _check(text.to_utf8_buffer().size() <= cap, "finite complete artifact byte bound: " + name):
		return false
	var file: FileAccess = FileAccess.open(_output_dir.path_join(name), FileAccess.WRITE)
	if not _check(file != null, "artifact destination opens: " + name):
		return false
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return _check(error == OK and FileAccess.get_file_as_string(_output_dir.path_join(name)) == text,
		"complete artifact write verified: " + name)


func _write_summary() -> void:
	var summary: Dictionary = {
		"source": _actual_runtime, "execution": _execution, "nonce": _nonce, "pid": OS.get_process_id(),
		"checks": _checks, "expected_checks": EXPECTED_NATIVE_CHECKS, "failures": _failures,
		"failed_labels": _failed_labels, "runner_errors": _errors,
		"route": "DETACHED_SCHEDULED_FIXTURE_NO_SETTLEMENT", "fixture": FIXTURE,
		"season_seed": SEASON_SEED, "match_seed": MATCH_SEED, "natural_starts": _natural_starts,
		"private_finished": _private_reports.size(), "ordinary_finished": _ordinary_reports.size(),
		"real_releases": _automation.releases.size() if _automation != null else 0,
		"live_release_observations": _observed_release_samples,
		"natural_pool_solid_contacts": _solid_contacts, "natural_water_commits": _water_commits,
		"game_end": _played != null and _played.phase == MatchState.Phase.GAME_END,
		"during_job_preserved": _observed_release_samples > 0 and _during_unchanged,
		"wall_seconds": (Time.get_ticks_usec() - _wall_start_usec) / 1000000.0,
		"zero_count_policy":
			"Zero natural contacts or water commits are valid observations; no search or replay.",
		"water_evidence_limit":
			"Count/reason/result consistency under live source-bound owner; "
			+ "not independent replay of every entry history.",
		"pre_tree_failure_coverage":
			"Direct configure-rejection teardown executed; "
			+ "runner configure-failure cleanup source-audited only."
	}
	if not _private_reports.is_empty():
		summary["score"] = [_private_reports[0].core.away_runs, _private_reports[0].core.home_runs]
		summary["simulated_seconds"] = _private_reports[0].core.elapsed
	var text: String = JSON.stringify(summary, "", true, true)
	# Summary transport failures fail the process without changing the assertion denominator.
	if not _output_admitted or text.to_utf8_buffer().size() > MAX_SUMMARY_BYTES:
		_failures += 1
		push_error("Pool match summary unavailable or exceeds finite byte cap")
		return
	var path: String = _output_dir.path_join("pool-match-v27-summary.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures += 1
		push_error("Pool match summary destination unavailable")
		return
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_string(path) != text:
		_failures += 1
		push_error("Pool match summary write verification failed")


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		_failed_labels.append(label)
		push_error(label)
	return condition
