extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One integrated paid ownership, physical contact, route and readable view qualification.

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Dictionary = {}
var _layout: Dictionary = {}
var _outcomes: Array = []
var _contact_cases: Array = []
var _report_provenance: Array = []
var _terrain_layouts: Array[Dictionary] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"BOUNDARY_REBUILD_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered boundary qualification with explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		_ownership()
		if not _layout.is_empty():
			await _runtime()
			_phase = "model-geometry"
			var root: Node3D = _world()
			await StadiumBoundaryGeometryRebuildChecks.run(root, _check)
			await _close_view()
			await _views()
	_phase = "completion"
	_check(
		_images == ["boundary-overview.png", "boundary-details.png"],
		"two readable originals, one shared selector and zero games"
	)
	var payload: Dictionary = {
		"checks": _checks,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"contact_cases": _contact_cases,
		"report_provenance": _report_provenance,
		"paid_copy_ids": _copies,
		"layout": _layout,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"back_wall_table":
		"defender_touched OR grounded Double; otherwise airborne Triple; preserve higher floor",
		"open_art":
		["line aliasing", "pole color", "concrete shadows", "optional attached pole flags"]
	}
	var file: FileAccess = FileAccess.open(
		directory.path_join("boundary-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "bounded shared evidence opens")
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "evidence fully writes")
		file.close()
	print(
		(
			"BOUNDARY_REBUILD checks=%d failures=%d images=%d games=0 synthetic_funding=true"
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _buy(item: String, quantity: int, version: int) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "boundary-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var entry: Dictionary = StadiumCatalog.item(item)
	var cost: int = (
		int(entry.copy_price) * quantity
		+ (0 if _paid.construction().blueprints.has(item) else int(entry.blueprint_price))
	)
	var balance: int = _paid.balance()
	var result: Dictionary = _paid.commit(command)
	_operands = {"item": item, "error": result.get("error", ""), "cost": cost}
	_check(result.ok and _paid.balance() == balance - cost, "unchanged Working purchase " + item)
	_check(
		_paid.commit(command).get("replayed", false) and _paid.balance() == balance - cost,
		"exact purchase retry " + item
	)
	_copies[item] = []
	for index in range(quantity):
		_copies[item].append("purchase:boundary-buy:%d:%d" % [revision, index])


func _valid(layout: Dictionary, message: String, tier: String = "expanded") -> bool:
	var result: Dictionary = StadiumBoundaryItems.validate(layout, _paid.construction(), tier)
	_operands = {
		"error": result.get("error", ""),
		"boundary": layout.get("boundary", []).size(),
		"left": layout.walls.left.size(),
		"right": layout.walls.right.size()
	}
	_check(result.ok, message)
	return result.ok


func _place(item: String, index: int, site: String, host: String = "") -> void:
	_layout = StadiumBoundaryItems.select(
		_layout,
		_paid.construction(),
		_copies[item][index],
		{"copy": "", "item": item, "site": site, "host": host}
	)


func _ownership() -> void:
	_phase = "paid-stock-and-cold-ownership"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new(81, _credits, _progress)
	var legacy: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_buy("ST-032", 2, StadiumBoundaryItems.PRICE_VERSION)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), 81, _credits, _progress
	)
	_check(
		cold != null and ClubCareer.same(cold.to_data(), _paid.to_data()),
		"boundary-only paid receipt cold replays"
	)
	_check(
		StadiumLayoutSnapshot.matches(legacy, _paid),
		"old snapshot still authenticates its exact prefix"
	)
	var land: Dictionary = _paid.commit(
		{
			"id": "expanded",
			"rev": _paid.revision(),
			"op": "stadium_land",
			"tier": "expanded",
			"through": 40,
			"progress_through": 40,
			"price_version": StadiumLand.VERSION
		}
	)
	_check(land.ok, "ordinary Expanded purchase")
	for item: String in ["ST-074", "ST-021", "ST-064"]:
		_buy(item, 2, StadiumBoundaryItems.PRICE_VERSION)
	for item: String in ["ST-020", "ST-071"]:
		_buy(item, 8, StadiumBoundaryItems.PRICE_VERSION)
	for item: String in ["ST-022", "ST-023"]:
		_buy(item, 19, StadiumWallItems.PRICE_VERSION)
	_buy("ST-024", 23, StadiumWallItems.PRICE_VERSION)
	_buy("ST-065", 23, StadiumWallItems.PRICE_VERSION)
	_layout = StadiumBoundaryItems.upgrade(_paid.view().stadium_active, _paid.surface_owned())
	_check(not _layout.is_empty(), "new wrapper preserves inherited field without grants")
	if _layout.is_empty():
		return
	for side: String in ["left", "right", "back"]:
		var item: String = "ST-024" if side == "back" else "ST-022" if side == "left" else "ST-023"
		var proposal: Dictionary = StadiumWallLayout.propose(
			_layout.walls, _paid.construction(), side, item
		)
		_check(proposal.ok, "complete owned original run " + side)
		if proposal.ok:
			_layout.walls = proposal.walls
	var original: Dictionary = _layout.duplicate(true)
	_place("ST-032", 0, "DUGOUT-L")
	_place("ST-074", 0, "DUGOUT-R")
	_check(
		_layout.walls.left.size() == 16 and _layout.walls.right.size() == 16,
		"each independent dugout cuts exactly three of nineteen paid side copies"
	)
	if not _valid(_layout, "timber left and concrete right coexist at exact additive placements"):
		return
	var checked: Dictionary = StadiumBoundaryItems.validate(
		_layout, _paid.construction(), "expanded"
	)
	var removed: Array = []
	for side: String in ["left", "right"]:
		var three: Array = []
		for copy: String in original.walls[side]:
			if not _layout.walls[side].has(copy):
				three.append(copy)
				removed.append(copy)
		_check(
			(
				three.size() == 3
				and three.all(func(copy: String) -> bool: return checked.stored.has(copy))
			),
			"three displaced copies remain owned and stored " + side
		)
		var restored: Dictionary = StadiumBoundaryItems.restore_side(
			_layout, _paid.construction(), side == "left", three
		)
		_check(
			restored.ok and restored.layout.walls[side] == original.walls[side],
			"explicit sixteen plus three restores original handed paid run " + side
		)
		_check(
			not (
				StadiumBoundaryItems
				. restore_side(
					_layout, _paid.construction(), side == "left", [three[0], three[0], three[2]]
				)
				. ok
			),
			"duplicate restoration cannot invent stock " + side
		)
	var empty_side: Dictionary = StadiumBoundaryItems.select(
		_layout, _paid.construction(), _copies["ST-032"][0], {}
	)
	_check(
		empty_side.walls.left.is_empty() and empty_side.walls.right.size() == 16,
		"whole-side template restoration stores sixteen without changing other side"
	)
	var replaced: Dictionary = StadiumBoundaryItems.select(
		_layout,
		_paid.construction(),
		_copies["ST-074"][1],
		{"copy": "", "item": "ST-074", "site": "DUGOUT-L", "host": ""}
	)
	_check(
		(
			StadiumBoundaryItems.validate(replaced, _paid.construction(), "expanded").stored.has(
				_copies["ST-032"][0]
			)
			and replaced.walls.left.size() == 16
		),
		"replacing timber stores exact old dugout while keeping cut run"
	)
	var timber_only: Dictionary = StadiumBoundaryItems.select(
		_layout, _paid.construction(), _copies["ST-074"][0], {}
	)
	_valid(timber_only, "timber is additive Backyard fit", "backyard")
	var one_graph: StadiumBoundaryOwnedGraph = StadiumBoundaryItems.graph_for(timber_only)
	_check(
		(
			not one_graph.segment("DUGOUT-L-OPEN").is_empty()
			and one_graph.segment("DUGOUT-R-OPEN").is_empty()
			and not one_graph.segment("SIDE-R-01").is_empty()
		),
		"left-only dugout leaves original independent right boundary intact"
	)
	_check(
		not StadiumBoundaryItems.validate(_layout, _paid.construction(), "backyard").ok,
		"concrete requires Expanded without changing old fit recipes"
	)
	for index in range(2):
		_place("ST-021", index, "FOUL-POLE-L" if index == 0 else "FOUL-POLE-R")
	var hosts: Array[Dictionary] = StadiumBoundaryItems.panel_host_rows(
		_layout, _paid.construction()
	)
	_check(
		hosts.size() == 21 and hosts.all(func(row: Dictionary) -> bool: return row.span == "full"),
		"distance panels offer only twenty-one full straight-wall copies"
	)
	for index in range(2):
		_place("ST-064", index, "DISTANCE:" + str(hosts[index * 10].copy), hosts[index * 10].copy)
	_layout = StadiumBoundaryItems.select_rear(_layout, _paid.construction(), "ST-020")
	_valid(_layout, "complete wood rear, graph-derived poles and exact-host panels coexist")
	var chain: Dictionary = StadiumBoundaryItems.select_rear(
		_layout, _paid.construction(), "ST-071"
	)
	var chain_checked: Dictionary = StadiumBoundaryItems.validate(
		chain, _paid.construction(), "expanded"
	)
	_check(
		(
			chain_checked.ok
			and _copies["ST-020"].all(
				func(copy: String) -> bool: return chain_checked.stored.has(copy)
			)
		),
		"eight matching chain modules store all eight wood copies"
	)
	var no_rear: Dictionary = StadiumBoundaryItems.select_rear(chain, _paid.construction(), "")
	var no_rear_checked: Dictionary = StadiumBoundaryItems.validate(
		no_rear, _paid.construction(), "expanded"
	)
	_check(
		(
			no_rear_checked.ok
			and _copies["ST-071"].all(
				func(copy: String) -> bool: return no_rear_checked.stored.has(copy)
			)
		),
		"whole rear removal restores template and stores every module"
	)
	var bad: Dictionary = chain.duplicate(true)
	bad.boundary.pop_back()
	_check(
		not StadiumBoundaryItems.validate(bad, _paid.construction(), "expanded").ok,
		"seven rear modules cannot become a replacement"
	)
	bad = chain.duplicate(true)
	for row: Dictionary in bad.boundary:
		if row.site == "REAR-00":
			row.copy = _copies["ST-020"][0]
			row.item = "ST-020"
	_check(
		not StadiumBoundaryItems.validate(bad, _paid.construction(), "expanded").ok,
		"mixed wood and chain rear set refuses"
	)
	bad = _layout.duplicate(true)
	var panel: Dictionary = bad.boundary.filter(func(row: Dictionary) -> bool: return row.item == \
		"ST-064")[0]
	panel.host = _layout.walls.back.copies[0]
	panel.site = "DISTANCE:" + panel.host
	bad.boundary.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	_check(
		not StadiumBoundaryItems.validate(bad, _paid.construction(), "expanded").ok,
		"short closure is not a panel host"
	)
	var without_host: Dictionary = _layout.duplicate(true)
	without_host.walls.back = {}
	without_host = StadiumBoundaryItems.prune(without_host)
	var host_checked: Dictionary = StadiumBoundaryItems.validate(
		without_host, _paid.construction(), "expanded"
	)
	_check(
		(
			host_checked.ok
			and _copies["ST-064"].all(
				func(copy: String) -> bool: return host_checked.stored.has(copy)
			)
		),
		"host removal stores panels without selling or granting them"
	)
	var balance: int = _paid.balance()
	_check(_apply(_layout), "ordinary draft and apply commit boundary23")
	_check(
		_apply(chain) and _apply(_layout) and _paid.balance() == balance,
		"replacement, storage and cold remount stay free"
	)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		not snapshot.is_empty() and StadiumLayoutSnapshot.matches(snapshot, _paid),
		"snapshot authenticates new layout and exact graph"
	)
	cold = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), 81, _credits, _progress
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
		),
		"cold JSON preserves all exact boundary ownership and graph"
	)
	for mode: String in [
		"wrong-item", "unknown-field", "duplicate-copy", "unknown-site", "unowned-copy", "bad-host"
	]:
		bad = _layout.duplicate(true)
		var row: Dictionary = bad.boundary[0]
		match mode:
			"wrong-item":
				row.item = "ST-032"
			"unknown-field":
				row["phantom"] = true
			"duplicate-copy":
				bad.boundary[1].copy = row.copy
			"unknown-site":
				row.site = "INVENTED"
			"unowned-copy":
				row.copy = "purchase:missing:0"
			"bad-host":
				row.host = "purchase:missing:0"
		_check(
			not StadiumBoundaryItems.validate(bad, _paid.construction(), "expanded").ok,
			"malformed exact boundary record refuses " + mode
		)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(snapshot, 81, 2)
	_check(
		StadiumFixtureEnvironment.valid(environment, snapshot),
		"shared fixture environment accepts exact boundary snapshot"
	)
	for mode: String in ["rough", "leveled"]:
		var surface: Dictionary = StadiumSurfaceLayout.upgrade(
			StadiumStarterLayout.empty(), _paid.surface_owned()
		)
		surface.surface.foundation = "dirt"
		surface.surface.condition = "prepared" if mode == "leveled" else "rough"
		surface = StadiumSurfaceLayout.terrain_upgrade(surface, _paid.surface_owned())
		var terrain: Dictionary = StadiumBoundaryItems.upgrade(surface, _paid.surface_owned())
		terrain = StadiumBoundaryItems.select(
			terrain,
			_paid.construction(),
			_copies["ST-032"][0],
			{"copy": "", "item": "ST-032", "site": "DUGOUT-L", "host": ""}
		)
		_check(
			(
				not terrain.is_empty()
				and StadiumBoundaryItems.is_terrain(terrain)
				and StadiumBoundaryItems.validate(terrain, _paid.construction(), "backyard").ok
			),
			"timber pads remain ground-zero on " + mode + " terrain"
		)
		_terrain_layouts.append(terrain)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "boundary-draft:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		_operands = {"error": draft.get("error", "")}
		return false
	var applied: Dictionary = _paid.commit(
		{
			"id": "boundary-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("expanded", layout)
		}
	)
	_operands = {"error": applied.get("error", "")}
	return applied.ok


func _runtime() -> void:
	_phase = "actual-boundary-and-distinct-contact-cases"
	var root: Node3D = _world()
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = property.build("expanded", _layout, _paid.construction())
	_check(built, "shared property builds full mixed boundary layout")
	if not built:
		property.free()
		await _close_view()
		return
	root.add_child(property)
	var boundary: StadiumBoundaryOwnedRuntime = (
		StadiumBoundaryRuntime.assemble(property) as StadiumBoundaryOwnedRuntime
	)
	_check(boundary != null, "shared runtime selects the exact owned boundary owner")
	if boundary == null:
		await _close_view()
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		boundary.intact() and property.props_intact(),
		"all ordinary and paid boundary identities remain intact"
	)
	_check(
		property.route_obstacles().is_empty(),
		"boundary additions do not create new live defender obstacles"
	)
	for left: bool in [true, false]:
		var site: String = "DUGOUT-L" if left else "DUGOUT-R"
		var cases: Array = [
			[13.0, 0.5, "DUGOUT_OPENING_DEAD"],
			[11.0, 0.5, "DUGOUT_FACE_LIVE"],
			[12.02, 0.5, "DUGOUT_FACE_LIVE"],
			[12.05, 0.5, "DUGOUT_OPENING_DEAD"],
			[13.0, 3.0, "DUGOUT_EXTERIOR_DEAD"]
		]
		if not left:
			cases.append([13.0, 2.38, "DUGOUT_ROOF_TERMINAL"])
		for row: Array in cases:
			var from: Vector3 = (
				StadiumDugoutRecipe.rail_point(row[0], -0.5, left) + Vector3.UP * row[1]
			)
			var to: Vector3 = (
				StadiumDugoutRecipe.rail_point(row[0], 0.7, left) + Vector3.UP * row[1]
			)
			var event: Dictionary = boundary.event(from, to, 0.0365)
			_operands = {"site": site, "s": row[0], "y": row[1], "event": event}
			_check(
				event.get("role", "") == row[2],
				"actual sphere selects aperture, jamb, face or roof " + site
			)
			if row[2] in ["DUGOUT_FACE_LIVE", "DUGOUT_ROOF_TERMINAL"]:
				_check(
					(
						event.get("body_id", 0) > 0
						and not String(event.get("owned_copy", "")).is_empty()
					),
					"solid contact carries actual exact paid body identity"
				)
			_contact_cases.append(
				{
					"site": site,
					"s": row[0],
					"y": row[1],
					"role": event.get("role", ""),
					"body_id": event.get("body_id", 0)
				}
			)
			if row[2] == "DUGOUT_EXTERIOR_DEAD":
				var exterior: Dictionary = _bound(root, boundary, from, false)
				boundary.observe(exterior.resolver, from, to)
				_check(
					_outcomes.size() == 1 and _outcomes[0].result == BallPlayOutcome.Result.SINGLE,
					"actual over-aperture exterior preserves minimum single"
				)
				_report_contact(exterior.resolver, false, site + ":exterior")
				exterior.ball.free()
		for foul: bool in [false, true]:
			for earned: int in [BallPlayState.ResultFloor.NONE, BallPlayState.ResultFloor.DOUBLE]:
				var from: Vector3 = (
					StadiumDugoutRecipe.rail_point(13, -0.5, left) + Vector3.UP * 0.5
				)
				var to: Vector3 = StadiumDugoutRecipe.rail_point(13, 0.7, left) + Vector3.UP * 0.5
				var context: Dictionary = _bound(root, boundary, from, foul)
				context.resolver.state.raise_result_floor(earned)
				boundary.observe(context.resolver, from, to)
				var expected: int = (
					BallPlayOutcome.Result.FOUL
					if foul
					else (
						BallPlayOutcome.Result.DOUBLE
						if earned > 0
						else BallPlayOutcome.Result.SINGLE
					)
				)
				_check(
					_outcomes.size() == 1 and _outcomes[0].result == expected,
					"actual aperture preserves initial foul and earned floor"
				)
				var count: int = context.resolver.state.stadium_contacts.size()
				context.resolver.record_clean_control(&"late-defender", to, true)
				_check(
					(
						boundary.observe(context.resolver, to, from).is_empty()
						and _outcomes.size() == 1
						and context.resolver.state.stadium_contacts.size() == count
					),
					"terminal entry prevents rebound and later catch"
				)
				_report_contact(context.resolver, foul, site + ":entry:%s:%d" % [str(foul), earned])
				context.ball.free()
		var from: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.8, left)
		var to: Vector3 = StadiumDugoutRecipe.rail_point(13, 1.0, left)
		var clipped: Vector3 = boundary.graph.clip(from, to)
		_check(
			(
				clipped.distance_to(from) < to.distance_to(from)
				and boundary.graph.contains(Vector2(clipped.x, clipped.z))
			),
			"defender swept-circle route stays outside actual dugout opening"
		)
	for pole: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		var normal: Vector2 = boundary.graph.inward(boundary.graph.segment(pole.segment))
		for state: String in ["upper", "lower", "touched", "grounded", "higher-floor"]:
			var height: float = 0.8 if state == "lower" else pole.split + 0.10
			var from: Vector3 = pole.position + Vector3(normal.x * 0.5, height, normal.y * 0.5)
			var to: Vector3 = pole.position + Vector3(-normal.x, height, -normal.y)
			var context: Dictionary = _bound(root, boundary, from, true)
			context.resolver.state.defender_touched = state == "touched"
			context.resolver.state.has_grounded = state == "grounded"
			if state == "higher-floor":
				context.resolver.state.raise_result_floor(BallPlayState.ResultFloor.HOME_RUN)
			var event: Dictionary = boundary.observe(context.resolver, from, to)
			var expected: int = (
				BallPlayOutcome.Result.DOUBLE
				if state in ["touched", "grounded"]
				else (
					BallPlayOutcome.Result.TRIPLE
					if state == "lower"
					else BallPlayOutcome.Result.HOME_RUN
				)
			)
			_operands = {
				"pole": pole.site, "case": state, "event": event, "outcomes": _outcomes.size()
			}
			_check(
				(
					event.get("kind", "") == "pole"
					and event.get("body_id", 0) > 0
					and _outcomes.size() == 1
					and _outcomes[0].result == expected
					and not context.resolver.state.is_foul_play
				),
				"real pole wins coincident wall and uses unchanged result table " + state
			)
			var recorded: Array = context.resolver.state.stadium_contacts.duplicate(true)
			context.resolver.record_clean_control(&"late-defender", to, true)
			_check(
				(
					boundary.observe(context.resolver, to, from).is_empty()
					and context.resolver.state.stadium_contacts == recorded
					and _outcomes.size() == 1
				),
				"pole emits one terminal result and no later catch"
			)
			_contact_cases.append(
				{
					"site": pole.site,
					"case": state,
					"kind": event.get("kind", ""),
					"body_id": event.get("body_id", 0)
				}
			)
			_report_contact(context.resolver, true, pole.site + ":" + state)
			context.ball.free()
	var rear: Dictionary = _bound(root, boundary, Vector3(1, 0.5, -5), false)
	var rear_event: Dictionary = boundary.observe(
		rear.resolver, Vector3(1, 0.5, -5), Vector3(1, 0.5, -7)
	)
	_check(
		(
			rear_event.get("role", "") == "REAR_PERIMETER_DEAD"
			and not String(rear_event.get("owned_copy", "")).is_empty()
			and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.FOUL
		),
		"paid rear contact preserves original Foul instead of becoming a scoring wall"
	)
	_report_contact(rear.resolver, false, "rear:wood")
	rear.ball.free()
	for row: Dictionary in (
		StadiumBoundaryItems.validate(_layout, _paid.construction(), "expanded").boundary_placements
	):
		if row.item != "ST-064":
			continue
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position
		)
		var from: Vector3 = pose * Vector3(0, 0, 0.7)
		var to: Vector3 = pose * Vector3(0, 0, -0.5)
		var context: Dictionary = _bound(root, boundary, from, false)
		var event: Dictionary = boundary.observe(context.resolver, from, to)
		_operands = {"panel": row.copy, "host": row.host, "event": event}
		_check(
			(
				event.get("kind", "") == "panel"
				and event.get("owned_copy", "") == row.copy
				and _outcomes.size() == 1
				and _outcomes[0].result == BallPlayOutcome.Result.TRIPLE
			),
			"actual panel face is bound to its full owned host and back-wall table"
		)
		_contact_cases.append(
			{"site": row.site, "kind": event.get("kind", ""), "body_id": event.get("body_id", 0)}
		)
		_report_contact(context.resolver, false, row.site)
		context.ball.free()

	await _physical_flights(root, boundary)
	var stale: Dictionary = _bound(root, boundary, Vector3.ZERO, false)
	var issued: Dictionary = boundary.event(
		StadiumDugoutRecipe.rail_point(13, -0.5, true) + Vector3.UP * 0.5,
		StadiumDugoutRecipe.rail_point(13, 0.5, true) + Vector3.UP * 0.5,
		0.0365,
		stale.resolver
	)
	var substitute: BattedBallBody = BattedBallBody.new()
	substitute.freeze = true
	root.add_child(substitute)
	boundary.bind_ball(substitute, stale.resolver)
	_check(
		not boundary.apply_event(stale.resolver, issued) and not stale.resolver.state.dead,
		"same resolver and play cannot transfer a contact token to another physical ball"
	)
	substitute.free()
	boundary.bind_ball(stale.ball, stale.resolver)
	stale.resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	_check(
		not boundary.apply_event(stale.resolver, issued) and not stale.resolver.state.dead,
		"previous-play token cannot score a different flight"
	)
	stale.ball.free()
	var model: Node3D = property.objects[_copies["ST-021"][0]]
	model.set_meta("owned_copy", _copies["ST-021"][1])
	_check(not boundary.intact(), "relabelled paid pole permanently retires boundary authority")
	model.set_meta("owned_copy", _copies["ST-021"][0])
	_check(not boundary.intact(), "restoring a label cannot reactivate retired boundary authority")
	await _close_view()

	root = _world()
	var chain_layout: Dictionary = StadiumBoundaryItems.select_rear(
		_layout, _paid.construction(), "ST-071"
	)
	var chain_property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var chain_built: bool = chain_property.build("expanded", chain_layout, _paid.construction())
	_check(chain_built, "chain replacement assembles its eight exact owned modules")
	if chain_built:
		root.add_child(chain_property)
		var chain_boundary: StadiumBoundaryOwnedRuntime = (
			StadiumBoundaryRuntime.assemble(chain_property) as StadiumBoundaryOwnedRuntime
		)
		await get_tree().physics_frame
		var context: Dictionary = _bound(root, chain_boundary, Vector3(-1, 0.5, -5), false)
		var event: Dictionary = chain_boundary.observe(
			context.resolver, Vector3(-1, 0.5, -5), Vector3(-1, 0.5, -7)
		)
		_check(
			(
				event.get("role", "") == "REAR_PERIMETER_DEAD"
				and _copies["ST-071"].has(event.get("owned_copy", ""))
				and _outcomes.size() == 1
				and _outcomes[0].result == BallPlayOutcome.Result.FOUL
			),
			"actual chain module contact retains same rear Foul semantics"
		)
		_report_contact(context.resolver, false, "rear:chain", chain_layout)
		context.ball.free()
	else:
		chain_property.free()
	await _close_view()
	for terrain: Dictionary in _terrain_layouts:
		root = _world()
		var terrain_property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		var terrain_built: bool = terrain_property.build("backyard", terrain, _paid.construction())
		_check(terrain_built, "physical terrain and timber assemble through shared property")
		if terrain_built:
			root.add_child(terrain_property)
			var terrain_boundary: StadiumBoundaryOwnedRuntime = (
				StadiumBoundaryRuntime.assemble(terrain_property) as StadiumBoundaryOwnedRuntime
			)
			await get_tree().physics_frame
			_check(
				(
					terrain_boundary != null
					and terrain_boundary.intact()
					and terrain_property.props_intact()
				),
				"rough or leveled boundary retains exact models and untouched terrain"
			)
		else:
			terrain_property.free()
		await _close_view()


func _bound(
	root: Node3D,
	boundary: StadiumBoundaryOwnedRuntime,
	at: Vector3,
	foul: bool,
	frozen: bool = true
) -> Dictionary:
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = frozen
	root.add_child(ball)
	ball.position = at
	boundary.bind_ball(ball, resolver)
	return {"ball": ball, "resolver": resolver}


func _physical_flights(root: Node3D, boundary: StadiumBoundaryOwnedRuntime) -> void:
	var cases: Array = [
		[true, 13.0, 0.5, "DUGOUT_OPENING_DEAD"],
		[false, 13.0, 2.38, "DUGOUT_ROOF_TERMINAL"],
		[true, 11.0, 0.5, "DUGOUT_FACE_LIVE"]
	]
	for row: Array in cases:
		var from: Vector3 = (
			StadiumDugoutRecipe.rail_point(row[1], -0.8, row[0]) + Vector3.UP * row[2]
		)
		var context: Dictionary = _bound(root, boundary, from, false, false)
		context.ball.gravity_scale = 0
		context.ball.aero_drag_coefficient = 0
		context.ball.aero_magnus_scale = 0
		context.ball.aero_perforation_force_scale = 0
		# Match the accepted fresh dynamic-ball path and let its native body register before launch.
		await get_tree().physics_frame
		await get_tree().physics_frame
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = from
		launch.velocity = StadiumDugoutRecipe.placement(row[0]).basis.z * 20
		context.ball.launch(launch)
		var start_velocity: Vector3 = context.ball.linear_velocity
		var start_position: Vector3 = context.ball.global_position
		for frame in range(45):
			await get_tree().physics_frame
			if not context.resolver.state.stadium_contacts.is_empty():
				break
		var contacts: Array = context.resolver.state.stadium_contacts
		_operands = {
			"expected": row[3],
			"contacts": contacts,
			"from": str(from),
			"launch_velocity": str(launch.velocity),
			"start_position": str(start_position),
			"start_velocity": str(start_velocity),
			"current_position": str(context.ball.global_position),
			"current_velocity": str(context.ball.linear_velocity),
			"frozen": context.ball.freeze,
			"space_matches":
			PhysicsServer3D.body_get_space(context.ball.get_rid()) == root.get_world_3d().space,
			"router_bound": context.ball.physics_contact_router.is_valid(),
			"flight_bound": not boundary._flight(context.resolver).is_empty()
		}
		_check(
			not contacts.is_empty() and contacts[0].role == row[3],
			"actual moving physical ball reaches distinct paid boundary role"
		)
		_check(
			context.resolver.state.dead == (row[3] != "DUGOUT_FACE_LIVE"),
			"physical live face and terminal opening or roof stay distinct"
		)
		_report_contact(context.resolver, false, "moving:" + row[3])
		context.ball.free()
		await get_tree().physics_frame


func _report_contact(
	resolver: BallPlayResolver, initially_foul: bool, label: String, layout: Dictionary = {}
) -> void:
	# Feed actual resolver events to the existing report consumer, without fabricating a game.
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	if not layout.is_empty():
		snapshot.layout = layout.duplicate(true)
		snapshot.geometry = StadiumHomeLayout.geometry(snapshot.tier, layout)
		snapshot.boundary = StadiumOwnedLayout.boundary_signature(layout)
		snapshot = StadiumLayoutSnapshot.normalized(snapshot)
	var names: Array[String] = ["out", "foul", "single", "double", "triple", "home_run"]
	var result: String = "out" if _outcomes.is_empty() else names[_outcomes[0].result]
	var reason: String = "" if _outcomes.is_empty() else String(_outcomes[0].reason)
	var plays: Array = [
		{
			"result": result,
			"contact":
			ContactResult.Outcome.FOUL if initially_foul else ContactResult.Outcome.CONTACT,
			"exit_speed": 20.0
		}
	]
	var events: Array = resolver.state.stadium_contacts.duplicate(true)
	var rows: Array = [{"play": 0, "reason": reason, "events": events}]
	var accepted: bool = (
		not events.is_empty()
		and StadiumLayoutSnapshot.valid(snapshot, _paid.construction())
		and PhysicalStadiumContacts.valid(rows, plays, snapshot)
	)
	_operands = {"case": label, "reason": reason, "result": result, "events": events}
	_check(accepted, "actual contact survives the existing report consumer " + label)
	var altered: Array = rows.duplicate(true)
	if not events.is_empty():
		altered[0].events[0].surface = "UNOWNED-SURFACE"
	var rejected: bool = (
		not events.is_empty() and not PhysicalStadiumContacts.valid(altered, plays, snapshot)
	)
	_check(rejected, "report refuses invented surface on the same actual contact " + label)
	if _report_provenance.is_empty():
		altered = rows.duplicate(true)
		if not events.is_empty():
			altered[0].events[0].id = "PERIM-UNOWNED"
		_check(
			not events.is_empty() and not PhysicalStadiumContacts.valid(altered, plays, snapshot),
			"report refuses another graph identity on an actual contact"
		)
	_report_provenance.append(
		{
			"case": label,
			"reason": reason,
			"result": result,
			"events": events,
			"accepted": accepted,
			"forged_surface_rejected": rejected
		}
	)


func _views() -> void:
	_phase = "readable-front-and-three-quarter-originals"
	var root: Node3D = _world()
	_studio(root, Vector3(10, 8, -20), Vector3(0, 1.5, 1), 18)
	for index in range(2):
		var item: String = "ST-032" if index == 0 else "ST-074"
		var model: Node3D = StadiumBoundaryOwnedModels.create(
			item, {"copy": _copies[item][0], "site": "DISPLAY", "position": Vector3.ZERO, "yaw": 0}
		)
		root.add_child(model)
		model.position.x = -4 if index == 0 else 4
	_label(root, "OWNED DUGOUTS | Open timber and roofed concrete", Vector2(28, 20), 23)
	_label(
		root,
		"Full-size openings, front barriers, benches and roof • Front three-quarter view • Working art",
		Vector2(28, 674),
		17
	)
	await _capture("boundary-overview.png")
	await _close_view()
	root = _world()
	_studio(root, Vector3(0, 7, 23), Vector3(0, 3, 0), 19)
	for index in range(2):
		var pole: Node3D = StadiumBoundaryOwnedModels.create(
			"ST-021", {"copy": _copies["ST-021"][index], "site": "DISPLAY", "split": 3.25}
		)
		root.add_child(pole)
		pole.position = Vector3(-7 if index == 0 else 7, 0, 0)
		var item: String = "ST-020" if index == 0 else "ST-071"
		for module in range(3):
			var fence: Node3D = StadiumBoundaryOwnedModels.create(
				item, {"copy": _copies[item][module], "site": "DISPLAY", "index": 3}
			)
			root.add_child(fence)
			fence.position = Vector3((-4 if index == 0 else 4) + (module - 1) * 2, 0, 1)
		var wall: Node3D = StadiumWallPanelModels.create(
			"ST-024" if index == 0 else "ST-065", "full"
		)
		root.add_child(wall)
		wall.position = Vector3(-3 if index == 0 else 3, 1.4, -1)
		var panel: Node3D = StadiumBoundaryOwnedModels.create(
			"ST-064",
			{
				"copy": _copies["ST-064"][index],
				"site": "DISPLAY",
				"host": _copies["ST-024"][index],
				"host_span": "full",
				"distance_m": 23.4 if index == 0 else 29.187
			}
		)
		root.add_child(panel)
		panel.position = wall.position + Vector3(0, 1.8, 0)
	_label(
		root,
		"BOUNDARY DETAILS | Owned foul poles • Distance mounts • Wood and chain rear modules",
		Vector2(22, 20),
		21
	)
	_label(
		root,
		(
			"Measured metres on explicit wall hosts • Eight matching modules complete the rear • "
			+ "Pole flags remain separate"
		),
		Vector2(22, 674),
		17
	)
	await _capture("boundary-details.png")
	await _close_view()
