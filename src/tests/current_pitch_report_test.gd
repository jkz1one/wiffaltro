extends "res://src/tests/physical_report_version_guard_test.gd"
## Finite synthetic contract checks; not gameplay, earning or publication qualification.


func _ready() -> void:
	var catalog: String = WorkingPitchCatalog.signature()
	for version: int in [27, 28]:
		var path: String = "res://src/tests/fixtures/report_version_guard/report%d.json" % version
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(PhysicalMatchReport.valid(old), "unchanged authentic historical report")
		var current: Dictionary = _fixture(old, catalog)
		check(CurrentPhysicalMatchReport.valid(current, catalog), "current exact-catalog wrapper")
		check(not CurrentPhysicalMatchReport.valid(current), "self-reported catalog is not authority")
		check(not CurrentPhysicalMatchReport.valid(current, catalog + "wrong"), "wrong exact catalog")
		check(not PhysicalMatchReport.valid(current), "legacy dispatch stays closed")
		check(not PhysicalMatchReport.valid(current.physical), "bound core cannot be stripped")
		check(CurrentPhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(current, "", true, true)), catalog),
			"current JSON roundtrip")
		var id: String = current.physical.teams[0].roster[0]
		current.physical.teams[0].recipes[id].append(WorkingPitchCatalog.new_ids()[0])
		check(CurrentPhysicalMatchReport.valid(current, catalog), "current new recipe in full roster")
		var row: Dictionary = {"fixture": 0, "request": "a".repeat(64), "report": current}
		check(SeasonPhysicalFixtures.envelope(row, catalog), "explicit current archive admission")
		check(not SeasonPhysicalFixtures.envelope(row), "old archive cannot admit new wrapper")
		check(SeasonPhysicalFixtures.from_data({"version": 1, "reports": [row], "pending": {}},
			catalog) != null, "archive decode preserves current evidence")
		check(SeasonPhysicalFixtures.from_data({"version": 1, "reports": [row], "pending": {}})
			== null, "archive requires outer validated identity")
		var bad: Dictionary = current.duplicate(true)
		bad.pitch_catalog = "wrong"
		check(not CurrentPhysicalMatchReport.valid(bad, catalog), "outer catalog mismatch")
		bad = current.duplicate(true)
		bad.physical.current_pitch_bound = "wrong"
		check(not CurrentPhysicalMatchReport.valid(bad, catalog), "inner catalog mismatch")
		bad = current.duplicate(true)
		bad.physical.erase("current_pitch_bound")
		check(not CurrentPhysicalMatchReport.valid(bad, catalog), "marker removal rejected")
		bad = current.duplicate(true)
		bad.version = version
		check(not PhysicalMatchReport.valid(bad), "relabeling cannot remove current contract")
		# Deliberately stripping ALL new fields may leave a legacy-shaped body. Legacy
		# shape is not authority: current archive and request/source routes reject it.
		check(not PhysicalMatchReport.accepted(old, catalog), "old proof cannot publish current source")
		check(not CurrentPhysicalMatchReport.matches(current, null), "no source is not authority")
		if version == 28:
			bad = current.duplicate(true)
			bad.workload[0].remaining[id] += 1.0
			check(not CurrentPhysicalMatchReport.valid(bad, catalog), "full workload retained")
		check(PhysicalMatchReport.valid(old), "historical original remains unchanged")
	print("Current pitch report checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _fixture(old: Dictionary, catalog: String) -> Dictionary:
	var result: Dictionary = {"version": CurrentPhysicalMatchReport.VERSION,
		"resolver": CurrentPhysicalMatchReport.RESOLVER, "pitch_catalog": catalog,
		"league_rules": old.league_rules.duplicate(true), "ownership": old.ownership.duplicate(true),
		"physical": old.physical.duplicate(true), "dynasty_start": old.get("dynasty_start", [{}, {}]),
		"pair": old.get("pair", [{}, {}]), "workload": old.get("workload", [{}, {}]), "uses": []}
	result.physical["current_pitch_bound"] = catalog
	for index in range(2):
		result.uses.append(old.get("uses", [[], []])[index] if old.version == 28 else
			old.physical.tactics.teams[index].get("consumed", []))
	return result
