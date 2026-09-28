class_name FieldCameraContext
extends RefCounted

# All provider coordinates are field-local. Future stadium generators may expose
# camera_play_bounds() and camera_ground_height(local_point) without changing rigs.
var definition: FieldDefinition
var geometry: Node3D
var mound: Vector3 = Vector3(0, 0, 13.716)


func configure(field: FieldDefinition, root: Node3D, mound_position: Vector3) -> void:
	definition = field
	geometry = root
	mound = mound_position


func frame() -> Transform3D:
	return geometry.global_transform if is_instance_valid(geometry) else Transform3D.IDENTITY


func play_bounds() -> AABB:
	if is_instance_valid(geometry) and geometry.has_method("camera_play_bounds"):
		var supplied: AABB = geometry.call("camera_play_bounds")
		if supplied.size.x > 0.0 and supplied.size.z > 0.0:
			return supplied
	var depth: float = definition.back_wall_z_m if definition != null else mound.z * 1.7
	var angle: float = definition.fair_half_angle_degrees if definition != null else 42.0
	var width: float = depth * tan(deg_to_rad(angle))
	var height: float = definition.home_run_height_m if definition != null else 3.25
	return AABB(Vector3(-width, 0, 0), Vector3(width * 2.0, height, depth))


func ground_point(world_point: Vector3) -> Vector3:
	var local: Vector3 = frame().affine_inverse() * world_point
	local.y = play_bounds().position.y
	if is_instance_valid(geometry) and geometry.has_method("camera_ground_height"):
		local.y = float(geometry.call("camera_ground_height", local))
	return frame() * local


func depth_m() -> float:
	return maxf(5.0, play_bounds().size.z * frame().basis.z.length())


func up() -> Vector3:
	return frame().basis.y.normalized()
