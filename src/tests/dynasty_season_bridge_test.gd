extends "res://src/tests/dynasty_foundation_test.gd"
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")


func _ready() -> void:
	var lineage: Dictionary = Lineage.close(Lineage.create(semantic_profile()), "loss")
	var next: Dictionary = Lineage.advance(
		lineage, Lineage.request_for(lineage, "next-season", 10902, overflow_choice())
	)
	check(not next.is_empty(), "controlled compact start transition valid")
	if next.is_empty():
		_finish()
		return
	var start: Dictionary = next.lineage.start_profile
	var season: SeasonState = Bridge.create(start)
	check(
		season != null, "explicit carried roster constructs closed season without fabricated draft"
	)
	if season == null:
		_finish()
		return
	check(
		season.picks == start.roster and season.build.roster() == start.roster,
		"carried owner membership/order retained"
	)
	check(season.league_context_consistent(), "all six closed contexts consistent")
	var wallet: Dictionary = season.build._bank.view()
	check(
		season.build.cash() == 0 and wallet.held.is_empty() and wallet.sponsors.is_empty(),
		"new season Cash and supplies/sponsors reset"
	)
	check(
		wallet.get("spare", {}).is_empty() and season.build._used_gear.is_empty(),
		"no old spare or used receipts inherited"
	)
	for slot: String in SeasonOwnership.GEAR_SLOTS:
		check(wallet.gear[slot].is_empty(), "old active gear not inherited")
	check(
		season.build._events.size() == 1 and season.build._bank._events.size() == 1,
		"only capability events, no old rewards"
	)
	check(
		season.build._events[0].op == SeasonInventoryResale.ENABLE_OP,
		"inventory enable remains first human event"
	)
	for team in range(1, 6):
		var ai: SeasonBuild = season.opponents.clubs[str(team)].build
		check(
			ai._dynasty_start.is_empty() and ai._events[0].op == SeasonInventoryResale.ENABLE_OP,
			"AI fresh start with first inventory enable"
		)
		for id: String in ai.roster():
			check(not start.roster.has(id), "AI allocation cannot shadow carried owner")
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	check(snapshot.get("version") == 79, "explicit Dynasty save79 wrapper")
	var restored: SeasonState = SeasonSave._decode(cold(snapshot))
	check(restored != null, "carried cold season restores")
	if restored != null:
		check(
			ClubCareer.same(SeasonSave.snapshot(restored), snapshot), "carried cold snapshot exact"
		)
		check(
			restored.build.player(ALEX).stats == start.players[ALEX].stats,
			"cold definitions retain carried raw growth"
		)
	var stripped: Dictionary = cold(snapshot.checkpoint)
	check(SeasonSave._decode(stripped) == null, "stripping79 to old76 rejects Dynasty context")
	var wrong: Dictionary = cold(snapshot)
	wrong.dynasty_start.owner_id = "foreign-owner"
	check(SeasonSave._decode(wrong) == null, "root/header owner mismatch rejects")
	wrong = cold(snapshot)
	wrong.dynasty_start = {}
	check(SeasonSave._decode(wrong) == null, "dropping carried header rejects raw-draft laundering")
	wrong = cold(snapshot)
	wrong.checkpoint.checkpoint.build.dynasty_start.seed += 1
	check(SeasonSave._decode(wrong) == null, "Build-only start tamper rejects")
	var app: SeasonApp = SeasonApp.new()
	app.season = season
	SeasonSave.path = "user://dynasty-bridge-test.json"
	check(SeasonPregameCommit.save(app), "real pregame transaction commits carried context")
	var state: MatchState = season.make_match()
	check(state != null, "carried match constructor accepts fresh anchor")
	if state != null:
		var own: TeamMatchState = (
			state.home_team if season.pending_fixture().home == 0 else state.away_team
		)
		check(own.roster.size() == 4, "physical owner contains four carried identities")
		check(
			ClubCareer.same(own.dynasty_start, start), "physical owner retains exact lineage start"
		)
		own.dynasty_start = start.duplicate(true)
		var request: MatchState = PhysicalMatchRequest.capture(state)
		check(request != null, "carried fresh physical request snapshots")
		if request != null:
			var copied: TeamMatchState = (
				request.home_team if season.pending_fixture().home == 0 else request.away_team
			)
			check(
				ClubCareer.same(copied.dynasty_start, start),
				"request clone preserves start provenance"
			)
			own.dynasty_start.owner_id = "mutable-caller-change"
			check(
				ClubCareer.same(copied.dynasty_start, start),
				"detached request does not alias mutable caller header"
			)
			own.dynasty_start = start
			copied.league_rules = {}
			copied.league_ownership = {}
			request.league_rules = {}
			request.home_team.league_rules = {}
			request.away_team.league_rules = {}
			request.home_team.league_ownership = {}
			request.away_team.league_ownership = {}
			check(
				not PhysicalLeagueReport.capture_context_valid(request),
				"retained carried identity cannot downgrade to legacy capture"
			)
		for player: PlayerMatchState in own.roster:
			check(
				start.roster.has(String(player.definition.id)),
				"physical definitions bind carried membership"
			)
			check(
				ClubCareer.same(
					SeasonPhysicalFixtures._resource(player.definition),
					SeasonPhysicalFixtures._resource(
						season.build.definition(String(player.definition.id))
					)
				),
				"physical complete definition matches carried recipes/mastery/abilities"
			)
	var pending: Dictionary = SeasonSave.snapshot(season)
	check(
		SeasonSave._decode(cold(pending)) != null,
		"fresh pending attempt cold restore retains start"
	)
	check(
		not (
			season
			. build
			. preview(
				{
					"id": "no-replacement",
					"rev": season.build.revision(),
					"op": "sign",
					"offer": "none",
					"release": ALEX
				}
			)
			. ok
		),
		"ordinary reveal-before-release sign remains gated"
	)
	var raw: SeasonState = SeasonState.create_closed_league(
		100, LeagueRules.capture("dynasty"), true
	)
	check(raw != null, "first-season raw draft remains closed-only")
	if raw != null:
		check(raw.choose_player(raw.offers()[0]), "first-season ordinary draft choice legal")
		var partial: Dictionary = SeasonSave.snapshot(raw)
		check(
			partial.get("version") == 79 and SeasonSave._decode(cold(partial)) != null,
			"partial raw Dynasty draft cold wrapper"
		)
	app.free()
	_finish()


func _finish() -> void:
	print("Dynasty season bridge checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
