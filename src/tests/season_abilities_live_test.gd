extends "res://src/tests/season_tactical_live_test.gd"

const Abilities = preload("res://src/tests/season_abilities_test.gd")
var _human: bool
var _learned_swings: int
var _count_ready: int
var _sky_launches: int
var _seen_ball: BattedBallBody


func _ready() -> void:
	SeasonSave.path = "user://abilities-live-%d.json" % OS.get_process_id()
	var fixture: Node = Abilities.new()
	var original: SeasonState = fixture._paid_abilities()
	_check(original != null and fixture._failures == 0, "generated paid abilities")
	if original == null:
		fixture.free()
		get_tree().quit(1)
		return
	_check(SeasonSave.save(original), "save learned pregame")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var total_swings: int = 0
	var total_ready: int = 0
	var total_sky: int = 0
	for human: bool in [true, false]:
		_human = human
		_learned_swings = 0
		_count_ready = 0
		_sky_launches = 0
		_seen_ball = null
		_season = SeasonSave._decode(data.duplicate(true))
		await _run_match(67)
		total_swings += _learned_swings
		total_ready += _count_ready
		total_sky += _sky_launches
		var app: SeasonApp = SeasonApp.new()
		app._continue = Button.new()
		app.add_child(app._continue)
		app.season = _season
		app._season_game = true
		app._fixture_id = _season.pending_fixture().id
		app.lab = PitchBatLab.new()
		app.lab._match_state = _played_state
		app.lab._player_home = _season.pending_fixture().home == 0
		_check(app._commit_result(), "physical result including existing fielding proof saves")
		var restored: SeasonState = SeasonSave.restore()
		_check(
			(
				restored != null
				and restored.build._abilities.learned == original.build._abilities.learned
			),
			"physical result replays paid slots and career"
		)
		_check(
			_season.make_match().abilities.called_balls == 0, "next game resets called-ball state"
		)
		print(
			"ABILITIES_LIVE human=",
			human,
			" ready_frames=",
			_count_ready,
			" sky_launches=",
			_sky_launches
		)
		app.lab.free()
		app.lab = null
		app.free()
	_check(total_swings > 0, "actual AI swing tracker receives earned coverage")
	_check(total_ready > 0, "actual taken pitches unlock Work the Count")
	_check(total_sky > 0, "physical qualified launches use Sky Reader")
	fixture.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro live abilities checks passed: "
				+ "paid learning, actual pitches, launch reactions and saves."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _player_home_for_fixture() -> bool:
	return (_season.pending_fixture().home == 0) == _human


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var batter: PlayerDefinition = state.batter().definition
	if batter.season_abilities.has(SeasonAbilities.COUNT) and state.abilities.called_balls >= 2:
		_count_ready += 1
		if lab._swing_tracker != null and lab._swing_tracker.active:
			var actual: SwingProfileDefinition = lab._swing_tracker.profile
			var baseline: SwingProfileDefinition = ContentDB.get_swing(actual.id)
			_check(
				is_equal_approx(actual.contact_radius_x_m, baseline.contact_radius_x_m * 1.06),
				"actual learned swing coverage"
			)
			_learned_swings += 1
		var source: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
		var profile: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
		_check(
			is_equal_approx(profile.contact_radius_x_m, source.contact_radius_x_m * 1.06),
			"human/AI actual effective profile includes earned spatial coverage"
		)
	if is_instance_valid(lab._batted_ball) and lab._batted_ball != _seen_ball:
		_seen_ball = lab._batted_ball
		var fielder: FielderController = lab._primary_fielder
		if fielder._sky_reader:
			if fielder.reaction_delay_seconds < fielder._base_reaction_delay:
				_sky_launches += 1
				_check(
					is_equal_approx(
						fielder.reaction_delay_seconds, fielder._base_reaction_delay * 0.60
					),
					"physical contact classifies once and changes initial reaction only"
				)
