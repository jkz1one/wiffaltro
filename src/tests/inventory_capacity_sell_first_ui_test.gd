extends "res://src/tests/season_loadout_ui_test.gd"
## Synthetic controlled offers and in-memory checkpoint seam only, not save78 proof.


class ControlledCheckpointApp:
	extends SeasonApp
	var checkpoints: int = 0

	func _checkpoint() -> bool:
		checkpoints += 1
		return true


var checks: int = 0


func check(ok: bool, message: String) -> void:
	checks += 1
	_check(ok, message)


func _ready() -> void:
	SeasonSave.path = "user://capacity-sell-first-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://capacity-sell-first-%d.cfg" % OS.get_process_id()
	_app = ControlledCheckpointApp.new()
	add_child(_app)
	await _frames()
	await _route()
	_app.queue_free()
	await _frames()
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	print("Capacity sell-first UI checks: %d, failures: %d" % [checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _route() -> void:
	var season: SeasonState = SeasonState.create_closed_league(
		112, LeagueRules.capture("standard"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "controlled season drafted")
	check(SeasonInventoryRules.enable(season), "rules enabled before synthetic rewards")
	_app.season = season
	var build: SeasonBuild = season.build
	for game in range(8):
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": game, "win": true}))
				. ok
			),
			"synthetic credited funding"
		)
	check(build.commit(SeasonOpponentPolicy.command(build, "open")).ok, "controlled shop opens")
	build._batch_start = SeasonSmallBatch.TYPES.duplicate()
	for item: String in ["G02", "A10", "C03", "C02"]:
		var offer: String = "controlled:%d" % build.revision()
		build._visit.offers[offer] = item
		var fields: Dictionary = {"offer": offer}
		if item == "G02":
			fields["replace"] = ""
		check(
			(
				build
				. commit(
					SeasonOpponentPolicy.command(
						build, "sponsor_buy" if item == "G02" else "tactical_buy", fields
					)
				)
				. ok
			),
			"controlled paid capacity fixture"
		)
	var wallet: Dictionary = build.view().wallet
	check(
		wallet.held.size() == 3 and wallet.capacity.held == 3,
		"three unused copies occupy legitimate expanded capacity"
	)
	if wallet.held.size() != 3:
		return
	var sponsor: String = SeasonSchoolSponsors.active(build, "G02").id
	var excess: String = wallet.held[0].id
	var refund: int = int(wallet.held[0].paid / 2)
	_app.show_season()
	await _frames()
	var ui: SeasonLoadoutUI = _app.loadout
	await _click(ui.entry)
	await _select_loadout_receipt(ui, "sponsors", sponsor)
	var before: Dictionary = build.to_data().duplicate(true)
	await _click(ui._sale_buttons[0])
	var resolver: SeasonSponsorResolution = _resolver()
	check(resolver != null, "capacity reducing sponsor sale opens actual resolver")
	if resolver == null:
		return
	check(
		resolver.gui_get_focus_owner() == resolver.get_cancel_button(),
		"capacity resolver defaults to Cancel"
	)
	check(_text(resolver).contains("cancel and sell unused extras first")
		and _text(resolver).contains("no-refund")
		and resolver._choices.get_children().any(func(child: Node) -> bool:
			return child is CheckBox and child.text.contains("no refund")), \
				"sell-first alternative and explicit no-refund discard both visible")
	check(resolver.get_ok_button().disabled, "unresolved overflow cannot be confirmed")
	await _click(resolver.get_cancel_button())
	check(
		ClubCareer.same(before, build.to_data()) and _resolver() == null,
		"Cancel closes resolver without changing Cash, owner or journal"
	)
	await _select_loadout_receipt(ui, "supplies", excess)
	check(
		ui._sale_buttons.size() == 1 and ui._sale_buttons[0].text == "SELL • %d Cash" % refund,
		"selected unused extra offers exact half-paid refund"
	)
	var cash: int = season.cash()
	await _click(ui._sale_buttons[0])
	check(
		(
			ui.sale.request.receipt == excess
			and ui.sale.gui_get_focus_owner() == ui.sale.get_cancel_button()
		),
		"extra sale confirms exact receipt with Cancel default"
	)
	await _click(ui.sale.get_ok_button())
	check(
		(
			season.cash() == cash + refund
			and SeasonOwnership._owned(season.build._bank.view(), excess).is_empty()
		),
		"controlled checkpoint sells only selected extra and credits half paid"
	)
	check(season.build.view().wallet.held.size() == 2, "two unused copies remain")
	await _select_loadout_receipt(ui, "sponsors", sponsor)
	await _click(ui._sale_buttons[0])
	check(
		_resolver() == null and ui.sale.visible and ui.sale.request.receipt == sponsor,
		"retry sponsor opens ordinary confirmation without overflow resolver"
	)
	check(ui.sale.request.get("discard", []).is_empty(), "retry requires no discard")
	await _click(ui.sale.get_ok_button())
	wallet = season.build.view().wallet
	check(
		(
			wallet.held.size() == 2
			and wallet.capacity.held == 2
			and SeasonOwnership._owned(wallet, sponsor).is_empty()
		),
		"sponsor removed with both remaining copies intact"
	)
	check(
		(_app as ControlledCheckpointApp).checkpoints == 2,
		"exactly two controlled checkpoint commits"
	)


func _resolver() -> SeasonSponsorResolution:
	for child: Node in _app.loadout.get_children():
		if child is SeasonSponsorResolution and not child.is_queued_for_deletion():
			return child
	return null
