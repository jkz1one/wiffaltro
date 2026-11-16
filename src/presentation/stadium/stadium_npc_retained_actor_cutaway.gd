class_name StadiumNpcRetainedActorCutaway
extends StadiumActorCutawayStudy

const AC02_PASSIVE_12 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Retained-only rigid-avatar presentation. The footprint is a conservative world-space
## capsule around the camera-to-ball segment, not an exact projected sphere silhouette.
## Immutable Mesh resources only; replacing the Mesh rebuilds both inherited caches.


func apply_actors(
	actors: Array[Node3D], camera: Camera3D, ball: Node3D, live: bool,
	effective_radius: float = 0.075
) -> void:
	var ac02_token: int = AC02_PASSIVE_12.enter("stadium_npc_retained_actor_cutaway.apply_actors")
	_ac02_passive_12_apply_actors(actors, camera, ball, live, effective_radius)
	AC02_PASSIVE_12.leave(ac02_token)


func _ac02_passive_12_apply_actors(
	actors: Array[Node3D], camera: Camera3D, ball: Node3D, live: bool,
	effective_radius: float = 0.075
) -> void:
	if frozen:
		return
	last_hits.clear()
	if not live or not is_instance_valid(camera) or not camera.is_inside_tree() \
		or not is_instance_valid(ball) or not ball.is_inside_tree() \
		or not is_finite(effective_radius) or effective_radius < 0:
		restore_all()
		return
	var active: Dictionary = {}
	var seen: Dictionary = {}
	for actor: Node3D in actors:
		if not _allowed(actor) or seen.has(actor.get_instance_id()):
			continue
		seen[actor.get_instance_id()] = true
		var meshes: Array[Node] = actor.find_children("*", "MeshInstance3D", true, false)
		var obstructs: bool = false
		for member: Node in meshes:
			var mesh: MeshInstance3D = member as MeshInstance3D
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			var id: int = mesh.get_instance_id()
			active[id] = true
			_sync(mesh)
			if not entries.has(id):
				continue
			var hit: Dictionary = footprint_hit(
				mesh, camera.global_position, ball.global_position, effective_radius
			)
			if not hit.is_empty():
				obstructs = true
				hit.merge({
					"actor": actor.get_instance_id(), "actor_path": String(actor.get_path()),
					"role": actor.role if actor is PlayerAvatar else "BAT",
					"mesh": id, "path": String(mesh.get_path()),
					"effective_radius": effective_radius
				})
				last_hits.append(hit)
		for member: Node in meshes:
			var mesh: MeshInstance3D = member as MeshInstance3D
			var id: int = mesh.get_instance_id()
			if not active.has(id) or not entries.has(id):
				continue
			if obstructs:
				mesh.material_override = entries[id].fade_material
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				entries[id].faded = true
			else:
				_restore(entries[id])
	for id: int in entries.keys():
		if not active.has(id):
			_restore(entries[id])
			entries.erase(id)


func _allowed(actor: Node3D) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() \
		or not actor.is_visible_in_tree():
		return false
	if actor is BatActor:
		return true
	return actor is PlayerAvatar and actor.role in [
		PlayerAvatar.Role.BATTER, PlayerAvatar.Role.PITCHER, PlayerAvatar.Role.FIELDER
	]


func footprint_hit(
	mesh: MeshInstance3D, from: Vector3, to: Vector3, radius: float
) -> Dictionary:
	if not is_instance_valid(mesh) or mesh.mesh == null or not mesh.is_visible_in_tree() \
		or not entries.has(mesh.get_instance_id()) or not is_finite(radius) or radius < 0:
		return {}
	var bounds: AABB = mesh.global_transform * mesh.get_aabb()
	if bounds.grow(radius).intersects_segment(from, to) == null:
		return {}
	var center: Dictionary = intersection(mesh, from, to)
	if not center.is_empty():
		center["distance"] = 0.0
		center["center_hit"] = true
		return center
	var entry: Dictionary = entries[mesh.get_instance_id()]
	if not entry.has("footprint_faces"):
		entry["footprint_faces"] = mesh.mesh.get_faces()
	var faces: PackedVector3Array = entry.footprint_faces
	var radius_squared: float = radius * radius
	for index in range(0, faces.size(), 3):
		var a: Vector3 = mesh.global_transform * faces[index]
		var b: Vector3 = mesh.global_transform * faces[index + 1]
		var c: Vector3 = mesh.global_transform * faces[index + 2]
		var crossed: Variant = Geometry3D.segment_intersects_triangle(from, to, a, b, c)
		if crossed != null:
			return {"position": crossed, "face_index": index / 3,
				"distance": 0.0, "center_hit": true}
		var nearest: Vector3 = _triangle_point(from, a, b, c)
		var distance_squared: float = from.distance_squared_to(nearest)
		var endpoint: Vector3 = _triangle_point(to, a, b, c)
		if to.distance_squared_to(endpoint) < distance_squared:
			nearest = endpoint
			distance_squared = to.distance_squared_to(endpoint)
		for edge: Array in [[a, b], [b, c], [c, a]]:
			var pair: PackedVector3Array = Geometry3D.get_closest_points_between_segments(
				from, to, edge[0], edge[1]
			)
			var edge_distance: float = pair[0].distance_squared_to(pair[1])
			if edge_distance < distance_squared:
				nearest = pair[1]
				distance_squared = edge_distance
		if distance_squared <= radius_squared:
			return {"position": nearest, "face_index": index / 3,
				"distance": sqrt(distance_squared), "center_hit": false}
	return {}


func _triangle_point(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var normal: Vector3 = (b - a).cross(c - a)
	var length_squared: float = normal.length_squared()
	if length_squared > 0:
		var projected: Vector3 = point - normal * normal.dot(point - a) / length_squared
		if normal.dot((b - a).cross(projected - a)) >= 0 \
			and normal.dot((c - b).cross(projected - b)) >= 0 \
			and normal.dot((a - c).cross(projected - c)) >= 0:
			return projected
	var closest: Vector3 = Geometry3D.get_closest_point_to_segment(point, a, b)
	for edge: Array in [[b, c], [c, a]]:
		var candidate: Vector3 = Geometry3D.get_closest_point_to_segment(point, edge[0], edge[1])
		if point.distance_squared_to(candidate) < point.distance_squared_to(closest):
			closest = candidate
	return closest
