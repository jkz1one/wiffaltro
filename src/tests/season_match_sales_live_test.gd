extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_gear_progress_test.gd")
var _app: SeasonApp
var _state: MatchState
var _sold_pitch: bool = false
var _sold_swing: bool = false
var _before_cash: int
var _copies: Dictionary


func _ready() -> void:
	SeasonSave.path = "user://match-sales-live-%d.json" % OS.get_process_id()
	var fixture: Node = Fixtures.new()
	_app = SeasonApp.new()
	_app.season = fixture._paid_pair(Fixtures.BASE_PAIR)
	_check(fixture._failures == 0, "paid career Gear through real stock")
	fixture.free()
	_app.loadout = SeasonLoadoutUI.new()
	_app.loadout.match_snapshot = SeasonLoadoutData.capture(_app.season)
	_app._season_game = true
	_app._fixture_id = _app.season.pending_fixture().id
	_check(SeasonPregameCommit.save(_app), "save inventory attempt before play")
	_before_cash = _app.season.cash()
	_copies = _app.season.build.view().wallet.gear.duplicate(true)
	await _run_match(67)
	_app.lab = null
	_check(_sold_pitch and _sold_swing, "both actual pitch and swing sales executed")
	_check(_app.sales.pending.is_empty(), "both effects retired at natural PA boundaries")
	var refund: int = int(_copies.bat.paid / 2) + int(_copies.ball.paid / 2)
	_check(_app.season.cash() == _before_cash + refund, "physical game retains exact refunds")
	_check(
		_app.season.record_player_result(
			_app._fixture_id,
			_state.away_team.runs,
			_state.home_team.runs,
			_state.performance.snapshot(_state),
			_state.gear_usage.first_pitch
		),
		"physical completed result accepts sold first-release copies"
	)
	_check(SeasonSave.save(_app.season), "save physical result with earned use")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null, "physical sale/result history replays")
	if restored != null:
		for id: String in Fixtures.BASE_PAIR:
			_check(
				(
					restored.career.gear_counts().get(id, 0) == 1
					and ClubCollection.discoveries(restored.career).has(id)
				),
				"sold paid copy earns exactly one completed use"
			)
		_check(
			(
				restored.build.view().wallet.gear.bat.is_empty()
				and restored.build.view().wallet.gear.ball.is_empty()
			),
			"reload does not resurrect Gear"
		)
		_check(
			restored.build._used_gear.is_empty(), "sold copies cannot acquire reclamation credit"
		)
	_app.loadout.free()
	_app.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live match sales checks passed: pitch, swing, natural boundaries and earned use."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _app.season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_state = state
	state.inventory_boundary.connect(_app.sales.apply_pending.bind(_app))


func _player_home_for_fixture() -> bool:
	return _app.season.pending_fixture().home == 0


func _observe_live_frame(lab: PitchBatLab) -> void:
	_app.lab = lab
	_app.sales.apply_pending(_app)
	var own: TeamMatchState = _state.home_team if lab._player_home else _state.away_team
	if not _sold_pitch and lab._pitch_actor.running and _state.gear_usage.started:
		var elapsed: float = lab._pitch_actor.state.elapsed_time
		_check(
			_app.sales.sell(_app, SeasonMatchSales.command(_app, _copies.ball.id)),
			"sale saves during actual pitch flight"
		)
		_check(
			lab._pitch_actor.running and lab._pitch_actor.state.elapsed_time == elapsed,
			"sale never resets in-flight actor"
		)
		_check(
			own.roster[0].definition.season_gear.ball == _copies.ball.item,
			"ball effect survives active pitch"
		)
		_sold_pitch = true
	if not _sold_swing and lab._swing_tracker != null and lab._swing_tracker.active:
		_check(
			_app.sales.sell(_app, SeasonMatchSales.command(_app, _copies.bat.id)),
			"sale saves during an actual swing"
		)
		_check(
			(
				lab._swing_tracker.active
				and own.roster[0].definition.season_gear.bat == _copies.bat.item
			),
			"active swing and paid bat remain until PA ends"
		)
		_sold_swing = true
	if _sold_pitch and not _app.sales.pending.has(_copies.ball.id):
		_check(not own.roster[0].definition.season_gear.has("ball"), "ball retires naturally")
	if _sold_swing and not _app.sales.pending.has(_copies.bat.id):
		_check(not own.roster[0].definition.season_gear.has("bat"), "bat retires naturally")
