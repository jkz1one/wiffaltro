extends Node
## Two ordinary-controller full games per retained revision, with exact unqualified evidence replay.
## This harness does not publish NPC fixture authority, production reports or certificates.

@export var candidate_v2: bool = false

var _kind: String = "UNQUALIFIED_NPC_RETAINED_RUNTIME_QUALIFICATION"
var _version: String = "retained-runtime-qualification-v1"

var _revision: int = 1
var _runtime: Script = StadiumNpcRetainedRuntime
var _definitions: Script = StadiumNpcVenues
var _failures: int = 0
var _report_dir: String = ""
var _venues: Array[String] = ["AY-01", "AE-01", "AC-01"]


func _ready() -> void:
	if candidate_v2:
		_revision = 2
		_runtime = StadiumNpcCandidateRuntimeV2
		_definitions = StadiumNpcCandidatesV2
		_kind = "UNQUALIFIED_NPC_CANDIDATE_R2_RUNTIME_QUALIFICATION"
		_version = "candidate-r2-runtime-qualification-v1"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arguments()
	_position_precision_contract()
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.career = ClubCareer.new()
	if not season.career.start(season):
		_check(false, "ordinary tracked season starts without manufactured purchases")
		get_tree().quit(1)
		return
	for pick in range(4):
		var offers: Array[String] = season.offers()
		if offers.is_empty() or not season.choose_player(offers[0]):
			_check(false, "ordinary tracked source completes its real draft")
			get_tree().quit(1)
			return
	var before: Dictionary = SeasonSave.snapshot(season)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	if before.is_empty() or ledger == null or _failures > 0:
		_check(false, "source season and real human ledger validate before any game")
		get_tree().quit(1)
		return
	var ledger_before: String = _json(ledger.to_data())
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	for id: String in _venues:
		var literal: String = _json(_definitions.definition(id, _revision))
		var first: Dictionary = await _game(source, id, 47, 1)
		if first.is_empty() or _failures > 0:
			break
		var persisted: Dictionary = _round_trip(first, id)
		if persisted.is_empty() or _failures > 0:
			break
		_check(
			(
				persisted.venue.id == id
				and persisted.venue.revision == _revision
				and (
					persisted.venue.definition_sha256
					== _definitions.key(_definitions.definition(id, _revision))
				)
			),
			"replay remains pinned to exact revision data"
		)
		var second: Dictionary = await _game(source, persisted.venue.id, persisted.seed, 2)
		_check(
			not second.is_empty() and first == second and _json(first) == _json(second),
			(
				"same fresh teams, exact revision and seed reproduce all exact observed game evidence "
				+ id
			)
		)
		_check(
			literal == _json(_definitions.definition(id, _revision)),
			"games never alter definition bytes or certify environments " + id
		)
		_check(
			PhysicalMatchRequest.capture(source) != null,
			"both games leave the source teams and source match genuinely fresh"
		)
		_reject_authority(season, first)
	_check(
		ClubCareer.same(before, SeasonSave.snapshot(season)),
		"all retained games leave originating season/save/rewards unchanged"
	)
	var after_ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(
		after_ledger != null and _json(after_ledger.to_data()) == ledger_before,
		"exact human paid ledger, wallet, ownership and reward history remain unchanged"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro candidate NPC r2 games passed: two complete real games and exact replay per venue."
				if candidate_v2
				else "Wiffaltro retained NPC games passed: two complete real games and exact replay per venue."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--npc-retained-report-dir="):
			_report_dir = argument.trim_prefix("--npc-retained-report-dir=")
		elif argument.begins_with("--npc-retained-venue="):
			var id: String = argument.trim_prefix("--npc-retained-venue=")
			_check(
				id in ["AY-01", "AE-01", "AC-01"],
				"optional qualification target is an exact supported ID"
			)
			_venues = [id] if id in ["AY-01", "AE-01", "AC-01"] else []


func _game(source: MatchState, id: String, seed_value: int, ordinal: int) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(viewport)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_npc_retained_lab_only", true)
	lab._sky_backdrop_enabled = false
	viewport.add_child(lab)
	var host: Node = lab.get_node("StarterFieldGeometry")
	var original_nodes: Array[Node] = host.get_children()
	_check(_runtime.install(lab, id, _revision), "full game explicitly installs retained " + id)
	if not lab.has_meta("stadium_property") or _failures > 0:
		viewport.queue_free()
		return {}
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_runtime.installed(lab, id, _revision), "actual retained geometry/bindings qualify")
	lab._configured_match = PhysicalMatchRequest.capture(source)
	_check(lab._configured_match != null, "game starts with freshly copied ordinary source teams")
	lab._automation = MatchAutomation.new()
	lab._automation.seed = seed_value
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab._start_new_match()
	if property.display != null:
		_check(
			property.display._match == lab._match_state,
			"full game binds its fresh match synchronously without a manual presentation update"
		)
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
			_check(false, "real retained game exceeded ordinary time/progress bounds")
			break
		if lab._automation.releases.size() % 25 == 0 and logged != lab._automation.releases.size():
			logged = lab._automation.releases.size()
			print(
				"NPC_RETAINED_GAME_PROGRESS venue=",
				id,
				" game=",
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
				"pause freezes actual retained game motion and ordinary match clock"
			)
			get_tree().paused = false
	_check(
		lab._match_state.phase == MatchState.Phase.GAME_END,
		"retained game reaches an actual final score without simulated-result fallback"
	)
	var report: Dictionary = {}
	if lab._match_state.phase == MatchState.Phase.GAME_END:
		_check(
			_runtime.installed(lab, id, _revision),
			"complete geometry, NPC identities and all bindings remain valid after full game"
		)
		report = _capture(lab, property, seed_value)
		_audit(lab, report)
		print(
			"NPC_RETAINED_GAME_COMPLETE venue=",
			id,
			" game=",
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
			_json(report).sha256_text()
		)
		if not _report_dir.is_empty():
			_check(
				DirAccess.make_dir_recursive_absolute(_report_dir) == OK,
				"unqualified retained evidence directory is available"
			)
			var file: FileAccess = FileAccess.open(
				_report_dir.path_join(
					(
						(
							"npc-candidate-r2-%s-game-%d.json"
							if candidate_v2
							else "npc-retained-%s-game-%d.json"
						)
						% [id.to_lower(), ordinal]
					)
				),
				FileAccess.WRITE
			)
			_check(file != null, "unqualified retained game evidence file opens")
			if file != null:
				file.store_string(_json(report))
				file.flush()
				_check(
					file.get_error() == OK, "unqualified retained game evidence writes completely"
				)
				file.close()
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	var retained_automation: MatchAutomation = lab._automation
	lab._automation = null
	lab._pitch_actor.reset_pitch()
	lab._release_controller.cancel()
	lab._at_bat_cadence.stop()
	lab._cleanup_batted_ball()
	_check(_runtime.teardown(lab), "finished game can release isolated runtime")
	lab._automation = retained_automation
	_check(
		PhysicalMatchReport.capture(lab).is_empty(),
		"reattached automation cannot recapture completed retained plays after teardown"
	)
	lab._automation = null
	_check(
		host.get_children() == original_nodes, "finished game restores original live field nodes"
	)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	return report


func _capture(
	lab: PitchBatLab, property: StadiumNpcRetainedProperty, seed_value: int
) -> Dictionary:
	var plays: Array[Dictionary] = []
	for play: PlayRecord in lab._play_records:
		plays.append(play.to_dict())
	var state: MatchState = lab._match_state
	return {
		"kind": _kind,
		"version": _version,
		"seed": seed_value,
		"venue":
		{
			"id": property.venue_id,
			"revision": _revision,
			"definition_sha256":
			_definitions.key(_definitions.definition(property.venue_id, _revision))
		},
		"score": [state.away_team.runs, state.home_team.runs],
		"elapsed": state.elapsed_seconds,
		"inning": state.inning,
		"top": state.top_half,
		"releases": lab._automation.releases.duplicate(true),
		"plays": plays,
		"performance": state.performance.snapshot(state),
		"surfaces": PhysicalStadiumContacts.capture(lab._play_records),
		"receiver": property.receiver.contacts.duplicate(true) if property.receiver != null else [],
		"provenance": property.provenance.duplicate(true)
	}


func _audit(lab: PitchBatLab, report: Dictionary) -> void:
	_check(
		(
			report.score[0] != report.score[1]
			and report.releases.size() > 0
			and report.plays.size() == report.releases.size()
		),
		"every actual pitch has one completed play"
	)
	var recorded_runs: int = 0
	var surface_events: int = 0
	for row: Dictionary in report.plays:
		_check(row.result != "pending", "no unfinished play is replaced by a guessed outcome")
		recorded_runs += int(row.runs_scored)
	for row: Dictionary in report.surfaces:
		surface_events += row.events.size()
		for event: Dictionary in row.events:
			if event.source == "item":
				_check(
					String(event.id).begins_with("npc:" + report.venue.id + ":r%d:" % _revision),
					"actual item events retain NPC provenance without human ownership"
				)
	_check(
		recorded_runs == report.score[0] + report.score[1],
		"actual play runs reconcile to final score"
	)
	_check(surface_events > 0, "ordinary full play genuinely reaches retained physical surfaces")
	var pitches: int = 0
	for line: Dictionary in report.performance.values():
		pitches += int(line.pitches)
	_check(
		pitches == report.releases.size(), "ordinary player pitch totals reconcile to all releases"
	)
	for contact: Dictionary in report.receiver:
		_check(
			String(contact.copy).begins_with("npc:" + report.venue.id + ":r%d:" % _revision),
			"receiver uses exact real NPC IDs"
		)
	_check(
		PhysicalMatchReport.capture(lab).is_empty() and not PhysicalMatchReport.valid(report),
		"retained qualification cannot become a production report or award rewards"
	)
	var instances: Dictionary = {}
	for instance: Dictionary in _definitions.definition(report.venue.id, _revision).instances:
		instances[instance.instance] = true
	for contact: Dictionary in report.provenance:
		_check(
			(
				instances.has(contact.instance)
				and contact.preterminal is bool
				and is_finite(float(contact.elapsed))
				and float(contact.elapsed) >= 0
			),
			"raw observed provenance retains real admitted instance and exact preterminal state"
		)
	var original_bytes: String = _json(report)
	var once: Variant = JSON.parse_string(original_bytes)
	var twice: Variant = JSON.parse_string(_json(once))
	if once != twice:
		var raw_differences: Array[Dictionary] = []
		_json_differences(once, twice, "$", raw_differences)
		for difference: Dictionary in raw_differences:
			print("NPC_RETAINED_JSON_REPRESENTATION ", _json(difference))
	var restored_once: Dictionary = _restore_position_vectors(once)
	var restored_twice: Dictionary = _restore_position_vectors(twice)
	_check(
		(
			not restored_once.is_empty()
			and restored_once == restored_twice
			and _json(restored_once) == _json(restored_twice)
			and ClubCareer.same(report, restored_once)
		),
		"complete decoded evidence is exact after restoring only typed engine position vectors"
	)
	if not restored_once.is_empty():
		for index in range(report.plays.size()):
			for key: String in ["first_ground_position", "resolution_position"]:
				_check(
					restored_once.plays[index][key] == report.plays[index][key],
					"every decoded position equals its original engine float32 coordinate exactly"
				)
	_check(
		_json(report) == original_bytes,
		"raw captured evidence keeps every original value and full-precision JSON byte"
	)


func _round_trip(report: Dictionary, id: String) -> Dictionary:
	var path: String = "user://npc-retained-evidence-%s-%d.json" % [id, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "local unqualified evidence opens for replay")
	if file == null:
		return {}
	file.store_string(_json(report))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	var text: String = FileAccess.get_file_as_string(path)
	DirAccess.remove_absolute(path)
	var decoded: Variant = JSON.parse_string(text)
	_check(
		error == OK and decoded is Dictionary and text == _json(report),
		"saved replay evidence retains its complete canonical bytes"
	)
	if not decoded is Dictionary:
		return {}
	var restored: Dictionary = _restore_position_vectors(decoded)
	_check(
		not restored.is_empty() and ClubCareer.same(restored, report),
		"read-back evidence contains every observed value after typed position reconstruction"
	)
	if not restored.is_empty():
		for index in range(report.plays.size()):
			for key: String in ["first_ground_position", "resolution_position"]:
				_check(
					restored.plays[index][key] == report.plays[index][key],
					"disk-read position reconstructs the exact original engine coordinate"
				)
	return decoded


func _reject_authority(season: SeasonState, report: Dictionary) -> void:
	_check(
		(
			not StadiumNpcVenues.valid_manifest(report)
			and not StadiumLayoutSnapshot.valid(report)
			and not PhysicalMatchReport.valid(report)
		),
		"qualification evidence acquires no published authority"
	)
	_check(
		SeasonSave._decode(report) == null, "qualification evidence cannot be restored as a season"
	)
	var injected: Dictionary = SeasonSave.snapshot(season)
	injected["npc_retained_runtime"] = report.duplicate(true)
	_check(
		SeasonSave._decode(injected) == null, "new NPC save data needs explicit future migration"
	)
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	source.stadium = _definitions.definition(report.venue.id, _revision)
	_check(
		PhysicalMatchRequest.capture(source) == null,
		"admitted NPC data still cannot enter ordinary production physical request authority"
	)


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _json_differences(
	before: Variant, after: Variant, path: String, rows: Array[Dictionary]
) -> void:
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
		rows.append(
			{
				"path": path,
				"before": before,
				"after": after,
				"before_type": typeof(before),
				"after_type": typeof(after),
				"before_exact_variant_bytes": var_to_bytes(before).hex_encode(),
				"after_exact_variant_bytes": var_to_bytes(after).hex_encode()
			}
		)


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
				if (
					typeof(component) not in [TYPE_INT, TYPE_FLOAT]
					or not is_finite(float(component))
				):
					return {}
			row[key] = Array(PackedFloat32Array(row[key]))
	return result


func _position_precision_contract() -> void:
	# Observed value is IEEE754 float32 0x34700000. Its adjacent value must remain different.
	var exact: float = PackedByteArray([0, 0, 0x70, 0x34]).decode_float(0)
	var adjacent: float = PackedByteArray([1, 0, 0x70, 0x34]).decode_float(0)
	var before: Dictionary = {
		"plays": [{"first_ground_position": [0, exact, 0], "resolution_position": [0, exact, 0]}],
		"elapsed": 270.733333333416
	}
	var changed: Dictionary = before.duplicate(true)
	changed.plays[0].first_ground_position[1] = adjacent
	_check(
		_restore_position_vectors(before) != _restore_position_vectors(changed),
		"even one adjacent representable engine coordinate remains a genuine difference"
	)
	changed = before.duplicate(true)
	changed.elapsed = 270.7333333334161
	_check(
		_restore_position_vectors(before) != _restore_position_vectors(changed),
		"scalar float64 elapsed evidence is never quantized as a position"
	)
