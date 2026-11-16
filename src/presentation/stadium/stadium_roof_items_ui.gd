class_name StadiumRoofItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Shared exact-copy editor options; each bay, hand and roof is separately purchased.


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "CURVED STANDS, HANDED JOINS & CANOPIES", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Each bay and handed transition is separate. One owned canopy can be stored and "
				+ "remounted from its lower stand to that stand's upper stack. No new purchase or "
				+ "mirror toggle is needed."
			)
		)
	)
	var history: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumRoofItems.PRICES:
		var entry: Dictionary = StadiumCatalog.item(item)
		var blueprint: int = 0 if stock.blueprints.has(item) else entry.blueprint_price
		var cost: int = blueprint + int(entry.copy_price)
		SeasonPages.wrapped(
			panel,
			(
				"%s • Requires %d seasons and %d wins • %d blueprint + %d copy = %d CB"
				% [
					entry.name,
					entry.requires.seasons,
					entry.requires.wins,
					blueprint,
					entry.copy_price,
					cost
				]
			)
		)
		var quote: Dictionary = StadiumPurchases.quote(
			stock,
			item,
			1,
			"roof-preview",
			StadiumRoofItems.PRICE_VERSION,
			StadiumCareerProgress.metrics(history, history.size())
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


static func card(
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
	var ledger: ClubAssetLedger = EditorAccess.editor_ledger(menu, supplied)
	var stock: StadiumStock = ledger.construction()
	var next_base: Dictionary = (
		draft.duplicate(true)
		if (
			(
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
			)
			or StadiumFacilityItems.is_family(draft)
		)
		else StadiumRoofItems.upgrade(draft, ledger.surface_owned())
	)
	var labels: Array[String] = ["Stored"]
	var choices: Array = [{}]
	var selected: int = 0
	if not next_base.is_empty():
		choices.append_array(options(next_base, stock, item, ledger.view().land))
	for index in range(1, choices.size()):
		labels.append(choices[index].label)
		var placement: Dictionary = choices[index].row.duplicate(true)
		placement.copy = copy
		if next_base.get("roofs", []).has(placement):
			selected = index
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or next_base.is_empty()
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Storage and remounting are free. Removing a named support stores only its dependent "
				+ "copies. A lower canopy must be stored before adding its upper, then this same canopy "
				+ "can be remounted above it."
			)
		)
	)
	if choices.size() == 1:
		SeasonPages.wrapped(
			panel,
			"No compatible named site and exact support chain is installed. This copy stays stored."
		)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= choices.size() or index == selected or next_base.is_empty():
				return
			var next: Dictionary = select(next_base, stock, copy, choices[index].get("row", {}))
			EditorAccess.editor_preview(menu, next, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)


static func options(layout: Dictionary, stock: StadiumStock, item: String, tier: String) -> Array:
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
		return options(StadiumReceiverOwnedItems.base(layout), stock, item, tier)
	if StadiumBoundaryItems.is_family(layout):
		return options(StadiumBoundaryItems.base(layout), stock, item, tier)
	var result: Array = []
	if StadiumFacilityItems.is_family(layout):
		result = options(StadiumFacilityItems.base(layout), stock, item, tier)
		if item == "ST-053":
			result = result.filter(
				func(option: Dictionary) -> bool:
					return not StadiumFacilityItems.room_at(layout, option.row.site)
			)
		return result
	if not StadiumRoofItems.is_family(layout) or not StadiumRoofItems.PRICES.has(item):
		return result
	var installed: Dictionary = StadiumRoofItems.active(layout, stock)
	var sites: Array[String] = (
		StadiumBaselineSites.SITES if item == "ST-053" else StadiumCurvedLowerSites.SITES
	)
	if item in ["ST-085", "ST-086"]:
		sites = ["JOIN-R"]
	elif item in ["ST-088", "ST-089"]:
		sites = ["JOIN-L"]
	var states: Array[String] = []
	states.assign(["lower", "upper"] if item in ["ST-053", "ST-084"] else [""])
	for site: String in sites:
		if not StadiumRoofItems._site(item, site, tier):
			continue
		for state: String in states:
			if (
				state == "lower"
				and (
					StadiumRoofItems._at(
						installed, "ST-030" if item == "ST-053" else "ST-082", site
					)
					!= ""
				)
			):
				continue
			var dependencies: Dictionary = StadiumRoofItems.dependencies(
				item, site, state, installed
			)
			if dependencies.is_empty():
				continue
			var placement: Dictionary = StadiumRoofItems.row(site)
			placement.roof_state = state
			for field: String in StadiumRoofItems.SUPPORTS:
				placement[field] = dependencies.get(field, "")
			result.append(
				{
					"label":
					(
						site
						+ (" • " + state + " canopy" if not state.is_empty() else "")
						+ (
							" • exact support " + placement.lower
							if not placement.lower.is_empty()
							else ""
						)
					),
					"row": placement
				}
			)
	return result


static func select(
	layout: Dictionary, stock: StadiumStock, copy: String, placement: Dictionary
) -> Dictionary:
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
		return StadiumReceiverOwnedItems.prune(
			StadiumReceiverOwnedItems.with_base(
				layout, select(StadiumReceiverOwnedItems.base(layout), stock, copy, placement)
			)
		)
	if StadiumBoundaryItems.is_family(layout):
		return StadiumBoundaryItems.prune(
			StadiumBoundaryItems.with_base(
				layout, select(StadiumBoundaryItems.base(layout), stock, copy, placement)
			)
		)
	if StadiumFacilityItems.is_family(layout):
		return StadiumFacilityItems.prune(
			StadiumFacilityItems.with_base(
				layout, select(StadiumFacilityItems.base(layout), stock, copy, placement)
			)
		)
	var result: Dictionary = layout.duplicate(true)
	if not StadiumRoofItems.is_family(result) or not stock.copies.has(copy):
		return result
	var item: String = stock.copies[copy].item
	result.roofs = result.roofs.filter(func(entry: Dictionary) -> bool: return entry.copy != copy)
	if not placement.is_empty():
		result.roofs = result.roofs.filter(
			func(entry: Dictionary) -> bool:
				return entry.site != placement.site or stock.copies[entry.copy].item != item
		)
		result = StadiumRoofItems.prune(result)
		var entry: Dictionary = placement.duplicate(true)
		entry.copy = copy
		result.roofs.append(entry)
	result.roofs.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				a.site + ":" + str(stock.copies[a.copy].item)
				< b.site + ":" + str(stock.copies[b.copy].item)
			)
	)
	return StadiumRoofItems.prune(result)
