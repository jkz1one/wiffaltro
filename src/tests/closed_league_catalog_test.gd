extends Node
## Future bounded source/controller qualification. No physical games, fabricated
## earnings, public admission or default save access. Requires explicit test root.
const Setup = preload("res://src/presentation/season/closed_league_setup_controller.gd")
const DevOwner = preload("res://src/presentation/season/closed_league_dev_owner_controller.gd")
const DevApp = preload("res://src/presentation/season/closed_league_dev_app.gd")
const Catalog = preload("res://src/presentation/season/league_catalog_ui.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Owner = preload("res://src/gameplay/season/dynasty_owner.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")


class TestApp:
	extends Node
	var season: SeasonState
	var dynasty_owner: RefCounted
	var lab: Node
	var notice: String = ""
	var menu: SeasonMenu
	var promoted: int = 0

	var _busy: bool = false

	func show_season() -> void:
		promoted += 1


var checks: int = 0
var failures: int = 0
var root: String = ""
var ordinary_before: PackedByteArray


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--catalog-test-root="):
			root = argument.trim_prefix("--catalog-test-root=")
	if (
		not root.is_absolute_path()
		or root.length() < 2
		or root != root.simplify_path()
		or root.begins_with("res://")
		or root.begins_with("user://")
		or DirAccess.dir_exists_absolute(root)
	):
		push_error("A fresh explicit absolute --catalog-test-root= is required; no test ran.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root.path_join("owners"))
	SeasonSave.path = root.path_join("ordinary-sentinel.json")
	var sentinel: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	sentinel.store_string("ordinary saved bytes: never opened or overwritten by closed enrollment")
	sentinel.close()
	ordinary_before = FileAccess.get_file_as_bytes(SeasonSave.path)
	_launch_controls()
	for league_id: String in LeagueRules.IDS:
		check(
			(
				not Catalog.description(league_id).is_empty()
				and not LeagueRules.public_activation_enabled(league_id)
			),
			"catalog description and public hold: " + league_id
		)
		check(
			LeagueRules.capture(league_id, 1, 5 if league_id == "scramble" else null).is_empty(),
			"higher tier not admitted: " + league_id
		)
		if league_id != "dynasty":
			_first_alternate(league_id)
	_cancel_stale_and_failures()
	_pending_retry()
	Store._test_stop_after = ""
	check(
		FileAccess.get_file_as_bytes(SeasonSave.path) == ordinary_before,
		"ordinary save bytes unchanged throughout"
	)
	check(
		(
			not FileAccess.file_exists(SeasonSave.path + ".bak")
			and not FileAccess.file_exists(SeasonSave.path + ".tmp")
		),
		"no ordinary backup or temp created"
	)
	SeasonSave._dynasty_owner_path = ""
	print("Closed catalog checks: %d, failures: %d, new physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _launch_controls() -> void:
	var ordinary: SeasonApp = SeasonApp.new()
	var ordinary_controller: RefCounted = ordinary._make_dynasty_owner_controller()
	check(
		(
			ordinary_controller.get_script()
			== preload("res://src/presentation/season/dynasty_owner_controller.gd")
		),
		"normal controller factory remains unchanged"
	)
	ordinary.free()
	var dev: Node = DevApp.new()
	var dev_controller: RefCounted = dev._make_dynasty_owner_controller()
	check(
		dev_controller.get_script() == DevOwner,
		"dev recovery controller is selected before inherited startup"
	)
	dev.free()
	check(DevApp.launch_arguments(PackedStringArray()).is_empty(), "no implicit dev launch")
	var path: String = root.path_join("owners/example.json")
	var args: PackedStringArray = PackedStringArray(
		["--closed-dynasty-owner=" + path, "--closed-league-dev-root=" + root.path_join("owners")]
	)
	check(not DevApp.launch_arguments(args).is_empty(), "explicit isolated launch shape")
	args.append("--closed-dynasty-owner=" + path)
	check(DevApp.launch_arguments(args).is_empty(), "duplicate owner arguments reject")
	check(
		(
			DevApp
			. launch_arguments(
				PackedStringArray(
					[
						"--closed-dynasty-owner=" + SeasonSave.path,
						"--closed-league-dev-root=" + root
					]
				)
			)
			. is_empty()
		),
		"ordinary-root overlap rejects"
	)


func _new_owner(name: String) -> TestApp:
	# Real zero-earnings ordinary draft, not an earned-feature or paid-item claim.
	var source: SeasonState = SeasonState.create(61001, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), name + ": source career starts")
	for index in range(4):
		check(source.choose_player(source.offers()[0]), name + ": source draft")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(
		origin, "catalog-" + name, "owner-" + name
	)
	var target: SeasonState = Bridge.create(profile)
	check(target != null, name + ": existing bridge creates controlled zero-growth target")
	if target == null:
		return null
	var path: String = root.path_join("owners/" + name + ".json")
	var outcome: Dictionary = Store.create(
		{
			"lineage": Lineage.create(profile),
			"snapshot": SeasonSave.snapshot(target),
			"session_id": profile.lineage_id + ":1",
			"origin": origin
		},
		path
	)
	check(
		outcome.get("status") == "committed",
		name + ": exact source owner created for isolated test"
	)
	if outcome.get("status") != "committed":
		return null
	check(SeasonSave.bind_dynasty_owner(path), name + ": bind test owner")
	var app: TestApp = TestApp.new()
	app.season = SeasonSave.restore()
	app.dynasty_owner = DevOwner.new(app)
	check(app.season != null, name + ": cold owner qualifies")
	return app


func _draft(setup: RefCounted) -> void:
	var ticket: String = setup.token()
	for index in range(4):
		var candidate: SeasonState = setup.candidate()
		if candidate == null or candidate.offers().is_empty():
			check(false, "candidate offers available before each detached pick")
			return
		check(
			setup.choose_player(ticket, index, candidate.offers()[0]),
			"detached draft pick %d: %s" % [index, setup.error]
		)
		candidate = setup.candidate()
		check(
			candidate != null and SeasonSave._decode(SeasonSave.snapshot(candidate)) != null,
			"detached pick cold round trip"
		)


func _first_alternate(league_id: String) -> void:
	var app: TestApp = _new_owner(league_id)
	if app == null or app.season == null:
		return
	var setup: RefCounted = Setup.new(app)
	var path: String = SeasonSave._dynasty_owner_path
	var original: Dictionary = SeasonSave.snapshot(app.season)
	var found: Dictionary = Store.inspect(path)
	check(
		setup.prepare_alternate(league_id, 61002, int(found.revision)),
		"prepare " + league_id + ": " + setup.error
	)
	if setup.candidate() == null:
		app.free()
		return
	var ticket: String = setup.token()
	check(
		setup.candidate().inventory_rules.is_empty(),
		"fresh detached draft has no early inventory grant"
	)
	_draft(setup)
	check(
		Owner.fingerprint(SeasonSave.snapshot(app.season)) == Owner.fingerprint(original),
		"draft never replaces live Dynasty"
	)
	check(Store.inspect(path).revision == found.revision, "draft writes no owner revision")
	var candidate: SeasonState = setup.candidate()
	check(
		SeasonInventoryRules.valid(candidate.inventory_rules) and candidate.build.cash() == 0,
		"inventory admitted without money grant"
	)
	for club: Dictionary in candidate.opponents.clubs.values():
		check(
			SeasonInventoryRules.build_consistent(club.build, true),
			"AI inventory admission is shared"
		)
	var prepared: Dictionary = SeasonSave.snapshot(candidate)
	check(setup.commit_alternate(ticket), "first alternate commits: " + setup.error)
	var after: Dictionary = Store.inspect(path)
	check(
		after.get("owner", {}).get("other", {}).get("profile", {}).get("league") == league_id,
		"captured alternate League preserved"
	)
	check(
		Owner.fingerprint(SeasonSave.snapshot(app.season)) == Owner.fingerprint(prepared),
		"only exact prepared candidate promoted"
	)
	check(
		not setup.commit_alternate(ticket) and Store.inspect(path).revision == after.revision,
		"duplicate confirmation cannot create a second alternate"
	)
	check(
		app.dynasty_owner.switch_to("dynasty", int(after.revision)),
		"return to Dynasty via existing controller"
	)
	check(
		Owner.fingerprint(SeasonSave.snapshot(app.season)) == Owner.fingerprint(original),
		"exact Dynasty restored"
	)
	check(
		not setup.prepare_alternate("dugout", 61003, int(Store.inspect(path).revision)),
		"occupied alternate is never replaced"
	)
	check(
		app.dynasty_owner.switch_to("other", int(Store.inspect(path).revision)),
		"resume captured alternate"
	)
	var cold: SeasonState = SeasonSave.restore()
	check(
		(
			cold != null
			and Owner.fingerprint(SeasonSave.snapshot(cold)) == Owner.fingerprint(prepared)
		),
		"cold resume retains exact alternate and inventory"
	)
	check(
		cold != null and SeasonPages.league_identity(cold) == league_id.capitalize() + " / Base",
		"captured presentation label"
	)
	app.free()


func _cancel_stale_and_failures() -> void:
	var app: TestApp = _new_owner("cancel")
	if app == null or app.season == null:
		return
	var setup: RefCounted = Setup.new(app)
	var path: String = SeasonSave._dynasty_owner_path
	var revision: int = int(Store.inspect(path).revision)
	check(not setup.prepare_alternate("dynasty", 61004, revision), "no hidden Dynasty enrollment")
	check(
		not setup.prepare_alternate("dugout", 61004, revision + 1), "stale catalog revision rejects"
	)
	check(setup.prepare_alternate("dugout", 61004, revision), "prepare cancel control")
	var ticket: String = setup.token()
	var offered: String = setup.candidate().offers()[0]
	check(
		setup.cancel(ticket) and Store.inspect(path).revision == revision,
		"Cancel leaves exact owner untouched"
	)
	check(
		not setup.choose_player(ticket, 0, offered) and not setup.commit_alternate(ticket),
		"cancelled callbacks cannot act"
	)
	check(
		setup.prepare_alternate("dugout", 61004, revision), "new setup after explicit cancellation"
	)
	ticket = setup.token()
	check(
		SeasonSave.save(app.season), "same-session checkpoint advances revision for stale control"
	)
	check(
		not setup.choose_player(ticket, 0, setup.candidate().offers()[0]),
		"changed owner invalidates draft callback"
	)
	check(setup.cancel(ticket), "stale uncommitted preview can be discarded")
	check(
		setup.prepare_alternate("dugout", 61004, int(Store.inspect(path).revision)),
		"prepare precommit failure control"
	)
	_draft(setup)
	ticket = setup.token()
	var prepared: String = Owner.fingerprint(SeasonSave.snapshot(setup.candidate()))
	var before: Dictionary = Store.inspect(path)
	Store._test_stop_after = "object0.a.open"
	check(not setup.commit_alternate(ticket), "interrupted object preparation does not promote")
	Store._test_stop_after = ""
	check(
		(
			Store.inspect(path).revision == before.revision
			and setup.token() == ticket
			and Owner.fingerprint(SeasonSave.snapshot(setup.candidate())) == prepared
		),
		"failed commit retains exact candidate/seed/request"
	)
	check(setup.commit_alternate(ticket), "exact precommit retry succeeds without reroll")
	app.free()


func _pending_retry() -> void:
	var app: TestApp = _new_owner("pending")
	if app == null or app.season == null:
		return
	var setup: RefCounted = Setup.new(app)
	var path: String = SeasonSave._dynasty_owner_path
	check(
		setup.prepare_alternate("dugout", 61005, int(Store.inspect(path).revision)),
		"prepare pending control"
	)
	_draft(setup)
	var ticket: String = setup.token()
	Store._test_stop_after = "intent.rename"
	check(not setup.commit_alternate(ticket), "intent interruption reported before promotion")
	Store._test_stop_after = ""
	check(Store.inspect(path).status == "pending", "exact enrollment remains pending")
	check(
		not setup.cancel(ticket) and setup.token() == ticket,
		"pending intent cannot be cancelled/reset"
	)
	check(setup.commit_alternate(ticket), "exact pending retry commits existing request")
	check(
		Store.inspect(path).get("owner", {}).get("other", {}).get("session_id") == ticket,
		"retry uses original session ID"
	)
	# Missing live selection is recoverable; catalog recovery must not require it.
	app.season = null
	SeasonSave._dynasty_owner_content_blocked = true
	var menu: SeasonMenu = SeasonMenu.new()
	var controls: VBoxContainer = VBoxContainer.new()
	app.dynasty_owner.add_controls(menu, controls)
	check(
		controls.get_child_count() == 1 and controls.get_child(0).text == "RECOVER SAVE",
		"metadata-ready but missing live source offers recovery only"
	)
	controls.free()
	menu.free()
	check(setup.recover() and app.season != null, "recovery accepts null live season")
	app.free()
