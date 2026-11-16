extends Node
## Two full ordinary-controller games in the isolated candidate; not a production fixture report.

var _failures: int = 0
var _report_dir: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--yard-study-report-dir="):
			_report_dir = argument.trim_prefix("--yard-study-report-dir=")
	_position_precision_contract()
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.career = ClubCareer.new()
	if not season.career.start(season):
		_check(false, "ordinary tracked career fixture starts without manufactured purchases")
		get_tree().quit(1)
		return
	for pick in range(4):
		var offers: Array[String] = season.offers()
		if offers.is_empty() or not season.choose_player(offers[0]):
			_check(false, "ordinary tracked fixture completes its draft")
			get_tree().quit(1)
			return
	var before: Dictionary = SeasonSave.snapshot(season)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	if before.is_empty() or ledger == null or _failures > 0:
		_check(false, "source season and real ownership ledger validate before either game")
		get_tree().quit(1)
		return
	var ledger_before: String = JSON.stringify(ledger.to_data(), "", true, true)
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var first: Dictionary = await _game(source, 47, 1)
	if first.is_empty() or _failures > 0:
		get_tree().quit(1)
		return
	var fixture: Dictionary = StadiumYardFixtureStudy.capture(first.venue)
	var path: String = "user://yard-study-fixture-%d.json" % OS.get_process_id()
	if not _save_fixture(path, fixture):
		_check(false, "frozen authoring fixture persists atomically")
		get_tree().quit(1)
		return
	var loaded: Dictionary = StadiumYardFixtureStudy.decode(FileAccess.get_file_as_string(path))
	if loaded.is_empty() or not ClubCareer.same(loaded, fixture):
		_check(false, "saved fixture loads without regenerated or missing pieces")
		DirAccess.remove_absolute(path)
		get_tree().quit(1)
		return
	var second: Dictionary = await _game(source, 47, 2, loaded)
	DirAccess.remove_absolute(path)
	_check(
		not second.is_empty() and first == second
		and JSON.stringify(first, "", true, true) == JSON.stringify(second, "", true, true),
		"same fresh teams, seed and complete candidate reproduce full observed game evidence"
	)
	_check(
		ClubCareer.same(before, SeasonSave.snapshot(season)),
		"detached authoring games do not award or mutate the originating season"
	)
	var after_ledger: ClubAssetLedger = ClubPlayers.assets(season.career) \
		if season.career != null else null
	_check(after_ledger != null and JSON.stringify(after_ledger.to_data(), "", true, true)
		== ledger_before, "exact paid ledger, wallet, stock and reward history remain unchanged")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Yard authoring games passed: two complete real games and exact study replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _game(source: MatchState, seed_value: int, ordinal: int, frozen: Variant = null) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(viewport)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_lab_only", true)
	lab._sky_backdrop_enabled = false
	viewport.add_child(lab)
	var installed: bool = (
		StadiumYardLab.install(lab)
		if frozen == null
		else (StadiumYardLab.install(lab, frozen))
	)
	_check(installed, "full game explicitly installs the requested isolated candidate")
	if _failures > 0:
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		viewport.queue_free()
		await get_tree().process_frame
		return {}
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var venue: Dictionary = property.get_meta("candidate_venue").duplicate(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._configured_match = PhysicalMatchRequest.capture(source)
	if lab._configured_match == null:
		_check(false, "authoring teams start from a fresh copied match")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		viewport.queue_free()
		await get_tree().process_frame
		return {}
	lab._automation = MatchAutomation.new()
	lab._automation.seed = seed_value
	# Automation was attached after the explicit lab opt-in, so adopt the ordinary runner pause mode.
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab._start_new_match()
	var progress: String = ""
	var stalled: int = 0
	var logged: int = -1
	var paused: bool = false
	var start: int = Time.get_ticks_usec()
	for frame in range(144000):
		await get_tree().physics_frame
		var state: MatchState = lab._match_state
		if state.phase == MatchState.Phase.GAME_END:
			break
		var next: String = (
			"%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
		)
		stalled = stalled + 1 if next == progress else 0
		progress = next
		if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
			_check(false, "real candidate game exceeded the ordinary time/progress limit")
			break
		if lab._automation.releases.size() % 25 == 0 and logged != lab._automation.releases.size():
			logged = lab._automation.releases.size()
			print(
				"YARD_GAME_PROGRESS game=",
				ordinal,
				" releases=",
				logged,
				" inning=",
				state.inning,
				" score=",
				state.away_team.runs,
				"-",
				state.home_team.runs
			)
		if not paused and lab._automation.releases.size() >= 3:
			paused = true
			var elapsed: float = state.elapsed_seconds
			var pitch: Vector3 = lab._pitch_actor.global_position
			get_tree().paused = true
			for wait_frame in range(4):
				await get_tree().process_frame
			_check(
				state.elapsed_seconds == elapsed and lab._pitch_actor.global_position == pitch,
				"pause interrupts the full candidate game without hidden motion or clock advancement"
			)
			get_tree().paused = false
	_check(
		lab._match_state.phase == MatchState.Phase.GAME_END,
		"candidate game reaches a real final score, without simulated-result fallback"
	)
	var report: Dictionary = {}
	if lab._match_state.phase == MatchState.Phase.GAME_END:
		report = _capture(lab, venue, seed_value)
		_audit(lab, report)
		_check(
			ClubCareer.same(venue, property.get_meta("candidate_venue")),
			"complete authored field stays frozen for the entire game"
		)
		print(
			"YARD_GAME_COMPLETE game=",
			ordinal,
			" releases=",
			report.releases.size(),
			" score=",
			report.score,
			" simulated_seconds=",
			report.elapsed,
			" wall_ms=",
			(Time.get_ticks_usec() - start) / 1000.0,
			" evidence_sha=",
			JSON.stringify(report, "", true, true).sha256_text()
		)
		if not _report_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(_report_dir)
			var file: FileAccess = FileAccess.open(
				_report_dir.path_join("yard-game-%d.json" % ordinal), FileAccess.WRITE
			)
			_check(file != null, "unqualified authoring evidence file opens")
			if file != null:
				file.store_string(JSON.stringify(report, "", true, true))
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	return report


func _capture(lab: PitchBatLab, venue: Dictionary, seed_value: int) -> Dictionary:
	var plays: Array[Dictionary] = []
	for play: PlayRecord in lab._play_records:
		plays.append(play.to_dict())
	var state: MatchState = lab._match_state
	return {
		"kind": "UNQUALIFIED_YARD_AUTHORING_STUDY",
		"version": "study-v1",
		"seed": seed_value,
		"venue": venue,
		"score": [state.away_team.runs, state.home_team.runs],
		"elapsed": state.elapsed_seconds,
		"inning": state.inning,
		"top": state.top_half,
		"releases": lab._automation.releases.duplicate(true),
		"plays": plays,
		"performance": state.performance.snapshot(state),
		"surfaces": PhysicalStadiumContacts.capture(lab._play_records)
	}


func _audit(lab: PitchBatLab, report: Dictionary) -> void:
	_check(
		(
			report.score[0] != report.score[1]
			and report.releases.size() > 0
			and report.plays.size() == report.releases.size()
		),
		"every real release has one completed play"
	)
	var recorded_runs: int = 0
	var surface_events: int = 0
	for row: Dictionary in report.plays:
		_check(row.result != "pending", "no unfinished play is replaced with a guessed outcome")
		recorded_runs += int(row.runs_scored)
	for row: Dictionary in report.surfaces:
		surface_events += row.events.size()
	_check(
		recorded_runs == report.score[0] + report.score[1],
		"actual play runs reconcile to final score"
	)
	_check(surface_events > 0, "ordinary full play genuinely reaches a candidate physical surface")
	var pitches: int = 0
	for line: Dictionary in report.performance.values():
		pitches += int(line.pitches)
	_check(pitches == report.releases.size(), "player pitch totals reconcile to recorded releases")
	_check(
		PhysicalMatchReport.capture(lab).is_empty() and not PhysicalMatchReport.valid(report),
		"authoring study cannot masquerade as a production fixture or earn rewards"
	)
	var original_bytes: String = JSON.stringify(report, "", true, true)
	var once: Variant = JSON.parse_string(original_bytes)
	var twice: Variant = JSON.parse_string(JSON.stringify(once, "", true, true))
	var restored_once: Dictionary = _restore_position_vectors(once)
	var restored_twice: Dictionary = _restore_position_vectors(twice)
	if restored_once != restored_twice:
		var differences: Array[Dictionary] = []
		_json_differences(restored_once, restored_twice, "$", differences)
		for difference: Dictionary in differences:
			print("YARD_JSON_DIFFERENCE ", JSON.stringify(difference, "", true, true))
	_check(not restored_once.is_empty() and restored_once == restored_twice
		and ClubCareer.same(report, restored_once),
		"complete JSON evidence is exact after restoring only its typed engine position vectors")
	if not restored_once.is_empty():
		for index in range(report.plays.size()):
			for key: String in ["first_ground_position", "resolution_position"]:
				_check(restored_once.plays[index][key] == report.plays[index][key],
					"every restored coordinate equals the original engine float32 value exactly")
	_check(JSON.stringify(report, "", true, true) == original_bytes,
		"raw capture retains every original numeric field and its full-precision JSON bytes")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _save_fixture(path: String, fixture: Dictionary) -> bool:
	# Test-only atomic disk roundtrip: no new production save surface is opened.
	var text: String = StadiumYardFixtureStudy.encode(fixture)
	if text.is_empty():
		return false
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	var recovered: Dictionary = StadiumYardFixtureStudy.decode(
		FileAccess.get_file_as_string(temporary))
	if StadiumYardFixtureStudy.encode(recovered) != text:
		DirAccess.remove_absolute(temporary)
		return false
	return DirAccess.rename_absolute(temporary, path) == OK


func _json_differences(before: Variant, after: Variant, path: String,
	rows: Array[Dictionary]) -> void:
	if rows.size() >= 24:
		return
	if before is Dictionary and after is Dictionary:
		for key: Variant in before:
			if not after.has(key):
				rows.append({"path": path + "." + str(key), "missing_after": true})
			else:
				_json_differences(before[key], after[key], path + "." + str(key), rows)
		for key: Variant in after:
			if not before.has(key):
				rows.append({"path": path + "." + str(key), "extra_after": true})
	elif before is Array and after is Array:
		if before.size() != after.size():
			rows.append({"path": path, "before_count": before.size(), "after_count": after.size()})
		for index in range(mini(before.size(), after.size())):
			_json_differences(before[index], after[index], "%s[%d]" % [path, index], rows)
	elif typeof(before) != typeof(after) or before != after:
		rows.append({"path": path, "before": before, "after": after,
			"before_type": typeof(before), "after_type": typeof(after),
			"before_exact_variant_bytes": var_to_bytes(before).hex_encode(),
			"after_exact_variant_bytes": var_to_bytes(after).hex_encode()})


func _restore_position_vectors(value: Variant) -> Dictionary:
	# Only these two PlayRecord fields are explicitly Vector3 (play_record.gd:46,49).
	# JSON parses decimal components as float64; reconstruct their original engine type.
	if not value is Dictionary or not value.get("plays") is Array:
		return {}
	var result: Dictionary = value.duplicate(true)
	for row: Variant in result.plays:
		if not row is Dictionary:
			return {}
		for key: String in ["first_ground_position", "resolution_position"]:
			if not row.get(key) is Array or row[key].size() != 3:
				return {}
			for component: Variant in row[key]:
				if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
					return {}
			row[key] = Array(PackedFloat32Array(row[key]))
	return result


func _position_precision_contract() -> void:
	# Observed value is IEEE754 float32 0x34700000. Its adjacent value must remain different.
	var exact: float = PackedByteArray([0, 0, 0x70, 0x34]).decode_float(0)
	var adjacent: float = PackedByteArray([1, 0, 0x70, 0x34]).decode_float(0)
	var before: Dictionary = {"plays": [{"first_ground_position": [0, exact, 0],
		"resolution_position": [0, exact, 0]}], "elapsed": 270.733333333416}
	var changed: Dictionary = before.duplicate(true)
	changed.plays[0].first_ground_position[1] = adjacent
	_check(_restore_position_vectors(before) != _restore_position_vectors(changed),
		"even one adjacent representable engine coordinate remains a genuine difference")
	changed = before.duplicate(true)
	changed.elapsed = 270.7333333334161
	_check(_restore_position_vectors(before) != _restore_position_vectors(changed),
		"scalar float64 elapsed evidence is never quantized as a position")
