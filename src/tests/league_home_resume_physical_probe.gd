extends Node
## Resume only an existing isolated candidate checkpoint. Never replay accepted games.
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("HOME_RESUME_CHECK ", checks, " ", ok, " ", label)
	if not ok: failures += 1
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--league-home-resume-root="):
			root = arg.trim_prefix("--league-home-resume-root=")
	if not root.is_absolute_path() or not FileAccess.file_exists(root.path_join("season.json.dynasty-owner")):
		get_tree().quit(2)
		return
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	app.child_entered_tree.connect(func(child: Node) -> void:
		if child is PitchBatLab:
			child._automation = MatchAutomation.new()
			child._automation.seed = SeasonPhysicalFixtures.seed_for(app.season, app.season.pending_fixture())
	)
	add_child(app)
	if check(app.season != null and app.dynasty_owner.ready(), "cold source restored"):
		await _continue(app)
	app.free()
	SeasonSave._dynasty_owner_path = ""
	print("HOME_RESUME: %d checks, %d failures" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _continue(app: SeasonApp) -> void:
	while app.season.player_results.size() < 2:
		var before: int = app.season.player_results.size()
		var fixture: Dictionary = app.season.pending_fixture().duplicate(true)
		var resumed: bool = false
		if not app.season.physical.pending.is_empty():
			print("PRESERVED_HUMAN ", fixture.id, " score=", app.season.physical.pending.human.slice(1,3),
				" accepted_ai=", app.season.physical.pending.reports.size())
			app.round_ui.resume()
			resumed = true
		else:
			print("NEW_PHYSICAL_MATCH ", fixture)
			app.play_season_game()
			await get_tree().process_frame
			if not check(is_instance_valid(app.lab), "actual main starts home: " + app.notice): return
			if fixture.home == 0:
				if not check(StadiumBoundaryRuntime.installed(app.lab, app.lab._match_state.stadium),
					"owned home boundary installed"): return
		var completed: bool = false
		for frame in range(300000):
			await get_tree().physics_frame
			if not app.season.physical.pending.is_empty() and not resumed and not app.round_ui._working:
				app.round_ui.resume()
				resumed = true
			if app.season.player_results.size() > before and not app.round_ui._working:
				completed = true
				break
			if resumed and not app.round_ui._working and not app.season.physical.pending.is_empty():
				check(false, "round paused: " + app.round_ui.status.text + " " + app.notice)
				return
			if frame % 10000 == 0:
				print("HOME_PROGRESS ", frame, " pending=", not app.season.physical.pending.is_empty(),
					" phase=", app.lab._match_state.phase if is_instance_valid(app.lab) else -1,
					" score=", app.lab._match_state.score_label() if is_instance_valid(app.lab) else "",
					" status=", app.round_ui.status.text)
		if not check(completed, "human and NPC round settled"): return
		if not check(SeasonSave.restore() != null, "complete round cold replay"): return
		print("COMPLETED_FIXTURE ", fixture.id, " home=", fixture.home, " saved_results=", app.season.player_results.size())
