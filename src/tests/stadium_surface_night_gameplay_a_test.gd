extends "res://src/tests/stadium_surface_night_gameplay_a_test_qualification_base.gd"
func _time_resource_case(kind: String) -> void:
	var context: Dictionary = _open()
	if context.is_empty():
		return
	var owner: StadiumSurfaceNightRuntime = context.owner
	var before: String = _time_source_values()
	var seals: Array = _input_seals(owner)
	_check(
		(
			owner._owned_sky != null
			and owner._owned_sky_material != null
			and StadiumSurfaceNightRuntime.boundary_allowed(context.lab)
		),
		"%s replacement starts with admitted authority" % kind
	)
	var replacement: Resource = Sky.new() if kind == "sky" else ShaderMaterial.new()
	replacement.resource_name = "fixture-owned-foreign-%s" % kind
	if kind == "sky":
		owner._working_environment.sky = replacement as Sky
	else:
		owner._owned_sky.sky_material = replacement as Material
	var refused: bool = not StadiumSurfaceNightRuntime.boundary_allowed(context.lab)
	var untouched: bool = (
		replacement.resource_name == "fixture-owned-foreign-%s" % kind
		and (
			owner._working_environment.sky == replacement
			if kind == "sky"
			else owner._owned_sky.sky_material == replacement
		)
	)
	_check(
		(
			refused
			and untouched
			and owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
			and _input_seals(owner) == seals
			and _time_source_values() == before
		),
		"%s replacement refuses without adopting or changing foreign resources or source" % kind
	)
	_time_rows.append(
		{
			"name": "replace_" + kind,
			"refused": refused,
			"replacement_untouched": untouched,
			"source_unchanged": _time_source_values() == before
		}
	)
	await _dispose(context)
	_write_evidence()


func _time_values(context: Dictionary) -> Dictionary:
	var owner: StadiumSurfaceNightRuntime = context.owner
	var lamps: Array = []
	for row: Dictionary in owner._lamps:
		lamps.append(
			[
				row.beam,
				row.beam.light_energy,
				row.beam.visible,
				row.lens.material_override,
				row.working.emission_enabled,
				row.working.emission_energy_multiplier
			]
		)
	var parameters: Dictionary = {}
	if owner._owned_sky_material != null:
		for key: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
			parameters[key] = owner._owned_sky_material.get_shader_parameter(key)
	return {
		"installed": _installed_inputs(context),
		"lamps": lamps,
		"sky": owner._working_environment.sky,
		"sky_material": owner._owned_sky_material,
		"parameters": parameters,
		"clock": [owner._clock_plays, owner._clock_halves, owner._profile_progress]
	}


func _time_version_checks(saved: Dictionary, snapshot: Dictionary, season: SeasonState) -> void:
	var bad: Dictionary = saved.duplicate(true)
	bad.version = 72
	_check(SeasonSave._decode(bad) == null, "policy2 cannot enter save72")
	bad = saved.duplicate(true)
	bad.owned_surface_night.start_minute += 1
	var bad_rule: Dictionary = saved.duplicate(true)
	bad_rule.owned_surface_night.rule = "foreign-rule"
	_check(
		SeasonSave._decode(bad) == null and SeasonSave._decode(bad_rule) == null,
		"new start-minute and rule tampering refuse cold decode"
	)
	var proof: Dictionary = StadiumSurfaceNightSnapshot.proof(
		snapshot, season.owned_surface_night, ClubPlayers.assets(season.career)
	)
	bad = proof.duplicate(true)
	bad.version = 1
	var wrong_profile: Dictionary = snapshot.duplicate(true)
	wrong_profile.environment.mode = "night"
	_check(
		(
			proof.get("version") == 2
			and StadiumSurfaceNightSnapshot.proof_valid(proof, snapshot)
			and not StadiumSurfaceNightSnapshot.proof_valid(bad, snapshot)
			and not StadiumSurfaceNightSnapshot.proof_valid(proof, wrong_profile)
		),
		"new proof binds its exact version and starting profile"
	)
	_check(
		(
			not StadiumSurfaceNightReport.valid(
				{"version": 25, "property": snapshot, "night": proof}
			)
			and not StadiumSurfaceNightHumanEvidence.valid(
				{"version": 2, "property": snapshot, "night": proof}
			)
		),
		"structural report25 and human2 examples cannot invent terminal gameplay"
	)


func _exercise_time_profiles() -> void:
	SeasonSave.path = "user://owned-surface-night-a-%d.json" % OS.get_process_id()
	_shared_before = StadiumSurfaceNightPreview._shadows(get_viewport())
	var completed: SeasonState = _funding()
	if completed == null:
		_check(false, "changed-profile synthetic funding setup succeeds")
		return
	var unlit_data: Dictionary = SeasonSave.snapshot(completed).duplicate(true)
	_paid = _purchases(completed)  # The existing eight paid-journal checks, once.
	if _paid == null:
		return
	_progress("time_paid_setup_complete")
	_app = SeasonApp.new()
	add_child(_app)
	_app.set_process(false)
	var unlit: SeasonState = SeasonSave._decode(JSON.parse_string(_json(unlit_data)))
	if unlit == null:
		_check(false, "retained ordinary unlit context decodes")
		return
	_app.season = unlit
	var before_unlit: Dictionary = _checkpoint_files(SeasonSave.path)
	var unlit_values: String = _json(SeasonSave.snapshot(unlit))
	for dark: String in ["sunset", "night"]:
		_app.begin_surface_time_season(dark, 101, 0)
		_check(
			(
				_app.season == unlit
				and _checkpoint_files(SeasonSave.path) == before_unlit
				and _json(SeasonSave.snapshot(unlit)) == unlit_values
			),
			"unlit %s refuses before assignment or checkpoint" % dark
		)
	_app.begin_surface_time_season("day", 101, 0)
	_check(
		(
			_app.season != unlit
			and _app.season != null
			and _app.season.owned_surface_night.is_empty()
			and SeasonSave.snapshot(_app.season).version < 72
		),
		"unlit Day retains its ordinary valid entry"
	)
	_app.season = completed
	_app.begin_surface_night_season(101, 0)
	var legacy: SeasonState = _app.season
	if not _time_draft(legacy):
		return
	var legacy_data: Dictionary = SeasonSave.snapshot(legacy)
	var legacy_cold: SeasonState = SeasonSave._decode(JSON.parse_string(_json(legacy_data)))
	_check(
		(
			legacy_data.get("version") == 72
			and legacy_cold != null
			and ClubCareer.same(SeasonSave.snapshot(legacy_cold), legacy_data)
			and StadiumSurfaceNightSnapshot.fixture(legacy, _first_home(legacy)).version == 26
		),
		"legacy72 fixture26 still roundtrips through its old branch"
	)
	var wrong_legacy: Dictionary = legacy_data.duplicate(true)
	wrong_legacy.version = 73
	_check(SeasonSave._decode(wrong_legacy) == null, "policy1 cannot enter save73")
	await _surface_time_profile_entries(completed)


func _surface_time_profile_entries(completed: SeasonState) -> void:
	var sunset_context: SeasonState
	for profile: String in ["day", "sunset", "night"]:
		_app.season = completed
		_app.begin_surface_time_season(profile, 101, 0)
		_season = _app.season
		if _season == null or _season == completed:
			_check(false, "changed profile enters its real season transaction")
			return
		var pre_draft: ClubCareer = _season.career
		if not _time_draft(_season):
			return
		var saved: Dictionary = SeasonSave.snapshot(_season)
		var checkpoint: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
		var scheduled: Dictionary = _first_home(_season)
		var snapshot: Dictionary = StadiumSurfaceNightSnapshot.fixture(_season, scheduled)
		_check(
			(
				saved.get("version") == 73
				and checkpoint != null
				and ClubCareer.same(SeasonSave.snapshot(checkpoint), saved)
				and snapshot.get("version") == 27
				and snapshot.environment.mode == profile
				and (
					snapshot.environment.start_minute
					== StadiumSurfaceNightSnapshot.start_minute(profile)
				)
				and _season.owned_surface_night.version == 2
				and not StadiumSurfaceNightSnapshot.PUBLIC_READY
			),
			"%s enters policy2 fixture27 and canonical save73" % profile
		)
		if checkpoint == null or snapshot.is_empty():
			return
		if profile == "day":
			_time_version_checks(saved, snapshot, _season)
			_time_clock_checks(snapshot)
		# Isolated genuine round0 checkpoint stays separate from this callback copy.
		# This in-memory cursor and its synthetic progress are never saved or settled.
		_season.round_index = int(scheduled.round)
		_app.season = _season
		_paid = ClubPlayers.assets(_season.career)
		if profile == "sunset":
			sunset_context = _season
		var normal: Dictionary = _open()
		if normal.is_empty():
			return
		if profile == "day":
			await _measure(normal)
			_write_evidence()
			_progress("time_early_timing_complete")
			_checkpoint_controls(checkpoint, pre_draft, normal)
		var owner: StadiumSurfaceNightRuntime = normal.owner
		var original: Dictionary = _original(owner)
		var sky_original: Sky = owner._original_sky
		var sky_material_original: Material = owner._original_sky_material
		var sky_values: Dictionary = owner._time_before.duplicate(true)
		var seals: Array = _input_seals(owner)
		var source_values: String = _time_source_values()
		var normal_install: bool = (
			owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
			and normal.state.phase == MatchState.Phase.PRE_PITCH
			and not normal.lab._pitch_actor.running
			and owner._time_mode
			and owner._time_profile == profile
			and owner._clock_plays == 0
			and owner._clock_halves == 0
			and owner._owned_sky != null
			and owner._owned_sky_material != null
			and owner._working_environment.sky == owner._owned_sky
			and owner._time_operands()
		)
		_check(
			normal_install, "%s installs its captured new sky and paid field at PRE_PITCH" % profile
		)
		var before: Dictionary = _time_values(normal)
		var same_tuple: bool = (
			StadiumSurfaceNightRuntime.boundary_allowed(normal.lab)
			and StadiumSurfaceNightRuntime.boundary_allowed(normal.lab)
			and _time_values(normal) == before
		)
		_check(same_tuple, "%s repeats the zero tuple without a presentation update" % profile)
		normal.lab._play_records.append(PlayRecord.new())  # Explicit cosmetic tuple probe, no delivery.
		normal.state.top_half = false
		var advanced: bool = StadiumSurfaceNightRuntime.boundary_allowed(normal.lab)
		var progress: float = owner._profile_progress
		var lamps_ok: bool = owner._lamps.size() == 4 and owner._time_operands()
		for lamp: Dictionary in owner._lamps:
			lamps_ok = (
				lamps_ok
				and lamp.model.get_meta("stadium_item", "") == "ST-037"
				and lamp.beam.light_energy >= 0.0
				and lamp.beam.light_energy <= lamp.beam_energy
				and (
					lamp.beam.light_energy == 0.0
					if profile == "day"
					else lamp.beam.light_energy > 0.0
				)
			)
		_check(
			(
				advanced
				and owner._clock_plays == 1
				and owner._clock_halves == 1
				and progress > 0.0
				and progress <= 0.002
				and lamps_ok
				and _input_seals(owner) == seals
				and _time_source_values() == source_values
			),
			"%s advances one bounded step using only four owned lamps" % profile
		)
		before = _time_values(normal)
		normal.lab._play_records.append(PlayRecord.new())
		normal.state.phase = MatchState.Phase.PITCH_IN_FLIGHT
		normal.lab._pitch_actor.running = true
		var pitch_frozen: bool = (
			StadiumSurfaceNightRuntime.boundary_allowed(normal.lab)
			and _time_values(normal) == before
		)
		normal.lab._pitch_actor.running = false
		normal.state.phase = MatchState.Phase.BALL_IN_PLAY
		var body: BattedBallBody = BattedBallBody.new()
		normal.lab._batted_ball = body
		var body_frozen: bool = (
			StadiumSurfaceNightRuntime.boundary_allowed(normal.lab)
			and _time_values(normal) == before
		)
		normal.lab._batted_ball = null
		body.free()
		normal.state.phase = MatchState.Phase.PRE_PITCH
		_check(
			pitch_frozen and body_frozen,
			"%s leaves the applied palette frozen through live pitch/body" % profile
		)
		var caught_up: bool = StadiumSurfaceNightRuntime.boundary_allowed(normal.lab)
		var caught: Dictionary = _time_values(normal)
		_check(
			(
				caught_up
				and owner._clock_plays == 2
				and owner._profile_progress >= progress
				and owner._profile_progress <= progress + 0.002
				and StadiumSurfaceNightRuntime.boundary_allowed(normal.lab)
				and _time_values(normal) == caught
			),
			"%s advances at the next safe tuple and is then idempotent" % profile
		)
		StadiumSurfaceNightRuntime.retire(normal.lab, "TIME_NORMAL")
		var restored: bool = (
			_restored(normal, original)
			and original.environment.sky == sky_original
			and (
				sky_original == null
				or (
					sky_original.sky_material == sky_material_original
					and owner._original_sky_values() == sky_values.sky_values
				)
			)
		)
		for lamp: Dictionary in owner._lamps:
			restored = restored and lamp.beam.light_energy == lamp.beam_energy
		_check(
			restored and _input_seals(owner) == seals and _time_source_values() == source_values,
			"%s restores original sky material lamp energy and source authority" % profile
		)
		_time_rows.append(
			{
				"name": profile,
				"normal_install": normal_install,
				"same_tuple": same_tuple,
				"advanced": advanced,
				"lamps_owned": lamps_ok,
				"pitch_frozen": pitch_frozen,
				"body_frozen": body_frozen,
				"caught_up": caught_up,
				"restored": restored,
				"synthetic_progress_only": true,
				"actual_game": false
			}
		)
		await _dispose(normal)
		_write_evidence()
		_progress("time_%s_complete" % profile)
	if sunset_context == null:
		return
	_season = sunset_context
	_app.season = _season
	_paid = ClubPlayers.assets(_season.career)
	var final_source: String = _time_source_values()
	for resource_kind: String in ["sky", "sky_material"]:
		await _time_resource_case(resource_kind)
	for callback_kind: String in ["phase", "tuple", "recursive"]:
		await _time_callback_case(callback_kind)
	_check(
		(
			_time_source_values() == final_source
			and _season.player_results.is_empty()
			and _season.physical.reports.is_empty()
		),
		"all focused probes leave saved history and source authority unchanged"
	)
	_contracts["mode"] = "changed_time_profiles"
	_contracts["legacy_save_version"] = 72
	_contracts["save_version"] = 73
	_contracts["fixture_version"] = 27
	_contracts["synthetic_callback_cursor"] = true
	_contracts["callback_state_saved"] = false
	_contracts["actual_sale_qualified"] = false
	_contracts["terminal_examples"] = "structural_only_no_report25_or_human2_game_claim"


func _finish_cleanup() -> void:
	if is_instance_valid(_app):
		_app.set_process(false)
		for child: Node in _app.get_children():
			if child is PitchBatLab:
				var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(child)
				if owner != null and owner._lab != null and owner._lab.get_ref() == child:
					StadiumSurfaceNightRuntime.retire_captured(child, owner)
				else:
					child.remove_meta(StadiumSurfaceNightRuntime.OWNER)
		_app.lab = null
		_app.queue_free()
	await get_tree().process_frame
	if not _shared_before.is_empty():
		get_viewport().remove_meta(StadiumSurfaceNightRuntime.ATLAS)
		_restore_shared_atlas()


func _finish_time_game() -> void:
	if is_instance_valid(_game_runner):
		_game_runner.cancel()
		_game_runner.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	_started_usec = Time.get_ticks_usec()
	_progress_usec = _started_usec
	_save_path = SeasonSave.path
	_case_ids.assign(range(1, 31))
	_tamper_ids.assign(range(1, 11))
	var selector_seen: bool = false
	var selector_valid: bool = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
		elif argument.begins_with("--night-a-group="):
			if selector_seen:
				selector_valid = false
			selector_seen = true
			_group = argument.trim_prefix("--night-a-group=")
	if selector_seen:
		match _group:
			"g1":
				_case_ids.assign(range(1, 11))
				_tamper_ids.clear()
			"g2":
				_case_ids.assign(range(11, 19))
				_tamper_ids.clear()
			"g3":
				_case_ids.assign(range(19, 31))
				_tamper_ids.clear()
			"g4":
				_case_ids.clear()
			"time-profiles", "time-game", "public-profiles":
				_case_ids.clear()
				_tamper_ids.clear()
			_:
				selector_valid = false
	_planned_checks = (
		TIME_CHECKS
		if _group == "time-profiles"
		else 42 + 2 * _case_ids.size() + 3 * _tamper_ids.size()
	)
	if _group == "time-game":
		_planned_checks = TIME_GAME_CHECKS
	if _group == "public-profiles":
		_planned_checks = PUBLIC_CHECKS
	if not selector_valid:
		_check(false, "one closed night A group selector is required when supplied")
	elif _capture_dir.is_empty():
		_check(false, "explicit evidence directory required")
	else:
		if _group == "public-profiles":
			await _exercise_public_profiles()
		elif _group == "time-game":
			await _exercise_time_game()
		elif _group == "time-profiles":
			await _exercise_time_profiles()
		else:
			await _exercise()
	if _group == "time-game":
		await _finish_time_game()
	await _finish_cleanup()
	await TestAudioDrain.finish(get_tree())
	_write_evidence()
	SeasonSave.path = _save_path
	print("OWNED_SURFACE_NIGHT_GAMEPLAY_A checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
