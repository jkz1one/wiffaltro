extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One existing-model small-yard ownership/absence qualification. Zero games.

const SEED: int = 121
const ITEMS: Array[String] = ["ST-001", "ST-003", "ST-004", "ST-008", "ST-009"]
const PRICES: Dictionary = {
	"ST-001": [0, 40],
	"ST-003": [0, 45],
	"ST-004": [240, 70],
	"ST-008": [190, 55],
	"ST-009": [145, 40],
	"ST-002": [160, 45],
	"ST-081": [650, 140]
}
const GATES: Dictionary = {
	"ST-001": {},
	"ST-003": {},
	"ST-004": {"seasons": 3, "wins": 8},
	"ST-008": {"seasons": 2, "wins": 5},
	"ST-009": {"seasons": 2}
}
const SITES: Array[String] = [
	"YS-L1", "YS-L2", "YS-L3", "YS-L4", "YS-R1", "YS-R2", "YS-R3", "YS-R4"
]
# Success path: ownership299 + controls11 + runtime/views64 + entry/completion7 + geometry96 = 477.
const EXPECTED_NON_GEOMETRY_CHECKS: int = 381

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Dictionary = {}
var _empty27: Dictionary = {}
var _base27: Dictionary = {}
var _layout: Dictionary = {}
var _snapshot: Dictionary = {}
var _records: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _contact_cases: Array[Dictionary] = []
var _route_cases: Array[Dictionary] = []
var _camera_cases: Array[Dictionary] = []
var _outcomes: Array = []
var _phase_counts: Dictionary = {}
var _ui_cases: Dictionary = {}
var _physical: Dictionary = {}
var _model_checks: int = 0


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"SMALL_YARD_SCENERY_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "actual-combined-workshop-cards-honest-lock-scope"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	var expected: Dictionary = {
		"ST-001": 13, "ST-003": 49, "ST-004": 35, "ST-008": 37, "ST-009": 37
	}
	var cards: Array[Dictionary] = []
	for item: String in ITEMS:
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumSmallYardSceneryItemsUI.card(
			menu, panel, _layout, _copies[item], item, _paid.revision(), false
		)
		var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		var choice: OptionButton = options[0] as OptionButton if options.size() == 1 else null
		_check(
			(
				choice != null
				and choice.disabled
				and choice.get_item_text(0) == "Stored"
				and choice.item_count == expected[item]
			),
			(
				"actual locked combined card includes Stored plus every preserved live and scenery pose "
				+ item
			)
		)
		var choices: Array[Dictionary] = StadiumSmallYardSceneryItemsUI.choices(item)
		var live: Array = choices.filter(func(row: Dictionary) -> bool: return row.mode == "live")
		var scenery: Array = choices.filter(
			func(row: Dictionary) -> bool: return row.mode == "scenery"
		)
		# Producer/helper-only shape probe: no owned-pool or native-pool claim.
		var pool_shape: Dictionary = {
			"version": 16, "family": StadiumPoolOwnedLayout.FAMILY, "obstacles": []
		}
		var requested: Dictionary = {"mode": "scenery", "site": "YS-L1", "yaw": 0}
		var rejected: Dictionary = StadiumSmallYardSceneryItemsUI.proposal(
			pool_shape, _paid.construction(), _copies[item], requested, _paid.surface_owned()
		)
		var holds_rejected: bool = StadiumSmallYardSceneryItemsUI.holds_choice(
			rejected, _copies[item], item, requested
		)
		_operands = {
			"item": item,
			"case": "producer-helper-only-separate-pool-shape",
			"input": pool_shape,
			"requested": requested,
			"unchanged": ClubCareer.same(pool_shape, rejected),
			"holds_choice": holds_rejected
		}
		_check(
			(
				scenery.size() == 8 * (1 if item == "ST-001" else 4)
				and live.size() == (16 if item == "ST-003" else 2 if item == "ST-004" else 4)
				and ClubCareer.same(pool_shape, rejected)
				and not holds_rejected
			),
			(
				"combined UI preserves live/scenery choices and rejects unchanged separate-pool proposals "
				+ item
			)
		)
		cards.append(
			{
				"item": item,
				"options": choices.size(),
				"live": live.size(),
				"scenery": scenery.size(),
				"disabled": choice != null and choice.disabled,
				"rejected_no_op_probe": _operands.duplicate(true)
			}
		)
	app.season.phase = SeasonState.Phase.REGULAR
	var held: Dictionary = app.season.career.to_data()
	var result: Dictionary = ClubConstruction.buy_copy(app.season, "ST-004", 0)
	_check(
		not result.ok and ClubCareer.same(held, app.season.career.to_data()),
		"ordinary locked season buy refuses without mutation"
	)
	_ui_cases = {
		"cards": cards,
		"new_purchase_controls": false,
		"accepted_seasonstate_purchase_executed": false,
		"ledger_paid_purchases_executed": true,
		"synthetic_ledger_funding": true,
		"locked_buy_error": result.get("error", "")
	}
	menu.free()
	app.free()


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "small-yard-draft:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		_operands = {"stage": "draft", "error": draft.get("error", "")}
		return false
	var result: Dictionary = _paid.commit(
		{
			"id": "small-yard-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("expanded", layout)
		}
	)
	_operands = {"stage": "apply", "error": result.get("error", "")}
	return result.ok


func _price_version(item: String) -> int:
	return (
		StadiumPurchases.VERSION
		if item in ["ST-001", "ST-003"]
		else (
			StadiumLiveFurnishingItems.PRICE_VERSION
			if item == "ST-002"
			else (
				StadiumRoofItems.PRICE_VERSION
				if item == "ST-081"
				else StadiumGroundPropsItems.PRICE_VERSION
			)
		)
	)


func _buy(item: String) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "small-yard-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": 1,
		"price_version": _price_version(item),
		"through": _credits.size()
	}
	if command.price_version != StadiumPurchases.VERSION:
		command["progress_through"] = _progress.size()
	var cost: int = (
		int(PRICES[item][1])
		+ (0 if _paid.construction().blueprints.has(item) else int(PRICES[item][0]))
	)
	var balance: int = _paid.balance()
	var count: int = _paid.construction().copies.size()
	var result: Dictionary = _paid.commit(command)
	_operands = {
		"item": item,
		"price_version": _price_version(item),
		"error": result.get("error", ""),
		"cost": cost
	}
	_check(
		(
			result.ok
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"ordinary unchanged paid purchase adds exactly one copy " + item
	)
	_check(
		(
			_paid.commit(command).get("replayed", false)
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"purchase retry neither charges nor duplicates " + item
	)
	if not result.ok:
		return  # A rejected setup command creates no paid-copy witness.
	_copies[item] = "purchase:small-yard-buy:%d:0" % revision
	_ownership_cases.append(
		{
			"case": "paid-purchase",
			"item": item,
			"copy": _copies[item],
			"cost": cost,
			"price_version": _price_version(item)
		}
	)


func _checked(layout: Dictionary, tier: String = "expanded") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"error": result.get("error", ""),
		"tier": tier,
		"yard_scenery": layout.get("yard_scenery", [])
	}
	return result


func _placed(layout: Dictionary, item: String, site: String, yaw: int = 0) -> Dictionary:
	return StadiumSmallYardSceneryItems.place(
		layout, _paid.construction(), _copies[item], site, yaw, _paid.surface_owned()
	)


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _conflicts() -> void:
	_phase = "whole-cell-existing-beach-and-actual-structure-conflicts"
	for item: String in ITEMS:
		var beach: Dictionary = StadiumLiveFurnishingItems.place(
			_empty27, _paid.construction(), _copies["ST-002"], "YS-L1", 0
		)
		_check(
			_checked(beach).ok,
			"existing paid beach-ball scenery independently occupies the shared cell " + item
		)
		var beach_first: Dictionary = _placed(beach, item, "YS-L1")
		var beach_first_check: Dictionary = _checked(beach_first)
		_check(
			(
				not beach_first_check.ok
				and beach_first.live_furnishings.size() == 1
				and beach_first.yard_scenery.size() == 1
			),
			"existing beach first rejects a second occupant without silent displacement " + item
		)
		var scene: Dictionary = _placed(_empty27, item, "YS-L1")
		var scene_first: Dictionary = StadiumLiveFurnishingItems.place(
			scene, _paid.construction(), _copies["ST-002"], "YS-L1", 0
		)
		var scene_first_check: Dictionary = _checked(scene_first)
		_check(
			(
				not scene_first_check.ok
				and scene_first.live_furnishings.size() == 1
				and scene_first.yard_scenery.size() == 1
			),
			"small-yard scenery first rejects later beach occupancy " + item
		)
		var explicit: Dictionary = StadiumLiveFurnishingItems.store_copy(beach, _copies["ST-002"])
		explicit = _placed(explicit, item, "YS-L1")
		_check(
			_checked(explicit).ok and _checked(explicit).stored.has(_copies["ST-002"]),
			"explicit beach Store-first permits the same paid scenery copy " + item
		)
		var reverse: Dictionary = StadiumSmallYardSceneryItems.store_copy(scene, _copies[item])
		reverse = StadiumLiveFurnishingItems.place(
			StadiumLiveFurnishingItems.upgrade(reverse, _paid.surface_owned()),
			_paid.construction(),
			_copies["ST-002"],
			"YS-L1",
			0
		)
		_check(
			_checked(reverse).ok and _checked(reverse).stored.has(_copies[item]),
			"explicit scenery Store-first permits the existing paid beach copy " + item
		)
		_ownership_cases.append(
			{
				"case": "actual-shared-cell-both-orders",
				"item": item,
				"site": "YS-L1",
				"beach_copy": _copies["ST-002"],
				"scene_copy": _copies[item],
				"beach_first_error": beach_first_check.get("error", ""),
				"scene_first_error": scene_first_check.get("error", ""),
				"both_candidates_preserve_both_rows": true
			}
		)
		var placed: Dictionary = StadiumSmallYardSceneryItems.row(_copies[item], item, "YS-R1", 0)
		var control: Dictionary = {
			"copy": "geometry-only-control",
			"item": "ST-001",
			"site": "O-R2",
			"position": placed.position + Vector3(1.10, 0, 0),
			"yaw": 0,
			"role": "LIVE_RICOCHET"
		}
		var actual_box: AABB = StadiumSmallYardSceneryItems.bounds(placed)
		var control_box: AABB = (
			StadiumLiveFurnishingItems._pose(control)
			* AABB(Vector3(-0.175, 0, -0.175), Vector3(0.35, 0.50, 0.35))
		)
		_operands = {
			"item": item,
			"case": "geometric-helper-only",
			"cell_center": _v3(placed.position),
			"control_center": _v3(control.position),
			"cell_radius_m": 1.0,
			"visible_boxes_overlap": actual_box.intersects(control_box)
		}
		_check(
			(
				not actual_box.intersects(control_box)
				and StadiumSmallYardSceneryItems._cell_overlaps(placed, control)
			),
			(
				(
					"complete reserved cell rejects nearby geometry even when visible object envelopes "
					+ "do not overlap "
				)
				+ item
			)
		)
		_check(
			(
				StadiumSmallYardSceneryItems._outside_play(
					placed.position,
					StadiumSmallYardSceneryItems.graph_for(_placed(_empty27, item, "YS-R1"))
				)
				and not StadiumSmallYardSceneryItems._outside_play(
					StadiumStarterLayout.SITES["O-R1"],
					StadiumSmallYardSceneryItems.graph_for(_placed(_empty27, item, "YS-R1"))
				)
			),
			"whole-cell outside-play guard rejects a live-field center " + item
		)
	_buy("ST-081")
	if not _copies.has("ST-081"):
		return
	for side: String in ["R", "L"]:
		var site: String = "BOWL-01" if side == "R" else "BOWL-05"
		var ys: String = "YS-" + side + "1"
		var roof_row: Dictionary = StadiumRoofItems.row(site)
		roof_row.copy = _copies["ST-081"]
		var structure: Dictionary = _empty27.duplicate(true)
		structure.roofs = [roof_row]
		_check(
			_checked(structure, "mogul").ok,
			(
				"actual separately paid standalone lower grandstand is a legal Mogul structure candidate "
				+ side
			)
		)
		_check(
			not _checked(structure, "expanded").ok,
			"standalone grandstand retains its existing land-access restriction " + side
		)
		var structure_first: Dictionary = _placed(structure, "ST-001", ys)
		var structure_first_check: Dictionary = _checked(structure_first, "mogul")
		_check(
			(
				not structure_first_check.ok
				and structure_first.roofs.size() == 1
				and structure_first.yard_scenery.size() == 1
			),
			"actual whole structure reservation rejects later scenery without displacement " + side
		)
		var scene_first: Dictionary = _placed(_empty27, "ST-001", ys)
		scene_first.roofs = [roof_row.duplicate(true)]
		var scene_first_check: Dictionary = _checked(scene_first, "mogul")
		_check(
			(
				not scene_first_check.ok
				and scene_first.roofs.size() == 1
				and scene_first.yard_scenery.size() == 1
			),
			"actual scenery reservation rejects the later paid structure " + side
		)
		var stored: Dictionary = StadiumSmallYardSceneryItems.store_copy(
			scene_first, _copies["ST-001"]
		)
		_check(
			(
				_checked(stored, "mogul").ok
				and _checked(stored, "mogul").stored.has(_copies["ST-001"])
			),
			"explicit Store-first restores the legal owned structure candidate " + side
		)
		_ownership_cases.append(
			{
				"case": "actual-structure-both-orders-validation-only",
				"structure": "ST-081",
				"copy": _copies["ST-081"],
				"site": site,
				"scenery_site": ys,
				"tier": "mogul",
				"installed_claim": false,
				"structure_first_error": structure_first_check.get("error", ""),
				"scene_first_error": scene_first_check.get("error", "")
			}
		)


func _negatives() -> void:
	_phase = "malformed-duplicate-foreign-and-stale-scenery"
	for mode: String in [
		"unowned",
		"wrong-item",
		"duplicate-copy",
		"duplicate-site",
		"unknown-field",
		"unknown-site",
		"unsupported-yaw",
		"wrong-family",
		"wrong-version"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		var raw: Dictionary = bad.yard_scenery[0]
		match mode:
			"unowned":
				raw.copy = "purchase:missing:0"
			"wrong-item":
				raw.item = "ST-007"
			"duplicate-copy":
				bad.yard_scenery[1].copy = raw.copy
			"duplicate-site":
				bad.yard_scenery[1].site = raw.site
			"unknown-field":
				raw["position"] = [0, 0, 0]
			"unknown-site":
				raw.site = "O-R2"
			"unsupported-yaw":
				raw.yaw = 45
			"wrong-family":
				bad.family = "reference-starter-v1"
			"wrong-version":
				bad.version = 27
		_check(not _checked(bad).ok, "malformed exact scenery selection refuses " + mode)
	var duplicate: Dictionary = _layout.duplicate(true)
	duplicate.obstacles.append({"copy": _copies["ST-001"], "site": "O-R2", "yaw": 0})
	_check(
		not _checked(duplicate).ok,
		"same copy cannot be simultaneously scenery and an inherited live obstacle"
	)
	var held: Dictionary = _paid.to_data().duplicate(true)
	var stale: Dictionary = _paid.commit(
		{
			"id": "small-yard-stale-draft",
			"rev": _paid.revision() - 1,
			"op": "stadium_draft",
			"layout": _layout
		}
	)
	_check(
		not stale.ok and ClubCareer.same(held, _paid.to_data()),
		"stale draft revision cannot mutate paid scenery or ownership"
	)


func _night_apply(paid: ClubAssetLedger, layout: Dictionary) -> bool:
	var draft: Dictionary = paid.commit(
		{
			"id": "small-yard-night-draft:%d" % paid.revision(),
			"rev": paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		return false
	var result: Dictionary = paid.commit(
		{
			"id": "small-yard-night-apply:%d" % paid.revision(),
			"rev": paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumHomeLayout.geometry(paid.view().land, layout)
		}
	)
	return result.ok
func _night_recovery() -> void:
	_phase = "bounded-cold-restoration-of-existing-night-candidate"
	var paid: ClubAssetLedger = ClubAssetLedger.new_club(SEED + 1, _credits, _progress)
	var setup: Array[Dictionary] = [
		{
			"op": "stadium_buy",
			"item": "ST-038",
			"quantity": 4,
			"price_version": StadiumFloodlightOwnedItems.PRICE_VERSION
		},
		{
			"op": "stadium_buy",
			"item": "ST-001",
			"quantity": 1,
			"price_version": StadiumPurchases.VERSION
		},
		{"op": "stadium_land", "tier": "expanded", "price_version": StadiumLand.VERSION},
		{"op": "stadium_land", "tier": "club", "price_version": StadiumLand.VERSION},
		{
			"op": "stadium_surface",
			"item": "grass",
			"price_version": StadiumSurfaceProgression.VERSION
		},
		{
			"op": "stadium_surface",
			"item": "ground_prep",
			"price_version": StadiumSurfaceProgression.VERSION
		},
		{"op": "stadium_style", "item": "ST-063b", "price_version": StadiumFieldStyles.VERSION},
		{
			"op": "stadium_style",
			"item": "ST-063i",
			"price_version": StadiumGroundStyles.PRICE_VERSION
		}
	]
	var commands: Array[Dictionary] = []
	var setup_ok: bool = true
	var copy: String = ""
	for raw: Dictionary in setup:
		var command: Dictionary = raw.duplicate(true)
		command.id = "small-yard-night:%d" % paid.revision()
		command.rev = paid.revision()
		command.through = _credits.size()
		if (
			command.op != "stadium_surface"
			and not (
				command.op == "stadium_buy" and command.price_version == StadiumPurchases.VERSION
			)
		):
			command["progress_through"] = _progress.size()
		if command.get("item", "") == "ST-001":
			copy = "purchase:" + str(command.id) + ":0"
		var result: Dictionary = paid.commit(command)
		setup_ok = setup_ok and result.ok
		commands.append(
			{
				"op": command.op,
				"item": command.get("item", ""),
				"tier": command.get("tier", ""),
				"ok": result.ok,
				"error": result.get("error", "")
			}
		)
		if not result.ok:
			break
	if not setup_ok:
		_operands = {"stage": "night-setup", "setup_commands": commands}
		_check(
			false,
			(
				"same paid scenery copy blocks Night and last Store/cold replay restores the exact "
				+ "previously eligible four-tower family25 candidate"
			)
		)
		return
	var base: Dictionary = StadiumFloodlightOwnedItems.upgrade(
		paid.view().stadium_active, paid.surface_owned()
	)
	base.surface = {"foundation": "grass", "condition": "prepared", "height": "short"}
	base.styles = {"grass": "ST-063b", "line": ""}
	base.ground = "ST-063i"
	base = StadiumFloodlightOwnedItems.select_preset(base, paid.construction(), "CLUB4-LOW")
	var base_applied: bool = _night_apply(paid, base)
	var before: Dictionary = StadiumSurfaceNightLayout.capture(paid)
	var balance: int = paid.balance()
	var scene: Dictionary = StadiumSmallYardSceneryItems.place(
		base, paid.construction(), copy, "YS-L1", 0, paid.surface_owned()
	)
	var scene_applied: bool = _night_apply(paid, scene)
	var during: Dictionary = StadiumSurfaceNightLayout.capture(paid)
	var stored: Dictionary = StadiumSmallYardSceneryItems.store_copy(scene, copy)
	var stored_applied: bool = _night_apply(paid, stored)
	var after: Dictionary = StadiumSurfaceNightLayout.capture(paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(paid.to_data())), SEED + 1, _credits, _progress
	)
	var cold_candidate: Dictionary = {} if cold == null else StadiumSurfaceNightLayout.capture(cold)
	var restored: bool = (
		setup_ok
		and base_applied
		and base.get("version", 0) == 25
		and not before.is_empty()
		and scene_applied
		and scene.get("version", 0) == 28
		and during.is_empty()
		and stored_applied
		and stored.get("version", 0) == 25
		and ClubCareer.same(stored, base)
		and not after.is_empty()
		and cold != null
		and not cold_candidate.is_empty()
		and ClubCareer.same(cold.to_data(), paid.to_data())
		and ClubCareer.same(cold_candidate, after)
		and paid.balance() == balance
	)
	_operands = {
		"setup_commands": commands,
		"profile": "CLUB4-LOW",
		"copy": copy,
		"base_applied": base_applied,
		"before_candidate": not before.is_empty(),
		"scene_applied": scene_applied,
		"during_candidate": not during.is_empty(),
		"stored_applied": stored_applied,
		"exact_base25_restored": ClubCareer.same(stored, base),
		"after_candidate": not after.is_empty(),
		"cold_candidate": not cold_candidate.is_empty(),
		"free_transitions": paid.balance() == balance
	}
	_check(
		restored,
		(
			"same paid scenery copy blocks Night and last Store/cold replay restores the exact "
			+ "previously eligible four-tower family25 candidate"
		)
	)
	_ownership_cases.append(
		{
			"case": "actual-owned-night-candidate-restoration",
			"disposable_synthetic_ledger": true,
			"native_night_install": false,
			"games": 0,
			"operands": _operands.duplicate(true),
			"before_layout": base,
			"stored_layout": stored,
			"cold_candidate": cold_candidate
		}
	)


func _record(label: String, layout: Dictionary) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_operands = {
		"case": label,
		"empty_snapshot": snapshot.is_empty(),
		"cold_null": cold == null,
		"revision": _paid.revision()
	}
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
			and ClubCareer.same(snapshot.layout, layout)
		),
		"exact frozen owned-copy snapshot " + label
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
		),
		"cold JSON replays exact paid identity and placement " + label
	)
	_records.append({"case": label, "layout": layout.duplicate(true), "snapshot": snapshot})


func _live(layout: Dictionary, item: String) -> Dictionary:
	return StadiumSmallYardSceneryItems.place_live(
		layout,
		_paid.construction(),
		_copies[item],
		"OM-L" if item == "ST-004" else "O-L1",
		0,
		_paid.surface_owned()
	)


func _same_copy_modes() -> void:
	_phase = "same-paid-copy-live-scenery-store-live-cold-journal"
	var balance: int = _paid.balance()
	for item: String in ITEMS:
		var live: Dictionary = _live(_empty27, item)
		_check(
			_checked(live).ok and _apply(live) and _paid.balance() == balance,
			"unchanged legacy live grammar accepts this exact paid copy " + item
		)
		_record(item + ":old-live", live)
		var scene: Dictionary = _placed(live, item, "YS-L1")
		var checked: Dictionary = _checked(scene)
		_check(
			(
				checked.ok
				and checked.get("live_units", -1) == 0
				and (
					(
						checked
						. placements
						. filter(func(row: Dictionary) -> bool: return row.copy == _copies[item])
						. size()
					)
					== 1
				)
				and _apply(scene)
				and _paid.balance() == balance
			),
			"same paid copy moves live to scenery without duplication or residual budget " + item
		)
		_record(item + ":scenery", scene)
		var stored: Dictionary = StadiumSmallYardSceneryItems.store_copy(scene, _copies[item])
		var empty25: Dictionary = StadiumLandscapeOwnedItems.base(
			StadiumLiveFurnishingItems.base(_empty27)
		)
		_check(
			(
				stored.version == 25
				and ClubCareer.same(stored, empty25)
				and _checked(stored).stored.has(_copies[item])
				and _apply(stored)
				and _paid.balance() == balance
			),
			(
				(
					"last scenery Store preserves exact ownership and canonically restores the prior "
					+ "supported family25 "
				)
				+ item
			)
		)
		_record(item + ":stored", stored)
		var remount: Dictionary = _live(stored, item)
		_check(
			(
				_checked(remount).ok
				and _apply(remount)
				and _paid.balance() == balance
				and _paid.construction().copies.size() == 9
			),
			"free return to old live route preserves all paid copies " + item
		)
		_record(item + ":live-remount", remount)


func _sites_and_yaws() -> void:
	_phase = "all-eight-cells-and-every-authored-yaw"
	for item: String in ITEMS:
		var sites: Array[String] = StadiumSmallYardSceneryItems.sites(item)
		var yaws: Array = StadiumSmallYardSceneryItems.yaws(item)
		_check(
			sites == SITES and not yaws.is_empty(),
			"every item offers exactly the same eight canonical small-yard cells " + item
		)
		for site: String in sites:
			for yaw: int in yaws:
				var candidate: Dictionary = _placed(_empty27, item, site, yaw)
				var checked: Dictionary = _checked(candidate)
				var row: Dictionary = StadiumSmallYardSceneryItems.row(
					_copies[item], item, site, yaw
				)
				_check(
					(
						checked.ok
						and checked.get("live_units", -1) == 0
						and checked.get("yard_scenery_placements", []).size() == 1
						and row.role == "DECORATIVE_AFTER_TERMINAL"
					),
					(
						"whole cell and authored scenery pose fit without live budget "
						+ item
						+ ":"
						+ site
						+ ":"
						+ str(yaw)
					)
				)
				_ownership_cases.append(
					{
						"case": "authored-cell-yaw",
						"item": item,
						"site": site,
						"yaw": yaw,
						"units": checked.get("live_units", -1)
					}
				)
