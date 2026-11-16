class_name StadiumNpcBasePublicChecks
extends RefCounted
## Focused checks called by one real managed fixture; no simulated terminal evidence.


static func terminal(lab: PitchBatLab, season: SeasonState) -> Dictionary:
	var errors: Array[String] = []
	var fixture: Dictionary = season.pending_fixture()
	var expected: Dictionary = SeasonVenues.for_fixture(season, fixture)
	var human: Dictionary = StadiumNpcYardTwoHumanEvidence.capture(lab, season)
	var report: Dictionary = PhysicalMatchReport.capture(lab)
	if human.is_empty() or not StadiumNpcYardTwoHumanEvidence.valid(human):
		errors.append("actual managed human terminal evidence")
	if report.is_empty() or not PhysicalMatchReport.valid(report) \
		or not StadiumNpcPublicReport.matches(report, expected):
		errors.append("actual managed automated report17")
	if not errors.is_empty():
		return {"errors": errors, "human": human, "report": report}
	var decoded: Variant = JSON.parse_string(JSON.stringify(report, "", true, true))
	if not PhysicalMatchReport.valid(decoded) or not ClubCareer.same(report, decoded):
		errors.append("report17 JSON reload")
	decoded = JSON.parse_string(JSON.stringify(human, "", true, true))
	if not StadiumNpcYardTwoHumanEvidence.valid(decoded) or not ClubCareer.same(human, decoded):
		errors.append("human evidence JSON reload")
	var bad: Dictionary = report.duplicate(true)
	bad.seed = (int(bad.seed) + 1) & 0x7fffffff
	if PhysicalMatchReport.valid(bad):
		errors.append("wrong report seed accepted")
	bad = report.duplicate(true)
	bad.property.binding.venue_id = "AY-03"
	if PhysicalMatchReport.valid(bad):
		errors.append("wrong venue accepted")
	bad = report.duplicate(true)
	bad.property.binding.environment_seed = (
		(int(bad.property.binding.environment_seed) + 1) & 0x7fffffff)
	if PhysicalMatchReport.valid(bad):
		errors.append("wrong saved environment seed accepted")
	bad = report.duplicate(true)
	bad.property.binding.erase("assignment_version")
	if PhysicalMatchReport.valid(bad):
		errors.append("missing assignment3 binding accepted")
	bad = expected.duplicate(true)
	bad.binding.fixture = (int(bad.binding.fixture) + 1) % 30
	bad.environment.fixture = bad.binding.fixture
	if StadiumNpcPublicReport.matches(report, bad):
		errors.append("wrong expected fixture accepted")
	bad = report.duplicate(true)
	bad.yard.append({"instance": "npc:AY-01:r1:forged", "surface": "CONE_BODY",
		"preterminal": true, "elapsed": 1.0})
	if PhysicalMatchReport.valid(bad):
		errors.append("foreign provenance accepted")
	bad = report.duplicate(true)
	bad.surfaces.pop_back()
	if PhysicalMatchReport.valid(bad):
		errors.append("missing play contacts accepted")
	bad = StadiumNpcPublicReport.core(report)
	bad.field = StadiumNpcSnapshot.FIELD
	if PhysicalMatchReport.valid(bad):
		errors.append("bare NPC report7 accepted")
	bad = human.duplicate(true)
	bad.request = "0".repeat(64)
	if StadiumNpcYardTwoHumanEvidence.accepts(season, fixture, bad,
		human.away_runs, human.home_runs, human.performance, {"base": human.base}):
		errors.append("wrong human request accepted")
	bad = human.duplicate(true)
	bad.fixture = (int(bad.fixture) + 1) % 30
	if StadiumNpcYardTwoHumanEvidence.valid(bad):
		errors.append("wrong human fixture accepted")
	if not StadiumPoolOwnedReport._source_hash(
		"ff4995cc3e6b58450d304ba18d368c040d223c688aa83ba5799b21a757a99d93"):
		errors.append("accepted Pool epoch lost")
	return {"errors": errors, "human": human, "report": report}


static func assignment(season: SeasonState) -> bool:
	if not SeasonVenues.matches_season(season) or season.season_seed != 10 \
		or SeasonVenues.run_for(season) != 1:
		return false
	var data: Dictionary = season.npc_venues
	if data.get("version") != 3 or data.get("venue_ordinal") != 0 \
		or not ClubCareer.same(data.get("quota"),
			{"backyard": 2, "expanded": 2, "club": 1, "mogul": 0}) \
		or data.assignments.size() != 5 or data.environments.size() != 32:
		return false
	var ids: Array[String] = ["AE-01", "AE-01", "AC-01", "AY-03", "AY-01"]
	for index: int in range(ids.size()):
		var entry: Dictionary = data.assignments[str(index + 1)]
		if entry.manifest.id != ids[index] \
			or entry.manifest.revision != (1 if ids[index] == "AY-03" else 2):
			return false
	return true


static func binding(snapshot: Dictionary, season: SeasonState, fixture_id: int) -> bool:
	if snapshot.is_empty() or fixture_id < 0 or fixture_id > 2 or not assignment(season):
		return false
	var ids: Array[String] = ["AY-01", "AE-01", "AC-01"]
	var hosts: Array[int] = [5, 1, 3]
	var away: Array[int] = [0, 4, 2]
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season, fixture_id)
	return fixture == {"id": fixture_id, "round": 0,
		"away": away[fixture_id], "home": hosts[fixture_id]} \
		and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture) \
		and snapshot.version == 19 and snapshot.manifest.id == ids[fixture_id] \
		and snapshot.manifest.revision == 2 and snapshot.binding.assignment_version == 3 \
		and snapshot.binding.assignment_key == SeasonVenues.key(season.npc_venues) \
		and snapshot.binding.owner_club == hosts[fixture_id] \
		and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture) \
		and snapshot.binding.environment_seed == snapshot.environment.seed \
		and ClubCareer.same(snapshot.environment, season.npc_venues.environments[str(fixture_id)]) \
		and snapshot.environment.mode == "day" and snapshot.environment.profile.is_empty()


static func report_bound(report: Dictionary, season: SeasonState, fixture_id: int) -> bool:
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season, fixture_id)
	return report.get("version") == 17 and PhysicalMatchReport.valid(report) \
		and report.resolver == StadiumNpcPublicReport.RESOLVER \
		and binding(report.property, season, fixture_id) \
		and StadiumNpcPublicReport.matches(report, SeasonVenues.for_fixture(season, fixture))
