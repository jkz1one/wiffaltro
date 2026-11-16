extends "res://src/tests/stadium_outfield_bleacher_rebuild_checks_fixture_base.gd"
func _camera_clearance(lab: PitchBatLab, model: Node3D) -> void:
	_phase = "actual-current-normal-zoom-pitcher-backdrop-clearance"
	var director: MatchCameraDirector = lab._camera_director
	var old_side: float = director._batter_side
	var old_shot: MatchCameraDirector.Shot = director.shot
	var old_motion: MatchCameraDirector.PresentationMotion = director._presentation_motion
	var old_progress: float = director._presentation_progress
	var old_pose: Transform3D = lab._camera.transform
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
			lab._camera.transform = pose
			director._apply_projection(lab._camera)
			var protected: Rect2 = (
				_project_rect(
					lab._camera,
					AABB(PitchBatLab.MOUND_ORIGIN + Vector3(-1.6, 0, -0.8), Vector3(3.2, 3.6, 1.6))
				)
				. grow(16)
			)
			var reserve: AABB = StadiumOutfieldBleacherItems.bounds(
				StadiumOutfieldBleacherItems.row(_copies[0], "ST-054", SITE)
			)
			var target: Vector3 = PitchBatLab.MOUND_ORIGIN + Vector3.UP
			var blocked: bool = (
				reserve.has_point(pose.origin)
				or reserve.intersects_segment(pose.origin, target) != null
			)
			var backdrop_clear: bool = true
			var visible_meshes: int = 0
			for node: Node in model.get_node("Visual").find_children(
				"*", "MeshInstance3D", true, false
			):
				var mesh: MeshInstance3D = node as MeshInstance3D
				var projected: Rect2 = _project_rect(
					lab._camera, mesh.global_transform * mesh.get_aabb()
				)
				if projected.has_area():
					visible_meshes += 1
					backdrop_clear = backdrop_clear and not projected.intersects(protected)
			var projection: Rect2 = _project_rect(
				lab._camera, model.global_transform * StadiumOutfieldBleacherModels.visible_bounds()
			)
			_operands = {
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _v3(pose.origin),
				"pitcher_target": _v3(target),
				"blocked": blocked,
				"backdrop_clear": backdrop_clear,
				"protected_pitcher_rect": _rect(protected),
				"projected_model_rect": _rect(projection),
				"visible_meshes": visible_meshes,
				"checked_meshes": StadiumOutfieldBleacherModels.mesh_count()
			}
			_check(
				not blocked and backdrop_clear and protected.has_area() and visible_meshes > 0,
				(
					"actual current normal or zoom camera clears whole reservation and every projected "
					+ "mesh from pitcher backdrop"
				)
			)
			_camera_cases.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress
	lab._camera.transform = old_pose
	director._apply_projection(lab._camera)


func _preview_focus() -> void:
	_phase = "actual-owned-copy-workshop-focus"
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(_layout, _paid.construction(), true, "mogul", null, null, _paid.surface_owned())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.preview_property.has_node("MoldedSeatPad")
			and not preview.night_eligible
		),
		"actual Workshop preview builds complete paid assembly without optional pad in daylight"
	)
	preview.focus_copy(_copies[0])
	await get_tree().process_frame
	var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
	var box: AABB = preview.board_bounds.get(_copies[0], AABB())
	var contained: bool = (
		preview.board_bounds.has(_copies[0]) and rect.size.x > 0 and rect.size.y > 0
	)
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		contained = (
			contained
			and not preview.camera.is_position_behind(point)
			and rect.has_point(preview.camera.unproject_position(point))
		)
	_check(
		contained,
		"actual owned-copy preview focus contains all eight complete assembly reservation corners"
	)
	_ui_cases.native_preview = true
	_ui_cases.focus_cases = [
		{"copy": _copies[0], "site": SITE, "all_eight_corners_in_frame": contained}
	]
	preview.queue_free()
	await get_tree().process_frame


func _runtime_model(
	root: Node3D,
	lab: PitchBatLab,
	property: StadiumPropertyGeometry,
	boundary: StadiumBoundaryOwnedRuntime,
	row: Dictionary,
	snapshot: Dictionary
) -> Dictionary:
	var model: Node3D = property.objects.get(row.copy)
	var exact: bool = (
		is_instance_valid(model)
		and model.get_meta("stadium_item", "") == row.item
		and model.get_meta("owned_copy", "") == row.copy
		and model.get_meta("site", "") == row.site
	)
	_check(
		(
			exact
			and model.position == row.position
			and is_zero_approx(model.rotation.y)
			and model.scale == Vector3.ONE
		),
		(
			"actual complete paid outfield bleacher retains exact identity and full-size fixed pose "
			+ row.item
		)
	)
	if not exact:
		return {}
	var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
	var roles: bool = bodies.size() == StadiumOutfieldBleacherModels.solid_count(row.item)
	for body: Node in bodies:
		roles = (
			roles
			and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
			and body.get_meta("owned_copy", "") == row.copy
			and body.get_meta("ball_surface", &"") == &"stadium_scenery"
			and not body is Area3D
		)
	_check(
		roles and model.find_children("*", "Area3D", true, false).is_empty(),
		(
			(
				"every actual outfield bleacher body is owned after-terminal scenery with no receiver "
				+ "or water-entry Area "
			)
			+ row.item
		)
	)
	var static_only: bool = (
		model.find_children("*", "AnimationPlayer", true, false).is_empty()
		and model.find_children("*", "RigidBody3D", true, false).is_empty()
	)
	for child: Node in [model] + model.find_children("*", "", true, false):
		static_only = (
			static_only and not child.is_processing() and not child.is_physics_processing()
		)
	_check(
		(
			static_only
			and model.get_meta("represented_audience_count", -1) == 0
			and not model.get_meta("connected_pedestrian_route", true)
			and model.get_meta("obstacle_units", -1) == 0
		),
		(
			"complete model remains static scenery without crowd pedestrian or obstacle effects "
			+ row.item
		)
	)
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	resolver.segment_observer = boundary.observe
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	root.add_child(ball)
	ball.position = row.position + Vector3.UP
	property.bind_ball(ball, resolver)
	for body: Node in bodies:
		property._ball_contact(body, ball, resolver)
	_check(
		(
			resolver.state.stadium_contacts.is_empty()
			and not resolver.state.dead
			and resolver.state.result_floor == BallPlayState.ResultFloor.NONE
			and resolver.state.last_obstacle_contact == &""
		),
		(
			(
				"real bound decorative body contact callbacks issue no contact scoring Double or "
				+ "terminal authority "
			)
			+ row.item
		)
	)
	ball.free()
	var surface: String = (
		str(bodies[0].get_meta("surface_id", bodies[0].name)) if not bodies.is_empty() else ""
	)
	for role: String in ["LIVE_RICOCHET", "DECORATIVE_AFTER_TERMINAL"]:
		var events: Array = [
			{
				"source": "item",
				"id": row.copy,
				"surface": surface,
				"role": role,
				"position": _v3(row.position + Vector3.UP),
				"time": 0.1,
				"kind": "contact"
			}
		]
		_check(
			not PhysicalStadiumContacts.valid(
				[{"play": 0, "reason": "", "events": events}],
				[
					{
						"result": "double",
						"contact": ContactResult.Outcome.CONTACT,
						"exit_speed": 12.0
					}
				],
				snapshot
			),
			(
				"ordinary report refuses fabricated outfield bleacher contact and Double authority "
				+ row.item
				+ ":"
				+ role
			)
		)
	var tracking: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var bounds_count: int = 0
	var collected: bool = true
	for mesh: Node in model.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (
			(mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		)
		if box.size.y > 0.025:
			bounds_count += 1
			collected = collected and tracking._obstacles.has(box)
	_check(
		collected and bounds_count > 0 and tracking._owned_receiver_models.is_empty(),
		(
			(
				"ordinary dynamic tracking collects every current visible outfield bleacher mesh "
				+ "without receiver exclusion "
			)
			+ row.item
		)
	)
	return {
		"copy": row.copy,
		"item": row.item,
		"site": row.site,
		"position": _v3(row.position),
		"physical_scenery_bodies": bodies.size(),
		"active_animation": not static_only,
		"actual_contact_callbacks": bodies.size(),
		"contact_events": resolver.state.stadium_contacts.size(),
		"terminal": resolver.state.dead,
		"result_floor": int(resolver.state.result_floor),
		"tracking_mesh_bounds": bounds_count,
		"tracking_collected": collected
	}


func _in_frame(camera: Camera3D, box: AABB) -> bool:
	var readable: Rect2 = Rect2(12, 110, 1256, 565)
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if (
			camera.is_position_behind(point)
			or not readable.has_point(camera.unproject_position(point))
		):
			_operands = {
				"corner": _v3(point),
				"pixel": str(camera.unproject_position(point)),
				"readable": str(readable)
			}
			return false
	return true


func _views(root: Node3D, property: StadiumPropertyGeometry) -> void:
	_phase = "two-native-complete-elevated-bleacher-originals"
	var camera: Camera3D = _studio(root, Vector3(-72, 70, -70), Vector3(-4, 1, 15), 76)
	_label(
		root, "ELEVATED OUTFIELD BLEACHERS | One exact complete paid ST-054", Vector2(22, 18), 23
	)
	_label(
		root,
		(
			"Club / Mogul fixed site | seats, supports, stairs and landings included | synthetic "
			+ "funding and progression"
		),
		Vector2(22, 50),
		16
	)
	await get_tree().process_frame
	var row: Dictionary = _checked(_layout).outfield_bleacher_placements[0]
	_check(
		_in_frame(camera, StadiumOutfieldBleacherItems.bounds(row)),
		"overview contains full installed complete assembly clear of heading and bottom edge"
	)
	var field_visible: bool = true
	for point: Vector2 in StadiumOutfieldBleacherItems.graph_for(_layout).polygon():
		field_visible = (
			field_visible
			and not camera.is_position_behind(Vector3(point.x, 0, point.y))
			and Rect2(10, 90, 1260, 590).has_point(
				camera.unproject_position(Vector3(point.x, 0, point.y))
			)
		)
	_check(
		field_visible, "overview contains complete actual current field and elevated seats together"
	)
	await _capture("outfield-bleacher-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	camera.position = Vector3(-42, 18, 55)
	camera.look_at(Vector3(-17, 4.5, 36))
	camera.size = 22
	_label(
		root, "ONE COMPLETE ASSEMBLY | Elevated seats and bundled local access", Vector2(22, 18), 23
	)
	_label(
		root,
		(
			"Actual paid installation | four rows, grounded steel supports, rear stairs, landings "
			+ "and finished guards"
		),
		Vector2(22, 50),
		16
	)
	_label(
		root,
		(
			"Plate / mound sightlines only | substantial near-wall ground blind area | no crowd or "
			+ "pedestrian claim"
		),
		Vector2(22, 77),
		16
	)
	await get_tree().process_frame
	var model: Node3D = property.objects[_copies[0]]
	_check(
		(
			_in_frame(
				camera, model.global_transform * StadiumOutfieldBleacherModels.visible_bounds()
			)
			and property.props_intact()
		),
		(
			"opposite-side detail contains the whole actual unscaled assembly including rear "
			+ "access and all ground supports"
		)
	)
	await _capture("outfield-bleacher-details.png")
func _runtime_and_views() -> void:
	_phase = "ordinary-registered-family34-property"
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
	_check(installed, "ordinary frozen paid snapshot installs complete family34 property")
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
		"actual property and complete boundary identity seals remain intact"
	)
	if boundary == null:
		await _close_view()
		return
	var checked: Dictionary = _checked(_layout)
	var inspected: Dictionary = _runtime_model(
		root, lab, property, boundary, checked.outfield_bleacher_placements[0], _snapshot
	)
	_check(
		(
			property.objects.size() == 2
			and not property.has_node("MoldedSeatPad")
			and not _layout.has("molded_seats")
			and _layout.treehouses.is_empty()
			and _layout.ground_boxes.is_empty()
			and _layout.practice_facilities.is_empty()
		),
		(
			"ordinary install contains only paid bleacher and current scoreboard without optional "
			+ "infrastructure"
		)
	)
	var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = baseline.build("mogul", _score_layout(_empty), _paid.construction())
	_check(
		(
			built
			and baseline.objects.size() == 1
			and property.route_obstacles() == baseline.route_obstacles()
			and lab._primary_fielder.stadium_obstacles == property.route_obstacles()
		),
		"actual fielder preserves scoreboard-only route and no added obstacle budget"
	)
	baseline.free()
	_check(
		(
			PhysicalStadiumContacts.valid([], [], _snapshot)
			and lab._play_records.is_empty()
			and lab._batted_ball == null
		),
		"zero-play native install invents no contacts scoring or performance result"
	)
	_camera_clearance(lab, property.objects[_copies[0]])
	await _preview_focus()
	await _views(root, property)
	_check(
		property.props_intact() and boundary.intact() and lab._play_records.is_empty(),
		"native checks and views preserve the registered complete installation without games"
	)
	_runtime = {
		"ordinary_install": installed,
		"paid_complete_parents": property.objects.size(),
		"optional_pad_adopted": false,
		"live_units": checked.get("live_units", -1),
		"route_obstacles": property.route_obstacles().size(),
		"zero_play_report_valid": true,
		"model": inspected,
		"false_contact_claims_rejected": 2,
		"actual_contact_callbacks_executed": true,
		"games": 0
	}
	await _close_view()


func _tree_triangle_witness(root: Node3D) -> void:
	_phase = "actual-tree-crown-visual-triangle-witness"
	var model: Node3D = StadiumLandscapeModels.create("ST-013")
	root.add_child(model)
	model.position = (
		StadiumLandscapeOwnedItems.row(_inherited["ST-013"], "ST-013", "TREE-L").position
	)
	var mesh: MeshInstance3D = model.get_node("Visual/CrownHighlight0")
	var from: Vector3 = Vector3(-23, 7, 33)
	var target: Vector3 = Vector3.ZERO
	var faces: PackedVector3Array = mesh.mesh.get_faces()
	var triangle: int = -1
	var hit_point: Vector3 = Vector3.ZERO
	var vertices: Array = []
	for index in range(0, faces.size(), 3):
		var a: Vector3 = mesh.global_transform * faces[index]
		var b: Vector3 = mesh.global_transform * faces[index + 1]
		var c: Vector3 = mesh.global_transform * faces[index + 2]
		var hit: Variant = Geometry3D.segment_intersects_triangle(from, target, a, b, c)
		if hit != null:
			triangle = index / 3
			hit_point = hit
			vertices = [_v3(a), _v3(b), _v3(c)]
			break
	var no_colliders: bool = model.find_children("*", "CollisionObject3D", true, false).is_empty()
	_check(
		no_colliders and mesh.mesh is SphereMesh and faces.size() > 0,
		"TREE-L actual authored CrownHighlight0 visual has triangle geometry and no physical collider"
	)
	_check(
		triangle >= 0 and hit_point.distance_to(from) > 0 and hit_point.distance_to(target) > 0,
		"exact actual transformed CrownHighlight0 triangle blocks front-left eye to home plate"
	)
	_tree_witness = {
		"copy": _inherited["ST-013"],
		"item": "ST-013",
		"site": "TREE-L",
		"mesh": "Visual/CrownHighlight0",
		"query":
		"Geometry3D.segment_intersects_triangle on actual Mesh.get_faces transformed vertices",
		"eye": _v3(from),
		"target": _v3(target),
		"physical_colliders": 0,
		"triangle_index": triangle,
		"triangle_vertices": vertices,
		"hit_position": _v3(hit_point),
		"blocked": triangle >= 0,
		"reservation_overlap_required": false
	}
	model.free()


func _sightlines() -> void:
	_phase = "native-complete-selected-walls-and-seated-plate-mound-rays"
	var root: Node3D = _world()
	var eyes: PackedVector3Array = StadiumOutfieldBleacherModels.eye_points()
	var expected_eyes: PackedVector3Array = []
	for row in range(4):
		for x: float in [-6.0, 0.0, 6.0]:
			expected_eyes.append(Vector3(x, 7.0 + row * 0.45, -3.0 + row))
	_check(
		eyes == expected_eyes and TARGETS == [Vector3(0, 0.02, 0), Vector3(0, 0.02, 13.716)],
		(
			"all four exact represented eye rows include both ends and center with explicit "
			+ "two-centimeter ground endpoint offset"
		)
	)
	for shape: String in ["straight", "deeper_center"]:
		var layout: Dictionary = _layout if shape == "straight" else _deeper_layout
		var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		var built: bool = property.build("mogul", layout, _paid.construction())
		_check(
			built and _checked(layout).ok,
			"ordinary complete paid property builds for the actual selected wall " + shape
		)
		if not built:
			property.free()
			continue
		root.add_child(property)
		var boundary: StadiumBoundaryOwnedRuntime = (
			StadiumBoundaryRuntime.assemble(property) as StadiumBoundaryOwnedRuntime
		)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(
			(
				boundary != null
				and boundary.graph._shape == shape
				and boundary.intact()
				and property.props_intact()
				and not property.has_node("TemplateBackWall")
			),
			(
				"actual selected complete wall slabs replace template and preserve every owned model "
				+ shape
			)
		)
		if boundary == null:
			property.free()
			continue
		var model: Node3D = property.objects[_copies[0]]
		var score: Node3D = property.objects[_inherited["ST-039"]]
		_check(
			(
				(
					model.find_children("*", "CollisionObject3D", true, false).size()
					== StadiumOutfieldBleacherModels.solid_count()
				)
				and not score.find_children("*", "CollisionObject3D", true, false).is_empty()
			),
			(
				(
					"sightline world contains complete assembly solids and the actual current four-meter "
					+ "SCORE-SMALL "
				)
				+ shape
			)
		)
		var rays: Array[Dictionary] = []
		for index in range(eyes.size()):
			var from: Vector3 = model.global_transform * eyes[index]
			for target_index in range(2):
				var target: Vector3 = TARGETS[target_index]
				var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(
					PhysicsRayQueryParameters3D.create(from, target, 1)
				)
				var row: Dictionary = {
					"eye_index": index,
					"row": index / 3,
					"sample": index % 3,
					"eye": _v3(from),
					"target": "plate" if target_index == 0 else "mound",
					"target_position": _v3(target),
					"native_clear": hit.is_empty(),
					"hit_body": str(hit.collider.name) if not hit.is_empty() else "",
					"hit_position": _v3(hit.position) if not hit.is_empty() else []
				}
				_operands = {"shape": shape, "ray": row}
				_check(
					hit.is_empty(),
					(
						"actual complete solids wall slabs and current scoreboard clear represented eye "
						+ str(index)
						+ " to "
						+ row.target
						+ ":"
						+ shape
					)
				)
				rays.append(row)
		# Front-center eye to the nominal (0, 0.02, 23.2) ground target clears all
		# 327 assembly prisms and the entire current SCORE-SMALL envelope. No exclusions.
		var blind_from: Vector3 = model.global_transform * eyes[1]
		var blind_target: Vector3 = Vector3(0, 0.02, 23.2)
		var blind: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(blind_from, blind_target, 1)
		)
		var blind_wall: Node = blind.get("collider")
		var blind_role: String = (
			str(blind_wall.get_meta("surface_role", "")) if blind_wall != null else ""
		)
		var blind_occluded: bool = not blind.is_empty() and blind_role == "BACK_WALL_TERMINAL"
		_operands = {
			"shape": shape,
			"eye": _v3(blind_from),
			"target": _v3(blind_target),
			"hit_body": str(blind_wall.name) if blind_wall != null else "",
			"hit_role": blind_role,
			"hit_position": _v3(blind.position) if not blind.is_empty() else [],
			"excluded_bodies": 0
		}
		_check(
			blind_occluded,
			(
				(
					"actual near-wall ground target is occluded by the current wall and forbids a "
					+ "full-field visibility claim "
				)
				+ shape
			)
		)
		_sightline_matrix.append(
			{
				"shape": shape,
				"tier": "mogul",
				"layout_version": layout.version,
				"boundary_signature": boundary.graph.signature(),
				"wall_owned_copies": layout.walls.back.get("copies", []).size(),
				"assembly_solids": StadiumOutfieldBleacherModels.solid_count(),
				"query_layer": 1,
				"excluded_bodies": 0,
				"rays": rays,
				"blind_eye": _v3(blind_from),
				"blind_target": _v3(blind_target),
				"blind_hit_body": str(blind_wall.name) if blind_wall != null else "",
				"blind_hit_role": blind_role,
				"blind_hit_position": _v3(blind.position) if not blind.is_empty() else [],
				"blind_ground_occluded": blind_occluded
			}
		)
		property.free()
		await get_tree().physics_frame
	_tree_triangle_witness(root)
	await _close_view()


func _body_rids(model: Node3D) -> Array[RID]:
	var result: Array[RID] = []
	for body: Node in model.find_children("*", "CollisionObject3D", true, false):
		result.append((body as CollisionObject3D).get_rid())
	return result


func _front_edge_support(
	property: StadiumPropertyGeometry, points: Array[Vector3], terrain_shape: CollisionShape3D
) -> Array[Dictionary]:
	# The exact reserve corners lie on the shared closed top/front edge at z=32.
	# A vertical ray there has a tied side normal; inspect the actual physical faces
	# before using the separate one-millimeter inward strict-up ray below.
	var body: StaticBody3D = property.get_node_or_null("OuterPropertyGround3") as StaticBody3D
	var shapes: Array[Node] = (
		body.find_children("*", "CollisionShape3D", true, false) if body != null else []
	)
	var collision: CollisionShape3D = shapes[0] as CollisionShape3D if shapes.size() == 1 else null
	var physical: BoxShape3D = collision.shape as BoxShape3D if collision != null else null
	var actual_box: AABB = (
		collision.global_transform * AABB(-physical.size * 0.5, physical.size)
		if physical != null
		else AABB()
	)
	var faces: PackedVector3Array = (terrain_shape.shape as ConcavePolygonShape3D).get_faces()
	var result: Array[Dictionary] = []
	for point: Vector3 in points:
		var contains: bool = (
			physical != null
			and not collision.disabled
			and collision.global_transform.basis == Basis.IDENTITY
			and body.collision_layer == 1
			and body.get_meta("ball_surface", &"") == &"ground"
			and point.x >= actual_box.position.x
			and point.x <= actual_box.end.x
			and point.z == actual_box.position.z
			and is_zero_approx(point.y)
			and is_zero_approx(actual_box.end.y)
		)
		var inner_meets: bool = false
		for index in range(0, faces.size(), 3):
			for edge in range(3):
				var a: Vector3 = terrain_shape.global_transform * faces[index + edge]
				var b: Vector3 = terrain_shape.global_transform * faces[index + (edge + 1) % 3]
				inner_meets = (
					inner_meets
					or (
						a.z == point.z
						and b.z == point.z
						and is_zero_approx(a.y)
						and is_zero_approx(b.y)
						and point.x >= minf(a.x, b.x)
						and point.x <= maxf(a.x, b.x)
					)
				)
		result.append(
			{
				"point": _v3(point),
				"collider": str(body.name) if body != null else "",
				"closed_box_min": _v3(actual_box.position),
				"closed_box_max": _v3(actual_box.end),
				"closed_top_contains": contains,
				"inner_faces_meet": inner_meets
			}
		)
	return result


func _ground_ray(
	root: Node3D, point: Vector3, excludes: Array[RID], kind: String, label: String
) -> Dictionary:
	# Only the two nominal front reserve corners use a one-millimeter inward z probe.
	# Their exact physical edge support is independently checked in the same property.
	var inset: float = (
		0.001 if kind == "full-reservation" and point.z == 32 and point.x in [-25.0, -9.0] else 0.0
	)
	var sample: Vector3 = point + Vector3(0, 0, inset)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		sample + Vector3.UP * 12, sample - Vector3.UP, 1, excludes
	)
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(query)
	var ground: Node = hit.get("collider")
	var supported: bool = (
		not hit.is_empty()
		and ground != null
		and ground.get_meta("ball_surface", &"") == &"ground"
		and absf(hit.position.y) < 0.0003
		and hit.normal.is_equal_approx(Vector3.UP)
	)
	var measured: Dictionary = {
		"kind": kind,
		"point": _v3(point),
		"sample_point": _v3(sample),
		"inset_m": inset,
		"actual_y": hit.position.y if not hit.is_empty() else null,
		"normal": _v3(hit.normal) if not hit.is_empty() else [],
		"collider": str(ground.name) if ground != null else "",
		"supported": supported
	}
	_operands = {"case": label, "ray": measured}
	_check(supported, "actual native ground supports whole footprint and assembly base " + label)
	return measured
