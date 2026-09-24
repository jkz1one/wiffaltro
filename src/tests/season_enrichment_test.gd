extends Node

var _failures: int = 0


func _ready() -> void:
	SeasonSave.path = "user://enrichment-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://enrichment-display-%d.cfg" % OS.get_process_id()
	_test_pool()
	_test_strategy()
	_test_reads()
	_test_migration()
	await _test_controls()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro season enrichment checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_pool() -> void:
	var total: int = 0
	var left: int = 0
	var matching: int = 0
	var switches: int = 0
	var arsenals: Dictionary = {}
	for player: PlayerDefinition in ContentDB.player_by_id.values():
		if player.id == PitchBatLab.DEBUG_PLAYER_ID:
			continue
		total += 1
		left += int(player.throws == PlayerDefinition.Handedness.LEFT)
		matching += int(player.bats == player.throws)
		switches += int(player.switch_hitter)
		arsenals[player.starting_pitches.size()] = true
		_check(
			player.signature_pitch_index < player.starting_pitches.size(), "signature must exist"
		)
		if player.pitching_style == 2:
			_check(
				player.starting_pitches[player.signature_pitch_index].category == 1,
				"Breaking specialists must own and favor a breaking Pitch"
			)
	_check(total == 48 and switches == 2, "48 authored players with two switch hitters")
	_check(left == 10 and matching >= 44, "lefties uncommon and hands usually match")
	_check(
		arsenals.has(2) and arsenals.has(3) and arsenals.has(4) and arsenals.has(5),
		"arsenal variety"
	)
	var no_special: int = 0
	var has_special: int = 0
	var seen: Dictionary = {}
	for seed_value in range(300):
		var season: SeasonState = SeasonState.create(seed_value)
		var specials: int = 0
		for index in range(12):
			var id: String = season.draft_pool[index]
			seen[id] = true
			specials += int(ContentDB.get_player(StringName(id)).starting_pitches.size() >= 4)
		_check(specials <= 1, "at most one rare arsenal in the twelve offers")
		no_special += int(specials == 0)
		has_special += int(specials == 1)
	_check(
		no_special > 0 and has_special > 0 and seen.size() == 48,
		"all cards can appear, rarity not guaranteed"
	)
	print(
		"POOL total=",
		total,
		" left_throwers=",
		left,
		" matching=",
		matching,
		" switch_hitters=",
		switches,
		" drafts_with_special=",
		has_special,
		"/300"
	)


func _test_strategy() -> void:
	var pitcher: PlayerDefinition = ContentDB.get_player(&"player.ash_cole").duplicate()
	pitcher.pitching_style = 2
	pitcher.signature_pitch_index = 1
	var options: Array[PitchDefinition] = pitcher.starting_pitches
	var attack: int = 0
	var expand: int = 0
	var signature: int = 0
	var easy_edges: int = 0
	var hard_edges: int = 0
	for seed_value in range(1200):
		var a: Dictionary = PitchingStrategy.choose(
			options, pitcher, 3, 1, 0, seed_value, 0.8, false
		)
		var b: Dictionary = PitchingStrategy.choose(
			options, pitcher, 0, 2, 1, seed_value, 0.8, false
		)
		_check(
			a == PitchingStrategy.choose(options, pitcher, 3, 1, 0, seed_value, 0.8, false),
			"AI replay"
		)
		attack += int(a["intent"] == "ATTACK")
		expand += int(b["intent"] == "ATTACK")
		signature += int(b["pitch_index"] == 1)
		var easy: Dictionary = PitchingStrategy.choose(
			options, pitcher, 0, 0, 0, seed_value, 0.0, false
		)
		var hard: Dictionary = PitchingStrategy.choose(
			options, pitcher, 0, 0, 0, seed_value, 1.0, false
		)
		easy_edges += int(absf(easy["target"].x) >= 0.24)
		hard_edges += int(absf(hard["target"].x) >= 0.24)
	_check(attack > expand + 250, "three balls should attack more than two-strike counts")
	_check(
		signature > 650, "breaking specialist may repeat their signature instead of forced rotation"
	)
	_check(hard_edges > easy_edges + 200, "tactical difficulty should change target selection")
	print(
		"STRATEGY attack_3balls=",
		attack,
		" attack_2strikes=",
		expand,
		" signature=",
		signature,
		" edges_relaxed/tactical=",
		easy_edges,
		"/",
		hard_edges
	)


func _test_reads() -> void:
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var batter: PlayerDefinition = ContentDB.get_player(&"player.debug_pitcher")
	var model: BatterApproachModel = BatterApproachModel.new()
	for pitch_id in [
		&"pitch.overhand_four_seam", &"pitch.overhand_slider", &"pitch.sidearm_slider"
	]:
		var pitch: PitchDefinition = ContentDB.get_pitch(pitch_id)
		var old_error: float = 0.0
		var new_error: float = 0.0
		var old_offers: int = 0
		var new_offers: int = 0
		for left in [false, true]:
			var launch: PitchLaunchParameters = PitchAimSolver.solve(
				pitch, ball, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), left, 41
			)
			_check(launch != null, "center fixture must solve")
			if launch == null:
				continue
			for sample in range(40):
				var parameters: PitchLaunchParameters = PitchExecutionModel.apply(
					launch,
					0.9,
					0.0,
					pitch.control_difficulty,
					pitch.execution_difficulty,
					pitch.category,
					4100 + sample
				)
				var state: PitchState = PitchState.new()
				state.position = parameters.position
				state.velocity = parameters.velocity
				state.orientation = parameters.orientation
				state.angular_velocity = parameters.angular_velocity
				state.seed = parameters.seed
				var read: Vector2
				model.reset(1)
				while state.elapsed_time < 3.0:
					PitchFlightSolver.step(state, parameters)
					var decision: Dictionary = model.track_pitch(
						pitch,
						state,
						batter,
						0,
						2,
						sample,
						batter.bats,
						ContentDB.get_swing(PitchBatLab.CONTACT_SWING_ID),
						ContentDB.get_swing(PitchBatLab.POWER_SWING_ID)
					)
					if not decision.is_empty():
						read = decision.plate_read
						break

				var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
					parameters, ContactResolver.CONTACT_PLANE_Z
				)
				_check(crossing.crossed, "read fixture must reach contact plane")
				var actual: Vector2 = Vector2(crossing.point.x, crossing.point.y)
				var current: Vector2 = Vector2(state.position.x, state.position.y)
				old_error += current.distance_to(actual)
				new_error += read.distance_to(actual)
				old_offers += int(
					model.decide(pitch, current, current, batter, 0, 2, 24, sample)["swing"]
				)
				new_offers += int(
					model.decide(pitch, read, read, batter, 0, 2, 24, sample)["swing"]
				)
		_check(
			new_error / 80.0 < 0.12, "sampled visible-motion read must stay within 12 cm mean error"
		)
		# The old comparison pooled inverted left-handed fastballs with right-hand
		# fastballs. Correct vertical spin removes that artificial improvement.
		if pitch.category == PitchDefinition.Category.BREAKING:
			_check(
				new_error < old_error * 0.6,
				"visible-motion read must improve the sampled breaking-pitch estimate"
			)
		_check(new_offers > 55, "center pitches should draw offers with two strikes")
		print(
			"READ ",
			pitch_id,
			" old/new_error=",
			old_error / 80,
			"/",
			new_error / 80,
			" old/new_offers=",
			old_offers,
			"/",
			new_offers,
			" of 80"
		)


func _test_migration() -> void:
	var legacy: SeasonState = SeasonState.create(713, true)
	for pick in range(4):
		legacy.choose_player(legacy.offers()[0])
	legacy.record_player_result(legacy.pending_fixture()["id"], 2, 4)
	var data: Dictionary = {
		"version": 1,
		"seed": 713,
		"picks": legacy.picks,
		"results": legacy.player_results,
		"lineup": legacy.teams[0]["roster"],
		"starter": 0,
		"fielder": 1
	}
	var migrated: SeasonState = SeasonSave._decode(data)
	_check(
		migrated != null and migrated.results == legacy.results,
		"v1 migration preserves fixture and AI scores"
	)
	if migrated == null:
		return
	_check(SeasonSave.save(migrated), "migrated save can checkpoint to current schema")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.draft_pool == legacy.draft_pool,
		"expanded catalog must not redraw saved offers"
	)
	data = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data["pool"][0] = data["pool"][1]
	_check(SeasonSave._decode(data) == null, "duplicate IDs rejected")
	DirAccess.remove_absolute(SeasonSave.path)


func _test_controls() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var controls: MatchRosterControls = lab.find_child("RosterControls", true, false)
	var batter: PlayerMatchState = lab._match_state.batter()
	batter.definition = batter.definition.duplicate()
	batter.definition.switch_hitter = true
	lab._awaiting_batter_confirm = true
	_check(MatchRosterControls.can_switch(lab), "switch hitter chooses before readiness")
	var original: bool = batter.bats_left()
	controls._switch_side()
	_check(
		batter.bats_left() != original and lab._bat_actor.bats_left == batter.bats_left(),
		"side reaches presentation"
	)
	_check(lab._batter_avatar.bats_left == batter.bats_left(), "avatar mirrors effective hand")
	lab._ai_pitch_preselected = true
	controls._switch_side()
	_check(batter.bats_left() != original, "side locks once the delivery plan is committed")
	lab._ai_pitch_preselected = false
	lab._match_state.top_half = false
	lab._awaiting_batter_confirm = false
	lab._apply_defensive_assignment()
	lab._field_setup_active = true
	controls._process(0.0)
	controls._select_fielder(2)
	_check(
		lab._primary_fielder.get_meta(&"player_id") == lab._match_state.fielder().definition.id,
		"visible Primary Fielder must use the selected roster identity"
	)
	_check(
		lab._primary_fielder.fielding_rating == lab._match_state.fielder().definition.fielding,
		"fielder movement and outcome rating must use selected player"
	)
	controls._select_fielder(lab._match_state.defensive_team().pitcher_index)
	_check(
		lab._match_state.defensive_team().fielder_index == 2,
		"pitcher cannot also be Primary Fielder"
	)
	lab.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
