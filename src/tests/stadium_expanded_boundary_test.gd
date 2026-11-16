extends "res://src/tests/stadium_recipe_boundary_test.gd"
## Reuse analytical rules against the exact installed graph, plus real joined slab ray casts.


func _ready() -> void:
	var host: Node3D = Node3D.new()
	add_child(host)
	var property: StadiumExpandedProperty = StadiumExpandedVenueStudy.build()
	_check(property != null, "complete candidate supplies boundary test scene")
	if property == null:
		get_tree().quit(1)
		return
	host.add_child(property)
	var boundary: StadiumExpandedBoundary = property.get_node("BoundaryGraph")
	_check(not boundary.build(), "second boundary build rejected")
	_graph(boundary.graph, "deeper_center")
	_rules(boundary.graph)
	_movement(boundary.graph)
	_analytic_sweeps()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	for row: Dictionary in boundary.graph.segments():
		var normal: Vector2 = boundary.graph.inward(row)
		for fraction: float in [0.05, 0.25, 0.5, 0.75, 0.95]:
			var point: Vector2 = row.a.lerp(row.b, fraction)
			var from: Vector3 = Vector3(
				point.x + normal.x * 0.15, row.height / 2, point.y + normal.y * 0.15
			)
			var to: Vector3 = from - Vector3(normal.x, 0, normal.y) * 0.8
			var hit: Dictionary = space.intersect_ray(
				PhysicsRayQueryParameters3D.create(from, to, 1)
			)
			_check(
				not hit.is_empty() and hit.collider.get_meta("boundary_segment", "") == row.id,
				"actual joined collider matches installed mathematical face " + row.id
			)
			from.y = row.height + 0.02
			to.y = from.y
			_check(
				space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty(),
				"actual slab top has no invisible extension " + row.id
			)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	host.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro expanded boundary passed: installed collision, exact rules and swept routes."
		)
	get_tree().quit(0 if _failures == 0 else 1)
