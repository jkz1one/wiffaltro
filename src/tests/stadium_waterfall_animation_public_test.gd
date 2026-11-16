extends Node
## Reuses only unchanged actually executed reports through ordinary settlement.
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("MOTION_PUBLIC_BUNDLE " + label)
	return ok


func _ready() -> void:
	var input: String = ""
	var evidence: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--funding-input="):
			input = arg.trim_prefix("--funding-input=")
		if arg.begins_with("--round-bundle="):
			evidence = arg.trim_prefix("--round-bundle=")
	if check(
		FileAccess.file_exists(input) and FileAccess.file_exists(evidence),
		"explicit original funding and actual evidence supplied"
	):
		var funding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input))
		var bundle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(evidence))
		if check(
			(
				bundle.get("schema") == "waterfall-public-actual-round-v1"
				and bundle.get("completed_physical_games") == 3
			),
			"exact actually completed three-game bundle"
		):
			await _profile(funding, bundle, _profile_label())
	print(
		(
			"MOTION_PUBLIC_BUNDLE_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"new_games_simulated": 0,
					"actual_reports_reused_only_after_exact_request_match": true,
					"synthetic_funding": true
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _new(career: ClubCareer) -> SeasonState:
	var season: SeasonState = SeasonState.create(51, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = career
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(career)) or not career.start(season):
		return null
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(career))
	for pick in range(4):
		if season.offers().is_empty() or not season.choose_player(season.offers()[0]):
			return null
	return season


func _profile(funding: Dictionary, bundle: Dictionary, profile: String) -> void:
	var branch: Dictionary = _prepare(funding)
	if not check(
		branch.ok, "public paid pre-draft variant " + profile + ": " + str(branch.get("error"))
	):
		return
	var completed: SeasonState = branch.completed_season
	if not check(completed.career.close(completed), "normal close after public Apply"):
		return
	var season: SeasonState = _new(completed.career)
	var control: SeasonState = SeasonSave._decode(bundle.initial_season)
	if not check(season != null and control != null, "variant and source modern seasons valid"):
		return
	var fixture: Dictionary = season.pending_fixture()
	print(
		"MOTION_PUBLIC_FIXTURE_IDENTITIES ",
		JSON.stringify(
			{
				"variant": fixture,
				"bundle": bundle.human_fixture,
				"control": control.pending_fixture(),
				"raw_bundle_equal": fixture == bundle.human_fixture,
				"canonical_bundle_equal": ClubCareer.same(fixture, bundle.human_fixture)
			},
			"",
			true,
			true
		)
	)
	if not check(
		(
			ClubCareer.same(fixture, bundle.human_fixture)
			and fixture == control.pending_fixture()
			and fixture.away == 0
		),
		"same actual scheduled first away game"
	):
		return
	if not check(
		(
			SeasonPhysicalFixtures.request_key(season, fixture) == bundle.human_request
			and SeasonPhysicalFixtures.request_key(control, fixture) == bundle.human_request
		),
		"exact unchanged human request including teams and field"
	):
		return
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	if not check(
		(
			state.stadium == SeasonPhysicalFixtures.match_for(control, fixture).stadium
			and PhysicalMatchReport.valid(bundle.human_report)
			and PhysicalStadiumReport.matches(bundle.human_report, state.stadium)
		),
		"untouched real human report and away snapshot valid"
	):
		return
	SeasonSave.path = "user://motion-public-bundle-" + profile + ".json"
	await _waterfall_settle_variant(bundle, profile, season, control)


func _waterfall_settle_variant(
	bundle: Dictionary, profile: String, season: SeasonState, control: SeasonState
) -> void:
	if not check(SeasonSave.save(season), "save actual variant before normal settlement"):
		return
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	app.round_ui.process_jobs = false
	if not check(
		app.season != null and app.round_ui.queue_human(bundle.human),
		"ordinary receipt queue accepts unchanged actual evidence"
	):
		app.free()
		return
	control.physical.pending = {"human": bundle.human.duplicate(true), "reports": []}
	for envelope: Dictionary in bundle.ai_reports:
		var next: Dictionary = SeasonRoundSettlement.project(app.season)
		var expected: Dictionary = SeasonRoundSettlement.project(control)
		if not check(
			(
				next.has("fixture")
				and expected.has("fixture")
				and next.fixture == expected.fixture
				and next.fixture.id == envelope.fixture
			),
			"same projected AI fixture"
		):
			app.free()
			return
		var request: String = SeasonPhysicalFixtures.request_key(next.candidate, next.fixture)
		var projected: MatchState = SeasonPhysicalFixtures.match_for(next.candidate, next.fixture)
		if not check(
			(
				request == envelope.request
				and (
					request
					== SeasonPhysicalFixtures.request_key(expected.candidate, expected.fixture)
				)
				and (
					projected.stadium
					== (
						SeasonPhysicalFixtures
						. match_for(expected.candidate, expected.fixture)
						. stadium
					)
				)
				and SeasonPhysicalFixtures.envelope(envelope)
				and PhysicalStadiumReport.matches(envelope.report, projected.stadium)
			),
			"unchanged actual AI request/report/field"
		):
			app.free()
			return
		app.season.physical.pending.reports.append(envelope.duplicate(true))
		control.physical.pending.reports.append(envelope.duplicate(true))
		if not check(
			SeasonSave.save(app.season), "ordinary checkpoint retains verified actual report"
		):
			app.free()
			return
	var terminal: Dictionary = SeasonRoundSettlement.project(app.season)
	if not check(
		terminal.has("candidate") and not terminal.has("fixture") and not terminal.has("error"),
		"normal projection completes without another simulation"
	):
		app.free()
		return
	app.round_ui.resume()
	await _waterfall_settled_round(profile, app)


func _waterfall_settled_round(profile: String, app: SeasonApp) -> void:
	if not check(
		(
			app.season.results.size() == 3
			and app.season.player_results.size() == 1
			and app.season.physical.pending.is_empty()
		),
		"ordinary atomic settlement consumed all three actual reports"
	):
		app.free()
		return
	var cold: SeasonState = SeasonSave.restore()
	if not check(
		(
			cold != null
			and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(app.season))
		),
		"settled variant cold replays normally"
	):
		app.free()
		return
	if not check(app.season.pending_fixture().home == 0, "next real scheduled fixture is home"):
		app.free()
		return
	app._fixture_id = int(app.season.pending_fixture().id)
	var home_state: MatchState = app.season.make_match()
	if not check(
		app._mounted_match_ledger(home_state, true, true) != null,
		"real pending animated home resolves its own paid ledger"
	):
		app.free()
		return
	check(
		(
			app._mounted_match_ledger(home_state, false, true) == null
			and app._mounted_match_ledger(home_state, true, false) == null
		),
		"away and exhibition cannot borrow animated home proof"
	)
	app._fixture_id += 1
	check(
		app._mounted_match_ledger(home_state, true, true) == null,
		"wrong pending fixture cannot borrow animation receipt"
	)
	app._fixture_id = int(app.season.pending_fixture().id)
	var forged: MatchState = app.season.make_match()
	forged.stadium = forged.stadium.duplicate(true)
	forged.stadium.layout.waterfall_motion = (
		["foreign-unowned-copy"] if forged.stadium.layout.waterfall_motion.is_empty() else []
	)
	var before: Dictionary = SeasonSave.snapshot(app.season)
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	app._open_match(forged, true, true)
	check(
		(
			app.lab == null
			and ClubCareer.same(before, SeasonSave.snapshot(app.season))
			and FileAccess.get_file_as_string(SeasonSave.path) == bytes
		),
		"changed motion selection cannot borrow paid snapshot or mutate saved season"
	)
	app.play_season_game()
	if check(
		app.lab != null,
		"ordinary SeasonApp starts paid animated home " + profile + ": " + app.notice
	):
		var lab: PitchBatLab = app.lab
		lab.set_process(false)
		lab.set_physics_process(false)
		lab._pitch_actor.set_physics_process(false)
		lab._primary_fielder.set_physics_process(false)
		check(
			(
				lab._stadium_ledger != null
				and StadiumWaterfallAnimationSnapshot.matches(
					lab._match_state.stadium, lab._stadium_ledger
				)
				and StadiumWaterfallAnimationInstall.installed_bound(lab, lab._match_state.stadium)
			),
			"exact paid animated boundary installed without test ledger injection"
		)
		await _motion_control(lab)
		app._close_match()
		check(app.lab == null, "normal app close releases match")
	app.free()
	await get_tree().process_frame


func _prepare(input: Dictionary) -> Dictionary:
	var previous: SeasonState = SeasonSave._decode(input)
	if previous == null or previous.phase != SeasonState.Phase.COMPLETE:
		return {"ok": false, "error": "Expected cold-valid completed funding career."}
	var paid: ClubAssetLedger = ClubPlayers.assets(previous.career)
	var layout: Dictionary = paid.view().stadium_active.duplicate(true)
	if not StadiumWaterfallLiveItems.is_family(layout) or layout.live_waterfalls.size() != 1:
		return {"ok": false, "error": "Expected one exact installed static45 copy."}
	var copy: String = layout.live_waterfalls[0].copy
	layout = StadiumWaterfallAnimationLayout.select(layout, copy, true, paid.surface_owned())
	var saved: Dictionary = ClubConstruction.save_draft(previous, layout, paid.revision())
	if not saved.ok:
		return saved
	var applied: Dictionary = ClubConstruction.apply_draft(
		previous, layout, ClubPlayers.assets(previous.career).revision()
	)
	if not applied.ok:
		return applied
	return {"ok": true, "error": "", "completed_season": previous}


func _motion_control(lab: PitchBatLab) -> void:
	var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(lab)
	if not check(
		owner != null and owner.intact(), "real public fixture owns exact animation lease"
	):
		return
	owner.set_process(false)
	var property: StadiumWaterfallAnimationProperty = (
		StadiumWaterfallAnimationRuntime.property_claim(lab) as StadiumWaterfallAnimationProperty
	)
	var initial: float = owner._lease.phase
	owner._process(0.1)
	if not check(owner._lease.phase == initial, "real public pre-pitch aiming starts frozen"):
		return
	var copy: String = lab._match_state.stadium.layout.waterfall_motion[0]
	var target: Vector3 = property.objects[copy].global_position + Vector3(0, 1.7, 0)
	var camera: Camera3D = Camera3D.new()
	camera.name = "WaterfallMotionDiagnosticCamera"
	lab.add_child(camera)
	camera.global_position = target + Vector3(-7, 4, -10)
	camera.look_at(target)
	camera.current = true
	await _capture("owned-live-phase-zero")
	lab._match_state.phase = MatchState.Phase.PLAY_DEAD
	lab._at_bat_cadence.state = AtBatCadenceController.State.IDLE
	for index in range(25):
		owner._process(0.1)
	var moving: float = owner._lease.phase
	check(
		moving > initial and owner.intact() and property.props_intact(),
		"real public owner advances only declared phase while quiet"
	)
	await _capture("owned-live-phase-moving")
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	owner._process(0.1)
	check(
		owner._lease.phase == moving and StadiumWaterfallAnimationRuntime.before_pitch(lab),
		"real public aiming freezes moved phase without invalidating paid context"
	)
	camera.global_position = Vector3(0, 24, -10)
	camera.look_at(Vector3(0, 0, 13))
	await _capture("owned-live-field-overview")
	camera.queue_free()
	await get_tree().process_frame


func _capture(label: String) -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--motion-capture-dir="):
			output = argument.trim_prefix("--motion-capture-dir=")
	if output.is_empty():
		return
	if not check(
		output.is_absolute_path() and DisplayServer.get_name() != "headless",
		"native capture requires explicit absolute directory and real display"
	):
		return
	DirAccess.make_dir_recursive_absolute(output)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	check(
		image != null and image.save_png(output.path_join(label + ".png")) == OK,
		"preserve actual native viewport " + label
	)


func _profile_label() -> String:
	return "live45-motion"
