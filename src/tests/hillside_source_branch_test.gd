extends Node
const S = preload("res://src/tests/hillside_source_branch_shadow.gd")
var checks: int = 0
var failures: int = 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("BRANCH ", label, " ", value)


func reset() -> void:
	S.pins = S.D.model_pins()
	S.observed = {}
	for key in S.SOURCE_PATHS:
		S.observed[S.SOURCE_PATHS[key]] = S.pins[key].sha256
	S.qualifier_calls = 0
	S.qualification = true


func _ready() -> void:
	reset()
	check(
		S.sources_valid() and S.qualifier_calls == 0,
		"historical exact bypasses successor qualifier"
	)
	for key in S.RETAINED_SOURCE_SUCCESSORS:
		reset()
		S.observed[S.SOURCE_PATHS[key]] = S.RETAINED_SOURCE_SUCCESSORS[key].current
		check(S.sources_valid() and S.qualifier_calls == 1, "explicit successor " + key)
		S.qualifier_calls = 0
		S.qualification = false
		check(not S.sources_valid() and S.qualifier_calls == 1, "successor requires profile " + key)
		S.pins[key].sha256 = "bad-retained-pin"
		S.qualifier_calls = 0
		check(not S.sources_valid() and S.qualifier_calls == 0, "wrong retained pin " + key)
		reset()
		S.observed[S.SOURCE_PATHS[key]] = "unknown-current-hash"
		check(not S.sources_valid() and S.qualifier_calls == 0, "wrong successor hash " + key)
	reset()
	S.observed[S.SOURCE_PATHS["terrain-ground-contact"]] = "unlisted-successor"
	check(not S.sources_valid() and S.qualifier_calls == 0, "unlisted change")
	reset()
	S.observed.erase(S.SOURCE_PATHS["actual-ball-body"])
	check(not S.sources_valid() and S.qualifier_calls == 0, "missing file")
	print("HILLSIDE_SOURCE_BRANCH checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
