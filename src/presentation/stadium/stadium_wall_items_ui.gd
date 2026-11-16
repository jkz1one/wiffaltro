class_name StadiumWallItemsUI
extends RefCounted
## Whole-run choices and missing-copy purchases; no individual obstacle controls for wall panels.

const SHORT_NAMES: Dictionary = {
	"ST-022": "Right-field plywood",
	"ST-023": "Left-field plywood",
	"ST-024": "Plywood",
	"ST-065": "Padding",
	"ST-077": "Brick",
	"ST-078": "Chain-link"
}


static func show(
	menu: SeasonMenu,
	ledger: ClubAssetLedger,
	draft: Dictionary,
	revision: int,
	editable: bool,
	buyable: bool,
	on_preview: Callable = Callable()
) -> void:
	var stock: StadiumStock = ledger.construction()
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "BOUNDARY WALLS", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Complete runs only. Straight back: 23 copies; deeper center: 22; "
				+ ("each side: 19. Short end panels still use one full owned copy. " + \
					"Swapping and storage are free.")
			)
		)
	)
	SeasonPages.wrapped(
		panel,
		(
			"Back walls: 3.25m; side walls: 1.20m. Back contact stays terminal. "
			+ "Paid wall recipes are daylight-only until their lighting profile is verified."
		)
	)
	for slot: String in ["back", "left", "right"]:
		_choices(
			menu, panel, draft, stock, revision, slot, editable and StadiumWallItems.RUNTIME_READY,
			ledger, on_preview
		)
	if on_preview.is_valid():
		SeasonPages.wrapped(panel, "Buy missing paid panels through Shared Field Upgrades. Current and paused fields stay unchanged.")
		return
	var progress_rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(progress_rows, progress_rows.size())
	for item: String in StadiumWallItems.PRICES:
		menu._label(panel, StadiumFieldLabels.item_name(item), 18)
		var owned: int = _count(stock, item)
		var blueprint: int = (
			0 if stock.blueprints.has(item) else int(StadiumWallItems.PRICES[item][0])
		)
		SeasonPages.wrapped(
			panel,
			(
				"%d owned • %d CB per copy • %s"
				% [
					owned,
					StadiumWallItems.PRICES[item][1],
					"Blueprint owned" if blueprint == 0 else ("Blueprint %d CB" % blueprint)
				]
			)
		)
		var counts: Array[int] = []
		counts.assign([23, 22] if StadiumWallRecipes.BACK_IDS.has(item) else [19])
		for required: int in counts:
			var missing: int = maxi(0, required - owned)
			var recipe: String = (
				"Straight" if required == 23 else ("Deeper center" if required == 22 else "Side")
			)
			var cost: int = (
				0 if missing == 0 else (blueprint + missing * int(StadiumWallItems.PRICES[item][1]))
			)
			var quote: Dictionary = StadiumWallItems.quote(
				stock, item, maxi(1, missing), "wall-preview", progress
			)
			var buy: Button = menu._button(
				panel,
				(
					"%s: %s"
					% [
						recipe,
						(
							"complete set owned"
							if missing == 0
							else "BUY %d MISSING • %d CB" % [missing, cost]
						)
					]
				),
				_buy.bind(menu, item, missing, cost, ledger.revision())
			)
			buy.set_meta("wall_buy", item + ":" + str(required))
			buy.disabled = (
				not buyable
				or not StadiumWallItems.RUNTIME_READY
				or missing == 0
				or not quote.ok
				or ledger.balance() < cost
			)
			if not quote.ok:
				buy.tooltip_text = quote.error


static func _choices(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	stock: StadiumStock,
	revision: int,
	slot: String,
	enabled: bool,
	owner: ClubAssetLedger = null,
	on_preview: Callable = Callable()
) -> void:
	menu._label(panel, StadiumFieldLabels.wall(slot), 18)
	var current: Dictionary = draft.get("walls", StadiumWallLayout.empty())
	var labels: Array[String] = ["Included template"]
	var options: Array[Dictionary] = [{"item": "", "shape": "straight"}]
	var items: Array[String] = []
	items.assign(StadiumWallRecipes.BACK_IDS if slot == "back" else [StadiumWallLayout.SIDES[slot]])
	for item: String in items:
		var shapes: Array[String] = []
		shapes.assign(StadiumWallRecipes.SHAPES if slot == "back" else ["straight"])
		for shape: String in shapes:
			var count: int = StadiumWallRecipes.back(shape, item).size() if slot == "back" else 19
			var missing: int = maxi(0, count - _count(stock, item))
			labels.append(
				(
					"%s • %s • %d copies%s"
					% [
						SHORT_NAMES[item],
						shape.replace("_", " "),
						count,
						" • need %d" % missing if missing > 0 else ""
					]
				)
			)
			options.append({"item": item, "shape": shape})
	var selected: int = 0
	for index in range(1, options.size()):
		if (
			slot == "back"
			and not current.back.is_empty()
			and current.back.item == options[index].item
			and current.back.shape == options[index].shape
		):
			selected = index
		elif slot != "back" and not current[slot].is_empty():
			selected = index
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	choice.set_meta("wall_slot", slot)
	choice.fit_to_longest_item = false
	choice.clip_text = true
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.tooltip_text = labels[selected]
	choice.disabled = not enabled
	for index in range(options.size()):
		var proposal: Dictionary = _proposal(
			menu, draft, stock, slot, options[index].item, options[index].shape, owner
		)
		choice.set_item_disabled(index, not proposal.ok)
		if not proposal.ok:
			choice.set_item_tooltip(index, proposal.error)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= options.size():
				return
			if index == selected or choice.is_item_disabled(index):
				return
			var proposal: Dictionary = _proposal(
				menu, draft, stock, slot, options[index].item, options[index].shape, owner
			)
			if proposal.ok:
				if on_preview.is_valid():
					on_preview.call(proposal.layout, revision)
				else:
					StadiumEditorUI.show(menu, proposal.layout, revision)
			else:
				menu.app.notice = proposal.error
				if not on_preview.is_valid():
					StadiumEditorUI.show(menu, draft, revision)
	)


static func _count(stock: StadiumStock, item: String) -> int:
	var result: int = 0
	for copy: Dictionary in stock.copies.values():
		if copy.item == item:
			result += 1
	return result


static func _buy(menu: SeasonMenu, item: String, quantity: int, cost: int, revision: int) -> void:
	menu.app._confirm(
		(
			(
				"Buy %d %s panels for %d Club Bucks? "
				% [quantity, StadiumFieldLabels.item_name(item), cost]
			)
			+ "This includes any unowned blueprint. "
			+ "Panels go into storage; the current field stays installed."
		),
		_complete_buy.bind(menu, item, quantity, revision)
	)


static func _complete_buy(menu: SeasonMenu, item: String, quantity: int, revision: int) -> void:
	var result: Dictionary = ClubConstruction.buy_walls(menu.app.season, item, quantity, revision)
	menu.app.notice = (
		"Wall panels purchased and stored. Choose a complete run, save, then apply."
		if result.ok
		else result.error
	)
	StadiumEditorUI.show(menu)


static func confirmation(
	active: Dictionary, draft: Dictionary, stock: StadiumStock, tier: String
) -> String:
	if (
		not draft.has("walls")
		or ClubCareer.same(active.get("walls", StadiumWallLayout.empty()), draft.walls)
	):
		return ""
	var checked: Dictionary = StadiumHomeLayout.preview(active, draft, stock, tier)
	if not checked.ok:
		return checked.error
	var before: Dictionary = StadiumHomeLayout.validate(active, stock, tier)
	var light: String = (
		" Future home games become daylight-only."
		if (before.get("night_qualified", false) and not checked.get("night_qualified", false))
		else ""
	)
	return (
		(
			"Apply this complete wall layout? %d panels installed; %d displaced copies stored. "
			% [checked.get("wall_panels", []).size(), checked.displaced.size()]
		)
		+ "No Club Bucks charge. Current frozen games keep their original field."
		+ light
	)


static func _proposal(
	menu: SeasonMenu,
	draft: Dictionary,
	stock: StadiumStock,
	slot: String,
	item: String,
	shape: String,
	owner: ClubAssetLedger = null
) -> Dictionary:
	if StadiumLowWallLayout.is_family(draft):
		if slot == "back" and draft.low_wall != StadiumLowWallManifest.empty():
			return StadiumStarterLayout._error(
				"Store the low-wall profile before selecting a standard back wall."
			)
		var proposed: Dictionary = _proposal(
			menu, StadiumLowWallLayout.base(draft), stock, slot, item, shape, owner
		)
		if not proposed.ok:
			return proposed
		var layout: Dictionary = StadiumLowWallLayout.with_base(draft, proposed.layout)
		var ledger: ClubAssetLedger = owner if owner != null else ClubPlayers.assets(menu.app.season.career)
		var checked: Dictionary = StadiumEditorUI._checked(ledger, layout)
		return {"ok": true, "error": "", "layout": layout} if checked.ok else checked
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
													StadiumOutfieldBleacherItems.is_family(draft)
													or (
														StadiumRisingAppleItems.is_family(draft)
														or (
															StadiumWallTopTerraceItems.is_family(
																draft
															)
															or (
																StadiumPlayerTunnelItems.is_family(
																	draft
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
																				. is_family(draft)
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
		var outer: Dictionary = draft.duplicate(true)
		var inner: Dictionary = StadiumBoundaryItems.base(outer)
		var proposed: Dictionary = StadiumWallLayout.propose(inner.walls, stock, slot, item, shape)
		if not proposed.ok:
			return proposed
		if slot in ["left", "right"]:
			var site: String = "DUGOUT-L" if slot == "left" else "DUGOUT-R"
			outer.boundary = outer.boundary.filter(
				func(row: Dictionary) -> bool: return row.site != site
			)
			outer.walls[slot] = []
		inner.walls = proposed.walls
		var next_boundary: Dictionary = StadiumBoundaryItems.prune(
			StadiumBoundaryItems.with_base(outer, inner)
		)
		var boundary_ledger: ClubAssetLedger = owner if owner != null else ClubPlayers.assets(menu.app.season.career)
		var boundary_checked: Dictionary = StadiumEditorUI._checked(boundary_ledger, next_boundary)
		return (
			{"ok": true, "error": "", "layout": next_boundary}
			if boundary_checked.ok
			else boundary_checked
		)
	var complete: bool = SeasonOwnership._whole(draft.get("version"), 13, 15)
	var ledger: ClubAssetLedger = owner if owner != null else (ClubPlayers.assets(menu.app.season.career) if complete else null)
	if complete and slot == "back":
		return StadiumAdvancedWallUI.propose_ordinary(
			draft,
			stock,
			ledger.wall_pieces(),
			ledger.scoreboards(),
			ledger.surface_owned(),
			ledger.view().land,
			item,
			shape
		)
	var next: Dictionary = StadiumWallItems.upgrade(draft)
	var proposal: Dictionary = StadiumWallLayout.propose(next.walls, stock, slot, item, shape)
	if not proposal.ok:
		return proposal
	next.walls = proposal.walls
	if complete:
		var checked: Dictionary = StadiumEditorUI._checked(ledger, next)
		if not checked.ok:
			return checked
	return {"ok": true, "error": "", "layout": next}
