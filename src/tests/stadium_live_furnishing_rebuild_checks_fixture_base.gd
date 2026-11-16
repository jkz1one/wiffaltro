extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One paid/cold shared ST-002/ST-007 qualification, real native flights, zero games.

const SEED: int = 111
const ITEMS: Array[String] = ["ST-002", "ST-007"]
const PRICES: Dictionary = {"ST-002": [160, 45], "ST-007": [680, 200]}
const GATES: Dictionary = {"ST-002": {"seasons": 2}, "ST-007": {"seasons": 8, "wins": 25}}
# Success path: ownership99 + controls4 + runtime/views100 + entry/completion7 + geometry62 = 272.
const EXPECTED_NON_GEOMETRY_CHECKS: int = 210

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Dictionary = {}
var _base26: Dictionary = {}
var _layout: Dictionary = {}
var _snapshot: Dictionary = {}
var _records: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _contact_cases: Array[Dictionary] = []
var _report_cases: Array[Dictionary] = []
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
				"LIVE_FURNISHING_REBUILD_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "real-workshop-controls-honest-lock-scope"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	StadiumLiveFurnishingItemsUI.purchases(menu, _paid, true)
	var buttons: Array[String] = []
	var locked: bool = true
	for button: Button in menu.find_children("*", "Button", true, false):
		if button.has_meta("stadium_buy"):
			buttons.append(button.get_meta("stadium_buy"))
			locked = locked and button.disabled
	buttons.sort()
	_check(
		buttons == ITEMS and locked,
		"actual Workshop builds both purchase controls and honors empty career locks"
	)
	for item: String in ITEMS:
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumLiveFurnishingItemsUI.card(
			menu, panel, _layout, _copies[item][0], item, _paid.revision(), false
		)
		var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		var choice: OptionButton = options[0] as OptionButton if options.size() == 1 else null
		_check(
			(
				choice != null
				and choice.disabled
				and choice.get_item_text(0) == "Stored"
				and choice.item_count == (13 if item == "ST-002" else 5)
			),
			"disabled actual card retains Stored plus every canonical fixed-pose site " + item
		)
	app.season.phase = SeasonState.Phase.REGULAR
	var before: Dictionary = app.season.career.to_data()
	var result: Dictionary = ClubConstruction.buy_copy(app.season, "ST-002", 0)
	_check(
		not result.ok and ClubCareer.same(before, app.season.career.to_data()),
		"ordinary season-locked buy refuses without mutation"
	)
	_ui_cases = {
		"purchase_buttons": buttons,
		"empty_career_locked": locked,
		"accepted_seasonstate_purchase_executed": false,
		"ledger_paid_purchases_executed": true,
		"synthetic_ledger_funding": true,
		"card_items": ITEMS,
		"locked_buy_error": result.get("error", "")
	}
	menu.free()
	app.free()


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "furnishing-draft:%d" % _paid.revision(),
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
			"id": "furnishing-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("expanded", layout)
		}
	)
	_operands = {"stage": "apply", "error": result.get("error", "")}
	return result.ok


func _buy(item: String, quantity: int) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "furnishing-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": StadiumLiveFurnishingItems.PRICE_VERSION,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var expected: int = int(PRICES[item][0]) + int(PRICES[item][1]) * quantity
	var balance: int = _paid.balance()
	var count: int = _paid.construction().copies.size()
	var result: Dictionary = _paid.commit(command)
	_operands = {
		"item": item,
		"error": result.get("error", ""),
		"expected_cost": expected,
		"before": count,
		"after": _paid.construction().copies.size()
	}
	_check(
		(
			result.ok
			and _paid.balance() == balance - expected
			and _paid.construction().copies.size() == count + quantity
		),
		"ordinary exact paid blueprint and copies " + item
	)
	_check(
		(
			_paid.commit(command).get("replayed", false)
			and _paid.balance() == balance - expected
			and _paid.construction().copies.size() == count + quantity
		),
		"retry cannot charge or duplicate paid stock " + item
	)
	_copies[item] = []
	for index in range(quantity):
		_copies[item].append("purchase:furnishing-buy:%d:%d" % [revision, index])
	_ownership_cases.append(
		{
			"case": "paid-purchase",
			"item": item,
			"quantity": quantity,
			"cost": expected,
			"copies": _copies[item].duplicate()
		}
	)


func _checked(layout: Dictionary, tier: String = "expanded") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"error": result.get("error", ""),
		"tier": tier,
		"live_furnishings": layout.get("live_furnishings", [])
	}
	return result


func _negatives() -> void:
	_phase = "foreign-duplicate-stale-and-malformed-placement"
	for mode: String in [
		"unowned",
		"wrong-item",
		"duplicate-copy",
		"duplicate-site",
		"unknown-field",
		"unknown-site",
		"nonzero-yaw",
		"wrong-family",
		"wrong-version"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		var raw: Dictionary = bad.live_furnishings[0]
		match mode:
			"unowned":
				raw.copy = "purchase:missing:0"
			"wrong-item":
				raw.item = "ST-006"
			"duplicate-copy":
				bad.live_furnishings[1].copy = raw.copy
			"duplicate-site":
				bad.live_furnishings[1].site = raw.site
			"unknown-field":
				raw["position"] = [0, 0, 0]
			"unknown-site":
				raw.site = "INVENTED"
			"nonzero-yaw":
				raw.yaw = 90
			"wrong-family":
				bad.family = "reference-starter-v1"
			"wrong-version":
				bad.version = 26
		_check(not _checked(bad).ok, "malformed exact furnishing record fails closed " + mode)
	var duplicate: Dictionary = _layout.duplicate(true)
	duplicate.obstacles = [{"copy": _copies["ST-002"][0], "site": "O-L1", "yaw": 0}]
	_check(
		not _checked(duplicate).ok, "one furnishing copy cannot also appear in an inherited channel"
	)
	var held: Dictionary = _paid.to_data().duplicate(true)
	var stale: Dictionary = _paid.commit(
		{
			"id": "furnishing-stale-draft",
			"rev": _paid.revision() - 1,
			"op": "stadium_draft",
			"layout": _layout
		}
	)
	_check(
		not stale.ok and ClubCareer.same(held, _paid.to_data()),
		"stale draft revision cannot replace paid placement"
	)


func _placed(layout: Dictionary, item: String, index: int, site: String) -> Dictionary:
	return StadiumLiveFurnishingItems.place(
		StadiumLiveFurnishingItems.upgrade(layout, _paid.surface_owned()),
		_paid.construction(),
		_copies[item][index],
		site
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
		"exact frozen paid-copy snapshot " + label
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
		),
		"cold JSON paid identity and placement " + label
	)
	_records.append({"case": label, "layout": layout.duplicate(true), "snapshot": snapshot})


func _same_copy_modes() -> void:
	_phase = "same-paid-copy-scenery-live-store-and-remount"
	var balance: int = _paid.balance()
	for item: String in ITEMS:
		var copy: String = _copies[item][0]
		var scene: Dictionary = _placed(_base26, item, 0, "YS-L1" if item == "ST-002" else "YL-L")
		_check(
			_apply(scene) and _paid.balance() == balance,
			"same paid copy enters scenery for free " + item
		)
		_record(item + ":scenery", scene)
		var live: Dictionary = _placed(scene, item, 0, "O-R2" if item == "ST-002" else "OL-L")
		_check(
			(
				_checked(live).ok
				and live.live_furnishings.size() == 1
				and live.live_furnishings[0].copy == copy
				and _apply(live)
				and _paid.balance() == balance
			),
			"same exact paid copy moves scenery to live without duplication " + item
		)
		_record(item + ":live", live)
		var stored: Dictionary = StadiumLiveFurnishingItems.store_copy(live, copy)
		_check(
			(
				ClubCareer.same(stored, _base26)
				and _checked(stored).stored.has(copy)
				and _apply(stored)
				and _paid.balance() == balance
			),
			"Store restores exact family26 and keeps paid identity " + item
		)
		_record(item + ":stored", stored)
		_check(
			_apply(live) and _paid.balance() == balance and _paid.construction().copies.size() == 9,
			"free remount retains all six paid copies and three starters " + item
		)
		_record(item + ":remounted", live)


func _sites_and_budgets() -> void:
	_phase = "canonical-sites-and-combined-four-unit-budget"
	for item: String in ITEMS:
		var sites: Array[String] = StadiumLiveFurnishingItems.sites(item)
		_check(
			sites.size() == (12 if item == "ST-002" else 4),
			"only authored live and scenery sites are offered " + item
		)
		for site: String in sites:
			var candidate: Dictionary = _placed(_base26, item, 0, site)
			var checked: Dictionary = _checked(candidate)
			var live: bool = site.begins_with("O")
			_check(
				(
					checked.ok
					and (
						checked.get("live_units", -1)
						== ((1 if item == "ST-002" else 3) if live else 0)
					)
				),
				"each exact site has its own live or scenery capacity " + item + ":" + site
			)
			_ownership_cases.append(
				{
					"case": "canonical-site",
					"item": item,
					"site": site,
					"live": live,
					"units": checked.get("live_units", -1)
				}
			)
	var four: Dictionary = _base26.duplicate(true)
	var small_sites: Array[String] = ["O-L1", "O-L2", "O-R1", "O-R2"]
	for index in range(4):
		four = _placed(four, "ST-002", index, small_sites[index])
	var four_check: Dictionary = _checked(four)
	_check(
		(
			four_check.ok
			and four_check.get("live_units", -1) == 4
			and four_check.get("live_furnishing_placements", []).size() == 4
		),
		"all four fixed beach-ball sites fit exactly four live instances and units"
	)
	for side: String in ["L", "R"]:
		var opposite: String = "R" if side == "L" else "L"
		var lone: Dictionary = _placed(_base26, "ST-007", 0, "OL-" + side)
		_check(_checked(lone).ok, "one whole hot tub fits independently " + side)
		var companion: Dictionary = _placed(lone, "ST-002", 0, "O-" + opposite + "2")
		_check(_checked(companion).ok, "only opposite O2 small companion fits hot tub " + side)
		for forbidden: String in ["O-" + side + "1", "O-" + side + "2", "O-" + opposite + "1"]:
			_check(
				not _checked(_placed(lone, "ST-002", 0, forbidden)).ok,
				"hot tub rejects noncanonical companion " + side + ":" + forbidden
			)
		_check(
			not _checked(_placed(lone, "ST-007", 1, "OL-" + opposite)).ok,
			"two hot tubs exceed the shared unit budget " + side
		)
		var extra: Dictionary = companion.duplicate(true)
		extra.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-" + opposite + "1", "yaw": 0}]
		_check(
			not _checked(extra).ok,
			"old starter obstacle cannot bypass the combined hot-tub budget " + side
		)
	_check(
		(
			StadiumCatalog.within_live_budget(["ST-002", "ST-002", "ST-002", "ST-002"])
			and not StadiumCatalog.within_live_budget(
				["ST-002", "ST-002", "ST-002", "ST-002", "ST-002"]
			)
		),
		"global live object cap remains four"
	)
	_check(
		(
			StadiumCatalog.within_live_budget(["ST-007", "ST-002"])
			and not StadiumCatalog.within_live_budget(["ST-007", "ST-003", "ST-002"])
		),
		"global capacity cap remains four units including legacy copies"
	)


func _ownership() -> void:
	_phase = "paid-stock-gates-and-legacy-prefix"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new(SEED, _credits, _progress)
	var old_snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"no new starter copies are granted"
	)
	for item: String in ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		var gate: Dictionary = GATES[item]
		_check(
			(
				entry.blueprint_price == PRICES[item][0]
				and entry.copy_price == PRICES[item][1]
				and ClubCareer.same(entry.requires, gate)
			),
			"prices and career unlock stay unchanged " + item
		)
		var below: Dictionary = gate.duplicate(true)
		below.seasons -= 1
		_check(
			not (
				StadiumLiveFurnishingItems
				. quote(_paid.construction(), item, 1, "locked:" + item, below)
				. ok
			),
			"one season below authored gate stays locked " + item
		)
		_check(
			(
				StadiumLiveFurnishingItems
				. quote(_paid.construction(), item, 1, "eligible:" + item, gate)
				. ok
			),
			"exact authored gate is sufficient " + item
		)
		_buy(item, 4 if item == "ST-002" else 2)
	_check(
		not (
			StadiumLiveFurnishingItems
			. quote(_paid.construction(), "ST-007", 1, "wins-locked", {"seasons": 8, "wins": 24})
			. ok
		),
		"hot tub still needs all twenty-five wins"
	)
	_check(
		_paid.to_data().version == 35 and _paid.construction().copies.size() == 9,
		"ledger35 contains only six explicitly paid copies plus three starters"
	)
	_check(
		StadiumLayoutSnapshot.matches(old_snapshot, _paid),
		"legacy snapshot still authenticates its unchanged journal prefix"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		cold != null and ClubCareer.same(cold.to_data(), _paid.to_data()),
		"purchase-only journal survives cold replay"
	)
	var held: Dictionary = _paid.to_data().duplicate(true)
	var stale: Dictionary = _paid.commit(
		{
			"id": "furnishing-stale-price",
			"rev": _paid.revision(),
			"op": "stadium_buy",
			"item": "ST-002",
			"quantity": 1,
			"price_version": 18,
			"through": 40,
			"progress_through": 40
		}
	)
	_check(
		not stale.ok and ClubCareer.same(held, _paid.to_data()),
		"stale purchase price version fails without debit or new copies"
	)
	var land: Dictionary = _paid.commit(
		{
			"id": "furnishing-expanded",
			"rev": _paid.revision(),
			"op": "stadium_land",
			"tier": "expanded",
			"through": 40,
			"progress_through": 40,
			"price_version": StadiumLand.VERSION
		}
	)
	_check(land.ok, "ordinary paid Expanded grounds unlock hot-tub scenery sites")
	_base26 = StadiumLandscapeOwnedItems.upgrade(_paid.view().stadium_active, _paid.surface_owned())
	_check(
		not _base26.is_empty() and _base26.version == 26,
		"historical family26 upgrades without granting or selecting furnishings"
	)
	if _base26.is_empty():
		return
	_base26.receiver = "starter-v1:ST-079"
	_check(
		_checked(_base26).ok and _apply(_base26),
		"nonempty inherited receiver and field channels apply through the old grammar"
	)
	_record("inherited-base26", _base26)
	_layout = StadiumLiveFurnishingItems.upgrade(_base26, _paid.surface_owned())
	_check(
		(
			ClubCareer.same(StadiumLiveFurnishingItems.base(_layout), _base26)
			and _layout.live_furnishings.is_empty()
		),
		"new wrapper preserves every inherited channel exactly"
	)
	_sites_and_budgets()
	_same_copy_modes()
	_layout = _placed(_base26, "ST-007", 0, "OL-L")
	_layout = _placed(_layout, "ST-002", 0, "O-R2")
	_layout = _placed(_layout, "ST-002", 1, "YS-L1")
	_layout = _placed(_layout, "ST-007", 1, "YL-R")
	var checked: Dictionary = _checked(_layout)
	_check(
		(
			checked.ok
			and checked.get("live_units", -1) == 4
			and checked.get("live_furnishing_placements", []).size() == 4
		),
		"one hot tub plus opposite small companion and two scenery copies fit exact four-unit budget"
	)
	_check(
		(
			ClubCareer.same(StadiumLiveFurnishingItems.base(_layout), _base26)
			and ClubCareer.same(StadiumLiveFurnishingItems.prune(_layout), _layout)
		),
		"mixed live and scenery placements preserve inherited base and canonical pruning"
	)
	_negatives()
	var pool: Dictionary = StadiumCatalog.item("ST-006")
	_check(
		(
			pool.blueprint_price == 540
			and pool.copy_price == 160
			and ClubCareer.same(pool.requires, {"seasons": 6, "wins": 18})
			and not StadiumLiveFurnishingItems.PRICES.has("ST-006")
			and StadiumLiveFurnishingItems.row("unowned-pool", "ST-006", "OL-L").is_empty()
		),
		"old ST-006 pool price gate and independent ownership grammar remain untouched"
	)
	var balance: int = _paid.balance()
	_check(
		_apply(_layout) and _paid.balance() == balance and _paid.construction().copies.size() == 9,
		"ordinary mixed family27 draft and apply remain free without inventory changes"
	)
	_record("mixed-live-and-scenery27", _layout)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not checked.get("night_qualified", true)
		),
		"ordinary installed fixture explicitly remains daylight-only"
	)


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func _actor_routes(lab: PitchBatLab, rows: Array, routes: Array[Dictionary]) -> void:
	_phase = "actual-fielder-controller-routes"
	var actor: FielderController = lab._primary_fielder
	var old_anchor: Vector3 = actor.anchor_position
	var old_pitcher: float = actor.pitcher_lane_z
	actor.pitcher_lane_z = INF
	for placed: Dictionary in rows:
		var center: Vector3 = placed.position
		if not placed.site.begins_with("O"):
			var from: Vector3 = center + Vector3(-2, 0, 0)
			var to: Vector3 = center + Vector3(2, 0, 0)
			_check(
				(
					StadiumDefenderRoutes.clear(from, to, routes)
					and StadiumDefenderRoutes.clip(from, to, routes) == to
				),
				"scenery footprint adds no route detour or stop " + placed.item
			)
			continue
		var from: Vector3 = center + Vector3(-4, 0, 0)
		var to: Vector3 = center + Vector3(4, 0, 0)
		actor.set_anchor(from)
		actor.begin_play(false)
		actor.reaction_delay_seconds = 0
		actor.target_position = to
		var clearance: float = INF
		var legal: bool = true
		var detour: float = 0
		var ticks: int = 0
		for tick in range(360):
			var previous: Vector3 = actor.global_position
			actor._physics_process(1.0 / 60.0)
			var current: Vector3 = actor.global_position
			legal = legal and StadiumDefenderRoutes.clear(previous, current, routes)
			detour = maxf(detour, absf(current.z - center.z))
			for obstacle: Dictionary in routes:
				clearance = minf(
					clearance,
					(
						DefenderSpacing.segment_distance_xz(obstacle.center, previous, current)
						- float(obstacle.radius)
					)
				)
			ticks = tick + 1
			if current.distance_to(to) <= 0.06:
				break
		_operands = {
			"item": placed.item,
			"site": placed.site,
			"start": _v3(from),
			"target": _v3(to),
			"finish": _v3(actor.global_position),
			"ticks": ticks,
			"minimum_route_clearance": clearance,
			"detour": detour
		}
		_check(
			legal and clearance >= -0.0001 and detour > 0.1,
			(
				"actual FielderController uses collision-clear detour around complete furnishing "
				+ placed.item
			)
		)
		_check(
			actor.global_position.distance_to(to) <= 0.06,
			(
				"actual FielderController reaches the opposite-side target without trapping "
				+ placed.item
			)
		)
		_route_cases.append(_operands.duplicate(true))
		actor.end_play()
	actor.set_anchor(old_anchor)
	actor.pitcher_lane_z = old_pitcher


func _camera_clearance(lab: PitchBatLab, rows: Array) -> void:
	_phase = "existing-batting-camera-extrema"
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
			for placed: Dictionary in rows:
				var box: AABB = (
					Transform3D(Basis.IDENTITY, placed.position)
					* StadiumLiveFurnishingModels.reservation(placed.item)
				)
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
				"actual batting camera origin and pitcher sightline clear every complete furnishing reservation"
			)
			_camera_cases.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress


func _bound(
	root: Node3D,
	boundary: StadiumBoundaryOwnedRuntime,
	at: Vector3,
	foul: bool,
	frozen: bool = false
) -> Dictionary:
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	resolver.segment_observer = boundary.observe
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = frozen
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	root.add_child(ball)
	ball.position = at
	var property: StadiumPropertyGeometry = boundary.get_parent() as StadiumPropertyGeometry
	property.bind_ball(ball, resolver)
	boundary.bind_ball(ball, resolver)
	return {"ball": ball, "resolver": resolver}


func _current_body_guard(
	root: Node3D, boundary: StadiumBoundaryOwnedRuntime, property: StadiumPropertyGeometry
) -> void:
	_phase = "current-body-seal-and-consumed-token"
	var model: Node3D = property.objects[_copies["ST-002"][0]]
	var body: StaticBody3D = model.get_node("Collision/BEACH_BALL") as StaticBody3D
	var from: Vector3 = model.global_position + Vector3(-1.0, 0.4, 0)
	var context: Dictionary = _bound(root, boundary, from, false, true)
	var issued: Dictionary = boundary.event(
		from, model.global_position + Vector3(0, 0.4, 0), 0.0365, context.resolver
	)
	var copy: String = str(body.get_meta("owned_copy"))
	body.set_meta("owned_copy", _copies["ST-002"][1])
	_check(
		(
			not boundary.apply_event(context.resolver, issued)
			and context.resolver.state.stadium_contacts.is_empty()
			and not property.props_intact()
		),
		"current-body paid-identity change invalidates its previously issued event"
	)
	body.set_meta("owned_copy", copy)
	_check(
		(
			not boundary.apply_event(context.resolver, issued)
			and context.resolver.state.stadium_contacts.is_empty()
		),
		"restoring a body label cannot revive the consumed rejected token"
	)
	context.ball.free()


func _current_water_guard(property: StadiumPropertyGeometry) -> void:
	_phase = "current-water-visual-parent-guard"
	var copy: String = _copies["ST-007"][0]
	var tub: Node3D = property.objects[copy]
	var visual: Node3D = tub.get_node("Visual")
	var original: Transform3D = visual.transform
	visual.position.y += 0.02
	_operands = {
		"copy": copy,
		"member": "Visual",
		"original_local_transform": str(original),
		"mutated_local_transform": str(visual.transform),
		"local_y_offset_m": 0.02
	}
	var rejected: bool = not property.props_intact()
	_check(
		rejected,
		"moving the actual water Visual parent invalidates current property water geometry"
	)
	visual.transform = original
	var restored: bool = (
		property.props_intact()
		and StadiumLiveFurnishingRuntime.water_intact(tub, property._furnishing_water.get(copy, {}))
	)
	_operands = {
		"copy": copy,
		"member": "Visual",
		"restored_exact_transform": visual.transform == original,
		"current_water_intact": restored
	}
	_check(
		restored, "exactly restoring the Visual parent verifies the current water geometry again"
	)
	_physical["water_visual_parent_guard"] = {
		"copy": copy,
		"member": "Visual",
		"local_y_offset_m": 0.02,
		"mutation_rejected": rejected,
		"exact_restore_intact": restored
	}


func _launch(context: Dictionary, from: Vector3, velocity: Vector3) -> void:
	# Register the fresh dynamic native body before the ordinary launch callback.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = from
	launch.velocity = velocity
	context.ball.launch(launch)
