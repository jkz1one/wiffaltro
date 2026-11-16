extends Node3D
## Compare presentation volumes with the actual joined physics bodies, not their AABBs.

var _failures: int = 0


func _ready() -> void:
	for shape: String in ["straight", "deeper_center", "offset_gables"]:
		var body: StadiumRecipeBoundaryBody = StadiumOffsetBoundaryBody.new() if (
			shape == "offset_gables") else StadiumRecipeBoundaryBody.new()
		add_child(body)
		_check(body.build(shape), "same joined physical faces")
		await get_tree().physics_frame
		await get_tree().physics_frame
		var prisms: StadiumWallViewPrisms = StadiumWallViewPrisms.new(body.graph)
		_check(prisms.walls.size() == body.graph.segments().size(), "no skipped wall volume")
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = 6100519
		var mismatches: int = 0
		for index in range(1200):
			var from: Vector3 = _point(random)
			var to: Vector3 = _point(random)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
			query.hit_from_inside = true
			var hit: bool = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
			var expected: bool = prisms.blocked(from, to, 0)
			if hit != expected:
				mismatches += 1
				print("WALL_PRISM_DIFFERENCE ", shape, " ", from, " -> ", to,
					" physical=", hit, " prism=", expected)
			if not prisms.blocked(to, to, 0):
				_check(not prisms.blocked(to, to, prisms.margin(to)),
					"visibility padding never engulfs a ball outside the actual wall")
		_check(mismatches == 0, "exact prism rays match actual physical joined faces")
		print("WALL_PRISM_RAYS ", shape, " samples=1200 mismatches=", mismatches)
		for row: Dictionary in body.graph.segments():
			var at: Vector2 = (row.a + row.b) / 2
			var normal: Vector2 = body.graph.inward(row)
			var inside: Vector3 = Vector3(at.x + normal.x * 0.15, 0.15, at.y + normal.y * 0.15)
			var outside: Vector3 = Vector3(at.x - normal.x, 0.15, at.y - normal.y)
			_check(prisms.blocked(inside, outside, 0), "real inward face crossing is always blocked")
			_check(not prisms.blocked(inside + Vector3.UP * 8, inside, prisms.margin(inside)),
				"an overhead ray beside an angled face has no invented AABB wall")
		body.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro wall prism checks passed: actual ray parity and safe visibility margins.")
	get_tree().quit(0 if _failures == 0 else 1)


func _point(random: RandomNumberGenerator) -> Vector3:
	return Vector3(random.randf_range(-28, 28), random.randf_range(-1, 7),
		random.randf_range(-8, 32))


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
