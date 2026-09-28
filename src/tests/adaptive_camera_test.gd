extends Node


class TerrainProvider:
	extends Node3D
	var bounds: AABB
	var grade: float = 0.0

	func camera_play_bounds() -> AABB:
		return bounds

	func camera_ground_height(point: Vector3) -> float:
		return maxf(0.0, point.z) * grade


var _failures: int = 0


func _ready() -> void:
	_test_batting_history()
	_test_dynamic_obstacles()
	await _test_stadiums()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro adaptive camera checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_batting_history() -> void:
	var fixture: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://src/tests/fixtures/batting_camera_665b46e.json")
	)
	var index: int = 0
	for left in [false, true]:
		for launch in [Vector3(0, -2, 8), Vector3(5, 2, 25), Vector3(-8, 18, 26)]:
			var camera: Camera3D = Camera3D.new()
			camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			add_child(camera)
			var director: MatchCameraDirector = MatchCameraDirector.new()
			director.set_batter_handedness(left)
			director.snap(camera)
			director.prepare_ball_in_play(false, Vector3(0, 1, 0.28), launch)
			director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
			for frame in range(60):
				var t: float = (frame + 1) / 60.0
				var ball: Vector3 = Vector3(0, 1, 0.28) + launch * t + Vector3(0, -4.905 * t * t, 0)
				ball.y = maxf(0.08, ball.y)
				director.update(camera, 1.0 / 60.0, true, ball)
				if frame + 1 in [1, 15, 30, 60]:
					var expected: Dictionary = fixture.rows[index]
					var p: Array = expected.position
					var q: Array = expected.rotation
					_check(
						camera.position.distance_to(Vector3(p[0], p[1], p[2])) < 0.0001,
						"offensive follow matches historical position " + str(index)
					)
					_check(
						(
							camera.basis.get_rotation_quaternion().angle_to(
								Quaternion(q[0], q[1], q[2], q[3])
							)
							< 0.001
						),
						"offensive follow matches historical orientation " + str(index)
					)
					index += 1
			camera.free()
	_check(index == 24, "both batting sides cover all historical snapshots")


func _test_dynamic_obstacles() -> void:
	var geometry: Node3D = Node3D.new()
	add_child(geometry)
	var visibility: BallTrackingVisibility = BallTrackingVisibility.new()
	visibility.configure(geometry)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "GeneratedObstacleUnrelatedToAnyVenue"
	mesh.set_meta(&"camera_occluder", true)
	mesh.mesh = BoxMesh.new()
	mesh.position = Vector3(0, 1, 5)
	var original: StandardMaterial3D = StandardMaterial3D.new()
	mesh.material_override = original
	geometry.add_child(mesh)
	visibility.update_occluders(Vector3(0, 1, 10), Vector3(0, 1, 0), 0.3)
	_check(mesh.material_override != original, "new generated geometry becomes an occluder")
	mesh.position.x = 10
	visibility.update_occluders(Vector3(0, 1, 10), Vector3(0, 1, 0), 1.0)
	_check(
		mesh.material_override == original, "moving geometry updates bounds and restores material"
	)
	mesh.position.x = 0
	visibility.update_occluders(Vector3(0, 1, 10), Vector3(0, 1, 0), 0.1)
	mesh.free()
	visibility.update_occluders(Vector3(0, 1, 10), Vector3(0, 1, 0), 0.3)
	_check(visibility._faded.is_empty(), "removing a faded prop leaves no stale reference")
	geometry.free()


func _test_stadiums() -> void:
	var rows: Array = []
	for depth in [18.0, 32.0, 55.0]:
		for size in [Vector2i(1280, 720), Vector2i(900, 900)]:
			var viewport: SubViewport = SubViewport.new()
			viewport.size = size
			add_child(viewport)
			var geometry: TerrainProvider = TerrainProvider.new()
			geometry.bounds = AABB(Vector3(-depth * 0.7, 0, 0), Vector3(depth * 1.6, 4, depth))
			geometry.grade = 0.08 if depth == 55.0 else 0.0
			viewport.add_child(geometry)
			geometry.position = Vector3(9, 2, -4)
			geometry.rotation.y = 0.3
			var camera: Camera3D = Camera3D.new()
			camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			viewport.add_child(camera)
			var field: FieldDefinition = FieldDefinition.new()
			field.back_wall_z_m = depth
			var director: MatchCameraDirector = MatchCameraDirector.new()
			director.configure_field(field, geometry, Vector3(0, 0, 13.716))
			_check(
				is_equal_approx(director.field_context.depth_m(), depth), "active provider bounds"
			)
			geometry.bounds.size.z += 5.0
			_check(
				is_equal_approx(director.field_context.depth_m(), depth + 5.0), "bounds remain live"
			)
			geometry.bounds.size.z = depth
			for fps in [30, 120]:
				for launch in [
					Vector3(0, -2, 8),
					Vector3(5, -1, 22),
					Vector3(0, 2, 33),
					Vector3(0, 18, 26),
					Vector3(0, 22, 5)
				]:
					rows.append(_flight(director, camera, geometry, launch, fps))
			viewport.queue_free()
			await get_tree().process_frame
	print("ADAPTIVE_CAMERA_JSON=", JSON.stringify(rows))


func _flight(
	director: MatchCameraDirector,
	camera: Camera3D,
	geometry: TerrainProvider,
	launch: Vector3,
	fps: int
) -> Dictionary:
	director.set_shot(MatchCameraDirector.Shot.PITCHING)
	director.snap(camera)
	var ball: Vector3 = Vector3(0, 1, 0.28)
	var velocity: Vector3 = launch
	var defender: Vector3 = Vector3(4, 0, geometry.bounds.size.z * 0.65)
	var transform: Transform3D = geometry.global_transform
	director.prepare_ball_in_play(true, transform * ball, transform.basis * launch)
	director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	var outside: int = 0
	var actor_outside: int = 0
	var distance: float = 0.0
	var rotation: float = 0.0
	var grounded: bool = false
	var actor_min_px: float = INF
	for frame in range(fps * 3):
		for substep in range(120 / fps):
			velocity += (
				(
					Vector3(0, -9.81, 0)
					+ BattedBallAerodynamics.acceleration(
						velocity,
						Quaternion.IDENTITY,
						Vector3.ZERO,
						0.020,
						0.0365,
						0.22,
						1.0,
						1.0,
						Vector3.RIGHT
					)
				)
				/ 120.0
			)
			ball += velocity / 120.0
			var floor_y: float = geometry.camera_ground_height(ball) + 0.08
			if ball.y < floor_y:
				ball.y = floor_y
				velocity.y = absf(velocity.y) * 0.52
				grounded = true
		defender = defender.move_toward(Vector3(ball.x, defender.y, ball.z), 4.6 / fps)
		defender.y = geometry.camera_ground_height(defender)
		director.set_fielding_subjects(PackedVector3Array([transform * defender]), grounded)
		var before: Transform3D = camera.global_transform
		director.update(camera, 1.0 / fps, true, transform * ball)
		distance += before.origin.distance_to(camera.global_position)
		rotation += before.basis.get_rotation_quaternion().angle_to(
			camera.global_basis.get_rotation_quaternion()
		)
		var ground: Vector3 = Vector3(ball.x, geometry.camera_ground_height(ball), ball.z)
		for point in [transform * ball, transform * ground]:
			outside += int(not _visible(camera, point))
		if defender.distance_to(ground) < 3.0:
			var foot: Vector3 = transform * defender
			var head: Vector3 = transform * (defender + Vector3.UP * 1.7)
			actor_outside += int(not _visible(camera, foot) or not _visible(camera, head))
			actor_min_px = minf(
				actor_min_px,
				camera.unproject_position(foot).distance_to(camera.unproject_position(head))
			)
		_check(camera.global_transform.is_finite(), "finite camera pose across generated fields")
		if ball.z > geometry.bounds.end.z or (launch.z == 8.0 and frame + 1 >= fps / 2):
			break
	var row: Dictionary = {
		"depth": geometry.bounds.size.z,
		"viewport": str(camera.get_viewport().size),
		"fps": fps,
		"launch": str(launch),
		"outside": outside,
		"actor_outside": actor_outside,
		"path": distance,
		"rotation": rad_to_deg(rotation),
		"shot": director._live_coverage.shot_name
	}
	_check(outside == 0 and actor_outside == 0, "live subjects framed: " + str(row))
	_check(actor_min_px >= 10.0, "nearby defender retains readable height")
	if launch.z == 8.0:
		_check(
			distance < 0.7 and rotation < deg_to_rad(4.0), "soft contact stays local: " + str(row)
		)
	elif launch.y < 3.0:
		_check(rotation < deg_to_rad(55.0), "ground play avoids a sweeping turn: " + str(row))
	var settled: Transform3D = camera.global_transform
	var lens: float = camera.fov
	director.update(camera, 0.5, false, transform * ball)
	_check(
		camera.global_transform.is_equal_approx(settled) and is_equal_approx(lens, camera.fov),
		"resolved play cancels further live motion"
	)
	return row


func _visible(camera: Camera3D, point: Vector3) -> bool:
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	return (
		not camera.is_position_behind(point)
		and Rect2(Vector2.ZERO, size).grow(-8).has_point(camera.unproject_position(point))
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
