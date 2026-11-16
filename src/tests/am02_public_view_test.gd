extends "res://src/tests/stadium_npc_yard_three_installed_view_test.gd"
## Actual public AM02/r1 installation; static daylight cameras only, no game/tracking credit.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const IDS: Array[String] = ["AM-02"]
const FIXTURE = preload("res://src/tests/am02_public_fixture.gd")
const COUNTS: Dictionary = {"AM-02": 91}
var _am02_checks: int = 0
var _families: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(DisplayServer.get_name() != "headless" and not _capture_dir.is_empty(),
		"rendered daylight views require an actual display and fresh capture directory")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native startup handshake has no hidden failure")
	if _failures == 0:
		await _setup_views()
	await TestAudioDrain.finish(get_tree())
	_check(_families == 1, "the exact current public AM02 family was captured")
	if _failures == 0:
		print("Wiffaltro AM02 installed static daylight views passed: "
			+ "one family, one size, both hands, three roles.")
	print("AM02_INSTALLED_VIEWS_RESULT checks=%d failures=%d families=%d" % [
		_am02_checks, _failures, _families])
	get_tree().quit(0 if _failures == 0 else 1)


func _setup_views() -> void:
	var season: SeasonState = _season()
	_check(season != null and not season.npc_venues.is_empty(),
		"actual test-only seed3 ordinal2 map exists")
	if season == null or season.npc_venues.is_empty():
		return
	var saved: Dictionary = SeasonSave.snapshot(season)
	for id: String in IDS:
		await _view_family(season, id)
		if _failures > 0:
			break
	_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"static captures preserve save, inventory, results and saved assignment")


func _view_family(season: SeasonState, id: String) -> void:
	var fixture: Dictionary = _fixture(season, id)
	_check(not fixture.is_empty(), "actual scheduled human-away fixture " + id)
	if fixture.is_empty():
		return
	var lab: PitchBatLab = _lab(season, fixture)
	var property: StadiumNpcPublicProperty = R._property(lab)
	_check(not lab.yard_bound_startup_failed and property != null
		and R.installed_bound(lab, lab._match_state.stadium), "ordinary public startup " + id)
	if property == null or not R.installed(lab):
		lab.queue_free()
		await get_tree().process_frame
		return
	_check(property.public_bound and property.venue_id == id
		and property.objects.size() == COUNTS[id], "complete current public family " + id)
	_check(not lab.has_meta("stadium_npc_retained_lab_only")
		and not lab.has_meta("stadium_candidate_only") and lab._stadium_ledger == null,
		"public runtime has no private qualification or human ownership")
	_check(lab._match_state.stadium.environment.mode == "day"
		and lab._match_state.stadium.environment.profile.is_empty(), "saved daylight environment")
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	_check(not lab._presentation_backdrop.visible and not lab._status_label.visible,
		"setup capture has no intro/readiness overlay")
	_check(await _native.resize(Vector2i(1280, 720)), "native setup window extent acknowledged")
	await get_tree().process_frame
	await get_tree().physics_frame
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
			else PlayerDefinition.Handedness.RIGHT
		PitchBatLabPresentation.sync_players(lab)
		lab._camera_director.set_batter_handedness(left)
		for shot: int in [MatchCameraDirector.Shot.ESTABLISHING,
			MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera)
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			var target: Vector3 = Vector3(0, 1, 0)
			_check(not lab._camera.is_position_behind(target), "plate corridor remains in front")
			await _shot("am02-%s-1280x720-hand%d-shot%d" % [id.to_lower(), int(left), shot])
	await _overview(lab)
	_check(R.installed_bound(lab, lab._match_state.stadium),
		"actual public binding survives setup and overview views " + id)
	_check(lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "static views manufacture no gameplay result")
	if _failures == 0:
		_families += 1
		print("AM02_INSTALLED_VIEWS id=%s fixture=%d owner=%d objects=%d captures=7 mode=day" % [
			id, fixture.id, fixture.home, property.objects.size()])
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _overview(lab: PitchBatLab) -> void:
	_check(await _native.resize(Vector2i(1280, 720)), "complete-property overview extent acknowledged")
	var camera: Camera3D = lab._camera
	var before: Transform3D = camera.global_transform
	var projection: int = camera.projection
	var size: float = camera.size
	var fov: float = camera.fov
	var property: StadiumNpcPublicProperty = R._property(lab)
	var ground: AABB = StadiumProperty.ground_bounds(property.tier)
	var scale_value: float = ground.size.z / 42.0
	var center: Vector3 = ground.get_center()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 50 * scale_value
	camera.global_position = center + Vector3(0, 50, -45) * scale_value
	camera.look_at(center)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab, true)
	var framing: Rect2 = get_viewport().get_visible_rect().grow(-24)
	for corner in range(8):
		_check(not camera.is_position_behind(ground.get_endpoint(corner))
			and framing.has_point(camera.unproject_position(ground.get_endpoint(corner))),
			"overview frames the complete actual " + property.tier + " surface")
	for model: Node3D in property.objects.values():
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		_check(not meshes.is_empty(), "installed model has actual rendered meshes " + str(model.name))
		for mesh: MeshInstance3D in meshes:
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			for corner in range(8):
				_check(not camera.is_position_behind(bounds.get_endpoint(corner))
					and framing.has_point(camera.unproject_position(bounds.get_endpoint(corner))),
					"overview frames the full installed mesh at " + str(model.name))
	await _shot("am02-" + property.venue_id.to_lower() + "-complete-property")
	camera.projection = projection as Camera3D.ProjectionType
	camera.size = size
	camera.fov = fov
	camera.global_transform = before
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)


func _check(ok: bool, label: String) -> void:
	_am02_checks += 1
	if not ok:
		_failures += 1
		push_error("AM02_INSTALLED_VIEWS " + label)


func _season() -> SeasonState:
	return FIXTURE.season()


func _fixture(season: SeasonState, id: String) -> Dictionary:
	for fixture: Dictionary in season.schedule:
		if fixture.away != 0:
			continue
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		if not snapshot.is_empty() and snapshot.manifest.id == id:
			return fixture.duplicate(true)
	return {}


func _lab(season: SeasonState, fixture: Dictionary) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	if not lab.yard_bound_startup_failed:
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._at_bat_cadence.stop()
	return lab
