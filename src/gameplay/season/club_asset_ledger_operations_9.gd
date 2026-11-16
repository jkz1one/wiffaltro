extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_ac02_passive_13_prefix(_source_owner: ClubAssetLedger, length: int) \
	-> ClubAssetLedger:
	if length < 0 or length > _source_owner.revision():
		return null
	var data: Dictionary = _source_owner.to_data()
	data.events = data.events.slice(0, length)
	if SeasonOwnership._whole(data.version, ClubAssetLedger.TERRAIN_VERSION, \
		ClubAssetLedger.WATERFALL_ANIMATION_VERSION):
		var terrain_seen: bool = ClubAssetLedger._has_terrain_events(data.events)
		var flags_seen: bool = ClubAssetLedger._has_flag_events(data.events)
		var props_seen: bool = ClubAssetLedger._has_ground_props_events(data.events)
		var straight_seen: bool = ClubAssetLedger._has_straight_events(data.events)
		var pennants_seen: bool = ClubAssetLedger._has_pennant_events(data.events)
		var roofs_seen: bool = ClubAssetLedger._has_roof_events(data.events)
		var facilities_seen: bool = ClubAssetLedger._has_facility_events(data.events)
		var boundaries_seen: bool = ClubAssetLedger._has_boundary_events(data.events)
		var receivers_seen: bool = ClubAssetLedger._has_receiver_events(data.events)
		var floodlights_seen: bool = ClubAssetLedger._has_floodlight_events(data.events)
		var landscape_seen: bool = ClubAssetLedger._has_landscape_events(data.events)
		var live_furnishings_seen: bool = ClubAssetLedger._has_live_furnishing_events(data.events)
		var yard_scenery_seen: bool = ClubAssetLedger._has_small_yard_scenery_events(data.events)
		var molded_seats_seen: bool = ClubAssetLedger._has_molded_seat_events(data.events)
		var ground_boxes_seen: bool = ClubAssetLedger._has_ground_box_events(data.events)
		var practice_facilities_seen: bool = ClubAssetLedger._has_practice_facility_events(data.events)
		var treehouses_seen: bool = ClubAssetLedger._has_treehouse_events(data.events)
		var landmarks_seen: bool = ClubAssetLedger._has_landmark_events(data.events)
		var outfield_bleachers_seen: bool = ClubAssetLedger._has_outfield_bleacher_events(data.events)
		var rising_apple_seen: bool = ClubAssetLedger._has_rising_apple_events(data.events)
		var wall_top_terrace_seen: bool = ClubAssetLedger._has_wall_top_terrace_events(data.events)
		var player_tunnels_seen: bool = ClubAssetLedger._has_player_tunnel_events(data.events)
		var mounted_displays_seen: bool = ClubAssetLedger._has_mounted_display_events(data.events)
		var string_lights_seen: bool = ClubAssetLedger._has_string_light_events(data.events)
		var salvage_seen: bool = not _source_owner._salvage_origin.is_empty() or \
			ClubAssetLedger._has_salvage_events(data.events)
		var mastery_seen: bool = ClubAssetLedger._has_mastery_events(data.events)
		var plaques_seen: bool = ClubAssetLedger._has_plaque_events(data.events)
		var waterfalls_seen: bool = ClubAssetLedger._has_waterfall_events(data.events)
		var lighting_kits_seen: bool = ClubAssetLedger._has_lighting_kit_events(data.events)
		var plazas_seen: bool = ClubAssetLedger._has_outfield_plaza_events(data.events)
		var live_waterfalls_seen: bool = ClubAssetLedger._has_live_waterfall_events(data.events)
		var low_walls_seen: bool = ClubAssetLedger._has_low_wall_events(data.events)
		if not low_walls_seen:
			data.erase("low_wall_catalog")
		var animation_seen: bool = ClubAssetLedger._has_waterfall_animation_events(data.events)
		if not animation_seen:
			data.erase("waterfall_animation_catalog")
		data.version = (
			ClubAssetLedger.WATERFALL_ANIMATION_VERSION
			if animation_seen
			else (
				ClubAssetLedger.LOW_WALL_VERSION
				if low_walls_seen
				else (
					ClubAssetLedger.LIVE_WATERFALL_VERSION
					if live_waterfalls_seen
					else (
						ClubAssetLedger.OUTFIELD_PLAZA_VERSION
						if plazas_seen
						else (
							ClubAssetLedger.LIGHTING_KIT_VERSION
							if lighting_kits_seen
							else (
								ClubAssetLedger.WATERFALL_VERSION
								if waterfalls_seen
								else (
									ClubAssetLedger.PLAQUE_VERSION
									if plaques_seen
									else (
										ClubAssetLedger.MASTERY_VERSION
										if mastery_seen
										else (
											ClubAssetLedger.SALVAGE_VERSION
											if salvage_seen
											else (
												ClubAssetLedger.STRING_LIGHT_VERSION
												if string_lights_seen
												else (
													ClubAssetLedger.MOUNTED_DISPLAY_VERSION
													if mounted_displays_seen
													else (
														ClubAssetLedger.PLAYER_TUNNEL_VERSION
														if player_tunnels_seen
														else (
															ClubAssetLedger.WALL_TOP_TERRACE_VERSION
															if wall_top_terrace_seen
															else (
																ClubAssetLedger.RISING_APPLE_VERSION
																if rising_apple_seen
																else (
																	ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
																	if outfield_bleachers_seen
																	else (
																		ClubAssetLedger.LANDMARK_VERSION
																		if landmarks_seen
																		else (
																			ClubAssetLedger.TREEHOUSE_VERSION
																			if treehouses_seen
																			else (
																				ClubAssetLedger.PRACTICE_FACILITY_VERSION
																				if practice_facilities_seen
																				else (
																					ClubAssetLedger.GROUND_BOX_VERSION
																					if ground_boxes_seen
																					else (
																						ClubAssetLedger.MOLDED_SEAT_VERSION
																						if molded_seats_seen
																						else (
																							ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
																							if yard_scenery_seen
																							else (
																								ClubAssetLedger.LIVE_FURNISHING_VERSION
																								if live_furnishings_seen
																								else (
																									ClubAssetLedger.LANDSCAPE_VERSION
																									if landscape_seen
																									else (
																										ClubAssetLedger.FLOODLIGHT_VERSION
																										if floodlights_seen
																										else (
																											ClubAssetLedger.RECEIVER_VERSION
																											if receivers_seen
																											else (
																												ClubAssetLedger.BOUNDARY_VERSION
																												if boundaries_seen
																												else (
																													ClubAssetLedger.FACILITY_VERSION
																													if facilities_seen
																													else (
																														ClubAssetLedger.ROOF_VERSION
																														if roofs_seen
																														else (
																															ClubAssetLedger.PENNANT_VERSION
																															if pennants_seen
																															else (
																																ClubAssetLedger.STRAIGHT_VERSION
																																if straight_seen
																																else (
																																	ClubAssetLedger.GROUND_PROPS_VERSION
																																	if props_seen
																																	else (
																																		ClubAssetLedger.FLAG_VERSION
																																		if flags_seen
																																		else (
																																			ClubAssetLedger.TERRAIN_VERSION
																																			if terrain_seen
																																			else ClubAssetLedger.VERSION
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
									)
								)
							)
						)
					)
				)
			)
		)
		if not live_waterfalls_seen:
			data.erase("live_waterfall_layout_catalog")
		if not plazas_seen:
			data.erase("outfield_plaza_catalog")
			data.erase("outfield_plaza_layout_catalog")
		if not lighting_kits_seen:
			data.erase("lighting_kit_catalog")
			data.erase("lighting_kit_layout_catalog")
		if not waterfalls_seen:
			data.erase("waterfall_catalog")
			data.erase("waterfall_layout_catalog")
		if not plaques_seen:
			data.erase("plaque_catalog")
		if not mastery_seen:
			data.erase("mastery_catalog")
		if not ClubAssetLedger._has_mastery_layout_events(data.events):
			data.erase("mastery_layout_catalog")
		if not salvage_seen:
			for key: String in [
				"salvage_origin",
				"salvage_origin_catalog",
				"salvage_catalog",
				"salvage_layout_catalog"
			]:
				data.erase(key)
		if not string_lights_seen:
			data.erase("string_light_catalog")
			data.erase("string_light_layout_catalog")
		if not mounted_displays_seen:
			data.erase("mounted_display_catalog")
			data.erase("mounted_display_layout_catalog")
		if not player_tunnels_seen:
			data.erase("player_tunnel_catalog")
			data.erase("player_tunnel_layout_catalog")
		if not wall_top_terrace_seen:
			data.erase("wall_top_terrace_catalog")
			data.erase("wall_top_terrace_layout_catalog")
		if not rising_apple_seen:
			data.erase("rising_apple_catalog")
			data.erase("rising_apple_layout_catalog")
		if not outfield_bleachers_seen:
			data.erase("outfield_bleacher_catalog")
			data.erase("outfield_bleacher_layout_catalog")
		if not landmarks_seen:
			data.erase("landmark_catalog")
			data.erase("landmark_layout_catalog")
		if not treehouses_seen:
			data.erase("treehouse_catalog")
			data.erase("treehouse_layout_catalog")
		if not practice_facilities_seen:
			data.erase("practice_facility_catalog")
			data.erase("practice_facility_layout_catalog")
		if not ground_boxes_seen:
			data.erase("ground_box_catalog")
			data.erase("ground_box_layout_catalog")
		if not molded_seats_seen:
			data.erase("molded_seat_catalog")
			data.erase("molded_seat_layout_catalog")
		if not yard_scenery_seen:
			data.erase("yard_scenery_layout_catalog")
		if not live_furnishings_seen:
			data.erase("live_furnishing_catalog")
			data.erase("live_furnishing_layout_catalog")
		if not landscape_seen:
			data.erase("landscape_catalog")
			data.erase("landscape_layout_catalog")
		if not floodlights_seen:
			data.erase("floodlight_catalog")
			data.erase("floodlight_layout_catalog")
		if not receivers_seen:
			data.erase("receiver_catalog")
			data.erase("receiver_layout_catalog")
		if not boundaries_seen:
			data.erase("boundary_catalog")
			data.erase("boundary_layout_catalog")
		if not facilities_seen:
			data.erase("facility_catalog")
			data.erase("facility_layout_catalog")
		if not roofs_seen:
			data.erase("roof_catalog")
			data.erase("roof_layout_catalog")
		if not straight_seen:
			data.erase("straight_catalog")
			data.erase("straight_layout_catalog")
		if not pennants_seen:
			data.erase("pennant_catalog")
		if not props_seen:
			data.erase("ground_props_catalog")
			data.erase("ground_props_layout_catalog")
		if not terrain_seen:
			data.erase("terrain_catalog")
			data.erase("leveled_terrain_catalog")
		if not flags_seen:
			data.erase("flag_catalog")
			data.erase("flag_layout_catalog")
	return ClubAssetLedger.from_data(data, _source_owner._seed, _source_owner._credits, \
		_source_owner._progress, _source_owner._championships)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_income(_source_owner: ClubAssetLedger, through: int) -> int:
	return ClubAssetLedger.Journal.income(_source_owner._credits, through)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_error(message: String) -> Dictionary:
	return {"ok": false, "replayed": false, "error": message}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_flag_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and event.get("price_version") == StadiumFlagItems.PRICE_VERSION
				)
				or StadiumFlagItems.is_family(event.get("layout"))
				or StadiumGroundPropsItems.is_family(event.get("layout"))
				or StadiumStraightItems.is_family(event.get("layout"))
				or StadiumRoofItems.is_family(event.get("layout"))
				or StadiumFacilityItems.is_family(event.get("layout"))
				or (
					StadiumBoundaryItems.is_family(event.get("layout"))
					or (
						StadiumReceiverOwnedItems.is_family(event.get("layout"))
						or (
							StadiumFloodlightOwnedItems.is_family(event.get("layout"))
							or (
								StadiumLandscapeOwnedItems.is_family(event.get("layout"))
								or (
									StadiumLiveFurnishingItems.is_family(event.get("layout"))
									or (
										StadiumSmallYardSceneryItems.is_family(event.get("layout"))
										or (
											StadiumMoldedSeatItems.is_family(event.get("layout"))
											or (
												StadiumGroundBoxItems.is_family(event.get("layout"))
												or (
													StadiumPracticeFacilityItems.is_family(
														event.get("layout")
													)
													or (
														StadiumTreehouseItems.is_family(
															event.get("layout")
														)
														or (
															StadiumLandmarkItems.is_family(
																event.get("layout")
															)
															or (
																(
																	StadiumOutfieldBleacherItems
																	. is_family(event.get("layout"))
																)
																or (
																	(
																		StadiumRisingAppleItems
																		. is_family(
																			event.get("layout")
																		)
																	)
																	or (
																		(
																			StadiumWallTopTerraceItems
																			. is_family(
																				event.get("layout")
																			)
																		)
																		or (
																			(
																				StadiumPlayerTunnelItems
																				. is_family(
																					event.get(
																						"layout"
																					)
																				)
																			)
																			or (
																				(
																					StadiumMountedDisplayItems
																					. is_family(
																						event.get(
																							"layout"
																						)
																					)
																				)
																				or (
																					(
																						StadiumStringLightItems
																						. is_family(
																							(
																								event
																								. get(
																									"layout"
																								)
																							)
																						)
																					)
																					or (
																						(
																							StadiumSalvageCarItems
																							. is_family(
																								(
																									event
																									. get(
																										"layout"
																									)
																								)
																							)
																						)
																						or (
																							(
																								StadiumMasteryBannerItems
																								. is_family(
																									(
																										event
																										. get(
																											"layout"
																										)
																									)
																								)
																							)
																							or (
																								(
																									StadiumWaterfallItems
																									. is_family(
																										(
																											event
																											. get(
																												"layout"
																											)
																										)
																									)
																								)
																								or (
																									StadiumLightingKitItems
																									. is_family(
																										(
																											event
																											. get(
																												"layout"
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_terrain_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and event.get("layout") is Dictionary
			and (
				event.layout.get("version") == 17
				or (
					StadiumFlagItems.is_family(event.layout)
					and StadiumFlagItems.is_terrain(event.layout)
				)
				or (
					StadiumGroundPropsItems.is_family(event.layout)
					and StadiumGroundPropsItems.is_terrain(event.layout)
				)
				or (
					StadiumStraightItems.is_family(event.layout)
					and StadiumStraightItems.is_terrain(event.layout)
				)
				or (
					StadiumRoofItems.is_family(event.layout)
					and StadiumRoofItems.is_terrain(event.layout)
				)
				or (
					StadiumFacilityItems.is_family(event.layout)
					and StadiumFacilityItems.is_terrain(event.layout)
				)
				or (
					(
						StadiumBoundaryItems.is_family(event.layout)
						and StadiumBoundaryItems.is_terrain(event.layout)
					)
					or (
						(
							StadiumReceiverOwnedItems.is_family(event.layout)
							and StadiumReceiverOwnedItems.is_terrain(event.layout)
						)
						or (
							(
								StadiumFloodlightOwnedItems.is_family(event.layout)
								and StadiumFloodlightOwnedItems.is_terrain(event.layout)
							)
							or (
								(
									StadiumLandscapeOwnedItems.is_family(event.layout)
									and StadiumLandscapeOwnedItems.is_terrain(event.layout)
								)
								or (
									(
										StadiumLiveFurnishingItems.is_family(event.layout)
										and StadiumLiveFurnishingItems.is_terrain(event.layout)
									)
									or (
										(
											StadiumSmallYardSceneryItems.is_family(event.layout)
											and StadiumSmallYardSceneryItems.is_terrain(
												event.layout
											)
										)
										or (
											(
												StadiumMoldedSeatItems.is_family(event.layout)
												and StadiumMoldedSeatItems.is_terrain(event.layout)
											)
											or (
												(
													StadiumGroundBoxItems.is_family(event.layout)
													and StadiumGroundBoxItems.is_terrain(
														event.layout
													)
												)
												or (
													(
														StadiumPracticeFacilityItems.is_family(
															event.layout
														)
														and StadiumPracticeFacilityItems.is_terrain(
															event.layout
														)
													)
													or (
														(
															StadiumTreehouseItems.is_family(
																event.layout
															)
															and StadiumTreehouseItems.is_terrain(
																event.layout
															)
														)
														or (
															(
																StadiumLandmarkItems.is_family(
																	event.layout
																)
																and StadiumLandmarkItems.is_terrain(
																	event.layout
																)
															)
															or (
																(
																	(
																		StadiumOutfieldBleacherItems
																		. is_family(event.layout)
																	)
																	and (
																		StadiumOutfieldBleacherItems
																		. is_terrain(event.layout)
																	)
																)
																or (
																	(
																		(
																			StadiumRisingAppleItems
																			. is_family(
																				event.layout
																			)
																		)
																		and (
																			StadiumRisingAppleItems
																			. is_terrain(
																				event.layout
																			)
																		)
																	)
																	or (
																		(
																			(
																				StadiumWallTopTerraceItems
																				. is_family(
																					event.layout
																				)
																			)
																			and (
																				StadiumWallTopTerraceItems
																				. is_terrain(
																					event.layout
																				)
																			)
																		)
																		or (
																			(
																				(
																					StadiumPlayerTunnelItems
																					. is_family(
																						event.layout
																					)
																				)
																				or (
																					(
																						StadiumMountedDisplayItems
																						. is_family(
																							(
																								event
																								. layout
																							)
																						)
																					)
																					or (
																						(
																							StadiumStringLightItems
																							. is_family(
																								(
																									event
																									. layout
																								)
																							)
																						)
																						or (
																							(
																								StadiumSalvageCarItems
																								. is_family(
																									(
																										event
																										. layout
																									)
																								)
																							)
																							or (
																								(
																									StadiumMasteryBannerItems
																									. is_family(
																										(
																											event
																											. layout
																										)
																									)
																								)
																								or (
																									StadiumWaterfallItems
																									. is_family(
																										(
																											event
																											. layout
																										)
																									)
																								)
																							)
																						)
																					)
																				)
																			)
																			and (
																				(
																					StadiumPlayerTunnelItems
																					. is_terrain(
																						event.layout
																					)
																				)
																				or (
																					(
																						StadiumMountedDisplayItems
																						. is_terrain(
																							(
																								event
																								. layout
																							)
																						)
																					)
																					or (
																						(
																							StadiumStringLightItems
																							. is_terrain(
																								(
																									event
																									. layout
																								)
																							)
																						)
																						or (
																							(
																								StadiumSalvageCarItems
																								. is_terrain(
																									(
																										event
																										. layout
																									)
																								)
																							)
																							or (
																								(
																									StadiumMasteryBannerItems
																									. is_terrain(
																										(
																											event
																											. layout
																										)
																									)
																								)
																								or (
																									StadiumWaterfallItems
																									. is_terrain(
																										(
																											event
																											. layout
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
		):
			return true
	return false
# gdlint: enable=max-returns
