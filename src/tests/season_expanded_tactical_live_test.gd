extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_expanded_tactical_test.gd")
var _season: SeasonState
var _played_state: MatchState
var _with_base: bool = false
var _heat_throws: int = 0
var _last_throw: int = -1


func _ready() -> void:
	var fixture: Node = Fixtures.new()
	for with_base: bool in [false, true]:
		_with_base = with_base
		_heat_throws = 0
		_last_throw = -1
		var ids: Array = [SeasonTacticalCatalog.HEAT]
		if with_base:
			ids.append(SeasonTacticalCatalog.BASE)
		_season = fixture._paid_tactics(ids)
		_check(_season != null and fixture._failures == 0, "actual generated expanded stock")
		if _season == null:
			break
		for id: String in ids:
			_check(
				(
					_season
					. build
					. commit(
						fixture._command(
							_season.build,
							"tactical_buy",
							{"offer": fixture._offer(_season.build, id)}
						)
					)
					. ok
				),
				"pay full quoted supply price"
			)
		SeasonSave.path = "user://expanded-live-%s-%d.json" % [str(with_base), OS.get_process_id()]
		_check(SeasonSave.save(_season), "save full pregame supply inventory")
		var game: Dictionary = _season.pending_fixture()
		_check(game.home == 0, "paid home club")
		await _run_match(67)
		var consumed: Array = _played_state.home_team.tactics.consumed
		_check(
			consumed.size() == ids.size() and _heat_throws > 0,
			"all paid cards used during physical game"
		)
		var stats: Dictionary = _played_state.performance.snapshot(_played_state)
		var driven_runs: int = 0
		for line: Dictionary in stats.values():
			driven_runs += int(line.rbi)
		var supply_runs: int = 0
		for action: Dictionary in consumed:
			if action.get("advance", {}).get("to", 0) == 4:
				supply_runs += 1
		_check(
			(
				driven_runs + supply_runs
				== _played_state.home_team.runs + _played_state.away_team.runs
			),
			"consumable runs separate from ordinary RBI"
		)
		_check(
			_season.record_player_result(
				game.id,
				_played_state.away_team.runs,
				_played_state.home_team.runs,
				stats,
				[],
				consumed
			),
			"completed physical game settles expanded ledger"
		)
		_check(SeasonSave.save(_season), "save completed physical expanded game")
		var restored: SeasonState = SeasonSave.restore()
		_check(
			(
				restored != null
				and restored.build.view() == _season.build.view()
				and restored.build.view().wallet.held.is_empty()
			),
			"expanded consumption replays exactly"
		)
		print(
			"EXPANDED_LIVE with_base=",
			with_base,
			" heated_throws=",
			_heat_throws,
			" consumable_runs=",
			supply_runs
		)
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro live expanded tactical checks passed: "
				+ "paid Heat/Base, physical games and separate scoring."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_played_state = state


func _player_home_for_fixture() -> bool:
	# First game has actual AI batting against paid Heat; second has AI batting
	# for the paid club to produce natural Base opportunities. No AI buying policy.
	return not _with_base


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.home_team
	if state.phase == MatchState.Phase.PRE_PITCH and state.between_batters:
		for copy: Dictionary in team.tactics.held.duplicate(true):
			if copy.item == SeasonTacticalCatalog.BASE:
				# Use a naturally occupied third when available; otherwise any legal
				# trailing runner. The card never invents its own occupancy.
				var before: Dictionary = state.performance.snapshot(state)
				var pa: int = state.plate_appearance_number
				if team.tactics.activate(state, team, copy.id):
					_check(
						(
							state.performance.snapshot(state) == before
							and state.plate_appearance_number == pa
						),
						"actual Base use leaves batting statistics/PA untouched"
					)
			else:
				team.tactics.activate(state, team, copy.id)
	if (
		state.phase == MatchState.Phase.PITCH_IN_FLIGHT
		and team.tactics.active(state) == SeasonTacticalCatalog.HEAT
		and lab._throw_number != _last_throw
	):
		_last_throw = lab._throw_number
		_heat_throws += 1
		_check(
			lab._last_executed_release_speed_mps > 0 and lab._last_expected_plate_speed_mps > 0,
			"live heated pitch has physical telemetry"
		)
