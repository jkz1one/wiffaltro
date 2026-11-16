class_name StadiumStraightItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Existing Workshop exact-copy controls, with explicit support and mount choices.


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "STRAIGHT STANDS & CLUB CRESTS", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Lower, concourse and upper are separately owned copies. Crests need a named host. "
				+ "Championship pennants are earned once per future title and may stay stored until a "
				+ "supported display is available. No income or gameplay benefit."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumStraightItems.PRICES:
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
			"straight-preview",
			StadiumStraightItems.PRICE_VERSION,
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
			or StadiumRoofItems.is_family(draft)
			or StadiumFacilityItems.is_family(draft)
		)
		else StadiumStraightItems.upgrade(draft, ledger.surface_owned())
	)
	var labels: Array[String] = ["Stored"]
	var choices: Array = [{}]
	var selected: int = 0
	if not next_base.is_empty():
		choices.append_array(options(next_base, stock, item, ledger.view().land))
	for index in range(1, choices.size()):
		var option: Dictionary = choices[index]
		labels.append(option.label)
		var row: Dictionary = option.row.duplicate(true)
		row.copy = copy
		if next_base.get("mounts", []).has(row) or next_base.get("hosts", []).has(row):
			selected = index
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or next_base.is_empty()
	if item == "ST-044":
		var earned: Dictionary = stock.copies[copy].earned
		SeasonPages.wrapped(
			panel,
			(
				"%s • Season %d • %s / %s • Frozen championship-era identity"
				% [earned.era.name, earned.season_number, earned.league_id, earned.difficulty_id]
			)
		)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Moving and storage are free. Removing a host stores only its dependent copies. "
				+ "Replacing a support never transfers a display to the replacement copy."
			)
		)
	)
	if choices.size() == 1:
		SeasonPages.wrapped(
			panel, "No compatible supported host is installed. This exact copy remains in storage."
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
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		var candidates: Array = options(StadiumMasteryBannerItems.base(layout), stock, item, tier)
		if item == "ST-042":
			var blocked: Array[String] = []
			for banner: Dictionary in layout.get("mastery_banners", []):
				blocked.append(banner.host)
			candidates = candidates.filter(
				func(option: Dictionary) -> bool: return not blocked.has(option.row.host)
			)
		return candidates
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
		if item == "ST-030":
			result = result.filter(
				func(option: Dictionary) -> bool:
					return not StadiumFacilityItems.room_at(layout, option.row.site)
			)
		return result
	if StadiumRoofItems.is_family(layout):
		return options(StadiumRoofItems.base(layout), stock, item, tier)
	if not StadiumStraightItems.is_family(layout):
		return result
	if item == "ST-035":
		if tier == "mogul":
			result.append(
				{
					"label": "ENTRY-GATE",
					"row": {"copy": "", "site": "ENTRY-GATE", "lower": "", "concourse": ""}
				}
			)
	elif item == "ST-029" and tier in ["club", "mogul"]:
		for site: String in StadiumBaselineSites.SITES:
			result.append(
				{"label": site, "row": {"copy": "", "site": site, "lower": "", "concourse": ""}}
			)
	elif item in ["ST-031", "ST-030"]:
		for lower: Dictionary in layout.hosts:
			if stock.copies[lower.copy].item != "ST-029":
				continue
			if item == "ST-031":
				result.append(
					{
						"label": lower.site + " • lower " + lower.copy,
						"row":
						{"copy": "", "site": lower.site, "lower": lower.copy, "concourse": ""}
					}
				)
			else:
				for support: Dictionary in layout.hosts:
					if (
						stock.copies[support.copy].item == "ST-031"
						and support.lower == lower.copy
						and support.site == lower.site
					):
						result.append(
							{
								"label": lower.site + " • lower + concourse " + support.copy,
								"row":
								{
									"copy": "",
									"site": lower.site,
									"lower": lower.copy,
									"concourse": support.copy
								}
							}
						)
	elif item == "ST-042":
		for host: Dictionary in layout.hosts + layout.displays:
			var host_item: String = stock.copies[host.copy].item
			if (
				not StadiumStraightOwnedModels.socket(host_item, "crest").is_empty()
				and not crest_blocked(layout, stock, host)
			):
				result.append(
					{
						"label": host.site + " • " + host_item + " • " + host.copy,
						"row": {"copy": "", "host": host.copy, "socket": "crest", "support": ""}
					}
				)
	elif item == "ST-044":
		for support: Dictionary in layout.hosts:
			if stock.copies[support.copy].item == "ST-031":
				result.append(
					{
						"label": support.site + " • upper band • " + support.copy,
						"row":
						{
							"copy": "",
							"host": support.lower,
							"socket": "pennant",
							"support": support.copy
						}
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
	if StadiumRoofItems.is_family(layout):
		return StadiumRoofItems.prune(
			StadiumRoofItems.with_base(
				layout, select(StadiumRoofItems.base(layout), stock, copy, placement)
			)
		)
	var result: Dictionary = layout.duplicate(true)
	if not StadiumStraightItems.is_family(result) or not stock.copies.has(copy):
		return result
	var item: String = stock.copies[copy].item
	if StadiumStraightItems.HOSTS.has(item):
		result.hosts = result.hosts.filter(func(row: Dictionary) -> bool: return row.copy != copy)
		if not placement.is_empty():
			result.hosts = result.hosts.filter(
				func(row: Dictionary) -> bool:
					return row.site != placement.site or stock.copies[row.copy].item != item
			)
			result = StadiumStraightItems.prune(result)
			var row: Dictionary = placement.duplicate(true)
			row.copy = copy
			result.hosts.append(row)
		result.hosts.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return (
					a.site + ":" + str(stock.copies[a.copy].item)
					< b.site + ":" + str(stock.copies[b.copy].item)
				)
		)
	else:
		result.mounts = result.mounts.filter(func(row: Dictionary) -> bool: return row.copy != copy)
		if not placement.is_empty():
			result.mounts = result.mounts.filter(
				func(row: Dictionary) -> bool:
					return row.host != placement.host or row.socket != placement.socket
			)
			var row: Dictionary = placement.duplicate(true)
			row.copy = copy
			result.mounts.append(row)
		result.mounts.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return a.host + ":" + a.socket < b.host + ":" + b.socket
		)
	return StadiumStraightItems.prune(result)


static func crest_blocked(layout: Dictionary, stock: StadiumStock, host: Dictionary) -> bool:
	if stock.copies[host.copy].item != "ST-029":
		return false
	var socket: Dictionary = StadiumStraightOwnedModels.socket("ST-029", "crest")
	var transform: Transform3D = StadiumStraightItems.host_pose(host.site) * socket.transform
	for other: Dictionary in layout.hosts:
		if other.copy == host.copy:
			continue
		var item: String = stock.copies[other.copy].item
		var local: Transform3D = (
			StadiumStraightItems.host_pose(other.site).affine_inverse() * transform
		)
		if (local * StadiumStraightOwnedModels.CREST_BOUNDS).intersects(
			StadiumStraightOwnedModels.envelope(item).grow(-0.0001)
		):
			return true
	return false
