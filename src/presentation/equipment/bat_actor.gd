class_name BatActor
extends Node3D

const CONTACT_SWING_SECONDS: float = 0.36
const POWER_SWING_SECONDS: float = 0.46

var bats_left: bool = false
var _pivot: Node3D
var _bat_axis: Node3D
var _swing_elapsed: float = 0.0
var _swing_duration: float = CONTACT_SWING_SECONDS
var _swinging: bool = false

func _ready() -> void:
	_build_bat()
	_apply_stance()

func configure(new_bats_left: bool, batter_position: Vector3) -> void:
	bats_left = new_bats_left
	position = batter_position
	if _pivot != null:
		reset_swing()

func play_swing(power: bool) -> void:
	_swing_duration = POWER_SWING_SECONDS if power else CONTACT_SWING_SECONDS
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
	var progress: float = clampf(_swing_elapsed / _swing_duration, 0.0, 1.0)
	var side: float = -1.0 if bats_left else 1.0
	var drive: float = smoothstep(0.0, 0.68, progress)
	var finish: float = smoothstep(0.68, 1.0, progress)
	var yaw_degrees: float = lerpf(-28.0, 142.0, drive)
	yaw_degrees = lerpf(yaw_degrees, 168.0, finish)
	_pivot.rotation.y = deg_to_rad(side * yaw_degrees)
	_bat_axis.rotation.z = deg_to_rad(
		-side * lerpf(58.0, 84.0, drive) * (1.0 - finish * 0.12)
	)
	if progress >= 1.0:
		reset_swing()

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
	var side: float = -1.0 if bats_left else 1.0
	_pivot.position = Vector3(-side * 0.24, 1.15, 0.02)
	_pivot.rotation = Vector3(0.0, deg_to_rad(side * -28.0), 0.0)
	_bat_axis.rotation = Vector3(0.0, 0.0, deg_to_rad(-side * 58.0))

static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
