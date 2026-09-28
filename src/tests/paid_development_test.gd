extends Node

const ROSTER: Array[String] = [
	"player.alex_finch", "player.rowan_chase", "player.nico_vega", "player.ari_banks"
]
var _failures: int = 0


func _ready() -> void:
	_atomic_purchases()
	_paid_replacement()
	_packs_and_rerolls()
	_eligibility()
	_capped_eligibility()
	_terminal_seasons()
	await _season_and_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro paid development checks passed: atomic purchases, fixed packs, saves and season UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _funded(seed_value: int = 5, rewards: int = 4) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER)
	for game in range(rewards):
		_ok(build.commit(_request(build, "reward", {"game": game, "win": true})), "earned income")
	_ok(build.commit(_request(build, "open")), "postgame shop")
	return build


func _atomic_purchases() -> void:
	var build: SeasonBuild
	var offers: Array[String] = []
	for seed_value in range(30):
		build = _funded(seed_value)
		offers.clear()
		for offer: String in build.view().shop.offers:
			if DevelopmentShopCatalog.CARDS.has(build.view().shop.offers[offer]):
				offers.append(offer)
		if offers.size() >= 3:
			break
	_check(offers.size() >= 3, "fixture has three ordinary card offers")
	var hold: Dictionary = _buy(build, offers[0], "hold")
	var before: Dictionary = _snapshot(build)
	_check(build.preview(hold).ok and _snapshot(build) == before, "cancelled preview is inert")
	_ok(build.commit(hold), "buy first held card")
	var receipt: Dictionary = build.view().wallet.held[0]
	_check(
		receipt.paid == DevelopmentShopCatalog.item(receipt.item).price, "full actual paid receipt"
	)
	_ok(build.commit(_buy(build, offers[1], "hold")), "buy second held card")
	_reject(build, _buy(build, offers[2], "hold"), "third held slot cannot overflow")
	var immediate: Dictionary = _buy(build, offers[2], "use")
	var item_id: String = build.view().shop.offers[offers[2]]
	var old_cash: int = build.cash()
	_ok(build.commit(immediate), "immediate use works with two held cards")
	_check(build.cash() == old_cash - int(DevelopmentShopCatalog.item(item_id).price), "one debit")
	_check(build.view().wallet.held.size() == 2, "immediate use needs no extra storage")
	_check(build.commit(immediate).replayed, "duplicate purchase settles once")
	var use: Dictionary = _request(build, "use", {"receipt": receipt.id})
	use.merge(build.targets(receipt.item)[0])
	old_cash = build.cash()
	_ok(build.commit(use), "held card applies and consumes together")
	_check(
		build.cash() == old_cash and build.view().wallet.held.size() == 1, "use does not pay twice"
	)
	_reject(
		build,
		_request(
			build, "use", {"receipt": receipt.id, "player": ROSTER[0], "pitch": "", "replace": ""}
		),
		"consumed receipt cannot be reused"
	)
	var invalid: Dictionary = _request(build, "charge", {"amount": -100})
	_reject(build, invalid, "player commands cannot choose debit amounts")
	var loaded: SeasonBuild = SeasonBuild.from_data(
		JSON.parse_string(JSON.stringify(build.to_data())), build.to_data().seed, ROSTER
	)
	_check(loaded != null and _snapshot(loaded) == _snapshot(build), "combined journal reload")
	_check(loaded.commit(use).replayed, "receipt use remains idempotent after reload")
	var poor: SeasonBuild = _funded(8, 1)
	_ok(poor.commit(_request(poor, "pack_open")), "spend 8 on pack")
	_ok(poor.commit(_request(poor, "pack_skip")), "paid skip gives no card/refund")
	_ok(poor.commit(_request(poor, "reroll")), "leave less than any lesson price")
	var lesson: String = ""
	for offer: String in poor.view().shop.offers:
		if str(poor.view().shop.offers[offer]).begins_with("lesson."):
			lesson = offer
	var buy_lesson: Dictionary = _buy(poor, lesson, "use")
	_reject(poor, buy_lesson, "unaffordable lesson rolls back already-prepared learning")
	buy_lesson.price = 0
	_reject(poor, buy_lesson, "client cannot override a quote")
	var rich: SeasonBuild = _funded(8)
	var lesson_offer: String = ""
	for offer: String in rich.view().shop.offers:
		if str(rich.view().shop.offers[offer]).begins_with("lesson."):
			lesson_offer = offer
	var request: Dictionary = _buy(rich, lesson_offer, "use")
	var lesson_item: Dictionary = DevelopmentShopCatalog.item(rich.view().shop.offers[lesson_offer])
	var foreign: Dictionary = request.duplicate(true)
	foreign.player = "player.bailey_quinn"
	_reject(rich, foreign, "cannot buy for an opposing/unowned player")
	_ok(rich.commit(request), "lesson settles immediately on legal owned target")
	_check(rich.player(request.player).active.has(lesson_item.recipe), "paid lesson is usable")
	_check(rich.view().wallet.held.is_empty(), "lessons never become spare items")


func _paid_replacement() -> void:
	var rich: SeasonBuild
	var offer: String = ""
	var selected: Dictionary = {}
	for seed_value in range(10):
		rich = _funded(seed_value)
		for key: String in rich.view().shop.offers:
			var id: String = rich.view().shop.offers[key]
			if not id.begins_with("lesson."):
				continue
			for target: Dictionary in rich.targets(id):
				if target.player == ROSTER[1]:
					offer = key
					selected = target
					break
		if not selected.is_empty():
			break
	_check(not selected.is_empty(), "paid full-capacity lesson fixture exists")
	if selected.is_empty():
		return
	var request: Dictionary = _request(rich, "buy", {"offer": offer, "mode": "use"})
	request.merge(selected)
	var invalid: Dictionary = request.duplicate(true)
	invalid.replace = ""
	_reject(rich, invalid, "full capacity never chooses an implicit paid replacement")
	invalid.replace = "pitch.switchback"
	_reject(rich, invalid, "replacement must identify an actually active recipe")
	var before: Dictionary = rich.player(selected.player)
	var lesson: Dictionary = DevelopmentShopCatalog.item(rich.view().shop.offers[offer])
	var old_cash: int = rich.cash()
	_ok(rich.commit(request), "explicit paid replacement settles all components")
	var after: Dictionary = rich.player(selected.player)
	_check(
		(
			after.active.size() == before.active.size()
			and after.active.has(lesson.recipe)
			and not after.active.has(selected.replace)
		),
		"exact repertoire replacement without overflow"
	)
	_check(
		after.mastery[selected.replace] == before.mastery[selected.replace],
		"paid replacement preserves remembered mastery"
	)
	_check(rich.cash() == old_cash - lesson.price, "replacement lesson charges once")


func _packs_and_rerolls() -> void:
	var build: SeasonBuild = _funded(17, 6)
	var original_cards: Array = build._visit.cards.duplicate()
	_check(not build.view().shop.has("cards"), "sealed pack choices are not exposed")
	for cost in [4, 6, 8]:
		var before: int = build.cash()
		_ok(build.commit(_request(build, "reroll")), "ordinary reroll")
		_check(build.cash() == before - cost, "escalating quoted fee")
		_check(build._visit.cards == original_cards, "reroll never refreshes fixed pack")
		_check(build.view().shop.offers.size() == 4, "four live ordinary positions")
	var stale: Dictionary = _buy(build, build.view().shop.offers.keys()[0], "use")
	_ok(build.commit(_request(build, "reroll")), "new stock invalidates old purchase")
	_reject(build, stale, "stale preview does not spend")
	var before: int = build.cash()
	var open: Dictionary = _request(build, "pack_open")
	_ok(build.commit(open), "fixed pack payment")
	_check(build.cash() == before - 8 and build.commit(open).replayed, "pack pays exactly once")
	_reject(build, _request(build, "reroll"), "must resolve revealed pack")
	_reject(build, _request(build, "reward", {"game": 20, "win": true}), "cannot carry open pack")
	var item_id: String = build.view().shop.cards[0]
	var choose: Dictionary = _request(build, "pack_pick", {"item": item_id})
	choose.merge(build.targets(item_id)[0])
	var invalid: Dictionary = choose.duplicate(true)
	invalid.player = "unknown"
	_reject(build, invalid, "invalid pack recipient preserves paid pending choice")
	_ok(build.commit(choose), "apply exactly one revealed card")
	_check(
		build.view().shop.pack_status == "used" and build.cash() == before - 8,
		"pack use is immediate and has no second charge"
	)
	_reject(build, _request(build, "pack_open"), "pack cannot be reopened")
	_ok(build.commit(_request(build, "reward", {"game": 20, "win": false})), "next result")
	_ok(build.commit(_request(build, "open")), "next visit")
	_check(build.view().shop.rerolls == 0, "reroll escalation resets per visit")
	var broken: Dictionary = build.to_data()
	broken.events[1].win = false
	# Valid changed inputs may form a different ledger, but the season loader must
	# reject rewards that differ from its real retained fixtures (integration below).
	broken["cash"] = 9000
	_check(SeasonBuild.from_data(broken, 17, ROSTER) == null, "no authoritative balance override")


func _eligibility() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("eligibility")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value in range(80):
		rng.seed = seed_value
		var pack: Array = DevelopmentShopCatalog.pack(book, ROSTER, rng)
		var families: Array = []
		for id: String in pack:
			families.append(DevelopmentShopCatalog.item(id).family)
		_check(pack.size() == 3 and families.count("pitch") <= 1, "distinct-family fixed pack")
		_check(
			(
				families[0] != families[1]
				and families[0] != families[2]
				and families[1] != families[2]
			),
			"no repeated family"
		)
		var stock: Dictionary = DevelopmentShopCatalog.offers(book, ROSTER, rng, "fixture")
		var types: Dictionary = {}
		for id: String in stock.values():
			types[DevelopmentShopCatalog.item(id).op == "learn"] = true
		_check(stock.size() == 4 and types.size() == 2, "two legal categories when feasible")
	var full: Array[String] = ["player.rowan_chase"]
	var targets: Array[Dictionary] = DevelopmentShopCatalog.targets(book, full, "lesson.pitch.drop")
	_check(
		targets.size() == 2 and targets[0].replace != "" and targets[1].replace != "",
		"full learned capacity supplies only explicit replacements"
	)
	_check(
		DevelopmentShopCatalog.targets(book, full, "lesson.pitch.switchback").is_empty(),
		"unready recipes never enter legal offers"
	)


func _season_and_ui() -> void:
	var prefix: String = "user://paid-development-%d" % OS.get_process_id()
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.begin_season(61, true)
	for _pick in range(4):
		app.choose_player(app.season.offers()[0])
	_check(app.season.build != null and app.season.cash() == 0, "Working season starts at zero")
	_check(not app.season.shop_available(), "no invented pregame-1 income/shop")
	var fixture: Dictionary = app.season.pending_fixture()
	_check(
		app.season.record_player_result(
			fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0
		),
		"completed fixture funds the build"
	)
	_check(app._checkpoint(), "result and wallet persisted")
	app.open_shop()
	var window: SeasonShopWindow
	for child in app.menu.get_children():
		if child is SeasonShopWindow:
			window = child
	_check(window != null, "real season opens shop window")
	var offer: String = app.season.build.view().shop.offers.keys()[0]
	var command: Dictionary = _buy(app.season.build, offer, "use")
	var before: Dictionary = _snapshot(app.season.build)
	window._preview(command, "Purchase integration fixture")
	_check(
		window._confirm.visible and _snapshot(app.season.build) == before, "review before payment"
	)
	window._confirm.canceled.emit()
	window._confirm.hide()
	_check(_snapshot(app.season.build) == before, "cancelled UI transaction is inert")
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = prefix + "/missing/season.json"
	_check(not app.commit_shop(command), "failed disk save rejects purchase")
	_check(_snapshot(app.season.build) == before, "failed save preserves cash, card and growth")
	SeasonSave.path = prefix + ".json"
	_check(FileAccess.get_file_as_string(SeasonSave.path) == saved, "prior save bytes preserved")
	window._preview(command, "Purchase integration fixture")
	window._confirm.confirmed.emit()
	window._confirm.hide()
	_check(app.season.cash() < 18, "confirmed UI purchase spends earned cash")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and _snapshot(restored.build) == _snapshot(app.season.build),
		"schema5 restores stock, receipts, cash and development together"
	)
	_check(
		app.commit_shop(command) and app.season.cash() == restored.cash(),
		"repeated confirm is inert"
	)
	var state: MatchState = restored.make_match()
	var own: TeamMatchState = (
		state.home_team if restored.pending_fixture().home == 0 else state.away_team
	)
	for player: PlayerMatchState in own.roster:
		var profile: Dictionary = restored.build.player(String(player.definition.id))
		_check(
			(
				player.definition.progression_test
				and player.definition.power == profile.stats.power
				and player.definition.control == profile.stats.pitching
			),
			"next match uses actual paid state"
		)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.build.events[0].win = false
	_check(SeasonSave._decode(data) == null, "forged reward cannot disagree with retained result")
	data = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.version = 4
	_check(SeasonSave._decode(data) == null, "downgrade cannot silently discard a build")
	window.queue_free()
	app.menu.show_lineup()
	app.menu.show_players()
	app.queue_free()
	await get_tree().process_frame
	for path: String in [prefix + ".json", prefix + ".cfg"]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)


func _capped_eligibility() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("capped-eligibility")
	var roster: Array[String] = [ROSTER[1]]
	var player_id: String = roster[0]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for stat: String in ["contact", "power", "fielding"]:
		while book.player(player_id).stats[stat] < 10:
			_grow(book, player_id, "stat", stat)
	_check(
		DevelopmentShopCatalog.pack(book, roster, rng).size() == 2,
		"two eligible families yield two real choices"
	)
	while book.player(player_id).stats.pitching < 10:
		_grow(book, player_id, "stat", "pitching")
	_check(
		DevelopmentShopCatalog.pack(book, roster, rng).size() == 1,
		"one eligible family yields one real choice"
	)
	for pitch: String in book.player(player_id).active:
		while book.player(player_id).mastery[pitch] < 5:
			_grow(book, player_id, "mastery", pitch)
	_check(
		DevelopmentShopCatalog.pack(book, roster, rng).is_empty(),
		"fully capped roster cannot generate a development pack"
	)
	var stock: Dictionary = DevelopmentShopCatalog.offers(book, roster, rng, "capped")
	_check(stock.size() == 4, "remaining lesson category still supplies stock")
	for item: String in stock.values():
		_check(item.begins_with("lesson."), "capped development is absent from ordinary offers")
	# Inject a capped model only as a boundary fixture, never a persisted season.
	var build: SeasonBuild = _funded(23)
	build._book = book
	build._roster = roster
	_check(build.view().shop.choice_count == 0, "sealed pack advertises current zero eligibility")
	_reject(build, _request(build, "pack_open"), "pack cannot charge after all targets reach caps")
	for offer: String in build.view().shop.offers:
		if DevelopmentShopCatalog.CARDS.has(build.view().shop.offers[offer]):
			_reject(build, _buy(build, offer, "hold"), "stale capped card cannot be bought to hold")
			break


func _grow(book: SeasonDevelopment, player: String, op: String, target: String) -> void:
	_ok(
		book.commit(
			{
				"id": "cap:%d" % book.revision(),
				"rev": book.revision(),
				"player": player,
				"op": op,
				"target": target
			}
		),
		"eligibility cap fixture"
	)


func _terminal_seasons() -> void:
	var old_path: String = SeasonSave.path
	SeasonSave.path = "user://paid-terminal-%d.json" % OS.get_process_id()
	for win: bool in [true, false]:
		var season: SeasonState = SeasonState.create(91, false, true)
		for _pick in range(4):
			season.choose_player(season.offers()[0])
		var games: int = 0
		while not season.pending_fixture().is_empty() and games < 12:
			var fixture: Dictionary = season.pending_fixture()
			var home_win: bool = win == (fixture.home == 0)
			_check(
				season.record_player_result(fixture.id, 0 if home_win else 1, 1 if home_win else 0),
				"regular/playoff result pays once"
			)
			games += 1
			if not season.pending_fixture().is_empty():
				_check(season.shop_available(), "postgame shop remains available through playoffs")
				_ok(season.build.commit(_request(season.build, "open")), "open between valid games")
		_check(season.phase == SeasonState.Phase.COMPLETE, "win/loss fixtures reach completion")
		_check(not season.shop_available(), "elimination/championship creates no extra shop")
		_check(season.cash() == games * (18 if win else 12), "terminal income is retained")
		_check(
			SeasonSave.save(season) and SeasonSave.restore() != null,
			"complete Working season and every earned reward restore"
		)
		var before: String = FileAccess.get_file_as_string(SeasonSave.path)
		_ok(
			season.build.commit(_request(season.build, "open")), "untrusted post-final open fixture"
		)
		_check(not SeasonSave.save(season), "season boundary rejects post-final shopping")
		_check(
			FileAccess.get_file_as_string(SeasonSave.path) == before,
			"rejected final shop cannot replace the completed checkpoint"
		)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	SeasonSave.path = old_path


func _request(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id": "test:%d" % build.revision(), "rev": build.revision(), "op": op}
	result.merge(fields)
	return result


func _buy(build: SeasonBuild, offer: String, mode: String) -> Dictionary:
	var result: Dictionary = _request(build, "buy", {"offer": offer, "mode": mode})
	if mode == "hold":
		result.merge({"player": "", "pitch": "", "replace": ""})
	else:
		result.merge(build.targets(build.view().shop.offers[offer])[0])
	return result


func _snapshot(build: SeasonBuild) -> Dictionary:
	var players: Dictionary = {}
	for id: String in build.to_data().roster:
		players[id] = build.player(id)
	return {"journal": build.to_data(), "view": build.view(), "players": players}


func _reject(build: SeasonBuild, command: Dictionary, message: String) -> void:
	var before: Dictionary = _snapshot(build)
	_check(not build.commit(command).ok and _snapshot(build) == before, message)


func _ok(result: Dictionary, message: String) -> void:
	_check(result.ok, message + ": " + str(result.get("error", "")))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
