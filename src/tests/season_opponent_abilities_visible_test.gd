extends "res://src/tests/season_physical_visible_test.gd"
## Real AI rounds acquire ability, then a managed fixture uses the paid build.

const AbilityFixtures = preload("res://src/tests/season_opponent_abilities_test.gd")

var _probe: OpponentAbilityProbe = OpponentAbilityProbe.new()


func _ready() -> void:
	SeasonSave.path = "user://ability-visible-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://ability-visible-%d.cfg" % OS.get_process_id()
	var fixture: Node = AbilityFixtures.new()
	var season: SeasonState = fixture._new(true)
	_check(fixture._failures == 0 and SeasonSave.save(season), "ability season fixture saves")
	fixture.free()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	var prepared: int = 0
	var upgraded: bool = false
	for round_number in range(8):
		var pending: Dictionary = _app.season.pending_fixture()
		_app.round_ui.begin([pending.id, 0 if pending.home == 0 else 1,
			1 if pending.home == 0 else 0, {}, [], [], {}, [], [], {}, {}, []])
		await _wait_ability_round()
		prepared += 1
		var next: Dictionary = _app.season.pending_fixture()
		var opponent: int = next.away if next.home == 0 else next.home
		var club: Dictionary = _app.season.opponents.clubs[str(opponent)]
		upgraded = club.decisions.any(func(row: Dictionary) -> bool: return row.stat == "ability")
		if upgraded:
			break
	_check(upgraded, "actual next opponent acquired paid ability before managed match")
	_prior_results = prepared
	_app.play_season_game()
	_check(_app.lab != null, "ordinary saved pregame opens ability match")
	var next: Dictionary = _app.season.pending_fixture()
	var opponent: int = next.away if next.home == 0 else next.home
	var club: Dictionary = _app.season.opponents.clubs[str(opponent)]
	var team: TeamMatchState = (_app.lab._match_state.away_team
		if next.away == opponent else _app.lab._match_state.home_team)
	for row: Dictionary in club.decisions:
		if row.stat != "ability":
			continue
		var player: PlayerMatchState
		for member: PlayerMatchState in team.roster:
			if String(member.definition.id) == row.player:
				player = member
		_check(player != null and player.definition.season_abilities.has(row.item),
			"paid learned ability reaches actual managed-game roster")
	await _play_owned()
	print("NPC_ABILITY_VISIBLE_OBSERVATION ", _probe.summary())
	await _wait_ability_round()
	_check(_app._result_saved and _app.season.player_results.size() == prepared + 1,
		"real managed ability fixture settles exactly once")
	_check(_app.season.physical.reports.size() == 2 * (prepared + 1),
		"all prepared rounds and managed round have actual offscreen evidence")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(SeasonSave.snapshot(_app.season),
		SeasonSave.snapshot(restored)), "ability visible and offscreen evidence replay exactly")
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent ability visible checks passed: "
			+ "paid ability in managed and AI matches. ",
			"games=", 2 * (prepared + 1) + 1)
	get_tree().quit(0 if _failures == 0 else 1)


func _wait_ability_round() -> void:
	for frame in range(300000):
		await get_tree().physics_frame
		if _app.season.physical.pending.is_empty():
			return
		if not _app.round_ui._working:
			_check(false, "ability settlement paused: " + _app.round_ui.detail.text)
			return
	_check(false, "ability round did not finish")


func _process(_delta: float) -> void:
	if is_instance_valid(_app):
		var lab: PitchBatLab = _app.lab
		if lab == null and _app.round_ui != null:
			lab = _app.round_ui.runner._lab
		_probe.observe(lab, _check)
