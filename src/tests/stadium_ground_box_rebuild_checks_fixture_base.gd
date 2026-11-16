extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One finite ST-052 exact-paid-section, final-layout and registered-property gate. Zero games.

const SEED: int = 152
const SITES: Array[String] = ["BOX-L", "BOX-R"]
const INNER_SOURCE_SHA256: String = \
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75"
# Reachable success path: ownership80 + fit72 + UI5 + terrain84 + runtime/views24
# plus entry2, model-budget1 and completion4 = 272 non-geometry checks.
const EXPECTED_NON_GEOMETRY_CHECKS: int = 272
const EXPECTED_PHASE_CHECKS: Dictionary = {
	"ownership": 80,
	"fit": 72,
	"workshop_controls": 5,
	"terrain_support": 84,
	"runtime_and_views": 24
}

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Array[String] = []
var _neighbors: Dictionary = {}
var _seat_copy: String = ""
var _empty: Dictionary = {}
var _layout: Dictionary = {}
var _snapshot: Dictionary = {}
var _old_prefix: Dictionary = {}
var _records: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _fit_cases: Array[Dictionary] = []
var _support_matrix: Array[Dictionary] = []
var _phase_counts: Dictionary = {}
var _ui_cases: Dictionary = {}
var _runtime: Dictionary = {}
var _model_checks: int = 0


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"GROUND_BOX_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "actual-three-choice-workshop-and-visible-copy-count"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	_check(
		StadiumGroundBoxItemsUI.choices() == ["Stored", "BOX-L", "BOX-R"],
		"ground-box control exposes exactly Stored plus the fixed left and right reservations"
	)
	var cards: Array[Dictionary] = []
	for index in range(_copies.size()):
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumGroundBoxItemsUI.card(menu, panel, _layout, _copies[index], _paid.revision(), false)
		var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		var choice: OptionButton = options[0] as OptionButton if options.size() == 1 else null
		var names: Array[String] = []
		if choice != null:
			for option in range(choice.item_count):
				names.append(choice.get_item_text(option))
		_operands = {
			"copy": _copies[index],
			"names": names,
			"selected": choice.selected if choice != null else -1
		}
		_check(
			(
				choice != null
				and choice.disabled
				and names == StadiumGroundBoxItemsUI.choices()
				and choice.selected == index + 1
			),
			"actual locked exact-copy card shows its independently selected section " + str(index)
		)
		cards.append(
			{
				"copy": _copies[index],
				"names": names,
				"selected": choice.selected if choice != null else -1,
				"disabled": choice != null and choice.disabled
			}
		)
	StadiumGroundBoxItemsUI.purchases(menu, _paid, _layout, _paid.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	_operands = {"text": text}
	_check(
		(
			text.contains("520")
			and text.contains("160")
			and text.contains("2 owned")
			and text.to_lower().contains("section")
		),
		"actual Workshop describes complete sections and exact owned count with unchanged prices"
	)
	var buys: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_meta("stadium_buy", "") == "ST-052"
	)
	_check(
		buys.size() == 1 and (buys[0] as Button).disabled,
		"locked ordinary purchase button cannot bypass season policy"
	)
	_ui_cases = {
		"cards": cards,
		"copy_count_text": text,
		"ledger_paid_purchases_executed": true,
		"accepted_seasonstate_purchase_executed": false
	}
	menu.free()
	app.free()


func _checked(layout: Dictionary, tier: String = "expanded") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"ground_boxes": layout.get("ground_boxes", [])
	}
	return result


func _clearance(box: AABB, graph: StadiumRecipeBoundary) -> Dictionary:
	var footprint: PackedVector2Array = PackedVector2Array(
		[
			Vector2(box.position.x, box.position.z),
			Vector2(box.end.x, box.position.z),
			Vector2(box.end.x, box.end.z),
			Vector2(box.position.x, box.end.z)
		]
	)
	var polygon: PackedVector2Array = graph.polygon()
	var distance: float = INF
	var overlap: float = 0
	for index in range(polygon.size()):
		var next: int = (index + 1) % polygon.size()
		for edge in range(4):
			distance = minf(
				distance,
				StadiumLandscapeOwnedItems._segment_distance(
					footprint[edge], footprint[(edge + 1) % 4], polygon[index], polygon[next]
				)
			)
		var slab: PackedVector2Array = PackedVector2Array(
			[polygon[index], polygon[next], graph.outer_vertex(next), graph.outer_vertex(index)]
		)
		for part: PackedVector2Array in Geometry2D.intersect_polygons(footprint, slab):
			var area: float = 0
			for point in range(part.size()):
				area += part[point].cross(part[(point + 1) % part.size()])
			overlap += absf(area) * 0.5
	return {"graph_line_m": distance, "slab_overlap_m2": overlap}


func _has_neighbor(layout: Dictionary, item: String) -> bool:
	for row: Dictionary in (
		layout.get("hosts", []) if item == "ST-029" else layout.get("boundary", [])
	):
		if row.copy == _neighbors[item]:
			return true
	return false


func _neighbor(layout: Dictionary, item: String, site: String, store: bool = false) -> Dictionary:
	var copy: String = _neighbors[item]
	if item == "ST-029":
		return StadiumStraightItemsUI.select(
			layout,
			_paid.construction(),
			copy,
			{} if store else {"copy": copy, "site": site, "lower": "", "concourse": ""}
		)
	return StadiumBoundaryItems.select(
		layout,
		_paid.construction(),
		copy,
		{} if store else {"copy": copy, "item": item, "site": site, "host": ""}
	)


func _place(layout: Dictionary, copy: String, site: String) -> Dictionary:
	return StadiumGroundBoxItems.place(
		layout, _paid.construction(), copy, site, 0.0, _paid.surface_owned()
	)


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func _fit_and_conflicts() -> void:
	_phase = "full-world-reservations-graph-line-and-actual-slabs"
	_check(
		not _checked(_layout, "backyard").ok,
		"occupied complete ground boxes require Expanded or larger property"
	)
	var graph: StadiumRecipeBoundary = StadiumGroundBoxItems.graph_for(_layout)
	var unsupported: Dictionary = _layout.duplicate(true)
	unsupported.walls.back = {"shape": "unapproved-box-boundary", "item": "ST-008", "copies": []}
	_check(
		(
			not _checked(unsupported).ok
			and not StadiumGroundBoxItems._outside_play(
				StadiumGroundBoxItems.bounds(
					StadiumGroundBoxItems.row(_copies[0], "ST-052", SITES[0])
				),
				null
			)
		),
		"unsupported selected boundary and unavailable complete graph fail closed"
	)
	for index in range(2):
		var row: Dictionary = StadiumGroundBoxItems.row(_copies[index], "ST-052", SITES[index])
		var box: AABB = StadiumGroundBoxItems.bounds(row)
		_operands = {
			"site": row.site, "position": _v3(row.position), "yaw": row.yaw, "bounds": str(box)
		}
		_check(
			(
				row.position == Vector3(-18.2 if index == 0 else 18.2, 0, 3)
				and box.size.is_equal_approx(Vector3(4, 2.2, 5.5))
				and box.get_center().is_equal_approx(row.position + Vector3(0, 1.1, 0))
			),
			(
				(
					"complete unscaled world reservation is exactly four by five-point-five by at most "
					+ "two-point-two "
				)
				+ row.site
			)
		)
		var clearance: Dictionary = _clearance(box, graph)
		_operands = {"site": row.site, "clearance": clearance}
		_check(
			(
				clearance.graph_line_m >= 1.5
				and clearance.slab_overlap_m2 <= 0.000001
				and StadiumGroundBoxItems._outside_play(box, graph)
			),
			(
				"whole reservation meets current graph-line setback and actual slab no-overlap "
				+ row.site
			)
		)
		for tier: String in ["expanded", "club", "mogul"]:
			_check(
				StadiumProperty.contains(tier, box) and _checked(_layout, tier).ok,
				"complete paired sections fit unchanged land tier " + tier + ":" + row.site
			)
		var overhang: AABB = box
		overhang.position.x = StadiumProperty.BOUNDS.expanded.end.x - 1
		_check(
			not StadiumProperty.contains("expanded", overhang),
			"whole-reservation property overhang fails closed " + row.site
		)
		var infield: AABB = box
		infield.position = Vector3(-2, 0, 8)
		_check(
			not StadiumGroundBoxItems._outside_play(infield, graph),
			"whole-reservation field-interior helper fails closed " + row.site
		)
		_fit_cases.append(
			{
				"case": "fixed-full-reservation",
				"site": row.site,
				"position": _v3(row.position),
				"bounds": str(box),
				"clearance": clearance
			}
		)
	_phase = "final-layout-same-side-exclusions-in-both-placement-orders"
	for side: String in ["L", "R"]:
		var box_site: String = "BOX-" + side
		var opposite: String = "BOX-R" if side == "L" else "BOX-L"
		for neighbor: Dictionary in [
			{"item": "ST-029", "site": "BASE-" + side + "1"},
			{"item": "ST-029", "site": "BASE-" + side + "2"},
			{"item": "ST-032", "site": "DUGOUT-" + side},
			{"item": "ST-074", "site": "DUGOUT-" + side}
		]:
			var other_only: Dictionary = _neighbor(_empty, neighbor.item, neighbor.site)
			_check(
				_checked(other_only, "club").ok,
				"independently owned neighbor remains legal by itself " + str(neighbor)
			)
			var neighbor_first: Dictionary = _place(other_only, _copies[0], box_site)
			var box_first: Dictionary = _neighbor(
				_place(_empty, _copies[0], box_site), neighbor.item, neighbor.site
			)
			var first_check: Dictionary = _checked(neighbor_first, "club")
			var second_check: Dictionary = _checked(box_first, "club")
			_operands = {
				"box": box_site,
				"neighbor": neighbor,
				"neighbor_first_error": first_check.get("error", ""),
				"box_first_error": second_check.get("error", "")
			}
			_check(
				(
					not first_check.ok
					and not second_check.ok
					and ClubCareer.same(neighbor_first, box_first)
					and box_first.ground_boxes.size() == 1
					and _has_neighbor(box_first, neighbor.item)
				),
				(
					(
						"final combined layout rejects same-side conflict in both orders without silently "
						+ "removing either copy "
					)
					+ str(neighbor)
				)
			)
			var opposite_first: Dictionary = _place(other_only, _copies[0], opposite)
			var opposite_second: Dictionary = _neighbor(
				_place(_empty, _copies[0], opposite), neighbor.item, neighbor.site
			)
			_check(
				(
					_checked(opposite_first, "club").ok
					and _checked(opposite_second, "club").ok
					and ClubCareer.same(opposite_first, opposite_second)
				),
				"opposite side remains independent in both placement orders " + str(neighbor)
			)
			var store_box: Dictionary = StadiumGroundBoxItems.store_copy(box_first, _copies[0])
			_check(
				(
					_checked(store_box, "club").ok
					and _checked(store_box, "club").stored.has(_copies[0])
					and _has_neighbor(store_box, neighbor.item)
				),
				(
					"explicit Store of the exact box permits the selected same-side neighbor "
					+ str(neighbor)
				)
			)
			var empty_again: Dictionary = _neighbor(store_box, neighbor.item, neighbor.site, true)
			_check(
				(
					_checked(empty_again, "club").ok
					and empty_again.ground_boxes.is_empty()
					and not _has_neighbor(empty_again, neighbor.item)
				),
				(
					"later neighbor Store does not automatically reinstall the stored box "
					+ str(neighbor)
				)
			)
			var store_neighbor: Dictionary = _neighbor(
				neighbor_first, neighbor.item, neighbor.site, true
			)
			_check(
				(
					_checked(store_neighbor, "club").ok
					and _checked(store_neighbor, "club").stored.has(_neighbors[neighbor.item])
					and store_neighbor.ground_boxes.size() == 1
				),
				(
					"inverse explicit Store permits the same exact box without consuming its neighbor "
					+ str(neighbor)
				)
			)
			var no_restore: Dictionary = StadiumGroundBoxItems.store_copy(
				store_neighbor, _copies[0]
			)
			_check(
				(
					_checked(no_restore, "club").ok
					and no_restore.ground_boxes.is_empty()
					and not _has_neighbor(no_restore, neighbor.item)
				),
				(
					"later box Store never automatically reinstalls the stored neighbor "
					+ str(neighbor)
				)
			)
			_fit_cases.append(
				{
					"case": "final-layout-both-orders-store-first",
					"box_site": box_site,
					"box_copy": _copies[0],
					"neighbor": neighbor,
					"neighbor_copy": _neighbors[neighbor.item],
					"same_side_rejected": not first_check.ok and not second_check.ok,
					"opposite_side_valid": _checked(opposite_first, "club").ok,
					"tier": "club",
					"installed_claim": false
				}
			)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "ground-box-draft:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		_operands = {"stage": "draft", "error": draft.get("error", "")}
		return false
	var applied: Dictionary = _paid.commit(
		{
			"id": "ground-box-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry(_paid.view().land, layout)
		}
	)
	_operands = {"stage": "apply", "error": applied.get("error", "")}
	return applied.ok


func _buy(item: String, price_version: int, cost: int) -> String:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "ground-box-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": 1,
		"price_version": price_version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var balance: int = _paid.balance()
	var count: int = _paid.construction().copies.size()
	var result: Dictionary = _paid.commit(command)
	_operands = {"item": item, "revision": revision, "error": result.get("error", ""), "cost": cost}
	_check(
		(
			result.ok
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"ordinary paid command adds exactly one purchased complete copy " + item
	)
	_check(
		(
			_paid.commit(command).get("replayed", false)
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"exact paid retry neither charges nor duplicates " + item
	)
	return "purchase:ground-box-buy:%d:0" % revision if result.ok else ""


func _negatives() -> void:
	_phase = "wrong-copy-foreign-duplicate-and-no-displacement"
	for copy: String in [
		"starter-v1:ST-003", _seat_copy, _neighbors["ST-029"], "purchase:foreign:0"
	]:
		var bad: Dictionary = _empty.duplicate(true)
		bad.ground_boxes = [{"copy": copy, "site": SITES[0]}]
		_check(not _checked(bad).ok, "complete section refuses wrong item or foreign copy " + copy)
		_check(
			ClubCareer.same(_place(_empty, copy, SITES[0]), _empty),
			"wrong-item helper cannot change the plan " + copy
		)
	for kind: String in [
		"duplicate-copy",
		"duplicate-site",
		"unknown-site",
		"unknown-field",
		"wrong-version",
		"wrong-family",
		"third-row",
		"wrong-base-version"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.ground_boxes[1].copy = bad.ground_boxes[0].copy
			"duplicate-site":
				bad.ground_boxes[1].site = bad.ground_boxes[0].site
			"unknown-site":
				bad.ground_boxes[0].site = "BOX-C"
			"unknown-field":
				bad.ground_boxes[0]["yaw"] = 45
			"wrong-version":
				bad.version = 29
			"wrong-family":
				bad.family = "reference-starter-v1"
			"third-row":
				bad.ground_boxes.append({"copy": _seat_copy, "site": "BOX-C"})
			"wrong-base-version":
				bad.ground_box_base_version = 27
		_check(not _checked(bad).ok, "exact bounded section grammar rejects " + kind)
	var occupied: Dictionary = _place(_empty, _copies[0], SITES[0])
	var collision: Dictionary = _place(occupied, _copies[1], SITES[0])
	_check(
		(
			not _checked(collision).ok
			and collision.ground_boxes.size() == 2
			and collision.ground_boxes.any(
				func(row: Dictionary) -> bool: return row.copy == _copies[0]
			)
		),
		"occupied-site proposal retains both copies and rejects without silent displacement"
	)
	var reversed: Dictionary = _place(_place(_empty, _copies[1], SITES[0]), _copies[0], SITES[0])
	_check(
		not _checked(reversed).ok and reversed.ground_boxes.size() == 2,
		"same-site conflict rejects in reverse placement order"
	)
	var explicit: Dictionary = _place(
		StadiumGroundBoxItems.store_copy(occupied, _copies[0]), _copies[1], SITES[0]
	)
	_check(
		_checked(explicit).ok and _checked(explicit).stored.has(_copies[0]),
		"explicit Store-first permits another exact paid section at this site"
	)
	var moved_without_store: Dictionary = _place(occupied, _copies[0], SITES[1])
	_check(
		not _checked(moved_without_store).ok and moved_without_store.ground_boxes.size() == 2,
		"moving an installed exact copy requires explicit Store rather than silent removal"
	)
	var moved_explicitly: Dictionary = _place(
		StadiumGroundBoxItems.store_copy(occupied, _copies[0]), _copies[0], SITES[1]
	)
	_check(
		(
			_checked(moved_explicitly).ok
			and moved_explicitly.ground_boxes == [{"copy": _copies[0], "site": SITES[1]}]
		),
		"explicit Store-first moves the same paid section without duplicating it"
	)
	_check(
		ClubCareer.same(_place(occupied, _copies[0], SITES[0]), occupied),
		"reselecting the exact installed site is an idempotent placement retry"
	)
	_ownership_cases.append(
		{
			"case": "same-copy-move-store-first",
			"copy": _copies[0],
			"from": SITES[0],
			"to": SITES[1],
			"implicit_move_rejected": true,
			"explicit_move_valid": true
		}
	)
	for yaw: float in [45.0, 180.0]:
		_check(
			(
				StadiumGroundBoxItems.row(_copies[0], "ST-052", SITES[0], yaw).is_empty()
				and ClubCareer.same(
					StadiumGroundBoxItems.place(
						_empty, _paid.construction(), _copies[0], SITES[0], yaw
					),
					_empty
				)
			),
			"arbitrary rotation cannot leave the fixed world reservation " + str(yaw)
		)
	var held: Dictionary = _paid.to_data().duplicate(true)
	var stale: Dictionary = _paid.commit(
		{
			"id": "ground-box-stale",
			"rev": _paid.revision() - 1,
			"op": "stadium_draft",
			"layout": _layout
		}
	)
	_check(
		not stale.ok and ClubCareer.same(held, _paid.to_data()),
		"stale ordinary draft cannot mutate ownership or placement"
	)
	_check(
		(
			ClubCareer.same(StadiumGroundBoxItems.prune(_layout), _layout)
			and StadiumGroundBoxItems.base(_layout).version == 28
		),
		"ground-box pruning preserves exact selection and the inherited no-pad family28 plan"
	)


func _record(label: String, layout: Dictionary) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_operands = {
		"case": label,
		"paid_revision": _paid.revision(),
		"snapshot_version": snapshot.get("version", -1)
	}
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
			and ClubCareer.same(snapshot.layout, layout)
		),
		"exact frozen owned-section snapshot " + label
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


func _ownership() -> void:
	_phase = "unchanged-price-gates-and-two-independent-paid-sections"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new_club(SEED, _credits, _progress)
	var starter_prefix: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"ground-box adoption grants no starter box or extracted molded-seat inventory"
	)
	var entry: Dictionary = StadiumCatalog.item("ST-052")
	_check(
		(
			entry.blueprint_price == 520
			and entry.copy_price == 160
			and ClubCareer.same(entry.requires, {"seasons": 6, "wins": 18})
		),
		"ST-052 retains exact 520 blueprint 160 per-copy and S6 W18 catalog gate"
	)
	for gate: Dictionary in [
		{"seasons": 6, "wins": 18}, {"seasons": 5, "wins": 18}, {"seasons": 6, "wins": 17}
	]:
		var quote: Dictionary = StadiumPurchases.quote(
			_paid.construction(),
			"ST-052",
			1,
			"ground-box-gate:" + str(gate),
			StadiumGroundBoxItems.PRICE_VERSION,
			gate
		)
		_operands = {"gate": gate, "quote_ok": quote.ok, "error": quote.get("error", "")}
		_check(
			quote.ok == (gate.seasons == 6 and gate.wins == 18),
			"exact existing ground-box progression threshold " + str(gate)
		)
	_check(
		not (
			StadiumPurchases
			. quote(
				_paid.construction(),
				"ST-052",
				1,
				"ground-box-wrong-price",
				StadiumMoldedSeatItems.PRICE_VERSION,
				entry.requires
			)
			. ok
		),
		"molded-seat price route cannot purchase a complete ST-052 section"
	)
	_copies.append(_buy("ST-052", StadiumGroundBoxItems.PRICE_VERSION, 680))
	_copies.append(_buy("ST-052", StadiumGroundBoxItems.PRICE_VERSION, 160))
	_neighbors["ST-029"] = _buy("ST-029", StadiumStraightItems.PRICE_VERSION, 520)
	_neighbors["ST-032"] = _buy("ST-032", StadiumBoundaryItems.PRICE_VERSION, 550)
	_neighbors["ST-074"] = _buy("ST-074", StadiumBoundaryItems.PRICE_VERSION, 640)
	_seat_copy = _buy("ST-051", StadiumMoldedSeatItems.PRICE_VERSION, 265)
	if _copies.has("") or _neighbors.values().has("") or _seat_copy.is_empty():
		return
	_check(
		(
			_paid.construction().copies.size() == 9
			and StadiumLayoutSnapshot.matches(starter_prefix, _paid)
		),
		"only six explicit paid copies were added and the unchanged starter prefix remains authenticated"
	)
	var land: Dictionary = _paid.commit(
		{
			"id": "ground-box-expanded",
			"rev": _paid.revision(),
			"op": "stadium_land",
			"tier": "expanded",
			"through": 40,
			"progress_through": 40,
			"price_version": StadiumLand.VERSION
		}
	)
	_check(
		land.ok, "ordinary Expanded property purchase supplies room without changing field scale"
	)
	var base28: Dictionary = StadiumSmallYardSceneryItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	var pad29: Dictionary = StadiumMoldedSeatItems.place(
		StadiumMoldedSeatItems.upgrade(base28, _paid.surface_owned()),
		_paid.construction(),
		_seat_copy,
		"SEAT-PAD-1",
		0.0,
		_paid.surface_owned()
	)
	_check(
		_checked(pad29).ok and _apply(pad29),
		"one separately paid ST-051 may already occupy its independently adopted family29 pad"
	)
	_record("inherited-family29-one-paid-seat", pad29)
	_old_prefix = StadiumLayoutSnapshot.capture(_paid)
	var with_pad: Dictionary = _place(pad29, _copies[0], SITES[0])
	_check(
		(
			with_pad.get("ground_box_base_version", -1) == 29
			and with_pad.molded_seats == pad29.molded_seats
			and _checked(with_pad).ok
			and _apply(with_pad)
		),
		"ground-box adoption retains an existing optional pad and its exact paid seat"
	)
	_record("box-retains-existing-family29-pad", with_pad)
	_empty = StadiumGroundBoxItems.upgrade(base28, _paid.surface_owned())
	_check(
		(
			_empty.get("version", -1) == 30
			and _empty.get("ground_box_base_version", -1) == 28
			and not _empty.has("molded_seats")
			and _empty.ground_boxes.is_empty()
			and _checked(_empty).ok
			and _apply(_empty)
		),
		"box-only family30 adopts no optional ST-051 pad and places no free section"
	)
	_record("empty-box-only-no-pad", _empty)
	_check(
		StadiumGroundBoxItems.sites() == SITES and StadiumGroundBoxItems.yaws() == [0],
		"two exact fixed ground-box sites have no arbitrary rotation option"
	)
	var balance: int = _paid.balance()
	var active: Dictionary = _empty.duplicate(true)
	for index in range(2):
		active = _place(active, _copies[index], SITES[index])
		_check(
			(
				_checked(active).ok
				and active.ground_boxes.size() == index + 1
				and _checked(active).get("live_units", -1) == 0
				and _apply(active)
				and _paid.balance() == balance
			),
			(
				"ordinary partial then two-section apply uses exactly one paid copy per site "
				+ str(index + 1)
			)
		)
		_record("paid-section-count-" + str(index + 1), active)
	_layout = active.duplicate(true)
	active = StadiumGroundBoxItems.store_copy(active, _copies[0])
	_check(
		(
			_checked(active).ok
			and active.ground_boxes == [{"copy": _copies[1], "site": SITES[1]}]
			and _checked(active).stored.has(_copies[0])
			and _apply(active)
		),
		"Store removes only the exact left section while the independent right remains installed"
	)
	_record("left-stored-right-retained", active)
	active = _place(active, _copies[0], SITES[0])
	_check(
		(
			_checked(active).ok
			and ClubCareer.same(active, _layout)
			and _apply(active)
			and _paid.balance() == balance
		),
		"same stored left section remounts without charge or replacement identity"
	)
	_record("same-left-copy-remounted", active)
	for index in range(2):
		active = StadiumGroundBoxItems.store_copy(active, _copies[index])
		_check(
			(
				_checked(active).ok
				and active.ground_boxes.size() == 1 - index
				and _checked(active).stored.has(_copies[index])
				and _apply(active)
			),
			(
				"exact-copy Store preserves ownership without automatically restoring a neighbor "
				+ str(index)
			)
		)
		_record("store-section-count-" + str(index + 1), active)
	_check(
		(
			ClubCareer.same(active, _empty)
			and _paid.balance() == balance
			and _paid.construction().copies.size() == 9
			and _paid.to_data().version == 38
		),
		"fully stored sections preserve ledger38 all paid identities and unchanged balance"
	)
	_negatives()
	_check(
		_checked(_layout).ok and _apply(_layout) and _paid.balance() == balance,
		"final actual two-box plan applies with independently paid full sections and no optional pad"
	)
	_record("two-paid-complete-boxes-no-pad", _layout)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		(
			StadiumLayoutSnapshot.matches(_old_prefix, _paid)
			and cold != null
			and StadiumLayoutSnapshot.matches(_old_prefix, cold)
			and _old_prefix.layout.version == 29
		),
		"exact older family29 snapshot remains authenticated against warm and cold paid journal prefixes"
	)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not _checked(_layout).get("night_qualified", true)
		),
		"ordinary frozen ground-box fixture is explicitly daylight-only"
	)
