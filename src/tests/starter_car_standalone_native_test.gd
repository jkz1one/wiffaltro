extends Node
## Standalone runtime diagnostic with the exact real ledger; NOT SeasonApp entry qualification.
## Pristine public new club; no synthetic funding, scores, completion or profile overrides.

const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
var _native: NativeCapture
var _app: SeasonApp
var _checks: int = 0
var _failures: int = 0
var _directory: String = ""
var _save_path: String = ""
var _captures: int = 0
var _home_fixture: Dictionary = {}


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		print("STARTER_CAR_STANDALONE_FAILURE " + label)
	return ok


func _frames(count: int = 12) -> void:
	for frame in range(count):
		await get_tree().process_frame


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_directory = argument.trim_prefix("--ui-capture-dir=")
	if not _check(
		DisplayServer.get_name() != "headless" and not _directory.is_empty(),
		"native display and explicit capture directory required"
	):
		await _finish()
		return
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	if not _check(await _native.resize(Vector2i(1280, 720)), "native normal extent"):
		await _finish()
		return
	_save_path = "user://starter-car-standalone-native-%d.json" % OS.get_process_id()
	SeasonSave.path = _save_path
	for suffix: String in ["", ".bak", ".tmp"]:
		if not _check(
			not FileAccess.file_exists(_save_path + suffix), "isolated save absent " + suffix
		):
			_save_path = ""
			await _finish()
			return
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	_app.begin_season(175, true, true, true, true, true)
	var season: SeasonState = _app.season
	if not _check(
		season != null and season.career != null, "public pristine entry: " + _app.notice
	):
		await _finish()
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	if not _check(ledger != null, "pristine ledger validates"):
		await _finish()
		return
	_check(season.phase == SeasonState.Phase.DRAFT and season.picks.is_empty(), "pristine DRAFT")
	_check(ledger.balance() == 0 and ledger.revision() == 0, "no funding or journal events")
	_check(
		(
			ledger.construction().copies.size() == 4
			and not ledger.construction().blueprints.has("ST-005")
			and ledger.construction().copies.has(StadiumStock.SALVAGE_COPY)
		),
		"exact separate owned salvage copy"
	)
	_check(
		ClubAssetLedger._fixed_salvage_present(season.home_property.get("layout", {})),
		"fixed car home snapshot"
	)
	_check(
		ClubCareer.same(
			ledger.construction().copies.get(StadiumStock.SALVAGE_COPY),
			{"item": "ST-005", "paid": 0, "source": "starter-salvage-v1"}
		),
		"exact salvage origin record"
	)
	await _standalone_draft(season, ledger)


func _standalone_draft(season: SeasonState, ledger: ClubAssetLedger) -> void:
	var home_key: String = StadiumLayoutSnapshot.key(season.home_property)
	var cold: SeasonState = SeasonSave.restore()
	_check(
		cold != null and StadiumLayoutSnapshot.key(cold.home_property) == home_key,
		"pristine home cold restore"
	)
	if _failures != 0:
		await _finish()
		return
	if not await _standalone_public_draft(season):
		return
	_check(
		season.pending_fixture().get("home", -1) != 0,
		"ordinary pending fixture is away; no progression claimed"
	)
	for fixture: Dictionary in season.schedule:
		if fixture.home == 0:
			_home_fixture = fixture.duplicate(true)
			break
	if not _check(not _home_fixture.is_empty(), "real home fixture exists"):
		await _finish()
		return
	var saved_bytes: String = FileAccess.get_file_as_string(_save_path)
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, _home_fixture)
	if not _check(state != null, "real home fixture match constructs"):
		await _finish()
		return
	# Diagnostic only: supply the exact original owner directly to a standalone lab.
	# This does not call or qualify SeasonApp._open_match or its current-fixture gate.
	_app.lab = PitchBatLab.new()
	_app.lab._configured_match = state
	_app.lab._stadium_ledger = ledger
	_app.lab._managed_match = true
	_app.lab._player_home = true
	_app.menu.hide()
	_app.add_child(_app.lab)
	if not _check(is_instance_valid(_app.lab), "managed home install: " + _app.notice):
		await _finish()
		return
	await _frames()
	_check(
		(
			_app.lab.get_parent() == _app
			and _app.lab.get_viewport() == get_viewport()
			and not _app.menu.visible
			and _app.lab._managed_match
		),
		"actual root-viewport managed lab"
	)
	var property: StadiumPropertyGeometry = (
		_app.lab.get_meta("stadium_property", null) as StadiumPropertyGeometry
	)
	if not _check(property != null, "actual stadium property exists"):
		await _finish()
		return
	_check(
		(
			property.objects.has(StadiumStock.SALVAGE_COPY)
			and is_instance_valid(property.objects.get(StadiumStock.SALVAGE_COPY))
		),
		"runtime owns exact salvage car object"
	)
	_check(
		StadiumBoundaryRuntime.installed(_app.lab, state.stadium),
		"bound boundary remains installed"
	)
	_check(
		(
			(
				StadiumLayoutSnapshot.key(state.stadium)
				== StadiumLayoutSnapshot.key(
					StadiumLayoutSnapshot.for_fixture(season, _home_fixture)
				)
			)
			and StadiumLayoutSnapshot.matches(state.stadium, ledger)
		),
		"runtime exact fixture key and original paid owner"
	)
	await _frames(240)
	await _capture("starter-car-standalone-initial")
	for mode in [0, 1]:
		for attempt in range(4):
			if _app.lab._camera_mode == mode:
				break
			_app.lab._cycle_camera()
		_check(_app.lab._camera_mode == mode, "existing camera cycle selects requested mode")
		await _capture(
			"starter-car-standalone-batting" if mode == 0 else "starter-car-standalone-pitching"
		)
	_check(_captures == 6, "all three normal/minimum root captures saved")
	_check(
		FileAccess.get_file_as_string(_save_path) == saved_bytes,
		"capture never writes match outcomes"
	)
	cold = SeasonSave.restore()
	_check(
		cold != null and StadiumLayoutSnapshot.key(cold.home_property) == home_key,
		"post-view cold home key unchanged"
	)
	await _finish()


func _capture(label: String) -> void:
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		if not _check(await _native.resize(extent), "native resize " + label):
			return
		await _frames()
		if _check(await _native.capture(_directory, label), "strict root readback " + label):
			_captures += 1
	_check(await _native.resize(Vector2i(1280, 720)), "restore normal extent")


func _finish() -> void:
	if is_instance_valid(_app):
		if is_instance_valid(_app.lab):
			_check(_app._close_match(), "managed lab closes")
		_app.queue_free()
		await _frames()
	if is_instance_valid(_native):
		_check(_native._failures == 0, "native helper clean")
	print(
		(
			"STARTER_CAR_STANDALONE_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"captures": _captures,
					"fixture": _home_fixture,
					"completed_games": 0,
					"synthetic_funding": false,
					"ordinary_pending_fixture_entry": false,
					"direct_managed_home_installation": false,
					"standalone_exact_owner_runtime": true
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _standalone_public_draft(season: SeasonState) -> bool:
	for pick in range(4):
		if not _check(not season.offers().is_empty(), "draft offer exists"):
			await _finish()
			return false
		_app.choose_player(season.offers()[0])
		if not _check(season.picks.size() == pick + 1, "public draft pick accepted"):
			await _finish()
			return false
	return true
