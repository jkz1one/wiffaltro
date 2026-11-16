extends "res://src/tests/stadium_club_game_test.gd"
## Six real ordinary-controller games on paid-prefix frozen authoring fields; no rewards.

var _shape: String = ""
var _fixture: Dictionary = {}
var _ledger: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _completed_games: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--advanced-study-report-dir="):
			_report_dir = argument.trim_prefix("--advanced-study-report-dir=")
	for index in range(20):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 4})
	var season: SeasonState = SeasonState.create(443, true, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var before: Dictionary = SeasonSave.snapshot(season)
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		_shape = shape
		_prepare(shape)
		if _failures > 0:
			break
		var first: Dictionary = await _game(source, 47, 1)
		if first.is_empty() or _failures > 0:
			break
		var path: String = "user://advanced-replay-%s.json" % shape
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "authoring replay bundle opens")
		if file == null:
			break
		file.store_string(
			JSON.stringify({"ledger": _ledger.to_data(), "fixture": _fixture}, "", true, true)
		)
		file.close()
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(loaded is Dictionary, "saved owned replay data decodes")
		if not loaded is Dictionary:
			break
		_ledger = ClubAssetLedger.from_data(loaded.ledger, 17, _credits, _progress)
		_check(
			_ledger != null and StadiumAdvancedSnapshot.matches(loaded.fixture, _ledger),
			"reloaded exact fixture binds the saved paid prefix"
		)
		var second: Dictionary = await _game(source, 47, 2, loaded.fixture)
		DirAccess.remove_absolute(path)
		_check(
			not second.is_empty() and ClubCareer.same(first, second),
			"saved exact field, seed and fresh teams reproduce full game evidence: " + shape
		)
	_check(
		ClubCareer.same(before, SeasonSave.snapshot(season)),
		"detached owned field games never award or mutate the originating season"
	)
	_check(_completed_games == 6, "all three actual full-game replay pairs completed")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro advanced authoring games passed: three frozen fields and exact full-game replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _prepare(shape: String) -> void:
	_ledger = ClubAssetLedger.new(17, _credits, _progress)
	_check(
		(
			_ledger
			. commit(
				{
					"id": "back",
					"rev": 0,
					"op": "stadium_buy",
					"through": 20,
					"progress_through": 20,
					"price_version": 8,
					"item": "ST-024",
					"quantity": 27
				}
			)
			. ok
		),
		"standard full back purchased"
	)
	for height: String in ["low", "tall"]:
		_check(
			(
				_ledger
				. commit(
					{
						"id": height,
						"rev": _ledger.revision(),
						"op": "stadium_wall_piece",
						"through": 20,
						"progress_through": 20,
						"price_version": 1,
						"item": StadiumWallPieceCatalog.identity("ST-024", height),
						"quantity": 12
					}
				)
				. ok
			),
			"exact height pieces purchased"
		)
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), _ledger.surface_owned(), true)
	)
	layout.receiver = "starter-v1:ST-079"
	layout.advanced_back = (
		StadiumAdvancedWallManifest
		. suggest(shape, "ST-024", _ledger.construction(), _ledger.wall_pieces().stock)
		. manifest
	)
	_check(
		_ledger.commit({"id": "draft", "rev": 3, "op": "stadium_draft", "layout": layout}).ok,
		"exact complete field data drafted"
	)
	_check(
		(
			_ledger
			. commit(
				{
					"id": "apply",
					"rev": 4,
					"op": "stadium_apply",
					"layout": layout,
					"geometry": StadiumOwnedLayout.geometry("backyard", layout)
				}
			)
			. ok
		),
		"exact field data applied"
	)
	_fixture = StadiumAdvancedSnapshot.fixture(StadiumAdvancedSnapshot.capture(_ledger), 47, 0)
	_check(
		StadiumAdvancedSnapshot.matches(_fixture, _ledger),
		"frozen fixture has exact paid provenance"
	)


func _game(source: MatchState, seed_value: int, ordinal: int, frozen: Variant = null) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(viewport)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_advanced_lab_only", true)
	lab._sky_backdrop_enabled = false
	viewport.add_child(lab)
	_reject_frozen(lab, _fixture if frozen == null else frozen)
	var installed: bool = StadiumAdvancedLab.install_frozen(
		lab, _fixture if frozen == null else frozen, _ledger
	)
	_check(installed, "full game explicitly installs the requested isolated candidate")
	if _failures > 0:
		viewport.queue_free()
		return {}
	var property: StadiumAdvancedPropertyGeometry = lab.get_meta("stadium_property")
	var venue: Dictionary = lab.get_meta("advanced_authoring_fixture").duplicate(true)
	_check(venue.environment.seed == seed_value, "game RNG uses the held fixture seed")
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._configured_match = PhysicalMatchRequest.capture(source)
	_check(lab._configured_match != null, "authoring teams start from a fresh copied match")
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
				"ADVANCED_GAME_PROGRESS shape=",
				_shape,
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
				"pause interrupts the full candidate game without hidden motion or clock advancement"
			)
			get_tree().paused = false
	_check(
		lab._match_state.phase == MatchState.Phase.GAME_END,
		"candidate game reaches a real final score, without simulated-result fallback"
	)
	var report: Dictionary = {}
	if lab._match_state.phase == MatchState.Phase.GAME_END:
		_completed_games += 1
		report = _capture(lab, venue, seed_value)
		_audit(lab, report)
		_check(
			(
				ClubCareer.same(venue.layout, property.get_meta("advanced_layout"))
				and ClubCareer.same(
					venue.wall_piece_inventory, property.get_meta("advanced_pieces")
				)
			),
			"complete authored field stays frozen for the entire game"
		)
		print(
			"ADVANCED_GAME_COMPLETE shape=",
			_shape,
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
			JSON.stringify(report, "", true, true).sha256_text()
		)
		if not _report_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(_report_dir)
			var file: FileAccess = FileAccess.open(
				_report_dir.path_join("advanced-game-%s-%d.json" % [_shape, ordinal]),
				FileAccess.WRITE
			)
			_check(file != null, "unqualified authoring evidence file opens")
			if file != null:
				file.store_string(JSON.stringify(report, "", true, true))
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	return report


func _capture(lab: PitchBatLab, fixture: Dictionary, seed_value: int) -> Dictionary:
	var result: Dictionary = super._capture(lab, fixture, seed_value)
	result.kind = "UNQUALIFIED_OWNED_ADVANCED_GAME"
	result.erase("venue")
	result["fixture"] = fixture
	return result


func _reject_frozen(lab: PitchBatLab, fixture: Dictionary) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var count: int = host.get_child_count()
	_check(
		not StadiumAdvancedLab.install_frozen(lab, {}, _ledger),
		"missing frozen data never becomes a default field"
	)
	_check(
		not StadiumAdvancedLab.install_frozen(lab, fixture, null),
		"frozen owned installation requires its paid ledger prefix"
	)
	var entry: Dictionary = StadiumAdvancedSnapshot.normalized(fixture)
	entry.version = StadiumAdvancedSnapshot.VERSION
	entry.erase("environment")
	_check(
		(
			StadiumAdvancedSnapshot.matches(entry, _ledger)
			and not StadiumAdvancedLab.install_frozen(lab, entry, _ledger)
		),
		"season-entry data cannot impersonate an explicit game fixture"
	)
	var forged: Dictionary = StadiumAdvancedSnapshot.normalized(fixture)
	var copy: Dictionary = forged.wall_piece_inventory.stock.copies.values()[0].duplicate(true)
	forged.wall_piece_inventory.stock.copies["wall-piece:forged:0"] = copy
	_check(
		(
			StadiumAdvancedSnapshot.valid(forged)
			and not StadiumAdvancedLab.install_frozen(lab, forged, _ledger)
		),
		"self-consistent invented surplus cannot bypass paid ownership during installation"
	)
	_check(
		(
			host.get_child_count() == count
			and host.has_node("BackWall")
			and not lab.has_meta("stadium_property")
		),
		"rejected fixtures leave original field intact"
	)
