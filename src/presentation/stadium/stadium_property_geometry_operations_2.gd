extends RefCounted
## Stateless operations for the original StadiumPropertyGeometry owner.


static func _source_private_build_property_models(_source_owner: StadiumPropertyGeometry, layout: \
	Dictionary, stock: StadiumStock) -> bool:
	if (
		StadiumMoldedSeatItems.is_family(layout)
		or (
			(
				StadiumGroundBoxItems.is_family(layout)
				or (
					StadiumPracticeFacilityItems.is_family(layout)
					or (
						StadiumTreehouseItems.is_family(layout)
						or (
							StadiumLandmarkItems.is_family(layout)
							or (
								StadiumOutfieldBleacherItems.is_family(layout)
								or (
									StadiumRisingAppleItems.is_family(layout)
									or (
										StadiumWallTopTerraceItems.is_family(layout)
										or (
											StadiumPlayerTunnelItems.is_family(layout)
											or (
												StadiumMountedDisplayItems.is_family(layout)
												or (
													StadiumStringLightItems.is_family(layout)
													or (
														StadiumSalvageCarItems.is_family(layout)
														or (
															StadiumMasteryBannerItems.is_family(
																layout
															)
															or (
																StadiumWaterfallItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumLightingKitItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumOutfieldPlazaItems
																			. is_family(layout)
																		)
																		or (
																			StadiumWaterfallLiveItems
																			. is_family(layout)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
			and StadiumMoldedSeatItems.is_family(StadiumGroundBoxItems.base(layout))
		)
	):
		var pad: Node3D = StadiumMoldedSeatModels.create_pad()
		if pad == null:
			return false
		pad.name = "MoldedSeatPad"
		_source_owner.add_child(pad)
		if not _source_owner._capture_infrastructure(pad):
			return false
	if not _source_owner._appearance(layout, stock):
		return false
	if (
		StadiumReceiverOwnedItems.is_family(layout)
		or (
			StadiumFloodlightOwnedItems.is_family(layout)
			or (
				StadiumLandscapeOwnedItems.is_family(layout)
				or (
					StadiumLiveFurnishingItems.is_family(layout)
					or (
						StadiumSmallYardSceneryItems.is_family(layout)
						or (
							StadiumMoldedSeatItems.is_family(layout)
							or (
								StadiumGroundBoxItems.is_family(layout)
								or (
									StadiumPracticeFacilityItems.is_family(layout)
									or (
										StadiumTreehouseItems.is_family(layout)
										or (
											StadiumLandmarkItems.is_family(layout)
											or (
												StadiumOutfieldBleacherItems.is_family(layout)
												or (
													StadiumRisingAppleItems.is_family(layout)
													or (
														StadiumWallTopTerraceItems.is_family(layout)
														or (
															StadiumPlayerTunnelItems.is_family(
																layout
															)
															or (
																(
																	StadiumMountedDisplayItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumStringLightItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumSalvageCarItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumMasteryBannerItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumWaterfallItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					(
																						StadiumLightingKitItems
																						. is_family(
																							layout
																						)
																					)
																					or (
																						(
																							StadiumOutfieldPlazaItems
																							. is_family(
																								layout
																							)
																						)
																						or (
																							StadiumWaterfallLiveItems
																							. is_family(
																								layout
																							)
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		_source_owner.set_meta("receiver_layout", layout.duplicate(true))
		_source_owner.set_meta("boundary_layout", StadiumReceiverOwnedItems.base(layout))
		_source_owner.set_meta("boundary_stock", stock.to_data())
	elif StadiumBoundaryItems.is_family(layout):
		_source_owner.set_meta("boundary_layout", layout.duplicate(true))
		_source_owner.set_meta("boundary_stock", stock.to_data())
	if (
		StadiumLiveFurnishingItems.is_family(layout)
		or (
			StadiumSmallYardSceneryItems.is_family(layout)
			or (
				StadiumMoldedSeatItems.is_family(layout)
				or (
					StadiumGroundBoxItems.is_family(layout)
					or (
						StadiumPracticeFacilityItems.is_family(layout)
						or (
							StadiumTreehouseItems.is_family(layout)
							or (
								StadiumLandmarkItems.is_family(layout)
								or (
									StadiumOutfieldBleacherItems.is_family(layout)
									or (
										StadiumRisingAppleItems.is_family(layout)
										or (
											StadiumWallTopTerraceItems.is_family(layout)
											or (
												StadiumPlayerTunnelItems.is_family(layout)
												or (
													StadiumMountedDisplayItems.is_family(layout)
													or (
														StadiumStringLightItems.is_family(layout)
														or (
															StadiumSalvageCarItems.is_family(layout)
															or (
																StadiumMasteryBannerItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(layout)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(layout)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		_source_owner.set_meta("live_furnishing_layout", layout.duplicate(true))
	if (
		StadiumSalvageCarItems.is_family(layout)
		or (
			StadiumMasteryBannerItems.is_family(layout)
			or (
				StadiumWaterfallItems.is_family(layout)
				or (
					StadiumLightingKitItems.is_family(layout)
					or (
						StadiumOutfieldPlazaItems.is_family(layout)
						or StadiumWaterfallLiveItems.is_family(layout)
					)
				)
			)
		)
	):
		_source_owner.set_meta("salvage_car_layout", layout.duplicate(true))
	if StadiumWaterfallLiveItems.is_family(layout):
		_source_owner.set_meta("waterfall_live_layout", layout.duplicate(true))
	if not _source_owner._waterfall_animation_copies.is_empty():
		_source_owner._waterfall_animation = StadiumWaterfallAnimationLease.capture(
			_source_owner, _source_owner._waterfall_animation_copies
		)
		if _source_owner._waterfall_animation == null:
			return false
	return _source_owner.props_intact()


static func _source_private_appearance(_source_owner: StadiumPropertyGeometry, layout: \
	Dictionary, stock: StadiumStock) -> bool:
	if (
		StadiumReceiverOwnedItems.is_family(layout)
		or (
			StadiumFloodlightOwnedItems.is_family(layout)
			or (
				StadiumLandscapeOwnedItems.is_family(layout)
				or (
					StadiumLiveFurnishingItems.is_family(layout)
					or (
						StadiumSmallYardSceneryItems.is_family(layout)
						or (
							StadiumMoldedSeatItems.is_family(layout)
							or (
								StadiumGroundBoxItems.is_family(layout)
								or (
									StadiumPracticeFacilityItems.is_family(layout)
									or (
										StadiumTreehouseItems.is_family(layout)
										or (
											StadiumLandmarkItems.is_family(layout)
											or (
												StadiumOutfieldBleacherItems.is_family(layout)
												or (
													StadiumRisingAppleItems.is_family(layout)
													or (
														StadiumWallTopTerraceItems.is_family(layout)
														or (
															StadiumPlayerTunnelItems.is_family(
																layout
															)
															or (
																(
																	StadiumMountedDisplayItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumStringLightItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumSalvageCarItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumMasteryBannerItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumWaterfallItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					(
																						StadiumLightingKitItems
																						. is_family(
																							layout
																						)
																					)
																					or (
																						(
																							StadiumOutfieldPlazaItems
																							. is_family(
																								layout
																							)
																						)
																						or (
																							StadiumWaterfallLiveItems
																							. is_family(
																								layout
																							)
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		return _source_owner._appearance(StadiumReceiverOwnedItems.base(layout), stock)
	if StadiumBoundaryItems.is_family(layout):
		return _source_owner._appearance(StadiumBoundaryItems.base(layout), stock)
	if StadiumFacilityItems.is_family(layout):
		return _source_owner._appearance(StadiumFacilityItems.base(layout), stock)
	if StadiumRoofItems.is_family(layout):
		return _source_owner._appearance(StadiumRoofItems.base(layout), stock)
	if StadiumStraightItems.is_family(layout):
		return _source_owner._appearance(StadiumStraightItems.base(layout), stock)
	return _source_owner._apply_family_appearance(layout, stock)


static func _source_private_apply_family_appearance(_source_owner: StadiumPropertyGeometry, \
	layout: Dictionary, stock: StadiumStock) -> bool:
	if StadiumGroundPropsItems.is_family(layout):
		return _source_owner._appearance(StadiumGroundPropsItems.base(layout), stock)
	if SeasonOwnership._whole(
		layout.get("version"), StadiumFlagItems.LAYOUT_VERSION, StadiumFlagItems.LAYOUT_VERSION
	):
		var base: Dictionary = StadiumFlagItems.base(layout)
		return (
			StadiumSurfaceLayout.apply_terrain(_source_owner, base, stock)
			if StadiumFlagItems.is_terrain(layout)
			else (StadiumSurfaceLayout.apply(_source_owner, base, stock))
		)
	if SeasonOwnership._whole(
		layout.get("version"),
		StadiumSurfaceLayout.TERRAIN_VERSION,
		StadiumSurfaceLayout.TERRAIN_VERSION
	):
		return StadiumSurfaceLayout.apply_terrain(_source_owner, layout, stock)
	if layout.has("surface"):
		return StadiumSurfaceLayout.apply(_source_owner, layout, stock)
	if layout.has("ground"):
		return (
			StadiumWallItems.apply(_source_owner, layout, stock)
			if layout.has("walls")
			else (
				StadiumInfieldStyles.apply(_source_owner, layout, stock)
				if layout.has("bases")
				else (StadiumGroundModels.apply(_source_owner, layout.ground, layout.styles, stock))
			)
		)
	return _source_owner._apply_style_appearance(layout, stock)


static func _source_private_apply_style_appearance(_source_owner: StadiumPropertyGeometry, \
	layout: Dictionary, stock: StadiumStock) -> bool:
	if layout.has("styles"):
		return StadiumFieldStylePrototype.apply(_source_owner, layout.styles, stock)
	return true


static func _source_private_box(_source_owner: StadiumPropertyGeometry,
	id: String, center: Vector3, size: Vector3, color: Color, surface: StringName = &""
) -> Node3D:
	var root: Node3D = Node3D.new() if surface.is_empty() else StaticBody3D.new()
	root.name = id
	root.position = center
	if root is StaticBody3D:
		root.collision_layer = 1
		root.collision_mask = 2
		root.set_meta("ball_surface", surface)
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = size
		root.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	root.add_child(mesh)
	_source_owner.add_child(root)
	return root


static func _source_public_outer_ground_boxes(property_tier: String) -> Array[AABB]:
	var result: Array[AABB] = []
	if property_tier == "backyard" or not StadiumProperty.BOUNDS.has(property_tier):
		return result
	var outer: Rect2 = StadiumProperty.BOUNDS[property_tier]
	var inner: Rect2 = StadiumSurfaceTerrain.BOUNDS
	# Four disjoint rectangles exactly fill outer minus inner. Every shared edge is y=0.
	for rectangle: Rect2 in [
		Rect2(outer.position, Vector2(inner.position.x - outer.position.x, outer.size.y)),
		Rect2(
			Vector2(inner.end.x, outer.position.y), Vector2(outer.end.x - inner.end.x, outer.size.y)
		),
		Rect2(
			Vector2(inner.position.x, outer.position.y),
			Vector2(inner.size.x, inner.position.y - outer.position.y)
		),
		Rect2(
			Vector2(inner.position.x, inner.end.y), Vector2(inner.size.x, outer.end.y - inner.end.y)
		)
	]:
		result.append(
			AABB(
				Vector3(rectangle.position.x, -0.16, rectangle.position.y),
				Vector3(rectangle.size.x, 0.16, rectangle.size.y)
			)
		)
	return result


static func _source_public_restore_outer_ground(_source_owner: StadiumPropertyGeometry) -> bool:
	if (
		_source_owner.is_inside_tree()
		or not _source_owner._outer_ground.is_empty()
		or not _source_owner.has_node("OwnedSurfaceTerrain")
		or _source_owner.has_node("PropertyGround")
	):
		return false
	var boxes: Array[AABB] = StadiumPropertyGeometry.outer_ground_boxes(_source_owner.tier)
	for index in range(boxes.size()):
		var box: AABB = boxes[index]
		var piece: Node3D = _source_owner._box(
			"OuterPropertyGround%d" % index, box.get_center(), box.size, Color("315640"), &"ground"
		)
		_source_owner._outer_ground.append(piece)
		if not _source_owner._capture_infrastructure(piece):
			return false
	return _source_owner._infrastructure_intact()


static func _source_private_infrastructure_intact(_source_owner: StadiumPropertyGeometry) -> bool:
	if (
		_source_owner._lighting_preview != null
		and (
			not is_instance_valid(_source_owner._lighting_preview)
			or _source_owner._lighting_preview.get_script() != StadiumLightingKitPreviewRuntime
			or not _source_owner._lighting_preview.presentation_intact()
		)
	):
		return false
	return _source_owner._infrastructure_seals_intact()


static func _source_private_infrastructure_seals_intact(_source_owner: StadiumPropertyGeometry) \
	-> bool:
	for seal: Dictionary in _source_owner._infrastructure:
		if not is_instance_valid(seal.root) or seal.root.get_parent() != _source_owner:
			return false
		for row: Dictionary in seal.rows:
			var node: Node = row.node
			if (
				not is_instance_valid(node)
				or node.is_queued_for_deletion()
				or node.get_script() != null
				or node.get_parent() != row.parent
				or node.name != row.name
				or node.get_children() != row.children
				or node.get_meta_list().size() != row.metadata.size()
			):
				return false
			for index in range(row.fields.size()):
				if (
					node.get(row.fields[index]) != row.values[index]
					and not (
						_source_owner._lighting_preview != null
						and _source_owner._lighting_preview.allows_change(
							node, row.fields[index], row.values[index], node.get(row.fields[index])
						)
					)
				):
					return false
			for key: StringName in row.metadata:
				if not node.has_meta(key) or node.get_meta(key) != row.metadata[key]:
					return false
		if not _source_owner._infrastructure_resources_intact(seal):
			return false
	return true


static func _source_private_infrastructure_resources_intact(_source_owner: \
	StadiumPropertyGeometry, seal: Dictionary) -> bool:
	for row: Dictionary in seal.resources:
		var resource: Resource = row.resource
		if not is_instance_valid(resource):
			return false
		if row.has("kit_surface_texture"):
			var texture_seal: StadiumKitSurfaceTextureSeal = (
				row.kit_surface_texture as StadiumKitSurfaceTextureSeal
			)
			if (
				texture_seal == null
				or texture_seal.get_script() != StadiumKitSurfaceTextureSeal
				or not texture_seal.intact(_source_owner)
			):
				return false
		if row.has("metadata"):
			if resource.get_meta_list().size() != row.metadata.size():
				return false
			for key: StringName in row.metadata:
				if not resource.has_meta(key) or resource.get_meta(key) != row.metadata[key]:
					return false
		for index in range(row.keys.size()):
			if resource.get(row.keys[index]) != row.values[index]:
				return false
	return true


static func _source_public_bind_ball(_source_owner: StadiumPropertyGeometry, ball: \
	BattedBallBody, resolver: BallPlayResolver) -> void:
	if _source_owner._ground_props_family:
		if (
			not _source_owner.props_intact()
			or not is_instance_valid(ball)
			or resolver == null
			or resolver.state == null
		):
			return
		_source_owner._props_ball = weakref(ball)
		_source_owner._props_play = resolver.state
		_source_owner._props_resolver = resolver
		_source_owner._props_world = _source_owner.global_transform
		_source_owner._props_ball_parent = ball.get_parent()
	var callback: Callable = _source_owner._ball_contact.bind(ball, resolver)
	if not ball.body_entered.is_connected(callback):
		ball.body_entered.connect(callback)


static func _source_private_ball_contact(_source_owner: StadiumPropertyGeometry, body: Node, \
	ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	if (
		body.get_meta("stadium_item", "") == "ST-005"
		or StadiumLiveFurnishingItems.PRICES.has(body.get_meta("stadium_item", ""))
	):
		return  # Exact native manifold/sweep dispatch is owned by the current boundary flight.
	_source_owner._apply_ball_contact(body, ball, resolver, Vector3.INF)


static func _source_private_receiver_native_contact(_source_owner: StadiumPropertyGeometry,
	body: Node, ball: BattedBallBody, resolver: BallPlayResolver, physical_position: Vector3
) -> void:
	if (
		not _source_owner.has_meta("receiver_layout")
		or body.get_meta("surface_role", "") != "RECEIVER_CONTAINMENT_FOUL"
	):
		return
	_source_owner._apply_ball_contact(body, ball, resolver, physical_position)


static func _source_private_apply_ball_contact(_source_owner: StadiumPropertyGeometry,
	body: Node, ball: BattedBallBody, resolver: BallPlayResolver, physical_position: Vector3
) -> void:
	if body.get_meta("boundary_owned", false):
		return
	if (
		_source_owner._ground_props_family
		and (
			not _source_owner.props_intact()
			or _source_owner._props_ball == null
			or _source_owner._props_ball.get_ref() != ball
			or resolver != _source_owner._props_resolver
			or resolver.state != _source_owner._props_play
			or ball.get_parent() != _source_owner._props_ball_parent
			or _source_owner.global_transform != _source_owner._props_world
			or not _source_owner._issued_contacts.has(body)
		)
	):
		return
	if not _source_owner.is_ancestor_of(body) or not body.has_meta("owned_copy"):
		return
	var owned_receiver: bool = (
		_source_owner.has_meta("receiver_layout")
		and body.get_meta("surface_role", "") == "RECEIVER_CONTAINMENT_FOUL"
	)
	# The native contact point precedes bounce integration; body_entered only has
	# the later ball center and cannot supply receiver report provenance.
	if owned_receiver and not physical_position.is_finite():
		return
	var point: Vector3 = physical_position if owned_receiver else ball.global_position
	var applied: bool = StadiumSurfaceRules.apply(
		resolver,
		body.get_meta("surface_role", ""),
		body.get_meta("owned_copy", ""),
		point,
		body.get_meta("surface_id", "")
	)
	var receiver: StadiumPitchReceiver = _source_owner.get_node_or_null("PitchReceiverPresentation")
	if (
		applied
		and receiver != null
		and body.get_meta("surface_role", "") == "RECEIVER_CONTAINMENT_FOUL"
	):
		receiver.present_contact(
			{
				"copy": body.get_meta("owned_copy"),
				"surface": body.get_meta("surface_id"),
				"position": point,
				"elapsed": resolver.state.elapsed_seconds
			},
			"batted"
		)


static func _source_public_route_obstacles(_source_owner: StadiumPropertyGeometry) -> \
	Array[Dictionary]:
	return _source_owner._route_obstacles(_source_owner.objects)


static func _source_private_route_obstacles(_unused_source_owner: StadiumPropertyGeometry, \
	models: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for copy: String in models:
		var model: Node3D = models[copy]
		var item: String = model.get_meta("stadium_item")
		if item in ["ST-046", "ST-067", "ST-111", "ST-112"]:
			continue  # Historical display only, never a defender detour.
		if (
			StadiumSmallYardSceneryItems.ITEMS.has(item)
			and String(model.get_meta("site", "")).begins_with("YS-")
		):
			continue  # Exact yard scenery has no collision, route detour or live result surface.
		if item == "ST-005":
			var bounds: AABB = model.global_transform * StadiumJunkCarModels.reservation(item)
			result.append(
				{
					"center": bounds.get_center(),
					"radius":
					(
						Vector2(bounds.size.x, bounds.size.z).length() / 2
						+ StadiumDefenderRoutes.BODY_RADIUS
					),
					"copy": copy
				}
			)
			continue
		if StadiumLiveFurnishingItems.PRICES.has(item):
			if model.get_node("Collision").get_child_count() > 0:
				var bounds: AABB = (
					model.global_transform
					* (
						StadiumLiveFurnishingModels.reservation(item)
						if item == "ST-007"
						else StadiumLiveFurnishingModels.envelope(item)
					)
				)
				result.append(
					{
						"center": bounds.get_center(),
						"radius":
						(
							Vector2(bounds.size.x, bounds.size.z).length() / 2
							+ StadiumDefenderRoutes.BODY_RADIUS
						),
						"copy": copy
					}
				)
			continue
		if (
			(
				item
				in [
					"ST-036",
					"ST-045",
					"ST-047",
					"ST-048",
					"ST-049",
					"ST-050",
					"ST-051",
					"ST-052",
					"ST-054",
					"ST-058",
					"ST-060",
					"ST-061",
					"ST-068",
					"ST-069",
					"ST-070",
					"ST-087"
				]
			)
			or StadiumLandscapeOwnedItems.PRICES.has(item)
			or StadiumFloodlightOwnedItems.PRICES.has(item)
			or StadiumReceiverOwnedItems.PRICES.has(item)
			or StadiumBoundaryItems.PRICES.has(item)
			or StadiumFacilityItems.PRICES.has(item)
			or StadiumRoofItems.PRICES.has(item)
			or StadiumStraightItems.HOSTS.has(item)
			or StadiumStraightItems.MOUNTS.has(item)
			or StadiumGroundPropsItems.PLANTS.has(item)
			or item == "ST-043"
			or StadiumPurchases.SEATING.has(item)
			or StadiumPurchases.DISPLAYS.has(item)
			or StadiumPurchases.BLEACHERS.has(item)
			or StadiumPurchases.LIGHTS.has(item)
		):
			continue
		if StadiumGroundPropsItems.LIVE.has(item):
			var box: AABB = model.global_transform * StadiumGroundPropsModels.envelope(item)
			result.append(
				{
					"center": box.get_center(),
					"radius":
					(
						Vector2(box.size.x, box.size.z).length() / 2
						+ StadiumDefenderRoutes.BODY_RADIUS
					),
					"copy": copy
				}
			)
			continue
		if item in ["ST-026", "ST-025"]:
			var bounds: AABB = (
				model.global_transform
				* (
					StadiumNetModels.ENVELOPE
					if (item == "ST-025")
					else StadiumTargetModels.ENVELOPE
				)
			)
			result.append(
				{
					"center": bounds.get_center(),
					"radius":
					(
						Vector2(bounds.size.x, bounds.size.z).length() / 2
						+ StadiumDefenderRoutes.BODY_RADIUS
					),
					"copy": copy
				}
			)
			continue
		var half: Vector2 = {
			"ST-001": Vector2(0.175, 0.175),
			"ST-003": Vector2(0.35, 0.40),
			"ST-079": Vector2(0.30, 0.43)
		}[item]
		result.append(
			{
				"center": model.global_position,
				"radius": half.length() + StadiumDefenderRoutes.BODY_RADIUS,
				"copy": copy
			}
		)
	return result


static func _source_private_prop_bodies(_unused_source_owner: StadiumPropertyGeometry, model: \
	Node3D) -> Array:
	if (
		model.get_meta("stadium_item", "") == "ST-112"
		or (
			model.get_meta("stadium_item", "") == "ST-046"
			and model.get_meta("site", "") != StadiumWaterfallLiveSites.SITE
		)
	):
		return []
	var bodies: Array = model.get_node("Collision").get_children()
	if model.get_meta("stadium_item", "") == "ST-047":
		bodies.append_array(model.get_node("RisingAssembly/Collision").get_children())
	return bodies
