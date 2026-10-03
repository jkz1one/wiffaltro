extends "res://src/tests/season_physical_visible_test.gd"
## Actual preparation matches, then a managed game against a genuinely paid sponsor club.

var _probe: OpponentSponsorProbe = OpponentSponsorProbe.new()
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://sponsor-visible-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://sponsor-visible-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.begin_season(443, true)
	for pick in range(4):
		_app.choose_player(_app.season.offers()[0])
	# Only test preparation drawing is omitted; fixed-step gameplay keeps running.
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	var prepared: int = 0
	var upgraded: bool = false
	for round_number in range(8):
		var fixture: Dictionary = _app.season.pending_fixture()
		var report: Dictionary = await _human_report(_app.season, fixture)
		if report.is_empty():
			break
		_app.round_ui.begin([fixture.id, report.away_runs, report.home_runs,
			report.performance, [], [], {}, [], [], {}, {}, []])
		await _wait_sponsor_round()
		prepared += 1
		_audit_season()
		var next: Dictionary = _app.season.pending_fixture()
		var opponent: int = next.away if next.home == 0 else next.home
		upgraded = not _app.season.opponents.clubs[str(opponent)].build._bank.view().sponsors.is_empty()
		if upgraded:
			break
	RenderingServer.set_render_loop_enabled(true)
	_check(upgraded, "actual next opponent bought a sponsor from earned match rewards")
	if upgraded:
		_prior_results = prepared
		_app.menu.show_lineup()
		await _review("opponent-sponsors-managed-pregame")
		# Review the whole native managed game at the already checked narrow window size.
		get_window().size = Vector2i(700, 400)
		await get_tree().process_frame
		_app.play_season_game()
		var fixture: Dictionary = _app.season.pending_fixture()
		var opponent: int = fixture.away if fixture.home == 0 else fixture.home
		var club: Dictionary = _app.season.opponents.clubs[str(opponent)]
		var team: TeamMatchState = (_app.lab._match_state.away_team
			if fixture.away == opponent else _app.lab._match_state.home_team)
		for player: PlayerMatchState in team.roster:
			_check(player.definition.season_sponsors == club.build.definition(
				String(player.definition.id)).season_sponsors, "exact paid sponsors reach managed roster")
		await _play_owned() # Actual managed match and its original outro render normally.
		if DisplayServer.get_name() != "headless":
			RenderingServer.set_render_loop_enabled(false)
		await _wait_sponsor_round()
		RenderingServer.set_render_loop_enabled(true)
		get_window().size = Vector2i(1280, 720)
		_check(_app._result_saved and _app.season.player_results.size() == prepared + 1,
			"actual managed sponsor game settles once after original outro")
		_audit_season()
		var saved: Dictionary = SeasonSave.snapshot(_app.season)
		for field: String in ["version", "policy", "market", "journal", "decision", "request", "stats"]:
			var bad: Dictionary = saved.duplicate(true)
			match field:
				"version": bad.version = 50
				"policy": bad.opponents.policy = 6
				"market": bad.opponents.clubs["1"].build.market = 5
				"journal": bad.opponents.clubs["1"].build.events.pop_back()
				"decision": bad.opponents.clubs["1"].decisions.append({"stat": "sponsor", "paid": 0})
				"request": bad.physical.reports[0].request = "0".repeat(64)
				"stats": bad.physical.reports[0].report.performance.values()[0].bb += 1
			_check(SeasonSave._decode(bad) == null, "altered sponsor " + field + " rejected")
		var committed: Dictionary = _app.season.opponents.to_data()
		_app.open_shop()
		_check(ClubCareer.same(committed, _app.season.opponents.to_data()),
			"human checkout has no counter-shop")
	print("NPC_SPONSOR_VISIBLE prepared=", prepared, " ", _probe.summary())
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent sponsor visible checks passed: "
			+ "actual credited history and managed use.")
	get_tree().quit(0 if _failures == 0 else 1)


func _human_report(season: SeasonState, fixture: Dictionary) -> Dictionary:
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var failures: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: failures.append(reason))
	_check(runner.start(SeasonPhysicalFixtures.match_for(season, fixture),
		SeasonPhysicalFixtures.seed_for(season, fixture), SeasonState.field_for_fixture(fixture).id),
		"real preparation fixture starts with committed definitions")
	for frame in range(300000):
		await get_tree().physics_frame
		if not report.is_empty() or not failures.is_empty():
			break
	_check(failures.is_empty() and PhysicalMatchReport.valid(report),
		"real preparation game completes")
	runner.queue_free()
	await get_tree().process_frame
	return report


func _wait_sponsor_round() -> void:
	for frame in range(300000):
		await get_tree().physics_frame
		if _app.season.physical.pending.is_empty():
			return
		if not _app.round_ui._working:
			_check(false, "sponsor round paused: " + _app.round_ui.detail.text)
			return
	_check(false, "sponsor round exceeded bounded frame budget")


func _audit_season() -> void:
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(_app.season)), "whole performance/stock/journal/reward replay agrees")
	for key: String in _app.season.opponents.clubs:
		var club: Dictionary = _app.season.opponents.clubs[key]
		var earned: int = 0
		var spent: int = 0
		var replay: SeasonBuild = SeasonBuild.new(club.build._seed, club.build.roster())
		replay._market = 6
		for event: Dictionary in club.build.to_data().events:
			var owns_walk: bool = replay._bank.view().sponsors.any(
				func(receipt: Dictionary) -> bool: return receipt.item == "D01")
			_check(replay.commit(event).ok, "actual acquisition event replay commits")
			if event.op == "reward":
				earned += 18 if event.win else 12
				var walks: int = 0
				for id: String in club.build.roster():
					walks += int(event.performance[id].bb)
				var income: int = mini(2, walks) * 2 if owns_walk else 0
				_check(int(club.build.income_for_game(int(event.game)).get("D01", 0)) == income,
					"income uses actual own walks and ownership preceding that game")
				earned += income
				var fixture: Dictionary = _app.season.results.filter(
					func(row: Dictionary) -> bool: return row.id == event.game)[0]
				_check(ClubCareer.same(event.performance, fixture.performance),
					"own reward uses the exact completed fixture statistics")
			spent += 4 if event.op == "reroll" else 8 if event.op == "pack_skip" else 0
		for decision: Dictionary in club.decisions:
			spent += int(decision.paid)
		_check(club.build.cash() == earned - spent,
			"actual base/earned sponsor income and all debits reconcile")


func _review(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for node: Node in _app.menu._body.find_children("*", "Label", true, false):
		if node.has_meta("opponent_sponsor_owned"):
			var scroll: ScrollContainer = _app.menu._body.get_parent()
			scroll.ensure_control_visible(node.get_parent())
			await get_tree().process_frame
			await _capture(label)
			get_window().size = Vector2i(700, 400)
			await get_tree().process_frame
			await get_tree().process_frame
			scroll.ensure_control_visible(node)
			await get_tree().process_frame
			_check(get_viewport().get_visible_rect().encloses(_app.menu._footer.get_global_rect()),
				"narrow sponsor disclosure preserves navigation")
			await _capture(label + "-small")
			get_window().size = Vector2i(1280, 720)
			return
	_check(false, "actual next opponent's paid sponsor is disclosed")


func _capture(label: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join(label + ".png")) == OK, "native sponsor capture")


func _process(_delta: float) -> void:
	if is_instance_valid(_app):
		var lab: PitchBatLab = _app.lab
		if lab == null and _app.round_ui != null:
			lab = _app.round_ui.runner._lab
		_probe.observe(lab, _check)
