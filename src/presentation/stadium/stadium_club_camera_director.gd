class_name StadiumClubCameraDirector
extends MatchCameraDirector
## Candidate-only swept near-volume protection; production camera families remain unchanged.

const SKIN: float = 0.015
var camera_mask: int = StadiumPitchReceiver.LAYER


func update(camera: Camera3D, delta_seconds: float, ball_live: bool,
	ball_position: Vector3) -> void:
	if not is_instance_valid(camera):
		return
	if ball_live and shot == Shot.BALL_IN_PLAY:
		_live_coverage.position_filter = _slide
		super.update(camera, delta_seconds, ball_live, ball_position)
		_live_coverage.position_filter = Callable()
		return
	_live_coverage.position_filter = Callable()
	var previous: Vector3 = camera.global_position
	super.update(camera, delta_seconds, ball_live, ball_position)
	camera.global_position = _slide(camera, previous, camera.global_position)


func snap(camera: Camera3D, ball_position: Vector3 = Vector3.ZERO) -> void:
	super.snap(camera, ball_position)
	if is_instance_valid(camera):
		var focus: Vector3 = camera.global_position - camera.global_basis.z * 10
		camera.global_position = _recover(camera, camera.global_position)
		camera.look_at(focus, camera.global_basis.y)


func _recover(camera: Camera3D, position: Vector3) -> Vector3:
	var query: PhysicsShapeQueryParameters3D = _query(camera)
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	for attempt in range(12):
		query.transform.origin = position
		var contact: Dictionary = space.get_rest_info(query)
		if contact.is_empty():
			return position
		var distance: float = (position - contact.point).dot(contact.normal)
		position += contact.normal * maxf(SKIN, query.shape.radius - distance + SKIN)
	return position


func _query(camera: Camera3D) -> PhysicsShapeQueryParameters3D:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = camera.near * 2 + SKIN
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = camera_mask
	return query


func _slide(camera: Camera3D, from: Vector3, desired: Vector3) -> Vector3:
	var query: PhysicsShapeQueryParameters3D = _query(camera)
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var position: Vector3 = _recover(camera, from)
	var motion: Vector3 = desired - position
	for attempt in range(3):
		if motion.length_squared() < 0.00000001:
			break
		query.transform.origin = position
		query.motion = motion
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions[0] >= 1:
			return position + motion
		position += motion * maxf(0, fractions[0] - 0.001)
		query.transform.origin += motion * fractions[1]
		query.motion = Vector3.ZERO
		query.margin = SKIN
		var contact: Dictionary = space.get_rest_info(query)
		query.margin = 0
		if contact.is_empty():
			break
		motion = (motion * (1 - fractions[0])).slide(contact.normal)
	return position


func prepare_ball_in_play(defense_view: bool, ball_position: Vector3,
	launch_velocity: Vector3 = Vector3.ZERO) -> void:
	super.prepare_ball_in_play(defense_view, ball_position, launch_velocity)
	# A close backward foul needs framing room before its camera reaches the deeper net.
	# The existing exponential zoom eases this lead; movement and turn limits remain intact.
	_live_coverage.framing_lead_degrees = 14 if not defense_view and launch_velocity.z < -1 else 0
