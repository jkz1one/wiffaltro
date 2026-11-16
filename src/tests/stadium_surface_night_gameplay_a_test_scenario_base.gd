extends "res://src/tests/stadium_surface_night_gameplay_a_test_fixture_base.gd"
func _case(id: int) -> Dictionary:
	if id == 28:
		return await _runner_case()
	if id == 29:
		return await _managed_attach_case()
	var partial: bool = (id >= 2 and id <= 5) or id == 10 or id == 11 or id == 13 or id == 14
	var context: Dictionary = _prepared() if partial else _open()
	if context.is_empty():
		return {}
	var lab: PitchBatLab = context.lab
	var owner: StadiumSurfaceNightRuntime = context.owner
	var probe: Dictionary = {"reached": false, "preserved": false, "detail": {}}
	match id:
		1:
			var replacement: BallTrackingVisibility = BallTrackingVisibility.new()
			for key: StringName in StadiumSurfaceNightRuntime.VISIBILITY:
				replacement.set(key, owner._tracking.get(key))
			var before: Dictionary = _visibility(replacement)
			lab._camera_director.tracking_visibility = replacement
			probe.reached = not StadiumSurfaceNightRuntime.action_allowed(lab)
			probe.preserved = (
				lab._camera_director.tracking_visibility == replacement
				and _visibility(replacement) == before
				and owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
			)
		2, 3, 4, 5:
			var field: String = [
				"_pitch_actor", "_camera", "_primary_fielder", "_world_environment"
			][id - 2]
			var stale: Node = lab.get(field)
			stale.free()
			probe.reached = not StadiumSurfaceNightRuntime.install_bound(lab)
			probe.preserved = (
				not is_instance_valid(lab.get(field))
				and owner._phase == StadiumSurfaceNightRuntime.Phase.CONFIGURED
				and not get_viewport().has_meta(StadiumSurfaceNightRuntime.ATLAS)
			)
		6:
			var replacement: Dictionary = _replacement(context)
			probe.reached = not StadiumSurfaceNightRuntime.action_allowed(lab)
			probe.preserved = (
				_untouched(lab, replacement)
				and owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
			)
		7:
			var replacement: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.new()
			lab.set_meta(StadiumSurfaceNightRuntime.OWNER, replacement)
			lab.process_mode = Node.PROCESS_MODE_ALWAYS
			lab.set_process(true)
			probe.reached = not StadiumSurfaceNightRuntime.continue_action(
				lab, owner, context.state
			)
			probe.reached = probe.reached and not StadiumSurfaceNightRuntime.action_allowed(lab)
			probe.preserved = (
				lab.get_meta(StadiumSurfaceNightRuntime.OWNER) == replacement
				and lab.process_mode == Node.PROCESS_MODE_ALWAYS
				and lab.is_processing()
			)
		8, 9:
			var abandoned: Dictionary = StadiumSurfaceNightPreview._shadows(get_viewport())
			var foreign: RefCounted = RefCounted.new()
			if id == 9:
				get_viewport().set_meta(StadiumSurfaceNightRuntime.ATLAS, foreign)
			var replacement: Dictionary = _replacement(context)
			probe.reached = not StadiumSurfaceNightRuntime.continue_action(
				lab, owner, context.state
			)
			probe.preserved = (
				_untouched(lab, replacement)
				and StadiumSurfaceNightPreview._shadows(get_viewport()) == abandoned
				and (
					not get_viewport().has_meta(StadiumSurfaceNightRuntime.ATLAS)
					if id == 8
					else get_viewport().get_meta(StadiumSurfaceNightRuntime.ATLAS) == foreign
				)
			)
			probe.detail = {
				"abandoned_atlas": abandoned,
				"original_atlas": owner._before.shadows,
				"atlas_values_restored": false,
				"own_token_removed": id == 8,
				"replacement_token_preserved": id == 9
			}
			if id == 8:
				# Retire the old lab without resetting abandoned atlas values, then admit
				# a fresh owner that captures those current values as its own baseline.
				_app.lab = null
				lab.queue_free()
				await get_tree().process_frame
				var fresh: Dictionary = _open()
				if fresh.is_empty():
					return {}
				probe.preserved = (
					probe.preserved
					and fresh.owner != owner
					and fresh.owner._before.shadows == abandoned
				)
				await _dispose(fresh)
		10, 11, 12, 13, 14:
			_tree_case(id, context, probe)
		15, 16:
			await _pitch_case(id, context, probe)
		17, 18:
			await _ball_case(id, context, probe)
		19, 20, 21, 22, 23, 24, 25, 26, 27:
			_gameplay_case(id, context, probe)
		30:
			_close_case(context, probe)
	var row: Dictionary = {
		"id": id,
		"name": CASE_NAMES[id - 1],
		"reached": probe.reached,
		"preserved": probe.preserved,
		"detail": probe.detail
	}
	await _dispose(context)
	return row


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _career_values(career: ClubCareer) -> String:
	return _json([career.current, career.runs, career._assets])


func _checkpoint_files(path: String) -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["", ".bak", ".tmp"]:
		result[suffix] = (
			FileAccess.get_file_as_string(path + suffix)
			if FileAccess.file_exists(path + suffix)
			else null
		)
	return result


func _input_seals(owner: StadiumSurfaceNightRuntime) -> Array:
	return [
		owner._paid_generation,
		owner._paid_data,
		owner._paid_state,
		owner._policy_data,
		owner._season_inputs,
		owner._snapshot_data,
		owner._proof_data,
		owner._replay_generation,
		owner._replay_state,
		owner._fixture_id,
		owner._match_seed,
		owner._tier,
		owner._geometry_signature,
		owner._season_seed,
		owner._season_phase,
		owner._season_round,
		owner._career_run,
		owner._replay_run,
		owner._paid_resources.duplicate(),
		owner._replay_resources.duplicate(),
		owner._field_fair,
		owner._field_safe,
		owner._field_deep,
		owner._field_wall,
		owner._field_home_run,
		owner._field_dead
	]


func _presentation(lab: PitchBatLab) -> Dictionary:
	return {
		"environment": lab._world_environment.environment,
		"values":
		StadiumSurfaceNightPreview._environment_values(lab._world_environment.environment),
		"shadows": StadiumSurfaceNightPreview._shadows(get_viewport()),
		"tracking": lab._camera_director.tracking_visibility,
		"visibility": _visibility(lab._camera_director.tracking_visibility),
		"children": lab.get_node("StarterFieldGeometry").get_children(),
		"transform": lab.global_transform
	}


func _installed_inputs(context: Dictionary) -> Dictionary:
	var owner: StadiumSurfaceNightRuntime = context.owner
	var lamps: Array = []
	for row: Dictionary in owner._lamps:
		lamps.append(
			[
				row.lens.material_override,
				row.beam.visible,
				row.working.emission_enabled,
				row.working.emission_energy_multiplier,
				StadiumSurfaceNightPreview._metadata(row.working)
			]
		)
	return {
		"presentation": _presentation(context.lab),
		"geometry": _geometry([owner._property]),
		"material": owner._surface.material_override,
		"pigment": owner._working_material.get_shader_parameter("vertex_pigment_scale"),
		"material_meta": StadiumSurfaceNightPreview._metadata(owner._working_material),
		"lamps": lamps,
		"snapshot": _json(owner._snapshot),
		"proof": _json(owner._proof)
	}


func _tamper_values(context: Dictionary) -> Dictionary:
	var owner: StadiumSurfaceNightRuntime = context.owner
	var paid: ClubAssetLedger = context.lab._stadium_ledger
	return {
		"installed": _installed_inputs(context),
		"paid": StadiumSurfaceNightRuntime._ledger_state(paid),
		"journal": _json(paid.to_data()),
		"generation": paid.mutation_generation(),
		"policy": _json(_season.owned_surface_night),
		"season_inputs": owner._season_state(),
		"state": context.lab._match_state,
		"home_property": _json(_season.home_property),
		"npc_venues": _json(_season.npc_venues),
		"state_stadium": _json(context.lab._match_state.stadium),
		"gameplay":
		[
			context.state.phase,
			context.state.inning,
			context.state.top_half,
			context.state.outs,
			context.state.balls,
			context.state.strikes,
			context.state.plate_appearance_number,
			context.state.elapsed_seconds,
			context.state.away_team.runs,
			context.state.home_team.runs,
			context.state.last_event,
			context.state.winner_name,
			context.lab._throw_number,
			context.lab._pitch_actor.running,
			context.lab._batted_ball
		],
		"replay": StadiumSurfaceNightRuntime._ledger_state(_season._pool_replay_ledger),
		"field_scalar": ContentDB.get_field(PitchBatLab.FIELD_ID).safe_hit_z_m
	}


func _checkpoint_controls(valid: SeasonState, pre_draft: ClubCareer, context: Dictionary) -> void:
	# Isolated, valid round0 persistence controls. No owned sale receipt exists here;
	# actual sale and active managed-home sale remain unqualified.
	var callback_path: String = SeasonSave.path
	var callback_error: String = SeasonSave.last_error
	var callback_files: Dictionary = _checkpoint_files(callback_path)
	var callback_values: Dictionary = _tamper_values(context)
	var callback_seals: Array = _input_seals(context.owner)
	var original: ClubCareer = valid.career
	var original_values: String = _career_values(original)
	var original_backing: Array = [
		original.current, original.runs.duplicate(true), original._assets.duplicate(true)
	]
	var draft_values: String = _career_values(pre_draft)
	var build: SeasonBuild = valid.build
	var build_values: String = _json(build.to_data())
	var expected: Dictionary = SeasonSave.snapshot(valid).duplicate(true)
	var setup_ok: bool = (
		valid != _season
		and valid.round_index == 0
		and valid.picks.size() == 4
		and valid.player_results.is_empty()
		and valid.pending_fixture().away == 0
		and original != pre_draft
		and not ClubCareer.same(
			original_backing, [pre_draft.current, pre_draft.runs, pre_draft._assets]
		)
		and _timing.get("calls", 0) == 128
		and build.cash() == 0
		and build.view().wallet.sponsors.is_empty()
		and build.view().wallet.gear.values().all(
			func(copy: Dictionary) -> bool: return copy.is_empty()
		)
	)
	_check(
		setup_ok, "isolated real round0 and retained pre-draft values follow all 128 timing calls"
	)
	var app: SeasonApp = SeasonApp.new()
	app.season = valid
	var control_path: String = callback_path + ".checkpoint-controls"
	SeasonSave.path = control_path
	var equal_saved: bool = app._checkpoint()
	var cold: SeasonState = SeasonSave.restore() if equal_saved else null
	var equal_retained: bool = (
		equal_saved
		and valid.career == original
		and _career_values(original) == original_values
		and valid.build == build
		and _json(build.to_data()) == build_values
	)
	var equal_cold_exact: bool = (
		cold != null
		and ClubCareer.same(SeasonSave.snapshot(cold), expected)
		and ClubCareer.same(
			[cold.career.current, cold.career.runs, cold.career._assets], original_backing
		)
	)
	_check(
		equal_retained and equal_cold_exact,
		(
			"equal night%d checkpoint preserves raw career identity and cold value closure"
			% int(expected.version)
		)
	)
	var before_failure: Dictionary = _checkpoint_files(control_path)
	var failed_path: String = control_path + "/missing/save.json"
	var failure_absent: bool = (
		not DirAccess.dir_exists_absolute(control_path + "/missing")
		and _checkpoint_files(failed_path).values().all(
			func(value: Variant) -> bool: return value == null
		)
	)
	SeasonSave.path = failed_path  # Existing file is not a directory: actual temporary-open failure.
	var failed_saved: bool = app._checkpoint()
	var failure_refused: bool = (
		failure_absent
		and not failed_saved
		and (
			SeasonSave.last_error
			== "Could not save season. Your current session is still available."
		)
	)
	var failure_unchanged: bool = (
		valid.career == original
		and _career_values(original) == original_values
		and valid.build == build
		and _json(build.to_data()) == build_values
		and _checkpoint_files(control_path) == before_failure
		and _checkpoint_files(failed_path).values().all(
			func(value: Variant) -> bool: return value == null
		)
	)
	_check(
		failure_refused and failure_unchanged,
		"real temporary-open refusal preserves career build bytes and leaves no temporary output"
	)
	SeasonSave.path = control_path
	var retry_saved: bool = app._checkpoint()
	var retry_exact: bool = (
		retry_saved
		and valid.career == original
		and _career_values(original) == original_values
		and valid.build == build
		and _json(build.to_data()) == build_values
		and FileAccess.get_file_as_string(control_path) == before_failure[""]
		and FileAccess.get_file_as_string(control_path + ".bak") == before_failure[""]
		and not FileAccess.file_exists(control_path + ".tmp")
	)
	_check(
		retry_saved and retry_exact,
		"ordinary checkpoint retry succeeds with exact primary backup and original career"
	)
	valid.career = pre_draft  # Genuine earlier career values; no fabricated result or progress.
	var unequal_saved: bool = app._checkpoint()
	cold = SeasonSave.restore() if unequal_saved else null
	var unequal_replaced: bool = (
		unequal_saved and valid.career != pre_draft and _career_values(pre_draft) == draft_values
	)
	var unequal_adopted: bool = (
		unequal_saved
		and ClubCareer.same(
			[valid.career.current, valid.career.runs, valid.career._assets], original_backing
		)
		and not ClubCareer.same(
			[valid.career.current, valid.career.runs, valid.career._assets],
			[pre_draft.current, pre_draft.runs, pre_draft._assets]
		)
		and valid.build == build
		and _json(build.to_data()) == build_values
		and cold != null
		and ClubCareer.same(SeasonSave.snapshot(cold), expected)
	)
	_check(
		unequal_replaced and unequal_adopted,
		"valid unequal draft sync adopts decoded progress without mutating the retained prior career"
	)
	# No early return after path mutation: failure observations still reach restoration.
	valid.career = original
	SeasonSave.path = callback_path
	SeasonSave.last_error = callback_error
	app.free()
	var globals_restored: bool = (
		SeasonSave.path == callback_path
		and SeasonSave.last_error == callback_error
		and _app.season == _season
		and _app.lab == context.lab
	)
	var callback_admitted: bool = StadiumSurfaceNightRuntime.boundary_allowed(context.lab)
	var callback_unchanged: bool = (
		_checkpoint_files(callback_path) == callback_files
		and _tamper_values(context) == callback_values
		and _input_seals(context.owner) == callback_seals
	)
	_check(
		globals_restored and callback_unchanged and callback_admitted,
		(
			"isolated checkpoints restore globals and preserve the separate callback owner source "
			+ "geometry and history"
		)
	)
	_contracts["checkpoint_controls"] = {
		"scope": "isolated_valid_round0",
		"after_timing": _timing.get("calls", 0) == 128,
		"round_index": valid.round_index,
		"fixture_away": valid.pending_fixture().away,
		"actual_sale_qualified": false,
		"managed_home_sale_qualified": false,
		"retained_pre_draft": setup_ok,
		"equal_retained": equal_retained,
		"equal_cold_exact": equal_cold_exact,
		"failure_kind": "temporary_file_open",
		"failure_refused": failure_refused,
		"failure_unchanged": failure_unchanged,
		"retry_succeeded": retry_saved,
		"retry_exact": retry_exact,
		"unequal_replaced": unequal_replaced,
		"unequal_adopted": unequal_adopted,
		"globals_restored": globals_restored,
		"callback_context_unchanged": callback_unchanged,
		"callback_boundary_admitted": callback_admitted,
		"no_games": valid.player_results.is_empty()
	}


func _first_home(season: SeasonState) -> Dictionary:
	var result: Dictionary = {}
	for scheduled: Dictionary in season.schedule:
		if scheduled.home == 0 and (result.is_empty() or scheduled.round < result.round):
			result = scheduled
	return result


func _contract_checks(
	day: SeasonState, day_bytes: String, day_entry: Dictionary, day_fixture: Dictionary
) -> void:
	var scheduled: Dictionary = _first_home(_season)
	var policy: Dictionary = _season.owned_surface_night
	var snapshot: Dictionary = StadiumLayoutSnapshot.for_fixture(_season, scheduled)
	var saved: Dictionary = SeasonSave.snapshot(_season)
	var historical: Dictionary = JSON.parse_string(day_bytes)
	_check(
		(
			day.owned_surface_night.is_empty()
			and StadiumSurfaceNightSnapshot.PUBLIC_READY
			and not StadiumSurfaceNightLayout.PUBLIC_READY
			and not StadiumSurfaceNightLayout.RUNTIME_READY
		),
		"default day stays ordinary while current public time entry remains enabled"
	)
	_check(
		day_entry.version == 8 and day_entry.layout.version == 12,
		"historical owned surface entry8 and layout12 remain exact"
	)
	_check(
		day_fixture.version == 9 and day_fixture.environment.mode == "day",
		"historical fixture9 remains day"
	)
	_check(
		(
			historical.version < 72
			and SeasonSave._decode(historical) != null
			and JSON.stringify(SeasonSave.snapshot(day), "", true, true) == day_bytes
		),
		"native full precision historical payload remains unchanged"
	)
	_check(
		StadiumSurfaceNightSnapshot.valid_policy(policy, _season, _paid),
		"named opt-in binds actual caller season and paid ledger"
	)
	_check(
		(
			snapshot.version == 26
			and ClubCareer.same(StadiumSurfaceNightSnapshot.entry(snapshot), day_entry)
		),
		"fixture26 reconstructs the identical owned entry8"
	)
	_check(
		(
			StadiumSurfaceNightSnapshot.matches_fixture(snapshot, _season, scheduled, _paid)
			and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(_season, scheduled)
		),
		"fixture seed and exact paid prefix are bound"
	)
	var bad: Dictionary = policy.duplicate(true)
	bad.season_seed += 1
	_check(
		not StadiumSurfaceNightSnapshot.valid_policy(bad, _season, _paid),
		"wrong policy seed refused"
	)
	var prefix: ClubAssetLedger = _paid.prefix(0)
	_check(
		prefix != null and not StadiumSurfaceNightSnapshot.matches(snapshot, prefix),
		"unpaid earlier prefix refused"
	)
	bad = snapshot.duplicate(true)
	bad.binding.fixture += 1
	_check(
		not StadiumSurfaceNightSnapshot.matches_fixture(bad, _season, scheduled, _paid),
		"wrong fixture binding refused"
	)
	_check(
		saved.version == 72 and saved.legacy_save_version == historical.version,
		"new save72 retains its explicit historical discriminator"
	)
	var decoded: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(saved, "", true, true))
	)
	_check(
		(
			decoded != null
			and ClubCareer.same(decoded.owned_surface_night, policy)
			and ClubCareer.same(SeasonSave.snapshot(decoded), saved)
		),
		"full precision native save72 roundtrip"
	)
	bad = historical.duplicate(true)
	bad["owned_surface_night"] = policy.duplicate(true)
	_check(SeasonSave._decode(bad) == null, "legacy payload cannot smuggle night policy")
	bad = saved.duplicate(true)
	bad.erase("owned_surface_night")
	_check(SeasonSave._decode(bad) == null, "save72 requires explicit policy")
	bad = saved.duplicate(true)
	bad.version = 72.5
	_check(SeasonSave._decode(bad) == null, "fractional save discriminator refused")
	bad = policy.duplicate(true)
	bad.version = 1.5
	_check(
		not StadiumSurfaceNightSnapshot.policy_shape(bad), "fractional policy discriminator refused"
	)
	_check(
		(
			not StadiumSurfaceNightReport.valid({"version": 24})
			and not StadiumSurfaceNightHumanEvidence.valid({})
		),
		"report and human proof need actual terminal evidence"
	)
	var pending: Array = []
	pending.resize(18)
	_check(
		not StadiumSurfaceNightHumanEvidence.pending_valid(_season, pending),
		"pending18 cannot invent human evidence"
	)
	var paid_before: Dictionary = _paid.to_data()
	var career_before: Dictionary = _season.career.to_data()
	var apply: Dictionary = ClubConstruction.apply_draft(
		_season, _paid.view().stadium_active, _paid.revision()
	)
	var land: Dictionary = ClubConstruction.buy_land(_season, "regulation", _paid.revision())
	_check(
		(
			not apply.get("ok", false)
			and not land.get("ok", false)
			and _paid.to_data() == paid_before
			and _season.career.to_data() == career_before
		),
		"unfinished opted-in home geometry and immutable history refuse workshop changes"
	)
	var away: Dictionary = {}
	for fixture: Dictionary in _season.schedule:
		if fixture.away == 0:
			away = fixture
			break
	_check(
		(
			not away.is_empty()
			and not StadiumSurfaceNightSnapshot.expected(_season, away)
			and not StadiumSurfaceNightSnapshot.is_family(
				StadiumLayoutSnapshot.for_fixture(_season, away)
			)
		),
		"night policy applies only to managed home fixtures"
	)
	_contracts = {
		"day_sha256": day_bytes.sha256_text(),
		"day_entry_version": 8,
		"day_fixture_version": 9,
		"night_fixture_version": 26,
		"save_version": 72,
		"policy_key": snapshot.policy_key,
		"paid_sha256": _json(_paid.to_data()).sha256_text(),
		"native_roundtrip_exact":
		decoded != null and ClubCareer.same(SeasonSave.snapshot(decoded), saved),
		"historical_bytes_exact":
		JSON.stringify(SeasonSave.snapshot(day), "", true, true) == day_bytes
	}


func _funding() -> SeasonState:
	# Existing setup vector: club_career_test._new/_finish and
	# stadium_bleachers_ui_test._fund_bleachers (20 closed champions), followed by
	# stadium_surface_ui_test._fund_surface's explicitly synthetic new-origin assets.
	var club: ClubCareer = ClubCareer.new()
	var completed: SeasonState
	for index in range(20):
		completed = SeasonState.create(37 + index, false, true, true)
		completed.career = club
		if not club.start(completed):
			return null
		for pick in range(4):
			if completed.offers().is_empty() or not completed.choose_player(completed.offers()[0]):
				return null
		while completed.phase != SeasonState.Phase.COMPLETE:
			var scheduled: Dictionary = completed.pending_fixture()
			if (
				scheduled.is_empty()
				or not completed.record_player_result(
					int(scheduled.id),
					0 if scheduled.home == 0 else 1,
					1 if scheduled.home == 0 else 0
				)
			):
				return null
		if not SeasonSave.save(completed):
			return null
		if index < 19:
			club = completed.career.fork()
			if not club.close(completed):
				return null
	return completed


func _measure(context: Dictionary) -> void:
	var samples: Array[float] = []
	var all_admitted: bool = true
	var before: String = _json(context.lab._stadium_ledger.to_data())
	var state: MatchState = context.lab._match_state
	var owner: StadiumSurfaceNightRuntime = context.owner
	for group in range(4):
		for index in range(32):
			var begin: int = Time.get_ticks_usec()
			var admitted: bool = StadiumSurfaceNightRuntime.action_allowed(context.lab)
			samples.append(float(Time.get_ticks_usec() - begin) / 1000.0)
			all_admitted = all_admitted and admitted
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var finite: bool = true
	var total: float = 0.0
	for sample: float in samples:
		finite = finite and is_finite(sample) and sample >= 0
		total += sample
	_check(
		samples.size() == 128 and all_admitted,
		"128 uncached captured-identity/resource/field hot guards admit"
	)
	_check(
		finite and is_finite(total), "native timing operands are finite nonnegative milliseconds"
	)
	var unchanged: bool = (
		context.lab._match_state == state
		and StadiumSurfaceNightRuntime.current(context.lab) == owner
		and _json(context.lab._stadium_ledger.to_data()) == before
	)
	_check(unchanged, "timing preserves exact owner state and paid journal")
	_timing = {
		"calls": samples.size(),
		"groups": 4,
		"calls_per_group": 32,
		"samples_ms": samples,
		"total_ms": total,
		"median_ms": (sorted[63] + sorted[64]) / 2.0,
		"p95_ms": sorted[121],
		"max_ms": sorted[-1],
		"all_admitted": all_admitted,
		"finite_nonnegative": finite,
		"paid_and_owner_unchanged": unchanged,
		"full_validation": false,
		"validation_mode": "captured_identity_resources_and_field_scalars",
		"full_boundary_validation": true,
		"cache": false,
		"threshold_ms": null
	}


func _progress(phase: String) -> void:
	var now: int = Time.get_ticks_usec()
	print(
		(
			"NIGHT_A_PROGRESS "
			+ JSON.stringify(
				{
					"phase": phase,
					"elapsed_ms": float(now - _started_usec) / 1000.0,
					"since_previous_ms": float(now - _progress_usec) / 1000.0,
					"checks": _checks,
					"failures": _failures,
					"completed_cases": _rows.size(),
					"completed_tampers": _tamper_rows.size()
				},
				"",
				true,
				true
			)
		)
	)
	_progress_usec = now


func _purchases(completed: SeasonState) -> ClubAssetLedger:
	var helper: Node = load("res://src/tests/stadium_surface_night_layout_candidate_test.gd").new()
	helper._credits = ClubPlayers.income(completed.career)
	helper._progress = StadiumCareerProgress.capture(completed.career)
	# Same explicitly historical rough-origin declaration as the repaired Surface UI
	# fixture. Retain every earned pennant event and balance; never replace its journal.
	var retained_assets: Dictionary = completed.career._assets.duplicate(true)
	var retained_events: Array = retained_assets.events.duplicate(true)
	var retained_balance: int = completed.career.balance()
	var rough_assets: Dictionary = retained_assets.duplicate(true)
	rough_assets.surface_origin = StadiumSurfaceProgression.ROUGH_ORIGIN
	completed.career._assets = rough_assets
	var paid: ClubAssetLedger = ClubPlayers.assets(completed.career)
	if (
		paid == null
		or paid.revision() != retained_events.size()
		or not ClubCareer.same(paid.to_data().events, retained_events)
		or paid.balance() != retained_balance
		or not paid.surface_owned().is_empty()
		or paid.view().stadium_active.version != 12
		or paid.to_data().has("salvage_origin")
	):
		_check(
			false, "historical rough fixture retains earned journal, balance and exact flat family"
		)
		helper.free()
		return null
	helper._buy(paid, "ST-037", 4, StadiumPurchases.LIGHT_VERSION, helper.LIGHT_REQUEST)
	helper._land(paid, "expanded")
	helper._surface(paid, "grass")
	helper._surface(paid, "ground_prep")
	helper._style(paid, "ST-063b", 1)
	helper._style(paid, "ST-063i", StadiumGroundStyles.PRICE_VERSION)
	var layout: Dictionary = paid.view().stadium_active
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	for index in range(4):
		layout.lights.append(
			{"copy": "purchase:%s:%d" % [helper.LIGHT_REQUEST, index], "site": sites[index]}
		)
	layout.surface = StadiumSurfaceProgression.selection(paid.surface_owned(), true)
	layout.styles.grass = "ST-063b"
	layout.ground = "ST-063i"
	helper._apply(paid, layout)
	_checks += helper._checks
	_failures += helper._failures
	var ok: bool = helper._failures == 0
	helper.free()
	if not ok:
		return null
	completed.career._assets = paid.to_data()
	completed.home_property = StadiumLayoutSnapshot.capture(paid)
	return paid
