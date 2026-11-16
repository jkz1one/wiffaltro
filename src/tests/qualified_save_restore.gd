extends Node
## Actual frozen legacy and naturally earned current saves; no fixture rewriting.
const INPUTS = preload("res://src/tests/legacy_decode_probe.gd").INPUTS
var checks: int = 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
	return ok


func _ready() -> void:
	var output: String = OS.get_environment("QA_SAVE_OUTPUT")
	if not output.is_absolute_path():
		get_tree().quit(2)
		return
	check(
		StadiumNpcPublicRuntime.source_qualified(), "legitimate installed combined source admitted"
	)
	for index in range(INPUTS.size()):
		var path: String = INPUTS[index]
		var before_hash: String = FileAccess.get_sha256(path)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var season: SeasonState = SeasonSave._decode(data)
		var row: Dictionary = {
			"index": index,
			"path": path,
			"input_sha256": before_hash,
			"version": data.version,
			"decoded": season != null
		}
		rows.append(row)
		if not check(season != null, "actual save%d decodes" % index):
			continue
		check(
			ClubCareer.same(data, SeasonSave.snapshot(season)),
			"save%d complete exact snapshot" % index
		)
		SeasonSave.path = output.path_join("actual-save-%d.json" % index)
		check(
			SeasonSave.save(season) and SeasonSave.save(season),
			"save%d repeated public save" % index
		)
		var cold: SeasonState = SeasonSave.restore()
		check(
			cold != null and ClubCareer.same(data, SeasonSave.snapshot(cold)),
			"save%d durable public reload preserves complete original state" % index
		)
		row["saved_path"] = SeasonSave.path
		row["saved_sha256"] = FileAccess.get_sha256(SeasonSave.path)
		row["pending_human_count"] = season.physical.pending.get("human", []).size()
		row["physical_report_count"] = season.physical.reports.size()
		for kind: String in ["catalog", "event", "cursor", "role", "extra"]:
			var bad: Dictionary = data.duplicate(true)
			var club: Dictionary = bad.opponents.clubs["1"]
			if kind == "catalog":
				club.build.catalog = "x" + club.build.catalog.substr(1)
			elif kind == "event":
				if club.build.events.is_empty():
					club.build.events.append({"rev": 999, "op": "fabricated"})
				else:
					club.build.events[0].rev = 999
			elif kind == "cursor":
				club.cursor += 1
			elif kind == "role":
				club.roles["unknown"] = "fabricated"
			else:
				club["extra"] = true
			check(
				SeasonSave._decode(bad) == null, "save%d opponent %s tamper refuses" % [index, kind]
			)
		if not data.physical.reports.is_empty():
			var bad: Dictionary = data.duplicate(true)
			bad.physical.reports[0].report.erase("plays")
			check(SeasonSave._decode(bad) == null, "save%d stripped physical plays refuses" % index)
		elif not data.physical.pending.is_empty() and data.physical.pending.human.size() == 17:
			var bad: Dictionary = data.duplicate(true)
			bad.physical.pending.human[16].erase("property")
			check(
				SeasonSave._decode(bad) == null,
				"save%d stripped pending human property refuses" % index
			)
		check(FileAccess.get_sha256(path) == before_hash, "save%d original bytes untouched" % index)
	var f: FileAccess = FileAccess.open(output.path_join("restore-summary.json"), FileAccess.WRITE)
	if f == null:
		get_tree().quit(2)
		return
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "saves": rows}))
	f.close()
	print(
		"QUALIFIED_SAVE_RESTORE checks=",
		checks,
		" failures=",
		failures.size(),
		" saves=",
		rows.size()
	)
	get_tree().quit(0 if failures.is_empty() else 1)
