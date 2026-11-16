extends "res://src/tests/plaque_natural_career_test.gd"


## Independent plain save57 physical regression; no career rewards or synthetic scores.
func _ready() -> void:
	_evidence_dir = OS.get_environment("SAVE57_EVIDENCE")
	_check(_evidence_dir.is_absolute_path(), "isolated save57 evidence")
	DirAccess.make_dir_recursive_absolute(_evidence_dir)
	SeasonSave.path = _file("current.json")
	var season: SeasonState
	if FileAccess.file_exists(SeasonSave.path):
		season = SeasonSave.restore()
	else:
		season = SeasonState.create(443, false, true, true)
		season.physical = SeasonPhysicalFixtures.new()
		season.opponents._format = 13
		for pick in range(4):
			_check(season.choose_player(season.offers()[0]), "ordinary draft")
		_check(SeasonSave.save(season), "pristine save57")
	_check(season != null, "save57 restores")
	if season == null:
		await _finish_dynasty()
		return
	while _failures == 0 and season.player_results.is_empty():
		if season.physical.pending.is_empty():
			var fixture: Dictionary = season.pending_fixture()
			var report: Dictionary = await _human_report(season, fixture)
			if report.is_empty():
				break
			var core: Dictionary = _core(report)
			var own: int = 1 if fixture.home == 0 else 0
			var row: Dictionary = core.teams[own]
			var ai: Dictionary = PhysicalBaseEvidence.enriched(
				core.tactics.teams[1 - own], core.tactics.base
			)
			season.physical.pending = {
				"human":
				[
					fixture.id,
					core.away_runs,
					core.home_runs,
					core.performance,
					[],
					[],
					{},
					[],
					[],
					{},
					{},
					[],
					ai
				],
				"reports": []
			}
			_check(SeasonSave.save(season), "human actual pending saves " + SeasonSave.last_error)
		var step: Dictionary = SeasonRoundSettlement.project(season)
		_check(not step.has("error"), "actual save57 projection " + str(step.get("error", "")))
		if step.has("error"):
			break
		if step.has("fixture"):
			var report: Dictionary = await _human_report(step.candidate, step.fixture)
			if report.is_empty():
				break
			season.physical.pending.reports.append(
				{
					"fixture": step.fixture.id,
					"request": SeasonPhysicalFixtures.request_key(step.candidate, step.fixture),
					"report": report
				}
			)
		else:
			season = step.candidate
		_check(SeasonSave.save(season), "actual save57 commits " + SeasonSave.last_error)
		if _failures > 0:
			break
		var count: int = season.results.size()
		season = SeasonSave.restore()
		_check(
			season != null and season.results.size() == count, "cold primary retains same progress"
		)
		if season == null:
			break
	if _failures == 0:
		var data: Dictionary = SeasonSave.snapshot(season)
		_check(data.version == 57 and season.results.size() == 3, "three actual games yield save57")
		_write_once("completed-save57.json", data)
	print(
		"SAVE57_LINEUP_RESULT checks=",
		_checks,
		" failures=",
		_failures,
		" physical_starts=",
		_physical_starts
	)
	await _finish_dynasty()


func _prepare_human_lineup(season: SeasonState) -> void:
	season.swap_batters(0, 1)
	season.fielder_index = 2
	season.select_starter(0)
	_check(SeasonSave.save(season), "legal lineup changes checkpoint before physical play")
