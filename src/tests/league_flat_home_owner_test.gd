extends "res://src/tests/league_home_paid_clearance_owner_test.gd"
## Fresh synthetic-history owner. Real Save/Apply/public owner operations; no games.

func check(ok: bool, label: String) -> void:
	print("FLAT_OWNER_CHECK ", checks + 1, " ", ok, " ", label)
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	var source: SeasonState = _source()
	var old: ClubAssetLedger = ClubPlayers.assets(source.career)
	source.career._assets = ClubAssetLedger.new_club(old._seed, old._credits, old._progress, old._championships).to_data()
	if not require(source.career.start(source), "synthetic funded modern source"):
		return
	for pick in range(4): check(source.choose_player(source.offers()[0]), "normal source draft")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "flat-lineage", "flat-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	if not require(dynasty != null, "unchanged source Dynasty"):
		return
	var context: Dictionary = Closed.binding_for(dynasty, profile.owner_id, profile.lineage_id, 0, 1, "flat-lineage:1")
	var created: Dictionary = Store.create({"lineage": Lineage.create(profile),
		"snapshot": Closed.wrap_checkpoint(SeasonSave.snapshot(dynasty), context),
		"session_id": context.session_id, "origin": origin}, path)
	if not require(created.status == "committed", "fresh isolated owner") or not _open(1): return
	var initial: Dictionary = current()
	var frozen: Dictionary = SeasonSave.snapshot(SeasonSave.restore())
	var balance: int = paid(initial).balance()
	var through: int = ClubPlayers.income_through(Authority._history(initial.career))
	if not _asset({"op": "stadium_salvage_clear", "copy": StadiumStock.SALVAGE_COPY, "price_version": 1, "through": through}): return
	var buy: Dictionary = ClubConstruction.copy_command(Authority._history(current().career), "ST-001", paid(current()).revision())
	buy.erase("id")
	buy.erase("rev")
	if not _asset(buy): return
	var ledger: ClubAssetLedger = paid(current())
	var copy: String = ""
	for id: String in ledger.construction().copies:
		if ledger.construction().copies[id].item == "ST-001": copy = id
	var layout: Dictionary = StadiumMasteryBannerItems.upgrade(ledger.view().stadium_active, ledger.surface_owned())
	layout.obstacles = [{"copy": copy, "site": "O-R1", "yaw": 0}]
	if not require(not copy.is_empty() and StadiumOwnedLayout.validate(layout, ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), ledger.view().land, ledger.scoreboards()).ok,
		"paid named41 layout validates with exact owned obstacle"):
		return
	var before_draft: Dictionary = current()
	if not _asset({"op": "stadium_draft", "layout": layout}): return
	var drafted: Dictionary = current()
	check(paid(drafted).view().stadium_draft.version == 41 and paid(drafted).view().stadium_active.version == 40,
		"Save preserves preview41 and applied40 separately")
	check(_candidate(drafted, 2).home_property.layout.version == 40, "Save alone cannot refresh future admission")
	var request: Dictionary = {"op": "stadium_assets", "request_id": "flat-apply", "expected_revision": drafted.revision,
		"command": {"id": "flat-apply", "rev": paid(drafted).revision(), "op": "stadium_apply", "layout": layout,
			"geometry": StadiumOwnedLayout.geometry("backyard", layout)}}
	var wrong: Dictionary = request.duplicate(true)
	wrong.expected_revision = before_draft.revision
	check(Store.transact(wrong, path).status == "blocked", "stale owner Apply cannot publish draft")
	wrong = request.duplicate(true)
	wrong.command.layout.obstacles[0].copy = "foreign"
	check(Store.transact(wrong, path).status == "blocked", "unowned Apply refused atomically")
	check(ClubCareer.same(current(), drafted), "rejected Apply leaves owner exact")
	var applied: Dictionary = Store.transact(request, path)
	if not require(applied.status == "committed", "real owner Apply commits paid41"):
		return
	check(ClubCareer.same(Store.transact(request, path).owner, applied.owner), "exact Apply retry idempotent")
	_frozen(initial, applied.owner, frozen)
	var candidate: Dictionary = _candidate(applied.owner, 2)
	if not require(not candidate.is_empty() and candidate.home_property.layout.version == 41, "future admission receives complete applied41"):
		return
	check(paid(applied.owner).balance() == balance - 230 and paid(applied.owner).construction().copies.has(StadiumStock.SALVAGE_COPY),
		"only190 clearance plus40 copy spent; original stored car retained")
	var forged: Dictionary = candidate.duplicate(true)
	forged.home_property = frozen.home_property.duplicate(true)
	check(Bound.qualify(forged, applied.owner.career).is_empty(), "new grant cannot substitute old frozen field")
	check(Store.restore(path).status == "committed", "owner journal cold restores before new entry")
	if not _close() or not _open(2): return
	var selected: SeasonState = SeasonSave.restore()
	var runtime: ClubAssetLedger = Runtime.paid_ledger(selected)
	check(selected != null and selected.home_property.layout.version == 41 and runtime != null
		and ClubCareer.same(StadiumLayoutSnapshot.capture(runtime, true), selected.home_property), "public restore selects exact paid41 runtime")
	check(current().revision > initial.revision and selected.phase == SeasonState.Phase.DRAFT, "normal next entry remains pre-draft; no accepted games")
	check(Store.restore(path).status == "committed", "final41 owner and selected reference cold replay")
