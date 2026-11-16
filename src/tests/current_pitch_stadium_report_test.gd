extends "res://src/tests/physical_report_version_guard_test.gd"
## Finite retained NPC geometry contract test. Synthetic context is not earned qualification.


func _ready() -> void:
	var path: String = "res://src/tests/fixtures/ac02-retained-first-ai-report17.json"
	var historical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(PhysicalMatchReport.valid(historical), "authentic historical NPC report unchanged")
	var catalog: String = WorkingPitchCatalog.signature()
	var context: Dictionary = {"pitch_catalog": catalog, "league_rules": {}, "ownership": []}
	var venue: Dictionary = historical.duplicate(true)
	venue["current_pitch_bound"] = catalog
	var id: String = venue.teams[0].roster[0]
	venue.teams[0].recipes[id].append(WorkingPitchCatalog.new_ids()[0])
	check(CurrentPhysicalStadiumEvidence.valid(venue, context), "current recipe plus full NPC proof")
	check(not CurrentPhysicalStadiumEvidence.valid(venue, {}), "venue cannot self-authorize")
	check(not PhysicalMatchReport.valid(venue), "current component is not an old accepted report")
	var core: Dictionary = CurrentPhysicalStadiumEvidence.core(venue, context)
	var report: Dictionary = {"version": CurrentPhysicalMatchReport.VERSION,
		"resolver": CurrentPhysicalMatchReport.RESOLVER, "pitch_catalog": catalog,
		"league_rules": {}, "ownership": [{}, {}], "dynasty_start": [{}, {}],
		"pair": [{}, {}], "workload": [{}, {}], "uses": [], "physical": core, "venue": venue}
	for index in range(2):
		report.uses.append(core.tactics.teams[index].get("consumed", []))
	check(CurrentPhysicalMatchReport.valid(report, catalog), "Report29 retains matching venue component")
	check(CurrentPhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true)), catalog),
		"full venue JSON roundtrip")
	check(CurrentPhysicalStadiumEvidence.matches(venue, historical.property, context),
		"exact expected venue snapshot")
	var bad: Dictionary = report.duplicate(true)
	bad.venue.surfaces.clear()
	check(not CurrentPhysicalMatchReport.valid(bad, catalog), "surfaces cannot be stripped")
	bad = report.duplicate(true)
	bad.venue.erase("yard")
	check(not CurrentPhysicalMatchReport.valid(bad, catalog), "provenance cannot be stripped")
	bad = report.duplicate(true)
	bad.venue.property.binding.match_seed += 1
	check(not CurrentPhysicalMatchReport.valid(bad, catalog), "fixture seed remains bound")
	bad = report.duplicate(true)
	bad.venue.teams[0].recipes[id].append("pitch.unknown")
	check(not CurrentPhysicalMatchReport.valid(bad, catalog), "venue/core drift is rejected")
	bad = report.duplicate(true)
	bad.venue.version = 15
	check(not CurrentPhysicalMatchReport.valid(bad, catalog), "retired NPC family remains closed")
	var wrong: Dictionary = context.duplicate(true)
	wrong.pitch_catalog += "wrong"
	check(not CurrentPhysicalStadiumEvidence.valid(venue, wrong), "wrong external catalog")
	check(not CurrentPhysicalStadiumEvidence.matches(venue, {}, context), "missing expected source")
	check(PhysicalMatchReport.valid(historical), "historical original untouched")
	print("Current stadium report checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
