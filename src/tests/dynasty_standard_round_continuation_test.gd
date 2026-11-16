extends Node
## Test-only retained-byte continuation through unmodified public round callbacks.
## Requires independently source-qualified runtime; never adjusts source pins.
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
var input: String = ""
var output: String = ""
var checks: int = 0
var failures: int = 0
var reports: int = 0
var original_hashes: Dictionary = {}
var initial_owner: Dictionary = {}
var owner_path: String = ""
var app: SeasonApp
var _admitted: bool = false
var settle_only: bool = false
var report_input: String = ""
var report_hashes: Dictionary = {}
var reports_backed: bool = false
var retained_reports_validated: int = 0
var protocol_gc_removed: Array[String] = []

class SettleOnlyRunnerGuard:
	extends PhysicalMatchRunner
	var attempts: int = 0
	func start(_source: MatchState, _seed: int, _field: StringName = PitchBatLab.FIELD_ID,
		_ledger: ClubAssetLedger = null, _pool_request: Dictionary = {},
		_npc_season: SeasonState = null) -> bool:
		attempts += 1
		return false  # Any unexpected new fixture fails without starting physics.

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("STANDARD_CONTINUATION_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--continuation-input="):
			input = arg.trim_prefix("--continuation-input=")
		if arg.begins_with("--continuation-output="):
			output = arg.trim_prefix("--continuation-output=")
		if arg == "--settle-only":
			settle_only = true
		if arg.begins_with("--continuation-reports="):
			report_input = arg.trim_prefix("--continuation-reports=")
	await _run()
	if is_instance_valid(app):
		if is_instance_valid(app.round_ui):
			app.round_ui.cancel()
		app.queue_free()
		await get_tree().process_frame
	if _admitted:
		check(_immutable_inputs_unchanged(), "original pending/report and other immutable input bytes unchanged")
		check(ClubCareer.same(original_hashes, _hash_tree(output.path_join("retained"))), "retained backup bytes unchanged")
		check(ClubCareer.same(original_hashes, _hash_tree(output.path_join("archive-copy"))), "second archival backup bytes unchanged")
		if reports_backed:
			check(_report_inputs_unchanged(), "retained AI files and both report backups unchanged")
		_write("summary.json", {"checks": checks, "failures": failures, "new_physical_ai_games": reports,
			"original_hashes": original_hashes, "source_qualified": StadiumNpcPublicRuntime.source_qualified(),
			"manual_input_qualified": false, "full_season_qualified": false,
			"mutated_isolated_owner_path": owner_path, "settle_only": settle_only,
			"validated_retained_ai_reports": retained_reports_validated,
			"protocol_gc_removed": protocol_gc_removed, "retained_ai_hashes": report_hashes})
	SeasonSave._dynasty_owner_path = ""
	print("STANDARD_CONTINUATION checks=%d failures=%d new_physical_ai_games=%d" % [checks, failures, reports])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run() -> void:
	if not check(input.is_absolute_path() and output.is_absolute_path()
		and input == input.simplify_path() and output == output.simplify_path()
		and input != output and not output.begins_with(input + "/") and not input.begins_with(output + "/")
		and DirAccess.dir_exists_absolute(input) and not DirAccess.dir_exists_absolute(output),
		"separate existing input and fresh output paths"):
		return
	if not check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and not get_tree().paused and StadiumNpcPublicRuntime.source_qualified(), "unchanged clock and qualified source"):
		return
	original_hashes = _hash_tree(input)
	if not check(not original_hashes.is_empty() and original_hashes.has("owner.json")
		and original_hashes.has("pending89.json") and original_hashes.has("physical-human-report.json"), "required retained inputs"):
		return
	DirAccess.make_dir_recursive_absolute(output)
	_admitted = true
	if not check(_copy_tree(input, output.path_join("retained")) and _copy_tree(input, output.path_join("archive-copy")), "two raw-byte archival backups before owner actions"):
		return
	if not check(ClubCareer.same(original_hashes, _hash_tree(output.path_join("retained")))
		and ClubCareer.same(original_hashes, _hash_tree(output.path_join("archive-copy")))
		and ClubCareer.same(original_hashes, _hash_tree(input)), "all copies match before first owner action"):
		return
	_write("input-sha256.json", original_hashes)
	# Manifests bind their original absolute path. Copies are archival only.
	# Mutate only this already-isolated original owner, after verified backups.
	owner_path = input.path_join("owner.json")
	if settle_only:
		await _settle_saved_reports()
		return
	var pending: Dictionary = _read(input.path_join("pending89.json"))
	var human_report: Dictionary = _read(input.path_join("physical-human-report.json"))
	var leaf: Dictionary = SeasonRoundSettlement._physical_payload(pending)
	var physical: Dictionary = leaf.get("physical", {})
	if not check(pending.get("version") == 89 and not physical.is_empty()
		and physical.pending.get("human") is Array and physical.pending.human.size() == 17
		and physical.pending.get("reports") == [] and PhysicalMatchReport.valid(human_report), "retained actual pending and terminal report shapes"):
		return
	var human: Array = physical.pending.human
	if not check(human[1] == human_report.away_runs and human[2] == human_report.home_runs
		and ClubCareer.same(human[3], human_report.performance)
		and human[14] == StadiumLayoutSnapshot.key(human_report.property)
		and human[16] is Dictionary and StadiumNpcYardTwoHumanEvidence.valid(human[16])
		and ClubCareer.same(human[16].property, human_report.property)
		and ClubCareer.same(human[16].base, human_report.tactics.base), "exact retained human report linkage"):
		return
	if not check(SeasonSave.bind_dynasty_owner(owner_path), "bind original isolated owner after exact backups"):
		return
	var bound: SeasonState = SeasonSave.restore()
	var baseline: Dictionary = pending.duplicate(true)
	SeasonRoundSettlement._physical_payload(baseline).physical.pending = {}
	if not check(bound != null and ClubCareer.same(SeasonSave.snapshot(bound), baseline), "public owner restore equals pending snapshot except pending alone"):
		return
	initial_owner = Store.inspect(owner_path).owner.duplicate(true)
	bound.physical.pending = physical.pending.duplicate(true)
	if not check(SeasonSave.save(bound), "transfer exact pending onto original bound restore"):
		return
	var restored: SeasonState = SeasonSave.restore()
	if not check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored), pending), "pending disk restore equals retained full envelope"):
		return
	_differential(restored, "initial pending")
	if failures > 0:
		return
	SeasonSave.path = output.path_join("unused-ordinary.json")
	PitchBatLabSettings.path = output.path_join("isolated-settings.cfg")
	app = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	if not check(app.get_script() == SeasonApp and app.season != null
		and ClubCareer.same(SeasonSave.snapshot(app.season), pending), "exact SeasonApp restores isolated pending owner"):
		return
	app.round_ui.process_jobs = false
	# Observe the actual callback; append/save/project remain its production code.
	app.round_ui.runner.finished.disconnect(app.round_ui._finished)
	app.round_ui.runner.finished.connect(_reported)
	app.round_ui.resume()
	if not check(app.round_ui._working, "normal resume starts first remaining AI fixture"):
		return
	for frame in range(360000):
		await get_tree().physics_frame
		if failures > 0 or app.season.physical.pending.is_empty():
			break
		if not app.round_ui._working:
			check(false, "normal round paused: " + app.round_ui.detail.text)
			break
	if not check(failures == 0 and reports == 2 and app.season.physical.pending.is_empty(), "two genuine AI games finish one normal round"):
		return
	var final_season: SeasonState = app.season
	if not check(final_season.career == null and final_season.player_results.size() == 1
		and final_season.results.size() == 3 and final_season.physical.reports.size() == 2
		and final_season.round_index == 1 and SeasonRoundSettlement._receipts(final_season), "one human game and one result per club without duplicate wallet"):
		return
	var final_snapshot: Dictionary = SeasonSave.snapshot(final_season)
	_write("final89.json", final_snapshot)
	var cold: SeasonState = SeasonSave.restore()
	check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), final_snapshot), "full round cold owner restore exact")
	var final_owner: Dictionary = Store.inspect(owner_path).owner
	check(Authority.view(final_owner.career).balance == Authority.view(initial_owner.career).balance
		and final_owner.career.settlements.size() == initial_owner.career.settlements.size()
		and final_owner.career.sessions.size() == initial_owner.career.sessions.size()
		and ClubCareer.same(final_owner.dynasty.reference, initial_owner.dynasty.reference), "one round grants no completion settlement or duplicate history; Dynasty unchanged")
	# One session contribution contains all three fixtures, not just its one human game.
	var entry: Dictionary = final_owner.career.sessions[final_owner.other.session_id]
	check(entry.settled == 0 and entry.contribution.proof.scores.size() == 3
		and ClubCareer.same(entry.contribution.proof, ClubSeasonRecord.capture(final_season))
		and ClubCareer.same(entry.standard_grant,
			initial_owner.career.sessions[initial_owner.other.session_id].standard_grant),
		"one current-session contribution and immutable admission witness")
	check(SeasonSave.save(final_season), "exact completed-round save retry")
	var retried: Dictionary = Store.inspect(owner_path).owner
	check(ClubCareer.same(final_owner, retried), "retry keeps revision refs balance contributions and settlement count exact")
	check(not FileAccess.file_exists(SeasonSave.path), "no ordinary wallet save created")
func _reported(report: Dictionary) -> void:
	var projection: Dictionary = app.round_ui._projection
	var fixture: Dictionary = projection.fixture
	var expected: Dictionary = {"fixture": int(fixture.id),
		"request": SeasonPhysicalFixtures.request_key(projection.candidate, fixture), "report": report}
	if not check(PhysicalMatchReport.valid(report) and fixture.id == reports + 1, "genuine expected AI report"):
		app.round_ui.cancel()
		return
	reports += 1
	_write("ai-report-%d.json" % reports, expected)
	app.round_ui._finished(report)
	if not app.season.physical.pending.is_empty():
		check(ClubCareer.same(app.season.physical.pending.reports[-1], expected), "production callback appended exact request wrapper")
		var current: Dictionary = SeasonSave.snapshot(app.season)
		_write("pending-after-ai-%d.json" % reports, current)
		var cold: SeasonState = SeasonSave.restore()
		check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), current), "each report checkpoint cold-restores exact")
		_differential(app.season, "after AI %d" % reports)
	else:
		check(app.season.physical.reports.size() == reports
			and ClubCareer.same(app.season.physical.reports[-1], expected), "final normal projection retains exact second report")
func _differential(season: SeasonState, label: String) -> void:
	var before: Dictionary = SeasonSave.snapshot(season)
	var fork: SeasonState = SeasonRoundSettlement._fork_replayed_standard(season)
	if not check(fork != null, label + " detached replay context"):
		return
	var fast: Dictionary = SeasonRoundSettlement._project_candidate(fork, season.physical.pending.duplicate(true))
	var full: Dictionary = SeasonRoundSettlement.project(season)
	check(fast.keys() == full.keys() and not full.has("error")
		and ClubCareer.same(fast.get("fixture", {}), full.get("fixture", {})), label + " fork/public next fixture identical")
	if fast.has("candidate") and full.has("candidate"):
		check(ClubCareer.same(Live.capture_raw(fast.candidate), Live.capture_raw(full.candidate)), label + " fork/public candidate identical")
	check(ClubCareer.same(before, SeasonSave.snapshot(season)), label + " source unchanged")
func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
func _write(name: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(output.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "", true, true))
func _hash_tree(root: String, relative: String = "") -> Dictionary:
	var result: Dictionary = {}
	var folder: String = root.path_join(relative)
	for name: String in DirAccess.get_files_at(folder):
		var key: String = relative.path_join(name) if not relative.is_empty() else name
		result[key] = FileAccess.get_sha256(root.path_join(key))
	for name: String in DirAccess.get_directories_at(folder):
		var key: String = relative.path_join(name) if not relative.is_empty() else name
		result.merge(_hash_tree(root, key))
	return result
func _copy_tree(source: String, target: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(target) != OK:
		return false
	for name: String in DirAccess.get_files_at(source):
		if DirAccess.copy_absolute(source.path_join(name), target.path_join(name)) != OK:
			return false
	for name: String in DirAccess.get_directories_at(source):
		if not _copy_tree(source.path_join(name), target.path_join(name)):
			return false
	return true

func _immutable_inputs_unchanged() -> bool:
	var current: Dictionary = _hash_tree(input)
	protocol_gc_removed.clear()
	var found: Dictionary = Store.inspect(owner_path) if not owner_path.is_empty() else {}
	for key: String in original_hashes:
		if key in ["owner.json", "owner.json.committed", "owner.json.pending", "owner.json.recovery"]:
			continue
		if current.has(key):
			if current[key] != original_hashes[key]:
				return false
			continue
		# Only the store's documented GC may remove a known original object.
		# Surviving objects and all evidence bytes must still match exactly.
		if not key.begins_with("owner.json.objects/") or found.get("status") != "ready" \
			or FileAccess.file_exists(owner_path + ".intent"):
			return false
		var name: String = key.trim_prefix("owner.json.objects/")
		var digest: String = Store._object_filename_digest(name)
		if name.contains("/") or digest.is_empty():
			return false
		for reference: Dictionary in Store._references(found.owner):
			if reference.sha256 == digest:
				return false
		protocol_gc_removed.append(key)
	return true

func _settle_saved_reports() -> void:
	if not check(report_input.is_absolute_path() and report_input == report_input.simplify_path()
		and report_input != output and not output.begins_with(report_input + "/")
		and not report_input.begins_with(output + "/") and DirAccess.dir_exists_absolute(report_input),
		"settle-only exact retained report directory"):
		return
	for name: String in ["pending-after-ai-2.json", "ai-report-1.json", "ai-report-2.json"]:
		var path: String = report_input.path_join(name)
		if not check(FileAccess.file_exists(path), "required retained file " + name):
			return
		report_hashes[name] = FileAccess.get_sha256(path)
	for folder: String in ["retained-reports", "archive-reports"]:
		if not check(DirAccess.make_dir_recursive_absolute(output.path_join(folder)) == OK, "report archive created"):
			return
		for name: String in report_hashes:
			if not check(DirAccess.copy_absolute(report_input.path_join(name), output.path_join(folder).path_join(name)) == OK,
				"retained AI bytes copied"):
				return
	reports_backed = true
	if not check(_report_inputs_unchanged(), "AI archives verified before owner actions"):
		return
	_write("retained-ai-sha256.json", report_hashes)
	var pending: Dictionary = _read(report_input.path_join("pending-after-ai-2.json"))
	var original_pending: Dictionary = _read(input.path_join("pending89.json"))
	var human_report: Dictionary = _read(input.path_join("physical-human-report.json"))
	var physical: Dictionary = SeasonRoundSettlement._physical_payload(pending).get("physical", {})
	if not check(pending.get("version") == 89 and physical.get("pending") is Dictionary
		and physical.pending.get("human") is Array and physical.pending.human.size() == 17
		and physical.pending.get("reports") is Array and physical.pending.reports.size() == 2
		and PhysicalMatchReport.valid(human_report), "complete retained pending shape with two actual reports"):
		return
	var without_ai: Dictionary = pending.duplicate(true)
	SeasonRoundSettlement._physical_payload(without_ai).physical.pending.reports = []
	if not check(ClubCareer.same(without_ai, original_pending), "only actual AI reports extend original human pending"):
		return
	var human: Array = physical.pending.human
	if not check(human[1] == human_report.away_runs and human[2] == human_report.home_runs
		and ClubCareer.same(human[3], human_report.performance)
		and human[14] == StadiumLayoutSnapshot.key(human_report.property)
		and human[16] is Dictionary and StadiumNpcYardTwoHumanEvidence.valid(human[16])
		and ClubCareer.same(human[16].property, human_report.property)
		and ClubCareer.same(human[16].base, human_report.tactics.base), "actual retained human terminal linkage"):
		return
	for index in range(2):
		var wrapper: Dictionary = _read(report_input.path_join("ai-report-%d.json" % (index + 1)))
		if not check(SeasonPhysicalFixtures.envelope(wrapper) and wrapper.fixture == index + 1
			and ClubCareer.same(wrapper, physical.pending.reports[index]), "exact validated AI wrapper file %d" % (index + 1)):
			return
		retained_reports_validated += 1
	if not check(SeasonSave.bind_dynasty_owner(owner_path), "bind original isolated complete-pending owner"):
		return
	var bound: SeasonState = SeasonSave.restore()
	if not check(bound != null and ClubCareer.same(SeasonSave.snapshot(bound), pending), "public owner restore exactly matches retained two-report pending"):
		return
	initial_owner = Store.inspect(owner_path).owner.duplicate(true)
	var projected: Dictionary = SeasonRoundSettlement.project(bound)
	if not check(not projected.has("error") and projected.has("candidate") and not projected.has("fixture"),
		"all retained games project final candidate with zero new fixture work: " + str(projected.get("error", ""))):
		return
	var candidate: SeasonState = projected.candidate
	if not check(candidate.career == null and candidate.player_results.size() == 1
		and candidate.results.size() == 3 and candidate.physical.reports.size() == 2
		and candidate.physical.pending.is_empty() and candidate.round_index == 1
		and SeasonRoundSettlement._receipts(candidate), "one complete round and no duplicate per-club awards"):
		return
	if not check(ClubCareer.same(SeasonSave.snapshot(bound), pending), "projection does not mutate retained bound pending"):
		return
	var expected_final: Dictionary = SeasonSave.snapshot(candidate)
	SeasonSave.path = output.path_join("unused-ordinary.json")
	PitchBatLabSettings.path = output.path_join("isolated-settings.cfg")
	app = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	if not check(app.get_script() == SeasonApp and app.season != null
		and is_instance_valid(app.round_ui)
		and ClubCareer.same(SeasonSave.snapshot(app.season), pending),
		"exact SeasonApp restores the complete retained pending envelope"):
		return
	app.round_ui.process_jobs = false
	if not check(not app.round_ui._working and not app.round_ui.runner._running
		and not app.round_ui.process_runner.running, "no physical work started during app restore"):
		return
	# Keep exact production resume/_next. Only its unused physical-start boundary
	# gets a fail-closed guard, so an unexpected fixture cannot replay any game.
	var original_runner: PhysicalMatchRunner = app.round_ui.runner
	app.round_ui.remove_child(original_runner)
	original_runner.free()
	var guard: SettleOnlyRunnerGuard = SettleOnlyRunnerGuard.new()
	app.round_ui.runner = guard
	app.round_ui.add_child(guard)
	guard.finished.connect(app.round_ui._finished)
	guard.failed.connect(app.round_ui._pause)
	app.round_ui.resume()
	if not check(guard.attempts == 0 and not app.round_ui.process_runner.running
		and not app.round_ui._working and app.season.physical.pending.is_empty()
		and app._result_saved, "normal resume to _next commits retained final round without any new fixture"):
		return
	candidate = app.season
	var final_snapshot: Dictionary = SeasonSave.snapshot(candidate)
	if not check(ClubCareer.same(final_snapshot, expected_final), "actual UI-committed snapshot equals prior public projection"):
		return
	_write("final89.json", final_snapshot)
	var cold: SeasonState = SeasonSave.restore()
	if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), final_snapshot), "settled full round cold restore exact"):
		return
	var owner: Dictionary = Store.inspect(owner_path).owner
	var entry: Dictionary = owner.career.sessions[owner.other.session_id]
	check(Authority.view(owner.career).balance == Authority.view(initial_owner.career).balance
		and owner.career.settlements.size() == initial_owner.career.settlements.size()
		and owner.career.sessions.size() == initial_owner.career.sessions.size()
		and ClubCareer.same(owner.dynasty.reference, initial_owner.dynasty.reference),
		"no season-completion payout or duplicate history; Dynasty unchanged")
	check(entry.settled == 0 and entry.contribution.proof.scores.size() == 3
		and ClubCareer.same(entry.contribution.proof, ClubSeasonRecord.capture(candidate))
		and ClubCareer.same(entry.standard_grant,
			initial_owner.career.sessions[initial_owner.other.session_id].standard_grant),
		"one current contribution and same frozen grant")
	check(SeasonSave.save(candidate), "settle-only exact save retry")
	check(ClubCareer.same(Store.inspect(owner_path).owner, owner), "retry preserves exact revision refs balance settlements and contribution")
	check(reports == 0 and guard.attempts == 0 and not guard._running
		and not app.round_ui.process_runner.running, "settle-only plays zero new games through actual app/UI commit")
	check(not FileAccess.file_exists(SeasonSave.path), "settle-only creates no ordinary wallet file")

func _report_inputs_unchanged() -> bool:
	for name: String in report_hashes:
		for folder: String in [report_input, output.path_join("retained-reports"), output.path_join("archive-reports")]:
			if FileAccess.get_sha256(folder.path_join(name)) != report_hashes[name]:
				return false
	return true
