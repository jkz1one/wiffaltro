extends "res://src/tests/hillside_public_low_liner_test.gd"
## Appearance-only comparison: faithful ordinary prefix, then its first preground view.
## Reuses accepted admission, inputs, passive launch witness and original capture lock.
## Stops before target ground/terminal; no bounce, scoring, H3 or full-game qualification.
# gdlint: disable=max-line-length,max-returns

const COMPARISON_CHECKS: int = 23
var _appearance_camera: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1000000
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
		elif argument.begins_with("--hillside-wall-appearance-output="):
			_output = argument.trim_prefix("--hillside-wall-appearance-output=")
		else:
			_check(false, "only exact output and capture-directory selectors are accepted")
	_run.call_deferred()


func _run() -> void:
	_output_admitted = _admit_output()
	_check(OS.get_cmdline_user_args().size() == 2 and _output_admitted \
		and _capture_dir.is_absolute_path() and _capture_dir.simplify_path() == _capture_dir \
		and DirAccess.dir_exists_absolute(_capture_dir), "two exact fresh output and root-owned capture arguments")
	_check(DisplayServer.get_name() != "headless" and Engine.physics_ticks_per_second == 60 \
		and Engine.time_scale == 1.0 and not get_tree().paused, "displayed ordinary unpaused fixed60 clock")
	if not _failed.is_empty():
		_finish()
		return
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0 and await _native.resize(Vector2i(1280, 800)),
		"native startup and one 1280 by 800 window handshake")
	_saved_path = SeasonSave.path
	_settings_path = PitchBatLabSettings.path
	SeasonSave.path = "user://hillside-low-liner-drafted-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://hillside-low-liner-settings-%d.cfg" % OS.get_process_id()
	_paths_isolated = true
	_check(not FileAccess.file_exists(SeasonSave.path) and not FileAccess.file_exists(SeasonSave.path + ".bak") \
		and not FileAccess.file_exists(SeasonSave.path + ".tmp") and not FileAccess.file_exists(PitchBatLabSettings.path) \
		and R.source_qualified() and F.ready(), "fresh isolated save/settings and accepted explicit public source")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	var prepared: SeasonState = F.season()
	_check(prepared != null and prepared.season_seed == 6 and prepared.results.is_empty() \
		and prepared.player_results.is_empty() and prepared.physical.reports.is_empty() \
		and prepared.physical.pending.is_empty() and prepared.final_fixture.is_empty() \
		and SeasonFinalVenue.matches_season(prepared), "same genuine completed draft and pre-draft fixed Hillside venue")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	_draft = SeasonSave.snapshot(prepared).duplicate(true)
	_check(_draft.version == 67 and _draft.opponents.policy == 13 and SeasonSave.save(prepared),
		"genuine current-policy drafted save67 written once")
	_save_sha = FileAccess.get_sha256(SeasonSave.path)
	_season = SeasonSave.restore()
	_check(_season != null and ClubCareer.same(_draft, SeasonSave.snapshot(_season)),
		"exact native canonical draft restore precedes explicit non-earned test binding")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	var fixture: Dictionary = F.fixture(_season, false)
	_season.phase = SeasonState.Phase.FINAL
	_match = SeasonPhysicalFixtures.match_for(_season, fixture)
	_check(_match != null and ClubCareer.same(fixture,
		{"id": 32, "round": 11, "away": 0, "home": 1, "neutral": true}) \
		and StadiumNpcSnapshot.matches_fixture(_match.stadium, _season, fixture) \
		and SeasonPhysicalFixtures.seed_for(_season, fixture) == 3351334,
		"same explicit fixture32, player-away roles and retained match seed3351334")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	_before_season = SeasonSave.snapshot(_season).duplicate(true)
	_app = SeasonApp.new()
	add_child(_app)
	# Hold only settlement polling, exactly as the accepted one-game qualification.
	_app.set_process(false)
	_app.season = _season
	_app._fixture_id = 32
	_app.notice = ""
	_app.child_entered_tree.connect(_configure_automation)
	_app._open_match(_match, false, true, &"field.npc_venue")
	_lab = _app.lab
	_owner = R._property(_lab) if is_instance_valid(_lab) else null
	var pending: bool = is_instance_valid(_owner) and R.pending_hillside(_lab)
	for _frame in range(180):
		await physics_observed
		if not is_instance_valid(_lab) or _app.lab != _lab:
			break
		if is_instance_valid(_owner) and _owner.issued and _lab.hillside_public_pending == null:
			break
	_check(pending and _starts == 1 and _pre_ready and is_instance_valid(_lab) \
		and _app.lab == _lab and _app.notice.is_empty() and _public_identity() \
		and R.installed_bound(_lab, _match.stadium), "same SeasonApp asynchronous public admission with pre-ready ordinary automation")
	if not _failed.is_empty():
		await _dispose()
		_finish()
		return
	_terrain = _owner.construction.terrain.get_node("TerrainCollision")
	_check(_lab._automation == _automation and _automation.seed == 3351334 and _automation.presentation_enabled \
		and not _app.is_processing() and _lab.is_processing() and _lab.is_physics_processing() \
		and _lab._managed_match and _lab._npc_season == _season and not _lab._player_home \
		and _automation.releases.is_empty() and _lab._play_records.is_empty() \
		and _lab._throw_number == 3351334000 and not _lab._release_controller.active \
		and not _lab._match_presentation_director.blocks_gameplay(),
		"same initial six-release input state with only existing diagnostic presentation enabled")
	_check(_owner.objects.size() == 8 and _owner.display == null and _owner.score_display_intact() \
		and _owner.route_obstacles().is_empty() and _owner.public_automation == _automation \
		and _owner.boundary.get_script() == StadiumHillsidePublicContactAdapter \
		and _owner.boundary.contact_applied.get_connections().size() == 1 \
		and _owner.boundary.contact_applied.is_connected(_owner._club_contact),
		"sole ordinary public contact authority and unchanged venue objects")
	_admission = {"pending_observed": pending, "owner_id": _owner.get_instance_id(),
		"terrain_id": _terrain.get_instance_id(), "terrain_rid": _terrain.get_rid().get_id(),
		"app_id": _app.get_instance_id(), "lab_id": _lab.get_instance_id(), "match_id": _match.get_instance_id(),
		"automation_id": _automation.get_instance_id(), "seed": _automation.seed,
		"fixture": fixture.duplicate(true), "snapshot": _match.stadium.duplicate(true),
		"presentation_enabled": _automation.presentation_enabled,
		"saved_draft_sha256": _save_sha, "completed_games": 0}
	var start_tick: int = _tick
	for _frame in range(MAX_TICKS):
		await physics_observed
		if not _ordinary_running():
			_early_exit = "ordinary owner, clock or six-release bound changed"
			_check(false, _early_exit)
			break
		_observe()
		_check_prefix()
		if not _failed.is_empty():
			break
		if _state != null:
			if _state.dead or _state.has_grounded:
				_early_exit = "target resolved or grounded before the one original appearance view"
				break
			if _body.global_position.z >= 14.0:
				var pose: Transform3D = _lab._camera.global_transform
				_appearance_camera = {"position": _v(pose.origin), "basis_x": _v(pose.basis.x),
					"basis_y": _v(pose.basis.y), "basis_z": _v(pose.basis.z),
					"fov": _lab._camera.fov, "near": _lab._camera.near, "far": _lab._camera.far,
					"shot": _lab._camera_director.shot}
				await _shot("hillside-low-liner-before-ground")
				break
	_check(is_instance_valid(_lab) and _tick - start_tick <= MAX_TICKS and _prefix_checked == 5
		and _lab._play_records.size() == 5 and _automation.releases.size() == 6
		and _target_launches == 1 and _captures.size() == 1 and _early_exit.is_empty(),
		"one original preground appearance view follows exact five-record six-release prefix")
	_check(not _launch.is_empty() and _launch.get("ordinary_start", false)
		and _launch.get("postlaunch_aero", false) and _identity_intact and _state != null
		and not _state.dead and not _state.has_grounded and not _state.defender_touched
		and _captures.size() == 1 and not _captures[0].state.dead and not _captures[0].state.grounded,
		"comparison stops on the genuine untouched preground target without terminal qualification")
	_complete = _failed.is_empty()
	await _dispose()
	_finish()


func _child_entered(child: Node) -> void:
	# No ground listener is needed for this appearance-only stopping boundary.
	if child is BattedBallBody and _automation.releases.size() == 6:
		child.launch_started.connect(_launched.bind(child))


func _finish() -> void:
	_check(_checks + 1 == COMPARISON_CHECKS, "exact single-view appearance assertion inventory")
	var result: Dictionary = {"kind": "ordinary-public-hillside-wall-appearance-comparison",
		"checks": _checks, "failures": _failed, "status": "passed" if _complete and _failed.is_empty() else "failed",
		"prefix_checked": _prefix_checked, "actual_plays": _plays, "actual_releases": _releases,
		"target_release": _release, "launch": _launch, "target_launches": _target_launches,
		"trace": _trace, "captures": _captures, "appearance_camera": _appearance_camera,
		"early_exit": _early_exit, "identity_intact": _identity_intact, "public_admission": _admission,
		"caps": {"releases": 6, "unpaused_physics_ticks": MAX_TICKS, "target_rows": MAX_TRACE, "captures": 1},
		"completed_games": 0, "earned_final": false, "settled": false, "manual_input_qualified": false,
		"public_selection": "HELD", "performance_claim": "NONE", "h3_repair_claim": false,
		"bounce_requalification": false,
		"reference_image_sha256": "de7891e620909888b91e91da0e3aa1f39e1a2e1c82e2543e7b7f588aa85f857b"}
	if _output_admitted:
		var file: FileAccess = FileAccess.open(_output, FileAccess.WRITE)
		if file == null:
			_check(false, "native JSON evidence file opens")
		else:
			file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
			file.close()
	print("HILLSIDE_WALL_APPEARANCE checks=%d failures=%d captures=%d releases=%d target_launches=%d" %
		[_checks, _failed.size(), _captures.size(), _releases.size(), _target_launches])
	get_tree().quit(0 if _complete and _failed.is_empty() else 1)
