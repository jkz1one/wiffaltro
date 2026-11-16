extends Node
const Main = preload("res://src/presentation/season/season_app.tscn")
const Modern = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("NORMAL_HOME_ROUTE ", ok, " ", label)
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fresh-league-root="): root = arg.trim_prefix("--fresh-league-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave._dynasty_owner_path = ""
	SeasonSave.path = root.path_join("fresh.json")
	var app: SeasonApp = Main.instantiate()
	add_child(app)
	_fresh(app)
	app.free()
	SeasonSave.path = root.path_join("legacy.json")
	_legacy()
	print("NORMAL_HOME_ROUTE_RESULT %d checks, %d failures" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _fresh(app: SeasonApp) -> void:
	check(app.season == null, "actual fresh main has no source")
	if not check(app.league_career.prepare("dugout", 98401), "prepare initial Dugout"): return
	var candidate: SeasonState = app.league_career.candidate()
	check(Modern.modern_origin(StadiumLayoutSnapshot.capture(ClubPlayers.assets(candidate.career), true)),
		"initial Dugout owns genuine constructor8/40")
	check(not FileAccess.file_exists(SeasonSave.path), "preparation leaves disk absent")
	var token: int = app.league_career.token()
	check(app.league_career.cancel(token), "cancel prepared origin")
	check(not FileAccess.file_exists(SeasonSave.path), "cancel preserves absent save")
	if not check(app.league_career.prepare("dugout", 98401), "prepare exact retry candidate"): return
	token = app.league_career.token()
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	check(not app.league_career.commit(token) and app.season == null and not FileAccess.file_exists(SeasonSave.path),
		"failed atomic write preserves absent save and live source")
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	if not check(app.league_career.commit(token), "same candidate retry commits owned93 once"): return
	check(not app.league_career.commit(token), "repeated commit cannot start another run")
	for pick in range(4): app.choose_player(app.season.offers()[0])
	check(app.season.picks.size() == 4, "four picks saved")
	check(app.season._league_home_context.get("format") == 93 and not app.season.home_property.is_empty()
		and app.season._dynasty_career_session.is_empty() and not SeasonSave.dynasty_owner_bound(),
		"ordinary owned-home93 with no hidden Dynasty session")
	var fixture: Dictionary = app.season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	check(fixture.home == 0 and StadiumLayoutSnapshot.for_fixture(app.season, fixture).get("version") == 9,
		"natural home fixture uses complete owned fixture9")
	var saved: Dictionary = SeasonSave.snapshot(app.season)
	check(saved.get("version") == 93, "normal save retains explicit93")
	check(SeasonSave._decode(saved.checkpoint) == null, "stripped93 rejected by historical grammar")
	var bad: Dictionary = saved.duplicate(true)
	bad.extra = true
	check(SeasonSave._decode(bad) == null, "extra envelope field rejected")
	bad = saved.duplicate(true)
	bad.home_property.layout.version = 41
	check(SeasonSave._decode(bad) == null, "unqualified family refused")
	bad = saved.duplicate(true)
	var inner: Dictionary = SeasonSave.OwnedDraftSave.closed(bad.checkpoint.checkpoint)
	inner.normal_home = "0".repeat(64)
	check(SeasonSave._decode(bad) == null, "mismatched frozen home marker refused")
	var transport: Dictionary = PhysicalRoundProcess.request_for(app.season, "normal93", "normal93-key", 1)
	check(transport.get("version") == 1 and not transport.has("owner")
		and PhysicalRoundProcess.decode_request(transport, "normal93") != null,
		"ordinary worker transport1 preserves owned93 without owner metadata")

	var restored: SeasonState = SeasonSave.restore()
	check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored), saved), "exact normal Save Reload")
	var assets: Dictionary = ClubPlayers.assets(app.season.career).to_data()
	check(app.league_career.prepare("dugout", 98402), "next alternate prepares from modern career")
	check(ClubCareer.same(ClubPlayers.assets(app.league_career.candidate().career).to_data(), assets),
		"existing modern assets not replaced")
	app.league_career.cancel(app.league_career.token())
func _legacy() -> void:
	var source: SeasonState = SeasonState.create(98501, false, true, true)
	source.career = ClubCareer.new()
	source.career.start(source)
	for pick in range(4): source.choose_player(source.offers()[0])
	var assets: Dictionary = ClubPlayers.assets(source.career).to_data()
	check(not Modern.modern_origin(StadiumLayoutSnapshot.capture(ClubPlayers.assets(source.career), true)), "retained legacy fixture")
	if not check(SeasonSave.save(source), "save legacy source"): return
	var app: SeasonApp = Main.instantiate()
	add_child(app)
	if check(app.league_career.prepare("dugout", 98502), "alternate prepares from retained legacy career"):
		check(ClubCareer.same(ClubPlayers.assets(app.league_career.candidate().career).to_data(), assets),
			"legacy paid assets retained exactly, no origin conversion")
	app.free()
