extends "res://src/tests/stadium_landscape_rebuild_checks_fixture_base.gd"
func _views(root: Node3D, property: StadiumPropertyGeometry) -> void:
	_phase = "two-readable-native-landscape-originals"
	var bounds: Rect2 = StadiumProperty.BOUNDS["expanded"]
	var target: Vector3 = Vector3(bounds.get_center().x, 0.8, bounds.get_center().y)
	var camera: Camera3D = _studio(root, target + Vector3(45, 61, -70), target, 76)
	_label(root, "OWNED LANDSCAPING | Full property and off-field context", Vector2(22, 18), 22)
	await _capture("landscape-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	_view.size = Vector2i(640, 360)
	var canvas: Image = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("16232e"))
	var details: Array = [
		[
			"ST-013",
			"TREE-L",
			Vector3(0, 3.4, 0),
			Vector3(8, 5, -10),
			10.0,
			"SHADE TREE | One independent 7 m assembly"
		],
		[
			"ST-014",
			"HEDGE-R1",
			Vector3(0, 0.9, 0),
			Vector3(4, 4, 6),
			4.3,
			"HEDGE | Finished 2 m section, empty gap"
		],
		[
			"ST-018",
			"LAND-L",
			Vector3(0, 0.25, 0),
			Vector3(6, 7, -6),
			7.2,
			"KOI POND | Static scenery, no water scoring"
		],
		[
			"ST-019",
			"LAND-R",
			Vector3(0, 0.65, 0),
			Vector3(6, 5, -6),
			7.0,
			"ROCK GARDEN | Whole paid pocket, 90 degrees"
		]
	]
	for index in range(details.size()):
		var detail: Array = details[index]
		var model: Node3D
		for candidate: Node3D in property.objects.values():
			if candidate.get_meta("site", "") == detail[1]:
				model = candidate
		_check(
			is_instance_valid(model),
			"native detail uses the actual installed paid model " + str(detail[1])
		)
		if not is_instance_valid(model):
			continue
		var focus: Vector3 = model.global_position + detail[2]
		camera.position = focus + detail[3]
		camera.look_at(focus)
		camera.size = detail[4]
		_label(root, detail[5], Vector2(12, 10), 15)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var tile: Image = _view.get_texture().get_image()
		_check(
			not tile.is_empty() and tile.get_size() == Vector2i(640, 360),
			"actual installed native 640 by 360 detail tile " + str(detail[0])
		)
		if not tile.is_empty():
			tile.convert(Image.FORMAT_RGBA8)
			canvas.blit_rect(
				tile,
				Rect2i(Vector2i.ZERO, Vector2i(640, 360)),
				Vector2i((index % 2) * 640, (index / 2) * 360)
			)
		for child: Node in root.get_children():
			if child is Label:
				child.queue_free()
	_check(
		(
			canvas.get_size() == SIZE
			and canvas.save_png(_capture_dir.path_join("landscape-details.png")) == OK
		),
		"four native close-up tiles save as one bounded 1280 by 720 original"
	)
	_images.append("landscape-details.png")


func _runtime_and_views() -> void:
	_phase = "ordinary-installed-property-colliders-routes-and-report-separation"
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
	lab._match_state.stadium = _snapshot.duplicate(true)
	lab._stadium_ledger = _paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	_operands = {
		"installed": installed,
		"snapshot_version": _snapshot.get("version", -1),
		"layout_version": _layout.get("version", -1)
	}
	_check(installed, "ordinary frozen-snapshot startup installs the complete family26 property")
	if not installed:
		await _close_view()
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		property.props_intact() and StadiumBoundaryRuntime.installed(lab, _snapshot),
		"ordinary property and complete terminal boundary keep their sealed identities"
	)
	var checked: Dictionary = _checked(_layout)
	var landscape_copies: Array[String] = []
	var landscape_bodies: int = 0
	var landscape_shapes: int = 0
	var rows: Array[Dictionary] = []
	for placed: Dictionary in checked.landscape_placements:
		var model: Node3D = property.objects.get(placed.copy)
		var exact: bool = (
			is_instance_valid(model)
			and model.get_meta("stadium_item", "") == placed.item
			and model.get_meta("owned_copy", "") == placed.copy
			and model.get_meta("site", "") == placed.site
		)
		_operands = {
			"copy": placed.copy,
			"item": placed.item,
			"site": placed.site,
			"model_found": is_instance_valid(model)
		}
		_check(
			(
				exact
				and model.position.is_equal_approx(placed.position)
				and is_equal_approx(model.rotation.y, deg_to_rad(float(placed.yaw)))
			),
			"installed native model has exact paid copy and authored full-scale pose " + placed.site
		)
		if not exact:
			continue
		var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
		var shapes: Array[Node] = model.find_children("*", "CollisionShape3D", true, false)
		landscape_bodies += bodies.size()
		landscape_shapes += shapes.size()
		landscape_copies.append(placed.copy)
		_check(
			(
				bodies.is_empty()
				and shapes.is_empty()
				and model.get_node("Collision").get_child_count() == 0
				and model.get_meta("scenery_only", false)
				and not model.get_meta("treehouse_support", true)
				and not model.get_meta("water_scoring", true)
			),
			(
				"full descendant traversal finds no body, shape, live scoring or treehouse adapter "
				+ placed.site
			)
		)
		rows.append(
			{
				"copy": placed.copy,
				"item": placed.item,
				"site": placed.site,
				"position": _v3(model.position),
				"collision_objects": bodies.size(),
				"collision_shapes": shapes.size()
			}
		)
	_native_model_count = landscape_copies.size()
	_check(
		_native_model_count == 9 and property.objects.size() == checked.placements.size(),
		"installed object inventory contains exactly selected paid models and no hedge fillers"
	)
	var actual_all_bodies: Array[Node] = property.find_children(
		"*", "CollisionObject3D", true, false
	)
	var landscape_leak: bool = false
	for body: Node in actual_all_bodies:
		landscape_leak = (
			landscape_leak or landscape_copies.has(str(body.get_meta("owned_copy", "")))
		)
	_check(
		(
			not actual_all_bodies.is_empty()
			and not landscape_leak
			and landscape_bodies == 0
			and landscape_shapes == 0
		),
		"whole-property physical traversal finds real legacy bodies but no landscape-owned body anywhere"
	)
	var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var baseline_built: bool = baseline.build("expanded", _base25, _paid.construction())
	root.add_child(baseline)
	baseline.visible = false
	_check(baseline_built, "ordinary historical base25 builds the comparison route source")
	var routes: Array[Dictionary] = property.route_obstacles()
	var old_routes: Array[Dictionary] = baseline.route_obstacles()
	_check(
		(
			routes == old_routes
			and routes.size() == 1
			and routes[0].copy == "starter-v1:ST-001"
			and lab._primary_fielder.stadium_obstacles == routes
		),
		"actual fielder receives exactly the old cone route with no landscape obstacle"
	)
	for item: String in ITEMS:
		var site: String = (
			"TREE-L"
			if item == "ST-013"
			else "HEDGE-L1" if item == "ST-014" else "LAND-L" if item == "ST-018" else "LAND-R"
		)
		var center: Vector3 = StadiumLandscapeOwnedItems.SITES[site].position
		var start: Vector3 = center + Vector3(-4, 0, 0)
		var finish: Vector3 = center + Vector3(4, 0, 0)
		var old_step: Vector3 = StadiumDefenderRoutes.step(start, finish, 0.75, old_routes)
		var new_step: Vector3 = StadiumDefenderRoutes.step(start, finish, 0.75, routes)
		_check(
			(
				StadiumDefenderRoutes.clear(start, finish, routes)
				and new_step == old_step
				and StadiumDefenderRoutes.clip(start, finish, routes) == finish
			),
			"existing route kernel gains no detour or stop from scenery " + item
		)
		_route_cases.append(
			{
				"item": item,
				"site": site,
				"from": _v3(start),
				"to": _v3(finish),
				"old_step": _v3(old_step),
				"landscape_step": _v3(new_step),
				"landscape_obstacles": 0
			}
		)
	baseline.free()
	_check(
		PhysicalStadiumContacts.valid([], [], _snapshot),
		(
			"ordinary contact report consumer accepts the installed layout with zero plays and "
			+ "zero fabricated events"
		)
	)
	for item: String in ITEMS:
		var placed: Dictionary = checked.landscape_placements.filter(func(row: Dictionary) -> bool: \
			return row.item == item)[0]
		var event: Dictionary = {
			"source": "item",
			"id": placed.copy,
			"surface": "INVENTED_LANDSCAPE_SURFACE",
			"role": placed.role,
			"position": _v3(placed.position),
			"time": 0.1,
			"kind": "contact"
		}
		var evidence: Array = [{"play": 0, "reason": "", "events": [event]}]
		_check(
			not PhysicalStadiumContacts.valid(
				evidence,
				[
					{
						"result": "single",
						"contact": ContactResult.Outcome.CONTACT,
						"exit_speed": 20.0
					}
				],
				_snapshot
			),
			"report provenance rejects invented landscape scoring contact " + item
		)
	_physical = {
		"ordinary_install": installed,
		"models": rows,
		"whole_property_collision_objects": actual_all_bodies.size(),
		"landscape_collision_objects": landscape_bodies,
		"landscape_collision_shapes": landscape_shapes,
		"route_obstacle_copies": routes.map(func(row: Dictionary) -> String: return row.copy),
		"report_zero_plays_valid": true,
		"invented_landscape_contacts_rejected": ITEMS
	}
	_check(
		property.props_intact() and lab._play_records.is_empty() and lab._batted_ball == null,
		"inspection and route/report negatives preserve the ordinary installation without starting a game"
	)
	_camera_clearance(lab, checked.landscape_placements)
	await _preview_focus()
	await _views(root, property)
	await _close_view()


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered landscape qualification and explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		_ownership()
		_phase_counts.ownership = _checks - before
		before = _checks
		_detached_controls()
		_phase_counts.workshop_controls = _checks - before
		if not _layout.is_empty() and not _snapshot.is_empty():
			_phase = "shared-source-model-geometry"
			var root: Node3D = _world()
			before = _checks
			await StadiumLandscapeGeometryRebuildChecks.run(root, _check)
			_model_checks = _checks - before
			_operands = {
				"reached": _model_checks,
				"expected": StadiumLandscapeGeometryRebuildChecks.expected_checks()
			}
			_check(
				_model_checks == StadiumLandscapeGeometryRebuildChecks.expected_checks(),
				"every bounded source-model assertion was reached"
			)
			await _close_view()
			before = _checks
			await _runtime_and_views()
			_phase_counts.runtime_and_views = _checks - before
	_phase = "completion"
	_operands = {"images": _images, "phase_checks": _phase_counts, "model_checks": _model_checks}
	_check(
		_images == ["landscape-overview.png", "landscape-details.png"],
		"exactly two readable originals at most 1280 by 720 and zero games"
	)
	var payload: Dictionary = {
		"checks": _checks,
		"expected_checks": EXPECTED_CHECKS,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumLandscapeGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"base25": _base25,
		"layout": _layout,
		"snapshot": _snapshot,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"route_cases": _route_cases,
		"physical_traversal": _physical,
		"camera_cases": _camera_cases,
		"workshop_preview": _ui_cases,
		"installed_landscape_models": _native_model_count,
		"night_qualified": false,
		"capture_layout":
		"one full-property overview and four native 640x360 detail tiles in one 1280x720 original"
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"shared structured JSON evidence is finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("landscape-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "shared landscape evidence opens")
	_check(
		(
			_checks + 1 == EXPECTED_CHECKS
			and _phase_counts.get("ownership", 0) == 100
			and _phase_counts.get("workshop_controls", 0) == 4
			and _phase_counts.get("runtime_and_views", 0) == 53
		),
		"all 278 shared native assertions are reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "shared landscape evidence fully writes")
		file.close()
	print(
		(
			(
				"LANDSCAPE_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}
