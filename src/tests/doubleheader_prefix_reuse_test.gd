extends "res://src/tests/league_doubleheader_projection_test.gd"
## Frozen qualified helper oracle; real retained evidence, no invented paid results.
const PrefixOracle = preload("res://src/tests/doubleheader_prefix_oracle.gd")


func _ready() -> void:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--input="):
			path = argument.trim_prefix("--input=")
	var raw: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(raw)
	var source: SeasonState = SeasonSave._decode(data)
	check(source != null, "actual long Doubleheader source decodes")
	if source == null:
		get_tree().quit(1)
		return
	var before: Dictionary = SeasonSave.snapshot(source).duplicate(true)
	var full: SeasonBuild = source.build
	var first_count: int = 0
	var second_count: int = 0
	for row: Dictionary in source.player_results:
		if int(row.get("round", 10)) >= 10:
			continue
		var game: int = int(row.id)
		var scope: SeasonState = SeasonRoundSettlement._fork_replayed_league(source)
		check(scope != null, "detached input")
		if scope == null:
			continue
		scope.phase = SeasonState.Phase.REGULAR
		scope.round_index = int(row.round)
		scope._doubleheader_replay_build = full
		var prefix: SeasonBuild = SeasonBuildRestore.restore(
			full.to_data(), full._seed, full._initial_roster, full._pool, full._blocked, game
		)
		check(prefix != null, "full journal prefix restores for " + str(game))
		if prefix == null:
			continue
		scope.build = prefix
		var prefix_before: Dictionary = _input_snapshot(prefix)
		var old_context: Dictionary = PrefixOracle._prefix(scope, 0, game)
		var new_context: Dictionary = SeasonDoubleheader._prefix(scope, 0, game, prefix)
		check(
			not old_context.is_empty() and not new_context.is_empty(),
			"both context paths admit " + str(game)
		)
		check(_exact(old_context, new_context), "all context/resource fields equal " + str(game))
		var old_team: Dictionary = PrefixOracle._historical_team(scope, 0, game)
		var new_team: Dictionary = SeasonDoubleheader._historical_team(scope, 0, game, prefix)
		check(
			not old_team.is_empty() and not new_team.is_empty(),
			"both historical teams admit " + str(game)
		)
		if not old_team.is_empty() and not new_team.is_empty():
			check(
				_team_values(old_team) == _team_values(new_team),
				"exact team/workload parity " + str(game)
			)
		check(
			_exact(prefix_before, _input_snapshot(prefix)), "reused prefix unchanged " + str(game)
		)
		check(
			SeasonDoubleheader._prefix(scope, 0, game + 1, prefix).is_empty(),
			"different game rejects"
		)
		check(
			SeasonDoubleheader._prefix(scope, 0, game, prefix._fork()).is_empty(),
			"different object rejects"
		)
		var held_seed: int = prefix._seed
		prefix._seed += 1
		check(
			SeasonDoubleheader._prefix(scope, 0, game, prefix).is_empty(), "different seed rejects"
		)
		prefix._seed = held_seed
		_replay_admission(scope, row, prefix, full)
		scope._doubleheader_replay_build = null
		check(
			SeasonDoubleheader._prefix(scope, 0, game, prefix).is_empty(),
			"ordinary nonreplay context rejects prefix"
		)
		if SeasonDoubleheaderRules.first(game) >= 0:
			second_count += 1
		else:
			first_count += 1
	check(first_count > 0 and second_count > 0, "both first and second halves covered")
	check(ClubCareer.same(before, SeasonSave.snapshot(source)), "actual source unchanged")
	check(FileAccess.get_file_as_string(path) == raw, "fixture bytes unchanged")
	_tamper_halves(data)
	print(
		(
			"PREFIX_REUSE_RESULT checks=%d failures=%d first=%d second=%d"
			% [checks, failures, first_count, second_count]
		)
	)
	get_tree().quit(0 if failures == 0 else 1)


func _replay_admission(
	scope: SeasonState, row: Dictionary, prefix: SeasonBuild, full: SeasonBuild
) -> void:
	var game: int = int(row.id)
	var opponent: int = int(row.away if row.home == 0 else row.home)
	var ai: Dictionary = row.ai_tactics.get(str(opponent), {})
	var forged: SeasonBuild = prefix._fork()
	forged._bank._state.cash += 777
	scope.build = forged
	scope._doubleheader_replay_build = full
	scope.physical.projecting = true
	var bad: Array = row.doubleheader_evidence.duplicate(true)
	var human_side: int = 0 if row.away == 0 else 1
	var initial: Dictionary = bad[human_side].proof.initial
	initial[initial.keys()[0]].capacity += 1.0
	check(
		not PrefixOracle.accepts(
			scope, row, bad, row.performance, row.get("pitching", {}), row.get("tactics", []), ai
		),
		"old public accepts rejects forged workload"
	)
	check(
		not SeasonDoubleheader.accepts(
			scope, row, bad, row.performance, row.get("pitching", {}), row.get("tactics", []), ai
		),
		"ordinary accepts still rejects forged workload"
	)
	var args: Array = [
		game,
		int(row.away_runs),
		int(row.home_runs),
		row.performance,
		row.get("used_gear", []),
		row.get("tactics", []),
		row.get("batting", {}),
		row.get("stances", []),
		row.get("fielding", []),
		row.get("pitching", {}),
		row.get("field_supply", {}),
		row.get("frozen", []),
		ai,
		[],
		"",
		null,
		null,
		null,
		bad,
		{},
		null,
		false
	]
	check(not scope.callv("_record_player_result", args), "ordinary record rejects forged workload")
	scope.build = forged
	args[-1] = true
	check(not scope.callv("_record_player_result", args), "replay mode rejects forged workload")
	check(
		scope.build != forged and _exact(_input_snapshot(scope.build), _input_snapshot(prefix)),
		"replay mode rebuilds journal authority rather than trusting forged backing"
	)
	var corrupt_full: SeasonBuild = full._fork()
	corrupt_full._events.insert(0, {"op": "invented"})
	scope._doubleheader_replay_build = corrupt_full
	scope.build = forged
	check(
		not scope.callv("_record_player_result", args) and scope.build == forged,
		"replay mode rejects corrupt full journal before installing any prefix"
	)
	scope._doubleheader_replay_build = full
	scope.build = prefix


func _team_values(value: Dictionary) -> String:
	var team: TeamMatchState = value.team
	var players: Array = []
	for player: PlayerMatchState in team.roster:
		players.append(
			{
				"definition": _serialized(player.definition),
				"max": player.stamina_max,
				"remaining": player.stamina_remaining
			}
		)
	return JSON.stringify(
		{
			"players": players,
			"rules": team.league_rules,
			"ownership": team.league_ownership,
			"pair": team.league_pair,
			"refund": value.refund_through,
			"cost": _serialized(value.cost_context)
		},
		"",
		true,
		true
	)


func _tamper_halves(data: Dictionary) -> void:
	for second: bool in [false, true]:
		var changed: Dictionary = data.duplicate(true)
		var body: Dictionary = changed
		while body.has("checkpoint"):
			body = body.checkpoint
		var found: bool = false
		for row: Dictionary in body.results:
			if (SeasonDoubleheaderRules.first(int(row.id)) >= 0) == second:
				row.doubleheader_evidence[0].pair.game += 1
				found = true
				break
		check(found, "retained half available for tamper")
		check(SeasonSave._decode(changed) == null, "tampered half evidence rejects " + str(second))
