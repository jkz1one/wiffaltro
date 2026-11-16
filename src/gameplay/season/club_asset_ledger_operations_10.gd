extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_has_ground_props_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and event.get("price_version") == StadiumGroundPropsItems.PRICE_VERSION
				)
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
static func _source_private_has_straight_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and event.get("price_version") == StadiumStraightItems.PRICE_VERSION
				)
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
static func _source_private_award_pennant(_source_owner: ClubAssetLedger, event: Dictionary) -> \
	Dictionary:
	var id: String = StadiumPennantRewards.record_key(event.earned)
	if (
		event.id != id
		or not _source_owner._championships.has(id)
		or not ClubCareer.same(_source_owner._championships[id], event.earned)
	):
		return \
			ClubAssetLedger._error( \
			"A validated completed championship and its frozen era record are required.")
	var quote: Dictionary = (
		_source_owner._stock.mastery_quote(event.earned)
		if event.op == "stadium_mastery"
		else _source_owner._stock.pennant_quote(event.earned)
	)
	if not quote.ok or quote.replayed:
		return ClubAssetLedger._error("This championship pennant is invalid or has already been issued.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": 0,
		"stock": quote.state,
		"balance_after": _source_owner.balance()
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_pennant_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if event is Dictionary and event.get("op") == "stadium_pennant":
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_roof_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and event.get("price_version") == StadiumRoofItems.PRICE_VERSION
				)
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
static func _source_private_has_facility_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and event.get("price_version") == StadiumFacilityItems.PRICE_VERSION
				)
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
