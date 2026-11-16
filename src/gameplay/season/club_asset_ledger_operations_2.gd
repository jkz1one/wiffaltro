extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_ac02_passive_13_from_data(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array = [],
	championships: Dictionary = {}
) -> ClubAssetLedger:
	if (
		not value is Dictionary
		or not SeasonOwnership._whole(value.get("version"), 1, \
			ClubAssetLedger.WATERFALL_ANIMATION_VERSION)
	):
		return null
	var keys: Array = ["version", "seed", "catalog", "events"]
	if value.get("version") >= 2:
		keys.append_array(["starter_grant", "starter_catalog"])
	if value.version >= 3:
		keys.append("draft_catalog")
	if value.version >= 4:
		keys.append("property_catalog")
	if value.version >= 5:
		keys.append("construction_catalog")
	if value.version >= 6:
		keys.append_array(["seating_catalog", "seating_layout_catalog"])
	if value.version >= 7:
		keys.append("land_catalog")
	if value.version >= 8:
		keys.append_array(["style_catalog", "appearance_catalog"])
	if value.version >= 9:
		keys.append_array(["display_catalog", "display_layout_catalog"])
	if value.version >= 10:
		keys.append_array(["ground_catalog", "ground_layout_catalog"])
	if value.version >= 11:
		keys.append_array(["bleacher_catalog", "bleacher_layout_catalog"])
	if value.version >= 12:
		keys.append_array(["target_catalog", "target_layout_catalog"])
	if value.version >= 13:
		keys.append_array(["net_catalog", "net_layout_catalog"])
	if value.version >= 14:
		keys.append_array(["light_catalog", "light_layout_catalog"])
	if value.version >= 15:
		keys.append_array(["infield_catalog", "infield_layout_catalog"])
	if value.version >= 16:
		keys.append_array(["wall_catalog", "wall_layout_catalog"])
	if value.version >= 17:
		keys.append_array(["surface_catalog", "surface_origin", "surface_layout_catalog"])
	if value.version >= 18:
		keys.append("wall_piece_catalog")
	if value.version >= 19:
		keys.append("advanced_layout_catalog")
	if value.version >= 20:
		keys.append("scoreboard_catalog")
	if value.version >= 21:
		keys.append("scoreboard_layout_catalog")
	if value.version >= 22:
		keys.append("mounted_scoreboard_layout_catalog")
	if value.version >= 23:
		keys.append_array(["pool_catalog", "pool_layout_catalog"])
	if (
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
			)
			and ClubAssetLedger._has_terrain_events(value.get("events"))
		)
	):
		keys.append_array(["terrain_catalog", "leveled_terrain_catalog"])
	if (
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
			)
			and ClubAssetLedger._has_flag_events(value.get("events"))
		)
	):
		keys.append_array(["flag_catalog", "flag_layout_catalog"])
	if (
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
			)
			and ClubAssetLedger._has_ground_props_events(value.get("events"))
		)
	):
		keys.append_array(["ground_props_catalog", "ground_props_layout_catalog"])
	if (
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
			)
			and ClubAssetLedger._has_straight_events(value.get("events"))
		)
	):
		keys.append_array(["straight_catalog", "straight_layout_catalog"])
	if (
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
			)
			and ClubAssetLedger._has_pennant_events(value.get("events"))
		)
	):
		keys.append("pennant_catalog")
	return ClubAssetLedger._restore_data_stage_2(value, seed_value, credits, progress, \
		championships, keys)
# gdlint: enable=max-returns
