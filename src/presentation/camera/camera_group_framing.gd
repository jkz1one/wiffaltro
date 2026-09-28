class_name CameraGroupFraming
extends RefCounted


# Perspective fit in camera space, independent of stadium dimensions.
static func tangents(camera: Camera3D, fov: float) -> Vector2:
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var aspect: float = size.x / maxf(1.0, size.y)
	var tangent: float = tan(deg_to_rad(fov) * 0.5)
	return (
		Vector2(tangent * aspect, tangent)
		if camera.keep_aspect == Camera3D.KEEP_HEIGHT
		else Vector2(tangent, tangent / aspect)
	)


static func fit_distance(
	camera: Camera3D,
	basis: Basis,
	focus: Vector3,
	points: PackedVector3Array,
	fov: float,
	margin: float = 0.78
) -> float:
	var tangent: Vector2 = tangents(camera, fov) * margin
	var distance: float = 0.0
	for point in points:
		var local: Vector3 = basis.inverse() * (point - focus)
		distance = maxf(
			distance,
			local.z + maxf(absf(local.x) / tangent.x, absf(local.y) / tangent.y) + camera.near
		)
	return distance


static func fits(camera: Camera3D, points: PackedVector3Array, margin: float) -> bool:
	var tangent: Vector2 = tangents(camera, camera.fov) * margin
	for point in points:
		var local: Vector3 = camera.global_transform.affine_inverse() * point
		if (
			-local.z <= camera.near
			or absf(local.x) > -local.z * tangent.x
			or absf(local.y) > -local.z * tangent.y
		):
			return false
	return true


static func required_fov(camera: Camera3D, points: PackedVector3Array) -> float:
	var unit: Vector2 = tangents(camera, 90.0) * 0.86
	var tangent: float = 0.0
	for point in points:
		var local: Vector3 = camera.global_transform.affine_inverse() * point
		var depth: float = maxf(0.1, -local.z)
		tangent = maxf(tangent, maxf(absf(local.x) / unit.x, absf(local.y) / unit.y) / depth)
	return rad_to_deg(atan(tangent)) * 2.0


static func play_subjects(
	context: FieldCameraContext,
	ball: Vector3,
	forecast: Vector3,
	defenders: PackedVector3Array,
	speed: float
) -> PackedVector3Array:
	var up: Vector3 = context.up()
	var points: PackedVector3Array = PackedVector3Array(
		[ball + up * 0.18, ball - up * 0.18, context.ground_point(ball), forecast]
	)
	var nearest: Vector3 = Vector3.ZERO
	var distance: float = INF
	for defender in defenders:
		var candidate: float = defender.distance_to(context.ground_point(forecast))
		if candidate < distance:
			distance = candidate
			nearest = defender
	if distance < maxf(4.0, speed * 0.45):
		points.append(nearest)
		points.append(nearest + up * 1.7)
	return points
