extends "res://src/tests/season_jumpstart_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://field-supply-%d.json" % OS.get_process_id()
	_field_runtime()
	_field_progress()
	_field_settlement()
	_field_capacity()
	_field_sale_boundary()
	_field_save()
	_field_migration()
	await _field_ui()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Field Supply checks passed: delivery, earned access, receipts, restart and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _clean(state: MatchState, dirty: String = "", pitcher: bool = false) -> void:
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(&"field.starter_backyard"), dirty == "foul")
	if dirty == "bobble":
		resolver.record_bobble(&"primary_fielder", Vector3(0, 1, 15))
	var outcomes: Array = []
	resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome))
	resolver.record_clean_control(
		&"pitcher" if pitcher else &"primary_fielder", Vector3(0, 1, 15), true
	)
	state.clean_outs.record(state, resolver.state, outcomes[0])
	state.clean_outs.record(state, resolver.state, outcomes[0])
	state.record_ball_in_play_out()
	state.continue_after_dead_ball()


func _field_runtime() -> void:
	for mode: String in ["room", "full", "development"]:
		var state: MatchState = _new_club(67).make_match()
		var own: TeamMatchState = state.defensive_team()
		for player: PlayerMatchState in own.roster:
			player.definition.season_sponsors["B01"] = true
		if mode == "full":
			own.tactics.held = [{"id": "one", "item": "A10"}, {"id": "two", "item": "C03"}]
		if mode == "development":
			own.field_supply.reserved = 2
		for index in range(2):
			_clean(state, "", index == 1)
		_check(
			own.field_supply.clean == 2 and own.field_supply.evidence().is_empty(),
			"two outs no grant"
		)
		_clean(state)
		_check(own.field_supply.clean == 3, "pitcher catches count; callbacks deduplicate")
		_check(
			own.field_supply.evidence().outcome == ("granted" if mode == "room" else "full"),
			"shared bag boundary"
		)
		if mode != "room":
			own.tactics.held.clear()
			own.field_supply.reserved = 0
		# Go through another defensive half; opportunity remains spent.
		for index in range(3):
			_clean(state)
		for index in range(3):
			_clean(state)
		_check(
			own.tactics.held.size() == (1 if mode == "room" else 0),
			"once per game; no deferred queue"
		)
		_check(
			own.field_supply.label().contains("forfeited") == (mode != "room"),
			"visible full-bag reason"
		)
	var state: MatchState = _new_club(67).make_match()
	var own: TeamMatchState = state.defensive_team()
	for player: PlayerMatchState in own.roster:
		player.definition.season_sponsors["B01"] = true
	_clean(state, "bobble")
	_clean(state, "foul")
	_check(own.field_supply.clean == 0, "prior bobble and foul catch never count")


func _field_progress() -> void:
	var season: SeasonState = _new_club(67)
	_jump_result(season, false, false)
	_check(
		(
			season.build._field_outs == 3
			and not SeasonEarnedSponsors.eligible(season.build).has("B01")
		),
		"three outs locked"
	)
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "close partial season")
	var next: SeasonState = _new_club(67, club)
	_jump_result(next, false)
	_check(next.build._field_outs == 3 and not next.build._field_start, "seasons do not combine")
	_jump_result(season, false)
	_check(
		season.build._field_outs == 6 and SeasonEarnedSponsors.eligible(season.build).has("B01"),
		"six across games earn paid access"
	)
	club = season.career.fork()
	_check(club.close(season), "close earned season")
	next = _new_club(67, club)
	_check(
		(
			next.build._field_start
			and next.build._field_outs == 0
			and next.build.view().wallet.sponsors.is_empty()
		),
		"only eligibility inherited"
	)


func _paid_field(buy: bool = true, home: Variant = null) -> SeasonState:
	var games: int = 4 if home == false else 3
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._field_start = false
	probe._field_outs = games * 3
	probe._jump_start = false
	probe._visit.number = games
	for seed_value in range(10000):
		probe._seed = seed_value
		if not probe._offers(0).values().has("B01"):
			continue
		var season: SeasonState = _new_club(seed_value)
		for game_index in range(games):
			_jump_result(season, false)
		if home != null and (season.pending_fixture().home == 0) != home:
			continue
		season.build.commit(_command(season.build, "open"))
		var offer: String = _offer(season.build, "B01")
		if offer.is_empty():
			continue
		if buy:
			_check(
				(
					season
					. build
					. commit(_command(season.build, "sponsor_buy", {"offer": offer, "replace": ""}))
					. ok
				),
				"paid 14 Cash copy"
			)
		return season
	_check(false, "reachable paid Field Supply")
	return null


func _reward(season: SeasonState, use: bool = false) -> Dictionary:
	var game: Dictionary = season.pending_fixture()
	var own: Array = season.teams[0].roster
	var rival: Array = season.teams[game.away if game.home == 0 else game.home].roster
	var stats: MatchPerformance = MatchPerformance.new()
	var rows: Array = []
	for index in range(3):
		stats.complete(StringName(rival[index]), StringName(own[0]), "out", 0)
		rows.append(
			{
				"pa": index + 1,
				"half": 0 if game.home == 0 else 1,
				"player": own[index + 1],
				"pitcher": own[0],
				"primary": true,
				"air": true,
				"clean": true
			}
		)
	stats.complete(StringName(own[0]), StringName(rival[0]), "single", 0)
	for id: String in own + rival:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	return _command(
		season.build,
		"reward",
		{
			"game": game.id,
			"win": true,
			"performance": stats.players,
			"fielding": rows,
			"field_supply": {"after_pa": 3, "outcome": "granted"},
			"tactics":
			(
				[
					{
						"receipt": SeasonFieldGrant.receipt(game.id),
						"player": own[0],
						"pa": 4,
						"swing": ""
					}
				]
				if use
				else []
			)
		}
	)


func _field_settlement() -> void:
	for use: bool in [false, true]:
		var season: SeasonState = _paid_field()
		var build: SeasonBuild = season.build
		_check(
			(
				build
				. commit(_command(build, "match_inventory", {"game": season.pending_fixture().id}))
				. ok
			),
			"start attempt"
		)
		var command: Dictionary = _reward(season, use)
		var original: Dictionary = build.to_data()
		for patch: Dictionary in [
			{"after_pa": 2, "outcome": "granted"},
			{"after_pa": 3, "outcome": "full"},
			{"after_pa": 3, "outcome": "granted", "extra": true}
		]:
			var bad: Dictionary = command.duplicate(true)
			bad.field_supply = patch
			_check(
				not build.commit(bad).ok and build.to_data() == original,
				"forged grant rolls back reward"
			)
		for actions: Variant in ["bad", [1], [{"receipt": "bad", "pa": "1"}]]:
			var bad: Dictionary = command.duplicate(true)
			bad.tactics = actions
			_check(
				not build.commit(bad).ok and build.to_data() == original,
				"malformed activation fails closed"
			)
		_check(build.commit(command).ok, "generated copy settles used or unused")
		_check(build.view().wallet.held.size() == (0 if use else 1), "only unused copy persists")
		_check(build._supply_used == (1 if use else 0), "generation alone gives no use progress")
		var restored: SeasonBuild = SeasonBuild.from_data(
			build.to_data(), build._seed, build._initial_roster, build._pool, build._blocked
		)
		_check(
			restored != null and ClubCareer.same(restored.view(), build.view()),
			"receipt and accounting replay"
		)
		_check(build.commit(command).replayed, "no duplicate grant on retry")
		if not use:
			_check(
				build.view().wallet.held[0].paid == 0 and build.view().wallet.held[0].item == "A10",
				"ordinary Tape with zero purchase price"
			)


func _field_save() -> void:
	var season: SeasonState = _paid_field()
	_check(SeasonSave.save(season), "current career saved")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	_check(SeasonSave._decode(data) != null, "current career rebuild")
	for kind: String in ["career", "start", "clean"]:
		var bad: Dictionary = data.duplicate(true)
		if kind == "career":
			bad.career.runs[-1].field_outs += 1
		elif kind == "start":
			bad.build.field_start = true
		else:
			bad.build.events[0].fielding[0].clean = false
		_check(SeasonSave._decode(bad) == null, "reject forged Field Supply " + kind)


func _field_migration() -> void:
	var season: SeasonState = _new_club(88)
	season.build._format = 33
	season.build._field_start = null
	season.build._copy.start = null
	season.build._abilities.start = null
	season.build._major.start = null
	season.career.runs[-1].field_outs = null
	season.career.runs[-1].copy_earned = null
	season.career.runs[-1].sky_outs = null
	season.career.runs[-1].major_earned = null
	_jump_result(season, false)
	_check(SeasonSave.save(season), "previous build saved")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 14
	data.career.runs[-1].erase("field_outs")
	data.career.runs[-1].erase("copy_earned")
	data.career.runs[-1].erase("sky_outs")
	data.career.runs[-1].erase("major_earned")
	var restored: SeasonState = SeasonSave._decode(data)
	_check(
		(
			restored != null
			and restored.build._field_start == null
			and restored.build._field_outs == 0
		),
		"old clean outs never retroactively earn"
	)
	_check(
		restored != null and SeasonSave.save(restored) and SeasonSave.restore() != null,
		"migrated second save"
	)


func _field_ui() -> void:
	var season: SeasonState = _paid_field(false)
	_check(SeasonSave.save(season), "UI earned stock checkpoint")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "field-supply-shop")
	var offer: String = _offer(season.build, "B01")
	var before: Dictionary = season.build.to_data()
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "cancel paid offer")
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(app.season.build.to_data() == before, "failed purchase keeps stock and cash")
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	_check(SeasonSchoolSponsors.active(app.season.build, "B01").paid == 14, "paid fourteen")
	window.queue_free()
	await _frames()
	app.menu.show_lineup()
	await _menu_bounds(app, "field-supply-lineup")
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "field-supply-progress")
	app.play_season_game()
	await _frames(3)
	var rows: Dictionary = SeasonLoadoutData.pages(app)
	var found: bool = false
	for row: Dictionary in rows.sponsors:
		found = found or (row.name == "Field Supply Co." and row.label.contains("0 / 3"))
	_check(found, "Equipped live counter")
	app.lab.set_process(false)
	app.lab.set_physics_process(false)
	var state: MatchState = app.lab._match_state
	_clean(state)
	_clean(state)
	state.begin_pitch()
	var copy: Dictionary = SeasonSchoolSponsors.active(app.season.build, "B01")
	_check(app.sales.sell(app, SeasonMatchSales.command(app, copy.id)), "unfinished PA sale saved")
	_check(app.sales._through_pa == 3, "sale remembers this PA")
	app.leave_game()
	await _frames()
	app.play_season_game()
	await _frames(3)
	_check(
		app.sales._through_pa == 0 and app.sales.pending.is_empty(),
		"actual relaunch resets retirement boundary"
	)
	_check(
		app.lab._match_state.home_team.field_supply.clean == 0, "actual relaunch resets generator"
	)
	_check(
		SeasonSchoolSponsors.active(app.season.build, "B01").is_empty(),
		"actual relaunch retains saved sale"
	)
	app.queue_free()
	await _frames()


func _field_capacity() -> void:
	var fixture: Node = preload("res://src/tests/season_small_batch_test.gd").new()
	for mode: String in ["generated", "paid", "before"]:
		var build: SeasonBuild = fixture._unit_build([])
		build._field_start = true
		build._batch_start = SeasonSmallBatch.TYPES.duplicate()
		for id: String in ["G02", "B01"]:
			_check(
				(
					build
					. commit(
						_command(
							build,
							"sponsor_buy",
							{"offer": fixture._unit_offer(build, id), "replace": ""}
						)
					)
					. ok
				),
				"controlled paid capacity sponsors"
			)
		build._jump_start = false
		_check(build.commit(fixture._hold(build, "A10")).ok, "first shared slot")
		_check(build.commit(fixture._hold(build, "C03")).ok, "second shared slot")
		_check(build.commit(_command(build, "match_inventory", {"game": 8})).ok, "capacity attempt")
		var season: SeasonState = _new_club(67)
		season.teams[0].roster = build.roster()
		var rivals: Array = (
			SeasonPlayerCatalog
			. ids()
			. filter(func(id: String) -> bool: return not build.roster().has(id))
			. slice(0, 4)
		)
		var game: Dictionary = season.pending_fixture()
		season.teams[game.home if game.away == 0 else game.away].roster = rivals
		var reward: Dictionary = _reward(season)
		reward.game = 8
		var grant: Dictionary = reward.field_supply.duplicate(true)
		var proof: Dictionary = {
			"pa": 4,
			"boundary": 3,
			"grant": grant,
			"uses": [],
			"fielding": reward.fielding.duplicate(true)
		}
		if mode == "before":
			proof.pa = 3
			proof.boundary = 3
			proof.grant = {}
			proof.fielding.pop_back()
			reward.field_supply.outcome = "full"
		var command: Dictionary = _command(
			build,
			"match_sell",
			{
				"game": 8,
				"receipt": SeasonSchoolSponsors.active(build, "G02").id,
				"first_pitch": null,
				"field_state": proof
			}
		)
		var original: Dictionary = build.to_data()
		if mode != "before":
			_check(
				not build.commit(command).ok and build.to_data() == original,
				"generated copy participates in capacity resolution"
			)
			command["sales"] = []
			command["discard"] = [
				(
					SeasonFieldGrant.receipt(8)
					if mode == "generated"
					else build.view().wallet.held[0].id
				)
			]
			command["discarded_use"] = []
		_check(build.commit(command).ok, "exact chosen capacity resolution")
		reward.id = "field-result:%d" % build.revision()
		reward.rev = build.revision()
		var settled: Dictionary = build.commit(reward)
		_check(settled.ok, "sale timing reconstructs delivery: " + settled.get("error", ""))
		_check(build.view().wallet.held.size() == 2, "only selected copy lost; capacity respected")
		var generated: bool = build.view().wallet.held.any(
			func(row: Dictionary) -> bool: return row.id == SeasonFieldGrant.receipt(8)
		)
		_check(generated == (mode == "paid"), "generated copy kept or forfeited exactly")
	_check(fixture._failures == 0, "controlled purchase fixtures")
	fixture.free()


func _field_sale_boundary() -> void:
	var app: SeasonApp = SeasonApp.new()
	app.season = _paid_field(true, true)
	app._fixture_id = app.season.pending_fixture().id
	app._season_game = true
	app.loadout = SeasonLoadoutUI.new()
	app.loadout.match_snapshot = SeasonLoadoutData.capture(app.season)
	_check(SeasonPregameCommit.save(app), "sale-boundary attempt saved")
	app.lab = PitchBatLab.new()
	app.lab._player_home = true
	var state: MatchState = app.season.make_match()
	app.lab._match_state = state
	state.inventory_boundary.connect(app.sales.apply_pending.bind(app))
	_clean(state)
	_clean(state)
	state.begin_pitch()
	var copy: Dictionary = SeasonSchoolSponsors.active(app.season.build, "B01")
	var cash_before: int = app.season.cash()
	_check(app.sales.sell(app, SeasonMatchSales.command(app, copy.id)), "sale during third PA")
	_check(app.season.cash() == cash_before + 7, "exact seven Cash refund")
	state.cancel_pitch()
	app.sales.apply_pending(app)
	_check(not app.sales.pending.is_empty(), "canceled windup cannot retire inside committed PA")
	_clean(state)
	_check(app.sales.pending.is_empty(), "third-out boundary retires ownership effect")
	_check(
		state.home_team.field_supply.evidence().outcome == "granted",
		"third out still earns Tape under current PA effect"
	)
	_check(
		state.home_team.tactics.held.size() == 1,
		"earned pending copy delivered after sponsor retires"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and SeasonSchoolSponsors.active(restored.build, "B01").is_empty(),
		"restart retains sale"
	)
	_check(
		restored.make_match().home_team.tactics.held.is_empty(),
		"restart drops unfinished free copy"
	)
	app.lab.free()
	app.loadout.free()
	app.free()
