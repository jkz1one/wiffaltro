extends Node
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Main = preload("res://src/presentation/season/season_app.tscn")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("NORMAL_HOME_ENROLL ", ok, " ", label)
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--normal-enroll-root="): root = arg.trim_prefix("--normal-enroll-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var source: SeasonState = SeasonState.create(99101, false, true, true)
	source.career = Fixture.nonphysical_dynasty_source()
	var prior: ClubAssetLedger = ClubPlayers.assets(source.career)
	source.career._assets = ClubAssetLedger.new_club(prior._seed, prior._credits, prior._progress, prior._championships).to_data()
	source.career.start(source)
	for pick in range(4): source.choose_player(source.offers()[0])
	if check(SeasonSave.save(source), "synthetic prerequisite history with genuine modern assets saves"):
		var app: SeasonApp = Main.instantiate()
		add_child(app)
		_run(app)
		app.free()
	SeasonSave._dynasty_owner_path = ""
	print("NORMAL_HOME_ENROLL_RESULT %d checks, %d failures; synthetic_titles=true; physical_games=0" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run(app: SeasonApp) -> void:
	app.call("_show_main_leagues")
	var choice: Button = _button(app.menu, "sponsorship", "")
	if not check(choice != null and not choice.disabled, "actual Choose League exposes earned Sponsorship Base"): return
	choice.pressed.emit()
	if not check(app.menu.page == "league_career_review" and app.league_career.candidate() != null,
		"actual chooser prepares owned-home review"): return
	var start: Button = _button(app.menu, "", "START & SAVE SEASON")
	if not check(start != null, "actual confirmation control exists"): return
	start.pressed.emit()
	if not check(app.season != null and app.season.league_rules.league == "sponsorship"
		and app.season._league_home_context.get("format") == 93, "actual Start and Save selects ordinary Sponsorship93"): return
	for pick in range(4): app.choose_player(app.season.offers()[0])
	if not check(app.season.picks.size() == 4 and not app.season.home_property.is_empty(), "actual main draft retains owned home"): return
	var snapshot: Dictionary = SeasonSave.snapshot(app.season)
	var cold: SeasonState = SeasonSave.restore()
	check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "normal93 exact cold replay")
	check(not SeasonSave.dynasty_owner_bound() and app.season._dynasty_career_session.is_empty(), "no hidden Dynasty session before enrollment")
	var roster: Array = app.season.picks.duplicate()
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	if not check(app.dynasty_enrollment.prepare(99200), "legitimate93 source prepares Dynasty: " + app.notice): return
	check(app.dynasty_enrollment.preview().roster == roster, "exact normal93 roster carried")
	if not check(app.dynasty_enrollment.commit(app.dynasty_enrollment.token()), "actual explicit enrollment commits92: " + app.notice): return
	check(app.season._league_home_context.get("format") == 92 and app.season.picks == roster
		and app.dynasty_owner.found().owner.selected == "dynasty", "selected92 preserves the earned source roster")
	check(FileAccess.get_file_as_string(SeasonSave.path) == original, "normal93 source remains byte-identical")
	check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed", "converted92 owner cold replay")
func _button(node: Node, league: String, label: String) -> Button:
	if node is Button and ((not league.is_empty() and node.get_meta("league_choice", "") == league
		and node.get_meta("league_tier", -1) == 0) or (not label.is_empty() and node.text == label)):
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button(child, league, label)
		if found != null: return found
	return null
