extends "res://src/tests/club_career_test.gd"
## Synthetic balanced stats isolate extraction; these are not claimed physical-game results.


func _ready() -> void:
	SeasonSave.path = "user://stadium-career-stats-%d.json" % OS.get_process_id()
	var season: SeasonState = _new(121)
	_record_stats(season)
	_check(StadiumCareerProgress.capture(season.career).is_empty(),
		"active-season stats do not fabricate a closed stadium progress prefix")
	while season.phase != SeasonState.Phase.COMPLETE:
		_record_stats(season)
	_check(SeasonSave.save(season), "completed synthetic stats receive a real saved career proof")
	var rows: Array = StadiumCareerProgress.capture(season.career)
	_check(rows.size() == 1 and rows[0].seasons == 1 and rows[0].wins == 10
		and rows[0].strikeouts == 48, "human regular and playoff pitching strikeouts are captured once")
	_check(StadiumCareerProgress.valid(rows, ClubPlayers.income(season.career)),
		"stat context is bound to exact closed income/progress rows")
	var metrics: Dictionary = StadiumCareerProgress.metrics(rows, 1)
	var stock: StadiumStock = StadiumStock.new_club()
	_check(stock.quote("ST-026", 1, metrics, "target-preview").ok,
		"catalog target milestone uses captured strikeouts, not a substitute season count")
	_check(not stock.quote("ST-026", 1, {"seasons": 1, "strikeouts": 39}, "39").ok
		and stock.quote("ST-026", 1, {"seasons": 1, "strikeouts": 40}, "40").ok,
		"exact forty-strikeout threshold is retained")
	var unknown: ClubCareer = ClubCareer.new()
	unknown.runs = season.career.runs.duplicate(true)
	unknown.runs[0].player_progress = null
	_check(StadiumCareerProgress.capture(unknown) == [{"seasons": 1, "wins": 10}],
		"missing historical stat evidence stays unknown and preserves the old row grammar")
	var malformed: ClubCareer = ClubCareer.new()
	malformed.runs = season.career.runs.duplicate(true)
	malformed.runs[0].player_progress.games[0].stats.strikeouts = true
	_check(StadiumCareerProgress.capture(malformed).is_empty(), "malformed stats fail closed")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "close completed run before next season")
	var active: SeasonState = _new(122, club)
	_record_stats(active)
	_check(StadiumCareerProgress.metrics(StadiumCareerProgress.capture(active.career), 1).strikeouts
		== 48, "unfinished current run cannot mutate an earlier purchase prefix")
	var abandoned: ClubCareer = active.career.fork()
	_check(abandoned.close(active), "close unfinished run as abandoned")
	var retained: Array = StadiumCareerProgress.capture(abandoned)
	_check(retained.size() == 2 and retained[1].seasons == 0 and retained[1].strikeouts == 4,
		"completed games retain their strikeouts after abandoning a season")
	_check(StadiumCareerProgress.metrics(retained, 2).strikeouts == 52
		and StadiumCareerProgress.metrics(retained, 2).seasons == 1,
		"abandoning grants no completed season or duplicate statistics")
	_check(StadiumCareerProgress.valid(retained, ClubPlayers.income(abandoned)),
		"zero-income abandoned row may retain independently evidenced statistics")
	for invalid: Variant in [true, -1, "40", 120000]:
		_check(not StadiumCareerProgress.valid([{"seasons": 1, "wins": 10, "strikeouts": invalid}],
			[220]), "untrusted malformed or unbounded stat context rejects")
	_cleanup()
	if _failures == 0:
		print("Wiffaltro stadium career stat checks passed: closed human evidence and exact K gates.")
	get_tree().quit(0 if _failures == 0 else 1)


func _record_stats(season: SeasonState) -> void:
	var fixture: Dictionary = season.pending_fixture()
	var roster: Array = season.teams[fixture.away].roster + season.teams[fixture.home].roster
	var stats: Dictionary = {}
	for id: String in roster:
		stats[id] = MatchPerformance.empty_line()
	var ours: String = season.teams[0].roster[0]
	var enemy: String = season.teams[fixture.away if fixture.home == 0 else fixture.home].roster[0]
	stats[ours].p_k = 4
	stats[ours].outs = 4
	stats[enemy].k = 4
	stats[enemy].pa = 4
	_check(SeasonPerformance.valid(stats, roster), "synthetic pitching/batting ledger balances")
	_check(season.record_player_result(fixture.id, 0 if fixture.home == 0 else 1,
		1 if fixture.home == 0 else 0, stats), "commit one scheduled synthetic human win")
