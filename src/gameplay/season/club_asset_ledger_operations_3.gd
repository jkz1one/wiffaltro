extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_restore_data_stage_2(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary,
	keys: Array
) -> ClubAssetLedger:
	if (
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
			)
			and ClubAssetLedger._has_roof_events(value.get("events"))
		)
	):
		keys.append_array(["roof_catalog", "roof_layout_catalog"])
	if (
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
			)
			and ClubAssetLedger._has_facility_events(value.get("events"))
		)
	):
		keys.append_array(["facility_catalog", "facility_layout_catalog"])
	if (
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
			)
			and ClubAssetLedger._has_boundary_events(value.get("events"))
		)
	):
		keys.append_array(["boundary_catalog", "boundary_layout_catalog"])
	if (
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
			and ClubAssetLedger._has_receiver_events(value.get("events"))
		)
	):
		keys.append_array(["receiver_catalog", "receiver_layout_catalog"])
	if (
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
			)
			and ClubAssetLedger._has_floodlight_events(value.get("events"))
		)
	):
		keys.append_array(["floodlight_catalog", "floodlight_layout_catalog"])
	if (
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
															value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
															or (
																(
																	value.version
																	== ClubAssetLedger.STRING_LIGHT_VERSION
																)
																or (
																	value.version == ClubAssetLedger.SALVAGE_VERSION
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
			and ClubAssetLedger._has_landscape_events(value.get("events"))
		)
	):
		keys.append_array(["landscape_catalog", "landscape_layout_catalog"])
	if (
		(value.version == ClubAssetLedger.LIVE_FURNISHING_VERSION or value.version == \
			ClubAssetLedger.SMALL_YARD_SCENERY_VERSION)
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
			and ClubAssetLedger._has_live_furnishing_events(value.get("events"))
		)
	):
		keys.append_array(["live_furnishing_catalog", "live_furnishing_layout_catalog"])
	if (
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
			and ClubAssetLedger._has_small_yard_scenery_events(value.get("events"))
		)
	):
		keys.append("yard_scenery_layout_catalog")
	if (
		value.version == ClubAssetLedger.MOLDED_SEAT_VERSION
		or (
			(
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
			and ClubAssetLedger._has_molded_seat_events(value.get("events"))
		)
	):
		keys.append_array(["molded_seat_catalog", "molded_seat_layout_catalog"])
	if (
		value.version == ClubAssetLedger.GROUND_BOX_VERSION
		or (
			(
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
			and ClubAssetLedger._has_ground_box_events(value.get("events"))
		)
	):
		keys.append_array(["ground_box_catalog", "ground_box_layout_catalog"])
	return ClubAssetLedger._restore_data_stage_3(value, seed_value, credits, progress, \
		championships, keys)
# gdlint: enable=max-returns
