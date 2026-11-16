extends RefCounted
## Stateless operations for the original StadiumLayoutSnapshot script.


static func _public_terrain_normalized(value: Dictionary) -> Dictionary:
	if not StadiumLayoutSnapshot.terrain_valid(value):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = int(value.version)
	result.revision = int(value.revision)
	result.layout.version = int(value.layout.version)
	if (
		StadiumGroundBoxItems.is_family(result.layout)
		or (
			StadiumPracticeFacilityItems.is_family(result.layout)
			or (
				StadiumTreehouseItems.is_family(result.layout)
				or (
					StadiumLandmarkItems.is_family(result.layout)
					or (
						StadiumOutfieldBleacherItems.is_family(result.layout)
						or (
							StadiumRisingAppleItems.is_family(result.layout)
							or (
								StadiumWallTopTerraceItems.is_family(result.layout)
								or (
									StadiumPlayerTunnelItems.is_family(result.layout)
									or (
										StadiumMountedDisplayItems.is_family(result.layout)
										or (
											StadiumStringLightItems.is_family(result.layout)
											or (
												StadiumSalvageCarItems.is_family(result.layout)
												or (
													StadiumMasteryBannerItems.is_family(
														result.layout
													)
													or (
														StadiumWaterfallItems.is_family(
															result.layout
														)
														or (
															StadiumLightingKitItems.is_family(
																result.layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	result.layout
																)
																or (
																	StadiumWaterfallLiveItems
																	. is_family(result.layout)
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
		result.layout.ground_box_base_version = int(value.layout.ground_box_base_version)
	if (
		StadiumFlagItems.is_family(result.layout)
		or (
			StadiumGroundPropsItems.is_family(result.layout)
			or (
				StadiumStraightItems.is_family(result.layout)
				or (
					StadiumRoofItems.is_family(result.layout)
					or (
						StadiumFacilityItems.is_family(result.layout)
						or (
							StadiumBoundaryItems.is_family(result.layout)
							or (
								StadiumReceiverOwnedItems.is_family(result.layout)
								or (
									StadiumFloodlightOwnedItems.is_family(result.layout)
									or (
										StadiumLandscapeOwnedItems.is_family(result.layout)
										or (
											StadiumLiveFurnishingItems.is_family(result.layout)
											or (
												StadiumSmallYardSceneryItems.is_family(
													result.layout
												)
												or (
													StadiumMoldedSeatItems.is_family(result.layout)
													or (
														StadiumGroundBoxItems.is_family(
															result.layout
														)
														or (
															StadiumPracticeFacilityItems.is_family(
																result.layout
															)
															or (
																StadiumTreehouseItems.is_family(
																	result.layout
																)
																or (
																	StadiumLandmarkItems.is_family(
																		result.layout
																	)
																	or (
																		(
																			StadiumOutfieldBleacherItems
																			. is_family(
																				result.layout
																			)
																		)
																		or (
																			(
																				StadiumRisingAppleItems
																				. is_family(
																					result.layout
																				)
																			)
																			or (
																				(
																					StadiumWallTopTerraceItems
																					. is_family(
																						(
																							result
																							. layout
																						)
																					)
																				)
																				or (
																					(
																						StadiumPlayerTunnelItems
																						. is_family(
																							(
																								result
																								. layout
																							)
																						)
																					)
																					or (
																						(
																							StadiumMountedDisplayItems
																							. is_family(
																								(
																									result
																									. layout
																								)
																							)
																						)
																						or (
																							(
																								StadiumStringLightItems
																								. is_family(
																									(
																										result
																										. layout
																									)
																								)
																							)
																							or (
																								(
																									StadiumSalvageCarItems
																									. is_family(
																										(
																											result
																											. layout
																										)
																									)
																								)
																								or (
																									(
																										StadiumMasteryBannerItems
																										. is_family(
																											(
																												result
																												. layout
																											)
																										)
																									)
																									or (
																										(
																											StadiumWaterfallItems
																											. is_family(
																												(
																													result
																													. layout
																												)
																											)
																										)
																										or (
																											(
																												StadiumLightingKitItems
																												. is_family(
																													(
																														result
																														. layout
																													)
																												)
																											)
																											or (
																												(
																													StadiumOutfieldPlazaItems
																													. is_family(
																														(
																															result
																															. layout
																														)
																													)
																												)
																												or (
																													StadiumWaterfallLiveItems
																													. is_family(
																														(
																															result
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
						)
					)
				)
			)
		)
	):
		result.layout.base_version = int(value.layout.base_version)
	if (
		StadiumSmallYardSceneryItems.is_family(result.layout)
		or (
			StadiumMoldedSeatItems.is_family(result.layout)
			or (
				StadiumGroundBoxItems.is_family(result.layout)
				or (
					StadiumPracticeFacilityItems.is_family(result.layout)
					or (
						StadiumTreehouseItems.is_family(result.layout)
						or (
							StadiumLandmarkItems.is_family(result.layout)
							or (
								StadiumOutfieldBleacherItems.is_family(result.layout)
								or (
									StadiumRisingAppleItems.is_family(result.layout)
									or (
										StadiumWallTopTerraceItems.is_family(result.layout)
										or (
											StadiumPlayerTunnelItems.is_family(result.layout)
											or (
												StadiumMountedDisplayItems.is_family(result.layout)
												or (
													StadiumStringLightItems.is_family(result.layout)
													or (
														StadiumSalvageCarItems.is_family(
															result.layout
														)
														or (
															StadiumMasteryBannerItems.is_family(
																result.layout
															)
															or (
																StadiumWaterfallItems.is_family(
																	result.layout
																)
																or (
																	(
																		StadiumLightingKitItems
																		. is_family(result.layout)
																	)
																	or (
																		(
																			StadiumOutfieldPlazaItems
																			. is_family(
																				result.layout
																			)
																		)
																		or (
																			StadiumWaterfallLiveItems
																			. is_family(
																				result.layout
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
		for row: Dictionary in result.layout.yard_scenery:
			row.yaw = int(row.yaw)
	if (
		StadiumLiveFurnishingItems.is_family(result.layout)
		or (
			StadiumSmallYardSceneryItems.is_family(result.layout)
			or (
				StadiumMoldedSeatItems.is_family(result.layout)
				or (
					StadiumGroundBoxItems.is_family(result.layout)
					or (
						StadiumPracticeFacilityItems.is_family(result.layout)
						or (
							StadiumTreehouseItems.is_family(result.layout)
							or (
								StadiumLandmarkItems.is_family(result.layout)
								or (
									StadiumOutfieldBleacherItems.is_family(result.layout)
									or (
										StadiumRisingAppleItems.is_family(result.layout)
										or (
											StadiumWallTopTerraceItems.is_family(result.layout)
											or (
												StadiumPlayerTunnelItems.is_family(result.layout)
												or (
													StadiumMountedDisplayItems.is_family(
														result.layout
													)
													or (
														StadiumStringLightItems.is_family(
															result.layout
														)
														or (
															StadiumSalvageCarItems.is_family(
																result.layout
															)
															or (
																StadiumMasteryBannerItems.is_family(
																	result.layout
																)
																or (
																	StadiumWaterfallItems.is_family(
																		result.layout
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(
																				result.layout
																			)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(
																					result.layout
																				)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(
																					result.layout
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
		for row: Dictionary in result.layout.live_furnishings:
			row.yaw = int(row.yaw)
	if (
		StadiumLandscapeOwnedItems.is_family(result.layout)
		or (
			StadiumLiveFurnishingItems.is_family(result.layout)
			or (
				StadiumSmallYardSceneryItems.is_family(result.layout)
				or (
					StadiumMoldedSeatItems.is_family(result.layout)
					or (
						StadiumGroundBoxItems.is_family(result.layout)
						or (
							StadiumPracticeFacilityItems.is_family(result.layout)
							or (
								StadiumTreehouseItems.is_family(result.layout)
								or (
									StadiumLandmarkItems.is_family(result.layout)
									or (
										StadiumOutfieldBleacherItems.is_family(result.layout)
										or (
											StadiumRisingAppleItems.is_family(result.layout)
											or (
												StadiumWallTopTerraceItems.is_family(result.layout)
												or (
													StadiumPlayerTunnelItems.is_family(
														result.layout
													)
													or (
														StadiumMountedDisplayItems.is_family(
															result.layout
														)
														or (
															StadiumStringLightItems.is_family(
																result.layout
															)
															or (
																StadiumSalvageCarItems.is_family(
																	result.layout
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(result.layout)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(
																				result.layout
																			)
																		)
																		or (
																			(
																				StadiumLightingKitItems
																				. is_family(
																					result.layout
																				)
																			)
																			or (
																				(
																					StadiumOutfieldPlazaItems
																					. is_family(
																						(
																							result
																							. layout
																						)
																					)
																				)
																				or (
																					StadiumWaterfallLiveItems
																					. is_family(
																						(
																							result
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
	):
		for row: Dictionary in result.layout.landscape:
			row.yaw = int(row.yaw)
	result.inventory = StadiumStock.from_data(value.inventory).to_data()
	for copy: Dictionary in result.inventory.copies.values():
		copy.paid = int(copy.paid)
		# Stock2/3 retain earned dictionaries verbatim; canonical snapshots use
		# their historical JSON-cold counters without changing raw stock authority.
		if result.inventory.version < StadiumStock.MASTERY_VERSION and copy.has("earned"):
			for field: String in ["version", "season_id", "season_number"]:
				copy.earned[field] = float(copy.earned[field])
			copy.earned.era.version = float(copy.earned.era.version)
	result.terrain = StadiumLayoutSnapshot._terrain_contract(result.layout)
	if result.version == StadiumLayoutSnapshot.TERRAIN_FIXTURE_VERSION:
		for key_value: String in ["version", "seed", "fixture"]:
			result.environment[key_value] = int(result.environment[key_value])
	return result


static func _public_terrain_entry(value: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumLayoutSnapshot.terrain_normalized(value)
	if not result.is_empty():
		result.version = StadiumLayoutSnapshot.TERRAIN_VERSION
		result.erase("environment")
	return result


static func _public_terrain_fixture(value: Dictionary, seed: int, fixture: int) -> Dictionary:
	if (
		value.get("version") != StadiumLayoutSnapshot.TERRAIN_VERSION
		or seed < 0
		or seed > 2147483647
		or fixture < 0
		or fixture > 32
	):
		return {}
	var result: Dictionary = StadiumLayoutSnapshot.terrain_normalized(value)
	if result.is_empty():
		return {}
	result.version = StadiumLayoutSnapshot.TERRAIN_FIXTURE_VERSION
	result["environment"] = {
		"version": 1, "seed": seed, "fixture": fixture, "mode": "day", "profile": ""
	}
	return result


static func _terrain_layout_valid(layout: Dictionary, stock: StadiumStock, tier: String) -> bool:
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
		return (
			StadiumHomeLayout
			. terrain_admission(
				layout, tier, StadiumReceiverOwnedItems.validate(layout, stock, tier)
			)
			. ok
		)
	if StadiumBoundaryItems.is_family(layout):
		return (
			StadiumHomeLayout
			. terrain_admission(layout, tier, StadiumBoundaryItems.validate(layout, stock, tier))
			. ok
		)
	if StadiumFacilityItems.is_family(layout):
		return (
			StadiumHomeLayout
			. terrain_admission(layout, tier, StadiumFacilityItems.validate(layout, stock, tier))
			. ok
		)
	if StadiumRoofItems.is_family(layout):
		return (
			StadiumHomeLayout
			. terrain_admission(layout, tier, StadiumRoofItems.validate(layout, stock, tier))
			. ok
		)
	if StadiumStraightItems.is_family(layout):
		return (
			StadiumHomeLayout
			. terrain_admission(layout, tier, StadiumStraightItems.validate(layout, stock, tier))
			. ok
		)
	if StadiumGroundPropsItems.is_family(layout) or StadiumStraightItems.is_family(layout):
		return (
			StadiumHomeLayout
			. terrain_admission(layout, tier, StadiumGroundPropsItems.validate(layout, stock, tier))
			. ok
		)
	var checked: Dictionary = (
		StadiumFlagItems.validate(layout, stock, tier)
		if StadiumFlagItems.is_terrain(layout)
		else StadiumSurfaceLayout.validate_terrain(layout, stock, tier)
	)
	return StadiumHomeLayout.terrain_admission(layout, tier, checked).ok


static func _terrain_contract(layout: Dictionary) -> Dictionary:
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
		return StadiumReceiverOwnedItems.terrain_contract(layout)
	if StadiumBoundaryItems.is_family(layout):
		return StadiumBoundaryItems.terrain_contract(layout)
	if StadiumFacilityItems.is_family(layout):
		return StadiumFacilityItems.terrain_contract(layout)
	if StadiumRoofItems.is_family(layout):
		return StadiumRoofItems.terrain_contract(layout)
	if StadiumStraightItems.is_family(layout):
		return StadiumStraightItems.terrain_contract(layout)
	if StadiumGroundPropsItems.is_family(layout) or StadiumStraightItems.is_family(layout):
		return StadiumGroundPropsItems.terrain_contract(layout)
	return (
		StadiumFlagItems.terrain_contract(layout)
		if StadiumFlagItems.is_family(layout)
		else StadiumSurfaceLayout.terrain_contract(layout)
	)
