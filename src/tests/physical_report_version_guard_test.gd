extends Node
## Reject malformed version discriminators without changing valid wrapper dispatch.

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var malformed: Array = [null, true, false, "27", "28", "", [], {},
		PackedInt32Array([28]), Vector2(28, 0), NAN, INF, -INF, 27.5, -1, 0, 9999]
	for value: Variant in malformed:
		check(not PhysicalMatchReport.valid({"version": value}), "malformed discriminator")
	for value: Variant in [null, true, "report", [], 28, {}]:
		check(not PhysicalMatchReport.valid(value), "malformed envelope")
	for version: int in [27, 28]:
		var path: String = "res://src/tests/fixtures/report_version_guard/report%d.json" % version
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(PhysicalMatchReport.valid(report), "authentic JSON wrapper %d" % version)
		report.version = version
		check(PhysicalMatchReport.valid(report), "integer wrapper %d" % version)
		report.version = float(version)
		check(PhysicalMatchReport.valid(report), "integral float wrapper %d" % version)
		for bad: Variant in malformed:
			var changed: Dictionary = report.duplicate(true)
			changed.version = bad
			check(not PhysicalMatchReport.valid(changed), "reject mutated wrapper discriminator")
		var tampered: Dictionary = report.duplicate(true)
		tampered.physical.home_runs += 1
		check(not PhysicalMatchReport.valid(tampered), "wrapper body validation preserved")
	print("Physical report version guard checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
