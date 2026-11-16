class_name StadiumClubItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Exact owned ground displays. A replacement is free storage, not an extra copy or refund.


static func card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	item: String,
	revision: int,
	editable: bool,
	preview: Callable = Callable()
) -> void:
	var options: Array[String] = ["Stored"]
	for site: String in StadiumClubSites.SITES:
		if StadiumClubSites.SITES[site].item == item:
			options.append(site)
	var selected: int = 0
	for row: Dictionary in draft.get("displays", []):
		if row.copy == copy:
			selected = options.find(row.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, options, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	SeasonPages.wrapped(
		panel, "Fixed outside-play site. Replacing an occupant stores that exact copy."
	)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= options.size() or index == selected:
				return
			var next: Dictionary = StadiumClubItems.upgrade(draft)
			next.displays = next.displays.filter(
				func(row: Dictionary) -> bool: return row.copy != copy
			)
			if index > 0:
				next.displays = next.displays.filter(
					func(row: Dictionary) -> bool: return row.site != options[index]
				)
				next.displays.append({"copy": copy, "site": options[index]})
			next.displays.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
			)
			(
				StadiumClubItemsUI
				. _return_preview(
					menu,
					(
						StadiumBoundaryItems.prune(next)
						if (
							StadiumBoundaryItems.is_family(next)
							or (
								StadiumReceiverOwnedItems.is_family(next)
								or (
									StadiumFloodlightOwnedItems.is_family(next)
									or (
										StadiumLandscapeOwnedItems.is_family(next)
										or (
											StadiumLiveFurnishingItems.is_family(next)
											or (
												StadiumSmallYardSceneryItems.is_family(next)
												or (
													StadiumMoldedSeatItems.is_family(next)
													or (
														StadiumGroundBoxItems.is_family(next)
														or (
															StadiumPracticeFacilityItems.is_family(
																next
															)
															or (
																StadiumTreehouseItems.is_family(
																	next
																)
																or (
																	StadiumLandmarkItems.is_family(
																		next
																	)
																	or (
																		(
																			StadiumOutfieldBleacherItems
																			. is_family(next)
																		)
																		or (
																			(
																				StadiumRisingAppleItems
																				. is_family(next)
																			)
																			or (
																				(
																					StadiumWallTopTerraceItems
																					. is_family(
																						next
																					)
																				)
																				or (
																					(
																						StadiumPlayerTunnelItems
																						. is_family(
																							next
																						)
																					)
																					or (
																						(
																							StadiumMountedDisplayItems
																							. is_family(
																								next
																							)
																						)
																						or (
																							(
																								StadiumStringLightItems
																								. is_family(
																									next
																								)
																							)
																							or (
																								(
																									StadiumSalvageCarItems
																									. is_family(
																										next
																									)
																								)
																								or (
																									(
																										StadiumMasteryBannerItems
																										. is_family(
																											next
																										)
																									)
																									or (
																										(
																											StadiumWaterfallItems
																											. is_family(
																												next
																											)
																										)
																										or (
																											(
																												StadiumLightingKitItems
																												. is_family(
																													next
																												)
																											)
																											or (
																												(
																													StadiumOutfieldPlazaItems
																													. is_family(
																														next
																													)
																												)
																												or (
																													StadiumWaterfallLiveItems
																													. is_family(
																														next
																													)
																												)
																											)
																										)
																									)
																								)
																							)
																						)
																					)
																				)
																			)
																		)
																	)
																)
															)
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
							StadiumFacilityItems.prune(next)
							if StadiumFacilityItems.is_family(next)
							else (
								StadiumRoofItems.prune(next)
								if StadiumRoofItems.is_family(next)
								else StadiumStraightItems.prune(next)
							)
						)
					),
					revision, preview
				)
			)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)


static func _return_preview(menu: SeasonMenu, draft: Dictionary, revision: int, preview: Callable) -> void:
	if preview.is_valid():
		preview.call(draft, revision)
	else:
		StadiumEditorUI.show(menu, draft, revision)


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool, scoreboard_shop: bool = false
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "CLUB DISPLAYS", 22)
	SeasonPages.wrapped(
		panel,
		(
			(
				"Painted ground sign. "
				if scoreboard_shop
				else "Manual scoreboard and painted ground sign. "
			)
			+ "Blueprint once, then an exact copy price. No passive income or free mounted extras."
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumPurchases.DISPLAYS:
		if scoreboard_shop and item == "ST-039":
			continue
		var entry: Dictionary = StadiumCatalog.item(item)
		var blueprint: int = 0 if stock.blueprints.has(item) else entry.blueprint_price
		var cost: int = blueprint + int(entry.copy_price)
		var requirement: String = "%d completed seasons" % entry.requires.seasons
		if entry.requires.has("wins"):
			requirement += " and %d regular-season wins" % entry.requires.wins
		SeasonPages.wrapped(panel, entry.name + " • Requires " + requirement)
		SeasonPages.wrapped(
			panel, "%d blueprint + %d copy = %d CB" % [blueprint, entry.copy_price, cost]
		)
		var quote: Dictionary = StadiumPurchases.quote(
			stock, item, 1, "display-preview", StadiumPurchases.DISPLAY_VERSION, progress
		)
		var buy: Button = menu._button(
			panel,
			"BUY " + entry.name.to_upper(),
			StadiumEditorUI._buy.bind(menu, item, ledger.revision())
		)
		buy.set_meta("stadium_buy", item)
		buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
		if not quote.ok:
			buy.tooltip_text = quote.error


static func flag_card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	revision: int,
	editable: bool,
	supplied: ClubAssetLedger = null,
	preview: Callable = Callable()
) -> void:
	var enclosed: Dictionary = (
		StadiumBoundaryItems.base(draft)
		if (
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
											StadiumPracticeFacilityItems.is_family(draft)
											or (
												StadiumTreehouseItems.is_family(draft)
												or (
													StadiumLandmarkItems.is_family(draft)
													or (
														StadiumOutfieldBleacherItems.is_family(
															draft
														)
														or (
															StadiumRisingAppleItems.is_family(draft)
															or (
																(
																	StadiumWallTopTerraceItems
																	. is_family(draft)
																)
																or (
																	(
																		StadiumPlayerTunnelItems
																		. is_family(draft)
																	)
																	or (
																		(
																			StadiumMountedDisplayItems
																			. is_family(draft)
																		)
																		or (
																			(
																				StadiumStringLightItems
																				. is_family(draft)
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
		else draft
	)
	var covered: Dictionary = (
		StadiumFacilityItems.base(enclosed)
		if StadiumFacilityItems.is_family(enclosed)
		else enclosed
	)
	var structural: Dictionary = (
		StadiumRoofItems.base(covered) if StadiumRoofItems.is_family(covered) else covered
	)
	var source: Dictionary = (
		StadiumStraightItems.base(structural)
		if StadiumStraightItems.is_family(structural)
		else structural
	)
	var next_base: Dictionary = StadiumFlagItems.upgrade(
		(
			StadiumGroundPropsItems.base(source)
			if StadiumGroundPropsItems.is_family(source)
			else source
		),
		EditorAccess.editor_ledger(menu, supplied).surface_owned()
	)
	var options: Array[String] = ["Stored", "FLAG-GROUND-L", "FLAG-GROUND-R"]
	var selected: int = 0
	for row: Dictionary in draft.get("flags", []):
		if row.copy == copy:
			selected = options.find(row.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, options, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or next_base.is_empty()
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Outside-play club flag. Free exact-copy placement and storage. The current flat or "
				+ "playable dirt field is preserved."
			)
		)
	)
	if next_base.is_empty():
		SeasonPages.wrapped(
			panel, "This field family has no flag attachment yet; the owned flag stays in storage."
		)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= options.size():
				return
			if choice.is_item_disabled(index) or index == selected or next_base.is_empty():
				return
			var next: Dictionary = next_base.duplicate(true)
			next.flags = next.flags.filter(func(row: Dictionary) -> bool: return row.copy != copy)
			if index > 0:
				next.flags = next.flags.filter(
					func(row: Dictionary) -> bool: return row.site != options[index]
				)
				next.flags.append({"copy": copy, "site": options[index]})
			next.flags.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
			)
			if StadiumGroundPropsItems.is_family(source):
				next = StadiumGroundPropsItems.with_base(source, next)
			if StadiumStraightItems.is_family(structural):
				next = StadiumStraightItems.with_base(structural, next)
			if StadiumRoofItems.is_family(covered):
				next = StadiumRoofItems.with_base(covered, next)
			if StadiumFacilityItems.is_family(enclosed):
				next = StadiumFacilityItems.with_base(enclosed, next)
			if (
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
												StadiumPracticeFacilityItems.is_family(draft)
												or (
													StadiumTreehouseItems.is_family(draft)
													or (
														StadiumLandmarkItems.is_family(draft)
														or (
															StadiumOutfieldBleacherItems.is_family(
																draft
															)
															or (
																StadiumRisingAppleItems.is_family(
																	draft
																)
																or (
																	(
																		StadiumWallTopTerraceItems
																		. is_family(draft)
																	)
																	or (
																		(
																			StadiumPlayerTunnelItems
																			. is_family(draft)
																		)
																		or (
																			(
																				StadiumMountedDisplayItems
																				. is_family(draft)
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
			):
				next = StadiumBoundaryItems.prune(StadiumBoundaryItems.with_base(draft, next))
			EditorAccess.editor_preview(menu, next, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)


static func flag_purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "CLUB FLAG", 22)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var stock: StadiumStock = ledger.construction()
	var blueprint: int = 0 if stock.blueprints.has("ST-043") else 190
	var cost: int = blueprint + 55
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"Requires 2 completed seasons and 5 regular-season wins. %d blueprint + 55 copy = %d "
					+ "CB. Decorative outside-play flag; no income or scoring effect."
				)
				% [blueprint, cost]
			)
		)
	)
	var quote: Dictionary = StadiumPurchases.quote(
		stock,
		"ST-043",
		1,
		"flag-preview",
		StadiumFlagItems.PRICE_VERSION,
		StadiumCareerProgress.metrics(rows, rows.size())
	)
	var buy: Button = menu._button(
		panel, "BUY CLUB FLAG ON POLE", StadiumEditorUI._buy.bind(menu, "ST-043", ledger.revision())
	)
	buy.set_meta("stadium_buy", "ST-043")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
	if not quote.ok:
		buy.tooltip_text = quote.error


static func ground_props_purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "PLANTS & YARD FURNISHINGS", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Plants are decorative. Live furnishings share the four-unit field budget. Blueprint "
				+ "once, exact copies thereafter; storage and remounting are free."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumGroundPropsItems.PRICES:
		var entry: Dictionary = StadiumCatalog.item(item)
		var blueprint: int = 0 if stock.blueprints.has(item) else entry.blueprint_price
		var cost: int = blueprint + int(entry.copy_price)
		var requirement: String = "%d completed seasons" % entry.requires.seasons
		if entry.requires.has("wins"):
			requirement += " and %d regular-season wins" % entry.requires.wins
		SeasonPages.wrapped(
			panel,
			(
				"%s • Requires %s • %d blueprint + %d copy = %d CB"
				% [entry.name, requirement, blueprint, entry.copy_price, cost]
			)
		)
		var quote: Dictionary = StadiumPurchases.quote(
			stock,
			item,
			1,
			"ground-props-preview",
			StadiumGroundPropsItems.PRICE_VERSION,
			StadiumCareerProgress.metrics(rows, rows.size())
		)
		var buy: Button = menu._button(
			panel,
			"BUY " + entry.name.to_upper(),
			StadiumEditorUI._buy.bind(menu, item, ledger.revision())
		)
		buy.set_meta("stadium_buy", item)
		buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
		if not quote.ok:
			buy.tooltip_text = quote.error


static func ground_props_card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	item: String,
	revision: int,
	editable: bool,
	supplied: ClubAssetLedger = null,
	preview: Callable = Callable()
) -> void:
	var enclosed: Dictionary = (
		StadiumBoundaryItems.base(draft)
		if (
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
											StadiumPracticeFacilityItems.is_family(draft)
											or (
												StadiumTreehouseItems.is_family(draft)
												or (
													StadiumLandmarkItems.is_family(draft)
													or (
														StadiumOutfieldBleacherItems.is_family(
															draft
														)
														or (
															StadiumRisingAppleItems.is_family(draft)
															or (
																(
																	StadiumWallTopTerraceItems
																	. is_family(draft)
																)
																or (
																	(
																		StadiumPlayerTunnelItems
																		. is_family(draft)
																	)
																	or (
																		(
																			StadiumMountedDisplayItems
																			. is_family(draft)
																		)
																		or (
																			(
																				StadiumStringLightItems
																				. is_family(draft)
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
		else draft
	)
	var covered: Dictionary = (
		StadiumFacilityItems.base(enclosed)
		if StadiumFacilityItems.is_family(enclosed)
		else enclosed
	)
	var structural: Dictionary = (
		StadiumRoofItems.base(covered) if StadiumRoofItems.is_family(covered) else covered
	)
	var next_base: Dictionary = StadiumGroundPropsItems.upgrade(
		(
			StadiumStraightItems.base(structural)
			if StadiumStraightItems.is_family(structural)
			else structural
		),
		EditorAccess.editor_ledger(menu, supplied).surface_owned()
	)
	var options: Array[String] = ["Stored"]
	for site: String in StadiumGroundPropsItems.SITES:
		if StadiumGroundPropsItems.SITES[site].items.has(item):
			options.append(site)
	var selected: int = 0
	for row: Dictionary in draft.get("props", []):
		if row.copy == copy:
			selected = options.find(row.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, options, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or next_base.is_empty()
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Fixed measured sites. Replacing an occupant stores its exact copy. Conflicting "
				+ "footprints or more than four live units cannot be saved or applied."
			)
		)
	)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= options.size():
				return
			if choice.is_item_disabled(index) or index == selected or next_base.is_empty():
				return
			var next: Dictionary = next_base.duplicate(true)
			next.props = next.props.filter(func(row: Dictionary) -> bool: return row.copy != copy)
			if index > 0:
				next.props = next.props.filter(
					func(row: Dictionary) -> bool: return row.site != options[index]
				)
				next.props.append({"copy": copy, "site": options[index]})
			next.props.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
			)
			if StadiumStraightItems.is_family(structural):
				next = StadiumStraightItems.with_base(structural, next)
			if StadiumRoofItems.is_family(covered):
				next = StadiumRoofItems.with_base(covered, next)
			if StadiumFacilityItems.is_family(enclosed):
				next = StadiumFacilityItems.with_base(enclosed, next)
			if (
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
												StadiumPracticeFacilityItems.is_family(draft)
												or (
													StadiumTreehouseItems.is_family(draft)
													or (
														StadiumLandmarkItems.is_family(draft)
														or (
															StadiumOutfieldBleacherItems.is_family(
																draft
															)
															or (
																StadiumRisingAppleItems.is_family(
																	draft
																)
																or (
																	(
																		StadiumWallTopTerraceItems
																		. is_family(draft)
																	)
																	or (
																		(
																			StadiumPlayerTunnelItems
																			. is_family(draft)
																		)
																		or (
																			(
																				StadiumMountedDisplayItems
																				. is_family(draft)
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
			):
				next = StadiumBoundaryItems.prune(StadiumBoundaryItems.with_base(draft, next))
			EditorAccess.editor_preview(menu, next, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)
