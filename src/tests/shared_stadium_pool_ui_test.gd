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
	print("SHARED_STADIUM_POOL_CHECK ", checks, " ", ok, " ", label)
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
	_run(root.path_join("ordinary.json.dynasty-owner"))
	SeasonSave._dynasty_owner_path = ""
	print("SHARED_STADIUM_POOL checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _run(path: String) -> void:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = preload("res://src/tests/league_unlock_fixture.gd").prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3},
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 0}])
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
	var original: String = SeasonSave.path
	SeasonSave.path = path.trim_suffix(".dynasty-owner")
	SeasonSave._dynasty_owner_path = ""
	var app: SeasonApp = Main.instantiate()
	add_child(app)
	var access = load("res://src/presentation/stadium/stadium_career_access.gd")
	var ui = load("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
	check(app.season != null and access.editable(app), "actual main exact shared pre-draft editor")
	var before: Dictionary = Store.inspect(path).owner
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	ui.show(app)
	check(app.menu.page == "shared_stadium", "shared workshop renders")
	var paid: ClubAssetLedger = access.ledger(app)
	var pool_ui = load("res://src/presentation/stadium/shared_stadium_pool_ui.gd")
	var quote: Dictionary = access.copy_quote(app, "ST-006")
	if not check(quote.get("ok", false), "Pool earned quote: " + str(quote)):
		app.free()
		return
	ui._catalog_confirm(app, "ST-006", quote)
	check(app._dialog.dialog_text.contains(str(quote.cost)), "Pool total shown")
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(ClubCareer.same(before, Store.inspect(path).owner), "cancel no owner write")
	check(access.commit_quote(app, quote).get("ok", false), "Pool purchase")
	check(access.transact(app, quote.command).get("replayed", false), "exact Pool purchase retry")
	paid = access.ledger(app)
	var copy: String = ""
	for id: String in paid.construction().copies:
		if paid.construction().copies[id].item == "ST-006":
			copy = id
	var base: Dictionary = StadiumStarterLayout.empty()
	base.receiver = "starter-v1:ST-079"
	pool_ui._place(app, base, paid.revision(), copy)
	check(app.menu.page == "shared_stadium_pool", "actual main Pool preview")
	var card: VBoxContainer = _pool_card(app.menu._body)
	if not check(card != null, "Pool placement card"):
		app.free()
		return
	var layout: Dictionary = card.get_meta("shared_pool_draft")
	check(access.save_draft(app, layout, paid.revision()).get("ok", false), "Pool draft saves")
	paid = access.ledger(app)
	ui.show(app)
	check(app.menu.page == "shared_stadium_pool", "saved Pool renders")
	var saved_revision: int = paid.revision()
	check(access.apply_draft(app, layout, saved_revision).get("ok", false), "Pool future field applies")
	check(access.apply_draft(app, layout, saved_revision).get("replayed", false), "Pool apply retry")
	var after: Dictionary = Store.inspect(path).owner
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "session grants unchanged")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "both saved fields unchanged")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "current exact snapshot frozen")
	app.free()
	app = Main.instantiate()
	add_child(app)
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "actual main cold frozen restore")
	check(ClubCareer.same(access.ledger(app).view().stadium_active, layout), "cold shared field persists separately")
	app.free()
	SeasonSave.path = original

func _pool_card(node: Node) -> VBoxContainer:
	if node is VBoxContainer and node.has_meta("shared_pool_draft"):
		return node
	for child: Node in node.get_children():
		var found: VBoxContainer = _pool_card(child)
		if found != null:
			return found
	return null
