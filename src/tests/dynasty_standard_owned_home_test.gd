extends "res://src/tests/dynasty_standard_round_continuation_test.gd"
## Genuine natural starter-owned-home game through exact SeasonApp; no fixture edits.
## Existing completed-round owner is exclusively assigned. Back up before any write.
var human_starts: int = 0
var automation_ready: bool = true
var home_games: int = 0
var expected_revision: int = -1
var legend_enabled: bool = false
var pregame_snapshot: Dictionary = {}
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--home-expected-revision="):
			expected_revision = int(arg.trim_prefix("--home-expected-revision="))
	if not check(input.is_absolute_path() and output.is_absolute_path()
		and input == input.simplify_path() and output == output.simplify_path()
		and input != output and not output.begins_with(input + "/") and not input.begins_with(output + "/")
		and expected_revision >= 0 and DirAccess.dir_exists_absolute(input)
		and not DirAccess.dir_exists_absolute(output), "exclusive original owner and fresh separate backup/output"):
		return
	if not check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and not get_tree().paused and StadiumNpcPublicRuntime.source_qualified(), "unchanged clock and independently qualified source"):
		return
	original_hashes = _hash_tree(input)
	if not check(original_hashes.has("owner.json") and original_hashes.has("owner.json.committed"), "retained owner manifests exist"):
		return
	DirAccess.make_dir_recursive_absolute(output)
	_admitted = true
	if not check(_copy_tree(input, output.path_join("retained")) and _copy_tree(input, output.path_join("archive-copy")), "two complete raw-byte backups"):
		return
	if not check(ClubCareer.same(original_hashes, _hash_tree(input))
		and ClubCareer.same(original_hashes, _hash_tree(output.path_join("retained")))
		and ClubCareer.same(original_hashes, _hash_tree(output.path_join("archive-copy"))), "backup hashes verified before owner action"):
		return
	_write("input-sha256.json", original_hashes)
	owner_path = input.path_join("owner.json")
	var found: Dictionary = Store.inspect(owner_path)
	if not check(found.get("status") == "ready" and found.owner.revision == expected_revision
		and found.owner.selected == "other" and not FileAccess.file_exists(owner_path + ".intent"), "expected exclusive owner revision ready without intent"):
		return
	initial_owner = found.owner.duplicate(true)
	if not check(SeasonSave.bind_dynasty_owner(owner_path), "bind original isolated shared owner"):
		return
	var source: SeasonState = SeasonSave.restore()
	var fixture: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
	if not check(source != null and source.career == null and source._dynasty_career_session.get("format") == 89
		and source.round_index == 1 and source.results.size() == 3 and source.player_results.size() == 1
		and source.physical.reports.size() == 2 and source.physical.pending.is_empty()
		and ClubCareer.same(source.pending_fixture(), fixture), "natural next round fixture3 is owned home after genuinely completed opening round"):
		return
	if not check(source.home_property.get("version") == 3 and source.home_property.get("layout", {}).get("version") == 1
		and SeasonState.field_for_fixture(fixture, source).id == PitchBatLab.FIELD_ID
		and not StadiumPoolOwnedHumanEvidence.expected(source, fixture)
		and not StadiumNpcYardTwoHumanEvidence.expected(source, fixture)
		and not StadiumSurfaceNightHumanEvidence.expected(source, fixture), "starter backyard owned-home scope and ordinary15-argument human grammar"):
		return
	var before: Dictionary = SeasonSave.snapshot(source)
	_write("owned-home-before89.json", before)
	SeasonSave.path = output.path_join("unused-ordinary.json")
	PitchBatLabSettings.path = output.path_join("isolated-settings.cfg")
	app = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	if not check(app.get_script() == SeasonApp and app.season != null
		and ClubCareer.same(SeasonSave.snapshot(app.season), before), "exact main app cold restores authoritative fixture3"):
		return
	if not check(not app.season.build.pack_pending(), "no unresolved ordinary pregame pack decision"):
		return
	app.round_ui.process_jobs = false
	app.child_entered_tree.connect(_home_automation)
	legend_enabled = ClubPlayerLegend.enabled(app.season)
	app.play_season_game()
	if not check(app.lab != null and human_starts == 1 and automation_ready
		and app.lab._managed_match and app.lab._player_home
		and ClubCareer.same(app.season.pending_fixture(), fixture)
		and StadiumLayoutSnapshot.key(app.lab._match_state.stadium)
			== StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(app.season, fixture)),
		"normal main play_season_game starts actual owned home without injected ledger: " + app.notice):
		return
	pregame_snapshot = SeasonSave.snapshot(app.season)
	_write("owned-home-pregame89.json", pregame_snapshot)
	var lab: PitchBatLab = app.lab
	var state: MatchState = lab._match_state
	var old_progress: String = ""
	var stalled: int = 0
	for frame in range(144120):
		if not is_instance_valid(lab) or app.lab != lab or lab._automation == null:
			check(false, "owned home runtime interrupted before completion")
			return
		if state.phase == MatchState.Phase.GAME_END and app._result_recorded and not app.season.physical.pending.is_empty():
			break
		var progress: String = "%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
		stalled = stalled + 1 if progress == old_progress else 0
		old_progress = progress
		if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
			check(false, "actual home game exceeded unchanged progress/time bounds")
			return
		await get_tree().physics_frame
	if not check(state.phase == MatchState.Phase.GAME_END and app._result_recorded
		and not app.season.physical.pending.is_empty(), "genuine managed home game reaches normal durable pending route"):
		return
	home_games = 1
	var report: Dictionary = PhysicalMatchReport.capture(lab)
	var human: Array = app.season.physical.pending.human
	if not check(PhysicalMatchReport.valid(report) and human.size() == 15
		and human[0] == 3 and human[1] == report.away_runs and human[2] == report.home_runs
		and ClubCareer.same(human[3], report.performance)
		and human[14] == StadiumLayoutSnapshot.key(report.property)
		and ClubCareer.same(report.property, state.stadium)
		and app.season.physical.pending.reports.is_empty(), "actual terminal report matches ordinary main-owned-home pending exactly"):
		return
	_write("owned-home-terminal-report.json", report)
	_write("owned-home-human.json", {"human": human})
	var pending: Dictionary = SeasonSave.snapshot(app.season)
	_write("owned-home-pending89.json", pending)
	var cold: SeasonState = SeasonSave.restore()
	if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), pending), "actual home pending cold owner restore exact"):
		return
	var projection: Dictionary = SeasonRoundSettlement.project(cold)
	if not check(not projection.has("error") and projection.has("candidate") and projection.has("fixture")
		and projection.fixture.id == 4 and projection.candidate.player_results.size() == 2,
		"public replay validates actual home game and requests natural AI fixture4: " + str(projection.get("error", ""))):
		return
	_differential(cold, "owned-home actual pending")
	check(ClubCareer.same(app.season.home_property, source.home_property)
		and ClubCareer.same(app.season.npc_venues, source.npc_venues)
		and ClubCareer.same(app.season.final_venue, source.final_venue), "owned/away/final context unchanged")
	var saved: Dictionary = Store.inspect(owner_path).owner
	check(Authority.view(saved.career).balance == Authority.view(initial_owner.career).balance
		and saved.career.settlements.size() == initial_owner.career.settlements.size()
		and ClubCareer.same(saved.dynasty.reference, initial_owner.dynasty.reference)
		and ClubCareer.same(saved.career.assets, initial_owner.career.assets), "home attempt duplicates no shared wallet/award/asset and leaves Dynasty exact")
	check(SeasonSave.save(app.season), "bound home-pending save retry")
	check(ClubCareer.same(Store.inspect(owner_path).owner, saved), "pending retry preserves exact owner revision and references")
	check(not app.round_ui._working and not app.round_ui.runner._running
		and not app.round_ui.process_runner.running and reports == 0, "no AI game started; exact home pending handed off")
	check(not FileAccess.file_exists(SeasonSave.path), "no ordinary wallet file")
	_write("owned-home-summary.json", {"checks": checks, "failures": failures,
		"human_starts": human_starts, "actual_human_games": home_games, "new_ai_games": reports,
		"fixture": fixture, "owner_revision": saved.revision, "owner_path": owner_path,
		"home_snapshot_version": app.season.home_property.version,
		"home_layout_version": app.season.home_property.layout.version,
		"legend_enabled": legend_enabled, "track_fielding": state.performance.track_fielding,
		"special_owned_families_qualified": false, "manual_input_qualified": false,
		"full_season_qualified": false, "source_qualified": StadiumNpcPublicRuntime.source_qualified()})
func _home_automation(node: Node) -> void:
	if not node is PitchBatLab:
		return
	var lab: PitchBatLab = node
	automation_ready = automation_ready and not lab.is_node_ready() and lab._match_state == null and lab._automation == null
	lab._automation = MatchAutomation.new()
	lab._automation.seed = SeasonPhysicalFixtures.seed_for(app.season, app.season.pending_fixture())
	lab._automation.presentation_enabled = false
	human_starts += 1
