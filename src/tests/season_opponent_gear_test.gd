extends "res://src/tests/season_physical_round_test.gd"
## Synthetic W/L policy fixtures; four actual offscreen matches in saved rounds.

var _gear_count: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_unit_contracts()
	await _saved_rounds()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Gear checks passed: "
			+ "paid stock, policy, four physical games and replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var roster: Array[String] = ["player.frankie_bell", "player.jo_lane",
		"player.jordan_lake", "player.rowan_chase"]
	var build: SeasonBuild = SeasonBuild.new(seed_value, roster)
	build._market = 2
	_check(build.commit(SeasonOpponentPolicy.command(
		build, "reward", {"game": 0, "win": true, "performance": {}})).ok, "synthetic paid win fixture")
	return build


func _unit_contracts() -> void:
	var discovered: Dictionary = {}
	var bought: Dictionary = {}
	for seed_value in range(96):
		var build: SeasonBuild = _build(seed_value)
		var stock: Dictionary = SeasonOpponentGear.offers(build, 0)
		var categories: Dictionary = {}
		for id: String in stock.values():
			var gear: bool = SeasonOpponentGear.INITIAL.has(id)
			categories["gear" if gear else "development"] = true
			_check(gear or SeasonOpponentMarket.cards(build).has(id), "finite supported offer pool")
			if gear:
				discovered[id] = true
		_check(stock.size() == 4 and categories.size() == 2, "normal category repair and four offers")
		for profile: String in SeasonOpponentGear.PREFERENCES:
			var candidate: SeasonBuild = _build(seed_value)
			var club: Dictionary = {"profile": profile, "roles": SeasonOpponentPolicy.roles(candidate),
				"cursor": 0, "decisions": []}
			SeasonOpponentPolicy.checkout(candidate, club, 0)
			for row: Dictionary in club.decisions:
				if row.stat == "gear":
					_check(SeasonOpponentGear.PREFERENCES[profile].has(row.item),
					"only authored preferences bought")
					bought[row.item] = true
			_audit(candidate, club)
			_check(candidate._visit.rerolls <= 1, "one ordinary paid reroll maximum")
	_check(discovered.size() == 13 and bought.size() == 6,
		"all thirteen offered and six distinct preferences purchased")
	for id: String in SeasonOpponentGear.INITIAL:
		var build: SeasonBuild
		var offer: String = ""
		for seed_value in range(96):
			build = _build(seed_value)
			build.commit(SeasonOpponentPolicy.command(build, "open"))
			for key: String in build._visit.offers:
				if build._visit.offers[key] == id:
					offer = key
					break
			if offer != "":
				break
		_check(offer != "", "real generated Gear offer: " + id)
		if offer == "":
			continue
		var item: Dictionary = SeasonGearCatalog.item(id)
		var command: Dictionary = SeasonOpponentPolicy.command(
			build, "equip", {"offer": offer, "replace": ""})
		_check(build.commit(command).ok and build.cash() == 18 - int(item.price),
			"ordinary paid Gear transaction")
		var owned: Dictionary = build._bank.view().gear[item.slot]
		_check(owned.item == id and owned.paid == item.price, "exact receipt, no spare copy")
		for player: String in build.roster():
			_check(build.definition(player).season_gear[item.slot] == id,
				"same team Gear reaches every definition")
		var replay: SeasonBuild = SeasonBuild.from_data(build.to_data(), build._seed, build.roster())
		_check(replay != null and ClubCareer.same(replay.view(), build.view()),
			"Gear market journal replays exactly")
		var before: Dictionary = build.to_data()
		_check(not build.commit(SeasonOpponentPolicy.command(
			build, "equip", {"offer": offer, "replace": ""})).ok
			and ClubCareer.same(before, build.to_data()),
			"sold stock cannot be bought again or mutate on failure")
		var club: Dictionary = {"profile": "Distributed", "roles": SeasonOpponentPolicy.roles(build),
			"cursor": 0, "decisions": []}
		SeasonOpponentGear._equip(build, club, 0)
		_check(build._bank.view().gear[item.slot] == owned, "occupied slots never get replaced")
	print("NPC_GEAR_EXPOSURE offered=", discovered.size(), " preferred=", bought.size())


func _audit(build: SeasonBuild, club: Dictionary) -> void:
	var spent: int = 0
	for row: Dictionary in club.decisions:
		spent += int(row.paid)
	for event: Dictionary in build.to_data().events:
		if event.op == "reroll":
			spent += 4
		_check(event.op not in ["sell_gear", "sponsor_buy", "tactical_buy", "sign"],
			"no sidegrades or unsupported acquisitions")
	_check(build.cash() == 18 - spent and build.cash() >= 0,
		"development and Gear compete for one paid wallet")
	var replay: SeasonBuild = SeasonBuild.from_data(build.to_data(), build._seed, build.roster())
	_check(replay != null and ClubCareer.same(replay.view(), build.view()),
		"whole paid policy journal replays")


func _new(physical: bool) -> SeasonState:
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.opponents._format = 3
	season.physical = SeasonPhysicalFixtures.new() if physical else null
	season.career = ClubCareer.new()
	_check(season.career.start(season), "Gear policy career starts")
	for pick in range(4):
		season.choose_player(season.offers()[0])
	return season


func _saved_rounds() -> void:
	SeasonSave.path = "user://opponent-gear-%d.json" % OS.get_process_id()
	var app: SeasonApp = await _app()
	app.begin_season(443, true)
	_check(SeasonSave.restore() != null, "empty draft Gear policy saves and restores")
	_check(app.season.opponents._format == 3 and app.season.physical != null,
		"ordinary Working UI selects Gear policy before draft")
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "each Gear policy draft checkpoint restores")
	_check(SeasonSave.restore() != null, "partially drafted Gear policy saves before picks")
	_check(SeasonSave.snapshot(app.season).version == 47, "new explicit save-to-Build41 mapping")
	for round_number in range(2):
		var fixture: Dictionary = app.season.pending_fixture()
		app.round_ui.begin([fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0,
			{}, [], [], {}, [], [], {}, {}, []])
		for frame in range(300000):
			await get_tree().physics_frame
			if app.season.physical.pending.is_empty():
				break
			if not app.round_ui._working:
				_check(false, "Gear round stopped: " + app.round_ui.detail.text)
				break
		_check(app.season.player_results.size() == round_number + 1, "actual AI round settles once")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
			SeasonSave.snapshot(app.season)), "all stock, Gear receipts, builds and reports reload exactly")
	_check(app.season.physical.reports.size() == 4, "four actual saved physical matches")
	var committed: Dictionary = app.season.opponents.to_data()
	for club: Dictionary in app.season.opponents.clubs.values():
		var gear: Dictionary = club.build._bank.view().gear
		for slot: String in SeasonOwnership.GEAR_SLOTS:
			if not gear[slot].is_empty():
				_gear_count += 1
	_check(_gear_count > 0, "real round acquisition equips paid Gear")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-gear-pregame")
	var found: bool = false
	var heading: Control
	for node: Node in app.menu._body.find_children("*", "Label", true, false):
		if node.has_meta("opponent_gear"):
			found = true
			heading = node
	_check(found, "actual preparation discloses committed slots and effects")
	if heading != null:
		var scroll: ScrollContainer = app.menu._body.get_parent()
		scroll.ensure_control_visible(heading)
		await _frames()
		await _capture(get_viewport(), "opponent-gear-slots")
		get_window().size = Vector2i(700, 400)
		await _frames()
		scroll.ensure_control_visible(heading)
		await _frames()
		_check(get_viewport().get_visible_rect().encloses(app.menu._footer.get_global_rect()),
			"Gear preparation retains navigation at smaller viewport")
		await _capture(get_viewport(), "opponent-gear-slots-small")
		get_window().size = Vector2i(1280, 720)
		await _frames()
	# Render the shared read-only component with a genuinely paid committed club build.
	for key: String in app.season.opponents.clubs:
		var build: SeasonBuild = app.season.opponents.clubs[key].build
		if not build._bank.view().gear.values().any(
			func(item: Dictionary) -> bool: return not item.is_empty()):
			continue
		var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
		SeasonPages.wrapped(card, "Committed club Gear • " + app.season.teams[int(key)].name)
		SeasonOpponentGearUI.equipment(card, build)
		await _frames()
		(app.menu._body.get_parent() as ScrollContainer).ensure_control_visible(card)
		await _frames()
		await _capture(get_viewport(), "opponent-paid-gear-component")
		break
	var saved: Dictionary = SeasonSave.snapshot(app.season)
	for target: String in ["version", "policy", "market", "receipt"]:
		var bad: Dictionary = saved.duplicate(true)
		match target:
			"version": bad.version = 46
			"policy": bad.opponents.policy = 2
			"market": bad.opponents.clubs["1"].build.market = 1
			"receipt": bad.opponents.clubs["1"].build.events.pop_back()
		_check(SeasonSave._decode(bad) == null, "reject altered Gear policy " + target)
	app.season.build.commit(SeasonOpponentPolicy.command(app.season.build, "open"))
	_check(ClubCareer.same(committed, app.season.opponents.to_data()),
		"human shop never triggers counter-shopping")
	var state: MatchState = app.season.make_match()
	for team: TeamMatchState in [state.away_team, state.home_team]:
		for player: PlayerMatchState in team.roster:
			var expected: PlayerDefinition = app.season.player_definition(String(player.definition.id))
			_check(player.definition.season_gear == expected.season_gear,
				"visible match uses the same committed team Gear definitions")
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	print("NPC_GEAR_ROUNDS games=4 equipped_slots=", _gear_count)
