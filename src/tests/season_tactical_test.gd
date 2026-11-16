extends "res://src/tests/season_wholesale_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_transactions_tactical()
	_effects_tactical()
	_recovery()
	_expiry_and_roles()
	_migration_tactical()
	await _tactical_ui()
	await _pair_ui("tactical")
	await _match_ui()
	await _recovery_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro tactical checks passed: paid copies, effects, readiness, UI and replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _hold(build: SeasonBuild, id: String) -> Dictionary:
	return _command(build, "tactical_buy", {"offer": _unit_offer(build, id)})


func _transactions_tactical() -> void:
	var build: SeasonBuild = _unit_build([])
	var request: Dictionary = _hold(build, "A10")
	var before: Dictionary = build.view()
	_check(build.preview(request).ok and build.view() == before, "preview spends nothing")
	_check(build.commit(request).ok and build.cash() == before.wallet.cash - 3, "paid Tape")
	_check(build.commit(request).replayed, "exact purchase retry once")
	_check(build.commit(_hold(build, "A10")).ok, "two duplicate tactical copies allowed")
	request = _hold(build, "C02")
	before = build.view()
	_check(not build.commit(request).ok and build.view() == before, "full shared bag atomic")
	var receipt: Dictionary = build.view().wallet.held[0]
	_check(
		not (
			build
			. commit(
				_command(
					build,
					"use",
					{"receipt": receipt.id, "player": ROSTER[0], "pitch": "", "replace": ""}
				)
			)
			. ok
		),
		"cannot turn a tactic into permanent growth"
	)
	_check(
		build.commit(_command(build, "discard", {"receipt": receipt.id})).ok, "discard exact copy"
	)
	_check(
		build.cash() == before.wallet.cash and build.view().wallet.held.size() == 1,
		"discard no refund"
	)
	_check(build.commit(_hold(build, "C02")).ok, "free slot accepts Recovery")
	build = _unit_build(["J02"])
	request = _pair(build, "C02", "C02")
	before = build.view()
	_check(
		build.commit(request).ok and build.cash() == before.wallet.cash - 7,
		"two Recovery offers cost7"
	)
	_check(
		build.view().wallet.held[0].paid == 3 and build.view().wallet.held[1].paid == 4,
		"distinct paid copies"
	)
	build = _unit_build(["J02"])
	build.commit(_hold(build, "C03"))
	request = _pair(build, "C02", "C02")
	before = build.view()
	_check(
		not build.commit(request).ok and build.view() == before,
		"second-copy capacity fails whole pair"
	)
	var development: String = DevelopmentShopCatalog.CARDS.keys()[0]
	build = _unit_build([])
	build.commit(
		_command(
			build,
			"buy",
			{
				"offer": _unit_offer(build, development),
				"mode": "hold",
				"player": "",
				"pitch": "",
				"replace": ""
			}
		)
	)
	_check(build.commit(_hold(build, "C03")).ok, "development and tactical share two slots")
	_check(not build.commit(_hold(build, "A10")).ok, "no separate tactical bag")


func _supply(team: TeamMatchState, id: String, receipt: String = "copy") -> void:
	team.tactics.held.append(
		{"id": receipt, "item": id, "paid": SeasonTacticalCatalog.item(id).price, "kind": "held"}
	)


func _effects_tactical() -> void:
	for id: String in ["A10", "C03"]:
		for swing_id: StringName in [&"swing.contact", &"swing.power"]:
			var state: MatchState = _fixture()
			var team: TeamMatchState = state.batting_team()
			_supply(team, id)
			_supply(team, "C02", "other")
			var chosen: StringName = swing_id if id == "C03" else &""
			_check(team.tactics.activate(state, team, "copy", chosen), "legal offensive activation")
			_check(not team.tactics.activate(state, team, "other"), "one club activation per PA")
			state.batter().definition.season_gear = {"bat": "BAT-POW-01", "misc": "MISC-BAT-01"}
			var source: SwingProfileDefinition = ContentDB.get_swing(swing_id)
			var normal: SwingProfileDefinition = SeasonGearCatalog.swing(
				source, state.batter().definition
			)
			var changed: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
			_check(
				is_equal_approx(
					changed.contact_radius_x_m / normal.contact_radius_x_m,
					1.08 if id == "A10" else 1.0
				),
				"coverage once after Gear"
			)
			for error: float in [0.0, 0.55, 0.90, 0.97]:
				var base: ContactResult = _contact(normal, false, error)
				var actual: ContactResult = _contact(changed, false, error)
				var scale: float = 1.0
				if actual.outcome != ContactResult.Outcome.FOUL:
					scale = (0.95 if id == "A10" else (1.06 if actual.quality >= 0.65 else 1.0))
				_check(
					is_equal_approx(
						actual.exit_velocity.length() / base.exit_velocity.length(), scale
					),
					"actual resolver fair/quality gate"
				)
				_check(
					actual.launch_angle_degrees == base.launch_angle_degrees,
					"no hidden launch change"
				)
			_check(source.tactical_quality_exit_scale == 1.0, "authored source unchanged")
			state.begin_pitch()
			state.cancel_pitch()
			_check(
				not team.tactics.activate(state, team, "copy", chosen),
				"cancel delivery never refunds copy"
			)
			state.begin_pitch()
			state.record_foul()
			state.continue_after_dead_ball()
			_check(team.tactics.active(state) == id, "foul preserves entire PA effect")
			_check(
				not team.tactics.activate(state, team, "other"), "between-pitch activation rejected"
			)
			state.defensive_team().select_pitcher(2)
			_check(team.tactics.active(state) == id, "opposing pitcher change preserves effect")
			state.record_hit(BallPlayOutcome.Result.SINGLE)
			_check(
				team.tactics.active(state) == "" and team.tactics.locked_swing(state) == &"",
				"next batter clears effect and lock"
			)
			_check(team.tactics.consumed.size() == 1, "completed PA retains one consumption record")


func _recovery() -> void:
	for fraction: float in [0.4, 0.95, 1.0]:
		var state: MatchState = _fixture()
		var team: TeamMatchState = state.defensive_team()
		_supply(team, "C02")
		_supply(team, "C02", "second")
		var pitcher: PlayerMatchState = state.pitcher()
		pitcher.stamina_remaining = pitcher.stamina_max * fraction
		_check(
			team.tactics.activate(state, team, "copy") == (fraction < 1.0),
			"full pitcher consumes nothing"
		)
		_check(
			is_equal_approx(
				pitcher.stamina_remaining, pitcher.stamina_max * minf(1, fraction + 0.10)
			),
			"restore10% game-start max with cap"
		)
		if fraction == 1.0:
			_check(
				team.tactics.held.size() == 2 and team.tactics.consumed.is_empty(),
				"invalid recovery preserves inventory"
			)
			continue
		state.record_hit(BallPlayOutcome.Result.SINGLE)
		state.continue_after_dead_ball()
		pitcher.stamina_remaining -= 30
		_check(not team.tactics.activate(state, team, "second"), "once per pitcher across PAs")
		team.select_pitcher(2)
		state.pitcher().stamina_remaining -= 30
		_check(
			team.tactics.activate(state, team, "second"),
			"different legal pitcher has independent recovery"
		)
		_check(
			not state.pitcher().first_batter_completed and state.pitcher().pitch_count == 0,
			"recovery never changes pitch counters"
		)


func _paid_tactics(ids: Array) -> SeasonState:
	var probe: SeasonBuild = _unit_build([])
	probe._visit.number = 3
	for seed_value in range(30000):
		probe._seed = seed_value
		var values: Array = probe._offers(0).values()
		var found: bool = true
		for id: String in ids:
			if values.count(id) < ids.count(id):
				found = false
		if not found:
			continue
		var season: SeasonState = _funded_season(seed_value, 3)
		values = season.build.view().shop.offers.values()
		for id: String in ids:
			if values.count(id) < ids.count(id):
				found = false
		if found:
			return season
	_check(false, "reachable real tactical stock")
	return null


func _migration_tactical() -> void:
	SeasonSave.path = "user://tactics-migration-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(42, false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 13
	_record(season)
	season.build.commit(_command(season.build, "open"))
	_check(SeasonSave.save(season), "schema17 saves")
	var before: Dictionary = season.build.view()
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == before, "old stock preserved exactly")
	_check(restored.build._tactical_from == 2, "tactics enabled next visit")
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		season.build.view().shop.offers == restored.build.view().shop.offers,
		"old same-visit reroll frozen"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "schema18 migration replays")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _tactical_ui() -> void:
	SeasonSave.path = "user://tactics-ui-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _paid_tactics(["A10", "C03"])
	_check(app._checkpoint(), "save actual offered tactics")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var before: Dictionary = app.season.build.view()
	var quote: String = _offer(app.season.build, "A10")
	await _click(_meta_exact(window, "tactical_offer", quote))
	_check(window._review_text.text.contains("No resale"), "review shows tactical cost and limits")
	await _shop_bounds(window, "tactical-review")
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.view() == before, "cancel paid tactic unchanged")
	await _click(_meta_exact(window, "tactical_offer", quote))
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(window._confirm.get_ok_button())
	_check(app.season.build.view() == before, "failed save rolls back purchase")
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "previous bytes preserved")
	for id: String in ["A10", "C03"]:
		await _click(_meta_exact(window, "tactical_offer", _offer(app.season.build, id)))
		await _click(window._confirm.get_ok_button())
	_check(app.season.build.view().wallet.held.size() == 2, "paid shared inventory")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == app.season.build.view(),
		"paid copies reload exactly"
	)
	window.size = Vector2i(1000, 650)
	await _shop_bounds(window, "tactical-held")
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _match_ui() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _fixture()
	lab._player_home = false
	_supply(lab._configured_match.away_team, "C03")
	add_child(lab)
	await _frames(4)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var controls: MatchTacticalControls = lab.get_node("TacticalControls")
	await _frames()
	await _click(controls._entry)
	_check(controls._dialog.visible, "readiness supplies open through actual input")
	if not controls._dialog.visible:
		lab.queue_free()
		await _frames()
		return
	_check(
		Rect2(Vector2.ZERO, Vector2(controls._dialog.size)).encloses(controls._scroll.get_rect()),
		"supply content fits dialog"
	)
	await _click(controls._choices.get_child(0))
	await _click(controls._dialog.get_cancel_button())
	_check(lab._match_state.away_team.tactics.held.size() == 1, "cancel match use preserves copy")
	await _click(controls._entry)
	await _click(controls._choices.get_child(0))
	_check(controls._detail.text.contains("Contact"), "exact Plan lock reviewed")
	await _click(controls._dialog.get_ok_button())
	_check(
		lab._match_state.away_team.tactics.locked_swing(lab._match_state) == &"swing.contact",
		"confirmed Plan locks Contact"
	)
	_check(controls._entry.text.contains("CONTACT"), "PA lock remains visible")
	lab._ai_pitch_preselected = true
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "actual delivery after activation")
	lab._resolve_swing(&"swing.power", Vector2(0, 1.05))
	_check(not lab._swing_consumed, "wrong swing input cannot bypass Plan")
	lab._resolve_swing(&"swing.contact", Vector2(0, 1.05))
	_check(
		lab._swing_consumed and lab._swing_tracker.profile.tactical_quality_exit_scale == 1.06,
		"legal actual swing receives Plan"
	)
	lab.queue_free()
	await _frames()


func _contact(profile: SwingProfileDefinition, left: bool, error: float) -> ContactResult:
	var pitch: PitchState = PitchState.new()
	pitch.velocity = Vector3(0, 0, -24)
	var intent: SwingIntent = SwingIntent.new()
	intent.handedness_left = left
	var center: Vector3 = Vector3(0, 1.05, ContactResolver.CONTACT_PLANE_Z)
	return ContactResolver._resolve_at_contact(
		pitch,
		center + Vector3(profile.contact_radius_x_m * error, 0, 0),
		center,
		intent,
		profile,
		5,
		5
	)


func _recovery_ui() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _fixture()
	lab._player_home = true
	_supply(lab._configured_match.home_team, "C02")
	add_child(lab)
	await _frames(4)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var controls: MatchTacticalControls = lab.get_node("TacticalControls")
	await _frames()
	await _click(controls._entry)
	_check(controls._choices.get_child(0).disabled, "full pitcher UI disabled")
	await _click(controls._dialog.get_cancel_button())
	var pitcher: PlayerMatchState = lab._match_state.pitcher()
	pitcher.stamina_remaining = 0.4 * pitcher.stamina_max
	await _click(controls._entry)
	await _click(controls._choices.get_child(0))
	_check(controls._detail.text.contains("Stamina:"), "actual recovery amount reviewed")
	# An already reviewed target cannot silently move to a substituted pitcher.
	lab._match_state.defensive_team().select_pitcher(2)
	await _click(controls._dialog.get_ok_button())
	_check(controls.team().tactics.held.size() == 1, "stale pitcher confirmation spends nothing")
	lab._match_state.pitcher().stamina_remaining = 0.4 * lab._match_state.pitcher().stamina_max
	await _click(controls._entry)
	await _click(controls._choices.get_child(0))
	await _click(controls._dialog.get_ok_button())
	_check(
		(
			controls.team().tactics.held.is_empty()
			and is_equal_approx(lab._match_state.pitcher().stamina_percent(), 0.5)
		),
		"actual defensive confirmation recovers exact amount"
	)
	lab.queue_free()
	await _frames()


func _expiry_and_roles() -> void:
	for outcome: String in ["walk", "strikeout", "out", "game-end"]:
		var state: MatchState = _fixture()
		var team: TeamMatchState = state.batting_team()
		_supply(team, "C03")
		_check(
			not team.tactics.activate(state, state.defensive_team(), "copy", &"swing.contact"),
			"foreign club cannot use owned copy"
		)
		_check(team.tactics.activate(state, team, "copy", &"swing.contact"), "own club uses Plan")
		_supply(state.defensive_team(), "C02", "defense")
		state.pitcher().stamina_remaining -= 30
		_check(
			state.defensive_team().tactics.activate(state, state.defensive_team(), "defense"),
			"both clubs have their own PA allowance"
		)
		state.begin_pitch()
		match outcome:
			"walk":
				state.balls = 3
				state.record_ball()
			"strikeout":
				state.strikes = 2
				state.record_strike()
			"out":
				state.record_ball_in_play_out()
			"game-end":
				state.phase = MatchState.Phase.GAME_END
		_check(
			team.tactics.active(state) == "" and team.tactics.held.is_empty(),
			"effect ends without refund on " + outcome
		)
		_check(team.tactics.consumed.size() == 1, "consumption retained on " + outcome)
