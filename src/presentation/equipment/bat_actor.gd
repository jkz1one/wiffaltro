class_name BatActor
extends Node3D

const DEFAULT_SWING_SECONDS: float = 0.26
const FOLLOW_THROUGH_HOLD_SECONDS: float = 0.10
const SLOT_SPLIT: float = 0.34
const EXTENSION_SPLIT: float = 0.48
const STANCE_YAW_DEGREES: float = 72.0
const SLOT_YAW_DEGREES: float = 38.0
const CONTACT_YAW_DEGREES: float = 0.0
const EXTENSION_YAW_DEGREES: float = -28.0
const FINISH_YAW_DEGREES: float = -102.0
const STANCE_AXIS_TILT_DEGREES: float = 54.0
const SLOT_AXIS_TILT_DEGREES: float = 68.0
const CONTACT_AXIS_TILT_DEGREES: float = 88.0
const EXTENSION_AXIS_TILT_DEGREES: float = 78.0
const FINISH_AXIS_TILT_DEGREES: float = 42.0

var bats_left: bool = false
var _pivot: Node3D
var _bat_axis: Node3D
var _swing_elapsed: float = 0.0
var _swing_duration: float = DEFAULT_SWING_SECONDS
var _sweet_spot_progress: float = 0.44
var _attack_angle_degrees: float = 7.0
var _swinging: bool = false
var _aim_pose: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_bat()
	_apply_stance()


func configure(new_bats_left: bool, batter_position: Vector3) -> void:
	bats_left = new_bats_left
	position = batter_position
	if _pivot != null:
		reset_swing()


func play_swing(profile: SwingProfileDefinition) -> void:
	if profile == null:
		return
	_swing_duration = profile.swing_duration_seconds
	_sweet_spot_progress = clampf(
		profile.sweet_spot_seconds / maxf(0.001, _swing_duration), 0.25, 0.72
	)
	_attack_angle_degrees = profile.attack_angle_degrees
	_swing_elapsed = 0.0
	_swinging = true
	_apply_stance()


func set_aim_pose(normalized_aim: Vector2) -> void:
	_aim_pose = Vector2(clampf(normalized_aim.x, -1.0, 1.0), clampf(normalized_aim.y, -1.0, 1.0))
	if not _swinging and _pivot != null:
		_apply_stance()


func reset_swing() -> void:
	_swinging = false
	_swing_elapsed = 0.0
	if _pivot != null:
		_apply_stance()


func _process(delta: float) -> void:
	if not _swinging or _pivot == null:
		return
	_swing_elapsed += maxf(0.0, delta)
	_apply_swing_pose(minf(_swing_elapsed, _swing_duration))
	if _swing_elapsed >= _swing_duration + FOLLOW_THROUGH_HOLD_SECONDS:
		reset_swing()


func _apply_swing_pose(elapsed_seconds: float) -> void:
	var side: float = handed_side(bats_left)
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, _sweet_spot_progress * _swing_duration, _swing_duration
	)
	var aim_influence: float = aim_influence_at_phases(phases)
	_pivot.position = (
		pivot_position_at_elapsed(
			bats_left, elapsed_seconds, _sweet_spot_progress * _swing_duration, _swing_duration
		)
		+ aim_pose_position_offset(_aim_pose) * aim_influence
	)
	_pivot.rotation = Vector3(
		deg_to_rad(-_attack_angle_degrees),
		deg_to_rad(
			(
				yaw_degrees_at_elapsed(
					bats_left,
					elapsed_seconds,
					_sweet_spot_progress * _swing_duration,
					_swing_duration
				)
				+ aim_pose_yaw_offset_degrees(_aim_pose) * aim_influence
			)
		),
		0.0
	)
	_bat_axis.rotation.z = deg_to_rad(
		(
			-side
			* (
				axis_tilt_degrees_at_elapsed(
					elapsed_seconds, _sweet_spot_progress * _swing_duration, _swing_duration
				)
				+ aim_pose_axis_tilt_degrees(_aim_pose) * aim_influence
			)
		)
	)


func _build_bat() -> void:
	_pivot = Node3D.new()
	_pivot.name = "SwingPivot"
	add_child(_pivot)

	_bat_axis = Node3D.new()
	_bat_axis.name = "BatAxis"
	_pivot.add_child(_bat_axis)

	var knob: MeshInstance3D = MeshInstance3D.new()
	var knob_mesh: SphereMesh = SphereMesh.new()
	knob_mesh.radius = 0.040
	knob_mesh.height = 0.080
	knob.mesh = knob_mesh
	knob.position.y = -0.025
	knob.material_override = _material(Color(0.46, 0.28, 0.11))
	_bat_axis.add_child(knob)

	var handle: MeshInstance3D = MeshInstance3D.new()
	var handle_mesh: CylinderMesh = CylinderMesh.new()
	handle_mesh.top_radius = 0.025
	handle_mesh.bottom_radius = 0.030
	handle_mesh.height = 0.34
	handle.mesh = handle_mesh
	handle.position.y = 0.17
	handle.material_override = _material(Color(0.56, 0.35, 0.14))
	_bat_axis.add_child(handle)

	var barrel: MeshInstance3D = MeshInstance3D.new()
	var barrel_mesh: CylinderMesh = CylinderMesh.new()
	barrel_mesh.top_radius = 0.060
	barrel_mesh.bottom_radius = 0.038
	barrel_mesh.height = 0.66
	barrel.mesh = barrel_mesh
	barrel.position.y = 0.67
	barrel.material_override = _material(Color(0.82, 0.68, 0.36))
	_bat_axis.add_child(barrel)


func _apply_stance() -> void:
	var side: float = handed_side(bats_left)
	# The hands begin behind the back shoulder (-Z), drive to a square barrel
	# at the authored sweet-spot time, then finish toward the front shoulder.
	# Handedness mirrors X and yaw while preserving that back-to-front motion.
	_pivot.position = (stance_pivot_position(bats_left) + aim_pose_position_offset(_aim_pose))
	_pivot.rotation = Vector3(
		deg_to_rad(-_attack_angle_degrees),
		deg_to_rad(side * STANCE_YAW_DEGREES + aim_pose_yaw_offset_degrees(_aim_pose)),
		0.0
	)
	_bat_axis.rotation = Vector3(
		0.0,
		0.0,
		deg_to_rad(-side * (STANCE_AXIS_TILT_DEGREES + aim_pose_axis_tilt_degrees(_aim_pose)))
	)


static func aim_pose_position_offset(normalized_aim: Vector2) -> Vector3:
	return Vector3(0.0, clampf(normalized_aim.y, -1.0, 1.0) * 0.075, 0.0)


static func aim_pose_yaw_offset_degrees(normalized_aim: Vector2) -> float:
	return clampf(normalized_aim.x, -1.0, 1.0) * 4.0


static func aim_pose_axis_tilt_degrees(normalized_aim: Vector2) -> float:
	return clampf(normalized_aim.y, -1.0, 1.0) * 4.0 + clampf(normalized_aim.x, -1.0, 1.0) * 2.0


static func handed_side(is_left_handed: bool) -> float:
	return 1.0 if is_left_handed else -1.0


static func stance_pivot_x(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * 0.24


static func stance_yaw_degrees(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * STANCE_YAW_DEGREES


static func contact_yaw_degrees(_is_left_handed: bool) -> float:
	return CONTACT_YAW_DEGREES


static func finish_yaw_degrees(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * FINISH_YAW_DEGREES


static func stance_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(stance_pivot_x(is_left_handed), 1.20, -0.20)


static func slot_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.19, 1.08, -0.04)


static func contact_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.34, 0.98, 0.09)


static func extension_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.42, 1.02, 0.34)


static func finish_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.12, 1.30, 0.22)


static func pivot_position_at_elapsed(
	is_left_handed: bool,
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> Vector3:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	if phases.y <= 0.0:
		return _interpolate_keyed_vector3(
			stance_pivot_position(is_left_handed),
			slot_pivot_position(is_left_handed),
			contact_pivot_position(is_left_handed),
			phases.x,
			SLOT_SPLIT
		)
	return _interpolate_keyed_vector3(
		contact_pivot_position(is_left_handed),
		extension_pivot_position(is_left_handed),
		finish_pivot_position(is_left_handed),
		phases.y,
		EXTENSION_SPLIT
	)


static func yaw_degrees_at_elapsed(
	is_left_handed: bool,
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> float:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	var side: float = handed_side(is_left_handed)
	if phases.y <= 0.0:
		return side * _interpolate_keyed_float(
			STANCE_YAW_DEGREES,
			SLOT_YAW_DEGREES,
			CONTACT_YAW_DEGREES,
			phases.x,
			SLOT_SPLIT
		)
	return side * _interpolate_keyed_float(
		CONTACT_YAW_DEGREES,
		EXTENSION_YAW_DEGREES,
		FINISH_YAW_DEGREES,
		phases.y,
		EXTENSION_SPLIT
	)


static func axis_tilt_degrees_at_elapsed(
	elapsed_seconds: float, sweet_spot_seconds: float, swing_duration_seconds: float
) -> float:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	if phases.y <= 0.0:
		return _interpolate_keyed_float(
			STANCE_AXIS_TILT_DEGREES,
			SLOT_AXIS_TILT_DEGREES,
			CONTACT_AXIS_TILT_DEGREES,
			phases.x,
			SLOT_SPLIT
		)
	return _interpolate_keyed_float(
		CONTACT_AXIS_TILT_DEGREES,
		EXTENSION_AXIS_TILT_DEGREES,
		FINISH_AXIS_TILT_DEGREES,
		phases.y,
		EXTENSION_SPLIT
	)


static func torso_yaw_degrees_at_elapsed(
	is_left_handed: bool,
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> float:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	var side: float = handed_side(is_left_handed)
	if phases.y <= 0.0:
		return side * _interpolate_keyed_float(-10.0, 4.0, 20.0, phases.x, SLOT_SPLIT)
	return side * _interpolate_keyed_float(20.0, 32.0, 42.0, phases.y, EXTENSION_SPLIT)


static func body_offset_at_elapsed(
	elapsed_seconds: float, sweet_spot_seconds: float, swing_duration_seconds: float
) -> Vector3:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	if phases.y <= 0.0:
		return _interpolate_keyed_vector3(
			Vector3(0.0, 0.0, -0.02),
			Vector3.ZERO,
			Vector3(0.0, 0.0, 0.07),
			phases.x,
			SLOT_SPLIT
		)
	return _interpolate_keyed_vector3(
		Vector3(0.0, 0.0, 0.07),
		Vector3(0.0, 0.0, 0.09),
		Vector3(0.0, 0.0, 0.05),
		phases.y,
		EXTENSION_SPLIT
	)


static func aim_influence_at_phases(phases: Vector2) -> float:
	if phases.y <= 0.0:
		return lerpf(1.0, 0.65, phases.x)
	return lerpf(0.65, 0.15, phases.y)


static func phase_progress_at_elapsed(
	elapsed_seconds: float, sweet_spot_seconds: float, swing_duration_seconds: float
) -> Vector2:
	var safe_sweet_spot: float = maxf(0.001, sweet_spot_seconds)
	var safe_duration: float = maxf(safe_sweet_spot + 0.001, swing_duration_seconds)
	if elapsed_seconds <= safe_sweet_spot:
		var pre_contact: float = clampf(elapsed_seconds / safe_sweet_spot, 0.0, 1.0)
		# Cubic Hermite drive: start at rest, peak shortly before contact, and
		# retain nearly that velocity through the ball instead of easing to a
		# stop at the authored sweet spot.
		var drive: float = (
			-0.6 * pre_contact * pre_contact * pre_contact + 1.6 * pre_contact * pre_contact
		)
		return Vector2(drive, 0.0)
	var post_contact: float = clampf(
		(elapsed_seconds - safe_sweet_spot) / (safe_duration - safe_sweet_spot), 0.0, 1.0
	)
	# Continue through contact without a speed discontinuity, then decelerate
	# monotonically into a readable front-shoulder finish.
	var follow_through: float = (
		1.5 * post_contact - 0.5 * post_contact * post_contact * post_contact
	)
	return Vector2(1.0, follow_through)


static func _interpolate_keyed_float(
	start_value: float, middle_value: float, end_value: float, progress: float, split: float
) -> float:
	var bounded: float = clampf(progress, 0.0, 1.0)
	if bounded <= split:
		var first_progress: float = smoothstep(0.0, split, bounded)
		return lerpf(start_value, middle_value, first_progress)
	var second_progress: float = smoothstep(split, 1.0, bounded)
	return lerpf(middle_value, end_value, second_progress)


static func _interpolate_keyed_vector3(
	start_value: Vector3,
	middle_value: Vector3,
	end_value: Vector3,
	progress: float,
	split: float
) -> Vector3:
	var bounded: float = clampf(progress, 0.0, 1.0)
	if bounded <= split:
		var first_progress: float = smoothstep(0.0, split, bounded)
		return start_value.lerp(middle_value, first_progress)
	var second_progress: float = smoothstep(split, 1.0, bounded)
	return middle_value.lerp(end_value, second_progress)


static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
