extends "res://src/tests/season_sponsor_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_usage_boundaries()
	_transactions()
	_replacement_and_edge_contracts()
	_migration()
	await _credit_ui()
	await _sponsor_ui(SeasonSponsorCatalog.SHOP_ITEMS)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Reclamation checks passed: exact copies, credits, rollback, UI and migration."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _reclamation_season() -> SeasonState:
	for seed_value in range(3000):
		var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER)
		for game in range(3):
			build.commit(_command(build, "reward", {"game": game, "win": true}))
		build.commit(_command(build, "open"))
		if _offer(build, "F05").is_empty():
			continue
		var gear: Dictionary = {}
		for id: String in build.view().shop.offers.values():
			var item: Dictionary = SeasonGearCatalog.item(id)
			if not item.is_empty():
				gear[item.slot] = id
		if gear.size() < 2:
			continue
		var season: SeasonState = _funded_season(seed_value, 3)
		build = season.build
		_check(
			(
				build
				. commit(
					_command(build, "sponsor_buy", {"offer": _offer(build, "F05"), "replace": ""})
				)
				. ok
			),
			"buy real Reclamation"
		)
		# This fixture promises exactly two paid copies, even if all three slots appear.
		for id: String in gear.values().slice(0, 2):
			_check(
				(
					build
					. commit(_command(build, "equip", {"offer": _offer(build, id), "replace": ""}))
					. ok
				),
				"buy real Gear in distinct slots"
			)
		return season
	_check(false, "reachable paid Reclamation and Gear fixture")
	return null


func _complete_used(season: SeasonState) -> void:
	var state: MatchState = season.make_match()
	state.begin_pitch()
	state.note_pitch_released(&"pitch.overhand_four_seam", 6.0)
	var game: Dictionary = season.pending_fixture()
	var rival: int = game.away if game.home == 0 else game.home
	_check(
		season.record_player_result(
			game.id,
			0 if game.home == 0 else 1,
			1 if game.home == 0 else 0,
			_sample(season.teams[0].roster, season.teams[rival].roster),
			state.gear_usage.first_pitch
		),
		"controlled completed game carries first-release receipts"
	)
	_check(season.build.commit(_command(season.build, "open")).ok, "open next visit")


func _usage_boundaries() -> void:
	var season: SeasonState = _reclamation_season()
	var state: MatchState = season.make_match()
	var ids: Array[String] = SeasonReclamation.receipts(season.build.view().wallet)
	_check(ids.size() == 2 and state.gear_usage.first_pitch.is_empty(), "pregame is not use")
	state.begin_pitch()
	state.cancel_pitch()
	state.note_pitch_released(&"pitch.overhand_four_seam", 0.0)
	_check(not state.gear_usage.started, "canceled release cannot qualify")
	state.begin_pitch()
	state.note_pitch_released()
	_check(not state.gear_usage.started, "legacy recipe-less notification grants no use")
	state.note_pitch_released(&"pitch.overhand_four_seam", 0.0)
	_check(state.gear_usage.first_pitch == ids, "first actual release captures exact paid receipts")
	state.gear_usage.equipped.clear()
	state.note_pitch_released(&"pitch.overhand_slider", 1.0)
	_check(state.gear_usage.first_pitch == ids, "later changes cannot overwrite first snapshot")
	_check(season.build.view().used_gear.is_empty(), "unfinished play never marks seasonal use")
	_check(season.make_match().gear_usage.first_pitch.is_empty(), "abandon/restart has no evidence")
	var receipt: Dictionary = SeasonOwnership._owned(season.build.view().wallet, ids[0])
	var before: int = season.cash()
	_check(
		season.build.commit(_command(season.build, "sell_gear", {"receipt": receipt.id})).ok,
		"unused purchased Gear still sells normally"
	)
	_check(
		(
			season.cash() == before + floori(float(receipt.paid) / 2)
			and SeasonReclamation.credit(season.build.view().shop) == 0
		),
		"unused sale earns no credit"
	)
	for bad: Variant in [["foreign"], [ids[1], ids[1]], ids, "invalid"]:
		var command: Dictionary = _command(
			season.build, "reward", {"game": 9, "win": true, "performance": {}, "used_gear": bad}
		)
		var old: Dictionary = season.build.to_data()
		_check(
			not season.build.commit(command).ok and season.build.to_data() == old,
			"invalid, duplicate, mismatched or score-only evidence rejected atomically"
		)


func _transactions() -> void:
	var season: SeasonState = _reclamation_season()
	_complete_used(season)
	var build: SeasonBuild = season.build
	_check(build.view().used_gear.size() == 2, "completed game qualifies both exact copies")
	SeasonSave.path = "user://reclamation-%d.json" % OS.get_process_id()
	_check(SeasonSave.save(season), "save completed receipt evidence")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == build.view(), "derived use replays exactly"
	)
	for played: Dictionary in restored.results:
		if played.id == restored.player_results[-1].id:
			_check(
				played.used_gear == restored.player_results[-1].used_gear,
				"season history and player result retain the same receipt evidence"
			)
	var tampered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	tampered.results[-1].used_gear = []
	_check(SeasonSave._decode(tampered) == null, "result and journal usage cannot disagree")
	tampered = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for event: Dictionary in tampered.build.events:
		if event.has("used_gear"):
			event.used_gear = ["foreign-copy"]
	_check(SeasonSave._decode(tampered) == null, "foreign receipt evidence cannot replay")
	var ids: Array = build.view().used_gear
	var receipt: Dictionary = SeasonOwnership._owned(build.view().wallet, ids[0])
	var command: Dictionary = _command(build, "sell_gear", {"receipt": receipt.id})
	var preview: Dictionary = build.preview(command)
	_check(
		(
			SeasonReclamation.credit(preview.after.shop) == 2
			and SeasonReclamation.credit(build.view().shop) == 0
		),
		"preview cannot award live credit"
	)
	var cash_before: int = build.cash()
	_check(build.commit(command).ok, "sell exact used copy")
	_check(build.cash() == cash_before + floori(float(receipt.paid) / 2), "credit is never Cash")
	_check(
		build.commit(command).replayed and SeasonReclamation.credit(build.view().shop) == 2,
		"retry cannot stack sale or credit"
	)
	var fork: SeasonBuild = build._fork()
	var sponsor: Dictionary = fork.view().wallet.sponsors[0]
	_check(
		fork.commit(_command(fork, "sponsor_sell", {"receipt": sponsor.id})).ok,
		"sell sponsor after award"
	)
	_check(
		SeasonReclamation.credit(fork.view().shop) == 2 and fork.view().shop.reclamation_used,
		"sale retains credit and once-visit flag"
	)
	_check(fork.commit(_command(fork, "leave_shop")).ok, "explicit shop departure")
	_check(
		SeasonReclamation.credit(fork.view().shop) == 0 and fork.view().shop.reclamation_used,
		"leaving expires credit without renewing allowance"
	)
	_check(SeasonSave.save(season), "save awarded credit")
	restored = SeasonSave.restore()
	_check(
		restored != null and SeasonReclamation.credit(restored.build.view().shop) == 2,
		"reload preserves earned unspent credit"
	)
	var pack: Array = build._visit.cards.duplicate()
	var recruit: Dictionary = build.view().shop.get("recruit", {}).duplicate(true)
	cash_before = build.cash()
	_check(build.commit(_command(build, "reroll")).ok, "redeem on ordinary paid reroll")
	_check(
		(
			build.cash() == cash_before - 2
			and build.view().shop.rerolls == 1
			and SeasonReclamation.credit(build.view().shop) == 0
		),
		"first base4 costs2 Cash; credit consumed once"
	)
	_check(
		build._visit.cards == pack and build.view().shop.get("recruit", {}) == recruit,
		"pack and recruiting never refresh"
	)
	_check(
		build.commit(_command(build, "sell_gear", {"receipt": ids[1]})).ok,
		"sell second qualified copy"
	)
	_check(SeasonReclamation.credit(build.view().shop) == 0, "second sale cannot re-award")
	cash_before = build.cash()
	_check(
		build.commit(_command(build, "reroll")).ok and build.cash() == cash_before - 6,
		"ordinary escalating base price remains6"
	)
	_check(SeasonSave.save(season) and SeasonSave.restore() != null, "consumed flag replays")
	_record(season)
	_check(
		(
			build.commit(_command(build, "open")).ok
			and not build.view().shop.get("reclamation_used", false)
		),
		"next visit renews allowance"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _credit_ui() -> void:
	var prefix: String = "user://reclamation-ui-%d" % OS.get_process_id()
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _reclamation_season()
	await _complete_through_app(app)
	_check(app._checkpoint(), "checkpoint before sale UI")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var receipt: String = app.season.build.view().used_gear[0]
	await _click(_gear_button(window, "gear_sell", receipt))
	_check(
		(
			window._review_text.text.contains("Reroll credit: 0 → 2")
			and window._review_text.text.contains("separate from Cash")
		),
		"review separates sale and credit"
	)
	await _shop_bounds(window, "reclamation-sale")
	await _click(window._confirm.get_cancel_button())
	_check(SeasonReclamation.credit(app.season.build.view().shop) == 0, "cancel grants nothing")
	var before: Dictionary = app.season.build.to_data()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = prefix + "/missing/save.json"
	await _click(_gear_button(window, "gear_sell", receipt))
	await _click(window._confirm.get_ok_button())
	_check(app.season.build.to_data() == before, "failed save rolls back sale and credit")
	SeasonSave.path = prefix + ".json"
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == bytes, "failed save preserves old bytes"
	)
	await _click(_gear_button(window, "gear_sell", receipt))
	await _click(window._confirm.get_ok_button())
	_check(
		SeasonReclamation.credit(app.season.build.view().shop) == 2, "confirmed sale awards credit"
	)
	await _click(_button(window, "Reroll individual offers", true))
	_check(
		window._review_text.text.contains("Base price 4; credit 2"),
		"reroll discloses base and credit"
	)
	await _click(window._confirm.get_cancel_button())
	_check(
		SeasonReclamation.credit(app.season.build.view().shop) == 2,
		"declined reroll retains credit"
	)
	SeasonSave.path = prefix + "/missing/save.json"
	await _click(window._back)
	_check(
		is_instance_valid(window) and SeasonReclamation.credit(app.season.build.view().shop) == 2,
		"failed departure save keeps shop and credit"
	)
	SeasonSave.path = prefix + ".json"
	await _click(window._back)
	_check(
		SeasonReclamation.credit(app.season.build.view().shop) == 0,
		"actual Back expires credit durably"
	)
	_check(
		SeasonSave.restore().build.view().shop.reclamation_used,
		"reload cannot renew used allowance"
	)
	app.queue_free()
	await _frames()
	for suffix: String in [".json", ".json.bak", ".json.tmp", ".cfg"]:
		DirAccess.remove_absolute(prefix + suffix)


func _replacement_and_edge_contracts() -> void:
	var season: SeasonState = _reclamation_season()
	_complete_used(season)
	var build: SeasonBuild = season.build
	var selected: String = ""
	for attempt in range(5):
		for id: String in build.view().shop.offers.values():
			var item: Dictionary = SeasonGearCatalog.item(id)
			if not item.is_empty() and not build.view().wallet.gear[item.slot].is_empty():
				selected = id
				break
		if not selected.is_empty():
			break
		_check(build.commit(_command(build, "reroll")).ok, "search actual replacement stock")
	_check(not selected.is_empty(), "used-slot replacement offer reachable")
	if selected.is_empty():
		return
	var item: Dictionary = SeasonGearCatalog.item(selected)
	var old: Dictionary = build.view().wallet.gear[item.slot]
	var request: Dictionary = _command(
		build, "equip", {"offer": _offer(build, selected), "replace": old.id}
	)
	var preview: Dictionary = build.preview(request)
	_check(
		(
			preview.ok
			and preview.after.wallet.cash == build.cash() + floori(float(old.paid) / 2) - item.price
		),
		"replacement pays full price using Cash and resale only"
	)
	_check(
		(
			SeasonReclamation.credit(preview.after.shop) == 2
			and SeasonReclamation.credit(build.view().shop) == 0
		),
		"replacement credit preview is separate and nonmutating"
	)
	var poor: SeasonBuild = build._fork()
	# Isolated low-cash primitive fixture; it is never saved as a season journal.
	poor._charge(poor.cash() - maxi(0, item.price - floori(float(old.paid) / 2) - 1))
	_check(not poor.preview(request).ok, "prospective credit cannot finance replacement")
	_check(build.commit(request).ok, "confirmed used Gear replacement")
	var fresh: Dictionary = build.view().wallet.gear[item.slot]
	_check(
		(
			fresh.paid == item.price
			and fresh.id != old.id
			and not build.view().used_gear.has(fresh.id)
		),
		"replacement retains full paid receipt and starts unused"
	)
	_check(not build.view().used_gear.has(old.id), "sold instance qualification removed")
	for slot: String in SeasonOwnership.GEAR_SLOTS:
		# Unit boundary cases include one-Cash purchases and free/default copies.
		var unit: SeasonBuild = build._fork()
		unit._visit.erase("reclamation_used")
		unit._visit.erase("reroll_credit")
		var receipt: Dictionary = {"id": "used." + slot, "item": "test", "paid": 1, "slot": slot}
		unit._used_gear[receipt.id] = true
		SeasonReclamation.sold(unit, receipt)
		_check(
			SeasonReclamation.credit(unit.view().shop) == 2,
			"positive paid copy qualifies even at zero resale"
		)
		unit._visit.erase("reclamation_used")
		unit._visit.erase("reroll_credit")
		receipt.id += ".new"
		SeasonReclamation.sold(unit, receipt)
		_check(
			SeasonReclamation.credit(unit.view().shop) == 0,
			"same identity new copy cannot inherit use"
		)
		receipt.paid = 0
		unit._used_gear[receipt.id] = true
		SeasonReclamation.sold(unit, receipt)
		_check(SeasonReclamation.credit(unit.view().shop) == 0, "free/default copies excluded")
	var absent: SeasonBuild = build._fork()
	absent._visit.erase("reclamation_used")
	absent._visit.erase("reroll_credit")
	var sponsor: Dictionary = absent.view().wallet.sponsors[0]
	absent.commit(_command(absent, "sponsor_sell", {"receipt": sponsor.id}))
	var remaining: String = absent.view().used_gear[0]
	absent.commit(_command(absent, "sell_gear", {"receipt": remaining}))
	_check(SeasonReclamation.credit(absent.view().shop) == 0, "must own sponsor at sale")


func _migration() -> void:
	SeasonSave.path = "user://reclamation-migrate-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(_seed_for("F03", 9), false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 9
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
					{"offer": _offer(season.build, "F03"), "replace": ""}
				)
			)
			. ok
		),
		"buy genuine schema13 sponsor"
	)
	var before: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save old paid visit")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == before,
		"migration preserves stock, Cash and ownership"
	)
	_check(
		(
			restored.build.to_data().shop_sponsor_from == 2
			and restored.build.view().used_gear.is_empty()
		),
		"new pool waits until next visit; old games do not invent use"
	)
	_check(FileAccess.get_file_as_string(SeasonSave.path) == bytes, "no load-only rewrite")
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		restored.build.view().shop.offers == season.build.view().shop.offers,
		"old current-visit rerolls frozen"
	)
	_check(
		SeasonSave.save(restored) and SeasonSave.restore() != null, "migrated current visit replays"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "new pool visit replays")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _complete_through_app(app: SeasonApp) -> void:
	_check(app._checkpoint(), "save paid pregame copies")
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	var path: String = SeasonSave.path
	var ids: Array[String] = SeasonReclamation.receipts(app.season.build.view().wallet)
	app.play_season_game()
	await _frames(4)
	var lab: PitchBatLab = app.lab
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._selected_pitch_index = 0
	lab._ai_pitch_preselected = true
	lab._pitch_target = Vector2(0, 1.05)
	lab._pending_release_quality = 1.0
	lab._throw_pitch()
	_check(
		lab._pitch_actor.running and lab._match_state.gear_usage.first_pitch == ids,
		"actual managed-game release captures paid copies"
	)
	_check(
		not app._commit_result() and app.season.build.view().used_gear.is_empty(),
		"unfinished managed game cannot qualify Gear"
	)
	var state: MatchState = lab._match_state
	var game: Dictionary = app.season.pending_fixture()
	var rival: int = game.away if game.home == 0 else game.home
	state.performance.players = _sample(app.season.teams[0].roster, app.season.teams[rival].roster)
	state.home_team.runs = 1 if game.home == 0 else 0
	state.away_team.runs = 0 if game.home == 0 else 1
	state.phase = MatchState.Phase.GAME_END
	SeasonSave.path = path + "/missing/save.json"
	_check(
		not app._commit_result() and app._result_recorded and not app._result_saved,
		"failed completed-game write enters existing retry flow"
	)
	_check(
		app.season.build.view().used_gear.size() == 2,
		"completed result records receipt use once in memory"
	)
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == saved, "failed settlement preserves pregame save")
	_check(
		app._commit_result() and app._commit_result(),
		"retry/repeated Continue cannot duplicate result"
	)
	_check(
		(
			app.season.player_results.size() == 4
			and SeasonSave.restore().build.view().used_gear.size() == 2
		),
		"managed used-copy evidence saves and replays with exactly one result"
	)
	app._close_match()
	await _frames(2)
