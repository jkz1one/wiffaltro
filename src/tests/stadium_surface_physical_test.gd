extends "res://src/tests/stadium_physical_test.gd"
## Two paid-surface home games, frozen report11 replay and unchanged baseball rules.

const SURFACE_UI_TEST_SCRIPT_PATH: String = (
	"res://src/tests/stadium_surface_ui_test.gd"
)

var _owned_layout: Dictionary = {}
var _terrain_mode: bool = false
var _terrain_checks: int = 0
var _terrain_output: String = ""
var _terrain_retained: Array[Dictionary] = []
var _terrain_state: String = "all"
var _terrain_views_only: bool = false
var _terrain_views: Array[Dictionary] = []
var _terrain_native: Node


func _complete_boundary() -> bool:
	return true


func _begin(app: SeasonApp) -> void:
	var helper: Node = load(SURFACE_UI_TEST_SCRIPT_PATH).new()
	app.season = helper._fund_surface()
	_check(helper._failures == 0, "closed synthetic new-origin funding validates")
	helper.free()
	app.begin_season(96, true)
	for item: String in ["grass", "ground_prep"]:
		_check(
			(
				ClubConstruction
				. buy_surface(app.season, item, ClubPlayers.assets(app.season.career).revision())
				. ok
			),
			"separate exact paid surface upgrade"
		)
	for item: String in ["ST-063b", "ST-063g"]:
		_check(
			(
				ClubConstruction
				. buy_style(app.season, item, ClubPlayers.assets(app.season.career).revision())
				. ok
			),
			"independent later pattern and cut"
		)
	_owned_layout = StadiumSurfaceLayout.upgrade(
		super._layout(), ClubPlayers.assets(app.season.career).surface_owned(), true
	)
	_owned_layout.surface.height = "long"
	_owned_layout.styles.grass = "ST-063b"
	_owned_layout.ground = "ST-063g"


func _layout() -> Dictionary:
	return _owned_layout.duplicate(true)


func _report_version() -> int:
	return 11


func _verification_seed(source: MatchState) -> int:
	return int(source.stadium.environment.seed)


func _tamper(report: Dictionary, source: MatchState) -> void:
	super._tamper(report, source)
	_check(
		(
			report.version == 11
			and report.property.version == 9
			and report.property.layout.version == 12
			and report.property.environment.mode == "day"
		),
		"actual new surface report carries frozen owned daylight appearance"
	)
	var bad: Dictionary = report.duplicate(true)
	bad.property.surface_access = []
	_check(not PhysicalMatchReport.valid(bad), "unowned grass cannot enter a physical report")
	bad = report.duplicate(true)
	bad.property.layout.surface.height = "short"
	_check(
		PhysicalMatchReport.valid(bad) and not PhysicalStadiumReport.matches(bad, source.stadium),
		"another legal appearance cannot impersonate the actual frozen field"
	)
	bad = report.duplicate(true)
	bad.version = 10
	bad.resolver = PhysicalStadiumReport.RECIPE_RESOLVER
	_check(not PhysicalMatchReport.valid(bad), "old wall report cannot smuggle a new surface")
	bad = report.duplicate(true)
	bad.property.version = 8
	bad.property.erase("environment")
	_check(
		StadiumLayoutSnapshot.valid(bad.property) and not PhysicalMatchReport.valid(bad),
		"entry snapshot is not a fixture-bound physical report"
	)


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--surface-terrain"):
		_terrain_mode = true
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				_terrain_output = argument.trim_prefix("--ui-capture-dir=")
			elif argument.begins_with("--terrain-state="):
				_terrain_state = argument.trim_prefix("--terrain-state=")
			elif argument == "--terrain-views":
				_terrain_views_only = true
		await _terrain_physical()
		return
	await super._ready()


func _check(ok: bool, message: String) -> void:
	if _terrain_mode:
		_terrain_checks += 1
	super._check(ok, message)


func _terrain_physical() -> void:
	var prior_path: String = SeasonSave.path
	var prior_error: String = SeasonSave.last_error
	var path: String = "user://surface-terrain-physical-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	_check(
		(
			not _terrain_output.is_empty()
			and DirAccess.dir_exists_absolute(_terrain_output)
			and _terrain_state in ["all", "rough", "leveled"]
			and (
				not _terrain_views_only
				or (_terrain_state == "all" and DisplayServer.get_name() != "headless")
			)
		),
		"bounded existing output and exact game/view selector prerequisites"
	)
	if _failures > 0:
		await _terrain_finish(path, prior_path, prior_error)
		return
	var helper: Node = load(SURFACE_UI_TEST_SCRIPT_PATH).new()
	var funding: SeasonState = helper._fund_surface()
	_check(helper._failures == 0 and funding != null, "existing closed synthetic funding setup")
	helper.free()
	if funding == null:
		await _terrain_finish(path, prior_path, prior_error)
		return
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	app.season = funding
	app.begin_season(96, true)
	var season: SeasonState = app.season
	_check(
		(
			season != null
			and season.phase == SeasonState.Phase.DRAFT
			and (
				ClubConstruction
				. buy_surface(season, "ground_prep", ClubPlayers.assets(season.career).revision())
				. ok
			)
		),
		"one ordinary preparation purchase for both terrain states"
	)
	if _failures > 0:
		app.free()
		await _terrain_finish(path, prior_path, prior_error)
		return
	if _terrain_views_only:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_terrain_native = (
			load("res://src/tests/stadium_mounted_scoreboard_capture_support.gd").new()
		)
		add_child(_terrain_native)
		await _terrain_native.initialize()
		_check(_terrain_native._failures == 0, "existing native window handshake succeeds")
		if _failures > 0:
			app.free()
			await _terrain_finish(path, prior_path, prior_error)
			return
	for mode: String in ["rough", "leveled"]:
		if _terrain_state != "all" and mode != _terrain_state:
			continue
		var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
		var active: Dictionary = paid.view().stadium_active
		if active.get("version") == 17:
			active = StadiumSurfaceLayout.terrain_base(active)
		var layout: Dictionary = StadiumSurfaceLayout.terrain_upgrade(active, paid.surface_owned())
		if layout.is_empty():
			_check(false, "exact terrain draft prerequisite refused before game")
			break
		layout.surface.condition = "rough" if mode == "rough" else "prepared"
		var balance: int = season.career.balance()
		_check(
			(
				ClubConstruction.save_draft(season, layout, paid.revision()).ok
				and (
					ClubConstruction
					. apply_draft(season, layout, ClubPlayers.assets(season.career).revision())
					. ok
				)
				and season.career.balance() == balance
			),
			"ordinary free terrain draft/apply: " + mode
		)
		var saved: Dictionary = SeasonSave.snapshot(season)
		var bytes: String = FileAccess.get_file_as_string(path)
		var clone: SeasonState = SeasonSave._decode(saved)
		_check(
			(
				saved.get("version") == 74
				and clone != null
				and clone.round_index == 0
				and clone.player_results.is_empty()
			),
			"valid current Save74 before detached game: " + mode
		)
		if clone == null or _failures > 0:
			break
		for pick in range(4):
			if clone.offers().is_empty() or not clone.choose_player(clone.offers()[0]):
				_check(false, "ordinary detached draft exhausted")
				break
		var fixture: Dictionary = {}
		for game: Dictionary in clone.schedule:
			if game.home == 0:
				fixture = game
				break
		_check(
			not fixture.is_empty() and clone.round_index == 0 and clone.player_results.is_empty(),
			"select existing future home fixture without changing cursor/history"
		)
		if fixture.is_empty() or _failures > 0:
			break
		var source: MatchState = SeasonPhysicalFixtures.match_for(clone, fixture)
		if _terrain_views_only:
			await _terrain_view(
				app, source, ClubPlayers.assets(clone.career), mode, saved, bytes, balance
			)
			if _failures > 0:
				break
			continue
		var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
		add_child(runner)
		runner.finished.connect(_terrain_completed.bind(mode, saved, bytes))
		runner.failed.connect(func(reason: String) -> void: _errors.append(reason))
		var count: int = _reports.size() + 1
		_check(
			runner.start(
				source,
				SeasonPhysicalFixtures.seed_for(clone, fixture),
				PitchBatLab.FIELD_ID,
				ClubPlayers.assets(clone.career)
			),
			"one actual bound detached game starts: " + mode
		)
		if runner._lab == null or _failures > 0:
			runner.cancel()
			runner.free()
			break
		_check(
			StadiumSurfaceTerrainRuntime.installed_bound(runner._lab, source.stadium),
			"actual running report authority is installed: " + mode
		)
		await _complete(count)
		_check(
			_errors.is_empty() and _reports.size() == count, "one actual game completed: " + mode
		)
		if _reports.size() != count:
			runner.cancel()
			runner.free()
			break
		var report: Dictionary = _reports[-1]
		_check(
			_terrain_retained.size() == count and _terrain_retained[-1].ok,
			"actual report and unchanged save retained before later validation: " + mode
		)
		_check(
			(
				report.get("version") == 26
				and PhysicalMatchReport.valid(report)
				and PhysicalStadiumReport.matches(report, source.stadium)
				and PhysicalChoiceEvidence.matches(report, source)
				and PhysicalTacticalEvidence.report_matches(report, source)
			),
			"full physical report26 validates: " + mode
		)
		_check(
			(
				PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report)))
				and ClubCareer.same(
					JSON.parse_string(
						FileAccess.get_file_as_string(
							_terrain_output.path_join("terrain-" + mode + "-report.json")
						)
					),
					report
				)
			),
			"retained report canonical cold join: " + mode
		)
		var bad: Dictionary = report.duplicate(true)
		bad.property.terrain.height = -1
		_check(not PhysicalMatchReport.valid(bad), "forged terrain physics refuses: " + mode)
		bad = report.duplicate(true)
		bad.version = 11
		bad.resolver = PhysicalStadiumReport.SURFACE_RESOLVER
		_check(
			not PhysicalMatchReport.valid(bad),
			"old flat report cannot carry actual terrain: " + mode
		)
		bad = report.duplicate(true)
		bad.property.version = 28
		bad.property.erase("environment")
		_check(
			StadiumLayoutSnapshot.valid(bad.property) and not PhysicalMatchReport.valid(bad),
			"entry cannot replace fixture-bound report: " + mode
		)
		_check(
			(
				FileAccess.get_file_as_string(path) == bytes
				and season.career.balance() == balance
				and ClubCareer.same(saved, SeasonSave.snapshot(season))
				and SeasonSave.restore() != null
			),
			"actual detached game leaves valid season/state/wallet bytes unchanged: " + mode
		)
		runner.free()
		if _failures > 0:
			break
	if _terrain_views_only:
		_check(
			(
				_terrain_views.size() == 2
				and _terrain_checks + 1 == 25
				and _terrain_views[0].pose == _terrain_views[1].pose
				and _terrain_views[0].fov == _terrain_views[1].fov
				and _terrain_views[0].projection == _terrain_views[1].projection
				and _terrain_views[0].size == _terrain_views[1].size
			),
			"exact two ordinary matched camera views, with no game or added comparison matrix"
		)
	app.free()
	await _terrain_finish(path, prior_path, prior_error)


func _terrain_completed(report: Dictionary, mode: String, saved: Dictionary, bytes: String) -> void:
	# Synchronous completed callback retains authority before any later assertion can fail.
	_reports.append(report.duplicate(true))
	var okay: bool = true
	for pair: Array in [
		["report", JSON.stringify(report, "", true, true)],
		["save", bytes],
		["snapshot", JSON.stringify(saved, "", true, true)]
	]:
		var file: FileAccess = FileAccess.open(
			_terrain_output.path_join("terrain-" + mode + "-" + pair[0] + ".json"), FileAccess.WRITE
		)
		if file == null:
			okay = false
			continue
		file.store_string(pair[1])
		file.flush()
		okay = file.get_error() == OK and okay
		file.close()
	_terrain_retained.append({"mode": mode, "ok": okay})


func _terrain_finish(path: String, prior_path: String, prior_error: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	SeasonSave.path = prior_path
	SeasonSave.last_error = prior_error
	if _terrain_views_only:
		print(
			(
				"STADIUM_SURFACE_TERRAIN_VIEWS checks=%d failures=%d captures=%d games=0 synthetic_history=true"
				% [_terrain_checks, _failures, _terrain_views.size()]
			)
		)
	else:
		print(
			(
				(
					"STADIUM_SURFACE_TERRAIN_PHYSICAL checks=%d failures=%d games=%d reports=%d "
					+ "synthetic_history=true"
				)
				% [_terrain_checks, _failures, _reports.size(), _terrain_retained.size()]
			)
		)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _terrain_view(
	app: SeasonApp,
	source: MatchState,
	paid: ClubAssetLedger,
	mode: String,
	saved: Dictionary,
	bytes: String,
	balance: int
) -> void:
	# A separate no-game view action: ordinary geometry/camera, no pixel processing.
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = source
	lab._stadium_ledger = paid
	var configured: bool = StadiumSurfaceTerrainRuntime.configure(lab, paid)
	var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	if configured:
		add_child(lab)
	_check(
		(
			configured
			and is_instance_valid(lab)
			and lab._match_state == source
			and StadiumSurfaceTerrainRuntime.current(lab) == owner
			and StadiumSurfaceTerrainRuntime.installed_bound(lab, source.stadium)
		),
		"ordinary no-game view installs exact paid terrain: " + mode
	)
	if _failures > 0:
		StadiumSurfaceTerrainRuntime.retire_captured(lab, owner)
		if is_instance_valid(lab):
			lab.free()
		return
	var material: ShaderMaterial = owner._material
	var original_wear: Variant = material.get_shader_parameter("terrain_wear")
	var captured_wear: Variant = owner._material_values.back()
	var captured_values: Array = owner._material_values.duplicate(true)
	var issued_nodes: Array[WeakRef] = [
		weakref(owner._property),
		weakref(owner._terrain),
		weakref(owner._visual),
		weakref(owner._body),
		weakref(owner._shape_node)
	]
	_check(
		(
			original_wear is bool
			and original_wear == true
			and captured_wear is bool
			and captured_wear == original_wear
			and owner.phase == StadiumSurfaceTerrainRuntime.Phase.ACTIVE
		),
		"terrain-only wear Boolean is captured exactly by the active owner: " + mode
	)
	if _failures > 0:
		StadiumSurfaceTerrainRuntime.retire_captured(lab, owner)
		lab.free()
		return
	var pause_helper: Node = load("res://src/tests/stadium_surface_night_gameplay_a_test.gd").new()
	pause_helper._pause(lab)
	pause_helper.free()
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab._camera_director.clear_presentation_motion()
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.snap(lab._camera)
	var camera: Camera3D = lab._camera
	var pose: Transform3D = camera.global_transform
	var fov: float = camera.fov
	var projection: int = camera.projection
	var center: Vector3 = StadiumSurfaceTerrain.support(Vector2(2, 11.5), mode).position
	var framed: bool = (
		not camera.is_position_behind(center)
		and get_viewport().get_visible_rect().has_point(camera.unproject_position(center))
	)
	_check(
		(
			framed
			and camera.current
			and lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING
		),
		"ordinary pitching camera frames the actual terrain patch: " + mode
	)
	var prior_paused: bool = get_tree().paused
	var prior_mode: Node.ProcessMode = lab.process_mode
	var prior_menu: bool = app.menu.visible
	var before_records: int = lab._play_records.size()
	var before_throw: int = lab._throw_number
	app.menu.hide()
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	var label: String = "terrain-" + mode + "-pitching"
	var captured: bool = await _terrain_native.capture(_terrain_output, label)
	var extent: Vector2i = _terrain_native._expected_content_size(get_window().size)
	var filename: String = "%s-%dx%d.png" % [label, extent.x, extent.y]
	var image: Image = (
		Image.load_from_file(_terrain_output.path_join(filename)) if captured else null
	)
	_check(
		captured and image != null and not image.is_empty() and image.get_size() == extent,
		"native ordinary view is retained at exact content dimensions: " + mode
	)
	lab.process_mode = prior_mode
	get_tree().paused = prior_paused
	app.menu.visible = prior_menu
	var exact: bool = (
		is_instance_valid(lab)
		and lab._match_state == source
		and StadiumSurfaceTerrainRuntime.current(lab) == owner
		and lab._camera == camera
		and camera.global_transform == pose
		and camera.fov == fov
		and camera.projection == projection
		and lab.process_mode == prior_mode
		and get_tree().paused == prior_paused
		and lab._play_records.size() == before_records
		and lab._throw_number == before_throw
		and before_records == 0
		and before_throw == 0
		and not lab._pitch_actor.running
		and not is_instance_valid(lab._batted_ball)
		and StadiumSurfaceTerrainRuntime.installed_bound(lab, source.stadium)
		and FileAccess.get_file_as_string(SeasonSave.path) == bytes
		and app.season.career.balance() == balance
		and ClubCareer.same(saved, SeasonSave.snapshot(app.season))
	)
	_check(
		exact,
		(
			"capture restores exact pause/menu and full terrain/save authority without a delivery: "
			+ mode
		)
	)
	var row: Dictionary = {}
	if captured and image != null and exact:
		row = {
			"mode": mode,
			"image": filename,
			"size": [extent.x, extent.y],
			"view": "ordinary_pitching",
			"pose":
			[
				pose.basis.x.x,
				pose.basis.x.y,
				pose.basis.x.z,
				pose.basis.y.x,
				pose.basis.y.y,
				pose.basis.y.z,
				pose.basis.z.x,
				pose.basis.z.y,
				pose.basis.z.z,
				pose.origin.x,
				pose.origin.y,
				pose.origin.z
			],
			"fov": fov,
			"projection": projection,
			"terrain_height_m": source.stadium.terrain.height,
			"patch_framed": framed,
			"full_authority": exact,
			"games": 0,
			"deliveries": 0,
			"working_physics_tuning": true,
			"visible_decrepit_starter_qualified": false
		}
	# Exercise the new Boolean only after retaining the unchanged ordinary view.
	material.set_shader_parameter("terrain_wear", false)
	var mutated_wear: Variant = material.get_shader_parameter("terrain_wear")
	var refused: bool = not StadiumSurfaceTerrainRuntime.action_allowed(lab)
	var abandoned: bool = owner.phase == StadiumSurfaceTerrainRuntime.Phase.ABANDONED
	material.set_shader_parameter("terrain_wear", original_wear)
	var restored: bool = material.get_shader_parameter("terrain_wear") == original_wear
	var not_revived: bool = not StadiumSurfaceTerrainRuntime.boundary_allowed(lab)
	_check(
		(
			mutated_wear is bool
			and mutated_wear == false
			and refused
			and abandoned
			and restored
			and not_revived
			and owner.phase == StadiumSurfaceTerrainRuntime.Phase.ABANDONED
			and owner._material == material
			and owner._material_values == captured_values
		),
		(
			"wear mutation refuses immediately and exact uniform restoration does not revive authority: "
			+ mode
		)
	)
	lab.free()
	await get_tree().process_frame
	var owned_nodes_freed: bool = true
	for issued: WeakRef in issued_nodes:
		owned_nodes_freed = issued.get_ref() == null and owned_nodes_freed
	_check(
		(
			not is_instance_valid(lab)
			and owned_nodes_freed
			and app.menu.visible == prior_menu
			and get_tree().paused == prior_paused
			and material.get_shader_parameter("terrain_wear") == original_wear
			and FileAccess.get_file_as_string(SeasonSave.path) == bytes
		),
		(
			"exact captured view lab/terrain are disposed and shared presentation/save remain restored: "
			+ mode
		)
	)
	if not row.is_empty():
		row["material_guard_after_capture"] = {
			"original": original_wear,
			"captured": captured_wear,
			"mutated": mutated_wear,
			"immediate_refused": refused,
			"abandoned": abandoned,
			"restored": restored,
			"not_revived": not_revived,
			"owned_nodes_freed": owned_nodes_freed
		}
		_terrain_views.append(row)
		print("STADIUM_SURFACE_TERRAIN_VIEW ", JSON.stringify(row, "", true, true))
