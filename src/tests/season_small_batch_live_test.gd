extends "res://src/tests/season_association_live_test.gd"

const BatchFixtures = preload("res://src/tests/season_small_batch_test.gd")
var _uses_at_sale: Array = []
var _discard_used: bool = true


func _ready() -> void:
	for used in [true, false]:
		_discard_used = used
		_sold = false
		await _run_case()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro live Small Batch checks passed: paid supplies, active sale and replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _run_case() -> void:
	SeasonSave.path = "user://batch-live-%d.json" % OS.get_process_id()
	var fixture: Node = BatchFixtures.new()
	_app = SeasonApp.new()
	_app.season = fixture._batch_fixture()
	_check(fixture._failures == 0 and _app.season != null, "paid career and inventory fixture")
	fixture.free()
	if _app.season == null:
		_app.free()
		get_tree().quit(1)
		return
	_association = SeasonSchoolSponsors.active(_app.season.build, "G02").id
	_app.loadout = SeasonLoadoutUI.new()
	_app.loadout.match_snapshot = SeasonLoadoutData.capture(_app.season)
	_app._season_game = true
	_app._fixture_id = _app.season.pending_fixture().id
	_check(SeasonPregameCommit.save(_app), "save three-copy attempt")
	_cash = _app.season.cash()
	await _run_match(67)
	_app.lab = null
	var own: TeamMatchState = (
		_state.home_team if _app.season.pending_fixture().home == 0 else _state.away_team
	)
	_check(_sold and _app.sales.pending.is_empty(), "sold through natural boundary")
	_check(_app.season.cash() == _cash + 6, "exact six Cash refund")
	_check(
		own.tactics.consumed.size() == (3 if _discard_used else 2),
		"three distinct PAs can use three saved supplies"
	)
	var actions: Array = own.tactics.consumed.duplicate(true)
	var bad: Array = actions.duplicate(true)
	bad[0].receipt = "foreign"
	var before: Dictionary = _app.season.build.to_data()
	_check(
		not _app.season.record_player_result(
			_app._fixture_id,
			_state.away_team.runs,
			_state.home_team.runs,
			_state.performance.snapshot(_state),
			_state.gear_usage.first_pitch,
			bad
		),
		"discarded evidence cannot change at settlement"
	)
	_check(_app.season.build.to_data() == before, "bad result rolls back whole reward")
	_check(
		_app.season.record_player_result(
			_app._fixture_id,
			_state.away_team.runs,
			_state.home_team.runs,
			_state.performance.snapshot(_state),
			_state.gear_usage.first_pitch,
			actions
		),
		"physical consumption survives live capacity retirement"
	)
	_check(SeasonSave.save(_app.season), "save physical result")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view().wallet.held.is_empty(),
		"exact three consumptions replay despite two-slot final cap"
	)
	_app.loadout.free()
	_app.free()


func _observe_live_frame(lab: PitchBatLab) -> void:
	_app.lab = lab
	_app.sales.apply_pending(_app)
	var own: TeamMatchState = _state.home_team if lab._player_home else _state.away_team
	if _state.phase == MatchState.Phase.PRE_PITCH and _state.between_batters:
		for copy: Dictionary in own.tactics.held.duplicate(true):
			own.tactics.activate(
				_state, own, copy.id, &"swing.contact" if copy.item == "C03" else &""
			)
	if (
		not _sold
		and not own.tactics.consumed.is_empty()
		and _state.phase == MatchState.Phase.PITCH_IN_FLIGHT
	):
		var command: Dictionary = SeasonMatchSales.command(_app, _association)
		_check(not _app.sales.sell(_app, command), "live removal requires exact excess resolution")
		command["sales"] = []
		command["discard"] = [
			own.tactics.consumed[0].receipt if _discard_used else own.tactics.held[0].id
		]
		command["discarded_use"] = (
			[own.tactics.consumed[0].duplicate(true)] if _discard_used else []
		)
		_uses_at_sale = own.tactics.consumed.duplicate(true)
		var before: Dictionary = _app.season.build.to_data()
		var held: Array = own.tactics.held.duplicate(true)
		var path: String = SeasonSave.path
		SeasonSave.path = path + "/missing/save.json"
		_check(not _app.sales.sell(_app, command), "failed write rejects sale and discard")
		SeasonSave.path = path
		_check(
			(
				_app.season.build.to_data() == before
				and own.tactics.held == held
				and _app.sales.pending.is_empty()
			),
			"failed write preserves wallet inventory and runtime"
		)
		_check(_app.sales.sell(_app, command), "explicit used-copy discard saves during pitch")
		_check(
			_app.sales.pending.size() == 1 and _state.phase == MatchState.Phase.PITCH_IN_FLIGHT,
			"sale does not interrupt play"
		)
		_check(own.tactics.consumed == _uses_at_sale, "consumption is never erased")
		_check(
			_app.loadout.match_snapshot.capacity.held == 3,
			"capacity display retires at safe boundary"
		)
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and restored.build.view().wallet.held.size() == 2,
			"discard persists on restart"
		)
		if restored != null:
			var restart: MatchState = restored.make_match()
			var restarted: TeamMatchState = (
				restart.home_team if restored.pending_fixture().home == 0 else restart.away_team
			)
			_check(
				restarted.tactics.held.size() == 2 and restarted.tactics.consumed.is_empty(),
				"restart has no discarded copy or phantom activation"
			)
		_sold = true
