extends Node
## Four isolated continuations of accepted actual human fixture0 on authored eligibility.
## No eligibility helper, human replay, fabricated game, credit injection or production edit.
# gdlint: disable=max-returns,max-file-lines

const ORIGIN_RUNTIME: String = "075f5df993d5386739a82b737cefe0d0cd3574aeec46fd73300b64bfa311007d"
const ORIGIN_EXECUTION: String = "151ff220446b482def881621b4acc8968c632dc5b2074b42949a42e40c17e962"
const MAX_FRAMES: int = 54060
const MAX_GAME_MSEC: int = 900000
const MAX_COLD_MSEC: int = 120000
const MAX_BYTES: int = 8 * 1024 * 1024
const PREDECESSORS: Dictionary = {
	"ai1": "cold", "ai2": "ai1", "reroll": "ai2", "cold-reroll": "reroll"
}
var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _state_dir: String = ""
var _output: String = ""
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _action: String = ""
var _app: SeasonApp
var _admitted: bool = false
var _started: int = 0
var _human_starts: int = 0
var _ai_reports: int = 0
var _completed_games: int = 0
var _status: String = "failed"
var _terminal: Dictionary = {}
var _proofs: Dictionary = {}
var _before: Dictionary = {}
var _before_journals: Dictionary = {}
var _entry: Dictionary = {}
var _receipt: Dictionary = {}
var _input: Dictionary = {}
var _entry_hashes: Dictionary = {}
var _origin_pending: Dictionary = {}
var _job_fixture: Dictionary = {}
var _job_request: String = ""


func _ready() -> void:
	_started = Time.get_ticks_msec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--d1-state-dir="):
			_state_dir = argument.trim_prefix("--d1-state-dir=")
		elif argument.begins_with("--d1-output="):
			_output = argument.trim_prefix("--d1-output=")
		elif argument.begins_with("--d1-runtime="):
			expected = argument.trim_prefix("--d1-runtime=")
		elif argument.begins_with("--d1-execution="):
			_execution = argument.trim_prefix("--d1-execution=")
		elif argument.begins_with("--d1-nonce="):
			_nonce = argument.trim_prefix("--d1-nonce=")
		elif argument.begins_with("--d1-action="):
			_action = argument.trim_prefix("--d1-action=")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(
		(
			args.size() == 7
			and args.has("--physical-in-process")
			and _runtime.length() == 64
			and _runtime == expected
			and _execution.length() == 64
			and _nonce.length() == 32
			and PREDECESSORS.has(_action)
		),
		"exact source and one continuation action"
	):
		await _run()
	if is_instance_valid(_app):
		_app.round_ui.cancel()
		_app._close_match()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	var summary: Dictionary = {
		"schema": "STANDARD-D1-ROUND-JOURNAL-v1",
		"pid": OS.get_process_id(),
		"runtime": _runtime,
		"execution": _execution,
		"nonce": _nonce,
		"action": _action,
		"checks": _checks,
		"failures": _failures,
		"failed": _failed,
		"status": _status if _failures == 0 else "failed",
		"human_starts": _human_starts,
		"ai_reports": _ai_reports,
		"completed_games": _completed_games,
		"terminal": _terminal.duplicate(true),
		"proofs": _proofs.duplicate(true),
		"wall_seconds": (Time.get_ticks_msec() - _started) / 1000.0,
		"synthetic_eligibility_prefix": true,
		"synthetic_prefix_run_ids": [1],
		"prefix_kind": "authored-structural-fixture-only",
		"genuine_promotion": false,
		"new_game_history_synthetic": false,
		"round_settled":
		_failures == 0 and _status in ["round_settled", "reroll_saved", "cold_reroll_preserved"],
		"paid_reroll_covered":
		_failures == 0 and _status in ["reroll_saved", "cold_reroll_preserved"],
		"synthetic_credit_claim": false,
		"earned_final_verified": false,
		"manual_input_qualified": false,
		"performance_qualified": false
	}
	_write(_output, "summary.json", summary)
	print("STANDARD_D1_ROUND_JOURNAL ", JSON.stringify(summary, "", true, true))
	get_tree().quit(0 if _failures == 0 and _status != "failed" else 1)


func _run() -> void:
	var expected_files: PackedStringArray = ["continuation-input.json", "predecessor-snapshot.json"]
	if _action != "ai1":
		expected_files.append("predecessor-journals.json")
	expected_files.sort()
	var actual_files: PackedStringArray = DirAccess.get_files_at(_output)
	actual_files.sort()
	if not _check(
		(
			_state_dir.is_absolute_path()
			and _output.is_absolute_path()
			and _state_dir != _output
			and not _state_dir.begins_with(_output + "/")
			and not _output.begins_with(_state_dir + "/")
			and actual_files == expected_files
			and DirAccess.get_directories_at(_output).is_empty()
		),
		"exact isolated admission inventory"
	):
		return
	_admitted = true
	SeasonSave.path = _state_dir.path_join("season.json")
	PitchBatLabSettings.path = _state_dir.path_join("settings.cfg")
	_entry = _read(_state_dir, "season.json")
	_entry_hashes = {
		"primary": FileAccess.get_sha256(SeasonSave.path),
		"backup": FileAccess.get_sha256(SeasonSave.path + ".bak")
	}
	_input = _read(_output, "continuation-input.json")
	if not _check(_clock(), "ordinary unpaused fixed60 clock"):
		return
	if not _check(
		(
			_input.get("schema") == "STANDARD-D1-ROUND-JOURNAL-INPUT-v1"
			and _input.get("action") == _action
			and _input.get("predecessor_action") == PREDECESSORS[_action]
			and str(_input.get("predecessor_result_sha256", "")).length() == 64
			and str(_input.get("predecessor_runtime", "")).length() == 64
			and str(_input.get("predecessor_execution", "")).length() == 64
			and _input.get("predecessor_pid", OS.get_process_id()) != OS.get_process_id()
			and _input.get("save_sha256") == _entry_hashes.primary
			and _input.get("backup_sha256") == _entry_hashes.backup
			and not _entry.is_empty()
			and (
				_input.get("snapshot_sha256")
				== FileAccess.get_sha256(_output.path_join("predecessor-snapshot.json"))
			)
			and (
				(_action == "ai1" and _input.get("journals_sha256") == "")
				or (
					_action != "ai1"
					and (
						_input.get("journals_sha256")
						== FileAccess.get_sha256(_output.path_join("predecessor-journals.json"))
					)
				)
			)
		),
		"accepted predecessor raw input joins"
	):
		return
	_receipt = _read(_state_dir, "pending-receipt.json")
	_origin_pending = _read(_state_dir, "human-pending.json")
	if not _check(
		(
			_receipt.get("runtime") == ORIGIN_RUNTIME
			and _receipt.get("execution") == ORIGIN_EXECUTION
			and _receipt.get("status") == "human_pending"
			and _receipt.get("prefix_kind") == "authored-structural-fixture-only"
			and (
				_receipt.get("report_sha256")
				== FileAccess.get_sha256(_state_dir.path_join("human-report.json"))
			)
			and (
				_receipt.get("pending_sha256")
				== FileAccess.get_sha256(_state_dir.path_join("human-pending.json"))
			)
			and (
				_receipt.get("origin_sha256")
				== FileAccess.get_sha256(_state_dir.path_join("origin.json"))
			)
			and (
				_receipt.get("prefix_sha256")
				== FileAccess.get_sha256(_state_dir.path_join("synthetic-prefix.json"))
			)
			and not _origin_pending.is_empty()
		),
		"immutable original human producer and authored prefix"
	):
		return
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.round_ui.process_jobs = false
	_app.child_entered_tree.connect(_unexpected_human)
	if _action in ["reroll", "cold-reroll"]:
		_app.round_ui.runner.finished.connect(_unexpected_ai)
	if not _check(
		_app.season != null and _app.lab == null and not _app.round_ui._working,
		"fresh ordinary app restores without starting a human game"
	):
		return
	_before = SeasonSave.snapshot(_app.season).duplicate(true)
	_before_journals = _journals(_app.season)
	_write(_output, "before.json", _before)
	_write(_output, "before-journals.json", _before_journals)
	if not _proof(
		"entry_snapshot",
		(
			ClubCareer.same(_entry, _before)
			and ClubCareer.same(_before, _read(_output, "predecessor-snapshot.json"))
			and ClubCareer.same(_before, _read(_output, "before.json"))
			and ClubCareer.same(_before_journals, _read(_output, "before-journals.json"))
		)
	):
		return
	if (
		_action != "ai1"
		and not _proof(
			"predecessor_journals",
			ClubCareer.same(_before_journals, _read(_output, "predecessor-journals.json"))
		)
	):
		return
	if not _d1_context(_before) or not _origin_valid():
		return
	match _action:
		"ai1", "ai2":
			await _round_job()
		"reroll":
			await _reroll()
		"cold-reroll":
			_cold_reroll()
	if _failures == 0 and _status != "failed":
		_checkpoint_proofs()


func _round_job() -> void:
	var prior: int = 0 if _action == "ai1" else 1
	if not _check(
		(
			_app.round_ui.shade.visible
			and not _app.round_ui._working
			and not _app.season.physical.pending.is_empty()
			and _app.season.physical.pending.reports.size() == prior
			and _unpaid()
			and _app.season.build.cash() == 0
			and _app.season.round_index == 0
		),
		"one scheduled AI starts from exact unpaid pending count"
	):
		return
	_app.round_ui.runner.finished.connect(_report_finished)
	_app.round_ui.resume()
	_job_fixture = _app.round_ui._projection.get("fixture", {}).duplicate(true)
	if not _check(
		(
			not _job_fixture.is_empty()
			and _app.round_ui._working
			and _app.round_ui.runner._running
			and 0 not in [_job_fixture.home, _job_fixture.away]
		),
		"ordinary Resume starts one actual nonhuman fixture"
	):
		return
	_job_request = SeasonPhysicalFixtures.request_key(
		_app.round_ui._projection.candidate, _job_fixture
	)
	_write(
		_output,
		"job.json",
		{
			"fixture": _job_fixture.duplicate(true),
			"request": _job_request,
			"seed": SeasonPhysicalFixtures.seed_for(_app.season, _job_fixture)
		}
	)
	for frame: int in range(MAX_FRAMES):
		if _ai_reports > 0:
			break
		if (
			not _app.round_ui._working
			or not _clock()
			or Time.get_ticks_msec() - _started >= MAX_GAME_MSEC
		):
			_check(
				false,
				(
					"physical job paused or exceeded900-second scene bound: "
					+ _app.round_ui.detail.text
				)
			)
			return
		if frame % 600 == 0:
			print(
				"D1_ROUND_PROGRESS ",
				_action,
				" fixture=",
				_job_fixture.id,
				" seconds=",
				_app.round_ui.runner._elapsed,
				" stalled=",
				_app.round_ui.runner._stalled
			)
		await get_tree().physics_frame
	if not _check(
		(
			_ai_reports == 1
			and _completed_games == 1
			and _human_starts == 0
			and not _app.round_ui._working
			and not _app.round_ui.runner._running
		),
		"exactly one actual AI report and no next completed job"
	):
		return
	var after: Dictionary = SeasonSave.snapshot(_app.season).duplicate(true)
	var old_envelopes: Dictionary = _envelopes(_before)
	var new_envelopes: Dictionary = _envelopes(after)
	var preserved: bool = new_envelopes.size() == prior + 1
	for id: String in old_envelopes:
		preserved = (
			preserved
			and new_envelopes.has(id)
			and ClubCareer.same(old_envelopes[id], new_envelopes[id])
		)
	if not _proof(
		"ai_envelope_chain",
		(
			preserved
			and new_envelopes.has(str(int(_job_fixture.id)))
			and new_envelopes[str(int(_job_fixture.id))].request == _job_request
		)
	):
		return
	if _action == "ai1":
		if not _proof(
			"ai1_unpaid",
			(
				_unpaid()
				and after.physical.pending.reports.size() == 1
				and ClubCareer.same(_before.physical.pending.human, after.physical.pending.human)
				and ClubCareer.same(_before.build, after.build)
				and ClubCareer.same(_before.opponents, after.opponents)
				and ClubCareer.same(_before.career, after.career)
				and ClubCareer.same(_before_journals, _journals(_app.season))
			)
		):
			return
		_status = "ai1_pending"
	else:
		if not _proof(
			"ai2_atomic_settlement",
			(
				_app._result_saved
				and _settled(_app.season)
				and after.results.size() == 1
				and _app.season.build.cash() == 18
			)
		):
			return
		var intermediate: Dictionary = _read(_output, "completed-backup.json")
		var live_backup: Dictionary = _read(_state_dir, "season.json.bak")
		if not _proof(
			"ai2_pending_backup",
			(
				not intermediate.get("physical", {}).get("pending", {}).is_empty()
				and intermediate.physical.pending.reports.size() == 2
				and intermediate.results.is_empty()
				and intermediate.physical.reports.is_empty()
				and ClubCareer.same(
					intermediate.physical.pending.human, _before.physical.pending.human
				)
				and ClubCareer.same(intermediate.build, _before.build)
				and ClubCareer.same(intermediate.opponents, _before.opponents)
				and ClubCareer.same(_envelopes(intermediate), new_envelopes)
				and ClubCareer.same(intermediate, live_backup)
				and (
					FileAccess.get_sha256(_output.path_join("completed-backup.json"))
					== FileAccess.get_sha256(SeasonSave.path + ".bak")
				)
			)
		):
			return
		_status = "round_settled"


func _report_finished(report: Dictionary) -> void:
	_ai_reports += 1
	_completed_games += 1
	# The application's earlier callback has saved this report and may start the next job.
	# Retain the completed checkpoint before any later proof can fail; never replay it.
	_app.round_ui.cancel()
	_write(_output, "ai-report.json", report.duplicate(true))
	var completed: Dictionary = SeasonSave.snapshot(_app.season).duplicate(true)
	_write(_output, "completed-snapshot.json", completed)
	_retain_raw(SeasonSave.path, "completed-primary.json")
	_retain_raw(SeasonSave.path + ".bak", "completed-backup.json")
	var envelopes: Dictionary = _envelopes(completed)
	var envelope: Dictionary = envelopes.get(str(int(_job_fixture.get("id", -1))), {}).duplicate(
		true
	)
	_write(_output, "ai-envelope.json", envelope)
	_proof(
		"completed_ai_report",
		(
			_ai_reports == 1
			and PhysicalMatchReport.valid(report)
			and report.releases.size() > 0
			and envelope.get("request") == _job_request
			and ClubCareer.same(envelope.get("report", {}), report)
			and ClubCareer.same(completed, _read(_state_dir, "season.json"))
			and ClubCareer.same(completed, _read(_output, "completed-snapshot.json"))
			and ClubCareer.same(completed, _read(_output, "completed-primary.json"))
			and ClubCareer.same(report, _read(_output, "ai-report.json"))
			and ClubCareer.same(envelope, _read(_output, "ai-envelope.json"))
		)
	)


func _reroll() -> void:
	if not _check(
		(
			_settled(_app.season)
			and _app.season.shop_available()
			and _app.season.build.cash() == 18
			and _app.season.build._visit.number == 1
			and not _app.season.build._visit.open
			and _human_shop_events(_before.build.events) == 0
			and _app.season.build.view().wallet.sponsors.is_empty()
		),
		"first earned human shop with18 actual Cash"
	):
		return
	_app.open_shop()
	await get_tree().process_frame
	var shop: SeasonShopWindow
	for child: Node in _app.menu.get_children():
		if child is SeasonShopWindow:
			shop = child
	if not _check(
		shop != null and shop.visible and _app.season.build._visit.open,
		"ordinary saved shop open displays its window"
	):
		return
	var opened: Dictionary = SeasonSave.snapshot(_app.season).duplicate(true)
	var opened_journals: Dictionary = _journals(_app.season)
	var opened_view: Dictionary = _app.season.build.view().duplicate(true)
	_write(_output, "shop-open.json", opened)
	_write(_output, "shop-open-journals.json", opened_journals)
	if not _proof(
		"ordinary_shop_open",
		(
			opened.build.events.size() == _before.build.events.size() + 1
			and ClubCareer.same(opened.build.events.slice(0, -1), _before.build.events)
			and opened.build.events[-1].op == "open"
			and opened_view.shop.rerolls == 0
			and SeasonReclamation.credit(opened_view.shop) == 0
			and opened_view.wallet.cash == 18
			and ClubCareer.same(opened.opponents, _before.opponents)
			and ClubCareer.same(opened, _read(_output, "shop-open.json"))
			and ClubCareer.same(opened_journals, _read(_output, "shop-open-journals.json"))
		)
	):
		return
	var request: Dictionary = shop._request("reroll").duplicate(true)
	var quote: int = _app.season.build.reroll_price()
	var visible_quote: String = _reroll_button(shop)
	var preview: Dictionary = _app.season.build.preview(request).duplicate(true)
	shop._preview(request, "First ordinary d1 individual-offer reroll")
	_write(
		_output,
		"reroll-review.json",
		{
			"request": request.duplicate(true),
			"quote": quote,
			"button": visible_quote,
			"review": shop._review_text.text,
			"preview": preview.duplicate(true)
		}
	)
	if not _proof(
		"reroll_preview",
		(
			quote == 5
			and visible_quote == "Reroll individual offers • 5 Cash"
			and preview.get("ok", false)
			and preview.before_cash == 18
			and preview.after.wallet.cash == 13
			and shop._confirm.visible
			and ClubCareer.same(shop._pending, request)
			and shop._review_text.text.contains("Cash: 18 → 13")
			and ClubCareer.same(opened, SeasonSave.snapshot(_app.season))
			and ClubCareer.same(opened_journals, _journals(_app.season))
			and ClubCareer.same(preview, _read(_output, "reroll-review.json").get("preview", {}))
		)
	):
		return
	shop._commit()
	var after: Dictionary = SeasonSave.snapshot(_app.season).duplicate(true)
	var view: Dictionary = _app.season.build.view().duplicate(true)
	if not _proof(
		"reroll_commit",
		(
			after.build.events.size() == opened.build.events.size() + 1
			and ClubCareer.same(after.build.events.slice(0, -1), opened.build.events)
			and ClubCareer.same(after.build.events[-1], request)
			and after.build.events[-1].op == "reroll"
			and view.wallet.cash == 13
			and view.shop.rerolls == 1
			and SeasonReclamation.credit(view.shop) == 0
			and _app.season.build.reroll_price() == 7
			and _reroll_button(shop) == "Reroll individual offers • 7 Cash"
			and not ClubCareer.same(opened_view.shop.offers, view.shop.offers)
			and ClubCareer.same(opened.build.recruits, after.build.recruits)
			and ClubCareer.same(opened_view.shop.get("recruit", {}), view.shop.get("recruit", {}))
			and opened_view.shop.pack_status == view.shop.pack_status
			and opened_view.shop.get("choice_count", 0) == view.shop.get("choice_count", 0)
			and ClubCareer.same(opened_view.wallet.rewards, view.wallet.rewards)
			and _settled(_app.season)
			and ClubCareer.same(opened_journals.human.pack, _journals(_app.season).human.pack)
			and ClubCareer.same(opened.opponents, after.opponents)
			and ClubCareer.same(opened.results, after.results)
			and ClubCareer.same(opened.physical, after.physical)
		)
	):
		return
	if not _proof(
		"reroll_saved_backup",
		(
			ClubCareer.same(after, _read(_state_dir, "season.json"))
			and ClubCareer.same(opened, _read(_state_dir, "season.json.bak"))
		)
	):
		return
	_terminal["reroll"] = {
		"request": request.duplicate(true),
		"quoted": quote,
		"before_cash": 18,
		"after_cash": 13,
		"next_quote": 7,
		"synthetic_credit": false
	}
	_status = "reroll_saved"


func _cold_reroll() -> void:
	var view: Dictionary = _app.season.build.view().duplicate(true)
	var events: Array = _app.season.build.to_data().events.duplicate(true)
	if not _check(
		(
			_settled(_app.season)
			and _app.lab == null
			and not _app.round_ui.shade.visible
			and not _app.round_ui._working
			and not _app.round_ui.runner._running
			and _human_shop_events(events) == 2
			and events[-2].op == "open"
			and events[-1].op == "reroll"
			and view.wallet.cash == 13
			and view.shop.rerolls == 1
			and SeasonReclamation.credit(view.shop) == 0
			and _app.season.build.reroll_price() == 7
		),
		"cold ordinary restore preserves first paid reroll"
	):
		return
	if not _proof(
		"cold_journal_no_write",
		(
			ClubCareer.same(_before, SeasonSave.snapshot(_app.season))
			and ClubCareer.same(_before_journals, _journals(_app.season))
			and _entry_hashes.primary == FileAccess.get_sha256(SeasonSave.path)
			and _entry_hashes.backup == FileAccess.get_sha256(SeasonSave.path + ".bak")
			and not FileAccess.file_exists(SeasonSave.path + ".tmp")
			and _human_starts == 0
			and _ai_reports == 0
			and _completed_games == 0
		)
	):
		return
	_terminal["reroll"] = {
		"request": events[-1].duplicate(true),
		"quoted": 5,
		"before_cash": 18,
		"after_cash": 13,
		"next_quote": 7,
		"synthetic_credit": false
	}
	_status = "cold_reroll_preserved"


func _origin_valid() -> bool:
	var report: Dictionary = _read(_state_dir, "human-report.json")
	var human: Array = _origin_pending.get("physical", {}).get("pending", {}).get("human", [])
	var fixture: Dictionary = SeasonVenues.fixture_for_id(_app.season, 0)
	var venue: Dictionary = StadiumLayoutSnapshot.for_fixture(_app.season, fixture)
	if not _proof(
		"original_human",
		(
			not fixture.is_empty()
			and fixture.id == 0
			and fixture.away == 0
			and PhysicalMatchReport.valid(report)
			and report.version == 17
			and report.releases.size() == 183
			and report.away_runs == 10
			and report.home_runs == 7
			and PhysicalStadiumReport.matches(report, venue)
			and StadiumNpcSnapshot.matches_fixture(report.property, _app.season, fixture)
			and human.size() == 17
			and human[0] == 0
			and human[1] == 10
			and human[2] == 7
			and human[15] == null
			and StadiumNpcYardTwoHumanEvidence.valid(human[16])
			and report.seed == SeasonPhysicalFixtures.seed_for(_app.season, fixture)
			and human[14] == StadiumLayoutSnapshot.key(venue)
			and ClubCareer.same(human[3], report.performance)
		)
	):
		return false
	return _proof(
		"origin_context",
		(
			ClubCareer.same(_before.home_property, _origin_pending.home_property)
			and ClubCareer.same(_before.npc_venues, _origin_pending.npc_venues)
			and ClubCareer.same(_before.final_venue, _origin_pending.final_venue)
			and _before.career.current == 2
			and _before.career.runs.size() == 2
			and ClubCareer.same(_before.career.runs[0], _origin_pending.career.runs[0])
			and _before.seed == _origin_pending.seed
		)
	)


func _d1_context(data: Dictionary) -> bool:
	if not _check(
		(
			data.get("version") == 68
			and data.career.version == 23
			and data.build.version == 42
			and data.build.market == 0
			and data.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
			and data.opponents.policy == 13
			and data.opponents.clubs.size() == 5
			and data.npc_venues.venue_ordinal == 1
			and data.final_venue.version == 2
			and data.final_venue.selection == SeasonFinalVenue.STANDARD_D1_SELECTION
			and _app.season.career.active_tier() == 1
			and SeasonFinalVenue.matches_season(_app.season)
		),
		"save68 human42 d1 rule and ordinal1 final context"
	):
		return false
	for index: int in range(1, 6):
		var club: Dictionary = data.opponents.clubs.get(str(index), {})
		if not _check(
			(
				club.get("build", {}).get("version") == 42
				and club.build.market == 12
				and club.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
			),
			"AI%d keeps exact42 market12 rule" % index
		):
			return false
	return true


func _unpaid() -> bool:
	if (
		not _app.season.results.is_empty()
		or not _app.season.player_results.is_empty()
		or not _app.season.physical.reports.is_empty()
		or not _app.season.build._bank.view().rewards.is_empty()
	):
		return false
	for club: Dictionary in _app.season.opponents.clubs.values():
		if not club.build._bank.view().rewards.is_empty():
			return false
	return true


func _settled(season: SeasonState) -> bool:
	if (
		season.results.size() != 3
		or season.player_results.size() != 1
		or season.round_index != 1
		or season.physical.reports.size() != 2
		or not season.physical.pending.is_empty()
		or season.phase != SeasonState.Phase.REGULAR
	):
		return false
	var human: Dictionary = season.player_results[0]
	if (
		human.id != 0
		or human.away_runs != 10
		or human.home_runs != 7
		or not ClubCareer.same(human.performance, _origin_pending.physical.pending.human[3])
	):
		return false
	for index: int in range(6):
		var expected: Dictionary = {}
		for fixture: Dictionary in season.results:
			if index in [int(fixture.home), int(fixture.away)]:
				expected[str(int(fixture.id))] = SeasonState._winner(fixture) == index
		var build: SeasonBuild = (
			season.build if index == 0 else season.opponents.clubs[str(index)].build
		)
		if expected.size() != 1 or not ClubCareer.same(build._bank.view().rewards, expected):
			return false
	return true


func _journals(season: SeasonState) -> Dictionary:
	var ai: Dictionary = {}
	for index: int in range(1, 6):
		var club: Dictionary = season.opponents.clubs[str(index)]
		ai[str(index)] = {
			"data": club.build.to_data().duplicate(true),
			"view": club.build.view().duplicate(true),
			"decisions": club.decisions.duplicate(true)
		}
	return {
		"human":
		{
			"data": season.build.to_data().duplicate(true),
			"view": season.build.view().duplicate(true),
			"pack": season.build._visit.get("cards", []).duplicate(true)
		},
		"ai": ai,
		"results": season.results.duplicate(true),
		"human_results": season.player_results.duplicate(true),
		"round_index": season.round_index,
		"phase": season.phase
	}


func _envelopes(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var physical: Dictionary = data.get("physical", {})
	for row: Dictionary in (
		physical.get("reports", []) + physical.get("pending", {}).get("reports", [])
	):
		result[str(int(row.fixture))] = row.duplicate(true)
	return result


func _human_shop_events(events: Array) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if event.op in SeasonBuild.SHOP_OPS:
			count += 1
	return count


func _reroll_button(node: Node) -> String:
	if node is Button and node.text.begins_with("Reroll individual offers • "):
		return node.text
	for child: Node in node.get_children():
		var found: String = _reroll_button(child)
		if not found.is_empty():
			return found
	return ""


func _checkpoint_proofs() -> void:
	var after: Dictionary = SeasonSave.snapshot(_app.season).duplicate(true)
	var journals: Dictionary = _journals(_app.season)
	var restored: SeasonState = SeasonSave.restore()
	var restored_data: Dictionary = (
		SeasonSave.snapshot(restored).duplicate(true) if restored != null else {}
	)
	var restored_journals: Dictionary = _journals(restored) if restored != null else {}
	_write(_output, "after.json", after)
	_write(_output, "after-journals.json", journals)
	_write(_output, "restored.json", restored_data)
	_write(_output, "restored-journals.json", restored_journals)
	_retain_raw(SeasonSave.path, "primary.json")
	_retain_raw(SeasonSave.path + ".bak", "backup.json")
	_proof("after_disk", ClubCareer.same(after, _read(_output, "primary.json")))
	_proof(
		"after_restore",
		(
			restored != null
			and ClubCareer.same(after, restored_data)
			and ClubCareer.same(journals, restored_journals)
		)
	)
	_proof(
		"after_emitted",
		(
			ClubCareer.same(after, _read(_output, "after.json"))
			and ClubCareer.same(restored_data, _read(_output, "restored.json"))
			and ClubCareer.same(journals, _read(_output, "after-journals.json"))
			and ClubCareer.same(restored_journals, _read(_output, "restored-journals.json"))
		)
	)
	_proof(
		"source_context_preserved",
		(
			ClubCareer.same(_before.home_property, after.home_property)
			and ClubCareer.same(_before.npc_venues, after.npc_venues)
			and ClubCareer.same(_before.final_venue, after.final_venue)
			and ClubCareer.same(_before.career.runs[0], after.career.runs[0])
		)
	)
	_proof(
		"bounded_final",
		(
			_clock()
			and _human_starts == 0
			and _app.lab == null
			and not _app.round_ui._working
			and not _app.round_ui.runner._running
			and (_action in ["ai1", "ai2"] or (_ai_reports == 0 and _completed_games == 0))
			and not FileAccess.file_exists(SeasonSave.path + ".tmp")
			and (
				Time.get_ticks_msec() - _started
				< (MAX_GAME_MSEC if _action in ["ai1", "ai2"] else MAX_COLD_MSEC)
			)
		)
	)
	_terminal.merge(
		{
			"save_sha256": FileAccess.get_sha256(SeasonSave.path),
			"backup_sha256": FileAccess.get_sha256(SeasonSave.path + ".bak"),
			"results": _app.season.results.size(),
			"human_results": _app.season.player_results.size(),
			"ai_archive": _app.season.physical.reports.size(),
			"pending_ai_reports": _app.season.physical.pending.get("reports", []).size(),
			"round_index": _app.season.round_index,
			"human_cash": _app.season.build.cash(),
			"origin_terminal": _receipt.get("terminal", {}).duplicate(true),
			"raw_hashes":
			{
				"before": _entry_hashes.duplicate(true),
				"after":
				{
					"primary": FileAccess.get_sha256(SeasonSave.path),
					"backup": FileAccess.get_sha256(SeasonSave.path + ".bak")
				}
			}
		}
	)
	_write(
		_output,
		"checkpoint-receipt.json",
		{
			"schema": "STANDARD-D1-ROUND-JOURNAL-CHECKPOINT-v1",
			"action": _action,
			"status": _status if _failures == 0 else "failed",
			"runtime": _runtime,
			"execution": _execution,
			"nonce": _nonce,
			"producer_pid": OS.get_process_id(),
			"predecessor_result_sha256": _input.predecessor_result_sha256,
			"primary_sha256": _terminal.save_sha256,
			"backup_sha256": _terminal.backup_sha256,
			"snapshot_sha256": FileAccess.get_sha256(_output.path_join("after.json")),
			"journals_sha256": FileAccess.get_sha256(_output.path_join("after-journals.json")),
			"origin_terminal": _receipt.get("terminal", {}).duplicate(true),
			"synthetic_eligibility_prefix": true,
			"genuine_promotion": false
		}
	)
	_proof(
		"origin_terminal",
		ClubCareer.same(
			_receipt.get("terminal", {}),
			_read(_output, "checkpoint-receipt.json").get("origin_terminal", {})
		)
	)


func _unexpected_ai(_report: Dictionary) -> void:
	_ai_reports += 1
	_completed_games += 1
	_app.round_ui.cancel()
	_check(false, "no-game action unexpectedly completed an AI game")


func _unexpected_human(node: Node) -> void:
	if node is PitchBatLab:
		_human_starts += 1
		_check(false, "continuation unexpectedly started a human game")


func _proof(label: String, valid: bool) -> bool:
	_proofs[label] = valid
	return _check(valid, "native exact " + label)


func _read(directory: String, name: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(directory.path_join(name), FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}


func _clock() -> bool:
	return (
		Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 and not get_tree().paused
	)


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		print("STANDARD_D1_ROUND_JOURNAL_FAIL ", label)
	return ok


func _retain_raw(source: String, name: String) -> void:
	if (
		not _admitted
		or not FileAccess.file_exists(source)
		or FileAccess.file_exists(_output.path_join(name))
	):
		_check(false, "cannot retain raw checkpoint " + name)
		return
	var file: FileAccess = FileAccess.open(source, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		_check(false, "unbounded raw checkpoint " + name)
		return
	file.close()
	if DirAccess.copy_absolute(source, _output.path_join(name)) != OK:
		_check(false, "raw checkpoint copy failed " + name)


func _write(directory: String, name: String, value: Dictionary) -> void:
	if not _admitted:
		return
	var raw: String = JSON.stringify(value, "", true, true)
	if raw.to_utf8_buffer().size() > MAX_BYTES:
		_check(false, "unbounded evidence " + name)
		return
	var path: String = directory.path_join(name)
	if FileAccess.file_exists(path):
		_check(false, "evidence already exists " + name)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "cannot write evidence " + name)
		return
	file.store_string(raw)
	file.flush()
	if file.get_error() != OK:
		_check(false, "cannot flush evidence " + name)
	file.close()
