extends Node
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	for shape: String in ["straight", "deeper_center"]:
		var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape)
		var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
		check(
			StadiumWaterfallLiveSites.geometry_legal("mogul", graph, field, 0),
			shape + " whole reserve fair and wall-clear, every stock anchor legal"
		)
		check(
			not StadiumWaterfallLiveSites.geometry_legal("club", graph, field, 0),
			shape + " lower property tier refused"
		)
		check(
			not StadiumWaterfallLiveSites.geometry_legal("mogul", graph, field, 1),
			shape + " live companions must explicitly be stored"
		)
		for ends: Array in [
			[Vector3(-16.2, 0, 16.4), Vector3(-4.2, 0, 22.4)],
			[Vector3(-4.2, 0, 22.4), Vector3(-16.2, 0, 16.4)],
			[Vector3(-16.2, 0, 22.4), Vector3(-4.2, 0, 16.4)],
			[Vector3(-4.2, 0, 16.4), Vector3(-16.2, 0, 22.4)],
			[Vector3(-18.2, 0, 19.4), Vector3(-2.2, 0, 19.4)],
			[Vector3(-10.2, 0, 12), Vector3(-10.2, 0, 22.4)]
		]:
			_walk(ends[0], ends[1], graph, [], shape + " full-scale passage " + str(ends))
		var actors: Array = [{"center": Vector3(-15.5, 0, 22), "radius": 0.64}]
		_walk(
			Vector3(-17, 0, 22), Vector3(-4, 0, 22), graph, actors, shape + " occupied rear corner"
		)
		var inside: Vector3 = StadiumWaterfallLiveRoutes.CENTER + Vector3(0, 0, -1.1)
		var approach: Dictionary = StadiumWaterfallLiveRoutes.plan(
			Vector3(-10.2, 0, 12), inside, graph
		)
		check(
			approach.ok and approach.target_blocked and approach.approach_distance > 0.76,
			shape + " basin approach never becomes through-stone pickup"
		)
		check(
			not StadiumWaterfallLiveRoutes.plan(inside, Vector3.ZERO, graph).ok,
			shape + " an illegal start fails closed"
		)
		check(
			not StadiumWaterfallLiveRoutes.clear(
				Vector3(-16.2, 0, 19.4), Vector3(-4.2, 0, 19.4), graph
			),
			shape + " no direct route through actual complete basin"
		)
		check(
			StadiumWaterfallLiveRoutes.legal(Vector3(-10.2, 0, 22), graph),
			shape + " back-wall corridor remains genuinely walkable"
		)
		check(
			(
				not (
					StadiumWaterfallLiveRoutes
					. plan(Vector3(-10.2, 0, 12), Vector3(-10.2, 0, 25), graph)
					. ok
				)
				if shape == "straight"
				else true
			),
			shape + " no forced route through wall"
		)
	var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create("straight")
	check(
		not (
			StadiumWaterfallLiveRoutes
			. plan(Vector3.ZERO, Vector3.ONE, graph, [{"center": Vector3.ZERO, "radius": NAN}])
			. ok
		),
		"malformed actor reservation rejected"
	)
	check(
		not StadiumWaterfallLiveRoutes.step(Vector3.ZERO, Vector3.ONE, -1, graph).ok,
		"negative travel rejected"
	)
	check(
		not StadiumWaterfallLiveRoutes.step(Vector3.ZERO, Vector3.ONE, INF, graph).ok,
		"unbounded travel rejected"
	)
	print(
		(
			"WATERFALL_LIVE_ROUTES_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"production_integration": false,
					"physical_games": 0,
					"native_sphere_collision_proof": false
				}
			)
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _walk(
	start: Vector3, target: Vector3, graph: StadiumRecipeBoundary, actors: Array, label: String
) -> void:
	var initial: Dictionary = StadiumWaterfallLiveRoutes.plan(start, target, graph, actors)
	check(initial.ok, label + " has a current-geometry route")
	if not initial.ok:
		return
	var position: Vector3 = start
	var clear: bool = true
	var moves: int = 0
	for index in range(600):
		if position.distance_to(target) < 0.001:
			break
		var result: Dictionary = StadiumWaterfallLiveRoutes.step(
			position, target, 5.2 / 30.0, graph, actors
		)
		if (
			not result.ok
			or not StadiumWaterfallLiveRoutes.clear(position, result.position, graph, actors)
			or result.position.distance_to(position) > 5.2 / 30.0 + 0.0001
		):
			clear = false
			break
		if result.position.distance_to(position) < 0.00001:
			clear = false
			break
		position = result.position
		moves += 1
	check(clear and moves > 0, label + " every step stays legal with bounded travel")
	check(position.distance_to(target) < 0.001, label + " reaches target without tangent stall")
