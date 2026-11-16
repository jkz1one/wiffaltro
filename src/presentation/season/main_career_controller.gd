extends RefCounted
## Normal-only composition. SeasonApp retains exact script identity for issued runtimes.

const LeagueController = preload("res://src/presentation/season/league_career_controller.gd")
const MainLeagueUI = preload("res://src/presentation/season/main_league_ui.gd")
const MainDynasty = preload("res://src/presentation/season/main_dynasty_route.gd")
const SharedController = preload("res://src/presentation/season/dynasty_career_controller.gd")
const Enrollment = preload("res://src/presentation/season/dynasty_career_enrollment.gd")
const DynastyUI = preload("res://src/presentation/season/dynasty_career_ui.gd")
const DynastyPlayers = preload("res://src/presentation/season/dynasty_career_players.gd")

var app: SeasonApp
var league_career: RefCounted
var dynasty_enrollment: RefCounted
var owner_path: String = ""
var shared_owner: bool = false
var blocked: bool = false
var player_asset_pending: Dictionary = {}


func _init(owner: SeasonApp) -> void:
	app = owner


func prepare() -> bool:
	league_career = LeagueController.new(app, SeasonSave.path)
	owner_path = MainDynasty.owner_path(SeasonSave.path)
	var route: Dictionary = MainDynasty.inspect_route(SeasonSave.path, OS.get_cmdline_user_args())
	if route.route == "blocked":
		blocked = true
		MainDynasty.blocked_screen(app, route.reason)
		return false
	shared_owner = route.route != "explicit"
	dynasty_enrollment = Enrollment.new(app, owner_path)
	if route.route == "shared":
		SeasonSave.bind_dynasty_owner(owner_path)
	return true


func release() -> void:
	if shared_owner and SeasonSave._dynasty_owner_path == owner_path:
		SeasonSave._dynasty_owner_path = ""
		SeasonSave._dynasty_owner_content_blocked = false


func make_owner_controller() -> RefCounted:
	return SharedController.new(app) if shared_owner else SeasonApp.DYNASTY_OWNER_CONTROLLER.new(app)


func shared_bound() -> bool:
	return shared_owner and SeasonSave.dynasty_owner_bound()


func home(parent: Node) -> void:
	if SeasonSave.dynasty_owner_bound() and app.dynasty_owner != null:
		app.dynasty_owner.add_controls(app.menu, parent)
	elif dynasty_enrollment != null and dynasty_enrollment.pending():
		app.menu._button(parent, "REVIEW DYNASTY START", DynastyUI.enrollment.bind(app))
	else:
		app.menu._button(parent, "CHOOSE LEAGUE", app._show_main_leagues)
		app.menu._button(parent, "CLASSIC SEASON", app.ask_new_season)


func show_leagues() -> void:
	if SeasonSave.dynasty_owner_bound():
		if shared_owner:
			DynastyUI.show(app)
		else:
			app.menu.show_home()
	else:
		MainLeagueUI.show(app)


func prepare_dynasty() -> void:
	if not MainDynasty.enrollment_enabled(app.season):
		app.notice = MainDynasty.ENROLLMENT_HOLD
		app.menu.show_home()
	elif dynasty_enrollment.prepare(int(Time.get_unix_time_from_system()) & 0x7fffffff):
		DynastyUI.enrollment(app)
	else:
		app.menu.show_home()


func new_season_handled() -> bool:
	if shared_bound():
		DynastyUI.show(app)
		return true
	if dynasty_enrollment != null and dynasty_enrollment.pending():
		DynastyUI.enrollment(app)
		return true
	return false


func standard_handled() -> bool:
	if not shared_bound():
		return false
	DynastyUI.show(app)
	return true


func choose_player_handled(id: String) -> bool:
	if shared_bound():
		app.dynasty_owner.draft_pick(id)
	elif not SeasonSave.dynasty_owner_bound() and app.season != null \
		and not app.season.league_rules.is_empty():
		league_career.draft_pick(id)
	else:
		return false
	app.show_season()
	return true


func show_season_handled() -> bool:
	if shared_bound() and app.dynasty_owner.ready():
		var owner: Dictionary = app.dynasty_owner.found().owner
		var entry: Dictionary = owner.career.sessions[owner[owner.selected].session_id]
		if entry.settled > 0 and app.season.phase != SeasonState.Phase.COMPLETE:
			app.menu.show_home()
			return true
	return false


func badge(parent: Node) -> bool:
	if not shared_bound():
		return false
	DynastyUI.badge(app, parent)
	return true


func settlement() -> bool:
	if not shared_bound():
		return false
	DynastyUI.settlement(app)
	return true


func summary() -> bool:
	if not shared_bound():
		return false
	SeasonPages.wrapped(app.menu._body, "Results and shared Club Bucks save together.")
	return true


func record(page: int) -> void:
	if shared_bound():
		DynastyUI.record(app, page)
	else:
		ClubCareerUI.show_ordinary(app.menu, page)


func players_enabled() -> bool:
	return app.dynasty_owner.ready() if shared_bound() else app.season != null and app.season.career != null


func player_view() -> Dictionary:
	return DynastyPlayers.view(app) if shared_bound() else (
		ClubPlayersUI.career_view(app.season.career) if app.season != null else {})


func player_transact(request: Dictionary) -> Dictionary:
	return DynastyPlayers.transact(app, request) if shared_bound() else ClubPlayers.transact(app.season, request)
