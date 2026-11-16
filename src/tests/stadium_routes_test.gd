extends Node3D
## Deterministic travel/occlusion tests against actual starter placements.

var _failures: int = 0


func _ready() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.obstacles = [{"copy": "starter-v1:ST-003", "site": "O-L1", "yaw": 90}]
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", layout, stock), "placed chair route geometry")
	await get_tree().physics_frame
	var obstacles: Array[Dictionary] = property.route_obstacles()
	var center: Vector3 = obstacles[0].center
	for axis: Vector3 in [Vector3.RIGHT, Vector3.FORWARD, Vector3(1, 0, 1).normalized()]:
		for speed: float in [3.8, 5.2]:
			var start: Vector3 = center - axis * 3
			var goal: Vector3 = center + axis * 3
			var current: Vector3 = start
			for frame in range(240):
				var next: Vector3 = StadiumDefenderRoutes.step(current, goal, speed / 60, obstacles)
				_check(StadiumDefenderRoutes.clear(current, next, obstacles), "no swept route penetration")
				_check(next.distance_to(current) <= speed / 60 + 0.00001, "speed budget preserved")
				current = next
			_check(current.distance_to(goal) < 0.06, "route reaches opposite side without oscillating")
	var start: Vector3 = center + Vector3(-3, 0, 0)
	var far: Vector3 = center + Vector3(3, 0, 0)
	var clipped: Vector3 = StadiumDefenderRoutes.clip(start, far, obstacles)
	_check(StadiumDefenderRoutes.clear(start, clipped, obstacles)
		and is_equal_approx(clipped.z, start.z), "forced first step clips rather than steering")
	var large: Vector3 = StadiumDefenderRoutes.step(start, far, 10, obstacles)
	_check(StadiumDefenderRoutes.clear(start, large, obstacles), "large delta cannot tunnel")
	var near: Vector3 = start
	for frame in range(120):
		near = StadiumDefenderRoutes.step(near, center, 0.1, obstacles)
	_check(near.distance_to(center) >= obstacles[0].radius
		and near.distance_to(center) < obstacles[0].radius + 0.05,
		"target inside a prop remains approached from outside its body clearance")
	var fielder: FielderController = FielderController.new()
	add_child(fielder)
	fielder.set_physics_process(false)
	fielder.stadium_obstacles = obstacles
	fielder.set_anchor(start)
	fielder.reaction_delay_seconds = 0
	fielder.begin_play()
	fielder.target_position = far
	for frame in range(240):
		var previous: Vector3 = fielder.global_position
		fielder._physics_process(1.0 / 60.0)
		_check(StadiumDefenderRoutes.clear(previous, fielder.global_position, obstacles),
			"actual fielder controller obeys placed-chair route")
	_check(fielder.global_position.distance_to(far) < 0.06, "actual controller reaches other side")
	fielder.end_play()
	fielder.begin_play(false, Vector3.RIGHT)
	FielderFirstStep.advance(fielder, Vector3.RIGHT, 2.0)
	_check(StadiumDefenderRoutes.clear(start, fielder.global_position, obstacles)
		and is_equal_approx(fielder.global_position.z, start.z),
		"actual forced first-step controller clips at authored route boundary")
	fielder.queue_free()
	property.queue_free()
	await get_tree().process_frame
	await _occlusion(layout, stock)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium route checks passed: swept clearance, real controller and occlusion.")
	get_tree().quit(0 if _failures == 0 else 1)


func _occlusion(layout: Dictionary, stock: StadiumStock) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	await get_tree().process_frame
	_check(StadiumPropertyRuntime.install_lab(lab, layout, stock), "isolated runtime routes installed")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var center: Vector3 = StadiumStarterLayout.SITES["O-L1"]
	lab._primary_fielder.global_position = center + Vector3(1, 0, 0)
	_check(not StadiumPropertyRuntime.clear_control(lab, lab._primary_fielder,
		center + Vector3(-1, 0.7, 0)), "actual rotated chair blocks control through its back")
	_check(StadiumPropertyRuntime.clear_control(lab, lab._primary_fielder,
		center + Vector3(-1, 1.2, 0)), "ball above chair can still be controlled")
	var next: Vector3 = StadiumPropertyRuntime.pitcher_step(lab,
		center + Vector3(-1, 0, 0), 0.1, Vector3.ZERO)
	_check(next != Vector3.ZERO, "installed property routes pitcher instead of supplied legacy step")
	lab.queue_free()
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
