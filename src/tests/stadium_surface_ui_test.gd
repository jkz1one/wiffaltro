extends "res://src/tests/stadium_infield_ui_test.gd"
## Actual new-club launch and paid surface flow; closed synthetic career isolates purchase gates.

var _terrain_mode: bool = false
var _terrain_checks: int = 0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--surface-terrain"):
		_terrain_mode = true
		await _terrain_ui()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://surface-ui-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.ask_progression_season()
	await _click(app._dialog.get_ok_button())
	_check(
		app.season != null and app.season.home_property.get("version") == 8,
		"explicit current new-club path creates the rough-dirt family"
	)
	if app.season == null or app.season.home_property.get("version") != 8:
		get_tree().quit(1)
		return
	_check(
		(
			app.season.home_property.layout.surface.foundation == "dirt"
			and ClubPlayers.assets(app.season.career).surface_owned().is_empty()
		),
		"no free grass or grading"
	)
	StadiumEditorUI.show(app.menu)
	await _bounds(app, "rough-dirt-starter")
	_check(_surface_buy(app, "grass").disabled, "new club cannot spend unearned money")
	app.season = _fund_surface()
	app.begin_season(96, true)
	var season: SeasonState = app.season
	_check(
		season.phase == SeasonState.Phase.DRAFT and SeasonSave.restore() != null,
		"ordinary new-season boundary durably admits the synthetic historical rough fixture"
	)
	StadiumEditorUI.show(app.menu)
	var before: Dictionary = SeasonSave.snapshot(season)
	var funded_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	_check(
		(
			not ClubConstruction.buy_surface(season, "grass", 0).ok
			and ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(SeasonSave.path) == funded_bytes
		),
		"stale surface receipt rejects without wallet, earned inventory or file mutation"
	)
	await _click(_surface_buy(app, "grass"))
	_check(
		app._dialog.visible and app._dialog.dialog_text.contains("120"), "exact grass confirmation"
	)
	await _click(app._dialog.get_cancel_button())
	_check(
		ClubCareer.same(before, SeasonSave.snapshot(season)), "cancel preserves wallet and field"
	)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_surface_buy(app, "grass"))
	await _click(app._dialog.get_ok_button())
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
		),
		"failed purchase preserves file and profile"
	)
	SeasonSave.path = path
	var balance: int = season.career.balance()
	await _click(_surface_buy(app, "grass"))
	await _click(app._dialog.get_ok_button())
	_check(
		(
			season.career.balance() == balance - 120
			and ClubConstruction.buy_surface(season, "grass", 20).replayed
		),
		"one permanent grass purchase, duplicate confirmation is harmless"
	)
	_check(
		season.home_property.layout.surface.foundation == "dirt", "purchase is not automatic apply"
	)
	await _surface_pick(app, "foundation", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(
		season.home_property.layout.surface.foundation == "grass",
		"grass installs through saved draft"
	)
	await _surface_pick(app, "height", 3)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.home_property.layout.surface.height == "long", "owned length swaps are free")
	await _click(_surface_buy(app, "ground_prep"))
	await _click(app._dialog.get_ok_button())
	_check(season.career.balance() == balance - 200, "ground preparation is a separate exact debit")
	await _surface_pick(app, "foundation", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(
		(
			season.home_property.layout.surface.foundation == "dirt"
			and season.home_property.layout.surface.condition == "prepared"
		),
		"maintained dirt remains usable"
	)
	await _bounds(app, "prepared-dirt-workshop")
	await _surface_pick(app, "foundation", 2)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	for id: String in ["ST-063b", "ST-063g"]:
		await _click(_style_buy(app, id))
	await _pick_style(app, "grass", 1)
	await _pick_style(app, "ground", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	await _bounds(app, "owned-fine-grass")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _bounds(app, "surface-workshop-small")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	_check(
		(
			SeasonSave.restore() != null
			and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key
		),
		"exact saved restart"
	)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(
		not (
			ClubConstruction
			. buy_surface(season, "grass", ClubPlayers.assets(season.career).revision())
			. ok
		),
		"surface purchases close when drafting starts"
	)
	for fixture: Dictionary in season.schedule:
		if fixture.home != 0:
			continue
		app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
		_check(app.lab != null, "real owned-surface home game opens")
		if app.lab != null:
			var property: Node3D = app.lab.get_meta("stadium_property")
			_check(property.has_node("OwnedSurfaceFinish"), "runtime installs the paid finish")
			await _frames()
			await _capture(get_viewport(), "owned-surface-home")
			app._close_match()
		break
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro surface UI checks passed: starter, purchases, save/apply and actual home.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund_surface() -> SeasonState:
	var completed: SeasonState = _fund_infield()
	# Synthetic historical rough-origin declaration, not a current-user migration.
	# Preserve every funded Club Buck and earned receipt instead of replacing the journal.
	var original: Dictionary = completed.career._assets.duplicate(true)
	var rough: Dictionary = original.duplicate(true)
	rough.surface_origin = StadiumSurfaceProgression.ROUGH_ORIGIN
	completed.career._assets = rough
	var ledger: ClubAssetLedger = ClubPlayers.assets(completed.career)
	_check(ledger != null, "historical rough declaration retains authoritative earned journal")
	if ledger == null:
		return completed
	_check(
		(
			ledger.revision() == 20
			and ledger.construction().copies.size() == 23
			and completed.career.balance() == 3925
			and ledger.surface_owned().is_empty()
			and ClubCareer.same(ledger.to_data().events, original.events)
		),
		"rough fixture preserves twenty pennants, exact income and no free surface access"
	)
	for event: Dictionary in ledger.to_data().events:
		_check(
			event.op == "stadium_pennant", "only original earned events fund the synthetic fixture"
		)
	completed.home_property = StadiumLayoutSnapshot.capture(ledger)
	_check(
		(
			completed.home_property.get("version") == 8
			and completed.home_property.layout.version == 12
		),
		"synthetic historical rough declaration preserves the intended flat family"
	)
	return completed


func _surface_buy(app: SeasonApp, item: String) -> Button:
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta("surface_buy", "") == item:
			return button
	_check(false, "surface purchase button exists")
	return null


func _surface_pick(app: SeasonApp, channel: String, index: int) -> void:
	for choice: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
		if choice.get_meta("surface_choice", "") == channel:
			_check(not choice.disabled, "owned surface selector is enabled")
			var previous: int = choice.selected
			choice.grab_focus()
			await _frames()
			await _key(KEY_ENTER)
			for step in range(absi(index - previous)):
				await _key(KEY_DOWN if index > previous else KEY_UP)
			await _key(KEY_ENTER)
			await _frames()
			return
	_check(false, "surface selector exists")


func _check(ok: bool, message: String) -> void:
	if _terrain_mode:
		_terrain_checks += 1
	super._check(ok, message)


func _terrain_press(app: SeasonApp, label: String) -> void:
	var button: Button = _button(app.menu, label)
	_check(
		button != null and not button.disabled, "ordinary terrain UI action is enabled: " + label
	)
	if button != null and not button.disabled:
		button.pressed.emit()
	await _frames()


func _terrain_ui() -> void:
	var prior_path: String = SeasonSave.path
	var prior_error: String = SeasonSave.last_error
	var path: String = "user://surface-terrain-ui-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	var completed: SeasonState = _fund_surface()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = completed
	app.begin_season(96, true)
	var season: SeasonState = app.season
	_check(
		(
			season != null
			and season.phase == SeasonState.Phase.DRAFT
			and season.home_property.get("version") == 8
		),
		"retained valid pre-draft flat season"
	)
	if season == null or season.home_property.get("version") != 8:
		await _terrain_ui_finish(app, path, prior_path, prior_error)
		return
	var original: Dictionary = SeasonSave.snapshot(season)
	var balance: int = season.career.balance()
	StadiumEditorUI.show(app.menu)
	await _terrain_press(app, "PREVIEW PLAYABLE DIRT TERRAIN")
	_check(
		ClubCareer.same(original, SeasonSave.snapshot(season)), "preview does not opt in or charge"
	)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(not DirAccess.dir_exists_absolute(path + "/missing"), "failure target is already absent")
	SeasonSave.path = path + "/missing/file.json"
	await _terrain_press(app, "SAVE DRAFT")
	_check(
		(
			ClubCareer.same(original, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
			and not FileAccess.file_exists(SeasonSave.path + ".tmp")
		),
		"failed draft preserves raw save and state"
	)
	SeasonSave.path = path
	StadiumEditorUI.show(app.menu)
	await _terrain_press(app, "PREVIEW PLAYABLE DIRT TERRAIN")
	await _terrain_press(app, "SAVE DRAFT")
	_check(
		season.home_property.version == 8 and _terrain_history(ClubPlayers.assets(season.career)),
		"saved explicit draft alone keeps installed flat field"
	)
	await _terrain_press(app, "APPLY LAYOUT")
	_check(
		season.home_property.get("version") == 28 and season.career.balance() == balance,
		"actual existing apply callback installs free rough terrain"
	)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			saved.version == 74
			and saved.terrain_save_version == original.version
			and restored != null
			and ClubCareer.same(SeasonSave.snapshot(restored), saved)
		),
		"Save74 wraps exact ordinary Base context and cold decodes"
	)
	var bad: Dictionary = saved.duplicate(true)
	bad.version = int(bad.terrain_save_version)
	bad.erase("terrain_save_version")
	_check(SeasonSave._decode(bad) == null, "old save cannot smuggle terrain history")
	bad = saved.duplicate(true)
	bad.terrain_save_version = 74
	_check(SeasonSave._decode(bad) == null, "recursive terrain envelopes refuse")
	app.begin_surface_time_season("night", 97)
	_check(
		app.season == season and ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"active rough terrain refuses new dark-profile entry without mutation"
	)
	_check(
		(
			ClubConstruction
			. buy_surface(season, "ground_prep", ClubPlayers.assets(season.career).revision())
			. ok
		),
		"existing preparation purchased exactly once"
	)
	StadiumEditorUI.show(app.menu)
	var choice: OptionButton = null
	for node: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
		if node.get_meta("terrain_choice", false):
			choice = node
	_check(
		choice != null and choice.item_count == 2 and not choice.disabled,
		"owned leveling appears in actual selector"
	)
	if choice != null:
		choice.select(1)
		choice.item_selected.emit(1)
	await _frames()
	await _terrain_press(app, "SAVE DRAFT")
	await _terrain_press(app, "APPLY LAYOUT")
	_check(
		season.home_property.terrain.mode == "leveled" and season.career.balance() == balance - 80,
		"leveling applies with no second charge"
	)
	await _terrain_owner_refusal(app, season)
	StadiumEditorUI.show(app.menu)
	await _terrain_press(app, "PREVIEW FLAT DIRT")
	await _terrain_press(app, "SAVE DRAFT")
	await _terrain_press(app, "APPLY LAYOUT")
	_check(
		season.home_property.version == 8 and _terrain_history(ClubPlayers.assets(season.career)),
		"ordinary flat return preserves the actual terrain journal history"
	)
	_terrain_future_profile(app, season)
	await _terrain_ui_finish(app, path, prior_path, prior_error)


func _terrain_owner_refusal(app: SeasonApp, season: SeasonState) -> void:
	# Detached configured lab only. No season cursor/result/save or actual game advances.
	var before: Dictionary = SeasonSave.snapshot(season)
	var clone: SeasonState = SeasonSave._decode(before)
	if clone == null:
		_check(false, "detached setup cold decode")
		return
	for index in range(4):
		if clone.offers().is_empty() or not clone.choose_player(clone.offers()[0]):
			_check(false, "detached setup ordinary draft")
			return
	var fixture: Dictionary = {}
	for row: Dictionary in clone.schedule:
		if row.home == 0:
			fixture = row
			break
	var state: MatchState = SeasonPhysicalFixtures.match_for(clone, fixture)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = state
	lab._stadium_ledger = ClubPlayers.assets(clone.career)
	lab._managed_match = true
	lab._player_home = true
	if not StadiumSurfaceTerrainRuntime.configure(lab, lab._stadium_ledger):
		_check(false, "detached terrain request binds before attachment")
		lab.free()
		return
	var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	lab.set_physics_process(false)
	app.add_child(lab)
	var helper: Node = load("res://src/tests/stadium_surface_night_gameplay_a_test.gd").new()
	helper._pause(lab)
	helper.free()
	_check(
		StadiumSurfaceTerrainRuntime.installed_bound(lab, state.stadium),
		"configured terrain owner installs before any physics advance"
	)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: Node = lab.get_meta("stadium_property")
	var visual: MeshInstance3D = property.get_node("OwnedSurfaceTerrain/TerrainVisual")
	var foreign: ArrayMesh = visual.mesh.duplicate(true)
	visual.mesh = foreign
	var old_lab: PitchBatLab = app.lab
	var home: Dictionary = season.home_property
	var venues: Dictionary = season.npc_venues
	app.lab = lab
	season.home_property = {}
	season.npc_venues = {}
	app._verify_match_install(state, false)
	_check(
		(
			owner.phase == StadiumSurfaceTerrainRuntime.Phase.ABANDONED
			and app.lab == lab
			and not app._played_field_matches()
			and not StadiumSurfaceTerrainRuntime.installed_bound(lab, state.stadium)
			and visual.mesh == foreign
		),
		"mount and sticky completion refuse replaced mesh without touching foreign resources"
	)
	season.home_property = home
	season.npc_venues = venues
	app.lab = old_lab
	_check(
		ClubCareer.same(before, SeasonSave.snapshot(season)),
		"replacement refusal preserves exact source season/history"
	)
	lab.free()


func _terrain_future_profile(app: SeasonApp, season: SeasonState) -> void:
	# Same ordinary paid commands and exact eligible composition as the existing night fixture.
	# The twenty-title funding is already labeled synthetic by _fund_surface; no new history is
	# inserted.
	var ok: bool = (
		ClubConstruction
		. buy_surface(season, "grass", ClubPlayers.assets(season.career).revision())
		. ok
	)
	ok = (
		(
			ClubConstruction
			. buy_land(season, "expanded", ClubPlayers.assets(season.career).revision())
			. ok
		)
		and ok
	)
	for index in range(4):
		ok = (
			(
				ClubConstruction
				. buy_copy(season, "ST-037", ClubPlayers.assets(season.career).revision())
				. ok
			)
			and ok
		)
	for item: String in ["ST-063b", "ST-063i"]:
		ok = (
			(
				ClubConstruction
				. buy_style(season, item, ClubPlayers.assets(season.career).revision())
				. ok
			)
			and ok
		)
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	var layout: Dictionary = paid.view().stadium_active.duplicate(true)
	layout.surface = StadiumSurfaceProgression.selection(paid.surface_owned(), true)
	layout.styles.grass = "ST-063b"
	layout.ground = "ST-063i"
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	var copies: Array = []
	for copy: String in paid.construction().copies:
		if paid.construction().copies[copy].item == "ST-037":
			copies.append(copy)
	copies.sort()
	if copies.size() != 4:
		_check(false, "four exact paid lamp copies exist")
		return
	for index in range(4):
		layout.lights.append({"copy": copies[index], "site": sites[index]})
	ok = ClubConstruction.save_draft(season, layout, paid.revision()).ok and ok
	ok = (
		(
			ClubConstruction
			. apply_draft(season, layout, ClubPlayers.assets(season.career).revision())
			. ok
		)
		and ok
	)
	_check(
		(
			ok
			and season.home_property.version == 8
			and _terrain_history(ClubPlayers.assets(season.career))
		),
		"ordinary paid return to eligible flat composition keeps terrain history"
	)
	if not ok:
		return
	app.begin_surface_time_season("night", 98)
	var data: Dictionary = SeasonSave.snapshot(app.season)
	var cold: SeasonState = SeasonSave.restore()
	print(
		"TERRAIN_FUTURE_PROFILE ",
		JSON.stringify(
			{
				"changed_season": app.season != season,
				"version": data.get("version"),
				"base": data.get("terrain_save_version"),
				"mode": data.get("owned_surface_night", {}).get("mode"),
				"cold": cold != null,
				"same": cold != null and ClubCareer.same(data, SeasonSave.snapshot(cold)),
				"restore_error": SeasonSave.last_error
			}
		)
	)
	_check(
		(
			app.season != season
			and data.get("version") == 74
			and data.get("terrain_save_version") == 73
			and data.get("owned_surface_night", {}).get("mode") == "night"
			and cold != null
			and ClubCareer.same(data, SeasonSave.snapshot(cold))
		),
		"future flat profile73 survives actual earned/terrain journal28 and Save74 cold replay"
	)
	var original_career: ClubCareer = app.season.career
	_check(
		SeasonSave.save(app.season) and app.season.career == original_career,
		"equivalent wrapped night save retains its existing career identity"
	)
	var stripped: Dictionary = data.duplicate(true)
	stripped.version = 73
	stripped.erase("terrain_save_version")
	_check(
		SeasonSave._decode(stripped) == null, "old profile73 cannot omit terrain-history envelope"
	)


func _terrain_ui_finish(
	app: SeasonApp, path: String, prior_path: String, prior_error: String
) -> void:
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	SeasonSave.path = prior_path
	SeasonSave.last_error = prior_error
	print(
		(
			"STADIUM_SURFACE_TERRAIN_UI checks=%d failures=%d games=0 synthetic_history=true"
			% [_terrain_checks, _failures]
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _terrain_history(ledger: ClubAssetLedger) -> bool:
	var data: Dictionary = ledger.to_data()
	return (
		data.version == ClubAssetLedger.PENNANT_VERSION
		and data.get("terrain_catalog") == StadiumSurfaceTerrain.signature("rough")
		and data.get("leveled_terrain_catalog") == StadiumSurfaceTerrain.signature("leveled")
		and data.get("pennant_catalog") == StadiumPennantRewards.signature()
		and ledger.construction().pennant_count() == 20
	)
