extends "res://src/tests/season_tactical_live_test.gd"

const Copy = preload("res://src/tests/season_carbon_copy_test.gd")
var _app: SeasonApp
var _mode: String
var _sold: bool
var _chains: int
var _retired: bool


func _ready() -> void:
	SeasonSave.path = "user://copy-live-%d.json" % OS.get_process_id()
	var default_before: String = _default_save_hash()
	var fixture: Node = Copy.new()
	var original: SeasonState = fixture._paid_copy()
	_check(original != null and fixture._failures == 0, "real paid Copy fixture")
	if original == null:
		fixture.free()
		get_tree().quit(1)
		return
	_check(SeasonSave.save(original), "paid fixture checkpoint")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for mode: String in ["deli", "walk", "source_sale", "copy_sale"]:
		_mode = mode
		_sold = false
		_retired = false
		_chains = 0
		_season = SeasonSave._decode(saved.duplicate(true))
		_app = SeasonApp.new()
		_app._continue = Button.new()
		_app.add_child(_app._continue)
		_app.season = _season
		_app._season_game = true
		_app._fixture_id = _season.pending_fixture().id
		_app.copy_game = _app._fixture_id
		_app.copy_receipt = (
			SeasonSchoolSponsors.active(_season.build, "D01" if mode == "walk" else "A07").id
		)
		_app.loadout = SeasonLoadoutUI.new()
		_app.loadout.match_snapshot = SeasonLoadoutData.capture(_season)
		_check(SeasonPregameCommit.save(_app), "save real selected Copy attempt")
		await _run_match(67)
		_check(mode == "walk" or _chains > 0, "physical Deli chain observed")
		_check(
			not mode.ends_with("sale") or (_sold and _retired),
			"sold effect retired at actual PA boundary"
		)
		_app.lab.free()
		_app.lab = PitchBatLab.new()
		_app.lab._match_state = _played_state
		_app.lab._player_home = _season.pending_fixture().home == 0
		var game: int = _app._fixture_id
		var path: String = SeasonSave.path
		var bytes: String = FileAccess.get_file_as_string(path)
		SeasonSave.path = path + "/missing/save.json"
		_check(
			not _app._commit_result() and _app._result_recorded,
			"completed result waits for save retry"
		)
		SeasonSave.path = path
		_check(FileAccess.get_file_as_string(path) == bytes, "failed result write keeps pregame")
		var restarted: SeasonState = SeasonSave.restore()
		_check(restarted != null, "restart replays paid sale and locked choice")
		if restarted != null:
			var target: String = SeasonCarbonCopy.target(restarted.build, game)
			_check(
				target == ("" if _sold else ("D01" if mode == "walk" else "A07")),
				"restart honors exact current ownership"
			)
		_check(_app._commit_result(), "retry actual result commits once")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null, "physical result and career replay")
		var income: Dictionary = _app.season.build.income_for_game(game)
		_check(
			income.get("E09", 0) == (income.get("D01", 0) if mode == "walk" else 0),
			"copied walks follow real capped source income"
		)
		_check(mode != "walk" or income.get("E09", 0) > 0, "real credited walk pays Copy")
		var snapshot: Dictionary = _app.season.build.to_data()
		_check(
			_app._commit_result() and snapshot == _app.season.build.to_data(),
			"continue cannot double pay"
		)
		print("CARBON_COPY_LIVE mode=", mode, " chains=", _chains, " income=", income)
		_app.lab.free()
		_app.lab = null
		_app.loadout.free()
		_app.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	_check(_default_save_hash() == default_before, "isolated live fixture preserves default save")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro live Carbon Copy checks passed: physical chains, walks, sales and retry.")
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	_played_state = state
	_app.lab = PitchBatLab.new()
	_app.lab._match_state = state
	_app.lab._player_home = _season.pending_fixture().home == 0
	state.inventory_boundary.connect(_app.sales.apply_pending.bind(_app))


func _player_home_for_fixture() -> bool:
	# The owned team uses ordinary AI batting, allowing actual fair-hit chains.
	return _season.pending_fixture().home != 0


func _observe_live_frame(lab: PitchBatLab) -> void:
	_app.sales.apply_pending(_app)
	var state: MatchState = lab._match_state
	var own: TeamMatchState = state.home_team if _app.lab._player_home else state.away_team
	if _sold and _app.sales.pending.is_empty():
		_retired = true
	if state.batting_team() != own or not SeasonSponsorEffects.deli_active(state):
		return
	_chains += 1
	if _mode == "walk":
		_check(
			is_equal_approx(SeasonCarbonCopy.deli_bonus(state), 0.04),
			"walk selection never copies Deli"
		)
		return
	var expected: float = 0.04 if _retired and _mode == "copy_sale" else 0.0816
	_check(
		is_equal_approx(SeasonCarbonCopy.deli_bonus(state), expected),
		"physical pair uses same Single chain"
	)
	if not _mode.ends_with("sale") or _sold or state.phase != MatchState.Phase.PITCH_IN_FLIGHT:
		return
	var id: String = "A07" if _mode == "source_sale" else "E09"
	var receipt: Dictionary = SeasonSchoolSponsors.active(_app.season.build, id)
	var command: Dictionary = SeasonMatchSales.command(_app, receipt.id)
	var before: Dictionary = _app.season.build.to_data()
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	_check(not _app.sales.sell(_app, command), "failed live sale")
	SeasonSave.path = path
	_check(
		_app.season.build.to_data() == before and _app.sales.pending.is_empty(),
		"sale failure rollback"
	)
	var cash: int = _app.season.cash()
	_check(_app.sales.sell(_app, command), "save exact live pair sale")
	_check(_app.season.cash() == cash + int(receipt.paid) / 2, "exact immediate refund")
	_check(
		is_equal_approx(SeasonCarbonCopy.deli_bonus(state), 0.0816),
		"committed PA retains copied effect"
	)
	_check(not _app.sales.sell(_app, command), "no duplicate refund")
	_sold = true


func _default_save_hash() -> String:
	var path: String = "user://season-v1.json"
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
