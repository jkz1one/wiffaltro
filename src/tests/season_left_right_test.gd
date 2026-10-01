extends "res://src/tests/season_freezers_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://left-right-%d.json" % OS.get_process_id()
	_sides_contract()
	_sides_progress()
	_sides_migration()
	await _sides_ui()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Left Right checks passed: committed sides, paid access, modifiers, migration and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _sides_contract() -> void:
	var state: MatchState = _new_club(67).make_match()
	var team: TeamMatchState = state.batting_team()
	for player: PlayerMatchState in team.roster:
		player.definition.season_sponsors["F06"] = true
	team.roster[0].definition.bats = PlayerDefinition.Handedness.LEFT
	team.roster[0].definition.switch_hitter = false
	team.roster[1].definition.bats = PlayerDefinition.Handedness.RIGHT
	team.roster[1].definition.switch_hitter = false
	_check(not state.sides.active(state), "first batter of half gets no modifier")
	_bat(state, 0, "walk")
	team.batting_index = 1
	_check(state.sides.active(state), "left walk sets reference for right batter")
	state.phase = MatchState.Phase.PRE_PITCH
	_check(state.begin_pitch(), "first pitch commits stance")
	var locked: Dictionary = state.sides._locked.duplicate()
	state.record_foul()
	state.continue_after_dead_ball()
	state.begin_pitch()
	_check(
		state.sides._locked == locked and state.sides.rows.size() == 1,
		"fouls do not add PAs or relock"
	)
	var pitcher: PlayerMatchState = state.pitcher()
	pitcher.definition.throws = 1 - pitcher.definition.throws
	_check(state.sides.active(state), "pitching hand cannot change qualification")
	var gear: Node = GearChecks.new()
	for swing: StringName in [&"swing.contact", &"swing.power"]:
		var source: SwingProfileDefinition = ContentDB.get_swing(swing)
		team.roster[1].definition.season_gear = {"bat": "BAT-POW-03", "misc": "MISC-BAT-01"}
		var normal: SwingProfileDefinition = SeasonGearCatalog.swing(
			source, state.batter().definition
		)
		var modified: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
		var expected: float = (
			normal.gear_fair_exit_scale + (0.04 if swing == &"swing.contact" else -0.04) * 0.96
		)
		_check(
			is_equal_approx(modified.gear_fair_exit_scale, expected),
			"additive authored tradeoff before Gloves"
		)
		_check(
			(
				modified.contact_radius_x_m == normal.contact_radius_x_m
				and modified.contact_radius_y_m == normal.contact_radius_y_m
				and modified.contact_start() == normal.contact_start()
			),
			"no coverage or timing change"
		)
		for left: bool in [false, true]:
			var plain: ContactResult = gear._contact(normal, left, 0.4)
			var changed: ContactResult = gear._contact(modified, left, 0.4)
			_check(
				is_equal_approx(
					changed.exit_velocity.length() / plain.exit_velocity.length(),
					expected / normal.gear_fair_exit_scale
				),
				"real fair-contact resolver exact ratio"
			)
	gear.free()
	team.roster[1].definition.season_gear = {}
	team.roster[1].definition.season_sponsors["A07"] = true
	team.roster[1].definition.season_sponsors["E05"] = 4
	state._deli_next_batter = true
	_check(
		is_equal_approx(
			(
				SeasonSponsorEffects
				. swing(ContentDB.get_swing(&"swing.contact"), state)
				. gear_fair_exit_scale
			),
			1.12
		),
		"Deli plus Legends plus alternating additive"
	)
	team.roster[1].definition.season_sponsors["E10"] = true
	state.cold._cold[String(team.roster[1].definition.id)] = 2
	_check(
		is_equal_approx(
			(
				SeasonSponsorEffects
				. swing(ContentDB.get_swing(&"swing.power"), state)
				. gear_fair_exit_scale
			),
			1.02
		),
		"two Cold and alternating Power net plus two"
	)
	_bat(state, 1, "single")
	_check(state.sides.rows.size() == 2, "one completed hit becomes one reference")
	team.batting_index = 1
	_check(not state.sides.active(state), "same side receives neither modifier")
	state.top_half = not state.top_half
	_check(not state.sides.qualifies(state), "next half resets reference")
	state.top_half = not state.top_half
	state.inning += 1
	_check(not state.sides.qualifies(state), "later same club half resets reference")
	var switcher: PlayerMatchState = team.roster[2]
	switcher.definition.switch_hitter = true
	team.batting_index = 2
	state.sides._previous = {
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1), "left": true
	}
	switcher.batting_hand_override = 0
	_check(state.sides.qualifies(state), "legal switch stance previews right")
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	state.begin_pitch()
	switcher.batting_hand_override = 1
	_check(state.sides.qualifies(state), "commit snapshot cannot change mid-PA")
	state.cancel_pitch()
	_check(not state.sides.qualifies(state), "canceled first pitch restores legal preview")


func _side_result(season: SeasonState, qualify: bool = true, win: bool = true) -> bool:
	var game: Dictionary = season.pending_fixture()
	var own: Array = season.teams[0].roster
	var rival: Array = season.teams[game.away if game.home == 0 else game.home].roster
	var lefts: Array = own.filter(
		func(id: String) -> bool: return season.player_definition(id).bats == 1
	)
	var rights: Array = own.filter(
		func(id: String) -> bool: return season.player_definition(id).bats == 0
	)
	if qualify and (lefts.is_empty() or rights.is_empty()):
		return false
	var rows: Array = []
	var stats: MatchPerformance = MatchPerformance.new()
	for index in range(4):
		var id: String = (lefts[0] if index % 2 == 0 else rights[0]) if qualify else own[0]
		var definition: PlayerDefinition = season.player_definition(id)
		stats.complete(StringName(id), StringName(rival[0]), "walk" if index == 1 else "out", 0)
		rows.append(
			{
				"pa": index + 1,
				"half": 1 if game.home == 0 else 0,
				"player": id,
				"left": definition.bats == 1
			}
		)
	for id: String in own + rival:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	var home_wins: bool = (game.home == 0) == win
	_check(
		season.record_player_result(
			game.id, 0 if home_wins else 1, 1 if home_wins else 0, stats.players, [], [], {}, rows
		),
		"controlled completed stance sequence"
	)
	return true


func _paid_sides(buy: bool = true) -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._sides_start = false
	probe._sides_earned = true
	probe._visit.number = 3
	for seed_value in range(10000):
		probe._seed = seed_value
		if not probe._offers(0).values().has("F06"):
			continue
		var season: SeasonState = _new_club(seed_value)
		if not _side_result(season):
			continue
		_side_result(season, false)
		_side_result(season, false)
		_check(season.build.commit(_command(season.build, "open")).ok, "generated earned stock")
		var offer: String = _offer(season.build, "F06")
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
				"paid Left Right copy"
			)
		print("LEFT_RIGHT_FIXTURE seed=", seed_value)
		return season
	_check(false, "reachable paid Left Right")
	return null


func _sides_progress() -> void:
	var loss: SeasonState = _new_club(98)
	_check(_side_result(loss, true, false) and loss.build._sides_earned, "loss can earn access")
	var season: SeasonState = _paid_sides(false)
	_check(season.build._sides_earned, "three transitions earn access without ownership")
	_check(SeasonSave.save(season), "save stance evidence")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for field: String in ["count", "side", "half", "order", "career", "start", "result"]:
		var bad: Dictionary = data.duplicate(true)
		match field:
			"count":
				bad.build.events[0].stances.pop_back()
			"side":
				bad.build.events[0].stances[0].left = not bad.build.events[0].stances[0].left
			"half":
				bad.results[0].stances[0].half += 1
			"order":
				bad.build.events[0].stances[1].pa = 1
			"career":
				bad.career.runs[-1].sides_earned = false
			"start":
				bad.build.sides_start = true
			"result":
				bad.results[0].stances.reverse()
		_check(SeasonSave._decode(bad) == null, "reject mismatched stance " + field)
	for patch: Dictionary in [{"performance": 5}, {"stances": [{"pa": 1}]}, {"stances": "bad"}]:
		var command: Dictionary = season.build.to_data().events[0].duplicate(true)
		command.id = "invalid-stance"
		command.rev = season.build.revision()
		command.game = 31
		command.merge(patch, true)
		var unchanged: Dictionary = season.build.to_data()
		_check(
			not season.build.commit(command).ok and season.build.to_data() == unchanged,
			"invalid reward rolls back entirely"
		)
	_check(SeasonSave.restore() != null, "stance replay")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "abandon retains completed side feat")
	var next: SeasonState = _new_club(67, club)
	_check(
		next.build._sides_start == true and next.build.view().wallet.sponsors.is_empty(),
		"inherits access not ownership"
	)
	_check(
		SeasonLeftRight.transitions([{"half": 0, "left": true}, {"half": 2, "left": false}]) == 0,
		"cross-half side change never counts"
	)
	_check(
		(
			SeasonLeftRight.transitions(
				[
					{"half": 0, "left": true},
					{"half": 0, "left": false},
					{"half": 2, "left": true},
					{"half": 2, "left": false}
				]
			)
			== 2
		),
		"qualified transitions accumulate across halves"
	)


func _sides_migration() -> void:
	var season: SeasonState = _new_club(88)
	season.build._format = 29
	season.build._sides_start = null
	season.build._jump_start = null
	season.build._batch_start = null
	season.build._sure_start = null
	season.build._field_start = null
	season.build._copy.start = null
	season.build._abilities.start = null
	season.career.runs[-1].sides_earned = null
	season.career.runs[-1].jump_earned = null
	season.career.runs[-1].batch_used = null
	season.career.runs[-1].sure_earned = null
	season.career.runs[-1].field_outs = null
	season.career.runs[-1].copy_earned = null
	season.career.runs[-1].sky_outs = null
	_completed(season, ["out", "out", "single"])
	_check(SeasonSave.save(season), "prior Freezers build")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 10
	data.career.runs[-1].erase("sides_earned")
	data.career.runs[-1].erase("jump_earned")
	data.career.runs[-1].erase("batch_used")
	data.career.runs[-1].erase("sure_earned")
	data.career.runs[-1].erase("field_outs")
	data.career.runs[-1].erase("copy_earned")
	data.career.runs[-1].erase("sky_outs")
	var restored: SeasonState = SeasonSave._decode(data)
	_check(
		restored != null and restored.build._sides_start == null and restored.build._freezer_earned,
		"migration preserves prior feat and starts sides prospectively"
	)
	_check(
		restored != null and SeasonSave.save(restored) and SeasonSave.restore() != null,
		"second migrated save"
	)


func _sides_ui() -> void:
	var season: SeasonState = _paid_sides(false)
	_check(SeasonSave.save(season), "UI earned stock checkpoint")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "left-right-shop")
	var offer: String = _offer(season.build, "F06")
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
	_check(SeasonSchoolSponsors.active(app.season.build, "F06").paid == 12, "paid twelve")
	window.queue_free()
	await _frames()
	app.menu.show_lineup()
	await _menu_bounds(app, "left-right-lineup")
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "left-right-progress")
	app.play_season_game()
	await _frames(3)
	var lab: PitchBatLab = app.lab
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var state: MatchState = lab._match_state
	state.top_half = not lab._player_home
	state.batter().definition = ContentDB.get_player(&"player.tess_vale").duplicate()
	state.batter().definition.season_sponsors = {"F06": true}
	state.batter().batting_hand_override = 0
	state.sides._previous = {
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"left": not state.batter().bats_left()
	}
	lab._awaiting_batter_confirm = true
	lab._refresh_config()
	await _frames()
	var label: Label = lab.find_child("BattingSides", true, false)
	_check(
		label != null and label.visible and label.text.contains("Alternating"),
		"readiness preview uses actual side"
	)
	if label != null:
		_check(Rect2(0, 0, 1280, 720).encloses(label.get_global_rect()), "readiness bounded")
	var controls: MatchRosterControls = lab.find_child("RosterControls", true, false)
	await _click(controls._switch)
	_check(
		not state.sides.qualifies(state) and label.text.contains("Same side"),
		"legal switch updates preview without starting pitch"
	)
	await _click(controls._switch)
	_check(
		state.sides.qualifies(state) and lab._awaiting_batter_confirm,
		"switch back preserves readiness"
	)
	await _click(app.loadout.entry)
	await _click(app.loadout._tab_buttons[1])
	_check(
		SeasonLoadoutData.pages(app).sponsors[0].label.contains("Alternating"),
		"Equipped current modifier"
	)
	await _click(app.loadout.close_button)
	app.leave_game()
	_check(
		app.season.make_match().sides.rows.is_empty(), "restart discards unfinished stance history"
	)
	app.queue_free()
	await _frames()
