extends Node
## Finite UI composition checks. No mouse, rendered-readability or gameplay qualification.
# gdlint: disable=max-file-lines,max-returns

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const EXPECTED_CHECKS: int = 372
# V59 255 + inventory 110 + active16 inventory 5 + stale Store 2 = 372.
const SUMMARY_CAP: int = 131072
const FUNDING_CAP: int = 8 * 1024 * 1024
const TREE_CAP: int = 512
const TREE_BYTES_CAP: int = 2 * 1024 * 1024

var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _groups: Array[Dictionary] = []
var _stages: Array[Dictionary] = []
var _refusals: Array[Dictionary] = []
var _previews: Array[Dictionary] = []
var _negatives: Array[Dictionary] = []
var _navigation: Array[Dictionary] = []
var _placements: Array[Dictionary] = []
var _inventory: Dictionary = {}
var _inventory_navigation_facts: Array[Dictionary] = []
var _inventory_checks: int = 0
var _placement_checks: int = 0
var _placement_stale: Dictionary = {}
var _output: String = ""
var _runtime: String = ""
var _expected_runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _admitted: bool = false
var _app: SeasonApp
var _pool_copy: String = ""
var _supported: Dictionary = {}
var _layout: Dictionary = {}
var _moved: Dictionary = {}
var _frozen_home: PackedByteArray
var _funding: Dictionary = {}
var _disposed: bool = false
var _final_no_lab: bool = false
var _tree_ok: bool = true


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		for key: String in ["dir", "runtime", "execution", "nonce"]:
			var prefix: String = "--pool-workshop-v51-" + key + "="
			if argument.begins_with(prefix):
				set({"dir": "_output", "runtime": "_expected_runtime",
					"execution": "_execution", "nonce": "_nonce"}[key], argument.trim_prefix(prefix))
	get_window().size = Vector2i(1280, 720)
	await _run()
	var app_ref: WeakRef = weakref(_app) if is_instance_valid(_app) else null
	if is_instance_valid(_app):
		_app.queue_free()
	await _frames()
	_disposed = app_ref == null or app_ref.get_ref() == null
	_check(_disposed, "application and private preview worlds disposed")
	await TestAudioDrain.finish(get_tree())
	_check(_checks + 1 == EXPECTED_CHECKS, "exact source-derived UI assertion count")
	var summary: Dictionary = _identity()
	summary.merge({"checks": _checks, "expected_checks": EXPECTED_CHECKS,
		"failures": _failures, "failed": _failed, "status": "PASS" if _failures == 0 else "FAILED",
		"groups": _groups, "stages": _stages, "refusals": _refusals,
		"previews": _previews, "negatives": _negatives, "navigation": _navigation,
		"placements": _placements, "placement_stale": _placement_stale,
		"inventory_preview": _inventory,
		"inventory_navigation": _inventory_navigation_facts,
		"disposed": _disposed,
		"preview_exposed": StadiumPoolWorkshopUI.PREVIEW_EXPOSED,
		"final_no_lab": _final_no_lab,
		"gameplay_launch_scope": "source-declared no launch calls; final state checked, no event counter",
		"funding_label": "deterministically simulated seed42 career, at most18 seasons",
		"interaction_scope": "actual menu signals and production handlers; no physical mouse claim",
		"visual_scope": "native tree parity only; rendered readability remains unqualified"})
	if not _write("pool-workshop-v51-summary.json", summary, SUMMARY_CAP):
		push_error("POOL_WORKSHOP_V51 summary could not be retained")
	print("POOL_WORKSHOP_V51 checks=%d failures=%d status=%s source=%s" % [
		_checks, _failures, summary.status, _runtime])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var first: int = _checks
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and OS.get_cmdline_user_args().has("--physical-in-process"), "explicit isolated output"):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty()
		and DirAccess.get_directories_at(_output).is_empty(), "fresh empty output"):
		return
	_admitted = true
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _check(_hex(_runtime, 64) and _runtime == _expected_runtime
		and _hex(_execution, 64) and _hex(_nonce, 32), "actual source and execution binding"):
		return
	_check(not StadiumPoolWorkshopUI.PREVIEW_EXPOSED, "production preview exposure stays closed")
	_group("admission", first)
	first = _checks
	if not await _setup():
		return
	_group("genuine_setup", first)
	first = _checks
	await _stored()
	_group("stored_old_layout", first)
	first = _checks
	await _preview_matrix()
	_group("readonly_preview", first)
	first = _checks
	await _inventory_matrix()
	_inventory_checks = _checks - first
	first = _checks
	await _placement_matrix()
	_placement_checks = _checks - first
	first = _checks
	var placement_before: int = _placement_checks
	var inventory_before: int = _inventory_checks
	await _stage_matrix()
	_group("staged_handlers", first + _placement_checks - placement_before
		+ _inventory_checks - inventory_before)
	_groups.append({"label": "placement_preview", "checks": _placement_checks})
	_groups.append({"label": "inventory_preview", "checks": _inventory_checks})
	_final_no_lab = _app.lab == null
	_check(_final_no_lab and _app.season.phase == SeasonState.Phase.DRAFT
		and _app.season.picks.is_empty(), "no gameplay start or roster selection")
	_check(var_to_bytes(_app.season.home_property) == _frozen_home,
		"all UI work preserves the original frozen supported home")


func _setup() -> bool:
	SeasonSave.path = _output.path_join("owned-career.json")
	PitchBatLabSettings.path = _output.path_join("owned-settings.cfg")
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if not _check(not FileAccess.file_exists(path + suffix), "isolated save path is new"):
				return false
	_funding = CareerFixture.new().fund(SeasonSave.path)
	var retained: Dictionary = _funding.duplicate(true)
	retained.erase("season")
	if not _write("pool-owned-v28-generated-career.json", retained, FUNDING_CAP):
		return false
	if not _check(_funding.get("ok", false) and _funding.seed == 42
		and _funding.completed_runs <= 18, "genuine bounded simulator funding"):
		return false
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	if not _check(_app.season != null and _app.season.phase == SeasonState.Phase.COMPLETE,
		"ordinary application restores the actual completed career"):
		return false
	_app.begin_season(42, true, true, true, true, false)
	if not _check(_app.season.phase == SeasonState.Phase.DRAFT
		and _app.season.picks.is_empty() and _app.lab == null,
		"ordinary next season remains before roster and gameplay"):
		return false
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var balance: int = _app.season.career.balance()
	var revision: int = ledger.revision()
	var bought: Dictionary = ClubConstruction.buy_copy(_app.season, "ST-006", revision)
	if not _check(bought.get("ok", false) and not bought.get("replayed", true),
		"ordinary unlocked Pool purchase succeeds"):
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	_check(_app.season.career.balance() == balance - 700 and ledger.revision() == revision + 1,
		"ordinary first Pool costs exactly700 and advances one journal entry")
	var paid: PackedByteArray = var_to_bytes(ledger.to_data())
	var replay: Dictionary = ClubConstruction.buy_copy(_app.season, "ST-006", revision)
	_check(replay.get("ok", false) and replay.get("replayed", false)
		and paid == var_to_bytes(ClubPlayers.assets(_app.season.career).to_data()),
		"duplicate purchase replays without another charge")
	var found: Array[String] = []
	for id: String in ledger.construction().copies:
		if ledger.construction().copies[id].item == "ST-006":
			found.append(id)
	if not _check(found.size() == 1, "one actual paid Pool copy from journal inventory"):
		return false
	_pool_copy = found[0]
	if not _place_owned_receiver():
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	_supported = ledger.view().stadium_active.duplicate(true)
	_layout = StadiumPoolOwnedLayout.upgrade(_supported, ledger.construction(),
		ledger.surface_owned(), ledger.view().land, _pool_copy, Vector2(12, 18), 0)
	if not _check(not _layout.is_empty(), "first fixed legal paid Pool pose"):
		return false
	_moved = StadiumPoolOwnedLayout.relocated(_layout, ledger.construction(),
		ledger.surface_owned(), ledger.view().land, Vector2(-12, 18), 270)
	if not _check(not _moved.is_empty() and _moved.surface == _layout.surface,
		"second fixed legal pose preserves the selected surface"):
		return false
	_frozen_home = var_to_bytes(_app.season.home_property)
	_check(_supported.version <= 15 and ledger.view().stadium_draft == _supported
		and StadiumLayoutSnapshot.matches(_app.season.home_property, ledger),
		"genuine paid Pool starts stored beside a frozen supported layout")
	return true


func _stored() -> void:
	var held: PackedByteArray = _held()
	ClubCareerUI.show(_app.menu)
	await _frames()
	var entry: Button = _button(_app.menu, "STADIUM WORKSHOP")
	_check(entry != null and not entry.disabled, "ordinary workshop menu entry exists")
	if entry == null:
		return
	entry.pressed.emit()
	await _frames()
	var cards: Array[Node] = _cards()
	_check(cards.size() == 1 and cards[0].get_meta("pool_copy", "") == _pool_copy
		and not cards[0].has_meta("pool_status"), "stored copy gets dedicated read-only card")
	var text: String = _text(_app.menu)
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	_check(text.contains("OWNED POOL • STORED") and text.contains(_pool_copy)
		and text.contains("Paid %d CB" % ledger.construction().copies[_pool_copy].paid)
		and text.contains("4 / 4") and text.contains(StadiumPoolWorkshopUI.NOTICE),
		"stored card reports paid identity capacity and pending qualification")
	_check(_choice(_pool_copy) == null, "stored Pool has no generic small-site choice")
	var receiver: OptionButton = _choice(_supported.receiver)
	_check(receiver != null and not receiver.disabled, "old-layout receiver editing stays enabled")
	var preview: StadiumDraftPreview = _preview(_app)
	_check(preview != null and preview.preview_property != null
		and preview.preview_property.get_node_or_null("BoundaryGraph") != null
		and preview.pool_model == null,
		"old layout retains its original complete preview")
	_check(_button(_app.menu, "SAVE DRAFT") != null
		and _button(_app.menu, "APPLY LAYOUT") != null, "old-layout save and apply controls remain")
	_check(held == _held(), "opening stored Pool card preserves all held bytes")
	StadiumEditorUI._buy(_app.menu, "ST-006", ledger.revision())
	await _frames()
	_check(held == _held() and _app.notice == StadiumPoolWorkshopUI.NOTICE,
		"direct stored-context Pool purchase handler refuses without mutation")


func _stage_matrix() -> void:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	await _stage("requested", _layout, ledger.revision(), 1)
	var navigation_held: PackedByteArray = _held()
	var back: Button = _button(_app.menu, "CLUB RECORD")
	var back_present: bool = back != null
	if back_present:
		back.pressed.emit()
	await _frames()
	var navigation_page: String = _app.menu.page
	var navigation_dialog: bool = _app._dialog.visible
	var navigation_after: PackedByteArray = _held()
	var navigation_equal: bool = navigation_held == navigation_after
	_navigation.append({"label": "requested_unsaved", "present_before": back_present,
		"page": navigation_page, "dialog_visible": navigation_dialog,
		"held_before_sha256": navigation_held.hex_encode().sha256_text(),
		"held_after_sha256": navigation_after.hex_encode().sha256_text(),
		"held_equal": navigation_equal})
	_check(back_present and navigation_dialog, "unsaved requested Pool Back asks before discard")
	_app._dialog.get_cancel_button().pressed.emit()
	await _frames()
	_check(_app.menu.page == "stadium" and not _app._dialog.visible and navigation_held == _held(),
		"cancelled Back keeps staged data and every held byte")
	await _refuse("requested", _layout, ledger.revision())
	var reload_button: Button = _button(_app.menu, "RELOAD SAVED")
	_check(reload_button != null and not reload_button.disabled, "requested staging offers reload")
	if reload_button != null:
		reload_button.pressed.emit()
	await _frames()
	_check(_preview(_app) != null and not _app._dialog.visible,
		"reload returns requested-only Pool to ordinary saved workshop")
	await _placement_stale_open(ledger.revision())
	var old_revision: int = ledger.revision()
	_check(ClubConstruction.save_draft(_app.season, _layout, old_revision).ok,
		"ordinary paid transaction stages saved-only16")
	ledger = ClubPlayers.assets(_app.season.career)
	await _placement_stale_check(old_revision)
	await _stage("saved", _supported, ledger.revision(), 1)
	await _refuse("stale_saved", _supported, old_revision)
	var home: PackedByteArray = var_to_bytes(_app.season.home_property)
	_check(ClubPlayers.transact(_app.season, {"id": "pool-workshop-active-v51",
		"rev": ledger.revision(), "op": "stadium_apply", "layout": _layout,
		"geometry": StadiumPoolOwnedLayout.geometry(ledger.view().land, _layout)}).ok,
		"ordinary data-only transaction stages paid active16")
	ledger = ClubPlayers.assets(_app.season.career)
	_check(ClubConstruction.save_draft(_app.season, _supported, ledger.revision()).ok,
		"ordinary draft transaction restores supported saved layout beside active16")
	ledger = ClubPlayers.assets(_app.season.career)
	_check(home == var_to_bytes(_app.season.home_property)
		and ledger.view().stadium_active == _layout and ledger.view().stadium_draft == _supported,
		"active-only16 preserves the existing frozen home")
	await _inventory_active(ledger)
	await _stage("active", _supported, ledger.revision(), 1)
	await _refuse("stale_active", _supported, old_revision)
	_check(ClubConstruction.save_draft(_app.season, _layout, ledger.revision()).ok,
		"ordinary transaction retains saved and active16 together")
	ledger = ClubPlayers.assets(_app.season.career)
	await _stage("saved_active", _layout, ledger.revision(), 3)
	navigation_held = _held()
	back = _button(_app.menu, "CLUB RECORD")
	back_present = back != null
	if back_present:
		back.pressed.emit()
	await _frames()
	navigation_page = _app.menu.page
	navigation_dialog = _app._dialog.visible
	navigation_after = _held()
	navigation_equal = navigation_held == navigation_after
	_navigation.append({"label": "unchanged_saved", "present_before": back_present,
		"page": navigation_page, "dialog_visible": navigation_dialog,
		"held_before_sha256": navigation_held.hex_encode().sha256_text(),
		"held_after_sha256": navigation_after.hex_encode().sha256_text(),
		"held_equal": navigation_equal})
	_check(back_present and navigation_page == "career" and not navigation_dialog
		and navigation_equal, "unchanged staged Back returns without mutation")
	var mounted_intent: Dictionary = {"version": 15, "family": "staged-mixed-negative"}
	await _stage("mixed15_16", mounted_intent, ledger.revision(), 2)
	await _refuse("mixed15_16", mounted_intent, old_revision)
	var before_malformed: PackedByteArray = _held()
	for malformed: Dictionary in [{"version": 16}, {"family": StadiumPoolOwnedLayout.FAMILY},
		{"pool": null}]:
		await _stage("malformed_pool_intent", malformed, ledger.revision(), 3)
	_check(before_malformed == _held() and var_to_bytes(_app.season.home_property) == _frozen_home,
		"staged cases leave the frozen supported home exact")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(_app.season)), "staged save restores the ordinary normalized snapshot")


func _stage(label: String, draft: Dictionary, revision: int, count: int) -> void:
	var held: PackedByteArray = _held()
	StadiumEditorUI.show(_app.menu, draft, revision)
	await _frames()
	var cards: Array[Node] = _cards()
	_check(cards.size() == count, label + " exact requested saved active cards")
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var expected: Array = []
	for entry: Array in [["REQUESTED DRAFT", draft], ["SAVED DRAFT", ledger.view().stadium_draft],
		["ACTIVE LAYOUT", ledger.view().stadium_active]]:
		if StadiumPoolWorkshopUI.pool_intent(entry[1]):
			expected.append([entry[0], StadiumPoolWorkshopUI.inspect(entry[1], ledger.construction(),
				ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
				revision, ledger.revision())])
	var exact: bool = cards.size() == expected.size()
	for index: int in range(mini(cards.size(), expected.size())):
		exact = exact and _text(cards[index]).contains(expected[index][0] + " • OWNED POOL") \
			and var_to_bytes(cards[index].get_meta("pool_status", {})) == var_to_bytes(expected[index][1])
	_check(exact, label + " exact slot headings and full validation status")
	_check(_preview(_app) == null
		and _app.menu.find_children("*", "SubViewport", true, false).is_empty(),
		label + " closed exposure gate allocates no preview")
	_check(_button(_app.menu, "SAVE DRAFT") == null
		and _button(_app.menu, "APPLY LAYOUT") == null
		and _app.menu.find_children("*", "OptionButton", true, false).is_empty(),
		label + " save apply placement controls absent")
	_check(_button(_app.menu, "RELOAD SAVED") != null
		and _button(_app.menu, "CLUB RECORD") != null
		and _text(_app.menu).contains(StadiumPoolWorkshopUI.NOTICE), label + " read-only navigation")
	_check(held == _held(), label + " exact held state preservation")
	var statuses: Array = []
	for card: Node in cards:
		statuses.append(_json_status(card.get_meta("pool_status", {})))
	_stages.append({"label": label, "cards": cards.size(), "statuses": statuses,
		"held_sha256": held.hex_encode().sha256_text(), "preserved": held == _held()})


func _refuse(label: String, draft: Dictionary, revision: int) -> void:
	for action: String in ["_save", "_apply", "_apply_now", "_buy"]:
		var held: PackedByteArray = _held()
		if action == "_buy":
			StadiumEditorUI._buy(_app.menu, "ST-006", revision)
		elif action == "_save":
			StadiumEditorUI._save(_app.menu, draft, revision)
		elif action == "_apply":
			StadiumEditorUI._apply(_app.menu, draft, revision)
		else:
			StadiumEditorUI._apply_now(_app.menu, draft, revision)
		await _frames()
		_check(held == _held(), label + action + " refuses and preserves every held byte")
		_check(not _app._dialog.visible and _app.notice == StadiumPoolWorkshopUI.NOTICE,
			label + action + " cannot open apply confirmation or report success")
		_refusals.append({"label": label, "action": action, "revision": revision,
			"preserved": held == _held(), "dialog_visible": _app._dialog.visible,
			"notice": _app.notice})


func _preview_matrix() -> void:
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var held: PackedByteArray = _held()
	for layout: Dictionary in [_layout, _moved]:
		var previous: WeakRef = weakref(preview.pool_model) if preview.pool_model != null else null
		var status: Dictionary = preview.build_pool_readonly(layout, ledger.construction(),
			ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
			ledger.revision(), ledger.revision())
		await _frames()
		if not _check(status.ok and _status_matches(status, layout, ledger),
			"preview returns exact paid copy pose surface capacity and stock"):
			preview.free()
			return
		_check(previous == null or previous.get_ref() == null, "reopening frees the previous model")
		_check(preview.pool_model != null
			and preview.pool_model.transform == StadiumPoolOwnedLayout.pose(layout)
			and preview.preview_property.objects.get(_pool_copy) == preview.pool_model
			and preview.positions.get(_pool_copy) == status.position
			and preview.items.get(_pool_copy) == "ST-006",
			"preview maps actual owned identity and rigid pose")
		var viewport: SubViewport = preview.get_child(0) as SubViewport
		_check(viewport != null and viewport.own_world_3d
			and viewport.find_world_3d() != get_viewport().find_world_3d(), "preview has a private World3D")
		var expected: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.SCENERY)
		var model_bytes: PackedByteArray = _tree_bytes(preview.pool_model, null, true)
		var expected_bytes: PackedByteArray = _tree_bytes(expected, null, true)
		_check(_tree_ok and not model_bytes.is_empty() and model_bytes == expected_bytes,
			"actual preview retains original scenery topology geometry materials and static collision")
		expected.free()
		_check(preview.pool_model.get_meta("placement_role", "") == StadiumPoolContract.SCENERY
			and not preview.pool_model.find_children("*", "StaticBody3D", true, false).is_empty()
			and preview.pool_model.find_children("*", "Area3D", true, false).is_empty()
			and preview.pool_model.find_children("*", "RigidBody3D", true, false).is_empty(),
			"scenery retains static collision without live water or actors")
		var base: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		add_child(base)
		var built: bool = base.build(ledger.view().land, StadiumPoolOwnedLayout.base(layout),
			ledger.construction())
		var old_wall: Node = base.get_node_or_null("TemplateBackWall")
		var boundary: Node3D = StadiumBoundaryRuntime.assemble(base) if built else null
		if is_instance_valid(old_wall) and old_wall.get_parent() == null:
			old_wall.free()
		var base_bytes: PackedByteArray = _tree_bytes(base)
		var actual_base: PackedByteArray = _tree_bytes(preview.preview_property, preview.pool_model)
		_check(built and boundary != null
			and preview.preview_property.get_node_or_null("BoundaryGraph") != null
			and _tree_ok and base_bytes == actual_base,
			"preview base surface receiver and complete boundary match original factories")
		base.free()
		_check(held == _held() and _app.lab == null, "read-only preview preserves every held byte")
		_previews.append({"status": _json_status(status),
			"model_sha256": model_bytes.hex_encode().sha256_text(),
			"base_sha256": base_bytes.hex_encode().sha256_text(), "model_bytes": model_bytes.size(),
			"base_bytes": base_bytes.size(), "preserved": held == _held()})
	var old_model: WeakRef = weakref(preview.pool_model)
	for label: String in ["missing_stock", "missing_pieces", "missing_boards",
		"unpaid", "missing_copy",
		"stale", "unsupported_tier", "unsupported_base", "nonfinite", "non_grid", "noncanonical_yaw",
		"malformed"]:
		var layout: Dictionary = _layout.duplicate(true)
		var stock: StadiumStock = ledger.construction()
		var pieces: StadiumWallPieceOwnership = ledger.wall_pieces()
		var boards: StadiumScoreboardOwnership = ledger.scoreboards()
		var tier: String = ledger.view().land
		var revision: int = ledger.revision()
		match label:
			"missing_stock": stock = null
			"missing_pieces": pieces = null
			"missing_boards": boards = null
			"unpaid": stock.copies[_pool_copy].paid = 0
			"missing_copy": stock.copies.erase(_pool_copy)
			"stale": revision -= 1
			"unsupported_tier": tier = "unknown"
			"unsupported_base": layout.version = 15
			"nonfinite": layout.pool.position[0] = INF
			"non_grid": layout.pool.position[0] = 12.25
			"noncanonical_yaw": layout.pool.yaw = 360
			"malformed": layout = {"version": 16}
		var expected: Dictionary = StadiumPoolWorkshopUI.inspect(layout, stock, pieces, boards,
			ledger.surface_owned(), tier, revision, ledger.revision())
		var rejected: Dictionary = preview.build_pool_readonly(layout, stock, pieces, boards,
			ledger.surface_owned(), tier, revision, ledger.revision())
		_check(not expected.ok and rejected == expected and not rejected.error.is_empty(),
			label + " exact validation refusal is reported")
		_check(preview.get_child_count() == 0 and preview.pool_model == null
			and preview.preview_property == null and preview.positions.is_empty()
			and old_model.get_ref() == null, label + " invalid reopen clears old world without allocation")
		_check(held == _held(), label + " preserves all genuine held bytes")
		_negatives.append({"label": label, "error": rejected.error,
			"children": preview.get_child_count(), "preserved": held == _held()})
	preview.build_pool_readonly(_layout, ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(),
		ledger.surface_owned(), ledger.view().land, ledger.revision(), ledger.revision())
	_check(preview.pool_model != null, "valid reopening works after rejected contexts")
	old_model = weakref(preview.pool_model)
	preview.build(_layout, ledger.construction(), true, ledger.view().land,
		ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned())
	_check(preview.get_child_count() == 0 and preview.pool_model == null
		and old_model.get_ref() == null and not preview.pool_preview_status.ok,
		"generic v16 build fails closed instead of showing the ordinary field")
	var reference: WeakRef = weakref(preview)
	preview.free()
	_check(reference.get_ref() == null and held == _held(),
		"dedicated preview cleanup preserves all held bytes")


func _status_matches(status: Dictionary, layout: Dictionary, ledger: ClubAssetLedger) -> bool:
	var checked: Dictionary = StadiumPoolOwnedLayout.validate(layout, ledger.construction(),
		ledger.surface_owned(), ledger.view().land)
	return status.copy == _pool_copy \
		and status.position == StadiumPoolOwnedLayout.pose(layout).origin \
		and status.yaw == layout.pool.yaw and status.surface == layout.surface \
		and status.live_units == 4 \
		and status.paid == ledger.construction().copies[_pool_copy].paid \
		and status.stored == checked.stored


func _json_status(status: Dictionary) -> Dictionary:
	var result: Dictionary = status.duplicate(true)
	if result.get("position") is Vector3:
		var point: Vector3 = result.position
		result.position = [point.x, point.y, point.z]
	return result


func _tree_bytes(root: Node, excluded: Node = null,
	ignore_root_pose: bool = false) -> PackedByteArray:
	var rows: Array = []
	_tree_rows(root, root, excluded, ignore_root_pose, rows)
	var result: PackedByteArray = var_to_bytes(rows)
	_tree_ok = _tree_ok and result.size() <= TREE_BYTES_CAP
	return result


func _tree_rows(node: Node, root: Node, excluded: Node,
	ignore_root_pose: bool, rows: Array) -> void:
	if node == excluded:
		return
	if rows.size() >= TREE_CAP:
		_tree_ok = false
		return
	var row: Array = [node.get_class(), "" if node == root or String(node.name).begins_with("@")
		else String(node.name), node.get_child_count()
		- (1 if excluded != null and excluded.get_parent() == node else 0)]
	if node is Node3D:
		row.append(Transform3D.IDENTITY if node == root and ignore_root_pose else node.transform)
	var metadata: Array = []
	for key: StringName in node.get_meta_list():
		metadata.append([key, node.get_meta(key)])
	row.append(metadata)
	if node is MeshInstance3D:
		row.append(node.visible)
		row.append(node.mesh.get_faces() if node.mesh != null else PackedVector3Array())
		row.append(node.mesh.get_aabb() if node.mesh != null else AABB())
		var material: Material = node.material_override
		row.append([material.get_class(), material.albedo_color, material.roughness,
			material.metallic, material.transparency, material.cull_mode]
			if material is StandardMaterial3D else ["none"])
	if node is CollisionObject3D:
		row.append([node.collision_layer, node.collision_mask])
	if node is CollisionShape3D:
		var shape: Shape3D = node.shape
		row.append([node.disabled, shape.get_class(), shape.margin] if shape != null else [])
		if shape is ConcavePolygonShape3D:
			row.append([shape.get_faces(), shape.backface_collision])
		elif shape is ConvexPolygonShape3D:
			row.append(shape.points)
		elif shape is BoxShape3D:
			row.append(shape.size)
		elif shape is CylinderShape3D:
			row.append([shape.height, shape.radius])
	rows.append(row)
	for child: Node in node.get_children():
		_tree_rows(child, root, excluded, ignore_root_pose, rows)


func _held() -> PackedByteArray:
	var files: Array = []
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".tmp", ".bak"]:
			files.append([path.get_file() + suffix, FileAccess.file_exists(path + suffix),
				FileAccess.get_file_as_bytes(path + suffix) if FileAccess.file_exists(path + suffix)
				else PackedByteArray()])
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	return var_to_bytes([SeasonSave.snapshot(_app.season), _app.season.career.to_data(),
		ledger.to_data(), ledger.construction().to_data(), _app.season.home_property, files])


func _cards() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in _app.menu.find_children("*", "", true, false):
		if node.get_meta("pool_readonly", false):
			result.append(node)
	return result


func _choice(copy: String) -> OptionButton:
	for node: Node in _app.menu.find_children("*", "OptionButton", true, false):
		if node.get_meta("stadium_copy", "") == copy:
			return node
	return null


func _text(root: Node) -> String:
	var result: String = ""
	for node: Node in root.find_children("*", "Label", true, false):
		result += node.text + "\n"
	return result


func _identity() -> Dictionary:
	return {"version": 1, "pid": OS.get_process_id(), "runtime": _runtime,
		"execution": _execution, "nonce": _nonce}


func _group(label: String, first: int) -> void:
	_groups.append({"label": label, "checks": _checks - first})


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		_failed.append(label)
		push_error(label)
	return condition


func _hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for index: int in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


func _write(name: String, value: Dictionary, cap: int) -> bool:
	if not _admitted:
		return false
	var encoded: String = JSON.stringify(value, "", true, true)
	if encoded.to_utf8_buffer().size() > cap:
		push_error("UI fixture artifact cap exceeded: " + name)
		_failures += 1
		return false
	var file: FileAccess = FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if file == null:
		push_error("UI fixture artifact cannot be written: " + name)
		_failures += 1
		return false
	file.store_string(encoded)
	file.close()
	return true


func _owned_receiver_draft(base: Dictionary, copies: Dictionary) -> Dictionary:
	if not base.has("receiver") or not base.receiver is String \
		or not base.has("obstacles") or not base.obstacles is Array \
		or not base.obstacles.is_empty():
		return {}
	var selected: String = base.receiver
	if not selected.is_empty():
		if not copies.has(selected) or copies[selected].item != "ST-079":
			return {}
	else:
		for id: String in copies:
			if copies[id].item == "ST-079":
				if not selected.is_empty():
					return {}
				selected = id
	if selected.is_empty():
		return {}
	var draft: Dictionary = base.duplicate(true)
	draft.receiver = selected
	return draft


func _place_owned_receiver() -> bool:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var before: Dictionary = SeasonSave.snapshot(_app.season)
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(SeasonSave.path)
	var balance: int = _app.season.career.balance()
	var draft: Dictionary = _owned_receiver_draft(ledger.view().stadium_active,
		ledger.construction().copies)
	if not _check(not draft.is_empty()
		and ClubCareer.same(before, SeasonSave.snapshot(_app.season))
		and saved == FileAccess.get_file_as_bytes(SeasonSave.path),
		"select actual owned ST-079 receiver without live or saved mutation"):
		return false
	var drafted: Dictionary = ClubConstruction.save_draft(_app.season, draft, ledger.revision())
	if not _check(drafted.get("ok", false) and _app.season.career.balance() == balance,
		"ordinary receiver draft transaction: " + str(drafted.get("error", ""))):
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	var applied: Dictionary = ClubConstruction.apply_draft(_app.season, draft, ledger.revision())
	ledger = ClubPlayers.assets(_app.season.career)
	if not _check(applied.get("ok", false) and _app.season.career.balance() == balance
		and ClubCareer.same(ledger.view().stadium_active, draft)
		and _app.season.home_property.layout.receiver == draft.receiver
		and StadiumLayoutSnapshot.matches(_app.season.home_property, ledger),
		"ordinary receiver apply freezes owned snapshot: " + str(applied.get("error", ""))):
		return false
	return true


func _button(parent: Node, text: String, prefix: bool = false) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if (
			node.is_visible_in_tree()
			and (node.text.begins_with(text) if prefix else node.text == text)
		):
			return node
	return null


func _frames(count: int = 3) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _preview(app: SeasonApp) -> StadiumDraftPreview:
	for node: Node in app.menu._body.get_children():
		if node is StadiumDraftPreview:
			return node
	return null


func _placement_matrix() -> void:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var held: PackedByteArray = _held()
	var original: PackedByteArray = var_to_bytes(_layout)
	var opened: Dictionary = StadiumPoolWorkshopUI.show_placement_preview(_app.menu,
		_layout, ledger.revision())
	await _frames()
	var card: VBoxContainer = _placement_card()
	if not _check(opened.ok and card != null,
		"placement production builder opens accepted paid draft"):
		return
	var x: SpinBox = card.get_node("PoolPositionX")
	var z: SpinBox = card.get_node("PoolPositionZ")
	var yaw: OptionButton = card.get_node("PoolYaw")
	_check(x.min_value == -64.0 and x.max_value == 64.0 and x.step == 0.5
		and z.min_value == -64.0 and z.max_value == 64.0 and z.step == 0.5
		and x.value == 12.0 and z.value == 18.0 and yaw.selected == 0
		and yaw.item_count == 4 and yaw.get_item_text(0) == "0°"
		and yaw.get_item_text(1) == "90°" and yaw.get_item_text(2) == "180°"
		and yaw.get_item_text(3) == "270°",
		"placement controls expose half-meter and quarter-turn inputs")
	_check(_text(_app.menu).contains(StadiumPoolWorkshopUI.PLACEMENT_NOTICE)
		and _text(card).contains("Paid %d CB" % ledger.construction().copies[_pool_copy].paid)
		and _text(card).contains(_pool_copy)
		and _button(_app.menu, "SAVE DRAFT") == null and _button(_app.menu, "APPLY LAYOUT") == null
		and _button(_app.menu, "ST-006", true) == null,
		"placement preview reports paid identity and keeps transactional controls absent")
	_check(held == _held() and original == var_to_bytes(_layout)
		and card.get_meta("pool_placement_draft") == _layout,
		"placement opening clones requested draft and preserves all held bytes")
	for pose: Vector3 in [Vector3(12.5, 18, 90), Vector3(-12, 18, 180),
		Vector3(-12, 18, 270), Vector3(12, 18, 0)]:
		await _placement_attempt(Vector2(pose.x, pose.y), int(pose.z / 90), true)
	await _placement_attempt(Vector2(64, 64), 0, false)
	await _placement_attempt(Vector2.ZERO, 0, false)
	await _placement_attempt(Vector2(12, 18), -1, false)
	await _placement_attempt(Vector2(12, 18), 0, true)
	card = _placement_card()
	var preview: StadiumDraftPreview = _preview(_app)
	var accepted: PackedByteArray = var_to_bytes(card.get_meta("pool_placement_draft"))
	var model: WeakRef = weakref(preview.pool_model)
	var field: Button = _button(_app.menu, "FIELD VIEW")
	var field_present: bool = field != null and not field.disabled
	if field_present:
		field.pressed.emit()
	await _frames()
	_check(field_present and _preview(_app) == preview
		and preview.camera.projection == Camera3D.PROJECTION_ORTHOGONAL
		and preview.pool_model == model.get_ref() and held == _held(),
		"Field View follows current accepted world after repeated replacement")
	# Metadata is not a source of accepted copy, pose, revision or navigation state.
	var tampered: Dictionary = card.get_meta("pool_placement_draft")
	tampered.pool.copy = "not-an-owned-copy"
	tampered.pool.position = [64, 64]
	card.set_meta("pool_placement_revision", ledger.revision() - 1)
	card.set_meta("pool_placement_preview", null)
	var update: Button = _button(card, "UPDATE PREVIEW")
	var update_present: bool = update != null and not update.disabled
	if update_present:
		update.pressed.emit()
	await _frames()
	preview = _preview(_app)
	model = weakref(preview.pool_model)
	_check(update_present and accepted == var_to_bytes(card.get_meta("pool_placement_draft"))
		and card.get_meta("pool_placement_revision") == ledger.revision()
		and preview.pool_model.transform == StadiumPoolOwnedLayout.pose(_layout)
		and preview.positions.has(_pool_copy) and held == _held(),
		"forged diagnostic copy pose revision and preview never override the accepted session")
	card.set_meta("pool_placement_draft", _supported.duplicate(true))
	var back: Button = _button(_app.menu, "CLUB RECORD")
	var back_present: bool = back != null and not back.disabled
	if back_present:
		back.pressed.emit()
	await _frames()
	_check(back_present and _app._dialog.visible and _app.menu.page == "stadium"
		and _app._dialog.dialog_text.contains("Unsaved stadium draft changes"),
		"placement Club Record uses the real unsaved-discard dialog")
	card.set_meta("pool_placement_draft", _layout.duplicate(true))
	_app._dialog.get_cancel_button().pressed.emit()
	await _frames()
	_check(not _app._dialog.visible and _app.menu.page == "stadium"
		and card == _placement_card() and preview.pool_model == model.get_ref()
		and accepted == var_to_bytes(card.get_meta("pool_placement_draft")) and held == _held(),
		"real Cancel retains accepted draft model and every held byte")
	back = _button(_app.menu, "CLUB RECORD")
	back_present = back != null and not back.disabled
	if back_present:
		back.pressed.emit()
	await _frames()
	_check(back_present and _app._dialog.visible, "repeated placement Back asks again")
	_app._dialog.get_ok_button().pressed.emit()
	await _frames()
	_check(_app.menu.page == "career" and not _app._dialog.visible
		and model.get_ref() == null and held == _held(),
		"real discard confirmation returns to Club Record and frees private world")
	opened = StadiumPoolWorkshopUI.show_placement_preview(_app.menu, _moved, ledger.revision())
	await _frames()
	card = _placement_card()
	if not _check(opened.ok and card != null, "moved placement reopens beside old saved layout"):
		return
	preview = _preview(_app)
	model = weakref(preview.pool_model)
	var reload_button: Button = _button(_app.menu, "RELOAD SAVED")
	var reload_present: bool = reload_button != null and not reload_button.disabled
	if reload_present:
		reload_button.pressed.emit()
	await _frames()
	var old_preview: StadiumDraftPreview = _preview(_app)
	_check(reload_present and model.get_ref() == null and _placement_card() == null
		and old_preview != null and old_preview.pool_model == null
		and _choice(_supported.receiver) != null and _button(_app.menu, "SAVE DRAFT") != null
		and _button(_app.menu, "APPLY LAYOUT") != null and held == _held(),
		"real placement Reload restores the ordinary old-layout workshop without mutation")
	_check(original == var_to_bytes(_layout)
		and var_to_bytes(_app.season.home_property) == _frozen_home,
		"placement controls never mutate source layout or frozen supported home")


func _placement_attempt(position: Vector2, yaw_index: int, legal: bool) -> void:
	var card: VBoxContainer = _placement_card()
	var update: Button = _button(card, "UPDATE PREVIEW") if card != null else null
	var present: bool = update != null and not update.disabled
	if not _check(card != null and present, "actual placement Update Preview button is enabled"):
		return
	var before: Dictionary = card.get_meta("pool_placement_draft")
	var draft_bytes: PackedByteArray = var_to_bytes(before)
	var previous: StadiumDraftPreview = _preview(_app)
	var previous_ref: WeakRef = weakref(previous)
	var model_ref: WeakRef = weakref(previous.pool_model)
	var tree_bytes: PackedByteArray = _tree_bytes(previous.pool_model)
	var held: PackedByteArray = _held()
	var x: SpinBox = card.get_node("PoolPositionX")
	var z: SpinBox = card.get_node("PoolPositionZ")
	var yaw: OptionButton = card.get_node("PoolYaw")
	x.value = position.x
	z.value = position.y
	yaw.select(yaw_index)
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var expected: Dictionary = StadiumPoolOwnedLayout.relocated(before, ledger.construction(),
		ledger.surface_owned(), ledger.view().land, position, yaw_index * 90)
	_check(not expected.is_empty() if legal else expected.is_empty(),
		"fixed placement attempt agrees with unchanged owned-layout validator")
	update.pressed.emit()
	await _frames()
	var accepted: Dictionary = card.get_meta("pool_placement_draft")
	var current: StadiumDraftPreview = _preview(_app)
	_check(accepted == expected if legal else var_to_bytes(accepted) == draft_bytes,
		"legal attempt changes only accepted UI draft; invalid attempt preserves exact draft")
	_check((previous_ref.get_ref() == null and model_ref.get_ref() == null
		and current.pool_model.transform == StadiumPoolOwnedLayout.pose(expected)) if legal else (
		previous_ref.get_ref() == current and model_ref.get_ref() == current.pool_model
		and tree_bytes == _tree_bytes(current.pool_model)),
		"prospective replacement frees old world; invalid attempt retains exact current model")
	_check(_text(card).contains("Last valid preview:") if legal else (
		_text(card).contains("Invalid placement:") and _text(card).contains("Last valid preview kept.")),
		"placement feedback clearly distinguishes accepted and refused pose")
	_check(held == _held() and _app.menu.find_children("*", "SubViewport", true, false).size() == 1,
		"placement attempt has one private world and preserves every held byte")
	_placements.append({"position": [position.x, position.y], "yaw": yaw_index * 90,
		"legal": legal, "draft_before_sha256": draft_bytes.hex_encode().sha256_text(),
		"draft_after_sha256": var_to_bytes(accepted).hex_encode().sha256_text(),
		"feedback": (card.get_node("PoolPlacementFeedback") as Label).text,
		"held_sha256": held.hex_encode().sha256_text(), "preserved": held == _held()})


func _placement_card() -> VBoxContainer:
	for node: Node in _app.menu._body.find_children("*", "VBoxContainer", true, false):
		if node.has_meta("pool_placement_draft"):
			return node
	return null


func _placement_stale_open(revision: int) -> void:
	var first: int = _checks
	var opened: Dictionary = StadiumPoolWorkshopUI.show_placement_preview(_app.menu,
		_layout, revision, true)
	await _frames()
	_check(opened.ok and _placement_card() != null and _preview(_app) != null,
		"real placement session opens before the existing saved-draft transaction")
	_placement_checks += _checks - first


func _placement_stale_check(old_revision: int) -> void:
	var first: int = _checks
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var held: PackedByteArray = _held()
	var card: VBoxContainer = _placement_card()
	var preview: StadiumDraftPreview = _preview(_app)
	if not _check(card != null and preview != null and ledger.revision() != old_revision,
		"existing genuine save advances revision beneath the open placement session"):
		_placement_checks += _checks - first
		return
	var model: WeakRef = weakref(preview.pool_model)
	var model_bytes: PackedByteArray = _tree_bytes(preview.pool_model)
	var accepted: PackedByteArray = var_to_bytes(card.get_meta("pool_placement_draft"))
	# These are deliberately untrusted diagnostics, not the callback-bound session.
	card.set_meta("pool_placement_revision", ledger.revision())
	card.set_meta("pool_placement_draft", _moved.duplicate(true))
	card.set_meta("pool_placement_preview", null)
	var x: SpinBox = card.get_node("PoolPositionX")
	x.value = -12.0
	var update: Button = _button(card, "UPDATE PREVIEW")
	var update_present: bool = update != null and not update.disabled
	if update_present:
		update.pressed.emit()
	await _frames()
	var feedback: String = (card.get_node("PoolPlacementFeedback") as Label).text
	_check(update_present and feedback.contains(StadiumPoolWorkshopUI.STALE)
		and card.get_meta("pool_placement_revision") == old_revision,
		"mutable diagnostic revision cannot freshen a stale callback-bound session")
	_check(accepted == var_to_bytes(card.get_meta("pool_placement_draft"))
		and model.get_ref() == preview.pool_model and model_bytes == _tree_bytes(preview.pool_model),
		"stale metadata-tampered update retains exact accepted draft and original model")
	_check(held == _held() and _app.menu.find_children("*", "SubViewport", true, false).size() == 1,
		"stale update creates no prospective world and changes no held byte")
	var store: Button = _button(card, "STORE IN PREVIEW")
	var store_present: bool = store != null and not store.disabled
	if store_present:
		store.pressed.emit()
	await _frames()
	_check(store_present and _app.notice == StadiumPoolWorkshopUI.STALE
		and (card.get_node("PoolPlacementFeedback") as Label).text.contains(StadiumPoolWorkshopUI.STALE)
		and _placement_card() == card and _inventory_card() == null,
		"stale inventory-origin Store refuses visibly without replacing placement screen")
	_check(held == _held() and model.get_ref() == preview.pool_model
		and model_bytes == _tree_bytes(preview.pool_model)
		and accepted == var_to_bytes(card.get_meta("pool_placement_draft")),
		"stale Store retains accepted pose model and all held bytes after metadata tampering")
	var callbacks: Array[Callable] = _placement_callbacks(card)
	var reload_button: Button = _button(_app.menu, "RELOAD SAVED")
	var reload_present: bool = reload_button != null and not reload_button.disabled
	if reload_present:
		reload_button.pressed.emit()
	var current_body: VBoxContainer = _app.menu._body
	for callback: Callable in callbacks:
		callback.call()
	_check(callbacks.size() == 3 and _app.menu._body == current_body
		and not _app._dialog.visible and held == _held(),
		"callbacks from the detached old panel cannot act on the reloaded screen")
	await _frames()
	_check(reload_present and model.get_ref() == null and _placement_card() == null
		and _preview(_app) == null and _text(_app.menu).contains(StadiumPoolWorkshopUI.NOTICE)
		and held == _held(), "real stale Reload returns saved Pool to closed public staging")
	for callback: Callable in callbacks:
		callback.call()
	await _frames()
	_check(_app.menu._body == current_body and not _app._dialog.visible
		and _preview(_app) == null and held == _held(),
		"callbacks with freed old controls are inert and cannot reach a replacement world")
	var refused: Dictionary = StadiumPoolWorkshopUI.show_placement_preview(_app.menu,
		_layout, old_revision)
	_check(not refused.ok and refused.error == StadiumPoolWorkshopUI.STALE
		and _app.menu._body == current_body and held == _held(),
		"stale direct preview opening refuses before replacing current screen")
	var opened: Dictionary = StadiumPoolWorkshopUI.show_placement_preview(_app.menu,
		_layout, ledger.revision())
	await _frames()
	card = _placement_card()
	if not _check(opened.ok and card != null, "saved Pool opens through dedicated builder only"):
		_placement_checks += _checks - first
		return
	preview = _preview(_app)
	model = weakref(preview.pool_model)
	# A forged changed diagnostic must not cause an unsaved dialog for this unchanged session.
	card.set_meta("pool_placement_draft", _moved.duplicate(true))
	var saved_callbacks: Array[Callable] = _placement_callbacks(card)
	var back: Button = _button(_app.menu, "CLUB RECORD")
	var back_present: bool = back != null and not back.disabled
	if back_present:
		back.pressed.emit()
	for callback: Callable in saved_callbacks:
		callback.call()
	await _frames()
	_check(back_present and _app.menu.page == "career" and not _app._dialog.visible
		and model.get_ref() == null and held == _held(),
		"unchanged saved Back ignores forged draft and old callbacks cannot act on Club Record")
	_placement_stale = {"original_revision": old_revision, "current_revision": ledger.revision(),
		"feedback": feedback, "accepted_draft_sha256": accepted.hex_encode().sha256_text(),
		"held_sha256": held.hex_encode().sha256_text(), "preserved": held == _held(),
		"detached_callbacks": callbacks.size(), "freed_callbacks": callbacks.size(),
		"unchanged_saved_back": _app.menu.page == "career" and not _app._dialog.visible}
	_placement_checks += _checks - first


func _placement_callbacks(card: VBoxContainer) -> Array[Callable]:
	var callbacks: Array[Callable] = []
	for button: Button in [_button(card, "UPDATE PREVIEW"), _button(_app.menu, "FIELD VIEW"),
		_button(_app.menu, "CLUB RECORD")]:
		if button != null:
			for connection: Dictionary in button.get_signal_connection_list("pressed"):
				callbacks.append(connection.callable)
	return callbacks


func _inventory_matrix() -> void:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var held: PackedByteArray = _held()
	var source: PackedByteArray = var_to_bytes(_supported)
	var valid: Dictionary = StadiumPoolWorkshopUI.inventory_candidate(_supported,
		ledger.construction(), ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned(),
		ledger.view().land, ledger.revision(), ledger.revision(), _pool_copy)
	_check(valid.ok and valid.layout == _layout and valid.copy == _pool_copy,
		"inventory candidate uses genuine paid copy and unchanged owned-layout upgrade")
	_check(source == var_to_bytes(_supported) and held == _held(),
		"inventory candidate preserves source wallet journal save active and frozen season")
	_inventory_candidates(ledger)
	await _inventory_refusals(ledger)
	await _inventory_cycle(ledger)
	await _inventory_navigation(ledger)
	await _inventory_stale(ledger)
	_check(source == var_to_bytes(_supported)
		and var_to_bytes(_app.season.home_property) == _frozen_home,
		"all inventory cases retain original supported layout and frozen home")
	_inventory["candidate_cases"] = 20
	_inventory["direct_refusal_cases"] = 8
	_inventory["original_source_sha256"] = source.hex_encode().sha256_text()
	_inventory["frozen_home_sha256"] = _frozen_home.hex_encode().sha256_text()


func _inventory_candidates(ledger: ClubAssetLedger) -> void:
	var held: PackedByteArray = _held()
	for label: String in ["missing_stock", "missing_pieces", "missing_piece_stock",
		"missing_boards", "unpaid", "missing_copy", "wrong_copy", "empty_copy", "stale",
		"negative_revision", "excess_revision", "unsupported_tier", "unsupported_base",
		"malformed", "pool_already_placed", "conflicting_live", "nonfinite", "non_grid",
		"noncanonical_yaw", "blocked_pose"]:
		var draft: Dictionary = _supported.duplicate(true)
		var stock: StadiumStock = ledger.construction()
		var pieces: StadiumWallPieceOwnership = ledger.wall_pieces()
		var boards: StadiumScoreboardOwnership = ledger.scoreboards()
		var copy: String = _pool_copy
		var tier: String = ledger.view().land
		var revision: int = ledger.revision()
		var current_revision: int = ledger.revision()
		var position: Vector2 = Vector2(12, 18)
		var yaw: int = 0
		match label:
			"missing_stock": stock = null
			"missing_pieces": pieces = null
			"missing_piece_stock": pieces.stock = null
			"missing_boards": boards = null
			"unpaid": stock.copies[_pool_copy].paid = 0
			"missing_copy": stock.copies.erase(_pool_copy)
			"wrong_copy": copy = _supported.receiver
			"empty_copy": copy = ""
			"stale": revision -= 1
			"negative_revision": revision = -1
			"excess_revision":
				revision = ClubAssetLedger.MAX_EVENTS + 1
				current_revision = revision
			"unsupported_tier": tier = "unknown"
			"unsupported_base": draft.version = 15
			"malformed": draft = {"version": 12}
			"pool_already_placed": draft = _layout.duplicate(true)
			"conflicting_live":
				draft.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
			"nonfinite": position.x = INF
			"non_grid": position.x = 12.25
			"noncanonical_yaw": yaw = 360
			"blocked_pose": position = Vector2.ZERO
		var before: PackedByteArray = var_to_bytes(draft)
		var result: Dictionary = StadiumPoolWorkshopUI.inventory_candidate(draft, stock,
			pieces, boards, ledger.surface_owned(), tier, revision, current_revision, copy,
			position, yaw)
		_check(not result.ok and not result.error.is_empty() and not result.has("layout"),
			label + " inventory candidate refuses without a fabricated layout")
		_check(before == var_to_bytes(draft), label + " inventory refusal preserves source draft")
		_check(held == _held(), label + " inventory refusal preserves every genuine held byte")


func _inventory_refusals(ledger: ClubAssetLedger) -> void:
	var held: PackedByteArray = _held()
	var body: VBoxContainer = _app.menu._body
	var preview: StadiumDraftPreview = _preview(_app)
	var children: int = _app.menu.find_children("*", "SubViewport", true, false).size()
	for label: String in ["stale", "missing_copy", "wrong_copy", "unsupported_base",
		"malformed", "pool_already_placed", "conflicting_live", "blocked_pose"]:
		var draft: Dictionary = _supported.duplicate(true)
		var revision: int = ledger.revision()
		var copy: String = _pool_copy
		var position: Vector2 = Vector2(12, 18)
		match label:
			"stale": revision -= 1
			"missing_copy": copy = "missing-paid-pool-copy"
			"wrong_copy": copy = _supported.receiver
			"unsupported_base": draft.version = 15
			"malformed": draft = {"version": 12}
			"pool_already_placed": draft = _layout.duplicate(true)
			"conflicting_live":
				draft.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
			"blocked_pose": position = Vector2.ZERO
		var result: Dictionary = StadiumPoolWorkshopUI.show_inventory_preview(_app.menu,
			draft, revision, copy, position)
		await _frames()
		_check(not result.ok and not result.error.is_empty() and _app.menu._body == body
			and _preview(_app) == preview and _inventory_card() == null,
			label + " direct inventory opening preserves current accepted screen")
		_check(held == _held() and children == _app.menu.find_children(
			"*", "SubViewport", true, false).size(),
			label + " direct inventory refusal allocates no world and preserves held bytes")


func _inventory_cycle(ledger: ClubAssetLedger) -> void:
	var held: PackedByteArray = _held()
	var source: Dictionary = _supported.duplicate(true)
	var opened: Dictionary = StadiumPoolWorkshopUI.show_inventory_preview(_app.menu,
		source, ledger.revision(), _pool_copy)
	await _frames()
	var card: VBoxContainer = _inventory_card()
	if not _check(opened.ok and card != null, "dedicated inventory opens genuine stored paid Pool"):
		return
	_check(_preview(_app) == null
		and _app.menu.find_children("*", "SubViewport", true, false).is_empty()
		and _text(card).contains("OWNED POOL • STORED IN PREVIEW")
		and _text(card).contains(_pool_copy)
		and _text(card).contains("Paid %d CB" % ledger.construction().copies[_pool_copy].paid),
		"inventory shows paid identity without allocating a scenery world")
	_check(_button(card, "PLACE IN PREVIEW") != null
		and _button(_app.menu, "SAVE DRAFT") == null and _button(_app.menu, "APPLY LAYOUT") == null
		and _button(_app.menu, "ST-006", true) == null and _choice(_pool_copy) == null
		and held == _held(), "inventory offers only isolated preview placement and navigation")
	var original: PackedByteArray = var_to_bytes(_supported)
	source.receiver = "forged-receiver"
	opened.layout.pool.copy = "forged-return-value"
	card.set_meta("pool_inventory_draft", {"version": 16})
	card.set_meta("pool_inventory_revision", ledger.revision() - 1)
	card.set_meta("pool_inventory_copy", "forged-diagnostic-copy")
	var old_callbacks: Array[Callable] = _inventory_callbacks(card)
	var place: Button = _button(card, "PLACE IN PREVIEW")
	if place != null:
		place.pressed.emit()
	await _frames()
	var placement: VBoxContainer = _placement_card()
	var preview: StadiumDraftPreview = _preview(_app)
	if not _check(placement != null and preview != null and preview.pool_model != null,
		"real inventory Place enters the existing placement builder"):
		return
	_check(placement.get_meta("pool_placement_draft") == _layout
		and preview.pool_model.transform == StadiumPoolOwnedLayout.pose(_layout)
		and preview.positions.has(_pool_copy) and held == _held()
		and original == var_to_bytes(_supported),
		"inventory callbacks ignore forged metadata and changed caller-owned dictionaries")
	var store: Button = _button(placement, "STORE IN PREVIEW")
	_check(store != null and not store.disabled
		and _button(_app.menu, "SAVE DRAFT") == null and _button(_app.menu, "APPLY LAYOUT") == null,
		"inventory placement exposes Store without transactional authority")
	for callback: Callable in old_callbacks:
		callback.call()
	_check(old_callbacks.size() == 2 and _placement_card() == placement
		and _preview(_app) == preview and not _app._dialog.visible and held == _held(),
		"freed inventory callbacks cannot place again or navigate the replacement screen")
	var first_model: WeakRef = weakref(preview.pool_model)
	(placement.get_node("PoolPositionX") as SpinBox).value = -12
	(placement.get_node("PoolYaw") as OptionButton).select(3)
	var update: Button = _button(placement, "UPDATE PREVIEW")
	if update != null:
		update.pressed.emit()
	await _frames()
	preview = _preview(_app)
	_check(update != null and placement.get_meta("pool_placement_draft") == _moved
		and first_model.get_ref() == null
		and preview.pool_model.transform == StadiumPoolOwnedLayout.pose(_moved)
		and held == _held(), "inventory-origin Move replaces only the accepted private scenery")
	var moved_model: WeakRef = weakref(preview.pool_model)
	var accepted: PackedByteArray = var_to_bytes(placement.get_meta("pool_placement_draft"))
	(placement.get_node("PoolPositionX") as SpinBox).value = 64
	(placement.get_node("PoolPositionZ") as SpinBox).value = 64
	if update != null:
		update.pressed.emit()
	await _frames()
	_check(accepted == var_to_bytes(placement.get_meta("pool_placement_draft"))
		and moved_model.get_ref() == preview.pool_model and held == _held(),
		"invalid inventory-origin Move preserves last accepted pose and original model")
	var store_callbacks: Array[Callable] = _pressed_callbacks(store)
	placement.set_meta("pool_placement_draft", _layout.duplicate(true))
	placement.set_meta("pool_placement_revision", ledger.revision() - 1)
	if store != null:
		store.pressed.emit()
	var stored_body: VBoxContainer = _app.menu._body
	for callback: Callable in store_callbacks:
		callback.call()
	_check(store_callbacks.size() == 1 and _app.menu._body == stored_body and held == _held(),
		"detached Store callback cannot act on the newly stored screen")
	await _frames()
	card = _inventory_card()
	var base: Dictionary = StadiumPoolOwnedLayout.base(_moved)
	if not _check(card != null and moved_model.get_ref() == null and _preview(_app) == null,
		"real Store releases placed world and returns to dedicated stored preview"):
		return
	_check(card.get_meta("pool_inventory_draft") == base
		and not base.has("pool") and base.surface == _moved.surface
		and card.get_meta("pool_inventory_copy") == _pool_copy
		and card.get_meta("pool_inventory_revision") == ledger.revision() and held == _held(),
		"Store extracts validated current base and preserves surface paid identity and revision")
	for callback: Callable in store_callbacks:
		callback.call()
	_check(_app.menu._body == stored_body and _preview(_app) == null and held == _held(),
		"freed Store callback stays inert on stored screen")
	old_callbacks = _inventory_callbacks(card)
	card.set_meta("pool_inventory_draft", _supported.duplicate(true))
	card.set_meta("pool_inventory_revision", -1)
	card.set_meta("pool_inventory_copy", "forged-replace-copy")
	place = _button(card, "PLACE IN PREVIEW")
	if place != null:
		place.pressed.emit()
	var placed_body: VBoxContainer = _app.menu._body
	for callback: Callable in old_callbacks:
		callback.call()
	_check(_app.menu._body == placed_body and not _app._dialog.visible and held == _held(),
		"detached stored callbacks cannot overwrite the re-placed session")
	await _frames()
	placement = _placement_card()
	preview = _preview(_app)
	if not _check(placement != null and preview != null and preview.pool_model != null,
		"real re-place rebuilds a private scenery world"):
		return
	_check(placement.get_meta("pool_placement_draft") == _moved
		and preview.pool_model.transform == StadiumPoolOwnedLayout.pose(_moved)
		and _button(placement, "STORE IN PREVIEW") != null and held == _held(),
		"re-place retains last valid moved pose despite forged inventory diagnostics")
	var replacement_model: WeakRef = weakref(preview.pool_model)
	store_callbacks = _pressed_callbacks(_button(placement, "STORE IN PREVIEW"))
	var reload_button: Button = _button(_app.menu, "RELOAD SAVED")
	var reload_present_before: bool = reload_button != null
	if reload_button != null:
		reload_button.pressed.emit()
	var reloaded_body: VBoxContainer = _app.menu._body
	for callback: Callable in store_callbacks:
		callback.call()
	await _frames()
	preview = _preview(_app)
	var reload_facts: Dictionary = {"label": "inventory_reload",
		"button_present_before": reload_present_before,
		"replacement_model_disposed": replacement_model.get_ref() == null,
		"inventory_absent": _inventory_card() == null,
		"placement_absent": _placement_card() == null,
		"preview_present": preview != null,
		"preview_pool_absent": preview != null and preview.pool_model == null,
		"body_is_reloaded": _app.menu._body == reloaded_body,
		"receiver_choice_present": _choice(_supported.receiver) != null,
		"held_equal": held == _held()}
	_inventory_navigation_facts.append(reload_facts)
	_check(reload_facts.button_present_before and reload_facts.replacement_model_disposed
		and reload_facts.inventory_absent and reload_facts.placement_absent
		and reload_facts.preview_present and reload_facts.preview_pool_absent
		and reload_facts.body_is_reloaded and reload_facts.receiver_choice_present
		and reload_facts.held_equal,
		"inventory-origin Reload restores ordinary saved workshop and old Store cannot act")
	_check(_button(_app.menu, "POOL INVENTORY PREVIEW") == null
		and _button(_app.menu, "PLACE IN PREVIEW") == null
		and _button(_app.menu, "STORE IN PREVIEW") == null
		and _button(_app.menu, "SAVE DRAFT") != null and _button(_app.menu, "APPLY LAYOUT") != null,
		"closed production gate keeps inventory entry hidden and ordinary editor unchanged")
	_inventory["cycle_held_sha256"] = held.hex_encode().sha256_text()
	_inventory["cycle_preserved"] = held == _held()
	_inventory["replaced_pose_sha256"] = accepted.hex_encode().sha256_text()
	_inventory["store_detached_callbacks"] = store_callbacks.size()


func _inventory_navigation(ledger: ClubAssetLedger) -> void:
	var held: PackedByteArray = _held()
	var opened: Dictionary = StadiumPoolWorkshopUI.show_inventory_preview(_app.menu,
		_supported, ledger.revision(), _pool_copy)
	await _frames()
	var card: VBoxContainer = _inventory_card()
	if not _check(opened.ok and card != null, "stored inventory reopens for unchanged Back"):
		return
	card.set_meta("pool_inventory_draft", {"version": 16})
	var back: Button = _button(_app.menu, "CLUB RECORD")
	var back_present_before: bool = back != null
	var callbacks: Array[Callable] = _inventory_callbacks(card)
	if back != null:
		back.pressed.emit()
	for callback: Callable in callbacks:
		callback.call()
	await _frames()
	var back_facts: Dictionary = {"label": "inventory_back",
		"button_present_before": back_present_before, "page": _app.menu.page,
		"dialog_visible": _app._dialog.visible, "held_equal": held == _held()}
	_inventory_navigation_facts.append(back_facts)
	_check(back_facts.button_present_before and back_facts.page == "career"
		and not back_facts.dialog_visible and back_facts.held_equal,
		"unchanged inventory Back ignores forged changed diagnostics")
	# An actual v11 input differs from the saved v12 base while retaining all furniture.
	var changed: Dictionary = StadiumSurfaceLayout.base(StadiumPoolOwnedLayout.base(_moved))
	opened = StadiumPoolWorkshopUI.show_inventory_preview(_app.menu,
		changed, ledger.revision(), _pool_copy,
		Vector2(-12, 18), 270)
	await _frames()
	card = _inventory_card()
	if not _check(opened.ok and card != null,
		"validated v11 stored input reopens as a genuinely changed unsaved draft"):
		return
	card.set_meta("pool_inventory_draft", _supported.duplicate(true))
	back = _button(_app.menu, "CLUB RECORD")
	if back != null:
		back.pressed.emit()
	await _frames()
	_check(back != null and _app._dialog.visible and _app.menu.page == "stadium"
		and held == _held(), "stored Back uses accepted base rather than forged saved diagnostics")
	_app._dialog.get_cancel_button().pressed.emit()
	await _frames()
	_check(not _app._dialog.visible and _inventory_card() == card and _preview(_app) == null
		and held == _held(), "real stored Cancel retains inventory session without a world")
	if back != null:
		back.pressed.emit()
	await _frames()
	_check(_app._dialog.visible, "repeated stored Back still asks to discard accepted changes")
	_app._dialog.get_ok_button().pressed.emit()
	await _frames()
	_check(_app.menu.page == "career" and not _app._dialog.visible
		and _inventory_card() == null and held == _held(),
		"real stored discard returns to Club Record without saving inventory changes")
	_inventory["navigation_preserved"] = held == _held()


func _inventory_stale(ledger: ClubAssetLedger) -> void:
	var revision: int = ledger.revision()
	var opened: Dictionary = StadiumPoolWorkshopUI.show_inventory_preview(_app.menu,
		_supported, revision, _pool_copy)
	await _frames()
	var card: VBoxContainer = _inventory_card()
	if not _check(opened.ok and card != null,
		"inventory session opens before genuine revision advance"):
		return
	var balance: int = _app.season.career.balance()
	var active: PackedByteArray = var_to_bytes(ledger.view().stadium_active)
	var saved: Dictionary = ClubConstruction.save_draft(_app.season, _supported, revision)
	ledger = ClubPlayers.assets(_app.season.career)
	_check(saved.ok and ledger.revision() == revision + 1
		and _app.season.career.balance() == balance
		and active == var_to_bytes(ledger.view().stadium_active)
		and ledger.view().stadium_draft == _supported
		and var_to_bytes(_app.season.home_property) == _frozen_home,
		"ordinary unchanged-layout save advances journal without charging or altering frozen data")
	var held: PackedByteArray = _held()
	var body: VBoxContainer = _app.menu._body
	card.set_meta("pool_inventory_revision", ledger.revision())
	card.set_meta("pool_inventory_draft", StadiumPoolOwnedLayout.base(_moved))
	card.set_meta("pool_inventory_copy", "forged-current-copy")
	var place: Button = _button(card, "PLACE IN PREVIEW")
	if place != null:
		place.pressed.emit()
	await _frames()
	_check(place != null and _app.notice == StadiumPoolWorkshopUI.STALE
		and (card.get_node("PoolInventoryFeedback") as Label).text.contains(StadiumPoolWorkshopUI.STALE)
		and _inventory_card() == card and _app.menu._body == body and _preview(_app) == null,
		"diagnostic revision cannot freshen a stale callback-bound inventory session")
	_check(held == _held()
		and _app.menu.find_children("*", "SubViewport", true, false).is_empty(),
		"stale inventory Place preserves all current held bytes without allocating a world")
	var callbacks: Array[Callable] = _inventory_callbacks(card)
	var reload_button: Button = _button(_app.menu, "RELOAD SAVED")
	var reload_present_before: bool = reload_button != null
	if reload_button != null:
		reload_button.pressed.emit()
	body = _app.menu._body
	for callback: Callable in callbacks:
		callback.call()
	_check(callbacks.size() == 2 and _app.menu._body == body
		and not _app._dialog.visible and held == _held(),
		"stale inventory callbacks become inert as soon as their screen is detached")
	await _frames()
	for callback: Callable in callbacks:
		callback.call()
	await _frames()
	var reloaded_preview: StadiumDraftPreview = _preview(_app)
	var stale_reload_facts: Dictionary = {"label": "inventory_stale_reload",
		"button_present_before": reload_present_before,
		"inventory_absent": _inventory_card() == null,
		"placement_absent": _placement_card() == null,
		"preview_present": reloaded_preview != null,
		"preview_pool_absent": reloaded_preview != null and reloaded_preview.pool_model == null,
		"body_is_reloaded": _app.menu._body == body, "held_equal": held == _held()}
	_inventory_navigation_facts.append(stale_reload_facts)
	_check(stale_reload_facts.button_present_before and stale_reload_facts.inventory_absent
		and stale_reload_facts.placement_absent and stale_reload_facts.preview_present
		and stale_reload_facts.preview_pool_absent and stale_reload_facts.body_is_reloaded
		and stale_reload_facts.held_equal,
		"stale inventory Reload restores ordinary workshop and freed callbacks stay inert")
	_inventory["stale_original_revision"] = revision
	_inventory["stale_current_revision"] = ledger.revision()
	_inventory["stale_preserved"] = held == _held()


func _inventory_card() -> VBoxContainer:
	for node: Node in _app.menu._body.find_children("*", "VBoxContainer", true, false):
		if node.has_meta("pool_inventory_draft"):
			return node
	return null


func _pressed_callbacks(button: Button) -> Array[Callable]:
	var callbacks: Array[Callable] = []
	if button != null:
		for connection: Dictionary in button.get_signal_connection_list("pressed"):
			callbacks.append(connection.callable)
	return callbacks


func _inventory_callbacks(card: VBoxContainer) -> Array[Callable]:
	var callbacks: Array[Callable] = _pressed_callbacks(_button(card, "PLACE IN PREVIEW"))
	callbacks.append_array(_pressed_callbacks(_button(_app.menu, "CLUB RECORD")))
	return callbacks


func _inventory_active(ledger: ClubAssetLedger) -> void:
	var first: int = _checks
	var held: PackedByteArray = _held()
	var opened: Dictionary = StadiumPoolWorkshopUI.show_placement_preview(_app.menu,
		_moved, ledger.revision(), true)
	await _frames()
	var card: VBoxContainer = _placement_card()
	var preview: StadiumDraftPreview = _preview(_app)
	var store: Button = _button(card, "STORE IN PREVIEW") if card != null else null
	if not _check(opened.ok and card != null and preview != null and store != null
		and ledger.view().stadium_active == _layout,
		"inventory-origin placement opens beside genuine staged active16"):
		_inventory_checks += _checks - first
		return
	var model: WeakRef = weakref(preview.pool_model)
	store.pressed.emit()
	await _frames()
	card = _inventory_card()
	if not _check(card != null and _preview(_app) == null and model.get_ref() == null
		and not _text(_app.menu).contains(StadiumPoolWorkshopUI.NOTICE),
		"active16 Store reaches dedicated inventory instead of closed ordinary staging"):
		_inventory_checks += _checks - first
		return
	_check(card.get_meta("pool_inventory_draft") == StadiumPoolOwnedLayout.base(_moved)
		and card.get_meta("pool_inventory_copy") == _pool_copy and held == _held(),
		"active16 Store preserves validated base and all active saved and frozen bytes")
	var place: Button = _button(card, "PLACE IN PREVIEW")
	if place != null:
		place.pressed.emit()
	await _frames()
	card = _placement_card()
	preview = _preview(_app)
	_check(card != null and preview != null and card.get_meta("pool_placement_draft") == _moved
		and preview.pool_model.transform == StadiumPoolOwnedLayout.pose(_moved) and held == _held(),
		"active16 re-place retains the remembered pose through private inventory path")
	var reload_button: Button = _button(_app.menu, "RELOAD SAVED")
	var reload_present: bool = reload_button != null and not reload_button.disabled
	if reload_present:
		reload_button.pressed.emit()
	await _frames()
	_check(reload_present and _placement_card() == null and _inventory_card() == null
		and _preview(_app) == null and _text(_app.menu).contains(StadiumPoolWorkshopUI.NOTICE)
		and held == _held(), "active16 Reload deliberately returns to closed public staging")
	_inventory["active16_private_store_preserved"] = held == _held()
	_inventory_checks += _checks - first
