class_name StadiumPoolTelemetryBody
extends BattedBallBody
## Test-only observation wrapper. It never writes direct state or changes integration.

signal integration_observed(phase: String, sample: Dictionary)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var observe: bool = _started and not freeze
	if observe:
		integration_observed.emit("before_super", _sample(state))
	super._integrate_forces(state)
	if observe:
		integration_observed.emit("after_super", _sample(state))


static func _sample(state: PhysicsDirectBodyState3D) -> Dictionary:
	var contacts: Array[Dictionary] = []
	for index: int in range(state.get_contact_count()):
		contacts.append(
			{
				"collider_instance": state.get_contact_collider_id(index),
				"collider_rid": state.get_contact_collider(index).get_id(),
				"local_position": state.get_contact_local_position(index),
				"collider_position": state.get_contact_collider_position(index),
				"local_normal": state.get_contact_local_normal(index),
				"impulse": state.get_contact_impulse(index),
				"local_velocity_at_position": state.get_contact_local_velocity_at_position(index),
				"collider_velocity_at_position":
				state.get_contact_collider_velocity_at_position(index),
				"local_shape": state.get_contact_local_shape(index),
				"collider_shape": state.get_contact_collider_shape(index)
			}
		)
	return {
		"physics_frame": Engine.get_physics_frames(),
		"step": state.step,
		"transform": state.transform,
		"linear_velocity": state.linear_velocity,
		"angular_velocity": state.angular_velocity,
		"total_gravity": state.total_gravity,
		"total_linear_damp": state.total_linear_damp,
		"total_angular_damp": state.total_angular_damp,
		"sleeping": state.sleeping,
		"contact_count": state.get_contact_count(),
		"contacts": contacts,
		"snapshot_kind": "DIRECT_STATE_AT_SCRIPT_INTEGRATION_CALLBACK",
		"contact_toi_available": false,
		"reflected_subsegments_available": false
	}
