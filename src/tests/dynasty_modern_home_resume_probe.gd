extends "res://src/tests/league_home_resume_physical_probe.gd"
## Existing isolated owner only. Accepted human/NPC checkpoints are never replayed.
var resumed_app: SeasonApp
func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--modern-dynasty-resume"):
		print("MODERN_DYNASTY_RESUME_PREPARED physical_games=0 owner_writes=0")
		get_tree().quit()
		return
	var user_root: String = OS.get_environment("WIFFALTRO_MODERN_USER_ROOT")
	var clock_ok: bool = Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 \
		and not get_tree().paused and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
	for arg: String in OS.get_cmdline_args():
		clock_ok = clock_ok and not arg.begins_with("--fixed-fps")
	if not check(StadiumNpcPublicRuntime.source_qualified() and clock_ok,
		"qualified exact source and ordinary clock before resume") \
		or not check(user_root.is_absolute_path() and user_root == user_root.simplify_path()
			and OS.get_environment("XDG_DATA_HOME") == user_root
			and OS.get_user_data_dir().begins_with(user_root + "/"), "isolated worker data root retained"):
		get_tree().quit(2)
		return
	await super._ready()

func _continue(app: SeasonApp) -> void:
	resumed_app = app
	var count: int = app.season.player_results.size()
	if not check(app.season._league_home_context.get("format") == 92
		and app.season._dynasty_career_session.league == "dynasty"
		and app.season._dynasty_career_session.tier == 0
		and preload("res://src/gameplay/season/dynasty_league_home_live.gd").modern_origin(app.season.home_property)
		and app.dynasty_owner.found().owner.selected == "dynasty"
		and count in [0, 1, 2] and app.season.physical.reports.size() == count * 2
		and (count == 2 or app.season.pending_fixture().id == count * 3),
		"exact modern92 natural retained frontier; accepted games preserved"):
		return
	await super._continue(app)
	check(app.season.player_results.size() == 2 and app.season.physical.reports.size() == 4
		and app.season.physical.pending.is_empty() and not app.round_ui._working,
		"complete natural away/home rounds with four accepted AI reports")

func check(ok: bool, label: String) -> bool:
	if ok and label == "complete round cold replay":
		var cold: SeasonState = SeasonSave.restore()
		ok = cold != null and resumed_app != null \
			and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(resumed_app.season))
		label = "complete round exact cold snapshot equality"
	return super.check(ok, label)
