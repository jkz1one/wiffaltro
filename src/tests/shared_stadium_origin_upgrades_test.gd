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
	print("SHARED_STADIUM_ORIGIN_UPGRADES_CHECK ", checks, " ", ok, " ", label)
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
	print("SHARED_STADIUM_ORIGIN_UPGRADES checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _run(path: String) -> void:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = preload("res://src/tests/league_unlock_fixture.gd").prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}])
	# Explicit synthetic new-club-origin fixture, using the production constructor
	# with this fixture's exact earned credits/progress/awards, never a fabricated wallet.
	var origin_assets: ClubAssetLedger = ClubPlayers.assets(source.career)
	source.career._assets = ClubAssetLedger.new_club(origin_assets._seed, origin_assets._credits,
		origin_assets._progress, origin_assets._championships).to_data()
	check(ClubCareer.from_data(source.career.to_data()) != null, "production rough/salvage origin cold validates")
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
	var access = load("res://src/presentation/stadium/stadium_career_access.gd")
	var app: SeasonApp = Main.instantiate()
	add_child(app)
	var before: Dictionary = Store.inspect(path).owner
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	var paid: ClubAssetLedger = access.ledger(app)
	check(paid.view().surface_origin == StadiumSurfaceProgression.ROUGH_ORIGIN, "actual authority keeps production rough origin")
	check(paid.construction().copies.has(StadiumStock.SALVAGE_COPY), "actual authority has exact granted salvage copy")
	var grass_quote: Dictionary = access.upgrade_quote(app, "stadium_surface", "grass")
	check(grass_quote.get("ok", false) and grass_quote.get("cost") == 120, "grass ownership remains independently purchasable under existing rules")
	var spent: int = 0
	for row: Array in [["stadium_surface", "ground_prep", 80], ["stadium_surface", "grass", 120],
		["stadium_salvage_clear", "", 190], ["stadium_wall_piece", "ST-024-L", 375]]:
		var quote: Dictionary = access.upgrade_quote(app, row[0], row[1])
		if not check(quote.get("ok", false) and quote.get("cost") == row[2], "exact positive quote " + str(row) + ": " + str(quote)):
			app.free()
			return
		check(access.commit_quote(app, quote).get("ok", false), "actual main commits " + row[0])
		check(access.transact(app, quote.command).get("replayed", false), "exact retry " + row[0])
		spent += row[2]
		check(access.ledger(app).balance() == paid.balance() - spent, "single debit " + row[0])
		check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "no frozen field refresh " + row[0])
	var after: Dictionary = Store.inspect(path).owner
	var cleared_quote: Dictionary = access.upgrade_quote(app, "stadium_salvage_clear", "")
	check(cleared_quote.get("ok", false) and cleared_quote.get("cost") == 0, "already-cleared car is an existing-rule zero-cost replay")
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "all grant evidence frozen")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "both snapshot references frozen")
	app.free()
	app = Main.instantiate()
	add_child(app)
	paid = access.ledger(app)
	check(paid.view().surface_owned.has("grass") and paid.view().surface_owned.has("ground_prep"), "cold surface entitlements preserved")
	check(paid.view().get("salvage_cleared", false) and paid.construction().copies.has(StadiumStock.SALVAGE_COPY) and paid.view().stadium_draft.get("salvage_cars", []).is_empty() and paid.view().stadium_active.get("salvage_cars", []).is_empty(), "cold authority clears layouts and preserves salvage audit identity")
	check(paid.wall_pieces().blueprints.has("ST-024-L"), "cold exact independent wall variant blueprint")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "cold admitted rough field unchanged")
	app.free()
	SeasonSave.path = original
