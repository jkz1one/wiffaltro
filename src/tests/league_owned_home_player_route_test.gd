extends Node
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const UI = preload("res://src/presentation/season/dynasty_career_ui.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("PLAYER_HOME_ROUTE ", ok, " ", label)
	if not ok: failures += 1
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--player-route-root="): root = arg.trim_prefix("--player-route-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var source: SeasonState = SeasonState.create(81102, false, true, true)
	source.career = _source_career()
	check(source.career.start(source), "synthetic title fixture starts normal source")
	for index in range(4): source.choose_player(source.offers()[0])
	check(SeasonSave.save(source), "normal canonical source saves")
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	add_child(app)
	await _run(app, original)
	app.free()
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	print("PLAYER_HOME_ROUTE_RESULT %d checks, %d failures" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run(app: SeasonApp, original: String) -> void:
	if not check(app.season != null, "actual main restores ordinary source"): return
	var roster: Array = app.season.picks.duplicate()
	if not check(app.dynasty_enrollment.prepare(81200), "actual enrollment prepares owned carried92: " + app.notice): return
	check(app.dynasty_enrollment._payload.snapshot.version == 92, "preview targets92 directly")
	UI.enrollment(app)
	check(app.dynasty_enrollment.pending(), "actual enrollment review keeps detached ticket")
	var ticket: int = app.dynasty_enrollment.token()
	Store._test_stop_after = "intent.rename"
	check(not app.dynasty_enrollment.commit(ticket), "atomic enrollment interruption not promoted")
	Store._test_stop_after = ""
	check(Store.inspect(app.dynasty_enrollment.path).get("status") == "pending", "exact92 create intent retained")
	check(app.season == null and SeasonSave.dynasty_owner_bound(), "no historical source fallback")
	if not check(app.dynasty_enrollment.commit(ticket), "exact enrollment retry commits92: " + app.notice): return
	check(app.season._league_home_context.get("format") == 92 and app.season.picks == roster,
		"actual main selected carried roster and owned home")
	check(FileAccess.get_file_as_string(SeasonSave.path) == original, "ordinary source archived unchanged")
	var current: Dictionary = app.dynasty_owner.found()
	check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed", "direct92 create cold restore")
	UI.show(app)
	var choice: Button = _league_button(app.menu, "dugout", 0)
	if not check(choice != null and not choice.disabled, "actual chooser exposes unlocked Dugout Base"): return
	choice.pressed.emit()
	check(app._dialog.visible, "actual chooser opens confirmation")
	app._dialog.hide()
	app._dialog.confirmed.emit()
	if not check(app.season != null and app.season._league_home_context.get("format") == 91,
		"chooser confirmation opens owned Dugout91: " + app.notice): return
	check(app.season._league_home_context.get("format") == 91 and app.season.league_rules.league == "dugout",
		"chooser uses exact owned alternate profile")
	current = app.dynasty_owner.found()
	check(not app.dynasty_owner.start_other("sponsorship", current.revision, 81301), "active alternate cannot be replaced")
	if not check(app.dynasty_owner.switch_to("dynasty", current.revision), "resume existing carried92 slot"): return
	check(app.season.picks == roster, "resume preserves roster")
	current = app.dynasty_owner.found()
	if not check(app.dynasty_owner.close_current("abandon", current.revision), "explicit test abandonment closes first generation"): return
	current = app.dynasty_owner.found()
	var generation: int = int(current.owner.lineage.generation)
	if not check(app.dynasty_owner.begin_next_tier(81400, current.revision, 0), "actual next-season route commits owned92: " + app.notice): return
	current = app.dynasty_owner.found()
	check(current.owner.lineage.generation == generation + 1 and app.season._league_home_context.get("format") == 92,
		"new generation remains owned carried92")
	check(app.season.picks == roster and app.season._dynasty_start.season_ordinal == generation + 2,
		"next generation carries exact roster and ordinal")
	check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed", "next generation cold restore")

func _league_button(node: Node, league: String, tier: int) -> Button:
	if node is Button and node.get_meta("owner_league", "") == league \
		and node.get_meta("owner_league_tier", -1) == tier:
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _league_button(child, league, tier)
		if found != null: return found
	return null

func _source_career() -> ClubCareer:
	return Fixture.nonphysical_dynasty_source()
