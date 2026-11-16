extends "res://src/tests/league_doubleheader_live_test.gd"
## Continue the accepted actual first pair through remaining fixtures and playoffs.
## Human automation uses the unchanged paid roster; no score/outcome manipulation.


func _ready() -> void:
	var segmented: bool = "--segment" in OS.get_cmdline_user_args()
	SeasonSave.path = "user://doubleheader-fullseason.json"
	var resume: String = (
		"user://doubleheader-fullseason.json"
		if FileAccess.file_exists("user://doubleheader-fullseason.json")
		else "user://completed-pair-1.json"
	)
	var file: FileAccess = FileAccess.open(resume, FileAccess.READ)
	var season: SeasonState = (
		SeasonSave.restore()
		if resume == "user://doubleheader-fullseason.json"
		else SeasonSave._decode(JSON.parse_string(file.get_as_text())) if file != null else null
	)
	_check(season != null and season.round_index >= 2, "accepted actual pair continuation")
	if season == null:
		get_tree().quit(1)
		return
	print(
		"DOUBLEHEADER_RESUME_MEMORY bytes=",
		Performance.get_monitor(Performance.MEMORY_STATIC),
		" objects=",
		Performance.get_monitor(Performance.OBJECT_COUNT)
	)
	var human_games: int = 0
	for step in range(12):
		var fixture:Dictionary=season.pending_fixture()
		if fixture.is_empty():break
		var game:int=int(fixture.id)
		var start:MatchState=season.make_match()
		_check(start!=null,"full season current request")
		if start==null:break
		for team:TeamMatchState in [start.away_team,start.home_team]:
			if SeasonDoubleheaderRules.first(game)<0:
				_check(team.league_pair.debt.is_empty() and \
					team.roster.all(func(p:PlayerMatchState)->bool:return \
					p.stamina_remaining==p.stamina_max),"new pair/playoff fresh recovery")
			else:
				_check(team.league_pair.first==game-3,"later exact return partner")
		start=null # Release diagnostic request before constructing/restoring full histories.
		if season.physical.pending.is_empty():
			var report:Dictionary=await _report_for(season,fixture)
			if report.is_empty():break
			if "--play-only" in OS.get_cmdline_user_args():
				await _finish_play(fixture)
				return
			var core:Dictionary=PhysicalDoubleheaderReport.core(report)
			var human_side:int=0 if fixture.away==0 else 1
			var ai_side:int=1-human_side
			var ai:Dictionary=PhysicalBaseEvidence.enriched(core.tactics.teams[ai_side],core.tactics.base)
			season.physical.pending={"human":[game,core.away_runs,core.home_runs,core.performance,
				[],report.uses[human_side],{},[],[],core.teams[human_side].pitching,{},[],ai,
				[PhysicalDoubleheaderReport.human(report,0),PhysicalDoubleheaderReport.human(report,1)]], \
					"reports":[]}
			_check(SeasonSave.save(season),"full season pending saved")
			season=SeasonSave.restore()
			_check(season!=null,"full season pending cold")
			if season==null:break
			_write("full-pending-%d.json"%game,SeasonSave.snapshot(season))
			if segmented:
				await _finish_segment(season)
				return
		var completed:bool=false
		for attempt in range(7):
			var projected:Dictionary=SeasonRoundSettlement.project(season)
			_check(not projected.has("error"),"full project: "+str(projected.get("error","")))
			if projected.has("error"):break
			if not projected.has("fixture"):
				season=projected.candidate
				projected={}
				completed=true
				break
			var next:Dictionary=projected.fixture
			var next_report:Dictionary=await _report_for(projected.candidate,next)
			if next_report.is_empty():break
			if "--play-only" in OS.get_cmdline_user_args():
				await _finish_play(next)
				return
			season.physical.pending.reports.append({"fixture":next.id,
				"request":SeasonPhysicalFixtures.request_key(projected.candidate,next),"report":next_report})
			projected={} # No extra disposable season retained across the next cold validation.
			next_report={}
			_check(SeasonSave.save(season),"full partial round saved")
			season=SeasonSave.restore()
			_check(season!=null,"full partial round cold")
			if season==null:break
			if segmented:
				await _finish_segment(season)
				return
		if season==null or not completed:break
		human_games+=1
		var before:Dictionary=SeasonSave.snapshot(season)
		_check(SeasonSave.save(season),"full completed checkpoint")
		season=SeasonSave.restore()
		_check(season!=null and \
			ClubCareer.same(before,SeasonSave.snapshot(season)),"full completed cold exact")
		if season==null:break
		before={}
		_write("full-completed-%d.json"%game,SeasonSave.snapshot(season))
		print("DOUBLEHEADER_FULL_CHECKPOINT game=",game," round=",season.round_index," phase=", \
			season.phase,
			" results=",season.results.size()," archived=",season.physical.reports.size(),
			" save_bytes=",FileAccess.get_file_as_bytes(SeasonSave.path).size())
		if segmented and season.phase!=SeasonState.Phase.COMPLETE:
			await _finish_segment(season)
			return
	if season != null:
		_check(
			season.phase == SeasonState.Phase.COMPLETE and season.results.size() == 33,
			"all30 regular plus3 playoff physical fixtures complete"
		)
		_check(
			season.physical.reports.size() + season.player_results.size() == 33,
			"each fixture has physical source"
		)
		_full_income(season)
		_write(
			(
				"completed-doubleheader-season77.json"
				if season.phase == SeasonState.Phase.COMPLETE and season.results.size() == 33
				else "doubleheader-season-failed-checkpoint77.json"
			),
			SeasonSave.snapshot(season)
		)
	print(
		"Doubleheader full season failures: ", _failures, " additional human games: ", human_games
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _full_income(season: SeasonState) -> void:
	var bonuses: int = 0
	for club in range(6):
		var build:SeasonBuild=season.build if club==0 else season.opponents.clubs[str(club)].build
		var bank:SeasonOwnership=build._bank.empty_fork()
		var count:int=0
		for event:Dictionary in build._bank.to_data().events:
			var before:int=bank.cash()
			_check(bank.commit(event).ok,"full ownership reconstructs")
			if event.op!="reward":continue
			count+=1
			var result:Dictionary={}
			for played:Dictionary in season.results:
				if played.id==event.game:result=played
			_check(not result.is_empty() and club in \
				[int(result.away),int(result.home)],"reward belongs to club's actual fixture")
			if result.is_empty():continue
			var won:bool=SeasonState._winner(result)==club
			var bonus:int=0
			var first:int=SeasonDoubleheaderRules.first(event.game)
			if won and first>=0:
				for earlier:Dictionary in season.results:
					if earlier.id==first and SeasonState._winner(earlier)==club:bonus=6
			bonuses+=bonus
			_check(event.win==won and bank.cash()-before==(18 if won else \
				12)+bonus,"actual score-bound ordinary plus sweep payment once")
		var expected:int=season.results.filter(func(row:Dictionary)->bool:return row.away==club or \
			row.home==club).size()
		_check(count==expected,"every actual club fixture paid once")
	print("DOUBLEHEADER_FULL_EARNED_SWEEP_CASH total=", bonuses, " sweeps=", bonuses / 6)


func _finish_segment(season: SeasonState) -> void:
	print(
		"DOUBLEHEADER_CHECKPOINT_STEP round=",
		season.round_index,
		" accepted=",
		season.results.size(),
		" pending_reports=",
		season.physical.pending.get("reports", []).size(),
		" failures=",
		_failures,
		" bytes=",
		Performance.get_monitor(Performance.MEMORY_STATIC),
		" objects=",
		Performance.get_monitor(Performance.OBJECT_COUNT)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _report_for(season: SeasonState, fixture: Dictionary) -> Dictionary:
	if not "--validate-only" in OS.get_cmdline_user_args():
		var original_fixture: Dictionary = fixture.duplicate(true)
		var original_request: String = SeasonPhysicalFixtures.request_key(season, fixture)
		_check(not original_request.is_empty(), "play-time request identity exists")
		if original_request.is_empty():
			return {}
		var actual: Dictionary = await _human_report(season, fixture)
		if not actual.is_empty():
			_write(
				"full-envelope-%d.json" % int(fixture.id),
				{"fixture": original_fixture, "request": original_request, "report": actual}
			)
		return actual
	var wanted: int = -1
	var path: String = ""
	var digest: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--reuse-report="):
			wanted = int(argument.trim_prefix("--reuse-report="))
		if argument.begins_with("--retained-path="):
			path = argument.trim_prefix("--retained-path=")
		if argument.begins_with("--report-sha="):
			digest = argument.trim_prefix("--report-sha=")
	if int(fixture.id) != wanted or path.is_empty() or digest.length() != 64:
		_check(
			false, "validate-only requires the exact retained next fixture and hash; never plays"
		)
		return {}
	for row: Dictionary in season.physical.reports + season.physical.pending.get("reports", []):
		if int(row.fixture) == wanted:
			_check(false, "retained fixture cannot duplicate an archived or pending report")
			return {}
	var raw: String = FileAccess.get_file_as_string(path)
	if raw.sha256_text() != digest:
		_check(false, "retained physical report bytes unchanged across process handoff")
		return {}
	var envelope: Variant = JSON.parse_string(raw)
	return _retained_fullseason_envelope(season, fixture, wanted, digest, envelope)


func _retained_fullseason_envelope(
	season: SeasonState, fixture: Dictionary, wanted: int, digest: String, envelope: Variant
) -> Dictionary:
	if (
		not envelope is Dictionary
		or not SeasonOwnership._keys(envelope, ["fixture", "request", "report"])
		or not ClubCareer.same(envelope.fixture, fixture)
		or envelope.request != SeasonPhysicalFixtures.request_key(season, fixture)
	):
		_check(false, "play-time envelope binds exact current fixture and request hash")
		return {}
	var retained: Variant = envelope.report
	var expected: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	var good: bool = (
		retained is Dictionary
		and expected != null
		and PhysicalDoubleheaderReport.valid(retained)
		and PhysicalDoubleheaderReport.matches(retained, expected)
	)
	if good:
		good = (
			retained.physical.seed == SeasonPhysicalFixtures.seed_for(season, fixture)
			and retained.physical.field == String(SeasonState.field_for_fixture(fixture, season).id)
		)
	_check(
		good, "unchanged actual retained report binds exact fixture seed field ownership and debt"
	)
	expected = null
	if not good:
		return {}
	print("DOUBLEHEADER_REUSED_ACTUAL_REPORT fixture=", wanted, " sha256=", digest)
	return retained


func _finish_play(fixture: Dictionary) -> void:
	var path: String = "user://full-envelope-%d.json" % int(fixture.id)
	print(
		"DOUBLEHEADER_PLAY_ONLY fixture=",
		fixture.id,
		" sha256=",
		FileAccess.get_file_as_string(path).sha256_text(),
		" failures=",
		_failures
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
