class_name FielderController
extends CharacterBody3D

@export var move_speed_mps: float = 5.2
@export var fielding_rating: int = 6
@export var reach_m: float = 0.98

var anchor_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var active: bool = false
var last_reaction_margin_seconds: float = 0.0
var reaction_delay_seconds: float = 0.11
var _play_elapsed_seconds: float = 0.0
var _avatar: PlayerAvatar

func _ready() -> void:
	_build_debug_fielder()

func set_anchor(new_anchor: Vector3) -> void:
	anchor_position = new_anchor
	if not active:
		global_position = new_anchor
	target_position = new_anchor

func begin_play() -> void:
	active = true
	_play_elapsed_seconds = 0.0
	global_position = anchor_position
	target_position = anchor_position

func end_play() -> void:
	active = false
	velocity = Vector3.ZERO
	global_position = anchor_position
	target_position = anchor_position
	_play_elapsed_seconds = 0.0

func configure_player(player: PlayerDefinition) -> void:
	if player == null:
		return
	fielding_rating = player.fielding
	move_speed_mps = lerpf(
		4.55,
		5.85,
		clampf(float(fielding_rating) / 10.0, 0.0, 1.0)
	)
	reach_m = lerpf(
		0.82,
		1.08,
		clampf(float(fielding_rating) / 10.0, 0.0, 1.0)
	)
	reaction_delay_seconds = lerpf(
		0.19,
		0.055,
		clampf(float(fielding_rating) / 10.0, 0.0, 1.0)
	)
	if _avatar != null:
		_avatar.configure(
			PlayerAvatar.Role.FIELDER,
			player.bats == PlayerDefinition.Handedness.LEFT,
			player.throws == PlayerDefinition.Handedness.LEFT,
			Color(0.18, 0.52, 0.95)
		)

func plan_for_ball(
	ball_position: Vector3,
	ball_velocity: Vector3,
	has_grounded: bool
) -> void:
	if not active:
		return
	if _play_elapsed_seconds < reaction_delay_seconds:
		return
	var plan_result: FielderPlan = FielderPlanner.plan(
		ball_position,
		ball_velocity,
		has_grounded,
		global_position,
		move_speed_mps,
		reach_m
	)
	target_position = plan_result.intercept_position
	last_reaction_margin_seconds = plan_result.reaction_margin_seconds

func horizontal_distance_to(point: Vector3) -> float:
	return Vector2(
		point.x - global_position.x,
		point.z - global_position.z
	).length()

func _physics_process(delta: float) -> void:
	if not active:
		return
	_play_elapsed_seconds += maxf(0.0, delta)
	if _play_elapsed_seconds < reaction_delay_seconds:
		velocity = Vector3.ZERO
		return
	var displacement: Vector3 = target_position - global_position
	displacement.y = 0.0
	if displacement.length() <= 0.05:
		velocity = Vector3.ZERO
		return
	velocity = displacement.normalized() * move_speed_mps
	move_and_slide()

func _build_debug_fielder() -> void:
	_avatar = PlayerAvatar.new()
	_avatar.name = "FielderAvatar"
	add_child(_avatar)
	_avatar.configure(
		PlayerAvatar.Role.FIELDER,
		false,
		false,
		Color(0.18, 0.52, 0.95)
	)

	var shadow_marker: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = reach_m
	cylinder.bottom_radius = reach_m
	cylinder.height = 0.018
	shadow_marker.mesh = cylinder
	shadow_marker.position.y = 0.018

	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.15, 0.55, 1.0, 0.16)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_marker.material_override = marker_material
	add_child(shadow_marker)
