class_name PhysicalStadiumReport
extends RefCounted
## Explicit venue wrappers preserve the unchanged report7 baseball evidence contract.

const TERRAIN_VERSION: int = 26
const TERRAIN_RESOLVER: String = "physical-ai-owned-dirt-terrain-v1"
const LEGACY_VERSION: int = 8
const LEGACY_RESOLVER: String = "physical-ai-home-property-v1"
const VERSION: int = 9
const SURFACE_VERSION: int = 11
const SCOREBOARD_VERSION: int = 12
const MOUNTED_VERSION: int = 13
const OWNED_POOL_VERSION: int = 14
const YARD_TWO_VERSION: int = 15
const YARD_THREE_VERSION: int = 16
const NPC_PUBLIC_VERSION: int = 17
const NEUTRAL_FINAL_VERSION: int = 18
const GRAND_FINAL_VERSION: int = 19
const GRAND_II_FINAL_VERSION: int = 20
const GRAND_III_FINAL_VERSION: int = 21
const POOL_PARTY_FINAL_VERSION: int = 22
const HILLSIDE_FINAL_VERSION: int = 23
const MOUNTED_RESOLVER: String = "physical-ai-mounted-scoreboards-v1"
const SCOREBOARD_RESOLVER: String = "physical-ai-scoreboards-v1"
const SURFACE_RESOLVER: String = "physical-ai-surface-finishes-v1"
const RECIPE_VERSION: int = 10
const RECIPE_RESOLVER: String = "physical-ai-wall-recipes-v1"
const RESOLVER: String = "physical-ai-complete-boundary-v1"


static func wrap(base: Dictionary, snapshot: Dictionary, surfaces: Array = []) -> Dictionary:
	return _wrap_context(base, snapshot, surfaces, {})


static func _wrap_context(base: Dictionary, snapshot: Dictionary, surfaces: Array, context: Dictionary) -> Dictionary:
	if (
		not SeasonOwnership._whole(
			base.get("version"), PhysicalMatchReport.BASE_VERSION, PhysicalMatchReport.BASE_VERSION
		)
		or not CurrentPhysicalStadiumEvidence.base_valid(base, context)
		or not StadiumLayoutSnapshot.valid(snapshot)
	):
		return {}
	# Owned Pool needs the live capture evidence; an ordinary wrap cannot omit its rows.
	if (
		StadiumLayoutSnapshot.is_terrain(snapshot)
		or StadiumSurfaceNightSnapshot.is_family(snapshot)
		or StadiumNpcSnapshot.is_public(snapshot)
		or snapshot.get("version") == StadiumPoolOwnedSnapshot.FIXTURE_VERSION
	):
		return {}
	var complete: bool = snapshot.has("boundary")
	if not complete and not surfaces.is_empty():
		return {}
	var result: Dictionary = base.duplicate(true)
	result.version = VERSION if complete else LEGACY_VERSION
	result.resolver = RESOLVER if complete else LEGACY_RESOLVER
	if SeasonOwnership._whole(snapshot.layout.get("version"), 11, 11):
		result.version = RECIPE_VERSION
		result.resolver = RECIPE_RESOLVER
	if (
		SeasonOwnership._whole(snapshot.layout.get("version"), 12, 12)
		or StadiumFlagItems.is_family(snapshot.layout)
		or (
			StadiumGroundPropsItems.is_family(snapshot.layout)
			or (
				StadiumStraightItems.is_family(snapshot.layout)
				or (
					StadiumRoofItems.is_family(snapshot.layout)
					or (
						StadiumFacilityItems.is_family(snapshot.layout)
						or (
							StadiumBoundaryItems.is_family(snapshot.layout)
							or (
								StadiumReceiverOwnedItems.is_family(snapshot.layout)
								or (
									StadiumFloodlightOwnedItems.is_family(snapshot.layout)
									or (
										StadiumLandscapeOwnedItems.is_family(snapshot.layout)
										or (
											StadiumLiveFurnishingItems.is_family(snapshot.layout)
											or (
												StadiumSmallYardSceneryItems.is_family(
													snapshot.layout
												)
												or (
													StadiumMoldedSeatItems.is_family(
														snapshot.layout
													)
													or (
														StadiumGroundBoxItems.is_family(
															snapshot.layout
														)
														or (
															StadiumPracticeFacilityItems.is_family(
																snapshot.layout
															)
															or (
																StadiumTreehouseItems.is_family(
																	snapshot.layout
																)
																or (
																	StadiumLandmarkItems.is_family(
																		snapshot.layout
																	)
																	or (
																		(
																			StadiumOutfieldBleacherItems
																			. is_family(
																				snapshot.layout
																			)
																		)
																		or (
																			(
																				StadiumRisingAppleItems
																				. is_family(
																					snapshot.layout
																				)
																			)
																			or (
																				(
																					StadiumWallTopTerraceItems
																					. is_family(
																						(
																							snapshot
																							. layout
																						)
																					)
																				)
																				or (
																					(
																						StadiumPlayerTunnelItems
																						. is_family(
																							(
																								snapshot
																								. layout
																							)
																						)
																					)
																					or (
																						(
																							StadiumMountedDisplayItems
																							. is_family(
																								(
																									snapshot
																									. layout
																								)
																							)
																						)
																						or (
																							(
																								StadiumStringLightItems
																								. is_family(
																									(
																										snapshot
																										. layout
																									)
																								)
																							)
																							or (
																								(
																									StadiumSalvageCarItems
																									. is_family(
																										(
																											snapshot
																											. layout
																										)
																									)
																								)
																								or (
																									(
																										StadiumMasteryBannerItems
																										. is_family(
																											(
																												snapshot
																												. layout
																											)
																										)
																									)
																									or (
																										(
																											StadiumWaterfallItems
																											. is_family(
																												(
																													snapshot
																													. layout
																												)
																											)
																										)
																										or (
																											(
																												StadiumLightingKitItems
																												. is_family(
																													(
																														snapshot
																														. layout
																													)
																												)
																											)
																											or (
																												(
																													StadiumOutfieldPlazaItems
																													. is_family(
																														(
																															snapshot
																															. layout
																														)
																													)
																												)
																												or (
																													StadiumWaterfallLiveItems
																													. is_family(
																														(
																															snapshot
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
	):
		result.version = SURFACE_VERSION
		result.resolver = SURFACE_RESOLVER
	if SeasonOwnership._whole(snapshot.layout.get("version"), 14, 14):
		result.version = SCOREBOARD_VERSION
		result.resolver = SCOREBOARD_RESOLVER
	if SeasonOwnership._whole(snapshot.layout.get("version"), 15, 15):
		result.version = MOUNTED_VERSION
		result.resolver = MOUNTED_RESOLVER
	result["property"] = StadiumLayoutSnapshot.normalized(snapshot)
	if complete:
		result["surfaces"] = surfaces.duplicate(true)
	return result if _valid_context(result, context) else {}


static func valid(value: Dictionary) -> bool:
	if SeasonOwnership._whole(value.get("version"), TERRAIN_VERSION, TERRAIN_VERSION):
		return terrain_valid(value)
	if SeasonOwnership._whole(
		value.get("version"),
		StadiumSurfaceNightReport.TIME_VERSION,
		StadiumSurfaceNightReport.TIME_VERSION
	):
		return StadiumSurfaceNightReport.valid(value)
	if SeasonOwnership._whole(
		value.get("version"), StadiumSurfaceNightReport.VERSION, StadiumSurfaceNightReport.VERSION
	):
		return StadiumSurfaceNightReport.valid(value)
	if SeasonOwnership._whole(value.get("version"), HILLSIDE_FINAL_VERSION, HILLSIDE_FINAL_VERSION):
		return StadiumHillsidePublicReport.valid(value)
	if SeasonOwnership._whole(
		value.get("version"), POOL_PARTY_FINAL_VERSION, POOL_PARTY_FINAL_VERSION
	):
		return StadiumPoolPartyPublicReport.valid(value)
	if SeasonOwnership._whole(
		value.get("version"), GRAND_III_FINAL_VERSION, GRAND_III_FINAL_VERSION
	):
		return StadiumGrandIIIPublicReport.valid(value)
	if SeasonOwnership._whole(value.get("version"), GRAND_II_FINAL_VERSION, GRAND_II_FINAL_VERSION):
		return StadiumGrandIIPublicReport.valid(value)
	if SeasonOwnership._whole(value.get("version"), GRAND_FINAL_VERSION, GRAND_FINAL_VERSION):
		return StadiumGrandIPublicReport.valid(value)
	if SeasonOwnership._whole(value.get("version"), NEUTRAL_FINAL_VERSION, NEUTRAL_FINAL_VERSION):
		return StadiumLongYardPublicReport.valid(value)
	if SeasonOwnership._whole(value.get("version"), NPC_PUBLIC_VERSION, NPC_PUBLIC_VERSION):
		return StadiumNpcPublicReport.valid(value)
	if SeasonOwnership._whole(value.get("version"), YARD_THREE_VERSION, YARD_THREE_VERSION):
		return StadiumNpcYardThreeReport.valid(value)
	if SeasonOwnership._whole(value.get("version"), YARD_TWO_VERSION, YARD_TWO_VERSION):
		return StadiumNpcYardTwoReport.valid(value)
	if SeasonOwnership._whole(value.get("version"), OWNED_POOL_VERSION, OWNED_POOL_VERSION):
		return StadiumPoolOwnedReport.valid(value)
	if not _shape(value):
		return false
	return PhysicalMatchReport.valid(_core_validated(value))


static func core(value: Dictionary) -> Dictionary:
	if SeasonOwnership._whole(value.get("version"), TERRAIN_VERSION, TERRAIN_VERSION):
		return _core_validated(value) if terrain_valid(value) else {}
	if SeasonOwnership._whole(
		value.get("version"),
		StadiumSurfaceNightReport.TIME_VERSION,
		StadiumSurfaceNightReport.TIME_VERSION
	):
		return StadiumSurfaceNightReport.core(value)
	if SeasonOwnership._whole(
		value.get("version"), StadiumSurfaceNightReport.VERSION, StadiumSurfaceNightReport.VERSION
	):
		return StadiumSurfaceNightReport.core(value)
	if SeasonOwnership._whole(value.get("version"), HILLSIDE_FINAL_VERSION, HILLSIDE_FINAL_VERSION):
		return StadiumHillsidePublicReport.core(value)
	if SeasonOwnership._whole(
		value.get("version"), POOL_PARTY_FINAL_VERSION, POOL_PARTY_FINAL_VERSION
	):
		return StadiumPoolPartyPublicReport.core(value)
	if SeasonOwnership._whole(
		value.get("version"), GRAND_III_FINAL_VERSION, GRAND_III_FINAL_VERSION
	):
		return StadiumGrandIIIPublicReport.core(value)
	if SeasonOwnership._whole(value.get("version"), GRAND_II_FINAL_VERSION, GRAND_II_FINAL_VERSION):
		return StadiumGrandIIPublicReport.core(value)
	if SeasonOwnership._whole(value.get("version"), GRAND_FINAL_VERSION, GRAND_FINAL_VERSION):
		return StadiumGrandIPublicReport.core(value)
	if SeasonOwnership._whole(value.get("version"), NEUTRAL_FINAL_VERSION, NEUTRAL_FINAL_VERSION):
		return StadiumLongYardPublicReport.core(value)
	if SeasonOwnership._whole(value.get("version"), NPC_PUBLIC_VERSION, NPC_PUBLIC_VERSION):
		return StadiumNpcPublicReport.core(value)
	if SeasonOwnership._whole(value.get("version"), YARD_THREE_VERSION, YARD_THREE_VERSION):
		return StadiumNpcYardThreeReport.core(value)
	if SeasonOwnership._whole(value.get("version"), YARD_TWO_VERSION, YARD_TWO_VERSION):
		return StadiumNpcYardTwoReport.core(value)
	if SeasonOwnership._whole(value.get("version"), OWNED_POOL_VERSION, OWNED_POOL_VERSION):
		return StadiumPoolOwnedReport.core(value)
	if not SeasonOwnership._whole(value.get("version"), 1, MOUNTED_VERSION):
		return {}
	if value.get("version") < LEGACY_VERSION:
		return value
	if not _shape(value):
		return {}
	return _core_validated(value)


# Both callers validate the full venue/contact shape before stripping its wrapper.
static func _core_validated(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("property")
	result.erase("surfaces")
	result.version = PhysicalMatchReport.BASE_VERSION
	result.resolver = PhysicalMatchReport.BASE_RESOLVER
	return result


static func matches(value: Dictionary, expected: Dictionary) -> bool:
	if SeasonOwnership._whole(value.get("version"), TERRAIN_VERSION, TERRAIN_VERSION):
		return (
			terrain_valid(value)
			and StadiumLayoutSnapshot.key(value.property) == StadiumLayoutSnapshot.key(expected)
		)
	if SeasonOwnership._whole(
		value.get("version"),
		StadiumSurfaceNightReport.TIME_VERSION,
		StadiumSurfaceNightReport.TIME_VERSION
	):
		return StadiumSurfaceNightReport.matches(value, expected)
	if SeasonOwnership._whole(
		value.get("version"), StadiumSurfaceNightReport.VERSION, StadiumSurfaceNightReport.VERSION
	):
		return StadiumSurfaceNightReport.matches(value, expected)
	if SeasonOwnership._whole(value.get("version"), HILLSIDE_FINAL_VERSION, HILLSIDE_FINAL_VERSION):
		return StadiumHillsidePublicReport.matches(value, expected)
	if SeasonOwnership._whole(
		value.get("version"), POOL_PARTY_FINAL_VERSION, POOL_PARTY_FINAL_VERSION
	):
		return StadiumPoolPartyPublicReport.matches(value, expected)
	if SeasonOwnership._whole(
		value.get("version"), GRAND_III_FINAL_VERSION, GRAND_III_FINAL_VERSION
	):
		return StadiumGrandIIIPublicReport.matches(value, expected)
	if SeasonOwnership._whole(value.get("version"), GRAND_II_FINAL_VERSION, GRAND_II_FINAL_VERSION):
		return StadiumGrandIIPublicReport.matches(value, expected)
	if SeasonOwnership._whole(value.get("version"), GRAND_FINAL_VERSION, GRAND_FINAL_VERSION):
		return StadiumGrandIPublicReport.matches(value, expected)
	if SeasonOwnership._whole(value.get("version"), NEUTRAL_FINAL_VERSION, NEUTRAL_FINAL_VERSION):
		return StadiumLongYardPublicReport.matches(value, expected)
	if SeasonOwnership._whole(value.get("version"), NPC_PUBLIC_VERSION, NPC_PUBLIC_VERSION):
		return StadiumNpcPublicReport.matches(value, expected)
	if SeasonOwnership._whole(value.get("version"), YARD_THREE_VERSION, YARD_THREE_VERSION):
		return StadiumNpcYardThreeReport.matches(value, expected)
	if SeasonOwnership._whole(value.get("version"), YARD_TWO_VERSION, YARD_TWO_VERSION):
		return StadiumNpcYardTwoReport.matches(value, expected)
	if SeasonOwnership._whole(value.get("version"), OWNED_POOL_VERSION, OWNED_POOL_VERSION):
		return (
			valid(value)
			and StadiumLayoutSnapshot.key(value.property) == StadiumLayoutSnapshot.key(expected)
		)
	if not SeasonOwnership._whole(value.get("version"), 1, MOUNTED_VERSION):
		return false
	if expected.is_empty():
		return value.get("version") < LEGACY_VERSION and not value.has("property")
	return (
		valid(value)
		and StadiumLayoutSnapshot.key(value.property) == StadiumLayoutSnapshot.key(expected)
	)


# Exact validated public-fixture dispatch; raw entries and unknown venues have no resolver.
static func npc_resolver(snapshot: Dictionary) -> String:
	var value: Dictionary = StadiumNpcSnapshot.normalized(snapshot)
	if value.is_empty() or not StadiumNpcSnapshot.is_fixture(value):
		return ""
	if value.version == StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION:
		return (
			StadiumHillsidePublicReport.RESOLVER
			if StadiumHillsidePublicReport.supports_definition(
				value.manifest.id, value.manifest.revision
			)
			else ""
		)
	if value.version == StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION:
		return (
			StadiumPoolPartyPublicReport.RESOLVER
			if StadiumPoolPartyPublicReport.supports_definition(
				value.manifest.id, value.manifest.revision
			)
			else ""
		)
	if value.version == StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION:
		return (
			StadiumGrandIIIPublicReport.RESOLVER
			if StadiumGrandIIIPublicReport.supports_definition(
				value.manifest.id, value.manifest.revision
			)
			else ""
		)
	if value.version == StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION:
		return (
			StadiumGrandIIPublicReport.RESOLVER
			if StadiumGrandIIPublicReport.supports_definition(
				value.manifest.id, value.manifest.revision
			)
			else ""
		)
	if value.version == StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION:
		return (
			StadiumGrandIPublicReport.RESOLVER
			if StadiumGrandIPublicReport.supports_definition(
				value.manifest.id, value.manifest.revision
			)
			else ""
		)
	if value.version == StadiumNpcSnapshot.FINAL_FIXTURE_VERSION:
		return (
			StadiumLongYardPublicReport.RESOLVER
			if StadiumLongYardPublicReport.supports_definition(
				value.manifest.id, value.manifest.revision
			)
			else ""
		)
	if StadiumNpcPublicReport.supports_definition(value.manifest.id, value.manifest.revision):
		return StadiumNpcPublicReport.RESOLVER
	if value.manifest.revision != 1:
		return ""
	if value.manifest.id == "AY-02":
		return StadiumNpcYardTwoReport.RESOLVER
	if value.manifest.id == "AY-03":
		return StadiumNpcYardThreeReport.RESOLVER
	return ""


static func _shape(value: Dictionary) -> bool:
	if (
		not SeasonOwnership._whole(value.get("version"), LEGACY_VERSION, MOUNTED_VERSION)
		or not SeasonOwnership._whole(value.get("seed"), 0, 2147483647)
		or not value.get("resolver") is String
		or not value.get("field") is String
		or value.field != String(PitchBatLab.FIELD_ID)
		or not StadiumLayoutSnapshot.valid(value.get("property"))
	):
		return false
	if value.property.has("environment") and value.property.environment.seed != value.get("seed"):
		return false
	if value.version == MOUNTED_VERSION:
		return _mounted_shape(value)
	if value.version == SCOREBOARD_VERSION:
		return _scoreboards_shape(value)
	return _old_shape(value)


static func _scoreboards_shape(value: Dictionary) -> bool:
	return (
		value.resolver == SCOREBOARD_RESOLVER
		and value.property.version == StadiumScoreboardSnapshot.FIXTURE_VERSION
		and SeasonOwnership._whole(value.property.layout.get("version"), 14, 14)
		and value.get("plays") is Array
		and PhysicalStadiumContacts.scoreboards_valid(
			value.get("surfaces"), value.plays, value.property
		)
	)


static func _old_shape(value: Dictionary) -> bool:
	if StadiumWaterfallAnimationSnapshot.is_family(value.property):
		return (
			value.version == VERSION
			and value.resolver == RESOLVER
			and value.property.version == StadiumWaterfallAnimationSnapshot.FIXTURE_VERSION
			and value.get("plays") is Array
			and PhysicalStadiumContacts.valid(value.get("surfaces"), value.plays, value.property)
		)
	if StadiumLowWallSnapshot.is_family(value.property):
		return (
			value.version == VERSION
			and value.resolver == RESOLVER
			and value.property.version == StadiumLowWallSnapshot.FIXTURE_VERSION
			and value.get("plays") is Array
			and PhysicalStadiumContacts.valid(value.get("surfaces"), value.plays, value.property)
		)
	if StadiumLayoutSnapshot.is_terrain(value.property):
		return false
	if SeasonOwnership._whole(value.property.layout.get("version"), 14, 15):
		return false
	if value.version == LEGACY_VERSION:
		return (
			value.resolver == LEGACY_RESOLVER
			and not value.property.has("boundary")
			and not value.has("surfaces")
		)
	var surface: bool = value.version == SURFACE_VERSION
	if (
		(
			surface
			!= (
				SeasonOwnership._whole(value.property.layout.get("version"), 12, 12)
				or StadiumFlagItems.is_family(value.property.layout)
				or (
					StadiumGroundPropsItems.is_family(value.property.layout)
					or (
						StadiumStraightItems.is_family(value.property.layout)
						or (
							StadiumRoofItems.is_family(value.property.layout)
							or (
								StadiumFacilityItems.is_family(value.property.layout)
								or (
									StadiumBoundaryItems.is_family(value.property.layout)
									or (
										StadiumReceiverOwnedItems.is_family(value.property.layout)
										or (
											StadiumFloodlightOwnedItems.is_family(
												value.property.layout
											)
											or (
												StadiumLandscapeOwnedItems.is_family(
													value.property.layout
												)
												or (
													StadiumLiveFurnishingItems.is_family(
														value.property.layout
													)
													or (
														StadiumSmallYardSceneryItems.is_family(
															value.property.layout
														)
														or (
															StadiumMoldedSeatItems.is_family(
																value.property.layout
															)
															or (
																StadiumGroundBoxItems.is_family(
																	value.property.layout
																)
																or (
																	(
																		StadiumPracticeFacilityItems
																		. is_family(
																			value.property.layout
																		)
																	)
																	or (
																		(
																			StadiumTreehouseItems
																			. is_family(
																				(
																					value
																					. property
																					. layout
																				)
																			)
																		)
																		or (
																			(
																				StadiumLandmarkItems
																				. is_family(
																					(
																						value
																						. property
																						. layout
																					)
																				)
																			)
																			or (
																				(
																					StadiumOutfieldBleacherItems
																					. is_family(
																						(
																							value
																							. property
																							. layout
																						)
																					)
																				)
																				or (
																					(
																						StadiumRisingAppleItems
																						. is_family(
																							(
																								value
																								. property
																								. layout
																							)
																						)
																					)
																					or (
																						(
																							StadiumWallTopTerraceItems
																							. is_family(
																								(
																									value
																									. property
																									. layout
																								)
																							)
																						)
																						or (
																							(
																								StadiumPlayerTunnelItems
																								. is_family(
																									(
																										value
																										. property
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
																											. property
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
																												. property
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
																													. property
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
																														. property
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
																															. property
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
																																. property
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
																																	. property
																																	. layout
																																)
																															)
																														)
																														or (
																															StadiumWaterfallLiveItems
																															. is_family(
																																(
																																	value
																																	. property
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
		)
		or (surface and value.property.version != 9)
	):
		return false
	var recipe: bool = value.version == RECIPE_VERSION
	if (
		recipe != SeasonOwnership._whole(value.property.layout.get("version"), 11, 11)
		or (recipe and value.property.version != 7)
	):
		return false
	var resolver: String = SURFACE_RESOLVER if surface else RECIPE_RESOLVER if recipe else RESOLVER
	return (
		value.resolver == resolver
		and value.property.has("boundary")
		and value.get("plays") is Array
		and PhysicalStadiumContacts.valid(value.get("surfaces"), value.plays, value.property)
	)


static func _mounted_shape(value: Dictionary) -> bool:
	return (
		value.resolver == MOUNTED_RESOLVER
		and value.property.version == StadiumMountedScoreboardSnapshot.FIXTURE_VERSION
		and SeasonOwnership._whole(value.property.layout.get("version"), 15, 15)
		and SeasonOwnership._whole(value.property.layout.get("mount_catalog"), 1, 1)
		and value.get("plays") is Array
		and PhysicalStadiumContacts.mounted_valid(
			value.get("surfaces"), value.plays, value.property
		)
	)


static func terrain_capture(lab: PitchBatLab) -> Dictionary:
	return _terrain_capture_context(lab, {})


static func _terrain_capture_context(lab: PitchBatLab, context: Dictionary) -> Dictionary:
	if (
		not is_instance_valid(lab)
		or lab._match_state == null
		or lab._automation == null
		or not StadiumSurfaceTerrainRuntime.installed_bound(lab, lab._match_state.stadium)
	):
		return {}
	var result: Dictionary = CurrentPhysicalStadiumEvidence.capture_base(lab, context)
	if result.get("version") != PhysicalMatchReport.BASE_VERSION:
		return {}
	result.version = TERRAIN_VERSION
	result.resolver = TERRAIN_RESOLVER
	result["property"] = StadiumLayoutSnapshot.normalized(lab._match_state.stadium)
	result["surfaces"] = PhysicalStadiumContacts.capture(lab._play_records)
	return result if _terrain_valid_context(result, context) else {}


static func terrain_valid(value: Dictionary) -> bool:
	return _terrain_valid_context(value, {})


static func _terrain_valid_context(value: Dictionary, context: Dictionary) -> bool:
	if (
		not SeasonOwnership._whole(value.get("version"), TERRAIN_VERSION, TERRAIN_VERSION)
		or value.get("resolver") != TERRAIN_RESOLVER
		or value.get("field") != String(PitchBatLab.FIELD_ID)
		or not StadiumLayoutSnapshot.terrain_valid(value.get("property"))
		or value.property.version != StadiumLayoutSnapshot.TERRAIN_FIXTURE_VERSION
		or value.property.environment.seed != value.get("seed")
		or not value.get("plays") is Array
	):
		return false
	var flat: Dictionary = value.property.duplicate(true)
	flat.layout = (
		StadiumReceiverOwnedItems.contacts_layout(flat.layout)
		if (
			StadiumReceiverOwnedItems.is_family(flat.layout)
			or (
				StadiumFloodlightOwnedItems.is_family(flat.layout)
				or (
					StadiumLandscapeOwnedItems.is_family(flat.layout)
					or (
						StadiumLiveFurnishingItems.is_family(flat.layout)
						or (
							StadiumSmallYardSceneryItems.is_family(flat.layout)
							or (
								StadiumMoldedSeatItems.is_family(flat.layout)
								or (
									StadiumGroundBoxItems.is_family(flat.layout)
									or (
										StadiumPracticeFacilityItems.is_family(flat.layout)
										or (
											StadiumTreehouseItems.is_family(flat.layout)
											or (
												StadiumLandmarkItems.is_family(flat.layout)
												or (
													StadiumOutfieldBleacherItems.is_family(
														flat.layout
													)
													or (
														StadiumRisingAppleItems.is_family(
															flat.layout
														)
														or (
															StadiumWallTopTerraceItems.is_family(
																flat.layout
															)
															or (
																StadiumPlayerTunnelItems.is_family(
																	flat.layout
																)
																or (
																	(
																		StadiumMountedDisplayItems
																		. is_family(flat.layout)
																	)
																	or (
																		(
																			StadiumStringLightItems
																			. is_family(flat.layout)
																		)
																		or (
																			(
																				StadiumSalvageCarItems
																				. is_family(
																					flat.layout
																				)
																			)
																			or (
																				(
																					StadiumMasteryBannerItems
																					. is_family(
																						flat.layout
																					)
																				)
																				or (
																					(
																						StadiumWaterfallItems
																						. is_family(
																							(
																								flat
																								. layout
																							)
																						)
																					)
																					or (
																						(
																							StadiumLightingKitItems
																							. is_family(
																								(
																									flat
																									. layout
																								)
																							)
																						)
																						or (
																							(
																								StadiumOutfieldPlazaItems
																								. is_family(
																									(
																										flat
																										. layout
																									)
																								)
																							)
																							or (
																								StadiumWaterfallLiveItems
																								. is_family(
																									(
																										flat
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
		else (
			StadiumBoundaryItems.contacts_layout(flat.layout)
			if StadiumBoundaryItems.is_family(flat.layout)
			else (
				StadiumFacilityItems.contacts_layout(flat.layout)
				if StadiumFacilityItems.is_family(flat.layout)
				else (
					StadiumRoofItems.contacts_layout(flat.layout)
					if StadiumRoofItems.is_family(flat.layout)
					else (
						StadiumStraightItems.contacts_layout(flat.layout)
						if StadiumStraightItems.is_family(flat.layout)
						else (
							StadiumGroundPropsItems.contacts_layout(flat.layout)
							if (
								StadiumGroundPropsItems.is_family(flat.layout)
								or StadiumStraightItems.is_family(flat.layout)
							)
							else (
								StadiumFlagItems.contacts_layout(flat.layout)
								if StadiumFlagItems.is_family(flat.layout)
								else StadiumSurfaceLayout.terrain_base(flat.layout)
							)
						)
					)
				)
			)
		)
	)
	if not PhysicalStadiumContacts.valid(value.get("surfaces"), value.plays, flat):
		return false
	return CurrentPhysicalStadiumEvidence.base_valid(_core_validated(value), context)


static func _valid_context(value: Dictionary, context: Dictionary) -> bool:
	return _shape(value) and CurrentPhysicalStadiumEvidence.base_valid(_core_validated(value), context)
