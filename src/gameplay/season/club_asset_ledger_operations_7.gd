extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_restore_data_stage_6(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary
) -> ClubAssetLedger:
	if (
		(
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
				and ClubAssetLedger._has_molded_seat_events(value.events)
			)
		)
		and (
			value.molded_seat_catalog != StadiumMoldedSeatItems.price_signature()
			or value.molded_seat_layout_catalog != StadiumMoldedSeatItems.signature()
			or not ClubAssetLedger._has_molded_seat_events(value.events)
		)
	):
		return null
	if (
		(
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
				and ClubAssetLedger._has_ground_box_events(value.events)
			)
		)
		and (
			value.ground_box_catalog != StadiumGroundBoxItems.price_signature()
			or value.ground_box_layout_catalog != StadiumGroundBoxItems.signature()
			or not ClubAssetLedger._has_ground_box_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
			or (
				(
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
				and ClubAssetLedger._has_practice_facility_events(value.events)
			)
		)
		and (
			value.practice_facility_catalog != StadiumPracticeFacilityItems.price_signature()
			or value.practice_facility_layout_catalog != StadiumPracticeFacilityItems.signature()
			or not ClubAssetLedger._has_practice_facility_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.TREEHOUSE_VERSION
			or (
				(
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
				and ClubAssetLedger._has_treehouse_events(value.events)
			)
		)
		and (
			value.treehouse_catalog != StadiumTreehouseItems.price_signature()
			or value.treehouse_layout_catalog != StadiumTreehouseItems.signature()
			or not ClubAssetLedger._has_treehouse_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.LANDMARK_VERSION
			or (
				(
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
				and ClubAssetLedger._has_landmark_events(value.events)
			)
		)
		and (
			value.landmark_catalog != StadiumLandmarkItems.price_signature()
			or value.landmark_layout_catalog != StadiumLandmarkItems.signature()
			or not ClubAssetLedger._has_landmark_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
			or (
				(
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
				and ClubAssetLedger._has_outfield_bleacher_events(value.events)
			)
		)
		and (
			value.outfield_bleacher_catalog != StadiumOutfieldBleacherItems.price_signature()
			or value.outfield_bleacher_layout_catalog != StadiumOutfieldBleacherItems.signature()
			or not ClubAssetLedger._has_outfield_bleacher_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.RISING_APPLE_VERSION
			or (
				(
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
				and ClubAssetLedger._has_rising_apple_events(value.events)
			)
		)
		and (
			value.rising_apple_catalog != StadiumRisingAppleItems.price_signature()
			or value.rising_apple_layout_catalog != StadiumRisingAppleItems.signature()
			or not ClubAssetLedger._has_rising_apple_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
			or (
				(
					value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
					or (
						value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
						or (
							value.version == ClubAssetLedger.STRING_LIGHT_VERSION
							or (
								value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
									ClubAssetLedger.MASTERY_VERSION
							)
						)
					)
				)
				and ClubAssetLedger._has_wall_top_terrace_events(value.events)
			)
		)
		and (
			value.wall_top_terrace_catalog != StadiumWallTopTerraceItems.price_signature()
			or value.wall_top_terrace_layout_catalog != StadiumWallTopTerraceItems.signature()
			or not ClubAssetLedger._has_wall_top_terrace_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
			or (
				(
					value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
					or (
						value.version == ClubAssetLedger.STRING_LIGHT_VERSION
						or (value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
							ClubAssetLedger.MASTERY_VERSION)
					)
				)
				and ClubAssetLedger._has_player_tunnel_events(value.events)
			)
		)
		and (
			value.player_tunnel_catalog != StadiumPlayerTunnelItems.price_signature()
			or value.player_tunnel_layout_catalog != StadiumPlayerTunnelItems.signature()
			or not ClubAssetLedger._has_player_tunnel_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
			or (
				(
					value.version == ClubAssetLedger.STRING_LIGHT_VERSION
					or (value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
						ClubAssetLedger.MASTERY_VERSION)
				)
				and ClubAssetLedger._has_mounted_display_events(value.events)
			)
		)
		and (
			value.mounted_display_catalog != StadiumMountedDisplayItems.price_signature()
			or value.mounted_display_layout_catalog != StadiumMountedDisplayItems.signature()
			or not ClubAssetLedger._has_mounted_display_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.STRING_LIGHT_VERSION
			or (
				(value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
					ClubAssetLedger.MASTERY_VERSION)
				and ClubAssetLedger._has_string_light_events(value.events)
			)
		)
		and (
			value.string_light_catalog != StadiumStringLightItems.price_signature()
			or value.string_light_layout_catalog != StadiumStringLightItems.signature()
			or not ClubAssetLedger._has_string_light_events(value.events)
		)
	):
		return null
	if (
		(
			value.version == ClubAssetLedger.SALVAGE_VERSION
			or (value.version >= ClubAssetLedger.MASTERY_VERSION and value.has("salvage_origin"))
		)
		and (
			not value.salvage_origin is Dictionary
			or (
				not value.salvage_origin.is_empty()
				and not ClubAssetLedger.valid_salvage_origin(value.salvage_origin)
			)
			or value.salvage_origin_catalog != ClubAssetLedger.salvage_origin_signature()
			or value.salvage_catalog != StadiumSalvageCarItems.price_signature()
			or value.salvage_layout_catalog != StadiumSalvageCarItems.signature()
			or (value.salvage_origin.is_empty() and not ClubAssetLedger._has_salvage_events(value.events))
		)
	):
		return null
	var result: ClubAssetLedger = ClubAssetLedger.new(seed_value, credits, progress, championships)
	if value.version >= 17:
		result._initialize_surface_origin(value.surface_origin)
	if value.has("salvage_origin") and not value.salvage_origin.is_empty():
		if value.surface_origin != StadiumSurfaceProgression.ROUGH_ORIGIN:
			return null
		result._initialize_salvage_origin()
	if not result._valid:
		return null
	result._loading = true
	if not ClubAssetLedger.Journal.replay(
		value.events, value, _event_version_valid, result.commit):
		return null
	result._loading = false
	if (
		(value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
			ClubAssetLedger.MASTERY_VERSION)
		and result.to_data().version != value.version
	):
		return null
	if value.version == ClubAssetLedger.TERRAIN_VERSION and result.to_data().version != \
		ClubAssetLedger.TERRAIN_VERSION:
		return null
	if (
		value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
		and result.to_data().version != ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
	):
		return null
	if value.version == ClubAssetLedger.RISING_APPLE_VERSION and result.to_data().version != \
		ClubAssetLedger.RISING_APPLE_VERSION:
		return null
	if (
		value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
		and result.to_data().version != ClubAssetLedger.WALL_TOP_TERRACE_VERSION
	):
		return null
	if value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION and result.to_data().version != \
		ClubAssetLedger.PLAYER_TUNNEL_VERSION:
		return null
	if value.version == ClubAssetLedger.STRING_LIGHT_VERSION and result.to_data().version != \
		ClubAssetLedger.STRING_LIGHT_VERSION:
		return null
	if (
		value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
		and result.to_data().version != ClubAssetLedger.MOUNTED_DISPLAY_VERSION
	):
		return null
	# New-family headers must be the exact replay result, including optional inherited
	# salvage, mastery and plaque catalogs. Historical readers keep their frozen rules.
	if value.version >= ClubAssetLedger.WATERFALL_VERSION and not ClubCareer.same(result.to_data(), \
		value):
		return null
	return result
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_fork(_source_owner: ClubAssetLedger) -> ClubAssetLedger:
	var ac02_token: int = ClubAssetLedger.AC02_PASSIVE_13.enter("club_asset_ledger.fork")
	var ac02_result: ClubAssetLedger = _source_owner._ac02_passive_13_fork()
	ClubAssetLedger.AC02_PASSIVE_13.leave(ac02_token)
	return ac02_result
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_ac02_passive_13_fork(_source_owner: ClubAssetLedger) -> ClubAssetLedger:
	return ClubAssetLedger.from_data(_source_owner.to_data(), _source_owner._seed, \
		_source_owner._credits, _source_owner._progress, _source_owner._championships)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_with_credits(_source_owner: ClubAssetLedger, credits: Array) -> \
	ClubAssetLedger:
	return ClubAssetLedger.from_data(_source_owner.to_data(), _source_owner._seed, credits, \
		_source_owner._progress, _source_owner._championships)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_preview(_source_owner: ClubAssetLedger, command: Dictionary) -> \
	Dictionary:
	return _source_owner._prepare(command).duplicate(true)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_commit(_source_owner: ClubAssetLedger, command: Dictionary) -> \
	Dictionary:
	var prepared: Dictionary = _source_owner._prepare(command)
	if not prepared.ok or prepared.replayed:
		return prepared.duplicate(true)
	_source_owner._advance_mutation_generation()
	var event: Dictionary = prepared.event
	if event.op == "player_pack_open":
		_source_owner._apply_player_pack(prepared)
	elif event.op in ["stadium_pennant", "stadium_mastery", "stadium_plaque"]:
		_source_owner._stock = StadiumStock.from_data(prepared.stock)
	elif event.op in ["stadium_buy", "stadium_style"]:
		_source_owner._stock = StadiumStock.from_data(prepared.stock)
		_source_owner._spent += prepared.price
		_source_owner._through = event.through
	elif event.op == "stadium_scoreboard":
		_source_owner._stock = StadiumStock.from_data(prepared.stock)
		_source_owner._scoreboards = StadiumScoreboardOwnership.from_data(
			prepared.scoreboards, _source_owner._stock.capacity_count() + \
				_source_owner._wall_pieces.stock.copies.size()
		)
		_source_owner._spent += prepared.price
		_source_owner._through = event.through
	elif event.op == "stadium_wall_piece":
		_source_owner._wall_pieces = StadiumWallPieceOwnership.from_data(
			prepared.wall_pieces, _source_owner._stock.capacity_count() + \
				_source_owner._scoreboards.copies.size()
		)
		_source_owner._spent += prepared.price
		_source_owner._through = event.through
	elif event.op == "stadium_salvage_clear":
		_source_owner._salvage_cleared = true
		_source_owner._stadium_draft = prepared.draft.duplicate(true)
		_source_owner._stadium_active = prepared.active.duplicate(true)
		_source_owner._spent += prepared.price
		_source_owner._through = event.through
	elif event.op == "stadium_surface":
		_source_owner._surface_owned.assign(prepared.surface_owned)
		_source_owner._spent += prepared.price
		_source_owner._through = event.through
	elif event.op == "stadium_land":
		_source_owner._land = event.tier
		_source_owner._spent += prepared.price
		_source_owner._through = event.through
	elif event.op == "stadium_draft":
		_source_owner._stadium_draft = event.layout.duplicate(true)
	elif event.op == "stadium_apply":
		_source_owner._stadium_active = event.layout.duplicate(true)
	else:
		_source_owner._apply_player_pack(prepared)
	ClubAssetLedger.Journal.append(_source_owner._events, _source_owner._requests, event)
	return {"ok": true, "replayed": false, "error": "", "view": _source_owner.view()}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _event_version_valid(value: Dictionary, event: Dictionary) -> bool:
	if value.version < ClubAssetLedger.WATERFALL_ANIMATION_VERSION and \
		ClubAssetLedger._has_waterfall_animation_events([event]):
		return false
	if value.version < ClubAssetLedger.LOW_WALL_VERSION and \
		ClubAssetLedger._has_low_wall_events([event]):
		return false
	if value.version < ClubAssetLedger.LIVE_WATERFALL_VERSION and \
		ClubAssetLedger._has_live_waterfall_events([event]):
		return false
	if value.version < ClubAssetLedger.OUTFIELD_PLAZA_VERSION and \
		ClubAssetLedger._has_outfield_plaza_events([event]):
		return false
	if value.version < ClubAssetLedger.LIGHTING_KIT_VERSION and \
		ClubAssetLedger._has_lighting_kit_events([event]):
		return false
	if value.version < ClubAssetLedger.WATERFALL_VERSION and \
		ClubAssetLedger._has_waterfall_events([event]):
		return false
	if value.version < ClubAssetLedger.PLAQUE_VERSION and ClubAssetLedger._has_plaque_events([event]):
		return false
	if value.version < ClubAssetLedger.MASTERY_VERSION and \
		ClubAssetLedger._has_mastery_events([event]):
		return false
	if value.version < ClubAssetLedger.SALVAGE_VERSION and \
		ClubAssetLedger._has_salvage_events([event]):
		return false
	if value.version < ClubAssetLedger.STRING_LIGHT_VERSION and \
		ClubAssetLedger._has_string_light_events([event]):
		return false
	if value.version < ClubAssetLedger.MOUNTED_DISPLAY_VERSION and \
		ClubAssetLedger._has_mounted_display_events([event]):
		return false
	if value.version < ClubAssetLedger.PLAYER_TUNNEL_VERSION and \
		ClubAssetLedger._has_player_tunnel_events([event]):
		return false
	if value.version < ClubAssetLedger.WALL_TOP_TERRACE_VERSION and \
		ClubAssetLedger._has_wall_top_terrace_events([event]):
		return false
	if value.version < ClubAssetLedger.RISING_APPLE_VERSION and \
		ClubAssetLedger._has_rising_apple_events([event]):
		return false
	if value.version < ClubAssetLedger.OUTFIELD_BLEACHER_VERSION and \
		ClubAssetLedger._has_outfield_bleacher_events([event]):
		return false
	if value.version < ClubAssetLedger.LANDMARK_VERSION and \
		ClubAssetLedger._has_landmark_events([event]):
		return false
	if value.version < ClubAssetLedger.TREEHOUSE_VERSION and \
		ClubAssetLedger._has_treehouse_events([event]):
		return false
	if value.version < ClubAssetLedger.PRACTICE_FACILITY_VERSION and \
		ClubAssetLedger._has_practice_facility_events([event]):
		return false
	if value.version < ClubAssetLedger.GROUND_BOX_VERSION and \
		ClubAssetLedger._has_ground_box_events([event]):
		return false
	if value.version < ClubAssetLedger.MOLDED_SEAT_VERSION and \
		ClubAssetLedger._has_molded_seat_events([event]):
		return false
	if value.version < ClubAssetLedger.SMALL_YARD_SCENERY_VERSION and \
		ClubAssetLedger._has_small_yard_scenery_events([event]):
		return false
	if value.version < ClubAssetLedger.LIVE_FURNISHING_VERSION and \
		ClubAssetLedger._has_live_furnishing_events([event]):
		return false
	if value.version < ClubAssetLedger.LANDSCAPE_VERSION and \
		ClubAssetLedger._has_landscape_events([event]):
		return false
	if value.version < ClubAssetLedger.FLOODLIGHT_VERSION and \
		ClubAssetLedger._has_floodlight_events([event]):
		return false
	if value.version < ClubAssetLedger.RECEIVER_VERSION and \
		ClubAssetLedger._has_receiver_events([event]):
		return false
	if value.version < ClubAssetLedger.BOUNDARY_VERSION and \
		ClubAssetLedger._has_boundary_events([event]):
		return false
	if value.version < ClubAssetLedger.FACILITY_VERSION and \
		ClubAssetLedger._has_facility_events([event]):
		return false
	if value.version < ClubAssetLedger.ROOF_VERSION and ClubAssetLedger._has_roof_events([event]):
		return false
	if value.version < ClubAssetLedger.PENNANT_VERSION and event.get("op") == "stadium_pennant":
		return false
	if value.version < ClubAssetLedger.GROUND_PROPS_VERSION and \
		ClubAssetLedger._has_ground_props_events([event]):
		return false
	if value.version < ClubAssetLedger.FLAG_VERSION and ClubAssetLedger._has_flag_events([event]):
		return false
	if (
		value.version < ClubAssetLedger.STRAIGHT_VERSION
		and (
			(
				event.get("op") == "stadium_buy"
				and event.get("price_version") == StadiumStraightItems.PRICE_VERSION
			)
			or StadiumStraightItems.is_family(event.get("layout"))
		)
	):
		return false
	if value.version < 3 and event.get("op") is String and event.op == "stadium_draft":
		return false
	if value.version < 4 and event.get("op") is String and event.op == "stadium_apply":
		return false
	if value.version < 5 and event.get("op") is String and event.op == "stadium_buy":
		return false
	if (
		value.version < 6
		and (
			event.has("progress_through")
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 2, 2)
			)
		)
	):
		return false
	if value.version < 7 and event.get("op") is String and event.op == "stadium_land":
		return false
	if (
		value.version < 8
		and (
			(event.get("op") is String and event.op == "stadium_style")
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 3, 3)
			)
		)
	):
		return false
	if (
		value.version < 9
		and (
			(
				event.get("op") is String
				and event.op == "stadium_buy"
				and SeasonOwnership._whole(event.get("price_version"), 3, 3)
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 4, 4)
			)
		)
	):
		return false
	if (
		value.version < 10
		and (
			(
				event.get("op") is String
				and event.op == "stadium_style"
				and SeasonOwnership._whole(event.get("price_version"), 2, 2)
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 5, 5)
			)
		)
	):
		return false
	if (
		value.version < 11
		and (
			(
				event.get("op") is String
				and event.op == "stadium_buy"
				and SeasonOwnership._whole(event.get("price_version"), 4, 4)
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 6, 6)
			)
		)
	):
		return false
	if (
		value.version < 12
		and (
			(
				event.get("op") is String
				and event.op == "stadium_buy"
				and SeasonOwnership._whole(event.get("price_version"), 5, 5)
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 7, 7)
			)
		)
	):
		return false
	if (
		value.version < 13
		and (
			(
				event.get("op") is String
				and event.op == "stadium_buy"
				and event.get("price_version") == StadiumPurchases.NET_VERSION
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 8, 8)
			)
		)
	):
		return false
	if (
		value.version < 14
		and (
			(
				event.get("op") is String
				and event.op == "stadium_buy"
				and event.get("price_version") == StadiumPurchases.LIGHT_VERSION
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 9, 9)
			)
		)
	):
		return false
	if (
		value.version < 15
		and (
			(
				event.get("op") is String
				and event.op == "stadium_style"
				and event.get("price_version") == StadiumInfieldStyles.PRICE_VERSION
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 10, 10)
			)
		)
	):
		return false
	if (
		value.version < 16
		and (
			(
				event.get("op") is String
				and event.op == "stadium_buy"
				and SeasonOwnership._whole(event.get("price_version"), 8, 8)
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 11, 11)
			)
		)
	):
		return false
	if (
		value.version < 17
		and (
			event.get("op") == "stadium_surface"
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 12, 12)
			)
		)
	):
		return false
	if (
		value.version < ClubAssetLedger.TERRAIN_VERSION
		and event.get("layout") is Dictionary
		and SeasonOwnership._whole(event.layout.get("version"), 17, 17)
	):
		return false
	if (
		value.version < 23
		and (
			(
				event.get("op") == "stadium_buy"
				and event.get("price_version") == StadiumPurchases.POOL_VERSION
			)
			or (
				event.get("layout") is Dictionary
				and SeasonOwnership._whole(event.layout.get("version"), 16, 16)
			)
		)
	):
		return false
	if (
		value.version < 22
		and event.get("layout") is Dictionary
		and SeasonOwnership._whole(event.layout.get("version"), 15, 15)
	):
		return false
	if (
		value.version < 21
		and event.get("layout") is Dictionary
		and SeasonOwnership._whole(event.layout.get("version"), 14, 14)
	):
		return false
	if value.version < 20 and event.get("op") == "stadium_scoreboard":
		return false
	if value.version < 18 and event.get("op") == "stadium_wall_piece":
		return false
	if (
		value.version < 19
		and event.get("layout") is Dictionary
		and SeasonOwnership._whole(event.layout.get("version"), 13, 13)
	):
		return false
	return true
# gdlint: enable=max-returns
