extends "res://src/tests/dynasty_live_round_test.gd"
## Authentic prospective Club Legend from retained physical career and normal future games.
var career_root: String


func _ready() -> void:
	_evidence_dir = OS.get_environment("PLAQUE_EVIDENCE")
	career_root = _evidence_dir
	_check(_evidence_dir.is_absolute_path(), "isolated explicit evidence path")
	DirAccess.make_dir_recursive_absolute(_evidence_dir)
	SeasonSave.path = _file("career-current.json")
	var season: SeasonState
	if FileAccess.file_exists(SeasonSave.path):
		season = SeasonSave.restore()
	else:
		var origin: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(OS.get_environment("PLAQUE_ORIGIN"))
		)
		season = SeasonSave._decode(origin)
		_check(season != null, "original two completed physical seasons cold validate")
		if season != null:
			_check(
				SeasonSave.save(season),
				"isolated retained original commits without altering source"
			)
	_check(season != null, "source cold restores")
	if season == null:
		await _finish_dynasty()
		return
	if season.season_seed != 3591:
		_evidence_dir = career_root.path_join("season-%d" % season.season_seed)
		DirAccess.make_dir_recursive_absolute(_evidence_dir)
	while _failures == 0 and StadiumPlaqueRewards.awards(season.career).is_empty():
		if season.phase == SeasonState.Phase.COMPLETE:
			season = _next_career(season)
			if season == null:
				break
		if _failures > 0:
			break
		if season.physical.pending.is_empty():
			var fixture: Dictionary = season.pending_fixture()
			var report: Dictionary = await _human_report(season, fixture)
			if report.is_empty():
				break
			var core: Dictionary = _core(report)
			var own: int = 1 if fixture.home == 0 else 0
			var row: Dictionary = core.teams[own]
			var ai: Dictionary = (
				PhysicalBaseEvidence.enriched(core.tactics.teams[1 - own], core.tactics.base)
				if core.has("tactics")
				else {}
			)
			season.physical.pending = {
				"human":
				[
					fixture.id,
					core.away_runs,
					core.home_runs,
					core.performance,
					[],
					[],
					row.batting,
					row.stances,
					row.fielding,
					row.pitching,
					{},
					[],
					ai
				],
				"reports": []
			}
			if season.opponents._format < 9:
				season.physical.pending.human.pop_back()
			_write_once(
				"human-%d-evidence.json" % fixture.id,
				{
					"fielding": row.fielding,
					"performance": core.performance,
					"qualifies_major": SeasonDoubleMajor.qualifies(row.fielding)
				}
			)
			_check(
				SeasonSave.save(season),
				"actual career human pending saves: " + SeasonSave.last_error
			)
			if _failures > 0:
				break
		var projected: Dictionary = SeasonRoundSettlement.project(season)
		_check(
			not projected.has("error"),
			"actual source round projects: " + str(projected.get("error", ""))
		)
		if projected.has("error"):
			break
		if projected.has("fixture"):
			var fixture: Dictionary = projected.fixture
			var report: Dictionary = await _human_report(projected.candidate, fixture)
			if report.is_empty():
				break
			season.physical.pending.reports.append(
				{
					"fixture": fixture.id,
					"request": SeasonPhysicalFixtures.request_key(projected.candidate, fixture),
					"report": report
				}
			)
		else:
			season = projected.candidate

			print(
				"F09_CAREER_ROUND games=",
				season.player_results.size(),
				" Cash=",
				season.build.cash(),
				" major=",
				SeasonDoubleMajor.access(season.career),
				" sky=",
				SeasonAbilities.access(season.career)
			)
		_check(
			SeasonSave.save(season), "actual source checkpoint commits: " + SeasonSave.last_error
		)
		if _failures > 0:
			break
		var before_count: int = season.results.size()
		season = SeasonSave.restore()
		_check(
			season != null and season.results.size() == before_count,
			"actual source checkpoint cold restores without fallback or progress loss"
		)
		if season == null:
			break
	if _failures == 0:
		var earned: Dictionary = StadiumPlaqueRewards.awards(season.career)
		_check(not earned.is_empty(), "normal official career earns genuine plaque")
		var frozen: Dictionary = season.career.to_data()
		_check(
			(
				StadiumPlaqueRewards.capture(season.career)
				and StadiumPlaqueRewards.deliver(season.career)
			),
			"repeat award capture and delivery succeed"
		)
		_check(
			ClubCareer.same(frozen, season.career.to_data()),
			"repeat capture never duplicates plaque or changes historical receipt"
		)
		_write_once("earned-season.json", SeasonSave.snapshot(season))
		_write_once("earned-plaques.json", earned)
		print("PLAQUE_AUTHENTIC_EARNED ", JSON.stringify(earned))
	print(
		"PLAQUE_NATURAL_RESULT checks=",
		_checks,
		" failures=",
		_failures,
		" physical_starts=",
		_physical_starts
	)
	await _finish_dynasty()


func _core(report: Dictionary) -> Dictionary:
	return PhysicalLeagueReport.core(report) if report.get("version") == 27 else report


func _audit_definitions(_season: SeasonState, _fixture: Dictionary, state: MatchState) -> void:
	_check(PhysicalMatchRequest.capture(state) != null, "actual career request detaches")


func _audit_report(
	_season: SeasonState, fixture: Dictionary, state: MatchState, envelope: Dictionary
) -> void:
	_check(
		SeasonPhysicalFixtures.envelope(envelope) and PhysicalMatchReport.valid(envelope.report),
		"actual career physical report valid"
	)
	_check(
		(
			envelope.fixture == fixture.id
			and _core(envelope.report).seed == SeasonPhysicalFixtures.seed_for(_season, fixture)
		),
		"actual source fixture and seed bound"
	)
	_check(
		PhysicalChoiceEvidence._matches_core(_core(envelope.report), state),
		"actual source physical definitions bound"
	)


func _human_report(season: SeasonState, fixture: Dictionary) -> Dictionary:
	var human: bool = season.league_rules.is_empty() and (fixture.away == 0 or fixture.home == 0)
	if human and not FileAccess.file_exists(_file("fixture-%d-request.json" % int(fixture.id))):
		_prepare_human_lineup(season)
	var state: MatchState = (
		season.make_match() if human else SeasonPhysicalFixtures.match_for(season, fixture)
	)
	_check(state != null, "fixture has committed playable source")
	if state == null:
		return {}
	_audit_definitions(season, fixture, state)
	var request: Dictionary = _request_record(season, fixture, state)
	var id: int = int(fixture.id)
	var request_name: String = "fixture-%d-request.json" % id
	var report_name: String = "fixture-%d-envelope.json" % id
	if not _write_once(request_name, request):
		return {}
	if FileAccess.file_exists(_file(report_name)):
		var retained: Dictionary = _read(report_name)
		_check(
			retained.get("fixture") == id and retained.get("request") == request.request,
			"retained actual fixture uses its original request, never substituted or re-run"
		)
		var retained_report: Dictionary = {}
		if _failures == 0 and retained.get("report") is Dictionary:
			_audit_report(season, fixture, state, retained)
			print("DYNASTY_RETAINED fixture=", id, " no_physical_replay=true")
			if _failures == 0:
				retained_report = retained.report
		return retained_report
	_check(
		_phase != "verify" and _physical_starts < ClubCareer.MAX_RUNS * 33,
		"bounded authorized phase may start missing fixture only"
	)
	if _failures > 0:
		return {}
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	# Write the exact original envelope in the completion callback before any
	# expensive validation or settlement. A retry reuses it, never resimulates it.
	runner.finished.connect(
		func(value: Dictionary) -> void:
			report.merge(value, true)
			_write_once(report_name, {"fixture": id, "request": request.request, "report": value})
	)
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started_ms: int = Time.get_ticks_msec()
	var started: bool = runner.start(state, int(request.seed), StringName(request.field))
	_check(started, "actual Dynasty physical fixture starts")
	if not started:
		runner.queue_free()
		return {}
	_physical_starts += 1
	var physics_frames: int = 0
	for frame in range(300000):
		await get_tree().physics_frame
		physics_frames += 1
		if frame % 3600 == 0 and runner._lab != null:
			var live: MatchState = runner._lab._match_state
			print(
				"DYNASTY_LIVE fixture=",
				id,
				" inning=",
				live.inning,
				" pa=",
				live.plate_appearance_number
			)
		if not report.is_empty() or not errors.is_empty():
			break
	_check(
		errors.is_empty() and not report.is_empty(),
		"actual physical fixture completes: " + str(errors)
	)
	if report.is_empty():
		runner.cancel()
	else:
		var envelope: Dictionary = {"fixture": id, "request": request.request, "report": report}
		_audit_report(season, fixture, state, envelope)
		var core: Dictionary = _core(report)
		if not core.is_empty():
			print(
				"DYNASTY_DONE fixture=",
				id,
				" wall_ms=",
				Time.get_ticks_msec() - started_ms,
				" physics_frames=",
				physics_frames,
				" releases=",
				core.releases.size(),
				" score=",
				core.away_runs,
				":",
				core.home_runs
			)
		_write_once(
			"fixture-%d-measurement.json" % id,
			{
				"wall_ms": Time.get_ticks_msec() - started_ms,
				"physics_frames": physics_frames,
				"errors": errors
			}
		)
	runner.queue_free()
	await get_tree().process_frame
	return report if _failures == 0 else {}


func _train_fielder(season: SeasonState) -> void:
	var build: SeasonBuild = season.build
	_check(
		build.commit(SeasonOpponentPolicy.command(build, "open")).get("ok", false),
		"ordinary career earned shop opens"
	)
	if build.cash() < build.pack_price():
		return
	_check(
		build.commit(SeasonOpponentPolicy.command(build, "pack_open")).get("ok", false),
		"actual source income pays pack"
	)
	var fixture: Dictionary = season.pending_fixture()
	var state: MatchState = season.make_match()
	var own: TeamMatchState = state.home_team if fixture.home == 0 else state.away_team
	var target: String = String(own.roster[own.fielder_index].definition.id)
	var selected: Dictionary = {}
	var cards: Array = build.view().shop.cards
	for preferred: String in ["development.fielding", "development.round_out"]:
		if not cards.has(preferred):
			continue
		for row: Dictionary in build.targets(preferred):
			if row.player == target:
				selected = row.duplicate(true)
				selected.item = preferred
				break
		if not selected.is_empty():
			break
	if selected.is_empty():
		for item: String in cards:
			var targets: Array[Dictionary] = build.targets(item)
			if not targets.is_empty():
				selected = targets[0].duplicate(true)
				selected.item = item
				break
	_check(not selected.is_empty(), "paid revealed pack has legal target")
	if not selected.is_empty():
		_check(
			build.commit(SeasonOpponentPolicy.command(build, "pack_pick", selected)).get(
				"ok", false
			),
			"ordinary paid source development applies"
		)
		print("F09_CAREER_TRAIN ", selected)
	_check(
		build.commit(SeasonOpponentPolicy.command(build, "leave_shop")).get("ok", false),
		"source shop exits"
	)


func _next_career(season: SeasonState) -> SeasonState:
	_write_once("completed-source.json", SeasonSave.snapshot(season))
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "completed natural career closes without forged eligibility")
	if _failures > 0:
		return null
	var next: SeasonState = SeasonState.create(season.season_seed + 1, false, true, true)
	next.physical = SeasonPhysicalFixtures.new()
	next.opponents._format = 13
	_check(
		ClubPlayerDraft.apply(next, ClubPlayers.owned(club)),
		"normal permanent owned-player draft access; no free cards"
	)
	next.career = club
	_check(next.career.start(next), "next ordinary career preserves actual earned history")
	if _failures > 0:
		return null
	next.physical = SeasonPhysicalFixtures.new()
	var history: Dictionary = ClubPlayerLegend.evaluate(club)
	for pick in range(4):
		var offers: Array[String] = next.offers()
		var chosen: String = offers[0]
		for id: String in offers:
			var old: int = history.get(chosen, {}).get("completed_seasons", []).size()
			var tenure: int = history.get(id, {}).get("completed_seasons", []).size()
			if tenure > old:
				chosen = id
		_check(
			next.choose_player(chosen),
			"choose most experienced legal offered player without rerolls"
		)
		print("PLAQUE_LEGAL_DRAFT offers=", offers, " choice=", chosen)
	_check(SeasonSave.save(next), "next ordinary career durably checkpoints")
	_evidence_dir = career_root.path_join("season-%d" % next.season_seed)
	DirAccess.make_dir_recursive_absolute(_evidence_dir)
	print(
		"F09_CAREER_NEXT season=",
		next.season_seed,
		" actual_prior_runs=",
		next.career.runs.size() - 1
	)
	return SeasonSave.restore()


func _prepare_human_lineup(season: SeasonState) -> void:
	var best: int = 0
	for index in range(4):
		if (
			season.player_definition(season.teams[0].roster[index]).fielding
			> season.player_definition(season.teams[0].roster[best]).fielding
		):
			best = index
	if best != 3:
		season.swap_batters(best, 3)
	season.fielder_index = 3
	season.select_starter(0)
	_check(SeasonSave.save(season), "legal fielding-focused lineup saves before actual human game")
	print(
		"F09_LEGAL_LINEUP primary=",
		season.teams[0].roster[3],
		" starter=",
		season.teams[0].roster[0]
	)


func _request_record(season: SeasonState, fixture: Dictionary, state: MatchState) -> Dictionary:
	var result: Dictionary = super._request_record(season, fixture, state)
	var name: String = _file("fixture-%d-request.json" % int(fixture.id))
	var retained: Dictionary = (
		JSON.parse_string(FileAccess.get_file_as_string(name))
		if FileAccess.file_exists(name)
		else {}
	)
	if retained.is_empty() or retained.has("actual_lineups"):
		result.actual_lineups = []
		for team: TeamMatchState in [state.away_team, state.home_team]:
			result.actual_lineups.append(
				{"pitcher": team.pitcher_index, "fielder": team.fielder_index}
			)
	return result
