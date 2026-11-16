extends Node
## Real detached home games bind immutable property snapshots; no season awards fabricated.

var _failures: int = 0
var _reports: Array[Dictionary] = []
var _errors: Array[String] = []


func _ready() -> void:
	SeasonSave.path = "user://stadium-physical-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	_begin(app)
	if _failures > 0:
		get_tree().quit(1)
		return
	var season: SeasonState = app.season
	var layout: Dictionary = _layout()
	var revision: int = ClubPlayers.assets(season.career).revision()
	var initial_balance: int = season.career.balance()
	_check(ClubConstruction.save_draft(season, layout, revision).ok, "real saved owned field draft")
	_check(ClubConstruction.apply_draft(season, layout, revision + 1).ok,
		"real atomic layout journal")
	if _failures > 0:
		get_tree().quit(1)
		return
	season.home_property = StadiumLayoutSnapshot.capture(
		ClubPlayers.assets(season.career), _complete_boundary())
	_check(SeasonSave.save(season), "owned frozen home snapshot saved before drafting")
	for pick in range(4):
		app.choose_player(season.offers()[0])
	var fixture: Dictionary = {}
	for game: Dictionary in season.schedule:
		if _select_fixture(season, game):
			fixture = game
			break
	_check(not fixture.is_empty(), "scheduled home fixture found")
	if fixture.is_empty():
		get_tree().quit(1)
		return
	var original_property: Dictionary = season.home_property.duplicate(true)
	var source: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	var snapshot: Dictionary = source.stadium.duplicate(true)
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	var key: String = SeasonPhysicalFixtures.request_key(season, fixture)
	season.home_property.layout.obstacles[0].site = "O-L2"
	_check(key != SeasonPhysicalFixtures.request_key(season, fixture),
		"physical request identity includes exact owned layout")
	season.home_property = original_property.duplicate(true)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	runner.finished.connect(func(report: Dictionary) -> void: _reports.append(report))
	runner.failed.connect(func(reason: String) -> void: _errors.append(reason))
	_check(not runner.start(source, _verification_seed(source), SeasonState.AWAY_FIELD_ID),
		"home geometry cannot be injected into the away park")
	_check(runner.start(source, _verification_seed(source)), "actual bound home physics starts")
	if runner._lab == null:
		get_tree().quit(1)
		return
	_check(runner._lab.has_meta("stadium_snapshot") and runner._lab.has_meta("stadium_property"),
		"worker installs the same full-scale geometry as the editor")
	source.stadium.layout.obstacles[0].site = "O-L2"
	_check(runner._lab._match_state.stadium == snapshot,
		"caller edits cannot mutate the running physical world")
	source.stadium = snapshot.duplicate(true)
	await _complete(1)
	_check(_errors.is_empty() and _reports.size() == 1, "first property game completes physically")
	if _reports.size() != 1:
		push_error(str(_errors))
		get_tree().quit(1)
		return
	var report: Dictionary = _reports[0]
	_check(report.version == _report_version() and PhysicalMatchReport.valid(report)
		and PhysicalChoiceEvidence.matches(report, source)
		and PhysicalTacticalEvidence.report_matches(report, source),
		"report8 validates unchanged baseball evidence plus exact property binding")
	_check(PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report))),
		"physical property report survives JSON round trip")
	_tamper(report, source)
	_check(runner.start(source, _verification_seed(source)), "repeat the same frozen property game")
	await _complete(2)
	_check(_reports.size() == 2 and _errors.is_empty(), "second physical game completes")
	if _reports.size() == 2:
		_check(ClubCareer.same(_reports[0], _reports[1]),
			"identical frozen layout and seed replay exactly")
	_check(FileAccess.get_file_as_string(SeasonSave.path) == original
		and SeasonSave.restore() != null and season.career.balance() == initial_balance,
		"detached property verification cannot award money or alter saved ownership")
	print("STADIUM_PHYSICAL releases=", report.releases.size(), " score=", report.away_runs,
		"-", report.home_runs, " property=", StadiumLayoutSnapshot.key(report.property))
	runner.queue_free()
	app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium physical checks passed: two real bound games and exact replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _tamper(report: Dictionary, source: MatchState) -> void:
	for field: String in ["version", "resolver", "property"]:
		var bad: Dictionary = report.duplicate(true)
		bad[field] = false
		_check(not PhysicalMatchReport.valid(bad), "reject malformed report " + field)
	var bad: Dictionary = report.duplicate(true)
	bad.erase("property")
	_check(not PhysicalMatchReport.valid(bad), "new report cannot omit its geometry")
	bad = report.duplicate(true)
	bad.property.layout.obstacles[0].site = "O-L2"
	_check(not PhysicalChoiceEvidence.matches(bad, source)
		and not PhysicalTacticalEvidence.report_matches(bad, source),
		"a different otherwise-legal layout cannot impersonate this match")
	bad = report.duplicate(true)
	bad.property.layout.receiver = "not-owned"
	_check(not PhysicalMatchReport.valid(bad), "unknown object copy cannot enter physical evidence")
	bad = PhysicalStadiumReport.core(report)
	_check(not PhysicalChoiceEvidence.matches(bad, source), "old report cannot erase bound geometry")
	var legacy: MatchState = PhysicalMatchRequest.capture(source)
	legacy.stadium = {}
	_check(not PhysicalChoiceEvidence.matches(report, legacy),
		"bound report cannot be substituted into an old unmodified field")


func _complete(count: int) -> void:
	for frame in range(200000):
		if _reports.size() >= count or not _errors.is_empty():
			return
		await get_tree().process_frame
	_check(false, "physical fixture exceeded verification frame budget")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _begin(app: SeasonApp) -> void:
	app.begin_season(443, true, true, true, _complete_boundary())


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	return layout


func _complete_boundary() -> bool:
	return false


func _verification_seed(_source: MatchState) -> int:
	return 27


func _select_fixture(_season: SeasonState, game: Dictionary) -> bool:
	return game.home == 0


func _report_version() -> int:
	return 9 if _complete_boundary() else 8
