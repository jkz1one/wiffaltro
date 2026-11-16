extends "res://src/tests/stadium_seating_ui_test.gd"
## Real display shop, exact copy movement and read-only in-game scoreboard binding.

var _ground_mode: bool = false
var _ground_checks: int = 0
var _flag_mode: bool = false
var _flag_checks: int = 0


func _ready() -> void:
	if _ground_mode:
		return
	if OS.get_cmdline_user_args().has("--club-flag"):
		_flag_mode = true
		await _flag_ui()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://displays-ui-%d.json" % OS.get_process_id()
	_fund_seating()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(92, true)
	var season: SeasonState = app.season
	StadiumEditorUI.show(app.menu)
	var path: String = SeasonSave.path
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(
		ClubPlayers.assets(season.career).revision() == 4,
		"four earned pennants precede display purchases"
	)
	_check(
		(
			not ClubConstruction.buy_copy(season, "ST-039", 0).ok
			and ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
		),
		"stale pre-award revision cannot spend or change saved display history"
	)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_buy_button(app, "ST-039"))
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
		),
		"failed display payment preserves the profile"
	)
	SeasonSave.path = path
	await _click(_buy_button(app, "ST-039"))
	_check(
		season.career.balance() == 365 and ClubConstruction.buy_copy(season, "ST-039", 4).replayed,
		"actual scoreboard button charges blueprint and copy once"
	)
	await _click(_buy_button(app, "ST-041"))
	await _click(_buy_button(app, "ST-041"))
	var board: String = "purchase:stadium-buy:4:0"
	var left: String = "purchase:stadium-buy:5:0"
	var right: String = "purchase:stadium-buy:6:0"
	_check(season.career.balance() == 215, "second sign pays only its copy cost")
	await _pick_copy(app, board, 1)
	await _pick_copy(app, left, 1)
	await _pick_copy(app, right, 2)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(
		(
			ledger.construction().copies.size() == 10
			and ClubCareer.same(ledger.to_data().events.slice(0, 4), before.career.assets.events)
		),
		"three paid displays retain three starter copies and all four original earned awards"
	)
	_check(
		(
			ledger.view().stadium_active.version == 4
			and ledger.view().stadium_active.displays.size() == 3
		),
		"three exact display copies applied"
	)
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "club-displays-property")
	await _click(_focus_button(app, board))
	await _bounds(app, "owned-scoreboard-focus")
	_focus_fits(app, board)
	await _pick_copy(app, right, 1)
	_check(
		_paid_choice(app, left).selected == 0 and _paid_choice(app, right).selected == 1,
		"moving another sign into an occupied site stores its previous exact occupant"
	)
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(
		_paid_choice(app, left).selected == 1 and _paid_choice(app, right).selected == 2,
		"reload discards unsaved display movement"
	)
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "club-displays-small-window")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(
		not ClubConstruction.buy_copy(season, "ST-041", ledger.revision()).ok,
		"display purchases lock with the season"
	)
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
	_check(app.lab != null, "actual human match accepts the saved displays")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		var display: StadiumScoreboardDisplay = property.objects[board].get_node(
			"Visual/ScoreDisplay"
		)
		await _frames(4)
		_check(
			display._match == app.lab._match_state and display.shown.home == 0,
			"actual scoreboard observes the actual match, not a preview or fabricated score"
		)
		_check(
			property.objects.size() == 3 and property.route_obstacles().is_empty(),
			"outside-play displays do not become live route obstacles"
		)
		_check(
			app.lab._camera_director.tracking_visibility._uprights.is_empty(),
			"scoreboard/sign posts do not trigger the live-pole camera sidestep"
		)
		app._close_match()
	_check(
		(
			SeasonSave.restore() != null
			and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key
		),
		"restart retains exact display ownership and active layout"
	)
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro display UI checks passed: paid copies, storage, preview and real score binding."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _focus_button(app: SeasonApp, copy: String) -> Button:
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta("stadium_focus", "") == copy:
			return button
	return null


func _focus_fits(app: SeasonApp, copy: String) -> void:
	var preview: StadiumDraftPreview = _preview(app)
	var camera: Camera3D = preview.camera
	var viewport: Rect2 = camera.get_viewport().get_visible_rect()
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, PI), preview.positions[copy])
	for index in range(8):
		var point: Vector3 = pose * StadiumClubSites.envelope("ST-039").get_endpoint(index)
		_check(
			(
				not camera.is_position_behind(point)
				and viewport.has_point(camera.unproject_position(point))
			),
			"focus contains the entire authored scoreboard envelope, including its feet"
		)


func _check(ok: bool, message: String) -> void:
	if _ground_mode:
		_ground_checks += 1
	if _flag_mode:
		_flag_checks += 1
	super._check(ok, message)


func _flag_ui() -> void:
	var prior_path: String = SeasonSave.path
	var prior_error: String = SeasonSave.last_error
	var path: String = "user://club-flag-ui-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	# Reuse the existing synthetic season/result helpers for exactly two completed seasons.
	# These score-only setup results are not actual gameplay or earned-history qualification.
	var completed: SeasonState = _new(71)
	_finish(completed, "champion")
	_check(SeasonSave.save(completed), "first synthetic completed prefix is validated")
	var club: ClubCareer = completed.career.fork()
	_check(club.close(completed), "first completed prefix is retained")
	completed = _new(72, club)
	_finish(completed, "champion")
	_check(SeasonSave.save(completed), "second synthetic completed prefix is validated")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(92, true)
	var season: SeasonState = app.season
	_check(
		season != null and season.phase == SeasonState.Phase.DRAFT and season.picks.is_empty(),
		"ordinary new Working season opens before roster draft"
	)
	if season == null:
		await _flag_ui_finish(app, path, prior_path, prior_error)
		return
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(
		(
			paid.surface_owned().has("ground_prep")
			or ClubConstruction.buy_surface(season, "ground_prep", paid.revision()).ok
		),
		"existing ground preparation access is retained or ordinarily purchased once"
	)
	StadiumEditorUI.show(app.menu)
	var revision: int = ClubPlayers.assets(season.career).revision()
	var balance: int = season.career.balance()
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	var missing: String = path + "/missing/file.json"
	SeasonSave.path = missing
	await _click(_buy_button(app, "ST-043"))
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
			and not FileAccess.file_exists(missing + ".tmp")
		),
		"failed flag checkout preserves wallet, ownership and exact durable bytes"
	)
	SeasonSave.path = path
	await _click(_buy_button(app, "ST-043"))
	_check(
		(
			season.career.balance() == balance - 245
			and ClubConstruction.buy_copy(season, "ST-043", revision).replayed
		),
		"actual flag button charges190 plus55 exactly once"
	)
	var first: String = "purchase:stadium-buy:%d:0" % revision
	await _click(_buy_button(app, "ST-043"))
	var second: String = "purchase:stadium-buy:%d:0" % (revision + 1)
	_check(season.career.balance() == balance - 300, "second actual flag button charges55 only")
	await _pick_copy(app, first, 1)
	await _pick_copy(app, second, 2)
	await _click(_button(app.menu, "PREVIEW PLAYABLE DIRT TERRAIN"))
	var grade: OptionButton = null
	for option: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
		if option.get_meta("terrain_choice", false):
			grade = option
	_check(
		grade != null and not grade.disabled and grade.item_count == 2,
		"existing owned terrain grade selector is enabled"
	)
	if grade != null and not grade.disabled:
		var was_rough: bool = grade.selected == 0
		grade.grab_focus()
		await _frames()
		await _key(KEY_ENTER)
		if was_rough:
			await _key(KEY_DOWN)
		await _key(KEY_ENTER)
		await _frames()
	await _click(_button(app.menu, "SAVE DRAFT"))
	paid = ClubPlayers.assets(season.career)
	var draft: Dictionary = paid.view().stadium_draft
	_check(
		(
			draft.version == 18
			and draft.base_version == 17
			and draft.surface.condition == "prepared"
			and (
				draft.flags
				== [
					{"copy": first, "site": "FLAG-GROUND-L"},
					{"copy": second, "site": "FLAG-GROUND-R"}
				]
			)
		),
		"ordinary terrain opt-in preserves both exact paid flag sites on leveled dirt"
	)
	before = SeasonSave.snapshot(season)
	bytes = FileAccess.get_file_as_string(path)
	SeasonSave.path = missing
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
			and not FileAccess.file_exists(missing + ".tmp")
		),
		"failed Apply leaves prior field and paid journal exact"
	)
	SeasonSave.path = path
	await _click(_button(app.menu, "APPLY LAYOUT"))
	paid = ClubPlayers.assets(season.career)
	_check(
		(
			season.home_property.get("version") == 28
			and season.home_property.terrain.mode == "leveled"
			and ClubCareer.same(paid.view().stadium_active, draft)
			and season.career.balance() == balance - 300
		),
		"actual Apply installs combined flags and leveled terrain without a new charge"
	)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			saved.get("version") == 74
			and saved.career.assets.version == 25
			and restored != null
			and ClubCareer.same(SeasonSave.snapshot(restored), saved)
		),
		"Save74 and complete journal25 cold replay retain composite authority"
	)
	await _pick_copy(app, second, 1)
	_check(
		_paid_choice(app, first).selected == 0 and _paid_choice(app, second).selected == 1,
		"moving another flag stores only the displaced exact occupant"
	)
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(
		(
			_paid_choice(app, first).selected == 1
			and _paid_choice(app, second).selected == 2
			and ClubCareer.same(saved, SeasonSave.snapshot(season))
		),
		"reload discards only unsaved movement"
	)
	app.choose_player(season.offers()[0])
	StadiumEditorUI.show(app.menu)
	_check(
		(
			_buy_button(app, "ST-043").disabled
			and _paid_choice(app, first).disabled
			and not ClubConstruction.buy_copy(season, "ST-043", paid.revision()).ok
		),
		"purchase and placement controls lock when roster drafting begins"
	)
	_check(
		(
			season.results.is_empty()
			and season.physical.reports.is_empty()
			and season.physical.pending.is_empty()
			and app.lab == null
		),
		"current flag season has no games, pending reports or installed match"
	)
	await _flag_ui_finish(app, path, prior_path, prior_error)


func _flag_ui_finish(app: SeasonApp, path: String, prior_path: String, prior_error: String) -> void:
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	SeasonSave.path = prior_path
	SeasonSave.last_error = prior_error
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"STADIUM_CLUB_FLAG_UI checks=%d failures=%d games=0 synthetic_history=true"
			% [_flag_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func run_owned() -> Dictionary:
	_ground_mode = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var attached_here: bool = get_parent() == null
	if attached_here:
		tree.root.add_child(self)
	var probe: Node = load("res://src/tests/stadium_displays_owned_test.gd").new()
	var result: Dictionary = probe.ground_props_owned()
	probe.free()
	await _ground_props_ui()
	result.checks += _ground_checks
	result.failures += _failures
	if attached_here:
		tree.root.remove_child(self)
	return result


func _ground_props_ui() -> void:
	var prior_path: String = SeasonSave.path
	var prior_error: String = SeasonSave.last_error
	var path: String = "user://ground-props-ui-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	# Five explicit score-only synthetic setup seasons; no claim of actual played history.
	var club: ClubCareer = ClubCareer.new()
	var funded: bool = true
	for index in range(5):
		var completed: SeasonState = SeasonState.create(71 + index, false, true, true)
		completed.career = club
		funded = completed.career.start(completed) and funded
		for pick in range(4):
			completed.choose_player(completed.offers()[0])
		while completed.phase != SeasonState.Phase.COMPLETE:
			var fixture: Dictionary = completed.pending_fixture()
			funded = (
				completed.record_player_result(
					fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0
				)
				and funded
			)
		funded = SeasonSave.save(completed) and funded
		if index < 4:
			club = completed.career.fork()
			funded = club.close(completed) and funded
	_check(funded, "five bounded synthetic setup seasons publish validated ordinary income")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(92, true)
	var season: SeasonState = app.season
	_check(
		season != null and season.phase == SeasonState.Phase.DRAFT and season.picks.is_empty(),
		"ordinary Working editor opens before drafting; notice=" + app.notice
	)
	if season == null:
		await _ground_ui_close(app, path, prior_path, prior_error)
		return
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(
		(
			paid.surface_owned().has("ground_prep")
			or ClubConstruction.buy_surface(season, "ground_prep", paid.revision()).ok
		),
		"ordinary preparation access is retained or purchased"
	)
	StadiumEditorUI.show(app.menu)
	var shop: bool = true
	for item: String in StadiumGroundPropsItems.PRICES:
		var button: Button = _buy_button(app, item)
		shop = button != null and not button.disabled and shop
	_check(shop, "all nine current catalog purchase routes are visible and unlocked")
	var revision: int = ClubPlayers.assets(season.career).revision()
	var balance: int = season.career.balance()
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	var missing: String = path + "/missing/file.json"
	SeasonSave.path = missing
	await _click(_buy_button(app, "ST-015"))
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
			and not FileAccess.file_exists(missing + ".tmp")
		),
		"failed prop checkout preserves wallet and exact saved bytes"
	)
	SeasonSave.path = path
	await _click(_buy_button(app, "ST-015"))
	var first: String = "purchase:stadium-buy:%d:0" % revision
	_check(
		(
			season.career.balance() == balance - 175
			and ClubConstruction.buy_copy(season, "ST-015", revision).replayed
		),
		"actual fern button pays blueprint and copy exactly once"
	)
	await _click(_buy_button(app, "ST-015"))
	var second: String = "purchase:stadium-buy:%d:0" % (revision + 1)
	await _click(_buy_button(app, "ST-004"))
	var mower: String = "purchase:stadium-buy:%d:0" % (revision + 2)
	await _click(_buy_button(app, "ST-043"))
	var flag: String = "purchase:stadium-buy:%d:0" % (revision + 3)
	_check(
		season.career.balance() == balance - 765,
		"extra fern, mower and independent flag debit exact current terms"
	)
	await _pick_copy(app, first, 1)
	await _pick_copy(app, mower, 1)
	await _pick_copy(app, flag, 1)
	await _click(_button(app.menu, "PREVIEW PLAYABLE DIRT TERRAIN"))
	var grade: OptionButton = null
	for option: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
		if option.get_meta("terrain_choice", false):
			grade = option
	_check(
		grade != null and not grade.disabled and grade.item_count == 2,
		"new composition preserves the actual terrain grade control"
	)
	if grade != null and not grade.disabled:
		var was_rough: bool = grade.selected == 0
		grade.grab_focus()
		await _frames()
		await _key(KEY_ENTER)
		if was_rough:
			await _key(KEY_DOWN)
		await _key(KEY_ENTER)
		await _frames()
	await _click(_button(app.menu, "SAVE DRAFT"))
	paid = ClubPlayers.assets(season.career)
	var draft: Dictionary = paid.view().stadium_draft
	_check(
		(
			draft.version == 19
			and draft.base_version == 17
			and draft.surface.condition == "prepared"
			and draft.flags == [{"copy": flag, "site": "FLAG-GROUND-L"}]
			and (
				draft.props
				== [{"copy": mower, "site": "OM-L"}, {"copy": first, "site": "PLANT-L1"}]
			)
		),
		"actual prop and flag selectors preserve both layers during terrain opt-in"
	)
	before = SeasonSave.snapshot(season)
	bytes = FileAccess.get_file_as_string(path)
	SeasonSave.path = missing
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
		),
		"failed Apply keeps the original full save and installed layout"
	)
	SeasonSave.path = path
	await _click(_button(app.menu, "APPLY LAYOUT"))
	paid = ClubPlayers.assets(season.career)
	_check(
		(
			season.home_property.get("version") == 28
			and season.home_property.terrain.mode == "leveled"
			and ClubCareer.same(paid.view().stadium_active, draft)
			and season.career.balance() == balance - 765
		),
		(
			"actual Apply installs paid props on leveled terrain for free; notice="
			+ app.notice
			+ " balance="
			+ str(season.career.balance())
			+ " active="
			+ JSON.stringify(paid.view().stadium_active)
		)
	)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			saved.get("version") == 74
			and saved.career.assets.version == 26
			and restored != null
			and ClubCareer.same(SeasonSave.snapshot(restored), saved)
		),
		"unchanged Save74 cold decode joins actual journal26 and complete composition"
	)
	await _pick_copy(app, second, 1)
	_check(
		_paid_choice(app, first).selected == 0 and _paid_choice(app, second).selected == 1,
		"replacement stores only the displaced fern"
	)
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(
		(
			_paid_choice(app, first).selected == 1
			and _paid_choice(app, second).selected == 0
			and ClubCareer.same(saved, SeasonSave.snapshot(season))
		),
		"reload restores only the saved exact prop selection"
	)
	await _pick_copy(app, first, 0)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	await _pick_copy(app, first, 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(
		(
			season.career.balance() == balance - 765
			and ClubPlayers.assets(season.career).view().stadium_active.props == draft.props
		),
		(
			"ordinary storage and free remount keep the exact paid fern; notice="
			+ app.notice
			+ " balance="
			+ str(season.career.balance())
		)
	)
	app.choose_player(season.offers()[0])
	StadiumEditorUI.show(app.menu)
	_check(
		(
			_buy_button(app, "ST-004").disabled
			and _paid_choice(app, mower).disabled
			and not (
				ClubConstruction
				. buy_copy(season, "ST-004", ClubPlayers.assets(season.career).revision())
				. ok
			)
		),
		"current-season drafting locks every new purchase and placement"
	)
	_check(
		(
			season.results.is_empty()
			and season.physical.reports.is_empty()
			and season.physical.pending.is_empty()
			and app.lab == null
		),
		"current UI season contains no actual game or pending physical report"
	)
	await _ground_ui_close(app, path, prior_path, prior_error)


func _ground_ui_close(
	app: SeasonApp, path: String, prior_path: String, prior_error: String
) -> void:
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	SeasonSave.path = prior_path
	SeasonSave.last_error = prior_error
