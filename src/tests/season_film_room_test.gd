extends "res://src/tests/season_tactical_sponsors_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_film_contracts()
	_film_migration()
	await _sponsor_ui(SeasonSponsorCatalog.FILM_ITEMS)
	await _film_ui()
	await _release_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Film Room checks passed: exact choice, release cue, neutral physics and replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _paid_film() -> SeasonState:
	var season: SeasonState = _funded_season(_sponsor_seed("J08", 3), 3)
	_check(
		(
			season
			. build
			. commit(
				_command(
					season.build,
					"sponsor_buy",
					{"offer": _offer(season.build, "J08"), "replace": ""}
				)
			)
			. ok
		),
		"actual paid Film Room"
	)
	return season


func _film_contracts() -> void:
	var build: SeasonBuild = _unit_build(["J08"])
	var recipe: String = "pitch.overhand_slider"
	var before: Dictionary = build.view()
	_check(
		not build.commit(_command(build, "pregame", {"game": 5})).ok,
		"active Film Room requires a choice"
	)
	for patch: Dictionary in [
		{"game": -1, "recipe": recipe},
		{"game": 4, "recipe": recipe},
		{"game": 5, "recipe": "bad"},
		{"game": 5, "recipe": recipe, "level": 5}
	]:
		_check(
			not build.commit(_command(build, "scout", patch)).ok and build.view() == before,
			"invalid or completed-game scouting is atomic"
		)
	var command: Dictionary = _command(build, "scout", {"game": 5, "recipe": recipe})
	_check(build.preview(command).ok and build.view() == before, "choice preview is pure")
	_check(build.commit(command).ok and build.commit(command).replayed, "exact selection retry")
	before = build.view()
	_check(
		(
			not (
				build
				. commit(_command(build, "scout", {"game": 5, "recipe": "pitch.sidearm_slider"}))
				. ok
			)
			and build.view() == before
		),
		"cannot retarget"
	)
	_check(build.commit(_command(build, "pregame", {"game": 5})).ok, "choice permits commitment")
	build = _unit_build([])
	_check(
		not build.commit(_command(build, "scout", {"game": 5, "recipe": recipe})).ok,
		"inactive sponsor cannot scout"
	)
	var state: MatchState = _fixture()
	state.batting_team().scouted_recipe = StringName(recipe)
	state.batter().definition.season_sponsors = {"J08": true}
	_check(MatchPitchDisclosure.release(state, StringName(recipe), 1).is_empty(), "no windup cue")
	state.begin_pitch()
	state.cancel_pitch()
	_check(state.pitch_disclosure.is_empty(), "canceled pitch reveals nothing")
	state.begin_pitch()
	_check(
		MatchPitchDisclosure.release(state, &"pitch.sidearm_slider", 2).is_empty(),
		"exact variants distinct"
	)
	var event: Dictionary = MatchPitchDisclosure.release(state, StringName(recipe), 2)
	_check(
		event.keys().size() == 4 and event.recipe == recipe and event.time == state.elapsed_seconds,
		"identity-only timestamped event, no flight data"
	)
	state.record_foul()
	state.continue_after_dead_ball()
	state.defensive_team().select_pitcher(2)
	state.begin_pitch()
	_check(state.pitch_disclosure.is_empty(), "new delivery clears old identity")
	_check(
		not MatchPitchDisclosure.release(state, StringName(recipe), 3).is_empty(),
		"same recipe from reliever qualifies"
	)
	state.batter().definition.season_sponsors = {}
	_check(
		MatchPitchDisclosure.release(state, StringName(recipe), 4).is_empty(),
		"no active sponsor no disclosure"
	)


func _film_migration() -> void:
	SeasonSave.path = "user://film-migration-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(_seed_for("E08", 17), false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 17
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
					{"offer": _offer(season.build, "E08"), "replace": ""}
				)
			)
			. ok
		),
		"real old Budget purchase"
	)
	season.build.commit(_command(season.build, "pregame", {"game": season.pending_fixture().id}))
	_check(SeasonSave.save(season), "old schema21 with committed pregame")
	var before: Dictionary = season.build.view()
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == before and restored.build._film_from == 2,
		"migration preserves committed pregame, paid inventory and stock"
	)
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		season.build.view().shop.offers == restored.build.view().shop.offers,
		"same-visit rerolls retain old pool"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		(
			SeasonSponsorCatalog.catalog(restored.build._sponsor_catalog_version()).has("J08")
			and SeasonSave.save(restored)
			and SeasonSave.restore() != null
		),
		"new Film pool activates next visit and replays"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
		await _frames(1)


func _film_ui() -> void:
	var path: String = "user://film-ui-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _paid_film()
	_check(app._checkpoint(), "checkpoint paid Film")
	var before: Dictionary = app.season.build.view()
	app.play_season_game()
	_check(app.lab == null and app.season.build.view() == before, "no silent default target")
	app.menu.show_lineup()
	await _frames()
	var picker: OptionButton = app.menu.find_child("FilmRecipe", true, false)
	_check(picker != null and picker.item_count > 1, "announced starter recipe options")
	await _menu_bounds(app, "film-pregame")
	picker.grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE)
	_check(app.film_recipe == "" and app.season.build.view() == before, "cancel is pure")
	picker.grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(app.film_recipe != "", "keyboard chooses actual exact recipe")
	var recipe: String = app.film_recipe
	await _click(_button(app.menu, "SEASON HUB"))
	app.menu.show_lineup()
	await _frames()
	_check(
		app.film_recipe == recipe and app.season.build.view() == before, "back retains draft only"
	)
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_button(app.menu, "PLAY GAME"))
	_check(app.lab == null and app.season.build.view() == before, "failed save rolls back choice")
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "previous bytes intact")
	app.menu.show_lineup()
	await _frames()
	await _click(_button(app.menu, "PLAY GAME"))
	_check(
		app.lab != null and SeasonFilmRoom.target(app.season) == StringName(recipe),
		"Play saves exact choice before game"
	)
	var game: int = int(app.season.pending_fixture().id)
	var committed: Dictionary = app.season.build.view()
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == committed, "selection replays")
	app.leave_game()
	await _frames()
	app.season = restored
	app.film_recipe = "pitch.sidearm_slider"
	app.menu.show_lineup()
	await _frames()
	_check(app.menu.find_child("FilmRecipe", true, false) == null, "locked choice has no editor")
	await _click(_button(app.menu, "PLAY GAME"))
	_check(app.season.build.view() == committed, "stale draft and restart cannot retarget")
	app.leave_game()
	await _frames()
	var foreign: SeasonState = _paid_film()
	var invalid: String = ""
	for id: StringName in ContentDB.pitch_by_id:
		if not SeasonFilmRoom.choices(foreign, foreign.pending_fixture()).has(String(id)):
			invalid = String(id)
			break
	_check(
		(
			foreign
			. build
			. commit(_command(foreign.build, "scout", {"game": game, "recipe": invalid}))
			. ok
		),
		"controlled nonstarter recipe journal"
	)
	bytes = FileAccess.get_file_as_string(path)
	_check(
		not SeasonSave.save(foreign) and FileAccess.get_file_as_string(path) == bytes,
		"save verifies announced repertoire, not just globally valid recipe"
	)
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _release_ui() -> void:
	var baseline: Dictionary = {}
	for enabled: bool in [false, true]:
		var lab: PitchBatLab = PitchBatLab.new()
		lab._configured_match = _fixture()
		lab._player_home = false
		add_child(lab)
		await _frames(3)
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		lab._match_state.phase = MatchState.Phase.PRE_PITCH
		var recipe: StringName = lab._current_pitch_options()[0].id
		lab._match_state.batting_team().scouted_recipe = recipe
		lab._match_state.batter().definition.season_sponsors = {"J08": true} if enabled else {}
		lab._throw_number = 150
		lab._selected_pitch_index = 0
		lab._ai_pitch_preselected = true
		lab._pitch_target = lab.DEFAULT_TARGET
		lab._throw_pitch()
		var parameters: PitchLaunchParameters = lab._pitch_actor.parameters
		var actual: Dictionary = {
			"position": parameters.position,
			"velocity": parameters.velocity,
			"angular": parameters.angular_velocity,
			"orientation": parameters.orientation,
			"seed": parameters.seed,
			"stamina": lab._match_state.pitcher().stamina_remaining
		}
		if not enabled:
			baseline = actual
			_check(
				lab._status_label.text == "" and not lab._live_label.visible,
				"baseline has no normal release name; debug preserved"
			)
		else:
			_check(actual == baseline, "same seed/input gives identical launch and workload")
			_check(
				lab._status_label.text == "FILM ROOM • " + lab._selected_pitch().display_name,
				"human release cue names exact recipe"
			)
			_check(
				(
					lab._batter_approach.recognized_recipe == lab._match_state.pitch_disclosure
					and (
						lab._active_play_record.to_dict().pitch_disclosure
						== lab._match_state.pitch_disclosure
					)
				),
				"human/AI/export share exact disclosure timestamp"
			)
			_check(
				lab._event_panel.visible and lab._event_panel.size.y < 100,
				"cue uses compact noncentral event panel"
			)
			await _capture(get_viewport(), "film-release-cue")
		lab.queue_free()
		await _frames(2)
