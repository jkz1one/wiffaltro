extends Node
## Opt-in read-only native presentation of the controlled human/Budget fixture.
## Uses the shipped Equipped UI with a real live team and immutable paid wallet snapshot.

var app: SeasonApp
var display: TextureRect
var label: Label
var capture_dir: String = ""
var paths: Array[String] = []


func setup(
	runner: PhysicalMatchRunner, season: SeasonState, wallet: Dictionary, directory: String
) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture_dir = directory
	get_window().size = Vector2i(1280, 720)
	runner._viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	display = TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = runner._viewport.get_texture()
	add_child(display)
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.layer = 95
	add_child(overlay)
	label = Label.new()
	label.text = "CLOSED DUGOUT TEST • synthetic paid fixture • not public or earned progression"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = Vector2(12, 8)
	overlay.add_child(label)
	# Do not enter SeasonApp's tree: its startup/settlement/save workflow is not part of this preview.
	app = SeasonApp.new()
	app.season = season
	app.lab = runner._lab
	app.lab._player_home = true
	app._season_game = false  # Inspect-only; no live sales or saved-season actions.
	app.menu = SeasonMenu.new()
	app.add_child(app.menu)
	app._dialog = ConfirmationDialog.new()
	app._dialog.hide()
	app.add_child(app._dialog)
	app.loadout = SeasonLoadoutUI.new()
	app.loadout.app = app
	app.loadout.match_snapshot = wallet.duplicate(true)
	add_child(app.loadout)
	await get_tree().process_frame


func capture(name: String, inventory: bool = true) -> bool:
	if capture_dir.is_empty() or not is_instance_valid(app.lab):
		return false
	if inventory:
		app.loadout.open()
		app.loadout._select("supplies")
		if not app.loadout.shade.visible:
			return false
	else:
		app.lab._debug_paused = true
		get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var path: String = capture_dir.path_join(name + ".png")
	var ok: bool = get_viewport().get_texture().get_image().save_png(path) == OK
	if ok:
		paths.append(path)
		print("LEAGUE_NATIVE_CAPTURE ", path)
	if inventory:
		app.loadout.close(false)
	else:
		app.lab._debug_paused = false
		get_tree().paused = false
	return ok


func detach() -> void:
	if app == null:
		return
	if is_instance_valid(app.loadout):
		app.loadout.close(false)
		app.loadout.free()
	app.lab = null
	app.free()
	app = null
