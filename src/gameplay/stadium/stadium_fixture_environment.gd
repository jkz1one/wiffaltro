class_name StadiumFixtureEnvironment
extends RefCounted
## Deterministic presentation-only day/night pool, bound by the existing fixture seed and property.

const VERSION: int = 1
const FINAL_VERSION: int = 2


static func capture(snapshot: Dictionary, seed: int, fixture: int) -> Dictionary:
	if StadiumLayoutSnapshot._mounted(snapshot) or StadiumLayoutSnapshot._scoreboards(snapshot):
		return (
			{"version": VERSION, "seed": seed, "fixture": fixture, "mode": "day", "profile": ""}
			if StadiumLayoutSnapshot.valid(snapshot)
			else {}
		)
	var checked: Dictionary = StadiumHomeLayout.validate(
		snapshot.layout, StadiumLayoutSnapshot.ownership(snapshot), snapshot.tier
	)
	var qualified: bool = checked.ok and checked.get("night_qualified", false)
	return {
		"version": VERSION,
		"seed": seed,
		"fixture": fixture,
		"mode": "night" if qualified and is_night_seed(seed) else "day",
		"profile": StadiumLightItems.PROFILE if qualified else ""
	}


static func valid(value: Variant, snapshot: Dictionary) -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["version", "seed", "fixture", "mode", "profile"])
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not SeasonOwnership._whole(value.seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.fixture, 0, 32)
		or not value.mode is String
		or not value.profile is String
	):
		return false
	return ClubCareer.same(value, capture(snapshot, int(value.seed), int(value.fixture)))


static func for_fixture(season: SeasonState, fixture: Dictionary) -> Dictionary:
	if StadiumWaterfallAnimationSnapshot.is_family(season.home_property):
		return StadiumWaterfallAnimationSnapshot.fixture(
			season.home_property, SeasonPhysicalFixtures.seed_for(season, fixture), int(fixture.id)
		)
	if StadiumLowWallSnapshot.is_family(season.home_property):
		return StadiumLowWallSnapshot.fixture(
			season.home_property, SeasonPhysicalFixtures.seed_for(season, fixture), int(fixture.id)
		)
	var snapshot: Dictionary = season.home_property.duplicate(true)
	if StadiumLayoutSnapshot._mounted(snapshot):
		return (
			StadiumMountedScoreboardSnapshot.fixture(
				snapshot, SeasonPhysicalFixtures.seed_for(season, fixture), int(fixture.id)
			)
			if (StadiumMountedScoreboardLayout.RUNTIME_READY)
			else {}
		)
	if StadiumLayoutSnapshot._scoreboards(snapshot):
		return (
			StadiumScoreboardSnapshot.fixture(
				snapshot, SeasonPhysicalFixtures.seed_for(season, fixture), int(fixture.id)
			)
			if (StadiumScoreboardLayout.RUNTIME_READY)
			else {}
		)
	if (
		not snapshot.is_empty()
		and (
			SeasonOwnership._whole(snapshot.layout.get("version"), 9, 12)
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
												StadiumLiveFurnishingItems.is_family(
													snapshot.layout
												)
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
																(
																	StadiumPracticeFacilityItems
																	. is_family(snapshot.layout)
																)
																or (
																	StadiumTreehouseItems.is_family(
																		snapshot.layout
																	)
																	or (
																		(
																			StadiumLandmarkItems
																			. is_family(
																				snapshot.layout
																			)
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
																						(
																							snapshot
																							. layout
																						)
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
		)
	):
		snapshot.version = (
			9
			if (
				snapshot.layout.version == 12
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
												StadiumLandscapeOwnedItems.is_family(
													snapshot.layout
												)
												or (
													StadiumLiveFurnishingItems.is_family(
														snapshot.layout
													)
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
																	(
																		StadiumPracticeFacilityItems
																		. is_family(snapshot.layout)
																	)
																	or (
																		(
																			StadiumTreehouseItems
																			. is_family(
																				snapshot.layout
																			)
																		)
																		or (
																			(
																				StadiumLandmarkItems
																				. is_family(
																					snapshot.layout
																				)
																			)
																			or (
																				(
																					StadiumOutfieldBleacherItems
																					. is_family(
																						(
																							snapshot
																							. layout
																						)
																					)
																				)
																				or (
																					(
																						StadiumRisingAppleItems
																						. is_family(
																							(
																								snapshot
																								. layout
																							)
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
			)
			else (7 if snapshot.layout.version == 11 else 5)
		)
		snapshot["environment"] = capture(
			snapshot, SeasonPhysicalFixtures.seed_for(season, fixture), int(fixture.id)
		)
	return snapshot


static func label(season: SeasonState, fixture: Dictionary) -> String:
	var snapshot: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
	if StadiumSurfaceNightSnapshot.valid(snapshot):
		if StadiumSurfaceNightSnapshot.is_time(snapshot):
			var mode: String = snapshot.environment.mode
			var minute: int = int(snapshot.environment.start_minute)
			return "%s • %02d:%02d • Owned surface" % [mode.capitalize(), minute / 60, minute % 60]
		return "Night game • Owned surface"
	if (
		(
			snapshot.get("version") == StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
			or snapshot.get("version") == StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
		)
		and StadiumNpcSnapshot.valid(snapshot)
	):
		return "13:10 • Clear"
	if (
		snapshot.get("version") == StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION
		and StadiumNpcSnapshot.valid(snapshot)
		and snapshot.environment.version == StadiumGrandIIIEnvironmentV1.TIME_ENVIRONMENT_VERSION
	):
		return (
			"%s • %s • Gardens"
			% [str(snapshot.environment.mode).capitalize(), snapshot.environment.time]
		)
	if (
		(
			snapshot.get("version") == StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION
			or snapshot.get("version") == StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION
			or snapshot.get("version") == StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION
		)
		and StadiumNpcSnapshot.valid(snapshot)
	):
		return "19:10 • Clear"
	if (
		snapshot.get("version") == StadiumNpcSnapshot.FINAL_FIXTURE_VERSION
		and StadiumNpcSnapshot.valid(snapshot)
	):
		return "16:10 • Clear"
	return (
		"Night game"
		if snapshot.get("version", 0) in [5, 7, 9] and snapshot.environment.mode == "night"
		else "Day game"
	)


static func is_night_seed(seed: int) -> bool:
	return ("yard-night-v1:%d" % seed).sha256_text().left(8).hex_to_int() % 3 == 0
