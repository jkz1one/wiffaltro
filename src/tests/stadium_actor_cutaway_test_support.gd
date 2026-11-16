extends RefCounted
## Independent actor geometry/control checks; no actor is hidden to establish visibility.

const FAILURE_CAMERA: Vector3 = Vector3(0.27426, 2.213413, -3.468808)
const FAILURE_BALL: Vector3 = Vector3(0.693333, 0.954667, 1.221333)


static func run(owner: Node, lab: PitchBatLab) -> void:
	var property: Node = lab.get_meta("stadium_property")
	var study: StadiumActorCutawayStudy = property.get("actor_cutaway")
	owner.call("_check", study != null, "candidate exposes actor cutaway study")
	if study == null:
		return
	study.restore_all()
	var fixture: Node3D = Node3D.new()
	fixture.name = "ActorCutawayControlFixture"
	lab.add_child(fixture)
	var batter: PlayerAvatar = _batter(fixture, Vector3(0.82, 0.0, 0.34))
	var bat: BatActor = BatActor.new()
	fixture.add_child(bat)
	bat.configure(false, batter.position)
	bat.set_process(false)
	var camera: Camera3D = Camera3D.new()
	fixture.add_child(camera)
	camera.position = FAILURE_CAMERA
	var ball: Node3D = Node3D.new()
	fixture.add_child(ball)
	ball.position = FAILURE_BALL
	var batter_meshes: Array[MeshInstance3D] = _meshes(batter)
	var bat_meshes: Array[MeshInstance3D] = _meshes(bat)
	# Non-default instance settings make restoration assertions meaningful.
	batter_meshes[0].transparency = 0.13
	batter_meshes[0].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	var witness: PlayerAvatar = _batter(fixture, Vector3(20, 0, 20))
	var witness_mesh: MeshInstance3D = _meshes(witness)[0]
	witness_mesh.material_override = batter_meshes[0].material_override
	var originals: Array[Dictionary] = _snapshot(batter_meshes + bat_meshes)
	var witness_original: Material = witness_mesh.material_override
	var poses: Array[Dictionary] = _poses(fixture)
	var collisions: Array[Dictionary] = _collisions(lab)
	await owner.get_tree().physics_frame
	var raw_hits: int = _triangle_hits(batter_meshes, camera.position, ball.position)
	owner.call(
		"_check",
		raw_hits > 0,
		"measured failure ray intersects authentic visible right-batter triangles"
	)
	study.apply(batter, bat, camera, ball, true)
	owner.call(
		"_check",
		not study.last_hits.is_empty(),
		"actor cutaway records measured triangle obstruction"
	)
	_check_faded(owner, batter_meshes, "measured obstructing batter")
	var authentic_hits: bool = true
	for hit: Dictionary in study.last_hits:
		var mesh: MeshInstance3D = instance_from_id(int(hit.get("mesh", 0))) as MeshInstance3D
		authentic_hits = (
			authentic_hits and mesh != null and (batter_meshes.has(mesh) or bat_meshes.has(mesh))
		)
		if mesh != null:
			var hit_meshes: Array[MeshInstance3D] = [mesh]
			authentic_hits = (
				authentic_hits and _triangle_hits(hit_meshes, camera.position, ball.position) > 0
			)
	owner.call(
		"_check",
		authentic_hits,
		"recorded hits belong to independently intersected authentic meshes"
	)
	_check_sources(owner, originals)
	owner.call(
		"_check",
		witness_mesh.material_override == witness_original,
		"shared material witness retains original resource"
	)
	_check_poses(owner, poses)
	owner.call(
		"_check",
		_collisions(lab) == collisions,
		"actor fade leaves collision count, layers, masks, and shape state unchanged"
	)

	# A capture lock must preserve precisely the same material state when the
	# ball is toggled for the real with/without-ball image pair.
	var locked: Array[Dictionary] = _snapshot(batter_meshes + bat_meshes)
	var locked_hits: Array = study.last_hits.duplicate(true)
	var locked_entry_count: int = study.entries.size()
	study.frozen = true
	ball.visible = false
	study.apply(batter, bat, camera, ball, true)
	_check_restored(owner, locked, "frozen hidden-ball capture")
	owner.call(
		"_check",
		study.last_hits == locked_hits and study.entries.size() == locked_entry_count,
		"capture freeze preserves hit evidence and tracked actor entries"
	)
	ball.visible = true
	study.apply(batter, bat, camera, ball, true)
	_check_restored(owner, locked, "frozen visible-ball capture")
	study.frozen = false

	ball.position = Vector3(-15, 5, 2)
	owner.call(
		"_check",
		_triangle_hits(batter_meshes + bat_meshes, camera.position, ball.position) == 0,
		"clear-ray control misses authentic actor triangles"
	)
	study.apply(batter, bat, camera, ball, true)
	_check_restored(owner, originals, "clear ray")
	ball.position = FAILURE_BALL
	study.apply(batter, bat, camera, ball, true)
	study.apply(batter, bat, camera, ball, false)
	_check_restored(owner, originals, "non-live ball")
	owner.call(
		"_check",
		study.entries.is_empty() and study.last_hits.is_empty(),
		"non-live cleanup releases tracked mesh entries and hit evidence"
	)

	# Aim through an authentic barrel triangle rather than adding proxy geometry.
	var barrel: MeshInstance3D = bat_meshes[bat_meshes.size() - 1]
	camera.position = barrel.global_position + Vector3(0, 0, -2)
	ball.position = barrel.global_position + Vector3(0, 0, 2)
	owner.call(
		"_check",
		_triangle_hits(bat_meshes, camera.position, ball.position) > 0,
		"bat control intersects authentic barrel triangles"
	)
	study.apply(batter, bat, camera, ball, true)
	_check_faded(owner, bat_meshes, "obstructing bat group")
	_check_sources(owner, originals)
	study.restore_all()
	_check_restored(owner, originals, "explicit restore_all")

	camera.position = FAILURE_CAMERA
	ball.position = FAILURE_BALL
	study.apply(batter, bat, camera, ball, true)
	batter.role = PlayerAvatar.Role.FIELDER
	study.apply(batter, bat, camera, ball, true)
	_check_restored(owner, originals.slice(0, batter_meshes.size()), "role-change cleanup")
	batter.role = PlayerAvatar.Role.BATTER
	study.apply(batter, bat, camera, ball, true)
	var replacement: PlayerAvatar = _batter(fixture, Vector3(-20, 0, 20))
	study.apply(replacement, null, camera, ball, true)
	_check_restored(owner, originals, "actor replacement cleanup")
	var replaced_released: bool = true
	for saved: Dictionary in originals:
		replaced_released = (
			replaced_released and not study.entries.has(saved.mesh.get_instance_id())
		)
	owner.call("_check", replaced_released, "replacement releases every old batter and bat entry")
	study.apply(batter, bat, camera, ball, true)
	study.restore_all()
	_check_restored(owner, originals, "final cleanup")
	_check_poses(owner, poses)
	owner.call(
		"_check",
		_collisions(lab) == collisions,
		"all cutaway controls preserve collision structure"
	)
	study.apply(batter, bat, camera, ball, true)
	batter.configure(PlayerAvatar.Role.BATTER, false, false, Color(0.2, 0.5, 0.7))
	var replacement_material: Material = batter_meshes[0].material_override
	study.apply(batter, bat, camera, ball, true)
	study.restore_all()
	owner.call(
		"_check",
		batter_meshes[0].material_override == replacement_material,
		"same-actor restart/reconfiguration preserves new material instead of stale cached source"
	)
	owner.call(
		"_check",
		witness_mesh.material_override == witness_original,
		"reconfiguration does not mutate the old shared-resource witness"
	)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	fixture.free()


static func _batter(parent: Node3D, at: Vector3) -> PlayerAvatar:
	var actor: PlayerAvatar = PlayerAvatar.new()
	parent.add_child(actor)
	actor.configure(PlayerAvatar.Role.BATTER, false, false, Color(0.94, 0.78, 0.18))
	actor.position = at
	actor.set_process(false)
	return actor


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		result.append_array(_meshes(child))
	return result


static func _triangle_hits(meshes: Array[MeshInstance3D], from: Vector3, to: Vector3) -> int:
	var count: int = 0
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for index: int in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(
				from,
				to,
				mesh.global_transform * faces[index],
				mesh.global_transform * faces[index + 1],
				mesh.global_transform * faces[index + 2]
			)
			if hit != null:
				count += 1
	return count


static func _snapshot(meshes: Array[MeshInstance3D]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mesh: MeshInstance3D in meshes:
		var material: BaseMaterial3D = mesh.material_override as BaseMaterial3D
		result.append(
			{
				"mesh": mesh,
				"material": mesh.material_override,
				"transparency": mesh.transparency,
				"shadow": mesh.cast_shadow,
				"color": material.albedo_color if material != null else Color.WHITE,
				"mode": material.transparency if material != null else -1
			}
		)
	return result


static func _check_restored(owner: Node, snapshots: Array[Dictionary], label: String) -> void:
	var exact: bool = true
	for saved: Dictionary in snapshots:
		var mesh: MeshInstance3D = saved.mesh
		exact = exact and mesh.material_override == saved.material
		exact = (
			exact and mesh.transparency == saved.transparency and mesh.cast_shadow == saved.shadow
		)
	owner.call(
		"_check", exact, label + " restores exact material reference, transparency, and shadow"
	)


static func _check_sources(owner: Node, snapshots: Array[Dictionary]) -> void:
	var unchanged: bool = true
	for saved: Dictionary in snapshots:
		var material: BaseMaterial3D = saved.material as BaseMaterial3D
		if material != null:
			unchanged = (
				unchanged
				and material.albedo_color == saved.color
				and material.transparency == saved.mode
			)
	owner.call("_check", unchanged, "source/shared materials are never mutated by fading")


static func _check_faded(owner: Node, meshes: Array[MeshInstance3D], label: String) -> void:
	var faded: bool = not meshes.is_empty()
	for mesh: MeshInstance3D in meshes:
		var material: BaseMaterial3D = mesh.material_override as BaseMaterial3D
		faded = faded and material != null and mesh.is_visible_in_tree()
		if material != null:
			faded = faded and is_equal_approx(material.albedo_color.a, 0.20)
			faded = faded and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
		faded = faded and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.call(
		"_check", faded, label + " remains visible with whole-group alpha 0.20 and shadows off"
	)


static func _poses(root: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Only actors: the test deliberately moves its temporary camera and ball.
	if root is PlayerAvatar or root is BatActor:
		_collect_poses(root, result)
	else:
		for child: Node in root.get_children():
			result.append_array(_poses(child))
	return result


static func _collect_poses(root: Node, result: Array[Dictionary]) -> void:
	if root is Node3D:
		result.append(
			{
				"node": root,
				"transform": (root as Node3D).transform,
				"visible": (root as Node3D).visible
			}
		)
	for child: Node in root.get_children():
		_collect_poses(child, result)


static func _check_poses(owner: Node, snapshots: Array[Dictionary]) -> void:
	var unchanged: bool = true
	for saved: Dictionary in snapshots:
		var node: Node3D = saved.node
		unchanged = (
			unchanged and node.transform == saved.transform and node.visible == saved.visible
		)
	owner.call(
		"_check", unchanged, "cutaway never changes authentic actor transforms or visibility"
	)


static func _collisions(root: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if root is CollisionObject3D:
		var body: CollisionObject3D = root as CollisionObject3D
		result.append(
			{
				"id": body.get_instance_id(),
				"layer": body.collision_layer,
				"mask": body.collision_mask
			}
		)
	if root is CollisionShape3D:
		var shape: CollisionShape3D = root as CollisionShape3D
		result.append(
			{
				"id": shape.get_instance_id(),
				"shape": shape.shape,
				"disabled": shape.disabled,
				"transform": shape.transform
			}
		)
	for child: Node in root.get_children():
		result.append_array(_collisions(child))
	return result
