extends RefCounted
## Stateless operations for the original StadiumLayoutSnapshot script.


static func _public_capture(ledger: ClubAssetLedger, complete_boundary: bool = true) -> Dictionary:
	if ledger == null:
		return {}
	if StadiumWaterfallAnimationLayout.is_family(ledger.view().stadium_active):
		return StadiumWaterfallAnimationSnapshot.capture(ledger) if complete_boundary else {}
	if StadiumLowWallLayout.is_family(ledger.view().stadium_active):
		return StadiumLowWallSnapshot.capture(ledger) if complete_boundary else {}
	var owned: StadiumStock = ledger.construction()
	var tier: String = ledger.view().land
	var version: int = (
		(3 if tier == "backyard" else 4)
		if complete_boundary
		else 1 if owned.copies.size() == 3 else 2
	)
	var layout: Dictionary = ledger.view().stadium_active
	if (
		SeasonOwnership._whole(layout.get("version"), 17, 17)
		or StadiumFlagItems.is_terrain(layout)
		or (
			StadiumGroundPropsItems.is_terrain(layout)
			or (
				StadiumStraightItems.is_terrain(layout)
				or (
					StadiumRoofItems.is_terrain(layout)
					or (
						StadiumFacilityItems.is_terrain(layout)
						or (
							StadiumBoundaryItems.is_terrain(layout)
							or (
								StadiumReceiverOwnedItems.is_terrain(layout)
								or (
									StadiumFloodlightOwnedItems.is_terrain(layout)
									or (
										StadiumLandscapeOwnedItems.is_terrain(layout)
										or (
											StadiumLiveFurnishingItems.is_terrain(layout)
											or (
												StadiumSmallYardSceneryItems.is_terrain(layout)
												or (
													StadiumMoldedSeatItems.is_terrain(layout)
													or (
														StadiumGroundBoxItems.is_terrain(layout)
														or (
															StadiumPracticeFacilityItems.is_terrain(
																layout
															)
															or (
																StadiumTreehouseItems.is_terrain(
																	layout
																)
																or (
																	StadiumLandmarkItems.is_terrain(
																		layout
																	)
																	or (
																		(
																			StadiumOutfieldBleacherItems
																			. is_terrain(layout)
																		)
																		or (
																			(
																				StadiumRisingAppleItems
																				. is_terrain(layout)
																			)
																			or (
																				(
																					StadiumWallTopTerraceItems
																					. is_terrain(
																						layout
																					)
																				)
																				or (
																					(
																						StadiumPlayerTunnelItems
																						. is_terrain(
																							layout
																						)
																					)
																					or (
																						(
																							StadiumMountedDisplayItems
																							. is_terrain(
																								layout
																							)
																						)
																						or (
																							(
																								StadiumStringLightItems
																								. is_terrain(
																									layout
																								)
																							)
																							or (
																								(
																									StadiumSalvageCarItems
																									. is_terrain(
																										layout
																									)
																								)
																								or (
																									(
																										StadiumMasteryBannerItems
																										. is_terrain(
																											layout
																										)
																									)
																									or (
																										(
																											StadiumWaterfallItems
																											. is_terrain(
																												layout
																											)
																										)
																										or (
																											(
																												StadiumLightingKitItems
																												. is_terrain(
																													layout
																												)
																											)
																											or (
																												(
																													StadiumOutfieldPlazaItems
																													. is_terrain(
																														layout
																													)
																												)
																												or (
																													StadiumWaterfallLiveItems
																													. is_terrain(
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
				)
			)
		)
	):
		return StadiumLayoutSnapshot.terrain_capture(ledger) if complete_boundary else {}
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return StadiumPoolOwnedSnapshot.capture(ledger) if complete_boundary else {}
	if SeasonOwnership._whole(layout.get("version"), 15, 15):
		return (
			StadiumMountedScoreboardSnapshot.capture(ledger)
			if (complete_boundary and StadiumMountedScoreboardLayout.RUNTIME_READY)
			else {}
		)
	if SeasonOwnership._whole(layout.get("version"), 14, 14):
		return (
			StadiumScoreboardSnapshot.capture(ledger)
			if (complete_boundary and StadiumScoreboardLayout.RUNTIME_READY)
			else {}
		)
	if (
		SeasonOwnership._whole(layout.get("version"), 12, 12)
		or StadiumFlagItems.is_family(layout)
		or (
			StadiumGroundPropsItems.is_family(layout)
			or (
				StadiumStraightItems.is_family(layout)
				or (
					StadiumRoofItems.is_family(layout)
					or (
						StadiumFacilityItems.is_family(layout)
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
															StadiumPracticeFacilityItems.is_family(
																layout
															)
															or (
																StadiumTreehouseItems.is_family(
																	layout
																)
																or (
																	StadiumLandmarkItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumOutfieldBleacherItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumRisingAppleItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumWallTopTerraceItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					(
																						StadiumPlayerTunnelItems
																						. is_family(
																							layout
																						)
																					)
																					or (
																						(
																							StadiumMountedDisplayItems
																							. is_family(
																								layout
																							)
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
						)
					)
				)
			)
		)
	):
		version = 8
		if not StadiumSurfaceLayout.RUNTIME_READY:
			return {}
	if SeasonOwnership._whole(layout.get("version"), 11, 11):
		version = 6
	if SeasonOwnership._whole(layout.get("version"), 11, 11) and not StadiumWallItems.RUNTIME_READY:
		return {}
	if (
		not complete_boundary
		and (tier != "backyard" or SeasonOwnership._whole(layout.get("version"), 2, 12))
	):
		return {}
	var result: Dictionary = {
		"version": version,
		"tier": tier,
		"geometry": StadiumHomeLayout.geometry(tier, layout),
		"revision": ledger.revision(),
		"layout": ledger.view().stadium_active.duplicate(true)
	}
	if result.version >= 2:
		result["inventory"] = owned.to_data()
	if version == 8:
		result["surface_access"] = ledger.surface_owned()
	if complete_boundary:
		result["boundary"] = StadiumOwnedLayout.boundary_signature(layout)
	return (
		StadiumLayoutSnapshot.normalized(result)
		if StadiumLayoutSnapshot.valid(result, owned)
		else {}
	)
