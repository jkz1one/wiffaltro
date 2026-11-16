extends "res://src/tests/season_sponsor_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_optics_contract()
	_field_contract()
	_migration()
	await _choice_ui()
	await _runtime_tags()
	await _runtime_thresholds()
	await _sponsor_ui(SeasonSponsorCatalog.FIELD_ITEMS)
	DirAccess.remove_absolute("user://field-sponsor-test-%d.json" % OS.get_process_id())
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro field sponsor checks passed: shapes, races, paid UI and migration.")
	get_tree().quit(0 if _failures == 0 else 1)


func _field_fixture() -> MatchState:
	var state: MatchState = _fixture()
	for team: TeamMatchState in [state.home_team, state.away_team]:
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors = {"F02": true, "F03": true, "G04": true}
	return state


func _optics_contract() -> void:
	var state: MatchState = _field_fixture()
	var contact: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var power: SwingProfileDefinition = ContentDB.get_swing(&"swing.power")
	state.batter().definition.season_gear = {"bat": "BAT-CON-01"}
	for mode: String in ["normal", "wide", "tall"]:
		_check(SeasonSponsorEffects.choose_optics(state, mode), "legal pre-PA mode")
		var axes: Vector2 = SeasonSponsorEffects.optics_axes(mode)
		var changed: SwingProfileDefinition = SeasonSponsorEffects.swing(contact, state)
		_check(
			(
				is_equal_approx(
					changed.contact_radius_x_m / contact.contact_radius_x_m, 1.06 * axes.x
				)
				and is_equal_approx(
					changed.contact_radius_y_m / contact.contact_radius_y_m, 1.06 * axes.y
				)
			),
			"Gear then once-only multiplicative Optics ellipse"
		)
		var power_changed: SwingProfileDefinition = SeasonSponsorEffects.swing(power, state)
		var gear_power: SwingProfileDefinition = SeasonGearCatalog.swing(
			power, state.batter().definition
		)
		_check(
			(
				power_changed.contact_radius_x_m == gear_power.contact_radius_x_m
				and power_changed.contact_radius_y_m == gear_power.contact_radius_y_m
			),
			"Optics never changes Power"
		)
	_check(not SeasonSponsorEffects.choose_optics(state, "automatic"), "no automatic pitch read")
	_check(state.begin_pitch(), "begin first pitch")
	state.cancel_pitch()
	_check(SeasonSponsorEffects.choose_optics(state, "wide"), "canceled windup can still choose")
	state.begin_pitch()
	state.record_foul()
	state.continue_after_dead_ball()
	_check(
		not SeasonSponsorEffects.choose_optics(state, "tall") and state.optics_mode == "wide",
		"foul locks choice for rest of PA"
	)
	state.defensive_team().select_pitcher(2)
	_check(state.optics_mode == "wide", "pitcher changes cannot reset batting choice")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	_check(state.optics_mode == "normal", "next PA defaults neutral")
	state.batter().definition.season_sponsors = {}
	_check(not SeasonSponsorEffects.choose_optics(state, "wide"), "unowned choice rejected")


func _field_contract() -> void:
	var state: MatchState = _field_fixture()
	var player: PlayerDefinition = state.fielder().definition
	_check(
		SeasonSponsorEffects.ground_margin(player, true) == -0.08,
		"Courier grounded penalty also applies with empty bases"
	)
	_check(SeasonSponsorEffects.ground_margin(player, false) == 0.0, "air control unchanged")
	var clean: int = FieldingResolver.resolve(0, 30, 0.5, true, 6)
	var penalized: int = FieldingResolver.resolve(0, 30, 0.5, true, 6, 0, 1, -0.08)
	_check(
		clean == FieldingResolver.Outcome.CLEAN and penalized == FieldingResolver.Outcome.BOBBLE,
		"ground margin can change clean to bobble without new randomness"
	)
	_check(
		FieldingResolver.resolve(2, 0, 0.5, true, 6, 0, 1, -0.08) == FieldingResolver.Outcome.MISS,
		"ordinary reach still required"
	)
	_check(
		FieldingResolver.resolve(0, 0, 3, true, 6, 0, 1, -0.08) == FieldingResolver.Outcome.MISS,
		"ordinary height still required"
	)
	for courier: bool in [false, true]:
		for trainers: bool in [false, true]:
			var bases: BaseState = BaseState.new()
			bases.first = &"first"
			bases.second = &"second"
			bases.third = &"third"
			var result: TagAdvanceResult = TagAdvanceResolver.resolve(
				bases, Vector3(0, 1, 17), 6, 0.75 if courier else 1.0, 0.88 if trainers else 1.0
			)
			_check(
				result.runs_scored == (1 if trainers and not courier else 0),
				"Courier and Trainers compare actual times, no scripted cancellation"
			)
			_check(bases.first == &"first", "never first-to-second")
			_check(
				is_equal_approx(result.gather_seconds, 0.67 * (0.75 if courier else 1.0)),
				"only gather reduced"
			)
			_check(
				(
					is_equal_approx(result.home_travel_seconds, 2.068 if trainers else 2.35)
					and is_equal_approx(result.third_travel_seconds, 2.508 if trainers else 2.85)
				),
				"only two legal tag travel times reduced"
			)
			if courier or trainers:
				_check(result.description.contains("Tag + margin / return"), "effective race shown")
	var bases: BaseState = BaseState.new()
	bases.second = &"second"
	var result: TagAdvanceResult = TagAdvanceResolver.resolve(bases, Vector3(12, 1, 15), 6, 1, 0.88)
	_check(result.advanced_from_second and bases.third == &"second", "second-to-third tag enabled")


func _migration() -> void:
	SeasonSave.path = "user://field-sponsor-migration-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(_seed_for("B03", 8), false, true)
	for _pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 8
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
					{"offer": _offer(season.build, "B03"), "replace": ""}
				)
			)
			. ok
		),
		"buy schema12 Strikecraft"
	)
	var before: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save genuine schema12")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == before, "preserve paid stock and cash")
	_check(FileAccess.get_file_as_string(SeasonSave.path) == bytes, "load does not rewrite")
	_check(restored.build.to_data().field_sponsor_from == 2, "expanded pool starts next visit")
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		restored.build.view().shop.offers == season.build.view().shop.offers,
		"current visit rerolls use frozen old pool"
	)
	_check(
		SeasonSave.save(restored) and SeasonSave.restore() != null, "schema13 current visit replays"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		SeasonSave.save(restored) and SeasonSave.restore() != null, "expanded next visit replays"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _choice_ui() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _field_fixture()
	lab._player_home = false
	add_child(lab)
	lab._record_export.path = "user://field-sponsor-test-%d.json" % OS.get_process_id()
	await _frames(4)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._awaiting_batter_confirm = true
	lab._ai_pitch_preselected = false
	lab._refresh_config()
	await _frames(2)
	var controls: MatchSponsorControls = lab.find_child("SponsorControls", true, false)
	var button: Button = controls._choice
	_check(
		button.visible and button.focus_mode == Control.FOCUS_ALL,
		"visible keyboard-focusable choice"
	)
	await _click(button)
	_check(lab._match_state.optics_mode == "wide", "actual viewport click chooses wide")
	var ellipse: Node3D = lab._batting_aim_marker.get_node("OpticsCoverage")
	var profile: SwingProfileDefinition = SeasonSponsorEffects.swing(
		ContentDB.get_swing(&"swing.contact"), lab._match_state
	)
	_check(
		(
			ellipse.visible
			and is_equal_approx(ellipse.scale.x, profile.contact_radius_x_m)
			and is_equal_approx(ellipse.scale.y, profile.contact_radius_y_m)
		),
		"visible ellipse matches actual radii"
	)
	_check(
		not lab._batting_aim_marker.get_node("ContactCoverage").visible,
		"no misleading old rectangle"
	)
	_check(lab._batting_aim_marker.get_node("PowerCoverage").visible, "Power coverage preserved")
	await _capture(get_viewport(), "optics-wide")
	button.grab_focus()
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = pressed
		get_viewport().push_input(key)
		await _frames(1)
	_check(lab._match_state.optics_mode == "tall", "keyboard Enter cycles choice")
	_check(lab._awaiting_batter_confirm, "choice does not start at-bat")
	_check(
		button.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y,
		"choice remains within match viewport"
	)
	lab._ai_pitch_preselected = true
	await _frames(2)
	_check(not button.visible, "choice hides before pitcher reveals committed selection")
	controls._choose()
	_check(lab._match_state.optics_mode == "tall", "stale UI action cannot change locked selection")
	lab.queue_free()
	await _frames(2)


func _runtime_tags() -> void:
	for grounded: bool in [false, true]:
		for outs: int in [0, 2]:
			for defender: StringName in [&"pitcher", &"primary_fielder"]:
				var lab: PitchBatLab = PitchBatLab.new()
				lab._configured_match = _field_fixture()
				add_child(lab)
				lab._record_export.path = "user://field-sponsor-test-%d.json" % OS.get_process_id()
				PitchBatLabFeelSupport.skip_match_presentation(lab)
				lab.set_process(false)
				lab.set_physics_process(false)
				lab._primary_fielder.set_physics_process(false)
				lab._match_state.outs = outs
				lab._match_state.bases.third = &"third"
				lab._match_state.bases.first = &"first"
				var launch: BattedBallLaunch = BattedBallLaunch.new()
				launch.position = Vector3(0, 0.4, 8 if grounded else 22)
				launch.velocity = Vector3(0, 0, 8)
				lab._start_ball_in_play(launch)
				if grounded:
					lab._ball_play_resolver.record_ground_contact(Vector3(0, 0.04, 3))
				lab._apply_fielding_outcome(
					defender, launch.position, FieldingResolver.Outcome.CLEAN
				)
				var expected: int = 1 if not grounded and outs == 0 else 0
				_check(
					lab._match_state.away_team.runs == expected,
					"actual catcher hook: no ground or third-out tags"
				)
				if not grounded and outs == 0:
					_check(
						lab._status_label.text.contains("Tag + margin / return"),
						"actual result explains race"
					)
				lab.queue_free()
				await _frames(2)


func _runtime_thresholds() -> void:
	for courier: bool in [false, true]:
		for trainers: bool in [false, true]:
			for defender: StringName in [&"pitcher", &"primary_fielder"]:
				var lab: PitchBatLab = _controlled_lab()
				lab._match_state.pitcher().definition.season_sponsors.F02 = courier
				lab._match_state.fielder().definition.season_sponsors.F02 = courier
				lab._match_state.batter().definition.season_sponsors.G04 = trainers
				lab._match_state.bases.third = &"third"
				var launch: BattedBallLaunch = BattedBallLaunch.new()
				launch.position = Vector3(0, 0.4, 17)
				launch.velocity = Vector3(0, 0, 8)
				lab._start_ball_in_play(launch)
				lab._apply_fielding_outcome(
					defender, launch.position, FieldingResolver.Outcome.CLEAN
				)
				_check(
					lab._match_state.away_team.runs == (1 if trainers and not courier else 0),
					"live marginal race consumes both actual owner effects for either catcher"
				)
				if courier or trainers:
					PitchBatLabPresentation.refresh_event(lab)
					await _frames(2)
					_check(
						lab._status_label.get_minimum_size().y <= 134,
						"effective tag explanation fits event panel"
					)
				lab.queue_free()
				await _frames(2)
	for courier: bool in [false, true]:
		var lab: PitchBatLab = _controlled_lab()
		lab._match_state.fielder().definition.season_sponsors.F02 = courier
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(0, 0.5, 8)
		launch.velocity = Vector3(0, 0, 30)
		lab._start_ball_in_play(launch)
		lab._ball_play_resolver.record_ground_contact(Vector3(0, 0.04, 3))
		lab._primary_fielder.global_position = Vector3(0, 0, 8)
		lab._primary_fielder.last_reaction_margin_seconds = 0.0
		lab._try_primary_fielder()
		_check(
			lab._last_fielding_text.contains("BOBBLE" if courier else "CLEAN"),
			"actual empty-base Primary encounter applies Courier penalty"
		)
		_check(
			(
				PitcherDefense.resolve(launch.position, launch.velocity, Vector3(0, 0, 8), true, 6)
				== FieldingResolver.Outcome.CLEAN
			),
			"Pitcher ground control stays neutral"
		)
		lab.queue_free()
		await _frames(2)


func _controlled_lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _field_fixture()
	lab._configured_match.pitcher().definition.fielding = 6
	lab._configured_match.fielder().definition.fielding = 6
	add_child(lab)
	lab._record_export.path = "user://field-sponsor-test-%d.json" % OS.get_process_id()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	return lab
