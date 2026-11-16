extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One bounded complete ST-048/049/050 qualification. Synthetic closed metrics; zero games.

const SEED: int = 160
const ITEMS: Array[String] = ["ST-048", "ST-049", "ST-050"]
const SITES: Array[String] = ["LANDMARK-A", "ODDITY-PLAZA"]
const PRICES: Dictionary = {"ST-048": [600, 160], "ST-049": [650, 170], "ST-050": [750, 200]}
const GATES: Dictionary = {
	"ST-048": {"seasons": 18, "wins": 60},
	"ST-049": {"seasons": 18, "strikeouts": 250},
	"ST-050": {"seasons": 20, "wins": 70}
}
const INNER_SOURCE_SHA256: String = \
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75"
# source-derived successful bounded path; frozen before binding
const EXPECTED_NON_GEOMETRY_CHECKS: int = 389
const EXPECTED_PHASE_CHECKS: Dictionary = {
	"ownership": 104,
	"fit": 60,
	"workshop_controls": 9,
	"terrain_support": 157,
	"runtime_and_views": 52
}

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Array[String] = []
var _inherited: Dictionary = {}
var _empty: Dictionary = {}
var _layout: Dictionary = {}
var _robot_layout: Dictionary = {}
var _snapshot: Dictionary = {}
var _robot_snapshot: Dictionary = {}
var _old_prefix: Dictionary = {}
var _records: Array[Dictionary] = []
var _receipts: Array[Dictionary] = []
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
				"LANDMARK_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "actual-workshop-controls-without-season-save-claim"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	_check(
		StadiumLandmarkItemsUI.choices() == ["Stored", "LANDMARK-A", "ODDITY-PLAZA"],
		"actual Workshop offers Store and only the two fixed sites"
	)
	var cards: Array[Dictionary] = []
	for index in range(4):
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumLandmarkItemsUI.card(menu, panel, _layout, _copies[index], _paid.revision(), false)
		var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		var choice: OptionButton = options[0] as OptionButton if options.size() == 1 else null
		var names: Array[String] = []
		if choice != null:
			for option in range(choice.item_count):
				names.append(choice.get_item_text(option))
		var expected: int = [1, 0, 2, 0][index]
		_check(
			(
				choice != null
				and choice.disabled
				and names == ["Stored", "LANDMARK-A", "ODDITY-PLAZA"]
				and choice.selected == expected
				and choice.item_selected.get_connections().size() == 1
			),
			"actual locked card distinguishes exact placed and stored paid copies " + str(index)
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
	StadiumLandmarkItemsUI.purchases(menu, _paid, _layout, _paid.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	_check(
		(
			text.contains("600")
			and text.contains("160")
			and text.contains("650")
			and text.contains("170")
			and text.contains("750")
			and text.contains("200")
			and text.contains("4 owned copies")
			and text.contains("250 recorded strikeouts")
			and text.contains("70 recorded wins")
		),
		"actual Workshop states exact three prices gates and independently paid copy count"
	)
	for item: String in ITEMS:
		var buys: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
			func(node: Node) -> bool: return node.get_meta("stadium_buy", "") == item
		)
		_check(
			buys.size() == 1 and (buys[0] as Button).disabled,
			"locked ordinary purchase control cannot bypass season policy " + item
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


func _checked(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"landmarks": layout.get("landmarks", [])
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


func _light_layout(layout: Dictionary, profile: String, site: String, copy: String) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	result.floodlight_profile = profile
	result.floodlights = [
		{"copy": copy, "item": "ST-076" if profile == "MOGUL4-PREMIUM" else "ST-038", "site": site}
	]
	return result


func _neighbor(label: String, reserve: AABB, other: AABB, expected_gap: float) -> void:
	var gap: float = _polygon_gap(_corners(reserve), _corners(other))
	var area: float = _intersection_area(_corners(reserve), _corners(other))
	_check(
		area <= 0.000001 and absf(gap - expected_gap) < 0.0001,
		"full existing reservation clears the complete landmark " + label
	)
	_fit_cases.append(
		{
			"case": label,
			"bounds": str(other),
			"gap_m": gap,
			"overlap_m2": area,
			"clear": area <= 0.000001 and gap > 0,
			"details": "complete existing fixed reservation"
		}
	)


func _place(layout: Dictionary, copy: String, site: String = "LANDMARK-A") -> Dictionary:
	return StadiumLandmarkItems.place(
		layout, _paid.construction(), copy, site, 0.0, _paid.surface_owned()
	)


func _refused(label: String, layout: Dictionary, stale: bool = false) -> void:
	var before: Dictionary = _paid.to_data().duplicate(true)
	var result: Dictionary = _paid.commit(
		{
			"id": "landmark-refuse:" + label,
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
	_phase = "full-reservations-property-field-and-fixed-lights"
	for index in range(3):
		for site: String in SITES:
			var row: Dictionary = StadiumLandmarkItems.row(_copies[index], ITEMS[index], site)
			var box: AABB = StadiumLandmarkItems.bounds(row)
			var expected: AABB = (
				AABB(Vector3(30, 0, 39), Vector3(13, [5, 7, 5][index], 10))
				if site == "LANDMARK-A"
				else AABB(Vector3(36.5, 0, -17.5), Vector3(7, 8, 7))
			)
			_check(
				(
					box == expected
					and (
						row.position
						== (Vector3(36.5, 0, 44) if site == "LANDMARK-A" else Vector3(40, 0, -14))
					)
					and row.yaw == 0
				),
				(
					"whole fixed site reservation retains exact approved coordinates and dimensions "
					+ ITEMS[index]
					+ ":"
					+ site
				)
			)
			var candidate: Dictionary = _place(_empty, _copies[index], site)
			for tier: String in ["backyard", "expanded", "club"]:
				_check(
					not _checked(candidate, tier).ok,
					(
						"earlier property tier refuses occupied landmark "
						+ ITEMS[index]
						+ ":"
						+ site
						+ ":"
						+ tier
					)
				)
			_check(
				StadiumProperty.contains("mogul", box) and _checked(candidate).ok,
				"whole reservation fits Mogul without scaling " + ITEMS[index] + ":" + site
			)
			for shape: String in ["straight", "deeper_center"]:
				var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape)
				var clearance: Dictionary = _clearance(box, graph)
				_check(
					(
						StadiumLandmarkItems._outside_play(box, graph)
						and clearance.graph_line_m > 0
						and clearance.slab_gap_m > 0
						and clearance.slab_overlap_m2 <= 0.000001
					),
					(
						"complete boundary line and miter slabs clear full reservation "
						+ ITEMS[index]
						+ ":"
						+ site
						+ ":"
						+ shape
					)
				)
				_fit_cases.append(
					{
						"case": ITEMS[index] + ":" + site + ":" + shape,
						"bounds": str(box),
						"gap_m": clearance.slab_gap_m,
						"overlap_m2": clearance.slab_overlap_m2,
						"clear": true,
						"details": "inner graph line " + str(clearance.graph_line_m)
					}
				)
	var primary: AABB = StadiumLandmarkItems.bounds(
		StadiumLandmarkItems.row(_copies[0], "ST-048", "LANDMARK-A")
	)
	var plaza: AABB = StadiumLandmarkItems.bounds(
		StadiumLandmarkItems.row(_copies[0], "ST-048", "ODDITY-PLAZA")
	)
	_neighbor(
		"BOARD-LARGE-v2-full-reservation",
		primary,
		AABB(Vector3(29, 0, 30.5), Vector3(15, 12, 2)),
		6.5
	)
	_neighbor("SERVICE-B-full-reservation", plaza, AABB(Vector3(33, 0, -10), Vector3(6, 5, 6)), 0.5)
	for index in range(3):
		var single: Dictionary = _place(_empty, _copies[index])
		var light_first: Dictionary = _light_layout(
			_empty, "CLUB4-LOW", "CLIGHT-OR", _inherited["ST-038"]
		)
		var order_a: Dictionary = _place(light_first, _copies[index])
		var order_b: Dictionary = _light_layout(
			single, "CLUB4-LOW", "CLIGHT-OR", _inherited["ST-038"]
		)
		_check(
			(
				_checked(light_first).ok
				and ClubCareer.same(order_a, order_b)
				and not _checked(order_a).ok
				and order_a.landmarks == single.landmarks
				and order_a.floodlights == light_first.floodlights
			),
			(
				"Club outer-right conflict rejects both orders while preserving both paid identities "
				+ ITEMS[index]
			)
		)
		_refused("club-light-first:" + ITEMS[index], order_a)
		_refused("landmark-first:" + ITEMS[index], order_b)
		for profile: String in ["MOGUL6-STANDARD", "MOGUL4-PREMIUM"]:
			var premium: bool = profile == "MOGUL4-PREMIUM"
			var site: String = "PLIGHT-OR" if premium else "MLIGHT-OR"
			var copy: String = _inherited["ST-076" if premium else "ST-038"]
			var candidate: Dictionary = _light_layout(single, profile, site, copy)
			var light: Dictionary = StadiumFloodlightOwnedItems.row(copy, profile, site)
			var radius: float = StadiumFloodlightOwnedItems.bounds(light).size.x * 0.5
			var nearest: Vector2 = Vector2(
				clampf(light.position.x, primary.position.x, primary.end.x),
				clampf(light.position.z, primary.position.z, primary.end.z)
			)
			var gap: float = (
				nearest.distance_to(Vector2(light.position.x, light.position.z)) - radius
			)
			_check(
				(
					_checked(candidate).ok
					and absf(gap - (1.412277660 if premium else 1.812277660)) < 0.0001
					and candidate.landmarks == single.landmarks
					and candidate.floodlights[0].copy == copy
				),
				(
					"fixed Mogul outer-right full tower reservation clears landmark without moving either copy "
					+ ITEMS[index]
					+ ":"
					+ profile
				)
			)
			_fit_cases.append(
				{
					"case": ITEMS[index] + ":" + profile,
					"bounds": str(StadiumFloodlightOwnedItems.bounds(light)),
					"gap_m": gap,
					"overlap_m2": 0,
					"clear": true,
					"details": "full circular tower reservation; exact site and paid copy preserved"
				}
			)
	_check(
		(
			not StadiumLandmarkItems._outside_play(
				AABB(Vector3(-2, 0, 8), Vector3(13, 7, 10)), StadiumLandmarkItems.graph_for(_layout)
			)
			and not StadiumLandmarkItems._outside_play(primary, null)
		),
		"field-reaching reservation and absent complete graph fail closed"
	)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "landmark-draft:%d" % _paid.revision(),
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
			"id": "landmark-apply:%d" % _paid.revision(),
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
		"id": "landmark-buy:%d" % revision,
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
	var copy: String = "purchase:landmark-buy:%d:0" % revision
	var receipt: Dictionary = _paid.construction().copies.get(copy, {})
	_operands = {"item": item, "revision": revision, "error": result.get("error", ""), "cost": cost}
	_check(
		(
			result.ok
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"ordinary paid command adds exactly one complete purchased copy " + item
	)
	_check(
		(
			ClubCareer.same(
				receipt,
				{
					"item": item,
					"paid": StadiumCatalog.item(item).copy_price,
					"source": "purchase-v1"
				}
			)
			and _paid.construction().blueprints.has(item)
		),
		"exact copy receipt preserves item copy price and paid source " + item
	)
	_check(
		(
			_paid.commit(command).get("replayed", false)
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"exact paid retry neither charges nor duplicates " + item
	)
	_receipts.append(
		{
			"copy": copy,
			"item": item,
			"command_revision": revision,
			"charged": cost,
			"copy_paid": receipt.get("paid", -1),
			"source": receipt.get("source", ""),
			"retry_replayed": true
		}
	)
	return copy if result.ok else ""


func _negatives(first: Dictionary) -> void:
	_check(
		StadiumLandmarkItems.sites() == SITES and StadiumLandmarkItems.yaws() == [0],
		"only the exact two fixed sites and zero yaw are offered"
	)
	for copy: String in ["starter-v1:ST-003", _inherited["ST-038"], "purchase:foreign:0"]:
		var bad: Dictionary = _empty.duplicate(true)
		bad.landmarks = [{"copy": copy, "site": "LANDMARK-A"}]
		_check(
			not _checked(bad).ok and ClubCareer.same(_place(_empty, copy), _empty),
			"wrong-item or foreign identity cannot become a landmark " + copy
		)
	for kind: String in [
		"duplicate-copy",
		"second-copy",
		"unknown-site",
		"unknown-field",
		"wrong-version",
		"wrong-family",
		"missing-copy",
		"non-array",
		"unsorted-sites"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.landmarks[1].copy = bad.landmarks[0].copy
			"second-copy":
				bad.landmarks[1].site = bad.landmarks[0].site
			"unknown-site":
				bad.landmarks[0].site = "LANDMARK-B"
			"unknown-field":
				bad.landmarks[0]["yaw"] = 0
			"wrong-version":
				bad.version = 32
			"wrong-family":
				bad.family = "reference-starter-v1"
			"missing-copy":
				bad.landmarks[0].erase("copy")
			"non-array":
				bad.landmarks = {}
			"unsorted-sites":
				bad.landmarks.reverse()
		_check(not _checked(bad).ok, "exact bounded grammar rejects " + kind)
	for reverse: bool in [false, true]:
		var conflict: Dictionary = _place(
			_place(_empty, _copies[1] if reverse else _copies[0]),
			_copies[0] if reverse else _copies[1]
		)
		_check(
			conflict.landmarks.size() == 2 and not _checked(conflict).ok,
			"one occupant per fixed site rejects both placement orders without displacement"
		)
		_refused("same-site-occupancy:" + str(reverse), conflict)
	_check(
		ClubCareer.same(_place(first, _copies[0]), first),
		"current exact-copy reselect is idempotent"
	)
	for yaw: float in [45.0, 180.0, INF]:
		_check(
			(
				StadiumLandmarkItems.row(_copies[0], "ST-048", "LANDMARK-A", yaw).is_empty()
				and ClubCareer.same(
					StadiumLandmarkItems.place(
						_empty, _paid.construction(), _copies[0], "LANDMARK-A", yaw
					),
					_empty
				)
			),
			"arbitrary or nonfinite rotation cannot escape fixed reservation " + str(yaw)
		)
	_refused("stale-current-copy-draft", _layout, true)
	_check(
		(
			ClubCareer.same(StadiumLandmarkItems.prune(_layout), _layout)
			and StadiumLandmarkItems.base(_layout).version == 32
		),
		"pruning preserves current copies and exact inherited treehouse route"
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


func _ownership() -> void:
	_phase = "exact-paid-copy-gates-and-lifecycle"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 10, "hits": 4})
	_check(
		StadiumCareerProgress.valid(_progress, _credits),
		"explicit synthetic closed metrics support qualification without claiming earned career progress"
	)
	_paid = ClubAssetLedger.new_club(SEED, _credits, _progress)
	var starter: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"adoption grants no landmark copies"
	)
	for item: String in ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		_check(
			(
				entry.blueprint_price == PRICES[item][0]
				and entry.copy_price == PRICES[item][1]
				and ClubCareer.same(entry.requires, GATES[item])
			),
			"unchanged exact catalog prices and earned unlock gate " + item
		)
		_check(
			(
				StadiumPurchases
				. quote(
					_paid.construction(),
					item,
					1,
					"landmark-gate:" + item,
					StadiumLandmarkItems.PRICE_VERSION,
					GATES[item]
				)
				. ok
			),
			"exact unlock threshold admits paid quote " + item
		)
		for key: String in GATES[item]:
			var below: Dictionary = GATES[item].duplicate(true)
			below[key] -= 1
			_check(
				not (
					StadiumPurchases
					. quote(
						_paid.construction(),
						item,
						1,
						"landmark-below:" + item + key,
						StadiumLandmarkItems.PRICE_VERSION,
						below
					)
					. ok
				),
				"each just-below unlock operand refuses " + item + ":" + key
			)
		_check(
			not (
				StadiumPurchases
				. quote(
					_paid.construction(),
					item,
					1,
					"landmark-old:" + item,
					StadiumTreehouseItems.PRICE_VERSION,
					GATES[item]
				)
				. ok
			),
			"older treehouse price route cannot buy a landmark " + item
		)
		_copies.append(
			_buy(item, StadiumLandmarkItems.PRICE_VERSION, PRICES[item][0] + PRICES[item][1])
		)
	_copies.append(_buy("ST-048", StadiumLandmarkItems.PRICE_VERSION, 160))
	_inherited["ST-038"] = _buy("ST-038", StadiumFloodlightOwnedItems.PRICE_VERSION, 640)
	_inherited["ST-076"] = _buy("ST-076", StadiumFloodlightOwnedItems.PRICE_VERSION, 930)
	_check(
		_paid.construction().copies.size() == 9 and StadiumLayoutSnapshot.matches(starter, _paid),
		"six explicit purchases preserve authenticated starter prefix and grant no extras"
	)
	if _copies.has("") or _inherited.values().has("") or _paid.construction().copies.size() != 9:
		return
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "landmark-land:" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(
			result.ok and _paid.construction().copies.size() == 9,
			"ordinary land purchase grants no landmark copies " + tier
		)
	if _paid.view().land != "mogul":
		return
	var base32: Dictionary = StadiumTreehouseItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	_check(
		_checked(base32).ok and _apply(base32),
		"accepted empty treehouse family32 applies before landmark adoption"
	)
	_record("inherited-family32", base32)
	_old_prefix = StadiumLayoutSnapshot.capture(_paid)
	_empty = StadiumLandmarkItems.upgrade(base32, _paid.surface_owned())
	_check(
		(
			_empty.version == 33
			and _empty.landmarks.is_empty()
			and ClubCareer.same(StadiumLandmarkItems.base(_empty), base32)
			and _checked(_empty).ok
			and _apply(_empty)
		),
		"empty family33 preserves exact inherited treehouse and all earlier channels"
	)
	_record("empty-landmark-family", _empty)
	var balance: int = _paid.balance()
	for index in range(3):
		for site: String in SITES:
			var placed: Dictionary = _place(_empty, _copies[index], site)
			_check(
				_checked(placed).ok and _apply(placed) and _paid.balance() == balance,
				"each complete paid item applies at each fixed site " + ITEMS[index] + ":" + site
			)
			_record(ITEMS[index] + ":" + site, placed)
			if index == 1 and site == "LANDMARK-A":
				_robot_layout = placed.duplicate(true)
				_robot_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var first: Dictionary = _place(_empty, _copies[0])
	var stored: Dictionary = StadiumLandmarkItems.store_copy(first, _copies[0])
	_check(
		(
			ClubCareer.same(stored, _empty)
			and _checked(stored).stored.has(_copies[0])
			and _apply(stored)
		),
		"Store vacates one site while keeping exact complete purchased copy"
	)
	_record("complete-copy-stored", stored)
	_check(
		(
			ClubCareer.same(_place(stored, _copies[0]), first)
			and _apply(first)
			and _paid.balance() == balance
		),
		"same exact complete copy remounts without new charge"
	)
	_record("same-complete-copy-remounted", first)
	var same_twice: Dictionary = _place(first, _copies[0], "ODDITY-PLAZA")
	_refused("same-copy-two-sites", same_twice)
	var two_paid: Dictionary = _place(first, _copies[3], "ODDITY-PLAZA")
	_check(
		_checked(two_paid).ok and _apply(two_paid) and two_paid.landmarks.size() == 2,
		"same item at two sites consumes two independently paid copies"
	)
	_record("same-item-two-paid-copies", two_paid)
	var swapped: Dictionary = _place(
		StadiumLandmarkItems.store_copy(two_paid, _copies[0]), _copies[1]
	)
	_check(
		_checked(swapped).ok and _checked(swapped).stored.has(_copies[0]) and _apply(swapped),
		"explicit Store first swaps occupant without consuming or displacing a different copy"
	)
	_record("store-first-item-swap", swapped)
	_layout = _place(first, _copies[2], "ODDITY-PLAZA")
	_negatives(first)
	_check(
		(
			_checked(_layout).ok
			and _apply(_layout)
			and _paid.balance() == balance
			and _paid.to_data().version == 41
			and _paid.construction().copies.size() == 9
		),
		"final two-site current-copy plan applies on ledger41 without any further charge"
	)
	_record("final-two-site-landmarks", _layout)
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
		"accepted treehouse family32 prefix remains authenticated warm and cold"
	)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not _checked(_layout).get("night_qualified", true)
		),
		"frozen complete landmark fixture preserves daylight-only admission"
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
