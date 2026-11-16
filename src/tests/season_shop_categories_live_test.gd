extends "res://src/tests/season_tactical_live_test.gd"

const CategoryFixtures = preload("res://src/tests/season_shop_categories_test.gd")
var _learned: Dictionary = {}
var _active_frames: int = 0
var _count_ready_frames: int = 0


func _ready() -> void:
	SeasonSave.path = "user://shop-categories-live-%d.json" % OS.get_process_id()
	var fixture: Node = CategoryFixtures.new()
	for carried: bool in [false, true]:
		_active_frames = 0
		_count_ready_frames = 0
		if carried:
			_season = fixture._reservation_fixture(true)
			var item: String = fixture._selected(_season.build, true)
			_season = fixture._carry(_season, item)
			_check(
				(
					_season
					. build
					. commit(fixture._ability_buy(_season.build, item, _season.build.roster()[0]))
					. ok
				),
				"buy actual carried ability"
			)
		else:
			_season = fixture._focus_fixture()
			_check(
				(
					_season
					. build
					. commit(
						fixture._command(_season.build, "focused_reroll", {"category": "ability"})
					)
					. ok
				),
				"actual paid ability focus"
			)
			_check(
				(
					_season
					. build
					. commit(
						fixture._ability_buy(
							_season.build, SeasonAbilities.COUNT, _season.build.roster()[0]
						)
					)
					. ok
				),
				"actual focused Work the Count purchase"
			)
		while _season.pending_fixture().home != 0:
			fixture._record(_season)
		_check(fixture._failures == 0, "all paid acquisition and career fixture checks pass")
		_check(SeasonSave.save(_season), "save exact acquired pregame")
		_learned = _season.build._abilities.learned.duplicate(true)
		var game: Dictionary = _season.pending_fixture()
		var before: Dictionary = _season.build.view()
		await _run_match(67)
		_check(_active_frames > 0, "acquired ability reaches actual live player")
		await _settlement_retry(game, before)
		_check(
			SeasonSave.restore().build._abilities.learned == _learned,
			"physical result and failed-save retry retain exact paid ability receipts"
		)
		print(
			"CATEGORY_LIVE carried=",
			carried,
			" profile_frames=",
			_active_frames,
			" count_ready_frames=",
			_count_ready_frames
		)
	fixture.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro live shop category checks passed: focused and reserved paid abilities.")
	get_tree().quit(0 if _failures == 0 else 1)


func _player_home_for_fixture() -> bool:
	return true


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var player: PlayerDefinition = state.batter().definition
	if player.season_abilities.has(SeasonAbilities.COUNT):
		var source: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
		var actual: SwingProfileDefinition = SeasonSponsorEffects.swing(source, state)
		var ready: bool = state.abilities.called_balls >= 2
		_check(
			is_equal_approx(
				actual.contact_radius_x_m, source.contact_radius_x_m * (1.06 if ready else 1.0)
			),
			"actual called-ball evidence controls coverage; purchase alone grants no bonus"
		)
		_active_frames += 1
		_count_ready_frames += 1 if ready else 0
	for runtime: PlayerMatchState in state.home_team.roster:
		if runtime.definition.season_abilities.has(SeasonAbilities.HANDS):
			_check(
				MatchAbilities.ground_margin(runtime.definition, true, 0.1) == 0.1,
				"carried Soft Hands uses ordinary grounded-control effect"
			)
			_active_frames += 1
