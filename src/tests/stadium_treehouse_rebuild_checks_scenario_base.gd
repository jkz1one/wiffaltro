extends "res://src/tests/stadium_treehouse_rebuild_checks_fixture_base.gd"
func _ownership() -> void:
	_phase = "exact-paid-copy-gates-and-inherited-state"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 3, "hits": 4})
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
		"adoption grants neither treehouse nor separate ST-013 support tree"
	)
	var entry: Dictionary = StadiumCatalog.item(ITEM)
	_check(
		(
			entry.blueprint_price == 560
			and entry.copy_price == 170
			and ClubCareer.same(entry.requires, {"seasons": 6, "wins": 18})
		),
		"unchanged ST-045 catalog price and exact S6 W18 gate"
	)
	for delta: Vector2i in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1)]:
		var quote: Dictionary = StadiumPurchases.quote(
			_paid.construction(),
			ITEM,
			1,
			"treehouse-gate:" + str(delta),
			StadiumTreehouseItems.PRICE_VERSION,
			{"seasons": 6 + delta.x, "wins": 18 + delta.y}
		)
		_operands = {"delta": str(delta), "ok": quote.ok, "error": quote.get("error", "")}
		_check(
			quote.ok == (delta == Vector2i.ZERO),
			"exact threshold and each just-below gate " + str(delta)
		)
	_check(
		not (
			StadiumPurchases
			. quote(
				_paid.construction(),
				ITEM,
				1,
				"treehouse-old-price",
				StadiumPracticeFacilityItems.PRICE_VERSION,
				{"seasons": 6, "wins": 18}
			)
			. ok
		),
		"older practice price route cannot buy a treehouse"
	)
	_copies.append(_buy(ITEM, StadiumTreehouseItems.PRICE_VERSION, 730))
	_copies.append(_buy(ITEM, StadiumTreehouseItems.PRICE_VERSION, 170))
	_check(
		(
			_paid.construction().copies.size() == 5
			and _paid.construction().copies.values().all(
				func(row: Dictionary) -> bool: return row.item != "ST-013"
			)
		),
		"two complete treehouse purchases grant no separate shade-tree copy"
	)
	_inherited["ST-051"] = _buy("ST-051", StadiumMoldedSeatItems.PRICE_VERSION, 265)
	_inherited["ST-052"] = _buy("ST-052", StadiumGroundBoxItems.PRICE_VERSION, 680)
	_inherited["ST-060"] = _buy("ST-060", StadiumPracticeFacilityItems.PRICE_VERSION, 970)
	_inherited["ST-013"] = _buy("ST-013", StadiumLandscapeOwnedItems.PRICE_VERSION, 340)
	_inherited["ST-019"] = _buy("ST-019", StadiumLandscapeOwnedItems.PRICE_VERSION, 450)
	if _copies.has("") or _inherited.values().has(""):
		return
	_check(
		_paid.construction().copies.size() == 10 and StadiumLayoutSnapshot.matches(starter, _paid),
		"seven explicit purchased copies preserve the exact authenticated starter prefix"
	)
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "treehouse-land:" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_operands = {"tier": tier, "error": result.get("error", "")}
		_check(
			result.ok and _paid.construction().copies.size() == 10,
			"ordinary land purchase exposes site without granting copies " + tier
		)
	var base28: Dictionary = StadiumSmallYardSceneryItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	var inherited: Dictionary = StadiumMoldedSeatItems.place(
		base28, _paid.construction(), _inherited["ST-051"], "SEAT-PAD-1", 0.0, _paid.surface_owned()
	)
	inherited = StadiumGroundBoxItems.place(
		inherited, _paid.construction(), _inherited["ST-052"], "BOX-L", 0.0, _paid.surface_owned()
	)
	inherited = StadiumPracticeFacilityItems.place(
		inherited,
		_paid.construction(),
		_inherited["ST-060"],
		"PRACTICE-CLUB",
		0.0,
		_paid.surface_owned()
	)
	inherited.landscape = [
		{"copy": _inherited["ST-019"], "item": "ST-019", "site": "LAND-L", "yaw": 0},
		{"copy": _inherited["ST-013"], "item": "ST-013", "site": "TREE-L", "yaw": 0}
	]
	_check(
		_checked(inherited).ok and _apply(inherited),
		"accepted family31 optional pad and paid box practice and landscape install before adoption"
	)
	_record("inherited-family31-with-optional-pad", inherited)
	_old_prefix = StadiumLayoutSnapshot.capture(_paid)
	_pad_occupied = StadiumTreehouseItems.upgrade(inherited, _paid.surface_owned())
	_check(
		(
			_pad_occupied.version == 32
			and _pad_occupied.ground_box_base_version == 29
			and _pad_occupied.treehouses.is_empty()
			and ClubCareer.same(StadiumTreehouseItems.base(_pad_occupied), inherited)
			and _checked(_pad_occupied).ok
			and _apply(_pad_occupied)
		),
		"empty family32 preserves all inherited optional and paid channels exactly"
	)
	_record("treehouse-family-preserves-populated-pad", _pad_occupied)
	_check(
		ClubCareer.same(StadiumMoldedSeatItems.remove_pad(_pad_occupied), _pad_occupied),
		"populated pad removal refuses without silently storing an owned seat"
	)
	_refused("populated-pad-treehouse", _place(_pad_occupied, _copies[0]))
	_pad_empty = StadiumMoldedSeatItems.store_copy(_pad_occupied, _inherited["ST-051"])
	_check(
		(
			StadiumMoldedSeatItems.has_pad(_pad_empty)
			and _pad_empty.molded_seats.is_empty()
			and _checked(_pad_empty).stored.has(_inherited["ST-051"])
			and _apply(_pad_empty)
		),
		"Store keeps the selected empty pad and the same paid seat in inventory"
	)
	_record("seat-stored-pad-still-selected", _pad_empty)
	_refused("empty-selected-pad-treehouse", _place(_pad_empty, _copies[0]))
	var no_pad: Dictionary = StadiumMoldedSeatItems.remove_pad(_pad_empty)
	_check(
		(
			not StadiumMoldedSeatItems.has_pad(no_pad)
			and not no_pad.has("molded_seats")
			and no_pad.ground_box_base_version == 28
			and no_pad.ground_boxes == inherited.ground_boxes
			and no_pad.practice_facilities == inherited.practice_facilities
			and no_pad.landscape == inherited.landscape
			and _checked(no_pad).ok
			and _apply(no_pad)
		),
		"explicit empty-pad remove transaction changes only optional infrastructure"
	)
	_record("empty-pad-actually-removed", no_pad)
	var balance: int = _paid.balance()
	_inherited_tree = _place(no_pad, _copies[0])
	_check(
		(
			_checked(_inherited_tree).ok
			and _apply(_inherited_tree)
			and _paid.balance() == balance
			and _checked(_inherited_tree).placements.any(
				func(row: Dictionary) -> bool: return row.copy == _inherited["ST-013"]
			)
		),
		(
			"treehouse installs after removal while preserving independently paid shade tree box "
			+ "practice and landscape"
		)
	)
	_record("treehouse-with-preserved-inherited-copies", _inherited_tree)
	var reselect: Dictionary = StadiumMoldedSeatItems.upgrade(
		_inherited_tree, _paid.surface_owned()
	)
	_check(
		(
			StadiumMoldedSeatItems.has_pad(reselect)
			and reselect.treehouses == _inherited_tree.treehouses
			and not _checked(reselect).ok
		),
		"inverse pad reselect keeps visible treehouse identity and refuses its actual conflict"
	)
	_refused("treehouse-pad-reselect", reselect)
	var stored: Dictionary = StadiumTreehouseItems.store_copy(_inherited_tree, _copies[0])
	_check(
		stored.treehouses.is_empty() and _checked(stored).stored.has(_copies[0]) and _apply(stored),
		"explicit treehouse Store vacates the site without losing either complete copy"
	)
	_record("treehouse-stored-for-pad-reselect", stored)
	var restored_pad: Dictionary = StadiumMoldedSeatItems.upgrade(stored, _paid.surface_owned())
	_check(
		(
			StadiumMoldedSeatItems.has_pad(restored_pad)
			and restored_pad.molded_seats.is_empty()
			and _checked(restored_pad).ok
			and _apply(restored_pad)
		),
		"actual empty-pad reselect transaction succeeds only after treehouse Store"
	)
	_record("empty-pad-actually-reselected", restored_pad)
	var seat_back: Dictionary = StadiumMoldedSeatItems.place(
		restored_pad,
		_paid.construction(),
		_inherited["ST-051"],
		"SEAT-PAD-1",
		0.0,
		_paid.surface_owned()
	)
	_check(
		(
			ClubCareer.same(seat_back, _pad_occupied)
			and _apply(seat_back)
			and _paid.balance() == balance
		),
		"same exact stored seat remounts into reselected pad with no new charge"
	)
	_record("same-seat-remounted-after-treehouse-store", seat_back)
	_empty = StadiumTreehouseItems.upgrade(base28, _paid.surface_owned())
	_check(
		(
			_empty.version == 32
			and _empty.ground_box_base_version == 28
			and not _empty.has("molded_seats")
			and _empty.treehouses.is_empty()
			and _checked(_empty).ok
			and _apply(_empty)
		),
		"treehouse-only empty plan grants no optional pad or bundled inventory"
	)
	_record("empty-treehouse-only-plan", _empty)
	_layout = _place(_empty, _copies[0])
	_check(
		_checked(_layout).ok and _apply(_layout) and _paid.balance() == balance,
		"one exact paid complete treehouse applies without another charge"
	)
	_record("one-paid-complete-treehouse", _layout)
	var tree_stored: Dictionary = StadiumTreehouseItems.store_copy(_layout, _copies[0])
	_check(
		(
			ClubCareer.same(tree_stored, _empty)
			and _checked(tree_stored).stored.has(_copies[0])
			and _apply(tree_stored)
		),
		"exact-copy Store returns only placement to empty while retaining ownership"
	)
	_record("complete-treehouse-stored", tree_stored)
	_check(
		(
			ClubCareer.same(_place(tree_stored, _copies[0]), _layout)
			and _apply(_layout)
			and _paid.balance() == balance
		),
		"same complete copy remounts with its original identity and no charge"
	)
	_record("same-complete-treehouse-remounted", _layout)
	_negatives()
	_check(
		(
			_checked(_layout).ok
			and _apply(_layout)
			and _paid.balance() == balance
			and _paid.to_data().version == 40
			and _paid.construction().copies.size() == 10
		),
		"final current-copy plan applies on ledger40 with unchanged purchased inventory"
	)
	_record("final-current-complete-treehouse", _layout)
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
		"accepted practice family31 prefix remains authenticated warm and cold"
	)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not _checked(_layout).get("night_qualified", true)
		),
		"frozen complete treehouse fixture preserves daylight-only admission"
	)


func _body_rids(model: Node3D) -> Array[RID]:
	var result: Array[RID] = []
	for body: Node in model.find_children("*", "CollisionObject3D", true, false):
		result.append((body as CollisionObject3D).get_rid())
	return result


func _camera_clearance(lab: PitchBatLab, box: AABB) -> void:
	_phase = "bounded-current-batting-camera-clearance"
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
			var blocked: bool = (
				box.has_point(pose.origin)
				or (
					box.intersects_segment(pose.origin, PitchBatLab.MOUND_ORIGIN + Vector3.UP)
					!= null
				)
			)
			_operands = {
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _v3(pose.origin),
				"pitcher_target": _v3(PitchBatLab.MOUND_ORIGIN + Vector3.UP),
				"blocked": blocked
			}
			_check(
				not blocked,
				"actual current batting origin and pitcher sightline clear the whole treehouse reservation"
			)
			_camera_cases.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress


func _ground_ray(
	root: Node3D, point: Vector3, excludes: Array[RID], kind: String, label: String
) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 8, point - Vector3.UP, 1, excludes
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
		"actual_y": hit.position.y if not hit.is_empty() else null,
		"normal": _v3(hit.normal) if not hit.is_empty() else [],
		"collider": str(ground.name) if ground != null else "",
		"supported": supported
	}
	_operands = {"case": label, "ray": measured}
	_check(
		supported,
		"actual native ground supports the entire reservation seam or assembly base " + label
	)
	return measured


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
		"actual Workshop preview builds the paid complete treehouse without optional pad in daylight"
	)
	preview.focus_copy(_copies[0])
	await get_tree().process_frame
	var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
	var bounds: AABB = preview.board_bounds.get(_copies[0], AABB())
	var contained: bool = (
		preview.board_bounds.has(_copies[0]) and rect.size.x > 0 and rect.size.y > 0
	)
	for index in range(8):
		var point: Vector3 = bounds.get_endpoint(index)
		contained = (
			contained
			and not preview.camera.is_position_behind(point)
			and rect.has_point(preview.camera.unproject_position(point))
		)
	_operands = {
		"copy": _copies[0],
		"bounds": str(bounds),
		"viewport": [rect.size.x, rect.size.y],
		"eye": _v3(preview.camera.position)
	}
	_check(
		contained,
		"actual owned-copy preview focus contains all eight complete treehouse reservation corners"
	)
	_ui_cases.native_preview = true
	_ui_cases.focus_cases = [{"copy": _copies[0], "all_eight_corners_in_frame": contained}]
	_ui_cases.night_eligible = preview.night_eligible
	preview.queue_free()
	await get_tree().process_frame


func _in_frame(camera: Camera3D, box: AABB) -> bool:
	var readable: Rect2 = Rect2(12, 90, 1256, 615)
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
	_phase = "two-native-complete-treehouse-originals"
	var camera: Camera3D = _studio(root, Vector3(44, 48, -56), Vector3(-7, 1, 14), 55)
	_label(
		root,
		"ST-045 TIMBER TREEHOUSE | One complete paid parent in the current field",
		Vector2(22, 18),
		23
	)
	_label(
		root,
		"TREEHOUSE-A | Full 6 x 6 x 7 m reservation | synthetic funding and progression",
		Vector2(22, 50),
		18
	)
	await get_tree().process_frame
	var world_box: AABB = StadiumTreehouseItems.bounds(_checked(_layout).treehouse_placements[0])
	_check(
		_in_frame(camera, world_box),
		"overview contains the full installed treehouse clear of heading and bottom HUD"
	)
	var field_visible: bool = true
	for point: Vector2 in StadiumTreehouseItems.graph_for(_layout).polygon():
		field_visible = (
			field_visible
			and not camera.is_position_behind(Vector3(point.x, 0, point.y))
			and Rect2(10, 90, 1260, 615).has_point(
				camera.unproject_position(Vector3(point.x, 0, point.y))
			)
		)
	_check(
		field_visible,
		"overview contains the current complete field alongside the installed treehouse"
	)
	await _capture("treehouse-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	var detail: Node3D = StadiumTreehouseModels.create()
	root.add_child(detail)
	detail.position = Vector3(900, 0, 0)
	camera.position = detail.position + Vector3(8.5, 7.5, -11)
	camera.look_at(detail.position + Vector3(0, 3.2, 0))
	camera.size = 10.4
	_label(
		root,
		"COMPLETE TIMBER TREEHOUSE | Bundled tree, cabin, deck, ladder and railings",
		Vector2(22, 18),
		23
	)
	_label(
		root,
		"Field-facing model view | static off-field scenery | no climbing, gameplay bonus or Night claim",
		Vector2(22, 50),
		17
	)
	await get_tree().process_frame
	_check(
		(
			_in_frame(camera, detail.transform * StadiumTreehouseModels.visible_bounds())
			and is_instance_valid(property.objects.get(_copies[0]))
		),
		(
			"model-only detail contains the complete field-facing artwork while the paid "
			+ "installation stays intact"
		)
	)
	await _capture("treehouse-details.png")
	detail.free()


func _runtime_and_views() -> void:
	_phase = "ordinary-registered-family32-property"
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
	_check(installed, "ordinary frozen paid snapshot installs the complete family32 property")
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
		"actual property and paid boundary identity seals remain intact"
	)
	var checked: Dictionary = _checked(_layout)
	var row: Dictionary = checked.treehouse_placements[0]
	var model: Node3D = property.objects.get(row.copy)
	var exact: bool = (
		is_instance_valid(model)
		and model.get_meta("stadium_item", "") == ITEM
		and model.get_meta("owned_copy", "") == row.copy
		and model.get_meta("site", "") == SITE
	)
	_operands = {"copy": row.copy, "site": row.site, "model_valid": is_instance_valid(model)}
	_check(
		(
			exact
			and model.position == row.position
			and is_zero_approx(model.rotation.y)
			and model.scale == Vector3.ONE
		),
		"actual complete paid treehouse retains exact copy identity and fixed full-size pose"
	)
	if not exact:
		await _close_view()
		return
	var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
	var roles: bool = not bodies.is_empty()
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
		"every actual treehouse body is owned after-terminal scenery with no receiver Area"
	)
	_check(
		(
			property.route_obstacles().is_empty()
			and checked.get("live_units", -1) == 0
			and not property.has_node("PitchReceiverPresentation")
		),
		"complete scenery adds no live unit receiver or defender route obstacle"
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
			and model.get_meta("bundled_support_tree", false)
			and not model.get_meta("climbing_enabled", true)
			and not model.get_meta("connected_pedestrian_route", true)
		),
		"complete parent remains static with bundled support and no climbing or connected route"
	)
	var surface: String = str(bodies[0].name) if not bodies.is_empty() else ""
	var events: Array = [
		{
			"source": "item",
			"id": row.copy,
			"surface": surface,
			"role": "LIVE_RICOCHET",
			"position": _v3(row.position + Vector3.UP),
			"time": 0.1,
			"kind": "contact"
		}
	]
	_check(
		not PhysicalStadiumContacts.valid(
			[{"play": 0, "reason": "", "events": events}],
			[{"result": "single", "contact": ContactResult.Outcome.CONTACT, "exit_speed": 12.0}],
			_snapshot
		),
		"ordinary report refuses fabricated live scoring against an actual treehouse surface"
	)
	_check(
		(
			property.objects.size() == 1
			and not property.has_node("MoldedSeatPad")
			and not _layout.has("molded_seats")
			and _layout.ground_boxes.is_empty()
			and _layout.practice_facilities.is_empty()
		),
		(
			"ordinary treehouse-only installation invents no optional infrastructure or additional "
			+ "paid parent"
		)
	)
	var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = baseline.build("mogul", _empty, _paid.construction())
	_check(
		built and baseline.objects.is_empty() and not baseline.has_node("MoldedSeatPad"),
		"ordinary empty family32 plan grants no free treehouse or pad"
	)
	_check(
		(
			built
			and property.route_obstacles() == baseline.route_obstacles()
			and lab._primary_fielder.stadium_obstacles == property.route_obstacles()
		),
		"actual fielder preserves the unchanged empty-plan route"
	)
	baseline.free()
	var inherited_property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var inherited_built: bool = inherited_property.build(
		"mogul", _inherited_tree, _paid.construction()
	)
	_check(
		(
			inherited_built
			and not inherited_property.has_node("MoldedSeatPad")
			and inherited_property.props_intact()
			and inherited_property.objects.size() == 5
			and inherited_property.objects.has(_copies[0])
			and inherited_property.objects.has(_inherited["ST-013"])
		),
		(
			"actual preserved assembly retains treehouse plus separately paid box practice shade "
			+ "tree and landscape"
		)
	)
	inherited_property.free()
	_check(
		(
			PhysicalStadiumContacts.valid([], [], _snapshot)
			and lab._play_records.is_empty()
			and lab._batted_ball == null
		),
		"zero-play native install invents no contacts scoring training or performance result"
	)
	var measured: Array[Dictionary] = []
	var excludes: Array[RID] = _body_rids(model)
	for point: Vector3 in StadiumTreehouseModels.support_points():
		measured.append(
			_ground_ray(
				root, model.global_transform * point, excludes, "actual-assembly-base", str(point)
			)
		)
	var approach: AABB = StadiumTreehouseModels.local_approach_bounds()
	var approach_point: Vector3 = approach.get_center()
	approach_point.y = 0
	measured.append(
		_ground_ray(
			root,
			model.global_transform * approach_point,
			excludes,
			"local-approach",
			"ladder-approach"
		)
	)
	var tracking: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var current_bounds: Array[AABB] = []
	for mesh: Node in model.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		var world_bounds: AABB = (
			(mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		)
		if world_bounds.size.y > 0.025:
			current_bounds.append(world_bounds)
	var collected: bool = not current_bounds.is_empty()
	for bounds: AABB in current_bounds:
		collected = collected and tracking._obstacles.has(bounds)
	_operands = {
		"treehouse_visible_bounds": current_bounds.size(),
		"tracking_obstacles": tracking._obstacles.size()
	}
	_check(
		collected and tracking._owned_receiver_models.is_empty(),
		(
			"ordinary dynamic tracking collection contains every current treehouse mesh without "
			+ "receiver exclusion"
		)
	)
	_runtime = {
		"ordinary_install": installed,
		"copy": row.copy,
		"item": row.item,
		"site": row.site,
		"position": _v3(row.position),
		"physical_scenery_bodies": bodies.size(),
		"paid_complete_parents": 1,
		"optional_pad_adopted": false,
		"live_units": checked.get("live_units", -1),
		"route_obstacles": property.route_obstacles().size(),
		"zero_play_report_valid": true,
		"false_live_surface_claims_rejected": 1,
		"active_animation": not static_only,
		"assembly_support_rays": measured,
		"tracking_mesh_bounds": current_bounds.size(),
		"tracking_collected": collected
	}
	_camera_clearance(lab, StadiumTreehouseItems.bounds(row))
	await _preview_focus()
	await _views(root, property)
	_check(
		(
			property.props_intact()
			and boundary != null
			and boundary.intact()
			and lab._play_records.is_empty()
		),
		"native views and focus preserve the current registered installation without games"
	)
	await _close_view()
