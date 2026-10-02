extends "res://src/tests/season_earned_sponsor_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://freezers-%d.json" % OS.get_process_id()
	_contract()
	_progress()
	_migration()
	await _freezer_ui()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Freezers checks passed: ordered feats, Cold, physics, paid stock, migration and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _bat(state: MatchState, index: int, outcome: String) -> void:
	state.batting_team().batting_index = index
	state.outs = 0
	state.phase = MatchState.Phase.PRE_PITCH
	match outcome:
		"walk":
			state.balls = 3
			state.record_ball()
		"strikeout":
			state.strikes = 2
			state.record_strike()
		"single":
			state.record_hit(BallPlayOutcome.Result.SINGLE)
		_:
			state.record_ball_in_play_out()


func _contract() -> void:
	var state: MatchState = _new_club(67).make_match()
	var team: TeamMatchState = state.batting_team()
	for player: PlayerMatchState in team.roster:
		player.definition.season_sponsors["E10"] = true
	var hitter: PlayerMatchState = team.roster[0]
	_bat(state, 0, "out")
	_check(state.cold.stacks(hitter) == 1, "first hitless AB")
	_bat(state, 0, "walk")
	_check(state.cold.stacks(hitter) == 1, "walk neither adds nor clears")
	_bat(state, 1, "strikeout")
	_check(
		state.cold.stacks(hitter) == 1 and state.cold.stacks(team.roster[1]) == 1,
		"individual hitters"
	)
	_bat(state, 0, "strikeout")
	_bat(state, 0, "out")
	_check(state.cold.stacks(hitter) == 2, "two-stack cap")
	team.batting_index = 0
	state.record_foul()
	state.record_strike()
	_check(state.cold.stacks(hitter) == 2, "uncompleted strikes and fouls neutral")
	var gear: Node = GearChecks.new()
	for bat: String in ["", "A02", "BAT-POW-03"]:
		for misc: String in ["", "MISC-BAT-01"]:
			hitter.definition.season_gear = {"bat": bat, "misc": misc}
			for swing: StringName in [&"swing.contact", &"swing.power"]:
				var source: SwingProfileDefinition = ContentDB.get_swing(swing)
				var normal: SwingProfileDefinition = SeasonGearCatalog.swing(
					source, hitter.definition
				)
				var changed: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
				var bonus: float = (
					0.06 * float(SeasonGearCatalog.item(misc).get("exit", 1.0))
					if swing == &"swing.power"
					else 0.0
				)
				_check(
					is_equal_approx(
						changed.gear_fair_exit_scale, normal.gear_fair_exit_scale + bonus
					),
					"additive Power term before misc penalty"
				)
				_check(
					(
						changed.contact_start() == normal.contact_start()
						and changed.contact_end() == normal.contact_end()
					),
					"no timing modification"
				)
				var radius: float = (
					(
						0.08
						* source.contact_radius_x_m
						* float(SeasonGearCatalog.item(misc).get("radius", 1.0))
					)
					if swing == &"swing.contact"
					else 0.0
				)
				_check(
					is_equal_approx(changed.contact_radius_x_m, normal.contact_radius_x_m - radius),
					"Contact-only additive coverage cost"
				)
				for left: bool in [false, true]:
					var original: ContactResult = gear._contact(normal, left, 0.4)
					var modified: ContactResult = gear._contact(changed, left, 0.4)
					_check(
						is_equal_approx(
							modified.exit_velocity.length() / original.exit_velocity.length(),
							changed.gear_fair_exit_scale / normal.gear_fair_exit_scale
						),
						"fair contact resolver uses exact speed scale"
					)
	gear.free()
	var before: SwingProfileDefinition = SeasonSponsorEffects.swing(
		ContentDB.get_swing(&"swing.power"), state
	)
	_bat(state, 0, "single")
	_check(
		before.gear_fair_exit_scale > 1.0 and state.cold.stacks(hitter) == 0,
		"hit uses pre-result stacks then clears"
	)
	_check(state.cold.stacks(team.roster[1]) == 1, "other hitter retains Cold")
	team.batting_index = 1
	hitter = team.roster[1]
	hitter.definition.season_sponsors.erase("E10")
	_check(state.cold.stacks(hitter) == 0, "retired copy has no effect")
	var fresh: MatchColdStreak = MatchColdStreak.new()
	_check(
		fresh.stacks(team.roster[0]) == 0 and fresh.appearances.is_empty(),
		"fresh game resets runtime"
	)
	_check(
		SeasonFreezers.breakout(["out", "walk", "strikeout", "single"]),
		"neutral walk in qualifying sequence"
	)
	_check(
		not SeasonFreezers.breakout(["out", "single", "out", "single"]),
		"intervening hit breaks streak"
	)


func _completed(season: SeasonState, outcomes: Array, win: bool = true) -> Dictionary:
	var game: Dictionary = season.pending_fixture()
	var own: Array = season.teams[0].roster
	var rival: Array = season.teams[game.away if game.home == 0 else game.home].roster
	var stats: MatchPerformance = MatchPerformance.new()
	var evidence: Dictionary = {}
	for id: String in own:
		evidence[id] = []
	for outcome: String in outcomes:
		stats.complete(StringName(own[0]), StringName(rival[0]), outcome, 0)
		evidence[own[0]].append(outcome)
	for id: String in own + rival:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	var home_wins: bool = (game.home == 0) == win
	_check(
		season.record_player_result(
			game.id, 0 if home_wins else 1, 1 if home_wins else 0, stats.players, [], [], evidence
		),
		"controlled ordered completed game"
	)
	return evidence


func _progress() -> void:
	var season: SeasonState = _new_club(88)
	_completed(season, ["out", "out"])
	_completed(season, ["single"])
	_check(not season.build._freezer_earned, "no cross-game streak")
	_completed(season, ["out", "walk", "strikeout", "single"], false)
	_check(
		season.build._freezer_earned and SeasonEarnedSponsors.eligible(season.build).has("E10"),
		"loss earns paid eligibility"
	)
	_check(SeasonSave.save(season), "ordered evidence saves")
	var malformed: Dictionary = season.build.to_data().events[-1].duplicate(true)
	malformed.id = "bad-streak"
	malformed.rev = season.build.revision()
	malformed.game = 31
	malformed.batting[season.picks[0]].append("out")
	var previous: Dictionary = season.build.to_data()
	_check(
		not season.build.commit(malformed).ok and season.build.to_data() == previous,
		"bad evidence rolls back reward and progression"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build._freezer_earned, "ordered evidence replay")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for field: String in ["result", "count", "history", "inherited", "foreign"]:
		var bad: Dictionary = data.duplicate(true)
		match field:
			"result":
				bad.results[-1].batting[season.picks[0]].reverse()
			"count":
				bad.build.events[-1].batting[season.picks[0]].append("out")
			"history":
				bad.career.runs[-1].freezer_earned = false
			"inherited":
				bad.build.freezer_start = true
			"foreign":
				bad.build.events[-1].batting["foreign"] = []
		_check(SeasonSave._decode(bad) == null, "reject forged " + field)
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "abandon retains completed feat")
	var next: SeasonState = _new_club(88, club)
	_check(
		next.build._freezer_start == true and next.build.view().wallet.sponsors.is_empty(),
		"new season inherits access only"
	)


func _paid_freezer(buy: bool = true) -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._freezer_start = false
	probe._freezer_earned = true
	probe._visit.number = 3
	for seed_value in range(10000):
		probe._seed = seed_value
		if not probe._offers(0).values().has("E10"):
			continue
		var season: SeasonState = _new_club(seed_value)
		_completed(season, ["out", "out", "single"])
		_completed(season, [])
		_completed(season, [])
		_check(
			season.build.commit(_command(season.build, "open")).ok, "open genuine eligible stock"
		)
		var offer: String = _offer(season.build, "E10")
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
				"pay 12 for generated Freezers"
			)
		print("FREEZERS_FIXTURE seed=", seed_value)
		return season
	_check(false, "reachable Freezers offer")
	return null


func _migration() -> void:
	var season: SeasonState = _new_club(88)
	season.build._format = 28
	season.build._freezer_start = null
	season.build._sides_start = null
	season.build._jump_start = null
	season.build._batch_start = null
	season.build._sure_start = null
	season.build._field_start = null
	season.build._copy.start = null
	season.build._abilities.start = null
	season.build._major.start = null
	season.career.runs[-1].freezer_earned = null
	season.career.runs[-1].sides_earned = null
	season.career.runs[-1].jump_earned = null
	season.career.runs[-1].batch_used = null
	season.career.runs[-1].sure_earned = null
	season.career.runs[-1].field_outs = null
	season.career.runs[-1].copy_earned = null
	season.career.runs[-1].sky_outs = null
	season.career.runs[-1].major_earned = null
	_result(season, ["single"])
	_check(SeasonSave.save(season), "prior format paid result")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 9
	data.career.runs[-1].erase("freezer_earned")
	data.career.runs[-1].erase("sides_earned")
	data.career.runs[-1].erase("jump_earned")
	data.career.runs[-1].erase("batch_used")
	data.career.runs[-1].erase("sure_earned")
	data.career.runs[-1].erase("field_outs")
	data.career.runs[-1].erase("copy_earned")
	data.career.runs[-1].erase("sky_outs")
	data.career.runs[-1].erase("major_earned")
	var restored: SeasonState = SeasonSave._decode(data)
	_check(
		restored != null and restored.build._freezer_start == null,
		"old active save stays prospective"
	)
	_check(
		restored != null and SeasonSave.save(restored) and SeasonSave.restore() != null,
		"migrated second save"
	)


func _freezer_ui() -> void:
	var season: SeasonState = _paid_freezer(false)
	_check(SeasonSave.save(season), "save paid UI source")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "freezers-shop")
	var offer: String = _offer(season.build, "E10")
	var before: Dictionary = season.build.to_data()
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "cancel Freezers purchase")
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(app.season.build.to_data() == before, "failed purchase rollback")
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	_check(SeasonSchoolSponsors.active(app.season.build, "E10").paid == 12, "confirmed paid copy")
	window.queue_free()
	await _frames()
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "freezers-progress")
	_check(SeasonSave.restore() != null, "paid copy reload")
	app.play_season_game()
	await _frames(3)
	var lab: PitchBatLab = app.lab
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var state: MatchState = lab._match_state
	state.top_half = not lab._player_home
	_bat(state, 0, "out")
	_bat(state, 0, "out")
	state.batting_team().batting_index = 0
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	lab._awaiting_batter_confirm = true
	lab._refresh_config()
	await _frames()
	var cold_label: Label = lab.find_child("ColdStreak", true, false)
	_check(
		cold_label != null and cold_label.visible and cold_label.text.contains("COLD 2/2"),
		"readiness shows actual hitter stacks"
	)
	if cold_label != null:
		_check(cold_label.get_global_rect().end.y <= 720, "readiness status inside viewport")
	await _click(app.loadout.entry)
	await _click(app.loadout._tab_buttons[1])
	await _frames()
	var rows: Dictionary = SeasonLoadoutData.pages(app)
	_check(rows.sponsors[0].effect.contains("Cold 2/2"), "Equipped shows every hitter's live Cold")
	_check(
		app.loadout.panel.get_rect().size.x <= get_viewport().get_visible_rect().size.x,
		"Equipped stays bounded"
	)
	await _click(app.loadout.close_button)
	app.leave_game()
	_check(
		app.season.make_match().cold.appearances.is_empty(),
		"abandon restarts clean pregame streaks"
	)
	app.queue_free()
	await _frames()
