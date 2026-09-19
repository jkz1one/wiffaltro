class_name PlayerAvatar
extends Node3D

enum Role {
	BATTER,
	PITCHER,
	FIELDER,
}

const CONTACT_SWING_SECONDS: float = 0.34
const POWER_SWING_SECONDS: float = 0.43

var role: Role = Role.FIELDER
var bats_left: bool = false
var throws_left: bool = false
var _body_root: Node3D
var _bat_pivot: Node3D
var _bat_mesh: MeshInstance3D
var _throw_hand: MeshInstance3D
var _glove_hand: MeshInstance3D
var _swing_elapsed: float = 0.0
var _swing_duration: float = CONTACT_SWING_SECONDS
var _swinging: bool = false

func _ready() -> void:
	_build_avatar()
	_apply_stance()

func configure(
	new_role: Role,
	new_bats_left: bool,
	new_throws_left: bool,
	body_color: Color
) -> void:
	role = new_role
	bats_left = new_bats_left
	throws_left = new_throws_left
	if _body_root == null:
		return
	_set_body_color(body_color)
	_apply_stance()

func play_swing(power: bool) -> void:
	if role != Role.BATTER:
		return
	_swing_duration = POWER_SWING_SECONDS if power else CONTACT_SWING_SECONDS
	_swing_elapsed = 0.0
	_swinging = true
	_apply_stance()

func _process(delta: float) -> void:
	if not _swinging or _bat_pivot == null:
		return
	_swing_elapsed += maxf(0.0, delta)
	var progress: float = clampf(_swing_elapsed / _swing_duration, 0.0, 1.0)
	var handedness: float = -1.0 if bats_left else 1.0
	var sweep: float = smoothstep(0.0, 0.72, progress)
	var follow: float = smoothstep(0.72, 1.0, progress)
	_bat_pivot.rotation.y = deg_to_rad(
		handedness * lerpf(-42.0, 128.0, sweep)
	)
	_body_root.rotation.y = deg_to_rad(
		handedness * lerpf(-8.0, 34.0, sweep) * (1.0 - follow * 0.35)
	)
	if progress >= 1.0:
		_swinging = false
		_apply_stance()

func _build_avatar() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)

	var torso: MeshInstance3D = MeshInstance3D.new()
	var torso_mesh: CapsuleMesh = CapsuleMesh.new()
	torso_mesh.radius = 0.28
	torso_mesh.height = 1.18
	torso.mesh = torso_mesh
	torso.position.y = 0.78
	_body_root.add_child(torso)

	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.20
	head_mesh.height = 0.40
	head.mesh = head_mesh
	head.position.y = 1.55
	head.material_override = _material(Color(0.82, 0.63, 0.45))
	_body_root.add_child(head)

	_throw_hand = _hand_mesh(Color(1.0, 0.76, 0.42))
	_body_root.add_child(_throw_hand)
	_glove_hand = _hand_mesh(Color(0.18, 0.12, 0.08))
	_body_root.add_child(_glove_hand)

	_bat_pivot = Node3D.new()
	_bat_pivot.name = "BatPivot"
	_bat_pivot.position.y = 1.13
	_body_root.add_child(_bat_pivot)
	_bat_mesh = MeshInstance3D.new()
	var bat: CylinderMesh = CylinderMesh.new()
	bat.top_radius = 0.035
	bat.bottom_radius = 0.065
	bat.height = 1.15
	_bat_mesh.mesh = bat
	_bat_mesh.position = Vector3(0.0, 0.48, 0.0)
	_bat_mesh.rotation.z = deg_to_rad(68.0)
	_bat_mesh.material_override = _material(Color(0.82, 0.68, 0.36))
	_bat_pivot.add_child(_bat_mesh)

func _apply_stance() -> void:
	if _body_root == null:
		return
	var bat_side: float = -1.0 if bats_left else 1.0
	var throw_side: float = -1.0 if throws_left else 1.0
	_body_root.rotation = Vector3.ZERO
	_bat_pivot.visible = role == Role.BATTER
	_bat_pivot.position.x = bat_side * 0.20
	_bat_pivot.rotation = Vector3(
		deg_to_rad(8.0),
		deg_to_rad(bat_side * -42.0),
		0.0
	)
	_throw_hand.position = Vector3(throw_side * 0.38, 1.12, 0.0)
	_glove_hand.position = Vector3(-throw_side * 0.38, 1.10, 0.02)
	_throw_hand.visible = role != Role.BATTER
	_glove_hand.visible = role != Role.BATTER

func _set_body_color(color: Color) -> void:
	if _body_root.get_child_count() <= 0:
		return
	var torso: MeshInstance3D = _body_root.get_child(0) as MeshInstance3D
	if torso != null:
		torso.material_override = _material(color)

static func _hand_mesh(color: Color) -> MeshInstance3D:
	var hand: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	hand.mesh = sphere
	hand.material_override = _material(color)
	return hand

static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
