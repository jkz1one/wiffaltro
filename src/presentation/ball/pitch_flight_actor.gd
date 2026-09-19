class_name PitchFlightActor
extends Node3D

signal trace_sampled(point: Vector3)
signal segment_advanced(previous_position: Vector3, previous_elapsed_seconds: float)
signal plate_crossed(point: Vector3, speed_mps: float, elapsed_seconds: float)
signal flight_stopped(reason: StringName)

const RECEIVER_PLANE_Z: float = -1.05
const MIN_RECEIVER_TRAVEL_SECONDS: float = 0.055
const MAX_RECEIVER_TRAVEL_SECONDS: float = 0.16
const RECEIVER_HOLD_SECONDS: float = 0.18

@export var plate_z: float = 0.0
@export var max_flight_seconds: float = 3.0
@export var trace_every_substeps: int = 4

var state: PitchState
var parameters: PitchLaunchParameters
var running: bool = false

var _accumulator_seconds: float = 0.0
var _substep_count: int = 0
var _plate_follow_tween: Tween

func _ready() -> void:
	_build_debug_ball()
	visible = false

func start_pitch(new_parameters: PitchLaunchParameters) -> void:
	_cancel_plate_follow_through()
	parameters = new_parameters
	state = PitchState.new()
	state.position = parameters.position
	state.velocity = parameters.velocity
	state.orientation = parameters.orientation
	state.angular_velocity = parameters.angular_velocity
	state.pitch_id = parameters.pitch_id
	state.seed = parameters.seed

	_accumulator_seconds = 0.0
	_substep_count = 0
	running = true
	visible = true
	global_position = state.position
	trace_sampled.emit(state.position)

func stop_pitch(reason: StringName = &"stopped") -> void:
	_cancel_plate_follow_through()
	if not running:
		visible = false
		return

	running = false
	visible = false
	flight_stopped.emit(reason)

func reset_pitch() -> void:
	_cancel_plate_follow_through()
	running = false
	state = null
	parameters = null
	_accumulator_seconds = 0.0
	_substep_count = 0
	visible = false

func _physics_process(delta: float) -> void:
	if not running or state == null or parameters == null:
		return

	_accumulator_seconds += delta

	while (
		_accumulator_seconds >= PitchFlightSolver.SUBSTEP_SECONDS
		and running
	):
		var previous_position: Vector3 = state.position
		var previous_elapsed_seconds: float = state.elapsed_time
		PitchFlightSolver.step(state, parameters)
		_accumulator_seconds -= PitchFlightSolver.SUBSTEP_SECONDS
		_substep_count += 1
		segment_advanced.emit(previous_position, previous_elapsed_seconds)
		if not running:
			break

		if _substep_count % maxi(1, trace_every_substeps) == 0:
			trace_sampled.emit(state.position)

		if previous_position.z > plate_z and state.position.z <= plate_z:
			var denominator: float = previous_position.z - state.position.z
			var fraction: float = 1.0
			if absf(denominator) > 0.000001:
				fraction = clampf(
					(previous_position.z - plate_z) / denominator,
					0.0,
					1.0
				)

			var crossing_point: Vector3 = previous_position.lerp(state.position, fraction)
			state.position = crossing_point
			global_position = crossing_point
			trace_sampled.emit(crossing_point)
			running = false
			plate_crossed.emit(
				crossing_point,
				state.velocity.length(),
				state.elapsed_time
			)
			flight_stopped.emit(&"plate_crossed")
			_begin_plate_follow_through(crossing_point, state.velocity)
			break

		if state.elapsed_time >= max_flight_seconds:
			stop_pitch(&"timeout")
			break

		if state.position.y < -1.0:
			stop_pitch(&"below_world")
			break

	global_position = state.position

func _begin_plate_follow_through(
	crossing_point: Vector3,
	crossing_velocity: Vector3
) -> void:
	var receiver_seconds: float = clampf(
		(RECEIVER_PLANE_Z - crossing_point.z)
		/ minf(-0.001, crossing_velocity.z),
		MIN_RECEIVER_TRAVEL_SECONDS,
		MAX_RECEIVER_TRAVEL_SECONDS
	)
	var receiver_point: Vector3 = (
		crossing_point
		+ crossing_velocity * receiver_seconds
		+ Vector3.DOWN * 4.9 * receiver_seconds * receiver_seconds
	)
	receiver_point.z = RECEIVER_PLANE_Z
	_plate_follow_tween = create_tween().bind_node(self)
	_plate_follow_tween.tween_property(
		self,
		"global_position",
		receiver_point,
		receiver_seconds
	).set_trans(Tween.TRANS_LINEAR)
	_plate_follow_tween.tween_interval(RECEIVER_HOLD_SECONDS)
	_plate_follow_tween.tween_callback(_hide_after_plate_follow_through)

func _hide_after_plate_follow_through() -> void:
	visible = false
	_plate_follow_tween = null

func _cancel_plate_follow_through() -> void:
	if _plate_follow_tween != null and _plate_follow_tween.is_valid():
		_plate_follow_tween.kill()
	_plate_follow_tween = null

func _build_debug_ball() -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "DebugBall"

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	mesh_instance.mesh = sphere

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 0.90)
	material.roughness = 0.85
	mesh_instance.material_override = material

	add_child(mesh_instance)
