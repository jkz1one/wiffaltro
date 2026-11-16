extends Node3D
## Candidate geometry and real sphere clearance; not proof of complete replaced-side gameplay.

var _failures: int = 0


func _ready() -> void:
	for left in [false, true]:
		var pose: Transform3D = StadiumDugoutRecipe.placement(left)
		_check(is_equal_approx(pose.basis.determinant(), 1)
			and pose.basis.get_scale().is_equal_approx(Vector3.ONE), "handed frame has positive unit scale")
		_check((pose * Vector3(0, 0, 1)).distance_to(
			StadiumDugoutRecipe.rail_point(13, 1, left)) < 0.00001, "local depth points outside play")
		_check(StadiumDugoutRecipe.panels(left).size() == 16
			and StadiumWallRecipes.side(left).size() == 19, "exact three cells displaced, old recipe frozen")
		_check(not StadiumDugoutRecipe.fits(left, "backyard")
			and StadiumDugoutRecipe.fits(left, "expanded"), "authored concrete property gate is explicit")
		var model: Node3D = StadiumConcreteDugoutModels.create()
		add_child(model)
		model.transform = pose
		for mesh: MeshInstance3D in model.get_node("Visual").get_children():
			for index in range(8):
				_check(StadiumDugoutRecipe.ENVELOPE.grow(0.00001).has_point(
					mesh.transform * mesh.get_aabb().get_endpoint(index)), "complete mesh stays in CI envelope")
		await get_tree().physics_frame
		await get_tree().physics_frame
		var paths: Array = [[Vector3(0, 0.5, -0.5), false],
			[Vector3(0.95, 0.5, -0.5), false], [Vector3(0.98, 0.5, -0.5), true],
			[Vector3(-0.98, 0.5, -0.5), true], [Vector3(0, 2.38, -0.5), true],
			[Vector3(0, 2.35, -0.5), false], [Vector3(2, 0.5, -0.5), true]]
		for path: Array in paths:
			var from: Vector3 = path[0]
			_check(_blocked(pose * from, pose * (from + Vector3(0, 0, 1))) == path[1],
				"physical sphere respects open aperture, jamb and roof clearance: " + str(from))
		_check(await StadiumAssetCapture.save(self, pose * StadiumDugoutRecipe.ENVELOPE,
			"ST-074-" + ("left" if left else "right"), pose.basis * Vector3(1, 0.65, -1)),
			"native handed dugout preview saved")
		model.queue_free()
		await get_tree().physics_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro dugout models passed: handed CI envelopes, cells and aperture.")
	get_tree().quit(0 if _failures == 0 else 1)


func _blocked(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = 0.0365
	query.shape.margin = 0
	query.margin = 0
	query.transform.origin = from
	query.motion = to - from
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	return not space.intersect_shape(query, 1).is_empty() or space.cast_motion(query)[0] < 1


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
