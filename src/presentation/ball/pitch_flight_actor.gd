class_name PitchFlightActor
extends Node3D

signal trace_sampled(point: Vector3)
signal plate_crossed(point: Vector3, speed_mps: float, elapsed_seconds: float)
signal flight_stopped(reason: StringName)

@export var plate_z: float = 0.0
@export var max_flight_seconds: float = 3.0
@export var trace_every_substeps: int = 4

var state: PitchState
var parameters: PitchLaunchParameters
var running: bool = false

var _accumulator_seconds: float = 0.0
var _substep_count: int = 0

func _ready() -> void:
	_build_debug_ball()
	visible = false

func start_pitch(new_parameters: PitchLaunchParameters) -> void:
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
	if not running:
		return

	running = false
	flight_stopped.emit(reason)

func reset_pitch() -> void:
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
		var previous_position := state.position
		PitchFlightSolver.step(state, parameters)
		_accumulator_seconds -= PitchFlightSolver.SUBSTEP_SECONDS
		_substep_count += 1

		if _substep_count % max(1, trace_every_substeps) == 0:
			trace_sampled.emit(state.position)

		if previous_position.z > plate_z and state.position.z <= plate_z:
			var denominator := previous_position.z - state.position.z
			var fraction := 1.0
			if absf(denominator) > 0.000001:
				fraction = clamp(
					(previous_position.z - plate_z) / denominator,
					0.0,
					1.0
				)

			var crossing_point := previous_position.lerp(state.position, fraction)
			trace_sampled.emit(crossing_point)
			plate_crossed.emit(
				crossing_point,
				state.velocity.length(),
				state.elapsed_time
			)
			stop_pitch(&"plate_crossed")
			break

		if state.elapsed_time >= max_flight_seconds:
			stop_pitch(&"timeout")
			break

		if state.position.y < -1.0:
			stop_pitch(&"below_world")
			break

	global_position = state.position

func _build_debug_ball() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DebugBall"

	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 0.90)
	material.roughness = 0.85
	mesh_instance.material_override = material

	add_child(mesh_instance)
