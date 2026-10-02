extends "res://src/tests/season_sponsor_test.gd"

const GearChecks = preload("res://src/tests/season_gear_test.gd")


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://earned-sponsor-%d.json" % OS.get_process_id()
	_progress_contracts()
	_legends_contracts()
	_encore_contracts()
	await _earned_ui()
	await _encore_ui()
	_migrate_earned()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro earned sponsor checks passed: persistent access, paid copies, stamps, return and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _new_club(seed_value: int, club: ClubCareer = null) -> SeasonState:
	var season: SeasonState = SeasonState.create(seed_value, false, true, true)
	season.career = ClubCareer.new() if club == null else club.fork()
	_check(season.career.start(season), "new prospective sponsor run")
	for pick in range(4):
		season.choose_player(season.offers()[0])
	return season


func _result(season: SeasonState, hits: Array[String], pitchers: int = 0, win: bool = true) -> void:
	var game: Dictionary = season.pending_fixture()
	var rival: int = game.away if game.home == 0 else game.home
	var own: Array = season.teams[0].roster
	var rivals: Array = season.teams[rival].roster
	var stats: MatchPerformance = MatchPerformance.new()
	for hit: String in hits:
		stats.complete(StringName(own[0]), StringName(rivals[0]), hit, 0)
	for index in range(pitchers):
		stats.complete(StringName(rivals[0]), StringName(own[index]), "strikeout", 0)
	for id: String in own + rivals:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	var home_wins: bool = (game.home == 0) == win
	_check(
		season.record_player_result(
			game.id, 0 if home_wins else 1, 1 if home_wins else 0, stats.players
		),
		"controlled completed evidence"
	)


func _paid(ids: Array[String], buy: bool = true) -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._sponsor_progress.enabled = true
	probe._sponsor_progress.start = {"hits": ["double", "hr", "single", "triple"], "encore": true}
	probe._visit.number = 3
	for seed_value in range(30000):
		probe._seed = seed_value
		var stock: Array = probe._offers(0).values()
		var matches: bool = true
		for id: String in ids:
			matches = matches and stock.has(id)
		if not matches:
			continue
		var season: SeasonState = _new_club(seed_value)
		_result(season, ["single", "double", "triple", "hr"], 2)
		_result(season, [], 0)
		_result(season, [], 0)
		_check(season.build.commit(_command(season.build, "open")).ok, "open earned stock")
		for id: String in ids:
			matches = matches and not _offer(season.build, id).is_empty()
		if not matches:
			continue
		if buy:
			for id: String in ids:
				_check(
					(
						season
						. build
						. commit(
							_command(
								season.build,
								"sponsor_buy",
								{"offer": _offer(season.build, id), "replace": ""}
							)
						)
						. ok
					),
					"buy exact earned stock"
				)
		print("EARNED_SPONSOR_FIXTURE seed=", seed_value, " items=", ids)
		return season
	_check(false, "reachable actual earned sponsor offers")
	return null


func _progress_contracts() -> void:
	var season: SeasonState = _new_club(51)
	_check(season.build._sponsor_progress.eligible().is_empty(), "no starting earned access")
	_result(season, ["single", "single", "double"], 2, false)
	_check(
		season.build._sponsor_progress.eligible().is_empty(), "two types and loss do not qualify"
	)
	_check(SeasonSave.save(season), "save partial career types")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "abandon retains committed types")
	season = _new_club(51, club)
	_result(season, ["hr"], 1)
	_check(
		season.build._sponsor_progress.eligible() == ["E05"],
		"third career type earns Local Legends"
	)
	_check(
		season.build.commit(_command(season.build, "open")).ok,
		"displayed stock exists before next feat"
	)
	var stock: Dictionary = season.build.view().shop.offers
	var state: Dictionary = season.career.to_data()
	_check(SeasonSave.save(season), "checkpoint unlocked access")
	_check(season.build.view().shop.offers == stock, "saving eligibility never rerolls stock")
	_result(season, [], 2)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	state = season.career.to_data()
	SeasonSave.path = path + "/missing/file.json"
	_check(
		not SeasonSave.save(season) and ClubCareer.same(state, season.career.to_data()),
		"failed result cannot publish unlock"
	)
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "failed unlock preserves bytes")
	_check(
		(
			SeasonSave.save(season)
			and SeasonSave.restore().build._sponsor_progress.eligible() == ["E05", "G05"]
		),
		"winning multi-pitcher result earns Encore once"
	)
	_check(SeasonSave.save(season), "repeat save remains idempotent")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for field: String in ["start", "hits", "win", "game", "missing", "type", "version"]:
		var bad: Dictionary = data.duplicate(true)
		match field:
			"start":
				bad.build.sponsor_start.encore = true
			"hits":
				bad.career.runs[-1].sponsors[0].hits = ["triple"]
			"win":
				bad.career.runs[-1].sponsors[-1].win = false
			"game":
				bad.career.runs[-1].sponsors[-1].game = 31
			"missing":
				bad.career.runs[-1].sponsors.clear()
			"type":
				bad.career.runs[-1].sponsors[-1].multi_k = 1
			"version":
				bad.career.version += 1
		_check(SeasonSave._decode(bad) == null, "reject mismatched sponsor " + field)
	club = season.career.fork()
	_check(club.close(season), "earned access retained on later abandonment")
	var fresh: SeasonState = _new_club(51, club)
	_check(
		(
			fresh.build._sponsor_progress.eligible() == ["E05", "G05"]
			and fresh.cash() == 0
			and fresh.build.view().wallet.sponsors.is_empty()
		),
		"next season inherits access but no copies or power"
	)


func _legends_contracts() -> void:
	var season: SeasonState = _paid(["E05"])
	if season == null:
		return
	var receipt: Dictionary = SeasonSchoolSponsors.active(season.build, "E05")
	_check(
		season.build.definition(season.picks[0]).season_sponsors.E05 == 0,
		"purchase has no retroactive stamps"
	)
	var snapshot: MatchState = season.make_match()
	_result(season, ["single", "double", "single"])
	_check(
		season.build._legends[receipt.id] == ["double", "single"],
		"first completed purchased game stamps distinct results once"
	)
	_check(
		snapshot.home_team.roster[0].definition.season_sponsors.E05 == 0,
		"existing match snapshot never receives midgame growth"
	)
	_check(SeasonSave.save(season), "stamps save with completed result")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build._legends == season.build._legends,
		"exact copy stamps replay"
	)
	_result(season, ["triple", "hr", "single"])
	_check(season.build._legends[receipt.id].size() == 4, "four-stamp cap")
	var state: MatchState = season.make_match()
	# Compare both swing types through the real resolver with unchanged quality/radii.
	state.top_half = season.pending_fixture().away == 0
	var gear: Node = GearChecks.new()
	for swing: StringName in [&"swing.contact", &"swing.power"]:
		var source: SwingProfileDefinition = ContentDB.get_swing(swing)
		var modified: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
		for left: bool in [false, true]:
			var normal: ContactResult = gear._contact(source, left, 0.4)
			var changed: ContactResult = gear._contact(modified, left, 0.4)
			_check(
				is_equal_approx(normal.quality, changed.quality),
				"Legends never grants contact quality"
			)
			_check(
				is_equal_approx(
					changed.exit_velocity.length() / normal.exit_velocity.length(),
					1.04 if swing == &"swing.contact" else 1.0
				),
				"Working four-stamp Contact-only bonus"
			)
	gear.free()
	state.batter().definition = SeasonGearCatalog.equip(
		state.batter().definition, {"bat": {"item": "BAT-POW-01"}, "misc": {"item": "MISC-BAT-01"}}
	)
	state.batter().definition.season_sponsors.A07 = true
	state._deli_next_batter = true
	_check(
		is_equal_approx(
			(
				SeasonSponsorEffects
				. swing(ContentDB.get_swing(&"swing.contact"), state)
				. gear_fair_exit_scale
			),
			1.13 * 0.96
		),
		"Legends adds once with Deli/Bat; Gloves multiply once"
	)
	_check(season.build.commit(_command(season.build, "open")).ok, "legal sale window")
	_check(
		season.build.commit(_command(season.build, "sponsor_sell", {"receipt": receipt.id})).ok,
		"sell stamped instance"
	)
	_check(
		season.build._legends.is_empty() and season.build._sponsor_progress.eligible().has("E05"),
		"sale removes power but preserves access"
	)
	for attempt in range(7):
		if not _offer(season.build, "E05").is_empty():
			break
		if not season.build.commit(_command(season.build, "reroll")).ok:
			break
	if not _offer(season.build, "E05").is_empty():
		_check(
			(
				season
				. build
				. commit(
					_command(
						season.build,
						"sponsor_buy",
						{"offer": _offer(season.build, "E05"), "replace": ""}
					)
				)
				. ok
			),
			"buy a fresh copy"
		)
		_check(
			season.build.definition(season.picks[0]).season_sponsors.E05 == 0,
			"repurchase starts unstamped"
		)
	_check(
		SeasonSave.save(season) and SeasonSave.restore() != null,
		"sale and growth journal remains valid"
	)


func _encore_contracts() -> void:
	var state: MatchState = _fixture()
	var team: TeamMatchState = state.defensive_team()
	var first: PlayerMatchState = team.current_pitcher()
	first.spend_stamina(37)
	first.first_batter_completed = true
	team.tactics._recovered.append(String(first.definition.id))
	team.strikecraft_uses = 2
	_check(team.select_pitcher(2), "normal first removal")
	team.current_pitcher().spend_stamina(12)
	_check(not SeasonEncore.return_pitcher(state, 0), "no sponsor means no return")
	for player: PlayerMatchState in team.roster:
		player.definition.season_sponsors.G05 = true
	state.between_batters = false
	_check(
		not SeasonEncore.return_pitcher(state, 0) and not team.encore_used,
		"mid-PA cannot spend token"
	)
	state.between_batters = true
	var stamina: float = first.stamina_remaining
	_check(SeasonEncore.return_pitcher(state, 0), "legal paid-sponsor exception")
	_check(
		(
			team.current_pitcher() == first
			and first.stamina_remaining == stamina
			and first.pitch_count == 1
			and first.first_batter_completed
		),
		"return retains exact player workload and Kit boundary"
	)
	_check(
		team.tactics._recovered.has(String(first.definition.id)) and team.strikecraft_uses == 2,
		"Recovery and Strikecraft allowances never reset"
	)
	_check(team.fielder_index != team.pitcher_index, "ordinary defense assignment remains legal")
	_check(
		not SeasonEncore.return_pitcher(state, 2) and not team.select_pitcher(2),
		"second return remains forbidden"
	)
	_check(
		team.select_pitcher(3) and not SeasonEncore.return_pitcher(state, 0),
		"returned pitcher cannot return again after later removal"
	)


func _earned_ui() -> void:
	var season: SeasonState = _paid(["E05", "G05"], false)
	if season == null:
		return
	_check(SeasonSave.save(season), "earned UI starts from saved actual stock")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.menu.show_home()
	await _click(_button(app.menu, "CLUB RECORD"))
	await _click(_button(app.menu, "EARNED SPONSORS"))
	await _menu_bounds(app, "earned-sponsors-progress")
	await _click(_button(app.menu, "BACK TO CLUB RECORD"))
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "earned-sponsors-shop")
	var offer: String = _offer(app.season.build, "E05")
	var before: Dictionary = app.season.build.to_data()
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "cancel preserves earned offer and wallet")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
		"failed purchase rolls back access and ownership atomically"
	)
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	_check(
		app.season.cash() == 42 and SeasonSchoolSponsors.active(app.season.build, "E05").paid == 12,
		"real confirmed earned purchase pays full quote"
	)
	await _shop_bounds(window, "earned-sponsor-stamps")
	app.queue_free()
	await _frames()


func _encore_ui() -> void:
	var season: SeasonState = _paid(["G05"])
	if season == null:
		return
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = season.make_match()
	lab._player_home = true
	add_child(lab)
	await _frames(3)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var state: MatchState = lab._match_state
	state.top_half = true
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	var team: TeamMatchState = state.home_team
	var index: int = team.pitcher_index
	var first: PlayerMatchState = team.current_pitcher()
	first.spend_stamina(30)
	_check(team.select_pitcher((index + 1) % 4), "UI bullpen fixture has removed pitcher")
	team.current_pitcher().spend_stamina(10)
	lab._pitching_staff_active = true
	lab._apply_defensive_assignment()
	lab._refresh_config()
	await _frames()
	await _click(lab._pitcher_buttons[index])
	var dialog: ConfirmationDialog = lab.get_meta("encore_review", null)
	_check(
		dialog != null and lab._debug_paused, "actual bullpen click opens exclusive return review"
	)
	if dialog != null:
		_check(
			dialog.gui_get_focus_owner() == dialog.get_cancel_button(),
			"return starts focused on cancel"
		)
		await _click(dialog.get_cancel_button())
		_check(
			not team.encore_used and first.pitching_finished and not lab._debug_paused,
			"cancel leaves return and workload intact"
		)
		lab._refresh_config()
		await _click(lab._pitcher_buttons[index])
		dialog = lab.get_meta("encore_review", null)
		if dialog != null:
			await _capture(dialog, "encore-confirm")
			await _click(dialog.get_ok_button())
			_check(
				(
					team.encore_used
					and team.current_pitcher() == first
					and first.stamina_remaining == first.stamina_max - 30
				),
				"confirmation returns exact spent pitcher"
			)
	lab.queue_free()
	await _frames()


func _migrate_earned() -> void:
	var season: SeasonState = _new_club(51)
	season.build._format = 20
	season.build._order_start = null
	season.build._rain_start = null
	season.build._transfer_start = null
	season.build._supply_start = null
	season.build._checkout_start = null
	season.build._association_start = null
	season.build._freezer_start = null
	season.build._sides_start = null
	season.build._jump_start = null
	season.build._batch_start = null
	season.build._sure_start = null
	season.build._field_start = null
	season.build._copy.start = null
	season.build._abilities.start = null
	season.build._major.start = null
	season.career.runs[-1].order_rerolls = null
	season.career.runs[-1].rain_earned = null
	season.career.runs[-1].transfer_earned = null
	season.career.runs[-1].supplies_used = null
	season.career.runs[-1].checkout_earned = null
	season.career.runs[-1].association_earned = null
	season.career.runs[-1].freezer_earned = null
	season.career.runs[-1].sides_earned = null
	season.career.runs[-1].jump_earned = null
	season.career.runs[-1].batch_used = null
	season.career.runs[-1].sure_earned = null
	season.career.runs[-1].field_outs = null
	season.career.runs[-1].copy_earned = null
	season.career.runs[-1].sky_outs = null
	season.career.runs[-1].major_earned = null
	season.build._sponsor_progress = SeasonSponsorProgress.new()
	season.career.runs[-1].sponsors = null
	_result(season, ["single", "double", "triple"], 2)
	_check(SeasonSave.save(season), "old build with prior feat saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 2
	for historical: Dictionary in data.career.runs:
		historical.erase("collection")
	for run: Dictionary in data.career.runs:
		run.erase("sponsors")
		run.erase("order_rerolls")
		run.erase("rain_earned")
		run.erase("transfer_earned")
		run.erase("supplies_used")
		run.erase("checkout_earned")
		run.erase("association_earned")
		run.erase("freezer_earned")
		run.erase("sides_earned")
		run.erase("jump_earned")
		run.erase("batch_used")
		run.erase("sure_earned")
		run.erase("field_outs")
		run.erase("copy_earned")
		run.erase("sky_outs")
		run.erase("major_earned")
	var old: SeasonState = SeasonSave._decode(data)
	_check(old != null, "career2 restores")
	if old != null:
		_check(
			old.build._sponsor_progress.eligible().is_empty() and old.build._gear_progress.enabled,
			"old active run keeps Gear and invents no sponsor feats"
		)
		_check(SeasonSave.save(old) and SeasonSave.restore() != null, "upgraded old career replays")
