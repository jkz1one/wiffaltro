extends RefCounted
## Normal-save owner discovery. Evidence always blocks fallback to an archived source.

const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const ENROLLMENT_ENABLED: bool = false
const ENROLLMENT_HOLD: String = "Dynasty enrollment is held until shared careers support Standard's owned fields and all difficulties. Your current season is unchanged."


static func owner_path(source_path: String) -> String:
	return source_path + ".dynasty-owner"


static func evidence(path: String) -> bool:
	for suffix: String in Store.SUFFIXES + [".objects"]:
		if FileAccess.file_exists(path + suffix) or DirAccess.dir_exists_absolute(path + suffix):
			return true
	return false


static func inspect_route(source_path: String, arguments: PackedStringArray) -> Dictionary:
	var path: String = owner_path(source_path)
	var existing: bool = evidence(path)
	var explicit: bool = SeasonSave.dynasty_owner_bound()
	for argument: String in arguments:
		explicit = explicit or argument.begins_with("--closed-dynasty-owner=")
	if explicit:
		return {"route": "blocked", "reason": "Two career owners were selected. No save was opened."} \
			if existing else {"route": "explicit"}
	if not existing:
		return {"route": "ordinary"}
	var found: Dictionary = Store.inspect(path)
	var owner: Dictionary = found.get("owner", {})
	if owner.is_empty():
		owner = found.get("pending", {})
	if owner.get("version") not in [2, 3]:
		return {"route": "blocked", "reason": "Shared-career evidence needs recovery. The archived source was not opened or overwritten. Older Dynasty owners are not migrated automatically."}
	return {"route": "shared"}


static func blocked_screen(app: Node, reason: String) -> void:
	app.set_process(false)
	var canvas: CanvasLayer = CanvasLayer.new()
	app.add_child(canvas)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = ClubhouseTheme.create()
	canvas.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	SeasonMenu._label(box, "CAREER NOT OPENED", 28)
	SeasonPages.wrapped(box, reason)
	var quit: Button = Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(app.get_tree().quit)
	box.add_child(quit)


static func enrollment_enabled(season: SeasonState) -> bool:
	# Historical enrollment gate stays unchanged. The current successor explicitly
	# admits only its implemented no-home context, after the ordinary unlock gate.
	return ENROLLMENT_ENABLED or (season != null and season.career != null and season.build != null
		and season.build.pitch_catalog_current() and season.home_property.is_empty()
		and season._league_home_context.is_empty() and season._standard_live_context.is_empty())
