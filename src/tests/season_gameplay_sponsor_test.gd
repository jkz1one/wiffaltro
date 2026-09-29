extends "res://src/tests/season_sponsor_test.gd"

const GearFixtures = preload("res://src/tests/season_gear_test.gd")


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_college_provenance()
	_deli_contract()
	_paid_growth_and_migration()
	await _runtime_hooks()
	await _sponsor_ui(SeasonSponsorCatalog.GAMEPLAY_ITEMS)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro gameplay sponsor checks passed: chains, earned growth, saves, UI and live hooks."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _growth(book: SeasonDevelopment, player: String, op: String, target: String) -> void:
	_check(
		(
			book
			. commit(
				{
					"id": "earned:%d" % book.revision(),
					"rev": book.revision(),
					"player": player,
					"op": op,
					"target": target
				}
			)
			. ok
		),
		"valid provenance event"
	)


func _college_provenance() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("college-test")
	_check(book.earned_players(ROSTER).is_empty(), "authored baseline is not earned")
	_growth(book, ROSTER[0], "stat", "contact")
	_growth(book, ROSTER[0], "mastery", book.player(ROSTER[0]).active[0])
	_check(book.earned_players(ROSTER) == [ROSTER[0]], "many upgrades count one player")
	_growth(book, ROSTER[1], "mastery", book.player(ROSTER[1]).active[0])
	_growth(book, ROSTER[2], "round_out", book.player(ROSTER[2]).active[0])
	var fresh: String = ROSTER[3]
	_growth(book, fresh, "recruit", "late")
	_check(not book.earned_players(ROSTER).has(fresh), "generated catch-up is not earned")
	var recipe: String = ""
	for candidate: String in DevelopmentShopCatalog.LESSON_PRICES:
		if not book.player(fresh).active.has(candidate):
			recipe = candidate
			break
	_check(
		(
			book
			. commit(
				{
					"id": "lesson",
					"rev": book.revision(),
					"player": fresh,
					"op": "learn",
					"target": recipe,
					"replace": book.player(fresh).active[0]
				}
			)
			. ok
		),
		"legal replacement lesson"
	)
	_check(not book.earned_players(ROSTER).has(fresh), "learning alone is not earned growth")
	_growth(book, fresh, "stat", "fielding")
	var saved: SeasonDevelopment = SeasonDevelopment.from_data(book.to_data(), "college-test")
	_check(saved != null and saved.earned_players(ROSTER).size() == 4, "provenance replays")
	var absent: Array = ROSTER.duplicate()
	absent.erase(ROSTER[0])
	_check(saved.earned_players(absent).size() == 3, "departed player contributes nothing")
	absent.append(ROSTER[0])
	_check(saved.earned_players(absent).size() == 4, "same returning instance contributes again")
	var profile: PlayerDefinition = ProgressionMatchAdapter.player(book, fresh)
	profile.season_sponsors = SeasonSponsorEffects.snapshot([{"item": "B02"}], book, ROSTER)
	for pitch: PitchDefinition in ContentDB.pitch_by_id.values():
		var natural: bool = pitch.delivery_profile.id == profile.natural_delivery.id
		_check(
			is_equal_approx(
				SeasonSponsorEffects.workload(profile, pitch), 0.88 if natural else 1.0
			),
			"only exact natural delivery receives max reduction"
		)
	_check(SeasonSponsorEffects.snapshot([], book, ROSTER).is_empty(), "no unowned effect")
	_check(
		SeasonSponsorCatalog.earnings([{"item": "A07"}, {"item": "B02"}], ROSTER, {}).is_empty(),
		"match sponsors do not invent settlement income"
	)


func _sponsored_fixture() -> MatchState:
	var state: MatchState = _fixture()
	for team: TeamMatchState in [state.away_team, state.home_team]:
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors = {"A07": true, "B02": 4}
	return state


func _deli_contract() -> void:
	var state: MatchState = _sponsored_fixture()
	_check(not SeasonSponsorEffects.deli_active(state), "no free opening chain")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	_check(SeasonSponsorEffects.deli_active(state), "credited Single gives next batter the chain")
	state.continue_after_dead_ball()
	_check(state.defensive_team().select_pitcher(2), "legal pitching change")
	_check(
		SeasonSponsorEffects.deli_active(state), "pitcher change retains same batting opportunity"
	)
	state.record_foul()
	state.continue_after_dead_ball()
	_check(
		SeasonSponsorEffects.deli_active(state), "foul battle does not consume next-batter benefit"
	)
	state.begin_pitch()
	state.cancel_pitch()
	_check(SeasonSponsorEffects.deli_active(state), "cancelled delivery does not consume the chain")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	var fixture: Node = GearFixtures.new()
	for bat: String in ["", "BAT-CON-01", "BAT-POW-01", "A02"]:
		for misc: String in ["", "MISC-BAT-01"]:
			state.batter().definition = SeasonGearCatalog.equip(
				state.batter().definition, {"bat": {"item": bat}, "misc": {"item": misc}}
			)
			for swing_id: StringName in [&"swing.contact", &"swing.power"]:
				var source: SwingProfileDefinition = ContentDB.get_swing(swing_id)
				var normal: SwingProfileDefinition = SeasonGearCatalog.swing(
					source, state.batter().definition
				)
				var changed: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
				var bonus: float = 0.04 if swing_id == &"swing.contact" else 0.0
				bonus *= 0.96 if misc == "MISC-BAT-01" else 1.0
				_check(
					is_equal_approx(
						changed.gear_fair_exit_scale, normal.gear_fair_exit_scale + bonus
					),
					"bounded additive Bat bonus; Gloves multiply once; Power unchanged"
				)
				for left: bool in [true, false]:
					for error: float in [0.0, 0.4, 0.95]:
						var a: ContactResult = fixture._contact(normal, left, error)
						var b: ContactResult = fixture._contact(changed, left, error)
						var ratio: float = (
							1.0
							if a.outcome == ContactResult.Outcome.FOUL
							else changed.gear_fair_exit_scale / normal.gear_fair_exit_scale
						)
						_check(
							is_equal_approx(
								b.exit_velocity.length() / a.exit_velocity.length(), ratio
							),
							"physical fair-only exit speed, both handednesses"
						)
						_check(
							(
								a.quality == b.quality
								and a.launch_angle_degrees == b.launch_angle_degrees
							),
							"no quality/trajectory rescue"
						)
	fixture.free()
	for ending: String in ["walk", "strikeout", "out", "double", "triple", "hr"]:
		state = _sponsored_fixture()
		state.record_hit(BallPlayOutcome.Result.SINGLE)
		state.continue_after_dead_ball()
		match ending:
			"walk":
				state.balls = 3
				state.record_ball()
			"strikeout":
				state.strikes = 2
				state.record_strike()
			"out":
				state.record_ball_in_play_out()
			"double":
				state.record_hit(BallPlayOutcome.Result.DOUBLE)
			"triple":
				state.record_hit(BallPlayOutcome.Result.TRIPLE)
			"hr":
				state.record_hit(BallPlayOutcome.Result.HOME_RUN)
		_check(not SeasonSponsorEffects.deli_active(state), ending + " does not refresh Deli")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	state.phase = MatchState.Phase.INNING_TRANSITION
	state.continue_after_dead_ball()
	_check(not SeasonSponsorEffects.deli_active(state), "chain cannot cross into opponent half")
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	state.outs = 2
	state.record_ball_in_play_out()
	state.continue_after_dead_ball()
	_check(not SeasonSponsorEffects.deli_active(state), "chain does not resume next own half")
	state = _fixture()
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	_check(not SeasonSponsorEffects.deli_active(state), "unowned Single gives no modifier")


func _paid_growth_and_migration() -> void:
	var path: String = "user://gameplay-sponsor-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	var season: SeasonState = _funded_season(_college_seed(), 2)
	var build: SeasonBuild = season.build
	var card: String = ""
	for value: String in build.view().shop.offers.values():
		if DevelopmentShopCatalog.CARDS.has(value):
			card = value
			break
	var hold: Dictionary = {
		"offer": _offer(build, card), "mode": "hold", "player": "", "pitch": "", "replace": ""
	}
	_check(build.commit(_command(build, "buy", hold)).ok, "buy a real held growth card")
	_check(
		build._book.earned_players(build.roster()).is_empty(), "held purchase is not development"
	)
	var target: Dictionary = build.targets(card)[0]
	var use: Dictionary = target.duplicate()
	use["receipt"] = build.view().wallet.held[0].id
	_check(build.commit(_command(build, "use", use)).ok, "consume paid held card")
	_check(
		(
			build
			. commit(_command(build, "sponsor_buy", {"offer": _offer(build, "B02"), "replace": ""}))
			. ok
		),
		"buy College after prior earned growth"
	)
	var id: String = build.roster()[0]
	_check(build.definition(id).season_sponsors.B02 == 1, "prior growth counts on later purchase")
	_check(build.commit(_command(build, "pack_open")).ok, "purchase real development pack")
	card = build.view().shop.cards[0]
	var pick: Dictionary = {"item": card}
	for choice: Dictionary in build.targets(card):
		if choice.player != target.player:
			pick.merge(choice)
			break
	_check(
		build.commit(_command(build, "pack_pick", pick)).ok, "commit real growth on another player"
	)
	_check(
		build.definition(id).season_sponsors.B02 == 2,
		"team-wide benefit recomputes after additional committed growth"
	)
	_check(SeasonSave.save(season), "save paid College and actual earned history")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.definition(id).season_sponsors.B02 == 2,
		"earned qualification survives schema11 replay"
	)
	var rival: String = season.teams[1].roster[0]
	_check(build.definition(rival).season_sponsors.is_empty(), "opponent gets no purchased sponsor")
	var receipt: Dictionary = build.view().wallet.sponsors[0]
	_check(
		build.commit(_command(build, "sponsor_sell", {"receipt": receipt.id})).ok,
		"explicit paid sponsor sale"
	)
	_check(
		build.definition(id).season_sponsors.is_empty(),
		"sale removes effect without erasing growth"
	)
	# A genuine old journal, not a current journal with its version number relabelled.
	season = SeasonState.create(_seed_for("D01", 6), false, true)
	for _pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 6
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
					{"offer": _offer(season.build, "D01"), "replace": ""}
				)
			)
			. ok
		),
		"paid old sponsor before migration"
	)
	var old: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save genuine schema10")
	var bytes: String = FileAccess.get_file_as_string(path)
	restored = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == old, "old stock, cash and counters stay exact"
	)
	_check(FileAccess.get_file_as_string(path) == bytes, "migration does not rewrite on load")
	_check(restored.build.to_data().gameplay_sponsor_from == 2, "new candidates start next visit")
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		season.build.view().shop.offers == restored.build.view().shop.offers,
		"old visit rerolls keep frozen three-sponsor pool"
	)
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "migrated journal replays")
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		SeasonSave.save(restored) and SeasonSave.restore() != null,
		"expanded next-visit pool replays"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _runtime_hooks() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = _sponsored_fixture()
	add_child(lab)
	await _frames(4)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	for human: bool in [true, false]:
		lab._player_home = human
		lab._match_state.record_hit(BallPlayOutcome.Result.SINGLE)
		lab._match_state.phase = MatchState.Phase.PRE_PITCH
		lab._match_state.between_batters = true
		lab._pitch_actor.reset_pitch()
		lab._selected_pitch_index = 0
		lab._ai_pitch_preselected = true
		lab._pitch_effort = 1.0
		lab._pending_release_quality = 1.0
		lab._pending_release_overdrive = 0.0
		lab._pitch_target = Vector2(0, 1.05)
		var pitcher: PlayerMatchState = lab._match_state.pitcher()
		_equip(pitcher, "MISC-PIT-03")
		lab._refresh_config()
		var pitch: PitchDefinition = lab._selected_pitch()
		var expected: float = MatchLabSupport.stamina_cost(pitch, 1.0) * 1.10
		expected *= (
			0.88 if pitch.delivery_profile.id == pitcher.definition.natural_delivery.id else 1.0
		)
		var before: float = pitcher.stamina_remaining
		lab._throw_pitch()
		_check(lab._pitch_actor.running, "real human/AI sponsored release launches")
		_check(
			is_equal_approx(before - pitcher.stamina_remaining, expected),
			"actual release spends College and Rosin workload exactly once"
		)
		lab._resolve_swing(PitchBatLab.CONTACT_SWING_ID, Vector2(0, 1.05))
		_check(
			is_equal_approx(lab._swing_tracker.profile.gear_fair_exit_scale, 1.04),
			"actual human/AI swing consumes Deli profile"
		)
	lab.queue_free()
	await _frames()


func _college_seed() -> int:
	for seed_value in range(300):
		var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER)
		for game in range(2):
			build.commit(_command(build, "reward", {"game": game, "win": true}))
		build.commit(_command(build, "open"))
		if _offer(build, "B02").is_empty():
			continue
		for value: String in build.view().shop.offers.values():
			if DevelopmentShopCatalog.CARDS.has(value):
				return seed_value
	_check(false, "find real College and held card quotes")
	return -1
