extends "res://src/presentation/season/season_app.gd"
## Explicit scene only. The normal main scene and Dynasty owner remain unchanged.

const Controller = preload("res://src/presentation/season/league_career_controller.gd")
const CareerUI = preload("res://src/presentation/season/league_career_ui.gd")
const DynastyController = preload("res://src/presentation/season/dynasty_career_controller.gd")
const DynastyEnrollment = preload("res://src/presentation/season/dynasty_career_enrollment.gd")
const DynastyUI = preload("res://src/presentation/season/dynasty_career_ui.gd")
const OwnerStore = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const DynastyPlayers = preload("res://src/presentation/season/dynasty_career_players.gd")
const ARGUMENT: String = "--league-career-candidate-root="

var league_career: RefCounted
var dynasty_enrollment: RefCounted
var candidate_owner_path: String = ""
var _original_save_path: String = ""
var _candidate_path: String = ""
var _candidate_ready: bool = false
var _player_asset_pending: Dictionary = {}


static func launch_arguments(arguments: PackedStringArray) -> Dictionary:
	var root: String = ""
	var count: int = 0
	for argument: String in arguments:
		if argument.begins_with("--closed-dynasty-owner="):
			return {}
		if argument.begins_with(ARGUMENT):
			count += 1
			root = argument.trim_prefix(ARGUMENT)
	if (
		count != 1 or not root.is_absolute_path() or root.length() < 2
		or root != root.simplify_path() or root.begins_with("res://")
		or root.begins_with("user://") or not DirAccess.dir_exists_absolute(root)
	):
		return {}
	var protected: Array[String] = [
		ProjectSettings.globalize_path("user://").simplify_path(),
		ProjectSettings.globalize_path("res://").simplify_path(),
		ProjectSettings.globalize_path(SeasonSave.path).get_base_dir().simplify_path()
	]
	for directory: String in protected:
		if root == directory or root.begins_with(directory.trim_suffix("/") + "/"):
			return {}
	# Reject filesystem aliases, including aliases in any parent of the explicit root.
	var component: String = root
	while component.length() > 1:
		var parent: DirAccess = DirAccess.open(component.get_base_dir())
		if parent == null or parent.is_link(component.get_file()):
			return {}
		component = component.get_base_dir()
	var directory: DirAccess = DirAccess.open(root)
	for suffix: String in ["", ".bak", ".tmp"]:
		if directory.is_link("league-career.json" + suffix):
			return {}
	for suffix: String in OwnerStore.SUFFIXES + [".objects"]:
		if directory.is_link("dynasty-career.json" + suffix):
			return {}
	return {
		"root": root, "path": root.path_join("league-career.json"),
		"owner": root.path_join("dynasty-career.json")
	}


static func owner_evidence(path: String) -> bool:
	for suffix: String in OwnerStore.SUFFIXES:
		if FileAccess.file_exists(path + suffix) or DirAccess.dir_exists_absolute(path + suffix):
			return true
	return false


func _make_dynasty_owner_controller() -> RefCounted:
	return DynastyController.new(self)


func _ready() -> void:
	var chosen: Dictionary = launch_arguments(OS.get_cmdline_user_args())
	if chosen.is_empty() or SeasonSave.dynasty_owner_bound():
		_blocked()
		return
	_original_save_path = SeasonSave.path
	_candidate_path = chosen.path
	candidate_owner_path = chosen.owner
	SeasonSave.path = _candidate_path
	league_career = Controller.new(self, _candidate_path)
	dynasty_enrollment = DynastyEnrollment.new(self, candidate_owner_path)
	if owner_evidence(candidate_owner_path):
		var found: Dictionary = OwnerStore.inspect(candidate_owner_path)
		var owner: Dictionary = found.get("owner", {})
		if owner.is_empty():
			owner = found.get("pending", {})
		if owner.get("version") != 2:
			_blocked("Existing owner evidence could not be qualified as this shared career. "
				+ "No older candidate or owner-v1 save was opened or replaced.")
			return
		SeasonSave.bind_dynasty_owner(candidate_owner_path)
	_candidate_ready = true
	super._ready()


func _exit_tree() -> void:
	super._exit_tree()
	if not _candidate_path.is_empty() and SeasonSave.path == _candidate_path:
		SeasonSave.path = _original_save_path
	if not candidate_owner_path.is_empty() and SeasonSave._dynasty_owner_path == candidate_owner_path:
		SeasonSave._dynasty_owner_path = ""
		SeasonSave._dynasty_owner_content_blocked = false


func _process(delta: float) -> void:
	if _candidate_ready:
		super._process(delta)


func _league_career_home(parent: Node) -> void:
	SeasonPages.wrapped(parent, "LEAGUE CAREER PLAYTEST • Separate candidate save")
	if SeasonSave.dynasty_owner_bound():
		dynasty_owner.add_controls(menu, parent)
		return
	if dynasty_enrollment.pending():
		menu._button(parent, "REVIEW DYNASTY START", DynastyUI.enrollment.bind(self))
		return
	menu._button(parent, "CHOOSE LEAGUE", ask_new_season)
	var unlocked: bool = "dynasty" in league_career.available_leagues()
	var start: Button = menu._button(parent, "START DYNASTY WITH THIS ROSTER", _prepare_dynasty)
	start.disabled = not unlocked or season == null or season.career == null \
		or season.picks.size() != 4
	start.tooltip_text = "Finish a four-player draft first. Enrollment is reviewed before it saves." \
		if unlocked else CareerUI.Unlocks.requirement("dynasty")
	if not unlocked:
		SeasonPages.wrapped(parent, "DYNASTY LOCKED • " + CareerUI.Unlocks.requirement("dynasty"))


func _prepare_dynasty() -> void:
	if dynasty_enrollment.prepare(int(Time.get_unix_time_from_system()) & 0x7fffffff):
		DynastyUI.enrollment(self)
	else:
		menu.show_home()


func _show_league_career_record(page: int = 0) -> void:
	if SeasonSave.dynasty_owner_bound():
		DynastyUI.record(self, page)
	else:
		CareerUI.record(self, page)


func _candidate_players_enabled() -> bool:
	if SeasonSave.dynasty_owner_bound():
		return not candidate_owner_path.is_empty() \
			and SeasonSave._dynasty_owner_path == candidate_owner_path and dynasty_owner.ready()
	return season != null and season.career != null and not season.player_access.is_empty()


func _player_collection_view() -> Dictionary:
	if not _candidate_players_enabled():
		return {}
	return DynastyPlayers.view(self) if SeasonSave.dynasty_owner_bound() \
		else ClubPlayersUI.career_view(season.career)


func _player_collection_transact(request: Dictionary) -> Dictionary:
	if not _candidate_players_enabled():
		return ClubAssetLedger._error("Recover the saved career before changing player ownership.")
	return DynastyPlayers.transact(self, request) if SeasonSave.dynasty_owner_bound() \
		else league_career.player_transaction(request)


func _shared_career_badge(parent: Node) -> bool:
	if not SeasonSave.dynasty_owner_bound():
		return false
	DynastyUI.badge(self, parent)
	return true


func _shared_career_settlement() -> bool:
	if not SeasonSave.dynasty_owner_bound():
		return false
	DynastyUI.settlement(self)
	return true


func _dynasty_career_summary() -> bool:
	if not SeasonSave.dynasty_owner_bound():
		return false
	SeasonPages.wrapped(menu._body,
		"Completed results and shared Club Bucks save together. Continue Dynasty or choose an alternate.")
	return true


func show_season() -> void:
	if SeasonSave.dynasty_owner_bound() and dynasty_owner.ready():
		var owner: Dictionary = dynasty_owner.found().owner
		var entry: Dictionary = owner.career.sessions[owner[owner.selected].session_id]
		if entry.settled > 0 and season.phase != SeasonState.Phase.COMPLETE:
			menu.show_home()
			return
	super.show_season()


func ask_new_season() -> void:
	if dynasty_enrollment.pending():
		DynastyUI.enrollment(self)
	elif SeasonSave.dynasty_owner_bound():
		DynastyUI.show(self)
	else:
		CareerUI.show(self)


func ask_progression_season(_selected_tier: int = 0) -> void:
	# No accidental Standard ladder entry from shared career pages in this candidate.
	ask_new_season()


func choose_player(id: String) -> void:
	if SeasonSave.dynasty_owner_bound():
		dynasty_owner.draft_pick(id)
	else:
		league_career.draft_pick(id)
	show_season()


func _blocked(reason: String = "") -> void:
	set_process(false)
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = ClubhouseTheme.create()
	canvas.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	SeasonMenu._label(box, "LEAGUE CAREER PLAYTEST • NOT OPENED", 28)
	SeasonPages.wrapped(box, reason if not reason.is_empty() else (
		"Provide one --league-career-candidate-root= pointing to an existing, separate test "
		+ "directory outside the game and ordinary save folders. No save was opened. "
		+ "Existing owner-v1 saves are not migrated by this scene."
	))
	var quit: Button = Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(get_tree().quit)
	box.add_child(quit)
