class_name BatActor
extends Node3D

const DEFAULT_SWING_SECONDS: float = 0.26
const FOLLOW_THROUGH_HOLD_SECONDS: float = 0.10
const STANCE_YAW_DEGREES: float = 64.0
const FINISH_YAW_DEGREES: float = -88.0
const STANCE_AXIS_TILT_DEGREES: float = 58.0
const CONTACT_AXIS_TILT_DEGREES: float = 84.0
const FINISH_AXIS_TILT_DEGREES: float = 52.0

var bats_left: bool = false
var _pivot: Node3D
var _bat_axis: Node3D
var _swing_elapsed: float = 0.0
var _swing_duration: float = DEFAULT_SWING_SECONDS
var _sweet_spot_progress: float = 0.44
var _attack_angle_degrees: float = 7.0
var _swinging: bool = false

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
		profile.sweet_spot_seconds / maxf(0.001, _swing_duration),
		0.25,
		0.72
	)
	_attack_angle_degrees = profile.attack_angle_degrees
	_swing_elapsed = 0.0
	_swinging = true
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
	_pivot.position = pivot_position_at_elapsed(
		bats_left,
		elapsed_seconds,
		_sweet_spot_progress * _swing_duration,
		_swing_duration
	)
	_pivot.rotation = Vector3(
		deg_to_rad(-_attack_angle_degrees),
		deg_to_rad(
			yaw_degrees_at_elapsed(
				bats_left,
				elapsed_seconds,
				_sweet_spot_progress * _swing_duration,
				_swing_duration
			)
		),
		0.0
	)
	_bat_axis.rotation.z = deg_to_rad(
		-side * axis_tilt_degrees_at_elapsed(
			elapsed_seconds,
			_sweet_spot_progress * _swing_duration,
			_swing_duration
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
	_pivot.position = stance_pivot_position(bats_left)
	_pivot.rotation = Vector3(
		deg_to_rad(-_attack_angle_degrees),
		deg_to_rad(side * STANCE_YAW_DEGREES),
		0.0
	)
	_bat_axis.rotation = Vector3(
		0.0,
		0.0,
		deg_to_rad(-side * STANCE_AXIS_TILT_DEGREES)
	)

static func handed_side(is_left_handed: bool) -> float:
	return -1.0 if is_left_handed else 1.0

static func stance_pivot_x(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * 0.24

static func stance_yaw_degrees(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * STANCE_YAW_DEGREES

static func contact_yaw_degrees(_is_left_handed: bool) -> float:
	return 0.0

static func finish_yaw_degrees(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * FINISH_YAW_DEGREES

static func stance_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(stance_pivot_x(is_left_handed), 1.15, -0.14)

static func contact_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.33, 0.97, 0.08)

static func finish_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.12, 1.18, 0.22)

static func pivot_position_at_elapsed(
	is_left_handed: bool,
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> Vector3:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds,
		sweet_spot_seconds,
		swing_duration_seconds
	)
	if phases.y <= 0.0:
		return stance_pivot_position(is_left_handed).lerp(
			contact_pivot_position(is_left_handed),
			phases.x
		)
	return contact_pivot_position(is_left_handed).lerp(
		finish_pivot_position(is_left_handed),
		phases.y
	)

static func yaw_degrees_at_elapsed(
	is_left_handed: bool,
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> float:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds,
		sweet_spot_seconds,
		swing_duration_seconds
	)
	if phases.y <= 0.0:
		return lerpf(
			stance_yaw_degrees(is_left_handed),
			contact_yaw_degrees(is_left_handed),
			phases.x
		)
	return lerpf(
		contact_yaw_degrees(is_left_handed),
		finish_yaw_degrees(is_left_handed),
		phases.y
	)

static func axis_tilt_degrees_at_elapsed(
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> float:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds,
		sweet_spot_seconds,
		swing_duration_seconds
	)
	if phases.y <= 0.0:
		return lerpf(
			STANCE_AXIS_TILT_DEGREES,
			CONTACT_AXIS_TILT_DEGREES,
			phases.x
		)
	return lerpf(
		CONTACT_AXIS_TILT_DEGREES,
		FINISH_AXIS_TILT_DEGREES,
		phases.y
	)

static func phase_progress_at_elapsed(
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> Vector2:
	var safe_sweet_spot: float = maxf(0.001, sweet_spot_seconds)
	var safe_duration: float = maxf(
		safe_sweet_spot + 0.001,
		swing_duration_seconds
	)
	if elapsed_seconds <= safe_sweet_spot:
		var pre_contact: float = clampf(
			elapsed_seconds / safe_sweet_spot,
			0.0,
			1.0
		)
		# Cubic Hermite drive: start at rest, peak shortly before contact, and
		# retain nearly that velocity through the ball instead of easing to a
		# stop at the authored sweet spot.
		var drive: float = (
			-0.6 * pre_contact * pre_contact * pre_contact
			+ 1.6 * pre_contact * pre_contact
		)
		return Vector2(drive, 0.0)
	var post_contact: float = clampf(
		(elapsed_seconds - safe_sweet_spot)
		/ (safe_duration - safe_sweet_spot),
		0.0,
		1.0
	)
	# Continue through contact without a speed discontinuity, then decelerate
	# monotonically into a readable front-shoulder finish.
	var follow_through: float = (
		1.5 * post_contact
		- 0.5 * post_contact * post_contact * post_contact
	)
	return Vector2(1.0, follow_through)

static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
