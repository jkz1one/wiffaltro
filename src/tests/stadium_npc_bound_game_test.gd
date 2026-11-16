extends "res://src/tests/stadium_npc_retained_game_test.gd"
## Two actual ordinary-controller games per public r2 fixture17, kept outside production authority.
## Existing physical evidence precision, audit, disk roundtrip and authority checks are inherited.

const MATCH_SEED: int = 47
const ENVIRONMENT_SEED: int = 911
const COMMON_FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
var _context: StadiumNpcQualificationContext
var _replay_fixture: Dictionary = {}
var _previous_match: MatchState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_revision = 2
	_runtime = StadiumNpcRuntime
	_definitions = StadiumNpcVenues
	_kind = "UNQUALIFIED_NPC_RAW_BOUND_RUNTIME_QUALIFICATION"
	_version = "raw-bound-runtime-qualification-v1"
	_arguments()
	_position_precision_contract()
	var season: SeasonState = SeasonState.create(443, false, true, true)
	_check(season.opponents != null and season.opponents._format == 2,
		"frozen candidate source uses actual paid-opponent policy2, without SeasonApp upgrades")
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
	_check(_policy_two_teams(source),
		"actual policy2 source teams keep later sponsor/base/heat/recovery/budget features disabled")
	if _failures > 0:
		get_tree().quit(1)
		return
	for id: String in _venues:
		var literal: String = _json(_definitions.definition(id, _revision))
		_replay_fixture.clear()
		var first: Dictionary = await _game(source, id, MATCH_SEED, 1)
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
		_replay_fixture = _replay_raw_fixture(persisted, id)
		if _replay_fixture.is_empty() or _failures > 0:
			break
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
		"all raw-bound games leave originating season/save/rewards unchanged"
	)
	var after_ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(
		after_ledger != null and _json(after_ledger.to_data()) == ledger_before,
		"exact human paid ledger, wallet, ownership and reward history remain unchanged"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			("Wiffaltro NPC raw-bound games passed: two complete real games "
				+ "and exact fixture17 replay per venue.")
			if _venues.size() == 3 else
			("Wiffaltro NPC raw-bound selected games passed: two complete real games "
				+ "and exact fixture17 replay.")
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--npc-raw-bound-report-dir="):
			_report_dir = argument.trim_prefix("--npc-raw-bound-report-dir=")
		elif argument.begins_with("--npc-raw-bound-venue="):
			var id: String = argument.trim_prefix("--npc-raw-bound-venue=")
			_check(id in ["AY-01", "AE-01", "AC-01"], "selected raw-bound venue is exact")
			_venues = [id] if id in ["AY-01", "AE-01", "AC-01"] else []


func _binding(id: String) -> Dictionary:
	# Caller-owned declarations: never derive context expectations from a tested envelope.
	return {
		"season_id": "a".repeat(32), "assignment_key": "b".repeat(64),
		"owner_club": 2, "venue_id": id, "venue_revision": 2,
		"fixture": 7, "away": 1, "batting_home": 2, "neutral": false,
		"match_seed": MATCH_SEED, "field": "field.npc_venue"
	}


func _environment() -> Dictionary:
	return {"version": 1, "seed": ENVIRONMENT_SEED, "fixture": 7, "mode": "day", "profile": ""}


func _fixture(id: String) -> Dictionary:
	return StadiumNpcSnapshot.raw_fixture(
		StadiumNpcSnapshot.raw_entry(id, 2), _binding(id), _environment())


func _replay_raw_fixture(persisted: Dictionary, id: String) -> Dictionary:
	var decoded: Variant = persisted.get("raw_fixture")
	var restored: Dictionary = StadiumNpcSnapshot.normalize_raw_envelope(decoded)
	var expected: Dictionary = _fixture(id)
	_check(
		not restored.is_empty() and restored == expected
		and _json(restored) == _json(expected)
		and StadiumNpcSnapshot.raw_envelope_key(restored) == persisted.raw_fixture_key
		and restored.binding == _binding(id) and restored.environment == _environment(),
		"disk-replayed complete fixture17 matches independent binding, environment and full public P"
	)
	return restored


func _policy_two_teams(state: MatchState) -> bool:
	if state == null:
		return false
	for team: TeamMatchState in [state.away_team, state.home_team]:
		if team == null or team.ai_sponsor_choices or team.ai_base or team.ai_heat \
			or team.track_bases or not team.ai_tactical_hitter.is_empty() \
			or not team.ai_recovery_pitcher.is_empty() or not team.ai_budget.is_empty() \
			or not team.ai_tactical_initial.is_empty():
			return false
	return true


func _game(source: MatchState, id: String, seed_value: int, ordinal: int) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(viewport)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	viewport.add_child(lab)
	var host: Node = lab.get_node("StarterFieldGeometry")
	var original_nodes: Array[Node] = host.get_children()
	_check(lab._match_state.stadium.is_empty() and not lab.has_meta("stadium_property"),
		"unchanged ordinary startup has no NPC snapshot or runtime admission")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var actual: MatchState = PhysicalMatchRequest.capture(source)
	_check(actual != null, "game starts with freshly copied ordinary source teams")
	if actual == null:
		viewport.queue_free()
		return {}
	# Match the original candidate install-before-startup order on genuine policy2 teams.
	# Keep the actual object through _start_new_match; never clear or invent evidence.
	lab._match_state = actual
	lab._base_state = actual.bases
	_check(lab._automation == null and lab._configured_match == null,
		"fresh context is installed before automation or pending match preparation")
	_check(lab._match_state != source and lab._match_state != _previous_match
		and lab._match_state.away_team != source.away_team
		and lab._match_state.home_team != source.home_team,
		"each repeat runs a new actual MatchState and independently copied teams")
	_check(lab._match_state.stadium.is_empty(), "ordinary fresh team copy remains unadmitted")
	_check(seed_value == MATCH_SEED, "actual automation uses the independent declared match seed")
	lab._match_state.stadium = (
		_fixture(id) if ordinal == 1 else _replay_fixture.duplicate(true))
	var fixture_bytes: String = _json(lab._match_state.stadium)
	var field: FieldDefinition = COMMON_FIELD.duplicate(true) as FieldDefinition
	_context = StadiumNpcQualificationContext.create(
		lab._match_state, _binding(id), _environment(), field, MATCH_SEED)
	_check(_context != null and _context.fresh(), "actual fresh match has independent typed context")
	_check(_runtime.install_bound(lab, _context), "explicit raw fixture17 runtime installs " + id)
	if not lab.has_meta("stadium_property") or _failures > 0:
		viewport.queue_free()
		return {}
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property")
	_check(_runtime.installed(lab, _context), "actual raw-bound geometry and callbacks qualify")
	_check(not lab.has_meta("stadium_npc_retained_lab_only")
		and not lab.has_meta("stadium_candidate_only") and not lab.has_meta("stadium_snapshot"),
		"raw installation uses no authoring flags or production snapshot metadata")
	# No frame occurs between raw installation and the complete ordinary startup.
	lab._configured_match = actual
	lab._automation = MatchAutomation.new()
	lab._automation.seed = seed_value
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab._start_new_match()
	_check(lab._match_state == actual and _context._match == actual
		and lab._configured_match == null and _context.matches(lab)
		and _runtime.installed(lab, _context),
		"ordinary startup retains the exact installed MatchState and independent raw context")
	_check(_policy_two_teams(actual) and actual.ai_choice_events.is_empty()
		and actual._ai_choice_prepared.is_empty() and actual.base_flow.ready.is_empty()
		and actual.away_team.recovery.initial.is_empty()
		and actual.home_team.recovery.initial.is_empty() and _context.fresh(),
		"ordinary policy2 startup preserves disabled later sponsor/base preparation on actual state")
	_check(lab._throw_number == MATCH_SEED * 1000 and lab._automation.releases.is_empty()
		and actual.phase == MatchState.Phase.PRE_PITCH and actual.elapsed_seconds == 0.0,
		"ordinary controllers begin at the actual seed without a manufactured release or time")
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
			_check(false, "real raw-bound game exceeded ordinary time/progress bounds")
			break
		if lab._automation.releases.size() % 25 == 0 and logged != lab._automation.releases.size():
			logged = lab._automation.releases.size()
			print(
				"NPC_RAW_BOUND_GAME_PROGRESS venue=",
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
				"pause freezes actual raw-bound game motion and ordinary match clock"
			)
			get_tree().paused = false
	_check(
		lab._match_state.phase == MatchState.Phase.GAME_END,
		"raw-bound game reaches an actual final score without simulated-result fallback"
	)
	var report: Dictionary = {}
	if lab._match_state.phase == MatchState.Phase.GAME_END:
		_check(
			_runtime.installed(lab, _context),
			"complete geometry, NPC identities and all bindings remain valid after full game"
		)
		report = _capture(lab, property, seed_value)
		_audit(lab, report)
		print(
			"NPC_RAW_BOUND_GAME_COMPLETE venue=",
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
				"unqualified raw-bound evidence directory is available"
			)
			var file: FileAccess = FileAccess.open(
				_report_dir.path_join("npc-raw-bound-%s-game-%d.json" % [id.to_lower(), ordinal]),
				FileAccess.WRITE
			)
			_check(file != null, "unqualified raw-bound game evidence file opens")
			if file != null:
				file.store_string(_json(report))
				file.flush()
				_check(
					file.get_error() == OK, "unqualified raw-bound game evidence writes completely"
				)
				file.close()
	_check(fixture_bytes == _json(lab._match_state.stadium),
		"complete ordinary gameplay preserves every actual raw fixture17 byte")
	_previous_match = lab._match_state
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
		_refuse_public_report(lab),
		"reattached automation cannot recapture completed raw-bound plays after teardown"
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
	var report: Dictionary = super._capture(lab, property, seed_value)
	report["raw_fixture"] = lab._match_state.stadium.duplicate(true)
	report["raw_fixture_key"] = StadiumNpcSnapshot.raw_envelope_key(report.raw_fixture)
	_check(not report.raw_fixture_key.is_empty()
		and report.raw_fixture.manifest_key == report.venue.definition_sha256,
		"full observed record pins the actual complete raw fixture and public manifest")
	return report


func _audit(lab: PitchBatLab, report: Dictionary) -> void:
	# The inherited audit calls the unchanged public capture API. Supply the actual
	# complete fixture only during that synchronous refusal probe to avoid absent-meta ERROR.
	var previous: Dictionary = _set_report_refusal_metadata(lab)
	_check(not _runtime.installed(lab, _context), "forged public metadata cannot grant raw authority")
	super._audit(lab, report)
	_restore_report_metadata(lab, previous)
	_check(_runtime.installed(lab, _context), "full raw runtime survives public-report refusal")
	_check(report.raw_fixture == lab._match_state.stadium
		and report.raw_fixture.binding == _binding(report.venue.id)
		and report.raw_fixture.environment == _environment(),
		"audited diagnostic carries the unchanged actual independent raw fixture")


func _set_report_refusal_metadata(lab: PitchBatLab) -> Dictionary:
	var previous: Dictionary = {"present": lab.has_meta("stadium_snapshot")}
	if previous.present:
		previous["value"] = lab.get_meta("stadium_snapshot")
	var actual: Dictionary = lab._match_state.stadium.duplicate(true)
	_check(StadiumNpcSnapshot.raw_envelope_valid(actual),
		"report-refusal probe uses the actual full valid raw fixture17")
	lab.set_meta("stadium_snapshot", actual)
	return previous


func _restore_report_metadata(lab: PitchBatLab, previous: Dictionary) -> void:
	if previous.present:
		lab.set_meta("stadium_snapshot", previous.value)
	else:
		lab.remove_meta("stadium_snapshot")
	_check(lab.has_meta("stadium_snapshot") == previous.present
		and (not previous.present or lab.get_meta("stadium_snapshot") == previous.value),
		"public report refusal restores exact previous metadata presence and value")


func _refuse_public_report(lab: PitchBatLab) -> bool:
	var previous: Dictionary = _set_report_refusal_metadata(lab)
	var refused: bool = PhysicalMatchReport.capture(lab).is_empty()
	_restore_report_metadata(lab, previous)
	return refused


func _reject_authority(season: SeasonState, report: Dictionary) -> void:
	super._reject_authority(season, report)
	var raw: Dictionary = report.raw_fixture
	_check(not StadiumNpcSnapshot.valid(raw) and StadiumNpcSnapshot.key(raw).is_empty()
		and StadiumNpcSnapshot.normalized(raw).is_empty()
		and not StadiumLayoutSnapshot.valid(raw),
		"full-game raw fixture never gains public snapshot authority")
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	source.stadium = raw.duplicate(true)
	_check(PhysicalMatchRequest.capture(source) == null,
		"even exact replayed raw fixture17 cannot enter production request authority")


func _restore_position_vectors(value: Variant) -> Dictionary:
	# Preserve the exact inherited physical position restoration and every scalar value.
	# Only the added fixture metadata also needs the existing raw manifest canonicalizer.
	var result: Dictionary = super._restore_position_vectors(value)
	if result.is_empty() or not result.has("raw_fixture"):
		return result
	var raw: Dictionary = StadiumNpcSnapshot.normalize_raw_envelope(result.raw_fixture)
	var expected: Dictionary = _fixture(result.venue.id)
	if raw.is_empty() or raw != expected or _json(raw) != _json(expected) \
		or StadiumNpcSnapshot.raw_envelope_key(raw) != result.raw_fixture_key:
		return {}
	result.raw_fixture = raw
	return result
