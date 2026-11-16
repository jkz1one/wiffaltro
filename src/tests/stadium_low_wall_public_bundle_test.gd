extends Node
## Reuses only unchanged actually executed reports through ordinary settlement.
const VariantSetup = preload("res://src/tests/stadium_low_wall_public_variant.gd")
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> bool:
	checks += 1
	print(
		(
			"LOW_PUBLIC_PROGRESS "
			+ JSON.stringify(
				{"check": checks, "label": label, "ok": ok, "time_ms": Time.get_ticks_msec()}
			)
		)
	)
	if not ok:
		failures.append(label)
		push_error("LOW_PUBLIC_BUNDLE " + label)
	return ok


func _ready() -> void:
	var input: String = ""
	var evidence: String = ""
	var funding40: String = ""
	var selected: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--funding-input="):
			input = arg.trim_prefix("--funding-input=")
		if arg.begins_with("--round-bundle="):
			evidence = arg.trim_prefix("--round-bundle=")
		if arg.begins_with("--funding40-input="):
			funding40 = arg.trim_prefix("--funding40-input=")
		if arg.begins_with("--profile="):
			selected = arg.trim_prefix("--profile=")
	if not check(
		selected.is_empty() or selected in StadiumLowWallRecipes.PROFILES,
		"selected profile is authored"
	):
		get_tree().quit(1)
		return
	if check(
		FileAccess.file_exists(input) and FileAccess.file_exists(evidence),
		"explicit original funding and actual evidence supplied"
	):
		var funding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input))
		var bundle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(evidence))
		if not funding40.is_empty():
			funding = _rebuild_funding(funding40, funding)
		if check(
			(
				not funding.is_empty()
				and bundle.get("schema") == "waterfall-public-actual-round-v1"
				and bundle.get("completed_physical_games") == 3
			),
			"exact actually completed three-game bundle"
		):
			for profile: String in StadiumLowWallRecipes.PROFILES:
				if selected.is_empty() or selected == profile:
					await _profile(funding, bundle, profile)
	print(
		(
			"LOW_PUBLIC_BUNDLE_RESULT "
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
	var branch: Dictionary = VariantSetup.prepare(funding, profile)
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
		(
			"LOW_PUBLIC_FIXTURE_COMPARE "
			+ JSON.stringify(
				{
					"profile": profile,
					"actual": fixture,
					"cold_control": control.pending_fixture(),
					"bundle": bundle.human_fixture,
					"native_bundle_equal": fixture == bundle.human_fixture,
					"native_control_equal": fixture == control.pending_fixture(),
					"canonical_bundle_equal": ClubCareer.same(fixture, bundle.human_fixture)
				}
			)
		)
	)
	# The persisted bundle has JSON numeric variants; compare exact canonical
	# serialization, while the cold-decoded native control remains exact too.
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
	SeasonSave.path = "user://low-public-bundle-" + profile + ".json"
	await _low_wall_settle_variant(bundle, profile, season, control)


func _low_wall_settle_variant(
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
	await _low_wall_settled_round(profile, app)


func _low_wall_settled_round(profile: String, app: SeasonApp) -> void:
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
	var home_fixture: Dictionary = app.season.pending_fixture()
	var original_state: MatchState = app.season.make_match()
	app._fixture_id = int(home_fixture.id)
	check(
		app._mounted_match_ledger(original_state, true, true) != null,
		"current pending home resolves its paid prefix"
	)
	check(
		(
			app._mounted_match_ledger(original_state, false, true) == null
			and app._mounted_match_ledger(original_state, true, false) == null
		),
		"away and exhibition cannot borrow paid home ledger"
	)
	app._fixture_id += 1
	check(
		app._mounted_match_ledger(original_state, true, true) == null,
		"wrong pending fixture refuses paid ledger"
	)
	app._fixture_id = int(home_fixture.id)
	var forged: MatchState = app.season.make_match()
	forged.stadium = forged.stadium.duplicate(true)
	forged.stadium.layout.low_wall.copies[0] = "unowned-public-low-copy"
	var before: Dictionary = SeasonSave.snapshot(app.season)
	var saved_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	app._open_match(forged, true, true)
	check(
		(
			app.lab == null
			and ClubCareer.same(before, SeasonSave.snapshot(app.season))
			and FileAccess.get_file_as_string(SeasonSave.path) == saved_bytes
		),
		"forged low request fails before allocation without save mutation"
	)
	print(
		(
			"LOW_PUBLIC_START_BEGIN "
			+ JSON.stringify({"profile": profile, "time_ms": Time.get_ticks_msec()})
		)
	)
	app.play_season_game()
	print(
		(
			"LOW_PUBLIC_START_END "
			+ JSON.stringify({"profile": profile, "time_ms": Time.get_ticks_msec()})
		)
	)
	if check(
		app.lab != null, "ordinary SeasonApp starts paid low home " + profile + ": " + app.notice
	):
		var lab: PitchBatLab = app.lab
		lab.set_process(false)
		lab.set_physics_process(false)
		lab._pitch_actor.set_physics_process(false)
		lab._primary_fielder.set_physics_process(false)
		check(
			(
				lab._stadium_ledger != null
				and StadiumLowWallSnapshot.matches(lab._match_state.stadium, lab._stadium_ledger)
				and StadiumLowWallRuntime.installed_bound(lab, lab._match_state.stadium)
			),
			"exact paid low boundary installed without test ledger injection"
		)
		var property: StadiumLowWallProperty = (
			lab.get_meta("stadium_property") as StadiumLowWallProperty
			if lab.has_meta("stadium_property")
			else null
		)
		if check(
			property != null and lab._npc_season == app.season,
			"public low owner captures actual current season"
		):
			var owner: SeasonState = app.season
			app.season = null
			check(
				(
					not property.low_context_intact()
					and not (
						(property.get_node("BoundaryGraph") as StadiumLowWallBoundaryRuntime)
						. intact()
					)
				),
				"public owner season replacement revokes issued authority"
			)
			app.season = owner
		app._close_match()
		check(app.lab == null, "normal app close releases match")
	app.free()
	await get_tree().process_frame


func _rebuild_funding(path: String, original: Dictionary) -> Dictionary:
	if not check(
		FileAccess.file_exists(path), "retained pre-purchase40-season funding file exists"
	):
		return {}
	var prior: SeasonState = SeasonSave._decode(
		JSON.parse_string(FileAccess.get_file_as_string(path))
	)
	if not check(
		prior != null and prior.career != null and prior.phase == SeasonState.Phase.COMPLETE,
		"retained funding cold-validates before purchases"
	):
		return {}
	var history: Array = original.career.runs
	if not check(
		(
			prior.career.to_data().runs.size() == 40
			and ClubCareer.same(prior.career.to_data().runs, history.slice(0, 40))
		),
		"all40 original synthetic funding runs match, no edited outcomes"
	):
		return {}
	var career: ClubCareer = prior.career
	if not check(career.close(prior), "close retained completed funding season normally"):
		return {}
	# This is exactly one existing score-only FUNDING fixture, not a physical
	# game or report. The three modern reports remain the untouched real bundle.
	var completed: SeasonState = StadiumPennantRewardRebuildChecks._new(career)
	if not check(
		(
			completed != null
			and StadiumPennantRewardRebuildChecks._finish(completed)
			and career.sync(completed)
		),
		"existing synthetic funding generator advances normally to41"
	):
		return {}
	return _funding_history_parity(history, career, completed)


func _funding_history_parity(
	history: Array, career: ClubCareer, completed: SeasonState
) -> Dictionary:
	if not check(
		ClubCareer.same(career.to_data().runs, history),
		"all41 synthetic funding run records exactly match original source"
	):
		return {}
	var saved: Dictionary = SeasonSave.snapshot(completed)
	if not check(
		not saved.is_empty() and SeasonSave._decode(saved) != null,
		"pre-purchase41 branch cold-validates with actual ledger replay"
	):
		return {}
	var out: FileAccess = FileAccess.open(
		"user://low-wall-pre-purchase41-funding.json", FileAccess.WRITE
	)
	out.store_string(JSON.stringify(saved, "", true, true))
	out.close()
	return saved
