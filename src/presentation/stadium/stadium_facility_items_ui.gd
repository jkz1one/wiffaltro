class_name StadiumFacilityItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Shared Workshop controls with complete owned rooms and ordinary displaced-copy preview.


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "SERVICE ROOMS & OFF-FIELD FACILITIES", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Press and suite rooms include their full platform, access and grounded supports. "
				+ "Each requires its own straight lower and concourse. Kiosks, announcer and ticket "
				+ "facilities are separately owned, with no income or gameplay benefit."
			)
		)
	)
	var history: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumFacilityItems.PRICES:
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
			"facility-preview",
			StadiumFacilityItems.PRICE_VERSION,
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
		else StadiumFacilityItems.upgrade(draft, ledger.surface_owned())
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
		if next_base.get("facilities", []).has(placement):
			selected = index
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or next_base.is_empty()
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Moving and storage are free. One room or kiosk occupies each named site; replacing "
				+ "it previews the displaced owned copy before Apply. Room supports and stairs remain "
				+ "part of that room. Store a room before adding this bay's upper or canopy."
			)
		)
	)
	if choices.size() == 1:
		SeasonPages.wrapped(
			panel, "No compatible supported site is available. This exact copy stays stored."
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
	if (
		not StadiumFacilityItems.is_family(layout)
		or not StadiumFacilityItems.PRICES.has(item)
		or tier not in ["club", "mogul"]
	):
		return result
	var active: Dictionary = StadiumRoofItems.active(StadiumFacilityItems.base(layout), stock)
	for site: String in StadiumFacilityItems.sites(item):
		if (
			item in StadiumFacilityItems.ROOMS
			and (
				StadiumRoofItems._at(active, "ST-030", site) != ""
				or StadiumRoofItems._at(active, "ST-053", site) != ""
			)
		):
			continue
		var required: Dictionary = StadiumFacilityItems.dependencies(item, site, active)
		if required.is_empty():
			continue
		result.append(
			{
				"label":
				(
					site
					+ (
						" • exact lower and concourse"
						if item in StadiumFacilityItems.ROOMS
						else " • complete ground facility"
					)
				),
				"row":
				{"copy": "", "site": site, "lower": required.lower, "concourse": required.concourse}
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
	var result: Dictionary = layout.duplicate(true)
	if not StadiumFacilityItems.is_family(result) or not stock.copies.has(copy):
		return result
	result.facilities = result.facilities.filter(
		func(entry: Dictionary) -> bool: return entry.copy != copy
	)
	if not placement.is_empty():
		result.facilities = result.facilities.filter(
			func(entry: Dictionary) -> bool: return entry.site != placement.site
		)
		var entry: Dictionary = placement.duplicate(true)
		entry.copy = copy
		result.facilities.append(entry)
	result.facilities.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				a.site + ":" + str(stock.copies[a.copy].item)
				< b.site + ":" + str(stock.copies[b.copy].item)
			)
	)
	return StadiumFacilityItems.prune(result)
