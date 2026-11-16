extends Node
## Candidate owned-pool/pack integration. Income fixture uses synthetic legacy scores,
## never physical completion evidence, a production save or a new economy rule.

const App = preload("res://src/presentation/season/league_career_candidate_app.gd")
const Controller = preload("res://src/presentation/season/league_career_controller.gd")
const CareerUI = preload("res://src/presentation/season/league_career_ui.gd")
const Enrollment = preload("res://src/presentation/season/dynasty_career_enrollment.gd")
const OwnerController = preload("res://src/presentation/season/dynasty_career_controller.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const UnlockFixture = preload("res://src/tests/league_unlock_fixture.gd")


class TestApp:
	extends App

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func show_season() -> void:
		pass


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
		if argument.begins_with("--league-owned-players-test-root="):
			root = argument.trim_prefix("--league-owned-players-test-root=")
	if not root.is_absolute_path() or root != root.simplify_path() or root.length() < 2 \
		or root.begins_with("res://") or root.begins_with("user://") \
		or DirAccess.dir_exists_absolute(root):
		push_error("A fresh absolute --league-owned-players-test-root= is required. No test ran.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	var original_path: String = SeasonSave.path
	var app: TestApp = TestApp.new()
	add_child(app)
	app.menu = SeasonMenu.new()
	app.add_child(app.menu)
	app.menu.build(app)
	_fresh_entries(app)
	SeasonSave.path = root.path_join("packs.json")
	app.league_career = Controller.new(app, SeasonSave.path)
	app.season = _synthetic_income()
	if app.season != null and SeasonSave.save(app.season):
		_legacy_and_pack(app)
		_owner_packs(app)
	else:
		check(false, "synthetic legacy income fixture saves")
	app.free()
	SeasonSave.path = original_path
	SeasonSave._dynasty_owner_path = ""
	SeasonSave._dynasty_owner_content_blocked = false
	Store._test_stop_after = ""
	print("League owned-player UI checks: %d, failures: %d; physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _fresh_entries(app: TestApp) -> void:
	for league: String in Controller.IDS:
		SeasonSave.path = root.path_join(league + ".json")
		app.season = null
		app.league_career = Controller.new(app, SeasonSave.path)
		var prefix: ClubCareer = UnlockFixture.for_league(league)
		if prefix == null:
			check(false, league + " synthetic legacy unlock fixture validates")
			continue
		if not prefix.runs.is_empty():
			app.season = _source_with_history(prefix, 69000)
			if app.season == null or not SeasonSave.save(app.season):
				check(false, league + " source with explicit synthetic unlock prefix saves")
				continue
		var before: String = FileAccess.get_file_as_string(SeasonSave.path) \
			if FileAccess.file_exists(SeasonSave.path) else "absent"
		check(app.league_career.available_tiers(league) == [0],
			league + " newly available League begins at Base")
		check(app.league_career.prepare(league, 69001), league + " owned entry prepares")
		var next: SeasonState = app.league_career.candidate()
		if next == null:
			continue
		if league in ["standard", "dugout"]:
			check(next.player_access == ClubPlayerCatalog.initial_owned(), league + " twelve starters")
		check(next.player_access == ClubPlayers.owned(next.career), league + " exact owned entry pool")
		check(next.draft_pool.size() == next.player_access.size()
			and next.build._pool == next.player_access,
			league + " owned draft and recruit pools")
		check((FileAccess.get_file_as_string(SeasonSave.path)
			if FileAccess.file_exists(SeasonSave.path) else "absent") == before,
			league + " preview writes nothing")
		check(app.league_career.commit(app.league_career.token()), league + " owned entry saves")
		app.season = SeasonSave.restore()
		if app.season == null:
			check(false, league + " cold restore")
			continue
		for pick: int in range(4):
			check(app.season.offers().all(func(id: String) -> bool:
				return app.season.player_access.has(id)), league + " offers owned only")
			check(app.league_career.draft_pick(app.season.offers()[0]), league + " owned pick")
			app.season = SeasonSave.restore()
			if app.season == null or app.season.picks.size() != pick + 1:
				check(false, league + " cold partial draft")
				break
		if app.season != null and app.season.picks.size() == 4:
			var allocated: Array[String] = []
			for team: Dictionary in app.season.teams:
				for id: String in team.roster:
					check(not allocated.has(id), league + " distinct NPC allocation")
					allocated.append(id)
			check(allocated.size() == 24, league + " NPCs use independent full catalog")


func _source_with_history(club: ClubCareer, seed_value: int) -> SeasonState:
	var season: SeasonState = SeasonState.create(seed_value, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) or not club.start(season):
		return null
	season.career = club
	return season


func _synthetic_income() -> SeasonState:
	var season: SeasonState = SeasonState.create(69002, false, true, true)
	# Explicit compact legacy Standard0..3 titles fund and unlock this owner fixture.
	# They are not claims that these physical championships were played.
	season.career = UnlockFixture.for_league("dynasty")
	if season.career == null:
		return null
	if not season.career.start(season):
		return null
	for pick: int in range(4):
		if not season.choose_player(season.offers()[0]):
			return null
	while season.phase != SeasonState.Phase.COMPLETE:
		var fixture: Dictionary = season.pending_fixture()
		if not season.record_player_result(fixture.id,
			0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0):
			return null
	return season


func _legacy_and_pack(app: TestApp) -> void:
	var source: SeasonState = app.season
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	check(source.player_access.is_empty(), "legacy full pool fixture unchanged")
	check(app.league_career.prepare("dugout", 69003), "prepare owned successor to legacy")
	app.league_career.cancel(app.league_career.token())
	check(app.season == source and FileAccess.get_file_as_string(SeasonSave.path) == original,
		"cancel leaves legacy live pool and bytes unchanged")
	check(app.league_career.prepare("dugout", 69003), "prepare owned successor again")
	check(app.league_career.commit(app.league_career.token()), "owned successor saves")
	if app.season == source:
		return
	var frozen: Array[String] = app.season.player_access.duplicate()
	var draft: Array[String] = app.season.draft_pool.duplicate()
	CareerUI.record(app)
	check(_text(app.menu).contains("PLAYERS & PACKS"), "owned candidate exposes actual pack route")
	ClubCollectionUI.show(app.menu)
	check(_text(app.menu).contains("PLAYERS"), "collection route reaches owned players")
	var before: int = app.season.career.balance()
	var view: Dictionary = ClubPlayers.assets(app.season.career).view()
	var request: Dictionary = {"id": "owned-test:open", "rev": view.revision,
		"op": "player_pack_open", "through": ClubPlayers.income_through(app.season.career),
		"price_version": ClubPlayerCatalog.PRICE_VERSION}
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	ClubPlayersUI.review(app.menu)
	ClubPlayersUI.show(app.menu)
	check(FileAccess.get_file_as_string(SeasonSave.path) == saved, "review/cancel spends nothing")
	_route_guards(app, request)
	_failed_transaction(app, request, "failed payment")
	check(app._player_collection_transact(request).ok, "guarded pack payment saves")
	check(app._player_collection_transact(request).ok, "same guarded payment idempotent")
	var pending: Dictionary = ClubPlayers.assets(app.season.career).view().pending.duplicate(true)
	app.season = SeasonSave.restore()
	if app.season == null or pending.is_empty():
		check(false, "paid reveal survives cold reload")
		return
	check(ClubCareer.same(ClubPlayers.assets(app.season.career).view().pending, pending),
		"cold reveal remains exact and unresolved")
	check(app.season.career.balance() == before - int(view.pack_price), "one established pack price")
	check(pending.choices.size() == 3 and pending.choices.all(func(id: String) -> bool:
		return not frozen.has(id) and ClubPlayerCatalog.PACK_POOL.has(id)), "unowned pack-only offers")
	var choose: Dictionary = {"id": "owned-test:pick", "op": "player_pack_pick",
		"rev": ClubPlayers.assets(app.season.career).revision(),
		"pack": pending.id, "player": pending.choices[0]}
	check(app.league_career.prepare("sponsorship", 69004), "prepare before collection change")
	var ticket: int = app.league_career.token()
	_failed_transaction(app, choose, "failed selection")
	check(app._player_collection_transact(choose).ok, "guarded ownership choice saves")
	check(app._player_collection_transact(choose).ok, "same guarded choice idempotent")
	check(not app.league_career.commit(ticket), "collection change invalidates older start preview")
	app.season = SeasonSave.restore()
	check(app.season != null and app.season.player_access == frozen
		and app.season.draft_pool == draft and app.season.build._pool == frozen,
		"purchase does not expand current frozen draft or recruit pool")
	if app.season == null:
		return
	check(ClubPlayers.owned(app.season.career).has(choose.player), "chosen player permanently owned")
	check(app.league_career.prepare("sponsorship", 69004), "prepare next fresh owned pool")
	if app.league_career.candidate() == null:
		return
	check(app.league_career.candidate().player_access.has(choose.player), "next pool includes card")
	check(app.league_career.commit(app.league_career.token()), "next owned season saves")
	app.season = SeasonSave.restore()
	check(app.season != null and app.season.player_access.has(choose.player), "new pool cold restore")


func _failed_transaction(app: TestApp, request: Dictionary, label: String) -> void:
	var path: String = SeasonSave.path
	var before: Dictionary = app.season.career.to_data()
	var saved: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = root.path_join("absent/save.json")
	check(not ClubPlayers.transact(app.season, request).ok, label + " reported")
	SeasonSave.path = path
	check(ClubCareer.same(app.season.career.to_data(), before)
		and FileAccess.get_file_as_string(path) == saved, label + " preserves live and disk")


func _route_guards(app: TestApp, request: Dictionary) -> void:
	var path: String = SeasonSave.path
	var before: Dictionary = app.season.career.to_data()
	var saved: String = FileAccess.get_file_as_string(path)
	var wrong: String = root.path_join("wrong-route.json")
	SeasonSave.path = wrong
	check(not app._player_collection_transact(request).ok, "wrong candidate path denied")
	check(not FileAccess.file_exists(wrong), "wrong path receives no player write")
	SeasonSave.path = path
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("stale disk sentinel")
	file.close()
	check(not app._player_collection_transact(request).ok, "stale candidate disk denied")
	check(FileAccess.get_file_as_string(path) == "stale disk sentinel",
		"stale disk is not overwritten by player callback")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(saved)
	file.close()
	app.season.starter_index = 1
	check(not app._player_collection_transact(request).ok, "unsaved candidate state denied")
	app.season = SeasonSave.restore()
	check(app.season != null and ClubCareer.same(app.season.career.to_data(), before)
		and FileAccess.get_file_as_string(path) == saved, "route guards preserve ownership and balance")


func _owner_packs(app: TestApp) -> void:
	if app.season == null or app.season.phase != SeasonState.Phase.DRAFT:
		check(false, "owned source available for enrollment")
		return
	for pick: int in range(4):
		if not app.league_career.draft_pick(app.season.offers()[0]):
			check(false, "owned source draft before enrollment")
			return
	var source_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	app.candidate_owner_path = root.path_join("dynasty-career.json")
	app.dynasty_owner = OwnerController.new(app)
	app.dynasty_enrollment = Enrollment.new(app, app.candidate_owner_path)
	check(app.dynasty_enrollment.prepare(69005), "owned source enrollment prepares")
	if not app.dynasty_enrollment.commit(app.dynasty_enrollment.token()):
		check(false, "owned source enrolls into shared owner")
		return
	var before: Dictionary = Store.inspect(app.candidate_owner_path)
	var dynasty_reference: Dictionary = before.owner.dynasty.reference.duplicate()
	var roster: Array[String] = app.season.picks.duplicate()
	var view: Dictionary = app._player_collection_view()
	check(app.season.career == null and not view.is_empty(), "shared collection without personal bank")
	ClubPlayersUI.show(app.menu)
	check(_text(app.menu).contains("does not replace anyone"), "Dynasty purchase effect disclosed")
	check(not _text(app.menu).contains("Fresh development each season"), "no false Dynasty reset copy")
	var command: Dictionary = {"id": "owned-owner:open", "rev": view.ledger.revision,
		"op": "player_pack_open", "through": view.through,
		"price_version": ClubPlayerCatalog.PRICE_VERSION}
	SeasonSave._dynasty_owner_path = root.path_join("wrong-owner.json")
	check(not app._player_collection_transact(command).ok, "wrong owner path blocks payment")
	check(not FileAccess.file_exists(SeasonSave._dynasty_owner_path), "wrong owner receives no write")
	SeasonSave._dynasty_owner_path = app.candidate_owner_path
	app.season.starter_index = (app.season.starter_index + 1) % 4
	check(not app._player_collection_transact(command).ok, "unsaved owner session blocks payment")
	check(app.dynasty_owner.recover(), "recover exact owner before payment")
	Store._test_stop_after = "intent.rename"
	check(not app._player_collection_transact(command).ok, "interrupted owner payment not promoted")
	Store._test_stop_after = ""
	check(Store.inspect(app.candidate_owner_path).status == "pending", "owner payment intent saved")
	check(not app._player_collection_transact(command).ok, "pending payment requires exact recovery")
	check(app.dynasty_owner.recover(), "recover exact owner payment")
	var paid: Dictionary = Store.inspect(app.candidate_owner_path)
	check(app._player_collection_transact(command).ok, "recovered payment callback idempotent")
	check(Store.inspect(app.candidate_owner_path).revision == paid.revision,
		"known paid callback adds no owner revision")
	var purchased: Dictionary = app._player_collection_view()
	check(purchased.ledger.balance == view.ledger.balance - view.ledger.pack_price,
		"shared balance charged once at existing pack price")
	if purchased.ledger.pending.is_empty():
		check(false, "owner paid reveal available")
		return
	var choose: Dictionary = {"id": "owned-owner:pick", "rev": purchased.ledger.revision,
		"op": "player_pack_pick", "pack": purchased.ledger.pending.id,
		"player": purchased.ledger.pending.choices[0]}
	check(app._player_collection_transact(choose).ok, "owner choice saves through shared authority")
	check(app._player_collection_transact(choose).ok, "owner choice callback idempotent")
	check(app.dynasty_owner.recover(), "owner purchased collection cold restores")
	var selected: Dictionary = Store.inspect(app.candidate_owner_path)
	check(selected.owner.dynasty.reference == dynasty_reference and app.season.picks == roster,
		"purchase cannot rewrite existing Dynasty snapshot or roster")
	check(app._player_collection_view().owned.has(choose.player), "owner permanently owns selection")
	check(FileAccess.get_file_as_string(SeasonSave.path) == source_bytes,
		"owner packs never rewrite archived standalone source")
	check(app.dynasty_owner.start_other("dugout", selected.revision, 69006),
		"fresh owned alternate starts after purchase")
	check(app.season.player_access.has(choose.player), "new alternate freezes owner purchased player")
	check(Store.inspect(app.candidate_owner_path).owner.dynasty.reference == dynasty_reference,
		"owned alternate leaves paused Dynasty snapshot exact")


func _text(node: Node) -> String:
	var result: String = str(node.text) if node is Label or node is Button else ""
	for child: Node in node.get_children():
		result += "\n" + _text(child)
	return result
