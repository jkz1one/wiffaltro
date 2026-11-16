extends RefCounted
## Stateless operations for the original StadiumLandscapeOwnedItems script.


static func _public_validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
		)
	):
		return StadiumLiveFurnishingItems.validate(layout, stock, tier)
	if (
		not StadiumLandscapeOwnedItems.is_family(layout)
		or layout.get("family") != StadiumLandscapeOwnedItems.FAMILY
		or not layout.get("landscape") is Array
		or layout.landscape.size() > StadiumLandscapeOwnedItems.SITES.size()
	):
		return StadiumStarterLayout._error("Unknown owned landscape layout or site capacity.")
	var checked: Dictionary = StadiumFloodlightOwnedItems.validate(
		StadiumLandscapeOwnedItems.base(layout), stock, tier
	)
	if not checked.ok:
		return checked
	checked["landscape_placements"] = []
	if layout.landscape.is_empty():
		return checked
	var graph: StadiumRecipeBoundary = StadiumLandscapeOwnedItems.graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error("Landscaping needs a verified complete field boundary.")
	var prior: String = ""
	for raw: Variant in layout.landscape:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, StadiumLandscapeOwnedItems.FIELDS)
			or not raw.copy is String
			or not raw.item is String
			or not raw.site is String
			or not StadiumLandscapeOwnedItems.PRICES.has(raw.item)
			or raw.site not in StadiumLandscapeOwnedItems.sites(raw.item)
			or not StadiumLandscapeOwnedItems._yaw_valid(raw.item, raw.yaw)
			or raw.site <= prior
			or stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or stock.copies[raw.copy].item != raw.item
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"Each landscape site needs one distinct matching paid copy and a supported cardinal "
						+ "orientation."
					)
				)
			)
		if raw.site.begins_with("LAND-") and tier not in ["expanded", "club", "mogul"]:
			return StadiumStarterLayout._error(
				"Ponds and rock gardens need an Expanded or larger landscape pocket."
			)
		var placed: Dictionary = StadiumLandscapeOwnedItems.row(
			raw.copy, raw.item, raw.site, float(raw.yaw)
		)
		var reserve: AABB = (
			StadiumLandscapeOwnedItems._pose(placed)
			* StadiumLandscapeOwnedItems._reservation(placed)
		)
		var pocket: AABB = (
			AABB(placed.position + Vector3(-3, 0, -3), Vector3(6, 2, 6))
			if raw.site.begins_with("LAND-")
			else reserve
		)
		if (
			not StadiumProperty.contains(tier, pocket)
			or not StadiumLandscapeOwnedItems._supported(pocket, layout)
		):
			return StadiumStarterLayout._error(
				raw.site + " needs a complete level, supported reservation inside this property."
			)
		if not StadiumLandscapeOwnedItems._outside_play(placed, graph):
			return (
				StadiumStarterLayout
				. _error(
					(
						raw.site
						+ " is live-reachable; landscaping is supported only beyond the complete terminal boundary."
					)
				)
			)
		for other: Dictionary in checked.placements:
			var reserve_pocket: bool = (
				raw.site.begins_with("LAND-")
				and not StadiumLandscapeOwnedItems.PRICES.has(other.item)
				and not StadiumFloodlightOwnedItems.PRICES.has(other.item)
				and other.item != "ST-037"
			)
			if StadiumLandscapeOwnedItems._overlaps(placed, other, reserve_pocket):
				return StadiumStarterLayout._error(
					(
						raw.site
						+ " conflicts with "
						+ other.site
						+ "; explicitly store one placement first."
					)
				)
		checked.placements.append(placed)
		checked.landscape_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = (
		"Owned landscaping has not been qualified for Night. Store the "
		+ "landscaping to restore the prior lighting layout."
	)
	return checked


static func _supported(box: AABB, layout: Dictionary) -> bool:
	if not StadiumLandscapeOwnedItems.is_terrain(layout):
		return true
	var contract: Dictionary = StadiumLandscapeOwnedItems.terrain_contract(layout)
	if contract.is_empty():
		return false
	for x: float in [box.position.x, box.get_center().x, box.end.x]:
		for z: float in [box.position.z, box.get_center().z, box.end.z]:
			var support: Dictionary = StadiumSurfaceTerrain.support(Vector2(x, z), contract.mode)
			if support.is_empty() or support.support_height != 0.0:
				return false
	return not (
		Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		. intersects(StadiumSurfaceTerrain.PATCH)
	)


static func _corners(placed: Dictionary, box: AABB) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for point: Vector3 in [
		Vector3(box.position.x, 0, box.position.z),
		Vector3(box.end.x, 0, box.position.z),
		Vector3(box.end.x, 0, box.end.z),
		Vector3(box.position.x, 0, box.end.z)
	]:
		var world: Vector3 = StadiumLandscapeOwnedItems._pose(placed) * point
		points.append(Vector2(world.x, world.z))
	return points


static func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return 0.0
	return minf(
		minf(
			a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)),
			b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d))
		),
		minf(
			c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)),
			d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b))
		)
	)


static func _outside_play(placed: Dictionary, graph: StadiumRecipeBoundary) -> bool:
	# The actual graph, including the deep-center choice, owns the terminal boundary.
	# Offset the complete wall reservation with its miter joins, not a world AABB.
	var expanded: Array[PackedVector2Array] = Geometry2D.offset_polygon(
		graph.polygon(), StadiumRecipeBoundary.THICKNESS, Geometry2D.JOIN_MITER
	)
	if expanded.size() != 1:
		return false
	var polygon: PackedVector2Array = expanded[0]
	var center: Vector2 = Vector2(placed.position.x, placed.position.z)
	var reserve_pocket: bool = String(placed.site).begins_with("LAND-")
	var radius: float = 0.0 if reserve_pocket else StadiumLandscapeOwnedItems._radius(placed.item)
	if radius > 0:
		if Geometry2D.is_point_in_polygon(center, polygon):
			return false
		for index in range(polygon.size()):
			if (
				center.distance_to(
					Geometry2D.get_closest_point_to_segment(
						center, polygon[index], polygon[(index + 1) % polygon.size()]
					)
				)
				<= radius + StadiumLandscapeOwnedItems.EPS
			):
				return false
		return true
	var footprint: PackedVector2Array = StadiumLandscapeOwnedItems._corners(
		placed,
		(
			AABB(Vector3(-3, 0, -3), Vector3(6, 2, 6))
			if reserve_pocket
			else StadiumLandscapeOwnedItems._reservation(placed)
		)
	)
	for point: Vector2 in footprint:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return false
	for point: Vector2 in polygon:
		if Geometry2D.is_point_in_polygon(point, footprint):
			return false
	for a in range(footprint.size()):
		for b in range(polygon.size()):
			if (
				StadiumLandscapeOwnedItems._segment_distance(
					footprint[a],
					footprint[(a + 1) % footprint.size()],
					polygon[b],
					polygon[(b + 1) % polygon.size()]
				)
				<= StadiumLandscapeOwnedItems.EPS
			):
				return false
	return true


static func _local_box(placed: Dictionary) -> AABB:
	if StadiumLiveFurnishingItems.PRICES.has(placed.item):
		return StadiumLiveFurnishingModels.reservation(placed.item)
	if StadiumLandscapeOwnedItems.PRICES.has(placed.item):
		return StadiumLandscapeOwnedItems._reservation(placed)
	if StadiumFloodlightOwnedItems.PRICES.has(placed.item):
		var radius: float = StadiumLandscapeOwnedItems._radius(placed.item)
		var height: float = (
			StadiumPremiumLightTowerModels.HEIGHT
			if placed.item == "ST-076"
			else StadiumFourHeadTowerModels.HEIGHT
		)
		return AABB(Vector3(-radius, 0, -radius), Vector3(radius * 2, height, radius * 2))
	if StadiumReceiverOwnedItems.PRICES.has(placed.item):
		return StadiumReceiverOwnedModels.envelope(placed.item)
	if StadiumBoundaryItems.PRICES.has(placed.item):
		return StadiumBoundaryOwnedModels.envelope(placed.item)
	if StadiumFacilityItems.PRICES.has(placed.item):
		return StadiumFacilityOwnedModels.envelope(placed.item)
	if StadiumRoofItems.PRICES.has(placed.item):
		return StadiumRoofOwnedModels.envelope(placed.item, placed.get("roof_state", "lower"))
	if StadiumStraightOwnedModels.ITEMS.has(placed.item) and placed.site != "SCORE-SMALL":
		return StadiumStraightOwnedModels.envelope(placed.item)
	if StadiumGroundPropsItems.PRICES.has(placed.item):
		return StadiumGroundPropsModels.envelope(placed.item)
	if placed.item == "ST-043":
		return StadiumFlagModels.ENVELOPE
	if placed.item == "ST-037":
		return StadiumYardLightModels.ENVELOPE
	if placed.item == "ST-025":
		return StadiumNetModels.ENVELOPE
	if placed.item == "ST-026":
		return StadiumTargetModels.ENVELOPE
	if StadiumPurchases.BLEACHERS.has(placed.item):
		return StadiumBleacherModels.envelope(placed.item)
	if StadiumPurchases.DISPLAYS.has(placed.item):
		return StadiumClubSites.envelope(placed.item)
	if StadiumPurchases.SEATING.has(placed.item):
		return StadiumSeatingLayout.envelope(placed.item)
	return StadiumProperty.layout_bounds(placed.item, Vector3.ZERO)


static func _overlaps(a: Dictionary, b: Dictionary, reserve_pocket: bool = false) -> bool:
	# A LAND pocket reserves its full square against occupied structures; nearby
	# landscaping and lights use the exact physical circle or oriented footprint.
	var ab: AABB = (
		AABB(Vector3(-3, 0, -3), Vector3(6, 2, 6))
		if reserve_pocket
		else StadiumLandscapeOwnedItems._local_box(a)
	)
	var bb: AABB = StadiumLandscapeOwnedItems._local_box(b)
	var at: Transform3D = StadiumLandscapeOwnedItems._pose(a)
	var bt: Transform3D = StadiumLandscapeOwnedItems._pose(b)
	var ac: Vector3 = at * ab.get_center()
	var bc: Vector3 = bt * bb.get_center()
	if absf(ac.y - bc.y) >= (ab.size.y + bb.size.y) * 0.5 - StadiumLandscapeOwnedItems.EPS:
		return false
	var ar: float = 0.0 if reserve_pocket else StadiumLandscapeOwnedItems._radius(a.item)
	var br: float = StadiumLandscapeOwnedItems._radius(b.item)
	if ar > 0 and br > 0:
		return Vector2(ac.x - bc.x, ac.z - bc.z).length() < ar + br - StadiumLandscapeOwnedItems.EPS
	if ar > 0 or br > 0:
		var circle: Vector3 = ac if ar > 0 else bc
		var box: AABB = bb if ar > 0 else ab
		var transform: Transform3D = bt if ar > 0 else at
		var local: Vector3 = transform.affine_inverse() * circle
		var nearest: Vector2 = Vector2(
			clampf(local.x, box.position.x, box.end.x), clampf(local.z, box.position.z, box.end.z)
		)
		return (
			nearest.distance_to(Vector2(local.x, local.z))
			< maxf(ar, br) - StadiumLandscapeOwnedItems.EPS
		)
	for axis: Vector3 in [at.basis.x, at.basis.z, bt.basis.x, bt.basis.z]:
		var a_extent: float = (
			(absf(axis.dot(at.basis.x)) * ab.size.x + absf(axis.dot(at.basis.z)) * ab.size.z) * 0.5
		)
		var b_extent: float = (
			(absf(axis.dot(bt.basis.x)) * bb.size.x + absf(axis.dot(bt.basis.z)) * bb.size.z) * 0.5
		)
		if absf(axis.dot(ac - bc)) >= a_extent + b_extent - StadiumLandscapeOwnedItems.EPS:
			return false
	return true


static func _public_prune(layout: Dictionary) -> Dictionary:
	if (
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
		)
	):
		return StadiumLiveFurnishingItems.prune(layout)
	# Dependency pruning below this channel never grants, removes or remounts landscaping.
	return StadiumLandscapeOwnedItems.with_base(
		layout, StadiumFloodlightOwnedItems.prune(StadiumLandscapeOwnedItems.base(layout))
	)
