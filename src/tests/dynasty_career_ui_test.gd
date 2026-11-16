extends Node
## Bounded owner/controller integration. No physical games or earned-title claim.

const Controller = preload("res://src/presentation/season/league_career_controller.gd")
const Enrollment = preload("res://src/presentation/season/dynasty_career_enrollment.gd")
const OwnerController = preload("res://src/presentation/season/dynasty_career_controller.gd")
const OwnerUI = preload("res://src/presentation/season/dynasty_career_ui.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const TierUI = preload("res://src/presentation/season/dynasty_career_tier_ui.gd")
const UnlockFixture = preload("res://src/tests/league_unlock_fixture.gd")


class TestApp:
	extends "res://src/presentation/season/league_career_candidate_app.gd"
	var shown: int = 0

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func show_season() -> void:
		shown += 1


class SettledPresentationFixture:
	extends RefCounted
	## Display-only completion, never persisted or used as career authority.
	func found() -> Dictionary:
		return {"owner": {"selected": "dynasty", "dynasty": {"session_id": "display-only"},
			"career": {"settlements": [{"session_id": "display-only", "receipt": {"total": 220}}]}}}

	func view() -> Dictionary:
		return {"balance": 220, "history": [], "access": {}, "sessions": {}}


class TierPresentationFixture:
	extends RefCounted
	## Display only; never persisted, settled or used to authorize a start.
	var _next_choice: Dictionary = {}

	func ready() -> bool:
		return true

	func found() -> Dictionary:
		return {"revision": 1, "owner": {"selected": "dynasty", "pending_next": {},
			"lineage": {"state": "closed"}}}

	func available_tiers(_league: String) -> Array[int]:
		return [0, 1, 2]


class SavedLockedPresentationFixture:
	extends RefCounted
	## Display-only historical session. Does not create ownership or unlock evidence.
	func ready() -> bool:
		return true

	func found() -> Dictionary:
		return {"revision": 1, "owner": {"selected": "dynasty", "pending_next": {},
			"lineage": {"state": "active"}, "dynasty": {"profile": {"tier": 2}},
			"other": {"session_id": "saved-other", "profile": {"league": "earnings", "tier": 1}},
			"career": {"sessions": {"saved-other": {"settled": 0}}}}}

	func available_leagues() -> Array[String]:
		return ["standard", "dugout"]

	func ask_switch(_target: String) -> void:
		pass


var checks: int = 0
var failures: int = 0
var root: String = ""
var starting_balance: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--dynasty-career-ui-test-root="):
			root = argument.trim_prefix("--dynasty-career-ui-test-root=")
	if (
		not root.is_absolute_path() or root.length() < 2 or root != root.simplify_path()
		or root.begins_with("res://") or root.begins_with("user://")
		or DirAccess.dir_exists_absolute(root)
	):
		push_error("A fresh absolute --dynasty-career-ui-test-root= is required. No test ran.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	var original_path: String = SeasonSave.path
	SeasonSave.path = root.path_join("league-career.json")
	var app: TestApp = TestApp.new()
	app.candidate_owner_path = root.path_join("dynasty-career.json")
	app.league_career = Controller.new(app, SeasonSave.path)
	app.dynasty_enrollment = Enrollment.new(app, app.candidate_owner_path)
	app.dynasty_owner = OwnerController.new(app)
	add_child(app)
	app.menu = SeasonMenu.new()
	app.add_child(app.menu)
	app.menu.build(app)
	_locked_enrollment(app)
	if _origin(app) and _enroll(app):
		_alternate(app)
		_next_tiers(app)
	Store._test_stop_after = ""
	app.free()
	SeasonSave.path = original_path
	SeasonSave._dynasty_owner_path = ""
	SeasonSave._dynasty_owner_content_blocked = false
	print("Dynasty career UI checks: %d, failures: %d; physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _origin(app: TestApp) -> bool:
	# Explicit synthetic compact legacy title prefix, not played physical wins.
	# It authorizes the positive enrollment path without altering fresh-club policy.
	var source: SeasonState = SeasonState.create(67000, false, true, true)
	source.physical = SeasonPhysicalFixtures.new()
	source.opponents._format = 13
	var club: ClubCareer = UnlockFixture.nonphysical_dynasty_source()
	if club == null or not ClubPlayerDraft.apply(source, ClubPlayers.owned(club)) \
		or not club.start(source):
		check(false, "synthetic legacy unlock source starts")
		return false
	source.career = club
	SeasonSave.path = root.path_join("unlocked-origin.json")
	app.league_career = Controller.new(app, SeasonSave.path)
	if not SeasonSave.save(source):
		check(false, "synthetic legacy unlock source saves")
		return false
	app.season = SeasonSave.restore()
	starting_balance = club.balance()
	check(app.league_career.prepare("standard", 67001), "prepare ordinary candidate origin")
	check(app.league_career.commit(app.league_career.token()), "save ordinary candidate origin")
	if app.season == null:
		return false
	check(not app.dynasty_enrollment.prepare(67002), "incomplete draft cannot enroll Dynasty")
	for pick: int in range(4):
		check(app.league_career.draft_pick(app.season.offers()[0]), "saved origin pick %d" % pick)
		if app.season.picks.size() != pick + 1:
			return false
	return true


func _locked_enrollment(app: TestApp) -> void:
	check(app.league_career.prepare("standard", 66999), "fresh locked origin prepares")
	check(app.league_career.commit(app.league_career.token()), "fresh locked origin saves")
	if app.season == null:
		return
	for pick: int in range(4):
		if not app.league_career.draft_pick(app.season.offers()[0]):
			check(false, "fresh locked origin draft")
			return
	var before: String = FileAccess.get_file_as_string(SeasonSave.path)
	check(not app.dynasty_enrollment.prepare(67002), "four picks do not bypass Dynasty tier3 gate")
	check(not app.dynasty_enrollment.commit(app.dynasty_enrollment.token()),
		"locked enrollment creates no usable commit ticket")
	check(FileAccess.get_file_as_string(SeasonSave.path) == before
		and Store.inspect(app.candidate_owner_path).status == "empty", "locked enrollment writes nothing")


func _enroll(app: TestApp) -> bool:
	var source: String = FileAccess.get_file_as_string(SeasonSave.path)
	var roster: Array[String] = app.season.picks.duplicate()
	check(app.dynasty_enrollment.prepare(67002), "prepare detached Dynasty enrollment")
	var ticket: int = app.dynasty_enrollment.token()
	check(Store.inspect(app.candidate_owner_path).status == "empty", "preview writes no owner")
	OwnerUI.enrollment(app)
	check(_text(app.menu).contains("unfinished source is abandoned for 0"), "source closure disclosed")
	check(_text(app.menu).contains("Enrollment starts Dynasty at Base"), "Base enrollment disclosed")
	check(_text(app.menu).contains("same-League championship gates"), "owner tier gate disclosed")
	check(app.dynasty_enrollment.cancel(ticket), "cancel leaves current source")
	check(not app.dynasty_enrollment.commit(ticket), "cancelled callback cannot enroll")
	check(FileAccess.get_file_as_string(SeasonSave.path) == source, "cancel keeps source bytes")
	check(app.dynasty_enrollment.prepare(67002), "prepare after cancel")
	ticket = app.dynasty_enrollment.token()
	app.season.starter_index = 1
	check(not app.dynasty_enrollment.commit(ticket), "changed live source invalidates enrollment")
	check(app.dynasty_enrollment.cancel(ticket), "stale preview can be discarded")
	app.season = SeasonSave.restore()
	check(app.dynasty_enrollment.prepare(67002), "prepare exact source for interruption")
	ticket = app.dynasty_enrollment.token()
	Store._test_stop_after = "intent.rename"
	check(not app.dynasty_enrollment.commit(ticket), "pending enrollment not promoted")
	Store._test_stop_after = ""
	check(Store.inspect(app.candidate_owner_path).status == "pending", "exact intent retained")
	check(app.season == null and SeasonSave.dynasty_owner_bound(), "no old-source fallback")
	check(not app.dynasty_enrollment.cancel(ticket), "pending start cannot be cancelled")
	check(app.dynasty_enrollment.commit(ticket), "retry exact enrollment")
	if app.season == null:
		return false
	check(not app.dynasty_enrollment.commit(ticket), "duplicate enrollment cannot reset lineage")
	var owner: Dictionary = Store.inspect(app.candidate_owner_path).get("owner", {})
	check(owner.get("version") == 2, "new owner version selected explicitly")
	check(app.season.career == null, "session has no stale personal career bank")
	check(app.season.picks == roster, "first Dynasty retains the exact roster")
	check(FileAccess.get_file_as_string(SeasonSave.path) == source,
		"source file stays archived intact")
	var view: Dictionary = app.dynasty_owner.view()
	check(not view.is_empty() and view.balance == starting_balance, "owner-wide balance visible")
	check(view.history[-1].status == "abandoned", "unfinished origin closes for zero payout")
	check(Store.restore(app.candidate_owner_path).status == "committed", "cold owner restores")
	OwnerUI.record(app)
	check(_text(app.menu).contains("CLUB BUCKS"), "record reads owner despite null session career")
	check(_text(app.menu).contains("PLAYERS & PACKS"), "shared player collection entry")
	_settled_display(app)
	_saved_locked_display(app)
	return true


func _saved_locked_display(app: TestApp) -> void:
	var real: RefCounted = app.dynasty_owner
	app.dynasty_owner = SavedLockedPresentationFixture.new()
	OwnerUI.show(app)
	check(_text(app.menu).contains("RESUME SAVED ALTERNATE"), "saved locked League remains resumable")
	check(_text(app.menu).contains("NEW START LOCKED"), "resume does not claim fresh League access")
	check(_text(app.menu).contains("Saved difficulty: d1"), "saved alternate tier stays visible")
	check(_text(app.menu).contains("Dynasty / d2"), "old Dynasty retains its captured tier")
	app.dynasty_owner = real


func _settled_display(app: TestApp) -> void:
	var real: RefCounted = app.dynasty_owner
	app.dynasty_owner = SettledPresentationFixture.new()
	app.menu._screen("controlled_settlement", "CONTROLLED SETTLEMENT", "Presentation only")
	OwnerUI.settlement(app)
	app._dynasty_career_summary()
	check(_text(app.menu).contains("+220 CLUB BUCKS"), "settled receipt displayed immediately")
	check(not _text(app.menu).contains("RETRY RESULT SAVE"), "settled receipt needs no retry")
	check(not _text(app.menu).contains("Settle this season"), "no extra payout click implied")
	app.dynasty_owner = real


func _alternate(app: TestApp) -> void:
	var before: Dictionary = Store.inspect(app.candidate_owner_path)
	var dynasty_reference: Dictionary = before.owner.dynasty.reference
	check(not app.dynasty_owner.available_leagues().has("earnings"), "source lacks Equipment title")
	check(not app.dynasty_owner.start_other("earnings", before.revision, 67003),
		"locked fresh alternate denied despite existing Dynasty")
	check(Store.inspect(app.candidate_owner_path).revision == before.revision,
		"locked alternate does not advance saved owner")
	check(app.dynasty_owner.available_tiers("dugout") == [0], "alternate independently starts Base")
	check(not app.dynasty_owner.start_other("dugout", before.revision, 67003, 1),
		"unearned alternate tier cannot start")
	OwnerUI.show(app)
	check(_league_tier_button(app.menu, "dugout", 1).disabled, "Dugout higher tier locked")
	check(not _league_tier_button(app.menu, "standard", 1).disabled
		and _league_tier_button(app.menu, "standard", 2).disabled, "Standard title unlocks only next Standard tier")
	check(app.dynasty_owner.start_other("dugout", before.revision, 67003), "start Base alternate")
	var opened: Dictionary = Store.inspect(app.candidate_owner_path)
	check(opened.owner.selected == "other", "alternate selected")
	check(opened.owner.lineage.state == "paused", "Dynasty pauses")
	check(opened.owner.dynasty.reference == dynasty_reference, "paused Dynasty snapshot unchanged")
	if app.season == null or app.season.league_rules.league != "dugout":
		return
	check(not app.dynasty_owner.start_other("standard", before.revision, 67004),
		"stale alternate callback cannot replace current session")
	for pick: int in range(4):
		check(app.dynasty_owner.draft_pick(app.season.offers()[0]), "owner-bound pick %d" % pick)
		if app.season.picks.size() != pick + 1:
			return
	check(SeasonInventoryRules.valid(app.season.inventory_rules), "alternate inventory admitted")
	check(app.season.career == null, "alternate does not get a stale personal bank")
	var saved: Dictionary = Store.inspect(app.candidate_owner_path)
	app.season.starter_index = 1
	check(not app.dynasty_owner.switch_to("dynasty", saved.revision), "unsaved source cannot switch")
	check(app.dynasty_owner.recover(), "recover exact selected alternate")
	check(app.dynasty_owner.close_current("abandon", saved.revision), "close alternate explicitly")
	check(not app.dynasty_owner.playable(), "closed alternate cannot keep playing")
	var closed: Dictionary = Store.inspect(app.candidate_owner_path)
	check(app.dynasty_owner.switch_to("dynasty", closed.revision), "return to paused Dynasty")
	check(Store.inspect(app.candidate_owner_path).owner.dynasty.reference == dynasty_reference,
		"returned Dynasty keeps exact original snapshot")
	check(app.dynasty_owner.view().balance == starting_balance, "switch and abandon grant no payout")
	var current: Dictionary = Store.inspect(app.candidate_owner_path)
	check(app.dynasty_owner.start_other("standard", current.revision, 67004, 1),
		"settled alternate can be replaced by owned Standard d1")
	check(app.dynasty_owner.view().sessions.size() == 3,
		"old session history remains after replacement")
	check(app.season.career == null and app.season.league_rules.is_empty()
		and not app.season.home_property.is_empty() and not app.season.npc_venues.is_empty(),
		"Standard replacement keeps owned venues without duplicate wallet")
	check(SeasonSave.snapshot(app.season).get("version") == 89, "Standard replacement uses explicit live89")
	for pick in range(4):
		check(app.dynasty_owner.draft_pick(app.season.offers()[0]), "Standard bound draft pick")
	check(app.season.inventory_rules.is_empty(), "Standard draft does not install alternate inventory")
	var standard: SeasonState = SeasonSave.restore()
	check(standard != null and standard.career == null and standard.picks.size() == 4,
		"Standard controller cold draft survives without ordinary wallet")


func _next_tiers(app: TestApp) -> void:
	var current: Dictionary = Store.inspect(app.candidate_owner_path)
	check(app.dynasty_owner.close_current("abandon", current.revision), "close final test alternate")
	current = Store.inspect(app.candidate_owner_path)
	check(app.dynasty_owner.switch_to("dynasty", current.revision), "return before next Dynasty")
	current = Store.inspect(app.candidate_owner_path)
	check(app.dynasty_owner.close_current("abandon", current.revision), "close Dynasty for next")
	current = Store.inspect(app.candidate_owner_path)
	var source: Dictionary = current.owner.dynasty.reference.duplicate()
	check(app.dynasty_owner.available_tiers("dynasty") == [0], "abandonment grants no Dynasty tier")
	check(not app.dynasty_owner.prepare_next(1, 67005, current.revision), "locked preview refused")
	check(not app.dynasty_owner.begin_next_tier(67005, current.revision, 1), "locked start refused")
	TierUI.show(app)
	check(not _tier_button(app.menu, "dynasty_next_tier", 0).disabled, "Base replay enabled")
	check(_tier_button(app.menu, "dynasty_next_tier", 1).disabled, "unearned Dynasty d1 locked")
	check(_text(app.menu).contains("Other Leagues") or _tier_button(app.menu,
		"dynasty_next_tier", 1).tooltip_text.contains("Other Leagues"), "same-League requirement")
	var controller: RefCounted = app.dynasty_owner
	app.dynasty_owner = TierPresentationFixture.new()
	TierUI.show(app)
	check(not _tier_button(app.menu, "dynasty_next_tier", 0).disabled, "display lower replay remains")
	check(not _tier_button(app.menu, "dynasty_next_tier", 2).disabled, "display unlocked d2 choice")
	check(_tier_button(app.menu, "dynasty_next_tier", 3).disabled, "display next unearned tier locked")
	check(_text(app.menu).contains("d3 nonrefundable copies remain nonrefundable"),
		"Dynasty d4 preview retains cumulative d3 pressure")
	app.dynasty_owner = controller
	check(controller.prepare_next(0, 67005, current.revision), "prepare next Base without writes")
	var ticket: int = controller._next_choice.ticket
	TierUI.review(app)
	check(_text(app.menu).contains("exact difficulty stays saved"), "pending choice tier disclosed")
	controller.cancel_next(ticket)
	check(not controller.commit_next(ticket), "cancelled next choice cannot commit")
	check(Store.inspect(app.candidate_owner_path).owner.dynasty.reference == source,
		"cancel leaves exact closed snapshot")
	check(controller.prepare_next(0, 67005, current.revision), "prepare after cancellation")
	ticket = controller._next_choice.ticket
	app.season.starter_index = (app.season.starter_index + 1) % 4
	check(not controller.commit_next(ticket), "unsaved source invalidates next confirmation")
	check(controller.recover(), "recover closed source before retry")
	Store._test_stop_after = "intent.rename"
	check(not controller.commit_next(ticket), "interrupted next transition not promoted")
	Store._test_stop_after = ""
	check(Store.inspect(app.candidate_owner_path).status == "pending", "next exact intent retained")
	check(not controller.prepare_next(0, 67006, current.revision), "pending next cannot be replaced")
	check(controller.recover(), "recover exact next transition")
	check(not controller.commit_next(ticket), "old ticket cannot repeat saved transition")
	var resumed: Dictionary = Store.inspect(app.candidate_owner_path)
	check(resumed.owner.lineage.ordinal == 2, "one generation after interrupted retry")
	check(app.season.league_rules.tier == 0, "recovered Base choice remains Base")
	check(app.dynasty_owner.view().balance == starting_balance, "next season does not grant CB")
	OwnerUI.record(app)
	check(_text(app.menu).contains("Dynasty / Base"), "saved session displays captured tier")


func _tier_button(node: Node, key: String, tier: int) -> Button:
	if node is Button and node.get_meta(key, -1) == tier:
		return node
	for child: Node in node.get_children():
		var found: Button = _tier_button(child, key, tier)
		if found != null:
			return found
	return null


func _text(node: Node) -> String:
	var result: String = str(node.text) if node is Label or node is Button else ""
	for child: Node in node.get_children():
		result += "\n" + _text(child)
	return result


func _league_tier_button(node: Node, league: String, tier: int) -> Button:
	if node is Button and node.get_meta("owner_league", "") == league \
		and node.get_meta("owner_league_tier", -1) == tier:
		return node
	for child: Node in node.get_children():
		var found: Button = _league_tier_button(child, league, tier)
		if found != null:
			return found
	return null
