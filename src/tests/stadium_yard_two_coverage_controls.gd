extends RefCounted
## Explicit rejected prior camera coverage and authentic-boundary controls.
const Audit = preload("res://src/tests/stadium_yard_two_visibility_audit.gd")
const Histories = preload("res://src/tests/stadium_yard_two_physics_histories.gd")


static func prior_side_coverage_control(
	owner: Node, lab: PitchBatLab, histories: Array[Dictionary]
) -> void:
	var history: Dictionary = {}
	for row: Dictionary in histories:
		if row.id == "left-side":
			history = row
	owner._check(
		not history.is_empty() and not history.dead,
		"prior side obstruction control retains full live nonterminal source history"
	)
	if history.is_empty():
		return
	var camera: Camera3D = lab._camera
	var saved: Transform3D = camera.global_transform
	var saved_fov: float = camera.fov
	var saved_ball: Vector3 = lab._batted_ball.position
	var director: StadiumYardTwoCameraDirector = lab._camera_director
	var saved_shot: MatchCameraDirector.Shot = director.shot
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	director.snap(camera)
	var original: BallInPlayCamera = BallInPlayCamera.new()
	original.prepare(false, history.start, history.launch)
	for frame in range(30):
		lab._batted_ball.position = Histories.sample(history, float(frame) / 30.0)
		original.update(camera, 1.0 / 30.0, lab._batted_ball.position, director.tracking_visibility)
	var audit: Dictionary = Audit.audit(lab, {})
	var wall_hits: int = 0
	for hit: Dictionary in audit.hits:
		if hit.path.ends_with("BoundaryGraph/SIDE-L-01/TemplateWallVisual"):
			owner._check(
				hit.classification == "blocked" and not hit.behind_ball_front,
				"prior live side-wall triangles remain rejected strictly before physical ball front"
			)
			wall_hits += 1
	owner._check(wall_hits > 0, "unchanged opaque oracle still rejects prior side-wall coverage")
	print(
		"AY02_PRIOR_SIDE_COVERAGE_CONTROL time=",
		29.0 / 30.0,
		" dead=",
		history.dead,
		" ball=",
		lab._batted_ball.position,
		" camera=",
		camera.global_position,
		" wall_hits=",
		wall_hits,
		" excluded_from_valid_history_counts=true audit=",
		audit
	)
	director.shot = saved_shot
	camera.global_transform = saved
	camera.fov = saved_fov
	lab._batted_ball.position = saved_ball


static func boundary_controls(owner: Node, lab: PitchBatLab) -> void:
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var motion: StadiumYardTwoCameraMotion = lab._camera_director._live_coverage
	var boundary: StadiumBoundaryPrototype = property.get_node("BoundaryGraph")
	owner._check(
		motion._boundary_intact(), "actual boundary matches bound canonical shapes and mesh"
	)
	var mesh: MeshInstance3D = boundary.get_node("SIDE-L-01/TemplateWallVisual")
	var shape: CollisionShape3D = boundary.get_node("SIDE-L-01").get_child(0)
	var desired: Vector3 = Vector3(-12, 8, -8)
	motion.prepare(false, Vector3(0, 1, 0), Vector3(-22, 3, 10))
	owner._check(motion.constrain_target(desired) != desired, "authentic side target policy active")
	var faces: Mesh = mesh.mesh
	mesh.mesh = BoxMesh.new()
	owner._check(
		not motion._boundary_intact(), "same-name modified side-wall mesh rejects selection"
	)
	motion.prepare(false, Vector3(0, 1, 0), Vector3(-22, 3, 10))
	owner._check(
		not motion._defense and motion.coverage_boundary.is_empty(),
		"unauthenticated side mesh cannot acquire camera authority"
	)
	mesh.mesh = faces
	motion.prepare(false, Vector3(0, 1, 0), Vector3(-22, 3, 10))
	var points: PackedVector3Array = shape.shape.points
	var changed: PackedVector3Array = points.duplicate()
	changed[0] += Vector3(0, 0.1, 0)
	shape.shape.points = changed
	owner._check(
		not motion._boundary_intact() and motion.constrain_target(desired) == desired,
		"changed real collision geometry rejects selection"
	)
	shape.shape.points = points
	var pose: Transform3D = boundary.transform
	boundary.position.x += 0.1
	owner._check(
		not motion._boundary_intact() and motion.constrain_target(desired) == desired,
		"moved boundary transform rejects selection"
	)
	boundary.transform = pose
	var material: StandardMaterial3D = mesh.material_override
	var color: Color = material.albedo_color
	material.albedo_color.a = 0.5
	owner._check(
		not motion._boundary_intact() and motion.constrain_target(desired) == desired,
		"modified wall material rejects selection"
	)
	material.albedo_color = color
	boundary.name = "OriginalBoundaryControl"
	var copied: StadiumBoundaryPrototype = StadiumBoundaryPrototype.new()
	copied.name = "BoundaryGraph"
	owner._check(
		copied.build(), "copied-name boundary control constructs literal canonical geometry"
	)
	property.add_child(copied)
	owner._check(
		not motion._boundary_intact() and motion.constrain_target(desired) == desired,
		"copied canonical name and geometry cannot replace identity"
	)
	property.remove_child(copied)
	copied.free()
	boundary.name = "BoundaryGraph"
	var child: Node = Node.new()
	boundary.add_child(child)
	owner._check(
		not motion._boundary_intact() and motion.constrain_target(desired) == desired,
		"extra boundary child rejects selection"
	)
	boundary.remove_child(child)
	child.free()
	owner._check(motion._boundary_intact(), "exact boundary geometry identity and material restore")
	for launch: Vector3 in [Vector3(-22, 3, 10), Vector3(22, 3, 10)]:
		motion.prepare(false, Vector3(0, 1, 0), launch)
		owner._check(
			not motion._defense and not motion.coverage_boundary.is_empty(),
			"both side selections return only after exact restoration"
		)
	print(
		"AY02_PRECONTACT_BOUNDARY_CONTROLS mirrored=2 forged_name=1 mesh=1 shape=1",
		" transform=1 material=1 extra_child=1 restored=true"
	)


static func prior_overtaking_control(
	owner: Node, lab: PitchBatLab, histories: Array[Dictionary]
) -> void:
	var camera: Camera3D = lab._camera
	var director: StadiumYardTwoCameraDirector = lab._camera_director
	var saved: Transform3D = camera.global_transform
	var saved_fov: float = camera.fov
	var saved_shot: MatchCameraDirector.Shot = director.shot
	var saved_side: float = director._batter_side
	var total: int = 0
	var samples: int = 0
	for left: bool in [false, true]:
		director.set_batter_handedness(left)
		for history: Dictionary in histories:
			if history.id not in ["left-side", "right-side"]:
				continue
			director.set_shot(MatchCameraDirector.Shot.BATTING)
			director.snap(camera)
			var original: BallInPlayCamera = BallInPlayCamera.new()
			original.prepare(true, history.start, history.launch)
			var outside: int = 0
			for frame in range(int(ceil(history.duration * 30)) + 1):
				var time: float = minf(history.duration, frame / 30.0)
				var point: Vector3 = Histories.sample(history, time)
				original.update(camera, 1.0 / 30.0, point, director.tracking_visibility)
				var rejected: bool = (
					camera.is_position_behind(point)
					or not owner.get_viewport().get_visible_rect().grow(-24).has_point(
						camera.unproject_position(point)
					)
				)
				samples += 1
				outside += int(rejected)
				if rejected:
					print(
						"AY02_PRIOR_OVERTAKING_REJECTED id=",
						history.id,
						" left=",
						left,
						" frame=",
						frame,
						" time=",
						time,
						" ball=",
						point,
						" camera=",
						camera.global_transform,
						" fov=",
						camera.fov,
						" clearance=0 unchanged_threshold=24"
					)
			owner._check(
				outside > 0,
				"prior non-wide side coverage still fails framing for each mirror and hand"
			)
			total += outside
	owner._check(
		samples > 0 and total > 0, "overtaking failure remains an explicit negative control"
	)
	print(
		"AY02_PRIOR_OVERTAKING_CONTROL samples=",
		samples,
		" outside=",
		total,
		" accepted_camera_samples=0 unchanged_motion=true unchanged_threshold=24"
	)
	director.shot = saved_shot
	director._batter_side = saved_side
	camera.global_transform = saved
	camera.fov = saved_fov


static func target_controls(owner: Node, lab: PitchBatLab, histories: Array[Dictionary]) -> void:
	var director: StadiumYardTwoCameraDirector = lab._camera_director
	var motion: StadiumYardTwoCameraMotion = director._live_coverage
	var visibility: StadiumYardTwoTrackingVisibility = director.tracking_visibility
	var reference: StadiumYardFieldVisibility = StadiumYardFieldVisibility.new()
	reference.configure(lab.get_node("StarterFieldGeometry"))
	var saved_shot: MatchCameraDirector.Shot = director.shot
	var saved_inspection: int = director._shot_before_inspection
	director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	var no_op: int = 0
	var constrained: int = 0
	for defense: bool in [false, true]:
		for history: Dictionary in histories:
			motion.prepare(defense, history.start, history.launch)
			var eligible: bool = not defense and history.id in ["left-side", "right-side"]
			for desired: Vector3 in [
				Vector3(-12, 8, -8), Vector3(12, 8, -8), Vector3(0, 8, -8), Vector3(0, 2.1, -6.5)
			]:
				var adjusted: Vector3 = motion.constrain_target(desired)
				if eligible:
					for identity: String in ["SIDE-L-01", "SIDE-R-01"]:
						var row: Dictionary = StadiumBoundaryGraph.segment(identity)
						var gap: float = (Vector2(adjusted.x, adjusted.z) - row.a).dot(
							StadiumBoundaryGraph.inward(row)
						)
						owner._check(
							gap >= BallTrackingVisibility.WALL_CAMERA_CLEARANCE - 0.00001,
							"both exact side half-planes retain existing1.2m clearance"
						)
					owner._check(
						adjusted.y == desired.y, "target projection leaves height unchanged"
					)
					owner._check(
						(
							visibility.clear_position(desired, history.start)
							== reference.clear_position(adjusted, history.start)
						),
						"candidate projects before exact unchanged inherited avoidance"
					)
					constrained += 1
				else:
					owner._check(
						adjusted == desired,
						"every unrelated history and defense target is exact no-op"
					)
					owner._check(
						(
							visibility.clear_position(desired, history.start)
							== reference.clear_position(desired, history.start)
						),
						"all non-corridor/defense inherited visibility results remain exact"
					)
					no_op += 1
	motion.prepare(false, Vector3(0, 1, 0), Vector3(-22, 3, 10))
	var desired: Vector3 = Vector3(-12, 8, -8)
	var ball: Vector3 = Vector3(-10, 1, 5)
	for other: int in MatchCameraDirector.Shot.values():
		if other == MatchCameraDirector.Shot.BALL_IN_PLAY:
			continue
		director.shot = other as MatchCameraDirector.Shot
		owner._check(
			visibility.clear_position(desired, ball) == reference.clear_position(desired, ball),
			"non-live views never use candidate target authority"
		)
	director.shot = MatchCameraDirector.Shot.BALL_IN_PLAY
	director._shot_before_inspection = int(MatchCameraDirector.Shot.BATTING)
	owner._check(
		visibility.clear_position(desired, ball) == reference.clear_position(desired, ball),
		"paused inspection never uses candidate target authority"
	)
	director._shot_before_inspection = -1
	var bound: WeakRef = visibility.motion_ref
	var foreign_motion: StadiumYardTwoCameraMotion = StadiumYardTwoCameraMotion.new()
	visibility.motion_ref = weakref(foreign_motion)
	owner._check(
		visibility.clear_position(desired, ball) == reference.clear_position(desired, ball),
		"foreign motion identity rejects target authority"
	)
	visibility.motion_ref = bound
	var active: MatchCameraDirector = lab._camera_director
	lab._camera_director = MatchCameraDirector.new()
	owner._check(
		visibility.clear_position(desired, ball) == reference.clear_position(desired, ball),
		"foreign director rejects target authority"
	)
	lab._camera_director = active
	director.shot = saved_shot
	director._shot_before_inspection = saved_inspection
	print(
		"AY02_TARGET_POLICY_CONTROLS history_count=",
		histories.size(),
		" exact_no_op=",
		no_op,
		" constrained=",
		constrained,
		" side_clearance=1.2 shared_avoidance_exact=true"
	)
