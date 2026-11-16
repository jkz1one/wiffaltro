extends Node
## Synthetic eligibility; actual shared seating callbacks, no physical gameplay.
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
	print("SHARED_STADIUM_STYLES_CHECK ", checks, " ", ok, " ", label)
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
	print("SHARED_STADIUM_STYLES checks=%d failures=%d physical_games=0" % [checks, failures])
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
	var quote: Dictionary = access.copy_quote(app, "ST-080")
	if not check(quote.get("ok", false), "current authority offers exact chair quote"):
		app.free()
		return
	ui.show_catalog(app, "ST-080")
	var buy: Button = _button(app.menu, "REVIEW PURCHASE")
	if not check(buy != null and not buy.disabled, "actual shared seating purchase control"):
		app.free()
		return
	buy.pressed.emit()
	check(app._dialog.dialog_text.contains(str(quote.cost)) and app._dialog.dialog_text.contains("unchanged"), "chair confirmation states exact total and frozen fields")
	app._dialog.confirmed.emit()
	app._dialog.hide()
	check(access.ledger(app).construction().blueprints.has("ST-080"), "actual main purchase callback stores chair stock")
	paid = access.ledger(app)
	ui.show(app)
	var choice: OptionButton
	for node: Node in _nodes(app.menu):
		if node is OptionButton and node.has_meta("stadium_copy"):
			choice = node
			break
	if not check(choice != null and not choice.disabled, "shared actual seating placement control"):
		app.free()
		return
	choice.select(1)
	choice.item_selected.emit(1)
	check(access.ledger(app).view().stadium_draft.version == 1, "seating preview does not mutate saved layout")
	var save: Button = _action(app.menu, "save")
	if not check(save != null and not save.disabled, "seating preview enables actual save callback"):
		app.free()
		return
	save.pressed.emit()
	paid = access.ledger(app)
	var layout: Dictionary = paid.view().stadium_draft
	check(layout.version == 2 and layout.seating.size() == 1, "actual UI saved v2 seating draft")
	check(paid.view().stadium_active.version == 1, "draft save leaves authority active layout unchanged")
	var apply: Button = _action(app.menu, "apply")
	if not check(apply != null and not apply.disabled, "saved seating draft enables actual apply callback"):
		app.free()
		return
	apply.pressed.emit()
	check(app._dialog.dialog_text.contains("unchanged"), "future-only field confirmation")
	app._dialog.confirmed.emit()
	app._dialog.hide()
	paid = access.ledger(app)
	check(ClubCareer.same(paid.view().stadium_active, layout), "actual UI applied v2 seating for next admission")
	check(access.apply_draft(app, layout, paid.revision() - 1).get("replayed", false), "exact original apply retry")
	# The v3 adapter reuses paid shared upgrade quotes, never ordinary career writes.
	var style_quote: Dictionary = access.upgrade_quote(app, "stadium_style", "ST-062a", 1)
	if not check(style_quote.get("ok", false), "qualified shared owner offers baseline style"):
		app.free()
		return
	var rows: Array[Dictionary] = Assets.Upgrades.entries()
	var selection: int = -1
	for index: int in range(rows.size()):
		if rows[index].op == "stadium_style" and rows[index].item == "ST-062a":
			selection = index
	if not check(selection >= 0, "style appears in public shared upgrade catalog"):
		app.free()
		return
	ui.show_upgrades(app, selection, 1)
	_button(app.menu, "REVIEW UPGRADE").pressed.emit()
	check(app._dialog.dialog_text.contains(str(style_quote.cost)), "style confirmation states exact shared price")
	app._dialog.confirmed.emit()
	app._dialog.hide()
	paid = access.ledger(app)
	check(paid.construction().styles.has("ST-062a"), "actual shared purchase unlocks baseline entitlement")
	ui.show(app)
	var line: OptionButton = _style(app.menu, "line")
	check(line != null and line.item_count == 2 and not line.disabled, "selector offers template plus purchased baseline only")
	check(_style(app.menu, "grass").item_count == 1, "unowned grass styles are not offered")
	line.select(1)
	line.item_selected.emit(1)
	check(app.menu.page == "shared_stadium", "style callback stays in shared workshop")
	check(access.ledger(app).view().stadium_draft.version == 2, "style preview preserves saved seating draft")
	check(not _action(app.menu, "save").disabled and _action(app.menu, "apply").disabled, "unsaved style requires save before apply")
	_button(app.menu, "CLUB RECORD").pressed.emit()
	check(app._dialog.dialog_text.contains("Discard"), "dirty style navigation asks before discard")
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(app.menu.page == "shared_stadium", "cancel discard retains shared preview")
	_action(app.menu, "save").pressed.emit()
	paid = access.ledger(app)
	layout = paid.view().stadium_draft
	check(layout.version == 3 and layout.styles.line == "ST-062a" and layout.seating.size() == 1, "v3 save preserves paid seating and owned baseline")
	check(paid.view().stadium_active.version == 2, "style draft leaves active seating unchanged")
	_action(app.menu, "apply").pressed.emit()
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(access.ledger(app).view().stadium_active.version == 2, "cancel apply leaves active authority unchanged")
	_action(app.menu, "apply").pressed.emit()
	app._dialog.confirmed.emit()
	app._dialog.hide()
	paid = access.ledger(app)
	check(ClubCareer.same(paid.view().stadium_active, layout), "actual shared confirmation applies v3 appearance")
	check(access.apply_draft(app, layout, paid.revision() - 1).get("replayed", false), "exact v3 apply retry is idempotent")
	var invalid: Dictionary = layout.duplicate(true)
	invalid.styles.grass = "ST-063d"
	ui.show(app, invalid, paid.revision())
	check(_action(app.menu, "save") == null and _style(app.menu, "line") == null, "unowned held style cannot reach controls or save")
	check(not access.save_draft(app, invalid, paid.revision()).ok, "owner transaction rejects unowned style")
	_button(app.menu, "RELOAD SAVED").pressed.emit()
	check(_style(app.menu, "line").selected == 1, "reload restores purchased baseline selection")
	ui.show(app, layout, paid.revision() - 1)
	check(_style(app.menu, "line").disabled and _action(app.menu, "save").disabled and _action(app.menu, "apply").disabled, "stale style preview disables editing and writes")
	ui.show(app)
	var after: Dictionary = Store.inspect(path).owner
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "both grants remain frozen")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "both snapshot refs remain frozen")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "current field remains exact")
	check(paid.balance() == Authority.view(before.career).balance - quote.cost - style_quote.cost, "save/apply/retry charge no additional bucks")
	var future_grant: Dictionary = Grant.capture(after.career)
	var future_context: Dictionary = context.duplicate(true)
	future_context.session_id = "future-seating-only"
	future_context.grant_sha256 = Save.snapshot_reference(future_grant).sha256
	var future: SeasonState = Live.create(future_grant, future_context)
	check(future != null and ClubCareer.same(future.home_property.layout, layout), "only future admission sees applied seating layout")
	check(future != null and future.career == null and future.player_access == app.season.player_access, "future field uses real shared adapter without career spoofing or new players")
	app.free()
	app = Main.instantiate()
	add_child(app)
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "cold current field remains frozen")
	check(ClubCareer.same(access.ledger(app).view().stadium_active, layout), "cold shared seating layout survives")
	ui.show(app)
	check(app.menu.page == "shared_stadium" and _action(app.menu, "save") != null, "cold v3 editor remains editable")
	app.free()
	SeasonSave.path = original

func _nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child: Node in root.get_children():
		result.append_array(_nodes(child))
	return result

func _action(root: Node, action: String) -> Button:
	for node: Node in _nodes(root):
		if node is Button and node.get_meta("shared_stadium_action", "") == action:
			return node
	return null


func _button(root: Node, caption: String) -> Button:
	for node: Node in _nodes(root):
		if node is Button and node.text == caption:
			return node
	return null

func _style(root: Node, channel: String) -> OptionButton:
	for node: Node in _nodes(root):
		if node is OptionButton and node.get_meta("stadium_style", "") == channel:
			return node
	return null
