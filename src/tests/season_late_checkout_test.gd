extends "res://src/tests/season_second_chance_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://checkout-%d.json" % OS.get_process_id()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var club: ClubCareer = _earn_checkout()
	if club != null:
		var season: SeasonState = _paid_checkout(club, false)
		if season != null:
			await _purchase_ui(season)
		_runtime_checkout()
		await _checkout_ui()
	_migrate_checkout()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Late Checkout checks passed: paid access, next-batter effects, replay and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _walk(state: MatchState) -> void:
	for pitch in range(MatchState.BALLS_FOR_WALK):
		state.record_ball()
	if state.phase != MatchState.Phase.GAME_END:
		state.phase = MatchState.Phase.PRE_PITCH


func _earn_checkout() -> ClubCareer:
	var season: SeasonState = _supply_fixture(["A10", "C03"])
	if season == null:
		return null
	_check(not SeasonEarnedSponsors.eligible(season.build).has("G03"), "locked before feat")
	var state: MatchState = season.make_match()
	state.top_half = season.pending_fixture().away == 0
	var team: TeamMatchState = state.batting_team()
	var before: Dictionary = season.build.to_data()
	_check(team.tactics.activate(state, team, team.tactics.held[0].id), "paid Tape consumed")
	_walk(state)
	_check(team.tactics.consumed[0].walked, "real called-walk hook marks original use")
	_check(season.build.to_data() == before, "unfinished walk earns no permanent access")
	_check(team.tactics.checkout.options(state, team).is_empty(), "no free unowned effect")
	var stats: Dictionary = state.performance.snapshot(state)
	var actions: Array = team.tactics.consumed.duplicate(true)
	var bad: Array = actions.duplicate(true)
	bad[0].walked = 1
	var game: Dictionary = season.pending_fixture()
	_check(not season.record_player_result(game.id, 0, 1, stats, [], bad), "strict walk evidence")
	var no_walk: Dictionary = stats.duplicate(true)
	no_walk[actions[0].player].bb = 0
	_check(
		not SeasonLateCheckout.valid_walk(
			season.build, actions[0], season.build.view().wallet.held[0], no_walk
		),
		"requires credited walk for the consuming player"
	)
	_check(
		season.record_player_result(game.id, 0, 1, stats, [], actions), "controlled completed walk"
	)
	_check(season.build._checkout_earned, "completed supplied walk earns access")
	_check(SeasonSave.save(season), "save earned access")
	var loaded: SeasonState = SeasonSave.restore()
	_check(loaded != null and SeasonLateCheckout.access(loaded.career), "unlock replays")
	if loaded == null:
		return null
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var corrupt: Dictionary = data.duplicate(true)
	corrupt.career.runs[-1].checkout_earned = false
	_check(SeasonSave._decode(corrupt) == null, "current run must match journal")
	corrupt = data.duplicate(true)
	corrupt.build.checkout_start = true
	_check(SeasonSave._decode(corrupt) == null, "inherited access must match prior runs")
	_check(loaded.career.close(loaded), "abandon retains earned access")
	return loaded.career


func _paid_checkout(club: ClubCareer, buy: bool = true) -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._checkout_start = true
	probe._visit.number = 3
	for seed_value in range(30000):
		probe._seed = seed_value
		var stock: Array = probe._offers(0).values()
		if not stock.has("G03") or not stock.has("C03"):
			continue
		var season: SeasonState = _new_club(seed_value, club)
		_check(season.build.view().wallet.sponsors.is_empty(), "inherited access grants no copy")
		for game in range(3):
			_result(season, [])
		var build: SeasonBuild = season.build
		_check(build.commit(_command(build, "open")).ok, "generated earned shop")
		if _offer(build, "G03").is_empty() or _offer(build, "C03").is_empty():
			continue
		_check(
			build.commit(_command(build, "tactical_buy", {"offer": _offer(build, "C03")})).ok,
			"paid generated Plan"
		)
		if buy:
			_check(
				(
					build
					. commit(
						_command(
							build, "sponsor_buy", {"offer": _offer(build, "G03"), "replace": ""}
						)
					)
					. ok
				),
				"paid generated Late Checkout"
			)
		print("CHECKOUT_FIXTURE seed=", seed_value, " cash=", build.cash(), " bought=", buy)
		return season
	_check(false, "reachable generated Late Checkout and Plan")
	return null


func _runtime_state(combo: bool = false) -> MatchState:
	# Controlled runtime fixture separates effect boundaries from paid acquisition above.
	var state: MatchState = _new_club(123).make_match()
	var team: TeamMatchState = state.batting_team()
	for player: PlayerMatchState in team.roster:
		player.definition.season_sponsors = {"G03": true, "E07": true, "E04": true}
	team.tactics.track_walks = true
	team.tactics.held = [{"id": "plan", "item": "C03", "kind": "held", "paid": 4}]
	team.tactics.insured_receipt = "plan"
	if combo:
		team.tactics.held.push_front({"id": "tape", "item": "A10", "kind": "held", "paid": 4})
		_check(
			team.tactics.activate_combo(state, team, ["tape", "plan"], &"swing.power"),
			"combo source"
		)
	else:
		_check(team.tactics.activate(state, team, "plan", &"swing.power"), "Plan source")
	return state


func _runtime_checkout() -> void:
	for item: String in ["A10", "C03"]:
		var state: MatchState = _runtime_state(true)
		var team: TeamMatchState = state.batting_team()
		_walk(state)
		var checkout: MatchLateCheckout = team.tactics.checkout
		_check(checkout.options(state, team) == ["A10", "C03"], "two sources offer one choice")
		var consumed: Array = team.tactics.consumed.duplicate(true)
		_check(checkout.accept(state, team, item), "accept exact source")
		_check(team.tactics.active(state) == item, "one inherited effect")
		_check(
			checkout.inherited_receipt == ("plan" if item == "C03" else "tape"),
			"exact source receipt retained"
		)
		_check(
			team.tactics.locked_swing(state) == (&"swing.power" if item == "C03" else &""),
			"exact Plan swing"
		)
		_check(
			team.tactics.consumed == consumed and team.tactics.held.is_empty(),
			"no extra consumption or copy"
		)
		team.tactics.held.append({"id": "extra", "item": "A10", "kind": "held", "paid": 4})
		_check(
			not team.tactics.activate(state, team, "extra"), "inherited PA blocks additional copy"
		)
		_check(not checkout.accept(state, team, item), "cannot accept twice")
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors.erase("G03")
		_check(team.tactics.active(state) == item, "later sale retains accepted current effect")
		_walk(state)
		_check(
			team.tactics.active(state) == "" and checkout.options(state, team).is_empty(),
			"no walk chain"
		)
		_check(team.tactics.consumed == consumed, "inherited walk adds no proof or insurance claim")
	var state: MatchState = _runtime_state()
	var team: TeamMatchState = state.batting_team()
	_walk(state)
	_check(
		team.tactics.checkout.decline(state, team) and not team.tactics.checkout.used,
		"decline preserves use"
	)
	_check(team.tactics.checkout.options(state, team).is_empty(), "decline clears opportunity")
	team.tactics.held.append({"id": "later", "item": "A10", "kind": "held", "paid": 4})
	_check(team.tactics.activate(state, team, "later"), "declined PA may use a real supply")
	_walk(state)
	_check(team.tactics.checkout.accept(state, team, "A10"), "later qualifying walk can transfer")
	for ending: String in ["pitch", "half", "finish", "sale", "hit"]:
		state = _runtime_state()
		team = state.batting_team()
		if ending == "hit":
			state.record_hit(BallPlayOutcome.Result.SINGLE)
			state.phase = MatchState.Phase.PRE_PITCH
		else:
			_walk(state)
		match ending:
			"pitch":
				state.begin_pitch()
				state.cancel_pitch()
			"half":
				state._advance_half_inning()
			"finish":
				state._finish_game("controlled")
			"sale":
				for player: PlayerMatchState in team.roster:
					player.definition.season_sponsors.erase("G03")
		_check(
			team.tactics.checkout.options(state, team).is_empty(), "opportunity expires: " + ending
		)
	state = _runtime_state()
	team = state.batting_team()
	state.top_half = false
	# Rebind source to home for an actual walk-off transition.
	state.home_team.tactics = team.tactics
	state.away_team.tactics = MatchTactics.new()
	team = state.home_team
	for player: PlayerMatchState in team.roster:
		player.definition.season_sponsors = {"G03": true}
	state.inning = 6
	state.bases.first = &"one"
	state.bases.second = &"two"
	state.bases.third = &"three"
	_walk(state)
	_check(
		state.phase == MatchState.Phase.GAME_END and team.tactics.checkout._pending.is_empty(),
		"walk-off has no next batter"
	)


func _purchase_ui(season: SeasonState) -> void:
	_check(SeasonSave.save(season), "save generated shop")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var offer: String = _offer(season.build, "G03")
	var before: Dictionary = season.build.to_data()
	var cash_before: int = season.cash()
	await _click(_sponsor_button(window, offer))
	await _shop_bounds(window, "checkout-purchase")
	await _click(window._confirm.get_cancel_button())
	_check(season.build.to_data() == before, "purchase cancel")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
		"failed save atomic"
	)
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	_check(
		(
			season.cash() == cash_before - 12
			and SeasonSchoolSponsors.active(season.build, "G03").paid == 12
		),
		"exact paid receipt"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == season.build.view(), "paid ownership replays"
	)
	window.queue_free()
	await _frames()
	app.menu.show_lineup()
	await _click(_button(app.menu, "PLAY GAME"))
	_check(app.lab != null, "paid match launches")
	if app.lab != null:
		var state: MatchState = app.lab._match_state
		var own: TeamMatchState = state.home_team if app.lab._player_home else state.away_team
		_check(own.roster[0].definition.season_sponsors.get("G03", false), "runtime paid effect")
		app.leave_game()
		await _frames()
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "checkout-access")
	app.queue_free()
	await _frames()


func _checkout_ui() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _runtime_state(true)
	lab._player_home = false
	add_child(lab)
	await _frames(4)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.away_team
	_walk(state)
	lab._awaiting_batter_confirm = true
	lab._ai_pitch_preselected = false
	var ui: MatchTacticalControls = lab.get_node("TacticalControls")
	await _frames()
	_check(ui._entry.visible and not ui._entry.disabled, "zero held copies still expose transfer")
	await _click(ui._entry)
	_checkout_button(ui, "C03").grab_focus()
	await _key(KEY_ENTER)
	_check(
		ui._detail.text.contains("power") and ui._detail.text.contains("No copy"),
		"exact inherited review"
	)

	_check(
		Rect2(Vector2.ZERO, Vector2(ui._dialog.size)).encloses(ui._scroll.get_rect()),
		"transfer review stays within dialog"
	)
	for node: Node in ui._choices.get_children():
		if node is Button:
			_check(node.size.y >= 44, "transfer choices retain usable targets")
	await _click(ui._dialog.get_cancel_button())
	_check(
		not team.tactics.checkout.used and team.tactics.checkout.options(state, team).size() == 2,
		"review cancel preserves choice"
	)
	await _click(ui._entry)
	await _click(_checkout_button(ui, "C03"))
	await _click(ui._dialog.get_ok_button())
	_check(
		team.tactics.checkout.used and team.tactics.locked_swing(state) == &"swing.power",
		"actual input accepts one effect"
	)
	_check(
		team.tactics.consumed.size() == 2 and team.tactics.held.is_empty(),
		"UI never grants or consumes extra copy"
	)
	_check(ui._entry.text.contains("POWER"), "HUD shows inherited swing")
	lab.queue_free()
	await _frames()


func _checkout_button(ui: MatchTacticalControls, item: String) -> Button:
	for node: Node in ui._choices.get_children():
		if node is Button and node.get_meta("checkout", "") == item:
			return node
	return null


func _migrate_checkout() -> void:
	var season: SeasonState = _new_club(543)
	season.build._format = 26
	season.build._checkout_start = null
	season.career.runs[-1].checkout_earned = null
	_check(SeasonSave.save(season), "prior build26 saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 7
	data.career.runs[-1].erase("checkout_earned")
	var loaded: SeasonState = SeasonSave._decode(data)
	_check(
		loaded != null and loaded.build._checkout_start == null,
		"old active tracking stays prospective"
	)
	_check(
		loaded != null and SeasonSave.save(loaded) and SeasonSave.restore() != null,
		"legacy roundtrip"
	)
