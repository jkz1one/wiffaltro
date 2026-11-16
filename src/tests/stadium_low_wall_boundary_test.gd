extends Node3D
## Focused isolated native boundary qualification, not a paid-prefix installation or full match.
## Straight trajectory probes disable aero/gravity only to isolate exact sphere/cap geometry.

var _checks: int = 0
var _failures: Array[String] = []
var _native_probes: int = 0
var _genuine_probes: int = 0
var _fixture: Dictionary
var _outcomes: Array[BallPlayOutcome] = []


func _ready() -> void:
	for profile: String in StadiumLowWallRecipes.PROFILES:
		_fixture = _context(profile)
		if _fixture.is_empty():
			continue
		_construction_guards()
		var boundary: StadiumLowWallBoundaryRuntime = _build()
		if boundary == null:
			continue
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(boundary.intact(), "installed complete recursive seal " + profile)
		_sweeps(boundary, profile)
		_issuance(boundary)
		for x: float in [-17, 0, 17]:
			var cap: float = 3.25 if profile == "low_flanks" and x == 0 else 1.625
			for delta: float in [-0.01, 0, 0.01]:
				await _native_probe(
					boundary,
					Vector3(x, cap + 0.0365 + delta, 22),
					Vector3(0, 0, 80),
					"BACK_WALL_TERMINAL" if delta <= 0 else "BACK_CLEAR"
				)
		for delta: float in [-0.01, 0.01]:
			var cap: float = 3.25 if profile == "low_flanks" else 1.625
			await _genuine_probe(
				boundary, cap + 0.0365 + delta, "BACK_WALL_TERMINAL" if delta < 0 else "BACK_CLEAR"
			)
		boundary.get_parent().free()
		await get_tree().process_frame
	_mutation_guards()
	_owned_models()
	_empty_profile()
	print(
		(
			"LOW_WALL_BOUNDARY_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"native_probes": _native_probes,
					"genuine_bat_probes": _genuine_probes,
					"runtime_qualified": false
				}
			)
		)
	)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _context(profile: String) -> Dictionary:
	var stock: StadiumStock = StadiumStock.new_club()
	var progress: Dictionary = {"seasons": 50, "wins": 200, "homers": 200, "strikeouts": 200}
	var quote: Dictionary = stock.quote("ST-024", 23, progress, "low-boundary-standard")
	_check(quote.ok, "authoring standard stock quote")
	if not quote.ok:
		return {}
	stock = StadiumStock.from_data(quote.state)
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	quote = pieces.quote("ST-024-L", 23, "low-boundary-pieces", progress, stock.capacity_count())
	_check(quote.ok, "distinct low stock quote")
	if not quote.ok:
		return {}
	pieces = StadiumWallPieceOwnership.from_data(quote.state, stock.capacity_count())
	var access: Array[String] = StadiumSurfaceProgression.INITIAL_LEGACY.duplicate()
	var layout: Dictionary = StadiumLowWallLayout.upgrade(StadiumStarterLayout.empty(), access)
	var suggestion: Dictionary = StadiumLowWallManifest.suggest(
		profile, "ST-024", stock, pieces.stock
	)
	_check(suggestion.ok, "complete authored suggestion")
	layout.low_wall = suggestion.manifest
	var checked: Dictionary = StadiumLowWallLayout.validate(
		layout, stock, pieces, access, "backyard"
	)
	_check(checked.ok, "complete authored validator: " + checked.error)
	return (
		{}
		if not checked.ok
		else {
			"stock": stock, "pieces": pieces, "access": access, "layout": layout, "checked": checked
		}
	)


func _build() -> StadiumLowWallBoundaryRuntime:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	property.tier = _fixture.get("tier", "backyard")
	var boundary: StadiumLowWallBoundaryRuntime = StadiumLowWallBoundaryRuntime.new()
	boundary.name = "BoundaryGraph"
	var built: bool = boundary.build_complete(
		property,
		_fixture.layout,
		_fixture.stock,
		_fixture.pieces,
		_fixture.access,
		_fixture.checked
	)
	_check(built, "complete boundary construction succeeds")
	if not built:
		boundary.free()
		property.free()
		return null
	property.add_child(boundary)
	add_child(property)
	return boundary


func _construction_guards() -> void:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	property.tier = _fixture.get("tier", "backyard")
	var boundary: StadiumLowWallBoundaryRuntime = StadiumLowWallBoundaryRuntime.new()
	_check(
		(
			not boundary.build()
			and not boundary.build_owned(_fixture.layout.walls, _fixture.stock)
			and not boundary.build_from(property, _fixture.layout, _fixture.stock)
		),
		"all stock-only entry points reject"
	)
	boundary.scale.y = 2
	_check(
		not boundary.build_complete(
			property,
			_fixture.layout,
			_fixture.stock,
			_fixture.pieces,
			_fixture.access,
			_fixture.checked
		),
		"transformed boundary cannot change authored sphere/box dimensions"
	)
	boundary.transform = Transform3D.IDENTITY
	property.position.x = 1
	_check(
		not boundary.build_complete(
			property,
			_fixture.layout,
			_fixture.stock,
			_fixture.pieces,
			_fixture.access,
			_fixture.checked
		),
		"transformed property cannot desynchronize graph and native geometry"
	)
	property.transform = Transform3D.IDENTITY
	var forged: Dictionary = _fixture.checked.duplicate(true)
	forged.low_panels[0].height = 3.25
	_check(
		(
			not boundary.build_complete(
				property, _fixture.layout, _fixture.stock, _fixture.pieces, _fixture.access, forged
			)
			and boundary.get_child_count() == 0
			and property.objects.is_empty()
		),
		"caller-forged validated result rejects before allocation"
	)
	var missing: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	_check(
		(
			not boundary.build_complete(
				property,
				_fixture.layout,
				_fixture.stock,
				missing,
				_fixture.access,
				_fixture.checked
			)
			and boundary.get_child_count() == 0
		),
		"claimed valid result cannot invent low inventory"
	)
	boundary.free()
	property.free()


func _sweeps(boundary: StadiumLowWallBoundaryRuntime, profile: String) -> void:
	var rows: Array[Dictionary] = boundary.graph.segments()
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var shape: CollisionShape3D = boundary.get_node(String(row.id) + "/Shape")
		var bounds: AABB = shape.transform * AABB(-shape.shape.size / 2, shape.shape.size)
		for point: Vector2 in [
			row.a,
			row.b,
			boundary.graph.outer_vertex(index),
			boundary.graph.outer_vertex((index + 1) % rows.size())
		]:
			_check(
				(
					point.x >= bounds.position.x - 0.000002
					and point.x <= bounds.end.x + 0.000002
					and point.y >= bounds.position.z - 0.000002
					and point.y <= bounds.end.z + 0.000002
				),
				"exact native box includes every unchanged inner/outer graph corner"
			)
		_check(
			is_equal_approx(bounds.size.y, row.height) and is_equal_approx(bounds.size.z, 0.35),
			"native box preserves exact height and full0.35m slab"
		)
	for x: float in [-17, 0, 17]:
		var cap: float = 3.25 if profile == "low_flanks" and x == 0 else 1.625
		for delta: float in [-0.01, -0.00002, 0, 0.00002, 0.01]:
			for distance: float in [1, 50, 300]:
				var y: float = cap + 0.0365 + delta
				var selected: Dictionary = boundary.event(
					Vector3(x, y, 23), Vector3(x, y, 23.4 + distance), 0.0365
				)
				var expected: String = "BACK_WALL_TERMINAL" if delta <= 0 else "BACK_CLEAR"
				_check(
					selected.get("role") == expected,
					(
						"sphere cap %s x=%s delta=%s distance=%s got=%s"
						% [profile, x, delta, distance, selected]
					)
				)
				if delta < 0:
					_check(
						selected.get("swept_contact", false),
						"under-clearance selection has native sphere witness"
					)
				if delta > 0:
					_check(
						not selected.get("swept_contact", false),
						"genuine clearance has no phantom collider"
					)
	for side: float in [-1, 1]:
		for delta: float in [-0.00002, 0, 0.00002]:
			var x: float = side * (StadiumWallRecipes.BACK_X + 0.0365 + delta)
			var selected: Dictionary = boundary.event(
				Vector3(x, 1.5, 23), Vector3(x, 1.5, 24), 0.0365
			)
			_check(
				selected.get("role") == ("BACK_WALL_TERMINAL" if delta <= 0 else "SIDE_EXIT_DEAD"),
				"outer return/back-wall join exact sphere end: " + str(selected)
			)
	if profile == "low_flanks":
		for side: float in [-1, 1]:
			for delta: float in [-0.01, -0.00002, 0, 0.00002, 0.01]:
				var x: float = side * (7 + 0.0365 + delta)
				var selected: Dictionary = boundary.event(
					Vector3(x, 2.4, 23), Vector3(x, 2.4, 24), 0.0365
				)
				_check(
					selected.get("role") == ("BACK_WALL_TERMINAL" if delta <= 0 else "BACK_CLEAR"),
					"vertical height-step native sphere competition: " + str(selected)
				)
		var descending: Dictionary = boundary.event(
			Vector3(0, 3.32, 23), Vector3(0, 3.18, 24), 0.0365
		)
		_check(
			(
				descending.get("role") == "BACK_WALL_TERMINAL"
				and descending.get("swept_contact", false)
			),
			"descending top-cap native sphere contact"
		)


func _issuance(boundary: StadiumLowWallBoundaryRuntime) -> void:
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	add_child(ball)
	boundary.bind_ball(ball, resolver)
	_check(
		(
			ball.physics_contact_router.get_object() == boundary
			and ball.physics_contact_router.get_method() == &"_contact_batch"
		),
		"only inherited native contact router is installed"
	)
	var issued: Dictionary = boundary.event(
		Vector3(17, 2, 23), Vector3(17, 2, 24), ball.radius_m, resolver
	)
	var fake: Dictionary = issued.duplicate(true)
	fake.position.x += 0.01
	_check(not boundary.apply_event(resolver, fake), "modified issued event cannot score")
	ball.launch_started.emit(Vector3(17, 2, 23))
	_check(
		not boundary.apply_event(resolver, issued), "old flight serial cannot score after relaunch"
	)
	issued = boundary.event(Vector3(17, 2, 23), Vector3(17, 2, 24), ball.radius_m, resolver)
	_outcomes.clear()
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	_check(boundary.apply_event(resolver, issued), "exact current issued event applies")
	var count: int = resolver.state.stadium_contacts.size()
	_check(
		_outcomes.size() == 1 and _outcomes[0].result == BallPlayOutcome.Result.HOME_RUN,
		"above-cap issued boundary gives exactly one HR"
	)
	_check(
		(
			not boundary.apply_event(resolver, issued)
			and resolver.state.stadium_contacts.size() == count
			and _outcomes.size() == 1
		),
		"issued event is one-use with no duplicate record"
	)
	ball.free()


func _native_probe(
	boundary: StadiumLowWallBoundaryRuntime,
	from: Vector3,
	velocity: Vector3,
	expected: String,
	genuine: BattedBallLaunch = null
) -> void:
	_native_probes += 1
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	var outcomes: Array[BallPlayOutcome] = []
	resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome))
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	boundary.bind_ball(ball, resolver)
	var launch: BattedBallLaunch = genuine
	if launch == null:
		launch = BattedBallLaunch.new()
		launch.position = from
		launch.velocity = velocity
	ball.launch(launch)
	for frame: int in range(120):
		await get_tree().physics_frame
		if resolver.state.dead:
			break
	_check(
		(
			resolver.state.dead
			and outcomes.size() == 1
			and resolver.state.stadium_contacts.size() == 1
		),
		"native ball produces one terminal result and record: " + str(from)
	)
	_check(
		(
			not resolver.state.stadium_contacts.is_empty()
			and resolver.state.stadium_contacts[0].role == expected
		),
		(
			"native first-contact role %s from %s got %s"
			% [expected, from, resolver.state.stadium_contacts]
		)
	)
	if not outcomes.is_empty():
		_check(
			(outcomes[0].result == BallPlayOutcome.Result.HOME_RUN) == (expected == "BACK_CLEAR"),
			"native cap cannot be an HR; true above cap is HR"
		)
	for frame: int in range(3):
		await get_tree().physics_frame
	_check(
		outcomes.size() == 1 and resolver.state.stadium_contacts.size() == 1,
		"later native physics cannot duplicate the terminal result"
	)
	ball.free()
	await get_tree().process_frame


func _genuine_probe(
	boundary: StadiumLowWallBoundaryRuntime, target_y: float, expected: String
) -> void:
	var profile: SwingProfileDefinition = load("res://src/content/swings/power_swing.tres")
	var pitch: PitchState = PitchState.new()
	pitch.position = Vector3(0, 0.7, 0.25)
	pitch.velocity = Vector3(0, 0, -12)
	pitch.elapsed_time = 1.0166666666666666
	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile.id
	intent.start_time_seconds = 0.8763333333333333
	intent.aim_point = Vector2(0, 0.7)
	var previous: Vector3 = Vector3(0, 0.7, 0.45)
	var first: ContactResult = ContactResolver.resolve_swept_segment(
		previous, 1, pitch, intent, profile, 10, 10
	)
	_check(first != null, "genuine legal pitch/swing intersects")
	if first == null:
		return
	var distance: float = (
		(StadiumWallRecipes.BACK_Z - first.contact_position.z)
		/ cos(deg_to_rad(first.spray_degrees))
	)
	var angle: float = rad_to_deg(atan2(target_y - first.contact_position.y, distance))
	var vertical_ratio: float = (angle - profile.attack_angle_degrees) / 32
	var depth: float = first.contact_position.z - ContactResolver.CONTACT_PLANE_Z
	intent.aim_point.y = (
		pitch.position.y
		- depth * tan(deg_to_rad(profile.attack_angle_degrees))
		- vertical_ratio * profile.contact_radius_y_m * ContactResolver._contact_factor(10)
	)
	_check(
		SwingIntent.reachable_aim(intent.aim_point) == intent.aim_point,
		"genuine contact uses reachable aim"
	)
	var contact: ContactResult = ContactResolver.resolve_swept_segment(
		previous, 1, pitch, intent, profile, 10, 10
	)
	_check(
		(
			contact != null
			and contact.outcome in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]
		),
		"genuine fair contact generated without edited outputs"
	)
	if (
		contact == null
		or contact.outcome not in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]
	):
		return
	var launch: BattedBallLaunch = BattedBallLaunch.from_contact(contact, pitch)
	var crossing: float = (
		launch.position.y
		+ (StadiumWallRecipes.BACK_Z - launch.position.z) * launch.velocity.y / launch.velocity.z
	)
	_check(
		absf(crossing - target_y) < 0.00001,
		"genuine immutable launch reaches selected cap-relative height"
	)
	_genuine_probes += 1
	await _native_probe(boundary, launch.position, launch.velocity, expected, launch)


func _mutation_guards() -> void:
	for mutation: String in [
		"panel_transform",
		"panel_copy",
		"panel_socket",
		"nested_transform",
		"nested_material",
		"material_value",
		"mesh_size",
		"shape_points",
		"node_order",
		"extra_child",
		"root_metadata",
		"root_visible",
		"graph_metadata",
		"graph_profile",
		"graph_identity"
	]:
		var boundary: StadiumLowWallBoundaryRuntime = _build()
		if boundary == null:
			continue
		var art: Node3D = boundary.get_node("PanelVisuals")
		var panel: Node3D = art.get_child(art.get_child_count() - 1)
		var mesh: MeshInstance3D = panel.find_children("*", "MeshInstance3D", true, false)[0]
		match mutation:
			"panel_transform":
				panel.position.x += 0.001
			"panel_copy":
				panel.set_meta("owned_copy", "wall-piece:foreign:0")
			"panel_socket":
				panel.set_meta("wall_socket", "wrong-socket")
			"nested_transform":
				mesh.position.y += 0.001
			"nested_material":
				mesh.material_override = mesh.material_override.duplicate(true)
			"material_value":
				mesh.material_override.albedo_color = Color.RED
			"mesh_size":
				mesh.mesh.size.y += 0.001
			"shape_points":
				var collider: CollisionShape3D = boundary.bodies[0].get_node("Shape")
				var points: PackedVector3Array = collider.shape.points
				points[0].x += 0.001
				collider.shape.points = points
			"node_order":
				art.move_child(panel, 0)
			"extra_child":
				mesh.add_child(Node3D.new())
			"root_metadata":
				boundary.set_meta("boundary_layout_hash", "forged")
			"root_visible":
				boundary.visible = false
			"graph_metadata":
				boundary.graph.set_meta("forged", true)
			"graph_profile":
				boundary.graph.profile = "low_flanks"
			"graph_identity":
				boundary.graph = StadiumLowWallLayout.graph_for(_fixture.layout)
		_check(not boundary.intact(), "same-frame fail-closed: " + mutation)
		_check(
			boundary.event(Vector3(17, 2, 23), Vector3(17, 2, 24), 0.0365).is_empty(),
			"retired boundary issues no score: " + mutation
		)
		boundary.get_parent().free()


func _owned_models() -> void:
	var original: Dictionary = _fixture
	for pair: Array in [["ST-032", "ST-020"], ["ST-074", "ST-071"]]:
		_fixture = original.duplicate(true)
		_fixture["tier"] = "expanded"
		var stock: StadiumStock = _fixture.stock
		var progress: Dictionary = {"seasons": 50, "wins": 200, "homers": 200, "strikeouts": 200}
		for entry: Array in [[pair[0], 2], [pair[1], 8]]:
			var quote: Dictionary = stock.quote(entry[0], entry[1], progress, entry[0])
			_check(quote.ok, "unchanged paid boundary stock quotes: " + entry[0])
			stock = StadiumStock.from_data(quote.state)
		_fixture.stock = stock
		_fixture.layout.boundary = []
		for side: String in ["L", "R"]:
			_fixture.layout.boundary.append(
				{
					"copy": "purchase:" + pair[0] + (":0" if side == "L" else ":1"),
					"item": pair[0],
					"site": "DUGOUT-" + side,
					"host": ""
				}
			)
		for index: int in range(8):
			_fixture.layout.boundary.append(
				{
					"copy": "purchase:" + pair[1] + ":" + str(index),
					"item": pair[1],
					"site": "REAR-%02d" % index,
					"host": ""
				}
			)
		_fixture.checked = StadiumLowWallLayout.validate(
			_fixture.layout, stock, _fixture.pieces, _fixture.access, _fixture.tier
		)
		_check(
			_fixture.checked.ok,
			"inherited paired dugouts and complete rear fence coexist: " + _fixture.checked.error
		)
		if not _fixture.checked.ok:
			continue
		var boundary: StadiumLowWallBoundaryRuntime = _build()
		if boundary == null:
			continue
		_check(
			boundary.intact() and boundary.owned_models.size() == 10,
			"all exact paid boundary models retain ownership and complete visual/native seals"
		)
		_check(
			not boundary.has_node("REAR-01"),
			"paid fence replaces template rear collider without duplication"
		)
		for key: String in boundary.owned_models:
			_check(
				boundary.owns_model(key, boundary.get_parent().objects[key]),
				"exact boundary-copy property registry preserved"
			)
		var dugout: Node3D = boundary.owned_models["purchase:" + pair[0] + ":0"]
		var mesh: MeshInstance3D = dugout.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.position.x += 0.001
		_check(
			not boundary.intact(),
			"inherited paid model nested visual mutation also retires boundary"
		)
		boundary.get_parent().free()
	_fixture = original


func _empty_profile() -> void:
	var original: Dictionary = _fixture
	_fixture = original.duplicate(true)
	_fixture.layout.low_wall = StadiumLowWallManifest.empty()
	_fixture.checked = StadiumLowWallLayout.validate(
		_fixture.layout, _fixture.stock, _fixture.pieces, _fixture.access, "backyard"
	)
	var boundary: StadiumLowWallBoundaryRuntime = _build()
	if boundary != null:
		_check(
			not boundary.graph is StadiumLowWallGraph and boundary.intact(),
			"stored low profile restores inherited standard graph without conversion"
		)
		for row: Dictionary in boundary.graph.segments():
			if row.role == "BACK_WALL_TERMINAL":
				_check(
					(
						row.height == 3.25
						and (
							boundary.get_node(String(row.id) + "/Shape").shape
							is ConvexPolygonShape3D
						)
					),
					"empty manifest keeps old standard construction and sweep path"
				)
		boundary.get_parent().free()
	_fixture = original


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error(label)
