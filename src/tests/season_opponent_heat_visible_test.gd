extends "res://src/tests/season_opponent_sponsors_visible_test.gd"
## Actual preparation matches, then a managed game against a genuinely paid supply club.

var _heat_probe: OpponentHeatProbe = OpponentHeatProbe.new()
var _tactical_probe: OpponentTacticalProbe = OpponentTacticalProbe.new()
var _choice_captured: bool = false
var _managed_heat_before: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://tactical-visible-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://tactical-visible-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.begin_season(443, true)
	_check(_app.season.opponents._format == 10, "ordinary Working policy10")
	for pick in range(4):
		_app.choose_player(_app.season.offers()[0])
	# Only test preparation drawing is omitted; fixed-step gameplay keeps running.
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	var prepared: int = 0
	var upgraded: bool = false
	for round_number in range(10):
		var fixture: Dictionary = _app.season.pending_fixture()
		var report: Dictionary = await _human_report(_app.season, fixture)
		if report.is_empty():
			break
		_app.round_ui.begin(
			[
				fixture.id,
				report.away_runs,
				report.home_runs,
				report.performance,
				[],
				[],
				{},
				[],
				[],
				{},
				{},
				[],
				_opponent_row(report, fixture)
			]
		)
		await _wait_sponsor_round()
		prepared += 1
		_audit_season()
		var next: Dictionary = _app.season.pending_fixture()
		var opponent: int = next.away if next.home == 0 else next.home
		upgraded = _app.season.opponents.clubs[str(opponent)].build._bank.view().held.any(
			func(copy: Dictionary) -> bool: return copy.item == SeasonTacticalCatalog.HEAT
		)
		if upgraded:
			break
	RenderingServer.set_render_loop_enabled(true)
	_check(upgraded, "actual next opponent bought held supply from earned match rewards")
	if upgraded:
		_prior_results = prepared
		_app.menu.show_lineup()
		await _review("opponent-heat-managed-pregame")
		# Native review captures the actual choice cue; drawing then pauses for full physics.
		get_window().size = Vector2i(700, 400)
		await get_tree().process_frame
		_app.play_season_game()
		var fixture: Dictionary = _app.season.pending_fixture()
		var opponent: int = fixture.away if fixture.home == 0 else fixture.home
		var club: Dictionary = _app.season.opponents.clubs[str(opponent)]
		var team: TeamMatchState = (
			_app.lab._match_state.away_team
			if fixture.away == opponent
			else _app.lab._match_state.home_team
		)
		for player: PlayerMatchState in team.roster:
			_check(
				(
					player.definition.season_sponsors
					== club.build.definition(String(player.definition.id)).season_sponsors
				),
				"exact paid passive sponsors reach managed roster"
			)
		if DisplayServer.get_name() != "headless":
			RenderingServer.set_render_loop_enabled(false)
		_managed_heat_before = _heat_probe.releases
		await _play_owned()  # Real managed inputs, full match and original outro state flow.
		_check(
			_choice_captured or DisplayServer.get_name() == "headless",
			"actual native AI supply cue reviewed"
		)
		if DisplayServer.get_name() != "headless":
			RenderingServer.set_render_loop_enabled(false)
		await _wait_sponsor_round()
		RenderingServer.set_render_loop_enabled(true)
		get_window().size = Vector2i(1280, 720)
		_check(
			_app._result_saved and _app.season.player_results.size() == prepared + 1,
			"actual managed supply game settles once after original outro"
		)
		_audit_season()
		var saved: Dictionary = SeasonSave.snapshot(_app.season)
		for field: String in [
			"version",
			"policy",
			"market",
			"journal",
			"decision",
			"request",
			"stats",
			"choices",
			"resolver",
			"tactics",
			"held",
			"human"
		]:
			var bad: Dictionary = saved.duplicate(true)
			match field:
				"version":
					bad.version = 53
				"policy":
					bad.opponents.policy = 9
				"market":
					bad.opponents.clubs["1"].build.market = 8
				"journal":
					bad.opponents.clubs["1"].build.events.pop_back()
				"decision":
					bad.opponents.clubs["1"].decisions.append({"stat": "sponsor", "paid": 0})
				"request":
					bad.physical.reports[0].request = "0".repeat(64)
				"stats":
					bad.physical.reports[0].report.performance.values()[0].bb += 1
				"choices":
					bad.physical.reports[0].report.choices.events.pop_back()
				"resolver":
					bad.physical.reports[0].report.resolver = PhysicalMatchReport.RESOLVER
				"tactics":
					bad.physical.reports[0].report.tactics.teams[0].featured = "foreign"
				"held":
					bad.physical.reports[0].report.tactics.teams[0].initial.append(
						{"id": "foreign", "item": "A10", "paid": 3, "kind": "held"}
					)
				"human":
					bad.results[-1].ai_tactics.values()[0].consumed.clear()
			_check(SeasonSave._decode(bad) == null, "altered sponsor " + field + " rejected")
		var committed: Dictionary = _app.season.opponents.to_data()
		_app.open_shop()
		_check(
			ClubCareer.same(committed, _app.season.opponents.to_data()),
			"human checkout has no counter-shop"
		)
	_check(_heat_probe.releases > 0, "actual managed or round Heat releases observed")
	print(
		"NPC_HEAT_VISIBLE prepared=",
		prepared,
		" ",
		_heat_probe.summary(),
		" ",
		_tactical_probe.summary()
	)
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro opponent Heat visible checks passed: "
				+ "actual credited history and managed use."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _audit_season() -> void:
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and ClubCareer.same(SeasonSave.snapshot(restored), SeasonSave.snapshot(_app.season))
		),
		"whole performance/stock/journal/reward replay agrees"
	)
	for key: String in _app.season.opponents.clubs:
		var club: Dictionary = _app.season.opponents.clubs[key]
		var earned: int = 0
		var spent: int = 0
		var replay: SeasonBuild = SeasonBuild.new(club.build._seed, club.build.roster())
		replay._market = 9
		for event: Dictionary in club.build.to_data().events:
			var owns_walk: bool = replay._bank.view().sponsors.any(
				func(receipt: Dictionary) -> bool: return receipt.item == "D01"
			)
			_check(replay.commit(event).ok, "actual acquisition event replay commits")
			if event.op == "reward":
				earned += 18 if event.win else 12
				var walks: int = 0
				for id: String in club.build.roster():
					walks += int(event.performance[id].bb)
				var income: int = mini(2, walks) * 2 if owns_walk else 0
				_check(
					int(club.build.income_for_game(int(event.game)).get("D01", 0)) == income,
					"income uses actual own walks and ownership preceding that game"
				)
				earned += income
				var matches: Array = _app.season.results.filter(
					func(row: Dictionary) -> bool: return row.id == event.game
				)
				var fixture: Dictionary = matches[0]
				_check(
					ClubCareer.same(event.performance, fixture.performance),
					"own reward uses the exact completed fixture statistics"
				)
				_check(
					ClubCareer.same(event.tactics, fixture.ai_tactics[key].consumed),
					"own reward consumes exact completed-fixture copies once"
				)
			spent += 4 if event.op == "reroll" else 8 if event.op == "pack_skip" else 0
		for decision: Dictionary in club.decisions:
			spent += int(decision.paid)
		_check(
			club.build.cash() == earned - spent,
			"actual base/earned sponsor income and all debits reconcile"
		)


func _process(_delta: float) -> void:
	if not is_instance_valid(_app):
		return
	var lab: PitchBatLab = _app.lab
	if lab == null and _app.round_ui != null:
		lab = _app.round_ui.runner._lab
	_tactical_probe.observe(lab, _check)
	_heat_probe.observe(lab, _check)
	if (
		DisplayServer.get_name() != "headless"
		and not _choice_captured
		and lab == _app.lab
		and lab != null
		and lab._pitch_feedback.visible
		and (lab._pitch_feedback.text.begins_with("OPPONENT EXTRA HEAT"))
	):
		_choice_captured = true
		_capture_live_choice(lab)


func _capture_live_choice(lab: PitchBatLab) -> void:
	RenderingServer.set_render_loop_enabled(true)
	_check(
		get_viewport().get_visible_rect().encloses(lab._pitch_feedback.get_global_rect()),
		"choice cue fits native managed viewport"
	)
	await _capture("opponent-heat-managed-cue")
	RenderingServer.set_render_loop_enabled(false)


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var fixture: Dictionary = _app.season.pending_fixture()
	var team: TeamMatchState = state.away_team if fixture.home == 0 else state.home_team
	var proof: Dictionary = SeasonOpponentTactics.evidence(state, team)
	var used: bool = false
	for action: Dictionary in proof.consumed:
		for copy: Dictionary in proof.initial:
			if copy.id == action.receipt and copy.item == SeasonTacticalCatalog.HEAT:
				used = true
	_check(
		used and _heat_probe.releases > _managed_heat_before,
		"actual managed paid Heat consumption and physical release were observed"
	)

	_check(
		PhysicalTacticalEvidence.human_matches(
			_app.season, fixture, proof, state.performance.snapshot(state)
		),
		"managed use binds pregame ownership and policy"
	)
	await super._check_outro_and_restart(lab)


func _review(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for node: Node in _app.menu._body.find_children("*", "Label", true, false):
		if node.has_meta("opponent_tactical_owned"):
			var scroll: ScrollContainer = _app.menu._body.get_parent()
			scroll.ensure_control_visible(node.get_parent())
			await get_tree().process_frame
			await _capture(label)
			get_window().size = Vector2i(700, 400)
			await get_tree().process_frame
			await get_tree().process_frame
			scroll.ensure_control_visible(node)
			await get_tree().process_frame
			_check(
				get_viewport().get_visible_rect().encloses(_app.menu._footer.get_global_rect()),
				"narrow held-card disclosure preserves navigation"
			)
			await _capture(label + "-small")
			get_window().size = Vector2i(1280, 720)
			return
	_check(false, "actual next opponent's paid held copy is disclosed")


func _opponent_row(report: Dictionary, fixture: Dictionary) -> Dictionary:
	return report.tactics.teams[0 if fixture.home == 0 else 1]
