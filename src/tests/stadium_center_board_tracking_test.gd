extends "res://src/tests/stadium_offset_tracking_test.gd"
## Reuse ordinary normal-size ball, dynamic camera bounds and native paired-image contrast.

var _center_shape: String = "straight"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	_legacy_board_policy()
	_coverage_policy_controls()
	# Headless qualifies timestep sensitivity; native qualifies the same paths at
	# 60 Hz with the authored 0.075 m shell ball-present/absent pixel readback.
	var rates: Array[int] = [60]
	if DisplayServer.get_name() == "headless":
		rates.assign([30, 60, 120])
	for shape: String in StadiumCenterBoardCandidate.SHAPES:
		_center_shape = shape
		for fps: int in rates:
			_sample_fps = fps
			await _walls(shape, "ST-024")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro center board tracking passed: five recipes, both hands/roles, "
			+ "recursive candidate bounds and stable moving-camera paths.")
	print("CENTER_BOARD_CAMERA_POLICY ", StadiumCenterBoardVisibility.POLICY, " rates=", rates)
	get_tree().quit(0 if _failures == 0 else 1)


func _install_walls(lab: PitchBatLab, shape: String, _item: String) -> void:
	lab.set_meta("stadium_center_board_lab_only", true)
	_check(StadiumCenterBoardLab.install(lab, shape), "actual opt-in center gameplay field installs")
	if not lab.has_meta("stadium_property"):
		return
	var property: StadiumCenterBoardProperty = lab.get_meta("stadium_property")
	var visibility: StadiumCenterBoardVisibility = lab._camera_director.tracking_visibility \
		as StadiumCenterBoardVisibility
	_check(visibility != null and visibility._recipe == property.boundary.graph,
		"candidate visibility retains the installed actual graph")
	var original: BallTrackingVisibility = StadiumHeightCameraVisibility.new()
	original.configure(lab.get_node("StarterFieldGeometry"))
	var meshes: Array[MeshInstance3D] = _candidate_meshes(property.candidate.get_node("Visual"))
	_check(visibility._obstacles == original._obstacles,
		"old scenery proxies are unchanged; candidate uses its own exact mesh boxes")
	_proxy_integrity(visibility, meshes)
	_ball_margin_controls(visibility)
	_trace_shoulder_blockers(lab, visibility)
	_check(visibility._uprights == original._uprights,
		"explicit candidate mast policy does not inherit the 14 m live-pole impulse")
	var before: Array[Dictionary] = visibility._candidate_meshes.duplicate(true)
	visibility.configure(lab.get_node("StarterFieldGeometry"))
	_check(before == visibility._candidate_meshes, "reconfigure never duplicates candidate proxies")
	lab._start_new_match()
	_check(lab._camera_director.tracking_visibility == visibility
		and before == visibility._candidate_meshes and PhysicalMatchReport.capture(lab).is_empty(),
		"restart keeps qualified camera policy and candidate-only report suppression")
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	for left: bool in [false, true]:
		lab._camera_director.set_batter_handedness(left)
		for shot: int in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING,
			MatchCameraDirector.Shot.SIDE, MatchCameraDirector.Shot.FOUL_SIDE,
			MatchCameraDirector.Shot.OUTFIELD]:
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera, Vector3(0, 1, 5))
			_check(lab._camera.global_transform.is_finite(), "fixed role/side/foul views are finite")
			_check(not (property.candidate.global_transform * StadiumCenterBoardCandidate.ENVELOPE)
				.grow(lab._camera.near * 2).has_point(lab._camera.global_position),
				"fixed camera clears complete raised candidate reservation")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	_check(is_equal_approx(ball.radius_m, 0.0365), "normal physical ball radius is unchanged")
	var visual: WiffleBallVisual
	for child: Node in ball.get_children():
		if child is WiffleBallVisual:
			visual = child
			break
	var rendered: ArrayMesh = visual.mesh as ArrayMesh if visual != null else null
	_check(rendered != null and visual.authored_mesh(), "normal visual retains its authored shell")
	if rendered != null:
		# Measure the actual authored shell vertices in world space.
		# Tessellated rings need not touch every nominal equatorial AABB extent.
		var arrays: Array = rendered.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var radius: float = 0
		var world_bounds: AABB = AABB(visual.global_position, Vector3.ZERO)
		for vertex: Vector3 in vertices:
			var world: Vector3 = visual.global_transform * vertex
			radius = maxf(radius, world.distance_to(visual.global_position))
			world_bounds = world_bounds.expand(world)
		var nominal: float = StadiumCenterBoardVisibility.BALL_RENDER_RADIUS
		print("CENTER_BOARD_BALL_SIZE physics=", ball.radius_m,
			" authored_radius=", WiffleBallVisual.RADIUS,
			" world_scale=", visual.global_basis.get_scale(),
			" mesh_aabb=", visual.get_aabb().size, " vertex_aabb=", world_bounds.size,
			" world_vertex_radius=", radius, " vertices=", vertices.size())
		_check(is_equal_approx(WiffleBallVisual.RADIUS, nominal)
			and visual.transform == Transform3D.IDENTITY and ball.scale == Vector3.ONE
			and visual.global_basis.is_equal_approx(Basis.IDENTITY)
			and absf(radius - nominal) < 0.00001 and not vertices.is_empty(),
			"LOS padding covers the actual normal rendered world radius, including parent scale")
		for size: float in [world_bounds.size.x, world_bounds.size.y, world_bounds.size.z]:
			_check(size <= nominal * 2 + 0.00001 and size >= nominal * 1.9,
				"actual tessellated ball extent fits its nominal diameter without resizing")
	ball.free()


func _candidate_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null and node.visible:
		result.append(node)
	for child: Node in node.get_children():
		result.append_array(_candidate_meshes(child))
	return result


func _proxy_integrity(visibility: StadiumCenterBoardVisibility,
	meshes: Array[MeshInstance3D]) -> void:
	_check(visibility._candidate_meshes.size() == meshes.size() and meshes.size() > 20,
		"every nested visual mesh has an exact candidate proxy, including thin details")
	var empty_corners: int = 0
	for index in range(meshes.size()):
		var mesh: MeshInstance3D = meshes[index]
		var proxy: Dictionary = visibility._candidate_meshes[index]
		_check(mesh.mesh is BoxMesh and proxy.bounds == mesh.get_aabb()
			and proxy.pose == mesh.global_transform
			and proxy.inverse.is_equal_approx(mesh.global_transform.affine_inverse()),
			"authored box retains exact local bounds and full world transform")
		var bounds: AABB = proxy.bounds
		var center: Vector3 = bounds.get_center()
		var offset: Vector3 = Vector3(0, 0, bounds.size.z + 1)
		_check(StadiumCenterBoardVisibility.proxy_intersects(proxy,
			proxy.pose * (center - offset), proxy.pose * (center + offset), 0),
			"a ray through each mesh center is still blocked by its proxy")
		var world: AABB = mesh.global_transform * mesh.get_aabb()
		if not String(mesh.name).begins_with("CrossBrace"):
			continue
		for x: float in [0.1, 0.9]:
			for y: float in [0.1, 0.9]:
				var from: Vector3 = Vector3(lerpf(world.position.x, world.end.x, x),
					lerpf(world.position.y, world.end.y, y), world.position.z - 1)
				var to: Vector3 = Vector3(from.x, from.y, world.end.z + 1)
				if world.intersects_segment(from, to) != null and not (
					StadiumCenterBoardVisibility.proxy_intersects(proxy, from, to, 0)):
					empty_corners += 1
	_check(empty_corners >= 4, "rotated brace proxies leave their real empty corner triangles open")


func _endpoints(_depth: float) -> Array[Vector3]:
	var graph: StadiumRecipeBoundary = StadiumCenterBoardCandidate.graph_for(_center_shape)
	var result: Array[Vector3] = []
	for row: Dictionary in graph.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		for fraction: float in [0.05, 0.5, 0.95]:
			var at: Vector2 = row.a.lerp(row.b, fraction) + graph.inward(row) * 0.15
			result.append(Vector3(at.x, 0.15, at.y))
		var joint: Vector2 = row.a + row.a.direction_to(Vector2(0, 10)) * 0.2
		result.append(Vector3(joint.x, 0.15, joint.y))
	# Side/foul, ground/deep/terminal, and airborne paths in front of and beyond
	# the raised cabinet exercise its supports without aiming a ball into scenery.
	result.append_array([Vector3(7, 0.15, 11.75), Vector3(-25, 1.8, 18),
		Vector3(25, 1.8, 18), Vector3(0, 7, 30), Vector3(0, 35, 31),
		Vector3(-5, 7, 32.5), Vector3(5, 7, 32.5)])
	return result


func _legacy_board_policy() -> void:
	_check(not StadiumPurchases.DISPLAYS.has("ST-090"), "old display catalog remains frozen")
	var board: Node3D = StadiumScoreboardModels.create("ST-090", "electronic-v2")
	board.transform = StadiumScoreboardSites.pose("BOARD-RIGHT-v2")
	add_child(board)
	var original: BallTrackingVisibility = BallTrackingVisibility.new()
	original._collect(board.get_node("Visual"), not StadiumPurchases.DISPLAYS.has("ST-090"))
	_check(not original._uprights.is_empty(),
		"old electronic board still has original narrow uprights")
	if not original._uprights.is_empty():
		_check(is_equal_approx(original.lateral_clearance(original._uprights[0].get_center()), 14),
			"old board's 14 m clearance behavior is unchanged")
	board.free()


func _contrast(camera: Camera3D, ball: Node3D) -> float:
	var contrast: float = await super._contrast(camera, ball)
	if not _capture_dir.is_empty():
		var lab: PitchBatLab = ball.get_parent() as PitchBatLab
		var paths: Array[Vector3] = _endpoints(0)
		var path_index: int = -1
		for index in range(paths.size()):
			if paths[index].is_equal_approx(ball.position):
				path_index = index
				break
		_check(path_index >= 0, "native capture has an exact sampled-path identity")
		var name_value: String = "center-board-live-%s-%s-%s-path%02d" % [_center_shape,
			"left" if lab._camera_director._batter_side < 0 else "right",
			"pitching" if lab._camera_director._live_coverage._defense else "batting", path_index]
		print("CENTER_BOARD_NATIVE_PATH ", name_value, " endpoint=", ball.position,
			" physics_radius=", (ball as BattedBallBody).radius_m,
			" render_radius=", StadiumCenterBoardVisibility.BALL_RENDER_RADIUS, " contrast=", contrast)
		await _shot(name_value)
	return contrast


func _shot(name_value: String) -> void:
	# All native paths are captured above, rather than the inherited one-view alias.
	if name_value.begins_with("center-board-live-"):
		await super._shot(name_value)


func _trace_shoulder_blockers(lab: PitchBatLab, visibility: StadiumCenterBoardVisibility) -> void:
	# Preserve a diagnostic for the previously failing path, independent of the
	# inherited pass/fail sweep. This distinguishes exact solids from padded hits.
	var director: MatchCameraDirector = lab._camera_director
	for defense: bool in [false, true]:
		director.clear_presentation_motion()
		director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
			else MatchCameraDirector.Shot.BATTING)
		director.snap(lab._camera)
		var endpoint: Vector3 = Vector3(5, 7, 32.5)
		director.prepare_ball_in_play(defense, Vector3(0, 1, 0), endpoint - Vector3(0, 1, 0))
		director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
		var reported: Dictionary = {}
		for frame in range(_sample_fps * 4):
			var ball: Vector3 = Vector3(0, 1, 0).lerp(endpoint,
				minf(1, frame / (_sample_fps * 2.5)))
			director.update(lab._camera, 1.0 / _sample_fps, true, ball)
			var hit: Dictionary = visibility.candidate_blocker(lab._camera.global_position, ball)
			if hit.is_empty() or reported.has(hit.path):
				continue
			reported[hit.path] = true
			print("CENTER_BOARD_OCCLUSION_TRACE ", _center_shape, " defense=", defense,
				" fps=", _sample_fps, " frame=", frame, " camera=", lab._camera.global_position,
				" ball=", ball, " padded=", hit.path, " raw=",
				visibility.candidate_blocker(lab._camera.global_position, ball, 0).get("path", ""))


func _ball_margin_controls(visibility: StadiumCenterBoardVisibility) -> void:
	var margin: float = StadiumCenterBoardVisibility.LOS_MARGIN
	_check(margin > StadiumCenterBoardVisibility.BALL_RENDER_RADIUS,
		"candidate margin includes the whole rendered ball and a positive edge tolerance")
	for proxy: Dictionary in visibility._candidate_meshes:
		var bounds: AABB = proxy.bounds
		var center: Vector3 = bounds.get_center()
		var edge: Vector3 = Vector3(bounds.end.x
			+ StadiumCenterBoardVisibility.BALL_RENDER_RADIUS * 0.75, center.y, center.z)
		var offset: Vector3 = Vector3(0, 0, bounds.size.z + 1)
		var from: Vector3 = proxy.pose * (edge - offset)
		var to: Vector3 = proxy.pose * (edge + offset)
		_check(not StadiumCenterBoardVisibility.proxy_intersects(proxy, from, to, 0)
			and StadiumCenterBoardVisibility.proxy_intersects(proxy, from, to),
			"ball-sized overlap beside every exact mesh edge remains blocked")
	var shoulder_camera: Vector3 = Vector3(-4.088054, 11.42096, -7.961359)
	var shoulder_ball: Vector3 = Vector3(5, 7, 32.5)
	_check(not visibility.candidate_blocker(shoulder_camera, shoulder_ball, 0.4).is_empty()
		and visibility.candidate_blocker(shoulder_camera, shoulder_ball, 0).is_empty()
		and visibility.candidate_blocker(shoulder_camera, shoulder_ball).is_empty(),
		"documented shoulder ray clears real geometry and the complete normal ball silhouette")


func _coverage_policy_controls() -> void:
	for defense: bool in [false, true]:
		for launch: Vector3 in [Vector3(-5, 6, 32.5), Vector3(5, 6, 32.5),
			Vector3(-25, 0.8, 18), Vector3(25, 0.8, 18), Vector3(0, 6, 30),
			Vector3(0, 34, 31),
			Vector3(5, 6, -8)]:
			var original: BallInPlayCamera = BallInPlayCamera.new()
			var candidate: StadiumCenterBoardCameraMotion = StadiumCenterBoardCameraMotion.new()
			original.prepare(defense, Vector3(0, 1, 0), launch)
			candidate.prepare(defense, Vector3(0, 1, 0), launch)
			var outer_shoulder: bool = defense and launch.z > 0 and launch.y > 3 \
				and absf(launch.x) > 1
			_check(candidate._side == (signf(launch.x) if outer_shoulder else original._side),
				"only candidate forward airborne defense selects the launch-side corridor")
			_check(candidate._air_coverage == original._air_coverage
				and candidate._ground_coverage == original._ground_coverage
				and candidate._carry == original._carry and candidate._velocity == Vector3.ZERO
				and candidate._turn_speed == 0,
				"candidate keeps normal coverage estimates and resets the bounded integrator")
