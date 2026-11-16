class_name PhysicalStadiumContacts
extends RefCounted
## Bounded report9 surface provenance plus the core baseball and exact ownership proof.
# gdlint: disable=max-returns


static func capture(plays: Array[PlayRecord]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(plays.size()):
		result.append(
			{
				"play": index,
				"reason": String(plays[index].resolution_reason),
				"events": plays[index].stadium_contacts.duplicate(true)
			}
		)
	return result


static func valid(value: Variant, plays: Array, snapshot: Dictionary) -> bool:
	if StadiumSurfaceNightSnapshot.is_wrapped(snapshot):
		# Validate the complete fixed-Night receipt before using its original full
		# ownership. Do not fabricate a stock-only entry8 from the physical projection.
		var original: Dictionary = StadiumSurfaceNightSnapshot.entry(snapshot)
		if not value is Array or value.size() != plays.size() or original.is_empty():
			return false
		var owners: Dictionary = (
			StadiumLowWallSnapshot.ownership(original)
			if int(original.version) == 32
			else StadiumWaterfallAnimationSnapshot.ownership(original)
		)
		return not owners.is_empty() and _owned_rows(value, plays, original, owners)
	if StadiumWaterfallAnimationSnapshot.is_family(snapshot):
		var canonical: Dictionary = StadiumWaterfallAnimationSnapshot.normalized(snapshot)
		return (
			value is Array
			and value.size() == plays.size()
			and not canonical.is_empty()
			and _owned_rows(
				value, plays, canonical, StadiumWaterfallAnimationSnapshot.ownership(canonical)
			)
		)
	if StadiumLowWallSnapshot.is_family(snapshot):
		return (
			value is Array
			and value.size() == plays.size()
			and StadiumLowWallSnapshot.valid(snapshot)
			and _owned_rows(value, plays, snapshot, StadiumLowWallSnapshot.ownership(snapshot))
		)
	if not value is Array or value.size() != plays.size():
		return false
	var layout: Dictionary = StadiumHomeLayout.validate(
		snapshot.layout, StadiumLayoutSnapshot.ownership(snapshot), snapshot.tier
	)
	if not layout.ok:
		return false
	var placements: Dictionary = {}
	for row: Dictionary in layout.placements:
		placements[row.copy] = row
	var graph: StadiumRecipeBoundary = StadiumWallItems.graph_for(snapshot.layout)
	if (
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
							StadiumSmallYardSceneryItems.is_family(snapshot.layout)
							or (
								StadiumMoldedSeatItems.is_family(snapshot.layout)
								or (
									StadiumGroundBoxItems.is_family(snapshot.layout)
									or (
										StadiumPracticeFacilityItems.is_family(snapshot.layout)
										or (
											StadiumTreehouseItems.is_family(snapshot.layout)
											or (
												StadiumLandmarkItems.is_family(snapshot.layout)
												or (
													StadiumOutfieldBleacherItems.is_family(
														snapshot.layout
													)
													or (
														StadiumRisingAppleItems.is_family(
															snapshot.layout
														)
														or (
															StadiumWallTopTerraceItems.is_family(
																snapshot.layout
															)
															or (
																StadiumPlayerTunnelItems.is_family(
																	snapshot.layout
																)
																or (
																	(
																		StadiumMountedDisplayItems
																		. is_family(snapshot.layout)
																	)
																	or (
																		(
																			StadiumStringLightItems
																			. is_family(
																				snapshot.layout
																			)
																		)
																		or (
																			(
																				StadiumSalvageCarItems
																				. is_family(
																					snapshot.layout
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
	):
		graph = StadiumOwnedLayout.graph_for(snapshot.layout)
	var contact_layout: Dictionary = snapshot.layout
	if StadiumWaterfallLiveItems.is_family(contact_layout):
		var normalized: Dictionary = StadiumLayoutSnapshot.normalized(snapshot)
		if normalized.is_empty():
			return false
		contact_layout = normalized.layout
	return _rows(value, plays, placements, graph, contact_layout)


static func scoreboards_valid(value: Variant, plays: Array, snapshot: Dictionary) -> bool:
	if (
		not value is Array
		or value.size() != plays.size()
		or not StadiumScoreboardSnapshot.valid(snapshot)
		or int(snapshot.version) != StadiumScoreboardSnapshot.FIXTURE_VERSION
	):
		return false
	var owners: Dictionary = StadiumScoreboardSnapshot.ownership(snapshot)
	return _owned_rows(value, plays, snapshot, owners)


static func mounted_valid(value: Variant, plays: Array, snapshot: Dictionary) -> bool:
	if (
		not value is Array
		or value.size() != plays.size()
		or not StadiumMountedScoreboardSnapshot.valid(snapshot)
		or int(snapshot.version) != StadiumMountedScoreboardSnapshot.FIXTURE_VERSION
	):
		return false
	return _owned_rows(value, plays, snapshot, StadiumMountedScoreboardSnapshot.ownership(snapshot))


static func _owned_rows(
	value: Array, plays: Array, snapshot: Dictionary, owners: Dictionary
) -> bool:
	var access: Array[String] = []
	access.assign(snapshot.surface_access)
	var layout: Dictionary = StadiumOwnedLayout.validate(
		snapshot.layout, owners.stock, owners.pieces, access, snapshot.tier, owners.boards
	)
	if not layout.ok:
		return false
	var placements: Dictionary = {}
	# Boards and their mount supports are decorative, never live contact targets.
	for row: Dictionary in layout.placements:
		placements[row.copy] = row
	return _rows(
		value, plays, placements, StadiumOwnedLayout.graph_for(snapshot.layout), snapshot.layout
	)


static func _rows(
	value: Array,
	plays: Array,
	placements: Dictionary,
	graph: StadiumRecipeBoundary,
	layout: Dictionary = {}
) -> bool:
	var owned: bool = graph is StadiumBoundaryOwnedGraph
	var previous: int = -1
	for row: Variant in value:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(row, ["play", "reason", "events"])
			or not SeasonOwnership._whole(row.play, previous + 1, previous + 1)
			or not row.events is Array
			or row.events.size() > 128
			or not row.reason is String
			or row.reason.length() > 80
		):
			return false
		previous = int(row.play)
		var play: Variant = plays[previous]
		if not play is Dictionary or not play.get("result") is String:
			return false
		if (
			not row.events.is_empty()
			and (
				not SeasonOwnership._whole(play.get("contact"), 1, 3)
				or not PhysicalMatchReport.number(play.get("exit_speed"), 0.0001, 1000)
			)
		):
			return false
		var required: Array = (
			_owned_reason_roles(row.reason) if owned else _reason_roles(row.reason)
		)
		if (
			row.events.is_empty()
			and (not required.is_empty() or play.result in ["triple", "home_run"])
		):
			return false
		var last_time: float = -1
		for index in range(row.events.size()):
			var event: Variant = row.events[index]
			if not _event(event, placements, graph, layout) or event.time < last_time:
				return false
			last_time = float(event.time)
			if (
				event.role not in ["SIDE_RETURN_LIVE", "LIVE_RICOCHET"]
				and not (owned and event.role == "DUGOUT_FACE_LIVE")
			):
				var terminal: bool = (
					_owned_terminal(event, play, row.reason)
					if owned
					else _terminal(event.role, play)
				)
				if index != row.events.size() - 1 or not terminal or not required.has(event.role):
					return false
		if not required.is_empty() and not required.has(row.events[-1].role):
			return false
	return true


static func _event(
	value: Variant,
	placements: Dictionary,
	graph: StadiumRecipeBoundary = null,
	layout: Dictionary = {}
) -> bool:
	var keys: Array[String] = ["source", "id", "surface", "role", "position", "time", "kind"]
	if value is Dictionary and value.get("role") == StadiumWaterfallLiveRuntime.TRAP_ROLE:
		keys.append_array(
			["waterfall_proof", "earned_floor", "waterfall_layout_hash", "waterfall_floor_evidence"]
		)
	if not value is Dictionary or not SeasonOwnership._keys(value, keys):
		return false
	for key: String in ["source", "id", "surface", "role", "kind"]:
		if not value[key] is String:
			return false
	if (
		not PhysicalMatchReport.number(value.time, 0, 3600)
		or not value.position is Array
		or value.position.size() != 3
	):
		return false
	for coordinate: Variant in value.position:
		if not PhysicalMatchReport.number(coordinate, -1000, 1000):
			return false
	var point: Vector3 = Vector3(value.position[0], value.position[1], value.position[2])
	if value.source == "item":
		if value.kind != "contact" or not placements.has(value.id):
			return false
		var placed: Dictionary = placements[value.id]
		if placed.item == "ST-046":
			return _waterfall_event(value, point, placed, layout)
		if placed.item == "ST-005":
			return _car_event(value, point, placed)
		if StadiumStringLightItems.PRICES.has(placed.item):
			return false  # Fixed decorative spans supply no live or scoring contact.
		if StadiumMountedDisplayItems.PRICES.has(placed.item):
			return false  # Rigid display art and simulation clock supply no scoring contact.
		if StadiumPlayerTunnelItems.PRICES.has(placed.item):
			return false  # Tunnel geometry is reached only after the existing dead boundary.
		if StadiumWallTopTerraceItems.PRICES.has(placed.item):
			return false  # The independent terrace cannot replace its terminal scoring wall.
		if StadiumRisingAppleItems.PRICES.has(placed.item):
			return false  # Confirmed-HR presentation never supplies a scoring contact.
		if StadiumOutfieldBleacherItems.PRICES.has(placed.item):
			return false  # Complete elevated bleachers have no live/contact/scoring authority.
		if StadiumLandmarkItems.PRICES.has(placed.item):
			return false  # Complete landmarks are scenery with no contact or scoring authority.
		if StadiumTreehouseItems.PRICES.has(placed.item):
			return false  # The complete treehouse is scenery, with no climbing or contact authority.
		if StadiumPracticeFacilityItems.PRICES.has(placed.item):
			return false  # Complete practice scenery has no receiver, live or scoring authority.
		if StadiumGroundBoxItems.PRICES.has(placed.item):
			return false  # Complete ground boxes have no live/scoring contact authority.
		if StadiumMoldedSeatItems.PRICES.has(placed.item):
			return false  # Seats and their fixed pad have no live/scoring contact authority.
		if StadiumSmallYardSceneryItems.ITEMS.has(placed.item) and placed.site.begins_with("YS-"):
			return false  # A paid scenery copy has no physical/report contact authority.
		if StadiumLiveFurnishingItems.PRICES.has(placed.item):
			if (
				placed.role != "LIVE_RICOCHET"
				or placed.site not in ["O-L1", "O-L2", "O-R1", "O-R2", "OL-L", "OL-R"]
			):
				return false
			if value.role == "LIVE_RICOCHET":
				return (
					StadiumLiveFurnishingModels.surfaces(placed.item).has(value.surface)
					and StadiumHomeLayout.bounds(placed).grow(0.1).has_point(point)
				)
			# The unchanged recorder snaps each coordinate to 0.0001 m: half a cell per axis.
			return (
				placed.item == "ST-007"
				and value.role == StadiumLiveFurnishingRuntime.WATER_ROLE
				and value.surface == StadiumLiveFurnishingRuntime.WATER_SURFACE
				and (
					StadiumLiveFurnishingRuntime.water_distance_squared(point - placed.position)
					< pow(
						(
							(
								ContentDB
								. get_ball_setup(PitchBatLab.BALL_SETUP_ID)
								. aero_profile
								. radius_m
							)
							+ sqrt(3.0) * 0.00005
						),
						2
					)
				)
			)
		var surfaces: Array[String] = (
			StadiumReceiverOwnedModels.surfaces(placed.item)
			if StadiumReceiverOwnedItems.PRICES.has(placed.item)
			else (
				StadiumGroundPropsModels.surfaces(placed.item)
				if StadiumGroundPropsItems.LIVE.has(placed.item)
				else (
					StadiumNetModels.surfaces()
					if placed.item == "ST-025"
					else (
						StadiumTargetModels.surfaces()
						if placed.item == "ST-026"
						else StadiumStarterModels.surfaces(placed.item)
					)
				)
			)
		)
		return (
			value.role == placed.role
			and surfaces.has(value.surface)
			and StadiumHomeLayout.bounds(placed).grow(0.1).has_point(point)
		)
	var graph_id: String = StadiumBoundaryGraph.ID if graph == null else graph.identity()
	if (
		value.source != "boundary"
		or value.id != graph_id
		or value.kind not in ["contact", "crossing"]
	):
		return false
	if (
		graph is StadiumBoundaryOwnedGraph
		and (
			value.surface.begins_with("DUGOUT-")
			or value.surface.begins_with("FOUL-POLE-")
			or value.surface.begins_with("DISTANCE:")
		)
	):
		return _owned_event(value, point, placements, graph)
	if graph is StadiumLowWallGraph and value.surface.begins_with("LOW46-BACK-"):
		return _low_wall_event(value, point, graph)
	var segment: Dictionary = (
		StadiumBoundaryGraph.segment(value.surface)
		if graph == null
		else (graph.segment(value.surface))
	)
	if segment.is_empty():
		return false
	var allowed: Array = [segment.role]
	if value.kind == "crossing":
		if segment.role == "SIDE_RETURN_LIVE":
			allowed.append("SIDE_EXIT_DEAD")
		elif segment.role == "BACK_WALL_TERMINAL":
			allowed.append("BACK_CLEAR")
	if not allowed.has(value.role):
		return false
	var position: Vector2 = Vector2(point.x, point.z)
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(position, segment.a, segment.b)
	if closest.distance_to(position) > 0.05 or point.y < -0.05:
		return false
	if value.role in ["SIDE_EXIT_DEAD", "BACK_CLEAR"]:
		return point.y >= segment.height - 0.0001
	return (
		point.y <= segment.height + 0.05
		or (value.kind == "crossing" and value.role == "REAR_PERIMETER_DEAD")
	)


static func _car_event(value: Dictionary, point: Vector3, placed: Dictionary) -> bool:
	if (
		placed.role != "LIVE_RICOCHET"
		or placed.site != StadiumSalvageCarItems.SITE
		or placed.position != StadiumSalvageCarItems.POSITION
		or float(placed.yaw) != 0
	):
		return false
	if value.role == "LIVE_RICOCHET":
		return (
			value.surface == StadiumJunkCarModels.SURFACE
			and StadiumHomeLayout.bounds(placed).grow(0.1).has_point(point)
		)
	# Recorder rounds each coordinate to 0.0001m. Only that rounding allowance
	# relaxes the complete-sphere cavity test, never the whole-car broad phase.
	var radius: float = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID).aero_profile.radius_m
	return (
		value.role == StadiumJunkCarRuntime.TRAP_ROLE
		and value.surface == StadiumJunkCarModels.TRAP_ID
		and value.time + 0.0001 >= StadiumJunkCarRuntime.SETTLED_DWELL
		and StadiumJunkCarModels.trap_contains_local(
			point - placed.position, radius - sqrt(3.0) * 0.00005
		)
	)


static func _terminal(role: String, play: Dictionary) -> bool:
	if (
		play.contact == ContactResult.Outcome.FOUL
		or role in ["REAR_PERIMETER_DEAD", "RECEIVER_CONTAINMENT_FOUL"]
	):
		return play.result == "foul"
	if role == "SIDE_EXIT_DEAD":
		return play.result in ["single", "double"]
	if role == "BACK_WALL_TERMINAL":
		return play.result in ["double", "triple"]
	return role == "BACK_CLEAR" and play.result in ["double", "home_run"]


static func _reason_roles(reason: String) -> Array:
	match reason:
		"back_wall_on_fly", "bounce_to_back_wall", "foul_back_wall":
			return ["BACK_WALL_TERMINAL", "BACK_CLEAR"]
		"cleared_hr_boundary":
			return ["BACK_CLEAR"]
		"side_exit":
			return ["SIDE_EXIT_DEAD"]
		"rear_perimeter":
			return ["REAR_PERIMETER_DEAD"]
		"receiver_containment":
			return ["RECEIVER_CONTAINMENT_FOUL"]
	return []


# Version 23 keeps the report schema. A named site resolves one validated paid copy;
# decorative surfaces and undeclared body names are never admitted.
static func _owned_event(
	value: Dictionary, point: Vector3, placements: Dictionary, graph: StadiumBoundaryOwnedGraph
) -> bool:
	if value.surface.begins_with("FOUL-POLE-"):
		var pole: Dictionary = _owned_site(placements, value.surface)
		if pole.get("item") != "ST-021" or value.kind != "contact":
			return false
		for socket: Dictionary in StadiumFoulPoleSites.rows(graph):
			if socket.site != pole.site:
				continue
			if (
				pole.position != socket.position
				or not is_equal_approx(float(pole.split), float(socket.split))
			):
				return false
			var local: Vector3 = point - socket.position
			return (
				Vector2(local.x, local.z).length() <= float(socket.radius) + 0.05
				and local.y >= -0.05
				and local.y <= float(socket.height) + 0.05
				and (
					value.role
					== StadiumFoulPoleModels.role_at(
						clampf(local.y, 0, socket.height), socket.split
					)
				)
			)
		return false
	if value.surface.begins_with("DISTANCE:"):
		for placed: Dictionary in placements.values():
			if (
				placed.item != "ST-064"
				or (
					value.surface
					not in [
						placed.site + ":DistancePanel",
						placed.site + ":PanelMount-1",
						placed.site + ":PanelMount1"
					]
				)
			):
				continue
			if (
				value.kind != "contact"
				or value.role != "BACK_WALL_TERMINAL"
				or placed.host.is_empty()
				or placed.site != "DISTANCE:" + placed.host
				or placed.get("host_span") != "full"
			):
				return false
			var center: Vector3 = Vector3(0, 0, 0.04)
			var size: Vector3 = Vector3(1.4, 0.55, 0.04)
			if not value.surface.ends_with(":DistancePanel"):
				center = Vector3(-0.5 if value.surface.ends_with(":PanelMount-1") else 0.5, 0, 0.01)
				size = Vector3(0.08, 0.40, 0.02)
			return _owned_box(placed, point, center, size)
		return false
	var site: String = "DUGOUT-L" if value.surface.begins_with("DUGOUT-L") else "DUGOUT-R"
	var dugout: Dictionary = _owned_site(placements, site)
	if (
		dugout.get("item", "") not in StadiumBoundaryItems.DUGOUTS
		or graph.owned_sides.get(site, "") != dugout.item
	):
		return false
	var segment: Dictionary = graph.segment(value.surface)
	if not segment.is_empty():
		if segment.role == "DUGOUT_FACE_LIVE" and value.kind == "contact":
			var inner: bool = value.surface == site + "-FACE-IN"
			var side: float = -1.0 if inner == (site == "DUGOUT-L") else 1.0
			var depth: float = 0.18 if dugout.item == "ST-032" else 0.20
			return (
				value.role == "DUGOUT_FACE_LIVE"
				and _owned_box(
					dugout, point, Vector3(side * 2, 0.6, depth / 2), Vector3(2, 1.2, depth)
				)
			)
		if value.kind != "crossing":
			return false
		var position: Vector2 = Vector2(point.x, point.z)
		if (
			(
				Geometry2D.get_closest_point_to_segment(position, segment.a, segment.b).distance_to(
					position
				)
				> 0.05
			)
			or point.y < -0.05
		):
			return false
		if value.role == segment.role:
			return point.y <= float(segment.height) + StadiumRecipeBoundary.EPS
		return (
			point.y > float(segment.height) + StadiumRecipeBoundary.EPS
			and (
				(segment.role == "DUGOUT_FACE_LIVE" and value.role == "SIDE_EXIT_DEAD")
				or (segment.role == "DUGOUT_OPENING_DEAD" and value.role == "DUGOUT_EXTERIOR_DEAD")
			)
		)
	if dugout.item != "ST-074" or value.kind != "contact":
		return false
	var body: String = value.surface.trim_prefix(site + ":")
	if value.role == "DUGOUT_ROOF_TERMINAL":
		if body == "Roof":
			return _owned_box(dugout, point, Vector3(0, 2.55, 1.325), Vector3(6, 0.3, 2.65))
		if body in ["RoofSupport-1", "RoofSupport1"]:
			return _owned_box(
				dugout,
				point,
				Vector3(-2.8 if body == "RoofSupport-1" else 2.8, 1.8, 0.12),
				Vector3(0.2, 1.2, 0.24)
			)
	elif value.role == "DUGOUT_EXTERIOR_DEAD":
		if body == "Rear":
			return _owned_box(dugout, point, Vector3(0, 1.2, 2.575), Vector3(6, 2.4, 0.15))
		if body in ["EndWall-1", "EndWall1"]:
			return _owned_box(
				dugout,
				point,
				Vector3(-2.925 if body == "EndWall-1" else 2.925, 1.2, 1.325),
				Vector3(0.15, 2.4, 2.65)
			)
	return false


static func _owned_site(placements: Dictionary, site: String) -> Dictionary:
	var found: Dictionary = {}
	for placed: Dictionary in placements.values():
		if placed.get("site", "") == site and StadiumBoundaryItems.PRICES.has(placed.item):
			if not found.is_empty():
				return {}
			found = placed
	return found


static func _owned_box(row: Dictionary, point: Vector3, center: Vector3, size: Vector3) -> bool:
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position)
	return AABB(center - size / 2, size).grow(0.05).has_point(pose.affine_inverse() * point)


static func _owned_terminal(event: Dictionary, play: Dictionary, reason: String) -> bool:
	if event.role == StadiumWaterfallLiveRuntime.TRAP_ROLE:
		if reason == "waterfall_basin_foul":
			return play.contact == ContactResult.Outcome.FOUL and play.result == "foul"
		var expected: String = ["single", "single", "double", "triple", "home_run"][int(
			event.earned_floor
		)]
		return (
			play.contact != ContactResult.Outcome.FOUL
			and reason == "waterfall_basin_minimum_single"
			and play.result == expected
		)
	if event.role == StadiumJunkCarRuntime.TRAP_ROLE:
		if reason == "junk_car_underbody_foul":
			return play.contact == ContactResult.Outcome.FOUL and play.result == "foul"
		return (
			play.contact != ContactResult.Outcome.FOUL
			and reason == "junk_car_underbody_minimum_single"
			and play.result in ["single", "double", "triple", "home_run"]
		)
	if event.role == StadiumLiveFurnishingRuntime.WATER_ROLE:
		if reason == "hot_tub_water_foul":
			return play.contact == ContactResult.Outcome.FOUL and play.result == "foul"
		return (
			play.contact != ContactResult.Outcome.FOUL
			and reason == "hot_tub_water_minimum_double"
			and play.result in ["double", "triple", "home_run"]
		)
	if event.role in ["FOUL_POLE_LOWER", "FOUL_POLE_UPPER"]:
		# A real pole makes the contact fair, even when the initial bat contact was foul.
		if reason == "foul_pole_upper":
			return event.role == "FOUL_POLE_UPPER" and play.result == "home_run"
		if reason == "back_wall_on_fly":
			return play.result in ["triple", "home_run"]
		return reason == "bounce_to_back_wall" and play.result in ["double", "triple", "home_run"]
	if (
		event.surface.begins_with("DUGOUT-")
		and (
			event.role
			in [
				"DUGOUT_OPENING_DEAD",
				"DUGOUT_EXTERIOR_DEAD",
				"DUGOUT_ROOF_TERMINAL",
				"SIDE_EXIT_DEAD"
			]
		)
	):
		var expected: String = (
			"dugout_terminal" if event.surface.contains(":") else event.role.to_lower()
		)
		if reason != expected:
			return false
		return (
			play.result == "foul"
			if play.contact == ContactResult.Outcome.FOUL
			else (play.result in ["single", "double", "triple", "home_run"])
		)
	if event.surface.begins_with("DISTANCE:") and event.role == "BACK_WALL_TERMINAL":
		if play.contact == ContactResult.Outcome.FOUL:
			return reason == "foul_back_wall" and play.result == "foul"
		if reason == "back_wall_on_fly":
			return play.result in ["triple", "home_run"]
		return reason == "bounce_to_back_wall" and play.result in ["double", "triple", "home_run"]
	return _terminal(event.role, play)


static func _owned_reason_roles(reason: String) -> Array:
	match reason:
		"waterfall_basin_foul", "waterfall_basin_minimum_single":
			return [StadiumWaterfallLiveRuntime.TRAP_ROLE]
		"junk_car_underbody_foul", "junk_car_underbody_minimum_single":
			return [StadiumJunkCarRuntime.TRAP_ROLE]
		"hot_tub_water_foul", "hot_tub_water_minimum_double":
			return [StadiumLiveFurnishingRuntime.WATER_ROLE]
		"dugout_opening_dead":
			return ["DUGOUT_OPENING_DEAD"]
		"dugout_exterior_dead":
			return ["DUGOUT_EXTERIOR_DEAD"]
		"dugout_terminal":
			return ["DUGOUT_ROOF_TERMINAL", "DUGOUT_EXTERIOR_DEAD"]
		"side_exit_dead":
			return ["SIDE_EXIT_DEAD"]
		"foul_pole_upper":
			return ["FOUL_POLE_UPPER"]
		"back_wall_on_fly", "bounce_to_back_wall":
			return ["BACK_WALL_TERMINAL", "BACK_CLEAR", "FOUL_POLE_LOWER", "FOUL_POLE_UPPER"]
	return _reason_roles(reason)


static func _low_wall_event(value: Dictionary, point: Vector3, graph: StadiumLowWallGraph) -> bool:
	for row: Dictionary in graph.segments():
		if row.id != value.surface:
			continue
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID).aero_profile.radius_m
		if value.role == "BACK_CLEAR":
			return (
				value.kind == "crossing"
				and point.y > row.height + StadiumRecipeBoundary.EPS
				and (
					Vector2(point.x, point.z).distance_to(
						Geometry2D.get_closest_point_to_segment(
							Vector2(point.x, point.z), row.a, row.b
						)
					)
					<= 0.0001
				)
			)
		if value.role != "BACK_WALL_TERMINAL" or value.kind not in ["contact", "crossing"]:
			return false
		# Native manifold contacts record a point on the solid. Inherited graph.apply
		# records sphere sweeps as crossing (they carry fraction), at the sphere center.
		# Preserve that issued evidence and awards, rather than rewriting its kind/point.
		var lower: Vector3 = Vector3(minf(row.a.x, row.b.x), 0.0, row.a.y)
		var upper: Vector3 = Vector3(
			maxf(row.a.x, row.b.x), row.height, row.a.y + StadiumRecipeBoundary.THICKNESS
		)
		var allowance: float = 0.0001  # Four-decimal recorder + native real_t rounding.
		var distance: float = point.distance_to(point.clamp(lower, upper))
		# The inherited native manifold fallback also retains fraction and therefore
		# records kind=crossing. Accept only its face OR the swept-center shell.
		var face_distance: float = minf(
			minf(absf(point.x - lower.x), absf(point.x - upper.x)),
			minf(
				minf(absf(point.y - lower.y), absf(point.y - upper.y)),
				minf(absf(point.z - lower.z), absf(point.z - upper.z))
			)
		)
		var on_face: bool = distance <= allowance and face_distance <= allowance
		return on_face or (value.kind == "crossing" and absf(distance - sphere.radius) <= allowance)
	return false


static func _waterfall_event(
	value: Dictionary, point: Vector3, placed: Dictionary, layout: Dictionary
) -> bool:
	if (
		not (
			StadiumWaterfallLiveItems.is_family(layout)
			or (
				StadiumWaterfallAnimationLayout.is_family(layout)
				and layout.get("animation_base") == 45
			)
		)
		or placed.role != "LIVE_RICOCHET"
		or placed.site != StadiumWaterfallLiveSites.SITE
		or placed.position != StadiumWaterfallLiveSites.CENTER
		or float(placed.yaw) != 0
	):
		return false
	if value.role == "LIVE_RICOCHET":
		if value.surface != StadiumWaterfallLiveModels.SURFACE:
			return false
		for solid: Dictionary in StadiumWaterfallLiveModels.solid_specs():
			if solid.bounds.grow(0.1).has_point(point - placed.position):
				return true
		return false
	if (
		value.role != StadiumWaterfallLiveRuntime.TRAP_ROLE
		or value.surface != StadiumWaterfallLiveModels.TRAP_ID
		or not SeasonOwnership._whole(value.earned_floor, 0, 4)
		or not value.waterfall_layout_hash is String
		or value.waterfall_layout_hash != JSON.stringify(layout, "", true, true).sha256_text()
	):
		return false
	var proof: Dictionary = StadiumWaterfallLiveRuntime.proof_from_data(value.waterfall_proof)
	# Match the exact native real_t sphere radius, not an approximate authored double.
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID).aero_profile.radius_m
	var radius: float = sphere.radius
	return (
		not proof.is_empty()
		and proof.copy == placed.copy
		and proof.radius == radius
		and absf(float(value.time) - proof.observed_at) <= 0.000051
		and point.distance_to(proof.position + placed.position) <= sqrt(3.0) * 0.000051
		and StadiumWaterfallLiveModels.trap_contains_local(proof.position, proof.radius)
		and StadiumWaterfallLiveRuntime.floor_evidence_valid(
			value.waterfall_floor_evidence,
			proof,
			int(value.earned_floor),
			ContentDB.get_field(PitchBatLab.FIELD_ID)
		)
	)
