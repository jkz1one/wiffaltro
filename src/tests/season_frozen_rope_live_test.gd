extends "res://src/tests/live_match_test.gd"

const FrozenFixture = preload("res://src/tests/season_frozen_rope_test.gd")
var _app: SeasonApp
var _state: MatchState
var _sale_game: bool = false
var _sold: bool = false
var _copy: Dictionary
var _contacts: Dictionary = {}
var _shaped: int = 0
var _profiles: int = 0
var _biased: int = 0
var _ai_biased: int = 0
var _saved_choices: int = 0
var _guided_done: bool = false
var _guided_throw: int = -1
var _crossing: PitchCrossingResult


func _ready() -> void:
	SeasonSave.path = "user://frozen-rope-live-%d.json" % OS.get_process_id()
	var fixture: Node = FrozenFixture.new()
	_app = SeasonApp.new()
	_app.season = fixture.paid_frozen()
	_check(_app.season != null and fixture._failures == 0, "earned and purchased real Frozen Rope")
	fixture.free()
	if _app.season == null:
		_app.free()
		get_tree().quit(1)
		return
	_app.loadout = SeasonLoadoutUI.new()
	_copy = _app.season.build.view().wallet.gear.bat.duplicate(true)
	for sale_game: bool in [false, true]:
		_sale_game = sale_game
		_app.loadout.match_snapshot = SeasonLoadoutData.capture(_app.season)
		_app._season_game = true
		_app._fixture_id = _app.season.pending_fixture().id
		_check(SeasonPregameCommit.save(_app), "durable paid pregame")
		var cash: int = _app.season.cash()
		await _run_match(67)
		_app.lab = null
		if sale_game:
			_check(
				_sold and _app.sales.pending.is_empty(),
				"active swing sale retires at natural boundary"
			)
			_check(_app.season.cash() == cash + 10, "twenty-paid copy refunds ten immediately")
		var own_roster: Array = _app.season.teams[0].roster
		var frozen_rows: Array = _state.frozen_contacts.filter(
			func(row: Dictionary) -> bool: return own_roster.has(row.player)
		)
		_check(
			_app.season.record_player_result(
				_app._fixture_id,
				_state.away_team.runs,
				_state.home_team.runs,
				_state.performance.snapshot(_state),
				_state.gear_usage.first_pitch,
				[],
				{},
				_state.sides.evidence(
					_state.home_team if _player_home_for_fixture() else _state.away_team
				),
				[],
				{},
				{},
				frozen_rows
			),
			"actual physical game accepts original paid receipt use"
		)
		_check(SeasonSave.save(_app.season), "save completed Frozen game")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null, "physical results, ownership and career rebuild together")
		if restored != null:
			_check(
				restored.career.gear_counts().get(FrozenFixture.GAP) == 20,
				"final tier never invents predecessor use credit"
			)
			_check(
				ClubCollection.discoveries(restored.career).has(FrozenFixture.FROPE),
				"sale retains discovery"
			)
			_verify_saved_choices(restored)
			_app.season = restored
	_check(_profiles > 0 and not _contacts.is_empty(), "actual AI swing and contact observed")
	_check(
		_guided_done and _biased > 0 and _ai_biased > 0 and _saved_choices > 0,
		"real human gap launch and saved evidence observed"
	)
	print(
		"FROZEN_LIVE profiles=",
		_profiles,
		" contacts=",
		_contacts.size(),
		" shaped=",
		_shaped,
		" biased=",
		_biased,
		" ai_biased=",
		_ai_biased,
		" saved=",
		_saved_choices
	)
	_app.loadout.free()
	_app.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Frozen Rope checks passed: two games, committed gap launches and active sale."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _app.season.make_match()


func _player_home_for_fixture() -> bool:
	return _app.season.pending_fixture().home == 0


func _equip_fixture(state: MatchState) -> void:
	_state = state
	state.inventory_boundary.connect(_app.sales.apply_pending.bind(_app))
	# Controlled opponent ownership exercises the same live resolver. This is not
	# claimed as AI shop acquisition, which is a separate unsupported category.
	var rival: TeamMatchState = state.away_team if _player_home_for_fixture() else state.home_team
	for player: PlayerMatchState in rival.roster:
		player.definition = SeasonGearCatalog.equip(
			player.definition, {"bat": {"item": FrozenFixture.FROPE}}
		)


func _observe_live_frame(lab: PitchBatLab) -> void:
	_app.lab = lab
	_app.sales.apply_pending(_app)
	_guided_contact(lab)
	if _sale_game and not _sold and lab._player_is_batting() and lab._pitch_actor.running:
		if not lab._swing_consumed:
			# A real legal button-equivalent swing during the live pitch, not forced contact.
			lab._resolve_swing(&"swing.contact", Vector2(0, 1.05))
		if lab._swing_tracker != null and lab._swing_tracker.active:
			var profile: SwingProfileDefinition = lab._swing_tracker.profile
			_check(
				profile.gear_line_drive_strength == 0.75 and profile.gear_line_drive_calibrated,
				"owned bat is committed to active human swing"
			)
			var request: Dictionary = SeasonMatchSales.command(_app, _copy.id)
			var before: Dictionary = _app.season.build.to_data()
			var path: String = SeasonSave.path
			SeasonSave.path = path + "/missing/file.json"
			_check(
				not _app.sales.sell(_app, request) and _app.season.build.to_data() == before,
				"failed live write rolls back ownership and effect queue"
			)
			SeasonSave.path = path
			_check(
				_app.sales.sell(_app, request), "sell original paid Frozen during committed swing"
			)
			_check(
				lab._swing_tracker.active and lab._swing_tracker.profile == profile,
				"sale never replaces or retimes active swing profile"
			)
			_check(
				_state.batter().definition.season_gear.get("bat") == FrozenFixture.FROPE,
				"Frozen effect remains for current batter"
			)
			_sold = true
	if lab._swing_tracker == null:
		return
	var tracker: SwingContactTracker = lab._swing_tracker
	if tracker.active and not lab._player_is_batting():
		_check(
			(
				tracker.profile.gear_line_drive_strength
				== (0.75 if tracker.profile.id == &"swing.contact" else 0.0)
			),
			"AI receives ordinary same-tier swing mapping"
		)
		_profiles += 1
	if tracker.result == null or _contacts.has(tracker.result.get_instance_id()):
		return
	var contact: ContactResult = tracker.result
	_contacts[contact.get_instance_id()] = true
	if contact.outcome not in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]:
		return
	var profile: SwingProfileDefinition = tracker.profile
	var rating: int = tracker.contact_rating
	var ny: float = (
		contact.vertical_error_m
		/ (profile.contact_radius_y_m * ContactResolver._contact_factor(rating))
	)
	var raw: float = clampf(
		profile.attack_angle_degrees + clampf(ny, -1.0, 1.0) * 32.0, -22.0, 55.0
	)
	var expected: float = SeasonAlleyGear.angle(
		raw, contact.quality, profile.gear_line_drive_strength
	)
	_check(
		is_equal_approx(contact.launch_angle_degrees, expected),
		"actual contact launches with one calibrated shaping"
	)
	if not contact.frozen_launch.is_empty():
		var launch: BattedBallLaunch = BattedBallLaunch.from_contact(contact)
		_check(
			SeasonGapCommit.same(
				contact.frozen_launch.spin,
				[launch.angular_velocity.x, launch.angular_velocity.y, launch.angular_velocity.z]
			),
			"physical launch preserves original spin despite selected spray"
		)
		_check(
			SeasonGapCommit.valid(contact.frozen_launch),
			"actual snapshot and selected vector validate"
		)
		_check(
			SeasonGapCommit.same(
				contact.frozen_launch.choice.velocity,
				[contact.exit_velocity.x, contact.exit_velocity.y, contact.exit_velocity.z]
			),
			"committed evidence equals actual release vector"
		)
		if contact.frozen_launch.choice.reason == "improved":
			_check(lab._batted_ball != null, "gap-biased contact releases a real physical body")
			_biased += 1
			if lab._player_is_batting():
				_guided_done = true
			else:
				_ai_biased += 1
	if expected < raw:
		_check(lab._batted_ball != null, "flattened contact releases an actual physics body")
		_shaped += 1


func _guided_contact(lab: PitchBatLab) -> void:
	if _sale_game or _guided_done or not lab._player_is_batting() or not lab._pitch_actor.running:
		return
	if lab._swing_consumed:
		return
	# Test driver alone predicts one pitch to aim a qualifying legal Contact swing.
	# This changes no production AI observation, contact result or ball trajectory.
	if _guided_throw != lab._throw_number:
		_guided_throw = lab._throw_number
		_crossing = PitchTrajectorySimulator.simulate_to_plane(
			lab._pitch_actor.parameters, ContactResolver.CONTACT_PLANE_Z
		)
	if _crossing == null or not _crossing.crossed:
		return
	var profile: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var factor: float = ContactResolver._contact_factor(_state.batter().definition.contact)
	var aim: Vector2 = Vector2(
		_crossing.point.x, _crossing.point.y - 0.05 * profile.contact_radius_y_m * factor
	)
	if SwingIntent.reachable_aim(aim) != aim:
		return
	if lab._pitch_actor.state.elapsed_time < _crossing.elapsed_seconds - profile.sweet_spot_seconds:
		return
	lab._resolve_swing(&"swing.contact", aim)


func _verify_saved_choices(restored: SeasonState) -> void:
	var result: Dictionary = restored.player_results[-1]
	for row: Dictionary in result.get("frozen", []):
		_check(
			SeasonGapCommit.valid(row.launch),
			"saved physical launch validates against frozen snapshot"
		)
		_saved_choices += 1
	if result.get("frozen", []).is_empty():
		return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var event: Dictionary
	for value: Dictionary in saved.build.events:
		if value.op == "reward" and value.game == result.id:
			event = value
	_check(
		event != null and SeasonGapCommit.same(event.frozen, result.frozen),
		"saved result and replay journal agree"
	)
	var forged: Dictionary = saved.duplicate(true)
	forged.results[-1].frozen[0].launch.choice.selected += 0.5
	for value: Dictionary in forged.build.events:
		if value.op == "reward" and value.game == result.id:
			value.frozen[0].launch.choice.selected += 0.5
	_check(
		SeasonSave._decode(forged) == null,
		"forged choice rejects even when result and journal agree"
	)
	forged = saved.duplicate(true)
	forged.results[-1].frozen[0].half += 1
	_check(SeasonSave._decode(forged) == null, "opponent-half Frozen evidence rejected")
