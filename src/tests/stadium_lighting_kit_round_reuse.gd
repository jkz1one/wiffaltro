extends RefCounted
## Test-only durable recovery of unchanged, previously simulated reports.
## Never reads or transplants bundle.settled_season. No report adaptation.
const SOURCE_SHA256: String = "1c405c2e83fe8daf528ef4e7fda6c37158fdbce615835d8a5a57fcd9e6c23f72"


static func load_exact(path: String) -> Dictionary:
	if not path.is_absolute_path() or FileAccess.get_sha256(path) != SOURCE_SHA256:
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


static func recover(app: SeasonApp, bundle: Dictionary) -> Dictionary:
	if (
		not is_instance_valid(app)
		or app.season == null
		or app.season.physical == null
		or not app.season.physical.pending.is_empty()
		or not app.season.results.is_empty()
	):
		return {"error": "fresh ordinary physical season required"}
	if (
		bundle.get("schema") != "waterfall-public-actual-round-v1"
		or bundle.get("completed_physical_games") != 3
		or not bundle.get("human") is Array
		or not bundle.get("ai_reports") is Array
		or bundle.ai_reports.size() != 2
	):
		return {"error": "exact retained three-game evidence required"}
	var source: SeasonState = SeasonSave._decode(bundle.get("initial_season", {}))
	var fixture: Dictionary = app.season.pending_fixture()
	if (
		source == null
		or not ClubCareer.same(source.pending_fixture(), fixture)
		or not ClubCareer.same(fixture, bundle.get("human_fixture"))
		or fixture.get("away") != 0
		or SeasonPhysicalFixtures.request_key(source, fixture) != bundle.get("human_request")
		or SeasonPhysicalFixtures.request_key(app.season, fixture) != bundle.get("human_request")
	):
		return {"error": "original human fixture/request/teams/field differ; no adaptation allowed"}
	var report: Dictionary = bundle.get("human_report", {})
	var state: MatchState = SeasonPhysicalFixtures.match_for(app.season, fixture)
	var field: FieldDefinition = SeasonState.field_for_fixture(fixture, app.season)
	if (
		state == null
		or field == null
		or not PhysicalMatchReport.valid(report)
		or report.seed != SeasonPhysicalFixtures.seed_for(app.season, fixture)
		or report.field != String(field.id)
		or not PhysicalStadiumReport.matches(report, state.stadium)
		or not PhysicalChoiceEvidence.matches(report, state)
		or not PhysicalTacticalEvidence.report_matches(report, state)
	):
		return {"error": "unchanged source human report does not match current exact match"}
	var row: Dictionary = PhysicalBaseEvidence.enriched(
		report.tactics.teams[1], report.tactics.base
	)
	var human: Array = [
		fixture.id,
		report.away_runs,
		report.home_runs,
		report.performance,
		[],
		[],
		{},
		[],
		[],
		{},
		{},
		[],
		row,
		[],
		StadiumLayoutSnapshot.key(state.stadium)
	]
	if not ClubCareer.same(human, bundle.human):
		return {"error": "original actual human-side evidence differs; no row adaptation allowed"}
	var source_before: String = JSON.stringify(bundle, "", true, true).sha256_text()
	if not app.round_ui.queue_human(bundle.human):
		return {"error": "ordinary durable queue refused original human-side evidence"}
	var accepted: Array[Dictionary] = []
	for envelope: Dictionary in bundle.ai_reports:
		var projection: Dictionary = SeasonRoundSettlement.project(app.season)
		if projection.has("error") or not projection.has("fixture"):
			return {"error": "normal round projection refused or completed before source report"}
		var needed: Dictionary = projection.fixture
		var candidate: SeasonState = projection.candidate
		if (
			envelope.get("fixture") != needed.id
			or envelope.get("request") != SeasonPhysicalFixtures.request_key(candidate, needed)
		):
			return {
				"error": "original AI fixture/request/teams/field differ; no adaptation allowed"
			}
		# This is a durable completed-job recovery record, not a new simulation.
		# The existing projector validates complete report/teams/policy/receipts.
		app.season.physical.pending.reports.append(envelope.duplicate(true))
		var checked: Dictionary = SeasonRoundSettlement.project(app.season)
		if checked.has("error") or not SeasonSave.save(app.season):
			app.season.physical.pending.reports.pop_back()
			return {"error": "existing completed-job validator rejected unchanged source report"}
		accepted.append(
			{
				"fixture": needed.id,
				"request": envelope.request,
				"report_sha256": JSON.stringify(envelope.report, "", true, true).sha256_text()
			}
		)
	var final_projection: Dictionary = SeasonRoundSettlement.project(app.season)
	if final_projection.has("error") or final_projection.has("fixture"):
		return {"error": "exact reports did not produce a complete ordinary round"}
	app.round_ui.process_jobs = false
	app.round_ui.resume()  # Existing atomic publication/save; no runner is needed.
	if (
		app.round_ui._working
		or not app.season.physical.pending.is_empty()
		or app.season.results.size() != 3
		or app.season.player_results.size() != 1
		or app.season.physical.reports.size() != 2
		or app.season.pending_fixture().get("home") != 0
	):
		return {"error": "ordinary atomic recovery did not reach real pending home fixture"}
	var cold: SeasonState = SeasonSave.restore()
	if (
		cold == null
		or not ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(app.season))
		or source_before != JSON.stringify(bundle, "", true, true).sha256_text()
	):
		return {"error": "cold replay or source immutability failed"}
	app.season = cold
	return {
		"source_sha256": SOURCE_SHA256,
		"reused_completed_games": 3,
		"new_simulated_games": 0,
		"human_request": bundle.human_request,
		"ai_reports": accepted,
		"pending_fixture": cold.pending_fixture(),
		"settled_save_sha256":
		JSON.stringify(SeasonSave.snapshot(cold), "", true, true).sha256_text(),
		"method":
		(
			"exact unchanged reports through durable pending recovery and ordinary atomic round "
			+ "settlement; no settled-save transplant"
		)
	}
