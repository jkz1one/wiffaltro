extends "res://src/tests/season_opponent_sponsors_test.gd"
## Paid generated-stock diagnostics, shared actual play, frozen history and pregame review.

var _choice_probe: OpponentChoiceProbe = OpponentChoiceProbe.new()


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_choice_units()
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	for item: String in ["F03", "F01"]:
		await _choice_game(item)
	RenderingServer.set_render_loop_enabled(true)
	await _choice_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent choice checks passed: paid stock, explicit choices and real physics.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(seed_value, ["player.alex_finch", "player.lee_stone",
		"player.rowan_chase", "player.gray_west"])
	build._market = 7
	_check(build.commit(SeasonOpponentPolicy.command(build, "reward", {
		"game": 0, "win": true, "performance": _performance(build, 0, 0)})).ok,
		"synthetic stock budget, no qualifying events fabricated")
	return build


func _choice_units() -> void:
	var purchased: Dictionary = {}
	for seed_value in range(128):
		var build: SeasonBuild = _build(seed_value)
		_check(SeasonOpponentSponsors.pool(build).keys() == ["D01", "A07", "B02", "B03", "F01", "F03"],
			"six supported sponsors, no tactical or information grants")
		var old: SeasonBuild = build._fork()
		old._market = 6
		_check(SeasonOpponentSponsors.pool(old).keys() == SeasonOpponentSponsors.ITEMS,
			"historical market6 never offers new choices")
		var stock: Dictionary = SeasonOpponentSponsors.offers(build, 0)
		var poor: SeasonBuild = build._fork()
		poor._bank.commit({"id": "charge", "rev": poor._bank.revision(),
			"op": "charge", "amount": poor.cash()})
		_check(stock == SeasonOpponentSponsors.offers(poor, 0), "no affordability filtering")
		for profile: String in ["Distributed", "Featured hitter", "Pitching / defense"]:
			var buyer: SeasonBuild = _build(seed_value)
			var club: Dictionary = _club(buyer)
			club.profile = profile
			var targets: Array[String] = SeasonOpponentSponsors.targets(buyer, club)
			_check(targets == (["B03", "F01"] if profile == "Pitching / defense" else ["F03"]),
				"current actual eligibility, no proxy development or fabricated walk signal")
			SeasonOpponentPolicy.checkout(buyer, club, 0)
			for row: Dictionary in club.decisions:
				if row.stat == "sponsor":
					purchased[row.item] = true
					_check(SeasonOpponentSponsors.pool(_build(seed_value)).has(row.item)
						and row.paid == SeasonSponsorCatalog.item(row.item).price, "profile pays shared choice price")
			_audit(buyer, club)
	_check(purchased.has("F01") and purchased.has("F03"), "ordinary policy buys both choices")
	for item: String in ["F03", "F01"]:
		_buy_choice(item)
	print("NPC_CHOICE_POLICY purchased=", purchased.keys())


func _buy_choice(item: String) -> void:
	for seed_value in range(512):
		var build: SeasonBuild = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		if not build._visit.offers.values().has(item):
			continue
		var club: Dictionary = _club(build)
		club["build"] = build
		club.profile = "Pitching / defense" if item == "F01" else "Distributed"
		var before: Dictionary = build.to_data()
		var poor: SeasonBuild = build._fork()
		poor._bank.commit({"id": "poor", "rev": poor._bank.revision(),
			"op": "charge", "amount": poor.cash()})
		var snapshot: Dictionary = poor.to_data()
		_check(not SeasonOpponentSponsors.purchase(poor, club.duplicate(true), 0)
			and ClubCareer.same(snapshot, poor.to_data()), "unaffordable policy preserves exact state")
		_check(SeasonOpponentSponsors.purchase(build, club, 0) and build.cash() == 8,
			"actual generated choice paid once")
		_check(build._bank.view().sponsors[0].item == item and build._bank.view().sponsors[0].paid == 10,
			"exact paid receipt owns choice")
		_check(not SeasonOpponentSponsors.pool(build).has(item), "owned identity leaves future pool")
		_check(SeasonBuild.from_data(build.to_data(), build._seed, build.roster()) != null,
			"market7 paid replay accepted")
		_check(before.events.size() + 1 == build.to_data().events.size(), "no free grant or extra events")
		_paid[item] = {"build": build, "club": club}
		return
	_check(false, "generated offer missing " + item)


func _choice_game(item: String) -> void:
	if not _paid.has(item):
		return
	var build: SeasonBuild = _paid[item].build
	var club: Dictionary = _paid[item].club
	var away: Array[PlayerDefinition] = []
	var home: Array[PlayerDefinition] = []
	for id: String in build.roster():
		away.append(build.definition(id))
	for id: String in ["player.dakota_wells", "player.mika_reed",
		"player.jamie_nash", "player.quinn_riley"]:
		home.append(SeasonBuild.new(9, [id]).definition(id))
	var state: MatchState = MatchState.create(TeamMatchState.create("Paid choice diagnostic", away),
		TeamMatchState.create("Ordinary opposition", home))
	state.away_team.ai_sponsor_choices = true
	state.away_team.pitcher_index = build.roster().find(club.roles.pitcher)
	state.away_team.fielder_index = build.roster().find(club.roles.fielder)
	var before: Dictionary = build.to_data()
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var failures: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: failures.append(reason))
	_check(runner.start(state, 67), "paid choice real game starts")
	var lab: PitchBatLab = runner._lab
	var initial: Dictionary = {"rows": lab._match_state.ai_choice_events.duplicate(true),
		"mode": lab._match_state.optics_mode, "recipe": lab._selected_pitch_index}
	SeasonOpponentChoices.prepare(lab)
	_check(ClubCareer.same(initial.rows, lab._match_state.ai_choice_events)
		and initial.mode == lab._match_state.optics_mode, "repeat preparation cannot peek or rechoose")
	_check(initial.rows.size() == 1 and initial.rows[0].role == "bat",
		"human-owned opposition choices untouched, even with both controllers")
	for frame in range(300000):
		await get_tree().physics_frame
		_choice_probe.observe(runner._lab, _check)
		if not report.is_empty() or not failures.is_empty():
			break
	_check(failures.is_empty() and PhysicalMatchReport.valid(report),
		"complete real choice game balances")
	if not report.is_empty():
		_check(report.version == 2 and PhysicalChoiceEvidence.matches(report, state),
			"report2 binds all explicit choices to committed paid ownership")
		for corruption: String in ["missing", "duplicate", "mode", "player", "spot", "club", "resolver"]:
			var bad: Dictionary = report.duplicate(true)
			match corruption:
				"missing": bad.choices.events.pop_back()
				"duplicate": bad.choices.events.append(bad.choices.events[-1])
				"mode": bad.choices.events[0].mode = "tall"
				"player": bad.choices.events[0].player = "player.mika_reed"
				"spot": bad.choices.events[0].spot = 0
				"club": bad.choices.clubs = [false, false]
				"resolver": bad.resolver = PhysicalMatchReport.RESOLVER
			_check(not PhysicalMatchReport.valid(bad), "altered choice " + corruption + " rejected")
		var altered: Dictionary = report.duplicate(true)
		for row: Dictionary in altered.choices.events:
			if row.mode != "normal":
				row.mode = "normal"
				break
		_check(PhysicalMatchReport.valid(altered) and not PhysicalChoiceEvidence.matches(altered, state),
			"structurally legal missing paid effect rejects against committed ownership")
		altered = report.duplicate(true)
		for row: Dictionary in altered.choices.events:
			if row.role == "field":
				var field: FieldDefinition = ContentDB.get_field(StringName(report.field))
				for spot in range(9):
					if spot != row.spot and field.is_fielder_anchor_available(spot):
						row.spot = spot
						break
				break
		_check(PhysicalMatchReport.valid(altered) and not PhysicalChoiceEvidence.matches(altered, state),
			"another legal spot rejects against the actual ordinary pre-PA positioning policy")
		altered = report.duplicate(true)
		for row: Dictionary in altered.choices.events:
			if row.role == "field":
				for id: String in report.teams[0].roster:
					if id != row.player:
						row.player = id
						break
				break
		_check(PhysicalMatchReport.valid(altered) and not PhysicalChoiceEvidence.matches(altered, state),
			"another owned roster member cannot replace the committed primary fielder")
		var unpaid: MatchState = PhysicalMatchRequest.capture(state)
		for player: PlayerMatchState in unpaid.away_team.roster:
			player.definition.season_sponsors = {}
		_check(not PhysicalChoiceEvidence.matches(report, unpaid),
			"unpaid ownership cannot claim chosen effect")
	_check(state.ai_choice_events.is_empty() and ClubCareer.same(before, build.to_data()),
		"detached game isolates caller state and paid receipts")
	for id: String in build.roster():
		_check(ContentDB.get_player(StringName(id)).season_sponsors.is_empty(),
			"natural resources unchanged")
	_check(_choice_probe.wide_frames > 0 if item == "F03" else _choice_probe.anchored_frames > 0,
		"real gameplay exercises paid choice " + item)
	print("NPC_PAID_CHOICE item=", item, " releases=", report.get("releases", []).size(),
		" events=", report.get("choices", {}).get("events", []).size(), " ", _choice_probe.summary())
	runner.queue_free()
	await _frames()


func _choice_ui() -> void:
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true)
	_check(app.season.opponents._format == 8 and SeasonSave.snapshot(app.season).version == 52,
		"ordinary new Working start uses save52 / policy8")
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "new partial drafts restore")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-choices-pregame")
	for item: String in ["F03", "F01"]:
		var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
		SeasonPages.wrapped(card, "Paid diagnostic club • actual receipt and completed physical game")
		SeasonOpponentSponsorsUI.preview(card, _paid[item].club)
		await _frames()
		await _lesson_capture(app, card, "opponent-paid-choice-" + item)
	app.queue_free()
	await _frames()
