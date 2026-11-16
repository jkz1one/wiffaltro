class_name StadiumDraftPreview
extends SubViewportContainer
## Read-only private World3D. Never modifies the live match world or publishes a field layout.

var camera: Camera3D
var positions: Dictionary = {}
var items: Dictionary = {}
var board_bounds: Dictionary = {}
var seating_layout: bool = false
var property_tier: String = "backyard"
var labels: Array[Label3D] = []
var night_eligible: bool = false
var night_preview: bool = false
var preview_property: StadiumPropertyGeometry
var preview_environment: WorldEnvironment
var preview_sun: DirectionalLight3D
var daylight: Environment
var pool_model: Node3D
var pool_preview_status: Dictionary = {}
var lighting_kit_preview: StadiumLightingKitPreviewRuntime
var _waterfall_motion_pending: float = 0.0


func build(
	layout: Dictionary,
	stock: StadiumStock,
	complete_boundary: bool = true,
	tier: String = "backyard",
	pieces: StadiumWallPieceOwnership = null,
	boards: StadiumScoreboardOwnership = null,
	access: Array[String] = []
) -> void:
	if StadiumPoolWorkshopUI.pool_intent(layout):
		_clear_pool_preview()
		pool_preview_status = (
			StadiumStarterLayout
			. _error(
				"Pool requires the dedicated read-only preview with complete ownership and revision context."
			)
		)
		return
	var checked: Dictionary = StadiumOwnedLayout.validate(
		layout, stock, pieces, access, tier, boards
	)
	night_eligible = checked.get("night_qualified", false)
	property_tier = tier
	seating_layout = (
		SeasonOwnership._whole(layout.get("version"), 2, 15)
		or (
			StadiumBoundaryItems.is_family(layout)
			or (
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
														StadiumOutfieldBleacherItems.is_family(
															layout
														)
														or (
															StadiumRisingAppleItems.is_family(
																layout
															)
															or (
																(
																	StadiumWallTopTerraceItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumPlayerTunnelItems
																		. is_family(layout)
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
																					. is_family(
																						layout
																					)
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
		)
	)
	stretch = true
	custom_minimum_size = Vector2(0, 320)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var root: Node3D = Node3D.new()
	viewport.add_child(root)
	var property: StadiumPropertyGeometry = (
		StadiumWaterfallAnimationProperty.new()
		if StadiumWaterfallAnimationLayout.is_family(layout)
		else (
			StadiumLowWallProperty.new()
			if StadiumLowWallLayout.is_family(layout)
			else (
				StadiumScoreboardPropertyGeometry.new()
				if SeasonOwnership._whole(layout.get("version"), 14, 15)
				else (
					StadiumAdvancedPropertyGeometry.new()
					if layout.get("version") == 13
					else StadiumPropertyGeometry.new()
				)
			)
		)
	)
	root.add_child(property)
	preview_property = property
	var built: bool = false
	if checked.ok:
		if property is StadiumWaterfallAnimationProperty:
			built = property.build_complete(tier, layout, stock, pieces, boards, access)
			if built and complete_boundary:
				var animated_boundary: StadiumBoundaryOwnedRuntime
				if layout.animation_base == 46:
					animated_boundary = StadiumWaterfallAnimationLowBoundary.new()
					animated_boundary.name = "BoundaryGraph"
					built = animated_boundary.build_complete(
						property, property.base_layout, stock, pieces, access, property.base_checked
					)
				else:
					animated_boundary = StadiumWaterfallAnimationBoundary.new()
					animated_boundary.name = "BoundaryGraph"
					built = animated_boundary.build_from(
						property, property.get_meta("boundary_layout"), stock
					)
				if built:
					property.get_node("TemplateBackWall").free()
					property.add_child(animated_boundary)
				else:
					animated_boundary.free()
		elif property is StadiumLowWallProperty:
			built = property.build_complete(tier, layout, stock, pieces, access)
			if built and complete_boundary:
				var low_boundary: StadiumLowWallBoundaryRuntime = (
					StadiumLowWallBoundaryRuntime.new()
				)
				low_boundary.name = "BoundaryGraph"
				built = low_boundary.build_complete(
					property, layout, stock, pieces, access, checked
				)
				if built:
					property.get_node("TemplateBackWall").free()
					property.add_child(low_boundary)
				else:
					low_boundary.free()
		elif property is StadiumScoreboardPropertyGeometry:
			built = property.build_scoreboards(tier, layout, stock, pieces, boards, access)
		elif property is StadiumAdvancedPropertyGeometry:
			built = property.build_owned(tier, layout, stock, pieces, access)
		else:
			built = property.build(property_tier, layout, stock)
			if built and complete_boundary:
				built = StadiumBoundaryRuntime.assemble(property) != null
	if built:
		for copy: String in property.objects:
			if property.objects[copy] is StadiumPennantMotion:
				(property.objects[copy] as StadiumPennantMotion).bind_preview()
			positions[copy] = property.objects[copy].position
			items[copy] = property.objects[copy].get_meta("stadium_item")
		for row: Dictionary in checked.placements:
			if row.item == "ST-046":
				board_bounds[row.copy] = StadiumWaterfallItems.bounds(row)
			elif row.item == "ST-067":
				board_bounds[row.copy] = StadiumMasteryBannerItems.bounds(row)
			elif row.item == "ST-005":
				board_bounds[row.copy] = StadiumHomeLayout.bounds(row)
			elif StadiumStringLightItems.ITEMS.has(row.item):
				board_bounds[row.copy] = StadiumStringLightItems.bounds(row)
			elif StadiumMountedDisplayItems.ITEMS.has(row.item):
				board_bounds[row.copy] = StadiumMountedDisplayItems.bounds(row)
			elif row.item == "ST-058":
				board_bounds[row.copy] = StadiumPlayerTunnelItems.bounds(row)
			elif row.item == "ST-087":
				board_bounds[row.copy] = StadiumWallTopTerraceItems.bounds(row)
			elif row.item == "ST-047":
				board_bounds[row.copy] = StadiumRisingAppleItems.bounds(row)
			elif row.item == "ST-054":
				board_bounds[row.copy] = StadiumOutfieldBleacherItems.bounds(row)
			elif row.item in ["ST-048", "ST-049", "ST-050"]:
				board_bounds[row.copy] = StadiumLandmarkItems.bounds(row)
			elif row.item == "ST-045":
				board_bounds[row.copy] = StadiumTreehouseItems.bounds(row)
			elif row.item in ["ST-060", "ST-061"]:
				board_bounds[row.copy] = StadiumPracticeFacilityItems.bounds(row)
			elif row.item == "ST-052":
				board_bounds[row.copy] = StadiumGroundBoxItems.bounds(row)
			elif row.item == "ST-051":
				board_bounds[row.copy] = StadiumMoldedSeatItems.bounds(row)
			elif StadiumSmallYardSceneryItems.ITEMS.has(row.item) and row.site.begins_with("YS-"):
				board_bounds[row.copy] = StadiumSmallYardSceneryItems.bounds(row)
			elif StadiumLiveFurnishingItems.PRICES.has(row.item):
				board_bounds[row.copy] = StadiumLiveFurnishingItems.bounds(row)
			elif StadiumLandscapeOwnedItems.PRICES.has(row.item):
				board_bounds[row.copy] = StadiumLandscapeOwnedItems.bounds(row)
			elif StadiumBoundaryItems.PRICES.has(row.item):
				board_bounds[row.copy] = StadiumBoundaryItems.bounds(row)
			elif StadiumFacilityItems.PRICES.has(row.item):
				board_bounds[row.copy] = StadiumFacilityItems.bounds(row)
			elif StadiumRoofItems.PRICES.has(row.item):
				board_bounds[row.copy] = StadiumRoofItems.bounds(row)
			elif (
				StadiumStraightItems.HOSTS.has(row.item)
				or StadiumStraightItems.MOUNTS.has(row.item)
			):
				board_bounds[row.copy] = StadiumStraightItems.bounds(row)
		for row: Dictionary in checked.get("board_placements", []):
			board_bounds[row.copy] = StadiumScoreboardAssembly.bounds(row)
	for site: String in StadiumStarterLayout.SITES:
		var label: Label3D = Label3D.new()
		label.text = site
		label.position = StadiumStarterLayout.SITES[site] + Vector3(0, 1.1, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.pixel_size = 0.04
		labels.append(label)
		root.add_child(label)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 0.70
	light.shadow_enabled = true
	root.add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111e1c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.35
	root.add_child(environment)
	preview_environment = environment
	preview_sun = light
	daylight = environment.environment.duplicate(true)
	if checked.ok and not checked.get("lighting_kit_placements", []).is_empty():
		var kit_row: Dictionary = checked.lighting_kit_placements[0]
		var poles: Array[Node3D] = []
		if kit_row.site == "MIXED_EDGE":
			for model: Node3D in preview_property.objects.values():
				if model.get_meta("stadium_item", "") == "ST-037":
					poles.append(model)
		lighting_kit_preview = StadiumLightingKitPreviewRuntime.install(
			preview_property, environment, light, preview_property.objects[kit_row.copy], poles
		)
	camera = Camera3D.new()
	camera.fov = 50
	root.add_child(camera)
	camera.make_current()
	overview(false)


func overview(reveal: bool = true) -> void:
	for label: Label3D in labels:
		label.visible = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = (
		maxf(48, StadiumProperty.BOUNDS[property_tier].size.y + 6)
		if property_tier != "backyard"
		else 48 if seating_layout else 40
	)
	camera.position = Vector3(0, 48, -18)
	camera.look_at(Vector3(0, 0, 11))
	# Construction sets the camera without scrolling away from the workshop summary.
	if reveal:
		_reveal.call_deferred()


func focus_copy(id: String) -> void:
	if not positions.has(id):
		return
	for label: Label3D in labels:
		label.visible = false
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var point: Vector3 = positions[id]
	if board_bounds.has(id):
		var bounds: AABB = board_bounds[id]
		var center: Vector3 = bounds.get_center()
		var distance: float = maxf(bounds.size.x, bounds.size.y) * 1.8
		if items.get(id, "") == "ST-036":
			# A span can run along depth, not just width. Fit its complete bounding
			# sphere within both viewport axes without altering legacy item views.
			var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
			var aspect: float = maxf(viewport_size.x / maxf(viewport_size.y, 1.0), 0.01)
			var half_angle: float = deg_to_rad(camera.fov) * 0.5
			if camera.keep_aspect == Camera3D.KEEP_WIDTH:
				half_angle = minf(half_angle, atan(tan(half_angle) / aspect))
			else:
				half_angle = minf(half_angle, atan(tan(half_angle) * aspect))
			distance = bounds.size.length() * 0.5 / sin(half_angle) * 1.1
			camera.position = center + Vector3(0.65, 0.75, -1.8).normalized() * distance
		elif (
			(
				items.get(id, "")
				in [
					"ST-045",
					"ST-046",
					"ST-047",
					"ST-048",
					"ST-049",
					"ST-050",
					"ST-051",
					"ST-052",
					"ST-054",
					"ST-058",
					"ST-060",
					"ST-061"
				]
			)
			or StadiumLandscapeOwnedItems.PRICES.has(items.get(id, ""))
			or StadiumLiveFurnishingItems.PRICES.has(items.get(id, ""))
			or StadiumSmallYardSceneryItems.ITEMS.has(items.get(id, ""))
		):
			var extent: float = maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
			distance = extent * 1.8
			camera.position = center + Vector3(extent * 0.65, extent * 0.75, -distance)
		else:
			camera.position = (
				center + Vector3(bounds.size.x * 0.12, bounds.size.y * 0.06, -distance)
			)
		camera.look_at(center)
		_reveal()
		return
	camera.position = (
		point
		+ (
			Vector3(6 if point.x < 0 else -6, 3, 5)
			if items.get(id) == "ST-027"
			else Vector3(1.6, 1.2, 2.5)
		)
	)
	var focus: Vector3 = point + Vector3(0, 0.4, 0)
	if items.get(id) == "ST-037":
		camera.position = point + Vector3(8 if point.x < 0 else -8, 6, 8)
		focus = point + Vector3(0, 3.3, 0)
	elif items.get(id) == "ST-025":
		camera.position = point + Vector3(4.6, 3.4, 4.8)
		focus = point + Vector3(0, 1.1, 0)
	elif items.get(id) == "ST-026":
		camera.position = point + Vector3(1.9, 1.6, 2.8)
		focus = point + Vector3(0, 0.8, 0)
	elif StadiumPurchases.BLEACHERS.has(items.get(id, "")):
		camera.position = point + Vector3(8 if point.x < 0 else -8, 4, 7)
		focus = point + Vector3(0, 1.8, 0)
	elif items.get(id) == "ST-039":
		camera.position = point + Vector3(2, 3.3, -6)
		focus = point + Vector3(0, 2.1, 0)
	elif items.get(id) == "ST-041":
		camera.position = point + Vector3(3 if point.x < 0 else -3, 2.1, 4)
		focus = point + Vector3(0, 1.1, 0)
	camera.look_at(focus)
	_reveal()


func _reveal() -> void:
	var parent: Node = get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(self)
			break
		parent = parent.get_parent()


func toggle_environment() -> void:
	if is_instance_valid(lighting_kit_preview):
		if lighting_kit_preview.set_night(not lighting_kit_preview.active):
			night_preview = lighting_kit_preview.active
		return
	if not night_eligible:
		return
	night_preview = not night_preview
	for model: Node3D in preview_property.objects.values():
		if model.get_meta("stadium_item", "") == "ST-037":
			StadiumYardLightModels.night(model, night_preview)
	StadiumInfieldNightPresentation.apply(preview_property, night_preview)
	if night_preview:
		StadiumYardNightPrototype.apply_scene(
			preview_property, preview_environment.environment, preview_sun
		)
	else:
		preview_environment.environment = daylight.duplicate(true)
		preview_sun.light_color = Color.WHITE
		preview_sun.light_energy = 0.70


func build_pool_readonly(
	layout: Variant,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership,
	access: Array[String],
	tier: String,
	revision: int,
	current_revision: int
) -> Dictionary:
	_clear_pool_preview()
	pool_preview_status = StadiumPoolWorkshopUI.inspect(
		layout, stock, pieces, boards, access, tier, revision, current_revision
	)
	if not pool_preview_status.ok:
		return pool_preview_status.duplicate(true)
	# Validation precedes all prospective nodes. No live installer or authority is involved.
	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var root: Node3D = Node3D.new()
	viewport.add_child(root)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	root.add_child(property)
	if not property.build(tier, StadiumPoolOwnedLayout.base(layout), stock):
		viewport.free()
		pool_preview_status = StadiumStarterLayout._error("Pool preview base could not be built.")
		return pool_preview_status.duplicate(true)
	var template_wall: Node = property.get_node_or_null("TemplateBackWall")
	var boundary: Node3D = StadiumBoundaryRuntime.assemble(property)
	if is_instance_valid(template_wall) and template_wall.get_parent() == null:
		template_wall.free()
	if boundary == null:
		viewport.free()
		pool_preview_status = StadiumStarterLayout._error(
			"Pool preview boundary could not be built."
		)
		return pool_preview_status.duplicate(true)
	var model: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.SCENERY)
	if model == null:
		viewport.free()
		pool_preview_status = StadiumStarterLayout._error("Pool preview model could not be built.")
		return pool_preview_status.duplicate(true)
	model.transform = StadiumPoolOwnedLayout.pose(layout)
	property.add_child(model)
	# Copy identity lives outside the preserved scenery tree, as in owned installation.
	property.objects[pool_preview_status.copy] = model
	for copy: String in property.objects:
		positions[copy] = property.objects[copy].position
		items[copy] = property.objects[copy].get_meta("stadium_item")
	pool_model = model
	preview_property = property
	property_tier = tier
	seating_layout = true
	stretch = true
	custom_minimum_size = Vector2(0, 320)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 0.70
	light.shadow_enabled = true
	root.add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111e1c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.35
	root.add_child(environment)
	preview_environment = environment
	preview_sun = light
	daylight = environment.environment.duplicate(true)
	camera = Camera3D.new()
	camera.fov = 50
	root.add_child(camera)
	add_child(viewport)
	camera.make_current()
	overview()
	return pool_preview_status.duplicate(true)


func _clear_pool_preview() -> void:
	# A rejected reopen must not retain an earlier successful World3D or any model references.
	for child: Node in get_children():
		remove_child(child)
		child.free()
	camera = null
	pool_model = null
	preview_property = null
	preview_environment = null
	preview_sun = null
	daylight = null
	positions.clear()
	items.clear()
	board_bounds.clear()
	labels.clear()
	night_eligible = false
	night_preview = false
	seating_layout = false
	property_tier = "backyard"
	pool_preview_status = {}


func _process(delta: float) -> void:
	if (
		not is_instance_valid(preview_property)
		or not preview_property is StadiumWaterfallAnimationProperty
		or preview_property._waterfall_animation == null
	):
		return
	if (
		not is_finite(delta)
		or delta < 0
		or delta > 0.25
		or not is_visible_in_tree()
		or get_tree().paused
	):
		_waterfall_motion_pending = 0
		return
	_waterfall_motion_pending += delta
	if _waterfall_motion_pending >= StadiumWaterfallAnimationRuntime.UPDATE_SECONDS:
		var step: float = _waterfall_motion_pending
		_waterfall_motion_pending = 0
		if not preview_property._waterfall_animation.advance(step, false, false):
			set_process(false)
