class_name StadiumLayoutSnapshot
extends RefCounted
## Immutable season-entry geometry and owned-layout binding; shape validation never grants objects.

const VERSION: int = 9
const TERRAIN_VERSION: int = 28
const TERRAIN_FIXTURE_VERSION: int = 29

const Operations1: GDScript = preload(
	"res://src/gameplay/stadium/stadium_layout_snapshot_operations_1.gd"
)

const Operations2: GDScript = preload(
	"res://src/gameplay/stadium/stadium_layout_snapshot_operations_2.gd"
)

const Operations3: GDScript = preload(
	"res://src/gameplay/stadium/stadium_layout_snapshot_operations_3.gd"
)


static func capture(ledger: ClubAssetLedger, complete_boundary: bool = true) -> Dictionary:
	return Operations3._public_capture(ledger, complete_boundary)


static func valid(value: Variant, stock: StadiumStock = null) -> bool:
	if StadiumWaterfallAnimationSnapshot.is_family(value):
		return (
			StadiumWaterfallAnimationSnapshot.valid(value)
			and (stock == null or ClubCareer.same(stock.to_data(), value.inventory))
		)
	if StadiumLowWallSnapshot.is_family(value):
		return (
			StadiumLowWallSnapshot.valid(value)
			and (stock == null or ClubCareer.same(stock.to_data(), value.inventory))
		)
	if is_terrain(value):
		return terrain_valid(value, stock)
	if StadiumSurfaceNightSnapshot.is_wrapped(value):
		return (
			StadiumSurfaceNightSnapshot.valid(value)
			and (stock == null or ClubCareer.same(stock.to_data(), value.inventory))
		)
	if StadiumSurfaceNightSnapshot.is_family(value):
		return (
			StadiumSurfaceNightSnapshot.valid(value)
			and (stock == null or StadiumHomeLayout.validate(value.layout, stock, value.tier).ok)
		)
	if StadiumNpcSnapshot.is_public(value):
		# NPC declarations never satisfy a human owned-stock check.
		return stock == null and StadiumNpcSnapshot.valid(value)
	if _pool(value):
		return _pool_valid(value, stock)
	if _mounted(value):
		return _mounted_valid(value, stock)
	if _scoreboards(value):
		return _scoreboards_valid(value, stock)
	if not value is Dictionary or not SeasonOwnership._whole(value.get("version"), 1, VERSION):
		return false
	if (
		value.get("layout") is Dictionary
		and SeasonOwnership._whole(value.layout.get("version"), 11, 11)
		and not StadiumWallItems.RUNTIME_READY
	):
		return false
	var fields: Array = ["version", "tier", "geometry", "revision", "layout"]
	if value.version >= 2:
		fields.append("inventory")
	if value.version >= 3:
		fields.append("boundary")
		if (
			not value.get("layout") is Dictionary
			or not value.get("boundary") is String
			or value.boundary != StadiumOwnedLayout.boundary_signature(value.layout)
		):
			return false
	if value.version >= 8:
		fields.append("surface_access")
	if int(value.version) in [5, 7, 9]:
		fields.append("environment")
	if not SeasonOwnership._keys(value, fields):
		return false
	if (
		not SeasonOwnership._whole(value.version, 1, VERSION)
		or not SeasonOwnership._whole(value.revision, 0, ClubAssetLedger.MAX_EVENTS)
		or not value.tier is String
		or not StadiumLand.TIERS.has(value.tier)
		or (value.version < 4 and value.tier != "backyard")
		or not value.layout is Dictionary
		or not value.geometry is String
		or value.geometry != StadiumHomeLayout.geometry(value.tier, value.layout)
	):
		return false
	if SeasonOwnership._whole(value.layout.get("version"), 2, 12) and value.version < 3:
		return false
	var declared: StadiumStock = ownership(value)
	if declared == null or not StadiumHomeLayout.validate(value.layout, declared, value.tier).ok:
		return false
	var surface: bool = (
		SeasonOwnership._whole(value.layout.get("version"), 12, 12)
		or StadiumFlagItems.is_family(value.layout)
		or (
			StadiumGroundPropsItems.is_family(value.layout)
			or (
				StadiumStraightItems.is_family(value.layout)
				or (
					StadiumRoofItems.is_family(value.layout)
					or (
						StadiumFacilityItems.is_family(value.layout)
						or (
							StadiumBoundaryItems.is_family(value.layout)
							or (
								StadiumReceiverOwnedItems.is_family(value.layout)
								or (
									StadiumFloodlightOwnedItems.is_family(value.layout)
									or (
										StadiumLandscapeOwnedItems.is_family(value.layout)
										or (
											StadiumLiveFurnishingItems.is_family(value.layout)
											or (
												StadiumSmallYardSceneryItems.is_family(value.layout)
												or (
													StadiumMoldedSeatItems.is_family(value.layout)
													or (
														StadiumGroundBoxItems.is_family(
															value.layout
														)
														or (
															StadiumPracticeFacilityItems.is_family(
																value.layout
															)
															or (
																StadiumTreehouseItems.is_family(
																	value.layout
																)
																or (
																	StadiumLandmarkItems.is_family(
																		value.layout
																	)
																	or (
																		(
																			StadiumOutfieldBleacherItems
																			. is_family(
																				value.layout
																			)
																		)
																		or (
																			(
																				StadiumRisingAppleItems
																				. is_family(
																					value.layout
																				)
																			)
																			or (
																				(
																					StadiumWallTopTerraceItems
																					. is_family(
																						value.layout
																					)
																				)
																				or (
																					(
																						StadiumPlayerTunnelItems
																						. is_family(
																							(
																								value
																								. layout
																							)
																						)
																					)
																					or (
																						(
																							StadiumMountedDisplayItems
																							. is_family(
																								(
																									value
																									. layout
																								)
																							)
																						)
																						or (
																							(
																								StadiumStringLightItems
																								. is_family(
																									(
																										value
																										. layout
																									)
																								)
																							)
																							or (
																								(
																									StadiumSalvageCarItems
																									. is_family(
																										(
																											value
																											. layout
																										)
																									)
																								)
																								or (
																									(
																										StadiumMasteryBannerItems
																										. is_family(
																											(
																												value
																												. layout
																											)
																										)
																									)
																									or (
																										(
																											StadiumWaterfallItems
																											. is_family(
																												(
																													value
																													. layout
																												)
																											)
																										)
																										or (
																											(
																												StadiumLightingKitItems
																												. is_family(
																													(
																														value
																														. layout
																													)
																												)
																											)
																											or (
																												(
																													StadiumOutfieldPlazaItems
																													. is_family(
																														(
																															value
																															. layout
																														)
																													)
																												)
																												or (
																													StadiumWaterfallLiveItems
																													. is_family(
																														(
																															value
																															. layout
																														)
																													)
																												)
																											)
																										)
																									)
																								)
																							)
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	)
	if surface != (int(value.version) in [8, 9]):
		return false
	if (
		surface
		and (
			not StadiumSurfaceLayout.RUNTIME_READY
			or not StadiumSurfaceProgression.valid_owned(value.surface_access)
			or not StadiumSurfaceLayout.owned(value.layout, surface_access(value))
		)
	):
		return false
	var walls: bool = SeasonOwnership._whole(value.layout.get("version"), 11, 11)
	if walls != (int(value.version) in [6, 7]):
		return false
	if value.version == 5 and not SeasonOwnership._whole(value.layout.get("version"), 9, 10):
		return false
	if (
		int(value.version) in [5, 7, 9]
		and not StadiumFixtureEnvironment.valid(value.environment, value)
	):
		return false
	return stock == null or StadiumHomeLayout.validate(value.layout, stock, value.tier).ok


static func matches(value: Dictionary, ledger: ClubAssetLedger) -> bool:
	if StadiumWaterfallAnimationSnapshot.is_family(value):
		return StadiumWaterfallAnimationSnapshot.matches(value, ledger)
	if StadiumLowWallSnapshot.is_family(value):
		return StadiumLowWallSnapshot.matches(value, ledger)
	if is_terrain(value):
		if ledger == null or not terrain_valid(value) or value.revision > ledger.revision():
			return false
		var prefix: ClubAssetLedger = ledger.prefix(int(value.revision))
		return prefix != null and ClubCareer.same(terrain_capture(prefix), terrain_entry(value))
	if StadiumSurfaceNightSnapshot.is_family(value):
		return StadiumSurfaceNightSnapshot.matches(value, ledger)
	if StadiumNpcSnapshot.is_public(value):
		return false
	if _pool(value):
		return StadiumPoolOwnedSnapshot.matches(value, ledger)
	if _mounted(value):
		return (
			StadiumMountedScoreboardLayout.RUNTIME_READY
			and StadiumMountedScoreboardSnapshot.matches(value, ledger)
		)
	if _scoreboards(value):
		return (
			StadiumScoreboardLayout.RUNTIME_READY
			and StadiumScoreboardSnapshot.matches(value, ledger)
		)
	if (
		ledger == null
		or not valid(value, ledger.construction())
		or value.revision > ledger.revision()
	):
		return false
	var prefix: ClubAssetLedger = ledger.prefix(int(value.revision))
	if (
		prefix == null
		or not valid(value, prefix.construction())
		or value.tier != prefix.view().land
	):
		return false
	if value.version >= 2 and not ClubCareer.same(value.inventory, prefix.construction().to_data()):
		return false
	if value.version >= 8 and not ClubCareer.same(value.surface_access, prefix.surface_owned()):
		return false
	return ClubCareer.same(prefix.view().stadium_active, value.layout)


static func surface_access(value: Dictionary) -> Array[String]:
	if StadiumSurfaceNightSnapshot.is_family(value):
		return surface_access(StadiumSurfaceNightSnapshot.entry(value))
	var result: Array[String] = []
	if StadiumSurfaceProgression.valid_owned(value.get("surface_access")):
		result.assign(value.surface_access)
	return result


static func ownership(value: Dictionary) -> StadiumStock:
	if StadiumWaterfallAnimationSnapshot.is_family(value):
		return (
			StadiumStock.from_data(value.inventory)
			if StadiumWaterfallAnimationSnapshot.valid(value)
			else null
		)
	if StadiumLowWallSnapshot.is_family(value):
		return (
			StadiumStock.from_data(value.inventory) if StadiumLowWallSnapshot.valid(value) else null
		)
	if StadiumSurfaceNightSnapshot.is_family(value):
		return (
			ownership(StadiumSurfaceNightSnapshot.entry(value))
			if StadiumSurfaceNightSnapshot.valid(value)
			else null
		)
	if StadiumNpcSnapshot.is_public(value):
		return null
	# Structural inventory is a frozen declaration, not proof of earned ownership.
	# matches() verifies it against the exact paid journal prefix before save/replay.
	if value.get("version", 1) >= 2:
		return StadiumStock.from_data(value.get("inventory"))
	return StadiumStock.new_club()


static func normalized(value: Dictionary) -> Dictionary:
	return Operations1._public_normalized(value)


static func key(value: Dictionary) -> String:
	var canonical: Dictionary = normalized(value)
	return (
		JSON.stringify(canonical, "", true, true).sha256_text() if not canonical.is_empty() else ""
	)


static func for_fixture(season: SeasonState, fixture: Dictionary) -> Dictionary:
	if StadiumSurfaceNightSnapshot.expected(season, fixture):
		return StadiumSurfaceNightSnapshot.fixture(season, fixture)
	if fixture.get("home", -1) == 0 and not fixture.get("neutral", false):
		if StadiumWaterfallAnimationSnapshot.is_family(season.home_property):
			return StadiumWaterfallAnimationSnapshot.fixture(
				season.home_property,
				SeasonPhysicalFixtures.seed_for(season, fixture),
				int(fixture.id)
			)
		if StadiumLowWallSnapshot.is_family(season.home_property):
			return StadiumLowWallSnapshot.fixture(
				season.home_property,
				SeasonPhysicalFixtures.seed_for(season, fixture),
				int(fixture.id)
			)
		if is_terrain(season.home_property):
			return terrain_fixture(
				season.home_property,
				SeasonPhysicalFixtures.seed_for(season, fixture),
				int(fixture.id)
			)
		if _pool(season.home_property):
			return StadiumPoolOwnedSnapshot.fixture(
				season.home_property,
				SeasonPhysicalFixtures.seed_for(season, fixture),
				int(fixture.id)
			)
		return StadiumFixtureEnvironment.for_fixture(season, fixture)
	return SeasonVenues.for_fixture(season, fixture)


static func _scoreboards(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"),
			StadiumScoreboardSnapshot.VERSION,
			StadiumScoreboardSnapshot.FIXTURE_VERSION
		)
	)


static func _scoreboards_valid(value: Dictionary, stock: StadiumStock) -> bool:
	if not StadiumScoreboardLayout.RUNTIME_READY or not StadiumScoreboardSnapshot.valid(value):
		return false
	if stock == null:
		return true
	var owners: Dictionary = StadiumScoreboardSnapshot.ownership(value)
	return (
		StadiumOwnedLayout
		. validate(
			value.layout, stock, owners.pieces, surface_access(value), value.tier, owners.boards
		)
		. ok
	)


static func _mounted(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"),
			StadiumMountedScoreboardSnapshot.VERSION,
			StadiumMountedScoreboardSnapshot.FIXTURE_VERSION
		)
	)


static func _mounted_valid(value: Dictionary, stock: StadiumStock) -> bool:
	if (
		not StadiumMountedScoreboardLayout.RUNTIME_READY
		or not StadiumMountedScoreboardSnapshot.valid(value)
	):
		return false
	if stock == null:
		return true
	var owners: Dictionary = StadiumMountedScoreboardSnapshot.ownership(value)
	return (
		StadiumOwnedLayout
		. validate(
			value.layout, stock, owners.pieces, surface_access(value), value.tier, owners.boards
		)
		. ok
	)


static func _pool(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"),
			StadiumPoolOwnedSnapshot.VERSION,
			StadiumPoolOwnedSnapshot.FIXTURE_VERSION
		)
	)


static func _pool_valid(value: Dictionary, stock: StadiumStock) -> bool:
	if not StadiumPoolOwnedSnapshot.valid(value):
		return false
	return (
		stock == null
		or (
			StadiumPoolOwnedLayout
			. validate(value.layout, stock, surface_access(value), value.tier)
			. ok
		)
	)


# Explicit first terrain family; historical flat snapshots never enter this branch.
static func is_terrain(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), TERRAIN_VERSION, TERRAIN_FIXTURE_VERSION)
	)


static func terrain_capture(ledger: ClubAssetLedger) -> Dictionary:
	if ledger == null:
		return {}
	var layout: Dictionary = ledger.view().stadium_active.duplicate(true)
	var result: Dictionary = {
		"version": TERRAIN_VERSION,
		"tier": ledger.view().land,
		"geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout),
		"revision": ledger.revision(),
		"layout": layout,
		"inventory": ledger.construction().to_data(),
		"surface_access": ledger.surface_owned(),
		"boundary": StadiumOwnedLayout.boundary_signature(layout),
		"terrain": _terrain_contract(layout)
	}
	return terrain_normalized(result)


static func terrain_valid(value: Variant, stock: StadiumStock = null) -> bool:
	if not is_terrain(value):
		return false
	var fields: Array = [
		"version",
		"tier",
		"geometry",
		"revision",
		"layout",
		"inventory",
		"surface_access",
		"boundary",
		"terrain"
	]
	if value.version == TERRAIN_FIXTURE_VERSION:
		fields.append("environment")
	if (
		not SeasonOwnership._keys(value, fields)
		or not StadiumProperty.BOUNDS.has(value.tier)
		or not SeasonOwnership._whole(value.revision, 0, ClubAssetLedger.MAX_EVENTS)
		or not value.layout is Dictionary
		or not (
			value.layout.get("version") == 17
			or StadiumFlagItems.is_terrain(value.layout)
			or (
				StadiumGroundPropsItems.is_terrain(value.layout)
				or (
					StadiumStraightItems.is_terrain(value.layout)
					or (
						StadiumRoofItems.is_terrain(value.layout)
						or (
							StadiumFacilityItems.is_terrain(value.layout)
							or (
								StadiumBoundaryItems.is_terrain(value.layout)
								or (
									StadiumReceiverOwnedItems.is_terrain(value.layout)
									or (
										StadiumFloodlightOwnedItems.is_terrain(value.layout)
										or (
											StadiumLandscapeOwnedItems.is_terrain(value.layout)
											or (
												StadiumLiveFurnishingItems.is_terrain(value.layout)
												or (
													StadiumSmallYardSceneryItems.is_terrain(
														value.layout
													)
													or (
														StadiumMoldedSeatItems.is_terrain(
															value.layout
														)
														or (
															StadiumGroundBoxItems.is_terrain(
																value.layout
															)
															or (
																(
																	StadiumPracticeFacilityItems
																	. is_terrain(value.layout)
																)
																or (
																	(
																		StadiumTreehouseItems
																		. is_terrain(value.layout)
																	)
																	or (
																		(
																			StadiumLandmarkItems
																			. is_terrain(
																				value.layout
																			)
																		)
																		or (
																			(
																				StadiumOutfieldBleacherItems
																				. is_terrain(
																					value.layout
																				)
																			)
																			or (
																				(
																					StadiumRisingAppleItems
																					. is_terrain(
																						value.layout
																					)
																				)
																				or (
																					(
																						StadiumWallTopTerraceItems
																						. is_terrain(
																							(
																								value
																								. layout
																							)
																						)
																					)
																					or (
																						(
																							StadiumPlayerTunnelItems
																							. is_terrain(
																								(
																									value
																									. layout
																								)
																							)
																						)
																						or (
																							(
																								StadiumMountedDisplayItems
																								. is_terrain(
																									(
																										value
																										. layout
																									)
																								)
																							)
																							or (
																								(
																									StadiumStringLightItems
																									. is_terrain(
																										(
																											value
																											. layout
																										)
																									)
																								)
																								or (
																									(
																										StadiumSalvageCarItems
																										. is_terrain(
																											(
																												value
																												. layout
																											)
																										)
																									)
																									or (
																										(
																											StadiumMasteryBannerItems
																											. is_terrain(
																												(
																													value
																													. layout
																												)
																											)
																										)
																										or (
																											(
																												StadiumWaterfallItems
																												. is_terrain(
																													(
																														value
																														. layout
																													)
																												)
																											)
																											or (
																												(
																													StadiumLightingKitItems
																													. is_terrain(
																														(
																															value
																															. layout
																														)
																													)
																												)
																												or (
																													(
																														StadiumOutfieldPlazaItems
																														. is_terrain(
																															(
																																value
																																. layout
																															)
																														)
																													)
																													or (
																														StadiumWaterfallLiveItems
																														. is_terrain(
																															(
																																value
																																. layout
																															)
																														)
																													)
																												)
																											)
																										)
																									)
																								)
																							)
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		or not StadiumSurfaceProgression.valid_owned(value.surface_access)
	):
		return false
	var declared: StadiumStock = StadiumStock.from_data(value.inventory)
	if (
		declared == null
		or not _terrain_layout_valid(value.layout, declared, value.tier)
		or not StadiumSurfaceLayout.owned(value.layout, surface_access(value))
		or value.geometry != StadiumOwnedLayout.geometry(value.tier, value.layout)
		or value.boundary != StadiumOwnedLayout.boundary_signature(value.layout)
		or not StadiumSurfaceTerrain.valid(value.terrain)
		or not ClubCareer.same(value.terrain, _terrain_contract(value.layout))
	):
		return false
	if value.version == TERRAIN_FIXTURE_VERSION:
		var environment: Variant = value.environment
		if (
			not environment is Dictionary
			or not SeasonOwnership._keys(
				environment, ["version", "seed", "fixture", "mode", "profile"]
			)
			or not SeasonOwnership._whole(environment.version, 1, 1)
			or not SeasonOwnership._whole(environment.seed, 0, 2147483647)
			or not SeasonOwnership._whole(environment.fixture, 0, 32)
			or environment.mode != "day"
			or environment.profile != ""
		):
			return false
	return stock == null or _terrain_layout_valid(value.layout, stock, value.tier)


static func terrain_normalized(value: Dictionary) -> Dictionary:
	return Operations2._public_terrain_normalized(value)


static func terrain_entry(value: Dictionary) -> Dictionary:
	return Operations2._public_terrain_entry(value)


static func terrain_fixture(value: Dictionary, seed: int, fixture: int) -> Dictionary:
	return Operations2._public_terrain_fixture(value, seed, fixture)


static func _terrain_layout_valid(layout: Dictionary, stock: StadiumStock, tier: String) -> bool:
	return Operations2._terrain_layout_valid(layout, stock, tier)


static func _terrain_contract(layout: Dictionary) -> Dictionary:
	return Operations2._terrain_contract(layout)
