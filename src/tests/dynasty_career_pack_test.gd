extends Node
## Synthetic legacy Standard0 + Sponsorship0..3 prefix plus nonphysical Standard scores fund these tests.
## They are not physically played championships or new producer evidence.

const UnlockFixture = preload("res://src/tests/league_unlock_fixture.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
var checks: int = 0
var failures: int = 0
var root: String = ""


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--dynasty-pack-test-root="):
			root = argument.trim_prefix("--dynasty-pack-test-root=")
	if (
		not root.is_absolute_path()
		or root.length() < 2
		or root != root.simplify_path()
		or DirAccess.dir_exists_absolute(root)
	):
		push_error("Fresh absolute --dynasty-pack-test-root= required; no tests ran.")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		get_tree().quit(2)
		return
	_insufficient()
	_paid_pending()
	Store._test_stop_after = ""
	print("Dynasty pack checks: %d, failures: %d, physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _earned_origin(champion: bool) -> Dictionary:
	var source: SeasonState = SeasonState.create(13002, false, true, true)
	source.career = UnlockFixture.nonphysical_dynasty_source()
	if source.career == null or not source.career.start(source):
		return {}
	for pick in range(4):
		if not source.choose_player(source.offers()[0]):
			return {}
	# Same public synthetic-score route used by club_career_test, not a live
	# closed-league physical gate bypass and never an edit to historical evidence.
	var rounds: int = 0
	while source.phase != SeasonState.Phase.COMPLETE and rounds < 16:
		var fixture: Dictionary = source.pending_fixture()
		if fixture.is_empty():
			return {}
		var home_wins: bool = (fixture.home == 0) == champion
		if not source.record_player_result(
			fixture.id, 0 if home_wins else 1, 1 if home_wins else 0
		):
			return {}
		rounds += 1
	if (
		source.phase != SeasonState.Phase.COMPLETE
		or not source.career.sync(source)
		or (not champion and not _spend_to_poor(source.career))
	):
		return {}
	return SeasonSave.snapshot(source)


func _spend_to_poor(career: ClubCareer) -> bool:
	# Exercise real ledger commands, never rewrite a balance or historical receipt.
	for index in range(128):
		var ledger: ClubAssetLedger = ClubPlayers.assets(career)
		var before: Dictionary = {} if ledger == null else ledger.view()
		if before.is_empty():
			break
		if before.balance < ClubPlayerCatalog.price():
			return before.balance > 0 and before.pending.is_empty() and index > 0
		var opened: Dictionary = ClubPlayers.command(career, {
			"op": "player_pack_open", "id": "poor-spend-open-%d" % index,
			"rev": before.revision, "through": ClubPlayers.income_through(career),
			"price_version": ClubPlayerCatalog.PRICE_VERSION})
		if not opened.get("ok", false):
			return false
		var paid: Dictionary = ClubPlayers.assets(career).view()
		if (
			paid.balance != before.balance - ClubPlayerCatalog.price()
			or paid.pending.get("choices", []).is_empty()
		):
			return false
		var picked: Dictionary = ClubPlayers.command(career, {
			"op": "player_pack_pick", "id": "poor-spend-pick-%d" % index,
			"rev": paid.revision, "pack": paid.pending.id,
			"player": paid.pending.choices[0]})
		if not picked.get("ok", false):
			return false
		var after: Dictionary = ClubPlayers.assets(career).view()
		if after.balance != paid.balance or not after.pending.is_empty():
			break
	return false


func _fixture(name: String, champion: bool) -> Dictionary:
	var origin: Dictionary = _earned_origin(champion)
	if origin.is_empty():
		return {}
	var profile: Dictionary = Profile.capture_access_season(origin, name + ":lineage", name)
	var season: SeasonState = Bridge.create(profile)
	if season == null:
		return {}
	var snapshot: Dictionary = Save.wrap_checkpoint(
		SeasonSave.snapshot(season),
		Save.binding_for(season, name, name + ":lineage", 0, 1, name + ":lineage:1")
	)
	var path: String = root.path_join(name + ".json")
	var result: Dictionary = Store.create(
		{
			"lineage": Lineage.create(profile),
			"snapshot": snapshot,
			"session_id": name + ":lineage:1",
			"origin": origin
		},
		path
	)
	if result.status != "committed":
		return {}
	return {"owner": result.owner, "path": path, "snapshot": snapshot}


func _open_request(owner: Dictionary, identity: String) -> Dictionary:
	var view: Dictionary = Authority.player_view(owner.career)
	return {
		"op": "player_assets",
		"request_id": identity,
		"expected_revision": owner.revision,
		"command":
		{
			"op": "player_pack_open",
			"id": identity + ":ledger",
			"rev": view.ledger.revision,
			"through": view.through,
			"price_version": ClubPlayerCatalog.PRICE_VERSION
		}
	}


func _insufficient() -> void:
	var fixture: Dictionary = _fixture("poor-owner", false)
	check(not fixture.is_empty(), "synthetic below-price earning fixture fully qualifies")
	if fixture.is_empty():
		return
	var view: Dictionary = Authority.player_view(fixture.owner.career)
	check(
		view.ledger.balance > 0 and view.ledger.balance < ClubPlayerCatalog.price(),
		"insufficient-funds fixture is nonvacuous"
	)
	var before: String = FileAccess.get_file_as_string(fixture.path)
	var result: Dictionary = Store.transact(_open_request(fixture.owner, "poor-open"), fixture.path)
	check(result.status == "blocked", "insufficient earned funds refuse pack")
	check(
		FileAccess.get_file_as_string(fixture.path) == before, "refusal leaves primary bytes exact"
	)
	check(
		Store.inspect(fixture.path).owner == fixture.owner, "refusal leaves all shared state exact"
	)


func _paid_pending() -> void:
	var fixture: Dictionary = _fixture("paid-owner", true)
	check(not fixture.is_empty(), "synthetic champion funding source fully qualifies")
	if fixture.is_empty():
		return
	var owner: Dictionary = fixture.owner
	var other: SeasonState = SeasonState.create_closed_league(
		13003, LeagueRules.capture("standard"), true, Authority.access(owner.career)
	)
	if other == null:
		check(false, "alternate session construction")
		return
	check(
		ClubPlayerDraft.apply(other, Authority.player_view(owner.career).owned),
		"fresh alternate freezes current global player ownership"
	)
	for pick in range(4):
		check(other.choose_player(other.offers()[0]), "alternate pick before pool freeze")
	var snapshot: Dictionary = Save.wrap_checkpoint(
		SeasonSave.snapshot(other),
		Save.binding_for(other, owner.owner_id, owner.lineage.id, 0, 1, "paid-other:1")
	)
	var switched: Dictionary = Store.transact(
		{
			"op": "switch",
			"request_id": "pause-for-pack",
			"expected_revision": owner.revision,
			"target": "other",
			"session_id": "paid-other:1",
			"snapshot": snapshot
		},
		fixture.path
	)
	check(switched.status == "committed", "pause Dynasty and select frozen alternate")
	if switched.status != "committed":
		return
	owner = switched.owner
	check(
		snapshot.version == Save.Owned.VERSION and owner.career.version == 30,
		"freeze case uses explicit owned87 and Authority30, not old full pool"
	)
	for old_version in [28, 29]:
		var downgrade: Dictionary = owner.career.duplicate(true)
		downgrade.version = old_version
		check(Authority.normalize(downgrade).is_empty(), "old authority cannot admit owned entry")
	var request: Dictionary = _open_request(owner, "paid-open")
	var initial: Dictionary = Authority.player_view(owner.career)
	check(initial.ledger.balance >= ClubPlayerCatalog.price(), "positive pack budget")
	Store._test_stop_after = "intent.write"
	var stopped: Dictionary = Store.transact(request, fixture.path)
	Store._test_stop_after = ""
	check(stopped.status == "not_committed", "failed intent write does not buy a pack")
	check(Store.inspect(fixture.path).owner == owner, "failed write preserves bank and snapshots")
	Store._test_stop_after = "intent.rename"
	stopped = Store.transact(request, fixture.path)
	Store._test_stop_after = ""
	check(
		stopped.status == "not_committed" and Store.inspect(fixture.path).status == "pending",
		"paid reveal waits behind exact pending owner intent"
	)
	var changed: Dictionary = request.duplicate(true)
	changed.command.price_version += 1
	check(
		Store.transact(changed, fixture.path).status == "blocked", "pending retry binds exact quote"
	)
	var opened: Dictionary = Store.retry_pending(fixture.path)
	check(opened.status == "committed", "cold pending open commits once")
	if opened.status != "committed":
		return
	check(
		Store.transact(request, fixture.path).owner == opened.owner,
		"duplicate open does not debit twice"
	)
	var pending: Dictionary = Authority.player_view(opened.owner.career)
	check(
		pending.ledger.balance == initial.ledger.balance - ClubPlayerCatalog.price(),
		"existing exact pack price debited once"
	)
	check(
		pending.ledger.pending.choices == opened.owner.asset_receipt.view.pending.choices,
		"revealed choices are exact stored ledger receipt"
	)
	check(
		opened.owner.dynasty == owner.dynasty and opened.owner.other == owner.other,
		"purchase changes neither active nor paused source reference"
	)
	var cold: Dictionary = Store.restore(fixture.path)
	check(cold.status == "committed", "paid pending choice survives explicit cold restore")
	if cold.status != "committed":
		return
	check(
		Authority.player_view(cold.owner.career).ledger.pending == pending.ledger.pending,
		"cold restore preserves exact paid choices and price"
	)
	check(
		Profile.same(Save.capture(cold.qualified_selected_season), snapshot),
		"cold paid-pending restore keeps exact owned87 pool"
	)
	var altered: Dictionary = cold.owner.duplicate(true)
	altered.asset_receipt.view.balance += 1
	check(Owner.normalize(altered).is_empty(), "persisted asset receipt cannot invent balance")
	_pick(fixture.path, owner, opened.owner, snapshot)


func _pick(path: String, before: Dictionary, opened: Dictionary, snapshot: Dictionary) -> void:
	var view: Dictionary = Authority.player_view(opened.career)
	var player: String = view.ledger.pending.choices[0]
	var request: Dictionary = {
		"op": "player_assets",
		"request_id": "paid-pick",
		"expected_revision": opened.revision,
		"command":
		{
			"op": "player_pack_pick",
			"id": "paid-pick:ledger",
			"rev": view.ledger.revision,
			"pack": view.ledger.pending.id,
			"player": player
		}
	}
	var picked: Dictionary = Store.transact(request, path)
	check(picked.status == "committed", "paid choice commits in shared owner")
	if picked.status != "committed":
		return
	check(Store.transact(request, path).owner == picked.owner, "duplicate choice is idempotent")
	var final: Dictionary = Authority.player_view(picked.owner.career)
	check(
		player in final.owned and final.ledger.pending.is_empty(),
		"chosen player becomes globally owned"
	)
	check(final.ledger.balance == view.ledger.balance, "choice does not debit a second time")
	check(
		picked.owner.dynasty == before.dynasty and picked.owner.other == before.other,
		"paid choice preserves retained roster and frozen active pool"
	)
	var readback: Dictionary = Store.restore(path)
	check(readback.status == "committed", "picked owner cold-qualifies")
	if readback.status == "committed":
		check(
			Profile.same(Save.capture(readback.qualified_selected_season), snapshot),
			"active session bytes unchanged after open and pick"
		)
	for expand: bool in [false, true]:
		var altered_pool: Dictionary = snapshot.duplicate(true)
		if expand:
			altered_pool.player_access.append(player)
			altered_pool.player_access.sort()
		else:
			altered_pool.player_access.pop_back()
		var refused: Dictionary = Store.transact(
			{
				"op": "checkpoint",
				"request_id": "changed-pool:%s" % expand,
				"expected_revision": picked.owner.revision,
				"session_id": picked.owner.other.session_id,
				"snapshot": altered_pool
			},
			path
		)
		check(
			refused.status == "blocked", "existing owned pool cannot grow or shrink on checkpoint"
		)
		check(Store.inspect(path).owner == picked.owner, "pool refusal preserves global ledger")
	var stale: Dictionary = request.duplicate(true)
	stale.request_id = "stale-owner"
	check(Store.transact(stale, path).status == "blocked", "stale prior authority cannot spend")
	check(Store.inspect(path).owner == picked.owner, "stale request preserves final authority")
	var next_draft: SeasonState = SeasonState.create_closed_league(
		13004, LeagueRules.capture("standard"), true, Authority.access(picked.owner.career)
	)
	check(next_draft != null, "future draft can be constructed")
	if next_draft != null:
		check(
			ClubPlayerDraft.apply(next_draft, final.owned), "future draft captures new owned pool"
		)
		check(
			player in next_draft.player_access and player in next_draft.draft_pool,
			"purchased player is eligible in a fresh draft, not inserted into retained roster"
		)
