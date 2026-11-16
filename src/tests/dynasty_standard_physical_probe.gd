extends Node
## Actual detached physical human-slot game, isolated Standard89 pending replay.
## Synthetic legacy title prefix; no production/native-source activation.
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Closed = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
var checks: int = 0
var failures: int = 0
var output: String = ""
var games: int = 0
var _human_evidence: Dictionary = {}

class ProbeRunner:
	extends PhysicalMatchRunner
	var season: SeasonState
	var human: Dictionary = {}
	func _process(delta: float) -> void:
		if _lab != null and _lab._match_state != null and _lab._match_state.phase == MatchState.Phase.GAME_END:
			human = StadiumNpcYardTwoHumanEvidence.capture(_lab, season)
		super._process(delta)

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("PROBE_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-output="):
			output = arg.trim_prefix("--probe-output=")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	await _run()
	SeasonSave._dynasty_owner_path = ""
	print("STANDARD_PHYSICAL_PROBE checks=%d failures=%d physical_games=%d" % [checks, failures, games])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run() -> void:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = Fixture.prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}])
	if not check(source.career != null and source.career.start(source), "synthetic legacy origin"):
		return
	for pick in range(4):
		source.choose_player(source.offers()[0])
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "probe-lineage", "probe-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	if not check(dynasty != null, "qualified Dynasty source"):
		return
	var dynasty_context: Dictionary = Closed.binding_for(dynasty, profile.owner_id, profile.lineage_id, 0, 1, "probe-lineage:1")
	var path: String = output.path_join("owner.json")
	var created: Dictionary = Store.create({"lineage": Lineage.create(profile),
		"snapshot": Closed.wrap_checkpoint(SeasonSave.snapshot(dynasty), dynasty_context),
		"session_id": dynasty_context.session_id, "origin": origin}, path)
	if not check(created.status == "committed", "owner create"):
		return
	var owner: Dictionary = created.owner
	var grant: Dictionary = Grant.capture(owner.career)
	var selected_seed: int = 301
	var context: Dictionary = Bound.binding({"owner_id": owner.owner_id, "lineage_id": owner.lineage.id,
		"generation": 0, "ordinal": 1, "session_id": "standard-probe:1", "seed": selected_seed,
		"tier": 0, "league": "standard", "format": 89,
		"grant_sha256": Closed.snapshot_reference(grant).sha256})
	var season: SeasonState = Live.create(grant, context)
	if not check(season != null, "live Standard owned home"):
		return
	var opened: Dictionary = Store.transact({"op": "switch", "request_id": "probe-open",
		"expected_revision": owner.revision, "target": "other", "session_id": context.session_id,
		"snapshot": Bound.capture(season, context, grant, owner.career)}, path)
	if not check(opened.status == "committed" and SeasonSave.bind_dynasty_owner(path), "owner admits Standard89"):
		return
	season = SeasonSave.restore()
	for pick in range(4):
		season.choose_player(season.offers()[0])
	if not check(SeasonSave.save(season), "four picks saved"):
		return
	var fixture: Dictionary = season.pending_fixture()
	if not check(fixture.away == 0 and StadiumNpcYardTwoHumanEvidence.expected(season, fixture), "natural NPC away opening"):
		return
	print("PROBE_FIXTURE ", fixture, " seed=", selected_seed, " field=", SeasonState.field_for_fixture(fixture, season).id)
	var report: Dictionary = await _physical_report(season, fixture)
	if report.is_empty():
		return
	games += 1
	_write("physical-human-report.json", report)
	var human: Array = [fixture.id, report.away_runs, report.home_runs, report.performance,
		[], [], {}, [], [], {}, {}, [], PhysicalBaseEvidence.enriched(
			report.tactics.teams[1], report.tactics.base), [], StadiumLayoutSnapshot.key(report.property), null, _human_evidence]
	season.physical.pending = {"human": human, "reports": []}
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	if not check(not snapshot.is_empty(), "real physical pending89 captures"):
		return
	_write("pending89.json", snapshot)
	var cold: SeasonState = SeasonSave._decode(JSON.parse_string(JSON.stringify(snapshot, "", true, true)))
	if not check(cold != null and not cold.physical.pending.is_empty(), "real pending cold89 replay"):
		return
	var before: Dictionary = SeasonSave.snapshot(cold)
	var fast: Dictionary = SeasonRoundSettlement._project_candidate(
		SeasonRoundSettlement._fork_replayed_standard(cold), cold.physical.pending.duplicate(true))
	var full: Dictionary = SeasonRoundSettlement.project(cold)
	check(fast.keys() == full.keys() and fast.get("error", "") == full.get("error", ""), "fork/public result kind identical")
	check(ClubCareer.same(fast.get("fixture", {}), full.get("fixture", {})), "fork/public next physical fixture identical")
	check(not full.has("error") and full.has("fixture"), "pending requires real AI fixture next")
	check(ClubCareer.same(before, SeasonSave.snapshot(cold)), "projection preserves source")
	if fast.has("candidate") and full.has("candidate"):
		check(ClubCareer.same(Live.capture_raw(fast.candidate), Live.capture_raw(full.candidate)), "fork/public candidate identical")
	check(SeasonSave.save(season), "pending public checkpoint commits using original owner-bound season")
	var pending_restored: SeasonState = SeasonSave.restore()
	check(pending_restored != null and ClubCareer.same(SeasonSave.snapshot(pending_restored), snapshot), "pending disk restore exact")
	_write("projection.json", {"fast_keys": fast.keys(), "full_keys": full.keys(), "fixture": full.get("fixture", {})})
func _physical_report(season: SeasonState, fixture: Dictionary) -> Dictionary:
	var runner: ProbeRunner = ProbeRunner.new()
	runner.season = season
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	if not check(runner.start(SeasonPhysicalFixtures.match_for(season, fixture),
		SeasonPhysicalFixtures.seed_for(season, fixture), SeasonState.field_for_fixture(fixture, season).id,
		season._pool_replay_ledger, {}, season), "actual physical runner starts"):
		runner.queue_free()
		return {}
	for frame in range(300000):
		await get_tree().physics_frame
		if not report.is_empty() or not errors.is_empty():
			break
	check(errors.is_empty() and PhysicalMatchReport.valid(report), "physical runner terminal report " + str(errors))
	_human_evidence = runner.human
	check(not _human_evidence.is_empty() and StadiumNpcYardTwoHumanEvidence.valid(_human_evidence), "actual live terminal human evidence")
	runner.queue_free()
	await get_tree().process_frame
	return report
func _write(name: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(output.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "", true, true))
