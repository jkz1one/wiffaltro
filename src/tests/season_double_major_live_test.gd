extends "res://src/tests/season_match_sales_live_test.gd"

const MajorFixture = preload("res://src/tests/season_double_major_test.gd")
var _forget_item: String
var _sold_major: bool
var _major_target: String
var _major_copy: Dictionary
var _ready_launches: int = 0
var _last_ball: BattedBallBody


func _ready() -> void:
	SeasonSave.path = "user://double-major-live-%d.json" % OS.get_process_id()
	var fixture: Node = MajorFixture.new()
	var original: SeasonState = fixture._paid_major()
	_check(original != null and fixture._failures == 0, "actual paid dual specialist")
	fixture.free()
	if original == null:
		get_tree().quit(1)
		return
	_check(SeasonSave.save(original), "paid snapshot")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for mode: String in ["", SeasonAbilities.HANDS, SeasonAbilities.SKY]:
		_forget_item = mode
		_sold_major = false
		_last_ball = null
		_app = SeasonApp.new()
		_app._continue = Button.new()
		_app.add_child(_app._continue)
		_app.season = SeasonSave._decode(data.duplicate(true))
		_app.loadout = SeasonLoadoutUI.new()
		_app.loadout.match_snapshot = SeasonLoadoutData.capture(_app.season)
		_app._season_game = true
		_app._fixture_id = _app.season.pending_fixture().id
		_major_target = _app.season.build._major.player
		_major_copy = SeasonSchoolSponsors.active(_app.season.build, "F09")
		_before_cash = _app.season.cash()
		_check(SeasonPregameCommit.save(_app), "saved pregame attempt")
		await _run_match(67)
		_check(
			mode == "" or (_sold_major and _app.sales.pending.is_empty()),
			"natural retirement after live sale"
		)
		_app.lab = PitchBatLab.new()
		_app.lab._match_state = _state
		_app.lab._player_home = _app.season.pending_fixture().home == 0
		_check(_app._commit_result(), "completed physical game replays paid/forgotten learning")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null, "physical result and career restore")
		if restored != null:
			_check(
				restored.build._abilities.ids(_major_target).size() == (2 if mode == "" else 1),
				"restart never restores forgotten ability"
			)
		print("DOUBLE_MAJOR_LIVE forget=", mode, " sky_launches=", _ready_launches)
		_app.lab.free()
		_app.lab = null
		_app.loadout.free()
		_app.free()
	_check(_ready_launches > 0, "actual dual specialist uses Sky launch reaction")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Double Major checks passed: paid specialist and safe ability retirement."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _observe_live_frame(lab: PitchBatLab) -> void:
	_app.lab = lab
	_app.sales.apply_pending(_app)
	var own: TeamMatchState = _state.home_team if lab._player_home else _state.away_team
	var player: PlayerDefinition
	for row: PlayerMatchState in own.roster:
		if String(row.definition.id) == _major_target:
			player = row.definition
	if (
		not _sold_major
		and _forget_item != ""
		and lab._pitch_actor.running
		and _state.gear_usage.started
	):
		var request: Dictionary = SeasonMatchSales.command(_app, _major_copy.id)
		var forget: String = ""
		for receipt: Dictionary in _app.season.build._abilities.in_slot(_major_target, "Fielding"):
			if receipt.item == _forget_item:
				forget = receipt.id
		request["major"] = {"player": "", "forget": forget}
		var before: Dictionary = _app.season.build.to_data()
		var path: String = SeasonSave.path
		SeasonSave.path = "user://missing-major-live/season.json"
		_check(not _app.sales.sell(_app, request), "failed live save")
		SeasonSave.path = path
		_check(
			_app.season.build.to_data() == before and player.season_abilities.size() == 2,
			"failed live sale rolls back both layers"
		)
		_check(_app.sales.sell(_app, request), "sale during actual pitch")
		_check(_app.season.cash() == _before_cash + 9, "immediate exact sponsor refund")
		_check(
			player.season_abilities.size() == 2 and lab._pitch_actor.running,
			"both abilities retained through committed PA"
		)
		_check(
			SeasonSave.restore().build._abilities.ids(_major_target).size() == 1,
			"saved ownership already forgot exact ability"
		)
		_sold_major = true
	if _sold_major and _app.sales.pending.is_empty():
		_check(
			not player.season_abilities.has(_forget_item),
			"forgotten effect retires at natural next batter"
		)
		_check(player.season_abilities.size() == 1, "other paid Fielding effect retained")
	if is_instance_valid(lab._batted_ball) and lab._batted_ball != _last_ball:
		_last_ball = lab._batted_ball
		var fielder: FielderController = lab._primary_fielder
		_check(
			(
				fielder._sky_reader
				== _state.fielder().definition.season_abilities.has(SeasonAbilities.SKY)
			),
			"launch uses current saved-boundary ability set"
		)
		if fielder._sky_reader and fielder.reaction_delay_seconds < fielder._base_reaction_delay:
			_ready_launches += 1
			_check(
				is_equal_approx(
					fielder.reaction_delay_seconds, fielder._base_reaction_delay * 0.60
				),
				"actual Sky term"
			)


func _check_outro_and_restart(_lab: PitchBatLab) -> void:
	# Preserve this exact completed match for atomic result/career settlement.
	pass
