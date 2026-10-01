extends "res://src/tests/season_association_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://carbon-copy-%d.json" % OS.get_process_id()
	_copy_contract()
	_copy_deli()
	var season: SeasonState = _paid_copy()
	if season != null:
		await _copy_purchase_ui()
		_copy_persistence(season)
		await _copy_ui(season)
	_copy_migration()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Carbon Copy checks passed: exact source, single events, income, replay and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _copy_unit() -> SeasonBuild:
	var build: SeasonBuild = _unit_association()
	build._copy.start = false
	_reject_build(build, _unit_buy(build, "E09"), "Copy remains locked before feat")
	for id: String in ["D01", "A07", "F02", "F03"]:
		var request: Dictionary = _unit_buy(build, id)
		var earned: bool = build._copy.earned
		_check(build.preview(request).ok and build._copy.earned == earned, "preview no unlock")
		var offers: Dictionary = build._visit.offers.duplicate()
		_check(build.commit(request).ok, "four paid distinct sponsors")
		_check(
			build._copy.earned == (SeasonCarbonCopy.count(build) >= 4),
			"three distinct sponsors insufficient"
		)
		offers.erase(request.offer)
		_check(build._visit.offers == offers, "unlock preserves existing stock")
	_check(build._copy.earned, "four simultaneous active identities earn access")
	_check(build.commit(_unit_buy(build, "E09")).ok, "paid twenty Cash Copy")
	return build


func _select_copy(build: SeasonBuild, item: String, game: int = 6) -> Dictionary:
	return _command(build, "copy_select", {"game": game, "receipt": _active_id(build, item)})


func _copy_contract() -> void:
	var build: SeasonBuild = _copy_unit()
	_reject_build(build, _select_copy(build, "F02"), "incompatible fielding source")
	_reject_build(build, _select_copy(build, "E09"), "no recursive copies")
	_reject_build(build, _select_copy(build, ""), "cannot skip compatible source")
	_check(build.commit(_select_copy(build, "D01")).ok, "choose exact walk source")
	_check(SeasonCarbonCopy.target(build, 6) == "D01", "walk target locked")
	_reject_build(build, _select_copy(build, "A07"), "no retargeting")
	var fork: SeasonBuild = build._fork()
	fork._copy.selections["6"].item = "A07"
	_check(build._copy.selections["6"].item == "D01", "fork has independent marks")
	var stats: Dictionary = _sample(ROSTER, ["a", "b", "c", "d"])
	var before: int = build.cash()
	var request: Dictionary = _command(
		build, "reward", {"game": 6, "win": true, "performance": stats}
	)
	_check(build.commit(request).ok, "completed three actual credited walks")
	_check(build.income_for_game(6) == {"D01": 4, "E09": 4}, "first two walks pay eight combined")
	_check(build.cash() == before + 18 + 8, "ordinary reward and two bounded contributions")
	_check(build.commit(request).replayed and build.cash() == before + 26, "settlement retry once")
	_check(stats[ROSTER[0]].bb == 3, "copy never re-emits walk")
	for sold: String in ["D01", "E09"]:
		build = _copy_unit()
		_check(build.commit(_select_copy(build, "D01")).ok, "lock sale fixture")
		_check(
			build.commit(_command(build, "sponsor_sell", {"receipt": _active_id(build, sold)})).ok,
			"sell exact pair member"
		)
		_check(SeasonCarbonCopy.target(build, 6) == "", "sold pair inactive")
		_check(build.commit(_unit_buy(build, sold)).ok, "purchase fresh identity")
		_check(SeasonCarbonCopy.target(build, 6) == "", "replacement never inherits locked source")
		_check(
			(
				build
				. commit(_command(build, "reward", {"game": 6, "win": true, "performance": stats}))
				. ok
			),
			"settle replaced pair"
		)
		_check(not build.income_for_game(6).has("E09"), "no copied cash after sale and rebuy")
	build = _copy_unit()
	for pair: Array in [["F02", "A08"], ["F03", "A09"]]:
		_check(
			build.commit(_unit_buy(build, pair[1], _active_id(build, pair[0]))).ok,
			"all ordinary income sponsors"
		)
	_check(build.commit(_select_copy(build, "D01")).ok, "select cash ceiling fixture")
	_check(
		build.commit(_command(build, "reward", {"game": 6, "win": true, "performance": stats})).ok,
		"combined 25 income settles without relaxing old event ceiling"
	)
	_check(
		build.income_for_game(6) == {"D01": 4, "A08": 8, "A09": 9, "E09": 4},
		"copy cannot retrigger other income sponsors"
	)
	build = _copy_unit()
	for id: String in ["D01", "A07"]:
		_check(
			build.commit(_command(build, "sponsor_sell", {"receipt": _active_id(build, id)})).ok,
			"remove sources"
		)
	_check(build.commit(_select_copy(build, "")).ok, "source-less copy legally inert")
	_check(SeasonCarbonCopy.target(build, 6) == "", "no invented source")


func _copy_deli() -> void:
	var state: MatchState = _fixture()
	for team: TeamMatchState in [state.home_team, state.away_team]:
		team.copy_source = "A07"
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors = {"A07": true, "E09": true, "E05": 2}
	_check(SeasonCarbonCopy.deli_bonus(state) == 0.0, "no first-batter free effect")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	state.continue_after_dead_ball()
	var before: Dictionary = state.performance.snapshot(state)
	var contact_fixture: Node = GearChecks.new()
	for bat: String in ["", "BAT-CON-01", "BAT-POW-01", "A02"]:
		for misc: String in ["", "MISC-BAT-01"]:
			state.batter().definition = SeasonGearCatalog.equip(
				state.batter().definition, {"bat": {"item": bat}, "misc": {"item": misc}}
			)
			for id: StringName in [&"swing.contact", &"swing.power"]:
				var source: SwingProfileDefinition = ContentDB.get_swing(id)
				var base: SwingProfileDefinition = SeasonGearCatalog.swing(
					source, state.batter().definition
				)
				var copied: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
				var extra: float = (
					(0.0816 + 0.02) * (0.96 if misc != "" else 1.0)
					if id == &"swing.contact"
					else 0.0
				)
				_check(
					is_equal_approx(copied.gear_fair_exit_scale, base.gear_fair_exit_scale + extra),
					"only Deli pair compounds; Legends and Gear unchanged"
				)
				for left: bool in [true, false]:
					for error: float in [0.0, 0.4, 0.95]:
						var a: ContactResult = contact_fixture._contact(base, left, error)
						var b: ContactResult = contact_fixture._contact(copied, left, error)
						var ratio: float = (
							1.0
							if a.outcome == ContactResult.Outcome.FOUL
							else copied.gear_fair_exit_scale / base.gear_fair_exit_scale
						)
						_check(
							is_equal_approx(
								b.exit_velocity.length() / a.exit_velocity.length(), ratio
							),
							"paired bonus only changes fair exit speed"
						)
						_check(
							(
								a.quality == b.quality
								and a.launch_angle_degrees == b.launch_angle_degrees
							),
							"no quality or trajectory rescue"
						)
	contact_fixture.free()
	_check(state.performance.snapshot(state) == before, "no duplicate single or PA")
	state.record_foul()
	state.continue_after_dead_ball()
	_check(is_equal_approx(SeasonCarbonCopy.deli_bonus(state), 0.0816), "foul retains same chain")
	state.batter().definition.season_sponsors.erase("E09")
	_check(
		is_equal_approx(SeasonCarbonCopy.deli_bonus(state), 0.04),
		"Copy retirement leaves ordinary Deli"
	)
	state.batter().definition.season_sponsors["E09"] = true
	state.batter().definition.season_sponsors.erase("A07")
	_check(SeasonCarbonCopy.deli_bonus(state) == 0.0, "source retirement removes both")
	state.record_hit(BallPlayOutcome.Result.DOUBLE)
	state.continue_after_dead_ball()
	_check(SeasonCarbonCopy.deli_bonus(state) == 0.0, "double does not refresh chain")


func _paid_copy() -> SeasonState:
	# Discover actual generated stock; never inject offers in persisted fixtures.
	for seed_value in [12]:
		var season: SeasonState = _new_club(seed_value)
		for game in range(11):
			_result(season, [])
			var build: SeasonBuild = season.build
			_check(build.commit(_command(build, "open")).ok, "open real Copy search shop")
			for roll in range(2):
				for offer: String in build._visit.offers.keys():
					var id: String = build._visit.offers[offer]
					var item: Dictionary = SeasonSponsorCatalog.item(id)
					if item.is_empty() or id in ["J08", "J10", "J05"]:
						continue
					if id not in ["A07", "D01", "E09"] and (item.price > 10 or build._copy.earned):
						continue
					var replace: String = ""
					if build.view().wallet.sponsors.size() == 5:
						for owned: Dictionary in build.view().wallet.sponsors:
							if owned.item not in ["A07", "D01", "E09"]:
								replace = owned.id
					var request: Dictionary = _command(
						build, "sponsor_buy", {"offer": offer, "replace": replace}
					)
					if build.preview(request).ok:
						if id == "E09":
							_check(SeasonSave.save(season), "capture real earned Copy offer")
							_purchase_fixture = SeasonSave.restore()
							_association_offer = offer
						_check(build.commit(request).ok, "purchase actual stock " + id)
				if (
					not _active_id(build, "E09").is_empty()
					and not _active_id(build, "A07").is_empty()
					and not _active_id(build, "D01").is_empty()
				):
					print("CARBON_COPY_FIXTURE seed=", seed_value, " games=", game + 1)
					return season
				if roll == 0 and build.cash() >= 30:
					_check(build.commit(_command(build, "reroll")).ok, "paid stock refresh")
				else:
					break
	_check(false, "reachable earned paid Copy with both sources")
	return null


func _copy_persistence(season: SeasonState) -> void:
	_check(SeasonSave.save(season), "real paid Copy save")
	var loaded: SeasonState = SeasonSave.restore()
	_check(
		loaded != null and ClubCareer.same(loaded.build.to_data(), season.build.to_data()),
		"paid journal rebuild"
	)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var bad: Dictionary = data.duplicate(true)
	bad.career.runs[-1].copy_earned = false
	_check(SeasonSave._decode(bad) == null, "forged career rejected")
	bad = data.duplicate(true)
	bad.build.copy_start = true
	_check(SeasonSave._decode(bad) == null, "forged inherited access rejected")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "abandon preserves paid eligibility")
	var next: SeasonState = _new_club(61, club)
	_check(
		next.build._copy.start == true and next.build.view().wallet.sponsors.is_empty(),
		"future season inherits access without ownership"
	)


func _copy_ui(season: SeasonState) -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "carbon-copy-pregame")
	var picker: OptionButton = app.menu.find_child("CarbonCopySource", true, false)
	_check(
		picker != null and picker.item_count == 3 and picker.size.y >= 44,
		"two legal source choices with accessible target"
	)
	_check(not SeasonPregameCommit.save(app), "explicit source required")
	if picker == null:
		app.queue_free()
		return
	var index: int = 1
	while picker.get_item_metadata(index) != _active_id(season.build, "A07"):
		index += 1
	picker.grab_focus()
	await _copy_key(KEY_ENTER)
	await _copy_key(KEY_ESCAPE)
	_check(app.copy_receipt == "?", "cancel source picker makes no draft selection")
	picker.grab_focus()
	await _copy_key(KEY_ENTER)
	for step in range(index):
		await _copy_key(KEY_DOWN)
	await _copy_key(KEY_ENTER)
	_check(app.copy_receipt == _active_id(season.build, "A07"), "keyboard selects exact source")
	var path: String = SeasonSave.path
	var before: Dictionary = season.build.to_data()
	SeasonSave.path = path + "/missing/save.json"
	_check(not SeasonPregameCommit.save(app), "selection write failure")
	SeasonSave.path = path
	_check(
		season.build.to_data() == before and season.build._copy.selections.is_empty(),
		"failed save rolls back selection and pregame"
	)
	_check(SeasonPregameCommit.save(app), "save exact source")
	var restored: SeasonState = SeasonSave.restore()
	var game: int = season.pending_fixture().id
	_check(
		restored != null and SeasonCarbonCopy.target(restored.build, game) == "A07",
		"source survives restart"
	)
	app.copy_receipt = _active_id(season.build, "D01")
	_check(
		SeasonPregameCommit.save(app) and SeasonCarbonCopy.target(season.build, game) == "A07",
		"restart cannot switch source"
	)
	app.play_season_game()
	await _frames()
	_check(app.lab != null, "paid selected game launches")
	if app.lab != null:
		PitchBatLabFeelSupport.skip_match_presentation(app.lab)
		app.lab._debug_paused = true
		await _click(app.loadout.entry)
		await _click(app.loadout._tab_buttons[1])
		_check(
			_labels(app.loadout.body).contains("Copying Neighborhood Deli"),
			"central Equipped explains selected source"
		)
		app.loadout.close()
		app.leave_game()
	app.queue_free()
	await _frames()


func _copy_migration() -> void:
	var season: SeasonState = _new_club(191)
	season.build._format = 34
	season.build._copy.start = null
	season.career.runs[-1].copy_earned = null
	_check(SeasonSave.save(season), "previous Build34 saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 15
	data.career.runs[-1].erase("copy_earned")
	var loaded: SeasonState = SeasonSave._decode(data)
	_check(loaded != null and loaded.build._copy.start == null, "older runs remain prospective")
	_check(
		loaded != null and SeasonSave.save(loaded) and SeasonSave.restore() != null,
		"old receipt generation roundtrip"
	)


func _copy_purchase_ui() -> void:
	_check(_purchase_fixture != null, "real generated E09 offer captured")
	if _purchase_fixture == null:
		return
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _purchase_fixture
	_check(SeasonSave.save(app.season), "pre-purchase checkpoint")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var before: Dictionary = app.season.build.to_data()
	var cash: int = app.season.cash()
	await _click(_sponsor_button(window, _association_offer))
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "Copy purchase cancel")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_sponsor_button(window, _association_offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
		"Copy purchase write failure rollback"
	)
	await _click(_sponsor_button(window, _association_offer))
	await _shop_bounds(window, "carbon-copy-purchase")
	await _click(window._confirm.get_ok_button())
	_check(
		(
			SeasonSchoolSponsors.active(app.season.build, "E09").paid == 20
			and app.season.cash() == cash - 20
		),
		"actual Copy purchase UI pays twenty"
	)
	_check(SeasonSave.restore() != null, "purchase reload")
	window.queue_free()
	await _frames()
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "carbon-copy-progress")
	app.queue_free()
	await _frames()


func _copy_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = code
		key.pressed = pressed
		get_viewport().push_input(key)
		await _frames(1)
