extends "res://src/tests/season_opponent_sponsors_visible_test.gd"
## Actual preparation matches, then a managed game against a genuinely paid sponsor club.

var _choice_probe: OpponentChoiceProbe = OpponentChoiceProbe.new()
var _choice_captured: bool = false


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://choice-visible-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://choice-visible-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.begin_season(443, true)
	_app.season.opponents._format = 8
	_check(SeasonSave.save(_app.season), "historical policy8 saves prospectively")
	_check(_app.season.opponents._format == 8, "ordinary Working policy8")
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
		upgraded = _app.season.opponents.clubs[str(opponent)].build._bank.view().sponsors.any(
			func(row: Dictionary) -> bool: return row.item in ["F01", "F03"])
		if upgraded:
			break
	RenderingServer.set_render_loop_enabled(true)
	_check(upgraded, "actual next opponent bought a sponsor from earned match rewards")
	if upgraded:
		_prior_results = prepared
		_app.menu.show_lineup()
		await _review("opponent-choices-managed-pregame")
		# Native review captures the actual choice cue; drawing then pauses for full physics.
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
		if DisplayServer.get_name() != "headless":
			RenderingServer.set_render_loop_enabled(false)
		await _play_owned() # Real managed inputs, full match and original outro state flow.
		_check(_choice_captured or DisplayServer.get_name() == "headless",
			"actual native AI choice cue reviewed")
		if DisplayServer.get_name() != "headless":
			RenderingServer.set_render_loop_enabled(false)
		await _wait_sponsor_round()
		RenderingServer.set_render_loop_enabled(true)
		get_window().size = Vector2i(1280, 720)
		_check(_app._result_saved and _app.season.player_results.size() == prepared + 1,
			"actual managed sponsor game settles once after original outro")
		_audit_season()
		var saved: Dictionary = SeasonSave.snapshot(_app.season)
		for field: String in ["version", "policy", "market", "journal", "decision",
			"request", "stats", "choices", "resolver"]:
			var bad: Dictionary = saved.duplicate(true)
			match field:
				"version": bad.version = 51
				"policy": bad.opponents.policy = 7
				"market": bad.opponents.clubs["1"].build.market = 6
				"journal": bad.opponents.clubs["1"].build.events.pop_back()
				"decision": bad.opponents.clubs["1"].decisions.append({"stat": "sponsor", "paid": 0})
				"request": bad.physical.reports[0].request = "0".repeat(64)
				"stats": bad.physical.reports[0].report.performance.values()[0].bb += 1
				"choices": bad.physical.reports[0].report.choices.events.pop_back()
				"resolver": bad.physical.reports[0].report.resolver = PhysicalMatchReport.RESOLVER
			_check(SeasonSave._decode(bad) == null, "altered sponsor " + field + " rejected")
		var committed: Dictionary = _app.season.opponents.to_data()
		_app.open_shop()
		_check(ClubCareer.same(committed, _app.season.opponents.to_data()),
			"human checkout has no counter-shop")
	print("NPC_CHOICE_VISIBLE prepared=", prepared, " ", _choice_probe.summary())
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent choice visible checks passed: "
			+ "actual credited history and managed use.")
	get_tree().quit(0 if _failures == 0 else 1)


func _audit_season() -> void:
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(_app.season)), "whole performance/stock/journal/reward replay agrees")
	for key: String in _app.season.opponents.clubs:
		var club: Dictionary = _app.season.opponents.clubs[key]
		var earned: int = 0
		var spent: int = 0
		var replay: SeasonBuild = SeasonBuild.new(club.build._seed, club.build.roster())
		replay._market = 7
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


func _process(_delta: float) -> void:
	if not is_instance_valid(_app):
		return
	var lab: PitchBatLab = _app.lab
	if lab == null and _app.round_ui != null:
		lab = _app.round_ui.runner._lab
	_choice_probe.observe(lab, _check)
	if DisplayServer.get_name() != "headless" and not _choice_captured and lab == _app.lab \
		and lab != null and lab._pitch_feedback.visible \
		and lab._pitch_feedback.text.begins_with("OPPONENT"):
		_choice_captured = true
		_capture_live_choice(lab)


func _capture_live_choice(lab: PitchBatLab) -> void:
	RenderingServer.set_render_loop_enabled(true)
	_check(get_viewport().get_visible_rect().encloses(lab._pitch_feedback.get_global_rect()),
		"choice cue fits native managed viewport")
	await _capture("opponent-choice-managed-cue")
	RenderingServer.set_render_loop_enabled(false)


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var total: int = 0
	for line: Dictionary in state.performance.snapshot(state).values():
		total += int(line.pa)
	_check(state.ai_choice_events.size() == total,
		"managed AI prepares exactly one controlled role for every completed PA")
	_check(state.ai_choice_events.any(func(row: Dictionary) -> bool:
		return row.mode in ["wide", "anchor"]), "actual managed paid choice was committed")
	for row: Dictionary in state.ai_choice_events:
		var index: int = int(row.half) % 2 if row.role == "bat" else 1 - int(row.half) % 2
		var team: TeamMatchState = state.away_team if index == 0 else state.home_team
		_check(team.ai_sponsor_choices, "managed choices never replace human controls")
	await super._check_outro_and_restart(lab)
