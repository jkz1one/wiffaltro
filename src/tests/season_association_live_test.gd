extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_association_test.gd")
var _app: SeasonApp
var _state: MatchState
var _sold: bool = false
var _association: String
var _optics: String
var _cash: int


func _ready() -> void:
	SeasonSave.path = "user://association-live-%d.json" % OS.get_process_id()
	var fixture: Node = Fixtures.new()
	_app = SeasonApp.new()
	_app.season = fixture._paid_association()
	_check(fixture._failures == 0 and _app.season != null, "generated paid association fixture")
	fixture.free()
	if _app.season == null:
		_app.free()
		get_tree().quit(1)
		return
	_association = SeasonSchoolSponsors.active(_app.season.build, "J05").id
	_optics = SeasonSchoolSponsors.active(_app.season.build, "F03").id
	_app.loadout = SeasonLoadoutUI.new()
	_app.loadout.match_snapshot = SeasonLoadoutData.capture(_app.season)
	_app._season_game = true
	_app._fixture_id = _app.season.pending_fixture().id
	_check(SeasonPregameCommit.save(_app), "save inventory before physical game")
	_cash = _app.season.cash()
	await _run_match(67)
	_app.lab = null
	_check(_sold and _app.sales.pending.is_empty(), "group sold and retired at natural boundary")
	_check(_app.season.cash() == _cash + 12, "only exact two refunds")
	_check(_app.season.build.view().wallet.sponsors.size() == 5, "five still owned")
	_check(
		_app.season.record_player_result(
			_app._fixture_id,
			_state.away_team.runs,
			_state.home_team.runs,
			_state.performance.snapshot(_state),
			_state.gear_usage.first_pitch
		),
		"completed physical game accepts grouped sponsor sales"
	)
	_check(SeasonSave.save(_app.season), "physical result saves")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view().wallet.sponsors.size() == 5,
		"reload retains sales"
	)
	_check(restored != null and SeasonAssociation.access(restored.career), "earned access persists")
	_app.loadout.free()
	_app.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Association checks passed: paid capacity, grouped swing sale and boundary."
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
	if not _sold and lab._swing_tracker != null and lab._swing_tracker.active:
		var command: Dictionary = SeasonMatchSales.command(_app, _association)
		_check(not _app.sales.sell(_app, command), "unresolved live sale rejected")
		command["sales"] = [_optics]
		var before: Dictionary = _app.season.build.to_data()
		var path: String = SeasonSave.path
		SeasonSave.path = path + "/missing/save.json"
		_check(not _app.sales.sell(_app, command), "failed live save rejected")
		SeasonSave.path = path
		_check(
			_app.season.build.to_data() == before and _app.sales.pending.is_empty(),
			"failed save retains both owned copies and effects"
		)
		_check(_app.sales.sell(_app, command), "retry saves whole group during actual swing")
		_check(
			own.roster[0].definition.season_sponsors.get("F03", false),
			"Optics remains through active PA"
		)
		_check(
			_app.sales.pending.size() == 2 and lab._swing_tracker.active,
			"both queued without interrupting swing"
		)
		_check(
			_app.loadout.match_snapshot.capacity.sponsors == 7,
			"active snapshot retains old capacity until boundary"
		)
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and restored.build.view().wallet.capacity.sponsors == 5,
			"saved ownership immediately reflects legal five"
		)
		_check(not _app.sales.sell(_app, command), "duplicate confirmation cannot refund again")
		_sold = true
	if _sold and _app.sales.pending.is_empty():
		_check(
			not own.roster[0].definition.season_sponsors.get("F03", false),
			"sold Common effect retires naturally"
		)
		_check(
			_app.loadout.match_snapshot.capacity.sponsors == 5,
			"equipped snapshot retires capacity with group"
		)
