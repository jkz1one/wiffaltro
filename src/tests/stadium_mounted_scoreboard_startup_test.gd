extends "res://src/tests/live_match_test.gd"
## Actual earned ownership through normal startup and typed proof boundaries.

const MountedFixture = preload("res://src/tests/stadium_mounted_scoreboard_season_fixture.gd")
const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
const RuntimeProbe = preload("res://src/tests/stadium_mounted_scoreboard_runtime_test.gd")
var _capture_dir: String = ""
var _native: NativeCapture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	SeasonSave.path = "user://mounted-scoreboard-startup-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://mounted-scoreboard-startup-%d.cfg" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	var data: MountedFixture = MountedFixture.new()
	data.prepare(app, _check)
	await _profile_startup(app)
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
	var fixture: Dictionary = {}
	for candidate: Dictionary in app.season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	_check(not fixture.is_empty(), "real earned season has a scheduled home fixture")
	if fixture.is_empty():
		get_tree().quit(1)
		return
	var source: MatchState = SeasonPhysicalFixtures.match_for(app.season, fixture)
	var ledger: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	var held: Dictionary = SeasonSave.snapshot(app.season)
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	_runner_guards(source, ledger)
	await _dispatch_guards(source, ledger)
	app.menu.hide()
	await _normal_startup(source, ledger)
	app._fixture_id = int(fixture.id)
	app._open_match(source, true, true)
	_check(app.lab == null and ClubCareer.same(held, SeasonSave.snapshot(app.season)),
		"future scheduled home cannot replace the actual pending away fixture")
	_check(FileAccess.get_file_as_string(SeasonSave.path) == bytes,
		"startup and rejected proof checks cannot settle games or change the saved career")
	app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	_check(_native._failures == 0, "native capture handshake remains valid")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard startup passed: typed proof and normal world binding.")
	get_tree().quit(0 if _failures == 0 else 1)


func _runner_guards(source: MatchState, ledger: ClubAssetLedger) -> void:
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var seed: int = int(source.stadium.environment.seed)
	_check(not runner.start(source, seed), "fixture15 without typed proof cannot allocate a job")
	_check(not runner.start(source, seed, PitchBatLab.FIELD_ID,
		ledger.prefix(ledger.revision() - 1)), "pre-Apply prefix cannot authorize mounted startup")
	_check(not runner.start(source, seed + 1, PitchBatLab.FIELD_ID, ledger),
		"runner seed must match the exact scheduled fixture seed")
	_check(not runner.start(source, seed, SeasonState.AWAY_FIELD_ID, ledger),
		"mounted human venue cannot replace an opponent park")
	_check(runner._lab == null and runner._viewport == null and not runner._running,
		"all missing/stale/context proof rejections occur before allocation")
	_check(runner.start(source, seed, PitchBatLab.FIELD_ID, ledger),
		"normal automated startup accepts the exact paid proof")
	if runner._lab != null:
		_check(runner._lab._stadium_ledger == ledger
			and runner._lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
			and not runner._lab._pitch_actor.running
			and StadiumBoundaryRuntime.installed(runner._lab, source.stadium),
			"delivery-before-release timing and complete mounted world remain valid")
		var retired: PitchBatLab = runner._lab
		runner.cancel()
		_check(retired._stadium_ledger == null, "cancel clears retained proof before deferred deletion")
	runner.queue_free()


func _dispatch_guards(source: MatchState, ledger: ClubAssetLedger) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._match_state.stadium = source.stadium.duplicate(true)
	var probe: Node = RuntimeProbe.new()
	var before: Dictionary = probe._field_state(lab)
	_check(not StadiumPropertyRuntime.install_bound(lab)
		and before == probe._field_state(lab), "missing typed proof refuses atomically")
	lab.set_meta("stadium_ledger", ledger)
	lab.set_meta("mounted_eligible", true)
	before = probe._field_state(lab)
	_check(not StadiumPropertyRuntime.install_bound(lab)
		and before == probe._field_state(lab), "metadata cannot impersonate typed paid authority")
	lab.remove_meta("stadium_ledger")
	lab.remove_meta("mounted_eligible")
	lab._stadium_ledger = ledger.prefix(ledger.revision() - 1)
	before = probe._field_state(lab)
	_check(not StadiumPropertyRuntime.install_bound(lab)
		and before == probe._field_state(lab), "stale proof refuses without partial scene mutation")
	lab._stadium_ledger = ledger
	_inventory_guards(lab, source.stadium, probe)
	lab._match_state.stadium = source.stadium.duplicate(true)
	_check(StadiumPropertyRuntime.install_bound(lab)
		and StadiumBoundaryRuntime.installed(lab, source.stadium),
		"restoring exact paid proof permits unchanged public property/boundary entry points")
	# Let native material uploads finish before this same-frame fixture is retired.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.free()
	probe.free()
	await get_tree().process_frame


func _inventory_guards(lab: PitchBatLab, fixture: Dictionary, probe: Node) -> void:
	for field: String in ["inventory", "wall_piece_inventory", "scoreboard_inventory"]:
		var bad: Dictionary = fixture.duplicate(true)
		var copies: Dictionary = bad[field].stock.copies if field == "wall_piece_inventory" \
			else bad[field].copies
		var chosen: String = ""
		for key: String in copies:
			if (field == "inventory" and copies[key].item == "ST-024") \
				or (field == "wall_piece_inventory" and copies[key].item == "ST-024-T") \
				or (field == "scoreboard_inventory" and key != bad.layout.scoreboards[0].copy):
				chosen = key
				break
		_check(not chosen.is_empty(), "actual paid spare exists: " + field)
		if chosen.is_empty():
			continue
		var invented: String = "purchase:unpaid:0" if field == "inventory" else (
			"wall-piece:unpaid:0" if field == "wall_piece_inventory" else "scoreboard:unpaid:0")
		copies[invented] = copies[chosen].duplicate(true)
		_check(StadiumLayoutSnapshot.valid(bad), "invented spare is shape-valid: " + field)
		lab._match_state.stadium = bad
		var before: Dictionary = probe._field_state(lab)
		_check(not StadiumPropertyRuntime.install_bound(lab)
			and before == probe._field_state(lab), "whole prefix rejects unpaid spare: " + field)
		if field == "scoreboard_inventory":
			bad.layout.scoreboards[0].copy = invented
			before = probe._field_state(lab)
			_check(not StadiumPropertyRuntime.install_bound(lab)
				and before == probe._field_state(lab), "same-looking unpaid center copy rejects")


func _normal_startup(source: MatchState, ledger: ClubAssetLedger) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = PhysicalMatchRequest.capture(source)
	lab._stadium_ledger = ledger
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var fixture: Dictionary = source.stadium
	_check(StadiumBoundaryRuntime.installed(lab, fixture),
		"normal _ready installs complete fixture15 using proof supplied before add_child")
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var helper: StadiumMountedScoreboardCelebration = property.celebration
	_check(helper != null and StadiumMountedPresentationContract.listeners_match(helper)
		and lab._camera_director._live_coverage is StadiumMountedCameraMotion,
		"normal startup preserves native scorer-before-celebration and exact center camera")
	lab._stadium_ledger = null
	_check(not StadiumBoundaryRuntime.installed(lab, fixture),
		"installed-world checks require the retained typed proof on every call")
	lab._stadium_ledger = ledger.prefix(ledger.revision() - 1)
	_check(not StadiumBoundaryRuntime.installed(lab, fixture),
		"installed-world checks reject a stale replacement proof")
	lab._stadium_ledger = ledger
	for hand: int in [PlayerDefinition.Handedness.LEFT, PlayerDefinition.Handedness.RIGHT]:
		var batter: PlayerMatchState = lab._match_state.batter()
		batter.definition = batter.definition.duplicate(true)
		batter.definition.bats = hand as PlayerDefinition.Handedness
		batter.batting_hand_override = -1
		PitchBatLabPresentation.sync_players(lab)
		lab._apply_role_camera()
		lab._camera_director.snap(lab._camera)
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
			_check(await _native.resize(size), "native startup extent is acknowledged")
			_check(StadiumBoundaryRuntime.installed(lab, fixture),
				"both-handed normal and small-window cameras preserve exact binding")
			await _capture("mounted-normal-%d-%d" % [hand, size.x])
	_check(await _native.resize(Vector2i(1280, 720)), "native startup extent restores")
	var display: StadiumScoreboardTierDisplay = property.board_display(
		fixture.layout.scoreboards[0].copy)
	var previous: MatchState = lab._match_state
	lab._configured_match = PhysicalMatchRequest.capture(source)
	lab._start_new_match()
	_check(lab._match_state != previous and lab._stadium_ledger == ledger
		and display._match == lab._match_state and StadiumBoundaryRuntime.installed(lab, fixture),
		"same-fixture restart retains proof and automatically rebinds readout and celebration")
	lab._configured_match = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "A", "H")
	lab._start_new_match()
	_check(lab._stadium_ledger == null and not StadiumBoundaryRuntime.installed(lab, fixture),
		"replacing the configured fixture clears proof and cannot authenticate the prior field")
	lab.free()
	await get_tree().process_frame


func _capture(label: String) -> void:
	_check(await _native.capture(_capture_dir, label), "normal mounted capture uses actual pixels")


func _profile_startup(app: SeasonApp) -> void:
	var center: Dictionary = app.season.home_property.layout.duplicate(true)
	var ledger: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	var balance: int = ledger.balance()
	var fixture: Dictionary = {}
	for candidate: Dictionary in app.season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	for mode: String in ["empty", "perimeter", "center"]:
		var layout: Dictionary = center.duplicate(true)
		if mode == "empty":
			layout.scoreboards.clear()
		elif mode == "perimeter":
			layout.scoreboards[0].site = "BOARD-RIGHT-v2"
			layout.scoreboards[0].mount_profile = ""
		var revision: int = ClubPlayers.assets(app.season.career).revision()
		_check(ClubConstruction.save_draft(app.season, layout, revision).ok
			and ClubConstruction.apply_draft(app.season, layout, revision + 1).ok,
			"normal public Save Draft/Apply creates paid profile: " + mode)
		if mode == "center":
			continue
		var lab: PitchBatLab = PitchBatLab.new()
		lab._configured_match = MatchLabSupport.create_match(
			PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD")
		lab._configured_match.stadium = StadiumLayoutSnapshot.for_fixture(app.season, fixture)
		lab._stadium_ledger = ClubPlayers.assets(app.season.career)
		lab._sky_backdrop_enabled = false
		add_child(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		_check(StadiumBoundaryRuntime.installed(lab, lab._match_state.stadium),
			"normal startup authenticates complete mounted15 without a center: " + mode)
		if lab.has_meta("stadium_property"):
			var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
			var camera: StadiumMountedCameraVisibility = lab._camera_director.tracking_visibility
			_check(property.celebration == null and camera._mounted_meshes.is_empty()
				and not lab._camera_director._live_coverage is StadiumMountedCameraMotion
				and lab._camera_director.presentation_override.is_null(),
				"empty and retained freestanding profiles keep ordinary camera/no celebration")
		# Both short-lived native profile labs must draw before teardown.
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		lab.free()
		await get_tree().process_frame
	_check(ClubPlayers.assets(app.season.career).balance() == balance
		and ClubCareer.same(ledger.construction().to_data(),
			ClubPlayers.assets(app.season.career).construction().to_data())
		and ClubCareer.same(ledger.wall_pieces().to_data(),
			ClubPlayers.assets(app.season.career).wall_pieces().to_data())
		and ClubCareer.same(ledger.scoreboards().to_data(),
			ClubPlayers.assets(app.season.career).scoreboards().to_data()),
		"public mount storage and replacement preserve the exact paid inventory and money")
