extends "res://src/tests/paid_shop_ui_test.gd"

const GearFixture = preload("res://src/tests/season_gear_test.gd")
const EarnedFixture = preload("res://src/tests/season_earned_sponsor_test.gd")
const TacticalFixture = preload("res://src/tests/season_tactical_test.gd")
var _app: SeasonApp


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://loadout-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://loadout-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	_check(not _app.loadout.entry.visible, "no misleading inventory before a club exists")
	await _menus_and_shop()
	await _sponsors_in_match()
	await _supplies_in_match()
	await _gear_purchase_refresh()
	_app.queue_free()
	await _frames()
	_check(not get_tree().paused, "teardown never leaves the tree paused")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro loadout UI checks passed: shared entry, modal, live inventory and pause safety."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _menus_and_shop() -> void:
	var fixture: Node = EarnedFixture.new()
	var pair: Array[String] = ["E05", "G05"]
	var hits: Array[String] = ["single", "double"]
	_app.season = fixture._paid(pair)
	fixture._result(_app.season, hits)
	_check(fixture._failures == 0 and SeasonSave.save(_app.season), "real paid stamped inventory")
	fixture.free()
	var before: Dictionary = _app.season.build.to_data()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var ui: SeasonLoadoutUI = _app.loadout
	_app.show_season()
	await _frames()
	var position: Vector2 = ui.entry.position
	for page: Callable in [
		_app.menu.show_home,
		_app.menu.show_hub,
		_app.menu.show_lineup,
		_app.menu.show_players,
		_app.menu.show_stats
	]:
		page.call()
		await _frames()
		_check(
			ui.entry.visible and ui.entry.position == position, "same entry position across menus"
		)
		_check(
			not ui.entry.get_global_rect().intersects(_app.menu._footer.get_global_rect()),
			"shared entry has reserved space outside season navigation"
		)
	await _click(ui.entry)
	_check(ui.shade.visible, "actual equipped click opens lightbox")
	_check(ui.get_viewport().gui_get_focus_owner() == ui.close_button, "modal starts on Close")
	await _bounds(ui, "loadout-gear-default")
	_check(ui._rows.gear.size() == 3, "all three gear slots present even when standard")
	await _click(ui._tab_buttons[1])
	_check(ui._rows.sponsors.size() == 2, "owned sponsors shown")
	_check(_text(ui.body).contains("2 / 4 stamps"), "copy-specific stamp count is visible")
	await _bounds(ui, "loadout-sponsors")
	for index in range(10):
		await _key(KEY_TAB)
		var focused: Control = get_viewport().gui_get_focus_owner()
		_check(ui.panel.is_ancestor_of(focused), "keyboard focus stays inside modal")
	for index in range(8):
		await _key(KEY_DOWN)
		_check(
			ui.panel.is_ancestor_of(get_viewport().gui_get_focus_owner()),
			"directional focus never reaches background menus"
		)
	var cancel: InputEventJoypadButton = InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	get_viewport().push_input(cancel, true)
	cancel = cancel.duplicate()
	cancel.pressed = false
	get_viewport().push_input(cancel, true)
	await _frames()
	_check(not ui.shade.visible and not get_tree().paused, "controller Cancel closes only loadout")
	_check(get_viewport().gui_get_focus_owner() == ui.entry, "menu focus returns to equipped entry")
	await _click(ui.entry)
	await _outside(ui)
	_check(not ui.shade.visible, "outside click dismisses modal")
	_check(_app.season.build.to_data() == before, "inspection is read-only")
	_check(FileAccess.get_file_as_string(SeasonSave.path) == bytes, "inspection never writes save")
	_app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(_app)
	var nested: SeasonLoadoutUI
	for child: Node in window.get_children():
		if child is SeasonLoadoutUI:
			nested = child
	_check(nested != null and ui.entry.disabled, "shop owns the one usable entry")
	for extent: Vector2i in [Vector2i(1000, 650), Vector2i(700, 400)]:
		window.size = extent
		await _frames()
		await _click(nested.entry)
		await _bounds(nested, "loadout-shop-%d" % extent.x)
		await _click(nested._tab_buttons[1])
		await _bounds(nested, "loadout-shop-sponsors-%d" % extent.x)
		await _click(nested.close_button)
		_check(not nested.shade.visible, "shop lightbox closes without leaving shop")
	await _click(window._back)
	await _frames()
	_check(not ui.entry.disabled, "main utility restored after shop close")


func _sponsors_in_match() -> void:
	var ui: SeasonLoadoutUI = _app.loadout
	var entry_position: Vector2 = ui.entry.position
	_app.play_season_game()
	await _frames()
	var lab: PitchBatLab = _app.lab
	_check(lab != null, "real paid match launches")
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(ui.entry.position == entry_position, "game and menu use identical entry coordinates")
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.home_team if lab._player_home else state.away_team
	var before: Dictionary = _app.season.build.to_data()
	await _click(ui.entry)
	_check(get_tree().paused and lab._debug_paused, "opening freezes the entire match")
	var elapsed: float = state.elapsed_seconds
	var camera: Transform3D = lab._camera.global_transform
	var pa: int = state.plate_appearance_number
	await _key(KEY_R)
	await _key(KEY_V)
	for frame in range(12):
		await get_tree().physics_frame
	_check(
		(
			state.elapsed_seconds == elapsed
			and state.plate_appearance_number == pa
			and lab._match_state == state
			and lab._camera.global_transform == camera
		),
		"modal blocks timers, camera and match restart shortcuts"
	)
	await _click(ui._tab_buttons[1])
	_check(_text(ui.body).contains("+2% Contact exit this game"), "match shows frozen game stamps")
	team.encore_used = true
	await _click(ui.close_button)
	_check(not get_tree().paused and not lab._debug_paused, "closing resumes prior running state")
	_check(
		get_viewport().gui_get_focus_owner() == null,
		"Space returns to gameplay, not utility button"
	)
	await _click(ui.entry)
	await _click(ui._tab_buttons[1])
	_check(
		_text(ui.body).contains("Return used this game"), "Encore availability reflects live use"
	)
	await _bounds(ui, "loadout-live-sponsors")
	await _key(KEY_ESCAPE)
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	await _frames()
	await _click(ui.entry)
	await _key(KEY_ESCAPE)
	_check(get_tree().paused and lab._debug_paused, "inspection preserves an existing pause")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	_check(_app.season.build.to_data() == before, "live inspection never changes season inventory")
	_app.leave_game()
	await _frames()
	_app.play_exhibition()
	await _frames()
	await _click(ui.entry)
	_check(ui._rows.sponsors.is_empty(), "exhibition never borrows saved season sponsors")
	await _click(ui.close_button)
	_app.leave_game()
	await _frames()


func _supplies_in_match() -> void:
	var fixture: Node = TacticalFixture.new()
	_app.season = fixture._paid_tactics(["A10", "C02"])
	for id: String in ["A10", "C02"]:
		_check(
			(
				_app
				. season
				. build
				. commit(
					fixture._command(
						_app.season.build,
						"tactical_buy",
						{"offer": fixture._offer(_app.season.build, id)}
					)
				)
				. ok
			),
			"buy real tactical supply"
		)
	_check(fixture._failures == 0 and SeasonSave.save(_app.season), "paid supplies saved")
	fixture.free()
	_app.show_season()
	_app.play_season_game()
	await _frames()
	var lab: PitchBatLab = _app.lab
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.home_team if lab._player_home else state.away_team
	var ui: SeasonLoadoutUI = _app.loadout
	var before: Dictionary = _app.season.build.to_data()
	state.top_half = lab._player_home
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	team.current_pitcher().spend_stamina(25)
	var recovery: String = ""
	for receipt: Dictionary in team.tactics.held:
		if receipt.item == "C02":
			recovery = receipt.id
	_check(team.tactics.activate(state, team, recovery), "ordinary runtime use consumes paid copy")
	await _click(ui.entry)
	await _click(ui._tab_buttons[2])
	_check(
		ui._rows.supplies.size() == 1 and ui._rows.used.size() == 1, "spent copy leaves held count"
	)
	_check(_text(ui.body).contains("Used this game"), "spent supply stays clearly labeled")
	await _bounds(ui, "loadout-live-supplies")
	await _click(ui.close_button)
	lab._pitch_target = lab.DEFAULT_TARGET
	PitchBatLabFeelSupport.begin_pitch_release(lab)
	_check(lab._release_controller.active, "uncommitted delivery starts")
	await _click(ui.entry)
	_check(not lab._release_controller.active, "opening inspection cancels uncommitted delivery")
	await _click(ui.close_button)
	PitchBatLabFeelSupport.begin_pitch_release(lab)
	lab._release_controller.elapsed_seconds = PitchReleaseController.IDEAL_RELEASE_SECONDS
	PitchBatLabFeelSupport.commit_pitch_release(lab)
	await get_tree().physics_frame
	_check(lab._pitch_actor.running, "real pitch actor is in flight")
	await _click(ui.entry)
	var pitch_time: float = lab._pitch_actor.state.elapsed_time
	for frame in range(15):
		await get_tree().physics_frame
	_check(
		lab._pitch_actor.state.elapsed_time == pitch_time,
		"live pitch physics freezes under lightbox"
	)
	await _key(KEY_ESCAPE)
	for frame in range(4):
		await get_tree().physics_frame
	_check(lab._pitch_actor.state.elapsed_time > pitch_time, "same pitch resumes after close")
	_check(_app.season.build.to_data() == before, "incomplete live use has not spent saved supply")
	await _click(ui.entry)
	_app.leave_game()
	await _frames()
	_check(
		not get_tree().paused and not ui.shade.visible, "leaving with modal open safely tears down"
	)
	_check(
		SeasonSave.restore().build.view().wallet.held.size() == 2,
		"unfinished game restores paid bag"
	)


func _gear_purchase_refresh() -> void:
	var fixture: Node = EarnedFixture.new()
	var gear: Node = GearFixture.new()
	_app.season = fixture._funded_season(gear._two_bats(true).to_data().seed)
	_check(SeasonSave.save(_app.season), "funded Gear fixture saved")
	_app.show_season()
	_app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(_app)
	var offer: String = gear._gear_offer(_app.season.build, "bat")
	var item: String = _app.season.build.view().shop.offers[offer]
	await _click(gear._gear_button(window, "gear_offer", offer))
	await _click(window._confirm.get_ok_button())
	var nested: SeasonLoadoutUI
	for child: Node in window.get_children():
		if child is SeasonLoadoutUI:
			nested = child
	await _click(nested.entry)
	await _click(nested._tab_buttons[0])
	_check(
		_text(nested.body).contains(SeasonGearCatalog.item(item).name),
		"successful real shop purchase immediately appears in shared loadout"
	)
	await _bounds(nested, "loadout-purchased-gear")
	await _click(nested.close_button)
	await _click(window._back)
	_app.season = SeasonSave.restore()
	_app.play_season_game()
	await _frames()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	await _click(_app.loadout.entry)
	await _click(_app.loadout._tab_buttons[0])
	_check(
		_text(_app.loadout.body).contains(SeasonGearCatalog.item(item).name),
		"reloaded paid Gear reaches the same in-game lightbox"
	)
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == bytes,
		"Gear inspection does not rewrite the paid save"
	)
	await _click(_app.loadout.close_button)
	_app.leave_game()
	await _frames()
	_check(fixture._failures == 0 and gear._failures == 0, "valid Gear fixture")
	fixture.free()
	gear.free()


func _bounds(ui: SeasonLoadoutUI, stage: String) -> void:
	await _frames()
	var bounds: Rect2 = ui.get_viewport().get_visible_rect()
	print("LOADOUT_LAYOUT ", stage, " viewport=", bounds, " panel=", ui.panel.get_global_rect())
	_check(bounds.encloses(ui.entry.get_global_rect()), "entry remains visible: " + stage)
	_check(bounds.encloses(ui.panel.get_global_rect()), "lightbox fits viewport: " + stage)
	_check(
		ui.panel.get_global_rect().encloses(ui.close_button.get_global_rect()),
		"Close stays visible"
	)
	_check(
		ui.panel.get_global_rect().encloses(ui.scroll.get_global_rect()),
		"content scroll stays inside"
	)
	for node: Node in ui.body.find_children("*", "Control", true, false):
		var rect: Rect2 = node.get_global_rect()
		_check(
			(
				rect.position.x >= ui.panel.position.x
				and rect.end.x <= ui.panel.get_global_rect().end.x
			),
			"no horizontal clipping: " + stage
		)
	await _capture(ui.get_viewport(), stage)


func _outside(ui: SeasonLoadoutUI) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(4, 4)
	event.pressed = true
	ui.get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	ui.get_viewport().push_input(event, true)
	await _frames()


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames()


func _text(parent: Node) -> String:
	var result: String = ""
	for child: Node in parent.find_children("*", "Label", true, false):
		result += child.text + "\n"
	return result
