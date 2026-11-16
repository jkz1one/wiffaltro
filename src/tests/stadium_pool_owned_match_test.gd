extends Node
## Public owned Pool: generated career, real purchase/layout, then two ordinary rounds.
## Existing automation controls genuine human-route labs before ready; no outcomes injected.
# gdlint: disable=max-file-lines,max-returns

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_MATCH_FRAMES: int = 144120
const MAX_ROUND_FRAMES: int = 288240
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const EXPECTED_NATIVE_CHECKS: int = 102 #101 independently counted path checks + this total guard.

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
var _human_starts: int = 0
var _ai_reports: Array[Dictionary] = []
var _human_rows: Array[Dictionary] = []
var _funding: Dictionary = {}
var _placements: Array[Dictionary] = []
var _wall_start: int = 0
var _output_admitted: bool = false
var _automation_ready: bool = true
var _terminal_fixture: int = -1
var _pending_snapshot: Dictionary = {}
var _match_wall_start: int = 0


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


func _ready() -> void:
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
	await _run()
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_check(_checks + 1 == EXPECTED_NATIVE_CHECKS, "exact reviewed successful assertion count")
	_write_summary({
		"version": 1, "pid": OS.get_process_id(), "checks": _checks,
		"expected_checks": EXPECTED_NATIVE_CHECKS, "failures": _failures, "failed": _failed,
		"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"human_starts": _human_starts, "ai_reports": _ai_reports.size(),
		"humans": _human_rows, "placements": _placements,
		"wall_seconds": (Time.get_ticks_usec() - _wall_start) / 1000000.0,
		"funding_label": "deterministically simulated test career, seed42, at most18 seasons",
		"production_qualified": false, "rendered_performance_qualified": false,
		"human_continue_ui_qualified": false})
	print("POOL_OWNED_V28 checks=%d failures=%d humans=%d ai=%d source=%s" % [
		_checks, _failures, _human_starts, _ai_reports.size(), _runtime])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and OS.get_cmdline_user_args().has("--physical-in-process"),
		"explicit external output and no child-engine round jobs"):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output) == OK
		and not FileAccess.file_exists(_output.path_join("pool-owned-v28-summary.json"))
		and not FileAccess.file_exists(_output.path_join("owned-career.json")),
		"fresh admitted output and career checkpoint"):
		return
	_output_admitted = true
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _check(_hex(_runtime, 64) and _runtime == _expected_runtime
		and _hex(_execution, 64) and _hex(_nonce, 32), "actual source and run identity bound"):
		return
	if not _check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
		and not get_tree().paused, "ordinary unpaused 60Hz Jolt clock"):
		return
	SeasonSave.path = _output.path_join("owned-career.json")
	PitchBatLabSettings.path = _output.path_join("owned-settings.cfg")
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if not _check(not FileAccess.file_exists(path + suffix), "new isolated save path"):
				return
	var career = CareerFixture.new()
	_funding = career.fund(SeasonSave.path)
	var saved_funding: Dictionary = _funding.duplicate(true)
	saved_funding.erase("season")
	if not _write("pool-owned-v28-generated-career.json", saved_funding):
		return
	if not _check(_funding.get("ok", false),
		"predeclared generated career earns ordinary eligibility"):
		return
	_app = ObservedApp.new()
	_app.terminal_observer = _capture_terminal
	_app.pending_observer = func(app: SeasonApp) -> void:
		_check(app.season.physical.pending.human.size() == (16 if app._fixture_id == 3 else 15),
			"owned home16 and ordinary away15 completed-game argument contracts")
		_pending_snapshot = SeasonSave.snapshot(app.season)
	add_child(_app)
	await get_tree().process_frame
	if not _check(_app.season != null and _app.season.phase == SeasonState.Phase.COMPLETE,
		"genuine funded completed career restored by ordinary SeasonApp"):
		return
	_app.begin_season(SEED, true, true, true, true, false)
	if not _check(_app.season != null and _app.season.phase == SeasonState.Phase.DRAFT
		and _app.season.picks.is_empty() and _app.season.physical != null
		and _app.season.opponents._format == 13 and not _app.season.player_access.is_empty(),
		"normal new Working season opens the earned journal before drafting"):
		return
	if not _purchase_and_place():
		return
	for index: int in range(4):
		if not _check(_app.season.offers().size() == 3, "ordinary current draft offer"):
			return
		var selected: String = _app.season.offers()[0]
		_app.choose_player(selected)
		if not _check(_app.season.picks.size() == index + 1
			and _app.season.picks[index] == selected, "unchanged first-offer draft selection"):
			return
	if not _check(_app.season.pending_fixture() == {"id": 0, "round": 0, "away": 0, "home": 5}
		and _app.season.results.is_empty(), "real opening fixture, no invented history"):
		return
	if not await _runner_pre_tree_controls():
		return
	_app.child_entered_tree.connect(_configure_ordinary_automation)
	_app.round_ui.runner.finished.connect(func(report: Dictionary) -> void:
		_ai_reports.append(report.duplicate(true))
		_progress_write("completed-ai-%d.json" % (_ai_reports.size() - 1), report,
			MAX_ARTIFACT_BYTES))
	if not await _play_round(0, false):
		return
	if not await _play_round(3, true):
		return
	_check(_human_starts == 2 and _ai_reports.size() == 4 and _automation_ready,
		"exact two human-route matches and four ordinary physical AI jobs")
	_check(_app.season.results.size() == 6 and _app.season.player_results.size() == 2
		and _app.season.physical.reports.size() == 4
		and _app.season.physical.pending.is_empty() and _app.season.round_index == 2,
		"two complete rounds publish once through genuine settlement")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(_app.season)), "save60 full career and physical results replay exactly")
	_write("pool-owned-v28-final-save.json", SeasonSave.snapshot(_app.season))
	_write("pool-owned-v28-ai-reports.json", {"reports": _ai_reports})
	_record_progress("complete", -1, null)


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


func _runner_pre_tree_controls() -> bool:
	var fixture: Dictionary = _fixture(3)
	if not _check(fixture == {"id": 3, "round": 1, "away": 4, "home": 0}
		and SeasonPhysicalFixtures.seed_for(_app.season, fixture) == 314229
		and _app.season.pending_fixture().id == 0 and _app.season.round_index == 0,
		"actual unique scheduled home fixture3 and seed before runner setup: "
		+ JSON.stringify(fixture)):
		return false
	var state: MatchState = SeasonPhysicalFixtures.match_for(_app.season, fixture)
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var seed: int = SeasonPhysicalFixtures.seed_for(_app.season, fixture)
	var before: Dictionary = SeasonSave.snapshot(_app.season)
	var owned_ready: bool = state != null and ledger != null \
		and (state.away_team.ai_base or state.home_team.ai_base) \
		and state.stadium.get("version") == StadiumPoolOwnedSnapshot.FIXTURE_VERSION \
		and StadiumPoolOwnedSnapshot.valid(state.stadium) \
		and StadiumPoolOwnedSnapshot.matches(state.stadium, ledger) \
		and state.stadium.environment.fixture == fixture.id \
		and state.stadium.environment.seed == seed \
		and SeasonState.field_for_fixture(fixture).id == PitchBatLab.FIELD_ID
	if not owned_ready:
		_write("pool-owned-v28-failure-context.json", {"stage": "owned_runner_precondition",
			"fixture": fixture, "seed": seed, "home_property": _app.season.home_property,
			"stadium": state.stadium if state != null else {},
			"ledger_revision": ledger.revision() if ledger != null else -1})
	if not _check(owned_ready, "actual fixture17 validates against held paid ledger before runner"):
		return false
	_runner = PhysicalMatchRunner.new()
	add_child(_runner)
	if not _check(not _runner.start(state, seed, PitchBatLab.FIELD_ID)
		and _runner._lab == null and _runner._viewport == null,
		"owned unattended runner refuses absent paid ledger before tree mutation"):
		_runner.cancel()
		return false
	var forged: MatchState = PhysicalMatchRequest.capture(state)
	if not _check(forged != null
		and forged.stadium.get("version") == StadiumPoolOwnedSnapshot.FIXTURE_VERSION
		and StadiumPoolOwnedSnapshot.valid(forged.stadium)
		and StadiumPoolOwnedSnapshot.matches(forged.stadium, ledger),
		"genuine scheduled owned runner request captures paid fixture17 shape"):
		return false
	forged.stadium.layout.pool.copy = "not-a-paid-copy"
	if not _check(not _runner.start(forged, seed, PitchBatLab.FIELD_ID, ledger)
		and _runner._lab == null and _runner._viewport == null,
		"forged paid copy refuses before tree mutation"):
		_runner.cancel()
		return false
	for mutation: String in ["descriptor", "transform"]:
		if not _check(_runner.start(state, seed, PitchBatLab.FIELD_ID, ledger),
			"fresh genuine paid owned unattended startup for disposable guard control"):
			return false
		var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(_runner._lab)
		var live: WeakRef = weakref(_runner._lab)
		if not _check(property != null and property.valid_owner(_runner._lab)
			and _runner._lab._stadium_ledger == ledger
			and _runner._lab._automation.releases.is_empty(),
			"paid owned startup has real property and zero releases before first physics tick"):
			_runner.cancel()
			return false
		_poison_disposable_preparation(_runner._lab, mutation)
		_runner.cancel()
		await get_tree().process_frame
		_check(live.get_ref() == null and _runner._lab == null and _runner._viewport == null
			and ClubCareer.same(before, SeasonSave.snapshot(_app.season)),
			"poisoned installation disposed before next fresh startup with no results or save mutation")
	return _failures == 0


func _poison_disposable_preparation(lab: PitchBatLab, mutation: String) -> void:
	# Only a disposable, zero-release installation. Never reused for an actual game.
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var model: Node3D = property.pool_model
	var carrier: Node3D = model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var identity: int = carrier.get_instance_id()
	var prepared: StadiumPoolModelPreparation = lab.pool_controller_active._prepared
	var descriptor: Dictionary = carrier.get_meta("descriptor")
	descriptor = descriptor.duplicate(true)
	var pose: Transform3D = carrier.transform
	_check(prepared.valid(model, StadiumPoolContract.LIVE, _runtime),
		"fresh actual production preparation valid before destructive control")
	if mutation == "descriptor":
		var changed: Dictionary = descriptor.duplicate(true)
		changed.height_m = float(changed.height_m) + 0.125
		carrier.set_meta("descriptor", changed)
	else:
		carrier.position.x += 0.125
	_check(carrier.get_instance_id() == identity
		and not prepared.valid(model, StadiumPoolContract.LIVE, _runtime)
		and prepared.context._invalidated,
		"same carrier mutation fails actual preparation and permanently invalidates context")
	carrier.set_meta("descriptor", descriptor)
	carrier.transform = pose
	_check(not prepared.valid(model, StadiumPoolContract.LIVE, _runtime)
		and prepared.context._invalidated and lab._automation.releases.is_empty(),
		"restoring bytes never revives poisoned authority; dispose before any physics tick")


func _configure_ordinary_automation(node: Node) -> void:
	if not node is PitchBatLab:
		return
	var lab: PitchBatLab = node
	_automation_ready = _automation_ready and not lab.is_node_ready() \
		and lab._match_state == null and lab._automation == null
	var fixture: Dictionary = _app.season.pending_fixture()
	lab._automation = MatchAutomation.new()
	lab._automation.seed = SeasonPhysicalFixtures.seed_for(_app.season, fixture)
	lab._automation.presentation_enabled = false
	_human_starts += 1


func _play_round(fixture_id: int, owned: bool) -> bool:
	if not _check(_app.season.pending_fixture().id == fixture_id
		and _app.season.physical.pending.is_empty(), "actual pending chronological human fixture"):
		return false
	var before_count: int = _app.season.results.size()
	var before_key: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	_match_wall_start = Time.get_ticks_usec()
	_pending_snapshot = {}
	_app.play_season_game()
	if not _check(_app.lab != null and _automation_ready and _app.lab._automation != null
		and _app.lab._player_home == owned, "genuine SeasonApp creates correct human-side live lab"):
		return false
	var lab: PitchBatLab = _app.lab
	var state: MatchState = lab._match_state
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	if not _check((property != null and property.valid_owner(lab)) if owned else property == null,
		"paid home property installed only on actual owned-home fixture"):
		return false
	for frame: int in range(MAX_MATCH_FRAMES):
		if _terminal_fixture == fixture_id:
			break
		if frame % 600 == 0:
			_record_progress("human", fixture_id, lab)
		await get_tree().physics_frame
	if not _check(_terminal_fixture == fixture_id and state.phase == MatchState.Phase.GAME_END,
		"ordinary automation reaches complete natural game within bound"):
		return false
	if not _check(not _pending_snapshot.is_empty(),
		"ordinary commit captured durable pending state before automatic round jobs"):
		return false
	var restored: SeasonState = SeasonSave.restore()
	if not _check(restored != null and SeasonSave.last_error.is_empty() and ClubCareer.same(
		SeasonSave.snapshot(restored), _pending_snapshot),
		"pending completed game survives exact save60 replay before round jobs"):
		return false
	if owned:
		var forged_pending: Dictionary = _pending_snapshot.duplicate(true)
		forged_pending.physical.pending.human[15].pool.copy = "unpaid"
		_check(SeasonSave._decode(forged_pending) == null,
			"forged completed human Pool owner cannot replay pending round")
	# Automation intentionally has no human outro. Continue through the same existing
	# completed-result branch; this does not qualify the rendered Continue UI.
	_app._commit_result()
	for frame: int in range(MAX_ROUND_FRAMES):
		if _app.season.results.size() == before_count + 3 and _app.season.physical.pending.is_empty():
			break
		if frame % 600 == 0:
			var current: Dictionary = _app.round_ui._projection.get("fixture", {})
			_record_progress("round", int(current.get("id", -1)), _app.round_ui.runner._lab)
		await get_tree().physics_frame
	if not _check(_app.season.results.size() == before_count + 3
		and _app.season.physical.pending.is_empty() and _app._result_saved,
		"normal sequential round jobs publish all three actual results exactly once"):
		return false
	var after: Dictionary = SeasonSave.snapshot(_app.season)
	var duplicate: SeasonState = SeasonSave._decode(after)
	_check(duplicate != null and not duplicate.callv(
		"record_player_result", _pending_snapshot.physical.pending.human)
		and ClubCareer.same(after, SeasonSave.snapshot(duplicate)),
		"settled human result cannot replay against the next pending fixture")
	_check(_app._commit_result() and ClubCareer.same(after, SeasonSave.snapshot(_app.season)),
		"repeated completed result does not rerun, repay or mutate settled round")
	_check(StadiumLayoutSnapshot.key(_app.season.home_property) == before_key,
		"season owned layout stays frozen through actual match and round settlement")
	return _failures == 0


func _capture_terminal(app: SeasonApp) -> void:
	var lab: PitchBatLab = app.lab
	var state: MatchState = lab._match_state
	var fixture_id: int = app.season.pending_fixture().id
	var owned: bool = fixture_id == 3
	var automation: MatchAutomation = lab._automation
	var report: Dictionary = PhysicalMatchReport.capture(lab)
	_check(PhysicalMatchReport.valid(report)
		and (report.version == StadiumPoolOwnedReport.VERSION if owned else
			report.version != StadiumPoolOwnedReport.VERSION), "complete actual unattended report captured")
	if owned:
		_check(StadiumPoolOwnedReport.matches(report, state.stadium, lab._stadium_ledger),
			"report14 matches actual paid fixture authority")
		_write("pool-owned-v28-report14.json", report)
	var human: Dictionary = StadiumPoolOwnedHumanEvidence.capture(lab, app.season) if owned else {}
	_check(not human.is_empty() if owned else human.is_empty(),
		"owned human-route evidence captured from same complete live PlayRecords")
	if owned:
		_write("pool-owned-v28-human-evidence.json", human)
	var solids: int = 0
	for play: PlayRecord in lab._play_records:
		for event: Dictionary in play.stadium_contacts:
			if owned and event.source == "item" and event.id == state.stadium.layout.pool.copy:
				solids += 1
	_human_rows.append({"fixture": fixture_id, "away": state.away_team.runs,
		"home": state.home_team.runs, "inning": state.inning, "top_half": state.top_half,
		"releases": automation.releases.size(), "plays": lab._play_records.size(),
		"next_plate_appearance_counter": state.plate_appearance_number,
		"completed_plate_appearances": state.base_flow.evidence(state).results.size(),
		"solid_pool_contacts": solids,
		"water_commits": lab.pool_controller_active.commits if owned else 0,
		"simulation_seconds": state.elapsed_seconds,
		"wall_seconds": (Time.get_ticks_usec() - _match_wall_start) / 1000000.0})
	_check(automation.releases.size() > 0 and automation.releases.size() == lab._play_records.size(),
		"actual release and pitch-record counts balance")
	if not owned:
		_progress_write("completed-human0-report.json", report, MAX_ARTIFACT_BYTES)
	_record_progress("human-completed", fixture_id, lab)
	_terminal_fixture = fixture_id


func _record_progress(stage: String, fixture: int, lab: PitchBatLab) -> void:
	var value: Dictionary = {"version": 1, "pid": OS.get_process_id(), "runtime": _runtime,
		"execution": _execution, "nonce": _nonce, "stage": stage, "fixture": fixture,
		"wall_seconds": (Time.get_ticks_usec() - _wall_start) / 1000000.0,
		"completed_humans": _human_rows, "completed_ai_reports": _ai_reports.size(),
		"checks": _checks, "failures": _failures, "live": {}}
	if is_instance_valid(lab) and lab._match_state != null:
		var state: MatchState = lab._match_state
		value.live = {"phase": state.phase, "inning": state.inning, "top_half": state.top_half,
			"away_runs": state.away_team.runs, "home_runs": state.home_team.runs,
			"plays": lab._play_records.size(), "simulation_seconds": state.elapsed_seconds,
			"releases": lab._automation.releases.size() if lab._automation != null else 0}
	_progress_write("pool-owned-v28-progress.json", value, 32768)


func _write_summary(value: Dictionary) -> bool:
	return _progress_write("pool-owned-v28-summary.json", value, 32768)


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
