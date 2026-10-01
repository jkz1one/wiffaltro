extends "res://src/tests/season_tactical_live_test.gd"

const Jump = preload("res://src/tests/season_jumpstart_test.gd")
var _seen_pa: Dictionary = {}
var _step_frames: int = 0
var _sale_app: SeasonApp
var _sold: bool = false
var _sell_mode: bool = false


func _ready() -> void:
	var fixture: Node = Jump.new()
	for mode: String in ["prospective", "paid", "sale"]:
		var sell_copy: bool = mode == "sale"
		_sell_mode = sell_copy
		_sold = false
		_seen_pa.clear()
		_step_frames = 0
		if mode == "prospective":
			_season = fixture._new_club(98)
			for game_index in range(3):
				fixture._jump_result(_season, false)
		else:
			_season = fixture._paid_jump()
		while _season.pending_fixture().home != 0:
			fixture._jump_result(_season, false)
		_check(fixture._failures == 0, "real paid Jumpstart fixture")
		SeasonSave.path = "user://jumpstart-live-%s-%d.json" % [mode, OS.get_process_id()]
		_sale_app = SeasonApp.new()
		_sale_app.season = _season
		_sale_app._season_game = true
		_sale_app._fixture_id = _season.pending_fixture().id
		_sale_app.loadout = SeasonLoadoutUI.new()
		_sale_app.loadout.match_snapshot = SeasonLoadoutData.capture(_season)
		_check(SeasonPregameCommit.save(_sale_app), "physical pregame saved")
		var game: Dictionary = _season.pending_fixture()
		await _run_match(67)
		_sale_app.lab.free()
		_sale_app.lab = null
		_check(mode == "prospective" or _step_frames > 0, "actual committed first steps observed")
		_check(
			not sell_copy or (_sold and _sale_app.sales.pending.is_empty()),
			"live sale retires at natural PA boundary"
		)
		_season = _sale_app.season
		_check(SeasonSave.save(_season), "save current ownership before result")
		var before: Dictionary = _season.build.view()
		await _settlement_retry(game, before)
		var restored: SeasonState = SeasonSave.restore()
		var evidence: Array = _played_state.clean_outs.evidence(_played_state.home_team)
		_check(
			restored != null and ClubCareer.same(restored.player_results[-1].fielding, evidence),
			"actual clean-out order replays exactly"
		)
		_check(
			SeasonJumpstart.valid(
				_season.build, evidence, _played_state.performance.snapshot(_played_state)
			),
			"actual fielded outs reconcile with physical box score"
		)
		print(
			"JUMPSTART_LIVE mode=",
			mode,
			" fielded_outs=",
			evidence.size(),
			" step_frames=",
			_step_frames
		)
		if mode == "prospective":
			var earned: bool = SeasonJumpstart.qualifies(evidence)
			_check(
				restored.build._jump_earned == earned,
				"only actual completed clean outs earn access"
			)
		_sale_app.loadout.free()
		_sale_app.free()
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro live Jumpstart checks passed: physical first steps, clean-out results, "
				+ "sale boundary and save retry."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	_played_state = state
	# The synthetic driver controls the managed home club; opposing hitters use the real AI.
	_sale_app.lab = PitchBatLab.new()
	_sale_app.lab._match_state = state
	_sale_app.lab._player_home = true
	state.inventory_boundary.connect(_sale_app.sales.apply_pending.bind(_sale_app))


func _player_home_for_fixture() -> bool:
	return true


func _observe_live_frame(lab: PitchBatLab) -> void:
	_sale_app.sales.apply_pending(_sale_app)
	var state: MatchState = lab._match_state
	if _sold and _sale_app.sales.pending.is_empty():
		_check(
			not state.home_team.roster[0].definition.season_sponsors.get("J04", false),
			"sold modifier retired from owning club"
		)
	if state.defensive_team() != state.home_team:
		return
	if state.can_change_defense() and not _seen_pa.has(state.plate_appearance_number):
		if state.fielder().definition.season_sponsors.get("J04", false):
			_check(SeasonJumpstart.choose(state, "left"), "explicit pre-PA synthetic policy")
		_seen_pa[state.plate_appearance_number] = true
	var fielder: FielderController = lab._primary_fielder
	if not fielder.active or fielder.first_step.is_zero_approx():
		return
	if fielder._play_elapsed_seconds > 0.20:
		return
	_step_frames += 1
	_check(fielder.first_step == Vector3.RIGHT, "actual fair-contact direction matches commitment")
	_check(
		(
			fielder.global_position.distance_to(fielder.anchor_position)
			<= fielder.move_speed_mps * 0.201
		),
		"physical step never exceeds normal speed budget"
	)
	if not _sell_mode or _sold:
		return
	var copy: Dictionary = SeasonSchoolSponsors.active(_sale_app.season.build, "J04")
	var command: Dictionary = SeasonMatchSales.command(_sale_app, copy.id)
	var before: Dictionary = _sale_app.season.build.to_data()
	var cash_before: int = _sale_app.season.cash()
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	_check(not _sale_app.sales.sell(_sale_app, command), "failed sale write")
	SeasonSave.path = path
	_check(
		_sale_app.season.build.to_data() == before and _sale_app.sales.pending.is_empty(),
		"failed sale keeps copy and modifier"
	)
	_check(_sale_app.sales.sell(_sale_app, command), "paid sale during real committed step")
	_check(
		(
			_sale_app.season.cash() == cash_before + 6
			and not SeasonJumpstart.direction(state).is_zero_approx()
		),
		"refund now, commitment remains through PA"
	)
	_check(not _sale_app.sales.sell(_sale_app, command), "sale cannot pay twice")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and SeasonSchoolSponsors.active(restored.build, "J04").is_empty(),
		"restart cannot resurrect sold copy"
	)
	_sold = true


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	_check(
		lab._match_state.clean_outs.rows.is_empty(), "restart clears incomplete clean-out evidence"
	)
	_check(
		(
			lab._match_state.jumpstart_mode == "normal"
			and lab._primary_fielder.first_step.is_zero_approx()
		),
		"restart clears commitment and movement"
	)
