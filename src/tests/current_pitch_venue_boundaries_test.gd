extends "res://src/tests/physical_report_version_guard_test.gd"
## Cold synthetic current-context tests, not completed current gameplay or paid-owner proof.
const PoolFixture = preload("res://src/tests/pool_party_public_fixture.gd")
const NightResult = preload("res://src/gameplay/season/league_home_night_result.gd")


func _ready() -> void:
	var catalog: String = WorkingPitchCatalog.signature()
	var context: Dictionary = {"pitch_catalog": catalog, "league_rules": {}, "ownership": []}
	for name_value: String in ["owned9", "time25"]:
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://src/tests/fixtures/current_pitch_venues/" + name_value + ".json"))
		check(PhysicalMatchReport.valid(old), "byte-preserved historical " + name_value)
		var venue: Dictionary = old.duplicate(true)
		venue["current_pitch_bound"] = catalog
		_check_wrapper(venue, context, name_value)
		var missing: Dictionary = venue.duplicate(true)
		missing.erase("surfaces")
		check(not CurrentPhysicalStadiumEvidence.valid(missing, context), "surface proof required")
		if name_value == "time25":
			for key: String in ["clock", "night", "property"]:
				missing = venue.duplicate(true)
				missing.erase(key)
				check(not CurrentPhysicalStadiumEvidence.valid(missing, context), key + " cannot be stripped")
	_pool_party(context)
	var fixture: Dictionary = {"id": 3, "round": 1, "away": 1, "home": 0}
	var result: Dictionary = fixture.duplicate(true)
	result["pitching_current"] = {} # This helper checks keys; called-proof semantics are separate.
	check(NightResult.result_keys_valid(result, fixture, false, false, true, catalog),
		"exact current time94 result permits its called-proof field")
	check(not NightResult.result_keys_valid(result, fixture, false, false, true),
		"historical time94 grammar does not gain a current field")
	check(not NightResult.result_keys_valid(result, fixture, false, false, true, "wrong"),
		"wrong catalog cannot widen time94 keys")
	print("Current venue boundary checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _pool_party(context: Dictionary) -> void:
	# Construct a deliberately synthetic no-terminal-contact geometry fixture from
	# balanced retained baseball operands. This is not a historical/current game report.
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/tests/fixtures/ac02-retained-first-ai-report17.json"))
	var season: SeasonState = PoolFixture.season()
	check(season != null, "synthetic Pool Party source setup")
	if season == null:
		return
	var fixture: Dictionary = PoolFixture.fixture(season)
	var snapshot: Dictionary = SeasonFinalVenue.for_fixture(season, fixture)
	check(not snapshot.is_empty(), "explicit qualification Pool Party snapshot")
	if snapshot.is_empty():
		return
	var venue: Dictionary = StadiumNpcYardTwoReport._core(old)
	venue.version = StadiumPoolPartyPublicReport.VERSION
	venue.resolver = StadiumPoolPartyPublicReport.RESOLVER
	venue.field = StadiumNpcSnapshot.FIELD
	venue.seed = snapshot.binding.match_seed
	venue["current_pitch_bound"] = context.pitch_catalog
	venue["property"] = snapshot
	venue["surfaces"] = []
	venue["yard"] = []
	for index in range(venue.plays.size()):
		check(venue.plays[index].result not in ["triple", "home_run"], "no required terminal fixture")
		venue.surfaces.append({"play": index, "reason": "synthetic_no_terminal", "events": []})
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	venue["pool"] = {"version": 1, "copy": StadiumPoolPartyPublicContacts.COPY,
		"pose": [12, 0, 18, 0], "geometry": StadiumPoolPartyPublicContacts.geometry(source),
		"source_sha256": source, "water_commits": [], "water_outcomes": []}
	_check_wrapper(venue, context, "synthetic PoolParty22")
	# The native default JSON writer truncates these authored polygon coordinates.
	# Production capture, worker transport and saves all use full precision instead.
	var lossy: Dictionary = JSON.parse_string(JSON.stringify(venue))
	check(not StadiumPoolPartyPublicContacts._geometry_matches(lossy.pool.geometry, source),
		"default-precision PoolParty geometry remains rejected")
	check(not CurrentPhysicalStadiumEvidence.valid(lossy, context),
		"default-precision PoolParty component remains rejected")
	var tampered: Dictionary = JSON.parse_string(JSON.stringify(venue, "", true, true))
	tampered.pool.geometry.vertices_xz[0][0] += 0.0001
	check(not CurrentPhysicalStadiumEvidence.valid(tampered, context),
		"full-precision PoolParty vertex tampering remains rejected")
	var core: Dictionary = CurrentPhysicalStadiumEvidence.core(venue, context)
	check(not core.is_empty() and not core.has("pool") and venue.has("pool"),
		"PoolParty22 canonical core excludes pool without dropping component proof")


func _check_wrapper(venue: Dictionary, context: Dictionary, label: String) -> void:
	check(CurrentPhysicalStadiumEvidence.valid(venue, context), label + " contextual geometry")
	var core: Dictionary = CurrentPhysicalStadiumEvidence.core(venue, context)
	if core.is_empty():
		return
	var report: Dictionary = {"version": 29, "resolver": CurrentPhysicalMatchReport.RESOLVER,
		"pitch_catalog": context.pitch_catalog, "league_rules": {}, "ownership": [{}, {}],
		"dynasty_start": [{}, {}], "pair": [{}, {}], "workload": [{}, {}], "uses": [],
		"physical": core, "venue": venue}
	for index in range(2):
		report.uses.append(core.tactics.teams[index].get("consumed", []))
	check(CurrentPhysicalMatchReport.valid(report, context.pitch_catalog), label + " Report29 wrapper")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(report, "", true, true))
	check(CurrentPhysicalStadiumEvidence.valid(decoded.venue, context),
		label + " full-precision component JSON roundtrip")
	check(CurrentPhysicalMatchReport.valid(decoded, context.pitch_catalog),
		label + " full-precision JSON roundtrip")
	check(ClubCareer.same(report, decoded), label + " full venue evidence preserved")
	if venue.version == StadiumPoolPartyPublicReport.VERSION:
		check(not CurrentPhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report)),
			context.pitch_catalog), label + " default-precision report remains rejected")
