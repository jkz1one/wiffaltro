extends Node3D
## Corrected field-facing cup and bounded flex; called-pitch cleanup qualification is separate.

var _failures: int = 0


func _ready() -> void:
	var net: Node3D = StadiumReceiverNetModels.create()
	add_child(net)
	var center: Array = StadiumReceiverNetModels.PANELS.ST073_CENTER_NET
	var wing: Array = StadiumReceiverNetModels.PANELS.ST073_NET_R
	_check(center[0].y < wing[1].y and wing[1].y < StadiumTargetModels.POSITION.z,
		"net center is behind the wings and target: cup opens toward the field")
	var poses: Array[Transform3D] = []
	var shapes: Array[RID] = []
	for body: StaticBody3D in net.get_node("Collision").get_children():
		_check(body.get_meta("surface_role") == "RECEIVER_CONTAINMENT_FOUL",
			"all named physical members have terminal receiver identity")
		poses.append(body.transform)
		shapes.append(body.get_child(0).shape.get_rid())
	_check(StadiumReceiverNetModels.GRID < 0.073, "rendered openings stay smaller than the ball")
	for id: String in StadiumReceiverNetModels.PANELS:
		var panel: MeshInstance3D = net.get_node("Visual/" + id)
		var impact: Vector3 = panel.transform * Vector3(0, 3.375, 0)
		for elapsed: float in [0.0, 0.1375, 0.275, 0.55, 1.0]:
			_check(StadiumReceiverNetModels.flex(net, id, elapsed, impact), "known panel can flex")
			var vertices: PackedVector3Array = panel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var minimum: float = 0
			for point: Vector3 in vertices:
				minimum = minf(minimum, point.z)
				_check(point.z >= -0.250001 and point.z <= 0.000001,
					"visual motion stays inside rearward quarter-meter envelope")
				_check(StadiumReceiverNetModels.ENVELOPE.grow(0.0001).has_point(panel.transform * point),
					"deformed net fits its complete authored bound")
			if elapsed == 0.275:
				_check(minimum < -0.24, "center visibly flexes at peak")
			if elapsed >= 0.55:
				_check(absf(minimum) < 0.00001, "net settles by 0.55 seconds")
	var index: int = 0
	for body: StaticBody3D in net.get_node("Collision").get_children():
		_check(body.transform == poses[index] and body.get_child(0).shape.get_rid() == shapes[index],
			"ripple never moves, replaces or duplicates physical catching surfaces")
		index += 1
	for mesh: MeshInstance3D in net.get_node("Visual").get_children():
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point: Vector3 in vertices:
			_check(StadiumReceiverNetModels.ENVELOPE.grow(0.0001).has_point(mesh.transform * point),
				"poles, lines, anchors and net fit the complete bound")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ray(Vector3(0, 2, -2), Vector3(0, 2, -5), "ST073_CENTER_NET")
	_ray(Vector3(3, 2, -2), Vector3(3, 2, -4), "ST073_NET_R")
	_ray(Vector3(-3, 2, -2), Vector3(-3, 2, -4), "ST073_NET_L")
	_ray(Vector3(0, 7, -2), Vector3(0, 7, -5), "")
	_ray(Vector3(0, 0.10, -2), Vector3(0, 0.10, -5), "")
	_check(not StadiumReceiverNetModels.flex(net, "ST025_NET", 0.2, Vector3.ZERO),
		"portable-net surfaces cannot impersonate a stadium-net panel")
	var target: Node3D = StadiumTargetModels.create()
	target.position = StadiumTargetModels.POSITION
	add_child(target)
	_check(await StadiumAssetCapture.save(self,
		AABB(Vector3(-5.1, 0, -5.15), Vector3(10.2, 6.9, 5)), "ST-073-target-pair"),
		"native stadium receiver pair preview saved")
	_check(await StadiumAssetCapture.save(self,
		AABB(Vector3(-5.1, 0, -5.15), Vector3(10.2, 6.9, 5)),
		"ST-073-orientation", Vector3(0, 1, 0.1)), "overhead target/net orientation preview saved")
	net.queue_free()
	target.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium net models passed: field-facing cup, fixed collision and bounded flex.")
	get_tree().quit(0 if _failures == 0 else 1)


func _ray(from: Vector3, to: Vector3, expected: String) -> void:
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1))
	_check((hit.is_empty() and expected.is_empty()) or (not hit.is_empty()
		and hit.collider.get_meta("surface_id", "") == expected), "physical catch surface: " + expected)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
