extends Node
## Synthetic eligibility; atomic shared starter workshop, no physical gameplay.
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
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("SHARED_STADIUM_ASSETS_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stadium-assets-root="):
			root = arg.trim_prefix("--stadium-assets-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	_run(root.path_join("owner.json"))
	SeasonSave._dynasty_owner_path = ""
	print("SHARED_STADIUM_ASSETS checks=%d failures=%d physical_games=0" % [checks, failures])
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
	var initial: Dictionary = Store.inspect(path).owner
	var frozen: Dictionary = SeasonSave.snapshot(live)
	var ledger: ClubAssetLedger = ClubPlayers.assets(Authority._history(initial.career))
	var request: Dictionary = {"op": "stadium_assets", "request_id": "workshop-buy",
		"expected_revision": initial.revision, "command": {"id": "starter-copy", "rev": ledger.revision(),
			"op": "stadium_buy", "through": ClubPlayers.income_through(Authority._history(initial.career)),
			"price_version": StadiumPurchases.VERSION, "item": "ST-001", "quantity": 1}}
	var wrong: Dictionary = request.duplicate(true)
	wrong.command.price_version = 999
	check(Store.transact(wrong, path).status == "blocked", "wrong price version refused")
	wrong = request.duplicate(true)
	wrong.command.quantity = 100000
	check(Store.transact(wrong, path).status == "blocked", "unaffordable quantity refused")
	wrong = request.duplicate(true)
	wrong.command.item = "ST-006"
	check(Store.transact(wrong, path).status == "blocked", "later family not silently enabled")
	Store._test_stop_after = "intent.rename"
	var stopped: Dictionary = Store.transact(request, path)
	Store._test_stop_after = ""
	if not check(stopped.status == "not_committed" and Store.inspect(path).status == "pending", "purchase intent interrupted without commit"):
		return
	wrong = request.duplicate(true)
	wrong.command.item = "ST-003"
	check(Store.transact(wrong, path).status == "blocked", "different interrupted operands refused")
	var bought: Dictionary = Store.transact(request, path)
	if not check(bought.status == "committed", "exact pending purchase retry commits: " + str(bought.get("reason", ""))):
		return
	var after: Dictionary = bought.owner
	check(Authority.view(initial.career).balance - Authority.view(after.career).balance == 40, "one exact starter price debited")
	check(ClubCareer.same(initial.career.sessions, after.career.sessions), "all current and paused grants and contributions unchanged")
	check(ClubCareer.same(initial.dynasty, after.dynasty) and ClubCareer.same(initial.other, after.other), "both frozen snapshot references unchanged")
	check(ClubCareer.same(Store.transact(request, path).owner, after), "exact owner retry does not charge twice")
	var retry: Dictionary = Assets.command(after.career, request.command)
	check(retry.applied.replayed and ClubCareer.same(retry.authority, after.career), "ledger retry after committed owner is exact")
	wrong = request.duplicate(true)
	wrong.request_id = "stale-writer"
	wrong.command.id = "different-purchase"
	check(Store.transact(wrong, path).status == "blocked", "stale owner writer rejected")
	check(not SeasonSave.save(live), "old bound season cannot write over purchase")
	live = SeasonSave.restore()
	check(live != null and ClubCareer.same(SeasonSave.snapshot(live), frozen), "cold selected snapshot remains frozen after purchase")
	check(Runtime.paid_ledger(live) != null, "runtime ledger remains original frozen grant despite new purchase")
	var paused: Dictionary = Store.read_snapshot(path, after.dynasty.reference)
	check(not Owner._qualified(after, "dynasty", paused).is_empty(), "paused Dynasty cold qualifies unchanged")
	ledger = ClubPlayers.assets(Authority._history(after.career))
	var layout: Dictionary = StadiumStarterLayout.empty()
	for copy_id: String in ledger.construction().copies:
		if ledger.construction().copies[copy_id].item == "ST-001":
			layout.obstacles = [{"copy": copy_id, "site": "O-L1", "yaw": 0}]
			break
	var draft: Dictionary = {"op": "stadium_assets", "request_id": "workshop-draft",
		"expected_revision": after.revision, "command": {"id": "new-draft", "rev": ledger.revision(),
			"op": "stadium_draft", "layout": layout}}
	wrong = draft.duplicate(true)
	wrong.command.layout.obstacles = [{"copy": "never-owned", "site": "O-L1", "yaw": 0}]
	check(Store.transact(wrong, path).status == "blocked", "unowned construction stock refused")
	var drafted: Dictionary = Store.transact(draft, path)
	if not check(drafted.status == "committed", "version1 free draft commits: " + str(drafted.get("reason", ""))):
		return
	after = drafted.owner
	ledger = ClubPlayers.assets(Authority._history(after.career))
	var apply: Dictionary = {"op": "stadium_assets", "request_id": "workshop-apply",
		"expected_revision": after.revision, "command": {"id": "apply-new", "rev": ledger.revision(),
			"op": "stadium_apply", "layout": layout,
			"geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout)}}
	wrong = apply.duplicate(true)
	wrong.command.geometry = "wrong-geometry"
	check(Store.transact(wrong, path).status == "blocked", "geometry mismatch refused")
	var applied: Dictionary = Store.transact(apply, path)
	if not check(applied.status == "committed", "exact paid-stock geometry applies future layout: " + str(applied.get("reason", ""))):
		return
	after = applied.owner
	check(ClubCareer.same(initial.career.sessions, after.career.sessions), "applying layout never rewrites grants or pool")
	check(ClubCareer.same(initial.dynasty, after.dynasty) and ClubCareer.same(initial.other, after.other), "applying layout never refreshes active or paused snapshot")
	live = SeasonSave.restore()
	check(ClubCareer.same(SeasonSave.snapshot(live), frozen), "cold original home retained after apply")
	var next_grant: Dictionary = Grant.capture(after.career)
	var future_context: Dictionary = context.duplicate(true)
	future_context.session_id = "future-only-candidate"
	future_context.grant_sha256 = Save.snapshot_reference(next_grant).sha256
	var future: SeasonState = Live.create(next_grant, future_context)
	check(future != null and not ClubCareer.same(future.home_property, live.home_property), "new admission candidate alone sees newly applied field")
	check(ClubCareer.same(after, Store.inspect(path).owner), "future candidate construction changes no owner")
	check(live.choose_player(live.offers()[0]) and SeasonSave.save(live), "begin draft normally")
	after = Store.inspect(path).owner
	ledger = ClubPlayers.assets(Authority._history(after.career))
	wrong = request.duplicate(true)
	wrong.request_id = "mid-draft-buy"
	wrong.expected_revision = after.revision
	wrong.command.id = "mid-draft-copy"
	wrong.command.rev = ledger.revision()
	check(Store.transact(wrong, path).status == "blocked", "workshop closes once draft begins")
	check(ClubCareer.same(after, Store.inspect(path).owner), "refused workshop changes no manifest")
