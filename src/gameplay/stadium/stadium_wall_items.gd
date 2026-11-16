class_name StadiumWallItems
extends RefCounted
## Versioned complete-wall family. Runtime activation remains gated until fixture acceptance.

const PRICE_VERSION: int = 8
const LAYOUT_VERSION: int = 11
const RUNTIME_READY: bool = true
const PRICES: Dictionary = {
	"ST-022": [280, 25],
	"ST-023": [280, 25],
	"ST-024": [360, 30],
	"ST-065": [520, 35],
	"ST-077": [700, 45],
	"ST-078": [450, 30]
}


static func price_signature() -> String:
	return (
		JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()
	)


static func signature() -> String:
	var graphs: Dictionary = {}
	for shape: String in StadiumWallRecipes.SHAPES:
		graphs[shape] = StadiumRecipeBoundary.create(shape).signature()
	return (
		JSON
		. stringify(
			{
				"version": LAYOUT_VERSION,
				"recipe": StadiumWallRecipes.VERSION,
				"model": StadiumWallPanelModels.VERSION,
				"field": StadiumRecipeFieldStyles.VERSION,
				"manifest": StadiumWallLayout.VERSION,
				"graphs": graphs,
				"spans": StadiumWallPanelModels.LENGTHS
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumInfieldStyles.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 10, 10):
		result.version = LAYOUT_VERSION
		result.family = "reference-wall-recipes-v11"
		result["walls"] = StadiumWallLayout.empty()
	return result


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		not SeasonOwnership._keys(
			layout,
			[
				"version",
				"family",
				"receiver",
				"obstacles",
				"seating",
				"styles",
				"displays",
				"ground",
				"bleachers",
				"target",
				"net",
				"lights",
				"bases",
				"walls"
			]
		)
		or not layout.family is String
		or layout.family != "reference-wall-recipes-v11"
	):
		return StadiumStarterLayout._error("Unknown complete-wall layout.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("walls")
	base.version = 10
	base.family = "reference-infield-v10"
	var result: Dictionary = StadiumHomeLayout.validate(base, stock, tier)
	if not result.ok:
		return result
	var walls: Dictionary = StadiumWallLayout.validate(layout.walls, stock)
	if not walls.ok:
		return walls
	for row: Dictionary in walls.panels:
		var size: Vector3 = StadiumWallPanelModels.dimensions(row.item, row.span)
		var bounds: AABB = (
			StadiumWallRecipes.placement(row) * AABB(Vector3(-size.x / 2, 0, -size.z), size)
		)
		if not StadiumProperty.contains(tier, bounds):
			return StadiumStarterLayout._error(
				"The complete wall supports do not fit this property."
			)
		result.stored.erase(row.copy)
	result["wall_panels"] = walls.panels
	result["wall_shape"] = walls.shape
	result["wall_owned"] = walls.has_paid
	if walls.has_paid:
		result.night_qualified = false
	return result


static func quote(
	stock: StadiumStock, item: String, quantity: int, request: String, progress: Dictionary
) -> Dictionary:
	if stock == null or not PRICES.has(item):
		return ClubAssetLedger._error("This item is not in the complete-wall catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The complete-wall quote changed; reload before purchasing.")
	return result


static func uses_recipe(layout: Dictionary) -> bool:
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
		return uses_recipe(StadiumReceiverOwnedItems.base(layout))
	if StadiumBoundaryItems.is_family(layout):
		return uses_recipe(StadiumBoundaryItems.base(layout))
	if StadiumFacilityItems.is_family(layout):
		return uses_recipe(StadiumFacilityItems.base(layout))
	if StadiumRoofItems.is_family(layout):
		return uses_recipe(StadiumRoofItems.base(layout))
	if StadiumStraightItems.is_family(layout):
		return uses_recipe(StadiumStraightItems.base(layout))
	if StadiumGroundPropsItems.is_family(layout):
		return uses_recipe(StadiumGroundPropsItems.base(layout))
	if StadiumFlagItems.is_family(layout):
		var original: Dictionary = StadiumFlagItems.base(layout)
		return uses_recipe(
			(
				StadiumSurfaceLayout.terrain_base(original)
				if StadiumFlagItems.is_terrain(layout)
				else original
			)
		)
	if SeasonOwnership._whole(layout.get("version"), 12, 12):
		return uses_recipe(StadiumSurfaceLayout.base(layout))
	if (
		not SeasonOwnership._whole(layout.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
		or not layout.get("walls") is Dictionary
	):
		return false
	var walls: Dictionary = layout.walls
	return (
		walls.get("back") is Dictionary
		and walls.get("left") is Array
		and walls.get("right") is Array
		and (not walls.back.is_empty() or not walls.left.is_empty() or not walls.right.is_empty())
	)


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	if not uses_recipe(layout):
		return null
	var shape: Variant = layout.walls.back.get("shape", "straight")
	return StadiumRecipeBoundary.create(shape) if shape is String else null


static func boundary_signature(layout: Dictionary) -> String:
	if not uses_recipe(layout):
		return StadiumBoundaryGraph.signature()
	var graph: StadiumRecipeBoundary = graph_for(layout)
	return "" if graph == null else graph.signature()


static func apply(
	property: StadiumPropertyGeometry, layout: Dictionary, stock: StadiumStock
) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(property):
		return false
	if not StadiumInfieldStyles.apply(property, layout, stock):
		return false
	if not uses_recipe(layout):
		return true
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if (
		graph == null
		or not StadiumRecipeFieldStyles.apply(property, graph, layout.styles, layout.ground, stock)
	):
		return false
	property.set_meta("wall_selection", layout.walls.duplicate(true))
	property.set_meta("wall_stock", stock.to_data())
	return true
