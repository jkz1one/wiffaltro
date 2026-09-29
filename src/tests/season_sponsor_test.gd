extends "res://src/tests/season_misc_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_contracts()
	_transactions_and_migration()
	await _sponsor_ui()
	await _replacement_and_retry_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro sponsor checks passed: credited income, ownership, migration and paid UI.")
	get_tree().quit(0 if _failures == 0 else 1)


func _sample(roster: Array, rivals: Array) -> Dictionary:
	var stats: MatchPerformance = MatchPerformance.new()
	for outcome: String in ["walk", "walk", "walk", "double", "double", "triple", "hr", "single"]:
		stats.complete(StringName(roster[0]), StringName(rivals[0]), outcome, 0)
	for index in range(4):
		for _strikeout in range(3):
			stats.complete(StringName(rivals[0]), StringName(roster[index]), "strikeout", 0)
	for id: String in roster + rivals:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	return stats.players.duplicate(true)


func _contracts() -> void:
	var rivals: Array = ["rival.a", "rival.b", "rival.c", "rival.d"]
	var stats: Dictionary = _sample(ROSTER, rivals)
	_check(SeasonPerformance.valid(stats, ROSTER + rivals), "balanced credited event sample")
	var active: Array = [{"item": "D01"}, {"item": "A08"}, {"item": "A09"}]
	var income: Dictionary = SeasonSponsorCatalog.earnings(active, ROSTER, stats)
	_check(
		income == {"D01": 4, "A08": 8, "A09": 9}, "all distinct caps, no repeat-hit or K farming"
	)
	_check(
		SeasonSponsorCatalog.earnings(active, ROSTER, {}) == {"D01": 0, "A08": 0, "A09": 0},
		"score-only or absent events grant no sponsor income"
	)
	_check(
		SeasonSponsorCatalog.earnings([], ROSTER, stats).is_empty(), "unowned sponsors pay nothing"
	)
	_check(
		SeasonSponsorCatalog.earnings(active, rivals, stats) == {"D01": 0, "A08": 0, "A09": 0},
		"opponent events never belong to owning club"
	)
	for index in range(1, 4):
		stats[ROSTER[index]].p_k = 0
	income = SeasonSponsorCatalog.earnings(active, ROSTER, stats)
	_check(income.A08 == 2, "multiple Ks by the same stable pitcher pay once")
	stats[ROSTER[0]].bb = 1
	stats[ROSTER[0]].triple = 0
	_check(
		SeasonSponsorCatalog.earnings(active, ROSTER, stats) == {"D01": 2, "A08": 2, "A09": 6},
		"actual sparse events, no guaranteed cap payout"
	)
	var state: MatchState = _fixture()
	var before: Dictionary = state.performance.snapshot(state)
	_check(state.begin_pitch(), "begin actual walk sequence")
	state.record_ball()
	_check(state.performance.snapshot(state) == before, "called ball alone is not a credited walk")
	state.continue_after_dead_ball()
	_check(state.begin_pitch(), "next actual pitch")
	state.balls = 3
	var batter: String = String(state.batter().definition.id)
	state.record_ball()
	_check(state.performance.snapshot(state)[batter].bb == 1, "actual fourth ball credits one walk")


func _sponsor_seed(id: String, visit: int = 1, required: Array = []) -> int:
	# Search only the real generator; callers still earn, open and pay through
	# complete season journals. Expanded pools need more seeds for three exact offers.
	var build: SeasonBuild = SeasonBuild.new(0, ROSTER)
	build._visit.number = visit
	for seed_value in range(30000):
		build._seed = seed_value
		build._visit["offers"] = build._offers(0)
		if not required.is_empty():
			var found: int = 0
			for item_id: String in required:
				if not _offer(build, item_id).is_empty():
					found += 1
			if found == required.size():
				return seed_value
		elif not _offer(build, id).is_empty():
			return seed_value
	_check(false, "sponsor is reachable through actual generator")
	return -1


func _funded_season(seed_value: int, count: int = 1) -> SeasonState:
	var season: SeasonState = SeasonState.create(seed_value, false, true)
	for _pick in range(4):
		season.choose_player(season.offers()[0])
	for _game in range(count):
		_record(season)
	_check(season.build.commit(_command(season.build, "open")).ok, "open earned shop")
	return season


func _transactions_and_migration() -> void:
	var path: String = "user://sponsor-contract-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	var season: SeasonState = _funded_season(
		_sponsor_seed("", 3, SeasonSponsorCatalog.ITEMS.keys()), 3
	)
	var build: SeasonBuild = season.build
	for id: String in SeasonSponsorCatalog.ITEMS:
		var purchase: Dictionary = _command(
			build, "sponsor_buy", {"offer": _offer(build, id), "replace": ""}
		)
		_check(
			build.commit(purchase).ok and build.commit(purchase).replayed,
			"real paid sponsor purchase is idempotent"
		)
	_check(
		build.cash() == 20 and build.view().wallet.sponsors.size() == 3,
		"full prices debit earned cash and occupy active slots"
	)
	var own: Array = season.teams[0].roster
	var next: Dictionary = season.pending_fixture()
	var opponent: int = next.away if next.home == 0 else next.home
	var stats: Dictionary = _sample(own, season.teams[opponent].roster)
	var old_cash: int = season.cash()
	_check(
		season.record_player_result(
			next.id, 0 if next.home == 0 else 1, 1 if next.home == 0 else 0, stats
		),
		"complete game with attributed statistics"
	)
	_check(season.cash() == old_cash + 18 + 21, "all three bonuses settle with completed result")
	_check(not season.record_player_result(next.id, 0, 1, stats), "duplicate fixture cannot repay")
	_check(SeasonSave.save(season), "save completed sponsor earnings")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and restored.cash() == season.cash()
			and restored.build.income_for_game(next.id) == build.income_for_game(next.id)
		),
		"reload retains exact settled earnings"
	)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var poisoned: Dictionary = data.duplicate(true)
	for event: Dictionary in poisoned.build.events:
		if event.op == "reward" and event.game == next.id:
			event.performance = {}
	_check(SeasonSave._decode(poisoned) == null, "reject altered income evidence against result")
	poisoned = data.duplicate(true)
	poisoned.results.back().performance = {}
	_check(SeasonSave._decode(poisoned) == null, "reject missing completed-game statistics")
	_check(build.commit(_command(build, "open")).ok, "next legal sponsor shop")
	var active: Array = build.view().wallet.sponsors
	for receipt: Dictionary in active:
		_check(
			not SeasonSponsorCatalog.eligible(active).has(receipt.item),
			"active unique identities excluded from offers"
		)
	var receipt: Dictionary = active[0]
	var amount: int = build.cash()
	_check(
		build.commit(_command(build, "sponsor_sell", {"receipt": receipt.id})).ok,
		"sell exact paid sponsor"
	)
	_check(
		build.cash() == amount + floori(float(receipt.paid) / 2),
		"sale preserves already earned money and returns half actual paid"
	)
	_check(
		SeasonSave.save(season) and SeasonSave.restore() != null,
		"sale and historical income remain replayable"
	)
	# Final/playoff income uses the same completion contract but cannot open a final shop.
	while season.phase != SeasonState.Phase.COMPLETE:
		var fixture: Dictionary = season.pending_fixture()
		var rival: int = fixture.away if fixture.home == 0 else fixture.home
		var snapshot: Dictionary = _sample(season.teams[0].roster, season.teams[rival].roster)
		var prior: int = season.cash()
		_check(
			season.record_player_result(
				fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0, snapshot
			),
			"complete next season/playoff fixture"
		)
		_check(season.cash() == prior + 18 + 17, "sold walk sponsor cannot earn in later games")
	_check(not season.shop_available(), "final bonus creates no extra purchasing window")
	_check(
		SeasonSave.save(season) and SeasonSave.restore() != null,
		"complete sponsored season and playoffs replay"
	)
	_old_sponsor_migration(path)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _old_sponsor_migration(path: String) -> void:
	var season: SeasonState = SeasonState.create(_seed_for("MISC-BAT-01", 5), false, true)
	for _pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 5
	_record(season)
	season.build.commit(_command(season.build, "open"))
	season.build.commit(
		_command(
			season.build, "equip", {"offer": _offer(season.build, "MISC-BAT-01"), "replace": ""}
		)
	)
	var before: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save genuine paid schema9 Gear")
	var bytes: String = FileAccess.get_file_as_string(path)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == before,
		"schema10 migration preserves all paid items, cash and offers"
	)
	_check(FileAccess.get_file_as_string(path) == bytes, "loading alone does not rewrite")
	if restored != null:
		_check(restored.build.to_data().sponsor_from == 2, "sponsors become eligible next visit")
		season.build.commit(_command(season.build, "reroll"))
		restored.build.commit(_command(restored.build, "reroll"))
		_check(
			season.build.view().shop.offers == restored.build.view().shop.offers,
			"same-visit rerolls retain old generation"
		)
		_check(
			SeasonSave.save(restored) and SeasonSave.restore() != null,
			"migrated sponsor boundary replays"
		)
		_record(restored)
		restored.build.commit(_command(restored.build, "open"))
		_check(
			SeasonSave.save(restored) and SeasonSave.restore() != null,
			"new sponsor pool visit replays after migration"
		)


func _sponsor_ui(items: Dictionary = SeasonSponsorCatalog.ITEMS) -> void:
	for id: String in items:
		var prefix: String = "user://sponsor-ui-%s-%d" % [id, OS.get_process_id()]
		SeasonSave.path = prefix + ".json"
		PitchBatLabSettings.path = prefix + ".cfg"
		var app: SeasonApp = SeasonApp.new()
		add_child(app)
		await _frames()
		app.season = _funded_season(_sponsor_seed(id))
		_check(app._checkpoint(), "save before sponsor transaction")
		app.open_shop()
		await _frames()
		var window: SeasonShopWindow = _shop(app)
		await _shop_bounds(window, "sponsor-normal-" + id)
		window.size = Vector2i(700, 400)
		await _shop_bounds(window, "sponsor-small-" + id)
		if id == "B02":
			var found: bool = false
			for child: Node in window._body.get_children():
				if child is Label and child.text.contains("College eligibility now: 0 / 4"):
					found = true
			_check(found, "College offer discloses actual current qualification")
		var offer: String = _offer(app.season.build, id)
		var before: Dictionary = app.season.build.to_data()
		await _click(_sponsor_button(window, offer))
		_check(
			(
				window._review_text.text.contains(items[id].effect)
				and window._review_text.text.contains("Working")
			),
			"review states exact candidate income"
		)
		_check(
			window._confirm.gui_get_focus_owner() == window._confirm.get_cancel_button(),
			"sponsor confirmation defaults to Cancel"
		)
		_check(window._confirm.size.y <= window.size.y, "income review fits small window")
		await _capture(window._confirm, "sponsor-review-" + id)
		await _click(window._confirm.get_cancel_button())
		_check(app.season.build.to_data() == before, "cancellation spends nothing")
		var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
		SeasonSave.path = prefix + "/missing/save.json"
		await _click(_sponsor_button(window, offer))
		await _click(window._confirm.get_ok_button())
		_check(app.season.build.to_data() == before, "failed save rolls back sponsor and cash")
		SeasonSave.path = prefix + ".json"
		_check(
			FileAccess.get_file_as_string(SeasonSave.path) == bytes, "failed save preserves bytes"
		)
		await _click(_sponsor_button(window, offer))
		await _click(window._confirm.get_ok_button())
		var receipt: Dictionary = app.season.build.view().wallet.sponsors[0]
		_check(
			receipt.item == id and receipt.paid == items[id].price,
			"UI activation records full immutable paid receipt"
		)
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and restored.build.view() == app.season.build.view(),
			"paid active sponsor persists"
		)
		await _shop_bounds(window, "sponsor-active-" + id)
		await _click(window._back)
		app.season = restored
		app.play_season_game()
		await _frames(5)
		_check(app.lab != null, "sponsored team enters real game")
		var cash: int = app.season.cash()
		if app.lab != null:
			_check(
				not app.commit_shop(
					_command(app.season.build, "sponsor_sell", {"receipt": receipt.id})
				),
				"no live-game sponsor sale"
			)
			app.leave_game()
		_check(app.season.cash() == cash, "leaving unfinished game grants no income")
		app.open_shop()
		await _frames()
		window = _shop(app)
		await _click(_gear_button(window, "sponsor_sell", receipt.id))
		await _click(window._confirm.get_ok_button())
		_check(
			app.season.build.view().wallet.sponsors.is_empty(), "explicit sale removes active copy"
		)
		app.queue_free()
		await _frames()
		for file: String in [prefix + ".json", prefix + ".cfg"]:
			for suffix: String in ["", ".bak", ".tmp"]:
				DirAccess.remove_absolute(file + suffix)


func _sponsor_button(window: SeasonShopWindow, offer: String, replace: String = "") -> Button:
	for child in window._body.get_children():
		if child is Button and child.get_meta("sponsor_offer", "") == offer:
			if child.get_meta("sponsor_replace", "") == replace:
				return child
	return null


func _replacement_and_retry_ui() -> void:
	var prefix: String = "user://sponsor-replace-%d" % OS.get_process_id()
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _funded_season(_sponsor_seed("", 1, ["D01", "A08"]))
	_check(app._checkpoint(), "checkpoint before replacement")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _click(_sponsor_button(window, _offer(app.season.build, "D01")))
	await _click(window._confirm.get_ok_button())
	var receipt: Dictionary = app.season.build.view().wallet.sponsors[0]
	var offer: String = _offer(app.season.build, "A08")
	var before: Dictionary = app.season.build.to_data()
	_check(
		not (
			app
			. season
			. build
			. preview(_command(app.season.build, "sponsor_buy", {"offer": offer, "replace": ""}))
			. ok
		),
		"insufficient cash without explicit sale"
	)
	await _click(_sponsor_button(window, offer, receipt.id))
	_check(
		(
			window._review_text.text.contains("Cash: 10 → 2")
			and window._review_text.text.contains("Sell Take Your Base for 4")
		),
		"replacement discloses full purchase price and sale credit"
	)
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "replacement cancel retains original sponsor")
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = prefix + "/missing/save.json"
	await _click(_sponsor_button(window, offer, receipt.id))
	await _click(window._confirm.get_ok_button())
	_check(app.season.build.to_data() == before, "failed replacement rolls back sale and buy")
	SeasonSave.path = prefix + ".json"
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == saved, "failed replacement retains bytes"
	)
	await _click(_sponsor_button(window, offer, receipt.id))
	await _click(window._confirm.get_ok_button())
	var active: Array = app.season.build.view().wallet.sponsors
	_check(
		(
			active.size() == 1
			and active[0].item == "A08"
			and active[0].paid == 12
			and app.season.cash() == 2
		),
		"atomic replacement records full twelve, not net eight"
	)
	_check(
		not app.commit_shop(_command(app.season.build, "sponsor_sell", {"receipt": receipt.id})),
		"sold receipt cannot pay twice"
	)
	await _click(window._back)
	app.play_season_game()
	await _frames(5)
	var lab: PitchBatLab = app.lab
	_check(lab != null, "replacement enters match")
	if lab != null:
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		var state: MatchState = lab._match_state
		var own: Array = app.season.teams[0].roster
		var fixture: Dictionary = app.season.pending_fixture()
		var opponent: int = fixture.away if fixture.home == 0 else fixture.home
		state.performance.players = _sample(own, app.season.teams[opponent].roster)
		_check(not app._commit_result(), "unfinished state cannot pay despite provisional stats")
		state.home_team.runs = 1 if fixture.home == 0 else 0
		state.away_team.runs = 0 if fixture.home == 0 else 1
		state.phase = MatchState.Phase.GAME_END
		# State-flow fixture, separately complemented by a complete physical sponsor game.
		SeasonSave.path = prefix + "/missing/save.json"
		_check(not app._commit_result(), "failed completion write requires retry")
		_check(
			app._result_recorded and not app._result_saved and app.season.cash() == 28,
			"base18 plus earned8 recorded exactly once"
		)
		SeasonSave.path = prefix + ".json"
		_check(app._commit_result() and app._commit_result(), "retry and repeated Continue succeed")
		_check(
			app.season.cash() == 28 and app.season.player_results.size() == 2,
			"retry never duplicates bonus or result"
		)
		_check(
			SeasonSave.restore() != null and SeasonSave.restore().cash() == 28,
			"settled bonus survives final checkpoint"
		)
		app.leave_game()
		app.menu.show_last_game()
		await _menu_bounds(app, "sponsor-settled-income")
		var shown: int = 0
		for label in app.menu._body.find_children("*", "Label", true, false):
			if label.text == "Shift Crew: +8 Cash • Settled":
				shown += 1
		_check(shown == 1, "postgame displays the exact settled bonus once")
	app.queue_free()
	await _frames()
	for file: String in [prefix + ".json", prefix + ".cfg"]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(file + suffix)
