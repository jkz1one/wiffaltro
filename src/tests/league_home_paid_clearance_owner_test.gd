extends "res://src/tests/dynasty_league_home_live_owner_test.gd"
## Synthetic income/title source; real isolated shared-owner journal transactions.
const Runtime = preload("res://src/gameplay/season/dynasty_league_home_runtime.gd")
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
const OwnerV2 = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")

func check(ok: bool, label: String) -> void:
	print("PAID_CLEARANCE_CHECK ", checks + 1, " ", ok, " ", label)
	super.check(ok, label)

func require(ok: bool, label: String) -> bool:
	check(ok, label)
	return ok

func current() -> Dictionary:
	return Store.inspect(path).get("owner", {})

func paid(owner: Dictionary) -> ClubAssetLedger:
	return ClubPlayers.assets(Authority._history(owner.career))

func _run() -> void:
	var source: SeasonState = _source()
	var old: ClubAssetLedger = ClubPlayers.assets(source.career)
	source.career._assets = ClubAssetLedger.new_club(old._seed, old._credits, old._progress, old._championships).to_data()
	if not require(source.career.start(source), "synthetic funded modern source"):
		return
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "normal source draft")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "clearance-lineage", "clearance-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	if not require(dynasty != null, "unchanged Dynasty source construction"):
		return
	var context: Dictionary = Closed.binding_for(dynasty, profile.owner_id, profile.lineage_id, 0, 1, "clearance-lineage:1")
	var created: Dictionary = Store.create({"lineage": Lineage.create(profile),
		"snapshot": Closed.wrap_checkpoint(SeasonSave.snapshot(dynasty), context),
		"session_id": context.session_id, "origin": origin}, path)
	if not require(created.status == "committed", "fresh isolated owner") or not _open(1):
		return
	var initial: Dictionary = current()
	var frozen: Dictionary = SeasonSave.snapshot(SeasonSave.restore())
	var ledger: ClubAssetLedger = paid(initial)
	var stock: Dictionary = ledger.construction().to_data()
	var initial_balance: int = ledger.balance()
	var clear: Dictionary = {"id": "clear-paid-once", "rev": ledger.revision(), "op": "stadium_salvage_clear",
		"copy": StadiumStock.SALVAGE_COPY, "price_version": 1,
		"through": ClubPlayers.income_through(Authority._history(initial.career))}
	var request: Dictionary = {"op": "stadium_assets", "request_id": "owner-clear", "expected_revision": initial.revision, "command": clear}
	for field: String in ["copy", "price_version", "through"]:
		var wrong: Dictionary = request.duplicate(true)
		wrong.command[field] = "foreign" if field == "copy" else 999
		check(Store.transact(wrong, path).status == "blocked", "wrong clearance " + field + " refused")
	var bypass: Dictionary = ledger.view().stadium_draft.duplicate(true)
	bypass.salvage_cars = []
	check(not ledger.fork().commit({"id": "free-clear", "rev": ledger.revision(), "op": "stadium_draft", "layout": bypass}).ok,
		"unpaid generic draft cannot remove car")
	Store._test_stop_after = "intent.rename"
	var stopped: Dictionary = Store.transact(request, path)
	Store._test_stop_after = ""
	if not require(stopped.status == "not_committed" and Store.inspect(path).status == "pending", "clearance interruption preserves unpaid intent"):
		return
	var wrong: Dictionary = request.duplicate(true)
	wrong.command.copy = "foreign"
	check(Store.transact(wrong, path).status == "blocked", "changed interrupted operands refused")
	var cleared: Dictionary = Store.transact(request, path)
	if not require(cleared.status == "committed", "exact clearance retry commits"):
		return
	check(ClubCareer.same(Store.transact(request, path).owner, cleared.owner), "owner retry cannot charge twice")
	var stale: Dictionary = request.duplicate(true)
	stale.request_id = "stale-owner-clear"
	stale.command.id = "stale-clear-command"
	check(Store.transact(stale, path).status == "blocked", "stale owner revision cannot rewrite paid clearance")
	ledger = paid(cleared.owner)
	check(ledger.balance() == initial_balance - 190 and Bound.paid_modern_clearance(ledger), "exact190 debit and replay-derived clearance")
	check(ClubCareer.same(stock, ledger.construction().to_data()), "clearance never grants copy or blueprint")
	_frozen(initial, cleared.owner, frozen)
	var staged: Dictionary = _candidate(cleared.owner, 2)
	if not require(not staged.is_empty() and Bound.modern_cleared(staged.home_property), "future admission uses paid cleared shape"):
		return
	_controls(staged, cleared.owner, initial)
	if not _close() or not _open(2):
		return
	var cleared_selected: Dictionary = current()
	var cleared_frozen: Dictionary = SeasonSave.snapshot(SeasonSave.restore())
	check(Bound.modern_cleared(cleared_frozen.home_property) and Runtime.paid_ledger(SeasonSave.restore()) != null,
		"new selected cleared owner grants runtime ledger")
	ledger = paid(cleared_selected)
	var placed: Dictionary = StadiumSalvageCarItems.place(ledger.view().stadium_draft,
		ledger.construction(), StadiumStock.SALVAGE_COPY, StadiumSalvageCarItems.SITE, ledger.surface_owned())
	if not _asset({"op": "stadium_draft", "layout": placed}):
		return
	check(Bound.modern_cleared(_candidate(current(), 3).home_property), "draft-only reinstall does not change next active home")
	if not _asset({"op": "stadium_apply", "layout": placed, "geometry": StadiumOwnedLayout.geometry("backyard", placed)}):
		return
	_frozen(cleared_selected, current(), cleared_frozen)
	staged = _candidate(current(), 3)
	check(not staged.is_empty() and Bound.modern_origin(staged.home_property), "applied same-copy reinstall restores exact origin shape")
	check(paid(current()).balance() == initial_balance - 190 and ClubCareer.same(stock, paid(current()).construction().to_data()),
		"reinstall is free and same inventory")
	if not _close() or not _open(3):
		return
	var reinstalled: Dictionary = current()
	var reinstalled_frozen: Dictionary = SeasonSave.snapshot(SeasonSave.restore())
	ledger = paid(reinstalled)
	var stored: Dictionary = StadiumSalvageCarItems.store_copy(ledger.view().stadium_draft, StadiumStock.SALVAGE_COPY)
	if not _asset({"op": "stadium_draft", "layout": stored}):
		return
	check(Bound.modern_origin(_candidate(current(), 4).home_property), "storage preview does not change active next home")
	if not _asset({"op": "stadium_apply", "layout": stored, "geometry": StadiumOwnedLayout.geometry("backyard", stored)}):
		return
	_frozen(reinstalled, current(), reinstalled_frozen)
	staged = _candidate(current(), 4)
	check(not staged.is_empty() and Bound.modern_cleared(staged.home_property), "subsequent storage admits same paid cleared shape")
	check(paid(current()).balance() == initial_balance - 190 and ClubCareer.same(stock, paid(current()).construction().to_data()),
		"clear/reinstall/store cycle spends190 once and preserves exact owned copy")
	check(Store.restore(path).status == "committed", "entire owner journal cold replays after storage")
	if not _close() or not _open(4):
		return
	var stored_selected: SeasonState = SeasonSave.restore()
	check(stored_selected != null and Bound.modern_cleared(stored_selected.home_property)
		and Runtime.paid_ledger(stored_selected) != null
		and Runtime.paid_ledger(stored_selected).view().salvage_cleared,
		"fourth selected admission cold replays stored-again paid home")

func _candidate(owner: Dictionary, ordinal: int) -> Dictionary:
	var grant: Dictionary = Grant.capture(owner.career)
	var context: Dictionary = Closed.binding({"owner_id": owner.owner_id, "lineage_id": owner.lineage.id,
		"generation": owner.lineage.generation, "ordinal": owner.lineage.ordinal, "session_id": "clearance-dugout:" + str(ordinal),
		"seed": 38200 + ordinal, "tier": 0, "league": "dugout", "access_sha256": ClosedContentAccess.digest(grant.access)})
	return Bound.prepare(owner.career, context)

func _open(ordinal: int) -> bool:
	var candidate: Dictionary = _candidate(current(), ordinal)
	if not require(not candidate.is_empty(), "exact future candidate " + str(ordinal)):
		return false
	var result: Dictionary = _step("switch", {"target": "other", "session_id": candidate.session.session_id, "snapshot": candidate})
	if result.get("status") != "committed":
		return false
	return require(SeasonSave.bind_dynasty_owner(path) and SeasonSave.restore() != null, "cold selected future admission " + str(ordinal))

func _close() -> bool:
	var result: Dictionary = _step("close", {"session_id": current().other.session_id, "reason": "abandon"})
	if result.get("status") != "committed":
		return false
	return _step("switch", {"target": "dynasty"}).get("status") == "committed"

func _asset(operands: Dictionary) -> bool:
	var command: Dictionary = operands.duplicate(true)
	command.id = "asset:" + str(current().revision)
	command.rev = paid(current()).revision()
	return _step("stadium_assets", {"command": command}).get("status") == "committed"

func _frozen(before: Dictionary, after: Dictionary, snapshot: Dictionary) -> void:
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "shared edit preserves all frozen session grants")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "both slot references remain exact")
	var cold: SeasonState = SeasonSave.restore()
	check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "cold selected checkpoint stays frozen across workshop edit")
	check(Runtime.paid_ledger(cold) != null and ClubCareer.same(StadiumLayoutSnapshot.capture(Runtime.paid_ledger(cold), true), snapshot.home_property),
		"selected paid runtime retains original admitted layout")
	check(not OwnerV2._qualified(after, "dynasty", Store.read_snapshot(path, after.dynasty.reference)).is_empty(), "paused Dynasty still cold qualifies unchanged")

func _controls(staged: Dictionary, owner: Dictionary, unpaid: Dictionary) -> void:
	var checked: Dictionary = Bound.qualify(JSON.parse_string(JSON.stringify(staged, "", true, true)), owner.career)
	if not require(not checked.is_empty(), "cleared complete JSON admission replay"):
		return
	var season: SeasonState = checked.season
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "cleared owned draft")
	check(SeasonInventoryRules.enable(season), "cleared owned inventory")
	var captured: Dictionary = Bound.capture(season)
	check(not Bound.qualify(captured, owner.career).is_empty(), "cleared drafted checkpoint roundtrip")
	var fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	check(state != null and state.stadium.version == 9 and state.stadium.environment.mode == "day"
		and state.stadium.layout.salvage_cars.is_empty(), "cleared exact fixture9 day match reconstructs")
	check(Runtime.paid_ledger(season) == null, "staged paid journal is not selected runtime authority")
	var selected: SeasonState = SeasonSave.restore()
	selected._dynasty_owner_binding = selected._dynasty_owner_binding.duplicate(true)
	selected._dynasty_owner_binding.revision -= 1
	check(Runtime.paid_ledger(selected) == null, "stale selected owner binding cannot borrow paid runtime")
	var bad: Dictionary = _candidate(unpaid, 2)
	bad.home_property = staged.home_property.duplicate(true)
	check(Bound.qualify(bad, unpaid.career).is_empty(), "complete cleared capture cannot borrow unpaid grant")
	bad = staged.duplicate(true)
	bad.home_property.layout.salvage_cars = [{"copy": StadiumStock.SALVAGE_COPY, "site": StadiumSalvageCarItems.SITE}]
	check(Bound.qualify(bad, owner.career).is_empty(), "reinstalled home cannot replace frozen cleared grant")
	for field: String in ["session_id", "owner_id", "lineage_id"]:
		bad = staged.duplicate(true)
		bad.session[field] += "-changed"
		check(Bound.qualify(bad, owner.career).is_empty(), "cleared rejects substituted " + field)
	bad = staged.duplicate(true)
	bad.home_property.inventory.copies.erase(StadiumStock.SALVAGE_COPY)
	check(not Bound.modern_cleared(bad.home_property) and Bound.qualify(bad, owner.career).is_empty(), "stored original copy remains mandatory")
	var ledger: ClubAssetLedger = paid(owner)
	var data: Dictionary = ledger.to_data()
	data.salvage_origin.copy = "foreign"
	check(ClubAssetLedger.from_data(data, ledger._seed, ledger._credits, ledger._progress, ledger._championships) == null,
		"forged original copy cannot replay paid journal")
	data = ledger.to_data()
	data.events = []
	var removed_clearance: ClubAssetLedger = ClubAssetLedger.from_data(data, ledger._seed, ledger._credits, ledger._progress, ledger._championships)
	check(removed_clearance == null or not Bound.paid_modern_clearance(removed_clearance),
		"removed clearance event cannot retain paid clearance authority")
	data = ledger.to_data()
	data["salvage_cleared"] = true
	check(ClubAssetLedger.from_data(data, ledger._seed, ledger._credits, ledger._progress, ledger._championships) == null,
		"serialized clearance flag cannot replace replayed journal")
	var fake: ClubAssetLedger = ClubAssetLedger.new(ledger._seed, ledger._credits, ledger._progress, ledger._championships)
	fake._stadium_active = staged.home_property.layout.duplicate(true)
	fake._salvage_cleared = true
	check(not Bound.paid_modern_clearance(fake), "originless family40 and forged clearance flag refused")
	for version: int in [41, 42, 43]:
		bad = staged.duplicate(true)
		bad.home_property.layout.version = version
		check(not Bound.modern_cleared(bad.home_property), "cleared cannot admit later family " + str(version))
	bad = staged.duplicate(true)
	bad.home_property.layout.surface.condition = "leveled"
	check(not Bound.modern_cleared(bad.home_property), "cleared cannot change rough surface")
	bad = staged.duplicate(true)
	bad.home_property.layout.base_version = 17
	check(not Bound.modern_cleared(bad.home_property), "cleared cannot adopt physical terrain")
	check(not ClubAssetLedger.new_club(1, [189]).commit({"id": "poor", "rev": 0,
		"op": "stadium_salvage_clear", "copy": StadiumStock.SALVAGE_COPY, "price_version": 1, "through": 1}).ok,
		"189CB cannot buy190CB clearance")
