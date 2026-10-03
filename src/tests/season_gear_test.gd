extends "res://src/tests/paid_shop_ui_test.gd"
## Paid ownership, real resolver paths and actual viewport clicks; no balance claim.

const ROSTER: Array[String] = [
	"player.alex_finch", "player.rowan_chase", "player.nico_vega", "player.ari_banks"
]


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_catalog()
	_batting()
	_pitching()
	_transactions()
	await _gear_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro Gear checks passed: purchases, effects, migrations, UI and live actors.")
	get_tree().quit(0 if _failures == 0 else 1)


func _catalog() -> void:
	_check(SeasonGearCatalog.ITEMS.size() == 6, "only supported initial candidates enabled")
	var book: SeasonDevelopment = SeasonDevelopment.new("gear")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var owned: Dictionary = {"bat": {"item": "BAT-CON-01"}, "misc": {"item": "MISC-PIT-03"}}
	var seen: Dictionary = {}
	for seed_value in range(150):
		rng.seed = seed_value
		var offers: Dictionary = SeasonGearCatalog.offers(book, ROSTER, owned, rng, "test", 1)
		var kinds: Dictionary = {}
		for id: String in offers.values():
			var kind: String = "development"
			if id.begins_with("lesson."):
				kind = "lesson"
			elif SeasonGearCatalog.ITEMS.has(id):
				kind = "gear"
				_check(id not in ["BAT-CON-01", "MISC-PIT-03"], "owned exact items excluded")
				seen[id] = true
			kinds[kind] = true
		_check(offers.size() == 4 and kinds.size() >= 2, "bounded category diversity")
	_check(seen.size() == 4, "all remaining eligible Gear reachable; no locked tiers")
	_check(SeasonGearCatalog.eligible({}).size() == 3, "all three enabled Gear slots eligible")


func _batting() -> void:
	var base: PlayerDefinition = ProgressionMatchAdapter.from_profile(
		SeasonPlayerCatalog.profile(ROSTER[0])
	)
	for swing_id: StringName in [&"swing.contact", &"swing.power"]:
		var source: SwingProfileDefinition = ContentDB.get_swing(swing_id)
		for left: bool in [false, true]:
			for id: String in [
				"BAT-CON-01", "BAT-POW-01", "BAT-CON-02", "BAT-CON-03", "BAT-POW-02", "BAT-POW-03"
			]:
				var player: PlayerDefinition = SeasonGearCatalog.equip(base, {"bat": {"item": id}})
				var modified: SwingProfileDefinition = SeasonGearCatalog.swing(source, player)
				var item: Dictionary = SeasonGearCatalog.item(id)
				_check(
					is_equal_approx(
						modified.contact_radius_x_m / source.contact_radius_x_m, item.radius
					),
					"horizontal tolerance"
				)
				_check(
					is_equal_approx(
						modified.contact_radius_y_m / source.contact_radius_y_m, item.radius
					),
					"vertical tolerance"
				)
				_check(
					(
						modified.contact_depth_m == source.contact_depth_m
						and (
							modified.contact_window_start_seconds
							== source.contact_window_start_seconds
						)
						and modified.sweet_spot_seconds == source.sweet_spot_seconds
					),
					"Bat cannot widen timing or retime swings"
				)
				for normalized_error: float in [0.0, 0.4, 0.95]:
					var normal: ContactResult = _contact(source, left, normalized_error)
					var changed: ContactResult = _contact(modified, left, normalized_error)
					_check(
						is_equal_approx(normal.quality, changed.quality), "same quality comparison"
					)
					var factor: float = (
						1.0 if normal.outcome == ContactResult.Outcome.FOUL else item.exit
					)
					_check(
						is_equal_approx(
							changed.exit_velocity.length() / normal.exit_velocity.length(), factor
						),
						"one fair-only exit speed multiplier"
					)
				_check(
					source.gear_fair_exit_scale == 1.0 and base.season_gear.is_empty(),
					"authored swing/player resources stay pristine"
				)


func _contact(profile: SwingProfileDefinition, left: bool, error: float) -> ContactResult:
	var state: PitchState = PitchState.new()
	state.velocity = Vector3(0, 0, -24)
	var intent: SwingIntent = SwingIntent.new()
	intent.handedness_left = left
	var center: Vector3 = Vector3(0, 1.05, ContactResolver.CONTACT_PLANE_Z)
	return ContactResolver._resolve_at_contact(
		state,
		center + Vector3(profile.contact_radius_x_m * error, 0, 0),
		center,
		intent,
		profile,
		5,
		5
	)


func _pitching() -> void:
	var base: PlayerDefinition = ProgressionMatchAdapter.from_profile(
		SeasonPlayerCatalog.profile(ROSTER[0])
	)
	var setup: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
	for recipe_id: String in DevelopmentShopCatalog.LESSON_PRICES:
		var recipe: PitchDefinition = PitchMastery.apply(
			ContentDB.get_pitch(StringName(recipe_id)), 3
		)
		for left: bool in [false, true]:
			for ball: String in [
				"BALL-MOV-01",
				"BALL-VEL-01",
				"BALL-HYB-01",
				"BALL-MOV-02",
				"BALL-MOV-03",
				"BALL-VEL-02",
				"BALL-VEL-03",
				"BALL-HYB-02",
				"BALL-HYB-03"
			]:
				var player: PlayerDefinition = SeasonGearCatalog.equip(
					base, {"ball": {"item": ball}, "misc": {"item": "MISC-PIT-03"}}
				)
				var normal: PitchDefinition = MatchLabSupport.rated_pitch(recipe, base, 1.0)
				var changed: PitchDefinition = MatchLabSupport.rated_pitch(recipe, player, 1.0)
				var item: Dictionary = SeasonGearCatalog.item(ball)
				_check(
					is_equal_approx(
						changed.nominal_velocity_mps / normal.nominal_velocity_mps, item.velocity
					),
					"ball velocity once after developed recipe"
				)
				_check(
					is_equal_approx(
						changed.mastery_movement_scale / normal.mastery_movement_scale,
						item.movement
					),
					"ball movement once after mastery"
				)
				_check(
					(
						changed.instability_strength == normal.instability_strength
						and changed.mastery_late_bias == normal.mastery_late_bias
					),
					"natural wobble and mastery timing unchanged"
				)
				var launch: PitchLaunchParameters = PitchLaunchBuilder.build_nominal(
					changed, setup, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), left, 55
				)
				_check(
					is_equal_approx(
						launch.gear_command_scale, float(item.get("command", 1.0)) * 0.85
					),
					"Rosin composes with hybrid penalty"
				)
				_check(
					launch.copy().gear_command_scale == launch.gear_command_scale,
					"launch copies preserve the modifier"
				)
				var aimed: PitchLaunchParameters = PitchAimSolver.solve(
					changed, setup, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), left, 55
				)
				var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
					aimed, 0
				)
				_check(
					crossing.crossed and crossing.point.y > 0.12 and crossing.velocity.is_finite(),
					"modified recipe still reaches the live plate"
				)
				_force_scaling(launch, item.movement)
				var neutral: PitchLaunchParameters = launch.copy()
				neutral.gear_command_scale = 1.0
				var before: PitchLaunchParameters = PitchExecutionModel.apply(
					neutral,
					0.7,
					0,
					changed.control_difficulty,
					changed.execution_difficulty,
					changed.category,
					21
				)
				var after: PitchLaunchParameters = PitchExecutionModel.apply(
					launch,
					0.7,
					0,
					changed.control_difficulty,
					changed.execution_difficulty,
					changed.category,
					21
				)
				_check(
					(after.position - launch.position).is_equal_approx(
						(before.position - launch.position) * launch.gear_command_scale
					),
					"seeded existing release error scaled once"
				)
				_check(
					(
						is_equal_approx(after.velocity.length(), before.velocity.length())
						and after.orientation.is_equal_approx(before.orientation)
					),
					"command modifier does not change speed or natural orientation noise"
				)
				_check(
					is_equal_approx(SeasonGearCatalog.factor(player, "workload"), 1.10),
					"Rosin workload penalty retained"
				)


func _force_scaling(parameters: PitchLaunchParameters, factor: float) -> void:
	var original: PitchLaunchParameters = parameters.copy()
	original.mastery_movement_scale /= factor
	var drag_only: PitchLaunchParameters = parameters.copy()
	drag_only.mastery_movement_scale = 0.0
	var baseline: Vector3 = _acceleration(drag_only)
	_check(
		(_acceleration(parameters) - baseline).is_equal_approx(
			(_acceleration(original) - baseline) * factor
		),
		"authored movement force scales; gravity/drag remain unchanged"
	)
	_check(
		(
			PitchAerodynamics.acceleration(
				Vector3.ZERO, Quaternion.IDENTITY, Vector3.ZERO, parameters
			)
			== PitchAerodynamics.GRAVITY_MPS2
		),
		"no Gear gravity scale"
	)


func _acceleration(parameters: PitchLaunchParameters) -> Vector3:
	return PitchAerodynamics.acceleration(
		parameters.velocity, parameters.orientation, parameters.angular_velocity, parameters
	)


func _transactions() -> void:
	var build: SeasonBuild = _two_bats(true)
	var first: String = _gear_offer(build, "bat")
	var second: String = _gear_offer(build, "bat", build.view().shop.offers[first])
	var request: Dictionary = _command(build, "equip", {"offer": first, "replace": ""})
	var before: Dictionary = build.to_data()
	_check(build.preview(request).ok and build.to_data() == before, "preview spends nothing")
	_check(build.commit(request).ok and build.cash() == 8, "first purchase paid from result income")
	_check(build.commit(request).replayed and build.cash() == 8, "repeated buy settles once")
	var receipt: Dictionary = build.view().wallet.gear.bat
	_reject(
		build, _command(build, "equip", {"offer": second, "replace": ""}), "explicit replacement"
	)
	_reject(
		build, _command(build, "equip", {"offer": second, "replace": "invented"}), "owned receipt"
	)
	request = _command(build, "equip", {"offer": second, "replace": receipt.id})
	_check(build.commit(request).ok and build.cash() == 3, "replacement can use sale proceeds")
	var replacement: Dictionary = build.view().wallet.gear.bat
	_check(
		replacement.paid == 10 and replacement.id != receipt.id, "full paid receipt not net five"
	)
	_reject(build, _command(build, "sell_gear", {"receipt": receipt.id}), "old receipt is gone")
	var loaded: SeasonBuild = SeasonBuild.from_data(
		JSON.parse_string(JSON.stringify(build.to_data())), build.to_data().seed, ROSTER
	)
	_check(loaded != null and loaded.view() == build.view(), "exact paid Gear replay")
	if loaded != null:
		_check(
			loaded.commit(_command(loaded, "sell_gear", {"receipt": replacement.id})).ok,
			"sell equipped item"
		)
		_check(
			loaded.cash() == 8 and loaded.definition(ROSTER[0]).season_gear.is_empty(),
			"sale restores neutral effects and credits five"
		)
	var poor: SeasonBuild = _two_bats(false)
	first = _gear_offer(poor, "bat")
	second = _gear_offer(poor, "bat", poor.view().shop.offers[first])
	_check(
		poor.commit(_command(poor, "equip", {"offer": first, "replace": ""})).ok, "poor buys first"
	)
	_reject(
		poor,
		_command(poor, "equip", {"offer": second, "replace": poor.view().wallet.gear.bat.id}),
		"unaffordable replacement changes nothing"
	)
	_reject(
		poor,
		_command(
			poor, "equip", {"offer": second, "replace": poor.view().wallet.gear.bat.id, "price": 0}
		),
		"no client price override"
	)


func _two_bats(win: bool) -> SeasonBuild:
	for seed_value in range(600):
		var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER)
		build.commit(_command(build, "reward", {"game": 0, "win": win}))
		build.commit(_command(build, "open"))
		var offers: Array = build.view().shop.offers.values()
		if offers.has("BAT-CON-01") and offers.has("BAT-POW-01"):
			return build
	_check(false, "two Bat fixture exists")
	return null


func _gear_offer(build: SeasonBuild, slot: String, except_id: String = "") -> String:
	for offer: String in build.view().shop.offers:
		var id: String = build.view().shop.offers[offer]
		if id != except_id and SeasonGearCatalog.item(id).get("slot", "") == slot:
			return offer
	return ""


func _command(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"id": "gear-test:%d" % build.revision(), "rev": build.revision(), "op": op
	}
	result.merge(fields)
	return result


func _reject(build: SeasonBuild, command: Dictionary, message: String) -> void:
	var data: Dictionary = build.to_data()
	var view: Dictionary = build.view()
	_check(
		not build.commit(command).ok and build.to_data() == data and build.view() == view, message
	)


func _gear_ui() -> void:
	var prefix: String = "user://gear-ui-%d" % OS.get_process_id()
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(_two_bats(true).to_data().seed, true)
	# Historical score-only fixture; physical rounds have separate integration coverage.
	app.season.physical = null
	app.season.opponents._format = 2
	for _pick in range(4):
		app.choose_player(app.season.offers()[0])
	_record(app.season)
	_check(app._checkpoint(), "save completed real fixture")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	var offer: String = _gear_offer(app.season.build, "bat")
	_check(not offer.is_empty(), "season fixture offers Gear")
	if offer.is_empty():
		app.queue_free()
		return
	await _shop_bounds(window, "gear-shop-normal")
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "gear-shop-narrow")
	var before: Dictionary = app.season.build.to_data()
	await _click(_gear_button(window, "gear_offer", offer))
	_check(
		window._confirm.visible and window._review_text.text.contains("Cash: 18 → 8"),
		"Gear review shows exact cost"
	)
	_check(
		window._confirm.gui_get_focus_owner() == window._confirm.get_cancel_button(),
		"Gear review starts focused on Cancel"
	)
	await _capture(window._confirm, "gear-confirm")
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "Cancel preserves cash, Gear and stock")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = prefix + "/missing/save.json"
	await _click(_gear_button(window, "gear_offer", offer))
	await _click(window._confirm.get_ok_button())
	_check(app.season.build.to_data() == before, "failed disk write rolls back Gear purchase")
	SeasonSave.path = prefix + ".json"
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == bytes, "failed write preserves old bytes"
	)
	await _click(_gear_button(window, "gear_offer", offer))
	await _click(window._confirm.get_ok_button())
	_check(app.season.cash() == 8, "actual confirm equips and saves")
	var receipt: Dictionary = app.season.build.view().wallet.gear.bat
	var second: String = _gear_offer(app.season.build, "bat", receipt.item)
	_check(not second.is_empty(), "replacement offered")
	if not second.is_empty():
		await _click(_gear_button(window, "gear_offer", second))
		_check(
			(
				window._review_text.text.contains("Sell ")
				and window._review_text.text.contains("Cash: 8 → 3")
			),
			"review includes sale proceeds"
		)
		await _capture(window._confirm, "gear-replacement")
		await _click(window._confirm.get_ok_button())
		_check(app.season.cash() == 3, "actual replacement click spends net five")
	await _shop_bounds(window, "gear-equipped")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == app.season.build.view(), "Gear save reload"
	)
	await _click(window._back)
	app.season = restored
	app.play_season_game()
	await _frames(5)
	_check(app.lab != null, "paid Gear reaches actual next match")
	if app.lab != null:
		await _live_actors(app.lab)
		app.leave_game()
	app.open_shop()
	await _frames()
	window = _shop(app)
	receipt = app.season.build.view().wallet.gear.bat
	await _click(_gear_button(window, "gear_sell", receipt.id))
	await _click(window._confirm.get_ok_button())
	_check(
		app.season.cash() == 8 and app.season.build.view().wallet.gear.bat.is_empty(),
		"actual sale click restores neutral slot"
	)
	_migration(app.season)
	app.queue_free()
	await _frames()
	for path: String in [prefix + ".json", prefix + ".cfg"]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)


func _live_actors(lab: PitchBatLab) -> void:
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var own: TeamMatchState = (
		lab._match_state.home_team if lab._player_home else lab._match_state.away_team
	)
	for player: PlayerMatchState in own.roster:
		_check(
			player.definition.season_gear.has("bat"), "all four paid team members get shared Bat"
		)
	var rival: TeamMatchState = (
		lab._match_state.away_team if lab._player_home else lab._match_state.home_team
	)
	for player: PlayerMatchState in rival.roster:
		_check(player.definition.season_gear.is_empty(), "opponents cannot inherit our paid Gear")
	# Exercise the same launch/swing path with both input ownership modes.
	for human: bool in [true, false]:
		lab._player_home = human
		lab._match_state.phase = MatchState.Phase.PRE_PITCH
		lab._match_state.between_batters = true
		lab._pitch_actor.reset_pitch()
		lab._selected_pitch_index = 0
		lab._ai_pitch_preselected = true
		lab._pitch_effort = 1.0
		lab._pending_release_quality = 1.0
		lab._pitch_target = Vector2(0, 1.05)
		var pitcher: PlayerMatchState = lab._match_state.pitcher()
		pitcher.definition = SeasonGearCatalog.equip(
			pitcher.definition, {"ball": {"item": "BALL-HYB-01"}, "misc": {"item": "MISC-PIT-03"}}
		)
		var batter: PlayerMatchState = lab._match_state.batter()
		batter.definition = SeasonGearCatalog.equip(
			batter.definition, {"bat": {"item": "BAT-CON-01"}}
		)
		lab._refresh_config()
		var stamina: float = pitcher.stamina_remaining
		var cost: float = MatchLabSupport.stamina_cost(lab._selected_pitch(), 1.0) * 1.10
		lab._throw_pitch()
		_check(lab._pitch_actor.running, "real human/AI Gear pitch launches")
		_check(
			is_equal_approx(lab._pitch_actor.parameters.gear_command_scale, 0.935),
			"live actor receives hybrid/Rosin stack"
		)
		_check(
			is_equal_approx(stamina - pitcher.stamina_remaining, cost),
			"real release spends workload penalty exactly once"
		)
		lab._resolve_swing(PitchBatLab.CONTACT_SWING_ID, Vector2(0, 1.05))
		_check(
			lab._swing_tracker.profile.gear_fair_exit_scale == 0.96,
			"real human/AI swing receives Bat"
		)
		await _frames(1)


func _migration(source: SeasonState) -> void:
	for format_version: int in [1, 2]:
		var season: SeasonState = SeasonState.create(source.season_seed, false, true)
		for _pick in range(4):
			season.choose_player(season.offers()[0])
		season.build._format = format_version
		_record(season)
		season.build.commit(_command(season.build, "open"))
		_check(SeasonSave.save(season), "write legacy schema fixture")
		var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
		var before: Dictionary = season.build.view()
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and restored.build.view() == before, "migration preserves open stock"
		)
		_check(
			FileAccess.get_file_as_string(SeasonSave.path) == bytes, "loading never rewrites file"
		)
		if restored != null:
			_check(restored.build.to_data().gear_from == 2, "Gear activation delayed one visit")
			_check(
				SeasonSave.save(restored) and SeasonSave.restore() != null, "schema7 stable replay"
			)
			_record(restored)
			restored.build.commit(_command(restored.build, "open"))
			_check(
				SeasonSave.save(restored) and SeasonSave.restore() != null,
				"new visit after migration"
			)


func _record(season: SeasonState) -> void:
	var fixture: Dictionary = season.pending_fixture()
	_check(
		season.record_player_result(
			fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0
		),
		"complete actual next fixture"
	)


func _gear_button(window: SeasonShopWindow, meta: String, value: String) -> Button:
	for child in window._body.find_children("*", "Control", true, false):
		if child is Button and child.get_meta(meta, "") == value:
			return child
	return null
