extends "res://src/tests/season_loadout_ui_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://match-sales-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://match-sales-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	await _gear_sales(false)
	await _gear_sales(true)
	await _sponsor_sales()
	_app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro match sales checks passed: atomic saves, deferred effects, restart and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _gear_sales(released: bool) -> void:
	var fixture: Node = EarnedFixture.new()
	var gear: Node = GearFixture.new()
	_app.season = fixture._funded_season(gear._two_bats(true).to_data().seed)
	var build: SeasonBuild = _app.season.build
	_check(
		(
			build
			. commit(
				gear._command(
					build, "equip", {"offer": gear._gear_offer(build, "bat"), "replace": ""}
				)
			)
			. ok
		),
		"buy generated paid bat"
	)
	var copy: Dictionary = build.view().wallet.gear.bat
	_check(SeasonSave.save(_app.season), "paid fixture saves")
	_app.show_season()
	_app.play_season_game()
	await _frames()
	var lab: PitchBatLab = _app.lab
	var state: MatchState = lab._match_state
	var own: TeamMatchState = state.home_team if lab._player_home else state.away_team
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._debug_paused = true
	if released:
		state.top_half = lab._player_home
		lab._pitch_target = lab.DEFAULT_TARGET
		PitchBatLabFeelSupport.begin_pitch_release(lab)
		lab._release_controller.elapsed_seconds = PitchReleaseController.IDEAL_RELEASE_SECONDS
		PitchBatLabFeelSupport.commit_pitch_release(lab)
		_check(lab._pitch_actor.running and state.gear_usage.started, "actual first pitch released")
	await _click(_app.loadout.entry)
	await _click(_app.loadout._tab_buttons[0])
	var before: Dictionary = _app.season.build.to_data()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	await _click(_app.loadout._sale_buttons[0])
	var sale: SeasonLoadoutSale = _app.loadout.sale
	_check(
		sale.visible and sale.get_viewport().gui_get_focus_owner() == sale.get_cancel_button(),
		"sale review starts focused on Cancel"
	)
	_check(
		sale.dialog_text.contains("Cash:") and sale.dialog_text.contains("next batter"),
		"review discloses exact refund and deferred effect"
	)
	await _click(sale.get_cancel_button())
	_check(_app.season.build.to_data() == before, "cancel makes no sale")
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	await _click(_app.loadout._sale_buttons[0])
	await _click(sale.get_ok_button())
	SeasonSave.path = path
	_check(
		_app.season.build.to_data() == before and _app.sales.pending.is_empty(),
		"failed save rolls back ownership, cash and queue"
	)
	_check(FileAccess.get_file_as_string(path) == bytes, "failed save preserves previous bytes")
	var old_cash: int = _app.season.cash()
	var stamina: float = own.current_pitcher().stamina_remaining
	await _click(_app.loadout._sale_buttons[0])
	var command: Dictionary = sale.request.duplicate(true)
	await _click(sale.get_ok_button())
	_check(_app.season.build.view().wallet.gear.bat.is_empty(), "successful sale removes ownership")
	_check(_app.season.cash() == old_cash + int(copy.paid / 2), "exact paid half refund")
	_check(not _app.sales.sell(_app, command), "duplicate runtime confirmation cannot repay")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and restored.cash() == _app.season.cash()
			and restored.build.view().wallet.gear.bat.is_empty()
		),
		"sale survives reload before PA ends"
	)
	if released:
		_check(
			own.roster[0].definition.season_gear.bat == copy.item,
			"in-flight pitch keeps current Gear effect"
		)
		_check(_text(_app.loadout.body).contains("SOLD"), "pending effect clearly marked sold")
		state.phase = MatchState.Phase.PRE_PITCH
		state.between_batters = false
		_app.sales.apply_pending(_app)
		_check(not _app.sales.pending.is_empty(), "another pitch in same PA retains effect")
		state.between_batters = true
		_check(state.begin_pitch(), "next batter starts a pitch")
		_check(_app.sales.pending.is_empty(), "boundary hook retires before next release")
	else:
		_check(
			_app.sales.pending.is_empty() and state.gear_usage.equipped.is_empty(),
			"pre-first-release sale retires now and cannot earn use"
		)
	_check(own.roster[0].definition.season_gear.is_empty(), "base bat restored without paid Gear")
	_check(own.current_pitcher().stamina_remaining == stamina, "removal never resets stamina")
	if released:
		var stats: Dictionary = state.performance.snapshot(state)
		_check(
			_app.season.record_player_result(
				_app._fixture_id, 1, 0, stats, state.gear_usage.first_pitch
			),
			"sold first-release Gear still validates completed result"
		)
		_check(
			SeasonSave.save(_app.season) and SeasonSave.restore() != null,
			"completed result and sold receipt replay together"
		)
	_app.leave_game()
	await _frames()
	_app.season = SeasonSave.restore()
	_app.play_season_game()
	await _frames()
	_check(
		_app.lab._match_state.gear_usage.equipped.is_empty(),
		"next attempt starts with remaining ownership only"
	)
	_check(_app.season.build._match_inventory.gear.bat.is_empty(), "attempt evidence resets")
	_app.leave_game()
	await _frames()
	_check(fixture._failures == 0 and gear._failures == 0, "valid generated Gear fixture")
	fixture.free()
	gear.free()


func _sponsor_sales() -> void:
	var fixture: Node = EarnedFixture.new()
	var pair: Array[String] = ["E05", "G05"]
	var hits: Array[String] = ["single", "double"]
	_app.season = fixture._paid(pair)
	fixture._result(_app.season, hits)
	_check(SeasonSave.save(_app.season), "paid stamped sponsor fixture saves")
	_app.show_season()
	_app.play_season_game()
	await _frames()
	var lab: PitchBatLab = _app.lab
	var state: MatchState = lab._match_state
	var own: TeamMatchState = state.home_team if lab._player_home else state.away_team
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._debug_paused = true
	state.phase = MatchState.Phase.BALL_IN_PLAY
	state.between_batters = false
	await _click(_app.loadout.entry)
	await _click(_app.loadout._tab_buttons[1])
	var cash_before: int = _app.season.cash()
	var refund: int = 0
	for copy: Dictionary in _app.season.build.view().wallet.sponsors:
		refund += int(copy.paid / 2)
	for index in range(2):
		await _click(_app.loadout._sale_buttons[0])
		await _click(_app.loadout.sale.get_ok_button())
	_check(_app.season.build.view().wallet.sponsors.is_empty(), "both sponsors sold during play")
	_check(_app.season.cash() == cash_before + refund, "both refunds saved exactly once")
	_check(
		(
			own.roster[0].definition.season_sponsors.get("E05") == 2
			and own.roster[0].definition.season_sponsors.get("G05", false)
		),
		"stamp and Encore effects retained for active PA"
	)
	_check(
		_app.sales.pending.size() == 2 and _app.loadout._sale_buttons.is_empty(),
		"pending sold copies cannot be offered for sale again"
	)
	own.encore_used = true
	state.phase = MatchState.Phase.PLAY_DEAD
	state.between_batters = true
	_app.sales.apply_pending(_app)
	_check(
		own.roster[0].definition.season_sponsors.is_empty() and own.encore_used,
		"sponsor effects retire together without restoring spent resources"
	)
	_app.leave_game()
	await _frames()
	_app.season = SeasonSave.restore()
	_check(
		_app.season != null and _app.season.build.view().wallet.sponsors.is_empty(),
		"unfinished restart cannot resurrect sold sponsors"
	)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for event: Dictionary in data.build.events:
		if event.op == "match_sell":
			event.game += 1
			break
	_check(SeasonSave._decode(data) == null, "wrong fixture sale is rejected on replay")
	_check(fixture._failures == 0, "valid paid sponsor fixture")
	fixture.free()
