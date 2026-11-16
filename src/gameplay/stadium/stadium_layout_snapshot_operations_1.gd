extends RefCounted
## Stateless operations for the original StadiumLayoutSnapshot script.


static func _public_normalized(value: Dictionary) -> Dictionary:
	if StadiumWaterfallAnimationSnapshot.is_family(value):
		return StadiumWaterfallAnimationSnapshot.normalized(value)
	if StadiumLowWallSnapshot.is_family(value):
		return StadiumLowWallSnapshot.normalized(value)
	if StadiumLayoutSnapshot.is_terrain(value):
		return StadiumLayoutSnapshot.terrain_normalized(value)
	if StadiumSurfaceNightSnapshot.is_family(value):
		return StadiumSurfaceNightSnapshot.normalized(value)
	if StadiumNpcSnapshot.is_public(value):
		return StadiumNpcSnapshot.normalized(value)
	if StadiumLayoutSnapshot._pool(value):
		return StadiumPoolOwnedSnapshot.normalized(value)
	if StadiumLayoutSnapshot._mounted(value):
		return (
			StadiumMountedScoreboardSnapshot.normalized(value)
			if (StadiumMountedScoreboardLayout.RUNTIME_READY)
			else {}
		)
	if StadiumLayoutSnapshot._scoreboards(value):
		return (
			StadiumScoreboardSnapshot.normalized(value)
			if (StadiumScoreboardLayout.RUNTIME_READY)
			else {}
		)
	if not StadiumLayoutSnapshot.valid(value):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = int(result.version)
	result.revision = int(result.revision)
	result.layout.version = int(result.layout.version)
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
		result.layout.ground_box_base_version = int(result.layout.ground_box_base_version)
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
		result.layout.base_version = int(result.layout.base_version)
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
	if result.version >= 2:
		result.inventory = StadiumLayoutSnapshot.ownership(value).to_data()
		for copy: Dictionary in result.inventory.copies.values():
			copy.paid = int(copy.paid)
			# Stock2/3 retain legacy receipt bytes; detached snapshot identity uses
			# their historical JSON-cold counters, preserving existing cold hashes.
			if result.inventory.version < StadiumStock.MASTERY_VERSION and copy.has("earned"):
				for field: String in ["version", "season_id", "season_number"]:
					copy.earned[field] = float(copy.earned[field])
				copy.earned.era.version = float(copy.earned.era.version)
	for row: Dictionary in result.layout.obstacles:
		row.yaw = int(row.yaw)
	if result.version in [5, 7, 9]:
		for field: String in ["version", "seed", "fixture"]:
			result.environment[field] = int(result.environment[field])
	return result
