extends BattedBallBody
## Instrumentation only: compare exact Jolt contact points with body-entered callback ordering.

var batches: Array[Dictionary] = []
var entered: Array[Dictionary] = []


func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	super._integrate_forces(physics_state)
	if not _started or batches.size() >= 3:
		return
	var contacts: Array[Dictionary] = []
	for index in range(physics_state.get_contact_count()):
		var body: Object = physics_state.get_contact_collider_object(index)
		if body == null:
			continue
		var id: String = body.get_meta("boundary_segment", body.get_meta("ball_surface", ""))
		var point: Vector3 = physics_state.get_contact_collider_position(index)
		contacts.append({"id": id, "point": [point.x, point.y, point.z]})
	if not contacts.is_empty():
		var position: Vector3 = physics_state.transform.origin
		batches.append({"frame": Engine.get_physics_frames(), "contacts": contacts,
			"ball": [position.x, position.y, position.z]})


func _on_body_entered(body: Node) -> void:
	super._on_body_entered(body)
	if _started:
		entered.append({"id": body.get_meta("boundary_segment", body.get_meta("ball_surface", "")),
			"frame": Engine.get_physics_frames()})
