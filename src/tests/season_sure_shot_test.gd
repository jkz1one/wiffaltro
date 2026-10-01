extends "res://src/tests/season_jumpstart_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://sure-shot-%d.json" % OS.get_process_id()
	_sure_contract()
	_sure_execution()
	_sure_progress()
	_sure_migration()
	await _sure_ui()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Sure Shot checks passed: commitments, execution, progression, saves and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _sure_result(season: SeasonState, qualify: bool = true, win: bool = true) -> bool:
	var game: Dictionary = season.pending_fixture()
	var own: Array = season.teams[0].roster
	var rival: Array = season.teams[game.away if game.home == 0 else game.home].roster
	var stats: MatchPerformance = MatchPerformance.new()
	stats.complete(StringName(rival[0]), StringName(own[0]), "strikeout", 0)
	for id: String in own + rival:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	var rows: Array = []
	for index in range(3 if qualify else 2):
		rows.append(
			{
				"pa": 1,
				"half": 0 if game.home == 0 else 1,
				"player": own[0],
				"recipe": String(season.build.definition(own[0]).starting_pitches[0].id)
			}
		)
	stats.players[own[0]].pitches = rows.size()
	var evidence: Dictionary = {
		"releases": rows,
		"calls": [],
		"strikeouts": [{"pa": 1, "half": 0 if game.home == 0 else 1, "player": own[0]}]
	}
	var home_wins: bool = (game.home == 0) == win
	return season.record_player_result(
		game.id,
		0 if home_wins else 1,
		1 if home_wins else 0,
		stats.players,
		[],
		[],
		{},
		[],
		[],
		evidence
	)


func _sure_contract() -> void:
	var state: MatchState = _new_club(67).make_match()
	state.pitcher().definition.season_sponsors["F08"] = true
	var recipe: StringName = state.pitcher().definition.starting_pitches[0].id
	_check(not state.sure_shot.choose(state, &"pitch.foreign"), "unknown recipe costs no use")
	state.elapsed_seconds = 3.25
	_check(state.sure_shot.choose(state, recipe), "announce exact known recipe before PA")
	var cue: Dictionary = state.pitch_disclosure.duplicate(true)
	_check(cue == {"source": "F08", "recipe": String(recipe), "time": 3.25}, "public identity only")
	_check(not state.defensive_team().select_pitcher(2), "no pitcher switch after announcement")
	_check(not state.sure_shot.choose(state, recipe), "duplicate confirmation costs no extra use")
	state.begin_pitch()
	_check(state.pitch_disclosure == cue, "windup keeps public cue")
	state.cancel_pitch()
	_check(state.sure_shot.remaining(state.defensive_team()) == 1, "cancellation cannot refund use")
	_check(not state.sure_shot.allows(state, &"other"), "other recipes locked after cancel")
	for index in range(3):
		state.begin_pitch()
		state.pitcher().spend_stamina(1.0)
		state.note_pitch_released(recipe, 1.0)
		state.note_pitch_released(recipe, 1.0)
		_check(MatchPitchDisclosure.release(state, recipe, index + 1) == cue, "same AI/replay cue")
		state.record_strike()
		state.continue_after_dead_ball()
	_check(state.sure_shot.releases.size() == 3, "only actual unique releases count")
	_check(state.sure_shot.current(state).is_empty(), "PA end clears active commitment")
	_check(
		SeasonSureShot.qualifies(state.sure_shot.evidence(state.defensive_team())),
		"actual K qualifies"
	)
	_check(state.defensive_team().select_pitcher(2), "normal next-batter pitcher change")
	state.pitcher().definition.season_sponsors["F08"] = true
	recipe = state.pitcher().definition.starting_pitches[0].id
	_check(state.sure_shot.choose(state, recipe), "second use shared across pitchers")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	state.continue_after_dead_ball()
	_check(not state.sure_shot.choose(state, recipe), "third use refused")
	var detached: Dictionary = state.sure_shot.evidence(state.defensive_team())
	detached.calls.clear()
	_check(state.sure_shot.calls.size() == 2, "evidence detached from live state")


func _sure_execution() -> void:
	# Isolate yaw from plate-reach correction and aerodynamic compensation.
	var straight: PitchLaunchParameters = PitchLaunchParameters.new()
	straight.position = Vector3(0, 10, 12)
	straight.velocity = Vector3(0, 0, -22)
	straight.drag_coefficient = 0
	straight.magnus_scale = 0
	straight.perforation_force_scale = 0
	straight.command_only_quality = true
	for gear: float in [1.0, SeasonGearCatalog.item("MISC-PIT-03").command]:
		straight.gear_command_scale = gear
		for seed_value in range(30):
			var announced: PitchLaunchParameters = straight.copy()
			announced.execution_direction_scale = 0.8
			var ordinary: PitchLaunchParameters = PitchExecutionModel.apply(
				straight, 0.4, 0.0, 1.0, 1.0, PitchDefinition.Category.BREAKING, seed_value
			)
			var reduced: PitchLaunchParameters = PitchExecutionModel.apply(
				announced, 0.4, 0.0, 1.0, 1.0, PitchDefinition.Category.BREAKING, seed_value
			)
			var normal_yaw: float = atan2(ordinary.velocity.x, -ordinary.velocity.z)
			var sure_yaw: float = atan2(reduced.velocity.x, -reduced.velocity.z)
			_check(
				absf(sure_yaw - normal_yaw * 0.8) < 0.000001,
				"fresh execution yaw is exactly 20% smaller before/with Rosin"
			)
	var base: PitchLaunchParameters = PitchLaunchParameters.new()
	base.position = Vector3(0.0, 1.8, 12.0)
	base.velocity = Vector3(0.3, -0.5, -22.0)
	base.angular_velocity = Vector3(0, 12, 2)
	base.command_only_quality = true
	for gear: float in [1.0, SeasonGearCatalog.item("MISC-PIT-03").command]:
		base.gear_command_scale = gear
		for quality: float in [0.0, 0.4, 1.0]:
			for fatigue: float in [0.0, 0.7, 1.0]:
				for seed_value in range(30):
					var sure: PitchLaunchParameters = base.copy()
					sure.execution_direction_scale = 0.8
					var a: PitchLaunchParameters = PitchExecutionModel.apply(
						base,
						quality,
						fatigue,
						1.0,
						1.0,
						PitchDefinition.Category.BREAKING,
						seed_value
					)
					var b: PitchLaunchParameters = PitchExecutionModel.apply(
						sure,
						quality,
						fatigue,
						1.0,
						1.0,
						PitchDefinition.Category.BREAKING,
						seed_value
					)
					_check(
						a.position == b.position and a.orientation == b.orientation,
						"release and orientation errors unchanged, same RNG draws"
					)
					_check(
						(
							is_equal_approx(a.velocity.length(), b.velocity.length())
							and a.angular_velocity == b.angular_velocity
							and a.perforation_force_scale == b.perforation_force_scale
						),
						"velocity and movement unchanged with fatigue/lapses/Rosin"
					)
					if quality == 1.0:
						_check(
							a.velocity == b.velocity,
							"zero execution component: no invented benefit"
						)


func _sure_progress() -> void:
	var season: SeasonState = _new_club(88)
	_check(_sure_result(season, false), "two actual pitches K settles")
	_check(not season.build._sure_earned, "count-start strikes do not fabricate third pitch")
	_check(_sure_result(season, true, false), "qualifying loss settles")
	_check(season.build._sure_earned, "completed loss earns paid access")
	_check(SeasonSave.save(season), "save qualified evidence")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and ClubCareer.same(restored.build.to_data(), season.build.to_data()),
		"canonical serialized replay"
	)
	var evidence: Dictionary = season.player_results[-1].pitching.duplicate(true)
	var stats: Dictionary = season.player_results[-1].performance
	var player: String = evidence.releases[0].player
	var original: String = evidence.releases[0].recipe
	var recipes: Array[PitchDefinition] = season.build.definition(player).starting_pitches
	if recipes.size() > 1:
		evidence.releases[1].recipe = String(recipes[1].id)
		_check(not SeasonSureShot.qualifies(evidence), "mixed exact recipes do not qualify")
		evidence.releases[1].recipe = original
	for patch: Dictionary in [
		{"pa": 0}, {"half": -1}, {"player": "foreign"}, {"recipe": "unknown"}, {"extra": true}
	]:
		var bad: Dictionary = evidence.duplicate(true)
		bad.releases[0].merge(patch, true)
		_check(not SeasonSureShot.valid(season.build, bad, stats), "invalid release proof rejected")
	var bad_count: Dictionary = evidence.duplicate(true)
	bad_count.releases.pop_back()
	_check(
		not SeasonSureShot.valid(season.build, bad_count, stats),
		"box-score count mismatch rejected"
	)
	var announced: Dictionary = evidence.duplicate(true)
	announced.calls = [evidence.releases[0].duplicate(true)]
	announced.calls[0]["time"] = 2.5
	_check(SeasonSureShot.valid(season.build, announced, stats), "valid announcement proof")
	for patch: Dictionary in [{"time": -1}, {"time": "2"}, {"recipe": "unknown"}, {"pa": 2}]:
		var bad: Dictionary = announced.duplicate(true)
		bad.calls[0].merge(patch, true)
		_check(not SeasonSureShot.valid(season.build, bad, stats), "reject invalid announcement")
	var unpaid: Dictionary = _command(
		season.build,
		"reward",
		{"game": 31, "win": true, "performance": stats, "pitching": announced}
	)
	_check(not season.build.commit(unpaid).ok, "unowned announcement proof cannot settle")
	announced.calls.append(announced.calls[0].duplicate(true))
	_check(
		not SeasonSureShot.valid(season.build, announced, stats), "reject repeated PA announcement"
	)
	var unchanged: Dictionary = season.build.to_data()
	var invalid: Dictionary = _command(
		season.build,
		"reward",
		{"game": 31, "win": true, "performance": stats, "pitching": bad_count}
	)
	_check(
		not season.build.commit(invalid).ok and season.build.to_data() == unchanged,
		"invalid pitching proof rolls back cash, progress and journal"
	)
	var tampered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	tampered.results[-1].pitching.releases[0].recipe = "unknown"
	_check(SeasonSave._decode(tampered) == null, "result and journal must agree")
	for field: String in ["career", "start"]:
		var bad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
		if field == "career":
			bad.career.runs[-1].sure_earned = false
		else:
			bad.build.sure_start = true
		_check(SeasonSave._decode(bad) == null, "reject invented inherited or current progress")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "close preserves earned eligibility")
	var next: SeasonState = _new_club(90, club)
	_check(
		next.build._sure_start == true and next.build.view().wallet.sponsors.is_empty(),
		"career inheritance unlocks future rolls without free ownership"
	)


func _sure_migration() -> void:
	var season: SeasonState = _new_club(88)
	season.build._format = 32
	season.build._sure_start = null
	season.build._field_start = null
	season.career.runs[-1].sure_earned = null
	season.career.runs[-1].field_outs = null
	_completed(season, ["out", "out", "single"])
	_check(SeasonSave.save(season), "Build32 saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 13
	data.career.runs[-1].erase("sure_earned")
	data.career.runs[-1].erase("field_outs")
	var restored: SeasonState = SeasonSave._decode(data)
	_check(restored != null and restored.build._sure_start == null, "old run remains prospective")
	_check(restored != null and SeasonSave.save(restored), "migrated save remains valid")


func _paid_sure(buy: bool = true) -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._sure_start = false
	probe._sure_earned = true
	probe._visit.number = 3
	for seed_value in range(10000):
		probe._seed = seed_value
		if not probe._offers(0).values().has("F08"):
			continue
		var season: SeasonState = _new_club(seed_value)
		if not _sure_result(season):
			continue
		_sure_result(season, false)
		_sure_result(season, false)
		_check(season.build.commit(_command(season.build, "open")).ok, "generated earned stock")
		var offer: String = _offer(season.build, "F08")
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
				"paid Sure Shot copy"
			)
		print("SURE_SHOT_FIXTURE seed=", seed_value)
		return season
	_check(false, "reachable paid Sure Shot")
	return null


func _sure_ui() -> void:
	var season: SeasonState = _paid_sure(false)
	_check(SeasonSave.save(season), "UI stock checkpoint")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "sure-shot-shop")
	var offer: String = _offer(season.build, "F08")
	var before: Dictionary = season.build.to_data()
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "canceled purchase")
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(app.season.build.to_data() == before, "failed purchase rolls back")
	await _click(_sponsor_button(window, offer))
	await _click(window._confirm.get_ok_button())
	_check(SeasonSchoolSponsors.active(app.season.build, "F08").paid == 12, "paid twelve")
	window.queue_free()
	await _frames()
	app.menu.show_lineup()
	await _menu_bounds(app, "sure-shot-lineup")
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "sure-shot-progress")
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
	var controls: MatchSureShotControls = lab.find_child("SureShotControls", true, false)
	_check(
		controls.choice.is_visible_in_tree() and not controls.choice.disabled,
		"announcement control"
	)
	await _click(controls.choice)
	_check(state.sure_shot.calls.size() == 1 and controls.choice.disabled, "one mouse commitment")
	_check(controls.announcement.is_visible_in_tree(), "identity announcement before first pitch")
	state.fielder().definition.season_sponsors["J04"] = true
	state.fielder().definition.season_sponsors["F01"] = true
	for hud in range(3):
		lab._hud_anchor_index = hud
		lab._refresh_config()
		await _frames()
		_check(
			Rect2(0, 0, 1280, 720).encloses(lab._field_setup_panel.get_global_rect()),
			"field menu fits every HUD anchor"
		)
	await _capture(get_viewport(), "sure-shot-announcement")
	var loadout: Dictionary = SeasonLoadoutData.pages(app)
	var shown: bool = false
	for row: Dictionary in loadout.sponsors:
		shown = shown or (row.name == "Sure Shot Signworks" and row.label.contains("1 / 2"))
	_check(shown, "Equipped shows remaining announcements")
	lab._field_setup_active = false
	lab._refresh_config()
	var options: Array[PitchDefinition] = lab._current_pitch_options()
	if options.size() > 1:
		var selected: int = lab._selected_pitch_index
		PitchBatLabInput._handle_match_key(lab, KEY_2 if selected != 1 else KEY_1)
		_check(lab._selected_pitch_index == selected, "number keys cannot bypass commitment")
		lab._selected_pitch_index = 1 if selected != 1 else 0
		var paid: int = state.pitcher().pitch_count
		var stamina: float = state.pitcher().stamina_remaining
		lab._throw_pitch()
		_check(
			state.pitcher().pitch_count == paid and state.pitcher().stamina_remaining == stamina,
			"direct illegal recipe input consumes no pitch or stamina"
		)
		_check(
			state.sure_shot.remaining(state.defensive_team()) == 1,
			"illegal input cannot refund or consume announcements"
		)
		lab._selected_pitch_index = selected
		MatchLabSupport.apply_ai_pitch_choice(lab)
		_check(lab._selected_pitch_index == selected, "shared AI choice respects committed recipe")
	app.queue_free()
	await _frames(3)
