extends Node
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	var layout: Dictionary = {
		"version": 23, "family": StadiumBoundaryItems.FAMILY, "boundary": [], "walls": {"back": {}}
	}
	for profile: String in StadiumLowWallRecipes.PROFILES:
		var graph: StadiumLowWallGraph = StadiumLowWallGraph.create_low(layout, profile)
		check(graph != null, "graph creates " + profile)
		check(graph.segments().size() == graph.polygon().size(), "exact indexed graph polygon")
		var rows: Array[Dictionary] = StadiumLowWallRecipes.rows(profile, "ST-024")
		check(rows.size() == 23, "complete 23 sockets")
		var counts: Dictionary = StadiumLowWallRecipes.requirements(profile, "ST-024")
		check(counts.low == (16 if profile == "low_flanks" else 23), "exact distinct low count")
		for row: Dictionary in rows:
			check(is_equal_approx(row.width, row.a.distance_to(row.b)), "exact panel span")
			var model: Node3D = StadiumLowWallModels.create(row)
			check(
				(
					model != null
					and model.find_children("*", "CollisionShape3D", true, false).is_empty()
				),
				"art has no second collision authority"
			)
			model.free()
		for x: float in [-17, 0, 17]:
			var cap: float = 3.25 if profile == "low_flanks" and x == 0 else 1.625
			var below: Dictionary = graph.crossing(
				Vector3(x, cap - 0.01, 23), Vector3(x, cap - 0.01, 24)
			)
			var above: Dictionary = graph.crossing(
				Vector3(x, cap + 0.1, 23), Vector3(x, cap + 0.1, 24)
			)
			check(below.get("role") == "BACK_WALL_TERMINAL", "below selected cap not clear")
			check(above.get("role") == "BACK_CLEAR", "above selected cap graph candidate")
	print(
		(
			"LOW_WALL_FOUNDATION "
			+ JSON.stringify({"checks": checks, "failures": failures, "runtime_qualified": false})
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)
