extends Node
## Authored structural fixtures; no authentic player achievements or physical game claims.
var _checks: int = 0
var _failures: Array[String] = []
var _ids: Array[String] = []


func _ready() -> void:
	_ids.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	_thresholds()
	_validation()
	_match_evidence()
	_capture()
	_lifecycle()
	await _runtime_activation()
	print(
		(
			"PLAYER_LEGEND_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"synthetic_history": true,
					"physical_games": 0,
					"rewards_issued": 0
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error("PLAYER_LEGEND: " + label)


func _line(pa: int = 1) -> Dictionary:
	return {
		"pa": pa,
		"pitches": 0,
		"hits": 0,
		"strikeouts": 0,
		"outs": 0,
		"fielded": false,
		"clean_outs": 0
	}


func _progress(games: int = 5) -> Dictionary:
	var rows: Array = []
	for game in range(games):
		var players: Dictionary = {}
		for id: String in _ids:
			players[id] = _line(1 if id == _ids[0] else 0)
		rows.append(
			{
				"game": game,
				"stats": {"homers": 0, "hits": 0, "hitters": 0, "strikeouts": 0, "three_k": 0},
				"sponsors": 0,
				"end_half": -1,
				"deficit": 0,
				"players": players
			}
		)
	return {"version": 3, "games": rows, "development": {"mastery": 0, "known": 0, "lessons": []}}


func _scores(games: int = 5) -> Array:
	var result: Array = []
	for game in range(games):
		result.append([game, 0, 1, 1, 0])
	return result


func _runs() -> Array:
	var result: Array = []
	for id in [1, 2, 3]:
		result.append({"id": id, "status": "completed", "player_progress": _progress()})
	return result


func _metric(runs: Array, key: String, count: int, index: int = 2, player: int = 0) -> void:
	var game: Dictionary = runs[index].player_progress.games[-1]
	var line: Dictionary = game.players[_ids[player]]
	line[key] = count
	if key == "hits":
		line.pa = maxi(count, int(line.pa))
		game.stats.hits = count
		game.stats.hitters = 1 if count > 0 else 0
	elif key == "strikeouts":
		line.pitches = count * 3
		line.outs = count
		game.stats.strikeouts = count
		game.stats.three_k = 1 if count >= 3 else 0
	else:
		line.fielded = count > 0
		line.outs = count


func _thresholds() -> void:
	for pair: Array in [["hits", 40], ["strikeouts", 60], ["clean_outs", 40]]:
		var runs: Array = _runs()
		_metric(runs, pair[0], pair[1] - 1)
		_check(
			not ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].eligible,
			pair[0] + " one below fails"
		)
		_metric(runs, pair[0], pair[1])
		var record: Dictionary = ClubPlayerLegend._evaluate_runs(runs)[_ids[0]]
		_check(
			record.eligible and record.completed_seasons == [1, 2, 3],
			pair[0] + " alone at boundary passes OR"
		)
		_check(
			record.credited_games == {"1": 5, "2": 5, "3": 5},
			"PA pitch and field play never multiply game credit"
		)
		_check(
			ClubPlayerLegend.valid(runs[2].player_progress, _scores()),
			pair[0] + " threshold fixture validates"
		)
	var runs: Array = _runs()
	_metric(runs, "hits", 40)
	runs[1].status = "abandoned"
	_check(
		not ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].eligible, "abandoned season never tenure"
	)
	runs.append({"id": 4, "status": "completed", "player_progress": _progress()})
	_check(
		ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].eligible, "nonconsecutive seasons qualify"
	)
	runs[2].status = "active"
	_check(
		not ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].eligible,
		"active season not completed tenure"
	)
	runs[2].status = "completed"
	runs[2].player_progress.games.resize(4)
	_metric(runs, "hits", 40, 1)
	_check(
		not ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].eligible,
		"four games does not qualify a season"
	)
	runs = _runs()
	_metric(runs, "hits", 40, 1)
	runs[1].status = "abandoned"
	runs.append({"id": 4, "status": "completed", "player_progress": _progress()})
	_check(
		ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].eligible,
		"abandoned performance remains eligible"
	)
	runs = _runs()
	_metric(runs, "hits", 40, 2, 1)
	_check(
		(
			not ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].eligible
			and not ClubPlayerLegend._evaluate_runs(runs)[_ids[1]].eligible
		),
		"another player's hits cannot combine with own tenure"
	)
	var accepted: Array = _runs()
	_metric(accepted, "strikeouts", 60)
	for run: Dictionary in accepted:
		for game: Dictionary in run.player_progress.games:
			game.players[_ids[0]].pa = 0
			game.players[_ids[0]].pitches = 0
	var no_participation: Dictionary = ClubPlayerLegend._evaluate_runs(accepted)[_ids[0]]
	_check(
		(
			no_participation.strikeouts == 60
			and no_participation.credited_games.is_empty()
			and not no_participation.eligible
		),
		"accepted zero-pitch synthetic Ks never fabricate participation"
	)
	for run: Dictionary in runs:
		for game: Dictionary in run.player_progress.games:
			game.players[_ids[0]].pa = 0
	_check(
		ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].completed_seasons.is_empty(),
		"reserve-only never credit"
	)
	for run: Dictionary in runs:
		for game: Dictionary in run.player_progress.games:
			game.players[_ids[0]].pitches = 1
	_check(
		ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].completed_seasons.size() == 3,
		"one actual pitch sufficient"
	)
	for run: Dictionary in runs:
		for game: Dictionary in run.player_progress.games:
			game.players[_ids[0]].pitches = 0
			game.players[_ids[0]].fielded = true
	_check(
		ClubPlayerLegend._evaluate_runs(runs)[_ids[0]].completed_seasons.size() == 3,
		"actual non-out fielding alone sufficient"
	)


func _validation() -> void:
	_check(ClubPlayerLegend.valid(_progress(), _scores()), "prospective schema validates")
	for mutation: String in [
		"extra",
		"fraction",
		"bool",
		"negative",
		"nan",
		"foreign",
		"duplicate",
		"opponent",
		"roster",
		"hits",
		"strikeouts",
		"clean",
		"downgrade",
		"detail"
	]:
		var bad: Dictionary = _progress()
		var line: Dictionary = bad.games[0].players[_ids[0]]
		match mutation:
			"extra":
				line.extra = 0
			"fraction":
				line.pa = 0.5
			"bool":
				line.pitches = true
			"negative":
				line.hits = -1
			"nan":
				line.pa = NAN
			"foreign":
				bad.games[0].players["player.unknown"] = bad.games[0].players[_ids[0]]
				bad.games[0].players.erase(_ids[0])
			"duplicate":
				bad.games[1].game = 0
			"opponent":
				pass
			"roster":
				bad.games[0].players.erase(_ids[1])
			"hits":
				line.hits = 40
			"strikeouts":
				line.strikeouts = 60
			"clean":
				line.clean_outs = 40
				line.fielded = true
			"downgrade":
				bad.version = 2
			"detail":
				bad.games[0].erase("players")
		var scores: Array = _scores()
		if mutation == "opponent":
			scores[0] = [0, 1, 2, 1, 0]
		_check(not ClubPlayerProgress.valid(bad, scores), "reject malformed " + mutation)
	var inflated: Dictionary = _progress()
	inflated.games[0].end_half = 9
	inflated.games[0].players[_ids[0]].outs = 40
	inflated.games[0].players[_ids[0]].clean_outs = 40
	inflated.games[0].players[_ids[0]].fielded = true
	_check(
		not ClubPlayerLegend.valid(inflated, _scores()),
		"known defensive halves cap fabricated clean outs"
	)
	var unknown: Dictionary = _progress()
	for game: Dictionary in unknown.games:
		game.players = null
	_check(
		(
			ClubPlayerLegend.valid(unknown, _scores())
			and (
				ClubPlayerLegend
				. _evaluate_runs([{"id": 1, "status": "completed", "player_progress": unknown}])
				. is_empty()
			)
		),
		"unknown detail is never invented"
	)


func _match_evidence() -> void:
	var away: Array[PlayerDefinition] = []
	var home: Array[PlayerDefinition] = []
	var ids: Array[String] = SeasonPlayerCatalog.ids()
	for index in range(4):
		away.append(ContentDB.get_player(StringName(ids[index])))
		home.append(ContentDB.get_player(StringName(ids[index + 4])))
	var state: MatchState = MatchState.create(
		TeamMatchState.create("Away", away), TeamMatchState.create("Home", home)
	)
	var old: Dictionary = state.performance.snapshot(state)
	_check(
		SeasonPerformance.valid(old, old.keys()) and not old.values()[0].has("fielding_v1"),
		"old performance stays exact"
	)
	state.performance.track_fielding = true
	var id: StringName = state.fielder().definition.id
	state.performance.fielding_play(id)
	state.performance.fielding_play(id)
	var current: Dictionary = state.performance.snapshot(state)
	_check(
		SeasonPerformance.valid(current, current.keys()) and current[String(id)].fielding_v1,
		"opt-in per-player fielding survives duplicate touch"
	)
	current.values()[0].fielding_v1 = 1
	_check(not SeasonPerformance.valid(current, current.keys()), "fielding flag strictly boolean")
	current = state.performance.snapshot(state)
	current.values()[0].erase("fielding_v1")
	_check(not SeasonPerformance.valid(current, current.keys()), "mixed old/new lines rejected")


func _capture() -> void:
	var season: SeasonState = StadiumPennantRewardRebuildChecks._new(ClubCareer.new())
	_check(season != null, "capture fixture ordinary new career")
	if season == null:
		return
	var fixture: Dictionary = season.pending_fixture()
	var own: Array = season.teams[0].roster
	var enemy: Array = season.teams[fixture.away if fixture.home == 0 else fixture.home].roster
	var stats: Dictionary = {}
	for id: String in own + enemy:
		stats[id] = MatchPerformance.empty_line()
		stats[id]["fielding_v1"] = false
	stats[own[0]].pa = 2
	stats[own[0]].h = 2
	stats[own[1]].outs = 4
	stats[own[1]].p_k = 2
	stats[own[1]].pitches = 6
	stats[own[2]].fielding_v1 = true
	stats[enemy[0]].pa = 4
	stats[enemy[0]].k = 2
	stats[enemy[1]].p_h = 2
	stats[enemy[1]].pitches = 2
	stats[enemy[2]].fielding_v1 = true
	var fields: Array = []
	for index in range(2):
		fields.append(
			{
				"pa": index + 1,
				"half": 0 if fixture.home == 0 else 1,
				"player": own[2],
				"pitcher": own[1],
				"primary": true,
				"air": index == 0,
				"clean": index == 0
			}
		)
	_check(
		(
			SeasonPerformance.valid(stats, stats.keys())
			and season.record_player_result(fixture.id, 1, 0, stats, [], [], {}, [], fields)
		),
		"actual settlement accepts attributed balanced synthetic evidence"
	)
	if season.player_results.is_empty():
		return
	var captured: Dictionary = ClubPlayerLegend.capture(season)
	_check(not captured.is_empty(), "capture produces valid v3 proof")
	if captured.is_empty():
		return
	var row: Dictionary = captured.games[0]
	_check(
		row.players.size() == 4 and not row.players.has(enemy[2]),
		"opponent-only performance never retained"
	)
	_check(
		row.players[own[2]].fielded == true and row.players[own[2]].clean_outs == 1,
		"same defender gets participation and only clean fielded out, not prior bobble"
	)
	_check(
		row.players[own[1]].strikeouts == 2 and row.players[own[1]].clean_outs == 0,
		"pitcher Ks are not clean fielded outs"
	)
	_check(
		(
			row.players[own[3]].pa == 0
			and row.players[own[3]].pitches == 0
			and row.players[own[3]].fielded == false
		),
		"unplayed reserve retains zero participation"
	)
	var before: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(before, "", true, true))
	)
	_check(
		(
			not before.is_empty()
			and cold != null
			and ClubCareer.same(SeasonSave.snapshot(cold), before)
		),
		"new per-player game survives actual cold-save replay exactly"
	)
	var closed: ClubCareer = season.career.fork()
	_check(closed.close(season), "abandoned season freezes prospective player evidence")
	var property_progress: Array = StadiumCareerProgress.capture(closed)
	_check(
		property_progress.size() == 1 and property_progress[0].get("hits") == 2,
		"v3 retains existing club-wide hits for stadium progression"
	)
	var evaluated: Dictionary = ClubPlayerLegend.evaluate(closed)
	_check(
		(
			evaluated.get(own[0], {}).get("hits") == 2
			and evaluated[own[0]].completed_seasons.is_empty()
		),
		"public evaluator validates cold career and retains abandoned individual hits without tenure"
	)
	season.player_results[0].erase("fielding")
	for line: Dictionary in season.player_results[0].performance.values():
		line.erase("fielding_v1")
	var unknown: Dictionary = ClubPlayerLegend.capture(season)
	_check(
		(
			not unknown.is_empty()
			and unknown.games[0].players[own[2]].fielded == null
			and unknown.games[0].players[own[2]].clean_outs == null
		),
		"missing fielding remains unknown"
	)
	season.player_results[0].erase("club_roster")
	unknown = ClubPlayerLegend.capture(season)
	_check(
		not unknown.is_empty() and unknown.games[0].players == null,
		"missing old game roster not reconstructed from present club"
	)


func _lifecycle() -> void:
	var source: Dictionary = StadiumPennantRewardRebuildChecks.fixture(1)
	_check(source.ok, "new prospective career fixture cold-validates")
	if not source.ok:
		return
	var career: ClubCareer = source.career
	var season: SeasonState = source.season
	_check(
		(
			career.runs[0].player_progress.version == 3
			and ClubPlayerLegend.evaluate(career).is_empty()
		),
		"score-only fixture grants no invented player evidence"
	)
	var before: Dictionary = career.to_data()
	_check(
		career.sync(season) and career.sync(season) and ClubCareer.same(before, career.to_data()),
		"settlement replay exact and idempotent"
	)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(saved, "", true, true))
	)
	_check(
		cold != null and ClubCareer.same(cold.career.to_data(), before),
		"prospective season save cold roundtrip"
	)
	var legacy: Dictionary = before.duplicate(true)
	legacy.runs[0].player_progress.version = 2
	for game: Dictionary in legacy.runs[0].player_progress.games:
		game.erase("players")
	var old: ClubCareer = ClubCareer.from_data(legacy)
	_check(
		old != null and ClubPlayerLegend.evaluate(old).is_empty(), "legacy v2 unchanged and unknown"
	)
	if old != null:
		season.career = old
		_check(
			old.sync(season) and ClubCareer.same(old.to_data(), legacy),
			"legacy active/completed sync never silently upgrades"
		)
	_check(
		not source.ledger.construction().copies.values().any(
			func(copy: Dictionary) -> bool: return copy.item == "ST-066"
		),
		"foundation issues no plaque"
	)


func _runtime_activation() -> void:
	# Authored runtime contacts, not a played/earned game: exercise the actual app gate,
	# core callback, result capture, duplicate sync and cold restore in one existing scene.
	var prior_path: String = SeasonSave.path
	SeasonSave.path = "user://legend-runtime-%d.json" % OS.get_process_id()
	for mode: String in ["v3", "v2", "exhibition"]:
		var app: SeasonApp = SeasonApp.new()
		add_child(app)
		app.set_process(false)
		app.season = StadiumPennantRewardRebuildChecks._new(ClubCareer.new())
		if mode == "v2":
			app.season.career.runs[-1].player_progress.version = 2
		var fixture: Dictionary = app.season.pending_fixture()
		app._fixture_id = fixture.id
		var state: MatchState = app.season.make_match()
		var field: FieldDefinition = SeasonState.field_for_fixture(fixture, app.season)
		app._open_match(state, fixture.home == 0, mode != "exhibition", field.id)
		_check(
			app.lab != null and state.performance.track_fielding == (mode == "v3"),
			"actual app activates only v3 official career: " + mode
		)
		if app.lab != null:
			var lab: PitchBatLab = app.lab
			lab._record_export.path = (
				"user://legend-contact-%s-%d.json" % [mode, OS.get_process_id()]
			)
			PitchBatLabFeelSupport.skip_match_presentation(lab)
			lab.set_process(false)
			lab.set_physics_process(false)
			lab._primary_fielder.set_physics_process(false)
			if mode == "v3":
				state.top_half = fixture.home == 0
				var own: String = String(state.fielder().definition.id)
				_runtime_bobble(lab)
				state.top_half = fixture.home != 0
				var enemy: String = String(state.fielder().definition.id)
				_runtime_bobble(lab)
				var stats: Dictionary = state.performance.snapshot(state)
				_check(
					(
						stats[own].fielding_v1
						and stats[enemy].fielding_v1
						and stats[own].pa == 0
						and stats[own].pitches == 0
						and state.clean_outs.rows.is_empty()
					),
					"runtime non-out contacts retain defender flags without PA/pitch/clean-out fabrication"
				)
				_check(
					app.season.record_player_result(fixture.id, 1, 0, stats),
					"runtime participation reaches ordinary settlement"
				)
				var proof: Dictionary = ClubPlayerLegend.capture(app.season)
				_check(
					(
						not proof.is_empty()
						and proof.games[0].players[own].fielded == true
						and not proof.games[0].players.has(enemy)
					),
					"settlement keeps own non-out fielding, excludes opponent"
				)
				var before: Dictionary = SeasonSave.snapshot(app.season)
				var cold: SeasonState = SeasonSave._decode(
					JSON.parse_string(JSON.stringify(before, "", true, true))
				)
				_check(
					(
						cold != null
						and ClubCareer.same(SeasonSave.snapshot(cold), before)
						and cold.career.sync(cold)
						and ClubCareer.same(SeasonSave.snapshot(cold), before)
					),
					"runtime non-out flag cold-restores and sync replay remains exact"
				)
				var restarted: MatchState = app.season.make_match()
				_check(
					restarted.performance.fielding_players.is_empty(),
					"fresh match never inherits prior touch flags"
				)
			else:
				_runtime_bobble(lab)
				var old: Dictionary = state.performance.snapshot(state)
				_check(
					(
						not old.values()[0].has("fielding_v1")
						and state.performance.fielding_players.is_empty()
					),
					"actual legacy/exhibition contact leaves old snapshot schema exact: " + mode
				)
		DirAccess.remove_absolute("user://legend-contact-%s-%d.json" % [mode, OS.get_process_id()])
		app.queue_free()
		await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	SeasonSave.path = prior_path
	var malformed: SeasonState = SeasonState.new()
	malformed.career = ClubCareer.new()
	malformed.career.current = 1
	_check(
		not ClubPlayerLegend.enabled(malformed), "empty malformed career cannot activate collector"
	)


func _runtime_bobble(lab: PitchBatLab) -> void:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 0.4, lab._field_definition.safe_hit_z_m - 0.01)
	launch.velocity = Vector3(0, 0, 20)
	lab._start_ball_in_play(launch)
	lab._apply_fielding_outcome(
		&"primary_fielder", launch.position, FieldingResolver.Outcome.BOBBLE
	)
