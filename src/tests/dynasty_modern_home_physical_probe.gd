extends "res://src/tests/league_home_modern_physical_probe.gd"
## Explicit modern92 proof. Synthetic unlock prefix; all six reported games are natural.
const Carried = preload("res://src/gameplay/season/dynasty_carried_home_runtime.gd")
var carried_start: Dictionary = {}
var carried_roster: Array = []

func _expected_league() -> String:
	return "dynasty"

func _paid_ledger(season: SeasonState) -> ClubAssetLedger:
	return Carried.paid_ledger(season)

func _complete_home_round() -> bool:
	return true

func _run() -> void:
	var source: SeasonState = _source()
	if not _require(source.career != null and source.career.start(source), "synthetic unlock prefix with genuine new_club assets"):
		return
	for pick in range(4):
		if not _require(source.choose_player(source.offers()[0]), "ordinary source draft pick"):
			return
	if not _require(SeasonSave.save(source), "isolated canonical normal source"):
		return
	var source_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	carried_roster = source.picks.duplicate()
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	app.child_entered_tree.connect(func(child: Node) -> void:
		if child is PitchBatLab:
			child._automation = MatchAutomation.new()
			child._automation.seed = SeasonPhysicalFixtures.seed_for(app.season, app.season.pending_fixture())
	)
	add_child(app)
	for frame in range(600):
		if not app._loading_boot: break
		await get_tree().process_frame
	if not _require(not app._loading_boot and app.season != null, "actual main restores normal source"):
		app.free()
		return
	if not _require(app.dynasty_enrollment.prepare(38200), "actual carried enrollment prepares: " + app.notice) \
		or not _require(app.dynasty_enrollment.commit(app.dynasty_enrollment.token()), "actual atomic92 enrollment: " + app.notice):
		app.free()
		return
	path = app.dynasty_enrollment.path
	if not _require(app.season.picks == carried_roster and app.season._league_home_context.get("format") == 92
		and app.season._dynasty_start.roster == carried_roster and app.season.career == null
		and Store.inspect(path).owner.selected == "dynasty"
		and FileAccess.get_file_as_string(SeasonSave.path) == source_bytes,
		"real carried roster in selected92; original normal source unchanged"):
		app.free()
		return
	carried_start = app.season._dynasty_start.duplicate(true)
	var cold: SeasonState = SeasonSave.restore()
	if not _require(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(app.season)),
		"fresh enrolled92 exact cold replay"):
		app.free()
		return
	await _play_rounds(app)
	app.free()

func _after_rounds(app: SeasonApp) -> void:
	var owner: Dictionary = Store.inspect(path).owner
	_require(physical_games == 2 and app.season.player_results.size() == 2
		and app.season.physical.reports.size() == 4 and app.season.physical.pending.is_empty()
		and not app.round_ui._working and not app.round_ui.process_runner.running and not app.round_ui.runner._running,
		"two human and four AI games published; no active writer")
	_require(owner.selected == "dynasty" and owner.dynasty.session_id == initial_owner.dynasty.session_id
		and ClubCareer.same(owner.career.assets, initial_owner.career.assets)
		and ClubCareer.same(owner.other, initial_owner.other)
		and owner.career.settlements.size() == initial_owner.career.settlements.size()
		and ClubCareer.same(app.season._dynasty_start, carried_start)
		and ClubCareer.same(app.season.home_property, frozen_home),
		"carried identity frozen; no settlement asset refresh or alternate replacement")
	_write("modern-dynasty-summary.json", {"checks": checks, "failures": failures,
		"human_games": physical_games, "accepted_ai_games": app.season.physical.reports.size(),
		"complete_home_round": true, "source_qualified": StadiumNpcPublicRuntime.source_qualified(),
		"engine": Engine.get_version_info(), "owner_path": path, "user_data_dir": OS.get_user_data_dir(),
		"synthetic_unlock_history": true, "native_visual_qualified": false, "full_season_qualified": false})
