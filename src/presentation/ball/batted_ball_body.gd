class_name BattedBallBody
extends RigidBody3D

signal surface_contact(surface_id: StringName, contact_position: Vector3)

@export var aero_drag_coefficient: float = 0.22
@export var aero_magnus_scale: float = 1.0
@export var aero_perforation_force_scale: float = 1.0

var ball_mass_kg: float = 0.020
var radius_m: float = 0.0365
var hole_axis_ball_local: Vector3 = Vector3.RIGHT
var _started: bool = false

func _ready() -> void:
	mass = ball_mass_kg
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	collision_layer = 2
	collision_mask = 1
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = true
	_build_debug_ball()
	body_entered.connect(_on_body_entered)

func configure_aero(ball_setup: BallSetupDefinition) -> void:
	if ball_setup == null or ball_setup.aero_profile == null:
		return
	var aero: BallAeroProfileDefinition = ball_setup.aero_profile
	ball_mass_kg = aero.mass_kg
	radius_m = aero.radius_m
	aero_drag_coefficient = aero.drag_coefficient * ball_setup.drag_multiplier
	aero_magnus_scale = aero.magnus_scale * ball_setup.magnus_multiplier
	aero_perforation_force_scale = (
		aero.perforation_force_scale
		* ball_setup.perforation_multiplier
	)

func launch(launch_data: BattedBallLaunch) -> void:
	global_position = launch_data.position
	linear_velocity = launch_data.velocity
	angular_velocity = launch_data.angular_velocity
	quaternion = launch_data.orientation
	_started = true
	freeze = false
	sleeping = false

func stop_and_freeze() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	set_deferred(&"freeze", true)

func deflect(new_velocity: Vector3, new_angular_velocity: Vector3) -> void:
	linear_velocity = new_velocity
	angular_velocity = new_angular_velocity
	sleeping = false

func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	if not _started or freeze:
		return

	var aero_acceleration: Vector3 = BattedBallAerodynamics.acceleration(
		physics_state.linear_velocity,
		physics_state.transform.basis.get_rotation_quaternion(),
		physics_state.angular_velocity,
		mass,
		radius_m,
		aero_drag_coefficient,
		aero_magnus_scale,
		aero_perforation_force_scale,
		hole_axis_ball_local
	)
	physics_state.linear_velocity += aero_acceleration * physics_state.step

func _on_body_entered(body: Node) -> void:
	if not _started:
		return
	var surface_id: StringName = StringName(body.get_meta(
		&"ball_surface",
		&"unknown"
	))
	surface_contact.emit(surface_id, global_position)

func _build_debug_ball() -> void:
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = radius_m
	collision_shape.shape = sphere_shape
	add_child(collision_shape)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.075
	sphere_mesh.height = 0.15
	mesh_instance.mesh = sphere_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.98, 0.96, 0.84)
	material.roughness = 0.78
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.bounce = 0.52
	physics_material.friction = 0.42
	physics_material_override = physics_material
