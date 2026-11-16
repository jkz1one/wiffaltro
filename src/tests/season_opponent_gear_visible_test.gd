extends "res://src/tests/season_physical_visible_test.gd"
## Real AI rounds acquire Gear, then a real managed fixture uses the paid build.

const GearFixtures = preload("res://src/tests/season_opponent_gear_test.gd")


func _ready() -> void:
	SeasonSave.path = "user://gear-visible-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://gear-visible-%d.cfg" % OS.get_process_id()
	var fixture: Node = GearFixtures.new()
	var season: SeasonState = fixture._new(true)
	_check(fixture._failures == 0 and SeasonSave.save(season), "Gear season fixture saves")
	fixture.free()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	var prepared: int = 0
	var equipped: bool = false
	for round_number in range(8):
		var pending: Dictionary = _app.season.pending_fixture()
		_app.round_ui.begin([pending.id, 0 if pending.home == 0 else 1,
			1 if pending.home == 0 else 0, {}, [], [], {}, [], [], {}, {}, []])
		await _wait_gear_round()
		prepared += 1
		var next: Dictionary = _app.season.pending_fixture()
		var opponent: int = next.away if next.home == 0 else next.home
		var gear: Dictionary = _app.season.opponents.clubs[str(opponent)].build._bank.view().gear
		equipped = gear.values().any(func(item: Dictionary) -> bool: return not item.is_empty())
		if equipped:
			break
	_check(equipped, "actual next opponent acquired paid Gear before managed match")
	_prior_results = prepared
	_app.play_season_game()
	_check(_app.lab != null, "ordinary saved pregame opens Gear match")
	await _play_owned()
	await _wait_gear_round()
	_check(_app._result_saved and _app.season.player_results.size() == prepared + 1,
		"real managed Gear fixture settles exactly once")
	_check(_app.season.physical.reports.size() == 2 * (prepared + 1),
		"all prepared rounds and managed round have actual offscreen evidence")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(SeasonSave.snapshot(_app.season),
		SeasonSave.snapshot(restored)), "Gear visible and offscreen evidence replay exactly")
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Gear visible checks passed: paid Gear in managed and AI matches. ",
			"games=", 2 * (prepared + 1) + 1)
	get_tree().quit(0 if _failures == 0 else 1)


func _wait_gear_round() -> void:
	for frame in range(300000):
		await get_tree().physics_frame
		if _app.season.physical.pending.is_empty():
			return
		if not _app.round_ui._working:
			_check(false, "Gear settlement paused: " + _app.round_ui.detail.text)
			return
	_check(false, "Gear round did not finish")
