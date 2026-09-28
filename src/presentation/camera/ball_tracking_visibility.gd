class_name BallTrackingVisibility
extends RefCounted

# Presentation-only bounds include scenery without gameplay collision shapes.
var field_wall_z: float = 23.4
var _obstacles: Array[AABB] = []
var _occluder_meshes: Array[MeshInstance3D] = []
var _faded: Dictionary = {}


func configure(geometry: Node) -> void:
	restore_occluders()
	_obstacles.clear()
	_occluder_meshes.clear()
	var wall: Node3D = geometry.get_node_or_null("BackWall")
	if wall != null:
		field_wall_z = wall.global_position.z - 0.25
	for node_name in ["BackWall", "LiveObjectPole", "CommonsParkScenery"]:
		var node: Node = geometry.get_node_or_null(node_name)
		if node != null:
			_collect(node)


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	if not _blocked(desired, ball):
		return desired
	# Pull toward an overhead view on the same side of play. This continuously
	# shortens the horizontal offset instead of cutting to the opposite end.
	var overhead: Vector3 = ball + Vector3(0, maxf(6.0, desired.y - ball.y), 0)
	var clear_fraction: float = 0.0
	var blocked_fraction: float = 1.0
	for step in range(10):
		var fraction: float = (clear_fraction + blocked_fraction) * 0.5
		if _blocked(overhead.lerp(desired, fraction), ball):
			blocked_fraction = fraction
		else:
			clear_fraction = fraction
	return overhead.lerp(desired, maxf(0.0, clear_fraction - 0.05))


func update_occluders(camera: Vector3, ball: Vector3, delta: float) -> void:
	# Preserve the rig when a live obstacle covers the ball. Material alpha also
	# works in Mobile, unlike GeometryInstance3D.transparency. Collision is intact.
	for mesh in _occluder_meshes:
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		var blocked: bool = bounds.grow(0.08).intersects_segment(camera, ball) != null
		if blocked and not _faded.has(mesh):
			var original: Material = mesh.material_override
			if not original is StandardMaterial3D:
				continue
			var faded: StandardMaterial3D = original.duplicate()
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.material_override = faded
			_faded[mesh] = original
		if not _faded.has(mesh):
			continue
		var material: StandardMaterial3D = mesh.material_override
		var color: Color = material.albedo_color
		color.a = 0.18 if blocked else move_toward(color.a, 1.0, delta * 3.0)
		material.albedo_color = color
		if color.a >= 1.0:
			mesh.material_override = _faded[mesh]
			_faded.erase(mesh)


func restore_occluders() -> void:
	for mesh in _faded:
		if is_instance_valid(mesh):
			mesh.material_override = _faded[mesh]
	_faded.clear()


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	for bounds in _obstacles:
		# A small margin starts the adjustment before the ball clips the wall.
		# Don't engulf a ball that is itself immediately next to that wall.
		var nearest: Vector3 = Vector3(
			clampf(ball.x, bounds.position.x, bounds.end.x),
			clampf(ball.y, bounds.position.y, bounds.end.y),
			clampf(ball.z, bounds.position.z, bounds.end.z)
		)
		var padded: AABB = bounds.grow(minf(0.4, ball.distance_to(nearest) * 0.5))
		if padded.intersects_segment(camera, ball) != null:
			return true
	return false


func _collect(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null and node.visible:
		var bounds: AABB = node.global_transform * node.get_aabb()
		# Turf stripes are surface decals, not occluders. Inflating their
		# millimeter thickness made rolling balls trigger huge false recoveries.
		if bounds.size.y > 0.025:
			_obstacles.append(bounds)
			_occluder_meshes.append(node)
	for child in node.get_children():
		_collect(child)
