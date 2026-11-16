extends Node
## Cold read-only final acceptance of actual settled round; creates no app/lab/game.
var checks: int = 0
var failures: Array[String] = []


func _ready() -> void:
	var folder: String = OS.get_environment("NPC_COLD_INPUT")
	var output: String = OS.get_environment("NPC_COLD_OUTPUT")
	if not folder.is_absolute_path() or not output.is_absolute_path():
		get_tree().quit(2)
		return
	var path: String = folder.path_join("settled.json")
	_check(StadiumNpcPublicRuntime.source_qualified(), "exact combined source qualifies cold audit")
	var before_hash: String = FileAccess.get_sha256(path)
	SeasonSave.path = path
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var pending: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(folder.path_join("pending.json"))
	)
	var season: SeasonState = SeasonSave.restore()
	_check(season != null, "fresh-process decode of actual final save")
	if season != null:
		_check(
			ClubCareer.same(expected, SeasonSave.snapshot(season)), "exact decoded settled state"
		)
		_check(
			season.results.size() == 3 and season.player_results.size() == 1,
			"one round three genuine results"
		)
		_check(
			season.physical.pending.is_empty() and season.physical.reports.size() == 2,
			"both opponent reports and no pending game"
		)
		_check(season.round_index == 1, "round advanced exactly once")
		var result: Dictionary = season.player_results[0]
		_check(
			ClubCareer.same(result.yard_evidence, pending.physical.pending.human[16]),
			"original genuine human terminal evidence retained"
		)
		_check(
			season.cash() == (18 if SeasonState._winner(result) == 0 else 12),
			"ordinary reward exactly once"
		)
		for row: Dictionary in season.physical.reports:
			var fixture: Dictionary = SeasonVenues.fixture_for_id(season, int(row.fixture))
			_check(
				(
					PhysicalMatchReport.valid(row.report)
					and PhysicalStadiumReport.matches(
						row.report, StadiumLayoutSnapshot.for_fixture(season, fixture)
					)
				),
				"actual opponent report binds assigned venue"
			)
		_check(
			(
				not season.record_player_result(
					result.id,
					result.away_runs,
					result.home_runs,
					result.performance,
					[],
					[],
					{},
					[],
					[],
					{},
					{},
					[],
					{},
					[],
					result.property,
					null,
					result.yard_evidence
				)
				and ClubCareer.same(expected, SeasonSave.snapshot(season))
			),
			"cold duplicate result cannot pay again"
		)
	_check(FileAccess.get_sha256(path) == before_hash, "original settled bytes unchanged")
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(
		JSON.stringify(
			{
				"checks": checks,
				"failures": failures,
				"input_sha256": before_hash,
				"new_games": 0,
				"new_live_authority": false
			}
		)
	)
	file.close()
	print("CURRENT_NPC_SETTLED_COLD checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
