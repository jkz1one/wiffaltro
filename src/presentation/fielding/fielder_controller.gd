class_name FielderController
extends CharacterBody3D

@export var move_speed_mps: float = 6.2
@export var fielding_rating: int = 6
@export var reach_m: float = 0.98

var anchor_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var active: bool = false
var last_reaction_margin_seconds: float = 0.0

func _ready() -> void:
	_build_debug_fielder()

func set_anchor(new_anchor: Vector3) -> void:
	anchor_position = new_anchor
	if not active:
		global_position = new_anchor
	target_position = new_anchor

func begin_play() -> void:
	active = true
	global_position = anchor_position
	target_position = anchor_position

func end_play() -> void:
	active = false
	velocity = Vector3.ZERO
	global_position = anchor_position
	target_position = anchor_position

func plan_for_ball(
	ball_position: Vector3,
	ball_velocity: Vector3,
	has_grounded: bool
) -> void:
	if not active:
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

func _physics_process(_delta: float) -> void:
	if not active:
		return
	var displacement: Vector3 = target_position - global_position
	displacement.y = 0.0
	if displacement.length() <= 0.05:
		velocity = Vector3.ZERO
		return
	velocity = displacement.normalized() * move_speed_mps
	move_and_slide()

func _build_debug_fielder() -> void:
	var body_mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.34
	capsule.height = 1.65
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.825

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.52, 0.95)
	material.roughness = 0.8
	body_mesh.material_override = material
	add_child(body_mesh)

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
