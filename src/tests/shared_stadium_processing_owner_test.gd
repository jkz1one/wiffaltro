extends Node
## Synthetic earned Dugout history, actual modern new_club origin and owner storage. No physical wins.
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
	print("PROCESSING_OWNER_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	var root: String = ""
	var final_owner: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--processing-final-owner="):
			final_owner = arg.trim_prefix("--processing-final-owner=")
		if arg.begins_with("--stadium-assets-root="):
			root = arg.trim_prefix("--stadium-assets-root=")
	if not final_owner.is_empty():
		_verify_final(final_owner)
		print("SHARED_PROCESSING_FINAL checks=%d failures=%d physical_games=0" % [checks, failures])
		get_tree().quit(0 if failures == 0 else 1)
		return
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	await _run(root.path_join("ordinary.json.dynasty-owner"))
	print("SHARED_PROCESSING_OWNER checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _origin_fixture() -> Dictionary:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = preload("res://src/tests/league_unlock_fixture.gd").prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3},
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 0}])
	var awards: Dictionary = StadiumPennantRewards.awards(source.career)
	awards.merge(StadiumPlaqueRewards.awards(source.career))
	source.career._assets = ClubAssetLedger.new_club(int(source.career.runs[0].seed),
		ClubPlayers.income(source.career), StadiumCareerProgress.capture(source.career), awards).to_data()
	check(ClubPlayers.assets(source.career).view().stadium_draft.version == 40, "exact modern family40 origin")
	check(source.career.start(source), "ordinary origin")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin pick")
	return SeasonSave.snapshot(source)

func _run(path: String) -> void:
	var origin: Dictionary = _origin_fixture()
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
	await _exercise(app, path)
	app.free()
	SeasonSave.path = original
	SeasonSave._dynasty_owner_path = ""

const UI = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
const Access = preload("res://src/presentation/stadium/stadium_career_access.gd")
const Busy = preload("res://src/presentation/stadium/shared_stadium_transaction_ui.gd")

func _button(app: SeasonApp, label: String) -> Button:
	for parent: Control in [app.menu._body, app.menu._footer]:
		for child: Node in parent.find_children("*", "Button", true, false):
			if child.text == label:
				return child as Button
	return null

func _settle(app: SeasonApp) -> void:
	while Busy.busy(app.menu):
		await get_tree().process_frame

func _exercise(app: SeasonApp, path: String) -> void:
	if not check(app.season != null and Access.editable(app), "normal main owner runtime opens exact synthetic modern owner"):
		return
	var before: Dictionary = Store.inspect(path).owner
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	var evidence: FileAccess = FileAccess.open(path.get_base_dir().path_join("before.json"), FileAccess.WRITE)
	evidence.store_string(JSON.stringify({"owner": before, "frozen": frozen}))
	evidence.close()
	var paid: ClubAssetLedger = Access.ledger(app)
	var initial_balance: int = paid.balance()
	UI.show(app)
	var initial_bytes: String = FileAccess.get_sha256(path)
	_button(app, "REVIEW CLEARANCE • 190 CB").pressed.emit()
	var clear: Callable = app._confirmed_action
	app._dialog.confirmed.emit()
	check(Busy.busy(app.menu) and not app._dialog.visible, "clearance immediately replaces confirmation with processing")
	check(FileAccess.get_sha256(path) == initial_bytes, "clearance does not write before paint yield")
	clear.call()
	await _settle(app)
	paid = Access.ledger(app)
	if not check(paid != null and paid.view().salvage_cleared and paid.balance() == initial_balance - 190, "one exact clearance debit after duplicate confirmation"):
		return
	check(app.notice.contains("same owned copy"), "clearance success shown only after durable commit")
	clear.call()
	check(paid.balance() == initial_balance - 190, "retired clearance remains inert")

	var cleared: Dictionary = Store.inspect(path).owner
	var draft: Dictionary = paid.view().stadium_draft.duplicate(true)
	draft = StadiumSalvageCarItems.place(draft, paid.construction(), StadiumStock.SALVAGE_COPY, "CAR-START", paid.surface_owned())
	if not check(not draft.is_empty(), "same cleared car makes valid placement preview"):
		return
	UI.show(app, draft, paid.revision())
	var revision: int = paid.revision()
	var save_button: Button = _button(app, "SAVE SHARED DRAFT")
	if not check(save_button != null and not save_button.disabled, "current modern preview Save enabled"):
		return
	var save: Callable = save_button.pressed.get_connections()[0].callable
	Store._test_stop_after = "intent.rename"
	save_button.pressed.emit()
	check(Busy.busy(app.menu) and save_button.disabled, "Save immediately disables its control")
	save.call()
	await _settle(app)
	Store._test_stop_after = ""
	check(Store.inspect(path).status == "pending" and Access.ledger(app) == null, "interrupted durable Save exposes pending recovery not success")
	check(_button(app, "RECOVER SHARED CAREER") != null and not Busy.busy(app.menu), "failure leaves recover control visible and unlocked")
	if not check(app.dynasty_owner.recover(), "exact interrupted Save recovers through normal owner controller"):
		return
	check(Access.save_draft(app, draft, revision).get("replayed", false), "recovered Save exact retry remains idempotent")
	UI.show(app)
	paid = Access.ledger(app)
	check(ClubCareer.same(paid.view().stadium_draft, draft), "recovered modern draft persisted")
	var saved_hash: String = FileAccess.get_sha256(path)
	save.call()
	check(FileAccess.get_sha256(path) == saved_hash, "retired Save cannot write after recovery")
	_button(app, "APPLY FOR FUTURE SEASONS").pressed.emit()
	var apply: Callable = app._confirmed_action
	app._dialog.confirmed.emit()
	check(Busy.busy(app.menu) and not app._dialog.visible, "Apply immediately hides enabled confirmation")
	check(FileAccess.get_sha256(path) == saved_hash, "Apply has not claimed success before paint yield")
	apply.call()
	await _settle(app)
	paid = Access.ledger(app)
	check(ClubCareer.same(paid.view().stadium_active, draft), "one durable Apply installs exact future modern field")
	check(app.notice.contains("Existing fields are unchanged") and not Busy.busy(app.menu), "durable Apply success visible and unlocked")
	var final_hash: String = FileAccess.get_sha256(path)
	apply.call()
	await get_tree().process_frame
	check(FileAccess.get_sha256(path) == final_hash, "replayed confirmation after freed controls does not write")
	var after: Dictionary = Store.inspect(path).owner
	check(paid.balance() == initial_balance - 190, "Save Apply recovery and duplicates add no debit")
	check(after.revision == before.revision + 3, "exactly clearance draft and apply durable revisions")
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "all session grants stay frozen")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "both saved field slots stay frozen")
	check(ClubCareer.same(before.career.origin, after.career.origin), "origin authority stays frozen")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "current live season stays frozen")


func _verify_final(path: String) -> void:
	if not check(path.is_absolute_path() and path.ends_with("ordinary.json.dynasty-owner") and FileAccess.file_exists(path), "requires this isolated fixture owner"):
		return
	var found: Dictionary = Store.inspect(path)
	if not check(found.status == "ready" and found.revision == 5, "finished owner is ready at exact revision five"):
		return
	var expected: Dictionary = Authority.create(_origin_fixture(), "runtime-owner")
	check(not expected.is_empty() and ClubCareer.same(found.owner.career.origin, expected.origin), "origin authority equals independently regenerated exact synthetic origin")
	var hash_before: String = FileAccess.get_sha256(path)
	SeasonSave.path = path.trim_suffix(".dynasty-owner")
	SeasonSave._dynasty_owner_path = ""
	var app: SeasonApp = Main.instantiate()
	add_child(app)
	var saved: Dictionary = Store._read_object(path, found.owner.other.reference)
	check(saved.get("ok", false) and ClubCareer.same(SeasonSave.snapshot(app.season), saved.snapshot), "cold current live season equals exact retained frozen snapshot")
	var paid: ClubAssetLedger = Access.ledger(app)
	check(paid != null and paid.balance() == 1134 and paid.view().stadium_active.version == 40, "cold modern field and one clearance debit persist")
	check(FileAccess.get_sha256(path) == hash_before, "final read checks perform no writes")
	app.free()
	SeasonSave._dynasty_owner_path = ""
