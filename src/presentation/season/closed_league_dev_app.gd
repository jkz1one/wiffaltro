extends "res://src/presentation/season/season_app.gd"
## Explicit scene only. Never configured as the project's main scene.
const Setup = preload("res://src/presentation/season/closed_league_setup_controller.gd")
const DevOwner = preload("res://src/presentation/season/closed_league_dev_owner_controller.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const PlayerCopy = preload("res://src/presentation/season/closed_league_player_copy.gd")
var league_setup: RefCounted
var _closed_dev_ready: bool = false


func _closed_league_notice(message: String) -> String:
	# Render-only projection; app.notice keeps the original diagnostic.
	return PlayerCopy.notice(message)


func _make_dynasty_owner_controller() -> RefCounted:
	# Install the null-safe recovery controls before the inherited first home.
	return DevOwner.new(self)


static func launch_arguments(arguments: PackedStringArray) -> Dictionary:
	var owner_path: String = ""
	var root: String = ""
	var owner_count: int = 0
	var root_count: int = 0
	for argument: String in arguments:
		if argument.begins_with("--closed-dynasty-owner="):
			owner_count += 1
			owner_path = argument.trim_prefix("--closed-dynasty-owner=")
		if argument.begins_with("--closed-league-dev-root="):
			root_count += 1
			root = argument.trim_prefix("--closed-league-dev-root=")
	# Root is an explicit caller-owned isolated test directory. No default owner,
	# file copy, hidden lineage, fallback ordinary restore or automatic creation.
	if (
		owner_count != 1
		or root_count != 1
		or not root.is_absolute_path()
		or root.begins_with("res://")
		or root.begins_with("user://")
		or root.length() < 2
		or root != root.simplify_path()
		or not owner_path.is_absolute_path()
		or owner_path != owner_path.simplify_path()
		or not owner_path.begins_with(root.trim_suffix("/") + "/")
	):
		return {}
	var ordinary: String = ProjectSettings.globalize_path(SeasonSave.path).simplify_path()
	if (
		ordinary == root
		or ordinary.begins_with(root.trim_suffix("/") + "/")
		or not Store._isolated(owner_path)
	):
		return {}
	return {"owner": owner_path, "root": root}


func _ready() -> void:
	var chosen: Dictionary = launch_arguments(OS.get_cmdline_user_args())
	if chosen.is_empty():
		_blocked(
			(
				"Closed League development needs one explicit --closed-dynasty-owner= and "
				+ "--closed-league-dev-root= outside the ordinary save directory."
			)
		)
		return
	if SeasonSave.dynasty_owner_bound() and SeasonSave._dynasty_owner_path != chosen.owner:
		_blocked("A different owner is already bound. Start a separate isolated process.")
		return
	var found: Dictionary = Store.inspect(chosen.owner)
	if (
		found.get("status") not in ["ready", "recoverable", "pending"]
		or found.get("owner", {}).is_empty()
	):
		_blocked(
			(
				"An existing qualified owner is required. No owner will be created or replaced. "
				+ str(found.get("reason", ""))
			)
		)
		return
	if not SeasonSave.bind_dynasty_owner(chosen.owner):
		_blocked("The explicit owner could not be bound; the ordinary save was not opened.")
		return
	super._ready()
	league_setup = Setup.new(self)
	_closed_dev_ready = true
	menu.show_home()


func _process(delta: float) -> void:
	if _closed_dev_ready:
		super._process(delta)


func _blocked(message: String) -> void:
	set_process(false)
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = ClubhouseTheme.create()
	canvas.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	SeasonMenu._label(box, "CLOSED LEAGUE DEVELOPMENT · NOT OPENED", 28)
	SeasonPages.wrapped(box, message)
	var quit: Button = Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(get_tree().quit)
	box.add_child(quit)
