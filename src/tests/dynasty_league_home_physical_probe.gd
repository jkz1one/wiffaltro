extends Node
## Isolated Store protocol; no physical game or production activation claim.
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Closed = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner.gd")
var checks: int = 0
var failures: int = 0
var path: String = ""
var physical_games: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PHYSICAL_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--league-home-physical-root="):
			path = argument.trim_prefix("--league-home-physical-root=")
	if not path.is_absolute_path() or DirAccess.dir_exists_absolute(path):
		push_error("Fresh isolated --standard-owner-root required")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(path)
	SeasonSave.path = path.path_join("season.json")
	path = SeasonSave.path + ".dynasty-owner"
	await _run()
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	print("DYNASTY_LEAGUE_HOME_PHYSICAL: %d checks, %d failures, physical_human_games=%d" % [checks, failures, physical_games])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _source() -> SeasonState:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = Fixture.prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}])
	return source
func _run() -> void:
	var source: SeasonState = _source()
	check(source.career != null and source.career.start(source), "synthetic title prefix normal source")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin draft")
	check(SeasonSave.save(source), "isolated ordinary source saves")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "disk-standard-lineage", "disk-standard-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	check(dynasty != null, "Dynasty source")
	if dynasty == null:
		return
	var dynasty_context: Dictionary = Closed.binding_for(dynasty, profile.owner_id, profile.lineage_id, 0, 1, "disk-standard-lineage:1")
	var dynasty_snapshot: Dictionary = Closed.wrap_checkpoint(SeasonSave.snapshot(dynasty), dynasty_context)
	var created: Dictionary = Store.create({"lineage": Lineage.create(profile), "snapshot": dynasty_snapshot,
		"session_id": dynasty_context.session_id, "origin": origin}, path)
	check(created.status == "committed", "owner created: " + str(created.get("reason", "")))
	if created.status != "committed":
		return
	var initial: Dictionary = created.owner
	var admission: Dictionary = initial.career
	var grant: Dictionary = Grant.capture(admission)
	var context: Dictionary = Closed.binding({"owner_id": initial.owner_id,
		"lineage_id": initial.lineage.id, "generation": 0, "ordinal": 1,
		"session_id": "home-dugout:1", "seed": 38200, "tier": 0, "league": "dugout",
		"access_sha256": ClosedContentAccess.digest(grant.access)})
	var snapshot: Dictionary = Bound.prepare(admission, context)
	check(not snapshot.is_empty(), "bound mixed-history Standard snapshot")
	if snapshot.is_empty():
		return
	var bad_home: Dictionary = snapshot.duplicate(true)
	bad_home.home_property = {}
	check(Bound.qualify(bad_home, admission).is_empty(), "changed home rejected at admission")
	var bad_session: Dictionary = snapshot.duplicate(true)
	bad_session.session.session_id = "foreign-session"
	check(Bound.qualify(bad_session, admission).is_empty(), "cross-session envelope rejected")
	check(SeasonSave._decode(snapshot) == null, "unbound public restore refuses staged envelope")
	var request: Dictionary = {"op": "switch", "request_id": "open-standard", "expected_revision": initial.revision,
		"target": "other", "session_id": context.session_id, "snapshot": snapshot}
	Store._test_stop_after = "intent.rename"
	var interrupted: Dictionary = Store.transact(request, path)
	Store._test_stop_after = ""
	check(interrupted.status == "not_committed", "interrupted admission has no commit: " + str(interrupted))
	check(Store.inspect(path).status == "pending", "admission intent retained")
	var forged: Dictionary = request.duplicate(true)
	forged.snapshot.grant.access.progress.rain_start = not forged.snapshot.grant.access.progress.rain_start
	check(Store.transact(forged, path).status == "blocked", "altered intent grant refused")
	var opened: Dictionary = Store.transact(request, path)
	check(opened.status == "committed", "exact retry commits owned alternate: " + str(opened.get("reason", "")))
	if opened.status != "committed":
		return
	check(opened.owner.lineage.state == "paused", "Dynasty paused not abandoned")
	check(Store.restore(path).status == "committed", "cold disk restore owned alternate")
	check(ClubCareer.same(Store.transact(request, path).owner, opened.owner), "admission retry no duplicate row")
	check(Owner.validate_selected(opened.owner, forged.snapshot) == null, "fixed committed witness rejects forged snapshot")
	check(SeasonSave.bind_dynasty_owner(path), "bind public dispatcher to live owner")
	var standard: SeasonState = SeasonSave.restore()
	check(standard != null and standard.career == null and not standard.home_property.is_empty(),
		"cold restore has owned home and no second wallet")
	if standard == null:
		return
	check(SeasonSave.snapshot(standard).get("version") == Bound.VERSION, "snapshot retains91")
	for pick in range(4):
		check(standard.choose_player(standard.offers()[0]), "alternate draft")
	check(SeasonInventoryRules.enable(standard), "four-pick live inventory contract")
	check(SeasonPhysicalFixtures.match_for(standard, standard.pending_fixture()) != null,
		"supported Dugout match reconstructs")
	var drafted: Dictionary = Bound.capture(standard)
	var checkpoint: Dictionary = _step("checkpoint", {"session_id": context.session_id, "snapshot": drafted})
	if checkpoint.get("status") != "committed":
		return
	var restored: Dictionary = Store.restore(path)
	check(restored.status == "committed" and restored.qualified_selected_season.picks.size() == 4, "cold disk draft restore")
	SeasonSave._dynasty_owner_path = ""
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	app.child_entered_tree.connect(func(child: Node) -> void:
		if child is PitchBatLab:
			child._automation = MatchAutomation.new()
			child._automation.seed = SeasonPhysicalFixtures.seed_for(app.season, app.season.pending_fixture())
	)
	add_child(app)
	# Native boot yields for its loading overlay before restoring the owner.
	# Wait without bypassing the ordinary initialization route.
	for frame in range(600):
		if not app._loading_boot:
			break
		await get_tree().process_frame
	check(not app._loading_boot and app.season != null and app.dynasty_owner.ready(), "actual main restores live owner")
	if app._loading_boot or app.season == null:
		app.free()
		return
	await _play_rounds(app)
	app.free()

func _play_rounds(app: SeasonApp) -> void:
	for game in range(2):
		var fixture: Dictionary = app.season.pending_fixture().duplicate(true)
		print("PHYSICAL_BEGIN ", fixture)
		app.play_season_game()
		await get_tree().process_frame
		check(is_instance_valid(app.lab), "actual main opens physical match: " + app.notice)
		if not is_instance_valid(app.lab):
			break
		if fixture.home == 0:
			check(not app.lab._match_state.stadium.is_empty()
				and StadiumBoundaryRuntime.installed(app.lab, app.lab._match_state.stadium),
				"owned home boundary actually installed")
		var completed: bool = false
		for frame in range(300000):
			await get_tree().physics_frame
			if is_instance_valid(app.lab) and app.lab._match_state.phase == MatchState.Phase.GAME_END:
				if app.lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD:
					app.finish_game()
			if app.season != null and app.season.player_results.size() > game and not app._busy:
				completed = true
				break
			if frame % 10000 == 0:
				print("PHYSICAL_PROGRESS ", game, " frame=", frame, " notice=", app.notice)
		check(completed, "real human and NPC round settles")
		if not completed:
			break
		physical_games += 1
		check(SeasonSave.restore() != null, "physical round cold restore")
		print("PHYSICAL_ROUND_SAVED ", game, " result=", app.season.player_results[-1])
	check(physical_games == 2, "away and owned-home rounds physically played")

func _step(op: String, operands: Dictionary) -> Dictionary:
	var owner: Dictionary = Store.inspect(path).get("owner", {})
	if owner.is_empty():
		check(false, "missing current owner for " + op)
		return {}
	var request: Dictionary = {"op": op, "request_id": "standard:%s:%d" % [op, owner.revision], "expected_revision": owner.revision}
	request.merge(operands)
	var result: Dictionary = Store.transact(request, path)
	check(result.status == "committed", op + " committed: " + str(result.get("reason", "")))
	if result.status == "committed":
		check(ClubCareer.same(Store.transact(request, path).owner, result.owner), op + " exact retry")
	return result
