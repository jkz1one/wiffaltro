extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_has_molded_seat_events(events: Variant) -> bool:
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
						StadiumMoldedSeatItems.PRICE_VERSION,
						StadiumMoldedSeatItems.PRICE_VERSION
					)
				)
				or (
					StadiumMoldedSeatItems.is_family(event.get("layout"))
					or (
						(
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
															StadiumMountedDisplayItems.is_family(
																event.get("layout")
															)
															or (
																StadiumStringLightItems.is_family(
																	event.get("layout")
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
																				event.get("layout")
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
						and StadiumMoldedSeatItems.is_family(
							StadiumGroundBoxItems.base(event.layout)
						)
					)
				)
			)
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_ground_box_events(events: Variant) -> bool:
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
						StadiumGroundBoxItems.PRICE_VERSION,
						StadiumGroundBoxItems.PRICE_VERSION
					)
				)
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
																StadiumMasteryBannerItems.is_family(
																	event.get("layout")
																)
																or (
																	StadiumWaterfallItems.is_family(
																		event.get("layout")
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_practice_facility_events(events: Variant) -> bool:
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
						StadiumPracticeFacilityItems.PRICE_VERSION,
						StadiumPracticeFacilityItems.PRICE_VERSION
					)
				)
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
										StadiumWallTopTerraceItems.is_family(event.get("layout"))
										or (
											StadiumPlayerTunnelItems.is_family(event.get("layout"))
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
															StadiumMasteryBannerItems.is_family(
																event.get("layout")
															)
															or (
																StadiumWaterfallItems.is_family(
																	event.get("layout")
																)
																or (
																	StadiumLightingKitItems
																	. is_family(event.get("layout"))
																)
															)
														)
													)
												)
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
static func _source_private_has_treehouse_events(events: Variant) -> bool:
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
						StadiumTreehouseItems.PRICE_VERSION,
						StadiumTreehouseItems.PRICE_VERSION
					)
				)
				or (
					StadiumTreehouseItems.is_family(event.get("layout"))
					or (
						StadiumLandmarkItems.is_family(event.get("layout"))
						or (
							StadiumOutfieldBleacherItems.is_family(event.get("layout"))
							or (
								StadiumRisingAppleItems.is_family(event.get("layout"))
								or (
									StadiumWallTopTerraceItems.is_family(event.get("layout"))
									or (
										StadiumPlayerTunnelItems.is_family(event.get("layout"))
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
														StadiumMasteryBannerItems.is_family(
															event.get("layout")
														)
														or (
															StadiumWaterfallItems.is_family(
																event.get("layout")
															)
															or StadiumLightingKitItems.is_family(
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_landmark_events(events: Variant) -> bool:
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
						StadiumLandmarkItems.PRICE_VERSION,
						StadiumLandmarkItems.PRICE_VERSION
					)
				)
				or (
					StadiumLandmarkItems.is_family(event.get("layout"))
					or (
						StadiumOutfieldBleacherItems.is_family(event.get("layout"))
						or (
							StadiumRisingAppleItems.is_family(event.get("layout"))
							or (
								StadiumWallTopTerraceItems.is_family(event.get("layout"))
								or (
									StadiumPlayerTunnelItems.is_family(event.get("layout"))
									or (
										StadiumMountedDisplayItems.is_family(event.get("layout"))
										or (
											StadiumStringLightItems.is_family(event.get("layout"))
											or (
												StadiumSalvageCarItems.is_family(
													event.get("layout")
												)
												or (
													StadiumMasteryBannerItems.is_family(
														event.get("layout")
													)
													or (
														StadiumWaterfallItems.is_family(
															event.get("layout")
														)
														or StadiumLightingKitItems.is_family(
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_outfield_bleacher_events(events: Variant) -> bool:
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
						StadiumOutfieldBleacherItems.PRICE_VERSION,
						StadiumOutfieldBleacherItems.PRICE_VERSION
					)
				)
				or (
					StadiumOutfieldBleacherItems.is_family(event.get("layout"))
					or (
						StadiumRisingAppleItems.is_family(event.get("layout"))
						or (
							StadiumWallTopTerraceItems.is_family(event.get("layout"))
							or (
								StadiumPlayerTunnelItems.is_family(event.get("layout"))
								or (
									StadiumMountedDisplayItems.is_family(event.get("layout"))
									or (
										StadiumStringLightItems.is_family(event.get("layout"))
										or (
											StadiumSalvageCarItems.is_family(event.get("layout"))
											or (
												StadiumMasteryBannerItems.is_family(
													event.get("layout")
												)
												or (
													StadiumWaterfallItems.is_family(
														event.get("layout")
													)
													or StadiumLightingKitItems.is_family(
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_rising_apple_events(events: Variant) -> bool:
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
						StadiumRisingAppleItems.PRICE_VERSION,
						StadiumRisingAppleItems.PRICE_VERSION
					)
				)
				or (
					StadiumRisingAppleItems.is_family(event.get("layout"))
					or (
						StadiumWallTopTerraceItems.is_family(event.get("layout"))
						or (
							StadiumPlayerTunnelItems.is_family(event.get("layout"))
							or (
								StadiumMountedDisplayItems.is_family(event.get("layout"))
								or (
									StadiumStringLightItems.is_family(event.get("layout"))
									or (
										StadiumSalvageCarItems.is_family(event.get("layout"))
										or (
											StadiumMasteryBannerItems.is_family(event.get("layout"))
											or (
												StadiumWaterfallItems.is_family(event.get("layout"))
												or StadiumLightingKitItems.is_family(
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_wall_top_terrace_events(events: Variant) -> bool:
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
						StadiumWallTopTerraceItems.PRICE_VERSION,
						StadiumWallTopTerraceItems.PRICE_VERSION
					)
				)
				or (
					StadiumWallTopTerraceItems.is_family(event.get("layout"))
					or (
						StadiumPlayerTunnelItems.is_family(event.get("layout"))
						or (
							StadiumMountedDisplayItems.is_family(event.get("layout"))
							or (
								StadiumStringLightItems.is_family(event.get("layout"))
								or (
									StadiumSalvageCarItems.is_family(event.get("layout"))
									or (
										StadiumMasteryBannerItems.is_family(event.get("layout"))
										or (
											StadiumWaterfallItems.is_family(event.get("layout"))
											or StadiumLightingKitItems.is_family(
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
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_player_tunnel_events(events: Variant) -> bool:
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
						StadiumPlayerTunnelItems.PRICE_VERSION,
						StadiumPlayerTunnelItems.PRICE_VERSION
					)
				)
				or (
					StadiumPlayerTunnelItems.is_family(event.get("layout"))
					or (
						StadiumMountedDisplayItems.is_family(event.get("layout"))
						or (
							StadiumStringLightItems.is_family(event.get("layout"))
							or (
								StadiumSalvageCarItems.is_family(event.get("layout"))
								or (
									StadiumMasteryBannerItems.is_family(event.get("layout"))
									or (
										StadiumWaterfallItems.is_family(event.get("layout"))
										or StadiumLightingKitItems.is_family(event.get("layout"))
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
static func _source_private_has_mounted_display_events(events: Variant) -> bool:
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
						StadiumMountedDisplayItems.PRICE_VERSION,
						StadiumMountedDisplayItems.PRICE_VERSION
					)
				)
				or (
					StadiumMountedDisplayItems.is_family(event.get("layout"))
					or (
						StadiumStringLightItems.is_family(event.get("layout"))
						or (
							StadiumSalvageCarItems.is_family(event.get("layout"))
							or (
								StadiumMasteryBannerItems.is_family(event.get("layout"))
								or (
									StadiumWaterfallItems.is_family(event.get("layout"))
									or StadiumLightingKitItems.is_family(event.get("layout"))
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
static func _source_private_has_string_light_events(events: Variant) -> bool:
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
						StadiumStringLightItems.PRICE_VERSION,
						StadiumStringLightItems.PRICE_VERSION
					)
				)
				or (
					StadiumStringLightItems.is_family(event.get("layout"))
					or (
						StadiumSalvageCarItems.is_family(event.get("layout"))
						or (
							StadiumMasteryBannerItems.is_family(event.get("layout"))
							or (
								StadiumWaterfallItems.is_family(event.get("layout"))
								or StadiumLightingKitItems.is_family(event.get("layout"))
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
static func _source_private_has_salvage_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				event.get("op") == "stadium_salvage_clear"
				or (
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumSalvageCarItems.PRICE_VERSION,
						StadiumSalvageCarItems.PRICE_VERSION
					)
				)
				or (
					StadiumSalvageCarItems.is_family(event.get("layout"))
					or (
						StadiumMasteryBannerItems.is_family(event.get("layout"))
						or (
							StadiumWaterfallItems.is_family(event.get("layout"))
							or StadiumLightingKitItems.is_family(event.get("layout"))
						)
					)
				)
			)
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_fixed_salvage_present(layout: Dictionary) -> bool:
	if (
		not (
			StadiumSalvageCarItems.is_family(layout)
			or (
				StadiumMasteryBannerItems.is_family(layout)
				or StadiumWaterfallItems.is_family(layout)
			)
		)
		or not layout.get("salvage_cars") is Array
	):
		return false
	var count: int = 0
	for row: Variant in layout.salvage_cars:
		if row is Dictionary and row.get("copy") == StadiumStock.SALVAGE_COPY:
			if row.get("site") != "CAR-START":
				return false
			count += 1
	return count == 1
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_without_salvage(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	var rows: Array = []
	for row: Dictionary in result.salvage_cars:
		if row.copy != StadiumStock.SALVAGE_COPY:
			rows.append(row.duplicate(true))
	result.salvage_cars = rows
	return result
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_clear_salvage(_source_owner: ClubAssetLedger, event: Dictionary) -> \
	Dictionary:
	if _source_owner._salvage_origin.is_empty() or not \
		_source_owner._stock.copies.has(StadiumStock.SALVAGE_COPY):
		return ClubAssetLedger._error("This club has no starter junk car to clear.")
	if event.price_version != ClubAssetLedger.SALVAGE_ORIGIN_VERSION:
		return ClubAssetLedger._error("The starter junk-car clearance quote changed.")
	if _source_owner._salvage_cleared:
		return {"ok": true, "replayed": true, "error": "", "view": _source_owner.view()}
	if event.through < _source_owner._through or event.through == 0 or \
		_source_owner._credits[event.through - 1] == 0:
		return ClubAssetLedger._error("A completed earning record is required.")
	if _source_owner._income(event.through) - _source_owner._spent < \
		ClubAssetLedger.SALVAGE_CLEAR_PRICE:
		return ClubAssetLedger._error("Not enough earned Club Bucks.")
	if not ClubAssetLedger._fixed_salvage_present(_source_owner._stadium_draft) or not \
		ClubAssetLedger._fixed_salvage_present(_source_owner._stadium_active):
		return \
			ClubAssetLedger._error("The fixed starter car could not be verified; preserve the current save.")
	var draft: Dictionary = ClubAssetLedger._without_salvage(_source_owner._stadium_draft)
	var active: Dictionary = ClubAssetLedger._without_salvage(_source_owner._stadium_active)
	if not _source_owner._validate_layout(draft).ok or not _source_owner._validate_layout(active).ok:
		return \
			ClubAssetLedger._error("The cleared layouts could not be validated; preserve the current save.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": ClubAssetLedger.SALVAGE_CLEAR_PRICE,
		"draft": draft,
		"active": active,
		"balance_after": _source_owner.balance() - ClubAssetLedger.SALVAGE_CLEAR_PRICE
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_mastery_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				event.get("op") == "stadium_mastery"
				or (
					StadiumMasteryBannerItems.is_family(event.get("layout"))
					or (
						StadiumWaterfallItems.is_family(event.get("layout"))
						or StadiumLightingKitItems.is_family(event.get("layout"))
					)
				)
			)
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_mastery_layout_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				StadiumMasteryBannerItems.is_family(event.get("layout"))
				or (
					StadiumWaterfallItems.is_family(event.get("layout"))
					or StadiumLightingKitItems.is_family(event.get("layout"))
				)
			)
		):
			return true
	return false
# gdlint: enable=max-returns
