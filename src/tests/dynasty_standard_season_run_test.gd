extends "res://src/tests/dynasty_standard_round_continuation_test.gd"
## Bounded genuine gameplay batches. No manufactured outcomes or fixture edits.
## Run only after exclusive owner handoff and qualified-source review.
var batch_rounds: int = 1
var expected_revision: int = -1
var human_starts: int = 0
var human_games: int = 0
var completed_batches: int = 0
var automation_ready: bool = true
var require_legend: bool = true
var process_jobs: bool = false
var stop_after_human: bool = false
var initial_session: String = ""
var initial_grant: Dictionary = {}
var initial_balance: int = 0
var first_title: bool = false
var initial_settlements: int = 0
var next_fixture: Dictionary = {}

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--season-rounds="):
			batch_rounds = int(arg.trim_prefix("--season-rounds="))
		if arg.begins_with("--season-expected-revision="):
			expected_revision = int(arg.trim_prefix("--season-expected-revision="))
		if arg == "--stop-after-human":
			stop_after_human = true
		if arg == "--season-process-jobs":
			process_jobs = true
		if arg == "--allow-existing-legend-gap":
			require_legend = false
	if not check(input.is_absolute_path() and output.is_absolute_path()
		and input == input.simplify_path() and output == output.simplify_path()
		and input != output and not output.begins_with(input + "/") and not input.begins_with(output + "/")
		and DirAccess.dir_exists_absolute(input) and not DirAccess.dir_exists_absolute(output)
		and batch_rounds >= 1 and batch_rounds <= 12 and expected_revision >= 1,
		"exclusive existing owner, exact expected revision and fresh separate bounded output"):
		return
	if not check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and not get_tree().paused and StadiumNpcPublicRuntime.source_qualified(), "unaltered clock and qualified source"):
		return
	owner_path = input.path_join("owner.json")
	if not check(not FileAccess.file_exists(owner_path + ".intent"), "no unresolved owner intent before inspection or restore"):
		return
	var found: Dictionary = Store.inspect(owner_path)
	if not check(found.get("status") == "ready" and found.get("revision") == expected_revision,
		"exclusive handoff revision is still current"):
		return
	initial_owner = found.owner.duplicate(true)
	if not check(initial_owner.selected == "other" and initial_owner.other.snapshot_version == 89,
		"existing shared live Standard selected"):
		return
	initial_session = initial_owner.other.session_id
	var entry: Dictionary = initial_owner.career.sessions[initial_session]
	if not check(entry.settled == 0 and entry.session.league == "standard", "active unsettled Standard session"):
		return
	initial_grant = entry.standard_grant.duplicate(true)
	initial_settlements = initial_owner.career.settlements.size()
	initial_balance = Authority.view(initial_owner.career).balance
	first_title = not Authority._history(initial_owner.career)._title_history().get(str(int(entry.session.tier)), false)
	original_hashes = _hash_tree(input)
	DirAccess.make_dir_recursive_absolute(output)
	_admitted = true
	if not check(_copy_tree(input, output.path_join("retained")) and _copy_tree(input, output.path_join("archive-copy"))
		and ClubCareer.same(original_hashes, _hash_tree(output.path_join("retained")))
		and ClubCareer.same(original_hashes, _hash_tree(output.path_join("archive-copy"))), "verified complete backups before any owner write"):
		return
	_write("input-sha256.json", original_hashes)
	if not check(SeasonSave.bind_dynasty_owner(owner_path), "bind authorized original owner path"):
		return
	SeasonSave.path = output.path_join("unused-ordinary.json")
	PitchBatLabSettings.path = output.path_join("isolated-settings.cfg")
	app = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	if not check(app.get_script() == SeasonApp and app.season != null
		and app.season.career == null and app.season.phase != SeasonState.Phase.COMPLETE,
		"exact main app restores active wallet-free Standard"):
		return
	if not check(not require_legend or ClubPlayerLegend.enabled(app.season),
		"prospective Legend tracking required unless explicitly documenting existing gap"):
		return
	if not check(not stop_after_human or app.season.physical.pending.is_empty(), "human-only boundary requires a new natural human fixture"):
		return
	app.child_entered_tree.connect(_automate_public_lab)
	# Process proof is opt-in only after the context/source tranche is approved.
	app.round_ui.process_jobs = process_jobs
	app.round_ui.runner.finished.disconnect(app.round_ui._finished)
	app.round_ui.runner.finished.connect(_record_ai)
	app.round_ui.process_runner.finished.disconnect(app.round_ui._finished)
	app.round_ui.process_runner.finished.connect(_record_ai)
	for batch in range(batch_rounds):
		if app.season.phase == SeasonState.Phase.COMPLETE:
			break
		var old_players: int = app.season.player_results.size()
		if app.season.physical.pending.is_empty():
			if not await _human_game():
				return
			if stop_after_human:
				check(not app.season.physical.pending.is_empty() and reports == 0, "stop at genuine durable human pending without starting AI")
				break
		else:
			_write("resumed-pending-%d.json" % batch, SeasonSave.snapshot(app.season))
			if not check(app.lab == null, "retained pending resumes without replaying a human game"):
				return
		var resume_started: int = Time.get_ticks_msec()
		print("SEASON_BOUNDARY begin=resume")
		if app.lab != null:
			app.finish_game()  # Ordinary Continue, including exact native issue checks.
		else:
			app.round_ui.resume()
		print("SEASON_BOUNDARY end=resume elapsed_ms=", Time.get_ticks_msec() - resume_started)
		if not await _finish_pending(old_players):
			return
		completed_batches += 1
		var snapshot: Dictionary = SeasonSave.snapshot(app.season)
		_write("settled-batch-%d.json" % completed_batches, snapshot)
		var cold_started: int = Time.get_ticks_msec()
		print("SEASON_BOUNDARY begin=cold_restore")
		var cold: SeasonState = SeasonSave.restore()
		print("SEASON_BOUNDARY end=cold_restore elapsed_ms=", Time.get_ticks_msec() - cold_started)
		if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "batch cold owner restore exact"):
			return
		var before_retry: Dictionary = Store.inspect(owner_path).owner
		var retry_started: int = Time.get_ticks_msec()
		print("SEASON_BOUNDARY begin=exact_retry")
		var retry_ok: bool = SeasonSave.save(app.season)
		print("SEASON_BOUNDARY end=exact_retry elapsed_ms=", Time.get_ticks_msec() - retry_started)
		if not check(retry_ok and ClubCareer.same(before_retry, Store.inspect(owner_path).owner), "batch save retry cannot duplicate revision/progress/awards"):
			return
		if not _audit_owner():
			return
	_write("season-batch-summary.json", {"checks": checks, "failures": failures,
		"new_human_games": human_games, "new_ai_games": reports, "human_starts": human_starts,
		"completed_batches": completed_batches, "stop_after_human": stop_after_human, "complete": app.season.phase == SeasonState.Phase.COMPLETE,
		"player_results": app.season.player_results.size(), "all_results": app.season.results.size(),
		"owner_revision": Store.inspect(owner_path).revision, "owner_path": owner_path,
		"legend_enabled": ClubPlayerLegend.enabled(app.season), "legend_gap_optout": not require_legend,
		"manual_input_qualified": false, "default_process_route_qualified": process_jobs and reports > 0 and failures == 0})
	check(not FileAccess.file_exists(SeasonSave.path), "no ordinary wallet/save created")

func _human_game() -> bool:
	next_fixture = app.season.pending_fixture().duplicate(true)
	if not check(not next_fixture.is_empty() and (next_fixture.away == 0 or next_fixture.home == 0)
		and not app.season.build.pack_pending(), "natural human fixture and no unresolved pack choice"):
		return false
	var starts: int = human_starts
	_write("before-human-%d.json" % int(next_fixture.id), SeasonSave.snapshot(app.season))
	var play_started: int = Time.get_ticks_msec()
	print("SEASON_BOUNDARY begin=play")
	app.play_season_game()
	print("SEASON_BOUNDARY end=play elapsed_ms=", Time.get_ticks_msec() - play_started)
	if not check(app.lab != null and human_starts == starts + 1 and automation_ready
		and app.lab._managed_match and app.lab._player_home == (next_fixture.home == 0),
		"public play starts genuine managed fixture: " + app.notice):
		return false
	var lab: PitchBatLab = app.lab
	var state: MatchState = lab._match_state
	if not check(not require_legend or state.performance.track_fielding, "actual human collector tracks fielding"):
		return false
	_write("pregame-%d.json" % int(next_fixture.id), SeasonSave.snapshot(app.season))
	var old_progress: String = ""
	var stalled: int = 0
	for frame in range(144120):
		if not is_instance_valid(lab) or app.lab != lab or lab._automation == null:
			check(false, "managed game ownership changed before terminal")
			return false
		if state.phase == MatchState.Phase.GAME_END and app._result_recorded and not app.season.physical.pending.is_empty():
			break
		if frame % 1800 == 0:
			_heartbeat_game("human", int(next_fixture.id), state)
		var progress: String = "%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
		stalled = stalled + 1 if progress == old_progress else 0
		old_progress = progress
		if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
			check(false, "genuine game exceeded unchanged production progress/time bounds")
			return false
		await get_tree().physics_frame
	if not check(state.phase == MatchState.Phase.GAME_END and app._result_recorded
		and not app.season.physical.pending.is_empty(), "natural terminal goes through production pending capture"):
		return false
	var report: Dictionary = PhysicalMatchReport.capture(lab)
	if not check(PhysicalMatchReport.valid(report), "actual automated managed terminal report"):
		return false
	human_games += 1
	_write("human-report-%d.json" % int(next_fixture.id), report)
	var pending: Dictionary = SeasonSave.snapshot(app.season)
	_write("human-pending-%d.json" % int(next_fixture.id), pending)
	var cold: SeasonState = SeasonSave.restore()
	if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), pending), "normal human pending capture is durably exact"):
		return false
	if stop_after_human:
		return true  # Durable terminal handoff does not request Continue.
	for frame in range(1800):
		if lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD:
			return true
		await get_tree().physics_frame
	check(false, "natural outro hold unavailable; no forced continue")
	return false

func _finish_pending(old_players: int) -> bool:
	for frame in range(360000):
		if process_jobs and not app.round_ui.process_jobs:
			check(false, "process job failed; no fallback qualification: " + app.round_ui.detail.text)
			return false
		if frame % 1800 == 0 and process_jobs:
			print("SEASON_PROCESS_PROGRESS fixture=", app.round_ui._projection.get("fixture", {}).get("id", -1),
				" progress=", app.round_ui.process_runner.progress, " elapsed_ms=", Time.get_ticks_msec() - app.round_ui._started)
		if frame % 1800 == 0 and is_instance_valid(app.round_ui.runner._lab):
			_heartbeat_game("ai", int(app.round_ui._projection.fixture.id), app.round_ui.runner._lab._match_state)
		if failures > 0:
			return false
		if app.season.physical.pending.is_empty():
			return check(app.season.player_results.size() == old_players + 1
				and app.lab == null and SeasonRoundSettlement._receipts(app.season), "one human result and exact per-club rewards after real required jobs")
		if not app.round_ui._working:
			check(false, "round paused; preserve accepted reports: " + app.round_ui.detail.text)
			return false
		await get_tree().physics_frame
	check(false, "bounded round continuation exceeded frame budget")
	return false

func _automate_public_lab(node: Node) -> void:
	if not node is PitchBatLab:
		return
	var lab: PitchBatLab = node
	automation_ready = automation_ready and not lab.is_node_ready() and lab._match_state == null and lab._automation == null
	lab._automation = MatchAutomation.new()
	lab._automation.seed = SeasonPhysicalFixtures.seed_for(app.season, app.season.pending_fixture())
	lab._automation.presentation_enabled = true  # Normal managed intro/outro permits public Continue.
	human_starts += 1

func _record_ai(report: Dictionary) -> void:
	var projection: Dictionary = app.round_ui._projection
	var fixture: Dictionary = projection.fixture
	if not check(PhysicalMatchReport.valid(report), "actual required AI terminal report"):
		app.round_ui.cancel()
		return
	reports += 1
	_write("ai-report-%d.json" % int(fixture.id), {"fixture": int(fixture.id),
		"request": SeasonPhysicalFixtures.request_key(projection.candidate, fixture), "report": report})
	var callback_started: int = Time.get_ticks_msec()
	print("SEASON_BOUNDARY begin=ai_callback fixture=", fixture.id)
	app.round_ui._finished(report)  # Exact append/save/project/final save callback.
	print("SEASON_BOUNDARY end=ai_callback fixture=", fixture.id, " elapsed_ms=", Time.get_ticks_msec() - callback_started)
	_write("after-ai-%d.json" % int(fixture.id), SeasonSave.snapshot(app.season))

func _audit_owner() -> bool:
	var owner: Dictionary = Store.inspect(owner_path).get("owner", {})
	if not check(not owner.is_empty() and owner.selected == "other" and owner.other.session_id == initial_session
		and ClubCareer.same(owner.dynasty.reference, initial_owner.dynasty.reference)
		and ClubCareer.same(owner.career.origin, initial_owner.career.origin)
		and owner.career.sessions.size() == initial_owner.career.sessions.size(), "same session/origin and untouched Dynasty"):
		return false
	var entry: Dictionary = owner.career.sessions[initial_session]
	if not check(ClubCareer.same(entry.standard_grant, initial_grant)
		and ClubCareer.same(entry.contribution.proof, ClubSeasonRecord.capture(app.season)), "frozen grant and exact all-fixture contribution"):
		return false
	if app.season.phase != SeasonState.Phase.COMPLETE:
		return check(entry.settled == 0 and owner.career.settlements.size() == initial_settlements
			and Authority.view(owner.career).balance == initial_balance, "unfinished season pays no completion award")
	var expected: Dictionary = ClubSeasonRecord.receipt(entry.contribution.proof, first_title, int(entry.session.tier))
	if not check(app.season.results.size() == 33 and not expected.is_empty()
		and entry.settled == initial_settlements + 1 and owner.career.settlements.size() == initial_settlements + 1,
		"all33 genuine fixtures produce exactly one completion settlement"):
		return false
	var settlement: Dictionary = owner.career.settlements[-1]
	check(settlement.session_id == initial_session and settlement.reason == "complete"
		and ClubCareer.same(settlement.receipt, expected)
		and Authority.view(owner.career).balance == initial_balance + int(expected.total), "actual finish/tier/first-title receipt credited exactly once")
	check(not app.dynasty_owner.playable(), "completed shared Standard cannot continue playing")
	var forged: Dictionary = owner.career.duplicate(true)
	forged.settlements[-1].receipt.total += 1
	check(Authority.normalize(forged).is_empty(), "modified completion receipt rejected read-only")
	_write("completion-receipt.json", {"receipt": expected, "first_title_available_before": first_title,
		"finish": ClubSeasonRecord.analyze(entry.contribution.proof), "owner_revision": owner.revision})
	return failures == 0

func _heartbeat_game(kind: String, fixture: int, state: MatchState) -> void:
	print("SEASON_PROGRESS kind=", kind, " fixture=", fixture, " inning=", state.inning,
		" top=", state.top_half, " pa=", state.plate_appearance_number, " elapsed=", state.elapsed_seconds)
