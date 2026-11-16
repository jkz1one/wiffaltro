class_name ClubConstruction
extends RefCounted
## Atomic free draft/apply and paid starter-copy transactions on the same club ledger.


static func editable(season: SeasonState) -> bool:
	return season != null and season.career != null and editable_phase(season)


static func editable_phase(season: SeasonState) -> bool:
	## Physical editing window only. This never authorizes a save owner.
	return (
		season != null
		and (
			season.phase == SeasonState.Phase.COMPLETE
			or (season.phase == SeasonState.Phase.DRAFT and season.picks.is_empty())
		)
		and (season.physical == null or season.physical.pending.is_empty())
	)


static func save_draft(season: SeasonState, layout: Dictionary, revision: int) -> Dictionary:
	var admission: Dictionary = draft_admission(season, layout, season != null and season.career != null)
	if not admission.ok:
		return admission
	return ClubPlayers.transact(
		season,
		{
			"id": "stadium-draft:%d" % revision,
			"rev": revision,
			"op": "stadium_draft",
			"layout": layout.duplicate(true)
		}
	)


static func draft_admission(season: SeasonState, layout: Dictionary, owner_admitted: bool) -> Dictionary:
	## Pure public layout gates. Caller must separately qualify its real owner.
	if (
		(
			layout.get("version") == 17
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
																(
																	StadiumPracticeFacilityItems
																	. is_terrain(layout)
																)
																or (
																	(
																		StadiumTreehouseItems
																		. is_terrain(layout)
																	)
																	or (
																		(
																			StadiumLandmarkItems
																			. is_terrain(layout)
																		)
																		or (
																			(
																				StadiumOutfieldBleacherItems
																				. is_terrain(layout)
																			)
																			or (
																				(
																					StadiumRisingAppleItems
																					. is_terrain(
																						layout
																					)
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
		)
		and season != null
		and not season.owned_surface_night.is_empty()
	):
		return ClubAssetLedger._error(
			"Start an ordinary daylight season before opting into terrain."
		)
	if (
		SeasonOwnership._whole(layout.get("version"), 15, 15)
		and not StadiumMountedScoreboardLayout.RUNTIME_READY
	):
		return ClubAssetLedger._error("Mounted scoreboard field integration is not enabled yet.")
	if (
		SeasonOwnership._whole(layout.get("version"), 14, 14)
		and not StadiumScoreboardLayout.RUNTIME_READY
	):
		return ClubAssetLedger._error("Scoreboard field integration is not enabled yet.")
	if (
		SeasonOwnership._whole(layout.get("version"), 13, 13)
		and not StadiumAdvancedWallLayout.RUNTIME_READY
	):
		return ClubAssetLedger._error("Advanced field integration is not enabled yet.")
	if not owner_admitted or not editable_phase(season):
		return ClubAssetLedger._error(
			"Stadium editing is available between seasons, before drafting."
		)
	return {"ok": true, "error": ""}


static func can_apply(season: SeasonState) -> bool:
	return (
		editable(season)
		and (
			season.phase == SeasonState.Phase.COMPLETE
			or (season.physical != null and not season.player_access.is_empty())
		)
	)


static func apply_draft(season: SeasonState, layout: Dictionary, revision: int) -> Dictionary:
	var admission: Dictionary = apply_admission(season, layout, season != null and season.career != null)
	if not admission.ok:
		return admission
	var source: Dictionary = SeasonSave.snapshot(season)
	var candidate: SeasonState = SeasonSave._decode(source) if not source.is_empty() else null
	if candidate == null:
		return ClubAssetLedger._error("The saved club could not be validated for this layout.")
	var applied: Dictionary = ClubPlayers.command(
		candidate.career,
		{
			"id": "stadium-apply:%d" % revision,
			"rev": revision,
			"op": "stadium_apply",
			"layout": layout.duplicate(true),
			"geometry":
			StadiumOwnedLayout.geometry(ClubPlayers.assets(candidate.career).view().land, layout)
		}
	)
	if not applied.ok:
		return applied
	if (
		not applied.replayed
		and candidate.phase == SeasonState.Phase.DRAFT
		and candidate.physical != null
		and not candidate.player_access.is_empty()
	):
		var frozen: Dictionary = StadiumLayoutSnapshot.capture(
			ClubPlayers.assets(candidate.career),
			candidate.home_property.is_empty() or candidate.home_property.has("boundary")
		)
		if frozen.is_empty():
			return ClubAssetLedger._error(
				"The owned field cannot be installed; prior save is unchanged."
			)
		if candidate._league_home_context.get("format") in [93, 94]:
			if not load("res://src/gameplay/season/normal_league_home.gd").recapture(candidate, frozen):
				return ClubAssetLedger._error("This updated field is not supported for this League yet. The prior save and balance are unchanged.")
		else:
			candidate.home_property = frozen
	if not SeasonSave.save(candidate):
		return ClubAssetLedger._error(SeasonSave.last_error)
	season.career = candidate.career
	season.home_property = candidate.home_property.duplicate(true)
	if candidate._league_home_context.get("format") in [93, 94]:
		season._league_home_context = candidate._league_home_context.duplicate(true)
		season._pool_replay_ledger = candidate._pool_replay_ledger
		if candidate._league_home_context.format == 94:
			season.owned_surface_night = candidate.owned_surface_night.duplicate(true)
	return applied


static func apply_admission(season: SeasonState, layout: Dictionary, owner_admitted: bool) -> Dictionary:
	## Pure public layout gates. No snapshot, ledger mutation or home refresh.
	if (
		(
			layout.get("version") == 17
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
																(
																	StadiumPracticeFacilityItems
																	. is_terrain(layout)
																)
																or (
																	(
																		StadiumTreehouseItems
																		. is_terrain(layout)
																	)
																	or (
																		(
																			StadiumLandmarkItems
																			. is_terrain(layout)
																		)
																		or (
																			(
																				StadiumOutfieldBleacherItems
																				. is_terrain(layout)
																			)
																			or (
																				(
																					StadiumRisingAppleItems
																					. is_terrain(
																						layout
																					)
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
		)
		and season != null
		and not season.owned_surface_night.is_empty()
	):
		return ClubAssetLedger._error(
			"Start an ordinary daylight season before opting into terrain."
		)
	if (
		season != null
		and not season.owned_surface_night.is_empty()
		and season.phase != SeasonState.Phase.COMPLETE
		and not load("res://src/gameplay/season/normal_league_time_candidate.gd").workshop_editable(season)
		and not (owner_admitted and load("res://src/gameplay/season/dynasty_shared_time_runtime.gd").future_editable(season))
	):
		return ClubAssetLedger._error(
			"This season’s night field is frozen. Apply changes after completing it."
		)
	if (
		SeasonOwnership._whole(layout.get("version"), 15, 15)
		and not StadiumMountedScoreboardLayout.RUNTIME_READY
	):
		return ClubAssetLedger._error("Mounted scoreboard field integration is not enabled yet.")
	if (
		SeasonOwnership._whole(layout.get("version"), 14, 14)
		and not StadiumScoreboardLayout.RUNTIME_READY
	):
		return ClubAssetLedger._error("Scoreboard field integration is not enabled yet.")
	if (
		SeasonOwnership._whole(layout.get("version"), 13, 13)
		and not StadiumAdvancedWallLayout.RUNTIME_READY
	):
		return ClubAssetLedger._error("Advanced field integration is not enabled yet.")
	if layout.get("version") == 12 and not StadiumSurfaceLayout.RUNTIME_READY:
		return ClubAssetLedger._error("Surface fixture integration is not enabled yet.")
	if SeasonOwnership._whole(layout.get("version"), 11, 11) and not StadiumWallItems.RUNTIME_READY:
		return ClubAssetLedger._error("Complete-wall fixture integration is not enabled yet.")
	if not owner_admitted or not editable_phase(season) or not (season.phase == SeasonState.Phase.COMPLETE or (season.physical != null and not season.player_access.is_empty())):
		return ClubAssetLedger._error(
			"Apply before drafting a Working season, or after completing one."
		)
	if (
		(
			SeasonOwnership._whole(layout.get("version"), 2, 15)
			or layout.get("version") == 17
			or layout.get("version") == 18
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
																(
																	StadiumPracticeFacilityItems
																	. is_family(layout)
																)
																or (
																	StadiumTreehouseItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumLandmarkItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumOutfieldBleacherItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumRisingAppleItems
																					. is_family(
																						layout
																					)
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
		)
		and season.phase == SeasonState.Phase.DRAFT
		and not season.home_property.has("boundary")
	):
		return ClubAssetLedger._error(
			"This layout needs a complete boundary; apply after this season."
		)
	return {"ok": true, "error": ""}


static func buy_copy(
	season: SeasonState, item: String, revision: int, quantity: int = 1
) -> Dictionary:
	if not editable(season):
		return ClubAssetLedger._error(
			"Construction purchases open between seasons, before drafting."
		)
	return ClubPlayers.transact(season, copy_command(season.career, item, revision, quantity))


static func copy_command(club: ClubCareer, item: String, revision: int, quantity: int = 1) -> Dictionary:
	## Pure existing catalog command. Callers retain their own editability and owner boundary.
	if club == null:
		return {}
	var command: Dictionary = {
		"id": "stadium-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"through": ClubPlayers.income_through(club),
		"price_version": StadiumPurchases.VERSION,
		"item": item,
		"quantity": quantity
	}
	var catalog: Dictionary = copy_catalog(item)
	command.price_version = catalog.price_version
	if catalog.progress:
		command["progress_through"] = StadiumCareerProgress.capture(club).size()
	return command


static func copy_catalog(item: String) -> Dictionary:
	## Existing buy-copy catalog only; this never enables a layout family.
	if StadiumOutfieldPlazaItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumOutfieldPlazaItems.PRICE_VERSION, "progress": true}
	if StadiumLightingKitItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumLightingKitItems.PRICE_VERSION, "progress": true}
	if StadiumWaterfallItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumWaterfallItems.PRICE_VERSION, "progress": true}
	if StadiumSalvageCarItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumSalvageCarItems.PRICE_VERSION, "progress": true}
	if StadiumStringLightItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumStringLightItems.PRICE_VERSION, "progress": true}
	if StadiumMountedDisplayItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumMountedDisplayItems.PRICE_VERSION, "progress": true}
	if StadiumPlayerTunnelItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumPlayerTunnelItems.PRICE_VERSION, "progress": true}
	if StadiumWallTopTerraceItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumWallTopTerraceItems.PRICE_VERSION, "progress": true}
	if StadiumRisingAppleItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumRisingAppleItems.PRICE_VERSION, "progress": true}
	if StadiumOutfieldBleacherItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumOutfieldBleacherItems.PRICE_VERSION, "progress": true}
	if StadiumLandmarkItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumLandmarkItems.PRICE_VERSION, "progress": true}
	if StadiumTreehouseItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumTreehouseItems.PRICE_VERSION, "progress": true}
	if StadiumPracticeFacilityItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumPracticeFacilityItems.PRICE_VERSION, "progress": true}
	if StadiumGroundBoxItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumGroundBoxItems.PRICE_VERSION, "progress": true}
	if StadiumMoldedSeatItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumMoldedSeatItems.PRICE_VERSION, "progress": true}
	if StadiumLiveFurnishingItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumLiveFurnishingItems.PRICE_VERSION, "progress": true}
	if StadiumLandscapeOwnedItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumLandscapeOwnedItems.PRICE_VERSION, "progress": true}
	if StadiumFloodlightOwnedItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumFloodlightOwnedItems.PRICE_VERSION, "progress": true}
	if StadiumReceiverOwnedItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumReceiverOwnedItems.PRICE_VERSION, "progress": true}
	if StadiumBoundaryItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumBoundaryItems.PRICE_VERSION, "progress": true}
	if StadiumFacilityItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumFacilityItems.PRICE_VERSION, "progress": true}
	if StadiumRoofItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumRoofItems.PRICE_VERSION, "progress": true}
	if StadiumStraightItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumStraightItems.PRICE_VERSION, "progress": true}
	if StadiumGroundPropsItems.PRICES.has(item):
		return {"known": true, "price_version": StadiumGroundPropsItems.PRICE_VERSION, "progress": true}
	if item == "ST-043":
		return {"known": true, "price_version": StadiumFlagItems.PRICE_VERSION, "progress": true}
	if StadiumPurchases.POOLS.has(item):
		return {"known": true, "price_version": StadiumPurchases.POOL_VERSION, "progress": true}
	if StadiumPurchases.LIGHTS.has(item):
		return {"known": true, "price_version": StadiumPurchases.LIGHT_VERSION, "progress": true}
	if StadiumPurchases.NETS.has(item):
		return {"known": true, "price_version": StadiumPurchases.NET_VERSION, "progress": true}
	if StadiumPurchases.TARGETS.has(item):
		return {"known": true, "price_version": StadiumPurchases.TARGET_VERSION, "progress": true}
	if StadiumPurchases.BLEACHERS.has(item):
		return {"known": true, "price_version": StadiumPurchases.BLEACHER_VERSION, "progress": true}
	if StadiumPurchases.DISPLAYS.has(item):
		return {"known": true, "price_version": StadiumPurchases.DISPLAY_VERSION, "progress": true}
	if StadiumPurchases.SEATING.has(item):
		return {"known": true, "price_version": StadiumPurchases.SEATING_VERSION, "progress": true}
	return {"known": StadiumPurchases.PRICES.has(item), "price_version": StadiumPurchases.VERSION, "progress": false}


static func copy_items() -> Array[String]:
	var result: Array[String] = []
	var catalogs: Array = [StadiumPurchases.PRICES,
		StadiumOutfieldPlazaItems.PRICES,
		StadiumLightingKitItems.PRICES,
		StadiumWaterfallItems.PRICES,
		StadiumSalvageCarItems.PRICES,
		StadiumStringLightItems.PRICES,
		StadiumMountedDisplayItems.PRICES,
		StadiumPlayerTunnelItems.PRICES,
		StadiumWallTopTerraceItems.PRICES,
		StadiumRisingAppleItems.PRICES,
		StadiumOutfieldBleacherItems.PRICES,
		StadiumLandmarkItems.PRICES,
		StadiumTreehouseItems.PRICES,
		StadiumPracticeFacilityItems.PRICES,
		StadiumGroundBoxItems.PRICES,
		StadiumMoldedSeatItems.PRICES,
		StadiumLiveFurnishingItems.PRICES,
		StadiumLandscapeOwnedItems.PRICES,
		StadiumFloodlightOwnedItems.PRICES,
		StadiumReceiverOwnedItems.PRICES,
		StadiumBoundaryItems.PRICES,
		StadiumFacilityItems.PRICES,
		StadiumRoofItems.PRICES,
		StadiumStraightItems.PRICES,
		StadiumGroundPropsItems.PRICES,
		StadiumPurchases.POOLS,
		StadiumPurchases.LIGHTS,
		StadiumPurchases.NETS,
		StadiumPurchases.TARGETS,
		StadiumPurchases.BLEACHERS,
		StadiumPurchases.DISPLAYS,
		StadiumPurchases.SEATING,
	]
	for catalog: Dictionary in catalogs:
		for item: String in catalog:
			if not result.has(item):
				result.append(item)
	result.append("ST-043")
	result.sort()
	return result


static func can_expand(season: SeasonState) -> bool:
	return (
		editable(season)
		and (season.phase == SeasonState.Phase.COMPLETE or season.home_property.has("boundary"))
	)


static func buy_land(season: SeasonState, tier: String, revision: int) -> Dictionary:
	if (
		season != null
		and not season.owned_surface_night.is_empty()
		and season.phase != SeasonState.Phase.COMPLETE
		and not load("res://src/gameplay/season/normal_league_time_candidate.gd").workshop_editable(season)
	):
		return ClubAssetLedger._error(
			"This season’s night field is frozen. Apply changes after completing it."
		)
	if not can_expand(season):
		return ClubAssetLedger._error("Expand between seasons in a complete-boundary home profile.")
	var source: Dictionary = SeasonSave.snapshot(season)
	var candidate: SeasonState = SeasonSave._decode(source) if not source.is_empty() else null
	if candidate == null:
		return ClubAssetLedger._error("The club could not be validated for property expansion.")
	var result: Dictionary = ClubPlayers.command(
		candidate.career,
		{
			"id": "stadium-land:%d" % revision,
			"rev": revision,
			"op": "stadium_land",
			"tier": tier,
			"price_version": StadiumLand.VERSION,
			"through": ClubPlayers.income_through(candidate.career),
			"progress_through": StadiumCareerProgress.capture(candidate.career).size()
		}
	)
	if not result.ok:
		return result
	if not result.replayed and candidate.phase == SeasonState.Phase.DRAFT:
		var frozen: Dictionary = StadiumLayoutSnapshot.capture(ClubPlayers.assets(candidate.career))
		if frozen.is_empty():
			return ClubAssetLedger._error("Expanded field unavailable; prior save is unchanged.")
		if candidate._league_home_context.get("format") in [93, 94]:
			if not load("res://src/gameplay/season/normal_league_home.gd").recapture(candidate, frozen):
				return ClubAssetLedger._error("This updated field is not supported for this League yet. The prior save and balance are unchanged.")
		else:
			candidate.home_property = frozen
	if not SeasonSave.save(candidate):
		return ClubAssetLedger._error(SeasonSave.last_error)
	season.career = candidate.career
	season.home_property = candidate.home_property.duplicate(true)
	if candidate._league_home_context.get("format") in [93, 94]:
		season._league_home_context = candidate._league_home_context.duplicate(true)
		season._pool_replay_ledger = candidate._pool_replay_ledger
		if candidate._league_home_context.format == 94:
			season.owned_surface_night = candidate.owned_surface_night.duplicate(true)
	return result


static func buy_style(season: SeasonState, item: String, revision: int) -> Dictionary:
	if not editable(season):
		return ClubAssetLedger._error(
			"Field appearance purchases open between seasons, before drafting."
		)
	return ClubPlayers.transact(
		season,
		{
			"id": "stadium-style:%d" % revision,
			"rev": revision,
			"op": "stadium_style",
			"item": item,
			"price_version":
			(
				StadiumInfieldStyles.PRICE_VERSION
				if StadiumInfieldStyles.PRICES.has(item)
				else (
					StadiumGroundStyles.PRICE_VERSION
					if StadiumGroundStyles.PRICES.has(item)
					else StadiumFieldStyles.VERSION
				)
			),
			"through": ClubPlayers.income_through(season.career),
			"progress_through": StadiumCareerProgress.capture(season.career).size()
		}
	)


static func buy_walls(
	season: SeasonState, item: String, quantity: int, revision: int
) -> Dictionary:
	if not StadiumWallItems.RUNTIME_READY or not editable(season):
		return ClubAssetLedger._error("Complete-wall purchases open between verified seasons.")
	if not StadiumWallItems.PRICES.has(item):
		return ClubAssetLedger._error("Unknown complete-wall material.")
	return ClubPlayers.transact(
		season,
		{
			"id": "stadium-wall-buy:%d" % revision,
			"rev": revision,
			"op": "stadium_buy",
			"item": item,
			"quantity": quantity,
			"price_version": StadiumWallItems.PRICE_VERSION,
			"through": ClubPlayers.income_through(season.career),
			"progress_through": StadiumCareerProgress.capture(season.career).size()
		}
	)


static func buy_surface(season: SeasonState, item: String, revision: int) -> Dictionary:
	if not editable(season):
		return ClubAssetLedger._error("Surface upgrades open between seasons, before drafting.")
	return ClubPlayers.transact(
		season,
		{
			"id": "stadium-surface:%d" % revision,
			"rev": revision,
			"op": "stadium_surface",
			"item": item,
			"price_version": StadiumSurfaceProgression.VERSION,
			"through": ClubPlayers.income_through(season.career)
		}
	)


static func buy_scoreboard(
	season: SeasonState, item: String, quantity: int, revision: int
) -> Dictionary:
	if not editable(season):
		return ClubAssetLedger._error("Scoreboard purchases open between seasons, before drafting.")
	if not StadiumScoreboardCatalog.IDS.has(item):
		return ClubAssetLedger._error("Unknown scoreboard tier.")
	return ClubPlayers.transact(
		season,
		{
			"id": "stadium-scoreboard:%d" % revision,
			"rev": revision,
			"op": "stadium_scoreboard",
			"item": item,
			"quantity": quantity,
			"price_version": StadiumScoreboardPurchases.VERSION,
			"through": ClubPlayers.income_through(season.career),
			"progress_through": StadiumCareerProgress.capture(season.career).size()
		}
	)


static func buy_wall_pieces(
	season: SeasonState, item: String, quantity: int, revision: int
) -> Dictionary:
	if not editable(season):
		return ClubAssetLedger._error("Wall-piece purchases open between seasons, before drafting.")
	if StadiumWallPieceCatalog.item(item).is_empty():
		return ClubAssetLedger._error("Unknown exact wall-piece variant.")
	return ClubPlayers.transact(
		season,
		{
			"id": "stadium-wall-piece:%d" % revision,
			"rev": revision,
			"op": "stadium_wall_piece",
			"item": item,
			"quantity": quantity,
			"price_version": StadiumWallPieceOwnership.VERSION,
			"through": ClubPlayers.income_through(season.career),
			"progress_through": StadiumCareerProgress.capture(season.career).size()
		}
	)


static func clear_salvage(season: SeasonState, revision: int) -> Dictionary:
	if not editable(season):
		return ClubAssetLedger._error(
			"Clear the starter junk car between seasons, before drafting."
		)
	if not season.owned_surface_night.is_empty() and season.phase != SeasonState.Phase.COMPLETE \
		and not load("res://src/gameplay/season/normal_league_time_candidate.gd").workshop_editable(season):
		return ClubAssetLedger._error(
			"This season's night field is frozen. Clear the car after completing it."
		)
	var source: Dictionary = SeasonSave.snapshot(season)
	var candidate: SeasonState = SeasonSave._decode(source) if not source.is_empty() else null
	if candidate == null:
		return ClubAssetLedger._error("The club could not be validated for junk-car clearance.")
	var result: Dictionary = ClubPlayers.command(
		candidate.career,
		{
			"id": "stadium-salvage-clear:%d" % revision,
			"rev": revision,
			"op": "stadium_salvage_clear",
			"copy": StadiumStock.SALVAGE_COPY,
			"price_version": ClubAssetLedger.SALVAGE_ORIGIN_VERSION,
			"through": ClubPlayers.income_through(candidate.career)
		}
	)
	if not result.ok:
		return result
	if not result.replayed and candidate.phase == SeasonState.Phase.DRAFT:
		var frozen: Dictionary = StadiumLayoutSnapshot.capture(
			ClubPlayers.assets(candidate.career),
			candidate.home_property.is_empty() or candidate.home_property.has("boundary")
		)
		if frozen.is_empty():
			return ClubAssetLedger._error(
				"The cleared field cannot be installed; prior save is unchanged."
			)
		if candidate._league_home_context.get("format") in [93, 94]:
			if not load("res://src/gameplay/season/normal_league_home.gd").recapture(candidate, frozen):
				return ClubAssetLedger._error("This updated field is not supported for this League yet. The prior save and balance are unchanged.")
		else:
			candidate.home_property = frozen
	if not SeasonSave.save(candidate):
		return ClubAssetLedger._error(SeasonSave.last_error)
	season.career = candidate.career
	season.home_property = candidate.home_property.duplicate(true)
	if candidate._league_home_context.get("format") in [93, 94]:
		season._league_home_context = candidate._league_home_context.duplicate(true)
		season._pool_replay_ledger = candidate._pool_replay_ledger
		if candidate._league_home_context.format == 94:
			season.owned_surface_night = candidate.owned_surface_night.duplicate(true)
	return result
