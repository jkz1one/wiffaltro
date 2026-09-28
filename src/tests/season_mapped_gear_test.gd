extends "res://src/tests/season_misc_test.gd"
## Proposed mappings exercise real effects; passing tests do not approve balance.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_bands()
	_shoes()
	_alley()
	_mapped_migration()
	await _misc_ui(SeasonGearCatalog.PROPOSAL_ITEMS)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mapped Gear checks passed: effects, boundaries, migration and paid UI.")
	get_tree().quit(0 if _failures == 0 else 1)


func _bands() -> void:
	var player: PlayerMatchState = _fixture().pitcher()
	var source: PitchDefinition = player.definition.starting_pitches[0]
	var neutral: PitchDefinition = SeasonGearCatalog.pitch(source, player.definition)
	_equip(player, "A04")
	for pair: Array in [
		[0.82, 0.85],
		[0.94, 0.85],
		[0.955, 0.925],
		[0.97, 1.0],
		[0.985, 1.075],
		[1.0, 1.15],
		[1.12, 1.15]
	]:
		_check(
			is_equal_approx(SeasonGearCatalog.workload(player, pair[0]), pair[1]),
			"Bands applies normalized control position, including both sides of the ramp"
		)
	for edge: float in [0.94, 1.0]:
		_check(
			(
				absf(
					(
						SeasonGearCatalog.workload(player, edge - 0.00001)
						- SeasonGearCatalog.workload(player, edge + 0.00001)
					)
				)
				< 0.001
			),
			"no workload cliff at ramp endpoints"
		)
	var modified: PitchDefinition = SeasonGearCatalog.pitch(source, player.definition)
	_check(
		(
			modified.nominal_velocity_mps == neutral.nominal_velocity_mps
			and modified.mastery_movement_scale == neutral.mastery_movement_scale
			and modified.gear_command_scale == neutral.gear_command_scale
		),
		"Bands never rescales pitch velocity, movement or command"
	)
	player.first_batter_completed = true
	_check(
		is_equal_approx(SeasonGearCatalog.workload(player, 0.82), 0.85),
		"Bands has no first-batter dependency"
	)
	_equip(player, "")
	_check(SeasonGearCatalog.workload(player, 0.82) == 1.0, "sale restores neutral workload")


func _shoes() -> void:
	for grounded: bool in [false, true]:
		# Choose existing difficulty at the CLEAN/BOBBLE threshold independently of Gear.
		var speed: float = 0.8 / (0.028 if grounded else 0.030)
		_check(
			FieldingResolver.resolve(0, speed, 0.5, grounded, 5) == FieldingResolver.Outcome.CLEAN,
			"neutral control remains clean"
		)
		_check(
			(
				FieldingResolver.resolve(0, speed, 0.5, grounded, 5, 0, 1.12)
				== FieldingResolver.Outcome.BOBBLE
			),
			"Track penalty affects an actual deterministic result"
		)
		speed = 0.9 / (0.028 if grounded else 0.030)
		_check(
			FieldingResolver.resolve(0, speed, 0.5, grounded, 5) == FieldingResolver.Outcome.BOBBLE,
			"neutral borderline control bobbles"
		)
		_check(
			(
				FieldingResolver.resolve(0, speed, 0.5, grounded, 5, 0, 0.85)
				== FieldingResolver.Outcome.CLEAN
			),
			"Turf benefit changes actual control"
		)
		for scale: float in [0.85, 1.0, 1.12]:
			_check(
				(
					FieldingResolver.resolve(0.8, 0, 0.5, grounded, 5, 10, scale)
					== FieldingResolver.Outcome.MISS
				),
				"Shoes cannot rescue physical reach"
			)
			_check(
				(
					FieldingResolver.resolve(0, 0, 3.0, grounded, 5, 10, scale)
					== FieldingResolver.Outcome.MISS
				),
				"Shoes cannot rescue height"
			)
			_check(
				(
					FieldingResolver.resolve(0, 0, 0.5, grounded, 5, 10, scale)
					== FieldingResolver.Outcome.CLEAN
				),
				"negative difficulty stays favorable"
			)
	var base: PlayerDefinition = _fixture().fielder().definition
	var controller: FielderController = FielderController.new()
	controller.configure_player(base)
	var speed: float = controller.move_speed_mps
	var reach: float = controller.reach_m
	var delay: float = controller.reaction_delay_seconds
	for id: String in ["MISC-FLD-01", "MISC-FLD-02"]:
		controller.configure_player(SeasonGearCatalog.equip(base, {"misc": {"item": id}}))
		_check(
			is_equal_approx(controller.move_speed_mps, speed * SeasonGearCatalog.item(id).speed),
			"primary pursuit receives exactly one speed scale"
		)
		_check(
			controller.reach_m == reach and controller.reaction_delay_seconds == delay,
			"Shoes retain physical reach and reaction delay"
		)
	controller.configure_player(base)
	_check(
		controller.move_speed_mps == speed and controller.handling_scale == 1.0,
		"new assignment removes stale Shoe effects"
	)
	controller.free()


func _alley() -> void:
	var player: PlayerDefinition = SeasonGearCatalog.equip(
		_fixture().batter().definition, {"bat": {"item": "A02"}}
	)
	for angle: float in [-22, 4, 17.9, 40.1, 55]:
		_check(
			ContactResolver.line_drive_angle(angle, 1, 0.25) == angle,
			"Alley cannot rescue grounders or high popups"
		)
	for angle: float in [18, 19, 20, 30, 38, 39, 40]:
		_check(
			ContactResolver.line_drive_angle(angle, 0.649, 0.25) == angle,
			"weak contact never qualifies"
		)
		_check(ContactResolver.line_drive_angle(angle, 1, 0) == angle, "neutral profile is exact")
	_check(
		ContactResolver.line_drive_angle(30, 0.8, 0.25) == 26.5,
		"tier-one interior moves 25 percent toward 16 degrees"
	)
	for angle: float in [18, 20, 38, 40]:
		_check(
			(
				absf(
					(
						ContactResolver.line_drive_angle(angle - 0.00001, 0.8, 0.25)
						- ContactResolver.line_drive_angle(angle + 0.00001, 0.8, 0.25)
					)
				)
				< 0.001
			),
			"continuous angular qualification shoulders"
		)
	_check(
		(
			absf(
				(
					ContactResolver.line_drive_angle(30, 0.65 - 0.00001, 0.25)
					- ContactResolver.line_drive_angle(30, 0.65 + 0.00001, 0.25)
				)
			)
			< 0.001
		),
		"continuous quality entry"
	)
	for swing_id: StringName in [&"swing.contact", &"swing.power"]:
		var source: SwingProfileDefinition = ContentDB.get_swing(swing_id)
		var modified: SwingProfileDefinition = SeasonGearCatalog.swing(source, player)
		for left: bool in [false, true]:
			for error: float in [0.0, 0.347, 0.95]:
				var a: ContactResult = _alley_contact(source, left, error)
				var b: ContactResult = _alley_contact(modified, left, error)
				_check(
					(
						a.quality == b.quality
						and a.spray_degrees == b.spray_degrees
						and a.backspin_rad_s == b.backspin_rad_s
						and a.outcome == b.outcome
					),
					"Alley preserves actual quality, spray, spin and classification"
				)
				var scale: float = (
					0.92
					if swing_id == &"swing.power" and (a.outcome != ContactResult.Outcome.FOUL)
					else 1.0
				)
				_check(
					is_equal_approx(b.exit_velocity.length(), a.exit_velocity.length() * scale),
					"Contact preserves speed; fair Power pays eight percent"
				)
				if swing_id == &"swing.contact" and error == 0.347:
					_check(
						b.launch_angle_degrees < a.launch_angle_degrees,
						"authored Contact profile has real qualifying contact"
					)
				elif swing_id == &"swing.power" or error != 0.347:
					_check(
						a.launch_angle_degrees == b.launch_angle_degrees,
						"nonqualifying or Power contact keeps launch angle"
					)
		_check(source.gear_line_drive_strength == 0, "authored resource remains neutral")


func _alley_contact(profile: SwingProfileDefinition, left: bool, error: float) -> ContactResult:
	var pitch: PitchState = PitchState.new()
	pitch.velocity = Vector3(0, 0, -24)
	var intent: SwingIntent = SwingIntent.new()
	intent.handedness_left = left
	var center: Vector3 = Vector3(0, 1.05, ContactResolver.CONTACT_PLANE_Z)
	return ContactResolver._resolve_at_contact(
		pitch,
		center + Vector3(0, profile.contact_radius_y_m * error, 0),
		center,
		intent,
		profile,
		5,
		5
	)


func _mapped_migration() -> void:
	var path: String = "user://mapped-migration-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	var season: SeasonState = SeasonState.create(_seed_for("MISC-BAT-01", 4), false, true)
	for _pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 4
	_record(season)
	season.build.commit(_command(season.build, "open"))
	_check(
		(
			season
			. build
			. commit(
				_command(
					season.build,
					"equip",
					{"offer": _offer(season.build, "MISC-BAT-01"), "replace": ""}
				)
			)
			. ok
		),
		"old schema8 owns genuinely paid Gloves"
	)
	var before: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save genuine build4")
	var bytes: String = FileAccess.get_file_as_string(path)
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == before, "keep paid Gear, stock and wallet")
	_check(FileAccess.get_file_as_string(path) == bytes, "load does not rewrite old save")
	if restored != null:
		_check(restored.build.to_data().mapped_gear_from == 2, "new pool starts next visit")
		var old: SeasonBuild = season.build
		var fresh: SeasonBuild = restored.build
		_check(
			old.commit(_command(old, "reroll")).ok and fresh.commit(_command(fresh, "reroll")).ok,
			"reroll same migrated visit"
		)
		_check(
			old.view().shop.offers == fresh.view().shop.offers,
			"migration preserves old reroll generation, not merely current snapshot"
		)
		_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "schema9 replay stable")
		_record(restored)
		restored.build.commit(_command(restored.build, "open"))
		_check(
			SeasonSave.save(restored) and SeasonSave.restore() != null,
			"next visit new catalogue is replayable"
		)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _live_misc(lab: PitchBatLab, id: String) -> void:
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var slot: String = SeasonGearCatalog.item(id).slot
	var own: TeamMatchState = (
		lab._match_state.home_team if lab._player_home else lab._match_state.away_team
	)
	for player: PlayerMatchState in own.roster:
		_check(player.definition.season_gear.get(slot) == id, "paid Gear reaches whole owning team")
	var opposing: TeamMatchState = (
		lab._match_state.away_team if lab._player_home else lab._match_state.home_team
	)
	for player: PlayerMatchState in opposing.roster:
		_check(player.definition.season_gear.is_empty(), "purchase does not equip opponents")
	for human: bool in [true, false]:
		lab._player_home = human
		for effort: float in [0.82, 0.97, 1.12]:
			lab._match_state.phase = MatchState.Phase.PRE_PITCH
			lab._match_state.between_batters = true
			lab._pitch_actor.reset_pitch()
			lab._selected_pitch_index = 0
			lab._ai_pitch_preselected = true
			lab._pitch_effort = effort
			lab._pending_release_quality = 1.0
			lab._pitch_target = Vector2(0, 1.05)
			for player: PlayerMatchState in [
				lab._match_state.pitcher(), lab._match_state.batter(), lab._match_state.fielder()
			]:
				player.definition = SeasonGearCatalog.equip(player.definition, {slot: {"item": id}})
			lab._refresh_config()
			lab._apply_defensive_assignment()
			var pitcher: PlayerMatchState = lab._match_state.pitcher()
			var stamina: float = pitcher.stamina_remaining
			var cost: float = MatchLabSupport.stamina_cost(lab._selected_pitch(), effort)
			cost *= SeasonGearCatalog.workload(pitcher, effort)
			lab._throw_pitch()
			_check(lab._pitch_actor.running, "real human/AI proposed Gear pitch launches")
			_check(
				is_equal_approx(stamina - pitcher.stamina_remaining, cost),
				"actual launch uses effort workload exactly once"
			)
			if id == "A02":
				for swing: StringName in [&"swing.contact", &"swing.power"]:
					lab._resolve_swing(swing, Vector2(0, 1.05))
					var profile: SwingProfileDefinition = lab._swing_tracker.profile
					_check(
						(
							profile.gear_line_drive_strength
							== (0.25 if swing == &"swing.contact" else 0.0)
						),
						"actual swing receives Alley"
					)
					lab._swing_tracker.reset()
					lab._swing_consumed = false
			elif id.begins_with("MISC-FLD"):
				_check(
					lab._primary_fielder.handling_scale == SeasonGearCatalog.item(id).handling,
					"human/AI active controller receives handling tradeoff"
				)
				_check(
					(
						PitchBatLabDefenseSupport.gear_factor(lab, "speed")
						== SeasonGearCatalog.item(id).speed
					),
					"pitcher pursuit receives same shoes"
				)
				_check(
					(
						PitchBatLabDefenseSupport.gear_factor(lab, "handling")
						== SeasonGearCatalog.item(id).handling
					),
					"pitcher handling receives same shoes"
				)
			await _frames(1)
		if id.begins_with("MISC-FLD"):
			_live_shoe_control(lab, id)


func _live_shoe_control(lab: PitchBatLab, id: String) -> void:
	# Probe actual lab entry points with an isolated ball-play resolver, avoiding a fake game result.
	lab._ball_play_resolver = BallPlayResolver.new()
	lab._batted_ball = BattedBallBody.new()
	lab.add_child(lab._batted_ball)
	lab._batted_ball.freeze = true
	for pitcher: bool in [false, true]:
		lab._ball_play_resolver.start_play(lab._field_definition)
		lab._pitcher_attempted = false
		lab._primary_attempts = 0
		lab._fielding_cooldown_seconds = 0
		lab._primary_fielder.last_reaction_margin_seconds = 0
		var rating: int = (
			MatchLabSupport.pitcher_fielding_rating(lab)
			if pitcher
			else lab._primary_fielder.fielding_rating
		)
		var scale: float = SeasonGearCatalog.item(id).handling
		var difficulty: float = (0.50 + rating * 0.095 - 0.16) * (1.0 + 1.0 / scale) / 2.0
		var position: Vector3 = (
			(
				lab._pitcher_marker.global_position
				if pitcher
				else lab._primary_fielder.global_position
			)
			+ Vector3(0, 0.5, 0)
		)
		lab._batted_ball.global_position = position
		lab._batted_ball.linear_velocity = Vector3(0, 0, difficulty / 0.030)
		if pitcher:
			lab._try_pitcher_defense(position, position)
		else:
			lab._try_primary_fielder()
		_check(
			lab._last_fielding_text.ends_with("BOBBLE" if id == "MISC-FLD-01" else "CLEAN"),
			"real primary/pitcher handling applies the Shoe tradeoff"
		)
	lab._cleanup_batted_ball()
