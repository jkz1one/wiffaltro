extends "res://src/tests/season_opponent_gear_test.gd"
## Synthetic unit income; saved rounds run four actual physical AI games.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_mastery_units()
	await _mastery_rounds()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent mastery checks passed: paid targets, family stock and physical replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var roster: Array[String] = ["player.alex_finch", "player.ari_banks",
		"player.rowan_chase", "player.gray_west"]
	var build: SeasonBuild = SeasonBuild.new(seed_value, roster)
	build._market = 3
	_check(build.commit(SeasonOpponentPolicy.command(
		build, "reward", {"game": 0, "win": true, "performance": {}})).ok, "synthetic reward fixture")
	return build


func _club(build: SeasonBuild) -> Dictionary:
	var roles: Dictionary = SeasonOpponentPolicy.roles(build)
	return {"profile": "Pitching / defense", "roles": roles, "cursor": 0, "decisions": [],
		"primary": SeasonOpponentMastery.primary(build, roles.pitcher)}


func _mastery_units() -> void:
	var discovered: Dictionary = {}
	var upgrades: Dictionary = {}
	for seed_value in range(96):
		var build: SeasonBuild = _build(seed_value)
		var club: Dictionary = _club(build)
		_check(club.primary == "pitch.overhand_four_seam", "stable fastball, never Alex's level2 Eephus")
		for id: String in SeasonOpponentMastery.offers(build, 0).values():
			_check(SeasonOpponentGear.INITIAL.has(id) or DevelopmentShopCatalog.CARDS.has(id),
				"finite supported mastery market")
			if DevelopmentShopCatalog.CARDS.has(id):
				discovered[id] = true
		var pack: Array = SeasonOpponentMarket.pack(build)
		var families: Dictionary = {}
		for id: String in pack:
			families[DevelopmentShopCatalog.item(id).family] = true
		_check(pack.size() == 3 and families.size() == 3, "three distinct development families")
		_check(not (pack.has("development.mastery") and pack.has("development.round_out")),
			"pack never doubles its pitch family")
		SeasonOpponentPolicy.checkout(build, club, 0)
		for row: Dictionary in club.decisions:
			if row.stat == "mastery":
				_check(row.player == club.roles.pitcher and row.pitch == club.primary
					and row.level <= 5, "paid exact committed primary target")
				upgrades[row.item] = true
		var definition: PlayerDefinition = build.definition(club.roles.pitcher)
		for pitch: PitchDefinition in definition.starting_pitches:
			if String(pitch.id) == club.primary:
				_check(pitch.mastery_level == build.player(club.roles.pitcher).mastery[club.primary],
					"committed mastery reaches the actual match recipe")
		_check(ContentDB.get_pitch(StringName(club.primary)).mastery_level == 1,
			"paid mastery never mutates the shared natural recipe")
		_audit(build, club)
		_check(build._visit.rerolls <= 1, "one affordable paid reroll")
	_check(discovered.size() == 6 and upgrades.size() == 2, "all six cards and both paid variants")
	_cheaper_target()
	var book: SeasonDevelopment
	for player: String in SeasonPlayerCatalog.ids():
		var build: SeasonBuild = SeasonBuild.new(1, [player])
		_check(SeasonOpponentMastery.FASTBALLS.has(SeasonOpponentMastery.primary(build, player)),
			"every authored player has a legal ordinary fastball")
	# Synthetic cap fixture exercises target filtering, not a purchased/saveable build.
	var capped: SeasonBuild = _build(1)
	var club: Dictionary = _club(capped)
	book = capped._book
	for recipe: String in book._players[club.roles.pitcher].active:
		book._players[club.roles.pitcher].mastery[recipe] = 5
	book._players[club.roles.pitcher].mastery["pitch.overhand_sinker"] = 4
	book._players[club.roles.pitcher].mastery[club.primary] = 1
	_check(SeasonOpponentMastery.primary(capped, club.roles.pitcher) == "pitch.overhand_sinker",
		"primary selection ranks existing ordinary mastery before stable ID")
	book._players[club.roles.pitcher].mastery[club.primary] = 5
	book._players[club.roles.pitcher].mastery["pitch.overhand_sinker"] = 5
	var goal: Dictionary = {"player": club.roles.pitcher, "stat": "mastery",
		"pitch": club.primary, "cursor": -1}
	_check(SeasonOpponentMastery.cards(capped, goal).is_empty(), "capped target cannot be purchased")
	_check(not SeasonOpponentMastery.objectives(capped, club).any(
		func(row: Dictionary) -> bool: return row.stat == "mastery"), "rotation skips capped mastery")
	print("NPC_MASTERY_EXPOSURE cards=", discovered.size(), " paid_variants=", upgrades.size())


func _cheaper_target() -> void:
	var build: SeasonBuild
	var club: Dictionary
	var found: bool = false
	for seed_value in range(512):
		build = _build(seed_value)
		club = _club(build)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		if (build._visit.offers.values().has("development.round_out")
			and build._visit.offers.values().has("development.mastery")):
			found = true
			break
	_check(found, "real generated stock contains both variants")
	if not found:
		return
	var goals: Array[Dictionary] = SeasonOpponentMastery.objectives(build, club)
	_check(SeasonOpponentMastery._develop(build, club, 0, goals)
		and club.decisions[0].item == "development.round_out" and build.cash() == 12,
		"choose cheaper legal Round Out before Mastery for the exact target")
	_check(SeasonOpponentMastery.useful_price(build, club,
		SeasonOpponentMastery.objectives(build, club)) == 8,
		"reroll affordability uses8 when Round Out cannot target the primary")
	var goal: Dictionary = goals[0]
	_check(SeasonOpponentMastery.cards(build, goal) == ["development.mastery"],
		"other lower pitches forbid Round Out on the raised primary")
	var round_offer: String = ""
	for offer: String in build._visit.offers:
		if build._visit.offers[offer] == "development.round_out":
			round_offer = offer
	var before: Dictionary = build.to_data()
	_check(not build.commit(SeasonOpponentPolicy.command(build, "buy", {
		"offer": round_offer, "mode": "use", "player": goal.player, "pitch": goal.pitch,
		"replace": ""})).ok and ClubCareer.same(before, build.to_data()),
		"ineligible or sold exact target rolls back without payment")
	_check(SeasonOpponentMastery._develop(build, club, 0,
		SeasonOpponentMastery.objectives(build, club))
		and club.decisions[-1].item == "development.mastery"
		and build.cash() == 4, "flexible Mastery buys exact raised fastball at8")
	_check(SeasonOpponentMastery.useful_price(build, club,
		SeasonOpponentMastery.objectives(build, club)) >= 6, "reroll cannot pretend Mastery costs6")
	_audit(build, club)


func _new(physical: bool) -> SeasonState:
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.opponents._format = 4
	season.physical = SeasonPhysicalFixtures.new() if physical else null
	season.career = ClubCareer.new()
	_check(season.career.start(season), "mastery policy career starts")
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "mastery policy draft completes")
	return season


func _mastery_rounds() -> void:
	SeasonSave.path = "user://opponent-mastery-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://opponent-mastery-%d.cfg" % OS.get_process_id()
	var app: SeasonApp = await _app()
	app.begin_season(443, true)
	# Frozen policy4 fixture; the lesson scene covers current Working startup.
	app.season.opponents._format = 4
	_check(SeasonSave.save(app.season), "historical mastery draft checkpoint saves")
	_check(app.season.opponents._format == 4 and SeasonSave.restore() != null,
		"historical mastery policy saves before draft")
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "every partial mastery draft restores")
	_check(SeasonSave.snapshot(app.season).version == 48, "save48 explicitly binds Build41/policy4")
	for round_number in range(2):
		var pending: Dictionary = app.season.pending_fixture()
		app.round_ui.begin([pending.id, 0 if pending.home == 0 else 1,
			1 if pending.home == 0 else 0, {}, [], [], {}, [], [], {}, {}, []])
		for frame in range(300000):
			await get_tree().physics_frame
			if app.season.physical.pending.is_empty():
				break
			if not app.round_ui._working:
				_check(false, "mastery round paused: " + app.round_ui.detail.text)
				break
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
			SeasonSave.snapshot(app.season)), "mastery stock, targets and reports replay exactly")
	var count: int = 0
	for club: Dictionary in app.season.opponents.clubs.values():
		for row: Dictionary in club.decisions:
			count += 1 if row.stat == "mastery" else 0
	_check(count > 0 and app.season.physical.reports.size() == 4,
		"real rounds acquire paid mastery and run four physical AI games")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-mastery-pregame")
	var focus_found: bool = false
	for node: Node in app.menu._body.find_children("*", "Label", true, false):
		if node.has_meta("opponent_mastery"):
			focus_found = true
			(app.menu._body.get_parent() as ScrollContainer).ensure_control_visible(node.get_parent())
			await _frames()
			await _capture(get_viewport(), "opponent-mastery-focus")
			get_window().size = Vector2i(700, 400)
			await _frames()
			_check(get_viewport().get_visible_rect().encloses(app.menu._footer.get_global_rect()),
				"mastery focus keeps navigation at smaller viewport")
			await _capture(get_viewport(), "opponent-mastery-focus-small")
			get_window().size = Vector2i(1280, 720)
			await _frames()
			break
	_check(focus_found, "actual next opponent discloses committed primary focus")
	var purchase_found: bool = false
	for node: Node in app.menu._body.find_children("*", "Label", true, false):
		if node.has_meta("opponent_mastery_purchase"):
			purchase_found = true
			(app.menu._body.get_parent() as ScrollContainer).ensure_control_visible(node)
			await _frames()
			await _capture(get_viewport(), "opponent-mastery-receipt")
			break
	_check(purchase_found, "actual opponent discloses its paid recipe upgrade")
	var saved: Dictionary = SeasonSave.snapshot(app.season)
	for target: String in ["primary", "primary_ordinary", "version", "policy", "market"]:
		var bad: Dictionary = saved.duplicate(true)
		match target:
			"primary": bad.opponents.clubs["3"].primary = "pitch.eephus"
			"primary_ordinary":
				bad.opponents.clubs["3"].primary = ("pitch.overhand_sinker"
					if bad.opponents.clubs["3"].primary != "pitch.overhand_sinker"
					else "pitch.overhand_four_seam")
			"version": bad.version = 47
			"policy": bad.opponents.policy = 3
			"market": bad.opponents.clubs["3"].build.market = 2
		_check(SeasonSave._decode(bad) == null, "reject altered mastery " + target)
	var committed: Dictionary = app.season.opponents.to_data()
	app.season.build.commit(SeasonOpponentPolicy.command(app.season.build, "open"))
	_check(ClubCareer.same(committed, app.season.opponents.to_data()), "no counter-shopping")
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	print("NPC_MASTERY_ROUNDS games=4 upgrades=", count)
