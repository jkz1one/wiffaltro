extends Node
## Actual viewport input and layout checks. Optional native captures require a display.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	await _exercise()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro paid shop UI checks passed: input, focus, bounds, reload and match handoff."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _exercise() -> void:
	var prefix: String = "user://paid-shop-ui-%d" % OS.get_process_id()
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	await _click(_button(app.menu, "NEW WORKING SEASON"))
	_check(app._dialog.visible, "Working season requires the explicit replacement warning")
	await _click(app._dialog.get_cancel_button())
	_check(not app._dialog.visible, "Cancel closes the new-season modal")
	_check(app.season == null, "cancelling new-season warning preserves the current state")
	app.begin_season(61, true)
	await _menu_bounds(app, "working-draft")
	for _pick in range(4):
		app.choose_player(app.season.offers()[0])
	await _menu_bounds(app, "working-hub")
	app.menu.show_lineup()
	await _menu_bounds(app, "working-lineup")
	app.menu.show_players()
	await _menu_bounds(app, "working-players")
	var fixture: Dictionary = app.season.pending_fixture()
	_check(
		app.season.record_player_result(
			fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0
		),
		"earn income"
	)
	_check(app._checkpoint(), "save earned result before shopping")
	app.show_season()
	await _frames()
	await _click(_button(app.menu, "SEASON SHOP"))
	var window: SeasonShopWindow = _shop(app)
	_check(window != null, "hub button opens the real shop")
	if window == null:
		app.queue_free()
		return
	await _shop_bounds(window, "shop-normal")
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "shop-narrow")
	var offer: String = ""
	for key: String in app.season.build.view().shop.offers:
		if DevelopmentShopCatalog.CARDS.has(app.season.build.view().shop.offers[key]):
			offer = key
			break
	var item_id: String = app.season.build.view().shop.offers[offer]
	var before: Dictionary = app.season.build.to_data()
	await _click(_offer_button(window, offer))
	await _shop_bounds(window, "shop-targets")
	_check(app.season.build.to_data() == before, "opening targeting costs nothing")
	await _click(_button(window._body, "CANCEL TARGETING"))
	_check(app.season.build.to_data() == before, "target cancellation costs nothing")
	await _click(_offer_button(window, offer))
	var target_button: Button = _target_button(window)
	var target: Dictionary = target_button.get_meta("target")
	await _click(target_button)
	_check(
		window._confirm.visible and window._pending.player == target.player,
		"clicked target reaches the exact confirmation"
	)
	_check(
		window._confirm.gui_get_focus_owner() == window._confirm.get_cancel_button(),
		"confirmation starts on cancel, preventing accidental spend"
	)
	_check(window._confirm.size.x <= window.size.x, "confirmation fits the narrow shop width")
	await _capture(window._confirm, "shop-confirmation")
	await _click(window._confirm.get_cancel_button())
	_check(
		window._pending.is_empty() and app.season.build.to_data() == before,
		"actual Cancel input clears the pending transaction"
	)
	await _click(_target_button(window))
	await _click(window._confirm.get_ok_button())
	_check(
		app.season.cash() == 18 - DevelopmentShopCatalog.item(item_id).price,
		"actual confirm input spends exactly the displayed price"
	)
	_check(not app.season.build.view().shop.offers.has(offer), "purchased offer leaves the UI")
	await _shop_bounds(window, "shop-after-purchase")
	await _click(_button(window._body, "Open fixed development pack", true))
	await _click(window._confirm.get_ok_button())
	_check(app.season.build.pack_pending(), "pack is paid before revealing its choices")
	await _shop_bounds(window, "shop-open-pack")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.pack_pending(), "pending pack survives reload")
	await _click(window._back)
	app.season = restored
	app.show_season()
	app.play_season_game()
	await _frames()
	_check(app.lab == null and _shop(app) != null, "pending pack blocks actual next-game launch")
	window = _shop(app)
	await _click(_button(window._body, "Skip this paid pack"))
	await _click(window._confirm.get_ok_button())
	_check(not app.season.build.pack_pending(), "skip resolves the paid pack without a refund")
	await _click(window._back)
	app.play_season_game()
	await _frames(5)
	_check(app.lab != null and not app.menu.visible, "paid build launches the actual next game")
	if app.lab != null:
		var state: MatchState = app.lab._match_state
		var own: TeamMatchState = state.home_team if app.lab._player_home else state.away_team
		for player: PlayerMatchState in own.roster:
			_check(player.definition.progression_test, "live game receives Working definitions")
		app.leave_game()
	await _menu_bounds(app, "return-from-match")
	app.queue_free()
	await _frames()
	for path: String in [prefix + ".json", prefix + ".cfg"]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)


func _shop(app: SeasonApp) -> SeasonShopWindow:
	for child in app.menu.get_children():
		if child is SeasonShopWindow:
			return child
	return null


func _offer_button(window: SeasonShopWindow, offer: String) -> Button:
	for child in window._body.find_children("*", "Control", true, false):
		if child is Button and child.get_meta("offer", "") == offer:
			return child
	return null


func _target_button(window: SeasonShopWindow) -> Button:
	for child in window._body.find_children("*", "Control", true, false):
		if child is Button and child.has_meta("target"):
			return child
	return null


func _button(parent: Node, text: String, prefix: bool = false) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if (
			node.is_visible_in_tree()
			and (node.text.begins_with(text) if prefix else node.text == text)
		):
			return node
	return null


func _click(button: Button) -> void:
	_check(button != null, "requested button exists")
	if button == null:
		return
	# Newly rebuilt pages settle wrapping and deferred focus before scrolling to the target.
	await _frames()
	var clips: Array[ScrollContainer] = []
	var parent: Node = button.get_parent()
	while parent != null and not parent is Window:
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
			clips.append(parent)
		parent = parent.get_parent()
	await _frames()
	var viewport: Viewport = button.get_viewport()
	var point: Vector2 = button.get_global_rect().get_center()
	_check(viewport.get_visible_rect().has_point(point), "clicked button is actually in view")
	for clip: ScrollContainer in clips:
		_check(
			clip.get_global_rect().has_point(point), "clicked button is inside its scroll viewport"
		)
	# Embedded windows receive OS-style mouse input through their containing viewport.
	while viewport is Window and viewport.is_embedded():
		point += Vector2(viewport.position)
		var ancestor: Node = viewport.get_parent()
		while ancestor != null:
			if ancestor is Viewport and ancestor.gui_embed_subwindows:
				break
			ancestor = ancestor.get_parent()
		_check(ancestor != null, "embedded window has an input viewport")
		if ancestor == null:
			return
		viewport = ancestor as Viewport
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	var presses: Array[int] = [0]
	var observe: Callable = func() -> void: presses[0] += 1
	button.pressed.connect(observe)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		viewport.push_input(event, true)
	if presses[0] != 1:
		var hovered: Control = viewport.gui_get_hovered_control()
		_check(
			false,
			(
				"GUI click did not press %s at %s; hovered %s"
				% [button.text, point, str(hovered.get_path()) if hovered != null else "none"]
			)
		)
	if is_instance_valid(button):
		button.pressed.disconnect(observe)
	await _frames()


func _shop_bounds(window: SeasonShopWindow, stage: String) -> void:
	await _frames()
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(window.size))
	_check(bounds.encloses(window._back.get_global_rect()), "Back remains visible: " + stage)
	_check(bounds.encloses(window._scroll.get_global_rect()), "scroll panel fits: " + stage)
	_check(bounds.encloses(window._balance.get_global_rect()), "Cash header stays in view")
	_check(
		window._balance.text == "%d Cash" % window.app.season.cash(),
		"sticky balance agrees with the committed wallet"
	)
	for node in window._body.find_children("*", "Control", true, false):
		var rect: Rect2 = node.get_global_rect()
		_check(
			rect.position.x >= 0 and rect.end.x <= window.size.x,
			"no horizontal clipping at " + stage + ": " + str(node.name)
		)
		if node is Button:
			_check(node.size.y >= 44, "shop action has a usable hit area")
	_check(window.gui_get_focus_owner() != null, "shop has a keyboard focus target")
	var focused: Control = window.gui_get_focus_owner()
	if focused is Button and window._body.is_ancestor_of(focused):
		_check(
			window._scroll.get_global_rect().encloses(focused.get_global_rect()),
			"focused purchase/target stays fully visible after resize: " + stage
		)
	await _capture(window, stage)


func _menu_bounds(app: SeasonApp, stage: String) -> void:
	await _frames()
	_check(
		app.menu.get_global_rect().encloses(app.menu._footer.get_global_rect()),
		"season navigation is visible: " + stage
	)
	for node in app.menu._body.find_children("*", "Control", true, false):
		if node.get_viewport() == app.menu.get_viewport() and node.is_visible_in_tree():
			var rect: Rect2 = node.get_global_rect()
			_check(
				rect.position.x >= 43 and rect.end.x <= 1237,
				"Working menu horizontal bounds: " + stage + ": " + str(node.name)
			)
	await _capture(get_viewport(), stage)


func _capture(viewport: Viewport, stage: String) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "rendered captures require a real display")
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var picture: Image = viewport.get_texture().get_image()
	_check(not picture.is_empty(), "renderer produced pixels: " + stage)
	_check(
		picture.save_png(_capture_dir.path_join(stage + ".png")) == OK,
		"rendered capture saved: " + stage
	)


func _frames(count: int = 3) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
