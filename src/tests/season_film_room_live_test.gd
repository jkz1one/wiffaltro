extends "res://src/tests/season_tactical_live_test.gd"

const FilmFixtures = preload("res://src/tests/season_film_room_test.gd")
var _enabled: bool = false
var _disclosures: int = 0
var _last_throw: int = -1
var _records: Array = []


func _ready() -> void:
	var fixture: Node = FilmFixtures.new()
	var baseline: Array = []
	for enabled: bool in [false, true]:
		_enabled = enabled
		_disclosures = 0
		_last_throw = -1
		_season = fixture._paid_film()
		_check(fixture._failures == 0, "real paid Film fixture")
		SeasonSave.path = "user://film-live-%s-%d.json" % [str(enabled), OS.get_process_id()]
		var app: SeasonApp = SeasonApp.new()
		app.season = _season
		app.film_game = int(_season.pending_fixture().id)
		app.film_recipe = SeasonFilmRoom.choices(_season, _season.pending_fixture())[0]
		_check(SeasonPregameCommit.save(app), "production atomic Film pregame")
		app.free()
		var before: Dictionary = _season.build.view()
		var game: Dictionary = _season.pending_fixture()
		await _run_match(67)
		if enabled:
			_check(_disclosures > 0, "selected recipe actually disclosed in complete game")
			_check(_records == baseline, "all complete-game physics and outcomes identical on/off")
			await _settlement_retry(game, before)
		else:
			baseline = _records.duplicate(true)
			_check(_disclosures == 0, "disabled control has no cues")
		print("FILM_LIVE enabled=", enabled, " disclosures=", _disclosures)
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Film Room checks passed: paid choice, neutral A/B games and saved results."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	_played_state = state
	if not _enabled:
		state.home_team.scouted_recipe = &""


func _observe_live_frame(lab: PitchBatLab) -> void:
	var event: Dictionary = lab._match_state.pitch_disclosure
	if not event.is_empty() and int(event.throw) != _last_throw:
		_last_throw = int(event.throw)
		_disclosures += 1
		_check(
			event.recipe == String(lab._match_state.home_team.scouted_recipe), "only chosen recipe"
		)
		_check(lab._batter_approach.recognized_recipe == event, "AI recognizes same release event")
	if lab._match_state.phase == MatchState.Phase.GAME_END:
		_records = []
		for record: PlayRecord in lab._play_records:
			var row: Dictionary = record.to_dict()
			row.erase("pitch_disclosure")
			_records.append(row)
