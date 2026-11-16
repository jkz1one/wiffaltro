extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One bounded complete ST-054 qualification. Synthetic closed metrics; zero games.

const SEED: int = 160
const SITE: String = "OF-BLEACHER-A"
const INNER_SOURCE_SHA256: String = \
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75"
# source-derived successful bounded path; frozen before binding
const EXPECTED_NON_GEOMETRY_CHECKS: int = 493
const EXPECTED_PHASE_CHECKS: Dictionary = {
	"ownership": 77,
	"fit": 26,
	"workshop_controls": 5,
	"terrain_support": 293,
	"seated_sightlines": 59,
	"runtime_and_views": 26
}
const TARGETS: Array[Vector3] = [Vector3(0, 0.02, 0), Vector3(0, 0.02, 13.716)]

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Array[String] = []
var _inherited: Dictionary = {}
var _wall_copies: Array[String] = []
var _empty: Dictionary = {}
var _layout: Dictionary = {}
var _deeper_layout: Dictionary = {}
var _snapshot: Dictionary = {}
var _old_prefix: Dictionary = {}
var _last_draft: Dictionary = {}
var _last_apply: Dictionary = {}
var _records: Array[Dictionary] = []
var _receipts: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _fit_cases: Array[Dictionary] = []
var _support_matrix: Array[Dictionary] = []
var _sightline_matrix: Array[Dictionary] = []
var _tree_witness: Dictionary = {}
var _camera_cases: Array[Dictionary] = []
var _phase_counts: Dictionary = {}
var _ui_cases: Dictionary = {}
var _runtime: Dictionary = {}
var _model_checks: int = 0


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"OUTFIELD_BLEACHER_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "actual-locked-workshop-controls-without-season-save-claim"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	_check(
		StadiumOutfieldBleacherItemsUI.choices() == ["Stored", SITE],
		"actual Workshop offers Store and only the one fixed site"
	)
	var cards: Array[Dictionary] = []
	for index in range(2):
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumOutfieldBleacherItemsUI.card(
			menu, panel, _layout, _copies[index], _paid.revision(), false
		)
		var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		var choice: OptionButton = options[0] as OptionButton if options.size() == 1 else null
		var names: Array[String] = []
		if choice != null:
			for option in range(choice.item_count):
				names.append(choice.get_item_text(option))
		_check(
			(
				choice != null
				and choice.disabled
				and names == ["Stored", SITE]
				and choice.selected == (1 if index == 0 else 0)
				and choice.item_selected.get_connections().size() == 1
			),
			"actual locked card distinguishes each exact placed or stored paid copy " + str(index)
		)
		cards.append(
			{
				"copy": _copies[index],
				"names": names,
				"selected": choice.selected if choice != null else -1,
				"disabled": choice != null and choice.disabled,
				"connected_actions":
				choice.item_selected.get_connections().size() if choice != null else 0
			}
		)
	StadiumOutfieldBleacherItemsUI.purchases(menu, _paid, _layout, _paid.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	_check(
		(
			text.contains("450 blueprint + 120 per copy")
			and text.contains("2 owned copies")
			and text.contains("11 seasons / 32 recorded wins")
			and text.contains("near-wall ground blind area")
			and text.contains("stairs and landings")
		),
		(
			"actual Workshop states exact prices gate independent copies included access and "
			+ "bounded sightline limitation"
		)
	)
	var buys: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_meta("stadium_buy", "") == "ST-054"
	)
	_check(
		buys.size() == 1 and (buys[0] as Button).disabled,
		"locked ordinary purchase control cannot bypass season policy"
	)
	_ui_cases = {
		"cards": cards,
		"copy_count_text": text,
		"ledger_paid_purchases_executed": true,
		"ledger_layout_transactions_executed": true,
		"accepted_seasonstate_purchase_executed": false,
		"editable_callback_executed": false,
		"native_preview": false,
		"focus_cases": [],
		"night_eligible": false
	}
	menu.free()
	app.free()


func _apply(layout: Dictionary) -> bool:
	_last_draft = {
		"id": "outfield-draft:%d" % _paid.revision(),
		"rev": _paid.revision(),
		"op": "stadium_draft",
		"layout": layout
	}
	var draft: Dictionary = _paid.commit(_last_draft)
	if not draft.ok:
		_operands = {"stage": "draft", "error": draft.get("error", "")}
		return false
	_last_apply = {
		"id": "outfield-apply:%d" % _paid.revision(),
		"rev": _paid.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumOwnedLayout.geometry(_paid.view().land, layout)
	}
	var applied: Dictionary = _paid.commit(_last_apply)
	_operands = {"stage": "apply", "error": applied.get("error", "")}
	return applied.ok


func _checked(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"outfield_bleachers": layout.get("outfield_bleachers", [])
	}
	return result


func _corners(box: AABB) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(box.position.x, box.position.z),
			Vector2(box.end.x, box.position.z),
			Vector2(box.end.x, box.end.z),
			Vector2(box.position.x, box.end.z)
		]
	)


func _intersection_area(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var area: float = 0
	for part: PackedVector2Array in Geometry2D.intersect_polygons(first, second):
		var signed_area: float = 0
		for index in range(part.size()):
			signed_area += part[index].cross(part[(index + 1) % part.size()])
		area += absf(signed_area) * 0.5
	return area


func _polygon_gap(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var gap: float = INF
	for a in range(first.size()):
		for b in range(second.size()):
			gap = minf(
				gap,
				StadiumLandscapeOwnedItems._segment_distance(
					first[a],
					first[(a + 1) % first.size()],
					second[b],
					second[(b + 1) % second.size()]
				)
			)
	return gap


func _clearance(box: AABB, graph: StadiumRecipeBoundary) -> Dictionary:
	var footprint: PackedVector2Array = _corners(box)
	var polygon: PackedVector2Array = graph.polygon()
	var distance: float = _polygon_gap(footprint, polygon)
	var slab_distance: float = INF
	var overlap: float = 0
	for index in range(polygon.size()):
		var next: int = (index + 1) % polygon.size()
		var slab: PackedVector2Array = PackedVector2Array(
			[polygon[index], polygon[next], graph.outer_vertex(next), graph.outer_vertex(index)]
		)
		slab_distance = minf(slab_distance, _polygon_gap(footprint, slab))
		overlap += _intersection_area(footprint, slab)
	return {"graph_line_m": distance, "slab_gap_m": slab_distance, "slab_overlap_m2": overlap}


func _place(layout: Dictionary, copy: String, site: String = SITE) -> Dictionary:
	return StadiumOutfieldBleacherItems.place(
		layout, _paid.construction(), copy, site, 0.0, _paid.surface_owned()
	)


func _record(label: String, layout: Dictionary) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
			and ClubCareer.same(snapshot.layout, layout)
		),
		"exact frozen owned-parent snapshot " + label
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
		),
		"cold journal preserves exact purchased identity and placement " + label
	)
	_records.append(
		{
			"case": label,
			"layout": layout.duplicate(true),
			"paid_revision": _paid.revision(),
			"snapshot_version": snapshot.get("version", -1),
			"snapshot_sha256": JSON.stringify(snapshot, "", true, true).sha256_text(),
			"cold_exact": cold != null and StadiumLayoutSnapshot.matches(snapshot, cold)
		}
	)


func _refused(label: String, layout: Dictionary, stale: bool = false) -> void:
	var before: Dictionary = _paid.to_data().duplicate(true)
	var result: Dictionary = _paid.commit(
		{
			"id": "outfield-refuse:" + label,
			"rev": _paid.revision() - (1 if stale else 0),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	var unchanged: bool = ClubCareer.same(before, _paid.to_data())
	_check(
		not result.ok and unchanged,
		"ordinary transaction refuses without changing paid journal " + label
	)
	_ownership_cases.append(
		{
			"case": label,
			"rejected": not result.ok,
			"unchanged": unchanged,
			"error": result.get("error", "")
		}
	)


func _fit_and_conflicts() -> void:
	_phase = "full-reservation-current-walls-and-store-first-sightline-exclusion"
	var row: Dictionary = StadiumOutfieldBleacherItems.row(_copies[0], "ST-054", SITE)
	var box: AABB = StadiumOutfieldBleacherItems.bounds(row)
	_check(
		(
			box == AABB(Vector3(-25, 0, 32), Vector3(16, 8.6, 8))
			and row.position == Vector3(-17, 0, 36)
			and row.yaw == 0
		),
		"fixed full reservation includes all elevated seats stairs landings and supports"
	)
	for tier: String in ["backyard", "expanded", "club", "mogul"]:
		var allowed: bool = tier in ["club", "mogul"]
		_check(
			(
				_checked(_layout, tier).ok == allowed
				and StadiumProperty.contains(tier, box) == allowed
			),
			"whole reservation preserves exact Club-plus property gate " + tier
		)
	for shape: String in ["straight", "deeper_center"]:
		var graph: StadiumRecipeBoundary = StadiumOutfieldBleacherItems.graph_for(
			_layout if shape == "straight" else _deeper_layout
		)
		var clearance: Dictionary = _clearance(box, graph)
		_check(
			graph._shape == shape and StadiumOutfieldBleacherItems.wall_eligible(graph),
			"exact currently selected owned wall graph is eligible " + shape
		)
		_check(
			(
				StadiumOutfieldBleacherItems._outside_play(box, graph)
				and clearance.graph_line_m > 0
				and clearance.slab_gap_m > 0
				and clearance.slab_overlap_m2 <= 0.000001
			),
			"complete current boundary line and miter slabs clear full reservation " + shape
		)
		_fit_cases.append(
			{
				"case": shape,
				"bounds": str(box),
				"graph_line_m": clearance.graph_line_m,
				"slab_gap_m": clearance.slab_gap_m,
				"slab_overlap_m2": clearance.slab_overlap_m2,
				"wall_eligible": true
			}
		)
	var dormant: StadiumHeightBoundary = StadiumHeightBoundary.candidate("left_loft")
	var taller: bool = false
	for segment: Dictionary in dormant.segments():
		taller = taller or float(segment.height) == 4.875
	_check(
		(
			taller
			and not StadiumAdvancedWallLayout.RUNTIME_READY
			and not StadiumOutfieldBleacherItems.wall_eligible(dormant)
			and not StadiumOutfieldBleacherItems.wall_eligible(null)
		),
		"existing dormant 4.875 m wall graph and absent graph remain ineligible without widening route"
	)
	_check(
		not StadiumOutfieldBleacherItems._outside_play(
			AABB(Vector3(-2, 0, 8), Vector3(16, 8.6, 8)),
			StadiumOutfieldBleacherItems.graph_for(_layout)
		),
		"field-reaching complete reservation fails closed"
	)
	for model: String in ["manual-v2", "electronic-v2"]:
		var legacy: Dictionary = _layout.duplicate(true)
		legacy["scoreboards"] = [
			{
				"copy": _inherited["ST-039"],
				"item": "ST-039" if model == "manual-v2" else "ST-090",
				"model": model,
				"site": "BOARD-LEFT-v2"
			}
		]
		_check(
			not _checked(legacy).ok,
			"separate legacy scoreboard branch gains no family34 eligibility " + model
		)
	var inventory: Dictionary = _paid.construction().to_data().duplicate(true)
	var first: Dictionary = _place(_empty, _copies[0])
	var tree_only: Dictionary = StadiumLandscapeOwnedItems.place(
		_empty, _paid.construction(), _inherited["ST-013"], "TREE-L"
	)
	for reverse: bool in [false, true]:
		var initial: Dictionary = first if reverse else tree_only
		_check(
			_checked(initial).ok and _apply(initial),
			"each independently paid occupant is accepted alone before conflict " + str(reverse)
		)
		var conflict: Dictionary = (
			StadiumLandscapeOwnedItems.place(
				first, _paid.construction(), _inherited["ST-013"], "TREE-L"
			)
			if reverse
			else _place(tree_only, _copies[0])
		)
		_check(
			(
				not _checked(conflict).ok
				and conflict.outfield_bleachers == first.outfield_bleachers
				and conflict.landscape == tree_only.landscape
			),
			(
				"TREE-L sightline exclusion rejects both orders without losing either paid row "
				+ str(reverse)
			)
		)
		_refused("tree-sightline-order:" + str(reverse), conflict)
		var restored: Dictionary = (
			StadiumOutfieldBleacherItems.store_copy(conflict, _copies[0])
			if reverse
			else StadiumLandscapeOwnedItems.store_copy(conflict, _inherited["ST-013"])
		)
		var expected_restored: Dictionary = conflict.duplicate(true)
		expected_restored["outfield_bleachers" if reverse else "landscape"] = []
		_operands = {
			"reverse": reverse, "expected_restored": expected_restored, "actual_restored": restored
		}
		_check(
			(
				ClubCareer.same(restored, expected_restored)
				and _checked(restored).ok
				and _apply(restored)
				and ClubCareer.same(_paid.construction().to_data(), inventory)
			),
			(
				(
					"explicit Store first removes only its exact channel occupant and preserves every "
					+ "inherited channel and paid copy "
				)
				+ str(reverse)
			)
		)
		_record("tree-store-first:" + str(reverse), restored)
	_check(
		_apply(_layout) and ClubCareer.same(_paid.construction().to_data(), inventory),
		"original complete selected bleacher and SCORE-SMALL scene is restored after both tree orders"
	)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)


func _buy(item: String, price_version: int, cost: int, quantity: int = 1) -> Array[String]:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "outfield-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": price_version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var balance: int = _paid.balance()
	var count: int = _paid.construction().copies.size()
	var result: Dictionary = _paid.commit(command)
	var copies: Array[String] = []
	var exact: bool = result.ok
	for index in range(quantity):
		var copy: String = "purchase:outfield-buy:%d:%d" % [revision, index]
		copies.append(copy)
		exact = (
			exact
			and ClubCareer.same(
				_paid.construction().copies.get(copy, {}),
				{
					"item": item,
					"paid": StadiumCatalog.item(item).copy_price,
					"source": "purchase-v1"
				}
			)
		)
	_operands = {
		"item": item,
		"revision": revision,
		"error": result.get("error", ""),
		"cost": cost,
		"quantity": quantity
	}
	_check(
		(
			result.ok
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + quantity
		),
		"ordinary exact paid purchase adds only requested complete copies " + item
	)
	_check(
		exact and _paid.construction().blueprints.has(item),
		"every exact copy receipt preserves item copy price and paid source " + item
	)
	_check(
		(
			_paid.commit(command).get("replayed", false)
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + quantity
		),
		"exact paid retry neither charges nor duplicates " + item
	)
	_receipts.append(
		{
			"copies": copies.duplicate(),
			"item": item,
			"command_revision": revision,
			"price_version": price_version,
			"quantity": quantity,
			"charged": cost,
			"copy_paid": StadiumCatalog.item(item).copy_price,
			"source": "purchase-v1",
			"retry_replayed": result.ok and exact
		}
	)
	return copies if result.ok and exact else []


func _negatives(first: Dictionary) -> void:
	_check(
		(
			StadiumOutfieldBleacherItems.sites() == [SITE]
			and StadiumOutfieldBleacherItems.yaws() == [0]
		),
		"only the exact fixed site and zero yaw are offered"
	)
	for copy: String in ["starter-v1:ST-003", _inherited["ST-013"], "purchase:foreign:0"]:
		var bad: Dictionary = _empty.duplicate(true)
		bad.outfield_bleachers = [{"copy": copy, "site": SITE}]
		_check(
			not _checked(bad).ok and ClubCareer.same(_place(_empty, copy), _empty),
			"wrong-item or foreign identity cannot become an outfield bleacher " + copy
		)
	for kind: String in [
		"duplicate-copy",
		"second-copy",
		"unknown-site",
		"unknown-field",
		"wrong-version",
		"wrong-family",
		"missing-copy",
		"non-array"
	]:
		var bad: Dictionary = first.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.outfield_bleachers.append(bad.outfield_bleachers[0].duplicate(true))
			"second-copy":
				bad.outfield_bleachers.append({"copy": _copies[1], "site": SITE})
			"unknown-site":
				bad.outfield_bleachers[0].site = "OF-BLEACHER-B"
			"unknown-field":
				bad.outfield_bleachers[0]["yaw"] = 0
			"wrong-version":
				bad.version = 33
			"wrong-family":
				bad.family = "reference-starter-v1"
			"missing-copy":
				bad.outfield_bleachers[0].erase("copy")
			"non-array":
				bad.outfield_bleachers = {}
		_check(not _checked(bad).ok, "exact bounded grammar rejects " + kind)
	for reverse: bool in [false, true]:
		var conflict: Dictionary = _place(
			_place(_empty, _copies[1] if reverse else _copies[0]),
			_copies[0] if reverse else _copies[1]
		)
		_check(
			conflict.outfield_bleachers.size() == 2 and not _checked(conflict).ok,
			"single site refuses both copy orders without silently storing either occupant"
		)
		_refused("same-site-occupancy:" + str(reverse), conflict)
	_check(
		ClubCareer.same(_place(first, _copies[0]), first),
		"current exact-copy reselect is idempotent"
	)
	for yaw: float in [45.0, 180.0, INF]:
		_check(
			(
				StadiumOutfieldBleacherItems.row(_copies[0], "ST-054", SITE, yaw).is_empty()
				and ClubCareer.same(
					StadiumOutfieldBleacherItems.place(
						_empty, _paid.construction(), _copies[0], SITE, yaw
					),
					_empty
				)
			),
			"arbitrary or nonfinite rotation cannot escape fixed reservation " + str(yaw)
		)
	_refused("stale-current-copy-draft", first, true)
	var foreign: Dictionary = first.duplicate(true)
	foreign.outfield_bleachers[0].copy = "purchase:foreign:0"
	_refused("foreign-current-copy-draft", foreign)
	_check(
		(
			ClubCareer.same(StadiumOutfieldBleacherItems.prune(first), first)
			and StadiumOutfieldBleacherItems.base(first).version == 33
		),
		"pruning preserves current copy and exact inherited landmark route"
	)


func _score_layout(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	result.displays = [{"copy": _inherited["ST-039"], "site": "SCORE-SMALL"}]
	return result


func _ownership() -> void:
	_phase = "exact-paid-copy-gates-and-lifecycle"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 10, "hits": 4})
	_check(
		StadiumCareerProgress.valid(_progress, _credits),
		"explicit synthetic closed metrics qualify without claiming earned career progress"
	)
	_paid = ClubAssetLedger.new_club(SEED, _credits, _progress)
	var starter: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"adoption grants no outfield bleacher copies"
	)
	var entry: Dictionary = StadiumCatalog.item("ST-054")
	var gate: Dictionary = {"seasons": 11, "wins": 32}
	_check(
		(
			entry.blueprint_price == 450
			and entry.copy_price == 120
			and ClubCareer.same(entry.requires, gate)
		),
		"unchanged ST-054 prices and exact S11 W32 earned gate"
	)
	_check(
		(
			StadiumOutfieldBleacherItems.PRICE_VERSION == 25
			and (
				StadiumPurchases
				. quote(
					_paid.construction(),
					"ST-054",
					1,
					"outfield-gate",
					StadiumOutfieldBleacherItems.PRICE_VERSION,
					gate
				)
				. ok
			)
		),
		"current price25 route accepts the exact unlock threshold"
	)
	for key: String in gate:
		var below: Dictionary = gate.duplicate(true)
		below[key] -= 1
		_check(
			not (
				StadiumPurchases
				. quote(
					_paid.construction(),
					"ST-054",
					1,
					"outfield-below:" + key,
					StadiumOutfieldBleacherItems.PRICE_VERSION,
					below
				)
				. ok
			),
			"each just-below unlock operand refuses " + key
		)
	_check(
		not (
			StadiumPurchases
			. quote(
				_paid.construction(),
				"ST-054",
				1,
				"outfield-old",
				StadiumLandmarkItems.PRICE_VERSION,
				gate
			)
			. ok
		),
		"older landmark price route cannot buy ST-054"
	)
	for cost: int in [570, 120]:
		var purchased: Array[String] = _buy(
			"ST-054", StadiumOutfieldBleacherItems.PRICE_VERSION, cost
		)
		if purchased.size() != 1:
			return
		_copies.append(purchased[0])
	for control: Array in [
		["ST-013", StadiumLandscapeOwnedItems.PRICE_VERSION, 340],
		["ST-039", StadiumPurchases.DISPLAY_VERSION, 440]
	]:
		var purchased: Array[String] = _buy(control[0], control[1], control[2])
		if purchased.size() != 1:
			return
		_inherited[control[0]] = purchased[0]
	_wall_copies = _buy("ST-024", StadiumWallItems.PRICE_VERSION, 1020, 22)
	_check(
		(
			_wall_copies.size() == StadiumWallRecipes.back("deeper_center", "ST-024").size()
			and _paid.construction().copies.size() == 29
			and StadiumLayoutSnapshot.matches(starter, _paid)
		),
		(
			"four complete scenery purchases and one exact 22-panel wall purchase preserve starter "
			+ "prefix without extras"
		)
	)
	if _wall_copies.size() != 22 or _paid.construction().copies.size() != 29:
		return
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "outfield-land:" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(
			result.ok and _paid.construction().copies.size() == 29,
			"ordinary land purchase grants no construction copies " + tier
		)
	if _paid.view().land != "mogul":
		return
	var base33: Dictionary = StadiumLandmarkItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	var inherited_ok: bool = _checked(base33).ok and _apply(base33)
	_check(inherited_ok, "accepted empty landmark family33 applies before outfield adoption")
	if not inherited_ok:
		return
	_record("inherited-family33", base33)
	_old_prefix = StadiumLayoutSnapshot.capture(_paid)
	_empty = StadiumOutfieldBleacherItems.upgrade(base33, _paid.surface_owned())
	var empty_ok: bool = (
		_empty.version == 34
		and _empty.outfield_bleachers.is_empty()
		and ClubCareer.same(StadiumOutfieldBleacherItems.base(_empty), base33)
		and _checked(_empty).ok
		and _apply(_empty)
	)
	_check(empty_ok, "empty family34 preserves every inherited channel and applies")
	if not empty_ok:
		return
	_record("empty-outfield-family", _empty)
	_bleacher_paid_placement_checks()


func _bleacher_paid_placement_checks() -> void:
	var balance: int = _paid.balance()
	var first: Dictionary = _place(_empty, _copies[0])
	var first_ok: bool = _checked(first).ok and _apply(first)
	_check(
		first_ok and _paid.balance() == balance,
		"one exact complete paid assembly applies at its fixed site"
	)
	if not first_ok:
		return
	_record("first-complete-copy", first)
	var stored: Dictionary = StadiumOutfieldBleacherItems.store_copy(first, _copies[0])
	_check(
		(
			ClubCareer.same(stored, _empty)
			and _checked(stored).stored.has(_copies[0])
			and _apply(stored)
		),
		"Store vacates site while keeping the exact whole purchased assembly"
	)
	_record("whole-copy-stored", stored)
	_check(
		(
			ClubCareer.same(_place(stored, _copies[0]), first)
			and _apply(first)
			and _paid.balance() == balance
		),
		"same exact complete copy remounts without another charge"
	)
	_record("same-whole-copy-remounted", first)
	var swapped: Dictionary = _place(
		StadiumOutfieldBleacherItems.store_copy(first, _copies[0]), _copies[1]
	)
	_check(
		_checked(swapped).ok and _checked(swapped).stored.has(_copies[0]) and _apply(swapped),
		"explicit Store first swaps independently paid whole copies without displacement"
	)
	_record("store-first-copy-swap", swapped)
	_negatives(first)
	_layout = _score_layout(first)
	var selected: Dictionary = StadiumWallLayout.propose(
		_layout.walls, _paid.construction(), "back", "ST-024", "deeper_center"
	)
	_check(
		selected.ok and selected.walls.back.copies.size() == 22,
		"ordinary complete-wall proposal consumes exact purchased deeper-center manifest"
	)
	if not selected.ok:
		_layout = {}
		return
	_deeper_layout = _layout.duplicate(true)
	_deeper_layout.walls = selected.walls
	var deeper_ok: bool = _checked(_deeper_layout).ok and _apply(_deeper_layout)
	_check(
		deeper_ok,
		"actual complete deeper-center selected-wall plan applies with ST-054 and current SCORE-SMALL"
	)
	if not deeper_ok:
		_layout = {}
		return
	_record("paid-deeper-center-boundary", _deeper_layout)
	_check(
		(
			_checked(_layout).ok
			and _apply(_layout)
			and _paid.balance() == balance
			and _paid.to_data().version == 42
			and _paid.construction().copies.size() == 29
		),
		"final single-bleacher current-copy plan applies on ledger42 without another charge"
	)
	var retry_before: Dictionary = _paid.to_data().duplicate(true)
	_check(
		(
			_paid.commit(_last_draft).get("replayed", false)
			and _paid.commit(_last_apply).get("replayed", false)
			and ClubCareer.same(_paid.to_data(), retry_before)
		),
		"exact draft and apply retries preserve every paid copy and the entire journal"
	)
	_record("final-straight-wall-bleacher", _layout)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		(
			StadiumLayoutSnapshot.matches(_old_prefix, _paid)
			and cold != null
			and StadiumLayoutSnapshot.matches(_old_prefix, cold)
		),
		"accepted landmark family33 prefix remains authenticated warm and cold"
	)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not _checked(_layout).get("night_qualified", true)
		),
		"frozen complete bleacher fixture retains daylight-only admission"
	)


func _project_rect(camera: Camera3D, box: AABB) -> Rect2:
	var rect: Rect2 = Rect2()
	var started: bool = false
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if camera.is_position_behind(point):
			continue
		var pixel: Vector2 = camera.unproject_position(point)
		if not started:
			rect = Rect2(pixel, Vector2.ZERO)
			started = true
		else:
			rect = rect.expand(pixel)
	return rect


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
