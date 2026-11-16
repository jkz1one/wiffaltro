extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One synthetic paid landscape batch, ordinary installation and two bounded native originals.

## Success path: ownership100 + controls4 + source114 + runtime/views53 + entry/completion7 = 278.
const EXPECTED_CHECKS: int = 278
const SEED: int = 101
const ITEMS: Array[String] = ["ST-013", "ST-014", "ST-018", "ST-019"]
const QUANTITIES: Array[int] = [3, 6, 2, 2]
const EXPECTED_PRICES: Dictionary = {
	"ST-013": [260, 80], "ST-014": [200, 45], "ST-018": [720, 220], "ST-019": [350, 100]
}
const EXPECTED_GATES: Dictionary = {
	"ST-013": {"seasons": 3},
	"ST-014": {"seasons": 3},
	"ST-018": {"seasons": 8, "wins": 24},
	"ST-019": {"seasons": 5}
}

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Dictionary = {}
var _layout: Dictionary = {}
var _base25: Dictionary = {}
var _snapshot: Dictionary = {}
var _records: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _route_cases: Array[Dictionary] = []
var _phase_counts: Dictionary = {}
var _model_checks: int = 0
var _native_model_count: int = 0
var _physical: Dictionary = {}
var _camera_cases: Array[Dictionary] = []
var _ui_cases: Dictionary = {}


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"LANDSCAPE_REBUILD_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "bounded-real-workshop-controls"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	StadiumLandscapeOwnedItemsUI.purchases(menu, _paid, true)
	var buttons: Array[String] = []
	var all_locked: bool = true
	for button: Button in menu.find_children("*", "Button", true, false):
		if button.has_meta("stadium_buy"):
			buttons.append(button.get_meta("stadium_buy"))
			all_locked = all_locked and button.disabled
	buttons.sort()
	_check(
		buttons == ITEMS and all_locked,
		"actual Workshop constructs all four purchase buttons and honors the empty career's locks"
	)
	for item: String in ["ST-013", "ST-019"]:
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumLandscapeOwnedItemsUI.card(
			menu, panel, _layout, _copies[item][0], item, _paid.revision(), false
		)
		var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		var choice: OptionButton = options[0] as OptionButton if options.size() == 1 else null
		_check(
			(
				choice != null
				and choice.disabled
				and choice.get_item_text(0) == "Stored"
				and choice.item_count == (3 if item == "ST-013" else 9)
			),
			(
				"actual disabled card keeps Stored plus the complete canonical site and yaw choices "
				+ item
			)
		)
	app.season.phase = SeasonState.Phase.REGULAR
	var before: Dictionary = app.season.career.to_data()
	var locked: Dictionary = ClubConstruction.buy_copy(app.season, "ST-013", 0)
	_operands = {"error": locked.get("error", ""), "season_phase": app.season.phase}
	_check(
		not locked.ok and ClubCareer.same(before, app.season.career.to_data()),
		"ordinary ClubConstruction buy refuses a locked season without mutation"
	)
	_ui_cases = {
		"purchase_buttons": buttons,
		"empty_career_locked": all_locked,
		"accepted_seasonstate_purchase_executed": false,
		"card_items": ["ST-013", "ST-019"],
		"locked_buy_error": locked.get("error", "")
	}
	menu.free()
	app.free()


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "landscape-draft:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		_operands = {
			"stage": "draft",
			"error": draft.get("error", ""),
			"landscape": layout.get("landscape", [])
		}
		return false
	var applied: Dictionary = _paid.commit(
		{
			"id": "landscape-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("expanded", layout)
		}
	)
	_operands = {
		"stage": "apply",
		"error": applied.get("error", ""),
		"landscape": layout.get("landscape", [])
	}
	return applied.ok


func _buy(item: String, quantity: int, version: int) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "landscape-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var entry: Dictionary = StadiumCatalog.item(item)
	var expected: int = (
		int(entry.copy_price) * quantity
		+ (0 if _paid.construction().blueprints.has(item) else int(entry.blueprint_price))
	)
	var balance: int = _paid.balance()
	var count: int = _paid.construction().copies.size()
	var result: Dictionary = _paid.commit(command)
	_operands = {
		"item": item,
		"error": result.get("error", ""),
		"expected_cost": expected,
		"before_copies": count,
		"after_copies": _paid.construction().copies.size()
	}
	_check(
		(
			result.ok
			and _paid.balance() == balance - expected
			and _paid.construction().copies.size() == count + quantity
		),
		"ordinary unchanged blueprint and exact-copy purchase " + item
	)
	_check(
		(
			_paid.commit(command).get("replayed", false)
			and _paid.balance() == balance - expected
			and _paid.construction().copies.size() == count + quantity
		),
		"purchase retry never duplicates or charges twice " + item
	)
	_copies[item] = []
	for index in range(quantity):
		_copies[item].append("purchase:landscape-buy:%d:%d" % [revision, index])
	_ownership_cases.append(
		{
			"case": "paid-purchase",
			"item": item,
			"quantity": quantity,
			"cost": expected,
			"copy_ids": _copies[item].duplicate()
		}
	)


func _checked(layout: Dictionary, tier: String = "expanded") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"error": result.get("error", ""),
		"tier": tier,
		"landscape": layout.get("landscape", []),
		"displays": layout.get("displays", [])
	}
	return result


func _clearances() -> void:
	_phase = "exact-narrow-clearances-and-both-wall-shapes"
	for side: String in ["L", "R"]:
		var tree: Dictionary = StadiumLandscapeOwnedItems.row(
			_copies["ST-013"][0], "ST-013", "TREE-" + side
		)
		var hedge: Dictionary = StadiumLandscapeOwnedItems.row(
			_copies["ST-014"][0], "ST-014", "HEDGE-" + side + "3"
		)
		var light: Dictionary = {
			"copy": _copies["ST-037"][0],
			"item": "ST-037",
			"site": "YLIGHT-R" + side,
			"position": StadiumYardLightModels.SITES["YLIGHT-R" + side],
			"yaw": StadiumYardLightSites.yaw("YLIGHT-R" + side)
		}
		for other: Dictionary in [hedge, light]:
			var pose: Transform3D = Transform3D(
				Basis(Vector3.UP, deg_to_rad(float(other.yaw))), other.position
			)
			var local: Vector3 = pose.affine_inverse() * tree.position
			var box: AABB = StadiumLandscapeOwnedItems._local_box(other)
			var nearest: Vector2 = Vector2(
				clampf(local.x, box.position.x, box.end.x),
				clampf(local.z, box.position.z, box.end.z)
			)
			var gap: float = (
				nearest.distance_to(Vector2(local.x, local.z))
				- StadiumLandscapeOwnedItems._radius(tree.item)
			)
			_operands = {"tree": tree.site, "other": other.site, "exact_circle_obb_gap": gap}
			_check(
				gap > 0 and gap < 0.1 and not StadiumLandscapeOwnedItems._overlaps(tree, other),
				(
					"tight positive complete-reservation clearance stays legal "
					+ tree.site
					+ " / "
					+ other.site
				)
			)
			_ownership_cases.append(
				{
					"case": "tight-positive-clearance",
					"tree": tree.site,
					"other": other.site,
					"metres": gap
				}
			)
		var with_rear_light: Dictionary = _layout.duplicate(true)
		with_rear_light.lights = [{"copy": _copies["ST-037"][0], "site": light.site}]
		_check(
			_checked(with_rear_light).ok,
			(
				"actual paid rear-yard-light placement coexists with all nine complete landscape assemblies "
				+ side
			)
		)
	for shape: String in ["straight", "deeper_center"]:
		var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape)
		var rejected: Array[String] = []
		for raw: Dictionary in _layout.landscape:
			var placed: Dictionary = StadiumLandscapeOwnedItems.row(
				raw.copy, raw.item, raw.site, raw.yaw
			)
			if not StadiumLandscapeOwnedItems._outside_play(placed, graph):
				rejected.append(raw.site)
		_operands = {"shape": shape, "boundary": graph.identity(), "rejected_sites": rejected}
		_check(
			rejected.is_empty(),
			"all selected complete reservations clear the actual supported wall polygon " + shape
		)
		_ownership_cases.append(
			{
				"case": "terminal-wall-shape",
				"shape": shape,
				"boundary": graph.identity(),
				"rejected_sites": rejected
			}
		)


func _placed(
	layout: Dictionary, item: String, index: int, site: String, yaw: int = 0
) -> Dictionary:
	return StadiumLandscapeOwnedItems.place(
		StadiumLandscapeOwnedItems.upgrade(layout, _paid.surface_owned()),
		_paid.construction(),
		_copies[item][index],
		site,
		yaw
	)


func _conflicts() -> void:
	_phase = "explicit-store-before-conflicting-placement"
	for first: String in ["ST-018", "ST-019"]:
		var second: String = "ST-019" if first == "ST-018" else "ST-018"
		var one: Dictionary = _placed(_base25, first, 0, "LAND-L")
		_check(_checked(one).ok, "each whole pocket occupant fits independently " + first)
		var conflict: Dictionary = _placed(one, second, 0, "LAND-L")
		var checked: Dictionary = _checked(conflict)
		_check(
			not checked.ok and conflict.landscape.size() == 2 and one.landscape.size() == 1,
			(
				"same pocket refuses both occupants without silent displacement "
				+ first
				+ " then "
				+ second
			)
		)
		var explicit: Dictionary = _placed(
			StadiumLandscapeOwnedItems.store_copy(one, _copies[first][0]), second, 0, "LAND-L"
		)
		var explicit_check: Dictionary = _checked(explicit)
		_check(
			(
				explicit_check.ok
				and explicit_check.stored.has(_copies[first][0])
				and explicit.landscape.size() == 1
			),
			"explicit Store-first permits pocket replacement " + first + " then " + second
		)
		_ownership_cases.append(
			{
				"case": "shared-pocket",
				"first": first,
				"second": second,
				"rejected_error": checked.get("error", ""),
				"preserved_candidate_rows": conflict.landscape,
				"explicit_store_result": explicit.landscape
			}
		)
	var tree: Dictionary = _placed(_base25, "ST-013", 0, "TREE-L")
	var board: Dictionary = _base25.duplicate(true)
	board.displays = [{"copy": _copies["ST-039"][0], "site": "SCORE-SMALL"}]
	_check(
		_checked(tree).ok and _checked(board).ok,
		(
			"tree and historical manual scoreboard are independently legal before their shared "
			+ "reservation conflict"
		)
	)
	for order: String in ["tree-then-scoreboard", "scoreboard-then-tree"]:
		var candidate: Dictionary = (
			tree.duplicate(true)
			if order == "tree-then-scoreboard"
			else _placed(board, "ST-013", 0, "TREE-L")
		)
		if order == "tree-then-scoreboard":
			candidate.displays = board.displays.duplicate(true)
		var checked: Dictionary = _checked(candidate)
		_check(
			not checked.ok and candidate.displays.size() == 1 and candidate.landscape.size() == 1,
			"both placement orders retain both exact rows and reject overlap " + order
		)
		var restored: Dictionary = (
			StadiumLandscapeOwnedItems.store_copy(candidate, _copies["ST-013"][0])
			if order == "tree-then-scoreboard"
			else candidate.duplicate(true)
		)
		if order == "scoreboard-then-tree":
			restored.displays = []
		var restored_check: Dictionary = _checked(restored)
		_check(
			(
				restored_check.ok
				and restored_check.stored.has(
					(
						_copies["ST-013"][0]
						if order == "tree-then-scoreboard"
						else _copies["ST-039"][0]
					)
				)
			),
			"explicit Store-first resolves tree-scoreboard overlap " + order
		)
		_ownership_cases.append(
			{
				"case": order,
				"rejected_error": checked.get("error", ""),
				"landscape_rows": candidate.landscape,
				"display_rows": candidate.displays,
				"store_first_valid": restored_check.ok
			}
		)
	for angle: int in [0, 90, 180, 270]:
		_check(
			_checked(_placed(_base25, "ST-019", 0, "LAND-R", angle)).ok,
			"whole rock garden fits its authored pocket at supported cardinal yaw %d" % angle
		)
	var small: Dictionary = _placed(
		StadiumLandscapeOwnedItems.upgrade(StadiumStarterLayout.empty(), _paid.surface_owned()),
		"ST-018",
		0,
		"LAND-L"
	)
	_check(not _checked(small, "backyard").ok, "Backyard cannot borrow the Expanded pond pocket")


func _hedges() -> void:
	_phase = "finished-two-metre-hedge-subsets"
	var sites: Array[String] = StadiumLandscapeOwnedItems.sites("ST-014")
	_check(
		sites.size() == 6 and StadiumLandscapeModels.envelope("ST-014").size == Vector3(2, 1.8, 1),
		"six exact sockets use complete two-metre hedge reservations"
	)
	for index in range(sites.size()):
		var single: Dictionary = _placed(_base25, "ST-014", index, sites[index])
		var checked: Dictionary = _checked(single)
		_check(
			(
				checked.ok
				and checked.get("landscape_placements", []).size() == 1
				and checked.stored.has(_copies["ST-014"][(index + 1) % sites.size()])
			),
			"one finished hedge needs no adjoining copy or filler " + sites[index]
		)
	var subset: Dictionary = StadiumLandscapeOwnedItems.upgrade(_base25, _paid.surface_owned())
	for index in [0, 2, 5]:
		subset = _placed(subset, "ST-014", index, sites[index])
	var subset_check: Dictionary = _checked(subset)
	_check(
		(
			subset_check.ok
			and subset_check.get("landscape_placements", []).size() == 3
			and subset_check.stored.has(_copies["ST-014"][1])
		),
		"noncontiguous hedge subset leaves the unused middle socket empty and owned"
	)
	var full: Dictionary = subset.duplicate(true)
	for index in range(sites.size()):
		full = _placed(full, "ST-014", index, sites[index])
	var full_check: Dictionary = _checked(full)
	_check(
		(
			full_check.ok
			and full_check.get("landscape_placements", []).size() == 6
			and full_check.get("live_units", -1) == 1
		),
		"all six touching finished hedge copies need no recipe filler and no additional live units"
	)
	_ownership_cases.append(
		{
			"case": "hedge-subsets",
			"single_sites": sites,
			"noncontiguous": subset.landscape,
			"full": full.landscape,
			"finished_length_m": 2,
			"filler_copies": 0
		}
	)


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func _negatives() -> void:
	_phase = "malformed-ownership-and-live-reachability"
	for mode: String in [
		"unowned",
		"wrong-item",
		"duplicate-copy",
		"duplicate-site",
		"unknown-field",
		"unknown-site",
		"noncardinal",
		"tree-rotation"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		var raw: Dictionary = bad.landscape[0]
		match mode:
			"unowned":
				raw.copy = "purchase:missing:0"
			"wrong-item":
				raw.item = "ST-013"
			"duplicate-copy":
				bad.landscape[1].copy = raw.copy
			"duplicate-site":
				bad.landscape[1].site = raw.site
			"unknown-field":
				raw["position"] = [0, 0, 0]
			"unknown-site":
				raw.site = "INVENTED"
			"noncardinal":
				raw.yaw = 45
			"tree-rotation":
				bad.landscape[-1].yaw = 90
		_check(not _checked(bad).ok, "malformed exact landscape selection fails closed " + mode)
	var graph: StadiumRecipeBoundary = StadiumLandscapeOwnedItems.graph_for(_layout)
	for item: String in ITEMS:
		var legal: Dictionary = StadiumLandscapeOwnedItems.row(
			_copies[item][0], item, StadiumLandscapeOwnedItems.sites(item)[0]
		)
		var live: Dictionary = legal.duplicate(true)
		live.position = StadiumStarterLayout.SITES["O-R1"]
		_operands = {
			"item": item,
			"site": legal.site,
			"legal_position": _v3(legal.position),
			"live_position": _v3(live.position),
			"boundary": graph.identity()
		}
		_check(
			(
				StadiumLandscapeOwnedItems._outside_play(legal, graph)
				and not StadiumLandscapeOwnedItems._outside_play(live, graph)
			),
			"actual complete-boundary reservation helper rejects a live-reachable footprint " + item
		)
		_ownership_cases.append(
			{
				"case": "live-reachable-rejection",
				"item": item,
				"site": legal.site,
				"legal_position": _v3(legal.position),
				"rejected_position": _v3(live.position),
				"boundary": graph.identity()
			}
		)


func _record(label: String, layout: Dictionary) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_operands = {
		"case": label,
		"revision": _paid.revision(),
		"snapshot_empty": snapshot.is_empty(),
		"cold_null": cold == null
	}
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
			and ClubCareer.same(snapshot.layout, layout)
		),
		"exact active snapshot authenticates " + label
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
		),
		"cold JSON journal replays exact copies and placement " + label
	)
	_records.append({"case": label, "layout": layout.duplicate(true), "snapshot": snapshot})


func _ownership() -> void:
	_phase = "paid-gates-prefix-and-inherited-base"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new(SEED, _credits, _progress)
	var old_entry: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"landscape work grants no extra starter copies"
	)
	for index in range(ITEMS.size()):
		var item: String = ITEMS[index]
		var entry: Dictionary = StadiumCatalog.item(item)
		var gate: Dictionary = EXPECTED_GATES[item]
		_check(
			(
				entry.blueprint_price == EXPECTED_PRICES[item][0]
				and entry.copy_price == EXPECTED_PRICES[item][1]
				and ClubCareer.same(entry.requires, gate)
			),
			"catalog price and progression threshold stay exact " + item
		)
		var below: Dictionary = gate.duplicate(true)
		below.seasons -= 1
		_check(
			not (
				StadiumLandscapeOwnedItems
				. quote(_paid.construction(), item, 1, "locked:" + item, below)
				. ok
			),
			"one season below authored unlock stays locked " + item
		)
		_check(
			(
				StadiumLandscapeOwnedItems
				. quote(_paid.construction(), item, 1, "eligible:" + item, gate)
				. ok
			),
			"exact authored unlock remains sufficient " + item
		)
		_buy(item, QUANTITIES[index], StadiumLandscapeOwnedItems.PRICE_VERSION)
	_check(
		not (
			StadiumLandscapeOwnedItems
			. quote(
				_paid.construction(), "ST-018", 1, "pond-wins-locked", {"seasons": 8, "wins": 23}
			)
			. ok
		),
		"pond still requires all twenty-four wins"
	)
	_check(
		(
			_paid.to_data().version == ClubAssetLedger.LANDSCAPE_VERSION
			and _paid.construction().copies.size() == 16
		),
		"ledger34 holds exactly thirteen paid landscape copies and three starters"
	)
	_check(
		StadiumLayoutSnapshot.matches(old_entry, _paid),
		"pre-purchase snapshot still authenticates its unchanged journal prefix"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		cold != null and ClubCareer.same(cold.to_data(), _paid.to_data()),
		"purchase-only landscape journal survives cold JSON replay"
	)
	_buy("ST-039", 1, StadiumPurchases.DISPLAY_VERSION)
	_buy("ST-037", 1, StadiumPurchases.LIGHT_VERSION)
	_buy("ST-015", 1, StadiumGroundPropsItems.PRICE_VERSION)
	var land: Dictionary = _paid.commit(
		{
			"id": "landscape-expanded",
			"rev": _paid.revision(),
			"op": "stadium_land",
			"tier": "expanded",
			"through": 40,
			"progress_through": 40,
			"price_version": StadiumLand.VERSION
		}
	)
	_check(land.ok, "ordinary Expanded purchase unlocks two landscape pockets")
	_base25 = StadiumFloodlightOwnedItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	_check(
		not _base25.is_empty() and _base25.version == 25,
		"historical floodlight wrapper upgrades without buying or selecting scenery"
	)
	if _base25.is_empty():
		return
	_base25.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
	_base25.props = [{"copy": _copies["ST-015"][0], "site": "PLANT-L1"}]
	_base25.lights = [{"copy": _copies["ST-037"][0], "site": "YLIGHT-FL"}]
	_check(
		_checked(_base25).ok and _apply(_base25),
		"nonempty historical obstacle, plant and lighting channels apply through their ordinary grammar"
	)
	_record("legacy-base25", _base25)
	_layout = StadiumLandscapeOwnedItems.upgrade(_base25, _paid.surface_owned())
	_check(
		(
			ClubCareer.same(StadiumLandscapeOwnedItems.base(_layout), _base25)
			and _layout.landscape.is_empty()
		),
		"landscape wrapper preserves every nested legacy channel exactly"
	)
	_hedges()
	_conflicts()
	for index in range(2):
		_layout = _placed(_layout, "ST-013", index, "TREE-L" if index == 0 else "TREE-R")
	for index in [0, 1, 2, 3, 5]:
		_layout = _placed(
			_layout, "ST-014", index, StadiumLandscapeOwnedItems.sites("ST-014")[index]
		)
	_layout = _placed(_layout, "ST-018", 0, "LAND-L")
	_layout = _placed(_layout, "ST-019", 0, "LAND-R", 90)
	var checked: Dictionary = _checked(_layout)
	_check(
		(
			checked.ok
			and checked.get("landscape_placements", []).size() == 9
			and checked.get("live_units", -1) == 1
		),
		"nine exact mixed landscape models coexist without spending live-object capacity"
	)
	if not checked.ok:
		return
	_check(
		(
			ClubCareer.same(StadiumLandscapeOwnedItems.base(_layout), _base25)
			and ClubCareer.same(StadiumLandscapeOwnedItems.prune(_layout), _layout)
		),
		"inherited pruning preserves all nine paid landscape rows and all older channels"
	)
	_negatives()
	_clearances()
	var treehouse: Dictionary = StadiumCatalog.item("ST-045")
	_check(
		(
			treehouse.blueprint_price == 560
			and treehouse.copy_price == 170
			and ClubCareer.same(treehouse.requires, {"seasons": 6, "wins": 18})
			and not _paid.construction().blueprints.has("ST-045")
			and StadiumLandscapeOwnedItems.row("unowned-treehouse", "ST-045", "TREE-L").is_empty()
		),
		"shade trees neither grant, host nor unlock the independent treehouse"
	)
	var balance: int = _paid.balance()
	_check(
		_apply(_layout) and _paid.balance() == balance,
		"ordinary draft and apply install family26 for free"
	)
	_record("mixed-landscape26", _layout)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not checked.get("night_qualified", true)
			and not str(checked.get("night_unqualified_reason", "")).is_empty()
			and StadiumSurfaceNightLayout.capture(_paid).is_empty()
		),
		"landscape remains explicitly daylight-only in ordinary fixture and night-candidate paths"
	)
	var swapped: Dictionary = StadiumLandscapeOwnedItems.store_copy(_layout, _copies["ST-013"][0])
	swapped = _placed(swapped, "ST-013", 2, "TREE-L")
	var swapped_check: Dictionary = _checked(swapped)
	_check(
		(
			swapped_check.ok
			and swapped_check.stored.has(_copies["ST-013"][0])
			and not swapped_check.stored.has(_copies["ST-013"][2])
			and _apply(swapped)
			and _paid.balance() == balance
		),
		"explicit Store then same-site paid-copy swap stores the exact old tree for free"
	)
	_record("exact-tree-copy-swap", swapped)
	_check(
		StadiumLayoutSnapshot.matches(_snapshot, _paid),
		"later free swap cannot rewrite the earlier frozen layout prefix"
	)
	var stored: Dictionary = swapped.duplicate(true)
	for raw: Dictionary in swapped.landscape:
		stored = StadiumLandscapeOwnedItems.store_copy(stored, raw.copy)
	var stored_check: Dictionary = _checked(stored)
	_check(
		(
			stored_check.ok
			and ClubCareer.same(stored, _base25)
			and stored.version == 25
			and _apply(stored)
			and _paid.balance() == balance
		),
		(
			"storing the last landscape copy restores exact historical base25 including its light "
			+ "and field state"
		)
	)
	_check( ITEMS.all( func(item: String) -> bool: return _copies[item].all(
					func(copy: String) -> bool: return stored_check.stored.has(copy) ) ),
		"all thirteen landscape copies remain owned in storage without refund or loss" )
	_record("all-landscape-stored-base25", stored)
	_check(
		_apply(_layout) and _paid.balance() == balance and _paid.construction().copies.size() == 19,
		"free remount keeps exactly sixteen paid copies plus three historical starters"
	)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	_record("cold-remount-landscape26", _layout)


func _camera_clearance(lab: PitchBatLab, placements: Array) -> void:
	_phase = "bounded-existing-batting-camera-clearance"
	var director: MatchCameraDirector = lab._camera_director
	var old_side: float = director._batter_side
	var old_shot: MatchCameraDirector.Shot = director.shot
	var old_motion: MatchCameraDirector.PresentationMotion = director._presentation_motion
	var old_progress: float = director._presentation_progress
	for left: bool in [false, true]:
		for zoom: bool in [false, true]:
			director.set_batter_handedness(left)
			director.set_shot(MatchCameraDirector.Shot.BATTING)
			director.set_presentation_motion(
				(
					MatchCameraDirector.PresentationMotion.ZOOM_IN
					if zoom
					else MatchCameraDirector.PresentationMotion.STILL
				),
				1.0
			)
			var pose: Transform3D = director._desired_transform(PitchBatLab.MOUND_ORIGIN, 0.0)
			var blocked: Array[String] = []
			for placed: Dictionary in placements:
				var box: AABB = StadiumLandscapeOwnedItems.bounds(placed)
				if (
					box.has_point(pose.origin)
					or (
						box.intersects_segment(pose.origin, PitchBatLab.MOUND_ORIGIN + Vector3.UP)
						!= null
					)
				):
					blocked.append(placed.site)
			_operands = {
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _v3(pose.origin),
				"blocked_sites": blocked
			}
			_check(
				blocked.is_empty(),
				"actual existing batting-camera origin and pitcher sightline clear whole landscape reservations"
			)
			_camera_cases.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress


func _preview_focus() -> void:
	_phase = "actual-workshop-preview-focus"
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(
		_layout, _paid.construction(), true, "expanded", null, null, _paid.surface_owned()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.night_eligible
		),
		"ordinary Workshop preview builds the exact paid daylight-only property"
	)
	var cases: Array[Dictionary] = []
	for item: String in ["ST-013", "ST-018", "ST-019"]:
		var copy: String = _copies[item][0]
		preview.focus_copy(copy)
		await get_tree().process_frame
		var viewport: Viewport = preview.camera.get_viewport()
		var rect: Rect2 = viewport.get_visible_rect()
		var box: AABB = preview.board_bounds.get(copy, AABB())
		var contained: bool = preview.board_bounds.has(copy) and rect.size.x > 0 and rect.size.y > 0
		for index in range(8):
			var point: Vector3 = box.get_endpoint(index)
			contained = (
				contained
				and not preview.camera.is_position_behind(point)
				and rect.has_point(preview.camera.unproject_position(point))
			)
		_operands = {
			"item": item,
			"copy": copy,
			"viewport": [rect.size.x, rect.size.y],
			"bounds": str(box),
			"eye": _v3(preview.camera.position)
		}
		_check(
			contained, "actual Workshop focus includes every complete reservation corner " + item
		)
		cases.append(
			{
				"item": item,
				"copy": copy,
				"all_eight_corners_in_frame": contained,
				"eye": _v3(preview.camera.position)
			}
		)
	_ui_cases.merge(
		{"native_preview": true, "focus_cases": cases, "night_eligible": preview.night_eligible}
	)
	preview.queue_free()
	await get_tree().process_frame
