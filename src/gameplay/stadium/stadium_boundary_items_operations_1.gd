extends RefCounted
## Stateless operations for the original StadiumBoundaryItems script.


static func _public_upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if (
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
															StadiumPlayerTunnelItems.is_family(
																layout
															)
															or (
																(
																	StadiumMountedDisplayItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumStringLightItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumSalvageCarItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumMasteryBannerItems
																				. is_family(layout)
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
	):
		return layout.duplicate(true)
	if StadiumBoundaryItems.is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumFacilityItems.upgrade(layout, access)
	if not StadiumFacilityItems.is_family(result):
		return {}
	result.version = StadiumBoundaryItems.LAYOUT_VERSION
	result.family = StadiumBoundaryItems.FAMILY
	result["boundary"] = []
	return result


static func _public_validate(
	layout: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	if (
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
															StadiumPlayerTunnelItems.is_family(
																layout
															)
															or (
																(
																	StadiumMountedDisplayItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumStringLightItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumSalvageCarItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumMasteryBannerItems
																				. is_family(layout)
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
	):
		return StadiumReceiverOwnedItems.validate(layout, stock, tier)
	if (
		not StadiumBoundaryItems.is_family(layout)
		or layout.get("family") != StadiumBoundaryItems.FAMILY
		or not layout.get("boundary") is Array
		or layout.boundary.size() > 40
	):
		return StadiumStarterLayout._error("Unknown boundary object layout or capacity.")
	var checked: Dictionary = StadiumFacilityItems.validate(
		StadiumBoundaryItems.base(layout), stock, tier
	)
	if not checked.ok:
		return checked
	var wall_check: Dictionary = {"used": [], "panels": []}
	for left: bool in [true, false]:
		if StadiumBoundaryItems._dugout(layout, left).is_empty():
			continue
		var side: String = "left" if left else "right"
		if not layout.walls[side] is Array:
			return StadiumStarterLayout._error(
				"A dugout side needs its exact remaining wall manifest."
			)
		if (
			not layout.walls[side].is_empty()
			and not StadiumWallLayout._copies(
				layout.walls[side], StadiumDugoutRecipe.panels(left), stock, wall_check
			)
		):
			return (
				StadiumStarterLayout
				. _error(
					"A cut side needs sixteen exact handed owned panels; the three removed copies stay stored."
				)
			)
	for row: Dictionary in wall_check.panels:
		if not checked.stored.has(row.copy):
			return StadiumStarterLayout._error("A wall copy cannot serve two placements.")
		checked.stored.erase(row.copy)
		checked.wall_panels.append(row)
	var hosts: Dictionary = {}
	for row: Dictionary in StadiumBoundaryItems.panel_host_rows(layout, stock):
		hosts[row.copy] = row
	var graph: StadiumBoundaryOwnedGraph = StadiumBoundaryItems.graph_for(layout)
	var poles: Dictionary = {}
	for row: Dictionary in StadiumFoulPoleSites.rows(graph):
		poles[row.site] = row
	var prior: String = ""
	var rear: Array = []
	var added: Array = []
	for raw: Variant in layout.boundary:
		if not raw is Dictionary or not SeasonOwnership._keys(raw, StadiumBoundaryItems.FIELDS):
			return StadiumStarterLayout._error(
				"Each boundary object needs exact copy, site and host fields."
			)
		for field: String in StadiumBoundaryItems.FIELDS:
			if not raw[field] is String:
				return StadiumStarterLayout._error(
					"Boundary object references must be exact strings."
				)
		if raw.site <= prior or not checked.stored.has(raw.copy):
			return StadiumStarterLayout._error(
				"Boundary sites are unique and use distinct owned copies."
			)
		var item: String = stock.copies[raw.copy].item
		if not StadiumBoundaryItems.PRICES.has(item) or raw.item != item:
			return StadiumStarterLayout._error("The selected copy is not a boundary object.")
		var pose: Transform3D = Transform3D.IDENTITY
		var row: Dictionary = raw.duplicate(true)
		row.merge({"item": item, "role": "BOUNDARY_OWNED"})
		if item in StadiumBoundaryItems.DUGOUTS:
			if (
				raw.site not in StadiumBoundaryItems.sites(item)
				or not raw.host.is_empty()
				or (item == "ST-074" and tier == "backyard")
			):
				return StadiumStarterLayout._error(
					"Timber fits Backyard and larger; concrete needs Expanded or larger."
				)
			var left: bool = raw.site == "DUGOUT-L"
			pose = StadiumDugoutRecipe.placement(left)
			for old: Dictionary in checked.placements:
				if old.item == "ST-052" and old.site == ("BOX-L" if left else "BOX-R"):
					return StadiumStarterLayout._error(
						"Store the same-side owner's box or dugout first."
					)
		elif item == "ST-021":
			if not poles.has(raw.site) or not raw.host.is_empty():
				return StadiumStarterLayout._error(
					"A foul pole needs its graph-derived left or right socket."
				)
			pose.origin = poles[raw.site].position
			row["split"] = poles[raw.site].split
		elif item == "ST-064":
			if not hosts.has(raw.host) or raw.site != "DISTANCE:" + raw.host:
				return StadiumStarterLayout._error(
					"Mount the panel on an explicit full two-metre owned back-wall copy."
				)
			pose = StadiumWallRecipes.placement(hosts[raw.host])
			row["distance_m"] = Vector2(pose.origin.x, pose.origin.z).length()
			row["host_span"] = "full"
			pose.origin.y = 1.8
			row.role = "BACK_WALL_TERMINAL"
		elif item in StadiumBoundaryItems.FENCES:
			if raw.site not in StadiumBoundaryItems.sites(item) or not raw.host.is_empty():
				return StadiumStarterLayout._error(
					"Rear fencing occupies eight exact two-metre sockets."
				)
			var index: int = int(raw.site.trim_prefix("REAR-"))
			pose.origin = Vector3(-7 + index * 2, 0, -6)
			row["index"] = index
			rear.append(item)
		row["position"] = pose.origin
		row["yaw"] = rad_to_deg(pose.basis.get_euler().y)
		if (
			not StadiumProperty.contains(tier, StadiumBoundaryItems.bounds(row))
			or not StadiumBoundaryItems._supported(row, layout)
		):
			return (
				StadiumStarterLayout
				. _error(
					"The complete boundary object needs supported property and level pads at ground zero."
				)
			)
		for old: Dictionary in checked.placements + added:
			if (
				item == "ST-064"
				or old.item == "ST-064"
				or (item in StadiumBoundaryItems.FENCES and old.item in StadiumBoundaryItems.FENCES)
			):
				continue
			if StadiumBoundaryItems._overlaps(row, old):
				return StadiumStarterLayout._error(
					"Store the conflicting object before placing this boundary object."
				)
		checked.stored.erase(raw.copy)
		added.append(row)
		prior = raw.site
	if not rear.is_empty() and (rear.size() != 8 or rear.count(rear[0]) != 8):
		return (
			StadiumStarterLayout
			. _error(
				"The rear replacement requires eight matching owned modules; partial stock stays stored."
			)
		)
	checked.placements.append_array(added)
	checked["boundary_placements"] = added
	return checked


static func _public_options(
	layout: Dictionary, stock: StadiumStock, item: String, tier: String
) -> Array:
	if (
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
															StadiumPlayerTunnelItems.is_family(
																layout
															)
															or (
																(
																	StadiumMountedDisplayItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumStringLightItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumSalvageCarItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumMasteryBannerItems
																				. is_family(layout)
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
	):
		return StadiumBoundaryItems.options(
			StadiumReceiverOwnedItems.base(layout), stock, item, tier
		)
	var result: Array = []
	if not StadiumBoundaryItems.is_family(layout) or not StadiumBoundaryItems.PRICES.has(item):
		return result
	if item == "ST-074" and tier == "backyard":
		return result
	if item == "ST-064":
		for host: Dictionary in StadiumBoundaryItems.panel_host_rows(layout, stock):
			result.append(
				{
					"label": host.socket + " • exact " + host.copy,
					"row":
					{"copy": "", "item": item, "site": "DISTANCE:" + host.copy, "host": host.copy}
				}
			)
	elif item not in StadiumBoundaryItems.FENCES:
		for site: String in StadiumBoundaryItems.sites(item):
			result.append(
				{"label": site, "row": {"copy": "", "item": item, "site": site, "host": ""}}
			)
	return result
