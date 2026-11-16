extends Node
## Synthetic owner/paid-ledger routing, not a rendered install or physical game.
const Runtime = preload("res://src/gameplay/season/dynasty_standard_runtime.gd")
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Main = preload("res://src/presentation/season/season_app.tscn")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("STANDARD_RUNTIME_LEDGER_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runtime-ledger-root="):
			root = arg.trim_prefix("--runtime-ledger-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	_run(root.path_join("owner.json"))
	SeasonSave._dynasty_owner_path = ""
	print("STANDARD_RUNTIME_LEDGER checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _run(path: String) -> void:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = preload("res://src/tests/league_unlock_fixture.gd").prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}])
	check(source.career.start(source), "ordinary origin")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin pick")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "runtime-lineage", "runtime-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	if not check(dynasty != null, "Dynasty source"):
		return
	var context: Dictionary = Save.binding_for(dynasty, profile.owner_id, profile.lineage_id, 0, 1, "runtime-lineage:1")
	var created: Dictionary = Store.create({"lineage": Lineage.create(profile),
		"snapshot": Save.wrap_checkpoint(SeasonSave.snapshot(dynasty), context),
		"session_id": context.session_id, "origin": origin}, path)
	if not check(created.status == "committed", "owner created: " + str(created.get("reason", ""))):
		return
	var owner: Dictionary = created.owner
	var grant: Dictionary = Grant.capture(owner.career)
	context = Bound.binding({"owner_id": owner.owner_id, "lineage_id": owner.lineage.id,
		"generation": 0, "ordinal": 1, "session_id": "runtime-standard:1", "seed": 301,
		"tier": 0, "league": "standard", "format": 89,
		"grant_sha256": Save.snapshot_reference(grant).sha256})
	var live: SeasonState
	# Admission requires a fresh pre-draft session, then normal public saves.
	live = Live.create(grant, context)
	check(Runtime.paid_ledger(live) == null and not ClubPlayerLegend.enabled(live), "unadmitted context cannot authorize ledger or collector")
	var opened: Dictionary = Store.transact({"op": "switch", "request_id": "runtime-open",
		"expected_revision": owner.revision, "target": "other", "session_id": context.session_id,
		"snapshot": Bound.capture(live, context, grant, owner.career)}, path)
	if not check(opened.status == "committed" and SeasonSave.bind_dynasty_owner(path), "admit live Standard"):
		return
	live = SeasonSave.restore()
	for pick in range(4):
		check(live.choose_player(live.offers()[0]), "owned pick")
	if not check(SeasonSave.save(live), "saved owned draft"):
		return
	var before: Dictionary = SeasonSave.snapshot(live)
	var paid: ClubAssetLedger = Runtime.paid_ledger(live)
	if not check(paid != null, "qualified frozen paid ledger"):
		return
	check(ClubCareer.same(paid.to_data(), live._pool_replay_ledger.to_data()), "exact frozen paid prefix")
	check(paid != live._pool_replay_ledger, "detached paid ledger")
	check(ClubPlayerLegend.enabled(live), "qualified Standard89 fielding collector")
	var app: SeasonApp = Main.instantiate()
	app.season = live
	app._fixture_id = live.pending_fixture().id
	var state: MatchState = SeasonPhysicalFixtures.match_for(live, live.pending_fixture())
	check(app.get_script() == SeasonApp, "normal scene retains exact owner identity")
	check(app._mounted_match_ledger(state, true, true) == null, "natural away opening cannot claim owned home")
	check(app._mounted_match_ledger(state, false, true) == null, "away refuses owned ledger")
	check(app._mounted_match_ledger(state, true, false) == null, "exhibition refuses owned ledger")
	app._fixture_id += 1
	check(app._mounted_match_ledger(state, true, true) == null, "wrong fixture refuses owned ledger")
	app._fixture_id -= 1
	var original: Dictionary = state.stadium
	state.stadium = {}
	check(app._mounted_match_ledger(state, true, true) == null, "mismatched field refuses owned ledger")
	state.stadium = original
	var clone: SeasonState = SeasonSave._decode(before)
	check(clone != null and Runtime.paid_ledger(clone) == null, "unbound decoded clone not runtime owner")
	var binding: Dictionary = live._dynasty_owner_binding
	live._dynasty_owner_binding = binding.duplicate(true)
	live._dynasty_owner_binding.revision -= 1
	check(Runtime.paid_ledger(live) == null and not ClubPlayerLegend.enabled(live), "stale revision refuses ledger and collector")
	live._dynasty_owner_binding = binding
	var original_path: String = SeasonSave._dynasty_owner_path
	SeasonSave._dynasty_owner_path = path + ".foreign"
	check(Runtime.paid_ledger(live) == null, "different owner path refused")
	SeasonSave._dynasty_owner_path = original_path
	var ledger: ClubAssetLedger = live._pool_replay_ledger
	live._pool_replay_ledger = null
	check(Runtime.paid_ledger(live) == null, "missing replay ledger refused")
	live._pool_replay_ledger = ClubAssetLedger.new()
	check(Runtime.paid_ledger(live) == null, "forged replay ledger refused")
	live._pool_replay_ledger = ledger
	var witness: Dictionary = live._standard_bound_grant
	live._standard_bound_grant = {}
	check(Runtime.paid_ledger(live) == null, "missing bound grant refused")
	live._standard_bound_grant = witness
	var session: Dictionary = live._dynasty_career_session
	live._dynasty_career_session = session.duplicate(true)
	live._dynasty_career_session.session_id = "wrong-session"
	check(Runtime.paid_ledger(live) == null, "different session refused")
	live._dynasty_career_session = session
	check(ClubCareer.same(before, SeasonSave.snapshot(live)), "routing leaves season snapshot unchanged")
	app.free()
	var cold: SeasonState = SeasonSave.restore()
	check(cold != null and Runtime.paid_ledger(cold) != null and ClubPlayerLegend.enabled(cold), "cold selected owner ledger and collector")
	check(ClubCareer.same(before, SeasonSave.snapshot(cold)), "cold snapshot unchanged")
