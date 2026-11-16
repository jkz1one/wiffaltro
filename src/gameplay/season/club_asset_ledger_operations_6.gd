extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_restore_data_stage_5(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary
) -> ClubAssetLedger:
	if (
		(
			value.version == ClubAssetLedger.ROOF_VERSION
			or (
				(
					value.version == ClubAssetLedger.FACILITY_VERSION
					or (
						value.version == ClubAssetLedger.BOUNDARY_VERSION
						or (
							value.version == ClubAssetLedger.RECEIVER_VERSION
							or (
								value.version == ClubAssetLedger.FLOODLIGHT_VERSION
								or (
									value.version == ClubAssetLedger.LANDSCAPE_VERSION
									or (
										value.version == ClubAssetLedger.LIVE_FURNISHING_VERSION
										or (
											value.version == ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
											or (
												value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
												or (
													value.version == ClubAssetLedger.GROUND_BOX_VERSION
													or (
														value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
														or (
															value.version == ClubAssetLedger.TREEHOUSE_VERSION
															or (
																value.version == ClubAssetLedger.LANDMARK_VERSION
																or (
																	(
																		value.version
																		== ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
																	)
																	or (
																		(
																			value.version
																			== ClubAssetLedger.RISING_APPLE_VERSION
																		)
																		or (
																			(
																				value.version
																				== ClubAssetLedger.WALL_TOP_TERRACE_VERSION
																			)
																			or (
																				(
																					value.version
																					== ClubAssetLedger.PLAYER_TUNNEL_VERSION
																				)
																				or (
																					(
																						(
																							value
																							. version
																						)
																						== ClubAssetLedger.MOUNTED_DISPLAY_VERSION
																					)
																					or (
																						(
																							(
																								value
																								. version
																							)
																							== ClubAssetLedger.STRING_LIGHT_VERSION
																						)
																						or (
																							(
																								(
																									value
																									. version
																								)
																								== ClubAssetLedger.SALVAGE_VERSION
																							)
																							or (
																								(
																									value
																									. version
																								)
																								>= ClubAssetLedger.MASTERY_VERSION
																							)
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
				and ClubAssetLedger._has_roof_events(value.events)
			)
		)
		and (
			value.roof_catalog != StadiumRoofItems.price_signature()
			or value.roof_layout_catalog != StadiumRoofItems.signature()
			or not ClubAssetLedger._has_roof_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.FACILITY_VERSION
			or (
				(
					value.version == ClubAssetLedger.BOUNDARY_VERSION
					or (
						value.version == ClubAssetLedger.RECEIVER_VERSION
						or (
							value.version == ClubAssetLedger.FLOODLIGHT_VERSION
							or (
								value.version == ClubAssetLedger.LANDSCAPE_VERSION
								or (
									value.version == ClubAssetLedger.LIVE_FURNISHING_VERSION
									or (
										value.version == ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
										or (
											value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
											or (
												value.version == ClubAssetLedger.GROUND_BOX_VERSION
												or (
													value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
													or (
														value.version == ClubAssetLedger.TREEHOUSE_VERSION
														or (
															value.version == ClubAssetLedger.LANDMARK_VERSION
															or (
																(
																	value.version
																	== ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
																)
																or (
																	(
																		value.version
																		== ClubAssetLedger.RISING_APPLE_VERSION
																	)
																	or (
																		(
																			value.version
																			== ClubAssetLedger.WALL_TOP_TERRACE_VERSION
																		)
																		or (
																			(
																				value.version
																				== ClubAssetLedger.PLAYER_TUNNEL_VERSION
																			)
																			or (
																				(
																					value.version
																					== ClubAssetLedger.MOUNTED_DISPLAY_VERSION
																				)
																				or (
																					(
																						(
																							value
																							. version
																						)
																						== ClubAssetLedger.STRING_LIGHT_VERSION
																					)
																					or (
																						(
																							(
																								value
																								. version
																							)
																							== ClubAssetLedger.SALVAGE_VERSION
																						)
																						or (
																							(
																								value
																								. version
																							)
																							>= ClubAssetLedger.MASTERY_VERSION
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
				and ClubAssetLedger._has_facility_events(value.events)
			)
		)
		and (
			value.facility_catalog != StadiumFacilityItems.price_signature()
			or value.facility_layout_catalog != StadiumFacilityItems.signature()
			or not ClubAssetLedger._has_facility_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.BOUNDARY_VERSION
			or (
				(
					value.version == ClubAssetLedger.RECEIVER_VERSION
					or (
						value.version == ClubAssetLedger.FLOODLIGHT_VERSION
						or (
							value.version == ClubAssetLedger.LANDSCAPE_VERSION
							or (
								value.version == ClubAssetLedger.LIVE_FURNISHING_VERSION
								or (
									value.version == ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
									or (
										value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
										or (
											value.version == ClubAssetLedger.GROUND_BOX_VERSION
											or (
												value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
												or (
													value.version == ClubAssetLedger.TREEHOUSE_VERSION
													or (
														value.version == ClubAssetLedger.LANDMARK_VERSION
														or (
															(
																value.version
																== ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
															)
															or (
																(
																	value.version
																	== ClubAssetLedger.RISING_APPLE_VERSION
																)
																or (
																	(
																		value.version
																		== ClubAssetLedger.WALL_TOP_TERRACE_VERSION
																	)
																	or (
																		(
																			value.version
																			== ClubAssetLedger.PLAYER_TUNNEL_VERSION
																		)
																		or (
																			(
																				value.version
																				== ClubAssetLedger.MOUNTED_DISPLAY_VERSION
																			)
																			or (
																				(
																					value.version
																					== ClubAssetLedger.STRING_LIGHT_VERSION
																				)
																				or (
																					(
																						(
																							value
																							. version
																						)
																						== ClubAssetLedger.SALVAGE_VERSION
																					)
																					or (
																						(
																							value
																							. version
																						)
																						>= ClubAssetLedger.MASTERY_VERSION
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
				and ClubAssetLedger._has_boundary_events(value.events)
			)
		)
		and (
			value.boundary_catalog != StadiumBoundaryItems.price_signature()
			or value.boundary_layout_catalog != StadiumBoundaryItems.signature()
			or not ClubAssetLedger._has_boundary_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.RECEIVER_VERSION
			or (
				(
					value.version == ClubAssetLedger.FLOODLIGHT_VERSION
					or (
						value.version == ClubAssetLedger.LANDSCAPE_VERSION
						or (
							value.version == ClubAssetLedger.LIVE_FURNISHING_VERSION
							or (
								value.version == ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
								or (
									value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
									or (
										value.version == ClubAssetLedger.GROUND_BOX_VERSION
										or (
											value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
											or (
												value.version == ClubAssetLedger.TREEHOUSE_VERSION
												or (
													value.version == ClubAssetLedger.LANDMARK_VERSION
													or (
														value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
														or (
															value.version == ClubAssetLedger.RISING_APPLE_VERSION
															or (
																(
																	value.version
																	== ClubAssetLedger.WALL_TOP_TERRACE_VERSION
																)
																or (
																	(
																		value.version
																		== ClubAssetLedger.PLAYER_TUNNEL_VERSION
																	)
																	or (
																		(
																			value.version
																			== ClubAssetLedger.MOUNTED_DISPLAY_VERSION
																		)
																		or (
																			(
																				value.version
																				== ClubAssetLedger.STRING_LIGHT_VERSION
																			)
																			or (
																				(
																					value.version
																					== ClubAssetLedger.SALVAGE_VERSION
																				)
																				or (
																					value.version
																					>= ClubAssetLedger.MASTERY_VERSION
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
				and ClubAssetLedger._has_receiver_events(value.events)
			)
		)
		and (
			value.receiver_catalog != StadiumReceiverOwnedItems.price_signature()
			or value.receiver_layout_catalog != StadiumReceiverOwnedItems.signature()
			or not ClubAssetLedger._has_receiver_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.FLOODLIGHT_VERSION
			or (
				(
					value.version == ClubAssetLedger.LANDSCAPE_VERSION
					or (
						value.version == ClubAssetLedger.LIVE_FURNISHING_VERSION
						or (
							value.version == ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
							or (
								value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
								or (
									value.version == ClubAssetLedger.GROUND_BOX_VERSION
									or (
										value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
										or (
											value.version == ClubAssetLedger.TREEHOUSE_VERSION
											or (
												value.version == ClubAssetLedger.LANDMARK_VERSION
												or (
													value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
													or (
														value.version == ClubAssetLedger.RISING_APPLE_VERSION
														or (
															(
																value.version
																== ClubAssetLedger.WALL_TOP_TERRACE_VERSION
															)
															or (
																(
																	value.version
																	== ClubAssetLedger.PLAYER_TUNNEL_VERSION
																)
																or (
																	(
																		value.version
																		== ClubAssetLedger.MOUNTED_DISPLAY_VERSION
																	)
																	or (
																		(
																			value.version
																			== ClubAssetLedger.STRING_LIGHT_VERSION
																		)
																		or (
																			(
																				value.version
																				== ClubAssetLedger.SALVAGE_VERSION
																			)
																			or (
																				value.version
																				>= ClubAssetLedger.MASTERY_VERSION
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
				and ClubAssetLedger._has_floodlight_events(value.events)
			)
		)
		and (
			value.floodlight_catalog != StadiumFloodlightOwnedItems.price_signature()
			or value.floodlight_layout_catalog != StadiumFloodlightOwnedItems.signature()
			or not ClubAssetLedger._has_floodlight_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.LANDSCAPE_VERSION
			or (
				(
					value.version == ClubAssetLedger.LIVE_FURNISHING_VERSION
					or (
						value.version == ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
						or (
							value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
							or (
								value.version == ClubAssetLedger.GROUND_BOX_VERSION
								or (
									value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
									or (
										value.version == ClubAssetLedger.TREEHOUSE_VERSION
										or (
											value.version == ClubAssetLedger.LANDMARK_VERSION
											or (
												value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
												or (
													value.version == ClubAssetLedger.RISING_APPLE_VERSION
													or (
														value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
														or (
															value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
															or (
																(
																	value.version
																	== ClubAssetLedger.MOUNTED_DISPLAY_VERSION
																)
																or (
																	(
																		value.version
																		== ClubAssetLedger.STRING_LIGHT_VERSION
																	)
																	or (
																		(
																			value.version
																			== ClubAssetLedger.SALVAGE_VERSION
																		)
																		or (
																			value.version
																			>= ClubAssetLedger.MASTERY_VERSION
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
				and ClubAssetLedger._has_landscape_events(value.events)
			)
		)
		and (
			value.landscape_catalog != StadiumLandscapeOwnedItems.price_signature()
			or value.landscape_layout_catalog != StadiumLandscapeOwnedItems.signature()
			or not ClubAssetLedger._has_landscape_events(value.events)
		)
	):
		return null
	if (
		(
			(
				value.version == ClubAssetLedger.LIVE_FURNISHING_VERSION
				or value.version == ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
			)
			or (
				(
					value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
					or (
						value.version == ClubAssetLedger.GROUND_BOX_VERSION
						or (
							value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
							or (
								value.version == ClubAssetLedger.TREEHOUSE_VERSION
								or (
									value.version == ClubAssetLedger.LANDMARK_VERSION
									or (
										value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
										or (
											value.version == ClubAssetLedger.RISING_APPLE_VERSION
											or (
												value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
												or (
													value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
													or (
														value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
														or (
															value.version == ClubAssetLedger.STRING_LIGHT_VERSION
															or (
																value.version == ClubAssetLedger.SALVAGE_VERSION
																or value.version >= ClubAssetLedger.MASTERY_VERSION
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
				and ClubAssetLedger._has_live_furnishing_events(value.events)
			)
		)
		and (
			value.live_furnishing_catalog != StadiumLiveFurnishingItems.price_signature()
			or value.live_furnishing_layout_catalog != StadiumLiveFurnishingItems.signature()
			or not ClubAssetLedger._has_live_furnishing_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
			or (
				(
					value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
					or (
						value.version == ClubAssetLedger.GROUND_BOX_VERSION
						or (
							value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
							or (
								value.version == ClubAssetLedger.TREEHOUSE_VERSION
								or (
									value.version == ClubAssetLedger.LANDMARK_VERSION
									or (
										value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
										or (
											value.version == ClubAssetLedger.RISING_APPLE_VERSION
											or (
												value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
												or (
													value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
													or (
														value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
														or (
															value.version == ClubAssetLedger.STRING_LIGHT_VERSION
															or (
																value.version == ClubAssetLedger.SALVAGE_VERSION
																or value.version >= ClubAssetLedger.MASTERY_VERSION
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
				and ClubAssetLedger._has_small_yard_scenery_events(value.events)
			)
		)
		and (
			value.yard_scenery_layout_catalog != StadiumSmallYardSceneryItems.signature()
			or not ClubAssetLedger._has_small_yard_scenery_events(value.events)
		)
	):
		return null
	return ClubAssetLedger._restore_data_stage_6(value, seed_value, credits, progress, championships)
# gdlint: enable=max-returns
