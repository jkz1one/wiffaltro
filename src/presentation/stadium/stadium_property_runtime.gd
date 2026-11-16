class_name StadiumPropertyRuntime
extends RefCounted

const AC02_PASSIVE_7 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Separate isolated-lab and validated frozen-snapshot installation paths.


static func authoring_delivery_idle(lab: PitchBatLab) -> bool:
	# Isolated wrappers only: production startup may legitimately already be in DELIVERY.
	return (
		lab != null
		and lab._pitch_actor != null
		and not lab._pitch_actor.running
		and (lab._release_controller == null or not lab._release_controller.active)
		and (
			lab._at_bat_cadence == null
			or lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE
		)
	)


static func install_lab(lab: PitchBatLab, layout: Dictionary, stock: StadiumStock) -> bool:
	if (
		not authoring_delivery_idle(lab)
		or not lab.get_meta("stadium_lab_only", false)
		or lab._automation != null
		or lab._managed_match
		or lab._field_id != PitchBatLab.FIELD_ID
		or is_instance_valid(lab._batted_ball)
		or lab.has_meta("stadium_property")
	):
		return false
	if not SeasonOwnership._whole(layout.get("version"), 1, 1):
		return false
	return _install(lab, layout, stock)


static func install_bound(lab: PitchBatLab) -> bool:
	if StadiumWaterfallAnimationInstall.requested(lab):
		return StadiumWaterfallAnimationInstall.install_bound(lab)
	if StadiumLowWallRuntime.requested(lab):
		return StadiumLowWallRuntime.install_bound(lab)
	if StadiumSurfaceTerrainRuntime.requested(lab):
		return StadiumSurfaceTerrainRuntime.install_bound(lab)
	if (
		is_instance_valid(lab)
		and (
			lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
			or (
				lab._match_state != null
				and StadiumSurfaceNightSnapshot.is_family(lab._match_state.stadium)
			)
		)
	):
		return StadiumSurfaceNightRuntime.install_bound(lab)
	if (
		is_instance_valid(lab)
		and lab._match_state != null
		and StadiumNpcSnapshot.is_public(lab._match_state.stadium)
	):
		var npc: Dictionary = StadiumNpcSnapshot.normalized(lab._match_state.stadium)
		if npc.is_empty():
			return false
		if npc.manifest.id == "AY-02":
			return StadiumNpcYardTwoRuntimeV1.install_bound(lab)
		if npc.manifest.id == "AY-03":
			return StadiumNpcYardThreeRuntimeV1.install_bound(lab)
		if StadiumNpcPublicRuntime.supports_snapshot(npc):
			return StadiumNpcPublicRuntime.install_bound(lab)
		return false
	if StadiumPoolBoundExtension.requested(lab):
		return StadiumPoolBoundExtension.install_bound(lab)
	if StadiumPoolOwnedExtension.requested(lab):
		return StadiumPoolOwnedExtension.install_bound(lab)
	if (
		lab == null
		or lab._match_state == null
		or not StadiumLayoutSnapshot.valid(lab._match_state.stadium)
	):
		return false
	var snapshot: Dictionary = StadiumLayoutSnapshot.normalized(lab._match_state.stadium)
	if (
		(
			StadiumWaterfallItems.is_family(snapshot.layout)
			or (
				StadiumLightingKitItems.is_family(snapshot.layout)
				or (
					StadiumOutfieldPlazaItems.is_family(snapshot.layout)
					or StadiumWaterfallLiveItems.is_family(snapshot.layout)
				)
			)
		)
		and (
			lab._stadium_ledger == null
			or not StadiumLayoutSnapshot.matches(snapshot, lab._stadium_ledger)
		)
	):
		return false  # Reject unbound decorative copies before allocating the owned assembly.
	if SeasonOwnership._whole(snapshot.layout.get("version"), 16, 16):
		return StadiumPoolOwnedExtension.prepare_match_start(lab)
	if SeasonOwnership._whole(snapshot.layout.get("version"), 15, 15):
		return (
			StadiumMountedScoreboardLayout.RUNTIME_READY
			and StadiumScoreboardRuntime.install_mounted_bound(lab, lab._stadium_ledger)
		)
	if SeasonOwnership._whole(snapshot.layout.get("version"), 14, 14):
		return StadiumScoreboardLayout.RUNTIME_READY and StadiumScoreboardRuntime.install_bound(lab)
	if not _install(lab, snapshot.layout, StadiumLayoutSnapshot.ownership(snapshot), snapshot.tier):
		return false
	if snapshot.has("boundary") and not StadiumBoundaryRuntime.install_bound(lab):
		return false
	StadiumLightRuntime.bind(lab, snapshot)
	lab.set_meta("stadium_snapshot", snapshot)
	return true


static func npc_installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	if is_instance_valid(lab) and lab.ac02_startup_pending():
		return false
	var npc: Dictionary = StadiumNpcSnapshot.normalized(snapshot)
	if (
		npc.is_empty()
		or (
			npc.version
			not in [
				StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION,
				StadiumNpcSnapshot.FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
			]
		)
	):
		return false
	if npc.manifest.id == "AY-02":
		return StadiumNpcYardTwoRuntimeV1.installed_bound(lab, snapshot)
	if npc.manifest.id == "AY-03":
		return StadiumNpcYardThreeRuntimeV1.installed_bound(lab, snapshot)
	if StadiumNpcPublicRuntime.supports_snapshot(npc):
		return StadiumNpcPublicRuntime.installed_bound(lab, snapshot)
	return false


static func _install(
	lab: PitchBatLab, layout: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> bool:
	if (
		lab._field_id != PitchBatLab.FIELD_ID
		or lab.has_meta("stadium_property")
		or is_instance_valid(lab._batted_ball)
	):
		return false
	var old: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if old == null:
		return false
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	if not property.build(tier, layout, stock):
		property.free()
		return false
	var attached: bool = _attach(lab, old, property, layout)
	if not attached and is_instance_valid(property) and property.get_parent() == null:
		property.free()
	return attached


static func _attach(
	lab: PitchBatLab,
	old: StarterFieldLabGeometry,
	property: StadiumPropertyGeometry,
	layout: Dictionary,
	prepared_receiver: StadiumPitchReceiver = null,
	terrain_owner: StadiumSurfaceTerrainRuntime = null
) -> bool:
	if (
		prepared_receiver != null
		and (
			prepared_receiver.get_parent() != property
			or (
				prepared_receiver.get_script()
				!= preload("res://src/presentation/stadium/stadium_pitch_receiver.gd")
			)
			or prepared_receiver.chair != property.objects.get(layout.get("receiver", ""))
		)
	):
		return false
	if terrain_owner != null and not terrain_owner.install_context(lab, property, old):
		return false
	if not property.bind_props_context(lab):
		return false
	var flag_state: MatchState = lab._match_state
	var flag_attachment: Dictionary = {
		"host": old,
		"host_parent": old.get_parent(),
		"host_pose": old.transform,
		"host_world": old.global_transform,
		"property_pose": property.transform,
		"attached": false
	}
	var issued_flags: Dictionary = {}
	for copy: String in property.objects:
		var candidate: Node3D = property.objects[copy]
		if candidate.get_meta("stadium_item") == "ST-043":
			if (
				candidate.get_script() != StadiumFlagModels
				or not (candidate as StadiumFlagModels)._intact()
			):
				return false
			issued_flags[copy] = {
				"node": candidate, "pose": candidate.transform, "site": candidate.get_meta("site")
			}
	for id: String in [
		"Ground",
		"BackWall",
		"LiveObjectPole",
		"Plate",
		"MoundMarker",
		"SafeBoundary",
		"DeepAirBoundary",
		"RightFoulLine",
		"LeftFoulLine"
	]:
		var node: Node = old.get_node_or_null(NodePath(id))
		if node != null:
			old.remove_child(node)
			node.queue_free()
			if terrain_owner != null and not terrain_owner.install_context(lab, property, old):
				return false
			if not _issued_flags_intact(
				lab, flag_state, property, issued_flags, false, flag_attachment
			):
				return false
	property.name = "HomeProperty"
	old.add_child(property)
	flag_attachment.attached = true
	if not _issued_flags_intact(lab, flag_state, property, issued_flags, false, flag_attachment):
		return false
	if terrain_owner != null and not terrain_owner.install_context(lab, property, old):
		return false
	lab.set_meta("stadium_property", property)
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	lab._primary_fielder.stadium_waterfall_step = (
		property.waterfall_step if property.has_live_waterfall() else Callable()
	)
	lab._primary_fielder.stadium_waterfall_clip = (
		property.waterfall_clip if property.has_live_waterfall() else Callable()
	)
	var owned_catcher: String = (
		String(layout.get("catcher", ""))
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
		)
		else ""
	)
	for model: Node3D in property.objects.values():
		if model.get_meta("stadium_item") == "ST-043":
			var issued: Dictionary = issued_flags.get(model.get_meta("owned_copy", ""), {})
			if (
				issued.is_empty()
				or issued.node != model
				or model.get_script() != StadiumFlagModels
				or not (model as StadiumFlagModels).bind_match(flag_state, lab)
			):
				return false
		if model.get_meta("stadium_item") == "ST-044":
			if (
				not model is StadiumPennantMotion
				or not (model as StadiumPennantMotion).bind_match(flag_state, lab)
			):
				return false
		if model.get_meta("stadium_item") == "ST-039":
			var display: StadiumScoreboardDisplay = model.get_node("Visual/ScoreDisplay")
			display.bind_match(lab._match_state)
		if model.get_meta("stadium_item") in ["ST-079", "ST-026"] and owned_catcher.is_empty():
			var paired: bool = not String(layout.get("net", "")).is_empty()
			var receiver: StadiumPitchReceiver = (
				prepared_receiver
				if prepared_receiver != null
				else (
					StadiumPairedReceiver.new()
					if paired
					else (
						StadiumTargetReceiver.new()
						if model.get_meta("stadium_item") == "ST-026"
						else StadiumPitchReceiver.new()
					)
				)
			)
			if prepared_receiver == null:
				receiver.name = "PitchReceiverPresentation"
				property.add_child(receiver)
				if terrain_owner != null and not terrain_owner.install_context(lab, property, old):
					return false
				if not _issued_flags_intact(
					lab, flag_state, property, issued_flags, true, flag_attachment
				):
					return false
			if prepared_receiver != null:
				pass  # Private transaction already validated/configured this ordinary receiver off-tree.
			elif paired:
				(receiver as StadiumPairedReceiver).configure_pair(
					model, property.objects[layout.net], lab._sounds
				)
			else:
				receiver.configure(model, lab._sounds)
			if terrain_owner != null and not terrain_owner.install_context(lab, property, old):
				return false
			if not _issued_flags_intact(
				lab, flag_state, property, issued_flags, true, flag_attachment
			):
				return false
			lab._pitch_actor.receiver_router = receiver.route
	if not StadiumRisingAppleRuntime.install(lab, property):
		return false
	if not StadiumMountedClockRuntime.install(lab, property):
		return false
	lab._camera_director.tracking_visibility.configure(old)
	if not owned_catcher.is_empty():
		var receiver: StadiumReceiverOwnedRuntime = StadiumReceiverOwnedRuntime.new()
		receiver.name = "PitchReceiverPresentation"
		property.add_child(receiver)
		var primary: Node3D = property.objects.get(
			(
				layout.target
				if not String(layout.get("target", "")).is_empty()
				else layout.get("receiver", "")
			)
		)
		if not receiver.configure_owned(
			property, primary, property.objects.get(owned_catcher), lab._sounds
		):
			return false
		receiver.visibility = StadiumReceiverOwnedVisibility.new()
		var models: Array[Node3D] = [receiver.net]
		var authority: Callable = func() -> bool:
			return (
				is_instance_valid(lab)
				and lab.has_meta("stadium_property")
				and lab.get_meta("stadium_property") == property
				and receiver.intact()
			)
		if not receiver.visibility.install(lab, property, models, authority):
			return false
		lab._camera_director.tracking_visibility.configure(old)
		receiver.camera_protection = func() -> bool:
			return receiver.visibility.excludes(receiver.net)
		lab._pitch_actor.receiver_router = receiver.route
	PitchBatLabPresentation.refresh_markers(lab)
	return (
		_issued_flags_intact(lab, flag_state, property, issued_flags, true, flag_attachment)
		and (terrain_owner == null or terrain_owner.install_context(lab, property, old))
	)


static func _issued_flags_intact(
	lab: PitchBatLab,
	state: MatchState,
	property: StadiumPropertyGeometry,
	issued: Dictionary,
	installed: bool = false,
	attachment: Dictionary = {}
) -> bool:
	if not is_instance_valid(property) or not property.props_intact():
		return false
	if issued.is_empty():
		return true
	if not is_instance_valid(lab) or lab._match_state != state or not is_instance_valid(property):
		return false
	if not attachment.is_empty():
		if (
			not is_instance_valid(attachment.host)
			or attachment.host.get_parent() != attachment.host_parent
			or attachment.host.transform != attachment.host_pose
			or attachment.host.global_transform != attachment.host_world
			or property.transform != attachment.property_pose
			or property.get_parent() != (attachment.host if attachment.attached else null)
		):
			return false
	if (
		(lab.has_meta("stadium_property") and lab.get_meta("stadium_property") != property)
		or (installed and not lab.has_meta("stadium_property"))
	):
		return false
	for copy: String in issued:
		var row: Dictionary = issued[copy]
		if (
			not is_instance_valid(row.node)
			or property.objects.get(copy) != row.node
			or row.node.get_script() != StadiumFlagModels
			or row.node.get_parent() != property
			or row.node.transform != row.pose
			or row.node.get_meta("owned_copy") != copy
			or row.node.get_meta("stadium_item") != "ST-043"
			or row.node.get_meta("site") != row.site
			or not (row.node as StadiumFlagModels)._intact()
		):
			return false
	for model: Variant in property.objects.values():
		if not is_instance_valid(model) or not model is Node3D:
			return false
		if (
			model.get_meta("stadium_item", "") == "ST-043"
			and issued.get(model.get_meta("owned_copy", ""), {}).get("node") != model
		):
			return false
	return true


static func bind_ball(lab: PitchBatLab, ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	if StadiumSurfaceTerrainRuntime.requested(lab):
		var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
		return owner != null and owner.bind_ball(lab, ball, resolver)
	if lab.hillside_private_runtime != null:
		return (
			is_instance_valid(lab.hillside_private_runtime)
			and lab.hillside_private_runtime.bind_ball(lab, ball, resolver)
		)
	var property: StadiumPropertyGeometry = (
		lab.get_meta("stadium_property") if lab.has_meta("stadium_property") else null
	)
	if property is StadiumNpcPublicProperty and property.venue_id == "HILLSIDE":
		return StadiumNpcPublicRuntime.bind_ball(lab, ball, resolver)
	if is_instance_valid(property):
		if not property.props_intact():
			return false
		var boundary: Node3D = property.get_node_or_null("BoundaryGraph")
		# New low-wall leases must pass deep admission before property listeners
		# are wired. Historical property/boundary paths retain their exact behavior.
		var low: bool = property.get_script() == StadiumLowWallProperty
		if (
			low
			and (
				not is_instance_valid(boundary)
				or boundary.get_script() != StadiumLowWallBoundaryRuntime
				or not is_instance_valid(ball)
				or resolver == null
				or resolver.state == null
				or resolver.state.dead
				or not boundary.deep_intact()
			)
		):
			return false
		# Exact NEW47 uses deep transition admission before any listener/router write.
		var moving: bool = property.get_script() == StadiumWaterfallAnimationProperty
		if moving:
			var expected_script: Script = (
				StadiumWaterfallAnimationLowBoundary
				if (
					(property as StadiumWaterfallAnimationProperty).animation_layout.get(
						"animation_base"
					)
					== 46
				)
				else StadiumWaterfallAnimationBoundary
			)
			if (
				not is_instance_valid(boundary)
				or boundary.get_script() != expected_script
				or not is_instance_valid(ball)
				or ball.is_queued_for_deletion()
				or resolver == null
				or resolver.state == null
				or resolver.state.dead
				or not (property as StadiumWaterfallAnimationProperty).deep_props_intact()
				or not boundary.deep_intact()
			):
				return false
		refresh_receiver_visibility(lab, true)
		property.bind_ball(ball, resolver)
		if low or moving:
			if not boundary.bind_issued_ball(ball, resolver):
				return false
		elif boundary != null:
			boundary.bind_ball(ball, resolver)
	var ground: StadiumHillsideGroundContact = (
		lab.get_node_or_null(NodePath(StadiumHillsideGroundContact.NODE_NAME))
		as StadiumHillsideGroundContact
	)
	if ground != null and ground.get_script() == StadiumHillsideGroundContact:
		return ground.bind_ball(lab, ball, resolver)
	return true


static func clear_control(lab: PitchBatLab, defender: Node3D, ball: Vector3) -> bool:
	if lab.has_meta("stadium_property"):
		var issued: Variant = lab.get_meta("stadium_property")
		if (
			typeof(issued) != TYPE_OBJECT
			or not is_instance_valid(issued)
			or not issued is StadiumPropertyGeometry
			or not _action_property_intact(lab, issued)
		):
			return false
	if (
		StadiumSurfaceTerrainRuntime.requested(lab)
		or lab.hillside_pitcher_motion != null
		or (
			is_instance_valid(lab._primary_fielder) and lab._primary_fielder.hillside_motion != null
		)
	):
		var query: PhysicsRayQueryParameters3D = control_ray(lab, defender, ball)
		return (
			query != null
			and defender.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		)
	if not lab.has_meta("stadium_property"):
		return true
	var start: Vector3 = defender.global_position + Vector3.UP * maxf(0.3, ball.y)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, ball, 1)
	return defender.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


static func control_ray(
	lab: PitchBatLab, defender: Node3D, ball: Vector3
) -> PhysicsRayQueryParameters3D:
	var frame: Dictionary = PitchBatLabDefenseSupport.control_frame(lab, defender, ball)
	if frame.is_empty():
		return null
	var start: Vector3 = defender.global_position + Vector3.UP * maxf(0.3, float(frame.height_m))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, ball, 1)
	if defender == lab._primary_fielder:
		query.exclude = [lab._primary_fielder.get_rid()]
	return query


static func pitcher_step(
	lab: PitchBatLab, target: Vector3, travel: float, legacy_step: Vector3
) -> Vector3:
	if lab.hillside_pitcher_motion != null:
		return lab.hillside_pitcher_motion.move_pitcher(lab, target, travel)
	var property: StadiumPropertyGeometry = (
		lab.get_meta("stadium_property") if lab.has_meta("stadium_property") else null
	)
	if not is_instance_valid(property):
		return legacy_step
	if not _action_property_intact(lab, property):
		return lab._pitcher_marker.global_position
	var obstacles: Array[Dictionary] = property.route_obstacles()
	obstacles.append(
		{
			"center": lab._primary_fielder.global_position,
			"radius": DefenderSpacing.MOUND_CLEARANCE_M
		}
	)
	var from: Vector3 = lab._pitcher_marker.global_position
	if property.has_live_waterfall():
		return property.waterfall_step(
			from,
			target,
			travel,
			[
				{
					"center": lab._primary_fielder.global_position,
					"radius": DefenderSpacing.MOUND_CLEARANCE_M
				}
			]
		)
	if property is StadiumPoolOwnedProperty:
		return StadiumDefenderRoutes.owned_pool_step(
			from, target, travel, obstacles, lab._primary_fielder.stadium_pool_pitcher_route
		)
	var next: Vector3 = StadiumDefenderRoutes.step(from, target, travel, obstacles)
	if property is StadiumNpcRetainedProperty:
		return property.clip(from, next)
	if property is StadiumClubPropertyGeometry:
		return property.boundary.graph.clip(from, next)
	var boundary: Node3D = property.get_node_or_null("BoundaryGraph")
	if boundary is StadiumRecipeBoundaryBody:
		return boundary.graph.clip(from, next)
	next = StadiumBoundaryGraph.clip(from, next) if boundary != null else next
	if StadiumSurfaceTerrainRuntime.requested(lab):
		var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
		return from if owner == null else owner.finish_step(lab._pitcher_marker, from, next, travel)
	return next


static func refresh_receiver_visibility(lab: PitchBatLab, force_visible: bool = false) -> void:
	var ac02_token: int = AC02_PASSIVE_7.enter(
		"stadium_property_runtime.refresh_receiver_visibility"
	)
	_ac02_passive_07_refresh_receiver_visibility(lab, force_visible)
	AC02_PASSIVE_7.leave(ac02_token)


static func _ac02_passive_07_refresh_receiver_visibility(
	lab: PitchBatLab, force_visible: bool = false
) -> void:
	if not lab.has_meta("stadium_property"):
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	if not is_instance_valid(property):
		return
	StadiumBaseMarkerVisibility.update(property, lab._camera, lab._batted_ball)
	if property is StadiumNpcRetainedProperty:
		property.refresh_receiver_presentation(lab, force_visible)
		return
	if property is StadiumAdvancedPropertyGeometry:
		property.rebind_displays(lab._match_state)
	if property is StadiumClubPropertyGeometry:
		property.rebind_display(lab._match_state)
		var hidden_club: bool = (
			not force_visible
			and not is_instance_valid(lab._batted_ball)
			and lab._camera_director.shot == MatchCameraDirector.Shot.BATTING
		)
		StadiumReceiverVisibility.apply(
			property.receiver.chair, hidden_club, lab._camera, lab._batted_ball
		)
		StadiumClubReceiverVisibility.apply(
			property.receiver.net, hidden_club, lab._camera, lab._batted_ball
		)
		return
	var owned_receiver: StadiumReceiverOwnedRuntime = (
		property.get_node_or_null("PitchReceiverPresentation") as StadiumReceiverOwnedRuntime
	)
	if owned_receiver != null and owned_receiver.visibility != null:
		owned_receiver.visibility.refresh(force_visible)
	var hidden: bool = (
		not force_visible
		and not is_instance_valid(lab._batted_ball)
		and lab._camera_director != null
		and lab._camera_director.shot == MatchCameraDirector.Shot.BATTING
	)
	for model: Node3D in property.objects.values():
		if model.get_meta("stadium_item", "") in ["ST-079", "ST-026", "ST-025"]:
			StadiumReceiverVisibility.apply(model, hidden, lab._camera, lab._batted_ball)


static func _action_property_intact(lab: PitchBatLab, property: StadiumPropertyGeometry) -> bool:
	# New low46 only. Historical branches and deep bind/report remain unchanged.
	if property.get_script() == StadiumLowWallProperty:
		return (property as StadiumLowWallProperty).issued_props_intact(lab)
	if property.get_script() == StadiumWaterfallAnimationProperty:
		return (property as StadiumWaterfallAnimationProperty).issued_props_intact(lab)
	# Exact new fixed-kit Night owner only; old candidates retain complete guards.
	if (
		is_instance_valid(lab)
		and lab._match_state != null
		and StadiumSurfaceNightSnapshot.is_family(lab._match_state.stadium)
		and StadiumLightingKitNightCandidate.is_candidate_layout(
			lab._match_state.stadium.get("layout")
		)
	):
		var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
		return (
			owner != null
			and owner._kit_mode
			and owner._property == property
			and StadiumSurfaceNightRuntime.action_allowed(lab)
		)
	return property.props_intact()
