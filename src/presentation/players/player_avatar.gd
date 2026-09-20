class_name PlayerAvatar
extends Node3D

enum Role {
	BATTER,
	PITCHER,
	FIELDER,
}

var role: Role = Role.FIELDER
var bats_left: bool = false
var throws_left: bool = false
var _body_root: Node3D
var _throw_hand: MeshInstance3D
var _glove_hand: MeshInstance3D

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

func _apply_stance() -> void:
	if _body_root == null:
		return
	var bat_side: float = -1.0 if bats_left else 1.0
	var throw_side: float = -1.0 if throws_left else 1.0
	_body_root.rotation = Vector3.ZERO
	if role == Role.BATTER:
		_throw_hand.position = Vector3(bat_side * 0.18, 1.15, 0.01)
		_glove_hand.position = Vector3(bat_side * 0.29, 1.15, 0.03)
		_throw_hand.material_override = _material(Color(1.0, 0.76, 0.42))
		_glove_hand.material_override = _material(Color(1.0, 0.76, 0.42))
	else:
		_throw_hand.position = Vector3(throw_side * 0.38, 1.12, 0.0)
		_glove_hand.position = Vector3(-throw_side * 0.38, 1.10, 0.02)
		_throw_hand.material_override = _material(Color(1.0, 0.76, 0.42))
		_glove_hand.material_override = _material(Color(0.18, 0.12, 0.08))

func set_pitch_delivery_progress(progress: float, sidearm: bool) -> void:
	if role != Role.PITCHER or _body_root == null:
		return
	var bounded_progress: float = clampf(progress, 0.0, 1.0)
	var throw_side: float = -1.0 if throws_left else 1.0
	var load: float = smoothstep(0.08, 0.48, bounded_progress)
	var drive: float = smoothstep(0.46, 0.94, bounded_progress)
	var arm_height: float = 1.31 if sidearm else 1.62
	var loaded_throw_hand: Vector3 = Vector3(
		throw_side * 0.52,
		arm_height,
		0.14
	)
	var release_throw_hand: Vector3 = Vector3(
		throw_side * (0.30 if sidearm else 0.12),
		1.30 if sidearm else 1.48,
		-0.46
	)
	_throw_hand.position = Vector3(
		throw_side * 0.38,
		1.12,
		0.0
	).lerp(loaded_throw_hand, load).lerp(release_throw_hand, drive)
	_glove_hand.position = Vector3(
		-throw_side * 0.38,
		1.10,
		0.02
	).lerp(
		Vector3(-throw_side * 0.16, 1.34, -0.16),
		maxf(load * 0.72, drive)
	)
	_body_root.rotation.y = throw_side * lerpf(
		-0.16 * load,
		0.30,
		drive
	)

func reset_pose() -> void:
	_apply_stance()

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
