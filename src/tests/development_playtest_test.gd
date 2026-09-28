extends Node

var _failures: int = 0


func _ready() -> void:
	_profiles()
	_stats()
	_recipes()
	_command_separation()
	await _window_and_match()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro development playtest checks passed: physical ladders and live UI/match path."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _profiles() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("playtest")
	for id: String in SeasonPlayerCatalog.ids():
		var source: PlayerDefinition = ContentDB.get_player(StringName(id))
		var before: Array[int] = SeasonPlayerCard.values(source)
		var player: PlayerDefinition = ProgressionMatchAdapter.player(book, id)
		_check(
			player != source and player.progression_test, "opt-in instance, not authored resource"
		)
		_check(
			player.id == source.id and player.display_name == source.display_name, "identity kept"
		)
		_check(
			(
				player.bats == source.bats
				and player.throws == source.throws
				and player.switch_hitter == source.switch_hitter
			),
			"hands kept"
		)
		_check(player.natural_delivery == source.natural_delivery, "natural delivery kept")
		_check(SeasonPlayerCard.values(player).size() == 4, "four visible stats")
		_check(
			SeasonPlayerCard.values(source) == before and not source.progression_test,
			"legacy definition unchanged"
		)
		for pitch: PitchDefinition in player.starting_pitches:
			_check(pitch != ContentDB.get_pitch(pitch.id), "mastered recipe is a match copy")
			_check(
				pitch.delivery_profile == ContentDB.get_pitch(pitch.id).delivery_profile,
				"exact recipe delivery kept"
			)
	var player: PlayerDefinition = ProgressionMatchAdapter.player(book, "player.alex_finch")
	var pitch: PitchDefinition = player.starting_pitches[0]
	var first: PitchDefinition = MatchLabSupport.rated_pitch(pitch, player, 1.0)
	player.velocity = 0
	player.break_rating = 10
	var second: PitchDefinition = MatchLabSupport.rated_pitch(pitch, player, 1.0)
	_check(
		(
			first.nominal_velocity_mps == second.nominal_velocity_mps
			and first.nominal_spin_rpm == second.nominal_spin_rpm
		),
		"no hidden retired Velocity/Break multipliers"
	)
	var rebuilt: PitchDefinition = PitchMastery.apply(PitchMastery.apply(pitch, 5), 5)
	_check(
		rebuilt.nominal_velocity_mps == PitchMastery.apply(pitch, 5).nominal_velocity_mps,
		"materialization does not compound mastery twice"
	)


func _stats() -> void:
	for stat: String in SeasonPlayerCatalog.STATS:
		var book: SeasonDevelopment = SeasonDevelopment.new("stats")
		var id: String = "player.alex_finch" if stat == "power" else "player.rowan_chase"
		var previous: float = -INF
		for level in range(1, 11):
			var player: PlayerDefinition = ProgressionMatchAdapter.player(book, id)
			_check(book.player(id).stats[stat] == level, "journal reaches each physical level")
			var value: float = _metric(player, stat)
			_check(value > previous, "%s has a physical benefit at level %d" % [stat, level])
			previous = value
			if level < 10:
				_check(
					(
						book
						. commit(
							{
								"id": "%s:%d" % [stat, level],
								"rev": book.revision(),
								"op": "stat",
								"player": id,
								"target": stat
							}
						)
						. ok
					),
					"next real growth step"
				)
	print("PHYSICAL_STATS all four ladders improve at each level 1 through 10")


func _metric(player: PlayerDefinition, stat: String) -> float:
	if stat == "fielding":
		var fielder: FielderController = FielderController.new()
		fielder.configure_player(player)
		var speed: float = fielder.move_speed_mps
		_check(
			fielder.reaction_delay_seconds > 0.0 and fielder.reach_m > 0.0, "bounded reaction/reach"
		)
		if player.fielding < 10:
			var ball_speed: float = (
				(0.5 + (player.fielding + 0.5) * 0.095 - 0.2 * 0.88 - 0.16) / 0.028
			)
			_check(
				(
					FieldingResolver.resolve(0.2, ball_speed, 0.3, true, player.fielding)
					!= FieldingResolver.Outcome.CLEAN
				),
				"lower handling level at controlled boundary"
			)
			_check(
				(
					FieldingResolver.resolve(0.2, ball_speed, 0.3, true, player.fielding + 1)
					== FieldingResolver.Outcome.CLEAN
				),
				"next level actually controls boundary ball"
			)
		fielder.free()
		return speed
	if stat == "pitching":
		var arm: PlayerMatchState = PlayerMatchState.create(player)
		if player.control > 1:
			_check(
				(
					PitchReleaseController.quality_at(0.50, player.control, 0.0)
					> PitchReleaseController.quality_at(0.50, player.control - 1, 0.0)
				),
				"each Pitching level improves actual release tolerance"
			)
		return arm.stamina_max
	var state: PitchState = PitchState.new()
	state.position = Vector3(0.0, 1.05, 0.18)
	state.velocity = Vector3(0.0, 0.0, -18.0)
	state.elapsed_time = 0.11
	var intent: SwingIntent = SwingIntent.new()
	intent.aim_point = Vector2(0.12, 1.05)
	var result: ContactResult = ContactResolver.resolve_swept_segment(
		Vector3(0.0, 1.05, 0.38),
		0.10,
		state,
		intent,
		ContentDB.get_swing(&"swing.contact"),
		player.contact if stat == "contact" else 5,
		player.power if stat == "power" else 5
	)
	_check(result != null and result.exit_velocity.length() > 0.0, "actual swept contact")
	return result.quality if stat == "contact" else result.exit_velocity.length()


func _recipes() -> void:
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
	var count: int = 0
	for id: String in SeasonPlayerCatalog.RECIPES.values():
		var source: PitchDefinition = ContentDB.get_pitch(StringName(id))
		var original_speed: float = source.nominal_velocity_mps
		var reliable: bool = id in ["pitch.eephus", "pitch.knuckleball"]
		var right_paths: Array[Vector3] = []
		for left: bool in [false, true]:
			var previous: Vector3 = Vector3.ZERO
			var previous_plate_speed: float = 0.0
			var previous_error: float = INF
			for level in range(1, 6):
				var recipe: PitchDefinition = PitchMastery.apply(source, level)
				var parameters: PitchLaunchParameters = PitchAimSolver.solve(
					recipe, ball, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), left, 53
				)
				_check(parameters != null, "%s level %d has a legal center launch" % [id, level])
				if parameters == null:
					continue
				var plate: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
					parameters, 0
				)
				var middle: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
					parameters, 7
				)
				_check(
					plate.crossed and plate.point.distance_to(Vector3(0, 1.05, 0)) < 0.02,
					"aim solver uses the same mastered physics"
				)
				if reliable:
					var error: float = _spread(parameters, recipe)
					_check(
						error > 0.0 and error < previous_error,
						"reliability reduces real spread: " + id
					)
					previous_error = error
					_check(
						(
							recipe.nominal_velocity_mps == original_speed
							and recipe.instability_strength == source.instability_strength
						),
						"reliability retains speed and seeded natural wobble"
					)
				elif level > 1:
					_check(
						(
							middle.point.distance_to(previous) > 0.00001
							or absf(plate.velocity.length() - previous_plate_speed) > 0.0001
						),
						"each mastered movement/velocity step changes actual flight: " + id
					)
				if left:
					var mirrored: Vector3 = right_paths[level - 1]
					mirrored.x *= -1.0
					_check(
						middle.point.distance_to(mirrored) < 0.0001, "mastered flight mirrors hands"
					)
				else:
					right_paths.append(middle.point)
				previous = middle.point
				previous_plate_speed = plate.velocity.length()
				count += 1
		_check(
			(
				source.nominal_velocity_mps == original_speed
				and source.mastery_level == 1
				and source.mastery_late_bias == 0.0
			),
			"authored recipe remains unchanged"
		)
	_check(count == 90, "nine recipes, five levels, both throwing hands")
	print("MASTERY_FLIGHT solved and measured ", count, " recipe/level/hand combinations")


func _spread(parameters: PitchLaunchParameters, recipe: PitchDefinition) -> float:
	var error: float = 0.0
	for seed_value in range(12):
		var executed: PitchLaunchParameters = PitchExecutionModel.apply(
			parameters,
			0.90,
			0.0,
			recipe.control_difficulty,
			recipe.execution_difficulty,
			recipe.category,
			seed_value + 7
		)
		var plate: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(executed, 0)
		_check(plate.crossed, "reliability fixture reaches plate")
		error += plate.point.distance_squared_to(Vector3(0, 1.05, 0))
	return error / 12.0


func _command_separation() -> void:
	var recipe: PitchDefinition = PitchMastery.apply(
		ContentDB.get_pitch(&"pitch.overhand_four_seam"), 1
	)
	var parameters: PitchLaunchParameters = PitchAimSolver.solve(
		recipe,
		ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID),
		PitchBatLab.MOUND_ORIGIN,
		Vector3(0, 1.05, 0),
		false,
		21
	)
	var low: PitchLaunchParameters = PitchExecutionModel.apply(
		parameters,
		0.874,
		0.0,
		recipe.control_difficulty,
		recipe.execution_difficulty,
		recipe.category,
		21
	)
	var high: PitchLaunchParameters = PitchExecutionModel.apply(
		parameters,
		1.0,
		0.0,
		recipe.control_difficulty,
		recipe.execution_difficulty,
		recipe.category,
		21
	)
	_check(
		(
			is_equal_approx(low.velocity.length(), high.velocity.length())
			and low.angular_velocity == high.angular_velocity
		),
		"Pitching does not secretly increase recipe velocity/spin"
	)
	_check(not low.position.is_equal_approx(high.position), "command still affects execution")


func _window_and_match() -> void:
	var prefix: String = "user://development-playtest-%d" % OS.get_process_id()
	SeasonSave.path = prefix + "-season.json"
	PitchBatLabSettings.path = prefix + "-settings.cfg"
	_check(SeasonSave.save(SeasonState.create(718)), "ordinary season checkpoint")
	var before: String = FileAccess.get_file_as_string(SeasonSave.path)
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.menu._open_development_lab()
	var window: DevelopmentLab
	for child in app.menu.get_children():
		if child is DevelopmentLab:
			window = child
	_check(window != null, "home opens real growth window")
	window.save_path = prefix + "-growth.json"
	var command: Dictionary = window._request("mastery", "pitch.overhand_four_seam")
	window._preview(command, "Movement refinement")
	_check(window._confirm.visible and window.book.revision() == 0, "preview is not a grant")
	window._confirm.canceled.emit()
	window._confirm.hide()
	_check(window.book.revision() == 0 and window._pending.is_empty(), "cancel keeps baseline")
	window._preview(command, "Movement refinement")
	window._confirm.confirmed.emit()
	window._confirm.hide()
	_check(window.book.revision() == 1, "confirmed grant applied once")
	window._save()
	window._reset()
	window._restore()
	_check(window.book.revision() == 1, "UI restores journal and mastery")
	window._play()
	await get_tree().process_frame
	_check(app.lab != null and not app._season_game, "test exhibition uses actual managed match")
	var lab: PitchBatLab = app.lab
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._record_export.path = prefix + "-records.json"
	for human: bool in [true, false]:
		lab._player_home = human
		lab._pitch_actor.reset_pitch()
		lab._match_state.phase = MatchState.Phase.PRE_PITCH
		lab._match_state.between_batters = true
		lab._selected_pitch_index = 0
		lab._ai_pitch_preselected = true
		lab._pending_release_quality = 1.0
		lab._pitch_effort = 1.0
		lab._pitch_target = Vector2(0, 1.05)
		lab._refresh_config()
		var selected: PitchDefinition = lab._selected_pitch()
		_check(selected.mastery_level == 2, "restored mastered pitch reaches match roster")
		lab._throw_pitch()
		_check(lab._pitch_actor.running, "real human/AI pitch launches")
		_check(
			lab._pitch_actor.parameters.mastery_movement_scale > 1.0,
			"real actor receives mastered physics for human and AI"
		)
		_check(
			lab._pitch_actor.parameters.command_only_quality, "four-stat execution in live actor"
		)
		if human:
			_check(lab._pitch_picker._selected.text.contains("Lv2"), "visible exact pitch level")
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == before, "test leaves season bytes intact"
	)
	app._close_match()
	app.queue_free()
	await get_tree().process_frame
	for path: String in [
		SeasonSave.path, prefix + "-growth.json", prefix + "-records.json", PitchBatLabSettings.path
	]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
