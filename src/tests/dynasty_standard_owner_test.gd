extends Node
## Isolated Store protocol; no physical game or production activation claim.
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
const Proposal = preload("res://src/gameplay/season/dynasty_standard_proposal.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
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
var live_format: bool = false
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--live-format":
			live_format = true
		if argument.begins_with("--standard-owner-root="):
			path = argument.trim_prefix("--standard-owner-root=")
	if not path.is_absolute_path() or DirAccess.dir_exists_absolute(path):
		push_error("Fresh isolated --standard-owner-root required")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(path)
	path = path.path_join("owner.json")
	_run()
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	print("DYNASTY_STANDARD_OWNER: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _run() -> void:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = Fixture.prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}])
	check(source.career != null and source.career.start(source), "synthetic title prefix normal source")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin draft")
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
	var proposal: Dictionary = Proposal.prepare(admission, 38200, 0)
	check(not proposal.is_empty(), "owned Standard proposal")
	if proposal.is_empty():
		return
	var standard: SeasonState = SeasonSave._decode(proposal.snapshot)
	var context: Dictionary = Bound.binding_for(standard, grant, initial.owner_id, initial.lineage.id, 0, 1, "disk-standard:1")
	if live_format:
		context["format"] = Bound.LIVE_VERSION
		context = Bound.binding(context)
		standard = Live.create(grant, context)
		check(standard != null, "live-format owned Standard candidate")
		if standard == null:
			return
	var snapshot: Dictionary = Bound.capture(standard, context, grant, admission)
	check(not snapshot.is_empty(), "bound mixed-history Standard snapshot")
	if snapshot.is_empty():
		return
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
	check(opened.status == "committed", "exact retry commits bound Standard: " + str(opened.get("reason", "")))
	if opened.status != "committed":
		return
	check(opened.owner.lineage.state == "paused", "Dynasty paused not abandoned")
	check(Store.restore(path).status == "committed", "cold disk restore bound Standard")
	check(ClubCareer.same(Store.transact(request, path).owner, opened.owner), "admission retry no duplicate row")
	check(Owner.validate_selected(opened.owner, forged.snapshot) == null, "fixed committed witness rejects forged snapshot")
	if live_format:
		check(SeasonSave.bind_dynasty_owner(path), "bind public dispatcher to actual owner")
		standard = SeasonSave.restore()
		check(standard != null and standard.career == null, "public restore has no duplicate wallet")
		if standard == null:
			return
		check(SeasonSave.snapshot(standard).get("version") == Bound.LIVE_VERSION, "public snapshot retains89")
	for pick in range(4):
		check(standard.choose_player(standard.offers()[0]), "Standard draft")
	if live_format:
		check(SeasonSave.save(standard), "public bound Standard draft save")
		check(SeasonSave.restore() != null, "public cold restore after draft save")
	var drafted: Dictionary = Bound.capture(standard, context, grant, admission)
	var checkpoint: Dictionary = _step("checkpoint", {"session_id": context.session_id, "snapshot": drafted})
	if checkpoint.get("status") != "committed":
		return
	var restored: Dictionary = Store.restore(path)
	check(restored.status == "committed" and restored.qualified_selected_season.picks.size() == 4, "cold disk draft restore")
	var closed: Dictionary = _step("close", {"session_id": context.session_id, "reason": "abandon"})
	if closed.get("status") != "committed":
		return
	check(closed.owner.career.settlements.size() == 1, "one Standard settlement")
	check(Authority.view(closed.owner.career).balance == Authority.view(admission).balance, "no duplicate or abandon payout")
	var resumed: Dictionary = _step("switch", {"target": "dynasty"})
	if resumed.get("status") != "committed":
		return
	check(Profile.same(resumed.owner.dynasty.reference, initial.dynasty.reference), "exact Dynasty checkpoint retained")
	check(Store.restore(path).status == "committed", "Dynasty cold resume after Standard")
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
