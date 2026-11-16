extends "res://src/tests/dynasty_standard_season_run_test.gd"
## Same genuine batch runner, plus narrow actual Night18 provenance assertions.
## Two separately reviewable batches: opening0–2, then natural home3 plus AI4–5.
var night_stage: String = ""
var night_pending_verified: bool = false
var actual_night_humans: int = 0
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--night-stage="):
			night_stage = arg.trim_prefix("--night-stage=")
		if arg.begins_with("--season-rounds=") and arg != "--season-rounds=1":
			check(false, "Night proof accepts exactly one bounded round per handoff")
			return
	if not check(night_stage in ["opening", "home"] and input.is_absolute_path()
		and DirAccess.dir_exists_absolute(input), "explicit bounded Night stage and existing isolated owner"):
		return
	var path: String = input.path_join("owner.json")
	if not check(not FileAccess.file_exists(path + ".intent"), "no unresolved intent before Night inspection"):
		return
	var found: Dictionary = Store.inspect(path)
	if not check(found.get("status") == "ready" and found.owner.selected == "other", "ready Night owner selected"):
		return
	var entry: Dictionary = found.owner.career.sessions.get(found.owner.other.session_id, {})
	if not check(entry.get("session", {}).get("starting_profile") == "night"
		and entry.get("session", {}).get("format") == 89 and entry.get("settled") == 0,
		"fixed admitted Night89 session, no mode retrofit"):
		return
	await super._run()
	if failures > 0 or not is_instance_valid(app):
		return
	if stop_after_human:
		if not check(human_games == 1 and reports == 0 and completed_batches == 0
			and not app.season.physical.pending.is_empty()
			and (night_stage != "home" or (night_pending_verified and actual_night_humans == 1)),
			"explicit durable human-only Night handoff; no Continue or AI games"):
			return
		_write("night-human-handoff-summary.json", {"stage": night_stage,
			"new_human_games": human_games, "new_ai_games": reports,
			"night_pending_verified": night_pending_verified,
			"actual_night_humans": actual_night_humans,
			"continue_qualified": false, "round_completed": false})
		return
	var round: int = 1 if night_stage == "opening" else 2
	if not check(completed_batches == 1 and app.season.round_index == round
		and app.season.results.size() == round * 3 and app.season.player_results.size() == round
		and app.season.physical.reports.size() == round * 2 and app.season.physical.pending.is_empty(),
		"exact bounded genuine round completed with unchanged schedule"):
		return
	if night_stage == "home":
		var result: Dictionary = app.season.player_results.back()
		check(night_pending_verified and result.id == 3 and result.has("night_evidence")
			and StadiumSurfaceNightHumanEvidence.valid(result.night_evidence)
			and not result.has("yard_evidence") and not result.has("pool_evidence"),
			"settled actual home result retains real Night evidence")
	var before: Dictionary = Store.inspect(owner_path).owner
	var tree_before: Dictionary = _hash_tree(input)
	var snapshot: Dictionary = SeasonSave.snapshot(app.season)
	var cold: SeasonState = SeasonSave.restore()
	if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "independent cold Night owner restore exact"):
		return
	check(SeasonSave.save(cold), "save actual cold-restored bound Night object")
	check(ClubCareer.same(before, Store.inspect(owner_path).owner)
		and ClubCareer.same(tree_before, _hash_tree(input)), "cold retry preserves entire owner and byte tree")
	_write("night-physical-summary.json", {"checks": checks, "failures": failures,
		"stage": night_stage, "new_human_games": human_games, "new_ai_games": reports,
		"actual_night_humans": actual_night_humans, "night_pending_verified": night_pending_verified,
		"owner_revision": before.revision, "owner_path": owner_path,
		"synthetic_startup_funding": true, "physical_results_synthetic": false,
		"manual_input_qualified": false, "default_process_route_qualified": false,
		"full_season_qualified": false})
func _human_game() -> bool:
	var fixture: Dictionary = app.season.pending_fixture()
	var expected_id: int = 0 if night_stage == "opening" else 3
	if not check(fixture.id == expected_id and app.season.owned_surface_night.get("mode") == "night"
		and (fixture.home == 0) == (night_stage == "home"), "natural stage fixture and immutable Night policy"):
		return false
	if not await super._human_game():
		return false
	if night_stage == "opening":
		return check(not StadiumSurfaceNightHumanEvidence.expected(app.season, fixture), "opening away venue keeps its own profile")
	if not _verify_night_pending():
		return false
	var lab: PitchBatLab = app.lab
	var human: Array = app.season.physical.pending.human
	var captured: Dictionary = StadiumSurfaceNightHumanEvidence.capture(lab, app.season)
	if not check(lab._player_home and lab._npc_season == app.season
		and lab._match_state.phase == MatchState.Phase.GAME_END
		and not captured.is_empty() and ClubCareer.same(captured, human[17]),
		"Night18 evidence exactly recaptures genuine live terminal runtime"):
		return false
	actual_night_humans += 1
	_write("actual-night-human18.json", {"human": human})
	_write("actual-night-runtime-evidence.json", captured)
	return true
func _finish_pending(old_players: int) -> bool:
	if night_stage == "home":
		if not app.season.physical.pending.is_empty() and not _verify_night_pending():
			return false
		if not check(night_pending_verified, "Night pending verified before final transition"):
			return false
	return await super._finish_pending(old_players)
func _verify_night_pending() -> bool:
	var human: Array = app.season.physical.pending.get("human", [])
	var fixture: Dictionary = app.season.pending_fixture()
	if not check(fixture.id == 3 and fixture.home == 0 and human.size() == 18
		and human[0] == 3 and human[13] is Array and human[13].is_empty()
		and human[15] == null and human[16] == null
		and StadiumSurfaceNightHumanEvidence.valid(human[17])
		and human[14] == StadiumLayoutSnapshot.key(human[17].property)
		and StadiumSurfaceNightHumanEvidence.accepts(app.season, fixture, human[17],
			int(human[1]), int(human[2]), human[3], human[12]),
		"actual saved Night18 exact property/null slots and full existing acceptance"):
		return false
	night_pending_verified = true
	_write("verified-night-pending89.json", SeasonSave.snapshot(app.season))
	return true
func _write(name: String, value: Dictionary) -> void:
	if night_stage == "home" and name.begins_with("resumed-pending-"):
		if not _verify_night_pending():
			return
	var file: FileAccess = FileAccess.open(output.path_join(name), FileAccess.WRITE)
	if not check(file != null, "artifact writable " + name):
		return
	file.store_string(JSON.stringify(value, "", true, true))
