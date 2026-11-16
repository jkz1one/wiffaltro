class_name ExpandedSeasonUI
extends RefCounted
## A separate ordinary season slot, never an owner migration or a synthetic grant.

const SAVE_PATH: String = "user://expanded-pitch-season-v6.json"
static var previous_path: String = ""
static var previous_season: SeasonState


static func controls(app: SeasonApp, parent: Node) -> void:
	if SeasonSave.dynasty_owner_bound():
		return  # This route never rewrites an owner's binding.
	if SeasonSave.path == SAVE_PATH:
		app.menu._button(parent, "NEW 43-PITCH SEASON", ask_new.bind(app))
		app.menu._button(parent, "RETURN TO SAVED CLUB", return_to_club.bind(app))
	else:
		app.menu._button(parent, "43-PITCH SEASON", open.bind(app))


static func open(app: SeasonApp) -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return
	if SeasonSave.dynasty_owner_bound() or not app._prepare_draft_exit():
		return
	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak"):
		var old_path: String = SeasonSave.path
		SeasonSave.path = SAVE_PATH
		var restored: SeasonState = SeasonSave.restore()
		SeasonSave.path = old_path
		if restored == null or restored.build == null or not restored.build.pitch_catalog_expanded():
			app.notice = "The expanded-pitch season could not be restored. Both saves were preserved."
			app.menu.show_home()
			return
		_enter(app, restored)
		return
	ask_new(app)


static func ask_new(app: SeasonApp) -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return
	app._confirm(
		"Start a 43-pitch Working season in its separate save slot? "
		+ "Draft the unchanged players, earn Cash in games, and buy slot-specific lessons. "
		+ "This replaces only an earlier v6 43-pitch season. Your saved club stays unchanged.",
		begin.bind(app)
	)


static func begin(app: SeasonApp) -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return
	if SeasonSave.dynasty_owner_bound() or not app._prepare_draft_exit():
		return
	var season: SeasonState = ExpandedSeasonProgression.create_season(
		int(Time.get_unix_time_from_system()) & 0x7fffffff
	)
	if season == null:
		app.notice = "The expanded pitch catalog is unavailable. No save was changed."
		app.menu.show_home()
		return
	var old_path: String = SeasonSave.path
	SeasonSave.path = SAVE_PATH
	var saved: bool = SeasonSave.save(season)
	SeasonSave.path = old_path
	if not saved:
		app.notice = SeasonSave.last_error
		app.menu.show_home()
		return
	_enter(app, season)


static func _enter(app: SeasonApp, season: SeasonState) -> void:
	if SeasonSave.path != SAVE_PATH:
		previous_path = SeasonSave.path
		previous_season = app.season
	SeasonSave.path = SAVE_PATH
	app.season = season
	app.menu.draft_selection = ""
	app.notice = "43 pitches: paid lessons, separate v6 season save. Provisional balance."
	app.show_season()


static func return_to_club(app: SeasonApp) -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return
	if SeasonSave.path != SAVE_PATH or previous_path.is_empty() or not app._prepare_draft_exit():
		return
	SeasonSave.path = previous_path
	app.season = previous_season
	previous_path = ""
	previous_season = null
	app.notice = "Returned to your saved club."
	app.menu.show_home()
