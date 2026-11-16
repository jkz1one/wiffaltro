extends RefCounted
## Stateless operations for the original StadiumMoldedSeatItems script.


static func _public_validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
									StadiumPlayerTunnelItems.is_family(layout)
									or (
										StadiumMountedDisplayItems.is_family(layout)
										or (
											StadiumStringLightItems.is_family(layout)
											or (
												StadiumSalvageCarItems.is_family(layout)
												or (
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallLiveItems
																	. is_family(layout)
																)
															)
														)
													)
												)
											)
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
		return StadiumGroundBoxItems.validate(layout, stock, tier)
	if (
		not StadiumMoldedSeatItems.is_family(layout)
		or layout.get("family") != StadiumMoldedSeatItems.FAMILY
		or not layout.get("molded_seats") is Array
		or layout.molded_seats.size() > StadiumMoldedSeatItems.SITES.size()
	):
		return StadiumStarterLayout._error("Unknown molded-seat layout or socket capacity.")
	if tier not in ["expanded", "club", "mogul"]:
		return StadiumStarterLayout._error(
			"The fixed molded-seat pad requires Expanded or larger property."
		)
	var checked: Dictionary = StadiumSmallYardSceneryItems.validate(
		StadiumMoldedSeatItems.base(layout), stock, tier
	)
	if not checked.ok:
		return checked
	var graph: StadiumRecipeBoundary = StadiumMoldedSeatItems.graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error(
			"The molded-seat pad needs a verified complete field boundary."
		)
	for reserve: AABB in StadiumMoldedSeatItems.reservations():
		if (
			not StadiumProperty.contains(tier, reserve)
			or not StadiumMoldedSeatItems._supported(reserve, layout)
			or not StadiumMoldedSeatItems._outside_play(reserve, graph)
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"The complete pad, ramp and approach must remain supported, inside the property and "
						+ "outside live play."
					)
				)
			)
		for other: Dictionary in checked.placements:
			if StadiumMoldedSeatItems._reservation_overlaps(reserve, other):
				return StadiumStarterLayout._error(
					(
						"The molded-seat pad or access conflicts with "
						+ other.site
						+ "; explicitly store that placement before selecting this pad plan."
					)
				)
	checked["molded_seat_placements"] = []
	var prior: String = ""
	for raw: Variant in layout.molded_seats:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, StadiumMoldedSeatItems.FIELDS)
			or not raw.copy is String
			or not raw.site is String
			or not StadiumMoldedSeatItems.SITES.has(raw.site)
			or raw.site <= prior
			or stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or stock.copies[raw.copy].item != "ST-051"
		):
			return (
				StadiumStarterLayout
				. _error(
					"Each empty pad socket needs one distinct exact owned ST-051 copy; store its occupant first."
				)
			)
		var placed: Dictionary = StadiumMoldedSeatItems.row(raw.copy, "ST-051", raw.site)
		var box: AABB = StadiumMoldedSeatItems.bounds(placed)
		if (
			not StadiumProperty.contains(tier, box)
			or box.position.y != StadiumMoldedSeatItems.PAD.end.y
			or box.position.x < StadiumMoldedSeatItems.PAD.position.x
			or box.end.x > StadiumMoldedSeatItems.PAD.end.x
			or box.position.z < 20.0
			or box.end.z > StadiumMoldedSeatItems.PAD.end.z
			or not StadiumMoldedSeatItems._outside_play(box, graph)
		):
			return StadiumStarterLayout._error(
				"The exact seat must fit its pad socket and leave the front access strip clear."
			)
		checked.placements.append(placed)
		checked.molded_seat_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	# The pad remains map infrastructure when all four owned seats are stored.
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "The molded-seat pad plan has not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func _public_prune(layout: Dictionary) -> Dictionary:
	if (
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
									StadiumPlayerTunnelItems.is_family(layout)
									or (
										StadiumMountedDisplayItems.is_family(layout)
										or (
											StadiumStringLightItems.is_family(layout)
											or (
												StadiumSalvageCarItems.is_family(layout)
												or (
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallLiveItems
																	. is_family(layout)
																)
															)
														)
													)
												)
											)
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
		return StadiumGroundBoxItems.prune(layout)
	return StadiumMoldedSeatItems.with_base(
		layout, StadiumSmallYardSceneryItems.prune(StadiumMoldedSeatItems.base(layout))
	)
