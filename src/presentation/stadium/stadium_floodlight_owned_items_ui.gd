class_name StadiumFloodlightOwnedItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Fixed complete-copy alternatives and explicit bounded night-profile feedback.


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "STADIUM FLOODLIGHT TOWERS", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Each purchased copy is a whole tower with its own heads, mast and supports. Presets "
				+ "use only your owned copies; changing presets stores displaced towers for free. "
				+ "Standard and premium towers never convert into each other."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumFloodlightOwnedItems.PRICES:
		var entry: Dictionary = StadiumCatalog.item(item)
		var blueprint: int = 0 if stock.blueprints.has(item) else int(entry.blueprint_price)
		var cost: int = blueprint + int(entry.copy_price)
		SeasonPages.wrapped(
			panel,
			(
				"%s • %d seasons / %d wins • %d blueprint + %d per copy"
				% [
					entry.name,
					entry.requires.seasons,
					entry.requires.wins,
					blueprint,
					entry.copy_price
				]
			)
		)
		var quote: Dictionary = StadiumPurchases.quote(
			stock,
			item,
			1,
			"floodlight-preview",
			StadiumFloodlightOwnedItems.PRICE_VERSION,
			progress
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


static func presets(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool,
	preview: Callable = Callable()
) -> void:
	var layout: Dictionary = StadiumFloodlightOwnedItems.upgrade(draft, ledger.surface_owned())
	if layout.is_empty():
		return
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "FLOODLIGHT PRESETS", 22)
	if (
		(
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
									StadiumOutfieldBleacherItems.is_family(draft)
									or (
										StadiumRisingAppleItems.is_family(draft)
										or (
											StadiumWallTopTerraceItems.is_family(draft)
											or (
												StadiumPlayerTunnelItems.is_family(draft)
												or (
													StadiumMountedDisplayItems.is_family(draft)
													or (
														StadiumStringLightItems.is_family(draft)
														or (
															StadiumSalvageCarItems.is_family(draft)
															or (
																StadiumMasteryBannerItems.is_family(
																	draft
																)
																or (
																	StadiumWaterfallItems.is_family(
																		draft
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(draft)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(draft)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(draft)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		and not draft.get("yard_scenery", []).is_empty()
	):
		SeasonPages.wrapped(panel, StadiumSmallYardSceneryItemsUI.NIGHT_REASON)
	elif (
		(
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
										StadiumOutfieldBleacherItems.is_family(draft)
										or (
											StadiumRisingAppleItems.is_family(draft)
											or (
												StadiumWallTopTerraceItems.is_family(draft)
												or (
													StadiumPlayerTunnelItems.is_family(draft)
													or (
														StadiumMountedDisplayItems.is_family(draft)
														or (
															StadiumStringLightItems.is_family(draft)
															or (
																StadiumSalvageCarItems.is_family(
																	draft
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(draft)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(draft)
																		)
																		or (
																			(
																				StadiumLightingKitItems
																				. is_family(draft)
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
		and not draft.get("live_furnishings", []).is_empty()
	):
		SeasonPages.wrapped(panel, StadiumLiveFurnishingItemsUI.NIGHT_REASON)
	elif (
		(
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
											StadiumOutfieldBleacherItems.is_family(draft)
											or (
												StadiumRisingAppleItems.is_family(draft)
												or (
													StadiumWallTopTerraceItems.is_family(draft)
													or (
														StadiumPlayerTunnelItems.is_family(draft)
														or (
															StadiumMountedDisplayItems.is_family(
																draft
															)
															or (
																StadiumStringLightItems.is_family(
																	draft
																)
																or (
																	(
																		StadiumSalvageCarItems
																		. is_family(draft)
																	)
																	or (
																		(
																			StadiumMasteryBannerItems
																			. is_family(draft)
																		)
																		or (
																			(
																				StadiumWaterfallItems
																				. is_family(draft)
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
		and not draft.get("landscape", []).is_empty()
	):
		SeasonPages.wrapped(panel, StadiumLandscapeOwnedItemsUI.NIGHT_REASON)
	var stock: StadiumStock = ledger.construction()
	for profile: String in StadiumFloodlightOwnedItems.PROFILES:
		var definition: Dictionary = StadiumFloodlightOwnedItems.PROFILES[profile]
		var owned: int = 0
		for value: Dictionary in stock.copies.values():
			if value.item == definition.item:
				owned += 1
		var blueprint: int = (
			0
			if stock.blueprints.has(definition.item)
			else int(StadiumFloodlightOwnedItems.PRICES[definition.item][0])
		)
		var price: int = int(StadiumFloodlightOwnedItems.PRICES[definition.item][1])
		(
			SeasonPages
			. wrapped(
				panel,
				(
					(
						"%s • requires %d matching towers • %d owned • complete set %d CB (%d blueprint + "
						+ "%d×%d copies)"
					)
					% [
						profile,
						definition.count,
						owned,
						blueprint + int(definition.count) * price,
						blueprint,
						definition.count,
						price
					]
				)
			)
		)
		var candidate: Dictionary = StadiumFloodlightOwnedItems.select_preset(
			layout, stock, profile
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var select: Button = _preview_button(menu, panel, "PREVIEW " + profile, candidate, revision, preview)
		select.disabled = not enabled or not checked.ok or owned == 0
		select.set_meta("floodlight_profile", profile)
		if not checked.ok:
			SeasonPages.wrapped(panel, checked.error)
		elif not checked.floodlight_complete:
			SeasonPages.wrapped(
				panel, "Partial installed set: daylight only. Remaining copies are still required."
			)
	var clear: Button = _preview_button(menu, panel, "STORE ALL FLOODLIGHTS",
		StadiumFloodlightOwnedItems.select_preset(layout, stock, ""), revision, preview)
	clear.disabled = not enabled or layout.floodlights.is_empty()
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Night qualification is limited to the measured sparse Club4-LOW, Mogul6-STANDARD and "
				+ "Mogul4-PREMIUM layouts. Club4-LOW also supports exactly the two lower BASE-L2/R2 "
				+ "canopies. Other roofs, upper/tall structures, mixed sets and unqualified "
				+ "obstructions remain daylight-only; partial or stored towers never count."
			)
		)
	)


static func card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	revision: int,
	enabled: bool,
	supplied: ClubAssetLedger = null,
	preview: Callable = Callable()
) -> void:
	var site: String = "Stored"
	for row: Dictionary in draft.get("floodlights", []):
		if row.copy == copy:
			site = row.site
	SeasonPages.wrapped(panel, site + " • fixed preset position and named head aim")
	var store: Button = _preview_button(menu, panel, "STORE THIS TOWER",
		StadiumFloodlightOwnedItems.store_copy(draft, copy), revision, preview)
	store.set_meta("stadium_copy", copy)
	store.disabled = not enabled or site == "Stored"


static func _preview_button(menu: SeasonMenu, panel: VBoxContainer, label: String,
	draft: Dictionary, revision: int, preview: Callable) -> Button:
	var button: Button = menu._button(panel, label, func() -> void: pass)
	button.pressed.connect(func() -> void:
		if button.is_inside_tree() and not button.disabled:
			EditorAccess.editor_preview(menu, draft, revision, preview))
	return button
