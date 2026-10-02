extends "res://src/tests/season_earned_sponsor_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://insurance-%d.json" % OS.get_process_id()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var season: SeasonState = _insurance_fixture()
	if season != null:
		_claim_contracts(season)
		_runtime_contracts(season)
		_combo_sale_contract()
		_exclusions(season)
		await _insurance_ui(season)
	_migrate_insurance()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Second Chance checks passed: earned access, exact copies, sales, replay and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _supply_fixture(ids: Array[String], club: ClubCareer = null) -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._supply_start = 0 if club == null else club.supply_count()
	probe._visit.number = 3
	for seed_value in range(30000):
		probe._seed = seed_value
		var stock: Array = probe._offers(0).values()
		var found: bool = true
		for id: String in ids:
			found = found and stock.count(id) >= ids.count(id)
		if not found:
			continue
		var season: SeasonState = _new_club(seed_value, club)
		for game in range(3):
			_result(season, [])
		var build: SeasonBuild = season.build
		_check(build.commit(_command(build, "open")).ok, "generated supply shop")
		for id: String in ids:
			found = found and not _offer(build, id).is_empty()
		if not found:
			continue
		for id: String in ids:
			var fields: Dictionary = {"offer": _offer(build, id)}
			if id == "E04":
				fields["replace"] = ""
			_check(
				(
					build
					. commit(
						_command(build, "sponsor_buy" if id == "E04" else "tactical_buy", fields)
					)
					. ok
				),
				"real generated purchase " + id
			)
		print("INSURANCE_FIXTURE seed=", seed_value, " items=", ids)
		return season
	_check(false, "reachable paid supply stock")
	return null


func _supply_result(season: SeasonState, insured: String = "") -> bool:
	var game: Dictionary = season.pending_fixture()
	var rival: int = game.away if game.home == 0 else game.home
	var own: Array = season.teams[0].roster
	var rivals: Array = season.teams[rival].roster
	var stats: MatchPerformance = MatchPerformance.new()
	stats.complete(StringName(own[0]), StringName(rivals[0]), "single", 0)
	stats.complete(StringName(own[0]), StringName(rivals[0]), "single", 0)
	stats.complete(StringName(rivals[0]), StringName(own[0]), "strikeout", 0)
	for id: String in own + rivals:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	stats.players[own[0]].pitches = 1
	var actions: Array = []
	for copy: Dictionary in season.build.view().wallet.held:
		var action: Dictionary = {
			"receipt": copy.id,
			"player": own[0],
			"pa": actions.size() + 1,
			"swing": "swing.contact" if copy.item == "C03" else ""
		}
		if copy.id == insured:
			action["insured"] = true
		actions.append(action)
	return season.record_player_result(
		game.id, 0 if game.home == 0 else 1, 1 if game.home == 0 else 0, stats.players, [], actions
	)


func _insurance_fixture() -> SeasonState:
	var season: SeasonState = _supply_fixture(["A10", "C03"])
	if season == null:
		return null
	_check(_supply_result(season), "two completed paid consumptions")
	_check(
		(
			season.build._supply_used == 2
			and not SeasonEarnedSponsors.eligible(season.build).has("E04")
		),
		"two stays locked"
	)
	_check(SeasonSave.save(season), "save partial progress")
	var saved: SeasonState = SeasonSave.restore()
	_check(saved != null and saved.career.supply_count() == 2, "partial count replays")
	if saved == null:
		return null
	_check(saved.career.close(saved), "abandon retains actual consumption count")
	season = _supply_fixture(["tactical.extra_heat"], saved.career)
	_check(
		season.build._supply_start == 2 and season.build._supply_used == 0,
		"inherited count not use"
	)
	var interrupted: MatchState = season.make_match()
	var team: TeamMatchState = (
		interrupted.home_team if season.pending_fixture().home == 0 else interrupted.away_team
	)
	interrupted.top_half = team == interrupted.home_team
	_check(
		team.tactics.activate(interrupted, team, team.tactics.held[0].id),
		"unfinished real Heat activation"
	)
	_check(season.build._supply_used == 0, "unfinished match cannot earn progress")
	_check(_supply_result(season), "third completed consumption")
	_check(SeasonEarnedSponsors.eligible(season.build).has("E04"), "third unlocks paid access")
	_check(SeasonSave.save(season), "save unlocked count")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var bad: Dictionary = data.duplicate(true)
	bad.career.runs[-1].supplies_used += 1
	_check(SeasonSave._decode(bad) == null, "reject invented current career count")
	bad = data.duplicate(true)
	bad.build.supply_start = 1
	_check(SeasonSave._decode(bad) == null, "reject changed inherited count")
	_check(season.career.close(season), "unlocked count survives abandonment")
	return _supply_fixture(["E04", "C03", "C02"], season.career)


func _mark(build: SeasonBuild, game: int, receipt: String) -> Dictionary:
	return build.commit(_command(build, "insure", {"game": game, "receipt": receipt}))


func _claim_contracts(season: SeasonState) -> void:
	var build: SeasonBuild = season.build._fork()
	var game: int = season.pending_fixture().id
	var receipt: String = build.view().wallet.held[0].id
	var before: Dictionary = build.to_data()
	_check(
		not _mark(build, game, "foreign").ok and build.to_data() == before, "foreign copy atomic"
	)
	_check(_mark(build, game, receipt).ok, "lock exact paid copy")
	_check(not _mark(build, game, "").ok, "cannot change locked choice")
	_check(SeasonSecondChance.target(build, game) == receipt, "runtime receives exact receipt")
	var restored: SeasonBuild = SeasonBuild.from_data(
		build.to_data(), build._seed, build._initial_roster, build._pool, build._blocked
	)
	_check(restored != null and restored._insurance == build._insurance, "choice replays")
	var wrong: Dictionary = {"receipt": build.view().wallet.held[1].id, "insured": true}
	_check(not SeasonSecondChance.valid_claim(build, game, wrong), "other copy cannot claim")
	wrong.receipt = receipt
	wrong.insured = 1
	_check(not SeasonSecondChance.valid_claim(build, game, wrong), "strict claim boolean")
	_check(
		(
			build
			. commit(
				_command(
					build, "sponsor_sell", {"receipt": SeasonSchoolSponsors.active(build, "E04").id}
				)
			)
			. ok
		),
		"sell insurance sponsor normally"
	)
	_check(
		SeasonSecondChance.target(build, game) == "", "sold sponsor cannot insure restarted game"
	)
	var clone: SeasonState = _clone_season(season)
	build = clone.build
	_check(
		_mark(build, game, receipt).ok and _supply_result(clone, receipt), "completed exact claim"
	)
	build = clone.build
	var copy: Dictionary = build.view().wallet.held[0]
	_check(
		copy.item == "C03" and copy.paid == 0 and copy.id != receipt,
		"fresh free copy, no same-game reuse"
	)
	_check(build._insurance[str(game)].outcome == "restored", "restored outcome")
	_check(SeasonSave.save(clone), "save restored copy")
	var loaded: SeasonState = SeasonSave.restore()
	_check(
		loaded != null and loaded.build.view() == build.view(), "result replay restores only once"
	)
	_check(
		SeasonSecondChance.target(build, int(clone.pending_fixture().id)) == "",
		"no inherited next-game mark"
	)
	clone = _clone_season(season)
	_check(_mark(clone.build, game, "").ok and _supply_result(clone), "explicit skip settles")
	_check(
		(
			clone.build.view().wallet.held.is_empty()
			and clone.build._insurance[str(game)].outcome == "skipped"
		),
		"skip restores nothing"
	)
	clone = _clone_season(season)
	_check(_mark(clone.build, game, receipt).ok, "unused selected copy")
	_result(clone, [])
	_check(
		(
			clone.build.view().wallet.held.size() == 2
			and clone.build._insurance[str(game)].outcome == "not_used"
		),
		"unused mark expires"
	)
	# Controlled capacity branch: no overflow queue or destructive displacement.
	build = season.build._fork()
	_mark(build, game, receipt)
	before = build.view().wallet
	_check(
		(
			(
				SeasonSecondChance.settle(
					build, {"game": game, "tactics": [{"receipt": receipt, "insured": true}]}
				)
				== ""
			)
			and build._insurance[str(game)].outcome == "full"
			and build.view().wallet == before
		),
		"full bag forfeits without displacement"
	)


func _clone_season(season: SeasonState) -> SeasonState:
	_check(SeasonSave.save(season), "checkpoint clone")
	var copy: SeasonState = SeasonSave.restore()
	_check(copy != null, "restore clone")
	return copy


func _runtime_contracts(season: SeasonState) -> void:
	for item: String in SeasonSecondChance.ELIGIBLE:
		for active: bool in [false, true]:
			var state: MatchState = season.make_match()
			var team: TeamMatchState = state.home_team
			state.top_half = item in ["C02", "tactical.extra_heat"]
			team.tactics.held = [{"id": "chosen", "item": item, "paid": 4, "kind": "held"}]
			team.tactics.insured_receipt = "chosen"
			for player: PlayerMatchState in team.roster:
				player.definition.season_sponsors = {"E04": true} if active else {}
			state.pitcher().stamina_remaining -= 30
			_check(
				team.tactics.activate(
					state, team, "chosen", &"swing.contact" if item == "C03" else &""
				),
				"actual eligible consumption " + item
			)
			_check(
				team.tactics.consumed[0].get("insured", false) == active,
				"insurance requires active sponsor at use"
			)
			for player: PlayerMatchState in team.roster:
				player.definition.season_sponsors.erase("E04")
			_check(
				team.tactics.consumed[0].get("insured", false) == active,
				"later retirement preserves earned claim"
			)
	var state: MatchState = season.make_match()
	var team: TeamMatchState = state.away_team
	for player: PlayerMatchState in team.roster:
		player.definition.season_sponsors = {"E04": true, "E07": true}
	team.tactics.held = [
		{"id": "tape", "item": "A10", "paid": 3, "kind": "held"},
		{"id": "plan", "item": "C03", "paid": 4, "kind": "held"}
	]
	team.tactics.insured_receipt = "plan"
	_check(
		team.tactics.activate_combo(state, team, ["tape", "plan"], &"swing.contact"),
		"real Double Booking pair"
	)
	_check(
		not team.tactics.consumed[0].has("insured") and team.tactics.consumed[1].insured,
		"only selected paired copy insured"
	)


func _insurance_ui(season: SeasonState) -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _clone_season(season)
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "insurance-pregame")
	var before: Dictionary = app.season.build.to_data()
	await _click(_button(app.menu, "PLAY GAME"))
	_check(
		app.lab == null and app.season.build.to_data() == before,
		"Play requires explicit choice or skip"
	)
	app.menu.show_lineup()
	await _frames()
	var picker: OptionButton = app.menu.find_child("InsuranceCopy", true, false)
	_check(picker != null and picker.item_count == 4, "eligible exact copies and skip visible")
	if picker == null:
		app.queue_free()
		return
	picker.grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(
		app.insurance_receipt == app.season.build.view().wallet.held[0].id,
		"keyboard selects exact first copy"
	)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_button(app.menu, "PLAY GAME"))
	_check(
		app.lab == null and app.season.build.to_data() == before,
		"failed pregame save rolls back selection and grant"
	)
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "failed selection preserves save bytes")
	app.menu.show_lineup()
	await _frames()
	await _click(_button(app.menu, "PLAY GAME"))
	_check(app.lab != null, "selected exact copy launches actual game")
	var game: int = app.season.pending_fixture().id
	var target: String = SeasonSecondChance.target(app.season.build, game)
	_check(target == app.insurance_receipt, "selected mark saved before play")
	app.leave_game()
	await _frames()
	app.season = SeasonSave.restore()
	app.insurance_receipt = ""
	app.menu.show_lineup()
	await _frames()
	_check(
		(
			app.menu.find_child("InsuranceCopy", true, false) == null
			and SeasonSecondChance.target(app.season.build, game) == target
		),
		"restart locks saved exact copy"
	)
	await _menu_bounds(app, "insurance-locked")
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "insurance-earned-progress")
	await _postgame_ui(app, season)
	app.insurance_game = game
	app.insurance_receipt = target
	app.begin_season(9124, true)
	_check(
		(
			app.season.phase == SeasonState.Phase.DRAFT
			and app.insurance_game == -1
			and app.insurance_receipt == ""
		),
		"new season cannot reuse an old draft choice"
	)
	app.queue_free()
	await _frames()


func _migrate_insurance() -> void:
	var season: SeasonState = _new_club(913)
	season.build._format = 25
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
	_check(SeasonSave.save(season), "build25 saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 6
	for historical: Dictionary in data.career.runs:
		historical.erase("collection")
	data.career.runs[-1].erase("supplies_used")
	data.career.runs[-1].erase("checkout_earned")
	data.career.runs[-1].erase("association_earned")
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
		(
			restored != null
			and restored.build._supply_start == null
			and restored.career.supply_count() == 0
		),
		"career6 migration invents no consumption"
	)
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "legacy roundtrip")


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
		await _frames(1)


func _exclusions(season: SeasonState) -> void:
	var game: int = season.pending_fixture().id
	for item: String in [SeasonTacticalCatalog.BASE, DevelopmentShopCatalog.CARDS.keys()[0]]:
		var build: SeasonBuild = season.build._fork()
		# Controlled exact held copy; insurance must reject excluded categories.
		build._bank._state.held = [{"id": "excluded", "item": item, "kind": "held", "paid": 3}]
		var before: Dictionary = build.view()
		_check(
			not _mark(build, game, "excluded").ok and build.view() == before,
			"excluded copy cannot be marked " + item
		)
	var clone: SeasonState = _clone_season(season)
	_check(
		_mark(clone.build, game + 1, clone.build.view().wallet.held[0].id).ok,
		"controlled foreign fixture event"
	)
	_check(not SeasonSave.save(clone), "save rejects mark for another scheduled game")


func _combo_sale_contract() -> void:
	var fixture: Node = preload("res://src/tests/season_tactical_sponsors_test.gd").new()
	var season: SeasonState = fixture._paid_combo()
	_check(fixture._failures == 0 and season != null, "generated paid combo fixture")
	fixture.free()
	if season == null:
		return
	var build: SeasonBuild = season.build
	var game: int = season.pending_fixture().id
	_check(
		build.commit(_command(build, "match_inventory", {"game": game})).ok,
		"combo attempt binds paid sponsors"
	)
	var state: MatchState = season.make_match()
	state.top_half = false
	var team: TeamMatchState = state.home_team
	_check(
		team.tactics.activate_combo(state, team, team.tactics.combo_copies(), &"swing.contact"),
		"paid pair used before sale"
	)
	_check(
		(
			build
			. commit(
				_command(
					build,
					"match_sell",
					{
						"game": game,
						"receipt": SeasonSchoolSponsors.active(build, "E07").id,
						"first_pitch": null
					}
				)
			)
			. ok
		),
		"sell used Double Booking"
	)
	_check(
		SeasonTacticalCombo.valid(build, team.tactics.consumed, game),
		"completed pair retains exact-attempt sponsor proof after sale"
	)
	_check(
		not SeasonTacticalCombo.valid(build, team.tactics.consumed, game + 1),
		"another game cannot borrow sponsor proof"
	)
	_check(SeasonSave.save(season) and SeasonSave.restore() != null, "sold combo attempt replays")
	build = season.build._fork()
	_check(
		build.commit(_command(build, "match_inventory", {"game": game})).ok,
		"restart replaces inventory attempt"
	)
	_check(
		not SeasonTacticalCombo.valid(build, team.tactics.consumed, game),
		"restart cannot resurrect sold sponsor proof"
	)
	var stats: MatchPerformance = MatchPerformance.new()
	stats.complete(team.current_batter().definition.id, state.pitcher().definition.id, "single", 0)
	for side: TeamMatchState in [state.home_team, state.away_team]:
		for player: PlayerMatchState in side.roster:
			var id: String = String(player.definition.id)
			if not stats.players.has(id):
				stats.players[id] = MatchPerformance.empty_line()
	_check(
		season.record_player_result(game, 0, 1, stats.players, [], team.tactics.consumed),
		"completed used pair settles after sponsor sale"
	)
	_check(
		(
			season.build.view().wallet.held.is_empty()
			and SeasonSave.save(season)
			and SeasonSave.restore() != null
		),
		"sold pair result consumes both copies and replays"
	)


func _postgame_ui(app: SeasonApp, season: SeasonState) -> void:
	app.season = _clone_season(season)
	var game: int = app.season.pending_fixture().id
	var receipt: String = app.season.build.view().wallet.held[0].id
	_check(
		_mark(app.season.build, game, receipt).ok and _supply_result(app.season, receipt),
		"postgame restored-copy fixture"
	)
	app.menu.show_postgame("", true)
	await _menu_bounds(app, "insurance-postgame")
	var found: bool = false
	for node in app.menu._body.find_children("*", "Label", true, false):
		found = found or node.text.contains("One fresh copy restored")
	_check(found, "postgame explains exact restoration outcome")
