extends "res://src/tests/season_tactical_sponsors_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_budget_contracts()
	_budget_migration()
	await _sponsor_ui(SeasonSponsorCatalog.BUDGET_ITEMS)
	await _budget_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Budget Bites checks passed: committed grant, no farming, paid UI and replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _budget_contracts() -> void:
	for cash_value: int in [0, 4, 5]:
		for held_count in range(3):
			var build: SeasonBuild = _unit_build(["E08"])
			for slot in range(held_count):
				var id: String = DevelopmentShopCatalog.CARDS.keys()[0]
				_check(
					(
						build
						. commit(
							_command(
								build,
								"buy",
								{
									"offer": _unit_offer(build, id),
									"mode": "hold",
									"player": "",
									"pitch": "",
									"replace": ""
								}
							)
						)
						. ok
					),
					"shared development inventory"
				)
			build._charge(build.cash() - cash_value)
			var before: Dictionary = build.view()
			var command: Dictionary = _command(build, "pregame", {"game": 5})
			_check(
				build.preview(command).ok and build.view() == before,
				"pregame preview has no side effects"
			)
			_check(build.commit(command).ok, "record first commitment even if no grant")
			var after: Dictionary = build.view()
			var expected: int = 1 if cash_value <= 4 and held_count < 2 else 0
			_check(
				build.cash() == cash_value and after.wallet.held.size() == held_count + expected,
				"Cash threshold and shared capacity"
			)
			if expected == 1:
				_check(
					(
						after.wallet.held[-1]
						== {"id": "budget:5", "item": "C03", "paid": 0, "kind": "held"}
					),
					"exact zero-cost ordinary Plan"
				)
			_check(
				build.commit(command).replayed and build.view() == after, "exact retry idempotent"
			)
			_check(
				(
					not build.commit(_command(build, "pregame", {"game": 5})).ok
					and build.view() == after
				),
				"different request cannot grant again"
			)
			if not after.wallet.held.is_empty():
				build.commit(_command(build, "discard", {"receipt": after.wallet.held[0].id}))
			build._charge(build.cash())
			before = build.view()
			_check(
				(
					not build.commit(_command(build, "pregame", {"game": 5})).ok
					and build.view() == before
				),
				"later space or spending never queues grant"
			)
	var build: SeasonBuild = _unit_build([])
	_check(
		(
			build.commit(_command(build, "pregame", {"game": 5})).ok
			and build.view().wallet.held.is_empty()
		),
		"no sponsor no grant"
	)
	_check(build._pregames["5"].outcome == "inactive", "first commitment recorded without sponsor")
	_check(
		(
			build
			. commit(
				_command(build, "sponsor_buy", {"offer": _unit_offer(build, "E08"), "replace": ""})
			)
			. ok
		),
		"late Budget purchase"
	)
	build._charge(build.cash())
	_check(
		(
			not build.commit(_command(build, "pregame", {"game": 5})).ok
			and build.view().wallet.held.is_empty()
		),
		"buying sponsor after first commitment cannot grant retroactively"
	)
	for patch: Dictionary in [
		{"game": 4}, {"game": -1}, {"game": 33}, {"game": 6, "cash": 0}, {"game": 6, "item": "A10"}
	]:
		var before: Dictionary = build.view()
		_check(
			not build.commit(_command(build, "pregame", patch)).ok and build.view() == before,
			"completed fixture and client overrides rejected"
		)
	build = _unit_build(["E08", "J07"])
	build._charge(build.cash())
	build.commit(_command(build, "pregame", {"game": 5}))
	_check(
		(
			build
			. commit(_command(build, "tactical_exchange", {"receipt": "budget:5", "item": "A10"}))
			. ok
		),
		"ordinary generated Plan can exchange"
	)
	_check(
		build.cash() == 0 and build.view().wallet.held[0].item == "A10",
		"no cash or duplicate from exchange"
	)

	_check(
		build.commit(_command(build, "reward", {"game": 5, "win": false, "performance": {}})).ok,
		"complete committed controlled fixture"
	)
	build.commit(_command(build, "open"))
	build._charge(build.cash())
	_check(
		(
			build.commit(_command(build, "pregame", {"game": 6})).ok
			and build.view().wallet.held.size() == 2
		),
		"new completed-game boundary permits one new grant beside carried supply"
	)


func _paid_budget() -> SeasonState:
	var season: SeasonState = _funded_season(_sponsor_seed("E08", 3), 3)
	_check(
		(
			season
			. build
			. commit(
				_command(
					season.build,
					"sponsor_buy",
					{"offer": _offer(season.build, "E08"), "replace": ""}
				)
			)
			. ok
		),
		"actual paid Budget Bites"
	)
	for roll in range(5):
		_check(
			season.build.commit(_command(season.build, "reroll")).ok,
			"real paid spending before commitment"
		)
	_check(season.cash() == 4, "54 earned minus10 sponsor minus40 rerolls =4")
	return season


func _budget_migration() -> void:
	SeasonSave.path = "user://budget-migrate-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(_seed_for("J07", 16), false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 16
	_record(season)
	season.build.commit(_command(season.build, "open"))
	_check(
		(
			season
			. build
			. commit(
				_command(
					season.build,
					"sponsor_buy",
					{"offer": _offer(season.build, "J07"), "replace": ""}
				)
			)
			. ok
		),
		"actual old paid Pick & Mix"
	)
	_check(SeasonSave.save(season), "schema20 checkpoint")
	var before: Dictionary = season.build.view()
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == before and restored.build._budget_from == 2,
		"old stock and no retroactive grants"
	)
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		season.build.view().shop.offers == restored.build.view().shop.offers,
		"old same-visit rerolls"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		(
			SeasonSponsorCatalog.catalog(restored.build._sponsor_catalog_version()).has("E08")
			and SeasonSave.save(restored)
			and SeasonSave.restore() != null
		),
		"Budget pool next visit replays"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _budget_ui() -> void:
	SeasonSave.path = "user://budget-ui-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _paid_budget()
	_check(app._checkpoint(), "save qualifying paid sponsor and Cash")
	var before: Dictionary = app.season.build.view()
	app.menu.show_lineup()
	await _frames()
	_check(
		_budget_label(app).text.contains("one free Swing Plan"), "pregame reviews grant before play"
	)
	await _menu_bounds(app, "budget-pregame")
	await _click(_button(app.menu, "SEASON HUB"))
	app.menu.show_lineup()
	await _frames()
	_check(app.season.build.view() == before, "open/back/reopen creates nothing")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_button(app.menu, "PLAY GAME"))
	_check(
		app.lab == null and app.season.build.view() == before,
		"failed pregame save rolls back grant and check flag"
	)
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "prior snapshot intact")
	app.menu.show_lineup()
	await _frames()
	await _click(_button(app.menu, "PLAY GAME"))
	_check(
		app.lab != null and app.season.build.view().wallet.held.size() == 1,
		"Play commits Plan before opening match"
	)
	var game: int = int(app.season.pending_fixture().id)
	var after: Dictionary = app.season.build.view()
	_check(
		(
			after.wallet.held[0].id == "budget:%d" % game
			and app.lab._match_state.home_team.tactics.held == after.wallet.held
		),
		"exact grant supplied to paid home club"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == after,
		"committed pregame copy and flag persisted"
	)
	app.leave_game()
	await _frames()
	app.menu.show_lineup()
	await _frames()
	_check(_budget_label(app).text.contains("No new grant on restart"), "restart status visible")
	await _click(_button(app.menu, "PLAY GAME"))
	_check(app.season.build.view() == after, "unfinished restart cannot accumulate")
	app.leave_game()
	await _frames()
	app.season = restored
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	await _click(_button(window, "DISCARD Swing Plan"))
	await _click(window._confirm.get_ok_button())
	_check(
		app.season.build.view().wallet.held.is_empty() and app.season.cash() == 4,
		"ordinary explicit discard has zero refund"
	)
	await _click(window._back)
	app.menu.show_lineup()
	await _frames()
	await _click(_button(app.menu, "PLAY GAME"))
	_check(app.season.build.view().wallet.held.is_empty(), "discard/restart cannot regenerate")
	app.leave_game()
	await _frames()
	# Pure creation/exhibition does not commit a season grant.
	before = app.season.build.view()
	app.season.make_match()
	app.play_exhibition()
	await _frames(3)
	_check(app.season.build.view() == before, "exhibition and model creation cannot grant")
	app.leave_game()
	await _frames()
	# Reject a structurally valid commitment for a different pending fixture.
	bytes = FileAccess.get_file_as_string(path)
	var foreign: SeasonState = _paid_budget()
	_check(
		foreign.build.commit(_command(foreign.build, "pregame", {"game": 32})).ok,
		"controlled foreign-fixture journal"
	)
	_check(
		not SeasonSave.save(foreign) and FileAccess.get_file_as_string(path) == bytes,
		"save binds pregame to actual fixture order"
	)
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _budget_label(app: SeasonApp) -> Label:
	for child: Node in app.menu._body.find_children("*", "Label", true, false):
		if child.has_meta("budget_preview"):
			return child
	return null
