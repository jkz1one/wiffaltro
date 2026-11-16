extends "res://src/tests/stadium_ground_box_rebuild_checks_fixture_base.gd"
func _preview_focus() -> void:
	_phase = "actual-owned-copy-workshop-focus"
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(
		_layout, _paid.construction(), true, "expanded", null, null, _paid.surface_owned()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.preview_property.has_node("MoldedSeatPad")
			and not preview.night_eligible
		),
		"actual Workshop preview builds two paid whole sections with no optional pad in daylight"
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
				"actual owned-copy preview focus contains all eight complete section reservation corners "
				+ copy
			)
		)
		cases.append({"copy": copy, "all_eight_corners_in_frame": contained})
	_ui_cases.merge(
		{"native_preview": true, "focus_cases": cases, "night_eligible": preview.night_eligible}
	)
	preview.queue_free()
	await get_tree().process_frame


func _views(root: Node3D, property: StadiumPropertyGeometry) -> void:
	_phase = "two-readable-native-ground-box-originals"
	var target: Vector3 = Vector3(0, 0.8, 5)
	var camera: Camera3D = _studio(root, Vector3(0, 32, -30), target, 29)
	_label(root, "GROUND BOX SECTIONS | 2 independently paid complete copies", Vector2(22, 18), 23)
	_label(
		root,
		"BOX-L + BOX-R | fixed 4 x 5.5 m world reservations | daylight, zero games",
		Vector2(22, 50),
		18
	)
	_label(
		root,
		"Static seats and audience, enclosure rail, local access and base | no optional seat pad",
		Vector2(22, 78),
		17
	)
	await _capture("ground-box-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	var model: Node3D = property.objects.get(_copies[0])
	_check(
		is_instance_valid(model),
		"native close detail uses the actual installed exact paid left ST-052 section"
	)
	if is_instance_valid(model):
		var focus: Vector3 = model.global_position + Vector3(0, 0.65, 0)
		camera.position = focus + Vector3(7, 5, -6)
		camera.look_at(focus)
		camera.size = 7.5
		_label(root, "ST-052 | ONE COMPLETE OWNED GROUND BOX", Vector2(22, 18), 23)
		_label(
			root,
			"Six represented seats and static audience | enclosure, local access, ground-supported base",
			Vector2(22, 50),
			18
		)
		_label(
			root,
			"Full 4 x 5.5 m reservation, height below 2.2 m | synthetic funding and progression",
			Vector2(22, 78),
			17
		)
		await _capture("ground-box-details.png")


func _runtime_and_views() -> void:
	_phase = "ordinary-owned-family30-registered-property"
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
		installed, "ordinary frozen paid snapshot installs the actual complete family30 property"
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
		"actual registered property and exact paid boundary identity seals remain intact"
	)
	var checked: Dictionary = _checked(_layout)
	var rows: Array = checked.get("ground_box_placements", [])
	var inspected: Array[Dictionary] = []
	for row: Dictionary in rows:
		var model: Node3D = property.objects.get(row.copy)
		var exact: bool = (
			is_instance_valid(model)
			and model.get_meta("stadium_item", "") == "ST-052"
			and model.get_meta("owned_copy", "") == row.copy
			and model.get_meta("site", "") == row.site
		)
		_operands = {
			"copy": row.copy,
			"site": row.site,
			"model_valid": is_instance_valid(model),
			"yaw": row.yaw
		}
		_check(
			(
				exact
				and model.position == row.position
				and is_equal_approx(model.rotation.y, deg_to_rad(float(row.yaw)))
				and model.scale == Vector3.ONE
			),
			(
				"actual installed complete paid box retains exact identity and authored full-size pose "
				+ row.site
			)
		)
		if not exact:
			continue
		var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
		var roles: bool = (
			not bodies.is_empty()
			and model.get_meta("represented_seats", 0) == 6
			and model.get_meta("represented_audience", false)
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
				"real complete-box bodies are off-field scenery with six static represented seats and audience "
				+ row.site
			)
		)
		_check(
			(
				property.route_obstacles().all(
					func(route: Dictionary) -> bool: return route.copy != row.copy
				)
				and StadiumGroundBoxItems._outside_play(
					StadiumGroundBoxItems.bounds(row), StadiumGroundBoxItems.graph_for(_layout)
				)
			),
			(
				"actual route obstacle list and full reservation keep the complete box outside live play "
				+ row.site
			)
		)
		var surface: String = str(bodies[0].name) if not bodies.is_empty() else ""
		var events: Array = [
			{
				"source": "item",
				"id": row.copy,
				"surface": surface,
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
				"ordinary report refuses fabricated live scoring attribution to an actual box body "
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
				"represented_seats": 6,
				"represented_audience": true,
				"live_route_obstacle": false,
				"false_live_surface": surface
			}
		)
	_check(
		(
			inspected.size() == 2
			and property.objects.size() == checked.placements.size()
			and checked.get("live_units", -1) == 0
		),
		"registered property contains precisely two selected paid full sections and zero live units"
	)
	_check(
		not property.has_node("MoldedSeatPad") and not _layout.has("molded_seats"),
		"actual box-only install does not silently adopt optional ST-051 infrastructure"
	)
	var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = baseline.build("expanded", _empty, _paid.construction())
	_check(
		built and baseline.objects.is_empty() and not baseline.has_node("MoldedSeatPad"),
		"ordinary empty box plan has no free sections or optional pad"
	)
	_check(
		(
			built
			and property.route_obstacles() == baseline.route_obstacles()
			and lab._primary_fielder.stadium_obstacles == property.route_obstacles()
		),
		"actual fielder receives the unchanged empty-plan route list"
	)
	baseline.free()
	_check(
		(
			PhysicalStadiumContacts.valid([], [], _snapshot)
			and lab._play_records.is_empty()
			and lab._batted_ball == null
		),
		(
			"registered install allows a zero-play report without inventing contact scoring or "
			+ "physical performance"
		)
	)
	_runtime = {
		"ordinary_install": installed,
		"models": inspected,
		"paid_complete_sections": 2,
		"represented_seats": 12,
		"represented_audience_static": true,
		"optional_pad_adopted": false,
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
		"native capture and focus leave the full paid installation intact without games"
	)
	await _close_view()


func _terrain_matrix() -> void:
	_phase = "bounded-current-rough-and-leveled-ground-support"
	_check(
		(
			FileAccess.get_sha256("res://src/gameplay/stadium/stadium_surface_terrain.gd")
			== INNER_SOURCE_SHA256
		),
		"inner deterministic terrain implementation remains byte exact"
	)
	var rough: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), [], false), []
	)
	var aggregate_layout: Dictionary = _place(rough, _copies[0], SITES[0])
	for kind: String in ["live-obstacle", "paid-wall", "late-live-role"]:
		var bad: Dictionary = aggregate_layout.duplicate(true)
		var helper: Dictionary = {
			"ok": true, "error": "", "placements": [], "live_units": 0, "wall_panels": []
		}
		match kind:
			"live-obstacle":
				bad.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
				helper.live_units = 1
			"paid-wall":
				bad.walls["foreign"] = true
				helper.wall_panels = [{}]
			"late-live-role":
				bad.lights = [{"copy": "purchase:foreign-light:0", "site": "LIGHT-L"}]
				helper.placements = [{"role": "LIVE_RICOCHET"}]
		var admission: Dictionary = StadiumHomeLayout.terrain_admission(
			aggregate_layout, "expanded", helper
		)
		_operands = {"case": kind, "aggregate": helper, "error": admission.get("error", "")}
		_check(
			not _checked(bad).ok and not admission.ok,
			(
				"actual invalid dirt selection and explicit helper-only aggregate retain existing constraint "
				+ kind
			)
		)
		_ownership_cases.append(
			{
				"case": "terrain-constraint-helper-only",
				"kind": kind,
				"aggregate": helper,
				"error": admission.get("error", ""),
				"installed_claim": false
			}
		)
	var root: Node3D = _world()
	for mode: String in ["rough", "leveled"]:
		var access: Array[String] = []
		if mode == "leveled":
			access.append("ground_prep")
		var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access, false), access
		)
		var layout: Dictionary = StadiumGroundBoxItems.place(
			StadiumGroundBoxItems.place(
				terrain, _paid.construction(), _copies[0], SITES[0], 0.0, access
			),
			_paid.construction(),
			_copies[1],
			SITES[1],
			0.0,
			access
		)
		_check(
			not _checked(layout, "backyard").ok,
			"current dirt mode never bypasses Expanded ground-box land gate " + mode
		)
		for tier: String in ["expanded", "club", "mogul"]:
			var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
			var checked: Dictionary = _checked(layout, tier)
			var built: bool = property.build(tier, layout, _paid.construction())
			_operands = {
				"tier": tier, "mode": mode, "built": built, "error": checked.get("error", "")
			}
			_check(
				(
					checked.ok
					and built
					and checked.get("live_units", -1) == 0
					and not checked.get("night_qualified", true)
				),
				(
					(
						"actual current terrain property builds supported decorative sections without Night "
						+ "broadening "
					)
					+ tier
					+ ":"
					+ mode
				)
			)
			if not built:
				property.free()
				continue
			root.add_child(property)
			await get_tree().physics_frame
			await get_tree().physics_frame
			var terrain_node: Node3D = property.get_node("OwnedSurfaceTerrain")
			var visual: MeshInstance3D = terrain_node.get_node("TerrainVisual")
			var shape: ConcavePolygonShape3D = (
				(terrain_node.get_node("TerrainCollision/ClosedTerrainShape") as CollisionShape3D)
				. shape
			)
			var geometry: Dictionary = StadiumSurfaceTerrain.geometry(mode)
			_check(
				(
					ClubCareer.same(
						terrain_node.get_meta("terrain"), StadiumSurfaceTerrain.contract(mode)
					)
					and visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == geometry.faces
					and shape.get_faces() == geometry.faces
					and shape.margin == 0
				),
				(
					"actual native inner terrain remains exact beneath complete box sections "
					+ tier
					+ ":"
					+ mode
				)
			)
			_check(
				(
					not property.has_node("MoldedSeatPad")
					and property.objects.size() == 2
					and property.props_intact()
					and property.route_obstacles().is_empty()
				),
				(
					"box-only dirt plan adds two paid full models and no optional pad or live route obstacle "
					+ tier
					+ ":"
					+ mode
				)
			)
			var measured: Array[Dictionary] = []
			for index in range(2):
				var row: Dictionary = StadiumGroundBoxItems.row(
					_copies[index], "ST-052", SITES[index]
				)
				var box: AABB = StadiumGroundBoxItems.bounds(row)
				var points: Array[Vector3] = [
					row.position,
					box.position,
					Vector3(box.end.x, 0, box.position.z),
					Vector3(box.position.x, 0, box.end.z),
					Vector3(box.end.x, 0, box.end.z)
				]
				for point: Vector3 in points:
					var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(
						PhysicsRayQueryParameters3D.create(
							point + Vector3.UP * 3,
							point - Vector3.UP,
							StadiumSurfaceTerrain.QUERY_LAYER
						)
					)
					_operands = {
						"tier": tier,
						"mode": mode,
						"site": row.site,
						"point": _v3(point),
						"actual_y": hit.position.y if not hit.is_empty() else null,
						"normal": _v3(hit.normal) if not hit.is_empty() else []
					}
					_check(
						(
							not hit.is_empty()
							and absf(hit.position.y) < 0.0003
							and hit.normal.is_equal_approx(Vector3.UP)
						),
						(
							"native terrain-only support ray reaches exact flat ground below complete section "
							+ tier
							+ ":"
							+ mode
							+ ":"
							+ row.site
						)
					)
					measured.append(_operands.duplicate(true))
			_support_matrix.append(
				{
					"tier": tier,
					"mode": mode,
					"layout_version": layout.version,
					"inner_signature": StadiumSurfaceTerrain.signature(mode),
					"paid_sections": 2,
					"optional_pad_adopted": false,
					"rays": measured
				}
			)
			property.free()
			await get_tree().physics_frame
	await _close_view()


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered combined ground-box qualification with explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		_ownership()
		_phase_counts.ownership = _checks - before
		if not _layout.is_empty() and not _snapshot.is_empty():
			before = _checks
			_fit_and_conflicts()
			_phase_counts.fit = _checks - before
			before = _checks
			_detached_controls()
			_phase_counts.workshop_controls = _checks - before
			_phase = "source-held-complete-ground-box-geometry"
			var model_root: Node3D = _world()
			before = _checks
			await StadiumGroundBoxGeometryRebuildChecks.run(model_root, _check)
			_model_checks = _checks - before
			_operands = {
				"reached": _model_checks,
				"expected": StadiumGroundBoxGeometryRebuildChecks.expected_checks()
			}
			_check(
				_model_checks == StadiumGroundBoxGeometryRebuildChecks.expected_checks(),
				"every complete ground-box geometry assertion is reached"
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
		_images == ["ground-box-overview.png", "ground-box-details.png"],
		"exactly two readable native 1280 by 720 originals and zero games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumGroundBoxGeometryRebuildChecks.expected_checks()
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
		"revenue_or_stat_mechanics": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumGroundBoxGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"layout": _layout,
		"snapshot": _snapshot,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"fit_cases": _fit_cases,
		"support_matrix": _support_matrix,
		"workshop_preview": _ui_cases,
		"runtime": _runtime,
		"inner_terrain_source_sha256": INNER_SOURCE_SHA256,
		"capture_layout":
		(
			"two independently paid complete left and right ground boxes; actual installed left "
			+ "enclosure detail"
		),
		"clearance_rule":
		(
			"full 4 x 5.5 m world reservation; graph-line setback at least 1.5 m plus actual "
			+ "boundary slab no-overlap"
		)
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence is finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("ground-box-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined ground-box evidence opens")
	_operands = {"reached": _checks + 1, "expected": expected, "phases": _phase_counts}
	_check(
		_checks + 1 == expected and _phase_counts == EXPECTED_PHASE_CHECKS,
		"every bounded fixture assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "combined ground-box evidence fully writes")
		file.close()
	print(
		(
			(
				"GROUND_BOX_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true synthetic_progression=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}
