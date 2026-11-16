extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One bounded complete ST-045 qualification. Synthetic closed metrics; zero games.

const SEED: int = 160
const ITEM: String = "ST-045"
const SITE: String = "TREEHOUSE-A"
const INNER_SOURCE_SHA256: String = \
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75"
# Frozen after source authorship; every loop below has a finite authored bound.
const EXPECTED_NON_GEOMETRY_CHECKS: int = 239
const EXPECTED_PHASE_CHECKS: Dictionary = {
	"ownership": 96,
	"fit": 29,
	"workshop_controls": 11,
	"terrain_support": 61,
	"runtime_and_views": 35
}

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Array[String] = []
var _inherited: Dictionary = {}
var _empty: Dictionary = {}
var _layout: Dictionary = {}
var _snapshot: Dictionary = {}
var _old_prefix: Dictionary = {}
var _pad_occupied: Dictionary = {}
var _pad_empty: Dictionary = {}
var _inherited_tree: Dictionary = {}
var _records: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _fit_cases: Array[Dictionary] = []
var _support_matrix: Array[Dictionary] = []
var _camera_cases: Array[Dictionary] = []
var _phase_counts: Dictionary = {}
var _ui_cases: Dictionary = {}
var _runtime: Dictionary = {}
var _model_checks: int = 0


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"TREEHOUSE_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "actual-workshop-controls-and-executed-pad-transactions"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	_check(
		StadiumTreehouseItemsUI.choices() == ["Stored", SITE],
		"actual Workshop offers only Store and the fixed treehouse site"
	)
	var cards: Array[Dictionary] = []
	for index in range(2):
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumTreehouseItemsUI.card(menu, panel, _layout, _copies[index], _paid.revision(), false)
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
				and names == ["Stored", SITE]
				and choice.selected == (1 if index == 0 else 0)
			),
			(
				"actual locked card distinguishes the installed and stored independently paid copies "
				+ str(index)
			)
		)
		cards.append(
			{
				"copy": _copies[index],
				"names": names,
				"selected": choice.selected if choice != null else -1,
				"disabled": choice != null and choice.disabled
			}
		)
	StadiumTreehouseItemsUI.purchases(menu, _paid, _layout, _paid.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	_check(
		(
			text.contains("560")
			and text.contains("170")
			and text.contains("6 seasons / 18")
			and text.contains("2 owned copies")
			and text.contains("ST-013")
		),
		"actual Workshop states exact prices progression distinct copy count and bundled tree semantics"
	)
	var buys: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_meta("stadium_buy", "") == ITEM
	)
	_check(
		buys.size() == 1 and (buys[0] as Button).disabled,
		"locked ordinary purchase control cannot bypass the existing season policy"
	)
	var cases: Array[Dictionary] = []
	for input: Dictionary in [
		{
			"case": "populated-pad-remove",
			"layout": _pad_occupied,
			"enabled": true,
			"meta": "molded_pad_remove",
			"disabled": true
		},
		{
			"case": "empty-pad-remove",
			"layout": _pad_empty,
			"enabled": true,
			"meta": "molded_pad_remove",
			"disabled": false
		},
		{
			"case": "locked-empty-pad-remove",
			"layout": _pad_empty,
			"enabled": false,
			"meta": "molded_pad_remove",
			"disabled": true
		},
		{
			"case": "treehouse-pad-reselect",
			"layout": _layout,
			"enabled": true,
			"meta": "molded_pad_preview",
			"disabled": true
		},
		{
			"case": "stored-treehouse-pad-reselect",
			"layout": _empty,
			"enabled": true,
			"meta": "molded_pad_preview",
			"disabled": false
		}
	]:
		for child: Node in menu._body.get_children():
			child.free()
		StadiumMoldedSeatItemsUI.purchases(
			menu, _paid, input.layout, _paid.revision(), input.enabled
		)
		var buttons: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
			func(node: Node) -> bool: return node.get_meta(input.meta, false)
		)
		var button: Button = buttons[0] as Button if buttons.size() == 1 else null
		_operands = {
			"case": input.case,
			"actual_disabled": button.disabled if button != null else null,
			"expected_disabled": input.disabled
		}
		_check(
			(
				button != null
				and button.disabled == input.disabled
				and button.pressed.get_connections().size() == 1
			),
			"real pad action control has the exact enabled state and connected action " + input.case
		)
		cases.append(
			{
				"case": input.case,
				"metadata": input.meta,
				"disabled": button.disabled if button != null else true,
				"connected_actions":
				button.pressed.get_connections().size() if button != null else 0
			}
		)
	_check( ( _records.any( func(row: Dictionary) -> bool:
					return row.case == "empty-pad-actually-removed" and row.cold_exact ) and _records.any(
				func(row: Dictionary) -> bool:
					return row.case == "empty-pad-actually-reselected" and row.cold_exact ) and _records.any(
				func(row: Dictionary) -> bool: return (
						row.case == "same-seat-remounted-after-treehouse-store" and row.cold_exact ) ) ), (
			"real paid draft-apply transactions and cold journals cover remove reselect and "
			+ "exact-seat remount" ) )
	_ui_cases = {
		"cards": cards,
		"pad_controls": cases,
		"copy_count_text": text,
		"ledger_paid_purchases_executed": true,
		"ledger_pad_transactions_executed": true,
		"accepted_seasonstate_purchase_executed": false,
		"native_preview": false,
		"focus_cases": [],
		"night_eligible": false
	}
	menu.free()
	app.free()


func _checked(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"treehouses": layout.get("treehouses", []),
		"pad_selected": StadiumMoldedSeatItems.has_pad(layout)
	}
	return result


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func _circle_neighbor(
	label: String, reserve: AABB, center: Vector3, radius: float, expected_gap: float
) -> void:
	var nearest: Vector2 = Vector2(
		clampf(center.x, reserve.position.x, reserve.end.x),
		clampf(center.z, reserve.position.z, reserve.end.z)
	)
	var gap: float = nearest.distance_to(Vector2(center.x, center.z)) - radius
	_operands = {"neighbor": label, "center": _v3(center), "radius": radius, "gap_m": gap}
	_check(
		absf(gap - expected_gap) < 0.0001 and gap > 0,
		"full circular occupied reservation clears the complete treehouse " + label
	)
	_fit_cases.append(
		{
			"case": label,
			"bounds":
			str(AABB(center - Vector3(radius, 0, radius), Vector3(radius * 2, 0, radius * 2))),
			"gap_m": gap,
			"overlap_m2": 0,
			"clear": gap > 0,
			"details": "full circle radius " + str(radius)
		}
	)


func _corners(pose: Transform3D, box: AABB) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for point: Vector3 in [
		box.position,
		Vector3(box.end.x, box.position.y, box.position.z),
		box.end,
		Vector3(box.position.x, box.position.y, box.end.z)
	]:
		var world: Vector3 = pose * point
		result.append(Vector2(world.x, world.z))
	return result


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
	var footprint: PackedVector2Array = _corners(Transform3D.IDENTITY, box)
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


func _neighbor(
	label: String, reserve: AABB, pose: Transform3D, other: AABB, expected_gap: float = -1
) -> void:
	var polygon: PackedVector2Array = _corners(pose, other)
	var footprint: PackedVector2Array = _corners(Transform3D.IDENTITY, reserve)
	var gap: float = _polygon_gap(footprint, polygon)
	var area: float = _intersection_area(footprint, polygon)
	_operands = {
		"neighbor": label,
		"full_bounds": str(pose * other),
		"oriented_gap_m": gap,
		"overlap_m2": area
	}
	_check(
		area <= 0.000001 and gap > 0 and (expected_gap < 0 or absf(gap - expected_gap) < 0.0001),
		"full occupied existing reservation clears the complete treehouse " + label
	)
	_fit_cases.append(
		{
			"case": label,
			"bounds": str(pose * other),
			"gap_m": gap,
			"overlap_m2": area,
			"clear": area <= 0.000001 and gap > 0,
			"details":
			"complete oriented footprint, including full authored roof or access reservation"
		}
	)


func _overlap_area(first: AABB, second: AABB) -> float:
	var a: Rect2 = Rect2(
		Vector2(first.position.x, first.position.z), Vector2(first.size.x, first.size.z)
	)
	var b: Rect2 = Rect2(
		Vector2(second.position.x, second.position.z), Vector2(second.size.x, second.size.z)
	)
	return a.intersection(b).get_area()


func _fit_and_conflicts() -> void:
	_phase = "full-reservation-property-field-and-neighbors"
	var row: Dictionary = StadiumTreehouseItems.row(_copies[0], ITEM, SITE)
	var box: AABB = StadiumTreehouseItems.bounds(row)
	_operands = {"position": _v3(row.position), "bounds": str(box), "yaw": row.yaw}
	_check(
		(
			row.position == Vector3(-29, 0, 20)
			and row.yaw == 0
			and box == AABB(Vector3(-32, 0, 17), Vector3(6, 7, 6))
		),
		"whole treehouse reservation is fixed full-size six by six by seven metres"
	)
	for tier: String in ["expanded", "club", "mogul"]:
		_check(
			StadiumProperty.contains(tier, box) and _checked(_layout, tier).ok,
			"complete treehouse reservation fits exact supported property tier " + tier
		)
	_check(
		not _checked(_layout, "backyard").ok,
		"occupied treehouse cannot use the smaller Backyard property"
	)
	var overhang: AABB = box
	overhang.position.x -= 0.01
	_check(
		not StadiumProperty.contains("expanded", overhang),
		"whole reservation crossing actual west property edge fails closed"
	)
	var intruding: AABB = box
	intruding.position = Vector3(-2, 0, 8)
	_check(
		(
			not StadiumTreehouseItems._outside_play(
				intruding, StadiumTreehouseItems.graph_for(_layout)
			)
			and not StadiumTreehouseItems._outside_play(box, null)
		),
		"field-reaching reservation and missing complete graph fail closed"
	)
	for shape: String in ["straight", "deeper_center"]:
		var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape)
		var clearance: Dictionary = _clearance(box, graph)
		_operands = {"shape": shape, "clearance": clearance, "bounds": str(box)}
		_check(
			(
				StadiumTreehouseItems._outside_play(box, graph)
				and absf(clearance.graph_line_m - 2.039607805) < 0.0001
				and absf(clearance.slab_gap_m - 1.597987110) < 0.0001
				and clearance.slab_overlap_m2 <= 0.000001
			),
			(
				"actual selected-boundary line and complete miter slabs leave measured clearance "
				+ shape
			)
		)
		_fit_cases.append(
			{
				"case": "boundary-" + shape,
				"bounds": str(box),
				"gap_m": clearance.slab_gap_m,
				"overlap_m2": clearance.slab_overlap_m2,
				"clear": true,
				"details": "inner graph line " + str(clearance.graph_line_m)
			}
		)
	var pad_boxes: Array[AABB] = StadiumMoldedSeatItems.reservations()
	for index in range(3):
		var area: float = _overlap_area(box, pad_boxes[index])
		_operands = {
			"part": index,
			"treehouse_bounds": str(box),
			"pad_bounds": str(pad_boxes[index]),
			"overlap_m2": area
		}
		_check(
			is_equal_approx(area, [15.0, 4.0, 0.0][index]),
			(
				"selected pad ramp and local approach retain exact full-reservation intersection "
				+ str(index)
			)
		)
		_fit_cases.append(
			{
				"case": ["selected-pad", "selected-ramp", "pad-approach"][index],
				"bounds": str(pad_boxes[index]),
				"gap_m": 0,
				"overlap_m2": area,
				"clear": index == 2,
				"details": "pad is an explicit selection even with every owned seat stored"
			}
		)
	for site: String in StadiumBaselineSites.SITES:
		var pose: Transform3D = StadiumBaselineSites.pose(site)
		var full: AABB = StadiumBaselineSites.LOWER_BOUNDS.merge(
			StadiumBaselineSites.LOWER_ROOF_BOUNDS
		)
		_neighbor(site + "-lower-and-canopy", box, pose, full)
	for site: String in StadiumFacilityItems.GROUND_SITES:
		_neighbor(
			site + "-full-service",
			box,
			StadiumFacilityItems.pose(site),
			StadiumFacilityItems.reserved(site)
		)
	for site: String in ["PRACTICE-CLUB", "PRACTICE-M1", "PRACTICE-M2"]:
		var other: Dictionary = StadiumPracticeFacilityItems.row(
			_inherited["ST-060"], "ST-060", site
		)
		_neighbor(
			site,
			box,
			Transform3D(Basis.IDENTITY, other.position),
			StadiumPracticeFacilityItems.envelope("ST-060")
		)
	var ground_box: Dictionary = StadiumGroundBoxItems.row(_inherited["ST-052"], "ST-052", "BOX-L")
	_neighbor(
		"BOX-L",
		box,
		StadiumLiveFurnishingItems._pose(ground_box),
		StadiumGroundBoxItems.envelope("ST-052")
	)
	_neighbor(
		"LAND-L-complete-pocket",
		box,
		Transform3D(Basis.IDENTITY, StadiumLandscapeOwnedItems.SITES["LAND-L"].position),
		AABB(Vector3(-3, 0, -3), Vector3(6, 2, 6)),
		0.25
	)
	_circle_neighbor(
		"TREE-L", box, StadiumLandscapeOwnedItems.SITES["TREE-L"].position, 3.5, 3.226812024
	)
	_circle_neighbor("CLIGHT-OL", box, Vector3(-32, 0, 38), 1.35, 13.65)
	var left: Dictionary = StadiumSeatingLayout.SITES["SIDE-SEAT-L"]
	_neighbor(
		"SIDE-SEAT-L-complete-bleacher",
		box,
		Transform3D(Basis(Vector3.UP, PI * 0.5), left.position),
		StadiumBleacherModels.envelope("ST-075")
	)
	_check(
		(
			_checked(_inherited_tree).ok
			and _inherited_tree.landscape == _pad_occupied.landscape
			and _inherited_tree.ground_boxes == _pad_occupied.ground_boxes
			and _inherited_tree.practice_facilities == _pad_occupied.practice_facilities
		),
		"actual combined selected paid neighbors remain preserved without invented conflicts"
	)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "treehouse-draft:%d" % _paid.revision(),
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
			"id": "treehouse-apply:%d" % _paid.revision(),
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
		"id": "treehouse-buy:%d" % revision,
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
	return "purchase:treehouse-buy:%d:0" % revision if result.ok else ""


func _place(layout: Dictionary, copy: String) -> Dictionary:
	return StadiumTreehouseItems.place(
		layout, _paid.construction(), copy, SITE, 0.0, _paid.surface_owned()
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
			"id": "treehouse-refuse:" + label,
			"rev": _paid.revision() - (1 if stale else 0),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	var unchanged: bool = ClubCareer.same(before, _paid.to_data())
	_operands = {
		"case": label,
		"error": result.get("error", ""),
		"unchanged": unchanged,
		"candidate": layout.get("treehouses", [])
	}
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


func _negatives() -> void:
	_phase = "copy-grammar-stale-and-single-site"
	_check(
		StadiumTreehouseItems.sites() == [SITE] and StadiumTreehouseItems.yaws() == [0],
		"only one exact fixed site and zero yaw are offered"
	)
	for copy: String in [
		"starter-v1:ST-003", _inherited["ST-013"], _inherited["ST-052"], "purchase:foreign:0"
	]:
		var bad: Dictionary = _empty.duplicate(true)
		bad.treehouses = [{"copy": copy, "site": SITE}]
		_check(
			not _checked(bad).ok and ClubCareer.same(_place(_empty, copy), _empty),
			"wrong-item or foreign identity cannot become a complete treehouse " + copy
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
		var bad: Dictionary = _layout.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.treehouses.append(bad.treehouses[0].duplicate(true))
			"second-copy":
				bad.treehouses.append({"copy": _copies[1], "site": SITE})
			"unknown-site":
				bad.treehouses[0].site = "TREEHOUSE-B"
			"unknown-field":
				bad.treehouses[0]["yaw"] = 0
			"wrong-version":
				bad.version = 31
			"wrong-family":
				bad.family = "reference-starter-v1"
			"missing-copy":
				bad.treehouses[0].erase("copy")
			"non-array":
				bad.treehouses = {}
		_check(not _checked(bad).ok, "exact bounded grammar rejects " + kind)
	var second: Dictionary = _place(_layout, _copies[1])
	var reverse: Dictionary = _place(_place(_empty, _copies[1]), _copies[0])
	_check(
		(
			second.treehouses.size() == 2
			and reverse.treehouses.size() == 2
			and not _checked(second).ok
			and not _checked(reverse).ok
		),
		"two separately paid copies reject one-site occupancy in both orders without displacement"
	)
	_refused("second-copy-same-site", second)
	var swapped: Dictionary = _place(
		StadiumTreehouseItems.store_copy(_layout, _copies[0]), _copies[1]
	)
	_check(
		_checked(swapped).ok and _checked(swapped).stored.has(_copies[0]) and _apply(swapped),
		"Store-first permits the independently paid second copy in the vacated site"
	)
	_record("second-paid-copy-after-explicit-store", swapped)
	_check(
		ClubCareer.same(_place(_layout, _copies[0]), _layout),
		"current exact-copy reselect is idempotent"
	)
	for yaw: float in [45.0, 180.0, INF]:
		_check(
			(
				StadiumTreehouseItems.row(_copies[0], ITEM, SITE, yaw).is_empty()
				and ClubCareer.same(
					StadiumTreehouseItems.place(
						_empty, _paid.construction(), _copies[0], SITE, yaw
					),
					_empty
				)
			),
			"arbitrary or nonfinite rotation cannot escape the complete reservation " + str(yaw)
		)
	_refused("stale-current-copy-draft", _layout, true)
	_check(
		(
			ClubCareer.same(StadiumTreehouseItems.prune(_layout), _layout)
			and StadiumTreehouseItems.base(_layout).version == 31
		),
		"pruning preserves the current complete copy and exact inherited practice route"
	)
