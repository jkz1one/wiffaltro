extends "res://src/tests/stadium_lighting_kit_route_test.gd"
const REUSE = preload("res://src/tests/stadium_lighting_kit_round_reuse.gd")
var _reuse_result: Dictionary = {}
var _new_simulated_games: int = 0
var _stage_file: FileAccess
var _stage_started: int = 0
var _stage_sequence: int = 0


func _ready() -> void:
	_stage_started = Time.get_ticks_usec()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--game-stage-output="):
			var path: String = argument.trim_prefix("--game-stage-output=")
			if not _check(
				path.is_absolute_path() and not FileAccess.file_exists(path),
				"fresh explicit full-game stage output"
			):
				get_tree().quit(1)
				return
			_stage_file = FileAccess.open(path, FileAccess.WRITE)
			if not _check(_stage_file != null, "open durable full-game stage output"):
				get_tree().quit(1)
				return
	_stage("test", "begin")
	var pattern: String = "PARALLEL"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--route-pattern="):
			pattern = arg.trim_prefix("--route-pattern=")
	SeasonSave.path = "user://kit-fixture36-round-reuse-%d.json" % OS.get_process_id()
	for suffix: String in ["", ".bak", ".tmp"]:
		if not _check(
			not FileAccess.file_exists(SeasonSave.path + suffix),
			"fresh isolated ordinary save path" + suffix
		):
			get_tree().quit(1)
			return
	_check(CANDIDATE.PUBLIC_READY, "isolated synthetic registry required, release remains closed")
	if failures.is_empty():
		await _public_case(pattern)
	_stage(
		"test",
		"end",
		{"checks": checks, "failures": failures, "new_simulated_games": _new_simulated_games}
	)
	print(
		"KIT_FIXTURE36_ROUND_REUSE_RESULT ",
		JSON.stringify(
			{
				"checks": checks,
				"failures": failures,
				"reuse": _reuse_result,
				"new_simulated_games": _new_simulated_games,
				"optical_qualification": false
			}
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _public_case(pattern: String) -> void:
	var wrapper: String = "47-46"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--wrapper="):
			wrapper = argument.trim_prefix("--wrapper=")
	if not _check(wrapper in ["46", "47-45", "47-46"], "explicit successor test composition"):
		return
	_stage("retained_career_construction", "begin")
	var fixture: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://src/tests/lighting_audit_verified_season_fixture.json")
	)
	var completed: SeasonState = SeasonSave._decode(fixture)
	if not _check(completed != null, "verified 41-season synthetic fixture cold-loads"):
		return
	var legacy: ClubAssetLedger = ClubPlayers.assets(completed.career)
	var prefix: ClubAssetLedger = legacy.prefix(41)
	if not _check(
		(
			prefix != null
			and legacy.to_data().events[41].op == "stadium_land"
			and prefix.view().land == "backyard"
		),
		"exact pre-land historical paid prefix, no invented income"
	):
		return
	fixture.career.assets = prefix.to_data()
	completed = SeasonSave._decode(fixture)
	if not _check(completed != null, "whole career validates retained Backyard prefix"):
		return
	_check(SeasonSave.save(completed), "initial supported full file save")
	await _round_reuse_draft(pattern, wrapper, completed)


func _round_reuse_draft(pattern: String, wrapper: String, completed: SeasonState) -> void:
	var paid: ClubAssetLedger = ClubPlayers.assets(completed.career)
	var revision: int = paid.revision()
	var bought: Dictionary = ClubConstruction.buy_copy(completed, "ST-111", revision, 1)
	if not _check(bought.ok, "supported paid kit purchase: " + bought.error):
		return
	paid = ClubPlayers.assets(completed.career)
	var layout: Dictionary = StadiumLightingKitItems.place(
		paid.view().stadium_draft,
		paid.construction(),
		"purchase:stadium-buy:%d:0" % revision,
		pattern,
		0,
		paid.surface_owned()
	)
	# Explicit supported rough-dirt choice; legacy fixture starts prepared.
	layout.surface = CANDIDATE.DEFAULT_SURFACE.duplicate(true)
	if pattern == "MIXED_EDGE":
		revision = paid.revision()
		bought = ClubConstruction.buy_copy(completed, "ST-037", revision, 2)
		if not _check(bought.ok, "separate supported rear-pole purchase"):
			return
		paid = ClubPlayers.assets(completed.career)
		layout.lights = [
			{"copy": "purchase:stadium-buy:%d:0" % revision, "site": "YLIGHT-RL"},
			{"copy": "purchase:stadium-buy:%d:1" % revision, "site": "YLIGHT-RR"}
		]
	# Explicit supported complete successor draft, with the same purchased copies.
	# These wrappers are not a user-visible Night option or a new purchase.
	layout = (
		StadiumLowWallLayout.upgrade(layout, paid.surface_owned())
		if wrapper != "47-45"
		else StadiumWaterfallLiveItems.upgrade(layout, paid.surface_owned())
	)
	if wrapper.begins_with("47"):
		layout = StadiumWaterfallAnimationLayout.upgrade(layout, paid.surface_owned())
	var result: Dictionary = ClubConstruction.save_draft(completed, layout, paid.revision())
	if not _check(result.ok, "supported complete kit draft: " + result.error):
		return
	paid = ClubPlayers.assets(completed.career)
	result = ClubConstruction.apply_draft(completed, layout, paid.revision())
	if not _check(result.ok, "supported Apply of exact rough dirt: " + result.error):
		return
	var source_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--exact-round-bundle="):
			source_path = argument.trim_prefix("--exact-round-bundle=")
	var bundle: Dictionary = REUSE.load_exact(source_path)
	if not _check(not bundle.is_empty(), "original actual three-game bundle SHA exact"):
		return
	var career: ClubCareer = completed.career
	if not _check(career.close(completed), "close completed retained synthetic season normally"):
		return
	await _round_reuse_live_season(bundle, career)


func _round_reuse_live_season(bundle: Dictionary, career: ClubCareer) -> void:
	var season: SeasonState = SeasonState.create(51, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = career
	if not _check(
		ClubPlayerDraft.apply(season, ClubPlayers.owned(career)) and career.start(season),
		"ordinary seed51/policy13 career start"
	):
		return
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(career))
	season.owned_surface_night = StadiumSurfaceNightSnapshot.capture_policy(
		season, ClubPlayers.assets(career)
	)
	if not _check(
		not season.owned_surface_night.is_empty(),
		"exact paid fixed-Night policy captured without changing away fixtures"
	):
		return
	for index in range(4):
		if not _check(
			not season.offers().is_empty() and season.choose_player(season.offers()[0]),
			"ordinary original draft choice"
		):
			return
	if not _check(SeasonSave.save(season), "initial exact Night season saved before reuse"):
		return
	_stage("retained_career_construction", "end")
	var app: SeasonApp = SeasonApp.new()
	_stage("actual_app_cold_ready", "begin")
	add_child(app)
	_stage("actual_app_cold_ready", "end")
	app.set_process(false)
	if not _check(
		(
			app.season != null
			and ClubCareer.same(SeasonSave.snapshot(app.season), SeasonSave.snapshot(season))
		),
		"actual app cold-loads initial candidate season"
	):
		app.free()
		return
	_stage("exact_previous_round_recovery", "begin", {"source_bundle_sha256": REUSE.SOURCE_SHA256})
	_reuse_result = REUSE.recover(app, bundle)
	_stage("exact_previous_round_recovery", "end", _reuse_result)
	if _check(
		not _reuse_result.has("error"),
		"strict unchanged-request recovery: " + str(_reuse_result.get("error", ""))
	):
		var pending: Dictionary = app.season.pending_fixture()
		var state: MatchState = app.season.make_match()
		var actual_home: bool = _check(
			pending.id == 3 and pending.home == 0 and app.season.round_index == 1,
			"genuine normally settled home cursor, not a future fixture edit"
		)
		var actual_receipt: bool = _check(
			(
				state != null
				and state.stadium.version == 36
				and StadiumSurfaceNightSnapshot.matches_fixture(
					state.stadium, app.season, pending, ClubPlayers.assets(app.season.career)
				)
			),
			"actual pending home receives exact original paid fixture36"
		)
		if actual_home and actual_receipt and failures.is_empty():
			await _exercise_settled(app)
	_stage("app_cleanup", "begin")
	app.free()
	_stage("app_cleanup", "end")
	await get_tree().process_frame


func _exercise_settled(_app: SeasonApp) -> void:
	pass  # A later actual-game harness may override; this test does not simulate a new game.


func _stage(label: String, phase: String, details: Dictionary = {}) -> void:
	_stage_sequence += 1
	var row: Dictionary = {
		"sequence": _stage_sequence,
		"stage": label,
		"phase": phase,
		"elapsed_us": Time.get_ticks_usec() - _stage_started,
		"details": details
	}
	if _stage_file != null:
		_stage_file.store_line(JSON.stringify(row, "", true, true))
		_stage_file.flush()
		_check(_stage_file.get_error() == OK, "durable stage marker: " + label + "/" + phase)
	print("KIT_FULL_GAME36_STAGE ", JSON.stringify(row, "", true, true))
