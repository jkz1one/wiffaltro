extends Node3D
## Retained-only presentation qualification. Genuine actor rays; no artificial actor hiding.

const Actors = preload("res://src/tests/stadium_actor_cutaway_test_support.gd")
const Readability = preload("res://src/tests/stadium_npc_retained_readability_checks.gd")
@export var candidate_v2: bool = false
var _runtime: Script = StadiumNpcRetainedRuntime
var _failures: int = 0


func _ready() -> void:
	if candidate_v2:
		_runtime = StadiumNpcCandidateRuntimeV2
	_footprints()
	var checks = Readability.new()
	add_child(checks)
	await checks.run()
	_failures += checks.failures
	checks.free()
	for id: String in ["AY-01", "AE-01", "AC-01"]:
		await _actors(id)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				(
					"Wiffaltro candidate NPC r2 presentation passed: "
					if candidate_v2
					else "Wiffaltro retained NPC presentation passed: "
				)
				+ "real actor cutaway and physical-safe pixel floor."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _actors(id: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	lab.set_meta("stadium_npc_retained_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(_runtime.install(lab, id), "retained presentation installs " + id)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(property.field, false)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		var actors: Array[Node3D] = [
			lab._batter_avatar,
			lab._bat_actor,
			lab._pitcher_avatar,
			lab._primary_fielder.get("_avatar")
		]
		for actor: Node3D in actors:
			_probe(lab, property, ball, actor, left)
		_foreign_slots(lab, property, ball)
		_replacement(lab, property, ball)
	_lifecycle(lab, property, ball)
	lab.free()
	await get_tree().process_frame


func _aim(camera: Camera3D, ball: Node3D, actor: Node3D, distance: float = 3) -> bool:
	# Use the largest actual visible triangle, avoiding arbitrary world-space guesses.
	var best: float = 0
	var center: Vector3
	var normal: Vector3
	for mesh: MeshInstance3D in Actors._meshes(actor):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for index in range(0, faces.size(), 3):
			var a: Vector3 = mesh.global_transform * faces[index]
			var b: Vector3 = mesh.global_transform * faces[index + 1]
			var c: Vector3 = mesh.global_transform * faces[index + 2]
			var cross: Vector3 = (b - a).cross(c - a)
			if cross.length_squared() > best:
				best = cross.length_squared()
				center = (a + b + c) / 3
				normal = cross.normalized()
	if best == 0:
		return false
	camera.global_position = center + normal * distance
	ball.global_position = center - normal * distance
	camera.look_at(ball.global_position, Vector3.RIGHT if absf(normal.y) > 0.9 else Vector3.UP)
	return (
		Actors._triangle_hits(Actors._meshes(actor), camera.global_position, ball.global_position)
		> 0
	)


func _probe(
	lab: PitchBatLab,
	property: StadiumNpcRetainedProperty,
	ball: BattedBallBody,
	actor: Node3D,
	left: bool
) -> void:
	property.actor_cutaway.restore_all()
	property.ball_readability.restore_all()
	var meshes: Array[MeshInstance3D] = Actors._meshes(actor)
	var saved: Array[Dictionary] = Actors._snapshot(meshes)
	var poses: Array[Dictionary] = Actors._poses(actor)
	_check(_aim(lab._camera, ball, actor), "actual actor triangle ray exists, left=" + str(left))
	var physical: PackedByteArray = Readability.physical(ball, lab._ball_play_resolver)
	property.refresh_actor_presentation(lab)
	Actors._check_faded(self, meshes, "genuine retained actor obstruction")
	var found: bool = false
	var center_found: bool = false
	for hit: Dictionary in property.actor_cutaway.last_hits:
		if hit.actor == actor.get_instance_id():
			found = true
			center_found = center_found or hit.center_hit
			_check(
				hit.distance <= hit.effective_radius and meshes.has(instance_from_id(hit.mesh)),
				"diagnostic hit names an actual independently intersected actor mesh"
			)
	_check(found and center_found, "ordinary retained refresh records actual center obstruction")
	Actors._check_sources(self, saved)
	Actors._check_poses(self, poses)
	_check(
		Readability.physical(ball, lab._ball_play_resolver) == physical,
		"actor fading leaves exact ball physics and resolver state untouched"
	)
	property.actor_cutaway.apply_actors(
		[], lab._camera, ball, true, property.ball_readability.effective_radius()
	)
	Actors._check_restored(self, saved, "no active actors")
	property.refresh_actor_presentation(lab)
	property.actor_cutaway.apply_actors([actor], lab._camera, ball, false)
	Actors._check_restored(self, saved, "non-live helper input")
	property.refresh_actor_presentation(lab)
	if not meshes.is_empty():
		var mesh: MeshInstance3D = meshes[0]
		var replacement: StandardMaterial3D = StandardMaterial3D.new()
		replacement.albedo_color = Color(0.21, 0.43, 0.67)
		mesh.material_override = replacement
		property.refresh_actor_presentation(lab)
		property.actor_cutaway.restore_all()
		_check(
			mesh.material_override == replacement and replacement.albedo_color.a == 1,
			"material replacement survives re-fade and cleanup without restoring stale source"
		)
		mesh.material_override = saved[0].material
	if actor is PlayerAvatar:
		var role: int = actor.role
		actor.role = (
			PlayerAvatar.Role.PITCHER
			if role != PlayerAvatar.Role.PITCHER
			else PlayerAvatar.Role.BATTER
		)
		property.refresh_actor_presentation(lab)
		Actors._check_restored(self, saved, "actor no longer has its expected slot role")
		actor.role = role as PlayerAvatar.Role
		property.refresh_actor_presentation(lab)
		property.actor_cutaway.restore_all()
	property.ball_readability.restore_all()


func _replacement(
	lab: PitchBatLab, property: StadiumNpcRetainedProperty, ball: BattedBallBody
) -> void:
	var original: FielderController = lab._primary_fielder
	var old_actor: PlayerAvatar = original.get("_avatar")
	var saved: Array[Dictionary] = Actors._snapshot(Actors._meshes(old_actor))
	_check(_aim(lab._camera, ball, old_actor), "old current fielder has genuine obstruction")
	property.refresh_actor_presentation(lab)
	Actors._check_faded(self, Actors._meshes(old_actor), "old current fielder")
	var replacement: FielderController = FielderController.new()
	lab.add_child(replacement)
	replacement.set_physics_process(false)
	replacement.position = Vector3(50, 0, 50)
	lab._primary_fielder = replacement
	property.refresh_actor_presentation(lab)
	Actors._check_restored(self, saved, "replaced current fielder")
	for mesh: MeshInstance3D in Actors._meshes(old_actor):
		_check(
			not property.actor_cutaway.entries.has(mesh.get_instance_id()),
			"old fielder is no longer an active cutaway subject"
		)
	var next_actor: PlayerAvatar = replacement.get("_avatar")
	var foreign_saved: Array[Dictionary] = Actors._snapshot(Actors._meshes(next_actor))
	_check(_aim(lab._camera, ball, next_actor), "foreign same-role actor has genuine obstruction")
	property.refresh_actor_presentation(lab)
	Actors._check_restored(self, foreign_saved, "foreign same-role slot injection")
	var original_name: StringName = original.name
	original.name = "FormerPrimaryFielder"
	replacement.name = original_name
	_check(
		_aim(lab._camera, ball, next_actor), "canonical replacement fielder has genuine obstruction"
	)
	property.refresh_actor_presentation(lab)
	Actors._check_faded(self, Actors._meshes(next_actor), "new actual current fielder")
	property.actor_cutaway.restore_all()
	lab._primary_fielder = original
	replacement.free()
	original.name = original_name


func _lifecycle(
	lab: PitchBatLab, property: StadiumNpcRetainedProperty, ball: BattedBallBody
) -> void:
	property.actor_cutaway.restore_all()
	property.ball_readability.restore_all()
	var visual: MeshInstance3D = ball.get_child(1)
	var original: PackedByteArray = var_to_bytes(visual.transform)
	var actor: PlayerAvatar = lab._batter_avatar
	var saved: Array[Dictionary] = Actors._snapshot(Actors._meshes(actor))
	_check(_aim(lab._camera, ball, actor, 30), "lifecycle begins on authentic actor obstruction")
	property.refresh_actor_presentation(lab)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	property.refresh_actor_presentation(lab)
	Actors._check_restored(self, saved, "leaving ball-in-play shot")
	_check(var_to_bytes(visual.transform) == original, "shot change restores original ball visual")
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	property.refresh_actor_presentation(lab)
	lab._batted_ball = null
	property.refresh_actor_presentation(lab)
	Actors._check_restored(self, saved, "no live physical ball")
	_check(var_to_bytes(visual.transform) == original, "no-live restores original ball visual")
	lab._batted_ball = ball
	property.refresh_actor_presentation(lab)
	var camera: Camera3D = lab._camera
	var replacement: Camera3D = Camera3D.new()
	lab.add_child(replacement)
	replacement.position = ball.position + Vector3(0, 0, -0.3)
	replacement.look_at(ball.global_position)
	lab._camera = replacement
	property.refresh_actor_presentation(lab)
	Actors._check_restored(self, saved, "camera replacement with unobstructed close ray")
	_check(
		var_to_bytes(visual.transform) == original, "camera identity change restores ball visual"
	)
	lab._camera = camera
	replacement.free()
	property.refresh_actor_presentation(lab)
	Actors._check_faded(self, Actors._meshes(actor), "restored exact installed camera")
	var director: MatchCameraDirector = lab._camera_director
	lab._camera_director = MatchCameraDirector.new()
	property.refresh_actor_presentation(lab)
	Actors._check_restored(self, saved, "foreign camera director")
	_check(var_to_bytes(visual.transform) == original, "foreign director restores original visual")
	lab._camera_director = director
	property.refresh_actor_presentation(lab)
	Actors._check_faded(self, Actors._meshes(actor), "restored exact installed camera director")
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(property.actor_cutaway.entries.is_empty(), "restart releases old actor fade entries")
	if is_instance_valid(visual):
		_check(var_to_bytes(visual.transform) == original, "restart restores old ball visual")
	ball = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(property.field, false)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	visual = ball.get_child(1)
	original = var_to_bytes(visual.transform)
	saved = Actors._snapshot(Actors._meshes(actor))
	_check(_aim(lab._camera, ball, actor, 30), "post-restart genuine actor obstruction")
	property.refresh_actor_presentation(lab)
	# Leave genuine helper-owned fade active, then satisfy teardown's idle admission.
	lab._batted_ball = null
	lab._pitch_actor.reset_pitch()
	lab._release_controller.cancel()
	lab._at_bat_cadence.stop()
	_check(_runtime.teardown(lab), "idle teardown releases retained presentation")
	Actors._check_restored(self, saved, "retained teardown")
	_check(var_to_bytes(visual.transform) == original, "teardown restores original ball visual")
	ball.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _footprints() -> void:
	var study: StadiumNpcRetainedActorCutaway = StadiumNpcRetainedActorCutaway.new()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.material_override = StandardMaterial3D.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
		[Vector3(-2, -2, 0), Vector3(2, -2, 0), Vector3(0, 2, 0)]
	)
	mesh.mesh = ArrayMesh.new()
	mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	add_child(mesh)
	study._sync(mesh)
	var center: Dictionary = study.footprint_hit(mesh, Vector3(0, 0, -1), Vector3(0, 0, 1), 0)
	_check(
		not center.is_empty() and center.center_hit,
		"zero-radius footprint preserves genuine center triangle intersection"
	)
	var face: Dictionary = study.footprint_hit(mesh, Vector3(0, 0, -1), Vector3(0, 0, -0.05), 0.075)
	_check(
		not face.is_empty() and not face.center_hit and face.distance <= 0.075,
		"endpoint-to-face proximity is detected without a center or edge crossing"
	)
	_check(
		study.footprint_hit(mesh, Vector3(0, 0, -1), Vector3(0, 0, -0.08), 0.075).is_empty(),
		"endpoint beyond effective visual radius remains clear"
	)
	var edge: Dictionary = study.footprint_hit(
		mesh, Vector3(-3, -2.05, -1), Vector3(3, -2.05, 1), 0.075
	)
	_check(
		not edge.is_empty() and not edge.center_hit,
		"sphere footprint detects near edge-segment occlusion"
	)
	_check(
		study.footprint_hit(mesh, Vector3(1.8, 1.8, -1), Vector3(1.8, 1.8, 1), 0.075).is_empty(),
		"expanded AABB overlap alone cannot fabricate triangle occlusion"
	)
	mesh.scale = Vector3(2, 0.5, 3)
	_check(
		not (
			study
			. footprint_hit(mesh, Vector3(-3, -1.05, -1), Vector3(3, -1.05, 1), 0.075)
			. is_empty()
		),
		"nonuniform mesh transform retains world-space footprint radius"
	)
	var replacement: ArrayMesh = ArrayMesh.new()
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
		[Vector3(8, -2, 0), Vector3(12, -2, 0), Vector3(10, 2, 0)]
	)
	replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = replacement
	study._sync(mesh)
	_check(
		study.footprint_hit(mesh, Vector3(0, 0, -1), Vector3(0, 0, 1), 0.075).is_empty(),
		"source mesh replacement invalidates both center and footprint caches"
	)
	study.restore_all()
	mesh.free()


func _foreign_slots(
	lab: PitchBatLab, property: StadiumNpcRetainedProperty, ball: BattedBallBody
) -> void:
	for key: String in ["_batter_avatar", "_bat_actor"]:
		property.actor_cutaway.restore_all()
		var original: Node3D = lab.get(key)
		var saved: Array[Dictionary] = Actors._snapshot(Actors._meshes(original))
		_check(_aim(lab._camera, ball, original), "canonical actor slot has genuine obstruction")
		property.refresh_actor_presentation(lab)
		var foreign: Node3D = BatActor.new() if key == "_bat_actor" else PlayerAvatar.new()
		foreign.name = "ForeignSameRoleProbe"
		lab.add_child(foreign)
		if foreign is BatActor:
			foreign.configure(false, Vector3(50, 0, 50))
		else:
			foreign.configure(PlayerAvatar.Role.BATTER, false, false, Color(0.2, 0.4, 0.6))
			foreign.position = Vector3(50, 0, 50)
		foreign.set_process(false)
		lab.set(key, foreign)
		property.refresh_actor_presentation(lab)
		Actors._check_restored(self, saved, "foreign same-role slot releases original")
		var foreign_saved: Array[Dictionary] = Actors._snapshot(Actors._meshes(foreign))
		_check(_aim(lab._camera, ball, foreign), "foreign same-role avatar/bat ray is genuine")
		property.refresh_actor_presentation(lab)
		Actors._check_restored(self, foreign_saved, "foreign avatar/bat never acquires cutaway")
		for mesh: MeshInstance3D in Actors._meshes(foreign):
			_check(
				not property.actor_cutaway.entries.has(mesh.get_instance_id()),
				"foreign avatar/bat is absent from owned presentation entries"
			)
		lab.set(key, original)
		foreign.free()
		property.actor_cutaway.restore_all()
