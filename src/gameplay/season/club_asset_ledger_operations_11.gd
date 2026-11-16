extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_has_boundary_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumBoundaryItems.PRICE_VERSION,
						StadiumBoundaryItems.PRICE_VERSION
					)
				)
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
static func _source_private_has_receiver_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumReceiverOwnedItems.PRICE_VERSION,
						StadiumReceiverOwnedItems.PRICE_VERSION
					)
				)
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
															StadiumOutfieldBleacherItems.is_family(
																event.get("layout")
															)
															or (
																StadiumRisingAppleItems.is_family(
																	event.get("layout")
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
																				event.get("layout")
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
																						event.get(
																							"layout"
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_floodlight_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumFloodlightOwnedItems.PRICE_VERSION,
						StadiumFloodlightOwnedItems.PRICE_VERSION
					)
				)
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
												StadiumTreehouseItems.is_family(event.get("layout"))
												or (
													StadiumLandmarkItems.is_family(
														event.get("layout")
													)
													or (
														StadiumOutfieldBleacherItems.is_family(
															event.get("layout")
														)
														or (
															StadiumRisingAppleItems.is_family(
																event.get("layout")
															)
															or (
																(
																	StadiumWallTopTerraceItems
																	. is_family(event.get("layout"))
																)
																or (
																	(
																		StadiumPlayerTunnelItems
																		. is_family(
																			event.get("layout")
																		)
																	)
																	or (
																		(
																			StadiumMountedDisplayItems
																			. is_family(
																				event.get("layout")
																			)
																		)
																		or (
																			(
																				StadiumStringLightItems
																				. is_family(
																					event.get(
																						"layout"
																					)
																				)
																			)
																			or (
																				(
																					StadiumSalvageCarItems
																					. is_family(
																						event.get(
																							"layout"
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_landscape_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumLandscapeOwnedItems.PRICE_VERSION,
						StadiumLandscapeOwnedItems.PRICE_VERSION
					)
				)
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
										StadiumPracticeFacilityItems.is_family(event.get("layout"))
										or (
											StadiumTreehouseItems.is_family(event.get("layout"))
											or (
												StadiumLandmarkItems.is_family(event.get("layout"))
												or (
													StadiumOutfieldBleacherItems.is_family(
														event.get("layout")
													)
													or (
														StadiumRisingAppleItems.is_family(
															event.get("layout")
														)
														or (
															StadiumWallTopTerraceItems.is_family(
																event.get("layout")
															)
															or (
																StadiumPlayerTunnelItems.is_family(
																	event.get("layout")
																)
																or (
																	(
																		StadiumMountedDisplayItems
																		. is_family(
																			event.get("layout")
																		)
																	)
																	or (
																		(
																			StadiumStringLightItems
																			. is_family(
																				event.get("layout")
																			)
																		)
																		or (
																			(
																				StadiumSalvageCarItems
																				. is_family(
																					event.get(
																						"layout"
																					)
																				)
																			)
																			or (
																				(
																					StadiumMasteryBannerItems
																					. is_family(
																						event.get(
																							"layout"
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_live_furnishing_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumLiveFurnishingItems.PRICE_VERSION,
						StadiumLiveFurnishingItems.PRICE_VERSION
					)
				)
				or (
					StadiumLiveFurnishingItems.is_family(event.get("layout"))
					or (
						StadiumSmallYardSceneryItems.is_family(event.get("layout"))
						or (
							StadiumMoldedSeatItems.is_family(event.get("layout"))
							or (
								StadiumGroundBoxItems.is_family(event.get("layout"))
								or (
									StadiumPracticeFacilityItems.is_family(event.get("layout"))
									or (
										StadiumTreehouseItems.is_family(event.get("layout"))
										or (
											StadiumLandmarkItems.is_family(event.get("layout"))
											or (
												StadiumOutfieldBleacherItems.is_family(
													event.get("layout")
												)
												or (
													StadiumRisingAppleItems.is_family(
														event.get("layout")
													)
													or (
														StadiumWallTopTerraceItems.is_family(
															event.get("layout")
														)
														or (
															StadiumPlayerTunnelItems.is_family(
																event.get("layout")
															)
															or (
																(
																	StadiumMountedDisplayItems
																	. is_family(event.get("layout"))
																)
																or (
																	(
																		StadiumStringLightItems
																		. is_family(
																			event.get("layout")
																		)
																	)
																	or (
																		(
																			StadiumSalvageCarItems
																			. is_family(
																				event.get("layout")
																			)
																		)
																		or (
																			(
																				StadiumMasteryBannerItems
																				. is_family(
																					event.get(
																						"layout"
																					)
																				)
																			)
																			or (
																				(
																					StadiumWaterfallItems
																					. is_family(
																						event.get(
																							"layout"
																						)
																					)
																				)
																				or (
																					StadiumLightingKitItems
																					. is_family(
																						event.get(
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_small_yard_scenery_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				StadiumSmallYardSceneryItems.is_family(event.get("layout"))
				or (
					StadiumMoldedSeatItems.is_family(event.get("layout"))
					or (
						StadiumGroundBoxItems.is_family(event.get("layout"))
						or (
							StadiumPracticeFacilityItems.is_family(event.get("layout"))
							or (
								StadiumTreehouseItems.is_family(event.get("layout"))
								or (
									StadiumLandmarkItems.is_family(event.get("layout"))
									or (
										StadiumOutfieldBleacherItems.is_family(event.get("layout"))
										or (
											StadiumRisingAppleItems.is_family(event.get("layout"))
											or (
												StadiumWallTopTerraceItems.is_family(
													event.get("layout")
												)
												or (
													StadiumPlayerTunnelItems.is_family(
														event.get("layout")
													)
													or (
														StadiumMountedDisplayItems.is_family(
															event.get("layout")
														)
														or (
															StadiumStringLightItems.is_family(
																event.get("layout")
															)
															or (
																StadiumSalvageCarItems.is_family(
																	event.get("layout")
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(
																			event.get("layout")
																		)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(
																				event.get("layout")
																			)
																		)
																		or (
																			StadiumLightingKitItems
																			. is_family(
																				event.get("layout")
																			)
																		)
																	)
																)
															)
														)
													)
												)
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
