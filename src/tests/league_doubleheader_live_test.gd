extends "res://src/tests/league_live_round_test.gd"
## Actual two-round pair. No fabricated scores, no public admission, no balance claim.


func _ready() -> void:
	SeasonSave.path = "user://doubleheader-live.json"
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("doubleheader"), true
	)
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "draft")
	_check(SeasonSave.snapshot(season).get("version") == 77, "explicit live77")
	var mislabeled: Dictionary = SeasonSave.snapshot(season)
	mislabeled.version = 76
	_check(SeasonSave._decode(mislabeled) == null, "Doubleheader cannot relabel old76")
	_check(SeasonSave.save(season), "opening durable save")
	season = SeasonSave.restore()
	_check(season != null, "opening cold restore")
	if season == null:
		get_tree().quit(1)
		return
	for round_number in range(2):
		var fixture: Dictionary=season.pending_fixture()
		var before: Dictionary=SeasonSave.snapshot(season)
		var first_key: String=SeasonPhysicalFixtures.request_key(season,fixture)
		_check(first_key==SeasonPhysicalFixtures.request_key(season,fixture),"request key pure")
		_check(ClubCareer.same(before,SeasonSave.snapshot(season)), \
			"request construction no state mutation")
		var state: MatchState=SeasonPhysicalFixtures.match_for(season,fixture)
		_check(state!=null,"pair request constructs")
		if state==null:
			break
		for team: TeamMatchState in [state.away_team,state.home_team]:
			_check(team.league_pair.first==(-1 if round_number==0 else \
				int(fixture.id)-3),"exact paired predecessor")
			if round_number==1:
				_check(not team.league_pair.debt.is_empty(),"both clubs carry validated debt")
				_check(team.roster.any(func(player: PlayerMatchState)->bool:return \
					player.stamina_remaining<player.stamina_max),"actual fatigue carries")
		var report: Dictionary=await _human_report(season,fixture)
		if report.is_empty():
			break
		var core: Dictionary=PhysicalDoubleheaderReport.core(report)
		var human_side: int=0 if fixture.away==0 else 1
		var ai_side: int=1-human_side
		var ai: Dictionary=PhysicalBaseEvidence.enriched(core.tactics.teams[ai_side],core.tactics.base)
		season.physical.pending={"human":[fixture.id,core.away_runs,core.home_runs,
			core.performance,[],report.uses[human_side],{},[],[],core.teams[human_side].pitching,{},[],ai,
			[PhysicalDoubleheaderReport.human(report,0),PhysicalDoubleheaderReport.human(report,1)]], \
				"reports":[]}
		_check(SeasonSave.save(season),"pending human durable save")
		season=SeasonSave.restore()
		_check(season!=null,"pending human cold restore")
		if season==null:
			break
		_write("pending-pair-%d.json"%round_number,SeasonSave.snapshot(season))
		for attempt in range(4):
			var projected: Dictionary=SeasonRoundSettlement.project(season)
			_check(not projected.has("error"),"project: "+str(projected.get("error","")))
			if projected.has("error"):
				break
			if not projected.has("fixture"):
				season=projected.candidate
				break
			var next: Dictionary=projected.fixture
			var next_report: Dictionary=await _human_report(projected.candidate,next)
			if next_report.is_empty():
				break
			season.physical.pending.reports.append({"fixture":next.id,
				"request":SeasonPhysicalFixtures.request_key(projected.candidate,next),"report":next_report})
			_check(SeasonSave.save(season),"partial round durable")
			season=SeasonSave.restore()
			_check(season!=null,"partial round cold")
			if season==null:
				break
		if season==null or season.round_index!=round_number+1:
			_check(false,"round completed")
			break
		_check(season.results.size()==3*(round_number+1),"all real fixtures accounted")
		_check(SeasonSave.save(season),"completed durable")
		var cold: SeasonState=SeasonSave.restore()
		_check(cold!=null and \
			ClubCareer.same(SeasonSave.snapshot(cold),SeasonSave.snapshot(season)),"completed cold exact")
		_write("completed-pair-%d.json"%round_number,SeasonSave.snapshot(season))
		if cold==null:
			break
		season=cold
	if season!=null and season.round_index==2:
		var fresh: MatchState=season.make_match()
		_check(fresh!=null,"new pair request")
		if fresh!=null:
			for team: TeamMatchState in [fresh.away_team,fresh.home_team]:
				_check(team.league_pair.debt.is_empty(),"fresh pair clears debt")
				_check(team.roster.all(func(player:PlayerMatchState)->bool:return \
					player.stamina_remaining==player.stamina_max),"new pair full capacities")
		_income(season)
	print("Doubleheader live pair failures: ", _failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _human_report(season: SeasonState, fixture: Dictionary) -> Dictionary:
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value:Dictionary)->void:report.merge(value,true))
	runner.failed.connect(func(reason:String)->void:errors.append(reason))
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	var started: bool = runner.start(
		state,
		SeasonPhysicalFixtures.seed_for(season, fixture),
		SeasonState.field_for_fixture(fixture, season).id
	)
	_check(started, "actual paired fixture starts")
	if not started:
		runner.queue_free()
		return {}
	var started_ms: int = Time.get_ticks_msec()
	var frames: int = 0
	for frame in range(300000):
		await get_tree().physics_frame
		frames += 1
		if not report.is_empty() or not errors.is_empty():
			break
	_check(
		errors.is_empty() and PhysicalMatchReport.valid(report),
		"actual paired fixture completed " + str(errors)
	)
	if not report.is_empty():
		var core: Dictionary = PhysicalDoubleheaderReport.core(report)
		print(
			"DOUBLEHEADER_DONE fixture=",
			fixture.id,
			" wall_ms=",
			Time.get_ticks_msec() - started_ms,
			" physics_frames=",
			frames,
			" releases=",
			core.releases.size(),
			" score=",
			core.away_runs,
			":",
			core.home_runs
		)
		_write("doubleheader-report-%d.json" % int(fixture.id), report)
	runner.queue_free()
	await get_tree().process_frame
	return report


func _income(season: SeasonState) -> void:
	var builds: Array = [season.build]
	for index in range(1, 6):
		builds.append(season.opponents.clubs[str(index)].build)
	for build: SeasonBuild in builds:
		var bank: SeasonOwnership = build._bank.empty_fork()
		var count: int = 0
		for event: Dictionary in build._bank.to_data().events:
			var before: int = bank.cash()
			var bonus: int = SeasonDoubleheaderRules.bonus(
				season.league_rules, event.get("game"), event.get("win"), bank.view().rewards
			)
			_check(bank.commit(event).ok, "bank replay")
			if event.op == "reward":
				count += 1
				_check(
					bank.cash() - before == (18 if event.win else 12) + bonus,
					"ordinary plus exact once sweep"
				)
		_check(count == 2, "each club exactly two payments")


func _write(name: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open("user://" + name, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "", true, true))
	file.close()
