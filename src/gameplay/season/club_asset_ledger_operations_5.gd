extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_restore_data_stage_4(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary
) -> ClubAssetLedger:
	if (
		(
			value.version == ClubAssetLedger.TERRAIN_VERSION
			or (
				(
					value.version == ClubAssetLedger.FLAG_VERSION
					or value.version == ClubAssetLedger.GROUND_PROPS_VERSION
					or (
						value.version == ClubAssetLedger.STRAIGHT_VERSION
						or value.version == ClubAssetLedger.PENNANT_VERSION
						or value.version == ClubAssetLedger.ROOF_VERSION
						or (
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
																(
																	value.version
																	== ClubAssetLedger.PRACTICE_FACILITY_VERSION
																)
																or (
																	(
																		value.version
																		== ClubAssetLedger.TREEHOUSE_VERSION
																	)
																	or (
																		(
																			value.version
																			== ClubAssetLedger.LANDMARK_VERSION
																		)
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
																						(
																							value
																							. version
																						)
																						== ClubAssetLedger.WALL_TOP_TERRACE_VERSION
																					)
																					or (
																						(
																							(
																								value
																								. version
																							)
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
					)
				)
				and ClubAssetLedger._has_terrain_events(value.events)
			)
		)
		and (
			value.terrain_catalog != StadiumSurfaceTerrain.signature("rough")
			or value.leveled_terrain_catalog != StadiumSurfaceTerrain.signature("leveled")
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.FLAG_VERSION
			or (
				(
					value.version == ClubAssetLedger.GROUND_PROPS_VERSION
					or (
						value.version == ClubAssetLedger.STRAIGHT_VERSION
						or value.version == ClubAssetLedger.PENNANT_VERSION
						or value.version == ClubAssetLedger.ROOF_VERSION
						or (
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
																(
																	value.version
																	== ClubAssetLedger.PRACTICE_FACILITY_VERSION
																)
																or (
																	(
																		value.version
																		== ClubAssetLedger.TREEHOUSE_VERSION
																	)
																	or (
																		(
																			value.version
																			== ClubAssetLedger.LANDMARK_VERSION
																		)
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
																						(
																							value
																							. version
																						)
																						== ClubAssetLedger.WALL_TOP_TERRACE_VERSION
																					)
																					or (
																						(
																							(
																								value
																								. version
																							)
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
					)
				)
				and ClubAssetLedger._has_flag_events(value.events)
			)
		)
		and (
			value.flag_catalog != StadiumFlagItems.price_signature()
			or value.flag_layout_catalog != StadiumFlagItems.signature()
			or not ClubAssetLedger._has_flag_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.GROUND_PROPS_VERSION
			or (
				(
					value.version == ClubAssetLedger.STRAIGHT_VERSION
					or value.version == ClubAssetLedger.PENNANT_VERSION
					or value.version == ClubAssetLedger.ROOF_VERSION
					or (
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
															(
																value.version
																== ClubAssetLedger.PRACTICE_FACILITY_VERSION
															)
															or (
																value.version == ClubAssetLedger.TREEHOUSE_VERSION
																or (
																	(
																		value.version
																		== ClubAssetLedger.LANDMARK_VERSION
																	)
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
																						(
																							value
																							. version
																						)
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
				)
				and ClubAssetLedger._has_ground_props_events(value.events)
			)
		)
		and (
			value.ground_props_catalog != StadiumGroundPropsItems.price_signature()
			or value.ground_props_layout_catalog != StadiumGroundPropsItems.signature()
			or not ClubAssetLedger._has_ground_props_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.STRAIGHT_VERSION
			or (
				(
					value.version == ClubAssetLedger.PENNANT_VERSION
					or value.version == ClubAssetLedger.ROOF_VERSION
					or (
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
															(
																value.version
																== ClubAssetLedger.PRACTICE_FACILITY_VERSION
															)
															or (
																value.version == ClubAssetLedger.TREEHOUSE_VERSION
																or (
																	(
																		value.version
																		== ClubAssetLedger.LANDMARK_VERSION
																	)
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
																						(
																							value
																							. version
																						)
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
				)
				and ClubAssetLedger._has_straight_events(value.events)
			)
		)
		and (
			value.straight_catalog != StadiumStraightItems.price_signature()
			or value.straight_layout_catalog != StadiumStraightItems.signature()
			or not ClubAssetLedger._has_straight_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.PENNANT_VERSION
			or (
				(
					value.version == ClubAssetLedger.ROOF_VERSION
					or (
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
															(
																value.version
																== ClubAssetLedger.PRACTICE_FACILITY_VERSION
															)
															or (
																value.version == ClubAssetLedger.TREEHOUSE_VERSION
																or (
																	(
																		value.version
																		== ClubAssetLedger.LANDMARK_VERSION
																	)
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
																						(
																							value
																							. version
																						)
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
				)
				and ClubAssetLedger._has_pennant_events(value.events)
			)
		)
		and (
			value.pennant_catalog != StadiumPennantRewards.signature()
			or not ClubAssetLedger._has_pennant_events(value.events)
		)
	):
		return null
	return ClubAssetLedger._restore_data_stage_5(value, seed_value, credits, progress, championships)
# gdlint: enable=max-returns
