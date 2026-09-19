class_name BatActor
extends Node3D

const DEFAULT_SWING_SECONDS: float = 0.26

var bats_left: bool = false
var _pivot: Node3D
var _bat_axis: Node3D
var _swing_elapsed: float = 0.0
var _swing_duration: float = DEFAULT_SWING_SECONDS
var _sweet_spot_progress: float = 0.44
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
	var load: float = smoothstep(0.0, 0.15, progress)
	var drive: float = smoothstep(
		0.12,
		minf(0.72, _sweet_spot_progress + 0.18),
		progress
	)
	var finish: float = smoothstep(
		minf(0.78, _sweet_spot_progress + 0.15),
		1.0,
		progress
	)
	var yaw_degrees: float = lerpf(-28.0, -38.0, load)
	yaw_degrees = lerpf(yaw_degrees, 142.0, drive)
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
	# Batters face the mound along +Z. Right-handed presentation therefore
	# starts at +X on the back/right shoulder; left-handed presentation mirrors.
	_pivot.position = Vector3(side * 0.24, 1.15, 0.02)
	_pivot.rotation = Vector3(0.0, deg_to_rad(side * -28.0), 0.0)
	_bat_axis.rotation = Vector3(0.0, 0.0, deg_to_rad(-side * 58.0))

static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
