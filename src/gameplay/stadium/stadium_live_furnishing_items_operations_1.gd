extends RefCounted
## Stateless operations for the original StadiumLiveFurnishingItems script.


static func _public_validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumSmallYardSceneryItems.is_family(layout)
		or (
			StadiumMoldedSeatItems.is_family(layout)
			or (
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
															StadiumMasteryBannerItems.is_family(
																layout
															)
															or (
																StadiumWaterfallItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumLightingKitItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumOutfieldPlazaItems
																			. is_family(layout)
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
			)
		)
	):
		return StadiumSmallYardSceneryItems.validate(layout, stock, tier)
	if (
		not StadiumLiveFurnishingItems.is_family(layout)
		or layout.get("family") != StadiumLiveFurnishingItems.FAMILY
		or not layout.get("live_furnishings") is Array
		or layout.live_furnishings.size() > StadiumLiveFurnishingItems.SITES.size()
	):
		return StadiumStarterLayout._error("Unknown fixed furnishing layout or site capacity.")
	var checked: Dictionary = StadiumLandscapeOwnedItems.validate(
		StadiumLiveFurnishingItems.base(layout), stock, tier
	)
	if not checked.ok:
		return checked
	checked["live_furnishing_placements"] = []
	if layout.live_furnishings.is_empty():
		return checked
	var graph: StadiumRecipeBoundary = StadiumLiveFurnishingItems.graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error("Furnishings need a verified complete field boundary.")
	var occupied: Dictionary = {}
	var live_rows: Array[Dictionary] = []
	for placed: Dictionary in checked.placements:
		occupied[placed.site] = placed
		if placed.role == "LIVE_RICOCHET":
			live_rows.append(placed)
	var prior: String = ""
	for raw: Variant in layout.live_furnishings:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, StadiumLiveFurnishingItems.FIELDS)
			or not raw.copy is String
			or not raw.item is String
			or not raw.site is String
			or not SeasonOwnership._whole(raw.yaw, 0, 0)
			or not StadiumLiveFurnishingItems.PRICES.has(raw.item)
			or raw.site not in StadiumLiveFurnishingItems.sites(raw.item)
			or raw.site <= prior
			or occupied.has(raw.site)
			or stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or stock.copies[raw.copy].item != raw.item
		):
			return (
				StadiumStarterLayout
				. _error(
					"Each furnishing needs one distinct matching paid copy and one explicit compatible site."
				)
			)
		if raw.site.begins_with("YL-") and tier not in ["expanded", "club", "mogul"]:
			return StadiumStarterLayout._error(
				"Yard hot tubs need an Expanded or larger large-object pocket."
			)
		var placed: Dictionary = StadiumLiveFurnishingItems.row(raw.copy, raw.item, raw.site)
		var reserve: AABB = (
			StadiumLiveFurnishingItems._pose(placed)
			* StadiumLiveFurnishingModels.reservation(raw.item)
		)
		var pocket: AABB = (
			AABB(placed.position + Vector3(-3, 0, -4), Vector3(6, 3.5, 8))
			if raw.site.begins_with("YL-")
			else reserve
		)
		if (
			not StadiumProperty.contains(tier, pocket)
			or not StadiumLiveFurnishingItems._supported(pocket, layout)
		):
			return StadiumStarterLayout._error(
				raw.site + " needs its full level supported reservation inside this property."
			)
		if StadiumLiveFurnishingItems.is_live_site(raw.site):
			if not StadiumLiveFurnishingItems._inside_play(placed, reserve, graph):
				return StadiumStarterLayout._error(
					raw.site + " does not clear this field's physical boundary and scoring rays."
				)
			live_rows.append(placed)
		elif not StadiumLiveFurnishingItems._outside_play(placed, graph):
			return StadiumStarterLayout._error(raw.site + " must stay wholly outside live play.")
		for other: Dictionary in checked.placements:
			if StadiumLiveFurnishingItems._overlaps(placed, other):
				return StadiumStarterLayout._error(
					(
						raw.site
						+ " conflicts with "
						+ other.site
						+ "; explicitly store one placement first."
					)
				)
		checked.placements.append(placed)
		checked.live_furnishing_placements.append(placed)
		checked.stored.erase(raw.copy)
		occupied[raw.site] = placed
		prior = raw.site
	var items: Array[String] = []
	var units: int = 0
	for placed: Dictionary in live_rows:
		items.append(placed.item)
		units += int(StadiumCatalog.LIVE_UNITS.get(placed.item, 100))
	if not StadiumCatalog.within_live_budget(items):
		return StadiumStarterLayout._error(
			"Live obstacles allow at most four instances and four capacity units."
		)
	for side: String in ["L", "R"]:
		if (
			occupied.has("OM-" + side)
			and (occupied.has("O-" + side + "1") or occupied.has("O-" + side + "2"))
		):
			return StadiumStarterLayout._error(
				"The medium site requires both same-side small sites clear."
			)
	for placed: Dictionary in live_rows:
		if placed.item != "ST-007":
			continue
		for other: Dictionary in live_rows:
			if (
				other.copy != placed.copy
				and (
					other.site != StadiumLiveFurnishingItems.COMPANIONS.get(placed.site, "")
					or other.item not in StadiumLiveFurnishingItems.SMALL
				)
			):
				return (
					StadiumStarterLayout
					. _error(
						"A live hot tub allows only one small object at its approved opposite-side O2 site."
					)
				)
	checked.live_units = units
	checked.night_qualified = false
	checked["night_unqualified_reason"] = (
		"Fixed live and yard furnishings have not been qualified for Night. "
		+ "Store them to restore the prior lighting layout."
	)
	return checked


static func _public_prune(layout: Dictionary) -> Dictionary:
	if (
		StadiumSmallYardSceneryItems.is_family(layout)
		or (
			StadiumMoldedSeatItems.is_family(layout)
			or (
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
															StadiumMasteryBannerItems.is_family(
																layout
															)
															or (
																StadiumWaterfallItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumLightingKitItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumOutfieldPlazaItems
																			. is_family(layout)
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
			)
		)
	):
		return StadiumSmallYardSceneryItems.prune(layout)
	return StadiumLiveFurnishingItems.with_base(
		layout, StadiumLandscapeOwnedItems.prune(StadiumLiveFurnishingItems.base(layout))
	)
