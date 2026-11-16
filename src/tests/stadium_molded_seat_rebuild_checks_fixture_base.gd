extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One bounded ST-051 paid-copy / fixed-pad / outer-ground qualification. Zero games.

const SEED: int = 151
const SITES: Array[String] = ["SEAT-PAD-1", "SEAT-PAD-2", "SEAT-PAD-3", "SEAT-PAD-4"]
const INNER_SOURCE_SHA256: String = \
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75"
# Counted from the finite success path; the model helper supplies its own exact count.
# Ownership107 + Workshop7 + terrain247 + runtime/views27 + entry/model-budget/completion7 = 395.
const EXPECTED_NON_GEOMETRY_CHECKS: int = 395

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Array[String] = []
var _plastic_copy: String = ""
var _roof_copy: String = ""
var _empty: Dictionary = {}
var _layout: Dictionary = {}
var _full: Dictionary = {}
var _snapshot: Dictionary = {}
var _records: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _support_matrix: Array[Dictionary] = []
var _guards: Array[Dictionary] = []
var _phase_counts: Dictionary = {}
var _ui_cases: Dictionary = {}
var _runtime: Dictionary = {}
var _model_checks: int = 0


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"MOLDED_SEAT_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "actual-five-choice-workshop-and-visible-copy-count"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	_check(
		(
			StadiumMoldedSeatItemsUI.choices()
			== ["Stored", "SEAT-PAD-1", "SEAT-PAD-2", "SEAT-PAD-3", "SEAT-PAD-4"]
		),
		"molded-seat control exposes exactly Stored plus four authored sockets"
	)
	var cards: Array[Dictionary] = []
	for index in range(_copies.size()):
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumMoldedSeatItemsUI.card(menu, panel, _layout, _copies[index], _paid.revision(), false)
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
				and names == StadiumMoldedSeatItemsUI.choices()
				and choice.selected == (index + 1 if index in [0, 2] else 0)
			),
			"actual locked exact-copy card shows one selected socket or Stored " + str(index)
		)
		cards.append(
			{
				"copy": _copies[index],
				"names": names,
				"selected": choice.selected if choice != null else -1,
				"disabled": choice != null and choice.disabled
			}
		)
	StadiumMoldedSeatItemsUI.purchases(menu, _paid, _layout, _paid.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	_check(
		(
			text.contains("four empty sockets")
			and text.contains("220")
			and text.contains("45")
			and text.contains("4 owned copies")
			and text.contains("2 of 4")
		),
		(
			"actual Workshop explains pad scope and displays selected and owned-copy counts with "
			+ "unchanged prices"
		)
	)
	var buys: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_meta("stadium_buy", "") == "ST-051"
	)
	_check(
		buys.size() == 1 and (buys[0] as Button).disabled,
		"existing locked purchase button cannot bypass ordinary season policy"
	)
	_ui_cases = {
		"cards": cards,
		"copy_count_text": text,
		"ledger_paid_purchases_executed": true,
		"accepted_seasonstate_purchase_executed": false
	}
	menu.free()
	app.free()


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "molded-draft:%d" % _paid.revision(),
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
			"id": "molded-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("expanded", layout)
		}
	)
	_operands = {"stage": "apply", "error": applied.get("error", "")}
	return applied.ok


func _buy(item: String, price_version: int, cost: int) -> String:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "molded-buy:%d" % revision,
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
	_operands = {"item": item, "command": command, "error": result.get("error", ""), "cost": cost}
	_check(
		(
			result.ok
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"ordinary paid command adds exactly one purchased copy " + item
	)
	_check(
		(
			_paid.commit(command).get("replayed", false)
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"exact paid retry neither charges nor duplicates " + item
	)
	return "purchase:molded-buy:%d:0" % revision if result.ok else ""


func _checked(layout: Dictionary, tier: String = "expanded") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"molded_seats": layout.get("molded_seats", [])
	}
	return result


func _place(layout: Dictionary, copy: String, site: String) -> Dictionary:
	return StadiumMoldedSeatItems.place(
		layout, _paid.construction(), copy, site, 0.0, _paid.surface_owned()
	)


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func _fit_and_conflicts() -> void:
	_phase = "complete-pad-access-property-and-structure-fit"
	_check(
		not _checked(_empty, "backyard").ok and not _checked(_full, "backyard").ok,
		"complete pad and access reject Backyard even with zero placed seats"
	)
	var graph: StadiumRecipeBoundary = StadiumMoldedSeatItems.graph_for(_full)
	for reserve: AABB in StadiumMoldedSeatItems.reservations():
		_check(
			(
				StadiumProperty.contains("expanded", reserve)
				and StadiumMoldedSeatItems._outside_play(reserve, graph)
			),
			"whole pad ramp or approach footprint fits the property outside play"
		)
		var shifted: AABB = reserve
		shifted.position.x = -33
		_check(
			not StadiumProperty.contains("expanded", shifted),
			"full reservation helper rejects a property-edge overhang"
		)
		var structure: Dictionary = {
			"copy": "geometry-only-control",
			"item": "ST-081",
			"site": "BOWL-03",
			"position": reserve.get_center() - Vector3(0, 0, 21.2),
			"yaw": 0,
			"role": "DECORATIVE_AFTER_TERMINAL",
			"roof_state": "lower"
		}
		_check(
			StadiumMoldedSeatItems._reservation_overlaps(reserve, structure),
			"full oriented structure reservation detects translated helper-only pad or access conflict"
		)
		_ownership_cases.append(
			{
				"case": "translated-structure-helper-only",
				"reservation": str(reserve),
				"structure_item": "ST-081",
				"position": _v3(structure.position),
				"installed_claim": false,
				"placement_order_claim": false
			}
		)
	var infield: AABB = StadiumMoldedSeatItems.PAD
	infield.position = Vector3(-3, 0, 10)
	_check(
		not StadiumMoldedSeatItems._outside_play(infield, graph),
		"whole-pad outside-play helper rejects a field-interior footprint"
	)
	# Existing legal ST-081 sites do not collide with this new local pad. Test actual
	# coexistence in both orders; translated conflict above remains helper-only.
	for site: String in ["BOWL-01", "BOWL-05"]:
		var roof: Dictionary = StadiumRoofItems.row(site)
		roof.copy = _roof_copy
		var structure_first: Dictionary = _empty.duplicate(true)
		structure_first.roofs = [roof]
		_check(
			_checked(structure_first, "mogul").ok,
			"separately paid existing structure is legal beside the complete empty pad " + site
		)
		structure_first = _place(structure_first, _copies[0], SITES[0])
		var seat_first: Dictionary = _place(_empty, _copies[0], SITES[0])
		seat_first.roofs = [roof.duplicate(true)]
		_check(
			(
				_checked(structure_first, "mogul").ok
				and _checked(seat_first, "mogul").ok
				and ClubCareer.same(structure_first, seat_first)
			),
			"actual legal structure and seat coexist in both placement orders " + site
		)
		_check(
			not _checked(structure_first, "expanded").ok,
			"existing structure retains its own Mogul land gate " + site
		)
		_ownership_cases.append(
			{
				"case": "actual-nonconflicting-structure-both-orders",
				"structure": "ST-081",
				"structure_site": site,
				"structure_copy": _roof_copy,
				"seat_copy": _copies[0],
				"tier": "mogul",
				"installed_claim": false
			}
		)
	var rough: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), [], false), []
	)
	for kind: String in ["live-obstacle", "paid-wall", "night-light"]:
		var bad: Dictionary = rough.duplicate(true)
		match kind:
			"live-obstacle":
				bad.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
			"paid-wall":
				bad.walls["foreign"] = true
			"night-light":
				bad.lights = [{"copy": "purchase:foreign-light:0", "site": "LIGHT-L"}]
		var helper_layout: Dictionary = StadiumMoldedSeatItems.upgrade(rough, [])
		var helper_checked: Dictionary = {
			"ok": true, "error": "", "placements": [], "live_units": 0, "wall_panels": []
		}
		var helper_kind: String = (
			"live-unit-budget"
			if kind == "live-obstacle"
			else "paid-wall-panels" if kind == "paid-wall" else "late-live-role"
		)
		match kind:
			"live-obstacle":
				helper_checked.live_units = 1
			"paid-wall":
				helper_checked.wall_panels = [{}]
			"night-light":
				helper_checked.placements = [{"role": "LIVE_RICOCHET"}]
		var admission: Dictionary = StadiumHomeLayout.terrain_admission(
			helper_layout, "expanded", helper_checked
		)
		_check(
			(
				not _checked(StadiumMoldedSeatItems.upgrade(bad, []), "expanded").ok
				and not admission.ok
			),
			(
				"actual invalid terrain selection and explicit helper-only aggregate both reject "
				+ kind
				+ ":"
				+ helper_kind
			)
		)
		_ownership_cases.append(
			{
				"case": "terrain-aggregate-helper-only",
				"actual_invalid_manifest": kind,
				"aggregate_operand": helper_kind,
				"checked_operand": helper_checked,
				"error": admission.get("error", ""),
				"paid_copy_or_runtime_claim": false
			}
		)


func _negatives() -> void:
	_phase = "wrong-copy-foreign-duplicate-and-no-displacement"
	for copy: String in [
		"starter-v1:ST-003", "starter-v1:ST-079", _plastic_copy, "purchase:foreign:0"
	]:
		var bad: Dictionary = _empty.duplicate(true)
		bad.molded_seats = [{"copy": copy, "site": SITES[0]}]
		_check(not _checked(bad).ok, "socket refuses wrong item or foreign copy " + copy)
		_check(
			ClubCareer.same(_place(_empty, copy, SITES[0]), _empty),
			"wrong-item placement helper cannot silently change the plan " + copy
		)
	for kind: String in [
		"duplicate-copy",
		"duplicate-site",
		"unknown-site",
		"unknown-field",
		"wrong-version",
		"wrong-family",
		"fifth-row"
	]:
		var bad: Dictionary = _full.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.molded_seats[1].copy = bad.molded_seats[0].copy
			"duplicate-site":
				bad.molded_seats[1].site = bad.molded_seats[0].site
			"unknown-site":
				bad.molded_seats[0].site = "SEAT-PAD-5"
			"unknown-field":
				bad.molded_seats[0]["yaw"] = 90
			"wrong-version":
				bad.version = 28
			"wrong-family":
				bad.family = "reference-starter-v1"
			"fifth-row":
				bad.molded_seats.append({"copy": _plastic_copy, "site": "SEAT-PAD-5"})
		_check(not _checked(bad).ok, "exact bounded socket grammar rejects " + kind)
	var occupied: Dictionary = _place(_empty, _copies[0], SITES[0])
	var collision: Dictionary = _place(occupied, _copies[1], SITES[0])
	_check(
		(
			not _checked(collision).ok
			and collision.molded_seats.size() == 2
			and collision.molded_seats.any(
				func(row: Dictionary) -> bool: return row.copy == _copies[0]
			)
		),
		"occupied-socket proposal retains both copies and rejects without silent displacement"
	)
	var reversed: Dictionary = _place(_place(_empty, _copies[1], SITES[0]), _copies[0], SITES[0])
	_check(
		not _checked(reversed).ok and reversed.molded_seats.size() == 2,
		"same socket conflict rejects in reverse placement order"
	)
	var explicit: Dictionary = _place(
		StadiumMoldedSeatItems.store_copy(occupied, _copies[0]), _copies[1], SITES[0]
	)
	_check(
		_checked(explicit).ok and _checked(explicit).stored.has(_copies[0]),
		"explicit Store-first permits replacement by another exact paid copy"
	)
	var held: Dictionary = _paid.to_data().duplicate(true)
	var stale: Dictionary = _paid.commit(
		{"id": "molded-stale", "rev": _paid.revision() - 1, "op": "stadium_draft", "layout": _full}
	)
	_check(
		not stale.ok and ClubCareer.same(held, _paid.to_data()),
		"stale ordinary draft cannot mutate ownership or placement"
	)
	_check(
		(
			ClubCareer.same(StadiumMoldedSeatItems.prune(_full), _full)
			and StadiumMoldedSeatItems.base(_full).version == 28
		),
		"molded wrapper and pruning preserve the inherited family28 plan"
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
		"exact frozen owned-copy snapshot " + label
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
		),
		"cold journal preserves exact copy identity and placement " + label
	)
	_records.append(
		{
			"case": label,
			"layout": layout.duplicate(true),
			"snapshot_version": snapshot.get("version", -1),
			"paid_revision": _paid.revision(),
			"snapshot_sha256": JSON.stringify(snapshot, "", true, true).sha256_text(),
			"cold_exact": cold != null and StadiumLayoutSnapshot.matches(snapshot, cold)
		}
	)


func _ownership() -> void:
	_phase = "unchanged-price-gates-paid-identities-and-fixed-sockets"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new_club(SEED, _credits, _progress)
	var prefix: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"fixed pad grants no starter molded seats or invented inventory"
	)
	var entry: Dictionary = StadiumCatalog.item("ST-051")
	_check(
		(
			entry.blueprint_price == 220
			and entry.copy_price == 45
			and ClubCareer.same(entry.requires, {"seasons": 4, "wins": 10})
		),
		"ST-051 retains exact 220 blueprint 45 per-copy and S4 W10 catalog gate"
	)
	for gate: Dictionary in [
		{"seasons": 4, "wins": 10}, {"seasons": 3, "wins": 10}, {"seasons": 4, "wins": 9}
	]:
		var quote: Dictionary = StadiumPurchases.quote(
			_paid.construction(),
			"ST-051",
			1,
			"molded-gate:" + str(gate),
			StadiumMoldedSeatItems.PRICE_VERSION,
			gate
		)
		_check(
			quote.ok == (gate.seasons == 4 and gate.wins == 10),
			"exact existing molded-seat progression threshold " + str(gate)
		)
	_check(
		not (
			StadiumPurchases
			. quote(
				_paid.construction(),
				"ST-051",
				1,
				"molded-wrong-price",
				StadiumPurchases.SEATING_VERSION,
				entry.requires
			)
			. ok
		),
		"old spectator-chair price route cannot purchase ST-051"
	)
	for index in range(4):
		_copies.append(
			_buy("ST-051", StadiumMoldedSeatItems.PRICE_VERSION, 265 if index == 0 else 45)
		)
	_plastic_copy = _buy("ST-080", StadiumPurchases.SEATING_VERSION, 190)
	_roof_copy = _buy("ST-081", StadiumRoofItems.PRICE_VERSION, 790)
	if _copies.has("") or _plastic_copy.is_empty() or _roof_copy.is_empty():
		return
	_check(
		_paid.construction().copies.size() == 9 and StadiumLayoutSnapshot.matches(prefix, _paid),
		"only six separately paid copies were added and old snapshot prefix remains authenticated"
	)
	var land: Dictionary = _paid.commit(
		{
			"id": "molded-expanded",
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
	_empty = StadiumMoldedSeatItems.upgrade(_paid.view().stadium_active, _paid.surface_owned())
	_check(
		(
			_empty.get("version") == 29
			and _empty.molded_seats.is_empty()
			and _checked(_empty).ok
			and _apply(_empty)
		),
		"empty four-socket plan applies without any seat copy placement"
	)
	_record("empty-four-socket-pad", _empty)
	_check(
		StadiumMoldedSeatItems.sites() == SITES and StadiumMoldedSeatItems.yaws() == [0],
		"four exact fixed sockets have one fixed facing"
	)
	for index in range(SITES.size()):
		var row: Dictionary = StadiumMoldedSeatItems.row(_copies[0], "ST-051", SITES[index])
		var one: Dictionary = _place(_empty, _copies[0], SITES[index])
		var checked: Dictionary = _checked(one)
		_check(
			(
				checked.ok
				and checked.get("live_units", -1) == 0
				and checked.get("molded_seat_placements", []).size() == 1
			),
			"same exact paid copy fits canonical socket " + SITES[index]
		)
		_check(
			(
				row.position == Vector3(-29.5 + index, 0.15, 20.8)
				and row.yaw == 0
				and StadiumMoldedSeatItems.bounds(row).size.is_equal_approx(
					Vector3(0.50, 0.85, 0.55)
				)
			),
			"full real-size seat envelope and fixed authored pose " + SITES[index]
		)
		_ownership_cases.append(
			{
				"case": "one-copy-each-socket",
				"copy": _copies[0],
				"site": SITES[index],
				"position": _v3(row.position),
				"live_units": checked.get("live_units", -1)
			}
		)
	var active: Dictionary = _empty.duplicate(true)
	var balance: int = _paid.balance()
	for index in range(4):
		active = _place(active, _copies[index], SITES[index])
		_check(
			(
				_checked(active).ok
				and active.molded_seats.size() == index + 1
				and _apply(active)
				and _paid.balance() == balance
			),
			"ordinary free partial/full pad apply with exact owned copies " + str(index + 1)
		)
		_record("paid-pad-count-" + str(index + 1), active)
	_full = active.duplicate(true)
	active = StadiumMoldedSeatItems.store_copy(active, _copies[1])
	_check(
		(
			_checked(active).ok
			and active.molded_seats.size() == 3
			and _checked(active).stored.has(_copies[1])
			and _apply(active)
		),
		"Store removes only the selected exact second copy from a full pad"
	)
	_record("middle-copy-stored", active)
	active = _place(active, _copies[1], SITES[1])
	_check(
		(
			_checked(active).ok
			and active.molded_seats.size() == 4
			and _apply(active)
			and _paid.balance() == balance
		),
		"same stored copy remounts without charge or replacement identity"
	)
	_record("same-copy-remounted", active)
	for index in range(4):
		active = StadiumMoldedSeatItems.store_copy(active, _copies[index])
		_check(
			(
				_checked(active).ok
				and active.molded_seats.size() == 3 - index
				and _checked(active).stored.has(_copies[index])
				and _apply(active)
			),
			"exact-copy Store preserves the fixed pad and other occupants " + str(index)
		)
		_record("store-count-" + str(index + 1), active)
	_check(
		(
			ClubCareer.same(active, _empty)
			and _paid.balance() == balance
			and _paid.construction().copies.size() == 9
			and _paid.to_data().version == 37
		),
		"fully emptied map pad preserves ledger37 all paid identities and balance"
	)
	_negatives()
	_fit_and_conflicts()
	_layout = _place(_place(_empty, _copies[0], SITES[0]), _copies[2], SITES[2])
	_check(
		_checked(_layout).ok and _apply(_layout) and _paid.balance() == balance,
		"final actual two-seat partial pad applies with two empty sockets"
	)
	_record("two-paid-seats-two-empty-sockets", _layout)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not _checked(_layout).get("night_qualified", true)
		),
		"frozen ordinary molded-seat fixture is explicitly daylight-only"
	)


func _preview_focus() -> void:
	_phase = "actual-owned-copy-workshop-focus"
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(_full, _paid.construction(), true, "expanded", null, null, _paid.surface_owned())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and preview.preview_property.has_node("MoldedSeatPad")
			and not preview.night_eligible
		),
		"actual Workshop preview builds the complete fixed pad and selected owned seat models in daylight"
	)
	var cases: Array[Dictionary] = []
	for copy: String in _copies:
		preview.focus_copy(copy)
		await get_tree().process_frame
		var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
		var bounds: AABB = preview.board_bounds.get(copy, AABB())
		var contained: bool = preview.board_bounds.has(copy) and rect.size.x > 0 and rect.size.y > 0
		for index in range(8):
			var point: Vector3 = bounds.get_endpoint(index)
			contained = (
				contained
				and not preview.camera.is_position_behind(point)
				and rect.has_point(preview.camera.unproject_position(point))
			)
		_operands = {
			"copy": copy,
			"bounds": str(bounds),
			"viewport": [rect.size.x, rect.size.y],
			"eye": _v3(preview.camera.position)
		}
		_check(
			contained,
			(
				"actual owned-copy preview focus contains all eight complete molded-seat corners "
				+ copy
			)
		)
		cases.append({"copy": copy, "all_eight_corners_in_frame": contained})
	_ui_cases.merge(
		{"native_preview": true, "focus_cases": cases, "night_eligible": preview.night_eligible}
	)
	preview.queue_free()
	await get_tree().process_frame


func _ray(root: Node3D, point: Vector3) -> Dictionary:
	return root.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3, point - Vector3.UP, 1)
	)


func _views(root: Node3D, property: StadiumPropertyGeometry) -> void:
	_phase = "two-readable-native-molded-seat-originals"
	var target: Vector3 = Vector3(-28, 0.30, 18.6)
	var camera: Camera3D = _studio(root, target + Vector3(-6, 7.2, -9), target, 10.4)
	_label(root, "MOLDED STADIUM SEATS | 2 paid copies, 2 empty sockets", Vector2(22, 18), 23)
	_label(
		root,
		"Fixed 6 x 3 m pad | local approach and ramp | daylight, zero games",
		Vector2(22, 50),
		18
	)
	_label(
		root,
		"Socket 1: paid   /   Socket 2: empty   /   Socket 3: paid   /   Socket 4: empty",
		Vector2(22, 78),
		17
	)
	# Clear top-space labels only. The existing match HUD owns the bottom edge.
	await _capture("molded-seat-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	var model: Node3D = property.objects.get(_copies[0])
	_check(
		is_instance_valid(model), "close native detail uses the actual installed paid ST-051 model"
	)
	if is_instance_valid(model):
		var focus: Vector3 = model.global_position + Vector3(0, 0.40, 0)
		camera.position = focus + Vector3(-1.6, 0.95, -2.2)
		camera.look_at(focus)
		camera.size = 1.6
		_label(root, "ST-051 | ONE OWNED MOLDED STADIUM SEAT", Vector2(22, 18), 23)
		_label(
			root,
			"0.50 m wide x 0.55 m deep x 0.85 m high | exact socket, no audience",
			Vector2(22, 50),
			18
		)
		await _capture("molded-seat-details.png")
