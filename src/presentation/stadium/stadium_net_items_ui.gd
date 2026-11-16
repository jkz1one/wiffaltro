class_name StadiumNetItemsUI
extends RefCounted
## Optional separately owned catching net, only behind an explicitly installed target.


static func card(
	menu: SeasonMenu,
	parent: VBoxContainer,
	draft: Dictionary,
	copy: String,
	revision: int,
	enabled: bool,
	on_preview: Callable = Callable()
) -> void:
	var active: bool = draft.get("net", "") == copy
	var choice: OptionButton = StadiumEditorUI._options(
		parent, ["Stored", "Behind installed target"], 1 if active else 0
	)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not enabled
	choice.set_item_disabled(1, String(draft.get("target", "")).is_empty())
	SeasonPages.wrapped(
		parent,
		(
			"Requires your separately owned target in Receiver primary. "
			+ "Removing this net keeps the target. Removing the target stores both copies free."
		)
	)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
				return
			if choice.is_item_disabled(index):
				return
			if index == 0 and not active:
				return
			if index == 1 and String(draft.get("target", "")).is_empty():
				return
			var next: Dictionary = StadiumNetItems.upgrade(draft)
			next.net = copy if index == 1 else ""
			if (
				index == 1
				and (
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
												StadiumPracticeFacilityItems.is_family(next)
												or (
													StadiumTreehouseItems.is_family(next)
													or (
														StadiumLandmarkItems.is_family(next)
														or (
															StadiumOutfieldBleacherItems.is_family(
																next
															)
															or (
																StadiumRisingAppleItems.is_family(
																	next
																)
																or (
																	(
																		StadiumWallTopTerraceItems
																		. is_family(next)
																	)
																	or (
																		(
																			StadiumPlayerTunnelItems
																			. is_family(next)
																		)
																		or (
																			(
																				StadiumMountedDisplayItems
																				. is_family(next)
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
			):
				next.catcher = ""
			if on_preview.is_valid():
				on_preview.call(next, revision)
			else:
				StadiumEditorUI.show(menu, next, revision)
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "CATCHING NET", 22)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	SeasonPages.wrapped(
		panel,
		(
			"Unlock after 3 completed seasons and 8 regular-season wins. "
			+ (
				"Your closed career: %d seasons • %d wins. Target purchased separately."
				% [progress.seasons, progress.wins]
			)
		)
	)
	var quote: Dictionary = StadiumPurchases.quote(
		ledger.construction(), "ST-025", 1, "net-preview", StadiumPurchases.NET_VERSION, progress
	)
	var blueprint: int = 0 if ledger.construction().blueprints.has("ST-025") else 300
	SeasonPages.wrapped(
		panel,
		(
			"Blueprint owned • 90 CB per copy"
			if blueprint == 0
			else "300 blueprint + 90 copy = 390 CB • Catching net only"
		)
	)
	var buy: Button = menu._button(
		panel,
		"BUY PORTABLE CATCHING NET",
		StadiumEditorUI._buy.bind(menu, "ST-025", ledger.revision())
	)
	buy.set_meta("stadium_buy", "ST-025")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < blueprint + 90
	if not quote.ok:
		buy.tooltip_text = quote.error
