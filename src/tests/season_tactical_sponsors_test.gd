extends "res://src/tests/season_expanded_tactical_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_exchange_contracts()
	_combo_contracts()
	_sponsor_migration()
	await _sponsor_ui(SeasonSponsorCatalog.TACTICAL_ITEMS)
	await _exchange_ui()
	await _combo_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro tactical sponsor checks passed: exchange, combo, paid UI and migration.")
	get_tree().quit(0 if _failures == 0 else 1)


func _exchange_contracts() -> void:
	for source: String in SeasonTacticalExchange.TYPES:
		for target: String in SeasonTacticalExchange.TYPES:
			var build: SeasonBuild = _unit_build(["J07"])
			build.commit(_hold(build, source))
			build.commit(_hold(build, "A10"))
			var old: Dictionary = build.view().wallet.held[0]
			var request: Dictionary = _command(
				build, "tactical_exchange", {"receipt": old.id, "item": target}
			)
			var before: Dictionary = build.view()
			_check(
				build.preview(request).ok == (source != target) and build.view() == before,
				"exchange preview"
			)
			_check(build.commit(request).ok == (source != target), "all sixteen type pairs")
			if source == target:
				_check(build.view() == before, "same-type exchange atomic refusal")
				continue
			var after: Dictionary = build.view()
			var cost: int = SeasonTacticalExchange.cost(source, target)
			_check(
				after.wallet.cash == before.wallet.cash - cost,
				"list price difference, never refund"
			)
			_check(
				after.wallet.held.size() == 2 and after.wallet.held[0] == before.wallet.held[1],
				"same slot keeps other exact copy"
			)
			_check(
				after.wallet.held[1].item == target and after.wallet.held[1].paid == cost,
				"output receipt records actual incremental charge"
			)
			_check(
				build.commit(request).replayed and build.view() == after,
				"retry does not create second output"
			)
			build.commit(_command(build, "reroll"))
			var sponsor: Dictionary = SeasonSchoolSponsors.active(build, "J07")
			build.commit(_command(build, "sponsor_sell", {"receipt": sponsor.id}))
			build.commit(
				_command(build, "sponsor_buy", {"offer": _unit_offer(build, "J07"), "replace": ""})
			)
			_check(
				not (
					SeasonTacticalExchange.reason(build, after.wallet.held[1].id, source).is_empty()
				),
				"reroll/rebuy does not renew"
			)
	var build: SeasonBuild = _unit_build(["J07"])
	build.commit(_hold(build, "A10"))
	var receipt: String = build.view().wallet.held[0].id
	build._charge(build.cash())
	var before: Dictionary = build.view()
	for target: String in ["C02", HEAT, BASE, "missing", DevelopmentShopCatalog.CARDS.keys()[0]]:
		_check(
			(
				not (
					build
					. commit(
						_command(build, "tactical_exchange", {"receipt": receipt, "item": target})
					)
					. ok
				)
				and build.view() == before
			),
			"funding and excluded types rollback"
		)
	_check(
		build.commit(_command(build, "tactical_exchange", {"receipt": receipt, "item": "C03"})).ok,
		"zero Cash same-price exchange"
	)
	build = _unit_build(["J07"])
	build.commit(_hold(build, BASE))
	before = build.view()
	_check(
		(
			not (
				build
				. commit(
					_command(
						build,
						"tactical_exchange",
						{"receipt": before.wallet.held[0].id, "item": "A10"}
					)
				)
				. ok
			)
			and build.view() == before
		),
		"Base is excluded as input too"
	)
	build = _unit_build([])
	build.commit(_hold(build, "A10"))
	before = build.view()
	_check(
		(
			not (
				build
				. commit(
					_command(
						build,
						"tactical_exchange",
						{"receipt": before.wallet.held[0].id, "item": "C03"}
					)
				)
				. ok
			)
			and build.view() == before
		),
		"no active sponsor no exchange"
	)


func _combo_contracts() -> void:
	for swing: StringName in [&"swing.contact", &"swing.power"]:
		var state: MatchState = _fixture()
		var team: TeamMatchState = state.batting_team()
		_supply(team, "A10", "tape")
		_supply(team, "C03", "plan")
		var pair: Array[String] = ["tape", "plan"]
		_check(not team.tactics.activate_combo(state, team, pair, swing), "no sponsor no combo")
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors = {"E07": true}
		_check(
			not team.tactics.activate_combo(state, team, ["tape", "tape"], swing),
			"not arbitrary two-copy activation"
		)
		_check(team.tactics.activate_combo(state, team, pair, swing), "atomic exact Tape/Plan")
		_check(
			team.tactics.held.is_empty() and team.tactics.consumed.size() == 2,
			"both copies consumed"
		)
		state.batter().definition.season_gear = {"bat": "BAT-POW-01", "misc": "MISC-BAT-01"}
		var source: SwingProfileDefinition = ContentDB.get_swing(swing)
		var normal: SwingProfileDefinition = SeasonGearCatalog.swing(
			source, state.batter().definition
		)
		var changed: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
		_check(
			is_equal_approx(changed.contact_radius_x_m / normal.contact_radius_x_m, 1.08),
			"Tape coverage once after Gear"
		)
		_check(
			is_equal_approx(changed.contact_radius_y_m / normal.contact_radius_y_m, 1.08),
			"both coverage axes"
		)
		for left: bool in [false, true]:
			for error: float in [0.0, 0.55, 0.90, 0.97]:
				var base: ContactResult = _contact(normal, left, error)
				var actual: ContactResult = _contact(changed, left, error)
				var scale: float = (
					1.0
					if actual.outcome == ContactResult.Outcome.FOUL
					else 0.95 * (1.06 if actual.quality >= 0.65 else 1.0)
				)
				_check(
					is_equal_approx(
						actual.exit_velocity.length() / base.exit_velocity.length(), scale
					),
					"actual fair/foul/quality multiplicative combination"
				)
				_check(
					actual.launch_angle_degrees == base.launch_angle_degrees,
					"no hidden angle adjustment"
				)
		state.begin_pitch()
		state.cancel_pitch()
		_check(team.tactics.active(state) == MatchTactics.COMBO, "cancel retains pair")
		state.begin_pitch()
		state.record_foul()
		state.continue_after_dead_ball()
		state.defensive_team().select_pitcher(2)
		_check(team.tactics.locked_swing(state) == swing, "foul and opponent change retain lock")
		state.balls = 3
		state.begin_pitch()
		state.record_ball()
		state.continue_after_dead_ball()
		_check(
			team.tactics.active(state) == "" and team.tactics.locked_swing(state) == &"",
			"walk expires both"
		)
		_supply(team, "A10", "new-tape")
		_supply(team, "C03", "new-plan")
		_check(
			not team.tactics.activate_combo(state, team, ["new-tape", "new-plan"], swing),
			"once per game"
		)
		_check(team.tactics.activate(state, team, "new-tape"), "ordinary use remains legal next PA")
		_check(
			not team.tactics.activate_combo(state, team, ["new-tape", "new-plan"], swing),
			"cannot append combo to active card"
		)


func _sponsor_migration() -> void:
	SeasonSave.path = "user://tactical-sponsor-migration-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(14, false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 15
	_record(season)
	season.build.commit(_command(season.build, "open"))
	_check(SeasonSave.save(season), "old schema19 save")
	var before: Dictionary = season.build.view()
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and restored.build.view() == before
			and restored.build._tactical_sponsor_from == 2
		),
		"current stock preserved, sponsor pool next visit"
	)
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		season.build.view().shop.offers == restored.build.view().shop.offers,
		"old reroll generation exact"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		(
			restored.build._sponsor_catalog_version() >= 9
			and SeasonSave.save(restored)
			and SeasonSave.restore() != null
		),
		"new sponsor gate replays"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _paid_combo() -> SeasonState:
	# Acquire the rare sponsor plus Tape, then seek Plan through real paid rerolls.
	# All three need not coincide in one finite initial-stock sample.
	var probe: SeasonBuild = _unit_build([])
	probe._visit.number = 3
	for seed_value in range(30000):
		probe._seed = seed_value
		var stock: Array = probe._offers(0).values()
		if not stock.has("E07") or not stock.has("A10"):
			continue
		var season: SeasonState = _funded_season(seed_value, 3)
		if _offer(season.build, "E07").is_empty() or _offer(season.build, "A10").is_empty():
			continue
		_check(
			(
				season
				. build
				. commit(
					_command(
						season.build,
						"sponsor_buy",
						{"offer": _offer(season.build, "E07"), "replace": ""}
					)
				)
				. ok
			),
			"actual paid Double Booking"
		)
		_check(
			(
				season
				. build
				. commit(
					_command(season.build, "tactical_buy", {"offer": _offer(season.build, "A10")})
				)
				. ok
			),
			"actual paid Tape"
		)
		for attempt in range(4):
			var offer: String = _offer(season.build, "C03")
			if not offer.is_empty():
				_check(
					(
						season
						. build
						. commit(_command(season.build, "tactical_buy", {"offer": offer}))
						. ok
					),
					"actual paid Plan"
				)
				return season
			if attempt < 3:
				_check(
					season.build.commit(_command(season.build, "reroll")).ok,
					"actual paid combo search"
				)
	_check(false, "paid combo reachable within bounded search")
	return null


func _exchange_ui() -> void:
	SeasonSave.path = "user://exchange-ui-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _paid_tactics(["J07", "A10"])
	var build: SeasonBuild = app.season.build
	build.commit(_command(build, "sponsor_buy", {"offer": _offer(build, "J07"), "replace": ""}))
	build.commit(_command(build, "tactical_buy", {"offer": _offer(build, "A10")}))
	_check(app._checkpoint(), "save paid Pick & Mix")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var before: Dictionary = build.view()
	var target: String = HEAT
	await _click(_meta_exact(window, "exchange_target", target))
	_check(window._review_text.text.contains("Pay 2 Cash"), "exact upward price review")
	await _shop_bounds(window, "exchange-review")
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.view() == before, "cancel retains input")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_meta_exact(window, "exchange_target", target))
	await _click(window._confirm.get_ok_button())
	_check(app.season.build.view() == before, "failed write rolls back exchange and allowance")
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "prior save bytes preserved")
	await _click(_meta_exact(window, "exchange_target", target))
	await _click(window._confirm.get_ok_button())
	var after: Dictionary = app.season.build.view()
	_check(
		after.wallet.cash == before.wallet.cash - 2 and after.wallet.held[0].item == HEAT,
		"paid UI one-for-one result"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == after and after.shop.mix_used,
		"use flag and receipt persist"
	)
	var request: Dictionary = _command(
		restored.build, "tactical_exchange", {"receipt": after.wallet.held[0].id, "item": "C03"}
	)
	_check(not restored.build.commit(request).ok, "reload cannot renew")
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		(
			restored
			. build
			. commit(
				_command(
					restored.build,
					"tactical_exchange",
					{"receipt": after.wallet.held[0].id, "item": "C03"}
				)
			)
			. ok
		),
		"new actual visit renews"
	)
	_check(
		SeasonSave.save(restored) and SeasonSave.restore() != null, "second visit exchange replays"
	)
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _combo_ui() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _fixture()
	lab._player_home = false
	var team: TeamMatchState = lab._configured_match.away_team
	team.current_batter().definition.season_sponsors = {"E07": true}
	_supply(team, "A10", "tape")
	_supply(team, "C03", "plan")
	add_child(lab)
	await _frames(4)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var controls: MatchTacticalControls = lab.get_node("TacticalControls")
	await _frames()
	await _click(controls._entry)
	await _click(_combo_button(controls))
	_check(
		(
			controls._detail.text.contains("×1.007")
			and controls._dialog.get_ok_button().text == "USE BOTH COPIES"
		),
		"combined costs and multiplicative effect reviewed"
	)
	await _click(controls._dialog.get_cancel_button())
	_check(
		team.tactics.held.size() == 2 and not team.tactics._combo_used,
		"cancel preserves both and once-game allowance"
	)
	await _click(controls._entry)
	await _click(_combo_button(controls))
	team.tactics.held[1].id = "changed"
	await _click(controls._dialog.get_ok_button())
	_check(
		team.tactics.held.size() == 2 and not team.tactics._combo_used,
		"stale exact-copy review spends nothing"
	)
	await _click(controls._entry)
	await _click(_combo_button(controls))
	await _click(controls._dialog.get_ok_button())
	_check(
		team.tactics.held.is_empty() and controls._entry.text.contains("Tape + Plan"),
		"both effects visible after actual confirmation"
	)
	_check(team.tactics.locked_swing(lab._match_state) == &"swing.contact", "shared input lock")
	var outline: Node3D = lab._batting_aim_marker.get_node("OpticsCoverage")
	var profile: SwingProfileDefinition = SeasonSponsorEffects.swing(
		ContentDB.get_swing(&"swing.contact"), lab._match_state
	)
	_check(
		outline.visible and is_equal_approx(outline.scale.x, profile.contact_radius_x_m),
		"combined Contact ellipse matches actual coverage"
	)
	_check(
		Rect2(Vector2.ZERO, Vector2(controls._dialog.size)).encloses(controls._scroll.get_rect()),
		"combined review remains within bounded dialog"
	)

	lab._ai_pitch_preselected = true
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "actual paired delivery")
	lab._resolve_swing(&"swing.power", Vector2(0, 1.05))
	_check(not lab._swing_consumed, "wrong swing input rejected")
	lab._resolve_swing(&"swing.contact", Vector2(0, 1.05))
	_check(
		lab._swing_consumed and lab._swing_tracker.profile.tactical_quality_exit_scale == 1.06,
		"actual legal paired swing"
	)

	lab.queue_free()
	await _frames()


func _combo_button(controls: MatchTacticalControls) -> Button:
	for child: Node in controls._choices.get_children():
		if child is Button and child.get_meta("tactical_combo", &"") == &"swing.contact":
			return child
	return null
