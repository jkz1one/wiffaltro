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
