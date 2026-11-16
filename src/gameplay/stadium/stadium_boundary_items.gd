class_name StadiumBoundaryItems
extends RefCounted
## Exact paid boundary objects. Legacy recipes remain immutable; removals never mint stock.

const VERSION: int = 1
const PRICE_VERSION: int = 15
const LAYOUT_VERSION: int = 23
const FAMILY: String = "reference-boundary-v23"
const PRICES: Dictionary = {
	"ST-032": [420, 130],
	"ST-074": [500, 140],
	"ST-021": [280, 90],
	"ST-064": [180, 35],
	"ST-020": [200, 25],
	"ST-071": [280, 35]
}
const DUGOUTS: Array[String] = ["ST-032", "ST-074"]
const FENCES: Array[String] = ["ST-020", "ST-071"]
const FIELDS: Array[String] = ["copy", "item", "site", "host"]

const Operations1: GDScript = preload(
	"res://src/gameplay/stadium/stadium_boundary_items_operations_1.gd"
)


static func price_signature() -> String:
	return (
		JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()
	)


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 22,
				"models": StadiumBoundaryOwnedModels.VERSION,
				"side_copies": [19, 16, 3],
				"rear": [8, 2, 1.2, 0.35],
				"panel": [1.4, 0.55],
				"timber_backyard": true,
				"concrete_expanded": true,
				"entry": "actual-aperture-earns-minimum-single-foul-stays-foul"
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func quote(
	stock: StadiumStock, item: String, quantity: int, request: String, progress: Dictionary
) -> Dictionary:
	if stock == null or not PRICES.has(item):
		return ClubAssetLedger._error("This item is not in the boundary object catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The boundary quote changed; reload before purchasing.")
	return result


static func is_family(layout: Variant) -> bool:
	return (
		layout is Dictionary
		and SeasonOwnership._whole(layout.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	return Operations1._public_upgrade(layout, access)


static func _dugout(layout: Dictionary, left: bool) -> Dictionary:
	for raw: Variant in layout.get("boundary", []):
		if raw is Dictionary and raw.get("site") == ("DUGOUT-L" if left else "DUGOUT-R"):
			return raw
	return {}


static func base(layout: Dictionary) -> Dictionary:
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
		return base(StadiumReceiverOwnedItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumFacilityItems.LAYOUT_VERSION
	result.family = StadiumFacilityItems.FAMILY
	result.erase("boundary")
	# The old nineteen-copy validator is untouched. The new cut runs validate below.
	for left: bool in [true, false]:
		if not _dugout(layout, left).is_empty() and result.get("walls") is Dictionary:
			result.walls["left" if left else "right"] = []
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
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
		return StadiumReceiverOwnedItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("boundary") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumFacilityItems.is_family(original)
		else StadiumFacilityItems.with_base(base(layout), original)
	)
	if not StadiumFacilityItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["boundary"] = layout.boundary.duplicate(true)
	for left: bool in [true, false]:
		if not _dugout(layout, left).is_empty():
			var side: String = "left" if left else "right"
			result.walls[side] = layout.walls[side].duplicate()
	return result


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumFacilityItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumFacilityItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumFacilityItems.contacts_layout(base(layout)))


static func geometry(tier: String, layout: Dictionary) -> String:
	return (
		JSON
		. stringify(
			{"base": StadiumFacilityItems.geometry(tier, base(layout)), "boundary": signature()},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func graph_for(layout: Dictionary) -> StadiumBoundaryOwnedGraph:
	return StadiumBoundaryOwnedGraph.create_owned(layout)


static func sites(item: String) -> Array[String]:
	var result: Array[String] = []
	if item in DUGOUTS:
		result.assign(["DUGOUT-L", "DUGOUT-R"])
	elif item == "ST-021":
		result.assign(["FOUL-POLE-L", "FOUL-POLE-R"])
	elif item in FENCES:
		for index in range(8):
			result.append("REAR-%02d" % index)
	return result


static func panel_host_rows(layout: Dictionary, stock: StadiumStock) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var checked: Dictionary = StadiumWallLayout.validate(base(layout).get("walls", {}), stock)
	if checked.ok:
		for row: Dictionary in checked.panels:
			if row.item in StadiumWallRecipes.BACK_IDS and row.span == "full":
				result.append(row)
	return result


static func bounds(row: Dictionary) -> AABB:
	return (
		Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position)
		* StadiumBoundaryOwnedModels.envelope(row.item)
	)


static func validate(
	layout: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	return Operations1._public_validate(layout, stock, tier)


static func _supported(row: Dictionary, layout: Dictionary) -> bool:
	if not is_terrain(layout):
		return true
	var contract: Dictionary = terrain_contract(layout)
	if contract.is_empty():
		return false
	var box: AABB = StadiumBoundaryOwnedModels.envelope(row.item)
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position)
	for x: float in [box.position.x, box.end.x]:
		for z: float in [box.position.z, box.end.z]:
			var point: Vector3 = pose * Vector3(x, 0, z)
			var support: Dictionary = StadiumSurfaceTerrain.support(
				Vector2(point.x, point.z), contract.mode
			)
			if support.is_empty() or support.support_height != 0.0:
				return false
	return true


static func _overlaps(a: Dictionary, b: Dictionary) -> bool:
	var ab: AABB = StadiumBoundaryOwnedModels.envelope(a.item)
	var bb: AABB = (
		StadiumBoundaryOwnedModels.envelope(b.item)
		if PRICES.has(b.item)
		else StadiumFacilityItems._local_box(b)
	)
	var at: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(a.yaw))), a.position)
	var bt: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(b.yaw))), b.position)
	var ac: Vector3 = at * ab.get_center()
	var bc: Vector3 = bt * bb.get_center()
	if absf(ac.y - bc.y) >= (ab.size.y + bb.size.y) * 0.5 - 0.0001:
		return false
	for axis: Vector3 in [at.basis.x, at.basis.z, bt.basis.x, bt.basis.z]:
		var ar: float = (
			(absf(axis.dot(at.basis.x)) * ab.size.x + absf(axis.dot(at.basis.z)) * ab.size.z) * 0.5
		)
		var br: float = (
			(absf(axis.dot(bt.basis.x)) * bb.size.x + absf(axis.dot(bt.basis.z)) * bb.size.z) * 0.5
		)
		if absf(axis.dot(ac - bc)) >= ar + br - 0.0001:
			return false
	return true


static func options(layout: Dictionary, stock: StadiumStock, item: String, tier: String) -> Array:
	return Operations1._public_options(layout, stock, item, tier)


static func select(
	layout: Dictionary, stock: StadiumStock, copy: String, placement: Dictionary
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
		return StadiumReceiverOwnedItems.with_base(
			layout, select(StadiumReceiverOwnedItems.base(layout), stock, copy, placement)
		)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result) or not stock.copies.has(copy):
		return result
	var item: String = stock.copies[copy].item
	if item in FENCES:
		return select_rear(result, stock, "" if placement.is_empty() else item)
	var old: Dictionary = {}
	for entry: Dictionary in result.boundary:
		if entry.copy == copy:
			old = entry
	result.boundary = result.boundary.filter(
		func(entry: Dictionary) -> bool: return entry.copy != copy
	)
	if (
		not old.is_empty()
		and old.site.begins_with("DUGOUT")
		and (placement.is_empty() or placement.site != old.site)
	):
		result.walls["left" if old.site == "DUGOUT-L" else "right"] = []
	if not placement.is_empty():
		var existing: Dictionary = (
			_dugout(result, placement.site == "DUGOUT-L") if item in DUGOUTS else {}
		)
		if item in DUGOUTS and existing.is_empty():
			var left: bool = placement.site == "DUGOUT-L"
			var side: String = "left" if left else "right"
			var ids: Array = result.walls[side]
			if ids.size() == 19:
				var kept: Array = []
				var full: Array[Dictionary] = StadiumWallRecipes.side(left)
				var cut: Array[Dictionary] = StadiumDugoutRecipe.panels(left)
				for index in range(full.size()):
					if cut.has(full[index]):
						kept.append(ids[index])
				result.walls[side] = kept
		result.boundary = result.boundary.filter(
			func(entry: Dictionary) -> bool: return entry.site != placement.site
		)
		var next: Dictionary = placement.duplicate(true)
		next.copy = copy
		next.item = item
		result.boundary.append(next)
	result.boundary.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	return prune(result)


static func restore_side(
	layout: Dictionary, stock: StadiumStock, left: bool, copies: Array
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
		var restored: Dictionary = restore_side(
			StadiumReceiverOwnedItems.base(layout), stock, left, copies
		)
		if restored.ok:
			restored.layout = StadiumReceiverOwnedItems.with_base(layout, restored.layout)
		return restored
	var result: Dictionary = layout.duplicate(true)
	var side: String = "left" if left else "right"
	if (
		not is_family(result)
		or _dugout(result, left).is_empty()
		or result.walls[side].size() != 16
		or copies.size() != 3
	):
		return StadiumStarterLayout._error(
			"Explicit restoration needs sixteen placed and three matching stored owned panels."
		)
	var checked: Dictionary = validate(result, stock, "mogul")
	if not checked.ok:
		return checked
	var ids: Array = result.walls[side].duplicate()
	for copy: Variant in copies:
		if (
			not copy is String
			or not checked.stored.has(copy)
			or ids.has(copy)
			or stock.copies[copy].item != StadiumWallLayout.SIDES[side]
		):
			return StadiumStarterLayout._error(
				"Restoration requires three distinct matching owned panel copies."
			)
		ids.append(copy)
	ids.sort()
	result.walls[side] = ids
	result.boundary = result.boundary.filter(
		func(entry: Dictionary) -> bool: return entry.site != ("DUGOUT-L" if left else "DUGOUT-R")
	)
	return {"ok": true, "error": "", "layout": prune(result)}


static func select_rear(layout: Dictionary, stock: StadiumStock, item: String) -> Dictionary:
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
		return StadiumReceiverOwnedItems.with_base(
			layout, select_rear(StadiumReceiverOwnedItems.base(layout), stock, item)
		)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result) or (not item.is_empty() and item not in FENCES):
		return result
	var ids: Array[String] = []
	if not item.is_empty():
		for copy: String in stock.copies:
			if stock.copies[copy].item == item:
				ids.append(copy)
		ids.sort()
		if ids.size() < 8:
			return result
	result.boundary = result.boundary.filter(
		func(entry: Dictionary) -> bool: return not entry.site.begins_with("REAR-")
	)
	if not item.is_empty():
		for index in range(8):
			result.boundary.append(
				{"copy": ids[index], "item": item, "site": "REAR-%02d" % index, "host": ""}
			)
	result.boundary.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	return result


static func prune(layout: Dictionary) -> Dictionary:
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
		return StadiumReceiverOwnedItems.prune(layout)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result):
		return result
	result = with_base(result, StadiumFacilityItems.prune(base(result)))
	var hosts: Array = result.walls.back.get("copies", [])
	result.boundary = result.boundary.filter(
		func(entry: Dictionary) -> bool: return entry.host.is_empty() or hosts.has(entry.host)
	)
	return result
