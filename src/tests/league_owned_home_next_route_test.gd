extends Node
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("NEXT_HOME_ROUTE ", ok, " ", label)
	if not ok: failures += 1
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--player-route-root="): root = arg.trim_prefix("--player-route-root=")
	if not root.is_absolute_path():
		get_tree().quit(2)
		return
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	add_child(app)
	_run(app)
	app.free()
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	print("NEXT_HOME_ROUTE_RESULT %d checks, %d failures" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run(app: SeasonApp) -> void:
	if not check(app.season != null and app.dynasty_owner.ready(), "actual main cold restores closed92 owner"): return
	var current: Dictionary = app.dynasty_owner.found()
	var generation: int = int(current.owner.lineage.generation)
	var roster: Array = app.season.picks.duplicate()
	var other: Dictionary = current.owner.other.duplicate(true)
	Store._test_stop_after = "intent.rename"
	check(not app.dynasty_owner.begin_next_tier(81400, current.revision, 0), "next-generation interruption not exposed")
	Store._test_stop_after = ""
	check(app.dynasty_owner.found().get("status") == "pending", "exact owned next-generation intent retained")
	if not check(app.dynasty_owner.recover(), "actual recovery commits same owned generation: " + app.notice): return
	current = app.dynasty_owner.found()
	check(current.owner.lineage.generation == generation + 1 and app.season._league_home_context.get("format") == 92,
		"next generation remains owned92")
	check(app.season.picks == roster and app.season._dynasty_start.season_ordinal == generation + 2,
		"carried roster and ordinal retained")
	check(ClubCareer.same(other, current.owner.other), "existing alternate slot untouched")
	check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed", "next generation cold replay")
