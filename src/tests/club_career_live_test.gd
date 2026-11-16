extends "res://src/tests/season_tactical_live_test.gd"

const CareerFixtures = preload("res://src/tests/club_career_test.gd")


func _ready() -> void:
	var fixture: Node = CareerFixtures.new()
	_season = fixture._new(51)
	for game in range(11):
		fixture._record(_season)
	_check(
		fixture._failures == 0 and _season.phase == SeasonState.Phase.FINAL,
		"earned actual final fixture"
	)
	fixture.free()
	SeasonSave.path = "user://career-live-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	app.season = _season
	var saved: bool = SeasonPregameCommit.save(app)
	app.free()
	_check(saved, "durable unawarded final pregame")
	if not saved:
		get_tree().quit(1)
		return
	var game: Dictionary = _season.pending_fixture()
	var before: Dictionary = _season.build.view()
	_check(game.home == 0 and _season.career.balance() == 0, "human club home, no early payout")
	await _run_match(67)
	await _settlement_retry(game, before)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.phase == SeasonState.Phase.COMPLETE,
		"actual final completes career"
	)
	if restored != null:
		var expected: int = 220 if restored.champion == 0 else 110
		_check(
			(
				restored.career.balance() == expected
				and restored.career.runs[-1].status == "completed"
			),
			"actual final result determines one finish reward"
		)
		print("CAREER_LIVE champion=", restored.champion, " award=", restored.career.balance())
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live club career checks passed: physical final and durable one-time payout."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _observe_live_frame(_lab: PitchBatLab) -> void:
	pass
