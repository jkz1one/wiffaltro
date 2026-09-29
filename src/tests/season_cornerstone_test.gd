extends "res://src/tests/season_field_sponsor_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_contract()
	await _controller_contract()
	await _choice_ui()
	await _encounters()
	_migration()
	await _sponsor_ui(SeasonSponsorCatalog.ANCHOR_ITEMS)
	DirAccess.remove_absolute("user://field-sponsor-test-%d.json" % OS.get_process_id())
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Cornerstone checks passed: lock, fixed pursuit, control, paid UI and migration."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _field_fixture() -> MatchState:
	var state: MatchState = super._field_fixture()
	for team: TeamMatchState in [state.home_team, state.away_team]:
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors.F01 = true
	return state


func _controlled_lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _field_fixture()
	lab._configured_match.pitcher().definition.fielding = 6
	lab._configured_match.fielder().definition.fielding = 6
	lab._player_home = true
	add_child(lab)
	lab._record_export.path = "user://field-sponsor-test-%d.json" % OS.get_process_id()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	return lab


func _contract() -> void:
	var state: MatchState = _field_fixture()
	_check(not state.cornerstone_anchored, "default normal")
	_check(SeasonCornerstone.choose(state, true), "explicit pre-PA anchor")
	_check(state.begin_pitch(), "first delivery starts")
	_check(not SeasonCornerstone.choose(state, false), "delivery locks mode")
	state.cancel_pitch()
	_check(SeasonCornerstone.choose(state, false), "canceled first pitch retains pre-PA choice")
	SeasonCornerstone.choose(state, true)
	state.begin_pitch()
	state.record_foul()
	state.continue_after_dead_ball()
	_check(SeasonCornerstone.position_locked(state), "foul preserves whole-PA position lock")
	_check(not SeasonCornerstone.choose(state, false), "later pitches cannot change mode")
	state.defensive_team().select_pitcher(2)
	_check(state.cornerstone_anchored, "pitcher assignment cannot erase mode")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	_check(not state.cornerstone_anchored, "completed PA resets choice")
	state.fielder().definition.season_sponsors.erase("F01")
	_check(not SeasonCornerstone.choose(state, true), "unowned cannot anchor")
	var speed: float = (1.07 - 0.08) / 0.028
	_check(
		FieldingResolver.resolve(0, speed, 0.5, true, 6) == FieldingResolver.Outcome.BOBBLE,
		"control margin0.08 is ordinary bobble"
	)
	_check(
		(
			FieldingResolver.resolve(0, speed, 0.5, true, 6, 0, 1, 0.12)
			== FieldingResolver.Outcome.CLEAN
		),
		"qualified margin0.20 is clean"
	)
	_check(
		FieldingResolver.resolve(2, 0, 0.5, true, 6, 0, 1, 0.12) == FieldingResolver.Outcome.MISS,
		"bonus never expands reach"
	)
	_check(
		FieldingResolver.resolve(0, 0, 3, false, 6, 0, 1, 0.12) == FieldingResolver.Outcome.MISS,
		"bonus never expands height"
	)
	var normal: FielderPlan = FielderPlanner.plan(
		Vector3(2, 0.5, 0), Vector3.ZERO, true, Vector3.ZERO, 5.0, 0.66
	)
	var fixed: FielderPlan = FielderPlanner.plan(
		Vector3(2, 0.5, 0), Vector3.ZERO, true, Vector3.ZERO, 5.0, 0.66, true
	)
	_check(normal.reachable and not fixed.reachable, "planner cannot assume forbidden travel")


func _controller_contract() -> void:
	var fielder: FielderController = FielderController.new()
	add_child(fielder)
	fielder.set_physics_process(false)
	fielder.set_anchor(Vector3(5.5, 0, 8.5))
	var original: Vector3 = fielder.global_position
	for anchored: bool in [true, false]:
		fielder.begin_play(anchored)
		for frame in range(90):
			fielder.plan_for_ball(original + Vector3(3, 0.5, 0), Vector3.ZERO, true)
			fielder._physics_process(1.0 / 60.0)
		_check(
			(fielder.global_position == original) == anchored,
			"anchored controller stays fixed; ordinary pursuit travels"
		)
		if anchored:
			fielder.target_position += Vector3(20, 0, 0)
			fielder._physics_process(1.0)
			_check(
				fielder.global_position == original and fielder.velocity == Vector3.ZERO,
				"stale target cannot cause a hidden lunge"
			)
		fielder.end_play()
	_check(not fielder.stationary, "end play clears stationary runtime")
	fielder.queue_free()
	await _frames(2)


func _choice_ui() -> void:
	var lab: PitchBatLab = _controlled_lab()
	await _frames(3)
	lab._field_setup_active = true
	lab._refresh_config()
	await _frames(2)
	var controls: MatchSponsorControls = lab.find_child("SponsorControls", true, false)
	var button: Button = controls._anchor_choice
	_check(button.is_visible_in_tree() and not button.disabled, "visible legal field choice")
	await _click(button)
	_check(lab._match_state.cornerstone_anchored, "actual click anchors Primary")
	MatchLabSupport.select_fielder_anchor(lab, 0)
	_check(lab._fielder_anchor_index == 0, "legal shallow side remains selectable pre-PA")
	MatchLabSupport.select_fielder_anchor(lab, 1)
	_check(lab._fielder_anchor_index == 0, "reserved pitcher lane stays unavailable")
	button.grab_focus()
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = pressed
		get_viewport().push_input(key)
		await _frames(1)
	_check(not lab._match_state.cornerstone_anchored, "keyboard can restore normal")
	await _click(button)
	await _capture(get_viewport(), "cornerstone-anchor")
	for hud: int in range(3):
		lab._hud_anchor_index = hud
		lab._refresh_config()
		await _frames(2)
		_check(
			(
				lab._field_setup_panel.get_global_rect().end.y
				<= get_viewport().get_visible_rect().end.y
			),
			"field menu fits every supported HUD anchor"
		)
	lab._field_setup_active = false
	lab._refresh_config()
	_check(
		lab._field_setup_toggle_button.text == "FIELD: ANCHOR",
		"active commitment stays visible outside field menu"
	)
	PitchBatLabFeelSupport.begin_pitch_release(lab)
	_check(not MatchSponsorControls.can_choose_anchor(lab), "windup locks UI choice")
	controls._choose_anchor()
	_check(lab._match_state.cornerstone_anchored, "stale callback cannot cancel commitment")
	PitchBatLabFeelSupport.cancel_release(lab)
	_check(MatchSponsorControls.can_choose_anchor(lab), "canceled windup restores choice")
	lab._match_state.begin_pitch()
	lab._match_state.record_foul()
	lab._match_state.continue_after_dead_ball()
	MatchLabSupport.select_fielder_anchor(lab, 2)
	_check(lab._fielder_anchor_index == 0, "foul cannot reposition anchored fielder")
	lab._field_setup_active = true
	lab._refresh_config()
	await _frames(2)
	_check(button.disabled and button.text.contains("Locked"), "locked mode remains disclosed")
	lab._match_state.record_ball_in_play_out()
	lab._match_state.continue_after_dead_ball()
	lab._refresh_config()
	await _frames(2)
	_check(
		not button.disabled and not lab._match_state.cornerstone_anchored,
		"next batter offers normal choice again"
	)
	lab.queue_free()
	await _frames(2)


func _encounters() -> void:
	for scenario: Array in [[false, false], [false, true], [true, false], [true, true]]:
		var grounded: bool = scenario[0]
		var courier: bool = scenario[1]
		for reaction: float in [-0.01, 0.0]:
			var lab: PitchBatLab = _controlled_lab()
			lab._match_state.fielder().definition.season_sponsors.F02 = courier
			MatchLabSupport.select_fielder_anchor(lab, 0)
			SeasonCornerstone.choose(lab._match_state, true)
			var launch: BattedBallLaunch = BattedBallLaunch.new()
			launch.position = lab._primary_fielder.anchor_position + Vector3(0, 0.5, 0)
			launch.velocity = Vector3(0, 0, (1.07 - 0.08) / (0.028 if grounded else 0.030))
			lab._start_ball_in_play(launch)
			if grounded:
				lab._ball_play_resolver.record_ground_contact(launch.position)
			lab._try_primary_fielder()
			_check(lab._primary_attempts == 0, "anchor does not bypass initial reaction")
			lab._primary_fielder._physics_process(0.3)
			lab._primary_fielder.last_reaction_margin_seconds = reaction
			_check(
				is_equal_approx(
					SeasonCornerstone.margin(lab._match_state, lab._primary_fielder),
					0.12 if reaction >= 0 else 0.0
				),
				"nonnegative reaction gates margin"
			)
			lab._try_primary_fielder()
			_check(
				lab._last_fielding_text.contains(
					"CLEAN" if reaction >= 0 and not (grounded and courier) else "BOBBLE"
				),
				"actual air/ground control applies Cornerstone and only grounded Courier penalty"
			)
			lab.queue_free()
			await _frames(2)
	var foul: PitchBatLab = _controlled_lab()
	SeasonCornerstone.choose(foul._match_state, true)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(5.5, 0.5, 8.5)
	launch.velocity = Vector3(8, 0, 0)
	launch.is_foul = true
	foul._start_ball_in_play(launch)
	_check(not foul._primary_fielder.stationary, "foul ball retains ordinary pursuit")
	_check(
		SeasonCornerstone.margin(foul._match_state, foul._primary_fielder) == 0,
		"no fair-ball bonus on foul contact"
	)
	foul.queue_free()
	await _frames(2)


func _paid_season() -> SeasonState:
	var season: SeasonState = _funded_season(_sponsor_seed("F01", 3), 3)
	_check(
		(
			season
			. build
			. commit(
				_command(
					season.build,
					"sponsor_buy",
					{"offer": _offer(season.build, "F01"), "replace": ""}
				)
			)
			. ok
		),
		"full-price Cornerstone in actual generated season"
	)
	return season


func _migration() -> void:
	SeasonSave.path = "user://cornerstone-migrate-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(_seed_for("F04", 11), false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 11
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
					{"offer": _offer(season.build, "F04"), "replace": ""}
				)
			)
			. ok
		),
		"actual paid schema15"
	)
	var before: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save old paid shop")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == before, "old paid stock remains exact")
	_check(
		(
			restored.build.to_data().anchor_sponsor_from == 2
			and FileAccess.get_file_as_string(SeasonSave.path) == bytes
		),
		"next-visit gate; no load rewrite"
	)
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		restored.build.view().shop.offers == season.build.view().shop.offers,
		"same-visit rerolls keep catalogue6"
	)
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "migrated visit replays")
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(restored.build._sponsor_catalog_version() == 7, "next visit enables Cornerstone")
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "new visit replays")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
