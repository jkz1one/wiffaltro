extends "res://src/tests/paid_shop_ui_test.gd"

const ROSTER: Array[String] = [
	"player.alex_finch", "player.rowan_chase", "player.nico_vega", "player.ari_banks"
]


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_kit_contract()
	_gloves_contract()
	await _goggles_contract()
	_migration()
	await _misc_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Misc checks passed: first batter, temporal window, reaction, saves and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture() -> MatchState:
	return ProgressionMatchAdapter.exhibition(SeasonDevelopment.new("misc-test"), ROSTER[0])


func _equip(player: PlayerMatchState, id: String) -> void:
	player.definition = SeasonGearCatalog.equip(player.definition, {"misc": {"item": id}})


func _release(state: MatchState) -> void:
	_check(state.begin_pitch(), "begin actual pitch")
	state.note_pitch_released()
	state.pitcher().spend_stamina(2.0 * SeasonGearCatalog.workload(state.pitcher()))


func _kit_contract() -> void:
	for outcome: String in ["walk", "strikeout", "hit", "out"]:
		var state: MatchState = _fixture()
		var first: PlayerMatchState = state.pitcher()
		_equip(first, "D02")
		_check(is_equal_approx(SeasonGearCatalog.workload(first), 0.85), "first batter discount")
		_check(state.begin_pitch(), "cancellable windup")
		state.cancel_pitch()
		_check(
			state._pa_pitchers.is_empty() and not first.first_batter_completed,
			"cancelled windup does not count as participation"
		)
		for _foul in range(8):
			_release(state)
			state.note_pitch_released()
			_check(
				state._pa_pitchers.size() == 1,
				"duplicate release notification does not duplicate pitcher"
			)
			state.record_foul()
			state.continue_after_dead_ball()
			_check(
				(
					not first.first_batter_completed
					and is_equal_approx(SeasonGearCatalog.workload(first), 0.85)
				),
				"long foul battle retains whole-first-batter benefit"
			)
		_release(state)
		match outcome:
			"walk":
				state.balls = 3
				state.record_ball()
			"strikeout":
				state.record_strike()
			"hit":
				state.record_hit(BallPlayOutcome.Result.SINGLE)
			"out":
				state.record_ball_in_play_out()
		_check(
			first.first_batter_completed and state._pa_pitchers.is_empty(),
			"completed PA consumes window"
		)
		_check(
			is_equal_approx(SeasonGearCatalog.workload(first), 1.10),
			"later-batter workload penalty"
		)
		state.continue_after_dead_ball()
		var team: TeamMatchState = state.defensive_team()
		_check(state.can_change_defense() and team.select_pitcher(2), "ordinary legal reliever")
		var second: PlayerMatchState = state.pitcher()
		_equip(second, "D02")
		_check(
			not second.first_batter_completed and SeasonGearCatalog.workload(second) == 0.85,
			"each reliever has their own first batter"
		)
		_check(not team.select_pitcher(0), "Kit grants no retired-pitcher return")
		state.outs = 2
		_release(state)
		state.record_ball_in_play_out()
		state.continue_after_dead_ball()
		_check(
			first.first_batter_completed and second.first_batter_completed,
			"inning transition does not reset participation"
		)
	var state: MatchState = _fixture()
	var first: PlayerMatchState = state.pitcher()
	_release(state)
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	var stamina: float = first.stamina_remaining
	_equip(first, "D02")
	_check(
		(
			first.first_batter_completed
			and SeasonGearCatalog.workload(first) == 1.10
			and first.stamina_remaining == stamina
		),
		"participation tracks without Kit and equip refunds no fatigue"
	)
	# Model a future legally authorised interruption without changing today's substitution rights.
	state = _fixture()
	first = state.pitcher()
	_release(state)
	state.defensive_team().pitcher_index = 2
	var relief: PlayerMatchState = state.pitcher()
	state.note_pitch_released()
	state.record_hit(BallPlayOutcome.Result.DOUBLE)
	_check(
		first.first_batter_completed and relief.first_batter_completed,
		"all actual release participants consume the completed PA"
	)
	_check(
		not state.defensive_team().roster[3].first_batter_completed,
		"nonparticipants do not consume a window"
	)
	_check(not _fixture().pitcher().first_batter_completed, "new game resets first-batter state")


func _gloves_contract() -> void:
	var player: PlayerDefinition = _fixture().batter().definition
	for swing_id: StringName in [&"swing.contact", &"swing.power"]:
		var source: SwingProfileDefinition = ContentDB.get_swing(swing_id)
		for bat: String in ["", "BAT-CON-01", "BAT-POW-01"]:
			var baseline: PlayerDefinition = SeasonGearCatalog.equip(player, {"bat": {"item": bat}})
			var geared: PlayerDefinition = SeasonGearCatalog.equip(
				player, {"bat": {"item": bat}, "misc": {"item": "MISC-BAT-01"}}
			)
			var normal: SwingProfileDefinition = SeasonGearCatalog.swing(source, baseline)
			var gloves: SwingProfileDefinition = SeasonGearCatalog.swing(source, geared)
			_check(
				is_equal_approx(
					gloves.contact_end() - gloves.contact_start(),
					(normal.contact_end() - normal.contact_start()) * 1.08
				),
				"separate temporal width +8%"
			)
			_check(
				(
					gloves.contact_radius_x_m == normal.contact_radius_x_m
					and gloves.contact_radius_y_m == normal.contact_radius_y_m
					and gloves.contact_depth_m == normal.contact_depth_m
				),
				"Gloves do not widen spatial contact"
			)
			_check(
				(
					gloves.sweet_spot_seconds == normal.sweet_spot_seconds
					and gloves.swing_duration_seconds == normal.swing_duration_seconds
					and gloves.contact_end() <= gloves.swing_duration_seconds
				),
				"committed swing timing unchanged"
			)
			var intent: SwingIntent = SwingIntent.new()
			intent.aim_point = Vector2(0, 1.05)
			intent.start_time_seconds = 2.0
			for left: bool in [false, true]:
				intent.handedness_left = left
				for time: float in [
					normal.contact_start() - 0.001,
					normal.sweet_spot_seconds,
					normal.contact_end() + 0.001
				]:
					_check(
						ContactResolver.swing_center_position(time, intent, normal).is_equal_approx(
							ContactResolver.swing_center_position(time, intent, gloves)
						),
						"barrel path is not retimed"
					)
					var result: ContactResult = _timed_contact(gloves, intent, time)
					_check(
						result != null and result.outcome != ContactResult.Outcome.MISS,
						"real swept contact accepts the extended window"
					)
					if not is_equal_approx(time, normal.sweet_spot_seconds):
						_check(
							_timed_contact(normal, intent, time) == null,
							"neutral misses outside original window"
						)
						_check(
							result.quality < 0.8 and absf(result.timing_error_m) > 0.0,
							"extended edge contact stays weak with actual timing error"
						)
				_check(
					(
						_timed_contact(gloves, intent, gloves.contact_start() - 0.001) == null
						and _timed_contact(gloves, intent, gloves.contact_end() + 0.001) == null
					),
					"Gloves do not rescue contact beyond the actual widened window"
				)
				var center: Vector3 = Vector3(0, 1.05, ContactResolver.CONTACT_PLANE_Z)
				var pitch: PitchState = PitchState.new()
				pitch.velocity = Vector3(0, 0, -24)
				for x: float in [0.0, normal.contact_radius_x_m * 0.95]:
					var position: Vector3 = center + Vector3(x, 0, 0)
					var a: ContactResult = ContactResolver._resolve_at_contact(
						pitch, position, center, intent, normal, 5, 5
					)
					var b: ContactResult = ContactResolver._resolve_at_contact(
						pitch, position, center, intent, gloves, 5, 5
					)
					_check(
						a.quality == b.quality and a.timing_error_m == b.timing_error_m,
						"Gloves do not grant quality or timing correction"
					)
					var scale: float = 1.0 if a.outcome == ContactResult.Outcome.FOUL else 0.96
					_check(
						is_equal_approx(b.exit_velocity.length() / a.exit_velocity.length(), scale),
						"fair-only glove penalty composes with either Bat"
					)
				var tracker: SwingContactTracker = SwingContactTracker.new()
				tracker.begin(intent, gloves, 5, 5)
				var miss: PitchState = PitchState.new()
				miss.position = Vector3(5, 5, 5)
				miss.elapsed_time = intent.start_time_seconds + normal.contact_end() + 0.001
				tracker.sample_segment(miss.position, miss.elapsed_time - 0.0001, miss)
				_check(tracker.active, "tracker remains active through added tolerance")
				miss.elapsed_time = intent.start_time_seconds + gloves.contact_end() + 0.001
				tracker.sample_segment(miss.position, miss.elapsed_time - 0.0001, miss)
				_check(not tracker.active, "tracker expires after modified window")
		_check(
			source.gear_timing_scale == 1.0 and source.gear_fair_exit_scale == 1.0,
			"authored resource remains neutral"
		)


func _timed_contact(
	profile: SwingProfileDefinition, intent: SwingIntent, time: float
) -> ContactResult:
	var center: Vector3 = ContactResolver.swing_center_position(time, intent, profile)
	var state: PitchState = PitchState.new()
	state.position = center
	state.elapsed_time = intent.start_time_seconds + time
	state.velocity = Vector3(0, 0, -24)
	return ContactResolver.resolve_swept_segment(
		center, state.elapsed_time - 0.00001, state, intent, profile, 5, 5
	)


func _goggles_contract() -> void:
	var player: PlayerDefinition = _fixture().fielder().definition
	var goggles: PlayerDefinition = SeasonGearCatalog.equip(
		player, {"misc": {"item": "MISC-FLD-03"}}
	)
	var fielder: FielderController = FielderController.new()
	add_child(fielder)
	fielder.set_physics_process(false)
	fielder.configure_player(player)
	var normal: float = fielder.reaction_delay_seconds
	var speed: float = fielder.move_speed_mps
	var reach: float = fielder.reach_m
	fielder.configure_player(goggles)
	_check(
		is_equal_approx(fielder.reaction_delay_seconds, normal * 0.85),
		"Goggles scale existing reaction"
	)
	_check(
		(
			fielder.move_speed_mps == speed
			and fielder.reach_m == reach
			and fielder.fielding_rating == player.fielding
		),
		"no hidden speed/reach/handling buff"
	)
	fielder.begin_play()
	var ball: Vector3 = Vector3(2, 0.5, 3)
	var velocity: Vector3 = Vector3(1, 0, 0)
	fielder._play_elapsed_seconds = fielder.reaction_delay_seconds - 0.001
	fielder.plan_for_ball(ball, velocity, true)
	_check(
		fielder.target_position == fielder.anchor_position,
		"no path observation before reduced delay"
	)
	fielder._play_elapsed_seconds = normal * 0.90
	fielder.plan_for_ball(ball, velocity, true)
	_check(
		fielder.target_position != fielder.anchor_position,
		"planning begins within gained reaction window"
	)
	fielder.configure_player(player)
	fielder.begin_play()
	fielder._play_elapsed_seconds = normal * 0.90
	fielder.plan_for_ball(ball, velocity, true)
	_check(fielder.target_position == fielder.anchor_position, "neutral defender still waits")
	_check(SeasonGearCatalog.reaction_delay(0.0, goggles) > 0.0, "positive reaction floor")
	fielder.queue_free()
	await _frames()


func _command(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id": "misc:%d" % build.revision(), "rev": build.revision(), "op": op}
	result.merge(fields)
	return result


func _record(season: SeasonState) -> void:
	var fixture: Dictionary = season.pending_fixture()
	_check(
		season.record_player_result(
			fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0
		),
		"completed fixture"
	)


func _offer(build: SeasonBuild, id: String) -> String:
	for key: String in build.view().shop.offers:
		if build.view().shop.offers[key] == id:
			return key
	return ""


func _seed_for(id: String, format_version: int = SeasonBuild.VERSION) -> int:
	for seed_value in range(300):
		var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER)
		build._format = format_version
		build.commit(_command(build, "reward", {"game": 0, "win": true}))
		build.commit(_command(build, "open"))
		if not _offer(build, id).is_empty():
			return seed_value
	_check(false, "supported item is reachable: " + id)
	return -1


func _migration() -> void:
	var path: String = "user://misc-migration-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	var season: SeasonState = SeasonState.create(_seed_for("MISC-PIT-03", 3), false, true)
	for _pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 3
	_record(season)
	season.build.commit(_command(season.build, "open"))
	var offer: String = _offer(season.build, "MISC-PIT-03")
	_check(
		season.build.commit(_command(season.build, "equip", {"offer": offer, "replace": ""})).ok,
		"schema7 owns genuinely paid Rosin"
	)
	var old: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save old Gear schema")
	var bytes: String = FileAccess.get_file_as_string(path)
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == old, "migration preserves Gear/cash/stock")
	_check(FileAccess.get_file_as_string(path) == bytes, "no load-only rewrite")
	if restored != null:
		_check(restored.build.to_data().misc_from == 2, "new Misc starts next visit")
		_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "schema8 replay stable")
		_record(restored)
		restored.build.commit(_command(restored.build, "open"))
		_check(
			SeasonSave.save(restored) and SeasonSave.restore() != null,
			"post-migration visit replay"
		)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _misc_ui(items: Dictionary = SeasonGearCatalog.MISC_ITEMS) -> void:
	for id: String in items:
		var slot: String = SeasonGearCatalog.item(id).slot
		var prefix: String = "user://misc-ui-%s-%d" % [id, OS.get_process_id()]
		SeasonSave.path = prefix + ".json"
		PitchBatLabSettings.path = prefix + ".cfg"
		var app: SeasonApp = SeasonApp.new()
		add_child(app)
		await _frames()
		app.begin_season(_seed_for(id), true)
		for _pick in range(4):
			app.choose_player(app.season.offers()[0])
		_record(app.season)
		_check(app._checkpoint(), "save result before Misc purchase")
		app.open_shop()
		await _frames()
		var window: SeasonShopWindow = _shop(app)
		await _shop_bounds(window, "gear-normal-" + id)
		window.size = Vector2i(700, 400)
		await _shop_bounds(window, "misc-shop-" + id)
		var offer: String = _offer(app.season.build, id)
		var before: Dictionary = app.season.build.to_data()
		_check(_gear_status_visible(window, id), "offer displays item's correct status")
		await _click(_gear_button(window, "gear_offer", offer))
		_check(
			(
				window._confirm.visible
				and window._review_text.text.contains(SeasonGearCatalog.item(id).effect)
			),
			"review names exact Misc tradeoff"
		)
		_check(
			window._confirm.gui_get_focus_owner() == window._confirm.get_cancel_button(),
			"Gear confirmation defaults to Cancel"
		)
		_check(window._confirm.size.x <= window.size.x, "Gear review fits narrow window")
		_check(window._confirm.size.y <= window.size.y, "Gear review fits narrow window height")
		var review_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(window._confirm.size))
		_check(
			(
				review_bounds.encloses(window._confirm.get_ok_button().get_global_rect())
				and review_bounds.encloses(window._confirm.get_cancel_button().get_global_rect())
			),
			"both confirmation controls remain visible"
		)
		_check(
			(
				window._review_text.text.ends_with("Confirm and save?")
				and window._review_text.text.contains("Cash: ")
			),
			"scrollable review retains every effect and transaction detail"
		)
		window._review_scroll.scroll_vertical = 10000
		await _frames()
		_check(
			(
				window._review_text.get_global_rect().end.y
				<= window._review_scroll.get_global_rect().end.y + 1
			),
			"scrolling reaches the final confirmation details"
		)
		if items == SeasonGearCatalog.PROPOSAL_ITEMS:
			_check(
				window._review_text.text.contains(
					"Working calibration" if id == "A02" else "Proposal — unapproved"
				),
				"paid review discloses selected calibration or remaining unapproved mapping"
			)
		await _capture(window._confirm, "misc-review-" + id)
		await _click(window._confirm.get_cancel_button())
		_check(app.season.build.to_data() == before, "Misc cancellation spends nothing")
		await _click(_gear_button(window, "gear_offer", offer))
		await _click(window._confirm.get_ok_button())
		var receipt: Dictionary = app.season.build.view().wallet.gear[slot]
		_check(
			receipt.item == id and receipt.paid == SeasonGearCatalog.item(id).price,
			"Misc purchase records full exact price"
		)
		_check(_gear_status_visible(window, id), "equipped receipt displays item's correct status")
		await _shop_bounds(window, "gear-equipped-" + id)
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and restored.build.view() == app.season.build.view(),
			"Misc saves atomically"
		)
		await _click(window._back)
		app.season = restored
		app.play_season_game()
		await _frames(5)
		_check(app.lab != null, "paid Misc reaches actual match")
		if app.lab != null:
			await _live_misc(app.lab, id)
			app.leave_game()
		app.open_shop()
		await _frames()
		window = _shop(app)
		await _click(_gear_button(window, "gear_sell", receipt.id))
		await _click(window._confirm.get_ok_button())
		_check(
			app.season.build.view().wallet.gear[slot].is_empty(), "Misc sale restores empty slot"
		)
		app.queue_free()
		await _frames()
		for file: String in [prefix + ".json", prefix + ".cfg"]:
			for suffix: String in ["", ".bak", ".tmp"]:
				DirAccess.remove_absolute(file + suffix)


func _live_misc(lab: PitchBatLab, id: String) -> void:
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var own: TeamMatchState = (
		lab._match_state.home_team if lab._player_home else lab._match_state.away_team
	)
	for player: PlayerMatchState in own.roster:
		_check(player.definition.season_gear.get("misc") == id, "all paid team members share Misc")
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
		_equip(pitcher, id)
		_equip(lab._match_state.batter(), id)
		_equip(lab._match_state.fielder(), id)
		lab._refresh_config()
		lab._apply_defensive_assignment()
		var stamina: float = pitcher.stamina_remaining
		var cost: float = (
			MatchLabSupport.stamina_cost(lab._selected_pitch(), 1.0)
			* SeasonGearCatalog.workload(pitcher)
		)
		lab._throw_pitch()
		_check(lab._pitch_actor.running, "real human/AI Misc pitch launches")
		_check(
			is_equal_approx(stamina - pitcher.stamina_remaining, cost),
			"real release uses workload once"
		)
		if id == "D02":
			_check(
				lab._match_state._pa_pitchers.has(pitcher), "real release records Kit participation"
			)
			lab._match_state.record_hit(BallPlayOutcome.Result.SINGLE)
			_check(
				pitcher.first_batter_completed and SeasonGearCatalog.workload(pitcher) == 1.10,
				"actual release and PA completion activate Kit penalty"
			)
		elif id == "MISC-BAT-01":
			lab._resolve_swing(PitchBatLab.POWER_SWING_ID, Vector2(0, 1.05))
			_check(
				(
					lab._swing_tracker.profile.gear_timing_scale == 1.08
					and lab._swing_tracker.profile.gear_fair_exit_scale == 0.96
				),
				"human/AI real swing uses Gloves"
			)
		elif id == "MISC-FLD-03":
			_check(
				is_equal_approx(PitchBatLabDefenseSupport.reaction_delay(lab), 0.17),
				"human/AI pitcher pursuit gets Goggles delay"
			)
			var rating: float = float(lab._match_state.fielder().definition.fielding) / 10.0
			_check(
				is_equal_approx(
					lab._primary_fielder.reaction_delay_seconds, lerpf(0.24, 0.09, rating) * 0.85
				),
				"human/AI active fielder gets same Gear"
			)
		await _frames(1)


func _gear_button(window: SeasonShopWindow, meta: String, value: String) -> Button:
	for child in window._body.find_children("*", "Control", true, false):
		if child is Button and child.get_meta(meta, "") == value:
			return child
	return null


func _gear_status_visible(window: SeasonShopWindow, id: String) -> bool:
	var item: Dictionary = SeasonGearCatalog.item(id)
	for child in window._body.find_children("*", "Control", true, false):
		if child is Label and child.text.contains(item.name):
			if child.text.contains(item.get("status", "Working")):
				return true
	return false
