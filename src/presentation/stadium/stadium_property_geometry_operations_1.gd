extends RefCounted
## Stateless operations for the original StadiumPropertyGeometry owner.


static func _source_public_construction_target_allowed(target: Node) -> bool:
	var node: Node = target
	while is_instance_valid(node):
		if (
			node.get_script()
			== load("res://src/presentation/stadium/stadium_waterfall_animation_property.gd")
		):
			return not bool(node.get("_context_attached"))
		if node.get_script() == load("res://src/presentation/stadium/stadium_low_wall_property.gd"):
			return not bool(node.get("_low_attached"))
		if (
			node.get_script() == StadiumPropertyGeometry
			and (node as StadiumPropertyGeometry)._lighting_fixture_sealed
		):
			return false  # Exact issued candidate3 property: authoring requires a new installation.
		if (
			node.get_script()
			== load("res://src/presentation/stadium/stadium_pool_owned_property.gd")
		):
			return not bool(node.get("_field_installation_sealed"))
		node = node.get_parent()
	return true


static func _source_public_build(_source_owner: StadiumPropertyGeometry, property_tier: String, \
	layout: Dictionary, stock: StadiumStock) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(_source_owner):
		return false
	if _source_owner.get_child_count() != 0 or not StadiumProperty.BOUNDS.has(property_tier):
		return false
	var terrain: bool = SeasonOwnership._whole(
		layout.get("version"),
		StadiumSurfaceLayout.TERRAIN_VERSION,
		StadiumSurfaceLayout.TERRAIN_VERSION
	)
	var checked: Dictionary = (
		StadiumSurfaceLayout.validate_terrain(layout, stock, property_tier)
		if terrain
		else StadiumHomeLayout.validate(layout, stock, property_tier)
	)
	if not checked.ok:
		return false
	for placement: Dictionary in checked.placements:
		if not StadiumProperty.contains(property_tier, StadiumHomeLayout.bounds(placement)):
			return false
	return _source_owner._build_property_families(property_tier, layout, stock, terrain, checked)


static func _source_private_build_property_families(_source_owner: StadiumPropertyGeometry,
	property_tier: String,
	layout: Dictionary,
	stock: StadiumStock,
	terrain: bool,
	checked: Dictionary
) -> bool:
	_source_owner._ground_props_family = (
		StadiumGroundPropsItems.is_family(layout)
		or StadiumStraightItems.is_family(layout)
		or StadiumRoofItems.is_family(layout)
		or StadiumFacilityItems.is_family(layout)
		or (
			StadiumBoundaryItems.is_family(layout)
			or (
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
														StadiumOutfieldBleacherItems.is_family(
															layout
														)
														or (
															StadiumRisingAppleItems.is_family(
																layout
															)
															or (
																(
																	StadiumWallTopTerraceItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumPlayerTunnelItems
																		. is_family(layout)
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
																					. is_family(
																						layout
																					)
																				)
																				or (
																					(
																						StadiumMasteryBannerItems
																						. is_family(
																							layout
																						)
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
			)
		)
	)
	_source_owner.tier = property_tier
	if (
		StadiumPlayerTunnelItems.is_family(layout)
		or (
			StadiumMountedDisplayItems.is_family(layout)
			or (
				StadiumStringLightItems.is_family(layout)
				or (
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
				)
			)
		)
	):
		_source_owner.set_meta(
			"player_tunnel_layout",
			(
				StadiumMountedDisplayItems.base(layout)
				if (
					StadiumMountedDisplayItems.is_family(layout)
					or (
						StadiumStringLightItems.is_family(layout)
						or (
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
						)
					)
				)
				else layout.duplicate(true)
			)
		)
	_source_owner.set_meta(
		"property_signature",
		(
			StadiumSurfaceLayout.terrain_geometry(_source_owner.tier, layout)
			if terrain
			else StadiumHomeLayout.geometry(_source_owner.tier, layout)
		)
	)
	_source_owner.field = ContentDB.get_field(PitchBatLab.FIELD_ID).duplicate(true)
	var ground: AABB = StadiumProperty.ground_bounds(_source_owner.tier)
	_source_owner._box("PropertyGround", ground.get_center(), ground.size, Color("315640"), &"ground")
	_source_owner._box(
		"TemplateBackWall",
		Vector3(0, _source_owner.field.home_run_height_m / 2, _source_owner.field.back_wall_z_m + 0.25),
		Vector3(StadiumProperty.reference_wall_width(_source_owner.field), \
			_source_owner.field.home_run_height_m, 0.5),
		Color("547079"),
		&"back_wall"
	)
	_source_owner._box("Plate", Vector3(0, 0.025, 0), Vector3(0.70, 0.05, 0.45), Color("e7e1cf"))
	_source_owner._box(
		"Mound",
		PitchBatLab.MOUND_ORIGIN + Vector3(0, 0.025, 0),
		Vector3(0.8, 0.05, 0.8),
		Color("927553")
	)
	for band: Array in [
		["Safe", _source_owner.field.safe_hit_z_m, Color("e4ca66")], ["Deep", \
			_source_owner.field.deep_air_z_m, Color("70c0c3")]
	]:
		var half: float = float(band[1]) * tan(deg_to_rad(_source_owner.field.fair_half_angle_degrees))
		_source_owner._box(band[0], Vector3(0, 0.016, band[1]), Vector3(half * 2, 0.025, 0.08), band[2])
	for side: int in [-1, 1]:
		var end: Vector3 = Vector3(
			side * _source_owner.field.back_wall_z_m * \
				tan(deg_to_rad(_source_owner.field.fair_half_angle_degrees)),
			0,
			_source_owner.field.back_wall_z_m
		)
		var line: Node3D = _source_owner._box(
			"FoulLine" + str(side),
			end / 2 + Vector3(0, 0.02, 0),
			Vector3(0.055, 0.025, end.length()),
			Color("d8ded0")
		)
		line.rotation.y = atan2(end.x, end.z)
	var bounds: Rect2 = StadiumProperty.BOUNDS[_source_owner.tier]
	for edge: Array in [
		[
			Vector3(bounds.position.x, 0.02, bounds.get_center().y),
			Vector3(0.08, 0.02, bounds.size.y)
		],
		[Vector3(bounds.end.x, 0.02, bounds.get_center().y), Vector3(0.08, 0.02, bounds.size.y)],
		[Vector3(0, 0.02, bounds.position.y), Vector3(bounds.size.x, 0.02, 0.08)],
		[Vector3(0, 0.02, bounds.end.y), Vector3(bounds.size.x, 0.02, 0.08)]
	]:
		_source_owner._box("LandEdge", edge[0], edge[1], Color("84a67e"))
	for placement: Dictionary in checked.placements:
		if StadiumBoundaryItems.PRICES.has(placement.item):
			continue  # The complete boundary owns its models and sealed contact issuance.
		var decorative: bool = placement.role == "DECORATIVE_AFTER_TERMINAL"
		var model: Node3D
		if placement.item == "ST-112":
			model = StadiumOutfieldPlazaModels.create(placement.recipe)
		elif placement.item == "ST-111":
			model = StadiumLightingKitModels.create(placement.item, placement)
		elif placement.item == "ST-046":
			model = (
				StadiumWaterfallAnimatedModels.create(
					placement.site == StadiumWaterfallLiveSites.SITE and not decorative
				)
				if _source_owner._waterfall_animation_copies.has(placement.copy)
				else (
					StadiumWaterfallLiveModels.create()
					if placement.site == StadiumWaterfallLiveSites.SITE and not decorative
					else StadiumWaterfallModels.create()
				)
			)
		elif placement.item == "ST-067":
			model = StadiumMasteryBannerModels.create(placement.earned)
		elif placement.item == "ST-005":
			model = StadiumJunkCarModels.create(placement.item, not decorative)
		elif placement.item in StadiumStringLightItems.ITEMS:
			model = StadiumStringLightModels.create(placement.item, placement)
		elif placement.item in StadiumMountedDisplayItems.ITEMS:
			model = StadiumMountedDisplayModels.create(placement.item, placement)
		elif placement.item == "ST-058":
			model = StadiumPlayerTunnelModels.create(placement.item, placement)
		elif placement.item == "ST-087":
			model = StadiumWallTopTerraceModels.create(placement.item, placement.host_item)
		elif placement.item == "ST-047":
			model = StadiumRisingAppleModels.create(placement.item)
		elif placement.item == "ST-054":
			model = StadiumOutfieldBleacherModels.create(placement.item)
		elif placement.item in ["ST-048", "ST-049", "ST-050"]:
			model = StadiumLandmarkModels.create(placement.item)
		elif placement.item == "ST-045":
			model = StadiumTreehouseModels.create(placement.item)
		elif placement.item in ["ST-060", "ST-061"]:
			model = StadiumPracticeFacilityModels.create(placement.item)
		elif placement.item == "ST-052":
			model = StadiumGroundBoxModels.create(placement.item)
		elif placement.item == "ST-051":
			model = StadiumMoldedSeatModels.create(placement.item)
		elif (
			StadiumSmallYardSceneryItems.ITEMS.has(placement.item)
			and placement.site.begins_with("YS-")
		):
			model = StadiumSmallYardSceneryModels.create(placement.item)
		elif StadiumLiveFurnishingItems.PRICES.has(placement.item):
			model = StadiumLiveFurnishingModels.create(placement.item, not decorative)
		elif StadiumLandscapeOwnedItems.PRICES.has(placement.item):
			model = StadiumLandscapeModels.create(placement.item)
		elif StadiumFloodlightOwnedItems.PRICES.has(placement.item):
			model = StadiumFloodlightOwnedModels.create(placement.item, placement)
		elif StadiumFacilityItems.PRICES.has(placement.item):
			model = StadiumFacilityOwnedModels.create(placement.item)
		elif StadiumRoofItems.PRICES.has(placement.item):
			model = StadiumRoofOwnedModels.create(
				placement.item, placement.get("roof_state", "lower")
			)
		elif (
			StadiumStraightItems.HOSTS.has(placement.item)
			or StadiumStraightItems.MOUNTS.has(placement.item)
		):
			model = StadiumStraightOwnedModels.create(placement.item, placement.get("earned", {}))
		elif StadiumGroundPropsItems.PRICES.has(placement.item):
			model = StadiumGroundPropsModels.create(placement.item)
		elif placement.item == "ST-043":
			model = StadiumFlagModels.create()
		elif placement.item == "ST-037":
			model = StadiumYardLightModels.create()
		elif StadiumReceiverOwnedItems.PRICES.has(placement.item):
			model = StadiumReceiverOwnedModels.create(placement.item, placement)
		elif placement.item == "ST-025":
			model = StadiumNetModels.create()
		elif placement.item == "ST-026":
			model = StadiumTargetModels.create()
		elif StadiumPurchases.BLEACHERS.has(placement.item):
			model = StadiumBleacherModels.create(placement.item)
		elif StadiumPurchases.DISPLAYS.has(placement.item):
			model = StadiumClubModels.create(placement.item)
		else:
			model = (
				StadiumSeatingModels.create(placement.item)
				if decorative
				else StadiumStarterModels.create(placement.item)
			)
		if model == null:
			return false
		if placement.item == "ST-111" and not StadiumLightingKitModels.valid(model):
			model.free()
			return false
		if (
			StadiumFloodlightOwnedItems.is_family(layout)
			and placement.item in ["ST-029", "ST-053"]
			and not StadiumFloodlightOwnedModels.intern_source_materials(model, placement.item)
		):
			model.free()
			return false
		if _source_owner._ground_props_family:
			model.name = "Owned_" + String(placement.copy).sha256_text()
		model.position = placement.position
		model.rotation.y = deg_to_rad(float(placement.yaw))
		model.set_meta("owned_copy", placement.copy)
		model.set_meta("site", placement.site)
		if (
			placement.item == "ST-029"
			and (
				StadiumPlayerTunnelItems.is_family(layout)
				or (
					StadiumMountedDisplayItems.is_family(layout)
					or (
						StadiumStringLightItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		):
			var tunnel_host: Dictionary = StadiumPlayerTunnelHostAdapters.binding(
				(
					StadiumMountedDisplayItems.base(layout)
					if (
						StadiumMountedDisplayItems.is_family(layout)
						or (
							StadiumStringLightItems.is_family(layout)
							or (
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
							)
						)
					)
					else layout
				),
				placement.copy,
				"lower"
			)
			if (
				not tunnel_host.is_empty()
				and not StadiumPlayerTunnelHostAdapters.apply_stand(model, tunnel_host)
			):
				model.free()
				return false
		if placement.item == "ST-087":
			model.set_meta("terrace_host_item", placement.host_item)
			model.set_meta("terrace_host_copies", placement.host_copies.duplicate())
		for dependency: String in [
			"lower",
			"concourse",
			"upper",
			"bowl",
			"curved",
			"base",
			"straight",
			"host",
			"support",
			"socket",
			"dugout"
		]:
			if placement.has(dependency):
				model.set_meta(
					dependency + "_copy" if dependency != "socket" else dependency,
					placement[dependency]
				)
		if placement.has("roof_state"):
			model.set_meta("roof_state", placement.roof_state)
		_source_owner.add_child(model)
		if placement.item == "ST-037":
			StadiumYardLightModels.place(model, placement.site)
		_source_owner.objects[placement.copy] = model
		for body: StaticBody3D in _source_owner._prop_bodies(model):
			body.set_meta("owned_copy", placement.copy)
			if StadiumFloodlightOwnedItems.PRICES.has(placement.item):
				continue  # Towers stay decorative after terminal; no ball-result surface metadata.
			body.set_meta(
				"ball_surface",
				(
					&"stadium_receiver"
					if (placement.role == "RECEIVER_CONTAINMENT_FOUL")
					else &"stadium_scenery" if decorative else &"stadium_live_object"
				)
			)
			if (
				(
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
															StadiumOutfieldBleacherItems.is_family(
																layout
															)
															or (
																StadiumRisingAppleItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumWallTopTerraceItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumPlayerTunnelItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumMountedDisplayItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumStringLightItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					(
																						StadiumSalvageCarItems
																						. is_family(
																							layout
																						)
																					)
																					or (
																						(
																							StadiumMasteryBannerItems
																							. is_family(
																								layout
																							)
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
				)
				and placement.role == "RECEIVER_CONTAINMENT_FOUL"
			):
				body.collision_layer |= StadiumPitchReceiver.LAYER
		if _source_owner._ground_props_family:
			_source_owner._capture_prop(model, placement)
		if (
			placement.item in ["ST-036", "ST-047", "ST-069", "ST-067", "ST-046", "ST-111", "ST-112"]
			and not _source_owner._capture_infrastructure(model)
		):
			return false
	return _source_owner._build_property_models(layout, stock)
