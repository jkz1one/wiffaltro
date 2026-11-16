extends Node
## Exact comparison regression using retained genuine operands. No games/writes/admission.
const Replay = preload("res://src/gameplay/season/dynasty_standard_replay.gd")
const Legacy = preload("res://src/gameplay/season/dynasty_owner.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var input: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--transition-operands="):
			input = arg.trim_prefix("--transition-operands=")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(input)) if input.is_absolute_path() else null
	if not value is Dictionary or not value.get("human") is Array or not value.get("result") is Dictionary:
		get_tree().quit(2)
		return
	var human: Array = value.human
	var result: Dictionary = value.result
	check(human.size() == 17 and result.has("yard_evidence"), "retained NPC17 operands")
	check(not Legacy._human_matches(human, result), "old closed grammar remains unchanged")
	check(Legacy._human_matches(human.slice(0, 13), result), "genuine common prefix")
	check(Replay._human_matches(human, result), "exact Standard17 continuation identity")
	for index in range(17):
		var bad: Array = human.duplicate(true)
		if bad[index] is Array:
			bad[index].append("changed")
		elif bad[index] is Dictionary:
			bad[index]["changed"] = true
		elif bad[index] == null:
			bad[index] = {}
		elif bad[index] is String:
			bad[index] += "changed"
		else:
			bad[index] += 1
		check(not Replay._human_matches(bad, result), "changed human operand%d refused" % index)
	for field: String in ["property", "yard_evidence", "id"]:
		var bad: Dictionary = result.duplicate(true)
		bad.erase(field)
		check(not Replay._human_matches(human, bad), "missing exact result " + field)
	for field: String in ["pool_evidence", "doubleheader_evidence", "inventory_final", "night_evidence"]:
		var bad: Dictionary = result.duplicate(true)
		bad[field] = {}
		check(not Replay._human_matches(human, bad), "no mixed result grammar " + field)
	var property_result: Dictionary = result.duplicate(true)
	property_result.erase("yard_evidence")
	check(Replay._human_matches(human.slice(0, 15), property_result), "property15 comparison unit")
	var pool: Array = human.slice(0, 15)
	pool.append({"comparison_unit_only": true})
	property_result.pool_evidence = pool[15].duplicate(true)
	check(Replay._human_matches(pool, property_result), "pool16 comparison unit, not evidence admission")
	property_result.pool_evidence.comparison_unit_only = false
	check(not Replay._human_matches(pool, property_result), "pool16 exact evidence retained")
	var report: Dictionary = {"fixture": 1, "request": "comparison-only", "report": {}}
	var before: Dictionary = {"results": [], "physical": {"reports": [], "pending": {"human": human, "reports": [report]}}}
	var after: Dictionary = {"results": [result], "physical": {"reports": [report.duplicate(true)], "pending": {}}}
	check(Replay._pending_extends(before, after), "Standard settlement compares human and retained AI prefix")
	after.physical.reports[0].request = "changed"
	check(not Replay._pending_extends(before, after), "AI prefix replacement refused")
	after.physical.reports = []
	check(not Replay._pending_extends(before, after), "AI prefix removal refused")
	after.physical.reports = [report.duplicate(true)]
	after.results = []
	check(not Replay._pending_extends(before, after), "human result cannot disappear")
	print("STANDARD_TRANSITION checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
