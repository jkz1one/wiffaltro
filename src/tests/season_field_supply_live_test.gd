extends "res://src/tests/season_tactical_live_test.gd"

const Field = preload("res://src/tests/season_field_supply_test.gd")
var _app: SeasonApp
var _mode: String
var _sold: bool
var _activated: bool


func _ready() -> void:
	var fixture: Node = Field.new()
	for mode: String in ["hold", "use", "sale", "away"]:
		_mode = mode
		_sold = false
		_activated = false
		_season = fixture._paid_field(true, mode != "away")
		_check(fixture._failures == 0, "real paid Field Supply fixture")
		SeasonSave.path = "user://field-live-%s-%d.json" % [mode, OS.get_process_id()]
		_app = SeasonApp.new()
		_app._continue = Button.new()
		_app.add_child(_app._continue)
		_app.season = _season
		_app._season_game = true
		_app._fixture_id = _season.pending_fixture().id
		_app.loadout = SeasonLoadoutUI.new()
		_app.loadout.match_snapshot = SeasonLoadoutData.capture(_season)
		_check(SeasonPregameCommit.save(_app), "save real inventory attempt")
		await _run_match(67)
		var own: TeamMatchState = (
			_played_state.home_team
			if _season.pending_fixture().home == 0
			else _played_state.away_team
		)
		var evidence: Dictionary = own.field_supply.evidence()
		if mode == "away":
			_check(
				own.field_supply.clean == 2 and evidence.is_empty(),
				"two actual away clean outs do not generate Tape"
			)
		else:
			_check(
				_sold if mode == "sale" else evidence.get("outcome") == "granted",
				"physical grant or prospective retirement"
			)
		_check(mode != "use" or _activated, "generated Tape actually activated")
		_check(not _activated or own.tactics.consumed.size() == 1, "generated Tape consumes once")
		_app.lab.free()
		_app.lab = PitchBatLab.new()
		_app.lab._match_state = _played_state
		_app.lab._player_home = _season.pending_fixture().home == 0
		# A failed write keeps the old save, then exactly one result can be retried.
		var path: String = SeasonSave.path
		var bytes: String = FileAccess.get_file_as_string(path)
		SeasonSave.path = path + "/missing/save.json"
		_check(
			not _app._commit_result() and _app._result_recorded,
			"completed result pending save retry"
		)
		SeasonSave.path = path
		_check(FileAccess.get_file_as_string(path) == bytes, "failed write keeps pregame bytes")
		var restarted: SeasonState = SeasonSave.restore()
		var restart_state: MatchState = restarted.make_match()
		var restarted_own: TeamMatchState = (
			restart_state.home_team
			if restarted.pending_fixture().home == 0
			else restart_state.away_team
		)
		_check(
			restarted_own.field_supply.clean == 0 and restarted_own.tactics.held.is_empty(),
			"restart resets counter and generated copy together"
		)
		_check(_app._commit_result(), "retry commits actual fielding and Tape")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null, "physical result and career rebuild")
		if restored != null:
			var expected: int = 1 if evidence.get("outcome") == "granted" and not _activated else 0
			_check(
				restored.build.view().wallet.held.size() == expected,
				"unused earned Tape persists exactly once"
			)
		var snapshot: Dictionary = _app.season.build.to_data()
		_check(
			_app._commit_result() and _app.season.build.to_data() == snapshot,
			"continue cannot regenerate"
		)
		print(
			"FIELD_SUPPLY_LIVE mode=",
			mode,
			" clean=",
			own.field_supply.clean,
			" delivery=",
			evidence,
			" used=",
			_activated
		)
		_app.lab.free()
		_app.lab = null
		_app.loadout.free()
		_app.free()
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Field Supply checks passed: physical outs, generated Tape, sales and save retry."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	_played_state = state
	_app.lab = PitchBatLab.new()
	_app.lab._match_state = state
	_app.lab._player_home = _season.pending_fixture().home == 0
	state.inventory_boundary.connect(_app.sales.apply_pending.bind(_app))


func _player_home_for_fixture() -> bool:
	return _season.pending_fixture().home == 0


func _observe_live_frame(lab: PitchBatLab) -> void:
	_app.sales.apply_pending(_app)
	var state: MatchState = lab._match_state
	var own: TeamMatchState = state.home_team if _app.lab._player_home else state.away_team
	if _mode == "use" and state.phase == MatchState.Phase.PRE_PITCH and state.between_batters:
		for copy: Dictionary in own.tactics.held.duplicate(true):
			_activated = own.tactics.activate(state, own, copy.id) or _activated
	if (
		_mode != "sale"
		or _sold
		or own.field_supply.clean != 2
		or state.phase != MatchState.Phase.PITCH_IN_FLIGHT
	):
		return
	var copy: Dictionary = SeasonSchoolSponsors.active(_app.season.build, "B01")
	var command: Dictionary = SeasonMatchSales.command(_app, copy.id)
	var original: Dictionary = _app.season.build.to_data()
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	_check(not _app.sales.sell(_app, command), "failed live sale")
	SeasonSave.path = path
	_check(
		_app.season.build.to_data() == original and _app.sales.pending.is_empty(),
		"failed sale atomic rollback"
	)
	_check(_app.sales.sell(_app, command), "saved B01 sale")
	_check(not _app.sales.pending.is_empty(), "modifier survives current PA")
	_check(not _app.sales.sell(_app, command), "sale cannot refund twice")
	_sold = true
