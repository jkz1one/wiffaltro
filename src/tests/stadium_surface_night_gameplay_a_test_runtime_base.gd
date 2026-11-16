extends "res://src/tests/stadium_surface_night_gameplay_a_test_scenario_base.gd"
func _tamper_case(id: int) -> Dictionary:
	# These are finite A-only mutations after a real, fully validated admission.
	# They never change the saved career or add a production mutation seam.
	var previous_replay: ClubAssetLedger = _season._pool_replay_ledger
	var previous_run: int = _season._npc_replay_run
	if id == 5:
		_season._pool_replay_ledger = _paid.fork()
		_season._npc_replay_run = _season.career.current
		if _season._pool_replay_ledger == null:
			_season._pool_replay_ledger = previous_replay
			_season._npc_replay_run = previous_run
			_check(false, "exact replay ledger setup succeeds")
			return {}
	var context: Dictionary = _open()
	if context.is_empty():
		_season._pool_replay_ledger = previous_replay
		_season._npc_replay_run = previous_run
		return {}
	var lab: PitchBatLab = context.lab
	var owner: StadiumSurfaceNightRuntime = context.owner
	var paid: ClubAssetLedger = lab._stadium_ledger
	var original_night_bound: bool = (
		lab.get_meta(StadiumSurfaceNightRuntime.BOUND, false)
		and StadiumSurfaceNightRuntime.current(lab) == owner
		and owner._state == context.state
	)
	var before: bool = (
		owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and StadiumSurfaceNightRuntime.action_allowed(lab)
		and original_night_bound
	)
	var seals: Array = _input_seals(owner)
	var installed: Dictionary = _installed_inputs(context)
	var proof_before: String = _json(owner._proof)
	var saved_before: String = FileAccess.get_file_as_string(SeasonSave.path)
	var results_before: String = _json(_season.player_results)
	var generation: int = paid.mutation_generation()
	var paid_before: String = _json(paid.to_data())
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var original: Variant
	var copy_key: String = ""
	var scheduled: Dictionary = _season.pending_fixture()
	var mutated: bool = false
	match id:
		1:
			original = paid._events[0].id
			paid._events[0].id = str(original) + "-tampered"
			mutated = (
				paid.mutation_generation() == generation and _json(paid.to_data()) != paid_before
			)
		2:
			copy_key = str(paid._stock.copies.keys()[0])
			original = paid._stock.copies[copy_key].paid
			paid._stock.copies[copy_key].paid = int(original) + 1
			mutated = (
				paid.mutation_generation() == generation
				and _json(paid.to_data()) == paid_before
				and StadiumSurfaceNightRuntime._ledger_state(paid) != owner._paid_state
			)
		3:
			original = _season.owned_surface_night.season_seed
			_season.owned_surface_night.season_seed = int(original) + 1
			mutated = _json(_season.owned_surface_night) != owner._policy_data
		4:
			original = _season.career.runs[0].receipt.total
			_season.career.runs[0].receipt.total = int(original) + 1
			mutated = (
				owner._season_state() != owner._season_inputs
				and _json(paid.to_data()) == paid_before
			)
		5:
			var replay: ClubAssetLedger = _season._pool_replay_ledger
			original = replay._spent
			replay._spent += 1
			mutated = (
				owner._replay_paid == replay
				and replay != paid
				and replay.mutation_generation() == owner._replay_generation
				and StadiumSurfaceNightRuntime._ledger_state(replay) != owner._replay_state
				and _json(paid.to_data()) == paid_before
			)
		6:
			original = scheduled.away
			scheduled.away = int(original) + 1
			_contracts.synthetic_callback_cursor.schedule_edited = true
			mutated = owner._season_state() != owner._season_inputs
		7:
			# Literal const catalogs are recursively read-only in this exact engine.
			# This existing Resource scalar is a genuine live signature dependency.
			original = field.safe_hit_z_m
			field.safe_hit_z_m = float(original) + 0.125
			mutated = (
				field.safe_hit_z_m != original
				and _json(paid.to_data()) != paid_before
				and paid.mutation_generation() == generation
			)
		8:
			var revision: int = paid.revision()
			var result: Dictionary = paid.commit(
				{
					"id": "night-a-sealed-generation",
					"rev": revision,
					"op": "stadium_draft",
					"layout": paid._stadium_draft.duplicate(true)
				}
			)
			mutated = (
				result.ok
				and not result.replayed
				and paid.revision() == revision + 1
				and paid.mutation_generation() == generation + 1
			)
		9:
			# Controlled exhaustion of the existing supported writer, no wrap/reseal.
			paid._mutation_generation = 9223372036854775807
			paid._advance_mutation_generation()
			paid._advance_mutation_generation()
			mutated = paid.mutation_generation() == -1 and _json(paid.to_data()) == paid_before
		10:
			original = {
				"home_property": _season.home_property.duplicate(true),
				"npc_venues": _season.npc_venues.duplicate(true)
			}
			_season.home_property.clear()
			_season.npc_venues.clear()
			mutated = (
				not original.home_property.is_empty()
				and _season.home_property.is_empty()
				and _season.npc_venues.is_empty()
				and owner._season_state() != owner._season_inputs
			)
	var changed: Dictionary = _tamper_values(context)
	var hot_admitted: bool = StadiumSurfaceNightRuntime.action_allowed(lab)
	var hot_unchanged: bool = _tamper_values(context) == changed
	var installed_unchanged: bool = _installed_inputs(context) == installed
	var proof_unchanged: bool = _json(owner._proof) == proof_before
	var export_started_active: bool = false
	var export_invoked: bool = false
	var export_refused: bool = false
	if id == 3:
		# Actual public dump call begins with an active owner and mutated policy.
		# The bounded raw-log reader, not a native invented boolean, proves silence.
		export_started_active = owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		print("NIGHT_A_INVALID_EXPORT_BEGIN")
		PitchBatLabFeelSupport.dump_records(lab)
		export_invoked = true
		print("NIGHT_A_INVALID_EXPORT_END")
		export_refused = (
			owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
			and not PitchBatLabFeelSupport._export_ready(lab)
		)
	var refused: bool = not hot_admitted
	if id <= 6:
		refused = not StadiumSurfaceNightRuntime.boundary_allowed(lab)
	var classification_invoked: bool = false
	if id == 10:
		# Directly exercise the original-night gate before any result/save path.
		refused = not _app._played_field_matches()
		classification_invoked = true
	var unchanged: bool = _tamper_values(context) == changed
	installed_unchanged = installed_unchanged and _installed_inputs(context) == installed
	proof_unchanged = proof_unchanged and _json(owner._proof) == proof_before
	var saved_history_unchanged: bool = (
		FileAccess.get_file_as_string(SeasonSave.path) == saved_before
		and _json(_season.player_results) == results_before
	)
	var seal_unchanged: bool = _input_seals(owner) == seals
	var abandoned: bool = (
		owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
		and not get_viewport().has_meta(StadiumSurfaceNightRuntime.ATLAS)
	)
	var row: Dictionary = {
		"id": id,
		"name": TAMPER_NAMES[id - 1],
		"before": before,
		"mutated": mutated,
		"refused": refused,
		"unchanged": unchanged,
		"seal_unchanged": seal_unchanged,
		"abandoned": abandoned,
		"hot_admitted": hot_admitted,
		"hot_unchanged": hot_unchanged,
		"installed_unchanged": installed_unchanged,
		"proof_unchanged": proof_unchanged,
		"saved_history_unchanged": saved_history_unchanged,
		"refusal_mode":
		(
			"played_field_boundary"
			if id == 10
			else (
				"full_export_boundary"
				if id == 3
				else ("full_boundary" if id <= 6 else "hot_action")
			)
		),
		"generation_before": generation,
		"generation_after": paid.mutation_generation()
	}
	if id == 3:
		row.merge(
			{
				"export_started_active": export_started_active,
				"export_invoked": export_invoked,
				"export_refused": export_refused
			}
		)
	if id == 10:
		row.merge(
			{
				"original_night_bound": original_night_bound,
				"classification_invoked": classification_invoked,
				"classification_restored": false
			}
		)
	# Restore only fixture-owned inputs after the refusal evidence is complete.
	# The abandoned runtime is never refreshed or made active again.
	match id:
		1:
			paid._events[0].id = original
		2:
			paid._stock.copies[copy_key].paid = original
		3:
			_season.owned_surface_night.season_seed = original
		4:
			_season.career.runs[0].receipt.total = original
		5:
			_season._pool_replay_ledger._spent = original
		6:
			scheduled.away = original
		7:
			field.safe_hit_z_m = original
		10:
			_season.home_property = original.home_property
			_season.npc_venues = original.npc_venues
			row.classification_restored = (
				_json(_season.home_property) == _json(original.home_property)
				and _json(_season.npc_venues) == _json(original.npc_venues)
				and owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
			)
			row.unchanged = row.unchanged and row.classification_restored
	await _dispose(context)
	if id == 6:
		_contracts.synthetic_callback_cursor.temporary_schedule_tamper_restored = (
			scheduled.away == original and _json(_season.schedule) == _cursor_before.schedule
		)
		row.unchanged = (
			row.unchanged
			and _contracts.synthetic_callback_cursor.temporary_schedule_tamper_restored
		)
	if id == 7:
		row["catalog_restored"] = (
			ContentDB.get_field(PitchBatLab.FIELD_ID) == field
			and field.safe_hit_z_m == original
			and _json(paid.to_data()) == paid_before
		)
		row.unchanged = row.unchanged and row.catalog_restored
	_season._pool_replay_ledger = previous_replay
	_season._npc_replay_run = previous_run
	return row


func _write_public_evidence() -> void:
	var evidence: Dictionary = {
		"version": 6,
		"scope": "owned-surface-night-gameplay-a",
		"mode": "public-profiles",
		"synthetic_funding": true,
		"earned_history_qualification": false,
		"actual_game_qualification": false,
		"optical_qualification": false,
		"actual_sale_qualification": false,
		"managed_human2_qualification": false,
		"public_ready": StadiumSurfaceNightSnapshot.PUBLIC_READY,
		"planned_checks": PUBLIC_CHECKS,
		"checks": _checks,
		"failures": _failures,
		"proofs": _public_proofs,
		"profiles": _public_profiles,
		"ui":
		{
			"confirmed_signals": _public_confirmed,
			"input": "programmatic_button_signals",
			"physical_mouse_claim": false
		},
		"actual_games": 0,
		"legacy_callback_cases_run": 0,
		"legacy_tamper_cases_run": 0,
		"contracts":
		{
			"save_version": 73,
			"fixture_version": 27,
			"legacy_save_version": 72,
			"legacy_fixture_version": 26,
			"callback_cursor_used": false,
			"current_results_inserted": false,
			"away_and_finals": "their_own_venue_profiles"
		}
	}
	var bytes: PackedByteArray = JSON.stringify(evidence, "", true, true).to_utf8_buffer()
	var file: FileAccess = (
		null
		if _capture_dir.is_empty()
		else FileAccess.open(_capture_dir.path_join(JSON_NAME), FileAccess.WRITE)
	)
	if _capture_dir.is_empty():
		pass
	elif bytes.size() > MAX_BYTES or file == null:
		_check(false, "bounded public-profile evidence file opens")
	else:
		file.store_buffer(bytes)
		file.flush()
		if file.get_error() != OK:
			_check(false, "public-profile evidence write succeeds")
		file.close()
func _write_time_evidence() -> void:
	var evidence: Dictionary = {
		"version": 4,
		"scope": "owned-surface-night-gameplay-a",
		"mode": "time-profiles",
		"synthetic_funding": true,
		"synthetic_progress_tuples": true,
		"earned_history_qualification": false,
		"actual_game_qualification": false,
		"optical_qualification": false,
		"actual_sale_qualification": false,
		"long_extra_gameplay_qualification": false,
		"public_ready": StadiumSurfaceNightSnapshot.PUBLIC_READY,
		"planned_checks": TIME_CHECKS,
		"checks": _checks,
		"failures": _failures,
		"cases": _time_rows,
		"legacy_callback_cases_run": 0,
		"legacy_tamper_cases_run": 0,
		"contracts": _contracts,
		"timing": _timing
	}
	var bytes: PackedByteArray = JSON.stringify(evidence, "", true, true).to_utf8_buffer()
	var file: FileAccess = (
		null
		if _capture_dir.is_empty()
		else FileAccess.open(_capture_dir.path_join(JSON_NAME), FileAccess.WRITE)
	)
	if _capture_dir.is_empty():
		pass
	elif bytes.size() > MAX_BYTES or file == null:
		_check(false, "bounded changed-profile evidence file opens")
	else:
		file.store_buffer(bytes)
		file.flush()
		if file.get_error() != OK:
			_check(false, "changed-profile evidence write succeeds")
		file.close()


# One actual detached future-fixture game; the valid round0 season never advances.
# The human2 envelope below is an explicitly synthetic codec projection, not capture.
func _game_store(name: String, value: String, cap: int) -> bool:
	var bytes: PackedByteArray = value.to_utf8_buffer()
	if _capture_dir.is_empty() or bytes.is_empty() or bytes.size() > cap:
		return false
	var file: FileAccess = FileAccess.open(_capture_dir.path_join(name), FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok


func _write_time_game_evidence() -> void:
	var artifacts: Dictionary = {}
	for name: String in [
		"sunset-report.json", "round0-primary.json", "round0-backup.json", "human2-codec.json"
	]:
		var path: String = _capture_dir.path_join(name)
		if FileAccess.file_exists(path):
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			artifacts[name] = {"bytes": bytes.size(), "sha256": FileAccess.get_sha256(path)}
	var evidence: Dictionary = {
		"version": 5,
		"scope": "owned-surface-night-gameplay-a",
		"mode": "time-game",
		"synthetic_funding": true,
		"earned_history_qualification": false,
		"actual_games": _game_completed,
		"actual_detached_game": _game_completed == 1,
		"managed_human2_capture": false,
		"human2_codec_projection": true,
		"human2_pending_qualification": false,
		"durable_game_history_qualification": false,
		"optical_qualification": false,
		"actual_sale_qualification": false,
		"public_ready": StadiumSurfaceNightSnapshot.PUBLIC_READY,
		"planned_checks": TIME_GAME_CHECKS,
		"checks": _checks,
		"failures": _failures,
		"status": _game_status,
		"error": _game_error,
		"proofs": _game_proofs,
		"fixture": _game_fixture,
		"terminal": _game_terminal,
		"progress": _game_trace,
		"artifacts": artifacts,
		"legacy_callback_cases_run": 0,
		"legacy_tamper_cases_run": 0,
		"contracts":
		{
			"seed": 101,
			"match_seed": 314288,
			"profile": "sunset",
			"save_version": 73,
			"fixture_version": 27,
			"report_version": 25,
			"human_codec_version": 2,
			"policy_version": 2,
			"round_index": 0,
			"current_fixture": 0,
			"game_fixture": 3,
			"cursor_changed": false,
			"results_inserted": false,
			"schedule_edited": false,
			"save_after_game": false,
			"settlement_performed": false,
			"cold_checkpoint_unchanged": _game_proofs.get("cold_no_write", false)
		}
	}
	if not _game_store(JSON_NAME, _json(evidence), MAX_BYTES) and not _capture_dir.is_empty():
		_check(false, "bounded detached-game evidence file writes")


# Public control signals and ordinary API entries; zero games, synthetic funding only.
func _write_evidence() -> void:
	if _group == "public-profiles":
		_write_public_evidence()
		return
	if _group == "time-game":
		_write_time_game_evidence()
		return
	if _group == "time-profiles":
		_write_time_evidence()
		return
	var evidence: Dictionary = {
		"version": 3,
		"scope": "owned-surface-night-gameplay-a",
		"synthetic_funding": true,
		"earned_history_qualification": false,
		"actual_game_qualification": false,
		"optical_qualification": false,
		"public_ready": StadiumSurfaceNightSnapshot.PUBLIC_READY,
		"planned_checks": _planned_checks,
		"checks": _checks,
		"failures": _failures,
		"selection":
		{
			"group": _group,
			"case_ids": _case_ids,
			"tamper_ids": _tamper_ids,
			"shared_checks": 42,
			"unique_union_checks": 132
		},
		"cases": _rows,
		"tamper_cases": _tamper_rows,
		"contracts": _contracts,
		"timing": _timing
	}
	var bytes: PackedByteArray = JSON.stringify(evidence, "", true, true).to_utf8_buffer()
	# A write failure reports the actual partial count; no false terminal success.
	var file: FileAccess = (
		null
		if _capture_dir.is_empty()
		else FileAccess.open(_capture_dir.path_join(JSON_NAME), FileAccess.WRITE)
	)
	if _capture_dir.is_empty():
		pass  # Admission already failed; never write to an implicit working-directory path.
	elif bytes.size() > MAX_BYTES or file == null:
		_check(false, "bounded evidence file opens")
	else:
		file.store_buffer(bytes)
		file.flush()
		if file.get_error() != OK:
			_check(false, "evidence file write succeeds")
		file.close()


func _exercise() -> void:
	SeasonSave.path = "user://owned-surface-night-a-%d.json" % OS.get_process_id()
	_shared_before = StadiumSurfaceNightPreview._shadows(get_viewport())
	var completed: SeasonState = _funding()
	if completed == null:
		_check(false, "closed synthetic funding setup succeeds")
		return
	_progress("funding_complete")
	_paid = _purchases(completed)
	if _paid == null:
		return
	_progress("paid_setup_complete")
	_app = SeasonApp.new()
	add_child(_app)
	_app.set_process(false)
	_app.season = completed
	var seed_value: int = 101
	_app.begin_season(seed_value, true, true, true, true, true, 0)
	var day: SeasonState = _app.season
	if day == completed or day == null:
		_check(false, "real default-day season entry succeeds")
		return
	var day_bytes: String = JSON.stringify(SeasonSave.snapshot(day), "", true, true)
	var day_entry: Dictionary = day.home_property.duplicate(true)
	var day_fixture: Dictionary = StadiumLayoutSnapshot.for_fixture(day, _first_home(day))
	_app.begin_surface_night_season(seed_value, 0)
	_season = _app.season
	if _season == day or _season == null or _season.owned_surface_night.is_empty():
		_check(false, "real named night opt-in entry succeeds")
		return
	# Retain, never mutate, the genuine pre-sync values.
	var pre_draft_career: ClubCareer = _season.career
	for pick in range(4):
		if _season.offers().is_empty() or not _season.choose_player(_season.offers()[0]):
			_check(false, "ordinary four-player draft succeeds")
			return
	if not SeasonSave.save(_season) or _season.round_index != 0:
		_check(false, "real round0 night checkpoint succeeds")
		return
	_paid = ClubPlayers.assets(_season.career)
	_contract_checks(day, day_bytes, day_entry, day_fixture)
	await _surface_guard_contract_checks(pre_draft_career)


func _surface_guard_contract_checks(pre_draft_career: ClubCareer) -> void:
	if _failures > 0:
		return
	_contracts["guard_contract"] = "delivery_boundary_v1"
	_progress("contracts_complete")
	# Root-approved A-only cursor: retain the valid real round0 checkpoint, then
	# use a decoded in-memory copy at the first EXISTING scheduled home round.
	# This decoded callback state is never saved or settled. Separate retained round0
	# checkpoint controls run only after early timing. The later bounded
	# schedule negative temporarily edits one scalar, then proves exact restoration.
	var checkpoint_season: SeasonState = _season  # Separate from the decoded callback copy.
	var round0: Dictionary = SeasonSave.snapshot(_season)
	_season = SeasonSave._decode(JSON.parse_string(_json(round0)))
	if _season == null:
		_check(false, "native round0 checkpoint copy decodes for callback fixture")
		return
	var home: Dictionary = _first_home(_season)
	if home.is_empty():
		_check(false, "ordinary schedule contains an existing home fixture")
		return
	_cursor_before = {
		"save": FileAccess.get_file_as_string(SeasonSave.path),
		"schedule": _json(_season.schedule),
		"results": _json(_season.player_results),
		"career": _json(_season.career.to_data()),
		"policy": _json(_season.owned_surface_night)
	}
	_contracts["synthetic_callback_cursor"] = {
		"before_round": _season.round_index,
		"after_round": int(home.round),
		"fixture_id": int(home.id),
		"results_inserted": false,
		"schedule_edited": false,
		"temporary_schedule_tamper_restored": false,
		"save_after_cursor": false,
		"settlement_after_cursor": false,
		"actual_game_eligibility_qualified": false
	}
	_season.round_index = int(home.round)
	_app.season = _season
	_paid = ClubPlayers.assets(_season.career)
	var normal: Dictionary = _open()
	if normal.is_empty():
		return
	await _measure(normal)  # First fully admitted lab; no retire/reopen cost before timing.
	_write_evidence()
	_progress("timing_complete")
	_checkpoint_controls(checkpoint_season, pre_draft_career, normal)
	_write_evidence()
	_progress("checkpoint_controls_complete")
	var owner: StadiumSurfaceNightRuntime = normal.owner
	_check(
		(
			owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
			and normal.state.phase == MatchState.Phase.PRE_PITCH
			and not normal.lab._pitch_actor.running
		),
		"normal managed entry installs before first delivery"
	)
	var original: Dictionary = _original(owner)
	StadiumSurfaceNightRuntime.retire(normal.lab, "A_NORMAL")
	_check(_restored(normal, original), "exact original resources values and geometry restored")
	var restored: Dictionary = _presentation(normal.lab)
	StadiumSurfaceNightRuntime.retire(normal.lab, "A_IDEMPOTENT")
	_check(
		(
			_presentation(normal.lab) == restored
			and owner._phase == StadiumSurfaceNightRuntime.Phase.RETIRED
		),
		"second retirement is idempotent"
	)
	await _dispose(normal)
	var reopened: Dictionary = _open()
	if reopened.is_empty():
		return
	_check(
		reopened.owner != owner and StadiumSurfaceNightRuntime.action_allowed(reopened.lab),
		"fresh managed owner reopens on the same shared viewport"
	)
	_progress("normal_lifecycle_complete")
	await _dispose(reopened)
	for id in _case_ids:
		var row: Dictionary = await _case(id)
		if row.is_empty():
			return
		_rows.append(row)
		_check(row.reached, "case %02d reaches %s" % [id, CASE_NAMES[id - 1]])
		_check(row.preserved, "case %02d preserves captured and replacement ownership" % id)
		_write_evidence()  # A partial file never satisfies the exact selected-group reader.
		_progress("case_%02d_complete" % id)
	await _surface_tamper_case_checks()


func _surface_tamper_case_checks() -> void:
	for id in _tamper_ids:
		var row: Dictionary = await _tamper_case(id)
		if row.is_empty():
			return
		_tamper_rows.append(row)
		_check(row.before, "tamper %02d admits the original exact inputs" % id)
		_check(
			(
				row.mutated
				and row.refused
				and row.hot_admitted == (id <= 6 or id == 10)
				and (
					id != 3
					or (row.export_started_active and row.export_invoked and row.export_refused)
				)
				and (
					id != 10
					or (
						row.original_night_bound
						and row.classification_invoked
						and row.classification_restored
					)
				)
			),
			"tamper %02d follows explicit %s refusal for %s" % [id, row.refusal_mode, row.name]
		)
		_check(
			(
				row.unchanged
				and row.seal_unchanged
				and row.abandoned
				and row.hot_unchanged
				and row.installed_unchanged
				and row.proof_unchanged
				and row.saved_history_unchanged
			),
			(
				"tamper %02d preserves installed inputs, changed source and saved history without resealing"
				% id
			)
		)
		_write_evidence()
		_progress("tamper_%02d_complete" % id)
	var cursor_unchanged: bool = (
		FileAccess.get_file_as_string(SeasonSave.path) == _cursor_before.save
		and _json(_season.schedule) == _cursor_before.schedule
		and _json(_season.player_results) == _cursor_before.results
		and _json(_season.career.to_data()) == _cursor_before.career
		and _json(_season.owned_surface_night) == _cursor_before.policy
	)
	_contracts.synthetic_callback_cursor["saved_history_unchanged"] = cursor_unchanged
	_check(
		_json(_timing).to_utf8_buffer().size() < MAX_BYTES / 2 and cursor_unchanged,
		"bounded native timing and exact untouched saved history after synthetic callback cursor"
	)


func _public_choices() -> Array[OptionButton]:
	var result: Array[OptionButton] = []
	for child: Node in _app._dialog.find_children("*", "OptionButton", true, false):
		if child is OptionButton and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _public_labels(choice: OptionButton) -> bool:
	return (
		choice.item_count == 3
		and choice.get_item_text(0) == "Day · 13:10"
		and choice.get_item_text(1) == "Sunset · 16:10 (paid four-pole field required)"
		and choice.get_item_text(2) == "Night · 19:10 (paid four-pole field required)"
	)


func _public_proof(name: String, passed: bool) -> void:
	_public_proofs[name] = passed
	_check(passed, "public profile: " + name)


func _time_draft(season: SeasonState) -> bool:
	if season == null:
		_check(false, "time-profile season exists before draft")
		return false
	for pick in range(4):
		if season.offers().is_empty() or not season.choose_player(season.offers()[0]):
			_check(false, "time-profile ordinary draft succeeds")
			return false
	if not SeasonSave.save(season) or season.round_index != 0:
		_check(false, "time-profile real round0 checkpoint succeeds")
		return false
	return true
