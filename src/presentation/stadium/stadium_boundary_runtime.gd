class_name StadiumBoundaryRuntime
extends RefCounted
## Known frozen-boundary installation; the legacy template remains available for old snapshots.


static func install_bound(lab: PitchBatLab) -> bool:
	if (
		lab._match_state == null
		or not StadiumLayoutSnapshot.valid(lab._match_state.stadium)
		or not lab._match_state.stadium.has("boundary")
	):
		return false
	return _install(lab)


static func _install(lab: PitchBatLab) -> bool:
	if (
		lab._field_id != PitchBatLab.FIELD_ID
		or is_instance_valid(lab._batted_ball)
		or not lab.has_meta("stadium_property")
	):
		return false
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: Node3D = assemble(property)
	if boundary == null:
		return false
	if boundary is StadiumRecipeBoundaryBody:
		lab._ball_play_resolver.segment_observer = (
			boundary.observe if boundary is StadiumBoundaryOwnedRuntime else boundary.graph.observe
		)
		lab._primary_fielder.stadium_boundary_clip = boundary.graph.clip
		lab.set_meta("boundary_signature", boundary.graph.signature())
	else:
		lab._ball_play_resolver.segment_observer = StadiumBoundaryObserver.observe
		lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
		lab.set_meta("boundary_signature", StadiumBoundaryGraph.signature())
	lab._camera_director.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	return true


static func assemble(property: StadiumPropertyGeometry) -> Node3D:
	if not StadiumPropertyGeometry.construction_target_allowed(property):
		return null
	var wall: Node = property.get_node_or_null("TemplateBackWall")
	if wall == null or property.has_node("BoundaryGraph"):
		return null
	var boundary: Node3D
	var built: bool = false
	if property.has_meta("boundary_layout"):
		boundary = StadiumBoundaryOwnedRuntime.new()
		boundary.name = "BoundaryGraph"
		built = boundary.build_from(
			property,
			property.get_meta("boundary_layout"),
			StadiumStock.from_data(property.get_meta("boundary_stock"))
		)
	else:
		boundary = (
			StadiumRecipeBoundaryBody.new()
			if property.has_meta("wall_selection")
			else StadiumBoundaryPrototype.new()
		)
		boundary.name = "BoundaryGraph"
		built = (
			boundary.build_owned(
				property.get_meta("wall_selection"),
				StadiumStock.from_data(property.get_meta("wall_stock"))
			)
			if (boundary is StadiumRecipeBoundaryBody)
			else boundary.build()
		)
	if not built:
		boundary.free()
		return null
	property.add_child(boundary)
	if boundary is StadiumRecipeBoundaryBody and not boundary is StadiumBoundaryOwnedRuntime:
		StadiumWallRenderQuality.attach(boundary)
	property.remove_child(wall)
	wall.queue_free()
	return boundary


static func installed(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	if StadiumWaterfallAnimationSnapshot.is_family(snapshot):
		return StadiumWaterfallAnimationInstall.installed_bound(lab, snapshot)
	if StadiumLowWallSnapshot.is_family(snapshot):
		return StadiumLowWallRuntime.installed_bound(lab, snapshot)
	if lab == null:
		return false
	if (
		snapshot.get("layout") is Dictionary
		and SeasonOwnership._whole(snapshot.layout.get("version"), 15, 15)
	):
		return (
			StadiumMountedScoreboardLayout.RUNTIME_READY
			and StadiumScoreboardRuntime.mounted_installed(lab, snapshot, lab._stadium_ledger)
		)
	if (
		snapshot.get("layout") is Dictionary
		and SeasonOwnership._whole(snapshot.layout.get("version"), 14, 14)
	):
		return (
			StadiumScoreboardLayout.RUNTIME_READY
			and StadiumScoreboardRuntime.installed(lab, snapshot)
		)
	if (
		lab.get_meta("boundary_signature", "") != snapshot.get("boundary", "unknown")
		or not lab.has_meta("stadium_property")
	):
		return false
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: Node = property.get_node_or_null("BoundaryGraph")
	if boundary is StadiumBoundaryOwnedRuntime:
		var normalized: Dictionary = StadiumLayoutSnapshot.normalized(snapshot)
		var layout: Dictionary = normalized.get("layout", {})
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
															StadiumWallTopTerraceItems.is_family(
																layout
															)
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
																					. is_family(
																						layout
																					)
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
			layout = StadiumReceiverOwnedItems.base(layout)
		return (
			not normalized.is_empty()
			and boundary.intact()
			and (
				boundary.get_meta("boundary_layout_hash", "")
				== JSON.stringify(layout, "", true, true).sha256_text()
			)
			and lab._ball_play_resolver.segment_observer == boundary.observe
			and lab._primary_fielder.stadium_boundary_clip == boundary.graph.clip
			and (
				not property.has_live_waterfall()
				or (
					lab._primary_fielder.stadium_waterfall_step == property.waterfall_step
					and lab._primary_fielder.stadium_waterfall_clip == property.waterfall_clip
				)
			)
		)
	if boundary is StadiumRecipeBoundaryBody:
		return (
			(
				boundary.get_meta("wall_manifest", "")
				== JSON.stringify(snapshot.layout.walls, "", true, true).sha256_text()
			)
			and boundary.get_child_count() == boundary.graph.segments().size() + 1
			and lab._ball_play_resolver.segment_observer.is_valid()
			and lab._primary_fielder.stadium_boundary_clip.is_valid()
		)
	return (
		boundary is StadiumBoundaryPrototype
		and boundary.get_child_count() == StadiumBoundaryGraph.IDS.size()
		and lab._ball_play_resolver.segment_observer.is_valid()
		and lab._primary_fielder.stadium_boundary_clip.is_valid()
	)
