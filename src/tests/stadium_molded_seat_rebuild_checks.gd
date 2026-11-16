extends "res://src/tests/stadium_molded_seat_rebuild_checks_fixture_base.gd"
func _runtime_and_views() -> void:
	_phase = "ordinary-owned-family29-registered-property"
	var root: Node3D = _world()
	var lab: PitchBatLab = PitchBatLab.new()
	root.add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._batter_avatar.set_process(false)
	lab._pitcher_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = _snapshot.duplicate(true)
	lab._stadium_ledger = _paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	_operands = {
		"installed": installed,
		"layout_version": _layout.get("version", -1),
		"snapshot_version": _snapshot.get("version", -1)
	}
	_check(
		installed, "ordinary frozen owned snapshot installs the actual complete family29 property"
	)
	if not installed:
		await _close_view()
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: StadiumBoundaryOwnedRuntime = (
		property.get_node_or_null("BoundaryGraph") as StadiumBoundaryOwnedRuntime
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		(
			boundary != null
			and boundary.intact()
			and property.props_intact()
			and StadiumBoundaryRuntime.installed(lab, _snapshot)
		),
		"actual registered property and exact paid-copy boundary identity seals remain intact"
	)
	var checked: Dictionary = _checked(_layout)
	var rows: Array = checked.get("molded_seat_placements", [])
	var inspected: Array[Dictionary] = []
	for row: Dictionary in rows:
		var model: Node3D = property.objects.get(row.copy)
		var exact: bool = (
			is_instance_valid(model)
			and model.get_meta("stadium_item", "") == "ST-051"
			and model.get_meta("owned_copy", "") == row.copy
			and model.get_meta("site", "") == row.site
		)
		_check(
			(
				exact
				and model.position == row.position
				and model.rotation.y == 0.0
				and model.scale == Vector3.ONE
			),
			(
				"actual installed paid molded seat retains exact identity full size and socket pose "
				+ row.site
			)
		)
		if not exact:
			continue
		var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
		var roles: bool = (
			not bodies.is_empty()
			and model.get_meta("represented_seats", 0) == 1
			and not model.get_meta("represented_audience", true)
		)
		for body: Node in bodies:
			roles = (
				roles
				and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
				and body.get_meta("owned_copy", "") == row.copy
				and body.get_meta("ball_surface", &"") == &"stadium_scenery"
			)
		_check(
			roles,
			(
				"real seat colliders are off-field scenery with one unoccupied represented seat "
				+ row.site
			)
		)
		_check(
			(
				property.route_obstacles().all(
					func(route: Dictionary) -> bool: return route.copy != row.copy
				)
				and StadiumMoldedSeatItems._outside_play(
					StadiumMoldedSeatItems.bounds(row), StadiumMoldedSeatItems.graph_for(_layout)
				)
			),
			(
				"actual route obstacle list and full envelope keep molded seat outside live play "
				+ row.site
			)
		)
		var events: Array = [
			{
				"source": "item",
				"id": row.copy,
				"surface": "MoldedShell00",
				"role": "LIVE_RICOCHET",
				"position": _v3(row.position + Vector3.UP * 0.5),
				"time": 0.1,
				"kind": "contact"
			}
		]
		_check(
			not PhysicalStadiumContacts.valid(
				[{"play": 0, "reason": "", "events": events}],
				[
					{
						"result": "single",
						"contact": ContactResult.Outcome.CONTACT,
						"exit_speed": 12.0
					}
				],
				_snapshot
			),
			(
				"ordinary contact report refuses fabricated live scoring attribution to molded seat "
				+ row.site
			)
		)
		inspected.append(
			{
				"copy": row.copy,
				"item": row.item,
				"site": row.site,
				"position": _v3(row.position),
				"physical_scenery_bodies": bodies.size(),
				"represented_seats": 1,
				"represented_audience": false,
				"live_route_obstacle": false
			}
		)
	_check(
		(
			inspected.size() == 2
			and property.objects.size() == checked.placements.size()
			and checked.get("live_units", -1) == 0
		),
		"registered partial pad has precisely two selected paid seats and zero live units"
	)
	var pad: Node3D = property.get_node_or_null("MoldedSeatPad")
	_check(
		(
			pad != null
			and pad.get_meta("map_infrastructure", false)
			and not pad.has_meta("owned_copy")
			and pad.get_meta("represented_seats", -1) == 0
			and not pad.get_meta("connected_pedestrian_route", true)
		),
		(
			"fixed pad is independently sealed map infrastructure without a copy crowd or "
			+ "connected-route claim"
		)
	)
	var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = baseline.build("expanded", _empty, _paid.construction())
	_check(
		built and baseline.objects.is_empty() and baseline.has_node("MoldedSeatPad"),
		"ordinary empty-pad property contains the same fixed infrastructure and zero free seats"
	)
	_check(
		(
			built
			and property.route_obstacles() == baseline.route_obstacles()
			and lab._primary_fielder.stadium_obstacles == property.route_obstacles()
		),
		"actual fielder receives exactly the unchanged empty-pad route list"
	)
	baseline.free()
	_check(
		(
			PhysicalStadiumContacts.valid([], [], _snapshot)
			and lab._play_records.is_empty()
			and lab._batted_ball == null
		),
		(
			"registered installation permits a zero-play report without inventing a game or "
			+ "physical-performance claim"
		)
	)
	var hit: Dictionary = _ray(root, Vector3(-28, 0, 19.5))
	_check(
		(
			not hit.is_empty()
			and absf(hit.position.y - 0.15) < 0.0003
			and (hit.collider as Node).get_meta("map_infrastructure", false)
		),
		"registered property really contains the fixed raised ground pad"
	)
	_runtime = {
		"ordinary_install": installed,
		"models": inspected,
		"represented_paid_seats": 2,
		"empty_sockets": [SITES[1], SITES[3]],
		"pad_granted_copies": 0,
		"live_units": checked.get("live_units", -1),
		"route_obstacles": property.route_obstacles().size(),
		"zero_play_report_valid": true,
		"false_live_surface_claims_rejected": 2
	}
	await _preview_focus()
	await _views(root, property)
	_check(
		(
			property.props_intact()
			and boundary != null
			and boundary.intact()
			and lab._play_records.is_empty()
		),
		"native capture and focus leave the complete paid installation intact without games"
	)
	await _close_view()


func _infrastructure_guard(property: StadiumPropertyGeometry, node: Node3D, label: String) -> void:
	_phase = "finite-infrastructure-foreign-mutation-and-exact-restore"
	var original: Transform3D = node.transform
	node.position.x += 0.125
	_check(not property.props_intact(), "infrastructure seal rejects foreign pose " + label)
	node.transform = original
	_check(property.props_intact(), "exact original pose restores infrastructure seal " + label)
	var shapes: Array[Node] = node.find_children("*", "CollisionShape3D", true, false)
	var collision: CollisionShape3D = shapes[0]
	var original_shape: Shape3D = collision.shape
	collision.shape = original_shape.duplicate(true)
	_check(
		not property.props_intact(),
		"infrastructure seal rejects equal-looking foreign shape identity " + label
	)
	collision.shape = original_shape
	_check(
		property.props_intact(),
		"exact original physical shape restores infrastructure seal " + label
	)
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	var mesh: MeshInstance3D = meshes[0]
	var original_material: Material = mesh.material_override
	mesh.material_override = original_material.duplicate(true)
	_check(
		not property.props_intact(),
		"infrastructure seal rejects equal-looking foreign material identity " + label
	)
	mesh.material_override = original_material
	_check(property.props_intact(), "exact original material restores infrastructure seal " + label)
	var foreign: Node3D = Node3D.new()
	node.add_child(foreign)
	_check(
		not property.props_intact(), "infrastructure seal rejects extra foreign descendant " + label
	)
	node.remove_child(foreign)
	foreign.free()
	_check(
		property.props_intact(),
		"exact original descendant set restores infrastructure seal " + label
	)
	node.set_meta("foreign_infrastructure", true)
	_check(not property.props_intact(), "infrastructure seal rejects foreign metadata " + label)
	node.remove_meta("foreign_infrastructure")
	_check(property.props_intact(), "exact original metadata restores infrastructure seal " + label)
	_guards.append(
		{
			"target": label,
			"rejected_and_exactly_restored":
			["pose", "shape_identity", "material_identity", "foreign_child", "foreign_metadata"],
			"queries_pure": true
		}
	)


func _support_samples(tier: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge: Vector3 in [
		Vector3(-26, 0, 7), Vector3(26, 0, 7), Vector3(7, 0, -10), Vector3(7, 0, 32)
	]:
		var axis: Vector3 = Vector3.RIGHT if absf(edge.x) == 26 else Vector3.BACK
		for offset: float in [0.0] if tier == "backyard" else [-0.05, 0.0, 0.05]:
			result.append(
				{
					"label": "seam-" + str(result.size()),
					"point": edge + axis * offset,
					"y": 0.0,
					"normal": Vector3.UP
				}
			)
	if tier == "backyard":
		return result
	var outer: Rect2 = StadiumProperty.BOUNDS[tier]
	for point: Vector3 in [
		Vector3((outer.position.x - 26) * 0.5, 0, 5),
		Vector3((outer.end.x + 26) * 0.5, 0, 5),
		Vector3(7, 0, (outer.position.y - 10) * 0.5),
		Vector3(7, 0, (outer.end.y + 32) * 0.5)
	]:
		result.append(
			{"label": "ring-" + str(result.size()), "point": point, "y": 0.0, "normal": Vector3.UP}
		)
	result.append(
		{"label": "local-approach", "point": Vector3(-28, 0, 16), "y": 0.0, "normal": Vector3.UP}
	)
	for z: float in [17.02, 17.5, 18.0, 18.5, 18.98]:
		result.append(
			{
				"label": "ramp-" + str(z),
				"point": Vector3(-28, 0, z),
				"y": (z - 17.0) * 0.075,
				"normal": Vector3(0, 1, -0.075).normalized()
			}
		)
	result.append(
		{
			"label": "pad-front-access",
			"point": Vector3(-28, 0, 19.5),
			"y": 0.15,
			"normal": Vector3.UP
		}
	)
	for index in range(4):
		result.append(
			{
				"label": "empty-socket-" + str(index + 1),
				"point": Vector3(-29.5 + index, 0, 20.8),
				"y": 0.15,
				"normal": Vector3.UP
			}
		)
	return result


func _terrain_matrix() -> void:
	_phase = "bounded-tier-and-dirt-mode-outer-ground-support"
	_check(
		(
			FileAccess.get_sha256("res://src/gameplay/stadium/stadium_surface_terrain.gd")
			== INNER_SOURCE_SHA256
		),
		"inner deterministic terrain implementation remains byte exact"
	)
	var root: Node3D = _world()
	for tier: String in ["backyard", "expanded", "club", "mogul"]:
		for mode: String in ["rough", "leveled"]:
			var access: Array[String] = []
			if mode == "leveled":
				access.append("ground_prep")
			var original: Dictionary = StadiumSurfaceLayout.upgrade(
				StadiumStarterLayout.empty(), access, false
			)
			var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(original, access)
			var layout: Dictionary = (
				terrain if tier == "backyard" else StadiumMoldedSeatItems.upgrade(terrain, access)
			)
			var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
			var checked: Dictionary = (
				StadiumSurfaceLayout.validate_terrain(layout, _paid.construction(), tier)
				if tier == "backyard"
				else _checked(layout, tier)
			)
			var built: bool = property.build(tier, layout, _paid.construction())
			_operands = {
				"tier": tier, "mode": mode, "built": built, "error": checked.get("error", "")
			}
			_check(
				checked.ok and built,
				"actual property builds finite tier and terrain-mode case " + tier + ":" + mode
			)
			if not built:
				property.free()
				continue
			root.add_child(property)
			await get_tree().physics_frame
			await get_tree().physics_frame
			var terrain_node: Node3D = property.get_node("OwnedSurfaceTerrain")
			_check(
				(
					ClubCareer.same(
						terrain_node.get_meta("terrain"), StadiumSurfaceTerrain.contract(mode)
					)
					and (
						StadiumSurfaceTerrain.signature(mode)
						== (
							JSON
							. stringify(terrain_node.get_meta("terrain"), "", true, true)
							. sha256_text()
						)
					)
				),
				"inner terrain contract and collision signature remain exact " + tier + ":" + mode
			)
			var geometry: Dictionary = StadiumSurfaceTerrain.geometry(mode)
			var visual: MeshInstance3D = terrain_node.get_node("TerrainVisual")
			var arrays: Array = visual.mesh.surface_get_arrays(0)
			var shape: ConcavePolygonShape3D = (
				(terrain_node.get_node("TerrainCollision/ClosedTerrainShape") as CollisionShape3D)
				. shape
			)
			var source: Node3D = StadiumSurfaceTerrain.build(mode)
			var source_visual: MeshInstance3D = source.get_node("TerrainVisual")
			var source_arrays: Array = source_visual.mesh.surface_get_arrays(0)
			var source_material: ShaderMaterial = source_visual.material_override
			var actual_material: ShaderMaterial = visual.material_override
			_check(
				(
					arrays == source_arrays
					and arrays[Mesh.ARRAY_VERTEX] == geometry.faces
					and shape.get_faces() == geometry.faces
					and shape.margin == 0
					and not shape.backface_collision
					and actual_material.shader.code == source_material.shader.code
					and (
						actual_material.get_shader_parameter("terrain_wear")
						== source_material.get_shader_parameter("terrain_wear")
					)
				),
				(
					(
						"native constructor readback matches unchanged source vertices encoded normals "
						+ "material and collision faces "
					)
					+ tier
					+ ":"
					+ mode
				)
			)
			source.free()
			var perimeter: bool = true
			for axis in range(2):
				for value: float in StadiumSurfaceTerrain.knots(axis):
					for edge: float in [
						StadiumSurfaceTerrain.BOUNDS.position[1 - axis],
						StadiumSurfaceTerrain.BOUNDS.end[1 - axis]
					]:
						var point: Vector2 = (
							Vector2(value, edge) if axis == 0 else Vector2(edge, value)
						)
						var support: Dictionary = StadiumSurfaceTerrain.support(point, mode)
						perimeter = perimeter and support.get("support_height", INF) == 0.0
			_check(
				perimeter,
				(
					"both dirt modes retain the exact y-zero entire inner perimeter "
					+ tier
					+ ":"
					+ mode
				)
			)
			var boxes: Array[AABB] = StadiumPropertyGeometry.outer_ground_boxes(tier)
			var exact_strips: bool = (
				boxes.size() == (0 if tier == "backyard" else 4)
				and not property.has_node("PropertyGround")
			)
			var area: float = 0.0
			var disjoint: bool = true
			for index in range(boxes.size()):
				var box: AABB = boxes[index]
				var strip: StaticBody3D = property.get_node("OuterPropertyGround%d" % index)
				var collision: CollisionShape3D = strip.get_child(0)
				var mesh: MeshInstance3D = strip.get_child(1)
				exact_strips = (
					exact_strips
					and strip.position == box.get_center()
					and (collision.shape as BoxShape3D).size == box.size
					and (mesh.mesh as BoxMesh).size == box.size
					and box.position.y == StadiumProperty.ground_bounds(tier).position.y
					and box.end.y == 0.0
					and strip.get_meta("ball_surface") == &"ground"
					and not strip.has_meta("owned_copy")
					and strip.collision_layer == 1
					and strip.collision_mask == 2
					and (
						(mesh.material_override as StandardMaterial3D).albedo_color
						== Color("315640")
					)
				)
				exact_strips = (
					exact_strips
					and StadiumProperty.contains(tier, box)
					and not (
						Rect2(
							Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)
						)
						. intersects(StadiumSurfaceTerrain.BOUNDS)
					)
				)
				area += box.size.x * box.size.z
				for other in range(index):
					disjoint = disjoint and not box.intersects(boxes[other])
			_check(
				exact_strips,
				(
					"four original-style physical strips restore only outer property ground "
					+ tier
					+ ":"
					+ mode
				)
			)
			var outer: Rect2 = StadiumProperty.BOUNDS[tier]
			_check(
				(
					disjoint
					and is_equal_approx(
						area, outer.get_area() - StadiumSurfaceTerrain.BOUNDS.get_area()
					)
				),
				(
					"outer strips are disjoint and cover exactly property minus unchanged inner terrain "
					+ tier
					+ ":"
					+ mode
				)
			)
			var pad: Node3D = property.get_node_or_null("MoldedSeatPad")
			_check(
				(
					(
						pad == null
						if tier == "backyard"
						else (
							pad != null
							and pad.get_meta("map_infrastructure", false)
							and not pad.get_meta("free_seats", true)
						)
					)
					and property.objects.is_empty()
					and property.props_intact()
				),
				(
					"Backyard remains unchanged while larger empty pad plans create no seat inventory "
					+ tier
					+ ":"
					+ mode
				)
			)
			var samples: Array[Dictionary] = _support_samples(tier)
			var measured: Array[Dictionary] = []
			for sample: Dictionary in samples:
				var hit: Dictionary = _ray(root, sample.point)
				var good: bool = (
					not hit.is_empty()
					and absf(hit.position.y - sample.y) < 0.0003
					and hit.normal.is_equal_approx(sample.normal)
				)
				_operands = {
					"tier": tier,
					"mode": mode,
					"sample": sample.label,
					"point": _v3(sample.point),
					"expected_y": sample.y,
					"actual_y": hit.position.y if not hit.is_empty() else null,
					"normal": _v3(hit.normal) if not hit.is_empty() else []
				}
				_check(
					good,
					(
						"native installed support ray reaches exact seam ring ramp or pad "
						+ tier
						+ ":"
						+ mode
						+ ":"
						+ sample.label
					)
				)
				measured.append(_operands.duplicate(true))
			_support_matrix.append(
				{
					"tier": tier,
					"mode": mode,
					"layout_version": layout.version,
					"inner_signature": StadiumSurfaceTerrain.signature(mode),
					"inner_vertices": geometry.faces.size(),
					"outer_strip_count": boxes.size(),
					"outer_area": area,
					"no_free_seats": property.objects.is_empty(),
					"rays": measured
				}
			)
			if tier == "expanded" and mode == "rough":
				_infrastructure_guard(property, pad, "fixed-pad")
				_infrastructure_guard(
					property, property.get_node("OuterPropertyGround0"), "outer-ground-strip"
				)
			property.free()
			await get_tree().physics_frame
	await _close_view()


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered combined molded-seat qualification with explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		_ownership()
		_phase_counts.ownership = _checks - before
		if not _layout.is_empty() and not _snapshot.is_empty():
			before = _checks
			_detached_controls()
			_phase_counts.workshop_controls = _checks - before
			_phase = "source-held-molded-seat-and-pad-geometry"
			var model_root: Node3D = _world()
			before = _checks
			await StadiumMoldedSeatGeometryRebuildChecks.run(model_root, _check)
			_model_checks = _checks - before
			_operands = {
				"reached": _model_checks,
				"expected": StadiumMoldedSeatGeometryRebuildChecks.expected_checks()
			}
			_check(
				_model_checks == StadiumMoldedSeatGeometryRebuildChecks.expected_checks(),
				"every source-held seat and infrastructure geometry assertion is reached"
			)
			await _close_view()
			before = _checks
			await _terrain_matrix()
			_phase_counts.terrain_support = _checks - before
			before = _checks
			await _runtime_and_views()
			_phase_counts.runtime_and_views = _checks - before
	_phase = "completion"
	_check(
		_images == ["molded-seat-overview.png", "molded-seat-details.png"],
		"exactly two readable native 1280 by 720 originals and zero games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumMoldedSeatGeometryRebuildChecks.expected_checks()
	)
	var payload: Dictionary = {
		"checks": _checks,
		"expected_checks": expected,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"earned_career_claim": false,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"physical_performance_claim": false,
		"connected_pedestrian_route_claim": false,
		"crowd_simulation_claim": false,
		"new_mechanics": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumMoldedSeatGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"layout": _layout,
		"snapshot": _snapshot,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"support_matrix": _support_matrix,
		"infrastructure_guards": _guards,
		"workshop_preview": _ui_cases,
		"runtime": _runtime,
		"inner_terrain_source_sha256": INNER_SOURCE_SHA256,
		"capture_layout":
		(
			"one actual installed two-seat overview with two empty sockets and local access; one "
			+ "native close seat and pad detail"
		)
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence is finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("molded-seat-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined molded-seat evidence opens")
	_operands = {"reached": _checks + 1, "expected": expected, "phases": _phase_counts}
	_check(
		(
			_checks + 1 == expected
			and (
				_phase_counts
				== {
					"ownership": 107,
					"workshop_controls": 7,
					"terrain_support": 247,
					"runtime_and_views": 27
				}
			)
		),
		"every bounded fixture assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "combined molded-seat evidence fully writes")
		file.close()
	print(
		(
			(
				"MOLDED_SEAT_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}
