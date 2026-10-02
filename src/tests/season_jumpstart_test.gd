extends "res://src/tests/season_freezers_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://jumpstart-%d.json" % OS.get_process_id()
	_jump_contract()
	await _jump_motion()
	await _jump_contacts()
	_jump_progress()
	_jump_migration()
	await _jump_ui()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Jumpstart checks passed: commitment, constrained motion, earned access, saves and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _jump_result(season: SeasonState, qualify: bool = true, win: bool = true) -> bool:
	var game: Dictionary = season.pending_fixture()
	var own: Array = season.teams[0].roster
	var rival: Array = season.teams[game.away if game.home == 0 else game.home].roster
	var stats: MatchPerformance = MatchPerformance.new()
	var rows: Array = []
	for index in range(3):
		stats.complete(StringName(rival[index]), StringName(own[0]), "out", 0)
		rows.append(
			{
				"pa": index + 1,
				"half": 0 if game.home == 0 else 1,
				"player": own[1] if qualify else own[1 + index],
				"pitcher": own[0],
				"primary": true,
				"air": index == 0,
				"clean": true
			}
		)
	for id: String in own + rival:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	var home_wins: bool = (game.home == 0) == win
	return season.record_player_result(
		game.id, 0 if home_wins else 1, 1 if home_wins else 0, stats.players, [], [], {}, [], rows
	)


func _jump_contract() -> void:
	var state: MatchState = _new_club(67).make_match()
	state.fielder().definition.season_sponsors = {"J04": true, "F01": true}
	_check(state.jumpstart_mode == "normal", "default baseline")
	_check(SeasonJumpstart.choose(state, "left"), "pre-PA choice")
	_check(not SeasonCornerstone.choose(state, true), "no anchor plus jump")
	state.begin_pitch()
	_check(not SeasonJumpstart.choose(state, "right"), "first pitch locks choice")
	state.cancel_pitch()
	_check(SeasonJumpstart.choose(state, "right"), "canceled windup releases choice")
	state.begin_pitch()
	state.record_foul()
	state.continue_after_dead_ball()
	_check(not SeasonJumpstart.choose(state, "in"), "foul retains full PA commitment")
	_check(SeasonJumpstart.direction(state) == Vector3.LEFT, "field Right matches anchor axis")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	_check(state.jumpstart_mode == "normal", "next batter clears commitment")
	state.continue_after_dead_ball()
	_check(SeasonCornerstone.choose(state, true), "anchor from Normal")
	_check(not SeasonJumpstart.choose(state, "out"), "anchor blocks step")
	SeasonCornerstone.choose(state, false)
	_check(not SeasonJumpstart.choose(state, "diagonal"), "no unsupported direction")
	state.fielder().definition.season_sponsors.erase("J04")
	_check(not SeasonJumpstart.choose(state, "left"), "unowned has no choice")
	# Capture through the real resolver, including bobble recovery and foul catches.
	for kind: String in ["clean", "bobble", "foul", "pitcher"]:
		var resolver: BallPlayResolver = BallPlayResolver.new()
		resolver.start_play(ContentDB.get_field(&"field.starter_backyard"), kind == "foul")
		if kind == "bobble":
			resolver.record_bobble(&"primary_fielder", Vector3(0, 1, 15))
		var outcomes: Array = []
		resolver.play_resolved.connect(
			func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
		)
		resolver.record_clean_control(
			&"pitcher" if kind == "pitcher" else &"primary_fielder", Vector3(0, 1, 15), true
		)
		state.clean_outs.record(state, resolver.state, outcomes[0])
		state.clean_outs.record(state, resolver.state, outcomes[0])
		state.record_ball_in_play_out()
		state.continue_after_dead_ball()
	_check(state.clean_outs.rows.size() == 4, "duplicate callbacks cannot double-credit")
	_check(
		(
			state.clean_outs.rows[0].clean
			and not state.clean_outs.rows[1].clean
			and not state.clean_outs.rows[2].clean
			and not state.clean_outs.rows[3].primary
		),
		"clean, bobble, foul and pitcher distinguish correctly"
	)
	_check(not SeasonJumpstart.qualifies(state.clean_outs.rows), "only qualifying Primary counts")


func _jump_motion() -> void:
	var fielder: FielderController = FielderController.new()
	add_child(fielder)
	fielder.set_physics_process(false)
	fielder.move_speed_mps = 4
	for reaction: float in [0.10, 0.30]:
		for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			fielder.reaction_delay_seconds = reaction
			fielder.set_anchor(Vector3.ZERO)
			fielder.begin_play(false, direction)
			for frame in range(12):
				fielder.plan_for_ball(-direction * 10, Vector3.ZERO, true)
				fielder._physics_process(1.0 / 60)
			_check(
				fielder.global_position.is_equal_approx(direction * 0.8),
				"exact 0.8m committed step"
			)
			_check(fielder.target_position == Vector3.ZERO, "no early trajectory pursuit")
			_check(fielder.pursuit_ready() == (reaction < 0.20), "both delays gate pursuit")
			fielder._physics_process(0.101)
			fielder.plan_for_ball(-direction * 10, Vector3.ZERO, true)
			_check(
				fielder.target_position != Vector3.ZERO,
				"planner resumes from actual stepped position"
			)
			fielder.end_play()
	# Large frame cannot lengthen the committed interval.
	fielder.begin_play(false, Vector3.RIGHT)
	fielder._physics_process(0.7)
	_check(fielder.global_position.is_equal_approx(Vector3(0.8, 0, 0)), "large-delta step capped")
	fielder.end_play()
	fielder.pitcher_lane_z = 0
	fielder.set_anchor(Vector3(1.7, 0, 0))
	fielder.begin_play(false, Vector3.LEFT)
	fielder._physics_process(0.2)
	_check(
		fielder.global_position.x >= 1.549 and fielder.global_position.z == 0,
		"pitcher blocks movement without secretly steering guess"
	)
	_check(fielder._play_elapsed_seconds >= 0.2, "collision spends time")
	fielder.end_play()
	fielder.pitcher_lane_z = INF
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.1, 3, 3)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.6, 1, 0)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	fielder.set_anchor(Vector3.ZERO)
	fielder.begin_play(false, Vector3.RIGHT)
	fielder._physics_process(0.2)
	_check(fielder.global_position.x < 0.4, "physical wall clips first step")
	_check(
		not FielderFirstStep.unobstructed(fielder, Vector3(0.8, 0.5, 0)), "no control through wall"
	)
	fielder.end_play()
	wall.queue_free()
	fielder.queue_free()
	await _frames()


func _jump_progress() -> void:
	var loss: SeasonState = _new_club(67)
	_check(_jump_result(loss, true, false) and loss.build._jump_earned, "loss earns access")
	var split: SeasonState = _new_club(67)
	_check(
		_jump_result(split, false) and not split.build._jump_earned,
		"three different fielders do not combine"
	)
	var season: SeasonState = _paid_jump(false)
	_check(SeasonSave.save(season), "earned stock saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for field: String in [
		"count", "player", "pitcher", "half", "order", "career", "start", "result", "type"
	]:
		var bad: Dictionary = data.duplicate(true)
		match field:
			"count":
				bad.build.events[0].fielding.pop_back()
			"player":
				bad.build.events[0].fielding[0].player = "foreign"
			"pitcher":
				bad.build.events[0].fielding[0].primary = false
			"half":
				bad.results[0].fielding[0].half += 1
			"order":
				bad.build.events[0].fielding[1].pa = 1
			"career":
				bad.career.runs[-1].jump_earned = false
			"start":
				bad.build.jump_start = true
			"result":
				bad.results[0].fielding.reverse()
			"type":
				bad.build.events[0].fielding[0].clean = 1
		_check(SeasonSave._decode(bad) == null, "reject forged evidence " + field)
	var unchanged: Dictionary = season.build.to_data()
	var invalid: Dictionary = _command(
		season.build, "reward", {"game": 31, "win": true, "performance": 5, "fielding": [{"pa": 1}]}
	)
	_check(
		not season.build.commit(invalid).ok and season.build.to_data() == unchanged,
		"invalid reward atomic rollback"
	)
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "abandon preserves earned feat")
	var next: SeasonState = _new_club(67, club)
	_check(
		next.build._jump_start == true and next.build.view().wallet.sponsors.is_empty(),
		"next season inherits eligibility without free copy"
	)


func _jump_migration() -> void:
	var season: SeasonState = _new_club(88)
	season.build._format = 30
	season.build._jump_start = null
	season.build._batch_start = null
	season.build._sure_start = null
	season.build._field_start = null
	season.build._copy.start = null
	season.build._abilities.start = null
	season.build._major.start = null
	season.career.runs[-1].jump_earned = null
	season.career.runs[-1].batch_used = null
	season.career.runs[-1].sure_earned = null
	season.career.runs[-1].field_outs = null
	season.career.runs[-1].copy_earned = null
	season.career.runs[-1].sky_outs = null
	season.career.runs[-1].major_earned = null
	_completed(season, ["out", "out", "single"])
	_check(SeasonSave.save(season), "prior build saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 11
	for historical: Dictionary in data.career.runs:
		historical.erase("collection")
	data.career.runs[-1].erase("jump_earned")
	data.career.runs[-1].erase("batch_used")
	data.career.runs[-1].erase("sure_earned")
	data.career.runs[-1].erase("field_outs")
	data.career.runs[-1].erase("copy_earned")
	data.career.runs[-1].erase("sky_outs")
	data.career.runs[-1].erase("major_earned")
	var restored: SeasonState = SeasonSave._decode(data)
	_check(
		restored != null and restored.build._jump_start == null and restored.build._freezer_earned,
		"migration preserves prior feats; new tracking prospective"
	)
	_check(
		restored != null and SeasonSave.save(restored) and SeasonSave.restore() != null,
		"second migrated save"
	)


func _paid_jump(buy: bool = true) -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._jump_start = false
	probe._jump_earned = true
	probe._visit.number = 3
	for seed_value in range(10000):
		probe._seed = seed_value
		if not probe._offers(0).values().has("J04"):
			continue
		var season: SeasonState = _new_club(seed_value)
		if not _jump_result(season):
			continue
		_jump_result(season, false)
		_jump_result(season, false)
		_check(season.build.commit(_command(season.build, "open")).ok, "generated earned stock")
		var offer: String = _offer(season.build, "J04")
		if offer.is_empty():
			continue
		if buy:
			_check(
				(
					season
					. build
					. commit(_command(season.build, "sponsor_buy", {"offer": offer, "replace": ""}))
					. ok
				),
				"paid Jumpstart copy"
			)
		print("JUMPSTART_FIXTURE seed=", seed_value)
		return season
	_check(false, "reachable paid Jumpstart")
	return null


func _jump_ui() -> void:
	var season: SeasonState = _paid_jump(false)
	_check(SeasonSave.save(season), "UI earned stock checkpoint")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "jumpstart-shop")
	var offer: String = _offer(season.build, "J04")
	var before: Dictionary = season.build.to_data()
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "cancel paid offer")
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(app.season.build.to_data() == before, "failed purchase keeps stock and cash")
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	_check(SeasonSchoolSponsors.active(app.season.build, "J04").paid == 12, "paid twelve")
	window.queue_free()
	await _frames()
	app.menu.show_lineup()
	await _menu_bounds(app, "jumpstart-lineup")
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "jumpstart-progress")
	app.play_season_game()
	await _frames(3)
	var lab: PitchBatLab = app.lab
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var state: MatchState = lab._match_state
	state.top_half = lab._player_home
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	lab._field_setup_active = true
	lab._refresh_config()
	await _frames(3)
	var controls: MatchJumpstartControls = lab.find_child("JumpstartControls", true, false)
	_check(
		controls.choice.is_visible_in_tree() and not controls.choice.disabled,
		"direction input visible"
	)
	await _click(controls.choice)
	_check(state.jumpstart_mode == "left", "actual mouse direction choice")
	controls.choice.grab_focus()
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = pressed
		get_viewport().push_input(key)
		await _frames()
	_check(state.jumpstart_mode == "right", "keyboard direction choice")
	for hud in range(3):
		lab._hud_anchor_index = hud
		lab._refresh_config()
		await _frames()
		_check(
			Rect2(0, 0, 1280, 720).encloses(lab._field_setup_panel.get_global_rect()),
			"field menu fits every HUD anchor"
		)
	await _capture(get_viewport(), "jumpstart-field-choice")
	# Both owned controls must fit; conflicts stay explicit, with no silent toggle.
	state.fielder().definition.season_sponsors["F01"] = true
	await _frames()
	var anchor: MatchSponsorControls = lab.find_child("SponsorControls", true, false)
	_check(anchor._anchor_choice.disabled, "Jumpstart visibly blocks anchor")
	SeasonJumpstart.choose(state, "normal")
	SeasonCornerstone.choose(state, true)
	await _frames()
	_check(
		controls.choice.disabled and controls.choice.text.contains("Turn off"),
		"explicit anchor conflict"
	)
	_check(
		Rect2(0, 0, 1280, 720).encloses(lab._field_setup_panel.get_global_rect()),
		"both controls fit"
	)
	SeasonCornerstone.choose(state, false)
	SeasonJumpstart.choose(state, "right")
	state.fielder().definition.season_sponsors.erase("F01")
	lab._field_setup_active = false
	lab._refresh_config()
	_check(lab._field_setup_toggle_button.text == "FIELD: RIGHT", "choice disclosed outside menu")
	await _click(app.loadout.entry)
	await _click(app.loadout._tab_buttons[1])
	_check(SeasonLoadoutData.pages(app).sponsors[0].label.contains("RIGHT"), "Equipped choice")
	await _click(app.loadout.close_button)
	state.begin_pitch()
	state.record_foul()
	state.continue_after_dead_ball()
	lab._field_setup_active = true
	lab._refresh_config()
	await _frames()
	_check(controls.choice.disabled and controls.choice.text.contains("Locked"), "whole-PA UI lock")
	controls._choose()
	_check(state.jumpstart_mode == "right", "stale callback preserves choice")
	app.leave_game()
	_check(
		app.season.make_match().clean_outs.rows.is_empty(), "restart discards incomplete evidence"
	)
	app.queue_free()
	await _frames()


func _jump_contacts() -> void:
	for foul: bool in [false, true]:
		var lab: PitchBatLab = PitchBatLab.new()
		lab._configured_match = _new_club(67).make_match()
		lab._configured_match.fielder().definition.season_sponsors = {"J04": true}
		lab._player_home = true
		add_child(lab)
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		lab._primary_fielder.set_physics_process(false)
		_check(SeasonJumpstart.choose(lab._match_state, "out"), "contact fixture precommit")
		var before: Vector3 = lab._primary_fielder.global_position
		lab._primary_fielder._physics_process(1)
		_check(lab._primary_fielder.global_position == before, "no movement before contact")
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(0, 1, 2)
		launch.velocity = Vector3(0, 3, 8)
		launch.is_foul = foul
		lab._start_ball_in_play(launch)
		_check(
			lab._primary_fielder.first_step == (Vector3.ZERO if foul else Vector3.BACK),
			"actual launch gates first step to fair contact"
		)
		lab.queue_free()
		await _frames(2)
