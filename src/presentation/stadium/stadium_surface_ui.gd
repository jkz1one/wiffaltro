class_name StadiumSurfaceUI
extends RefCounted
## Separate permanent preparations; appearance selection uses the existing save/apply flow.

const NAMES: Dictionary = {"ground_prep": "Level & prepare ground", "grass": "Establish grass"}


static func show(
	menu: SeasonMenu,
	ledger: ClubAssetLedger,
	draft: Dictionary,
	revision: int,
	editable: bool,
	clean_draft: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "FIELD FOUNDATION", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Start with dirt. Ground preparation and grass are separate permanent "
				+ "upgrades. Preparation opens maintained dirt; grass includes four mowing heights. "
				+ "Existing textured fields stay flat. Dirt can explicitly opt into playable "
				+ "rough or leveled terrain; preparation already owned grants leveling without another charge."
			)
		)
	)
	var owned: Array[String] = ledger.surface_owned()
	for item: String in StadiumSurfaceProgression.PRICES:
		if owned.has(item):
			SeasonPages.wrapped(panel, NAMES[item] + " • OWNED")
			continue
		var cost: int = StadiumSurfaceProgression.PRICES[item]
		var buy: Button = menu._button(
			panel, "%s • %d CB" % [NAMES[item], cost], _buy.bind(menu, item, cost, revision)
		)
		buy.set_meta("surface_buy", item)
		buy.disabled = (
			not editable
			or not clean_draft
			or ledger.balance() < cost
			or ClubPlayers.income_through(menu.app.season.career) == 0
		)
	if (
		draft.get("version") == 17
		or StadiumFlagItems.is_terrain(draft)
		or (
			StadiumGroundPropsItems.is_terrain(draft)
			or (
				StadiumStraightItems.is_terrain(draft)
				or (
					StadiumRoofItems.is_terrain(draft)
					or (
						StadiumFacilityItems.is_terrain(draft)
						or (
							StadiumBoundaryItems.is_terrain(draft)
							or (
								StadiumReceiverOwnedItems.is_terrain(draft)
								or (
									StadiumFloodlightOwnedItems.is_terrain(draft)
									or (
										StadiumLandscapeOwnedItems.is_terrain(draft)
										or (
											StadiumLiveFurnishingItems.is_terrain(draft)
											or (
												StadiumSmallYardSceneryItems.is_terrain(draft)
												or (
													StadiumMoldedSeatItems.is_terrain(draft)
													or (
														StadiumGroundBoxItems.is_terrain(draft)
														or (
															StadiumPracticeFacilityItems.is_terrain(
																draft
															)
															or (
																StadiumTreehouseItems.is_terrain(
																	draft
																)
																or (
																	StadiumLandmarkItems.is_terrain(
																		draft
																	)
																	or (
																		(
																			StadiumOutfieldBleacherItems
																			. is_terrain(draft)
																		)
																		or (
																			(
																				StadiumRisingAppleItems
																				. is_terrain(draft)
																			)
																			or (
																				(
																					StadiumWallTopTerraceItems
																					. is_terrain(
																						draft
																					)
																				)
																				or (
																					(
																						StadiumPlayerTunnelItems
																						. is_terrain(
																							draft
																						)
																					)
																					or (
																						(
																							StadiumMountedDisplayItems
																							. is_terrain(
																								draft
																							)
																						)
																						or (
																							(
																								StadiumStringLightItems
																								. is_terrain(
																									draft
																								)
																							)
																							or (
																								(
																									StadiumSalvageCarItems
																									. is_terrain(
																										draft
																									)
																								)
																								or (
																									(
																										StadiumMasteryBannerItems
																										. is_terrain(
																											draft
																										)
																									)
																									or (
																										(
																											StadiumWaterfallItems
																											. is_terrain(
																												draft
																											)
																										)
																										or (
																											(
																												StadiumLightingKitItems
																												. is_terrain(
																													draft
																												)
																											)
																											or (
																												(
																													StadiumOutfieldPlazaItems
																													. is_terrain(
																														draft
																													)
																												)
																												or (
																													StadiumWaterfallLiveItems
																													. is_terrain(
																														draft
																													)
																												)
																											)
																										)
																									)
																								)
																							)
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
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
		_terrain_choices(menu, panel, draft, owned, revision, editable)
		return
	var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(_surface_base(draft), owned)
	if not terrain.is_empty():
		terrain = _with_surface_base(draft, terrain)
	if not terrain.is_empty() and StadiumProperty.BOUNDS.has(ledger.view().land):
		var opt_terrain: Button = menu._button(
			panel, "PREVIEW PLAYABLE DIRT TERRAIN", _terrain_opt_in.bind(menu, terrain, revision)
		)
		opt_terrain.set_meta("terrain_opt_in", true)
		opt_terrain.disabled = not editable or not menu.app.season.owned_surface_night.is_empty()
	if (
		not SeasonOwnership._whole(draft.get("version"), 12, 15)
		and not StadiumFlagItems.is_family(draft)
		and not (
			StadiumGroundPropsItems.is_family(draft)
			or (
				StadiumStraightItems.is_family(draft)
				or (
					StadiumRoofItems.is_family(draft)
					or (
						StadiumFacilityItems.is_family(draft)
						or (
							StadiumBoundaryItems.is_family(draft)
							or (
								StadiumReceiverOwnedItems.is_family(draft)
								or (
									StadiumFloodlightOwnedItems.is_family(draft)
									or (
										StadiumLandscapeOwnedItems.is_family(draft)
										or (
											StadiumLiveFurnishingItems.is_family(draft)
											or (
												StadiumSmallYardSceneryItems.is_family(draft)
												or (
													StadiumMoldedSeatItems.is_family(draft)
													or (
														StadiumGroundBoxItems.is_family(draft)
														or (
															StadiumPracticeFacilityItems.is_family(
																draft
															)
															or (
																StadiumTreehouseItems.is_family(
																	draft
																)
																or (
																	StadiumLandmarkItems.is_family(
																		draft
																	)
																	or (
																		(
																			StadiumOutfieldBleacherItems
																			. is_family(draft)
																		)
																		or (
																			(
																				StadiumRisingAppleItems
																				. is_family(draft)
																			)
																			or (
																				(
																					StadiumWallTopTerraceItems
																					. is_family(
																						draft
																					)
																				)
																				or (
																					(
																						StadiumPlayerTunnelItems
																						. is_family(
																							draft
																						)
																					)
																					or (
																						(
																							StadiumMountedDisplayItems
																							. is_family(
																								draft
																							)
																						)
																						or (
																							(
																								StadiumStringLightItems
																								. is_family(
																									draft
																								)
																							)
																							or (
																								(
																									StadiumSalvageCarItems
																									. is_family(
																										draft
																									)
																								)
																								or (
																									(
																										StadiumMasteryBannerItems
																										. is_family(
																											draft
																										)
																									)
																									or (
																										(
																											StadiumWaterfallItems
																											. is_family(
																												draft
																											)
																										)
																										or (
																											(
																												StadiumLightingKitItems
																												. is_family(
																													draft
																												)
																											)
																											or (
																												(
																													StadiumOutfieldPlazaItems
																													. is_family(
																														draft
																													)
																												)
																												or (
																													StadiumWaterfallLiveItems
																													. is_family(
																														draft
																													)
																												)
																											)
																										)
																									)
																								)
																							)
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
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
		SeasonPages.wrapped(
			panel,
			(
				"Your existing field is preserved. Opt into the textured finishes "
				+ "with a new draft; this currently makes future home fixtures daylight-only."
			)
		)
		var opt: Button = menu._button(
			panel, "PREVIEW TEXTURED SURFACE", _opt_in.bind(menu, draft, owned, revision)
		)
		opt.set_meta("surface_opt_in", true)
		opt.disabled = not editable
		return
	_choices(menu, panel, draft, owned, revision, editable)


static func _choices(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	owned: Array[String],
	revision: int,
	editable: bool,
	preview: Callable = Callable()
) -> void:
	var labels: Array[String] = ["Rough dirt"]
	var choices: Array[Dictionary] = [
		{"foundation": "dirt", "condition": "rough", "height": "short"}
	]
	if owned.has("ground_prep"):
		labels.append("Prepared dirt")
		choices.append(StadiumSurfaceProgression.selection(owned, false))
	if owned.has("grass"):
		labels.append("Grass")
		choices.append(StadiumSurfaceProgression.selection(owned, true, draft.surface.height))
	var selected: int = 0
	for index in range(choices.size()):
		if (
			choices[index].foundation == draft.surface.foundation
			and (
				draft.surface.foundation == "grass"
				or choices[index].condition == draft.surface.condition
			)
		):
			selected = index
	var foundation: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	foundation.set_meta("surface_choice", "foundation")
	foundation.disabled = not editable
	foundation.item_selected.connect(
		func(index: int) -> void:
			if foundation.disabled or index < 0 or index >= choices.size():
				return
			var next: Dictionary = draft.duplicate(true)
			next.surface = choices[index].duplicate(true)
			if next.surface.foundation == "dirt":
				next.styles.grass = ""
				next.ground = ""
			_return_preview(menu, next, revision, preview)
			_focus.call_deferred(menu, "foundation")
	)
	if draft.surface.foundation == "grass":
		var height: OptionButton = StadiumEditorUI._options(
			panel,
			["Very short • 15mm", "Short • 25mm", "Medium • 40mm", "Long • 60mm"],
			StadiumSurfaceProgression.HEIGHTS.find(draft.surface.height)
		)
		height.set_meta("surface_choice", "height")
		height.disabled = not editable
		height.item_selected.connect(
			func(index: int) -> void:
				if height.disabled or index < 0 or index >= StadiumSurfaceProgression.HEIGHTS.size():
					return
				var next: Dictionary = draft.duplicate(true)
				next.surface.height = StadiumSurfaceProgression.HEIGHTS[index]
				_return_preview(menu, next, revision, preview)
				_focus.call_deferred(menu, "height")
		)


static func _opt_in(
	menu: SeasonMenu, draft: Dictionary, owned: Array[String], revision: int,
	preview: Callable = Callable()
) -> void:
	var next: Dictionary = StadiumSurfaceLayout.upgrade(draft, owned, owned.has("grass"))
	_return_preview(menu, next, revision, preview)


static func _return_preview(menu: SeasonMenu, draft: Dictionary, revision: int, preview: Callable) -> void:
	if preview.is_valid():
		preview.call(draft, revision)
	else:
		StadiumEditorUI.show(menu, draft, revision)


static func _buy(menu: SeasonMenu, item: String, cost: int, revision: int) -> void:
	menu.app._confirm(
		(
			"%s for %d Club Bucks? " % [NAMES[item], cost]
			+ "This unlock is permanent. Choose the surface, save the draft, then apply. "
			+ "The current installed field stays unchanged."
		),
		_complete.bind(menu, item, revision)
	)


static func _complete(menu: SeasonMenu, item: String, revision: int) -> void:
	var result: Dictionary = ClubConstruction.buy_surface(menu.app.season, item, revision)
	menu.app.notice = (
		"Surface upgrade owned. Choose it, save the draft, then apply."
		if result.ok
		else result.error
	)
	StadiumEditorUI.show(menu)


static func _focus(menu: SeasonMenu, channel: String) -> void:
	if menu.page not in ["stadium", "shared_stadium"]:
		return
	for choice: OptionButton in menu._body.find_children("*", "OptionButton", true, false):
		if choice.get_meta("surface_choice", "") == channel:
			choice.grab_focus()
			return


static func _terrain_opt_in(menu: SeasonMenu, terrain: Dictionary, revision: int, preview: Callable = Callable()) -> void:
	_return_preview(menu, terrain.duplicate(true), revision, preview)


static func _terrain_choices(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	owned: Array[String],
	revision: int,
	editable: bool,
	preview: Callable = Callable()
) -> void:
	SeasonPages.wrapped(
		panel,
		(
			"Playable Backyard dirt • daylight only. Save the draft and apply "
			+ "between seasons before drafting. Existing installed games stay unchanged."
		)
	)
	var flat_layout: Dictionary = StadiumSurfaceLayout.terrain_base(_surface_base(draft))
	flat_layout = _with_surface_base(draft, flat_layout)
	var flat: Button = menu._button(
		panel, "PREVIEW FLAT DIRT", func() -> void:
			if editable:
				_terrain_opt_in(menu, flat_layout, revision, preview)
	)
	flat.set_meta("terrain_flat", true)
	flat.disabled = not editable
	var labels: Array[String] = ["Rough terrain"]
	if owned.has("ground_prep"):
		labels.append("Leveled terrain • already owned")
	var choice: OptionButton = StadiumEditorUI._options(
		panel, labels, 1 if draft.surface.condition == "prepared" and labels.size() == 2 else 0
	)
	choice.set_meta("terrain_choice", true)
	choice.disabled = not editable
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= labels.size():
				return
			var next: Dictionary = draft.duplicate(true)
			next.surface.condition = (
				"prepared" if index == 1 and owned.has("ground_prep") else "rough"
			)
			_return_preview(menu, next, revision, preview)
	)


static func _surface_base(layout: Dictionary) -> Dictionary:
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
		return _surface_base(StadiumReceiverOwnedItems.base(layout))
	if StadiumBoundaryItems.is_family(layout):
		return _surface_base(StadiumBoundaryItems.base(layout))
	if StadiumFacilityItems.is_family(layout):
		return _surface_base(StadiumFacilityItems.base(layout))
	if StadiumRoofItems.is_family(layout):
		return _surface_base(StadiumRoofItems.base(layout))
	if StadiumStraightItems.is_family(layout):
		return _surface_base(StadiumStraightItems.base(layout))
	var inner: Dictionary = (
		StadiumGroundPropsItems.base(layout)
		if StadiumGroundPropsItems.is_family(layout)
		else layout
	)
	return StadiumFlagItems.base(inner) if StadiumFlagItems.is_family(inner) else inner


static func _with_surface_base(layout: Dictionary, surface: Dictionary) -> Dictionary:
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
			layout, _with_surface_base(StadiumReceiverOwnedItems.base(layout), surface)
		)
	if StadiumBoundaryItems.is_family(layout):
		return StadiumBoundaryItems.with_base(
			layout, _with_surface_base(StadiumBoundaryItems.base(layout), surface)
		)
	if StadiumFacilityItems.is_family(layout):
		return StadiumFacilityItems.with_base(
			layout, _with_surface_base(StadiumFacilityItems.base(layout), surface)
		)
	if StadiumRoofItems.is_family(layout):
		return StadiumRoofItems.with_base(
			layout, _with_surface_base(StadiumRoofItems.base(layout), surface)
		)
	if StadiumStraightItems.is_family(layout):
		return StadiumStraightItems.with_base(
			layout, _with_surface_base(StadiumStraightItems.base(layout), surface)
		)
	var inner: Dictionary = (
		StadiumGroundPropsItems.base(layout)
		if StadiumGroundPropsItems.is_family(layout)
		else layout
	)
	var wrapped: Dictionary = (
		StadiumFlagItems.with_base(inner, surface) if StadiumFlagItems.is_family(inner) else surface
	)
	return (
		StadiumGroundPropsItems.with_base(layout, wrapped)
		if StadiumGroundPropsItems.is_family(layout)
		else wrapped
	)
