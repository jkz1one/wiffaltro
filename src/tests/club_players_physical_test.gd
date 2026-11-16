extends "res://src/tests/physical_round_process_ui_test.gd"
## Production twelve-owned pool through actual physics, worker failure, restart and earned proof.


var _owned_checks: int = 0


func _ready() -> void:
	await super._ready()
	print("OWNED_PLAYER_RESULT checks=", _owned_checks, " failures=", _failures)


func _check(ok: bool, message: String) -> void:
	_owned_checks += 1
	super._check(ok, message)


func _permanent_players() -> bool:
	return true


func _audit_season() -> void:
	super._audit_season()
	var season: SeasonState = _app.season
	_check(season.player_access.size() == 12, "production starter access survives physical settlement")
	_check(SeasonSave.snapshot(season).version == 58,
		"pre-stadium ownership save58 remains replayable")
	var stored: Dictionary = season.career.runs[-1].player_progress
	var evidence: Dictionary = ClubPlayerProgress.capture_for(season, stored)
	_check(evidence.get("version") == ClubPlayerLegend.VERSION,
		"new owned season uses prospective Legend evidence without downgrading it")
	_check(not evidence.is_empty() and evidence.games.size() == season.player_results.size(),
		"real human-slot games produce compact unlock evidence")
	_check(ClubCareer.same(evidence, season.career.runs[-1].player_progress),
		"saved evidence exactly matches physical performance and chronology")
	# Preserve the historical v1 contract as an exact projection, not by
	# comparing a legacy capture to the newer stored v3 record.
	var hits: Dictionary = evidence.duplicate(true)
	hits.version = ClubPlayerProgress.HITS_VERSION
	for row: Dictionary in hits.games:
		row.erase("players")
	_check(ClubCareer.same(hits, ClubPlayerProgress.capture_with_hits(season)),
		"legacy v2 hit totals remain an exact projection of real physical evidence")
	var legacy: Dictionary = hits.duplicate(true)
	legacy.version = ClubPlayerProgress.VERSION
	for row: Dictionary in legacy.games:
		if row.stats != null:
			row.stats.erase("hits")
	_check(ClubCareer.same(legacy, ClubPlayerProgress.capture(season)),
		"legacy v1 aggregate performance and chronology remain exact")
	var scores: Array = ClubSeasonRecord.capture(season).scores
	_check(ClubPlayerProgress.valid(evidence, scores) and ClubPlayerProgress.valid(hits, scores)
		and ClubPlayerProgress.valid(legacy, scores),
		"all three evidence grammars retain valid provenance")
	var mislabeled: Dictionary = evidence.duplicate(true)
	mislabeled.version = ClubPlayerProgress.VERSION
	_check(not ClubPlayerProgress.valid(mislabeled, scores),
		"new individual evidence cannot be smuggled under the historical v1 grammar")
	var saved: SeasonState = SeasonSave._decode(JSON.parse_string(JSON.stringify(
		SeasonSave.snapshot(season), "", true, true)))
	_check(saved != null and ClubCareer.same(saved.career.runs[-1].player_progress, evidence),
		"cold save preserves exact earned player evidence after physical settlement")
	for index in range(evidence.games.size()):
		var row: Dictionary = evidence.games[index]
		var game: Dictionary = season.player_results[index]
		_check(row.game == game.id and row.players is Dictionary
			and row.players.size() == 4, "individual evidence binds exact game and four roster identities")
		if not row.players is Dictionary:
			continue
		for id: String in row.players:
			var line: Dictionary = game.performance[id]
			_check(row.players[id].hits == line.h and row.players[id].pa == line.pa
				and row.players[id].pitches == line.pitches and row.players[id].strikeouts == line.p_k
				and row.players[id].outs == line.outs,
				"stored individual totals equal actual report performance for " + id)
	for row: Dictionary in evidence.games:
		_check(row.stats != null and row.end_half >= 4,
			"current physical games have actual stats and end")
	print("OWNED_PLAYER_PHYSICAL games=", evidence.games.size(),
		" owned=", ClubPlayers.owned(season.career).size(), " evidence=", JSON.stringify(evidence))
