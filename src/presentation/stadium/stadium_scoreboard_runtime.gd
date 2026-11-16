class_name StadiumScoreboardRuntime
extends RefCounted
## Complete fixture13 installer and world checks; scheduled reward authority is separate.

const IDENTITY: StringName = &"scoreboard_runtime_identity"
const AUTHORING: Array[StringName] = [
	&"stadium_candidate_only",
	&"stadium_lab_only",
	&"stadium_boundary_lab_only",
	&"stadium_advanced_lab_only",
	&"stadium_club_lab_only",
	&"stadium_scoreboard_lab_only",
	&"advanced_authoring_fixture",
	&"scoreboard_authoring_fixture"
]


static func install_bound(lab: PitchBatLab) -> bool:
	if not _startup(lab) or not _fixture(lab._match_state.stadium):
		return false
	var frozen: Dictionary = StadiumScoreboardSnapshot.normalized(lab._match_state.stadium)
	return _install_frozen(lab, frozen, StadiumScoreboardSnapshot.ownership(frozen))


static func install_mounted_bound(lab: PitchBatLab, ledger: ClubAssetLedger) -> bool:
	# Dedicated raw fixture15 exercise only. Public snapshot/report dispatch stays closed.
	if not _startup(lab) or lab._camera_director.tracking_visibility == null \
		or not StadiumMountedPresentationContract.preflight(lab):
		return false
	var context: Dictionary = StadiumMountedScoreboardContract.context(
		lab._match_state.stadium, ledger)
	if context.is_empty() or not StadiumMountedScoreboardContract.origin_clean(lab):
		return false
	return _install_frozen(lab, context.frozen, context.owners)


static func _install_frozen(lab: PitchBatLab, frozen: Dictionary, owners: Dictionary) -> bool:
	var host: StarterFieldLabGeometry = _host(lab)
	if host == null or host.has_node("HomeProperty"):
		return false
	var access: Array[String] = []
	access.assign(frozen.surface_access)
	var property: StadiumScoreboardPropertyGeometry = StadiumScoreboardPropertyGeometry.new()
	if not property.build_scoreboards(
		frozen.tier, frozen.layout, owners.stock, owners.pieces, owners.boards, access
	):
		property.free()
		return false
	var physics: Dictionary = _boundary_physics(property.boundary)
	if physics.is_empty() or _object_physics(property).is_empty() \
		or (_mounted(frozen) and StadiumMountedScoreboardIntegrity.capture(
			property, frozen.layout).is_empty()):
		property.free()
		return false
	# The complete builder already owns its only boundary. Never assemble a second one.
	if not StadiumPropertyRuntime._attach(lab, host, property, frozen.layout):
		property.free()
		return false
	lab._ball_play_resolver.segment_observer = property.observe
	var boundary: Node3D = property.boundary
	lab._primary_fielder.stadium_boundary_clip = (
		boundary.graph.clip if boundary is StadiumRecipeBoundaryBody else StadiumBoundaryGraph.clip
	)
	lab.set_meta("boundary_signature", frozen.boundary)
	lab._camera_director.tracking_visibility = (
		StadiumMountedCameraVisibility.new() if _mounted(frozen) else (
			StadiumHeightCameraVisibility.new() if boundary is StadiumHeightBoundaryBody
			else BallTrackingVisibility.new())
	)
	lab._camera_director.tracking_visibility.configure(host)
	lab.set_meta("stadium_snapshot", frozen)
	if _mounted(frozen):
		StadiumMountedPresentationContract.bind(lab, property, frozen)
	StadiumWallRenderQuality.attach(boundary)
	property.rebind_displays(lab._match_state)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	lab.set_meta("stadium_snapshot", frozen)
	var identity: Dictionary = _identity(property, frozen, physics)
	if _mounted(frozen):
		identity["mounted_presentation"] = StadiumMountedPresentationContract.capture(lab, property)
		identity["mounted_host"] = host.get_instance_id()
		identity["mounted_lab"] = lab.get_instance_id()
		identity["mounted_assemblies"] = StadiumMountedScoreboardIntegrity.capture(
			property, frozen.layout)
		identity["mounted_camera"] = StadiumMountedScoreboardIntegrity.camera_capture(
			lab._camera_director.tracking_visibility)
	lab.set_meta(IDENTITY, identity)
	return true


static func installed(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	return _fixture(snapshot) and _installed_frozen(lab, snapshot)


static func mounted_installed(lab: PitchBatLab, snapshot: Dictionary,
	ledger: ClubAssetLedger) -> bool:
	var context: Dictionary = StadiumMountedScoreboardContract.context(snapshot, ledger)
	return not context.is_empty() and StadiumMountedScoreboardContract.origin_clean(lab) \
		and _installed_frozen(lab, context.frozen)


static func _installed_frozen(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	if (
		not is_instance_valid(lab)
		or _authoring(lab)
		or lab._match_state == null
		or lab._field_id != PitchBatLab.FIELD_ID
		or not lab.has_meta("stadium_property")
		or not lab.get_meta(IDENTITY, {}) is Dictionary
	):
		return false
	var host: StarterFieldLabGeometry = _host(lab)
	var value: Variant = lab.get_meta("stadium_property")
	if (
		host == null
		or not value is StadiumScoreboardPropertyGeometry
		or not is_instance_valid(value)
	):
		return false
	var property: StadiumScoreboardPropertyGeometry = value
	var identity: Dictionary = lab.get_meta(IDENTITY, {})
	var key: String = _snapshot_key(snapshot)
	if (
		not _same(identity.get("key"), key)
		or _snapshot_key(lab.get_meta("stadium_snapshot", {})) != key
		or _snapshot_key(lab._match_state.stadium) != key
		or not _id(identity.get("property"), property.get_instance_id())
		or host.get_node_or_null("HomeProperty") != property
		or not property.transform.is_equal_approx(Transform3D.IDENTITY)
	):
		return false
	return (
		_metadata(property, snapshot)
		and _boundary(lab, property, snapshot, identity)
		and _objects(property, snapshot, identity)
		and _physics_equal(_object_physics(property), identity.get("object_physics"))
		and _wiring(lab, property, snapshot.layout)
		and (not _mounted(snapshot) or (
			_id(identity.get("mounted_host"), host.get_instance_id())
			and _id(identity.get("mounted_lab"), lab.get_instance_id())
			and StadiumMountedScoreboardIntegrity.matches(property, snapshot.layout,
				identity.get("mounted_assemblies"))
			and StadiumMountedPresentationContract.matches(lab, property, snapshot,
				identity.get("mounted_presentation"))
			and StadiumMountedScoreboardIntegrity.camera_matches(
				lab._camera_director.tracking_visibility, host, identity.get("mounted_camera"))))
	)


static func _mounted(value: Dictionary) -> bool:
	return SeasonOwnership._whole(value.get("version"), 15, 15)


static func _snapshot_key(value: Variant) -> String:
	return StadiumMountedScoreboardSnapshot.key(value) \
		if value is Dictionary and _mounted(value) else StadiumScoreboardSnapshot.key(value)


static func _fixture(value: Variant) -> bool:
	return (
		StadiumScoreboardSnapshot.valid(value)
		and int(value.version) == StadiumScoreboardSnapshot.FIXTURE_VERSION
	)


static func _authoring(lab: PitchBatLab) -> bool:
	for marker: StringName in AUTHORING:
		if lab.has_meta(marker):
			return true
	return false


static func _startup(lab: PitchBatLab) -> bool:
	if (
		not is_instance_valid(lab)
		or _authoring(lab)
		or lab._match_state == null
		or not lab._match_mode
		or lab._field_id != PitchBatLab.FIELD_ID
		or lab.has_meta("stadium_property")
		or lab.has_meta(IDENTITY)
		or is_instance_valid(lab._batted_ball)
		or lab._pitch_actor == null
	):
		return false
	# Automated startup begins DELIVERY before binding its venue, but has no live pitch.
	return (
		lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and not lab._pitch_actor.running
		and (lab._release_controller == null or not lab._release_controller.active)
		and (
			lab._at_bat_cadence == null
			or (
				lab._at_bat_cadence.state
				in [AtBatCadenceController.State.IDLE, AtBatCadenceController.State.DELIVERY]
			)
		)
		and lab._primary_fielder != null
		and lab._ball_play_resolver != null
		and lab._camera_director != null
		and lab._camera_director.presentation_override.is_null()
	)


static func _host(lab: PitchBatLab) -> StarterFieldLabGeometry:
	var host: Node = lab.get_node_or_null("StarterFieldGeometry")
	if (
		not host is StarterFieldLabGeometry
		or not host.is_inside_tree()
		or not host.global_transform.is_equal_approx(Transform3D.IDENTITY)
	):
		return null
	return host


static func _identity(
	property: StadiumScoreboardPropertyGeometry, frozen: Dictionary, physics: Dictionary
) -> Dictionary:
	var objects: Dictionary = {}
	var poses: Dictionary = {}
	var items: Dictionary = {}
	var sites: Dictionary = {}
	var displays: Dictionary = {}
	for copy: String in property.objects:
		objects[copy] = property.objects[copy].get_instance_id()
		poses[copy] = property.objects[copy].transform
		items[copy] = property.objects[copy].get_meta("stadium_item")
		sites[copy] = property.objects[copy].get_meta("site")
	for copy: String in property.board_objects:
		displays[copy] = (
			property.board_display(copy).get_instance_id()
		)
	return {
		"key": _snapshot_key(frozen),
		"property": property.get_instance_id(),
		"boundary": property.boundary.get_instance_id(),
		"nodes": _children(property),
		"boundary_nodes": _children(property.boundary),
		"physics": physics,
		"object_physics": _object_physics(property),
		"items": items,
		"sites": sites,
		"objects": objects,
		"poses": poses,
		"displays": displays
	}


static func _children(node: Node) -> Array[int]:
	var result: Array[int] = []
	for child: Node in node.get_children():
		result.append(child.get_instance_id())
	result.sort()
	return result


static func _metadata(property: StadiumScoreboardPropertyGeometry, frozen: Dictionary) -> bool:
	var expected: Dictionary = {
		"property_signature": frozen.geometry,
		"scoreboard_layout": frozen.layout,
		"advanced_layout": StadiumScoreboardAssembly.base(frozen.layout),
		"advanced_stock": frozen.inventory,
		"advanced_pieces": frozen.wall_piece_inventory,
		"scoreboard_inventory": frozen.scoreboard_inventory,
		"advanced_surface_access": frozen.surface_access,
		"scoreboard_models": StadiumScoreboardModels.signature()
	}
	if _mounted(frozen):
		expected["scoreboard_mount_catalog"] = StadiumScoreboardMountCatalog.signature(1)
		if property.has_meta("scoreboard_authoring_only") or property.top_level or not property.visible:
			return false
	else:
		expected["scoreboard_authoring_only"] = true
	if StadiumWallItems.uses_recipe(
		StadiumAdvancedWallLayout.base(StadiumScoreboardAssembly.base(frozen.layout))
	):
		expected["wall_selection"] = frozen.layout.walls
		expected["wall_stock"] = frozen.inventory
	for key: String in expected:
		if not property.has_meta(key) or not _same(property.get_meta(key), expected[key]):
			return false
	return (
		property.tier == frozen.tier
		and property.field != null
		and property.field.id == PitchBatLab.FIELD_ID
		and not property.has_node("TemplateBackWall")
	)


static func _boundary(
	lab: PitchBatLab,
	property: StadiumScoreboardPropertyGeometry,
	frozen: Dictionary,
	identity: Dictionary
) -> bool:
	var boundary: Node3D = property.boundary
	if (
		not is_instance_valid(boundary)
		or boundary.get_parent() != property
		or property.get_node_or_null("BoundaryGraph") != boundary
		or not _id(identity.get("boundary"), boundary.get_instance_id())
		or not _ids(identity.get("boundary_nodes"), _children(boundary))
		or not boundary.transform.is_equal_approx(Transform3D.IDENTITY)
		or not _same(lab.get_meta("boundary_signature", ""), frozen.boundary)
		or not _physics_matches(boundary, identity.get("physics"))
	):
		return false
	var expected: StadiumRecipeBoundary = StadiumOwnedLayout.graph_for(frozen.layout)
	if expected == null:
		return (
			boundary is StadiumBoundaryPrototype
			and frozen.boundary == StadiumBoundaryGraph.signature()
			and boundary.get_child_count() == StadiumBoundaryGraph.IDS.size()
		)
	if (
		not boundary is StadiumRecipeBoundaryBody
		or boundary.graph == null
		or boundary.graph.signature() != expected.signature()
		or boundary.graph.signature() != frozen.boundary
		or boundary.get_child_count() != expected.segments().size() + 1
	):
		return false
	return _manifest(property, frozen.layout, frozen.inventory)


static func _manifest(
	property: StadiumScoreboardPropertyGeometry, layout: Dictionary, inventory: Dictionary
) -> bool:
	var boundary: StadiumRecipeBoundaryBody = property.boundary
	var advanced: String = layout.advanced_back.shape
	if not advanced.is_empty():
		var correct: bool = (
			boundary is StadiumOffsetBoundaryBody
			if advanced == "offset_gables"
			else boundary is StadiumHeightBoundaryBody
		)
		return (
			correct
			and (_same(
				boundary.get_meta("advanced_manifest", ""),
				StadiumAdvancedOwnedAssembly.manifest_key(layout.advanced_back, layout.walls)
			))
			and (
				not boundary is StadiumHeightBoundaryBody
				or (_same(
					boundary.get_meta("height_manifest", ""),
					JSON.stringify(layout.advanced_back, "", true, true).sha256_text()
				))
			)
		)
	return (
		not boundary is StadiumOffsetBoundaryBody
		and not boundary is StadiumHeightBoundaryBody
		and not boundary.has_meta("advanced_manifest")
		and (_same(
			boundary.get_meta("wall_manifest", ""),
			JSON.stringify(layout.walls, "", true, true).sha256_text()
		))
		and _same(property.get_meta("wall_selection", {}), layout.walls)
		and _same(property.get_meta("wall_stock", {}), inventory)
	)


static func _objects(
	property: StadiumScoreboardPropertyGeometry, frozen: Dictionary, identity: Dictionary
) -> bool:
	if (
		not _ids(identity.get("nodes"), _children(property))
		or not identity.get("objects") is Dictionary
		or not identity.get("poses") is Dictionary
		or not identity.get("items") is Dictionary
		or not identity.get("sites") is Dictionary
		or not identity.get("displays") is Dictionary
		or property.objects.size() != identity.objects.size()
		or property.board_objects.size() != frozen.layout.scoreboards.size()
	):
		return false
	for copy: Variant in property.objects:
		if not copy is String:
			return false
		var value: Variant = property.objects[copy]
		if (
			not value is Node3D
			or not is_instance_valid(value)
			or value.get_parent() != property
			or not _id(identity.objects.get(copy), value.get_instance_id())
			or not _same(value.get_meta("owned_copy", ""), copy)
			or not _same(value.get_meta("stadium_item", ""), identity.items.get(copy, "unknown"))
			or not _same(value.get_meta("site", ""), identity.sites.get(copy, "unknown"))
			or not identity.poses.get(copy) is Transform3D
			or not value.transform.is_equal_approx(identity.poses[copy])
		):
			return false
	for row: Dictionary in frozen.layout.scoreboards:
		if not _board(property, row, identity.displays.get(row.copy, 0)):
			return false
	return true


static func _board(
	property: StadiumScoreboardPropertyGeometry, row: Dictionary, display_id: Variant
) -> bool:
	var value: Variant = property.board_objects.get(row.copy)
	if (
		not value is Node3D
		or not is_instance_valid(value)
		or property.objects.get(row.copy) != value
	):
		return false
	var model: Node3D = value
	var expected: Dictionary = {
		"owned_copy": row.copy,
		"stadium_item": row.item,
		"scoreboard_owned_model": row.model,
		"site": row.site,
		"surface_role": "DECORATIVE_AFTER_TERMINAL",
		"scoreboard_model_version": StadiumScoreboardTiers.VERSION
	}
	if row.has("mount_profile"):
		expected["scoreboard_mount_profile"] = row.mount_profile
	else:
		expected["scoreboard_candidate"] = StadiumScoreboardCatalog.TIERS[row.item]
	for key: String in expected:
		if not model.has_meta(key) or not _same(model.get_meta(key), expected[key]):
			return false
	var display: Node = StadiumScoreboardAssembly.display(model, row)
	return (
		model.transform.is_equal_approx(StadiumScoreboardAssembly.pose(row))
		and model.find_children("*", "CollisionObject3D", true, false).is_empty()
		and display is StadiumScoreboardTierDisplay
		and _id(display_id, display.get_instance_id())
		and display.tier == StadiumScoreboardCatalog.TIERS[row.item]
	)


static func _wiring(
	lab: PitchBatLab, property: StadiumScoreboardPropertyGeometry, layout: Dictionary
) -> bool:
	if (
		lab._ball_play_resolver == null
		or lab._primary_fielder == null
		or lab._pitch_actor == null
		or lab._camera_director == null
		or lab._ball_play_resolver.segment_observer != property.observe
	):
		return false
	if not SeasonOwnership._whole(layout.get("version"), 15, 15) \
		and not lab._camera_director.presentation_override.is_null():
		return false
	if SeasonOwnership._whole(layout.get("version"), 15, 15) \
		and not StadiumMountedScoreboardIntegrity.equal(
			lab._primary_fielder.stadium_obstacles, property.route_obstacles()):
		return false
	var boundary: Node3D = property.boundary
	var clip: Callable = (
		boundary.graph.clip if boundary is StadiumRecipeBoundaryBody else StadiumBoundaryGraph.clip
	)
	var camera: BallTrackingVisibility = lab._camera_director.tracking_visibility
	if (
		lab._primary_fielder.stadium_boundary_clip != clip
		or camera == null
		or not _camera_type(camera, boundary, layout)
		or (boundary is StadiumRecipeBoundaryBody and camera._recipe != boundary.graph)
	):
		return false
	var receiver: StadiumPitchReceiver = property.get_node_or_null("PitchReceiverPresentation")
	var copy: String = layout.target if not layout.target.is_empty() else layout.receiver
	if (
		not copy.is_empty()
		and (
			receiver == null
			or receiver.chair != property.objects.get(copy)
			or lab._pitch_actor.receiver_router != receiver.route
		)
	):
		return false
	if (
		not layout.net.is_empty()
		and (
			not receiver is StadiumPairedReceiver
			or receiver.net != property.objects.get(layout.net)
		)
	):
		return false
	for copy_id: String in property.board_objects:
		var display: StadiumScoreboardTierDisplay = property.board_display(copy_id)
		if display == null or display._match != lab._match_state:
			return false
		if SeasonOwnership._whole(layout.get("version"), 15, 15) and not display.is_processing():
			return false
	return true


static func _camera_type(camera: BallTrackingVisibility, boundary: Node3D,
	layout: Dictionary) -> bool:
	if SeasonOwnership._whole(layout.get("version"), 15, 15):
		return camera is StadiumMountedCameraVisibility
	return (camera is StadiumHeightCameraVisibility) == (boundary is StadiumHeightBoundaryBody)


static func _same(a: Variant, b: Variant) -> bool:
	# Compare Strings after canonicalization, never unlike metadata Variants directly.
	var left: Variant = JSON.parse_string(JSON.stringify(a, "", true, true))
	var right: Variant = JSON.parse_string(JSON.stringify(b, "", true, true))
	return JSON.stringify(left, "", true, true) == JSON.stringify(right, "", true, true)


static func _id(value: Variant, expected: int) -> bool:
	# These are live engine identities, not JSON fixture numbers. Preserve all 64 bits.
	return value is int and value == expected


static func _ids(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not _id(value[index], expected[index]):
			return false
	return true


static func _boundary_physics(boundary: Node3D) -> Dictionary:
	# Complete boundary builders use direct static prism bodies. Panel art has no colliders.
	# Keep this explicit: a new collision primitive needs a complete geometry contract here.
	if not is_instance_valid(boundary):
		return {}
	var bodies: Array[Dictionary] = []
	for node: Node in boundary.find_children("*", "CollisionObject3D", true, false):
		if not node is StaticBody3D or node.get_parent() != boundary:
			return {}
		var body: Dictionary = _static_physics(node)
		if body.is_empty():
			return {}
		bodies.append(body)
	if bodies.is_empty():
		return {}
	bodies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return {"pose": boundary.transform, "top_level": boundary.top_level, "bodies": bodies}


static func _static_physics(body: StaticBody3D) -> Dictionary:
	if not body.find_children("*", "CollisionPolygon3D", true, false).is_empty():
		return {}
	var shapes: Array[Dictionary] = []
	for node: Node in body.find_children("*", "CollisionShape3D", true, false):
		if node.get_parent() != body:
			return {}
		var shape: CollisionShape3D = node
		var geometry: Dictionary = _shape_geometry(shape.shape)
		if geometry.is_empty():
			return {}
		shapes.append(
			{
				"id": shape.get_instance_id(),
				"resource": shape.shape.get_instance_id(),
				"pose": shape.transform,
				"top_level": shape.top_level,
				"disabled": shape.disabled,
				"geometry": geometry
			}
		)
	if shapes.is_empty():
		return {}
	shapes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var metadata: Dictionary = {}
	for key: StringName in [
		&"boundary_segment",
		&"ball_surface",
		&"owned_copy",
		&"surface_id",
		&"surface_role",
		&"stadium_item"
	]:
		if body.has_meta(key):
			metadata[String(key)] = body.get_meta(key)
	return {
		"id": body.get_instance_id(),
		"metadata": metadata,
		"pose": body.transform,
		"top_level": body.top_level,
		"layer": body.collision_layer,
		"mask": body.collision_mask,
		"priority": body.collision_priority,
		"disable_mode": body.disable_mode,
		"material": _physics_material(body.physics_material_override),
		"linear_velocity": body.constant_linear_velocity,
		"angular_velocity": body.constant_angular_velocity,
		"shapes": shapes
	}


static func _physics_material(material: PhysicsMaterial) -> Dictionary:
	if material == null:
		return {"id": 0}
	return {
		"id": material.get_instance_id(),
		"friction": material.friction,
		"bounce": material.bounce,
		"rough": material.rough,
		"absorbent": material.absorbent
	}


static func _shape_geometry(shape: Shape3D) -> Dictionary:
	if not is_instance_valid(shape):
		return {}
	var result: Dictionary = {}
	if shape is ConvexPolygonShape3D:
		result = _convex_geometry(shape)
	elif (
		shape is BoxShape3D
		and shape.size.is_finite()
		and shape.size.x > 0
		and shape.size.y > 0
		and shape.size.z > 0
	):
		result = {"kind": "box", "size": shape.size}
	elif shape is CylinderShape3D or shape is CapsuleShape3D:
		if (
			is_finite(shape.radius)
			and is_finite(shape.height)
			and shape.radius > 0
			and shape.height > 0
		):
			result = {
				"kind": "cylinder" if shape is CylinderShape3D else "capsule",
				"radius": shape.radius,
				"height": shape.height
			}
	if result.is_empty() or not is_finite(shape.margin) or not is_finite(shape.custom_solver_bias):
		return {}
	result["margin"] = shape.margin
	result["solver_bias"] = shape.custom_solver_bias
	return result


static func _convex_geometry(shape: ConvexPolygonShape3D) -> Dictionary:
	if shape.points.size() < 4:
		return {}
	for point: Vector3 in shape.points:
		if not point.is_finite():
			return {}
	return {"kind": "convex", "points": shape.points.duplicate()}


static func _object_physics(property: StadiumScoreboardPropertyGeometry) -> Dictionary:
	var models: Array[Dictionary] = []
	for copy: Variant in property.objects:
		if not copy is String:
			return {}
		if property.board_objects.has(copy):
			continue
		var value: Variant = property.objects[copy]
		if not value is Node3D or not is_instance_valid(value):
			return {}
		var model: Node3D = value
		var container: Node = model.get_node_or_null("Collision")
		if not container is Node3D:
			return {}
		var collision: Dictionary = _boundary_physics(container)
		if (
			collision.is_empty()
			or (
				model.find_children("*", "CollisionObject3D", true, false).size()
				!= collision.bodies.size()
			)
		):
			return {}
		models.append(
			{
				"copy": copy,
				"id": model.get_instance_id(),
				"container": container.get_instance_id(),
				"collision": collision,
				"top_level": model.top_level
			}
		)
	models.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.copy < b.copy)
	return {"models": models}


static func _physics_matches(boundary: Node3D, frozen: Variant) -> bool:
	var actual: Dictionary = _boundary_physics(boundary)
	return not actual.is_empty() and _physics_equal(actual, frozen)


static func _physics_equal(actual: Variant, frozen: Variant) -> bool:
	# No JSON conversion: engine IDs keep all integer bits, and geometry keeps every component.
	if typeof(actual) != typeof(frozen):
		return false
	if actual is Dictionary:
		return _physics_dictionary(actual, frozen)
	if actual is Array:
		return _physics_array(actual, frozen)
	if (
		typeof(actual)
		in [
			TYPE_BOOL,
			TYPE_INT,
			TYPE_FLOAT,
			TYPE_STRING,
			TYPE_STRING_NAME,
			TYPE_VECTOR3,
			TYPE_TRANSFORM3D,
			TYPE_PACKED_VECTOR3_ARRAY
		]
	):
		return actual == frozen
	return false


static func _physics_dictionary(actual: Dictionary, frozen: Dictionary) -> bool:
	if actual.size() != frozen.size():
		return false
	for key: Variant in actual:
		if not frozen.has(key) or not _physics_equal(actual[key], frozen[key]):
			return false
	return true


static func _physics_array(actual: Array, frozen: Array) -> bool:
	if actual.size() != frozen.size():
		return false
	for index in range(actual.size()):
		if not _physics_equal(actual[index], frozen[index]):
			return false
	return true
