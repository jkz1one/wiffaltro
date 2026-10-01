extends "res://src/tests/season_tactical_live_test.gd"

const Sure = preload("res://src/tests/season_sure_shot_test.gd")
var _seen_pa: Dictionary = {}
var _cue_frames: int = 0
var _sale_app: SeasonApp
var _sold: bool = false
var _sell_mode: bool = false
var _sell_before_release: bool = false


func _ready() -> void:
	var fixture: Node = Sure.new()
	for mode: String in ["prospective", "paid", "sale", "sale_before_release"]:
		var sell_copy: bool = mode.begins_with("sale")
		_sell_mode = sell_copy
		_sell_before_release = mode == "sale_before_release"
		_sold = false
		_seen_pa.clear()
		_cue_frames = 0
		if mode == "prospective":
			_season = fixture._new_club(98)
			for game_index in range(3):
				fixture._sure_result(_season, false)
		else:
			_season = fixture._paid_sure()
		while _season.pending_fixture().home != 0:
			fixture._sure_result(_season, false)
		_check(fixture._failures == 0, "real paid SureShot fixture")
		SeasonSave.path = "user://sure_shot-live-%s-%d.json" % [mode, OS.get_process_id()]
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
		_check(mode == "prospective" or _cue_frames > 0, "actual committed pitch cues observed")
		_check(
			not sell_copy or (_sold and _sale_app.sales.pending.is_empty()),
			"live sale retires at natural PA boundary"
		)
		_season = _sale_app.season
		_check(SeasonSave.save(_season), "save current ownership before result")
		var before: Dictionary = _season.build.view()
		await _settlement_retry(game, before)
		var restored: SeasonState = SeasonSave.restore()
		var evidence: Dictionary = _played_state.sure_shot.evidence(_played_state.home_team)
		_check(
			restored != null and ClubCareer.same(restored.player_results[-1].pitching, evidence),
			"actual releases and announcements replays exactly"
		)
		_check(
			SeasonSureShot.valid(
				_season.build, evidence, _played_state.performance.snapshot(_played_state)
			),
			"actual pitch releases reconcile with physical box score"
		)
		_check(
			evidence.calls.size() == (0 if mode == "prospective" else (1 if sell_copy else 2)),
			"two team uses, with sold copy unable to announce a new PA"
		)
		print(
			"SURE_SHOT_LIVE mode=",
			mode,
			" pitch_evidence=",
			evidence.releases.size(),
			" calls=",
			evidence.calls.size(),
			" cue_frames=",
			_cue_frames
		)
		if mode == "prospective":
			var earned: bool = SeasonSureShot.qualifies(evidence)
			_check(
				restored.build._sure_earned == earned,
				"only actual completed repeated recipes earn access"
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
				"Wiffaltro live Sure Shot checks passed: physical commitments, pitching results, "
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
			not state.home_team.roster[0].definition.season_sponsors.get("F08", false),
			"sold modifier retired from owning club"
		)
	if state.defensive_team() != state.home_team:
		return
	if state.phase == MatchState.Phase.PRE_PITCH and state.between_batters:
		if not _seen_pa.has(state.plate_appearance_number):
			if (
				state.pitcher().definition.season_sponsors.get("F08", false)
				and state.sure_shot.remaining(state.defensive_team()) > 0
			):
				_check(
					state.sure_shot.choose(state, lab._selected_pitch().id),
					"explicit pre-PA synthetic commitment"
				)
			_seen_pa[state.plate_appearance_number] = true
	var call: Dictionary = state.sure_shot.current(state)
	if call.is_empty():
		return
	if lab._pitch_actor.running:
		_cue_frames += 1
		_check(
			lab._selected_pitch().id == StringName(call.recipe), "only announced recipe released"
		)
		_check(
			state.pitch_disclosure == state.sure_shot.cue(state), "AI and human get identical cue"
		)
		_check(
			lab._active_play_record.pitch_disclosure == state.pitch_disclosure,
			"replay retains public announcement timestamp"
		)
	if not _sell_mode or _sold or (not _sell_before_release and not lab._pitch_actor.running):
		return
	var copy: Dictionary = SeasonSchoolSponsors.active(_sale_app.season.build, "F08")
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
	_check(_sale_app.sales.sell(_sale_app, command), "paid sale during commitment")
	_check(
		_sale_app.season.cash() == cash_before + 6 and not _sale_app.sales.pending.is_empty(),
		"refund now, committed PA effect remains even before first release"
	)
	_check(not _sale_app.sales.sell(_sale_app, command), "sale cannot pay twice")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and SeasonSchoolSponsors.active(restored.build, "F08").is_empty(),
		"restart cannot resurrect sold copy"
	)
	_sold = true


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	_check(
		(
			lab._match_state.sure_shot.releases.is_empty()
			and lab._match_state.sure_shot.calls.is_empty()
		),
		"restart clears attempt-only pitching state"
	)
	_check(not lab._match_state.home_team.sure_shot_locked, "restart releases pitcher commitment")
