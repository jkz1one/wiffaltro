class_name StadiumPoolWaterTestSupport
extends RefCounted
## Private test assembly only. No production installation or route qualification.


static func ground(parent: Node3D) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PoolRuleTestGround"
	body.position = Vector3(0, -0.08, 12)
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("ball_surface", &"ground")
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(64, 0.16, 54)
	box.margin = 0
	collision.shape = box
	body.add_child(collision)
	parent.add_child(body)
	return body


static func registry(model: Node3D, floor_body: StaticBody3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"body": floor_body, "kind": "ground", "label": "GROUND"}]
	if model != null:
		for body: StaticBody3D in model.get_node("Collision").get_children():
			result.append({"body": body, "kind": "solid", "label": String(body.name)})
	return result


static func model(parent: Node3D, role: String) -> Node3D:
	if role == "NO_POOL":
		return null
	var value: Node3D = StadiumPoolModelsV2.create(role)
	value.transform = StadiumPoolContract.placement()
	parent.add_child(value)
	return value


static func ball(parent: Node3D, position: Vector3) -> BattedBallBody:
	var value: BattedBallBody = BattedBallBody.new()
	value.configure_aero(ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID))
	value.position = position
	parent.add_child(value)
	return value


static func launch(value: BattedBallBody, position: Vector3, velocity: Vector3) -> void:
	var data: BattedBallLaunch = BattedBallLaunch.new()
	data.position = position
	data.velocity = velocity
	data.angular_velocity = Vector3.ZERO
	data.orientation = Quaternion.IDENTITY
	value.launch(data)


static func state_snapshot(value: BallPlayState) -> Dictionary:
	return {
		"dead": value.dead,
		"is_foul_play": value.is_foul_play,
		"is_fair": value.is_fair,
		"floor": value.result_floor,
		"grounded": value.has_grounded,
		"touched": value.defender_touched,
		"caught": value.caught,
		"bobbled": value.bobbled,
		"first_ground_position": value.first_ground_position,
		"last_defender_touch": value.last_defender_touch,
		"last_obstacle_contact": value.last_obstacle_contact,
		"stadium_contacts": value.stadium_contacts.duplicate(true),
		"catch_position": value.catch_position,
		"catch_time": value.catch_time,
		"elapsed_seconds": value.elapsed_seconds
	}
