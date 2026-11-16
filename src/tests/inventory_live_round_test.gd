extends "res://src/tests/season_opponent_sponsors_visible_test.gd"
## Closed live integration. No public League admission is exercised or enabled.


func _ready() -> void:
	SeasonSave.path = "user://inventory-live-round78.json"
	var season: SeasonState = SeasonState.create_closed_league(443, _league_rules(), true)
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "closed live draft pick")
	_check(
		SeasonInventoryRules.enable(season), "fresh inventory capability enabled on all six clubs"
	)
	var saved: Dictionary = SeasonSave.snapshot(season)
	_check(saved.get("version") == 78, "live save78")
	_check(SeasonSave.save(season), "live durable checkpoint")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.league_live, "cold live context")
	_check(
		SeasonSave._decode(saved.checkpoint) == null,
		"stripped inventory wrapper rejects enabled journals"
	)
	season.build._market = 12
	_check(
		not season.league_context_consistent() and SeasonSave.snapshot(season).is_empty(),
		"human market cannot impersonate AI"
	)
	season.build._market = 0
	var human_build: SeasonBuild = season.build
	season.build = null
	season.league_live = false
	season.league_rules = {}
	_check(
		not season.league_context_consistent(), "surviving league AI cannot enter legacy runtime"
	)
	season.build = human_build
	season.league_live = true
	season.league_rules = _league_rules()
	var original_rules: Dictionary = season.opponents.clubs["1"].build._league_rules
	season.opponents.clubs["1"].build._league_rules = {}
	_check(
		season.make_match() == null and SeasonSave.snapshot(season).is_empty(),
		"AI context stripping rejects runtime and save"
	)
	season.opponents.clubs["1"].build._league_rules = original_rules
	var malformed: MatchState = MatchState.new()
	_check(PhysicalMatchRequest.capture(malformed) == null, "null teams reject cleanly")
	var fixture: Dictionary = season.pending_fixture()
	var match_state: MatchState = season.make_match()
	_check(
		match_state != null and PhysicalMatchRequest.capture(match_state) != null,
		"human request context"
	)
	var report: Dictionary = await _human_report(season, fixture)
	if report.is_empty():
		get_tree().quit(1)
		return
	_check(report.get("version") == 27, "new report27")
	_check(not PhysicalMatchReport.valid(report.physical), "stripped wrapper rejected")
	var core: Dictionary = PhysicalLeagueReport.core(report)
	var stripped: Dictionary = core.duplicate(true)
	stripped.erase("league_bound")
	_check(
		not PhysicalLeagueReport.matches(
			stripped, SeasonPhysicalFixtures.match_for(season, fixture)
		),
		"legacy-shaped stripped core cannot enter live league"
	)
	var forged_match: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	forged_match.league_rules = {}
	_check(
		not PhysicalLeagueReport.matches(report, forged_match),
		"league report cannot enter legacy match"
	)
	var bad: Dictionary = report.duplicate(true)
	bad.league_rules = LeagueRules.capture("standard")
	_check(not PhysicalMatchReport.valid(bad), "profile substitution rejected")
	var row: Dictionary = PhysicalBaseEvidence.enriched(
		core.tactics.teams[0 if fixture.home == 0 else 1], core.tactics.base
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
			{},
			[],
			[],
			{},
			{},
			[],
			row
		],
		"reports": []
	}
	_audit_pending(season)
	_check(SeasonSave.save(season), "human pending durable save")
	season = SeasonSave.restore()
	_check(season != null and not season.physical.pending.is_empty(), "cold pending resumes")
	if season == null:
		get_tree().quit(1)
		return
	for attempt in range(4):
		var projected: Dictionary = SeasonRoundSettlement.project(season)
		_check(not projected.has("error"), "round projection: " + str(projected.get("error", "")))
		if projected.has("error"):
			break
		if not projected.has("fixture"):
			season = projected.candidate
			break
		var next: Dictionary = projected.fixture
		var next_report: Dictionary = await _human_report(projected.candidate, next)
		if next_report.is_empty():
			break
		season.physical.pending.reports.append(
			{
				"fixture": next.id,
				"request": SeasonPhysicalFixtures.request_key(projected.candidate, next),
				"report": next_report
			}
		)
		_check(SeasonSave.save(season), "partial round checkpoint")
		season = SeasonSave.restore()
		if season == null:
			_check(false, "partial round cold restore")
			break
	if season != null:
		_check(
			season.player_results.size() == 1 and season.results.size() == 3,
			"three real games settle once"
		)
		_audit_game_income(season)
		_check(SeasonSave.save(season), "completed round save")
		restored = SeasonSave.restore()
		_check(
			(
				restored != null
				and ClubCareer.same(SeasonSave.snapshot(restored), SeasonSave.snapshot(season))
			),
			"completed cold replay exact"
		)
	if season != null:
		_paid_sale_checkpoint(season)
	print("Inventory live save78 round failures: ", _failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _human_report(season: SeasonState, fixture: Dictionary) -> Dictionary:
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	var started: bool = runner.start(
		state,
		SeasonPhysicalFixtures.seed_for(season, fixture),
		SeasonState.field_for_fixture(fixture, season).id
	)
	_check(started, "real closed fixture starts")
	if not started:
		runner.queue_free()
		return {}
	var started_ms: int = Time.get_ticks_msec()
	var physics_frames: int = 0
	for frame in range(300000):
		await get_tree().physics_frame
		physics_frames += 1
		if frame % 3600 == 0 and runner._lab != null:
			var live: MatchState = runner._lab._match_state
			print(
				"LEAGUE_LIVE fixture=",
				fixture.id,
				" inning=",
				live.inning,
				" pa=",
				live.plate_appearance_number
			)
		if not report.is_empty() or not errors.is_empty():
			break
	_check(
		errors.is_empty() and PhysicalMatchReport.valid(report),
		"closed fixture completed: " + str(errors)
	)
	if not report.is_empty():
		var core: Dictionary = PhysicalLeagueReport.core(report)
		print(
			"LEAGUE_DONE fixture=",
			fixture.id,
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
		var file: FileAccess = FileAccess.open(
			"user://league-report-%d.json" % int(fixture.id), FileAccess.WRITE
		)
		file.store_string(JSON.stringify(report))
		file.close()
	runner.queue_free()
	await get_tree().process_frame
	return report


func _league_rules() -> Dictionary:
	return LeagueRules.capture(_league_profile())


func _league_profile() -> String:
	return "dugout"


func _audit_game_income(season: SeasonState) -> void:
	var builds: Array[SeasonBuild] = [season.build]
	for club: Dictionary in season.opponents.clubs.values():
		builds.append(club.build)
	var rewards: int = 0
	for build: SeasonBuild in builds:
		var team_index: int = 0
		for key: String in season.opponents.clubs:
			if season.opponents.clubs[key].build == build:
				team_index = int(key)
		var replay: SeasonOwnership = build._bank.empty_fork()
		for event: Dictionary in build._bank.to_data().events:
			var before: int = replay.cash()
			var outcome: Dictionary = replay.commit(event)
			_check(outcome.ok, "real ownership journal reconstructs")
			if event.op == "reward":
				rewards += 1
				var fixture: Dictionary = {}
				for result: Dictionary in season.results:
					if int(result.id) == int(event.game):
						fixture = result
				_check(not fixture.is_empty(), "reward belongs to completed fixture")
				if fixture.is_empty():
					continue
				var own: int = int(
					fixture.home_runs if fixture.home == team_index else fixture.away_runs
				)
				var opponent: int = int(
					fixture.away_runs if fixture.home == team_index else fixture.home_runs
				)
				if LeagueRules.earnings(season.league_rules):
					_check(
						event.get("own_runs") == own and event.get("opponent_runs") == opponent,
						"reward score pair exactly binds actual club fixture orientation"
					)
				_check(
					(
						replay.cash() - before
						== LeagueRules.game_income(
							season.league_rules, own > opponent, own, opponent
						)
					),
					"actual human/AI ordinary payout obeys frozen profile"
				)
			elif event.op == "sponsor_income":
				_check(
					replay.cash() - before == event.amount,
					"actual sponsor aggregate is not reduced"
				)
	_check(rewards == 6, "one real ordinary payout for each of six clubs")


func _audit_pending(_season: SeasonState) -> void:
	pass


func _paid_sale_checkpoint(season: SeasonState) -> void:
	var build: SeasonBuild = season.build
	_check(
		build.commit(SeasonOpponentPolicy.command(build, "open")).ok, "earned postgame shop opens"
	)
	var offer: String = ""
	for roll in range(5):
		for key: String in build._visit.offers:
			if build._visit.offers[key] in ["A10", "C02", "C03"]:
				offer = key
				break
		if not offer.is_empty():
			break
		var reroll: Dictionary = SeasonOpponentPolicy.command(build, "reroll")
		if build.cash() < 6 or build.candidate(reroll) == null:
			break
		_check(build.commit(reroll).ok, "ordinary paid reroll seeks supply without free refresh")
	_check(not offer.is_empty(), "earned shop has an unused tactical copy")
	if offer.is_empty():
		return
	_check(
		build.commit(SeasonOpponentPolicy.command(build, "tactical_buy", {"offer": offer})).ok,
		"earned Cash purchases supply"
	)
	var receipt: String = build._bank.view().held[-1].id
	var fixture: Dictionary = season.pending_fixture()
	_check(
		(
			build
			. commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": fixture.id}))
			. ok
		),
		"new attempt anchors supply"
	)
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	var side: int = 1 if fixture.home == 0 else 0
	var own: TeamMatchState = state.home_team if side == 1 else state.away_team
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		state, own, SeasonInventoryRules.anchor(build, fixture.id)
	)
	_check(not proof.is_empty(), "zero-PA unused supply proof")
	if proof.is_empty():
		return
	var command: Dictionary = SeasonOpponentPolicy.command(
		build,
		"match_supply_sell",
		{
			"game": fixture.id,
			"receipt": receipt,
			"first_pitch": null,
			"field_state": proof.field_state,
			"inventory_prefix": proof
		}
	)
	var quote: Dictionary = SeasonInventoryResale.quote(build._bank, receipt)
	var before: Dictionary = SeasonSave.snapshot(season)
	var cash: int = build.cash()
	_check(
		build.candidate(command) != null and ClubCareer.same(before, SeasonSave.snapshot(season)),
		"cancel paid-copy sale preserves exact season"
	)
	_check(
		build.commit(command).ok and build.cash() == cash + int(quote.refund),
		"earned unused copy pays exact actual-paid half"
	)
	_check(SeasonSave.save(season), "save78 after live supply sale")
	var cold: SeasonState = SeasonSave.restore()
	_check(
		cold != null and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(season)),
		"whole-season sale cold replay exact"
	)
	if cold == null:
		return
	var cold_before: Dictionary = SeasonSave.snapshot(cold)
	_check(
		(
			cold.build.commit(command).get("replayed", false)
			and ClubCareer.same(cold_before, SeasonSave.snapshot(cold))
		),
		"cold whole-season sale retry pays once"
	)
	_check(
		SeasonSave._decode(cold_before.checkpoint) == null,
		"progressed enabled journals reject stripped save78 wrapper"
	)
	var orientation: SeasonState = SeasonSave._decode(cold_before)
	var oriented: Dictionary = orientation.build._events[-1].inventory_prefix
	oriented.own_index = 1 - side
	oriented.rosters.reverse()
	_check(
		(
			SeasonBuild.from_data(
				orientation.build.to_data(),
				orientation.build._seed,
				orientation.build._initial_roster,
				orientation.build._pool,
				orientation.build._blocked
			)
			!= null
		),
		"wrong orientation remains internally valid Build proof"
	)
	var oriented_save: Dictionary = SeasonSave.snapshot(orientation)
	_check(
		oriented_save.is_empty() or SeasonSave._decode(oriented_save) == null,
		"external fixture rejects reversed side despite internally consistent proof"
	)
	var unchanged: Dictionary = SeasonSave.snapshot(season)
	var event: Dictionary = cold.build._events[-1]
	var order: Array = event.inventory_prefix.rosters[1 - side]
	var first: Variant = order[0]
	order[0] = order[1]
	order[1] = first
	_check(
		(
			SeasonBuild.from_data(
				cold.build.to_data(),
				cold.build._seed,
				cold.build._initial_roster,
				cold.build._pool,
				cold.build._blocked
			)
			!= null
		),
		"wrong opponent permutation remains internally valid Build proof"
	)
	var wrong: Dictionary = SeasonSave.snapshot(cold)
	_check(
		wrong.is_empty() or SeasonSave._decode(wrong) == null,
		"whole-season authority rejects internally valid wrong-opponent order"
	)
	_check(
		ClubCareer.same(unchanged, SeasonSave.snapshot(season)),
		"rejected foreign fixture does not change original cash or journal"
	)
