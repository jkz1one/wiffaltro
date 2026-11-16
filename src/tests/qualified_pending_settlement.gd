extends Node
## Qualified replay from actual untouched legacy/current pending checkpoints.
## No production or authority edits; ordinary pending saves only.

var app: SeasonApp
var output: String
var mode: String
var checks: int = 0
var failures: Array[String] = []
var input_events: int = 0
var held: bool = false
var manual_keys: int = 0
var native: bool = false
var dismissed: bool = false


func _ready() -> void:
	output = OS.get_environment("NPC_QA_OUTPUT")
	mode = OS.get_environment("NPC_QA_MODE")
	native = mode == "native-probe"
	if output.is_empty() or not output.is_absolute_path():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	_write(
		mode + "-harness-source.json",
		{"sha256": FileAccess.get_sha256("res://src/tests/qualified_pending_settlement.gd")}
	)
	SeasonSave.path = output.path_join("season.json")
	PitchBatLabSettings.path = output.path_join("settings.cfg")
	if mode == "resume":
		await _resume()
	else:
		await _play()
	if is_instance_valid(app):
		app.round_ui.cancel()
		app._close_match()
		app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_write(
		mode + "-summary.json",
		{
			"checks": checks,
			"failures": failures,
			"mode": mode,
			"input_events": input_events,
			"manual_keys": manual_keys,
			"native": native,
			"full_manual_game": false
		}
	)
	print(
		"CURRENT_NPC_QA mode=",
		mode,
		" checks=",
		checks,
		" failures=",
		failures.size(),
		" input_events=",
		input_events
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _play() -> void:
	_check(not FileAccess.file_exists(SeasonSave.path), "isolated fresh save")
	app = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	var seed_text: String = OS.get_environment("NPC_QA_SEED")
	var seed_value: int = int(seed_text) if not seed_text.is_empty() else 10
	app.begin_season(seed_value, true, true, true)
	if not _check(
		app.season != null and SeasonSave.snapshot(app.season).version == 63,
		"current ordinary Base63 season starts without historical projection"
	):
		return
	for index in range(4):
		app.choose_player(app.season.offers()[0])
	var before: Dictionary = SeasonSave.snapshot(app.season)
	_write("pregame.json", before)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and ClubCareer.same(before, SeasonSave.snapshot(restored)),
		"current drafted season cold-reloads"
	)
	var fixture: Dictionary = app.season.pending_fixture()
	var expected: Dictionary = SeasonVenues.for_fixture(app.season, fixture)
	_check(fixture.away == 0 and not expected.is_empty(), "actual opening away NPC fixture")
	_write("expected-venue.json", expected)
	app.play_season_game()
	var started_snapshot: Dictionary = SeasonSave.snapshot(app.season)
	_write("post-start.json", started_snapshot)
	if not _check(
		(
			app.lab != null
			and app.lab._automation == null
			and app.lab._managed_match
			and app.lab._npc_season == app.season
			and StadiumPropertyRuntime.npc_installed_bound(app.lab, expected)
		),
		"normal Play installs exact current NPC venue in nonautomated human mode"
	):
		_write(
			"admission-refused.json",
			{
				"notice": app.notice,
				"source_qualified": StadiumNpcPublicRuntime.source_qualified(),
				"saved_unchanged": ClubCareer.same(before, SeasonSave.snapshot(app.season))
			}
		)
		if native:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				output.path_join("native-refused.png")
			)
			print("CURRENT_NPC_NATIVE_REFUSED: inspect actual notice, then Escape")
			var deadline: int = Time.get_ticks_msec() + 180000
			while not dismissed and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
		return
	var lab: PitchBatLab = app.lab
	var state: MatchState = lab._match_state
	print("CURRENT_NPC_START venue=", expected.manifest.id, " fixture=", fixture.id)
	var initial_throw: int = lab._throw_number
	var start: int = Time.get_ticks_msec()
	for frame in range(180000):
		await get_tree().physics_frame
		if native:
			if manual_keys >= 2 and lab._throw_number > initial_throw:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(
					output.path_join("native-pitch.png")
				)
				_check(
					lab._automation == null and state.plate_appearance_number >= 1,
					"cloud keyboard readiness starts an actual pitch without AI input automation"
				)
				_check(
					(
						ClubCareer.same(started_snapshot, SeasonSave.snapshot(app.season))
						and app.season.results.is_empty()
						and app.season.cash() == 0
					),
					"incomplete native game cannot settle or pay beyond ordinary pregame checkpoint"
				)
				_write(
					"native-witness.json",
					{
						"manual_keys": manual_keys,
						"throw_before": initial_throw,
						"throw_after": lab._throw_number,
						"venue": expected.manifest.id,
						"phase": state.phase,
						"automation_null": lab._automation == null
					}
				)
				return
			if Time.get_ticks_msec() - start > 180000:
				_check(false, "native keyboard witness completes within three minutes")
				return
			continue
		if (
			state.phase == MatchState.Phase.GAME_END
			and app._result_recorded
			and not app.season.physical.pending.is_empty()
		):
			break
		_drive(lab)
		if frame % 3600 == 0:
			print(
				"CURRENT_NPC_PLAY frame=",
				frame,
				" inning=",
				state.inning,
				" pitches=",
				lab._play_records.size(),
				" phase=",
				state.phase
			)
	if not _check(
		state.phase == MatchState.Phase.GAME_END and app._result_recorded,
		"input-driven managed game reaches genuine terminal and durable outro"
	):
		return
	var human: Dictionary = StadiumNpcYardTwoHumanEvidence.capture(lab, app.season)
	var report: Dictionary = PhysicalMatchReport.capture(lab)
	_check(
		(
			not human.is_empty()
			and StadiumNpcYardTwoHumanEvidence.valid(human)
			and ClubCareer.same(human.property, StadiumNpcSnapshot.normalized(expected))
			and StadiumNpcYardTwoHumanEvidence.accepts(
				app.season,
				fixture,
				human,
				state.away_team.runs,
				state.home_team.runs,
				state.performance.snapshot(state),
				SeasonOpponentTactics.evidence(state, state.home_team)
			)
		),
		"actual terminal PlayRecords generate exact accepted NPC human evidence"
	)
	_check(
		report.is_empty() and lab._automation == null,
		"managed human terminal cannot masquerade as an automated physical report"
	)
	var pending: Dictionary = SeasonSave.snapshot(app.season)
	_check(
		(
			pending.physical.pending.human.size() == 17
			and ClubCareer.same(human, pending.physical.pending.human[16])
			and app.season.player_results.is_empty()
			and app.season.results.is_empty()
		),
		"outro saves genuine17-field human payload without partial-round payment"
	)
	_check(app.lab == lab and not app.round_ui._working, "outro remains until Continue")
	_write("terminal-human.json", human)
	_write("terminal-report.json", report)
	_write("pending.json", pending)
	_check(
		ClubCareer.same(pending, SeasonSave.snapshot(SeasonSave.restore())),
		"actual pending human game survives disk reload"
	)
	for field: String in ["request", "fixture", "property", "plays"]:
		var bad: Dictionary = pending.duplicate(true)
		bad.physical.pending.human[16].erase(field)
		_check(SeasonSave._decode(bad) == null, "missing human authority rejects: " + field)
	var bad: Dictionary = pending.duplicate(true)
	bad.physical.pending.human[14] = "0".repeat(64)
	_check(SeasonSave._decode(bad) == null, "wrong played venue key rejects")
	_check(
		lab._automation == null and input_events > 0,
		"all human actions used input events, never AI automation or manufactured results"
	)


func _resume() -> void:
	if not _check(
		StadiumNpcPublicRuntime.source_qualified(),
		"exact installed source qualifies pending replay"
	):
		return
	var previous: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(output.path_join("pending.json"))
	)
	var pregame: Dictionary = previous
	app = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	if not _check(
		(
			app.season != null
			and ClubCareer.same(previous, SeasonSave.snapshot(app.season))
			and app.lab == null
			and not app.round_ui._working
		),
		"fresh process restores exact terminal checkpoint without replaying human game"
	):
		return
	var cash_before: int = app.season.cash()
	app.round_ui.resume()
	var start: int = Time.get_ticks_msec()
	while app.round_ui._working and Time.get_ticks_msec() - start < 1200000:
		await get_tree().process_frame
	if not _check(
		(
			app.season.results.size() == 3
			and app.season.player_results.size() == 1
			and app.season.physical.reports.size() == 2
			and app.season.physical.pending.is_empty()
		),
		"two real opponent jobs settle the current NPC round exactly once"
	):
		var blocked: Dictionary = SeasonSave.snapshot(app.season)
		_write(
			"resume-blocked.json",
			{
				"detail": app.round_ui.detail.text,
				"source_qualified": StadiumNpcPublicRuntime.source_qualified(),
				"human_not_replayed": app.lab == null,
				"unchanged_pending": ClubCareer.same(blocked, previous),
				"results": app.season.results.size(),
				"human_results": app.season.player_results.size(),
				"cash": app.season.cash()
			}
		)
		_check(
			(
				ClubCareer.same(blocked, previous)
				and app.season.results.is_empty()
				and app.season.cash() == 0
			),
			"refused opponent job cannot publish or pay a partial round"
		)
		_check(
			ClubCareer.same(blocked, SeasonSave.snapshot(SeasonSave.restore())),
			"refused job retains exact durable human checkpoint for future authorized resume"
		)
		return
	var settled: Dictionary = SeasonSave.snapshot(app.season)
	var result: Dictionary = app.season.player_results[0]
	_check(
		ClubCareer.same(result.yard_evidence, previous.physical.pending.human[16]),
		"settlement preserves exact genuine human evidence across process restart"
	)
	_check(
		(
			ClubCareer.same(settled.npc_venues, pregame.npc_venues)
			and ClubCareer.same(settled.final_venue, pregame.final_venue)
			and ClubCareer.same(settled.home_property, pregame.home_property)
			and ClubCareer.same(settled.career.assets, pregame.career.assets)
		),
		"round cannot rewrite venue assignment or grant owned property"
	)
	_check(
		app.season.cash() == cash_before + (18 if SeasonState._winner(result) == 0 else 12),
		"single human result pays the exact ordinary reward once"
	)
	_check(
		(
			not app.season.record_player_result(
				result.id,
				result.away_runs,
				result.home_runs,
				result.performance,
				[],
				[],
				{},
				[],
				[],
				{},
				{},
				[],
				{},
				[],
				result.property,
				null,
				result.yard_evidence
			)
			and ClubCareer.same(settled, SeasonSave.snapshot(app.season))
		),
		"duplicate human submission cannot pay again or alter settled state"
	)
	_check(
		(
			SeasonSave.save(app.season)
			and SeasonSave.save(app.season)
			and ClubCareer.same(settled, SeasonSave.snapshot(SeasonSave.restore()))
		),
		"repeated public save and cold reload preserve exact settled round"
	)
	for row: Dictionary in app.season.physical.reports:
		var fixture: Dictionary = SeasonVenues.fixture_for_id(app.season, int(row.fixture))
		_check(
			(
				PhysicalMatchReport.valid(row.report)
				and PhysicalStadiumReport.matches(
					row.report, StadiumLayoutSnapshot.for_fixture(app.season, fixture)
				)
			),
			"each opponent job binds its own actual assigned park"
		)
	_write("settled.json", settled)


func _drive(lab: PitchBatLab) -> void:
	if lab._match_state.phase == MatchState.Phase.GAME_END:
		return
	if lab._match_presentation_director.blocks_gameplay():
		_tap()
	elif lab._player_is_batting():
		if lab._awaiting_batter_confirm:
			_tap()
	elif lab._match_state.phase == MatchState.Phase.PRE_PITCH:
		if not lab._release_controller.active and not held:
			_key(true)
			held = true
		elif (
			held
			and (
				lab._release_controller.elapsed_seconds
				>= PitchReleaseController.IDEAL_RELEASE_SECONDS
			)
		):
			_key(false)
			held = false


func _tap() -> void:
	_key(true)
	_key(false)


func _key(pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)
	input_events += 1


func _input(event: InputEvent) -> void:
	if native and event is InputEventKey and event.pressed and not event.echo:
		manual_keys += 1
		dismissed = event.keycode == KEY_ESCAPE
		print("CURRENT_NPC_NATIVE_KEY key=", event.keycode, " count=", manual_keys)


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
	return ok


func _write(name: String, value: Variant) -> void:
	var file: FileAccess = FileAccess.open(output.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "", true, true))
