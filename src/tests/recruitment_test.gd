extends "res://src/tests/paid_shop_ui_test.gd"

const ROSTER: Array[String] = [
	"player.alex_finch", "player.rowan_chase", "player.nico_vega", "player.ari_banks"
]


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_catalog()
	_offer_lifecycle()
	_returning_player()
	_mastered_return()
	await _season_recruitment()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro recruitment checks passed: 144 profiles, paid returns, history, saves and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _catalog() -> void:
	var listed: Array = []
	for group: Dictionary in RecruitCatalog.GROUPS:
		for id: String in group.ids:
			_check(not listed.has(id), "one authored recruitment contract per identity")
			listed.append(id)
	_check(listed.size() == 48, "complete named catalogue")
	for id: String in SeasonPlayerCatalog.ids():
		var base: Dictionary = SeasonPlayerCatalog.profile(id)
		for index in range(3):
			var fresh: Dictionary = RecruitCatalog.fresh(id, RecruitCatalog.STAGES[index])
			_check(not fresh.is_empty(), "all 144 profiles exist")
			var total: int = 0
			var changed: int = 0
			for stat: String in SeasonPlayerCatalog.STATS:
				var delta: int = fresh.stats[stat] - base.stats[stat]
				total += delta
				changed += int(delta > 0)
				_check(delta >= 0 and fresh.stats[stat] <= 10, "preserve weaknesses and stat caps")
			_check(
				changed <= 2 and total >= [1, 2, 3][index] and total <= [1, 3, 5][index],
				"authored stage bands, not accumulated stage grants"
			)
			var mastery_steps: int = 0
			for recipe: String in fresh.active:
				_check(fresh.mastery[recipe] <= 3, "fresh incoming pitch cap3")
				mastery_steps += fresh.mastery[recipe] - base.mastery[recipe]
			_check(
				(
					mastery_steps == index
					if not RecruitCatalog.contract(id).pitch.is_empty()
					else mastery_steps == 0
				),
				"exact role mastery additions"
			)
			_check(
				fresh.active == base.active and fresh.capacity == base.capacity,
				"no free repertoire or capacity changes"
			)
			_check(
				(
					fresh.catchup.price >= [18, 22, 28][index]
					and fresh.catchup.price <= [22, 28, 36][index]
				),
				"authored price bands"
			)
	var alex: Dictionary = RecruitCatalog.fresh(ROSTER[0], "late")
	_check(
		alex.mastery["pitch.eephus"] == 3 and alex.mastery["pitch.overhand_four_seam"] == 2,
		"Alex's split mastery exception is exact"
	)
	var gray: Dictionary = RecruitCatalog.fresh("player.gray_west", "late")
	_check(
		(
			gray.stats == {"contact": 3, "power": 1, "fielding": 7, "pitching": 2}
			and gray.catchup.price == 28
		),
		"named late defender matches source"
	)
	var morgan: Dictionary = RecruitCatalog.fresh("player.morgan_pike", "late")
	_check(
		(
			morgan.stats == {"contact": 2, "power": 1, "fielding": 4, "pitching": 6}
			and morgan.mastery["pitch.sidearm_slider"] == 3
			and morgan.catchup.price == 32
		),
		"named late breaking specialist matches source"
	)


func _at_visit(
	seed_value: int, visit: int, pool: Array[String] = [], blocked: Array[String] = []
) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER, pool, blocked)
	for game in range(visit):
		_check(
			build.commit(_command(build, "reward", {"game": game, "win": true})).ok, "fund fixture"
		)
	_check(build.commit(_command(build, "open")).ok, "open fixture visit")
	return build


func _offer_lifecycle() -> void:
	for visit in range(1, 8):
		_check(
			(
				RecruitCatalog.appearance_chance(visit, false)
				== (0.0 if visit > 6 else (0.5 if visit >= 5 else 0.25))
			),
			"conditional late protection"
		)
		_check(
			RecruitCatalog.appearance_chance(visit, true) == (0.0 if visit > 6 else 0.25),
			"appearance, not purchase, removes late protection"
		)
	var blocked: Array[String] = ["player.morgan_pike", "player.gray_west"]
	for seed_value in range(24):
		var build: SeasonBuild = _at_visit(seed_value, 3, [], blocked)
		var offer: Dictionary = build.view().shop.recruit
		_check(
			offer.is_empty() or (not ROSTER.has(offer.player) and not blocked.has(offer.player)),
			"no duplicate current-club or active-opponent identities"
		)
		var data: Dictionary = build.to_data()
		var frozen: Array = data.recruits.duplicate(true)
		_check(build.commit(_command(build, "reroll")).ok, "reroll ordinary stock")
		_check(
			build.view().shop.recruit == offer and build.to_data().recruits == frozen,
			"ordinary rerolls preserve the exact recruit"
		)
		var loaded: SeasonBuild = SeasonBuild.from_data(
			_json(build.to_data()), seed_value, ROSTER, [], blocked
		)
		_check(loaded != null and loaded.view() == build.view(), "exact saved offer restores")
		var encounter: SeasonBuild = loaded
		if not offer.is_empty():
			var sign: Dictionary = _command(
				build, "sign", {"offer": offer.id, "replace": ROSTER[0]}
			)
			var invalid: Dictionary = sign.duplicate(true)
			invalid.replace = blocked[0]
			_reject_build(build, invalid, "cannot release an opponent")
			invalid = sign.duplicate(true)
			invalid.price = 0
			_reject_build(build, invalid, "quote cannot be overridden")
			var before: Dictionary = _snapshot(build)
			_check(build.preview(sign).ok and _snapshot(build) == before, "sign preview is inert")
			_check(build.commit(sign).ok, "complete fixed-price signing")
			_check(
				build.roster().has(offer.player) and not build.roster().has(ROSTER[0]),
				"exact replacement"
			)
			_check(build.cash() == 54 - 4 - offer.price, "release pays zero; full fee charged")
			_check(build.player(offer.player) == offer.profile, "incoming profile equals the quote")
			_check(build.commit(sign).replayed, "duplicate confirmation is inert")
			loaded = SeasonBuild.from_data(_json(build.to_data()), seed_value, ROSTER, [], blocked)
			_check(
				loaded != null and _snapshot(loaded) == _snapshot(build),
				"signed roster and growth reload"
			)
			if loaded != null:
				_check(loaded.commit(sign).replayed, "signing replay stays inert after reload")
			data.recruits[0].offer.price = 0
			_check(
				SeasonBuild.from_data(data, seed_value, ROSTER, [], blocked) == null,
				"tampered persisted quote fails closed"
			)
		if encounter != null:
			for game in [3, 4]:
				encounter.commit(_command(encounter, "reward", {"game": game, "win": true}))
			encounter.commit(_command(encounter, "open"))
			_check(
				encounter.to_data().recruits.back().chance == (0.5 if offer.is_empty() else 0.25),
				"saved appearance history controls late protection, even without a purchase"
			)
	var empty_pool: SeasonBuild = _at_visit(4, 5, ROSTER)
	_check(
		empty_pool.view().shop.recruit.is_empty(),
		"no recruit when all eligible identities are owned"
	)
	var late: SeasonBuild = _at_visit(8, 7)
	_check(late.view().shop.recruit.is_empty(), "Game7 cannot generate a recruit")
	var pool: Array[String] = ROSTER.duplicate()
	pool.append("player.bailey_quinn")
	var checked_poor: bool = false
	for seed_value in range(40):
		var poor: SeasonBuild = _at_visit(seed_value, 1, pool)
		if poor.view().shop.recruit.is_empty():
			continue
		_reject_build(
			poor,
			_command(poor, "sign", {"offer": poor.view().shop.recruit.id, "replace": ROSTER[0]}),
			"unaffordable recruit remains offered"
		)
		checked_poor = true
		break
	_check(checked_poor, "unaffordable appearance fixture exercised")


func _returning_player() -> void:
	var pool: Array[String] = ROSTER.duplicate()
	pool.append("player.gray_west")
	var exercised: bool = false
	for seed_value in range(400):
		var build: SeasonBuild = _at_visit(seed_value, 1, pool)
		var upgraded: bool = false
		for key: String in build.view().shop.offers:
			var id: String = build.view().shop.offers[key]
			if not DevelopmentShopCatalog.CARDS.has(id):
				continue
			for target: Dictionary in build.targets(id):
				if target.player == ROSTER[0]:
					var buy: Dictionary = _command(build, "buy", {"offer": key, "mode": "use"})
					buy.merge(target)
					upgraded = build.commit(buy).ok
					break
			if upgraded:
				break
		var developed: Dictionary = build.player(ROSTER[0])
		build.commit(_command(build, "reward", {"game": 1, "win": true}))
		build.commit(_command(build, "open"))
		var offer: Dictionary = build.view().shop.recruit
		if not upgraded or offer.is_empty():
			continue
		_check(
			build.commit(_command(build, "sign", {"offer": offer.id, "replace": ROSTER[0]})).ok,
			"release developed original player"
		)
		_check(
			build.targets("development.contact").all(
				func(t: Dictionary) -> bool: return t.player != ROSTER[0]
			),
			"released records are not an owned reserve"
		)
		build.commit(_command(build, "reward", {"game": 2, "win": true}))
		build.commit(_command(build, "open"))
		offer = build.view().shop.recruit
		if offer.is_empty():
			continue
		_check(
			offer.returning and offer.player == ROSTER[0] and offer.price == 22,
			"drafted player's immutable early reference is reused at a later stage"
		)
		_check(offer.profile == developed, "return quotes actual retained state")
		var command: Dictionary = _command(
			build, "sign", {"offer": offer.id, "replace": "player.gray_west"}
		)
		_check(build.commit(command).ok, "legal paid return")
		_check(
			build.player(ROSTER[0]) == developed and not build.player(ROSTER[0]).has("catchup"),
			"return grants neither stage additions nor free draft catch-up"
		)
		var restored: SeasonBuild = SeasonBuild.from_data(
			_json(build.to_data()), seed_value, ROSTER, pool
		)
		_check(
			restored != null and _snapshot(restored) == _snapshot(build),
			"return history is replayable"
		)
		var retained_gray: Dictionary = build.player("player.gray_west")
		build.commit(_command(build, "reward", {"game": 3, "win": true}))
		build.commit(_command(build, "open"))
		offer = build.view().shop.recruit
		if offer.is_empty():
			continue
		_check(
			offer.player == "player.gray_west" and offer.returning and offer.price == 18,
			"recruited player's first full contract stays fixed at a later stage"
		)
		_check(offer.profile == retained_gray, "released fresh recruit is never regenerated")
		_check(
			build.commit(_command(build, "sign", {"offer": offer.id, "replace": ROSTER[0]})).ok,
			"recruited player can legally return at the first fee"
		)
		_check(
			build.player("player.gray_west") == retained_gray,
			"second signing does not grant another catch-up step"
		)
		exercised = true
		break
	_check(exercised, "seeded paid release/return path exercised")


func _mastered_return() -> void:
	var pool: Array[String] = ROSTER.duplicate()
	pool.append("player.gray_west")
	var exercised: bool = false
	for seed_value in range(1200):
		var build: SeasonBuild = _at_visit(seed_value, 1, pool)
		for visit in range(1, 4):
			if visit > 1:
				build.commit(_command(build, "reward", {"game": visit - 1, "win": true}))
				build.commit(_command(build, "open"))
			for key: String in build.view().shop.offers:
				if (
					build.view().shop.offers[key] == "development.mastery"
					and build.player(ROSTER[0]).mastery["pitch.eephus"] < 4
				):
					_check(
						(
							build
							. commit(
								_command(
									build,
									"buy",
									{
										"offer": key,
										"mode": "use",
										"player": ROSTER[0],
										"pitch": "pitch.eephus",
										"replace": ""
									}
								)
							)
							. ok
						),
						"mastery is genuinely bought from available stock"
					)
		var offer: Dictionary = build.view().shop.recruit
		if offer.is_empty() or build.player(ROSTER[0]).mastery["pitch.eephus"] != 4:
			continue
		_check(
			build.commit(_command(build, "sign", {"offer": offer.id, "replace": ROSTER[0]})).ok,
			"release legitimately mastered player"
		)
		build.commit(_command(build, "reward", {"game": 3, "win": true}))
		build.commit(_command(build, "open"))
		offer = build.view().shop.recruit
		if offer.is_empty():
			continue
		_check(
			offer.returning and offer.profile.mastery["pitch.eephus"] == 4,
			"fresh pitch cap3 cannot downgrade a returning earned level4"
		)
		_check(
			(
				build
				. commit(
					_command(build, "sign", {"offer": offer.id, "replace": "player.gray_west"})
				)
				. ok
			),
			"pay original fee for mastered return"
		)
		var restored: SeasonBuild = SeasonBuild.from_data(
			_json(build.to_data()), seed_value, ROSTER, pool
		)
		_check(
			restored != null and restored.player(ROSTER[0]).mastery["pitch.eephus"] == 4,
			"earned returning mastery survives file-style replay"
		)
		exercised = true
		break
	_check(exercised, "earned above-fresh-cap return fixture exercised")


func _season_recruitment() -> void:
	var prefix: String = "user://recruitment-%d" % OS.get_process_id()
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	for seed_value in range(40):
		app.season = SeasonState.create(seed_value, false, true)
		for _pick in range(4):
			app.season.choose_player(app.season.offers()[0])
		_record(app.season)
		_record(app.season)
		app.season.build.commit(_command(app.season.build, "open"))
		if not app.season.build.view().shop.recruit.is_empty():
			break
	var offer: Dictionary = app.season.build.view().shop.recruit
	_check(not offer.is_empty(), "real season recruit fixture")
	if offer.is_empty():
		app.queue_free()
		return
	app.season.swap_batters(0, 2)
	for key: String in app.season.build.view().shop.offers:
		if DevelopmentShopCatalog.CARDS.has(app.season.build.view().shop.offers[key]):
			_check(
				app.commit_shop(
					_command(
						app.season.build,
						"buy",
						{"offer": key, "mode": "hold", "player": "", "pitch": "", "replace": ""}
					)
				),
				"buy a team-held card before signing"
			)
			break
	_check(app._checkpoint(), "persist reordered lineup and offer")
	var before: Dictionary = _snapshot(app.season.build)
	var old_lineup: Array = app.season.teams[0].roster.duplicate()
	var departing: String = old_lineup[2]
	var starter: int = app.season.starter_index
	var fielder: int = app.season.fielder_index
	app.show_season()
	app.open_shop()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "recruit-shop-narrow")
	await _click(_button(window._body, "REVIEW RECRUIT REPLACEMENT"))
	await _shop_bounds(window, "recruit-compare-narrow")
	await _click(_replacement(window, departing))
	_check(window._pending.replace == departing, "exact clicked departure reaches confirmation")
	await _capture(window._confirm, "recruit-confirmation")
	await _click(window._confirm.get_cancel_button())
	_check(_snapshot(app.season.build) == before, "cancel leaves money and both players untouched")
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = prefix + "/missing/season.json"
	await _click(_replacement(window, departing))
	await _click(window._confirm.get_ok_button())
	_check(
		_snapshot(app.season.build) == before and app.season.teams[0].roster == old_lineup,
		"failed save rolls back fee, signing and actual lineup"
	)
	SeasonSave.path = prefix + ".json"
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == saved,
		"failed signing preserves saved bytes"
	)
	await _click(_button(window._body, "REVIEW RECRUIT REPLACEMENT"))
	await _click(_replacement(window, departing))
	await _click(window._confirm.get_ok_button())
	_check(
		(
			app.season.teams[0].roster[2] == offer.player
			and app.season.cash() == before.view.wallet.cash - offer.price
		),
		"actual UI signs into the chosen batting position"
	)
	_check(
		(
			app.season.build.view().wallet.held == before.view.wallet.held
			and before.view.wallet.held.size() == 1
		),
		"team-held receipt survives roster replacement"
	)
	_check(
		app.season.starter_index == starter and app.season.fielder_index == fielder,
		"replacement inherits the chosen lineup slot's defensive assignment"
	)
	await _click(window._back)
	var loaded: SeasonState = SeasonSave.restore()
	_check(
		loaded != null and loaded.teams[0].roster == app.season.teams[0].roster,
		"roster changes restore with paid state"
	)
	if loaded == null:
		app.queue_free()
		return
	app.season = loaded
	app.play_season_game()
	await _frames(5)
	_check(app.lab != null, "recruited team launches an actual match")
	if app.lab != null:
		var own: TeamMatchState = (
			app.lab._match_state.home_team
			if app.lab._player_home
			else app.lab._match_state.away_team
		)
		_check(
			(
				String(own.roster[2].definition.id) == offer.player
				and own.roster[2].definition.power == offer.profile.stats.power
			),
			"live match receives the exact paid recruit at the correct position"
		)
		app.leave_game()
	_record(app.season)
	_check(app._checkpoint(), "save a result from the changed roster")
	loaded = SeasonSave.restore()
	_check(loaded != null, "old and new roster performance histories load together")
	_check(
		SeasonPerformance.totals(app.season)[departing].h == 2,
		"former player's earned hits stay in club totals"
	)
	var data: Dictionary = _json(JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path)))
	var first: Dictionary = data.results[0].performance
	first[offer.player] = first[departing]
	first.erase(departing)
	_check(
		SeasonSave._decode(data) == null, "future recruit cannot be substituted into an old game"
	)
	app.menu.show_stats()
	await _menu_bounds(app, "recruit-former-player-stats")
	_legacy_migration(app.season.season_seed)
	app.queue_free()
	await _frames()
	for path: String in [prefix + ".json", prefix + ".cfg"]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)


func _legacy_migration(seed_value: int) -> void:
	var season: SeasonState = SeasonState.create(seed_value, false, true)
	for _pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 1
	_record(season)
	season.build.commit(_command(season.build, "open"))
	for key: String in season.build.view().shop.offers:
		if DevelopmentShopCatalog.CARDS.has(season.build.view().shop.offers[key]):
			_check(
				(
					season
					. build
					. commit(
						_command(
							season.build,
							"buy",
							{"offer": key, "mode": "hold", "player": "", "pitch": "", "replace": ""}
						)
					)
					. ok
				),
				"legacy fixture owns a genuinely paid held card"
			)
			break
	_check(
		season.build.commit(_command(season.build, "pack_open")).ok,
		"legacy fixture has a paid unresolved pack"
	)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.version = 5
	data.picks = season.picks
	data.lineup = season.teams[0].roster
	data.results = season.player_results
	data.starter = season.starter_index
	data.fielder = season.fielder_index
	data.build = season.build.to_data()
	var old_view: Dictionary = season.build.view()
	var restored: SeasonState = SeasonSave._decode(_json(data))
	_check(
		restored != null and restored.build.view() == old_view,
		"schema5 migration leaves saved stock intact"
	)
	if restored != null:
		_check(
			restored.build.to_data().recruit_from == 2,
			"migration enables recruiting only from next visit"
		)
		_check(
			SeasonSave.save(restored) and SeasonSave.restore() != null, "migrated schema6 is stable"
		)


func _record(season: SeasonState) -> void:
	var fixture: Dictionary = season.pending_fixture()
	var stats: Dictionary = {}
	for index: int in [fixture.home, fixture.away]:
		for id: String in season.teams[index].roster:
			stats[id] = MatchPerformance.empty_line()
	var opponent: int = fixture.away if fixture.home == 0 else fixture.home
	var batter: String = season.teams[0].roster[0]
	stats[batter].h = 1
	stats[batter].pa = 1
	stats[season.teams[opponent].roster[0]].p_h = 1
	_check(
		season.record_player_result(
			fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0, stats
		),
		"retained roster performance fixture"
	)


func _replacement(window: SeasonShopWindow, id: String) -> Button:
	for child in window._body.get_children():
		if child is Button and child.get_meta("recruit_replace", "") == id:
			return child
	return null


func _command(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var command: Dictionary = {
		"id": "recruit-test:%d" % build.revision(), "rev": build.revision(), "op": op
	}
	command.merge(fields)
	return command


func _snapshot(build: SeasonBuild) -> Dictionary:
	var players: Dictionary = {}
	for id: String in SeasonPlayerCatalog.ids():
		players[id] = build.player(id)
	return {"data": build.to_data(), "view": build.view(), "players": players}


func _reject_build(build: SeasonBuild, command: Dictionary, message: String) -> void:
	var before: Dictionary = _snapshot(build)
	_check(not build.commit(command).ok and before == _snapshot(build), message)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))
