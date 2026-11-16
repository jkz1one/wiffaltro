extends SceneTree
## Exact structural dispatch only, not full cold season replay qualification.
const Owned = preload("res://src/gameplay/season/league_owned_draft_save.gd")
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _initialize() -> void:
	for versions: Array in [[83, 85], [80, 84], [75, 76, 77], [76, 77, 82], [76, 77, 82, 86]]:
		for version: int in versions:
			var transported: Dictionary = JSON.parse_string(JSON.stringify({"version": version}))
			check(transported.version is float, "real JSON floating numeric fixture")
			check(Owned.version_in(transported.version, versions), "exact JSON version admitted")
			check(Owned.version_in(version, versions), "original integer version retained")
		for invalid: Variant in [null, true, false, "83", 83.5, 85.5, -1, 0, 88, INF, NAN]:
			check(not Owned.version_in(invalid, versions), "malformed or foreign version refused")
	check(not Owned.version_in(83, [83, "85"]), "malformed expected list refuses entirely")
	check(not Owned.version_in(83, [83.0]), "expected list must contain integer literals")
	for outer: int in [81, 83, 85]:
		for middle: int in [78, 80, 84]:
			for inner: int in [76, 77, 82, 86]:
				var raw: Dictionary = {"version": outer, "checkpoint": {"version": middle,
					"checkpoint": {"version": inner, "sentinel": "unchanged"}}}
				var cold: Dictionary = JSON.parse_string(JSON.stringify(raw))
				check(Owned.closed(cold) == cold.checkpoint.checkpoint,
					"exact closed traversal survives all numeric transport layers")
				for depth in range(3):
					for invalid: Variant in [null, true, "83", 83.5, 88, INF, NAN]:
						var bad: Dictionary = cold.duplicate(true)
						var target: Dictionary = bad
						for step in range(depth):
							target = target.checkpoint
						target.version = invalid
						check(Owned.closed(bad).is_empty(), "malformed traversal layer refuses")
	check(Owned.closed({}).is_empty(), "missing version refuses")
	check(Owned.closed({"version": 83.0, "checkpoint": null}).is_empty(),
		"missing nested dictionary refuses")
	print("League save JSON dispatch: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
