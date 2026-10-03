extends "res://src/tests/season_opponent_mastery_test.gd"
## Synthetic rewards for stock units; saved rounds use actual physical AI fixtures.

const SEED: int = 443


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_lesson_units()
	await _lesson_rounds()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent lesson checks passed: paid stock, learning and physical replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(seed_value, ["player.alex_finch", "player.lee_stone",
		"player.rowan_chase", "player.gray_west"])
	build._market = 4
	_check(build.commit(SeasonOpponentPolicy.command(build,
		"reward", {"game": 0, "win": true, "performance": {}})).ok, "synthetic lesson win fixture")
	return build


func _club(build: SeasonBuild) -> Dictionary:
	var club: Dictionary = super._club(build)
	# Explicit legal committed-role fixture isolates a missing secondary slider.
	club.roles.secondary = "player.lee_stone"
	return club


func _lesson_units() -> void:
	var exposed: Dictionary = {}
	var bought: int = 0
	for seed_value in range(96):
		var build: SeasonBuild = _build(seed_value)
		var club: Dictionary = _club(build)
		var stock: Dictionary = SeasonOpponentLessons.offers(build, 0)
		var categories: Dictionary = {}
		for id: String in stock.values():
			var lesson: bool = id.begins_with("lesson.")
			_check(SeasonOpponentGear.INITIAL.has(id) or DevelopmentShopCatalog.CARDS.has(id)
				or (lesson and SeasonOpponentLessons.RECIPES.has(id.trim_prefix("lesson."))),
				"only finite supported stock")
			categories["lesson" if lesson else ("gear" if SeasonOpponentGear.INITIAL.has(id)
				else "development")] = true
			if lesson:
				exposed[id] = true
		_check(stock.size() == 4 and categories.size() >= 2, "ordinary category diversity repair")
		var before: Dictionary = build.to_data()
		var poor: SeasonBuild = build._fork()
		poor._bank.commit({"id": "fixture-charge", "rev": poor._bank.revision(),
			"op": "charge", "amount": 18})
		_check(SeasonOpponentLessons.offers(poor, 0) == stock,
			"affordability never filters legal lesson stock")
		var pack: Array = SeasonOpponentMarket.pack(build)
		_check(pack.all(func(id: String) -> bool: return DevelopmentShopCatalog.CARDS.has(id)),
			"fixed pack never includes lessons")
		_check(ClubCareer.same(before, build.to_data()), "stock/pack inspection spends nothing")
		for profile: String in ["Distributed", "Featured hitter", "Pitching / defense"]:
			var candidate: SeasonBuild = _build(seed_value)
			var buyer: Dictionary = _club(candidate)
			buyer.profile = profile
			SeasonOpponentPolicy.checkout(candidate, buyer, 0)
			for row: Dictionary in buyer.decisions:
				if row.stat != "lesson":
					continue
				bought += 1
				_check(profile != "Featured hitter" and row.player == buyer.roles.secondary
					and row.pitch == "pitch.overhand_slider" and row.paid == 10,
					"only matching secondary slider buys at10")
				_check(row.level == 1 and candidate.player(row.player).active.size() == 4,
					"new recipe starts1 without capacity expansion")
			_audit(candidate, buyer)
			_check(candidate._visit.rerolls <= 1, "at most one affordable useful paid reroll")
	_check(exposed.size() == 5 and bought > 0, "all five lessons exposed and real policy buys")
	for recipe: String in SeasonOpponentLessons.RECIPES:
		_buy_common(recipe)
	_target_guards()
	_remembered_slider()
	print("NPC_LESSON_EXPOSURE offered=", exposed.size(), " policy_purchases=", bought)


func _audit(build: SeasonBuild, club: Dictionary) -> void:
	var spent: int = 0
	for row: Dictionary in club.decisions:
		spent += int(row.paid)
	for event: Dictionary in build.to_data().events:
		if event.op == "reroll":
			spent += 4
		elif event.op == "pack_skip":
			spent += 8
		_check(event.op not in ["sell_gear", "sponsor_buy", "tactical_buy", "sign", "ability_buy"],
			"no sidegrades or unsupported acquisitions")
	_check(build.cash() == 18 - spent and build.cash() >= 0,
		"paid development/Gear/lessons and skipped packs compete for one wallet")
	var replay: SeasonBuild = SeasonBuild.from_data(build.to_data(), build._seed, build.roster())
	_check(replay != null and ClubCareer.same(replay.view(), build.view()),
		"entire paid lesson-policy journal replays exactly")


func _buy_common(recipe: String) -> void:
	var build: SeasonBuild
	var offer: String = ""
	var id: String = "lesson." + recipe
	for seed_value in range(96):
		build = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		for key: String in build._visit.offers:
			if build._visit.offers[key] == id:
				offer = key
				break
		if not offer.is_empty():
			break
	_check(not offer.is_empty(), "actual generated Common lesson: " + recipe)
	if offer.is_empty():
		return
	var target: Dictionary = build.targets(id)[0]
	_check(not target.is_empty(), "legal shared lesson recipient exists")
	if target.is_empty():
		return
	var command: Dictionary = SeasonOpponentPolicy.command(build, "buy", {
		"offer": offer, "mode": "use", "player": target.player, "pitch": "", "replace": target.replace})
	_check(build.commit(command).ok and build.cash() == 8, "shared10-Cash paid learning transaction")
	_check(build.player(target.player).active.has(recipe)
		and build.definition(target.player).starting_pitches.any(
			func(pitch: PitchDefinition) -> bool: return String(pitch.id) == recipe),
		"paid recipe reaches actual committed match resources")
	_check(ContentDB.get_player(StringName(target.player)).starting_pitches.all(
		func(pitch: PitchDefinition) -> bool: return String(pitch.id) != recipe),
		"paid lesson does not mutate natural player resources")
	var before: Dictionary = build.to_data()
	_check(not build.commit(SeasonOpponentPolicy.command(build, "buy", {
		"offer": offer, "mode": "use", "player": target.player,
		"pitch": "", "replace": target.replace})).ok
		and ClubCareer.same(before, build.to_data()), "sold lesson rejects with atomic rollback")
	var replay: SeasonBuild = SeasonBuild.from_data(before, build._seed, build.roster())
	_check(replay != null and ClubCareer.same(replay.view(), build.view()), "paid lesson exact replay")


func _target_guards() -> void:
	var build: SeasonBuild = _build(1)
	var club: Dictionary = _club(build)
	_check(SeasonOpponentLessons.target(build, club).pitch == "pitch.overhand_slider",
		"natural overhand chooses exact OS even with mixed authored repertoire")
	club.profile = "Featured hitter"
	_check(SeasonOpponentLessons.target(build, club).is_empty(), "featured profile skips lessons")
	club.profile = "Distributed"
	club.roles.secondary = "player.gray_west"
	_check(SeasonOpponentLessons.target(build, club).is_empty(), "known/full sidearm skips lessons")
	club.roles.secondary = "player.rowan_chase"
	_check(SeasonOpponentLessons.target(build, club).is_empty(),
		"full two-pitch specialist never forgets")
	club.roles.secondary = "player.alex_finch"
	_check(SeasonOpponentLessons.target(build, club).is_empty(), "already-known slider skipped")
	# Synthetic capacity fixture checks stock and buying separately; never serialized as paid growth.
	club.roles.secondary = "player.lee_stone"
	build._book._players[club.roles.secondary].capacity = 3
	_check(SeasonOpponentLessons.target(build, club).is_empty(),
		"empty slot required despite legal replacement")
	_check(SeasonOpponentLessons.pool(build).has("lesson.pitch.overhand_slider"),
		"legal shared replacement stock remains even when policy declines")


func _remembered_slider() -> void:
	# Unit history fixture isolates re-learning. Actual shared transactions are tested above.
	var build: SeasonBuild = _build(1)
	var club: Dictionary = _club(build)
	club.profile = "Distributed"
	club.roles.secondary = "player.gray_west"
	var profile: Dictionary = build._book._players[club.roles.secondary]
	profile.active.erase("pitch.sidearm_slider")
	profile.mastery["pitch.sidearm_slider"] = 4
	_check(SeasonOpponentLessons.target(build, club).pitch == "pitch.sidearm_slider",
		"natural sidearm chooses SS after forgetting, not OS")
	build.commit(SeasonOpponentPolicy.command(build, "open"))
	var found: bool = false
	for roll in range(32):
		# Synthetic stock-only fixture, distinct from generated paid replay tests above.
		build._visit.offers = SeasonOpponentLessons.offers(build, roll)
		if SeasonOpponentLessons.purchase(build, club, 0):
			found = true
			break
	_check(found and build.player(club.roles.secondary).mastery["pitch.sidearm_slider"] == 4
		and club.decisions[-1].level == 4,
		"same player's remembered mastery restored, never copied")
	_check(SeasonOpponentLessons.target(build, club).is_empty(),
		"policy cannot buy known slider twice")


func _new(physical: bool) -> SeasonState:
	var season: SeasonState = SeasonState.create(SEED, false, true, true)
	season.opponents._format = 5
	season.physical = SeasonPhysicalFixtures.new() if physical else null
	season.career = ClubCareer.new()
	_check(season.career.start(season), "lesson policy career starts")
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "lesson policy draft completes")
	return season


func _lesson_rounds() -> void:
	SeasonSave.path = "user://opponent-lessons-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://opponent-lessons-%d.cfg" % OS.get_process_id()
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true)
	_check(app.season.opponents._format == 5 and SeasonSave.restore() != null,
		"ordinary Working UI saves policy5 before draft")
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "each partial lesson draft restores")
	_check(SeasonSave.snapshot(app.season).version == 49, "save49 explicitly binds Build41/policy5")
	for round_number in range(2):
		var pending: Dictionary = app.season.pending_fixture()
		app.round_ui.begin([pending.id, 0 if pending.home == 0 else 1,
			1 if pending.home == 0 else 0, {}, [], [], {}, [], [], {}, {}, []])
		await _wait_lesson_round(app)
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
			SeasonSave.snapshot(app.season)), "whole lesson stock/journal/request/reward replay")
	var count: int = 0
	for club: Dictionary in app.season.opponents.clubs.values():
		for row: Dictionary in club.decisions:
			count += 1 if row.stat == "lesson" else 0
	_check(count > 0 and app.season.physical.reports.size() == 4,
		"actual round rewards acquire lessons; four complete physical AI games")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-lessons-pregame")
	var found: bool = false
	for node: Node in app.menu._body.find_children("*", "Label", true, false):
		if node.has_meta("opponent_lesson_repertoire"):
			found = true
			await _lesson_capture(app, node.get_parent(), "opponent-lessons-secondary")
			break
	_check(found, "next opponent exposes current secondary repertoire and acquisition rule")
	# Same production component, rendered using a genuinely paid committed club.
	for key: String in app.season.opponents.clubs:
		var club: Dictionary = app.season.opponents.clubs[key]
		if not club.decisions.any(func(row: Dictionary) -> bool: return row.stat == "lesson"):
			continue
		var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
		SeasonPages.wrapped(card, "Committed club • " + app.season.teams[int(key)].name)
		SeasonOpponentLessonsUI.preview(card, club)
		await _frames()
		await _lesson_capture(app, card, "opponent-paid-lesson")
		break
	var saved: Dictionary = SeasonSave.snapshot(app.season)
	for field: String in ["version", "policy", "market", "journal", "decision"]:
		var bad: Dictionary = saved.duplicate(true)
		match field:
			"version": bad.version = 48
			"policy": bad.opponents.policy = 4
			"market": bad.opponents.clubs["1"].build.market = 3
			"journal": bad.opponents.clubs["1"].build.events.pop_back()
			"decision": bad.opponents.clubs["1"].decisions.append({"stat": "lesson", "paid": 0})
		_check(SeasonSave._decode(bad) == null, "reject altered lesson " + field)
	var committed: Dictionary = app.season.opponents.to_data()
	app.season.build.commit(SeasonOpponentPolicy.command(app.season.build, "open"))
	_check(ClubCareer.same(committed, app.season.opponents.to_data()), "no human counter-shopping")
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	print("NPC_LESSON_ROUNDS games=4 lessons=", count)


func _wait_lesson_round(app: SeasonApp) -> void:
	for frame in range(300000):
		await get_tree().physics_frame
		if app.season.physical.pending.is_empty():
			return
		if not app.round_ui._working:
			_check(false, "lesson round paused: " + app.round_ui.detail.text)
			return
	_check(false, "lesson physical round did not finish")


func _lesson_capture(app: SeasonApp, control: Control, label: String) -> void:
	var scroll: ScrollContainer = app.menu._body.get_parent()
	scroll.ensure_control_visible(control)
	await _frames()
	await _capture(get_viewport(), label)
	get_window().size = Vector2i(700, 400)
	await _frames()
	scroll.ensure_control_visible(control)
	await _frames()
	_check(get_viewport().get_visible_rect().encloses(app.menu._footer.get_global_rect()),
		"secondary lesson disclosure keeps narrow navigation accessible")
	await _capture(get_viewport(), label + "-small")
	get_window().size = Vector2i(1280, 720)
	await _frames()
