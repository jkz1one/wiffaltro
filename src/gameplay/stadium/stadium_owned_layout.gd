class_name StadiumOwnedLayout
extends RefCounted
## Explicit complete ownership context. Old layout validators and signatures stay unchanged.


static func validate(
	layout: Variant,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	access: Array[String],
	tier: String,
	boards: StadiumScoreboardOwnership = null
) -> Dictionary:
	if StadiumWaterfallAnimationLayout.is_family(layout):
		return StadiumWaterfallAnimationLayout.validate(layout, stock, pieces, access, tier, boards)
	if StadiumLowWallLayout.is_family(layout):
		return StadiumLowWallLayout.validate(layout, stock, pieces, access, tier)
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
		var checked: Dictionary = StadiumReceiverOwnedItems.validate(layout, stock, tier)
		checked = StadiumHomeLayout.terrain_admission(layout, tier, checked)
		return (
			checked
			if not checked.ok or StadiumSurfaceLayout.owned(layout, access)
			else (StadiumStarterLayout._error(
				"The selected boundary field preparation is not owned."
			))
		)
	if StadiumBoundaryItems.is_family(layout):
		var checked: Dictionary = StadiumBoundaryItems.validate(layout, stock, tier)
		checked = StadiumHomeLayout.terrain_admission(layout, tier, checked)
		return (
			checked
			if not checked.ok or StadiumSurfaceLayout.owned(layout, access)
			else (StadiumStarterLayout._error(
				"The selected boundary field preparation is not owned."
			))
		)
	if StadiumFacilityItems.is_family(layout):
		var checked: Dictionary = StadiumFacilityItems.validate(layout, stock, tier)
		checked = StadiumHomeLayout.terrain_admission(layout, tier, checked)
		return (
			checked
			if not checked.ok or StadiumSurfaceLayout.owned(layout, access)
			else (StadiumStarterLayout._error(
				"The selected facility field preparation is not owned."
			))
		)
	if StadiumRoofItems.is_family(layout):
		var checked: Dictionary = StadiumRoofItems.validate(layout, stock, tier)
		checked = StadiumHomeLayout.terrain_admission(layout, tier, checked)
		return (
			checked
			if not checked.ok or StadiumSurfaceLayout.owned(layout, access)
			else (StadiumStarterLayout._error("The selected roof field preparation is not owned."))
		)
	if StadiumStraightItems.is_family(layout):
		var checked: Dictionary = StadiumStraightItems.validate(layout, stock, tier)
		checked = StadiumHomeLayout.terrain_admission(layout, tier, checked)
		return (
			checked
			if not checked.ok or StadiumSurfaceLayout.owned(layout, access)
			else (StadiumStarterLayout._error(
				"The selected straight-host field preparation is not owned."
			))
		)
	if StadiumGroundPropsItems.is_family(layout):
		var checked: Dictionary = StadiumGroundPropsItems.validate(layout, stock, tier)
		checked = StadiumHomeLayout.terrain_admission(layout, tier, checked)
		return (
			checked
			if not checked.ok or StadiumSurfaceLayout.owned(layout, access)
			else (StadiumStarterLayout._error(
				"The selected ground-prop field preparation is not owned."
			))
		)
	if StadiumFlagItems.is_family(layout):
		var checked: Dictionary = StadiumFlagItems.validate(layout, stock, tier)
		checked = StadiumHomeLayout.terrain_admission(layout, tier, checked)
		return (
			checked
			if not checked.ok or StadiumSurfaceLayout.owned(layout, access)
			else (StadiumStarterLayout._error("The selected flag field preparation is not owned."))
		)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 17, 17):
		var checked: Dictionary = StadiumSurfaceLayout.validate_terrain(layout, stock, tier)
		checked = StadiumHomeLayout.terrain_admission(layout, tier, checked)
		return (
			checked
			if not checked.ok or StadiumSurfaceLayout.owned(layout, access)
			else (StadiumStarterLayout._error("The selected terrain preparation is not owned."))
		)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 16, 16):
		return StadiumPoolOwnedLayout.validate(layout, stock, access, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 15, 15):
		return StadiumMountedScoreboardLayout.validate(layout, stock, pieces, access, tier, boards)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 14, 14):
		return StadiumScoreboardLayout.validate(layout, stock, pieces, boards, access, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 13, 13):
		return StadiumAdvancedWallLayout.validate(layout, stock, pieces, tier, access)
	return StadiumHomeLayout.validate(layout, stock, tier)


static func preview(
	before: Dictionary,
	after: Dictionary,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	access: Array[String],
	tier: String,
	boards: StadiumScoreboardOwnership = null
) -> Dictionary:
	if (
		SeasonOwnership._whole(before.get("version"), 15, 15)
		or SeasonOwnership._whole(after.get("version"), 15, 15)
	):
		return StadiumMountedScoreboardLayout.preview(
			before, after, stock, pieces, access, tier, boards
		)
	if not _complete_ownership(stock, pieces, boards):
		return StadiumStarterLayout._error("Explicit complete construction ownership is required.")
	var old: Dictionary = _preview_layout(before, stock, pieces, access, tier, boards)
	var next: Dictionary = _preview_layout(after, stock, pieces, access, tier, boards)
	if not old.ok or not next.ok:
		return StadiumStarterLayout._error(old.error if not old.ok else next.error)
	var displaced: Array[String] = []
	var moved: Array[String] = []
	var active: Dictionary = {}
	for row: Dictionary in _physical_rows(next):
		active[row.copy] = row
	for row: Dictionary in _physical_rows(old):
		if not active.has(row.copy):
			displaced.append(row.copy)
		elif not ClubCareer.same(row, active[row.copy]):
			moved.append(row.copy)
	displaced.sort()
	moved.sort()
	return {
		"ok": true,
		"error": "",
		"cost": 0,
		"stored": next.stored.duplicate(),
		"pieces_stored": next.pieces_stored.duplicate(),
		"scoreboards_stored": next.scoreboards_stored.duplicate(),
		"displaced": displaced,
		"moved": moved,
		"placement": next
	}


static func _complete_ownership(
	stock: StadiumStock, pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership
) -> bool:
	return (
		stock != null
		and pieces != null
		and pieces.stock != null
		and boards != null
		and StadiumStock.from_data(stock.to_data()) != null
		and (
			StadiumWallPieceOwnership.from_data(
				pieces.to_data(), stock.capacity_count() + boards.copies.size()
			)
			!= null
		)
		and (
			StadiumScoreboardOwnership.from_data(
				boards.to_data(), stock.capacity_count() + pieces.stock.copies.size()
			)
			!= null
		)
	)


static func _preview_layout(
	layout: Dictionary,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	access: Array[String],
	tier: String,
	boards: StadiumScoreboardOwnership
) -> Dictionary:
	var checked: Dictionary = validate(layout, stock, pieces, access, tier, boards)
	if not checked.ok:
		return checked
	if (
		SeasonOwnership._whole(layout.get("version"), 12, 14)
		and not StadiumSurfaceLayout.owned(layout, access)
	):
		return StadiumStarterLayout._error("This surface selection is not owned.")
	for channel: String in ["wall_panels", "advanced_panels", "board_placements"]:
		if not checked.has(channel):
			checked[channel] = []
	if not checked.has("pieces_stored"):
		checked["pieces_stored"] = pieces.stock.copies.keys()
		checked.pieces_stored.sort()
	if not checked.has("scoreboards_stored"):
		checked["scoreboards_stored"] = boards.copies.keys()
		checked.scoreboards_stored.sort()
	return checked


static func _physical_rows(checked: Dictionary) -> Array:
	return (
		checked.placements
		+ checked.wall_panels
		+ checked.advanced_panels
		+ checked.board_placements
		+ checked.get("low_panels", [])
	)


static func geometry(tier: String, layout: Dictionary) -> String:
	if StadiumWaterfallAnimationLayout.is_family(layout):
		return StadiumWaterfallAnimationLayout.geometry(tier, layout)
	if StadiumLowWallLayout.is_family(layout):
		return StadiumLowWallLayout.geometry(tier, layout)
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
		return StadiumReceiverOwnedItems.geometry(tier, layout)
	if StadiumBoundaryItems.is_family(layout):
		return StadiumBoundaryItems.geometry(tier, layout)
	if StadiumFacilityItems.is_family(layout):
		return StadiumFacilityItems.geometry(tier, layout)
	if StadiumRoofItems.is_family(layout):
		return StadiumRoofItems.geometry(tier, layout)
	if StadiumStraightItems.is_family(layout):
		return StadiumStraightItems.geometry(tier, layout)
	if StadiumGroundPropsItems.is_family(layout):
		return StadiumGroundPropsItems.geometry(tier, layout)
	if StadiumFlagItems.is_family(layout):
		return StadiumFlagItems.geometry(tier, layout)
	if SeasonOwnership._whole(layout.get("version"), 17, 17):
		return StadiumSurfaceLayout.terrain_geometry(tier, layout)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return StadiumPoolOwnedLayout.geometry(tier, layout)
	if SeasonOwnership._whole(layout.get("version"), 15, 15):
		return StadiumMountedScoreboardLayout.geometry(tier, layout)
	if SeasonOwnership._whole(layout.get("version"), 14, 14):
		return StadiumScoreboardLayout.geometry(tier)
	return (
		StadiumAdvancedWallLayout.geometry(tier)
		if SeasonOwnership._whole(layout.get("version"), 13, 13)
		else StadiumHomeLayout.geometry(tier, layout)
	)


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	if StadiumWaterfallAnimationLayout.is_family(layout):
		return StadiumWaterfallAnimationLayout.graph_for(layout)
	if StadiumLowWallLayout.is_family(layout):
		return StadiumLowWallLayout.graph_for(layout)
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
		return StadiumReceiverOwnedItems.graph_for(layout)
	if StadiumBoundaryItems.is_family(layout):
		return StadiumBoundaryItems.graph_for(layout)
	if StadiumFacilityItems.is_family(layout):
		return graph_for(StadiumFacilityItems.base(layout))
	if StadiumRoofItems.is_family(layout):
		return graph_for(StadiumRoofItems.base(layout))
	if StadiumStraightItems.is_family(layout):
		return graph_for(StadiumStraightItems.base(layout))
	if StadiumGroundPropsItems.is_family(layout):
		return graph_for(StadiumGroundPropsItems.base(layout))
	if StadiumFlagItems.is_family(layout):
		return graph_for(StadiumFlagItems.base(layout))
	if SeasonOwnership._whole(layout.get("version"), 17, 17):
		return graph_for(StadiumSurfaceLayout.terrain_base(layout))
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return StadiumPoolOwnedLayout.graph_for(layout)
	if SeasonOwnership._whole(layout.get("version"), 15, 15):
		return StadiumMountedScoreboardLayout.graph_for(layout)
	if SeasonOwnership._whole(layout.get("version"), 14, 14):
		return graph_for(StadiumScoreboardLayout.base(layout))
	if not SeasonOwnership._whole(layout.get("version"), 13, 13):
		return StadiumWallItems.graph_for(layout)
	if (
		not layout.get("advanced_back") is Dictionary
		or not layout.advanced_back.get("shape") is String
	):
		return null
	if layout.advanced_back.shape.is_empty():
		return StadiumWallItems.graph_for(StadiumAdvancedWallLayout.base(layout))
	return StadiumAdvancedWallManifest.graph(layout.advanced_back.shape)


static func boundary_signature(layout: Dictionary) -> String:
	if StadiumWaterfallAnimationLayout.is_family(layout):
		return StadiumWaterfallAnimationLayout.boundary_signature(layout)
	if StadiumLowWallLayout.is_family(layout):
		return StadiumLowWallLayout.boundary_signature(layout)
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
		var graph: StadiumRecipeBoundary = StadiumReceiverOwnedItems.graph_for(layout)
		return "" if graph == null else graph.signature()
	if StadiumBoundaryItems.is_family(layout):
		var graph: StadiumRecipeBoundary = StadiumBoundaryItems.graph_for(layout)
		return "" if graph == null else graph.signature()
	if StadiumFacilityItems.is_family(layout):
		return boundary_signature(StadiumFacilityItems.base(layout))
	if StadiumRoofItems.is_family(layout):
		return boundary_signature(StadiumRoofItems.base(layout))
	if StadiumStraightItems.is_family(layout):
		return boundary_signature(StadiumStraightItems.base(layout))
	if StadiumGroundPropsItems.is_family(layout):
		return boundary_signature(StadiumGroundPropsItems.base(layout))
	if StadiumFlagItems.is_family(layout):
		return boundary_signature(StadiumFlagItems.base(layout))
	if SeasonOwnership._whole(layout.get("version"), 17, 17):
		return boundary_signature(StadiumSurfaceLayout.terrain_base(layout))
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return StadiumPoolOwnedLayout.boundary_signature(layout)
	if SeasonOwnership._whole(layout.get("version"), 15, 15):
		return StadiumMountedScoreboardLayout.boundary_signature(layout)
	if SeasonOwnership._whole(layout.get("version"), 14, 14):
		return boundary_signature(StadiumScoreboardLayout.base(layout))
	if not SeasonOwnership._whole(layout.get("version"), 13, 13):
		return StadiumWallItems.boundary_signature(layout)
	if layout.get("advanced_back") == StadiumAdvancedWallManifest.empty():
		return StadiumWallItems.boundary_signature(StadiumAdvancedWallLayout.base(layout))
	var graph: StadiumRecipeBoundary = graph_for(layout)
	return "" if graph == null else graph.signature()
