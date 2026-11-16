extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One finite two-parent practice-facility gate. Synthetic closed metrics; zero games.

const SEED: int = 160
const ITEMS: Array[String] = ["ST-060", "ST-061"]
const SITES: Array[String] = ["PRACTICE-CLUB", "PRACTICE-M1", "PRACTICE-M2"]
const INNER_SOURCE_SHA256: String = \
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75"
# Reachable path: ownership111 + fit46 + UI6 + terrain43 + runtime/views33
# plus entry2, model-budget1 and completion4 = 246, plus complete-model96 = 342.
const EXPECTED_NON_GEOMETRY_CHECKS: int = 246
const EXPECTED_PHASE_CHECKS: Dictionary = {
	"ownership": 111,
	"fit": 46,
	"workshop_controls": 6,
	"terrain_support": 43,
	"runtime_and_views": 33
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
				"PRACTICE_FACILITY_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "actual-four-choice-workshop-controls"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	_check(
		(
			StadiumPracticeFacilityItemsUI.choices()
			== ["Stored", "PRACTICE-CLUB", "PRACTICE-M1", "PRACTICE-M2"]
		),
		"actual Workshop exposes Store and only the three fixed sites"
	)
	var cards: Array[Dictionary] = []
	for index in [0, 2]:
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumPracticeFacilityItemsUI.card(
			menu, panel, _layout, _copies[index], _paid.revision(), false
		)
		var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		var choice: OptionButton = options[0] as OptionButton if options.size() == 1 else null
		var names: Array[String] = []
		if choice != null:
			for option in range(choice.item_count):
				names.append(choice.get_item_text(option))
		var expected: int = 2 if index == 0 else 3
		_operands = {
			"copy": _copies[index],
			"names": names,
			"selected": choice.selected if choice != null else -1
		}
		_check(
			(
				choice != null
				and choice.disabled
				and names == StadiumPracticeFacilityItemsUI.choices()
				and choice.selected == expected
			),
			(
				"actual locked copy card displays its independently selected complete parent "
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
	StadiumPracticeFacilityItemsUI.purchases(menu, _paid, _layout, _paid.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	_operands = {"text": text}
	_check(
		(
			text.contains("750")
			and text.contains("220")
			and text.contains("120")
			and text.contains("160")
			and text.contains("4 owned copies")
		),
		"actual Workshop presents exact prices and distinct K120 H160 requirements with owned-copy counts"
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
		"accepted_seasonstate_purchase_executed": false
	}
	menu.free()
	app.free()


func _checked(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"practice_facilities": layout.get("practice_facilities", [])
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


func _footprint(box: AABB) -> Rect2:
	return Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))


func _overlap_area(first: AABB, second: AABB) -> float:
	var overlap: Rect2 = _footprint(first).intersection(_footprint(second))
	return overlap.get_area()


func _place(layout: Dictionary, copy: String, site: String) -> Dictionary:
	return StadiumPracticeFacilityItems.place(
		layout, _paid.construction(), copy, site, 0.0, _paid.surface_owned()
	)


func _tower(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	result.floodlight_profile = "CLUB4-LOW"
	result.floodlights = [{"copy": _inherited["ST-038"], "item": "ST-038", "site": "CLIGHT-OL"}]
	return result


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _fit_and_conflicts() -> void:
	_phase = "full-property-ground-field-and-structure-reservations"
	_check(
		(
			not _checked(_layout, "backyard").ok
			and not _checked(_layout, "expanded").ok
			and not _checked(_layout, "club").ok
		),
		"two Mogul lanes cannot use smaller property tiers"
	)
	var graph: StadiumRecipeBoundary = StadiumPracticeFacilityItems.graph_for(_layout)
	var positions: Array[Vector3] = [
		Vector3(-36.75, 0, 39.25), Vector3(-40.25, 0, 41.75), Vector3(-34.25, 0, 41.75)
	]
	for index in range(3):
		for item: String in ITEMS:
			var row: Dictionary = StadiumPracticeFacilityItems.row(
				_copies[0] if item == "ST-060" else _copies[2], item, SITES[index]
			)
			var box: AABB = StadiumPracticeFacilityItems.bounds(row)
			var height: float = 3.5 if item == "ST-060" else 4.0
			var clearance: Dictionary = _clearance(box, graph)
			_operands = {"site": row.site, "item": item, "bounds": str(box), "clearance": clearance}
			_check(
				(
					row.position == positions[index]
					and row.yaw == 0
					and (
						box
						== AABB(
							positions[index] + Vector3(-2.25, 0, -5.25), Vector3(4.5, height, 10.5)
						)
					)
				),
				"complete unscaled source reservation and fixed center " + item + ":" + row.site
			)
			_check(
				(
					StadiumProperty.contains("mogul", box)
					and StadiumProperty.contains("club", box) == (index == 0)
					and not StadiumProperty.contains("expanded", box)
				),
				"whole reservation obeys the exact Club versus Mogul land boundary " + row.site
			)
			_check(
				(
					StadiumPracticeFacilityItems._supported(box, _layout)
					and StadiumPracticeFacilityItems._outside_play(box, graph)
					and clearance.slab_overlap_m2 <= 0.000001
				),
				(
					"complete supported footprint remains outside live field and selected boundary slabs "
					+ row.site
				)
			)
			var intruding: AABB = box
			intruding.position = Vector3(-2, 0, 8)
			_check(
				(
					not StadiumPracticeFacilityItems._outside_play(intruding, graph)
					and not StadiumPracticeFacilityItems._outside_play(box, null)
				),
				"unavailable boundary and field-reaching facility fail closed " + row.site
			)
			var structures: Array[Dictionary] = []
			var clear: bool = true
			for site: String in StadiumBaselineSites.SITES:
				var full: AABB = (
					StadiumBaselineSites.pose(site)
					* StadiumBaselineSites.LOWER_BOUNDS.merge(
						StadiumBaselineSites.LOWER_ROOF_BOUNDS
					)
				)
				clear = clear and not _footprint(box).intersects(_footprint(full))
				structures.append(
					{
						"site": site,
						"full_lower_and_canopy_bounds": str(full),
						"overlap_m2": _overlap_area(box, full)
					}
				)
			for site: String in StadiumFacilityItems.GROUND_SITES:
				var full: AABB = (
					StadiumFacilityItems.pose(site) * StadiumFacilityItems.reserved(site)
				)
				clear = clear and not _footprint(box).intersects(_footprint(full))
				structures.append(
					{
						"site": site,
						"full_service_reservation": str(full),
						"overlap_m2": _overlap_area(box, full)
					}
				)
			_check(
				clear,
				(
					"full existing lower-canopy and service-structure reservations leave practice footprint clear "
					+ row.site
				)
			)
			_fit_cases.append(
				{
					"case": "full-fixed-reservation",
					"item": item,
					"site": row.site,
					"position": _v3(row.position),
					"bounds": str(box),
					"clearance": clearance,
					"structure_reservations": structures
				}
			)
	var club_box: AABB = StadiumPracticeFacilityItems.bounds(
		StadiumPracticeFacilityItems.row(_copies[0], "ST-060", SITES[0])
	)
	for index in [1, 2]:
		var other_box: AABB = StadiumPracticeFacilityItems.bounds(
			StadiumPracticeFacilityItems.row(_copies[2], "ST-061", SITES[index])
		)
		var overlap: float = _overlap_area(club_box, other_box)
		_check(
			is_equal_approx(overlap, 8.0 if index == 1 else 16.0),
			"whole Club and Mogul reservations have exact source overlap " + SITES[index]
		)
		var club_first: Dictionary = _place(
			_place(_empty, _copies[0], SITES[0]), _copies[2], SITES[index]
		)
		var mogul_first: Dictionary = _place(
			_place(_empty, _copies[2], SITES[index]), _copies[0], SITES[0]
		)
		_check(
			(
				not _checked(club_first).ok
				and not _checked(mogul_first).ok
				and ClubCareer.same(club_first, mogul_first)
				and club_first.practice_facilities.size() == 2
			),
			(
				"final combined Club versus Mogul collision rejects both orders without displacement "
				+ SITES[index]
			)
		)
		var store_club: Dictionary = StadiumPracticeFacilityItems.store_copy(club_first, _copies[0])
		_check(
			(
				_checked(store_club).ok
				and _checked(store_club).stored.has(_copies[0])
				and store_club.practice_facilities.size() == 1
			),
			"explicit Club Store permits exact Mogul copy " + SITES[index]
		)
		var store_mogul: Dictionary = StadiumPracticeFacilityItems.store_copy(
			mogul_first, _copies[2]
		)
		_check(
			(
				_checked(store_mogul, "club").ok
				and _checked(store_mogul).stored.has(_copies[2])
				and store_mogul.practice_facilities.size() == 1
			),
			"inverse Mogul Store permits exact Club copy " + SITES[index]
		)
		_check(
			(
				ClubCareer.same(
					StadiumPracticeFacilityItems.store_copy(store_club, _copies[2]), _empty
				)
				and ClubCareer.same(
					StadiumPracticeFacilityItems.store_copy(store_mogul, _copies[0]), _empty
				)
			),
			"later Store never silently restores displaced facility " + SITES[index]
		)
		_fit_cases.append(
			{
				"case": "club-mogul-store-first",
				"site": SITES[index],
				"overlap_m2": overlap,
				"both_orders_rejected": true,
				"store_first_both_directions_valid": true
			}
		)
	var m1: AABB = StadiumPracticeFacilityItems.bounds(
		StadiumPracticeFacilityItems.row(_copies[0], "ST-060", SITES[1])
	)
	var m2: AABB = StadiumPracticeFacilityItems.bounds(
		StadiumPracticeFacilityItems.row(_copies[2], "ST-061", SITES[2])
	)
	_check(
		(
			is_equal_approx(m2.position.x - m1.end.x, 1.5)
			and _overlap_area(m1, m2) == 0
			and _checked(_layout).ok
		),
		"two full Mogul reservations preserve exactly one-point-five metres between independent parents"
	)
	var tower: Dictionary = StadiumFloodlightOwnedItems.row(
		_inherited["ST-038"], "CLUB4-LOW", "CLIGHT-OL"
	)
	var tower_box: AABB = StadiumFloodlightOwnedItems.bounds(tower)
	_check(
		(
			is_equal_approx(tower_box.position.x - club_box.end.x, 1.15)
			and _overlap_area(club_box, tower_box) == 0
			and _overlap_area(m2, tower_box) > 0
		),
		"complete existing Club tower clears Club practice by1.15m but overlaps Mogul M2"
	)
	var tower_only: Dictionary = _tower(_empty)
	_check(
		(
			_checked(tower_only, "club").ok
			and not _checked(tower_only, "club").get("floodlight_complete", true)
			and not _checked(tower_only, "club").get("night_qualified", true)
			and _checked(_place(tower_only, _copies[0], SITES[0]), "club").ok
		),
		"the independently paid Club tower and Club practice remain compatible without Night expansion"
	)
	var tower_first: Dictionary = _place(tower_only, _copies[2], SITES[2])
	var practice_first: Dictionary = _tower(_place(_empty, _copies[2], SITES[2]))
	_check(
		(
			not _checked(tower_first).ok
			and not _checked(practice_first).ok
			and ClubCareer.same(tower_first, practice_first)
		),
		"actual combined tower and M2 layout rejects in both placement orders"
	)
	var no_tower: Dictionary = StadiumFloodlightOwnedItems.store_copy(
		tower_first, _inherited["ST-038"]
	)
	var no_practice: Dictionary = StadiumPracticeFacilityItems.store_copy(
		practice_first, _copies[2]
	)
	_check(
		(
			_checked(no_tower).ok
			and _checked(no_tower).stored.has(_inherited["ST-038"])
			and _checked(no_practice).ok
			and _checked(no_practice).stored.has(_copies[2])
		),
		"explicit exact-copy Store resolves the actual tower conflict in either direction"
	)
	_fit_cases.append(
		{
			"case": "existing-club-tower",
			"site": "CLIGHT-OL",
			"bounds": str(tower_box),
			"club_gap_m": tower_box.position.x - club_box.end.x,
			"m2_overlap_m2": _overlap_area(m2, tower_box),
			"both_orders_rejected": true,
			"store_first_both_directions_valid": true,
			"night_claim": false
		}
	)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "practice-facility-draft:%d" % _paid.revision(),
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
			"id": "practice-facility-apply:%d" % _paid.revision(),
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
		"id": "practice-facility-buy:%d" % revision,
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
	return "purchase:practice-facility-buy:%d:0" % revision if result.ok else ""


func _first_cold_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	if ClubCareer.same(expected, actual):
		return {}
	return _cold_container_difference(expected, actual, path)


func _cold_container_difference(expected: Variant, actual: Variant, path: String) -> Dictionary:
	if expected is Dictionary and actual is Dictionary:
		for key: String in expected:
			if not actual.has(key):
				return {"path": path + "." + key, "kind": "missing_actual_key"}
			var nested: Dictionary = _first_cold_difference(
				expected[key], actual[key], path + "." + key
			)
			if not nested.is_empty():
				return nested
		for key: String in actual:
			if not expected.has(key):
				return {"path": path + "." + key, "kind": "extra_actual_key"}
	elif expected is Array and actual is Array:
		if expected.size() != actual.size():
			return {
				"path": path,
				"kind": "array_size",
				"expected": expected.size(),
				"actual": actual.size()
			}
		for index in range(expected.size()):
			var nested: Dictionary = _first_cold_difference(
				expected[index], actual[index], path + "[%d]" % index
			)
			if not nested.is_empty():
				return nested
	return {
		"path": path,
		"kind": "scalar_or_type",
		"expected": JSON.stringify(expected, "", true, true).left(160),
		"actual": JSON.stringify(actual, "", true, true).left(160)
	}
func _cold_operands(label: String, expected: Dictionary, restored: SeasonState) -> void:
	var actual: Dictionary = SeasonSave.snapshot(restored) if restored != null else {}
	_operands = {
		"case": label,
		"save_version": expected.get("version", -1),
		"decoded": restored != null,
		"error": SeasonSave.last_error,
		"first_difference": _first_cold_difference(expected, actual)
	}


func _hit_source_contract() -> void:
	_phase = "backward-compatible-earned-hit-source-contract"
	var capture_source: String = FileAccess.get_file_as_string(
		"res://src/gameplay/season/club_player_progress.gd"
	)
	var capture_begin: int = capture_source.find("static func capture(")
	var capture_end: int = capture_source.find("static func capture_with_hits(")
	var legacy_capture_sha: String = (
		capture_source.substr(capture_begin, capture_end - capture_begin).sha256_text()
	)
	var scores: Array = [[0, 0, 1, 1, 0]]
	var legacy: Dictionary = {
		"version": 1,
		"games":
		[
			{
				"game": 0,
				"stats": {"homers": 0, "hitters": 1, "strikeouts": 3, "three_k": 1},
				"sponsors": 0,
				"end_half": -1,
				"deficit": 0
			}
		],
		"development": {"mastery": 0, "known": 0, "lessons": []}
	}
	var current: Dictionary = legacy.duplicate(true)
	current.version = 2
	current.games[0].stats["hits"] = 4
	_check(
		(
			legacy_capture_sha == "8c717e779d563e3019b5438b151b08f200892d0c2ad5dec35af1ee8d10b3880c"
			and ClubPlayerProgress.valid(legacy, scores)
			and ClubPlayerProgress.valid(current, scores)
		),
		"byte-exact legacy capture and exact old proof schema and explicit total-hit schema both validate"
	)
	var upgrade_label: Dictionary = legacy.duplicate(true)
	upgrade_label.version = 2
	var downgrade_label: Dictionary = current.duplicate(true)
	downgrade_label.version = 1
	_check(
		(
			not ClubPlayerProgress.valid(upgrade_label, scores)
			and not ClubPlayerProgress.valid(downgrade_label, scores)
		),
		"relabeling versions cannot invent or erase a total-hit evidence field"
	)
	for invalid: Variant in [-1, 0, 4000001, "4"]:
		var bad: Dictionary = current.duplicate(true)
		bad.games[0].stats.hits = invalid
		_check(
			not ClubPlayerProgress.valid(bad, scores),
			"malformed or inconsistent total-hit evidence fails closed " + str(invalid)
		)
	var season: SeasonState = SeasonState.create(SEED, false, true, true)
	season.career = ClubCareer.new()
	_check(
		(
			season.career.start(season)
			and season.career.runs[-1].player_progress.version == ClubPlayerLegend.VERSION
		),
		"ordinary new career starts with explicit total-hit schema"
	)
	var fresh: Dictionary = SeasonSave.snapshot(season)
	var fresh_cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(fresh, "", true, true))
	)
	_cold_operands("save45-v2", fresh, fresh_cold)
	_check(
		(
			not fresh.is_empty()
			and fresh_cold != null
			and ClubCareer.same(SeasonSave.snapshot(fresh_cold), fresh)
		),
		"zero-game new-schema season roundtrips through the real cold save decoder"
	)
	var old: Dictionary = fresh.duplicate(true)
	old.career.runs[-1].player_progress.version = 1
	var old_cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(old, "", true, true))
	)
	_cold_operands("save45-v1", old, old_cold)
	_check(
		(
			old_cold != null
			and ClubCareer.same(SeasonSave.snapshot(old_cold), old)
			and old_cold.career.runs[-1].player_progress.version == 1
		),
		"zero-game legacy-schema season stays byte-equivalent through the real cold decoder"
	)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var fixture: Dictionary = season.pending_fixture()
	var roster: Array = season.teams[fixture.away].roster + season.teams[fixture.home].roster
	var stats: Dictionary = {}
	for id: String in roster:
		stats[id] = MatchPerformance.empty_line()
	var ours: String = season.teams[0].roster[0]
	var enemy: String = season.teams[fixture.away if fixture.home == 0 else fixture.home].roster[0]
	stats[ours].h = 4
	stats[ours].pa = 4
	stats[ours].p_k = 3
	stats[ours].outs = 3
	stats[enemy].p_h = 4
	stats[enemy].k = 3
	stats[enemy].pa = 3
	_check(
		(
			SeasonPerformance.valid(stats, roster)
			and season.record_player_result(fixture.id, 1, 0, stats)
		),
		(
			"explicit synthetic balanced performance enters one scheduled-result source row "
			+ "without playing a game"
		)
	)
	var captured_legacy: Dictionary = ClubPlayerProgress.capture(season)
	var captured: Dictionary = ClubPlayerProgress.capture_with_hits(season)
	var stripped: Dictionary = captured.duplicate(true)
	stripped.version = 1
	for row: Dictionary in stripped.games:
		if row.stats != null:
			row.stats.erase("hits")
	_check(
		(
			not captured.is_empty()
			and captured.games.size() == 1
			and captured.games[0].stats.hits == 4
			and captured.games[0].stats.hitters == 1
			and captured.games[0].stats.strikeouts == 3
			and ClubCareer.same(captured_legacy, stripped)
		),
		"actual validated four-player source sums hits while preserving exact legacy extraction"
	)
	var proof: Dictionary = ClubSeasonRecord.capture(season)
	var career: ClubCareer = ClubCareer.new()
	career.runs.append({"status": "abandoned", "proof": proof, "player_progress": captured})
	var earned: Array = StadiumCareerProgress.capture(career)
	_check(
		(
			earned.size() == 1
			and earned[0].get("hits", -1) == 4
			and earned[0].get("strikeouts", -1) == 3
			and StadiumCareerProgress.metrics(earned, 1).hits == 4
		),
		"closed-source stadium progression receives actual total hits rather than hitter count"
	)
	career.runs[0].player_progress = captured_legacy
	var unknown_old: Array = StadiumCareerProgress.capture(career)
	career.runs[0].player_progress = null
	var unknown_null: Array = StadiumCareerProgress.capture(career)
	_check(
		(
			unknown_old.size() == 1
			and unknown_null.size() == 1
			and not unknown_old[0].has("hits")
			and not unknown_null[0].has("hits")
		),
		"legacy and unknown detail grant no invented total-hit progression"
	)
	season.player_results[0].erase("performance")
	var unknown: Dictionary = ClubPlayerProgress.capture_with_hits(season)
	_check(
		not unknown.is_empty() and unknown.games[0].stats == null,
		"missing source performance remains unknown under the new schema"
	)
	_ownership_cases.append(
		{
			"case": "hit-source-v2-compatibility",
			"legacy_capture_sha256": legacy_capture_sha,
			"synthetic_performance": true,
			"source_h": 4,
			"source_hitters": 1,
			"legacy_exact_after_strip": true,
			"unknown_total_hits_absent": true,
			"new_save_version": fresh.get("version", -1),
			"new_cold_exact": fresh_cold != null,
			"legacy_cold_exact": old_cold != null,
			"played_games": 0
		}
	)


func _negatives() -> void:
	_phase = "exact-copy-grammar-and-no-displacement"
	for copy: String in [
		"starter-v1:ST-003", _inherited["ST-052"], _inherited["ST-051"], "purchase:foreign:0"
	]:
		var bad: Dictionary = _empty.duplicate(true)
		bad.practice_facilities = [{"copy": copy, "site": SITES[0]}]
		_check(
			not _checked(bad).ok and ClubCareer.same(_place(_empty, copy, SITES[0]), _empty),
			"wrong-item or foreign identity cannot become a facility " + copy
		)
	for kind: String in [
		"duplicate-copy",
		"duplicate-site",
		"unknown-site",
		"unknown-field",
		"wrong-version",
		"wrong-family",
		"fourth-row"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.practice_facilities[1].copy = bad.practice_facilities[0].copy
			"duplicate-site":
				bad.practice_facilities[1].site = bad.practice_facilities[0].site
			"unknown-site":
				bad.practice_facilities[0].site = "PRACTICE-M3"
			"unknown-field":
				bad.practice_facilities[0]["yaw"] = 45
			"wrong-version":
				bad.version = 30
			"wrong-family":
				bad.family = "reference-starter-v1"
			"fourth-row":
				bad.practice_facilities.append_array(
					[{"copy": _copies[1], "site": SITES[0]}, {"copy": _copies[3], "site": SITES[2]}]
				)
		_check(not _checked(bad).ok, "exact bounded grammar rejects " + kind)
	var occupied: Dictionary = _place(_empty, _copies[0], SITES[1])
	var collision: Dictionary = _place(occupied, _copies[2], SITES[1])
	var reverse: Dictionary = _place(_place(_empty, _copies[2], SITES[1]), _copies[0], SITES[1])
	_check(
		(
			not _checked(collision).ok
			and not _checked(reverse).ok
			and collision.practice_facilities.size() == 2
			and reverse.practice_facilities.size() == 2
		),
		"same-site different parents reject in both orders without displacement"
	)
	var explicit: Dictionary = _place(
		StadiumPracticeFacilityItems.store_copy(occupied, _copies[0]), _copies[2], SITES[1]
	)
	_check(
		_checked(explicit).ok and _checked(explicit).stored.has(_copies[0]),
		"explicit Store permits the other purchased parent in the vacated lane"
	)
	_check(
		(
			not _checked(_place(occupied, _copies[0], SITES[2])).ok
			and ClubCareer.same(_place(occupied, _copies[0], SITES[1]), occupied)
		),
		"installed-copy move requires Store and exact reselect is idempotent"
	)
	var moved: Dictionary = _place(
		StadiumPracticeFacilityItems.store_copy(occupied, _copies[0]), _copies[0], SITES[2]
	)
	_check(
		(
			_checked(moved).ok
			and moved.practice_facilities == [{"copy": _copies[0], "site": SITES[2]}]
		),
		"same exact stored copy moves without replacement identity"
	)
	for item: String in ITEMS:
		_check(
			(
				StadiumPracticeFacilityItems.row(_copies[0], item, SITES[0], 45).is_empty()
				and StadiumPracticeFacilityItems.row(_copies[0], item, SITES[0], 180).is_empty()
			),
			"arbitrary rotation cannot escape full fixed reservation " + item
		)
	var held: Dictionary = _paid.to_data().duplicate(true)
	var stale: Dictionary = _paid.commit(
		{
			"id": "practice-stale",
			"rev": _paid.revision() - 1,
			"op": "stadium_draft",
			"layout": _layout
		}
	)
	_check(
		not stale.ok and ClubCareer.same(held, _paid.to_data()),
		"stale draft cannot mutate ownership or placement"
	)
	_check(
		(
			ClubCareer.same(StadiumPracticeFacilityItems.prune(_layout), _layout)
			and StadiumPracticeFacilityItems.base(_layout).version == 30
		),
		"practice pruning preserves exact selection and the accepted parent route"
	)
	_ownership_cases.append(
		{
			"case": "copy-grammar-store-first",
			"wrong_copy_rejections": 4,
			"grammar_rejections": 7,
			"same_site_both_orders_rejected": true,
			"same_copy_move_requires_store": true,
			"stale_draft_unchanged": true
		}
	)
