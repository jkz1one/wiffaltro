extends "res://src/tests/stadium_npc_retained_game_test.gd"
## AY03-only complete ordinary games. Inherited audits and replay retain their exact original bytes.
## Private evidence only: no production reports, public definition or certificate.

const SEASON_SEED: int = 443
const MATCH_SEED: int = 47


func _ready() -> void:
	_runtime = StadiumNpcYardThreeRuntimeV1
	_definitions = StadiumNpcYardThreeCandidateV1
	_revision = 1
	_venues = ["AY-03"]
	_kind = "UNQUALIFIED_AY03_INSTALLED_GAME_QUALIFICATION"
	_version = "ay03-installed-game-qualification-v1"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arguments()
	if _failures > 0:
		get_tree().quit(1)
		return
	_position_precision_contract()
	var season: SeasonState = SeasonState.create(SEASON_SEED, false, true, true)
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
		print("Wiffaltro AY03 private installed games passed: "
			+ "two complete ordinary games and exact replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ay03-installed-games-dir="):
			_check(_report_dir.is_empty(), "one exact AY03 evidence output directory")
			_report_dir = argument.trim_prefix("--ay03-installed-games-dir=")
		elif argument != "--physical-in-process":
			_check(false, "no venue, revision, seed or shortened-game input is accepted")
	_check(not _report_dir.is_empty(), "root supplies an explicit AY03 evidence directory")


func _game(source: MatchState, id: String, seed_value: int, ordinal: int) -> Dictionary:
	if id != "AY-03" or seed_value != MATCH_SEED or ordinal not in [1, 2]:
		_check(false, "only the exact AY03 seeded replay pair may execute")
		return {}
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(viewport)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
	lab.set_meta("stadium_npc_retained_lab_only", true)
	lab._sky_backdrop_enabled = false
	viewport.add_child(lab)
	var host: Node = lab.get_node("StarterFieldGeometry")
	var original_nodes: Array[Node] = host.get_children()
	_check(_runtime.install(lab, id, _revision), "full game explicitly installs retained " + id)
	if not lab.has_meta("stadium_property") or _failures > 0:
		viewport.queue_free()
		return {}
	var property: StadiumNpcYardThreePropertyV1 = lab.get_meta("stadium_property")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_runtime.installed(lab, id, _revision), "actual retained geometry/bindings qualify")
	lab._configured_match = PhysicalMatchRequest.capture(source)
	_check(lab._configured_match != null, "game starts with freshly copied ordinary source teams")
	if lab._configured_match == null:
		viewport.queue_free()
		await get_tree().process_frame
		return {}
	# Explicit idle rebind precedes automation. Production start/automation code is unchanged.
	lab._start_new_match()
	var fresh_state: MatchState = lab._match_state
	var fresh_elapsed: float = fresh_state.elapsed_seconds
	var fresh_plays: int = lab._play_records.size()
	_check(property.bound_state != fresh_state and not _runtime.installed(lab, id, _revision),
		"replacement MatchState remains unbound until explicit private rebind")
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	_check(lab._automation == null and StadiumPropertyRuntime.authoring_delivery_idle(lab),
		"startup is idle with no automation before explicit private rebind")
	_check(_runtime.rebind_match(lab) and property.bound_state == fresh_state,
		"explicit private rebind selects the actual fresh ordinary MatchState")
	_check(_runtime.installed(lab, id, _revision)
		and fresh_state.elapsed_seconds == fresh_elapsed and fresh_plays == 0
		and lab._play_records.is_empty() and lab._throw_number == 0,
		"no release, play or elapsed time is manufactured before successful rebind")
	if _failures > 0:
		viewport.queue_free()
		await get_tree().process_frame
		return {}
	lab._automation = MatchAutomation.new()
	lab._automation.seed = seed_value
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab._automation.begin(lab)
	_check(property.bound_state == lab._match_state and _runtime.installed(lab, id, _revision),
		"ordinary automation begins exactly once on the explicitly rebound private field")
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
				"AY03_INSTALLED_GAME_PROGRESS venue=",
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
			"AY03_INSTALLED_GAME_COMPLETE venue=",
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
			var path: String = _report_dir.path_join("ay03-installed-game-%d.json" % ordinal)
			_check(not FileAccess.file_exists(path), "raw game evidence is never overwritten")
			if FileAccess.file_exists(path):
				viewport.queue_free()
				await get_tree().process_frame
				return {}
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
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
	_check(lab.get_meta("stadium_npc_ay03_installed_lab_only") == true
		and lab.get_meta("stadium_npc_retained_lab_only") == true,
		"both caller-owned quarantine flags survive completed-game teardown")
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
	var result: Dictionary = super._capture(lab, property, seed_value)
	result["candidate_sha256"] = StadiumNpcYardThreeCandidateV1.SHA256
	result["subject_sha256"] = StadiumNpcYardThreeCandidateV1.SUBJECT_SHA256
	return result


func _audit(lab: PitchBatLab, report: Dictionary) -> void:
	super._audit(lab, report)
	_check(report.candidate_sha256 == StadiumNpcYardThreeCandidateV1.SHA256
		and report.subject_sha256 == StadiumNpcYardThreeCandidateV1.SUBJECT_SHA256
		and report.venue.id == "AY-03" and report.venue.revision == 1
		and report.seed == MATCH_SEED and report.receiver.is_empty(),
		"current installed games bind exact AY03 C/S and empty receiver without public authority")
	_check(StadiumNpcVenues.definition("AY-03", 1).is_empty()
		and StadiumNpcAvailability.record("AY-03", 1).is_empty()
		and StadiumNpcYardThreeCandidateV1.payload().environment_certificates.is_empty(),
		"game evidence cannot manufacture public membership, availability or day/night certificates")
