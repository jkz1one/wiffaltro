extends "res://src/tests/stadium_surface_night_gameplay_a_test_runtime_base.gd"
func _exercise_public_profiles() -> void:
	SeasonSave.path = "user://owned-surface-night-a-%d.json" % OS.get_process_id()
	_shared_before = StadiumSurfaceNightPreview._shadows(get_viewport())
	var completed: SeasonState = _funding()
	if completed == null:
		_check(false, "public-profile synthetic funding setup succeeds")
		return
	var unlit_data: Dictionary = SeasonSave.snapshot(completed).duplicate(true)
	_paid = _purchases(completed)  # Exactly the existing eight paid checks, once.
	if _paid == null:
		return
	_progress("public_paid_setup_complete")
	var source_values: String = _json(SeasonSave.snapshot(completed))
	var paid_values: String = _json(_paid.to_data())
	_app = SeasonApp.new()
	add_child(_app)
	_app.set_process(false)
	_app.season = completed
	_app.menu.show_home()
	_app._dialog.confirmed.connect(func() -> void: _public_confirmed += 1)
	_public_proof(
		"gates",
		(
			StadiumSurfaceNightSnapshot.PUBLIC_READY
			and not StadiumSurfaceNightLayout.PUBLIC_READY
			and not StadiumSurfaceNightLayout.RUNTIME_READY
		)
	)
	var entries: Array[Button] = []
	for node: Node in _app.menu._body.find_children("*", "Button", true, false):
		if node is Button and node.text == "NEW WORKING SEASON":
			entries.append(node)
	_public_proof("menu", entries.size() == 1 and not entries[0].disabled)
	if entries.size() != 1 or entries[0].disabled:
		return
	await _surface_unlit_profile_checks(completed, unlit_data, source_values, paid_values, entries)


func _surface_unlit_profile_checks(
	completed: SeasonState, unlit_data: Dictionary, source_values: String, paid_values: String,
	entries: Array[Button]
) -> void:
	var before_files: Dictionary = _checkpoint_files(SeasonSave.path)
	var original_career: ClubCareer = completed.career
	entries[0].pressed.emit()
	var choices: Array[OptionButton] = _public_choices()
	_public_proof(
		"choice",
		(
			_app._dialog.visible
			and choices.size() == 1
			and _public_labels(choices[0])
			and choices[0].selected == 0
			and _app._dialog.dialog_text.contains(
				"Away and final parks use their own venue profiles."
			)
		)
	)
	_public_proof(
		"ask_unchanged",
		(
			_app.season == completed
			and completed.career == original_career
			and _json(SeasonSave.snapshot(completed)) == source_values
			and _checkpoint_files(SeasonSave.path) == before_files
			and _public_confirmed == 0
		)
	)
	if choices.size() != 1:
		return
	var old_choice: OptionButton = choices[0]
	_app._dialog.get_cancel_button().pressed.emit()
	await get_tree().process_frame
	_public_proof(
		"cancel",
		(
			not _app._dialog.visible
			and not is_instance_valid(old_choice)
			and _public_choices().is_empty()
			and _public_confirmed == 0
			and _app.season == completed
			and completed.career == original_career
			and _json(SeasonSave.snapshot(completed)) == source_values
			and _checkpoint_files(SeasonSave.path) == before_files
		)
	)
	entries[0].pressed.emit()
	choices = _public_choices()
	_public_proof(
		"reopen",
		(
			_app._dialog.visible
			and choices.size() == 1
			and _public_labels(choices[0])
			and choices[0].selected == 0
			and _public_confirmed == 0
		)
	)
	if choices.size() != 1:
		return
	var policy2_data: Dictionary = {}
	for profile: String in ["sunset", "day", "night"]:
		_app.season = completed
		if profile == "sunset":
			choices[0].select(1)
			_app._dialog.get_ok_button().pressed.emit()
			await get_tree().process_frame
		else:
			_app.begin_surface_time_season(profile, 101, 0)
		_season = _app.season
		var admitted: bool = _season != null and _season != completed
		var snapshot: Dictionary = (
			StadiumSurfaceNightSnapshot.fixture(_season, _first_home(_season)) if admitted else {}
		)
		_public_proof(
			profile + "_entry",
			(
				admitted
				and snapshot.get("version") == 27
				and snapshot.environment.mode == profile
				and (
					snapshot.environment.start_minute
					== StadiumSurfaceNightSnapshot.start_minute(profile)
				)
				and _season.owned_surface_night.version == 2
				and _season.owned_surface_night.mode == profile
				and _public_confirmed == 1
				and (
					profile != "sunset"
					or (not _app._dialog.visible and _public_choices().is_empty())
				)
			)
		)
		if not admitted or snapshot.is_empty() or not _time_draft(_season):
			return
		var saved: Dictionary = SeasonSave.snapshot(_season)
		var raw_before: Dictionary = _checkpoint_files(SeasonSave.path)
		var cold: SeasonState = SeasonSave.restore()
		var cold_ok: bool = cold != null and ClubCareer.same(SeasonSave.snapshot(cold), saved)
		_public_proof(
			profile + "_cold",
			(
				saved.get("version") == 73
				and cold_ok
				and _season.round_index == 0
				and _season.player_results.is_empty()
				and _season.physical != null
				and _season.physical.pending.is_empty()
				and _season.physical.reports.is_empty()
				and _checkpoint_files(SeasonSave.path) == raw_before
			)
		)
		_public_profiles.append(
			{
				"profile": profile,
				"route": "ok_button_signal" if profile == "sunset" else "api",
				"start_minute": StadiumSurfaceNightSnapshot.start_minute(profile),
				"save_version": saved.get("version"),
				"fixture_version": snapshot.get("version"),
				"cold_exact": cold_ok,
				"round": _season.round_index,
				"results": _season.player_results.size()
			}
		)
		if profile == "day":
			policy2_data = saved.duplicate(true)
		_write_evidence()
		_progress("public_%s_complete" % profile)
	var unlit: SeasonState = SeasonSave._decode(JSON.parse_string(_json(unlit_data)))
	if unlit == null:
		_check(false, "retained unlit public-entry context decodes")
		return
	_app.season = unlit
	var unlit_values: String = _json(SeasonSave.snapshot(unlit))
	before_files = _checkpoint_files(SeasonSave.path)
	for dark: String in ["sunset", "night"]:
		_app.begin_surface_time_season(dark, 101, 0)
		_public_proof(
			"unlit_" + dark,
			(
				_app.season == unlit
				and _json(SeasonSave.snapshot(unlit)) == unlit_values
				and _checkpoint_files(SeasonSave.path) == before_files
			)
		)
	_app.begin_surface_time_season("day", 101, 0)
	_public_proof(
		"unlit_day",
		(
			_app.season != null
			and _app.season != unlit
			and _app.season.owned_surface_night.is_empty()
			and SeasonSave.snapshot(_app.season).version < 72
		)
	)
	_app.season = completed
	_app.begin_surface_night_season(101, 0)
	var legacy: SeasonState = _app.season
	if legacy == completed or not _time_draft(legacy):
		return
	var legacy_data: Dictionary = SeasonSave.snapshot(legacy)
	before_files = _checkpoint_files(SeasonSave.path)
	var legacy_cold: SeasonState = SeasonSave.restore()
	var legacy_fixture: Dictionary = StadiumSurfaceNightSnapshot.fixture(
		legacy, _first_home(legacy)
	)
	_public_proof(
		"legacy",
		(
			legacy_data.get("version") == 72
			and legacy_cold != null
			and ClubCareer.same(SeasonSave.snapshot(legacy_cold), legacy_data)
			and legacy_fixture.get("version") == 26
			and legacy_fixture.environment.profile == StadiumSurfaceNightSnapshot.signature()
			and _checkpoint_files(SeasonSave.path) == before_files
		)
	)
	var wrong: Dictionary = legacy_data.duplicate(true)
	wrong.version = 73
	_public_proof("policy1_save73_refused", SeasonSave._decode(wrong) == null)
	wrong = policy2_data.duplicate(true)
	wrong.version = 72
	_public_proof("policy2_save72_refused", SeasonSave._decode(wrong) == null)
	var legacy_values: String = _json(SeasonSave.snapshot(legacy))
	_app.begin_surface_time_season("unsupported", 101, 0)
	_public_proof(
		"unsupported",
		(
			_app.season == legacy
			and _json(SeasonSave.snapshot(legacy)) == legacy_values
			and _checkpoint_files(SeasonSave.path) == before_files
		)
	)
	_public_proof(
		"scope",
		(
			_public_confirmed == 1
			and _public_profiles.size() == 3
			and _json(SeasonSave.snapshot(completed)) == source_values
			and _json(_paid.to_data()) == paid_values
			and legacy.round_index == 0
			and legacy.player_results.is_empty()
			and legacy.physical.pending.is_empty()
			and legacy.physical.reports.is_empty()
			and _checkpoint_files(SeasonSave.path) == before_files
			and _app.lab == null
		)
	)


func _game_proof(name: String, condition: bool) -> bool:
	_game_proofs[name] = condition
	_check(condition, "time-game " + name)
	return condition


func _time_game_finished(report: Dictionary) -> void:
	# Actual report is durable before any terminal assertion or codec construction.
	_game_completed += 1
	_game_report = report.duplicate(true)
	_game_report_written = _game_store("sunset-report.json", _json(_game_report), 16 * 1024 * 1024)
	if not is_instance_valid(_game_lab) or _game_lab._match_state == null:
		return
	var state: MatchState = _game_lab._match_state
	_game_terminal = {
		"elapsed": state.elapsed_seconds,
		"inning": state.inning,
		"top": state.top_half,
		"away_runs": state.away_team.runs,
		"home_runs": state.home_team.runs,
		"plays": _game_lab._play_records.size(),
		"releases": _game_lab._automation.releases.size(),
		"managed": _game_lab._managed_match
	}
	_game_capture_matches = ClubCareer.same(
		[
			report.elapsed,
			report.inning,
			report.top,
			report.away_runs,
			report.home_runs,
			report.performance,
			report.tactics.base,
			report.surfaces
		],
		[
			state.elapsed_seconds,
			state.inning,
			state.top_half,
			state.away_team.runs,
			state.home_team.runs,
			state.performance.snapshot(state),
			state.base_flow.evidence(state),
			PhysicalStadiumContacts.capture(_game_lab._play_records)
		]
	)
	_game_human_capture_empty = (
		StadiumSurfaceNightHumanEvidence.capture(_game_lab, _season).is_empty()
	)
	_game_tactics = SeasonOpponentTactics.evidence(state, state.away_team).duplicate(true)
	var plays: Array = []
	for index in range(_game_lab._play_records.size()):
		var play: PlayRecord = _game_lab._play_records[index]
		plays.append(
			{
				"play": index,
				"half": (play.inning - 1) * 2 + (0 if play.top_half else 1),
				"batter": String(play.batter_id),
				"pitcher": String(play.pitcher_id),
				"recipe": String(play.pitch_id),
				"contact": play.contact_outcome,
				"exit_speed": play.exit_speed_mps,
				"result": String(play.result),
				"balls": play.balls_before,
				"strikes": play.strikes_before,
				"outs": play.outs_before,
				"runs": play.runs_scored
			}
		)
	_game_codec = {
		"version": 2,
		"fixture": int(_game_fixture.id),
		"request": StadiumSurfaceNightHumanEvidence.request_key(_season, _game_fixture),
		"property": report.property.duplicate(true),
		"away_runs": report.away_runs,
		"home_runs": report.home_runs,
		"performance": report.performance.duplicate(true),
		"teams": [report.teams[0].roster.duplicate(), report.teams[1].roster.duplicate()],
		"plays": plays,
		"base": report.tactics.base.duplicate(true),
		"surfaces": report.surfaces.duplicate(true),
		"night": report.night.duplicate(true),
		"clock": report.clock.duplicate(true)
	}
	_game_codec_written = _game_store("human2-codec.json", _json(_game_codec), 8 * 1024 * 1024)
	_write_evidence()


func _time_source_values() -> String:
	return _json(
		[
			_checkpoint_files(SeasonSave.path),
			_season.schedule,
			_season.player_results,
			_season.career.current,
			_season.career.runs,
			_season.career._assets,
			_season.owned_surface_night,
			_paid.to_data()
		]
	)


func _exercise_time_game() -> void:
	SeasonSave.path = "user://owned-surface-night-a-%d.json" % OS.get_process_id()
	_shared_before = StadiumSurfaceNightPreview._shadows(get_viewport())
	var completed: SeasonState = _funding()
	if completed == null:
		_check(false, "detached-game synthetic funding setup succeeds")
		return
	_paid = _purchases(completed)  # Existing eight paid-journal checks, once.
	if _paid == null:
		return
	_app = SeasonApp.new()
	add_child(_app)
	_app.set_process(false)
	_app.season = completed
	_app.begin_surface_time_season("sunset", 101, 0)
	_season = _app.season
	if not _game_proof(
		"entry",
		(
			_season != null
			and _season != completed
			and _season.owned_surface_night.get("version") == 2
			and _season.owned_surface_night.get("mode") == "sunset"
		)
	):
		return
	if not _time_draft(_season):
		return
	_paid = ClubPlayers.assets(_season.career)
	await _surface_time_match_checks()


func _surface_time_match_checks() -> void:
	var saved: Dictionary = SeasonSave.snapshot(_season).duplicate(true)
	var files: Dictionary = _checkpoint_files(SeasonSave.path)
	var cold: SeasonState = SeasonSave.restore()
	var retained: bool = files[""] is String and files[".bak"] is String and files[".tmp"] == null
	if retained:
		retained = (
			_game_store("round0-primary.json", files[""], 8 * 1024 * 1024)
			and _game_store("round0-backup.json", files[".bak"], 8 * 1024 * 1024)
		)
	if not _game_proof(
		"checkpoint",
		(
			retained
			and saved.get("version") == 73
			and cold != null
			and ClubCareer.same(SeasonSave.snapshot(cold), saved)
			and _season.round_index == 0
			and _season.phase == SeasonState.Phase.REGULAR
			and _season.pending_fixture().id == 0
			and _season.pending_fixture().away == 0
			and _season.results.is_empty()
			and _season.player_results.is_empty()
			and _season.physical.reports.is_empty()
			and _season.physical.pending.is_empty()
		)
	):
		return
	_game_fixture = _first_home(_season).duplicate(true)
	var snapshot: Dictionary = StadiumSurfaceNightSnapshot.fixture(_season, _game_fixture)
	if not _game_proof(
		"fixture",
		(
			_game_fixture.get("id") == 3
			and _game_fixture.get("round") == 1
			and _game_fixture.get("home") == 0
			and snapshot.get("version") == 27
			and snapshot.environment.mode == "sunset"
			and snapshot.environment.start_minute == 970
			and StadiumSurfaceNightSnapshot.matches_fixture(snapshot, _season, _game_fixture, _paid)
		)
	):
		return
	var source: MatchState = SeasonPhysicalFixtures.match_for(_season, _game_fixture)
	var seed_value: int = SeasonPhysicalFixtures.seed_for(_season, _game_fixture)
	var request: String = SeasonPhysicalFixtures.request_key(_season, _game_fixture)
	if not _game_proof(
		"request",
		(
			source != null
			and source.phase == MatchState.Phase.PRE_PITCH
			and source.away_team.runs == 0
			and source.home_team.runs == 0
			and ClubCareer.same(source.stadium, snapshot)
			and seed_value == 314288
			and request.length() == 64
			and (source.away_team.ai_base or source.home_team.ai_base)
		)
	):
		return
	var source_values: String = _time_source_values()
	_game_runner = PhysicalMatchRunner.new()
	_game_runner.presentation_enabled = false
	add_child(_game_runner)
	_game_runner.finished.connect(_time_game_finished)
	_game_runner.failed.connect(func(reason: String) -> void: _game_error = reason)
	if not _game_proof(
		"started", _game_runner.start(source, seed_value, PitchBatLab.FIELD_ID, _paid, {}, _season)
	):
		return
	_game_lab = _game_runner._lab
	var played: MatchState = _game_lab._match_state
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(_game_lab)
	if not _game_proof(
		"installed",
		(
			owner != null
			and owner._time_mode
			and owner._time_profile == "sunset"
			and StadiumSurfaceNightRuntime.installed_bound(_game_lab, snapshot)
			and not _game_lab._managed_match
			and _game_lab._automation != null
			and not _game_lab._automation.presentation_enabled
			and _game_runner._viewport.own_world_3d
			and _game_runner._viewport.find_world_3d() != get_viewport().find_world_3d()
		)
	):
		return
	if not await _surface_wait_and_check_time_report(played, owner):
		return
	_game_proof(
		"report_fixture",
		(
			StadiumSurfaceNightReport.matches(_game_report, snapshot, _paid)
			and StadiumSurfaceNightSnapshot.matches_fixture(
				_game_report.property, _season, _game_fixture, _paid
			)
			and ClubCareer.same(
				_game_report.night,
				StadiumSurfaceNightSnapshot.proof(snapshot, _season.owned_surface_night, _paid)
			)
			and _game_report.night.version == 2
			and _game_report.seed == seed_value
			and SeasonPhysicalFixtures.request_key(_season, _game_fixture) == request
		)
	)
	var halves: int = (
		int(_game_report.tactics.base.final.half)
		+ (1 if int(_game_report.tactics.base.final.outs) == 3 else 0)
	)
	_game_proof(
		"terminal_clock",
		(
			StadiumSurfaceNightSnapshot.clock_valid(
				_game_report.clock, snapshot, _game_report.plays, halves
			)
			and _game_report.clock.completed_plays == _game_report.plays.size()
			and _game_report.clock.completed_halves == halves
			and _game_report.clock.start_minute == 970
			and (
				_game_report.clock.elapsed_seconds
				== mini(21600, 15 * _game_report.plays.size() + 120 * halves)
			)
		)
	)
	_game_proof(
		"natural_progress",
		(
			_game_trace.samples > 0
			and _game_trace.active_samples > 0
			and _game_trace.bounded
			and _game_trace.clock_progress_valid
			and _game_trace.advances > 0
			and _game_trace.max_plays > 0
			and _game_trace.max_halves > 0
			and _game_trace.max_progress > 0.0
			and _game_trace.max_progress <= 1.0
			and _game_report.releases.size() > 0
			and _game_report.plays.size() == _game_report.releases.size()
		)
	)
	_game_proof(
		"detached_scope",
		(
			_game_human_capture_empty
			and not _game_terminal.managed
			and _app.lab == null
			and _season.round_index == 0
			and _season.pending_fixture().id == 0
		)
	)
	_game_proof(
		"source_unchanged",
		(
			_time_source_values() == source_values
			and ClubCareer.same(saved, SeasonSave.snapshot(_season))
			and source.phase == MatchState.Phase.PRE_PITCH
			and source.away_team.runs == 0
			and source.home_team.runs == 0
			and source.sure_shot.releases.is_empty()
		)
	)
	_game_proof(
		"checkpoint_bytes",
		(
			_checkpoint_files(SeasonSave.path) == files
			and (
				FileAccess.get_file_as_string(_capture_dir.path_join("round0-primary.json"))
				== files[""]
			)
			and (
				FileAccess.get_file_as_string(_capture_dir.path_join("round0-backup.json"))
				== files[".bak"]
			)
		)
	)
	cold = SeasonSave.restore()
	_game_proof(
		"cold_roundtrip",
		(
			cold != null
			and ClubCareer.same(SeasonSave.snapshot(cold), saved)
			and cold.round_index == 0
			and cold.pending_fixture().id == 0
			and cold.player_results.is_empty()
			and cold.physical.reports.is_empty()
			and cold.physical.pending.is_empty()
			and ClubCareer.same(cold.owned_surface_night, _season.owned_surface_night)
		)
	)
	_game_proof(
		"cold_no_write",
		(
			_checkpoint_files(SeasonSave.path) == files
			and _time_source_values() == source_values
			and SeasonSave.last_error.is_empty()
		)
	)
	_game_proof(
		"runner_cleanup",
		(
			_game_runner._lab == null
			and _game_runner._viewport == null
			and _game_runner.get_child_count() == 0
			and owner._phase == StadiumSurfaceNightRuntime.Phase.RETIRED
		)
	)
	_surface_cold_codec_replay_checks(source_values)


func _surface_cold_codec_replay_checks(source_values: String) -> void:
	if not _game_proof(
		"codec_valid",
		(
			_game_codec_written
			and StadiumSurfaceNightHumanEvidence.valid(_game_codec)
			and StadiumSurfaceNightHumanEvidence.accepts(
				_season,
				_game_fixture,
				_game_codec,
				int(_game_report.away_runs),
				int(_game_report.home_runs),
				_game_report.performance,
				_game_tactics
			)
		)
	):
		return
	var decoded_codec: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(_capture_dir.path_join("human2-codec.json"))
	)
	_game_proof(
		"codec_roundtrip",
		(
			StadiumSurfaceNightHumanEvidence.valid(decoded_codec)
			and ClubCareer.same(decoded_codec, _game_codec)
			and ClubCareer.same(_game_codec.clock, _game_report.clock)
			and ClubCareer.same(_game_codec.base, _game_report.tactics.base)
			and ClubCareer.same(_game_codec.surfaces, _game_report.surfaces)
			and ClubCareer.same(_game_codec.performance, _game_report.performance)
		)
	)
	var bad: Dictionary = _game_codec.duplicate(true)
	bad.clock.elapsed_seconds += 1
	_game_proof("codec_clock_refusal", not StadiumSurfaceNightHumanEvidence.valid(bad))
	bad = _game_codec.duplicate(true)
	bad.version = 1
	_game_proof("codec_version_refusal", not StadiumSurfaceNightHumanEvidence.valid(bad))
	bad = _game_codec.duplicate(true)
	bad.request = "0".repeat(64)
	_game_proof(
		"codec_request_refusal",
		not StadiumSurfaceNightHumanEvidence.accepts(
			_season,
			_game_fixture,
			bad,
			int(_game_report.away_runs),
			int(_game_report.home_runs),
			_game_report.performance,
			_game_tactics
		)
	)
	_game_proof(
		"split_final",
		(
			_game_completed == 1
			and _time_source_values() == source_values
			and _season.results.is_empty()
			and _season.player_results.is_empty()
			and _season.physical.reports.is_empty()
			and _season.physical.pending.is_empty()
			and _season.round_index == 0
			and not StadiumSurfaceNightSnapshot.PUBLIC_READY
		)
	)
	_game_status = "detached_report25_and_unchanged_save73"
	_write_evidence()


func _time_callback_case(kind: String) -> void:
	var context: Dictionary = _open()
	if context.is_empty():
		return
	var owner: StadiumSurfaceNightRuntime = context.owner
	var original: Dictionary = _original(owner)
	var source_values: String = _time_source_values()
	var seals: Array = _input_seals(owner)
	var probe: Dictionary = {"reached": false, "recursive_refused": false, "gameplay": []}
	_check(
		(
			owner._time_profile == "sunset"
			and owner._clock_plays == 0
			and owner._profile_progress == 0.0
			and owner._lamps.size() == 4
			and not owner._lamps[0].beam.visible
		),
		"same-owner %s callback starts before the first Sunset lamp transition" % kind
	)
	owner._lamps[0].beam.visibility_changed.connect(
		func() -> void:
			if probe.reached:
				return
			probe.reached = true
			if kind == "phase":
				context.state.phase = MatchState.Phase.PITCH_IN_FLIGHT
			elif kind == "tuple":
				context.lab._play_records.append(PlayRecord.new())
			else:
				probe.recursive_refused = not StadiumSurfaceNightRuntime.boundary_allowed(
					context.lab
				)
			probe.gameplay = [
				context.state.phase,
				context.lab._play_records.size(),
				context.state.inning,
				context.state.top_half,
				context.lab._pitch_actor.running
			],
		CONNECT_ONE_SHOT
	)
	context.lab._play_records.append(PlayRecord.new())
	var refused: bool = not StadiumSurfaceNightRuntime.boundary_allowed(context.lab)
	var preserved: bool = (
		probe.reached
		and _restored(context, original)
		and owner._clock_plays == 0
		and owner._clock_halves == 0
		and owner._profile_progress == 0.0
		and (
			[
				context.state.phase,
				context.lab._play_records.size(),
				context.state.inning,
				context.state.top_half,
				context.lab._pitch_actor.running
			]
			== probe.gameplay
		)
		and _input_seals(owner) == seals
		and _time_source_values() == source_values
		and (kind != "recursive" or probe.recursive_refused)
	)
	_check(
		refused and preserved,
		(
			(
				"same-owner %s callback refuses later writes and restores owned resources without "
				+ "adopting progress"
			)
			% kind
		)
	)
	_time_rows.append(
		{
			"name": "callback_" + kind,
			"reached": probe.reached,
			"refused": refused,
			"preserved": preserved,
			"recursive_refused": probe.recursive_refused
		}
	)
	await _dispose(context)
	_write_evidence()


func _time_clock_checks(snapshot: Dictionary) -> void:
	for profile: String in ["day", "sunset", "night"]:
		var clock: Dictionary = StadiumSurfaceNightSnapshot.clock(profile, 160, 10)
		var later: Dictionary = StadiumSurfaceNightSnapshot.clock(profile, 200, 12)
		var drift: float = StadiumSurfaceNightSnapshot.drift(profile, clock)
		_check(
			(
				clock.start_minute == StadiumSurfaceNightSnapshot.start_minute(profile)
				and clock.elapsed_seconds == 3600
				and later.elapsed_seconds == 4440
				and clock.rule == "completed-play-half-v1"
				and drift >= 0.0
				and drift <= (0.06 if profile == "sunset" else 0.02)
				and StadiumSurfaceNightSnapshot.drift(profile, later) >= drift
			),
			"%s pure regulation and extra clock stays monotone within authored caps" % profile
		)
	var capped: Dictionary = StadiumSurfaceNightSnapshot.clock("night", 9999, 9999)
	_check(
		(
			capped.elapsed_seconds == 21600
			and StadiumSurfaceNightSnapshot.clock("foreign", 0, 0).is_empty()
			and StadiumSurfaceNightSnapshot.clock("day", -1, 0).is_empty()
		),
		"pure clock saturates and rejects unsupported inputs"
	)
	var plays: Array = [{}, {}]  # Structural count only, never accepted report/history rows.
	var terminal_shape: MatchState = _season.make_match()
	terminal_shape.inning = 5
	terminal_shape.top_half = false
	terminal_shape.outs = 3
	var third_shape: Dictionary = MatchBaseFlow.snapshot(terminal_shape)
	terminal_shape.outs = 1
	var walk_shape: Dictionary = MatchBaseFlow.snapshot(terminal_shape)
	var third_out: Dictionary = StadiumSurfaceNightSnapshot.clock_evidence(
		snapshot, plays, int(third_shape.half) + (1 if int(third_shape.outs) == 3 else 0)
	)
	var walk_off: Dictionary = StadiumSurfaceNightSnapshot.clock_evidence(
		snapshot, plays, int(walk_shape.half) + (1 if int(walk_shape.outs) == 3 else 0)
	)
	var bad: Dictionary = third_out.duplicate(true)
	bad.elapsed_seconds += 1
	_check(
		(
			third_out.completed_halves == 10
			and walk_off.completed_halves == 9
			and third_out.elapsed_seconds - walk_off.elapsed_seconds == 120
			and StadiumSurfaceNightSnapshot.clock_valid(third_out, snapshot, plays, 10)
			and StadiumSurfaceNightSnapshot.clock_valid(walk_off, snapshot, plays, 9)
			and not StadiumSurfaceNightSnapshot.clock_valid(bad, snapshot, plays, 10)
		),
		(
			"structural third-out counts the completed half while walk-off excludes it and altered "
			+ "elapsed refuses"
		)
	)
	_contracts["clock"] = {
		"rule": "completed-play-half-v1",
		"regulation_seconds": 3600,
		"extra_seconds": 4440,
		"saturated_seconds": 21600,
		"third_out": third_out,
		"walk_off": walk_off,
		"structural_only": true,
		"long_extra_gameplay_qualified": false
	}




func _surface_wait_and_check_time_report(
	played: MatchState, owner: StadiumSurfaceNightRuntime
) -> bool:
	_progress("time_game_started")
	var started: int = Time.get_ticks_msec()
	for frame in range(60000):
		await get_tree().physics_frame
		if not _game_runner._running:
			break
		if (
			not is_instance_valid(_game_lab)
			or played.elapsed_seconds >= 900.0
			or Time.get_ticks_msec() - started >= 900000
		):
			_game_error = "Detached game exceeded its existing 900-second game/progress boundary."
			_game_runner.cancel()
			break
		_game_trace.samples += 1
		if owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE:
			_game_trace.active_samples += 1
			_game_trace.bounded = (
				_game_trace.bounded
				and owner._clock_plays <= _game_lab._play_records.size()
				and owner._clock_halves <= (played.inning - 1) * 2 + (0 if played.top_half else 1)
			)
			var changed: bool = (
				owner._clock_plays != _game_trace.max_plays
				or owner._clock_halves != _game_trace.max_halves
			)
			var clock: Dictionary = StadiumSurfaceNightSnapshot.clock(
				"sunset", owner._clock_plays, owner._clock_halves
			)
			var target: float = StadiumSurfaceNightSnapshot.drift("sunset", clock)
			_game_trace.clock_progress_valid = (
				_game_trace.clock_progress_valid
				and owner._clock_plays >= _game_trace.max_plays
				and owner._clock_halves >= _game_trace.max_halves
				and (
					clock.elapsed_seconds
					== mini(21600, 15 * owner._clock_plays + 120 * owner._clock_halves)
				)
				and owner._profile_progress >= _game_trace.max_progress
				and owner._profile_progress <= target
				and owner._profile_progress <= _game_trace.max_progress + 0.002
				and (changed or owner._profile_progress == _game_trace.max_progress)
			)
			_game_trace.advances += 1 if changed else 0
			_game_trace.last_clock = clock
			_game_trace.last_target = target
			_game_trace.max_plays = maxi(_game_trace.max_plays, owner._clock_plays)
			_game_trace.max_halves = maxi(_game_trace.max_halves, owner._clock_halves)
			_game_trace.max_progress = maxf(_game_trace.max_progress, owner._profile_progress)
		if frame % 600 == 0:
			print(
				"NIGHT_A_TIME_GAME inning=",
				played.inning,
				" away=",
				played.away_team.runs,
				" home=",
				played.home_team.runs,
				" releases=",
				_game_lab._automation.releases.size()
			)
	await get_tree().process_frame
	if not _game_proof(
		"completed",
		(
			_game_completed == 1
			and _game_error.is_empty()
			and not _game_runner._running
			and played.phase == MatchState.Phase.GAME_END
		)
	):
		return false
	if not _game_proof(
		"report_retained",
		(
			_game_report_written
			and (
				FileAccess.get_file_as_string(_capture_dir.path_join("sunset-report.json"))
				== _json(_game_report)
			)
		)
	):
		return false
	var decoded_report: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(_capture_dir.path_join("sunset-report.json"))
	)
	if not _game_proof(
		"report_roundtrip",
		(
			PhysicalMatchReport.valid(_game_report)
			and StadiumSurfaceNightReport.valid(decoded_report)
			and ClubCareer.same(_game_report, decoded_report)
			and _game_capture_matches
			and _game_report.version == 25
		)
	):
		return false
	return true
