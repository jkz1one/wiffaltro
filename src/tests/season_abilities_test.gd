extends "res://src/tests/season_field_supply_test.gd"

var _ability_fixture: SeasonState
var _sky_offer: String


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://abilities-%d.json" % OS.get_process_id()
	_count_runtime()
	await _field_abilities()
	await _soft_physical()
	_sky_progress()
	var season: SeasonState = _paid_abilities()
	if season != null:
		_ability_receipts(season)
		_ability_return(season)
		_ability_migration()
		await _ability_ui()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro abilities checks passed: learning, replacement, physics, progression, saves and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _taken(state: MatchState, actual: bool = true) -> void:
	_check(state.begin_pitch(), "begin taken pitch")
	if actual:
		state.note_pitch_released()
	state.record_called_pitch(false)
	state.continue_after_dead_ball()


func _count_runtime() -> void:
	var state: MatchState = _new_club(67).make_match()
	var player: PlayerDefinition = state.batter().definition
	player.season_abilities = [SeasonAbilities.COUNT]
	var source: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	_taken(state, false)
	_check(state.abilities.called_balls == 0, "unreleased synthetic call is not evidence")
	state.balls = 0
	_taken(state)
	_check(state.abilities.called_balls == 1, "first actual called ball")
	state.begin_pitch()
	state.cancel_pitch()
	_check(state.abilities.called_balls == 1, "canceled windup keeps progress")
	state.begin_pitch()
	state.note_pitch_released()
	state.record_foul()
	state.continue_after_dead_ball()
	_check(state.abilities.called_balls == 1, "foul never earns progress")
	var next_pitcher: int = (state.defensive_team().pitcher_index + 1) % 4
	state.defensive_team().pitcher_index = next_pitcher
	_taken(state)
	_check(state.abilities.called_balls == 2, "pitcher change preserves actual called balls")
	for swing: StringName in [&"swing.contact", &"swing.power"]:
		source = ContentDB.get_swing(swing)
		var profile: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
		_check(
			(
				is_equal_approx(profile.contact_radius_x_m, source.contact_radius_x_m * 1.06)
				and is_equal_approx(profile.contact_radius_y_m, source.contact_radius_y_m * 1.06)
			),
			"both swing profiles gain spatial radii only"
		)
		_check(
			profile.contact_window_end_seconds == source.contact_window_end_seconds,
			"no timing or exit bonus"
		)
	player.season_gear = {"bat": "BAT-CON-01"}
	var gear: SwingProfileDefinition = SeasonGearCatalog.swing(source, player)
	var combined: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
	_check(
		is_equal_approx(
			combined.contact_radius_x_m, gear.contact_radius_x_m + source.contact_radius_x_m * 0.06
		),
		"Bat and learned radii are additive"
	)
	state.batting_team().tactics.held = [{"id": "tape", "item": "A10"}]
	state.between_batters = true
	_check(
		state.batting_team().tactics.activate(state, state.batting_team(), "tape"), "Tape fixture"
	)
	var tape: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
	_check(
		is_equal_approx(tape.contact_radius_x_m, combined.contact_radius_x_m * 1.08),
		"existing Tape multiplication remains last"
	)
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	_check(state.abilities.called_balls == 0, "next hitter resets evidence")
	state.continue_after_dead_ball()
	state.balls = 2
	_check(state.abilities.called_balls == 0, "starting count is not actual takes")


func _field_abilities() -> void:
	var player: PlayerDefinition = _new_club(67).build.definition(ROSTER[0])
	player.season_abilities = [SeasonAbilities.HANDS]
	var bonus: float = MatchAbilities.ground_margin(player, true, 0.0)
	_check(bonus == 0.10, "eligible ground margin")
	_check(
		(
			MatchAbilities.ground_margin(player, true, -0.001) == 0.0
			and MatchAbilities.ground_margin(player, false, 1.0) == 0.0
		),
		"negative reaction and air excluded"
	)
	var speed: float = (0.50 + 5 * 0.095 - 0.08) / 0.028
	_check(
		FieldingResolver.resolve(0, speed, 0.1, true, 5) == FieldingResolver.Outcome.BOBBLE,
		"baseline borderline ground bobble"
	)
	_check(
		(
			FieldingResolver.resolve(0, speed, 0.1, true, 5, 0, 1, bonus)
			== FieldingResolver.Outcome.CLEAN
		),
		"Soft Hands converts eligible ground control"
	)
	_check(
		(
			FieldingResolver.resolve(9, speed, 0.1, true, 5, 0, 1, bonus)
			== FieldingResolver.Outcome.MISS
		),
		"bonus cannot rescue reach"
	)
	_check(
		(
			FieldingResolver.resolve(0, speed, 2.2, true, 5, 0, 1, bonus)
			== FieldingResolver.Outcome.MISS
		),
		"bonus cannot rescue height"
	)
	_check(
		(
			(PitcherDefense.resolve(
				Vector3(0, 0.1, 0), Vector3(speed, 0, 0), Vector3.ZERO, true, 5, 1, bonus
			))
			== FieldingResolver.Outcome.CLEAN
		),
		"defending pitcher receives margin"
	)
	var fielder: FielderController = FielderController.new()
	add_child(fielder)
	player.season_abilities = [SeasonAbilities.SKY]
	player.season_gear = {"misc": "MISC-FLD-03"}
	fielder.configure_player(player)
	var normal: float = fielder.reaction_delay_seconds
	for angle: float in [24.9, 25.0, 45.0]:
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.velocity = Vector3(0, sin(deg_to_rad(angle)), cos(deg_to_rad(angle))) * 20
		fielder.begin_play(false, Vector3.ZERO, launch)
		_check(
			is_equal_approx(
				fielder.reaction_delay_seconds, normal * (0.60 if angle >= 25 else 1.0)
			),
			"actual launch classification " + str(angle)
		)
		fielder.end_play()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.velocity = Vector3(0, 20, 10)
	launch.is_foul = true
	fielder.begin_play(false, Vector3.ZERO, launch)
	_check(is_equal_approx(fielder.reaction_delay_seconds, normal), "foul retains baseline")
	fielder.end_play()
	launch.is_foul = false
	fielder.begin_play(false, Vector3.RIGHT, launch)
	fielder._play_elapsed_seconds = 0.19
	_check(not fielder.pursuit_ready(), "Sky cannot shorten mandatory Jumpstart step")
	fielder._play_elapsed_seconds = 0.20
	_check(fielder.pursuit_ready(), "pursuit after both gates")
	fielder.free()


func _sky_progress() -> void:
	for kind: String in ["pitcher", "bobble"]:
		var rejected: SeasonState = _new_club(67)
		var command: Dictionary = _reward(rejected)
		command.erase("field_supply")
		for row: Dictionary in command.fielding:
			if kind == "pitcher":
				row.primary = false
				row.player = row.pitcher
			else:
				row.clean = false
		_check(
			rejected.build.commit(command).ok and rejected.build._abilities.earned == 0,
			"Sky excludes " + kind + " catches"
		)
	var season: SeasonState = _new_club(67)
	_check(_jump_result(season, false, false), "completed loss with one clean airborne primary out")
	_check(season.build._abilities.earned == 1, "ground outs excluded from Sky count")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "completed games survive abandonment")
	season = _new_club(67, club)
	_check(season.build._abilities.start == 1, "career counts combine across seasons")
	_check(
		_jump_result(season, false) and _jump_result(season, false), "two more completed catches"
	)
	_check(season.career.sync(season), "sync completed career catches")
	_check(SeasonAbilities.access(season.career) == 3, "three clean primary catches earn access")
	_check(season.build._abilities.pool(season.build).has(SeasonAbilities.SKY), "paid access only")
	_check(season.build._abilities.learned.is_empty(), "unlock grants no free learning")


func _paid_abilities() -> SeasonState:
	var probe_season: SeasonState = _new_club(0)
	for game in range(6):
		_jump_result(probe_season, false)
	var probe: SeasonBuild = probe_season.build
	for seed_value in range(100000):
		probe._seed = seed_value
		var offers: Array = probe._offers(0).values()
		if (
			not offers.has(SeasonAbilities.COUNT)
			or not offers.has(SeasonAbilities.HANDS)
			or not offers.has(SeasonAbilities.SKY)
		):
			continue
		var season: SeasonState = _new_club(seed_value)
		for game in range(6):
			_jump_result(season, false)
		var build: SeasonBuild = season.build
		_check(build.commit(_command(build, "open")).ok, "generated ability shop")
		for id: String in [SeasonAbilities.COUNT, SeasonAbilities.HANDS, SeasonAbilities.SKY]:
			var offer: String = _offer(build, id)
			_check(not offer.is_empty(), "real namespaced offer " + id)
			if id == SeasonAbilities.SKY:
				_check(SeasonSave.save(season), "save exact replacement fixture")
				_ability_fixture = SeasonSave.restore()
				_sky_offer = offer
			_check(
				(
					build
					. commit(
						_command(
							build,
							"ability_buy",
							{
								"offer": offer,
								"player":
								(
									build.roster()[1]
									if id == SeasonAbilities.SKY
									else build.roster()[0]
								),
								"replace": ""
							}
						)
					)
					. ok
				),
				"pay full price and teach " + id
			)
		print("ABILITY_FIXTURE seed=", seed_value)
		return season
	_check(false, "reachable generated ability offers")
	return null


func _ability_receipts(season: SeasonState) -> void:
	var build: SeasonBuild = season.build
	_check(
		build._abilities.ids(build.roster()[0]).size() == 2, "separate Hitting and Fielding slots"
	)
	var fork: SeasonBuild = build._fork()
	fork._abilities.learned[build.roster()[0]][0].paid = 999
	_check(build._abilities.learned[build.roster()[0]][0].paid == 12, "deep fork owns receipts")
	_check(SeasonSave.save(season), "save real paid learning")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build._abilities.learned == build._abilities.learned,
		"learning replays with identical receipts"
	)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for field: String in ["career", "start", "receipt", "unknown"]:
		var bad: Dictionary = data.duplicate(true)
		if field == "career":
			bad.career.runs[-1].sky_outs = 0
		elif field == "start":
			bad.build.ability_start = 3
		elif field == "receipt":
			bad.build.events[-1].replace = "foreign"
		else:
			bad.build.learned = {}
		_check(SeasonSave._decode(bad) == null, "reject forged ability data " + field)
	build = _ability_fixture.build._fork()
	var old: Dictionary = build._abilities.occupied(build.roster()[0], "Fielding")
	var request: Dictionary = _command(
		build, "ability_buy", {"offer": _sky_offer, "player": build.roster()[0], "replace": ""}
	)
	var before: Dictionary = build.to_data()
	_check(
		not build.commit(request).ok and build.to_data() == before,
		"full slot requires exact replacement"
	)
	request.replace = old.id
	var money: int = build.cash()
	_check(
		build.commit(request).ok and build.cash() == money - 12,
		"replacement charges full price no refund"
	)
	_check(
		build._abilities.ids(build.roster()[0]) == [SeasonAbilities.COUNT, SeasonAbilities.SKY],
		"explicit replacement forgets only old Fielding"
	)
	_check(
		build.commit(request).replayed and build.cash() == money - 12,
		"duplicate request idempotent"
	)
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "close learned season")
	var next: SeasonState = _new_club(67, club)
	_check(
		next.build._abilities.start == 3 and next.build._abilities.learned.is_empty(),
		"new season inherits access but resets learning"
	)


func _ability_migration() -> void:
	var season: SeasonState = _new_club(67)
	season.build._format = 35
	season.build._abilities.start = null
	season.career.runs[-1].sky_outs = null
	_jump_result(season, false)
	_check(season.build.commit(_command(season.build, "open")).ok, "legacy generated shop")
	var old_shop: Dictionary = season.build.view().shop
	_check(SeasonSave.save(season), "old build snapshot")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 16
	data.career.runs[-1].erase("sky_outs")
	var loaded: SeasonState = SeasonSave._decode(data)
	_check(loaded != null, "Build35 migration")
	if loaded == null:
		return
	_check(
		loaded.build.view().shop == old_shop and loaded.build._abilities.start == null,
		"old offers and prospective progress preserved"
	)
	_check(
		loaded.build._abilities.pool(loaded.build).is_empty(),
		"current old visit excludes abilities"
	)
	_check(loaded.build.commit(_command(loaded.build, "reroll")).ok, "old visit reroll")
	_check(
		not loaded.build.view().shop.offers.values().any(
			func(id: String) -> bool: return id.begins_with("ability.")
		),
		"old visit generator frozen"
	)
	_jump_result(loaded, false)
	_check(
		(
			loaded.build._abilities.pool(loaded.build).has(SeasonAbilities.COUNT)
			and not loaded.build._abilities.pool(loaded.build).has(SeasonAbilities.SKY)
		),
		"next visit gains initial abilities without retroactive Sky credit"
	)
	_check(SeasonSave.save(loaded) and SeasonSave.restore() != null, "migrated journal roundtrip")


func _ability_ui() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _ability_fixture
	var window: SeasonShopWindow = SeasonShopWindow.new()
	window.app = app
	app.add_child(window)
	window.popup_centered()
	await _frames()
	var loadout: SeasonLoadoutUI
	for child: Node in window.get_children():
		if child is SeasonLoadoutUI:
			loadout = child
	loadout.open()
	loadout._select("abilities")
	await _frames()
	_check(
		loadout._rows.abilities.size() == 2 and loadout._sale_buttons.is_empty(),
		"Equipped shows learned player effects without selling abilities"
	)
	_check(
		is_equal_approx(loadout.entry.position.x, (window.size.x - 176) / 2.0),
		"shop Equipped stays centered"
	)
	for index in range(8):
		loadout._cycle_focus(false)
		_check(
			loadout.panel.is_ancestor_of(window.gui_get_focus_owner()), "four-tab focus containment"
		)
	loadout.close()
	SeasonAbilityUI.choose(window, _sky_offer, SeasonAbilities.SKY)
	await _shop_bounds(window, "ability-replacement-choice")
	var chosen: Button
	for button: Button in window._body.find_children("*", "Button", true, false):
		if button.get_meta("ability_player", "") == app.season.build.roster()[0]:
			chosen = button
	_check(chosen != null, "explicit ability recipient control")
	if chosen != null:
		chosen.pressed.emit()
		await _frames()
		_check(
			window._review_text.text.contains("Forget Soft Hands; no refund"),
			"exact replacement disclosure"
		)
		var before: Dictionary = app.season.build.to_data()
		var path: String = SeasonSave.path
		SeasonSave.path = path + "/missing/save.json"
		window._commit()
		SeasonSave.path = path
		_check(app.season.build.to_data() == before, "failed save rolls back Cash, slot and offer")
		SeasonAbilityUI.choose(window, _sky_offer, SeasonAbilities.SKY)
		var old: Dictionary = app.season.build._abilities.occupied(
			app.season.build.roster()[0], "Fielding"
		)
		window._preview(
			window._request(
				"ability_buy",
				{"offer": _sky_offer, "player": app.season.build.roster()[0], "replace": old.id}
			),
			"Replace Soft Hands with Sky Reader"
		)
		window._commit()
		_check(
			app.season.build._abilities.ids(app.season.build.roster()[0]).has(SeasonAbilities.SKY),
			"UI saves learning"
		)
	window._confirm.hide()
	app.season = _paid_field()
	window._refresh()
	var old_money: int = app.season.build.cash()
	var receipt: Dictionary = SeasonSchoolSponsors.active(app.season.build, "B01")
	_check(SeasonSave.save(app.season), "shop lightbox sale checkpoint")
	loadout.open()
	loadout._select("sponsors")
	_check(loadout._sale_buttons.size() == 1, "shop lightbox exposes owned sponsor sale")
	loadout.sale.review(receipt.id, "Field Supply Co.")
	_check(loadout.sale._review.text.contains("7 Cash"), "exact visible half-price refund")
	var sale_path: String = SeasonSave.path
	SeasonSave.path = sale_path + "/missing/save.json"
	loadout.sale._commit()
	SeasonSave.path = sale_path
	_check(
		(
			app.season.build.cash() == old_money
			and not SeasonSchoolSponsors.active(app.season.build, "B01").is_empty()
		),
		"lightbox sale write failure rolls back"
	)
	loadout.sale.review(receipt.id, "Field Supply Co.")
	loadout.sale._commit()
	_check(
		app.season.build.cash() == old_money + 7 and loadout._rows.sponsors.is_empty(),
		"shop lightbox saves refund and refreshes cards"
	)
	_check(SeasonSave.restore() != null, "shop lightbox sale replays")
	loadout.close()
	window.queue_free()
	await _frames()
	SeasonAbilityUI.show(app.menu)
	await _menu_bounds(app, "ability-progress-and-roster")
	app.queue_free()
	await _frames()


func _ability_return(season: SeasonState) -> void:
	var build: SeasonBuild = season.build._fork()
	var owner: String = build.roster()[0]
	var retained: Array[String] = build._abilities.ids(owner)
	var fresh: String = ""
	for id: String in build._pool:
		if not build.roster().has(id) and not build._blocked.has(id):
			fresh = id
			break
	var profile: Dictionary = RecruitCatalog.fresh(fresh, "late")
	# Controlled recruitment quotes isolate identity retention; real paid learning above.
	build._visit.recruit = {
		"id": "fixture:departure",
		"player": fresh,
		"stage": "late",
		"price": 0,
		"returning": false,
		"profile": profile,
		"signed": false
	}
	_check(
		build.commit(_command(build, "sign", {"offer": "fixture:departure", "replace": owner})).ok,
		"release learned player"
	)
	_check(
		build._abilities.ids(owner) == retained and build._abilities.ids(fresh).is_empty(),
		"learning stays with departed owner, never incoming player"
	)
	build._visit.recruit = {
		"id": "fixture:return",
		"player": owner,
		"stage": "late",
		"price": 0,
		"returning": true,
		"profile": build.player(owner),
		"signed": false
	}
	_check(
		build.commit(_command(build, "sign", {"offer": "fixture:return", "replace": fresh})).ok,
		"rehire same instance"
	)
	_check(
		build.definition(owner).season_abilities == retained, "return restores exact learned slots"
	)


func _soft_physical() -> void:
	for role: String in ["primary", "pitcher"]:
		for eligible: bool in [true, false]:
			var lab: PitchBatLab = PitchBatLab.new()
			lab._configured_match = _new_club(67).make_match()
			var player: PlayerDefinition = (
				lab._configured_match.fielder().definition
				if role == "primary"
				else lab._configured_match.pitcher().definition
			)
			player.season_abilities = [SeasonAbilities.HANDS]
			player.fielding = 5
			lab._player_home = true
			add_child(lab)
			PitchBatLabFeelSupport.skip_match_presentation(lab)
			lab.set_process(false)
			lab.set_physics_process(false)
			lab._primary_fielder.set_physics_process(false)
			var location: Vector3 = (
				lab._primary_fielder.global_position
				if role == "primary"
				else lab._pitcher_marker.global_position
			)
			var launch: BattedBallLaunch = BattedBallLaunch.new()
			launch.position = location + Vector3(0, 0.1, 0)
			launch.velocity = Vector3((0.50 + 5 * 0.095 - 0.08) / 0.028, 0, 0)
			lab._start_ball_in_play(launch)
			lab._batted_ball.freeze = true
			lab._ball_play_resolver.state.has_grounded = true
			lab._ball_play_resolver.state.elapsed_seconds = 1.0 if eligible else 0.0
			lab._primary_fielder._play_elapsed_seconds = 1.0 if eligible else 0.0
			lab._primary_fielder.last_reaction_margin_seconds = 0.0
			if role == "primary":
				PitchBatLabDefenseSupport.try_primary(lab)
			else:
				PitchBatLabDefenseSupport.try_pitcher(lab, launch.position, launch.position)
			_check(
				lab._ball_play_resolver.state.bobbled == (not eligible),
				"actual " + role + " control applies Soft Hands only after reaction"
			)
			lab.queue_free()
			await _frames(2)
