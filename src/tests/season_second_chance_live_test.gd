extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_second_chance_test.gd")
var _app: SeasonApp
var _state: MatchState
var _sold: bool = false
var _marked: String
var _sponsor: String


func _ready() -> void:
	SeasonSave.path = "user://insurance-live-%d.json" % OS.get_process_id()
	var fixture: Node = Fixtures.new()
	_app = SeasonApp.new()
	_app.season = fixture._insurance_fixture()
	_check(fixture._failures == 0 and _app.season != null, "earned and paid live fixture")
	fixture.free()
	if _app.season == null:
		_app.free()
		get_tree().quit(1)
		return
	_app.loadout = SeasonLoadoutUI.new()
	_app.loadout.match_snapshot = SeasonLoadoutData.capture(_app.season)
	_app._season_game = true
	_app._fixture_id = _app.season.pending_fixture().id
	_marked = _app.season.build.view().wallet.held[0].id
	_sponsor = SeasonSchoolSponsors.active(_app.season.build, "E04").id
	_app.insurance_game = _app._fixture_id
	_app.insurance_receipt = _marked
	_check(SeasonPregameCommit.save(_app), "mark and inventory saved before live game")
	await _run_match(67)
	_app.lab = null
	_check(_sold and _app.sales.pending.is_empty(), "sale retired at natural PA boundary")
	var team: TeamMatchState = _state.home_team
	_check(not team.roster[0].definition.season_sponsors.has("E04"), "own sponsor effect retired")
	_check(team.tactics.consumed.size() == 2, "both real paid supplies consumed")
	var claims: int = 0
	for action: Dictionary in team.tactics.consumed:
		claims += int(action.get("insured", false))
	_check(claims == 1, "exactly one real insured copy")
	var saved_before: Dictionary = _app.season.build.view()
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	_app.lab = PitchBatLab.new()
	_app.lab._match_state = _state
	_app.lab._player_home = true
	_app._continue = Button.new()
	SeasonSave.path = path + "/missing/save.json"
	_check(
		not _app._commit_result() and _app._result_recorded,
		"failed result save leaves one retryable restoration"
	)
	SeasonSave.path = path
	_check(
		(
			FileAccess.get_file_as_string(path) == bytes
			and SeasonSave.restore().build.view() == saved_before
		),
		"failed write preserves complete saved match attempt"
	)
	var settled: Dictionary = _app.season.build.view()
	_check(
		(
			settled.wallet.held.size() == 1
			and settled.wallet.held[0].item == "C03"
			and settled.wallet.held[0].paid == 0
			and settled.wallet.held[0].id != _marked
		),
		"one fresh Plan after completed use, despite later sale"
	)
	_check(settled.wallet.sponsors.is_empty(), "no sponsor resurrection")
	_check(
		_app._commit_result() and _app.season.build.view() == settled,
		"retry saves without paying or restoring twice"
	)
	_check(
		_app._commit_result() and _app.season.build.view() == settled,
		"repeated Continue stays idempotent"
	)
	_app.lab.free()
	_app.lab = null
	_app._continue.free()
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == settled, "live sale and claim replay once")
	_check(
		(
			not _app.season.record_player_result(
				_app._fixture_id,
				_state.away_team.runs,
				_state.home_team.runs,
				_state.performance.snapshot(_state),
				[],
				team.tactics.consumed
			)
			and _app.season.build.view() == settled
		),
		"repeated completed result cannot mint another copy"
	)
	_app.loadout.free()
	_app.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro live Second Chance checks passed: "
				+ "physical consumption, sale, retirement and restoration."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _app.season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_state = state
	_check(_app.season.pending_fixture().home == 0, "paid home fixture")
	state.inventory_boundary.connect(_retire_for_owner)


func _player_home_for_fixture() -> bool:
	# Home club bats using the actual AI Contact-plan hooks.
	return false


func _observe_live_frame(lab: PitchBatLab) -> void:
	_app.lab = lab
	# Sales authority belongs to the paid home club; restore the driver role afterward.
	lab._player_home = true
	_app.sales.apply_pending(_app)
	var team: TeamMatchState = _state.home_team
	if team.tactics.consumed.is_empty():
		var rows: Dictionary = SeasonLoadoutData.pages(_app)
		_check(
			rows.supplies.any(
				func(row: Dictionary) -> bool: return row.label.contains("Insured this game")
			),
			"equipped menu identifies insured copy"
		)
	if _state.phase == MatchState.Phase.PRE_PITCH and _state.between_batters:
		for copy: Dictionary in team.tactics.held.duplicate(true):
			team.tactics.activate(
				_state, team, copy.id, &"swing.contact" if copy.item == "C03" else &""
			)
	if (
		not _sold
		and team.tactics.active(_state) == "C03"
		and lab._swing_tracker != null
		and lab._swing_tracker.active
	):
		_check(
			_app.sales.sell(_app, SeasonMatchSales.command(_app, _sponsor)),
			"sell insurance during actual insured swing"
		)
		_check(
			team.roster[0].definition.season_sponsors.get("E04", false),
			"in-flight PA retains sponsor snapshot"
		)
		var rows: Dictionary = SeasonLoadoutData.pages(_app)
		_check(
			_has_label(rows.used, "Replacement after completion"),
			"equipped menu keeps consumed insurance claim visible"
		)
		_sold = true
	lab._player_home = false


func _retire_for_owner() -> void:
	if not is_instance_valid(_app.lab):
		return
	var role: bool = _app.lab._player_home
	_app.lab._player_home = true
	_app.sales.apply_pending(_app)
	_app.lab._player_home = role


func _has_label(rows: Array, text: String) -> bool:
	for row: Dictionary in rows:
		if row.label.contains(text):
			return true
	return false
