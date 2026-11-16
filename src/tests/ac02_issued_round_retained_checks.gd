extends RefCounted
## Test-only original terminal predicates over actual retained settlement outputs.
## No capture, live authority, game mutation, cached validation or alternate outcome.


static func terminal(season: SeasonState, human: Dictionary, report: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var fixture: Dictionary = season.pending_fixture()
	var expected: Dictionary = SeasonVenues.for_fixture(season, fixture)
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

