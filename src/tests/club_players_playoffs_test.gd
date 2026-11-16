extends "res://src/tests/season_opponent_base_playoffs_test.gd"
## Full 33-game current owned-player season. Every score remains a physical result.


func _permanent_players() -> bool:
	return true


func _audit_season() -> void:
	super._audit_season()
	var season: SeasonState = _app.season
	var evidence: Dictionary = ClubPlayerProgress.capture(season)
	_check(season.player_access == ClubPlayerCatalog.initial_owned(), "season access remains frozen")
	_check(not evidence.is_empty() and ClubCareer.same(
		evidence, season.career.runs[-1].player_progress), "physical unlock history exactly saved")
	_check(SeasonSave.snapshot(season).version == 58,
		"historical pre-stadium full-season ownership grammar")
	var owned: Array[String] = ClubPlayers.owned(season.career)
	if season.phase == SeasonState.Phase.COMPLETE:
		_check(owned.has("player.quinn_riley"), "real completed season earns participation player")
	print("OWNED_PLAYER_SEASON games=", season.player_results.size(),
		" owned=", JSON.stringify(owned), " metrics=",
		JSON.stringify(ClubPlayerProgress.metrics(season.career.runs)))
