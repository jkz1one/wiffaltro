extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_late_checkout_test.gd")
var _season: SeasonState
var _state: MatchState
var _accepted: bool = false
var _observed: bool = false
var _sold: bool = false
var _app: SeasonApp


func _ready() -> void:
	SeasonSave.path = "user://checkout-live-%d.json" % OS.get_process_id()
	var fixture: Node = Fixtures.new()
	var club: ClubCareer = fixture._earn_checkout()
	_season = fixture._paid_checkout(club)
	_check(fixture._failures == 0 and _season != null, "paid generated live fixture")
	fixture.free()
	if _season == null:
		get_tree().quit(1)
		return
	_app = SeasonApp.new()
	_app.season = _season
	_app._fixture_id = _season.pending_fixture().id
	_app._season_game = true
	_app.loadout = SeasonLoadoutUI.new()
	_app.loadout.match_snapshot = SeasonLoadoutData.capture(_season)
	_check(SeasonPregameCommit.save(_app), "saved paid match attempt")
	var game: Dictionary = _season.pending_fixture()
	await _run_match(67)
	_app.lab = null
	_check(
		_accepted and _observed and _sold, "inherited Plan reached physical AI swing and live sale"
	)
	var team: TeamMatchState = _state.home_team
	_check(
		team.tactics.consumed.size() == 1 and team.tactics.held.is_empty(), "one original copy only"
	)
	_check(team.tactics.consumed[0].walked, "original supplied walk evidence")
	_check(
		not team.roster[0].definition.season_sponsors.has("G03"), "sale retired for later batters"
	)
	var before: Dictionary = _season.build.view()
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	_app.lab = PitchBatLab.new()
	_app.lab._match_state = _state
	_app.lab._player_home = true
	_app._continue = Button.new()
	SeasonSave.path = path + "/missing/save.json"
	_check(
		not _app._commit_result() and _app._result_recorded, "completed result remains retryable"
	)
	SeasonSave.path = path
	_check(
		(
			FileAccess.get_file_as_string(path) == bytes
			and SeasonSave.restore().build.view() == before
		),
		"failed write preserves saved attempt"
	)
	var after: Dictionary = _season.build.view()
	_check(
		after.wallet.held.is_empty() and after.wallet.sponsors.is_empty(),
		"no copy or sponsor resurrection"
	)
	_check(_app._commit_result() and _season.build.view() == after, "retry settles once")
	_check(
		_app._commit_result() and _season.build.view() == after,
		"duplicate Continue remains idempotent"
	)
	var loaded: SeasonState = SeasonSave.restore()
	_check(loaded != null and loaded.build.view() == after, "sale, consumption and access replay")
	_check(
		not _season.record_player_result(
			game.id,
			_state.away_team.runs,
			_state.home_team.runs,
			_state.performance.snapshot(_state),
			[],
			team.tactics.consumed
		),
		"no duplicate completed result"
	)
	_app.lab.free()
	_app._continue.free()
	_app.loadout.free()
	_app.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Late Checkout checks passed: controlled walk, physical effect, sale and replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_state = state
	_check(_season.pending_fixture().home == 0, "paid club is home")
	state.top_half = false
	var team: TeamMatchState = state.home_team
	_check(
		team.tactics.activate(state, team, team.tactics.held[0].id, &"swing.contact"),
		"paid Plan activated"
	)
	# Controlled called-walk trigger; the following game exercises physical pitching/batting.
	for pitch in range(MatchState.BALLS_FOR_WALK):
		state.record_ball()
	state.phase = MatchState.Phase.PRE_PITCH
	state.inventory_boundary.connect(_retire_for_owner)


func _player_home_for_fixture() -> bool:
	return false


func _observe_live_frame(lab: PitchBatLab) -> void:
	_app.lab = lab
	lab._player_home = true
	_app.sales.apply_pending(_app)
	var team: TeamMatchState = _state.home_team
	if not _accepted and not team.tactics.checkout.options(_state, team).is_empty():
		_accepted = team.tactics.checkout.accept(_state, team, "C03")
		lab._refresh_config()
		var rows: Dictionary = SeasonLoadoutData.pages(_app)
		_check(
			rows.used.size() == 1 and rows.used[0].label.contains("Inherited this PA"),
			"equipped inherited status"
		)
	if (
		team.tactics.checkout.inherited_pa == _state.plate_appearance_number
		and lab._swing_tracker != null
		and lab._swing_tracker.active
	):
		_observed = true
		_check(
			(
				lab._swing_tracker.profile.id == &"swing.contact"
				and is_equal_approx(lab._swing_tracker.profile.tactical_quality_exit_scale, 1.06)
			),
			"physical profile receives inherited Plan"
		)
		if not _sold:
			var sponsor: Dictionary = SeasonSchoolSponsors.active(_season.build, "G03")
			_check(
				_app.sales.sell(_app, SeasonMatchSales.command(_app, sponsor.id)),
				"sell during inherited swing"
			)
			_check(team.tactics.active(_state) == "C03", "sale preserves active inherited PA")
			_sold = true
	lab._player_home = false


func _retire_for_owner() -> void:
	if not is_instance_valid(_app.lab):
		return
	var role: bool = _app.lab._player_home
	_app.lab._player_home = true
	_app.sales.apply_pending(_app)
	_app.lab._player_home = role
