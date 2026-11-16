extends RefCounted
## Independent all-four actor triangle evidence. Actors keep their actual positions and poses.

const Mechanics = preload("res://src/tests/stadium_npc_retained_daylight_support.gd")


static func actors(lab: PitchBatLab) -> Dictionary:
	if (
		lab.get_node_or_null("BatterAvatar") != lab._batter_avatar
		or not is_instance_valid(lab._batter_avatar)
		or lab._batter_avatar.role != PlayerAvatar.Role.BATTER
		or lab.get_node_or_null("BatActor") != lab._bat_actor
		or not is_instance_valid(lab._bat_actor)
		or lab.get_node_or_null("PitcherDefender") != lab._pitcher_marker
		or lab.get_node_or_null("PitcherDefender/PitcherAvatar") != lab._pitcher_avatar
		or not is_instance_valid(lab._pitcher_avatar)
		or lab._pitcher_avatar.role != PlayerAvatar.Role.PITCHER
		or lab.get_node_or_null("PrimaryFielder") != lab._primary_fielder
		or not is_instance_valid(lab._primary_fielder)
		or not is_instance_valid(lab._primary_fielder._avatar)
		or lab._primary_fielder.get_node_or_null("FielderAvatar") != lab._primary_fielder._avatar
		or lab._primary_fielder._avatar.role != PlayerAvatar.Role.FIELDER
	):
		return {}
	return {
		"batter": lab._batter_avatar,
		"bat": lab._bat_actor,
		"pitcher": lab._pitcher_avatar,
		"fielder": lab._primary_fielder._avatar
	}


static func audit(lab: PitchBatLab, faces_cache: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"actors": 0, "meshes": 0, "hidden": 0, "hits": 0, "opaque": 0, "roles": {}
	}
	var identities: Dictionary = actors(lab)
	var property: StadiumMogulTwoProperty = lab.get_meta("stadium_property")
	for label: String in identities:
		var actor: Node3D = identities[label]
		var hits: int = 0
		var meshes: Array[Node] = actor.find_children("*", "MeshInstance3D", true, false)
		result.actors += 1
		result.hidden += int(not actor.is_visible_in_tree() or meshes.is_empty())
		for mesh: MeshInstance3D in meshes:
			result.meshes += 1
			result.hidden += int(not mesh.is_visible_in_tree() or mesh.mesh == null)
			hits += _triangle_hits(
				mesh, lab._camera.global_position, lab._batted_ball.global_position, faces_cache
			)
		result.roles[label] = hits
		result.hits += hits
		if hits == 0:
			continue
		# A detected center-line actor must have the actual actor-wide qualified fade.
		for mesh: MeshInstance3D in meshes:
			if not faded(mesh, property.actor_cutaway):
				result.opaque += 1
	return result


static func _triangle_hits(
	mesh: MeshInstance3D, from: Vector3, to: Vector3, cache: Dictionary
) -> int:
	if mesh.mesh == null or not mesh.is_visible_in_tree():
		return 0
	var inverse: Transform3D = mesh.global_transform.affine_inverse()
	var start: Vector3 = inverse * from
	var end: Vector3 = inverse * to
	if mesh.get_aabb().intersects_segment(start, end) == null:
		return 0
	var identity: int = mesh.mesh.get_instance_id()
	if not cache.has(identity):
		cache[identity] = mesh.mesh.get_faces()
	var faces: PackedVector3Array = cache[identity]
	var count: int = 0
	for index in range(0, faces.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				start, end, faces[index], faces[index + 1], faces[index + 2]
			)
			!= null
		):
			count += 1
	return count


static func faded(mesh: MeshInstance3D, study: StadiumActorCutawayStudy) -> bool:
	var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
	var entry: Dictionary = study.entries.get(mesh.get_instance_id(), {})
	return (
		mesh.is_visible_in_tree()
		and not entry.is_empty()
		and material != null
		and material == entry.fade_material
		and is_equal_approx(material.albedo_color.a, 0.20)
		and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
		and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)


static func poses(lab: PitchBatLab) -> Array:
	var result: Array = []
	for actor: Node3D in actors(lab).values():
		var nodes: Array[Node] = [actor]
		nodes.append_array(actor.find_children("*", "Node3D", true, false))
		for node: Node3D in nodes:
			result.append(
				[
					node.get_instance_id(),
					node.get_parent().get_instance_id(),
					node.transform,
					node.global_transform,
					node.visible,
					node.is_visible_in_tree()
				]
			)
	return result


static func controls(owner: Node, lab: PitchBatLab, fps: int) -> float:
	var property: StadiumMogulTwoProperty = lab.get_meta("stadium_property")
	var camera: Camera3D = lab._camera
	var ball: BattedBallBody = lab._batted_ball
	var director: StadiumMogulTwoCamera = lab._camera_director
	var saved: Dictionary = {
		"camera_local": camera.transform,
		"camera_global": camera.global_transform,
		"fov": camera.fov,
		"ball_local": ball.transform,
		"ball_global": ball.global_transform,
		"presentation": owner._presentation_snapshot(lab),
		"poses": poses(lab),
		"mechanics": Mechanics.mechanics(lab)
	}
	owner._check(
		director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY,
		"all-actor controls retain genuine final dense-path live state"
	)
	var cache: Dictionary = {}
	# A point at the genuine fixed ball is an explicit unoccluded negative control.
	# Keep the helper cache so replay retains exact already-existing fade resource identities.
	camera.global_position = ball.global_position
	director.refresh_actor_cutaway(camera, true)
	owner._check(
		property.actor_cutaway.last_hits.is_empty() and audit(lab, cache).hits == 0,
		"fixed-ball negative control has no actor footprint or triangle obstruction"
	)
	var originals: Array[Dictionary] = owner._presentation_snapshot(lab)
	var minimum: float = INF
	for label: String in actors(lab):
		var actor: Node3D = actors(lab)[label]
		var target: MeshInstance3D = _largest_mesh(actor)
		owner._check(target != null, "positive " + label + " control has authentic geometry")
		if target == null:
			continue
		# Only the inspection camera moves. The ball remains at its last genuine path sample.
		var center: Vector3 = target.global_transform * target.get_aabb().get_center()
		var away: Vector3 = (center - ball.global_position).normalized()
		owner._check(not away.is_zero_approx(), "authentic actor and fixed ball are distinct")
		# The former3m extension put the actual pitcher/fielder controls below ground.
		# Keep those rejected fixtures as physical negative controls, never acceptance samples.
		var legacy_position: Vector3 = center + away * 3.0
		if legacy_position.y < 0:
			camera.global_position = legacy_position
			camera.look_at(ball.global_position)
			director.refresh_actor_cutaway(camera, true)
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			var legacy_near: bool = owner._near_clear(camera)
			var legacy_los: bool = owner._clear_after_fades(
				property, camera.global_position, ball.global_position
			)
			owner._check(
				not legacy_near or not legacy_los,
				"below-ground former positive fixture is rejected by unchanged physical oracles"
			)
			print(
				"MOGUL_TWO_SYNTHETIC_REJECTED_LEGACY_ACTOR role=",
				label,
				" camera=",
				camera.global_transform,
				" near_clear=",
				legacy_near,
				" full_los_clear=",
				legacy_los
			)
		# Fixed1m stand-off is independent of oracle results and still traverses the
		# identical authentic actor center toward the same fixed ball for every role.
		camera.global_position = center + away * 1.0
		camera.look_at(ball.global_position)
		director.refresh_actor_cutaway(camera, true)
		StadiumPropertyRuntime.refresh_receiver_visibility(lab)
		var proof: Dictionary = audit(lab, cache)
		owner._check(
			(
				proof.actors == 4
				and proof.hidden == 0
				and proof.roles.get(label, 0) > 0
				and proof.opaque == 0
			),
			"positive " + label + " ray crosses actual actor triangles with actual qualified fade"
		)
		owner._check(poses(lab) == saved.poses, "positive control preserves every actor pose")
		owner._check(
			Mechanics.mechanics(lab) == saved.mechanics,
			"positive camera-only control preserves exact genuine ball pose and mechanics"
		)
		owner._check(owner._near_clear(camera), "positive actor camera has physical near clearance")
		owner._check(
			owner._clear_after_fades(property, camera.global_position, ball.global_position),
			"positive actor ray rejects all farther opaque physical geometry"
		)
		print(
			"MOGUL_TWO_SYNTHETIC_ALL_ACTOR_CONTROL role=",
			label,
			" fps=",
			fps,
			" camera=",
			camera.global_transform,
			" ball=",
			ball.global_position,
			" proof=",
			proof
		)
		if DisplayServer.get_name() != "headless":
			var contrast: float = await owner._representative_contrast(
				camera,
				ball,
				"mogul-two-synthetic-authentic-%s-%d" % [label, fps],
				{"control": "unchanged-actor-pose", "role": label, "fps": fps, "proof": proof}
			)
			minimum = minf(minimum, contrast)
			owner._check(contrast >= 0.03, "actual " + label + " native contrast keeps0.03 gate")
		owner._check(
			Mechanics.mechanics(lab) == saved.mechanics,
			"actual native contrast leaves genuine ball mechanics and transform unchanged"
		)
		camera.global_position = ball.global_position
		director.refresh_actor_cutaway(camera, true)
		owner._check(
			property.actor_cutaway.last_hits.is_empty(),
			"returning to fixed-ball negative restores all four unobstructed actor presentations"
		)
		# Receiver alpha belongs to the current camera; compare the four actors only here.
		owner._check(
			_actor_rows(lab, originals) == _actor_rows(lab, owner._presentation_snapshot(lab)),
			"all-four original actor material identities alpha shadows and transforms restore"
		)
	camera.transform = saved.camera_local
	camera.fov = saved.fov
	camera.force_update_transform()
	director.refresh_actor_cutaway(camera, true)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	owner._check(
		(
			camera.global_transform == saved.camera_global
			and ball.global_transform == saved.ball_global
			and poses(lab) == saved.poses
			and Mechanics.mechanics(lab) == saved.mechanics
			and owner._presentation_snapshot(lab) == saved.presentation
		),
		"actor controls restore exact original camera ball materials transforms and mechanics"
	)
	return minimum


static func _largest_mesh(actor: Node3D) -> MeshInstance3D:
	var chosen: MeshInstance3D
	var volume: float = -1.0
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if (
			mesh.mesh != null
			and mesh.is_visible_in_tree()
			and mesh.get_aabb().get_volume() > volume
		):
			chosen = mesh
			volume = mesh.get_aabb().get_volume()
	return chosen


static func _actor_rows(lab: PitchBatLab, rows: Array[Dictionary]) -> Array[Dictionary]:
	var ids: Dictionary = {}
	for actor: Node3D in actors(lab).values():
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			ids[mesh.get_instance_id()] = true
	var result: Array[Dictionary] = []
	for row: Dictionary in rows:
		if ids.has(row.id):
			result.append(row)
	return result
