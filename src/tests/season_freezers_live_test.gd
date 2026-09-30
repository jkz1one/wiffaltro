extends "res://src/tests/season_tactical_live_test.gd"

const Freezers = preload("res://src/tests/season_freezers_test.gd")
var _seen_pa: Dictionary = {}
var _cold_swings: int = 0
var _sale_app: SeasonApp
var _sold: bool = false
var _sell_mode: bool = false


func _ready() -> void:
	var fixture: Node = Freezers.new()
	for mode: String in ["prospective", "paid", "sale"]:
		var sell_copy: bool = mode == "sale"
		_sell_mode = sell_copy
		_sold = false
		_seen_pa.clear()
		_cold_swings = 0
		if mode == "prospective":
			_season = fixture._new_club(48)
			for game_index in range(3):
				fixture._completed(_season, [])
		else:
			_season = fixture._paid_freezer()
		while _season.pending_fixture().home != 0:
			fixture._completed(_season, [])
		_check(fixture._failures == 0, "real paid Freezers fixture")
		SeasonSave.path = "user://freezers-live-%s-%d.json" % [mode, OS.get_process_id()]
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
		_check(mode == "prospective" or _cold_swings > 0, "actual Cold-modified swings observed")
		_check(
			not sell_copy or (_sold and _sale_app.sales.pending.is_empty()),
			"live sale retires at natural PA boundary"
		)
		_season = _sale_app.season
		_check(SeasonSave.save(_season), "save current ownership before result")
		var before: Dictionary = _season.build.view()
		await _settlement_retry(game, before)
		var restored: SeasonState = SeasonSave.restore()
		var evidence: Dictionary = _played_state.cold.evidence(_played_state.home_team)
		_check(
			restored != null and restored.player_results[-1].batting == evidence,
			"actual PA order replays exactly"
		)
		_check(
			SeasonFreezers.valid(
				evidence, _season.teams[0].roster, _played_state.performance.snapshot(_played_state)
			),
			"actual orders reconcile with physical box score"
		)
		if mode == "prospective":
			var earned: bool = false
			for outcomes: Array in evidence.values():
				earned = earned or SeasonFreezers.breakout(outcomes)
			_check(
				restored.build._freezer_earned == earned,
				"only actual completed breakout earns access"
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
				"Wiffaltro live Freezers checks passed: physical Cold swings, ordered results, "
				+ "sale boundary and save retry."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	_played_state = state
	# The synthetic driver controls the away pitcher while the managed club is home.
	_sale_app.lab = PitchBatLab.new()
	_sale_app.lab._match_state = state
	_sale_app.lab._player_home = true
	state.inventory_boundary.connect(_sale_app.sales.apply_pending.bind(_sale_app))


func _observe_live_frame(lab: PitchBatLab) -> void:
	_sale_app.sales.apply_pending(_sale_app)
	var state: MatchState = lab._match_state
	if _sold and _sale_app.sales.pending.is_empty():
		_check(
			not state.home_team.roster[0].definition.season_sponsors.get("E10", false),
			"sold effect retired from exact owning club"
		)
	if state.batting_team() != state.home_team or lab._swing_tracker == null:
		return
	if not lab._swing_tracker.active or _seen_pa.has(state.plate_appearance_number):
		return
	_seen_pa[state.plate_appearance_number] = true
	var player: PlayerMatchState = state.batter()
	var cold: int = state.cold.stacks(player)
	var profile: SwingProfileDefinition = lab._swing_tracker.profile
	var source: SwingProfileDefinition = ContentDB.get_swing(profile.id)
	_check(
		is_equal_approx(
			profile.gear_fair_exit_scale,
			1.0 + (cold * 0.03 if profile.id == &"swing.power" else 0.0)
		),
		"physical swing exact Power coefficient"
	)
	_check(
		is_equal_approx(
			profile.contact_radius_x_m / source.contact_radius_x_m,
			1.0 - (cold * 0.04 if profile.id == &"swing.contact" else 0.0)
		),
		"physical swing exact Contact radius"
	)
	if cold == 0:
		return
	_cold_swings += 1
	if not _sell_mode or _sold:
		return
	var copy: Dictionary = SeasonSchoolSponsors.active(_sale_app.season.build, "E10")
	var command: Dictionary = SeasonMatchSales.command(_sale_app, copy.id)
	var before: Dictionary = _sale_app.season.build.to_data()
	var cash_before: int = _sale_app.season.cash()
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	_check(not _sale_app.sales.sell(_sale_app, command), "failed sale write")
	SeasonSave.path = path
	_check(
		_sale_app.season.build.to_data() == before and _sale_app.sales.pending.is_empty(),
		"failed sale keeps copy and Cold"
	)
	_check(_sale_app.sales.sell(_sale_app, command), "paid sale during real Cold swing")
	_check(
		_sale_app.season.cash() == cash_before + 6 and state.cold.stacks(player) == cold,
		"refund now, Cold remains through PA"
	)
	_check(not _sale_app.sales.sell(_sale_app, command), "sale cannot pay twice")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and SeasonSchoolSponsors.active(restored.build, "E10").is_empty(),
		"restart cannot resurrect sold copy"
	)
	_sold = true


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	_check(lab._match_state.cold.appearances.is_empty(), "restart clears completed PA order")
	for player: PlayerMatchState in lab._match_state.home_team.roster:
		_check(lab._match_state.cold.stacks(player) == 0, "restart Cold is zero")
