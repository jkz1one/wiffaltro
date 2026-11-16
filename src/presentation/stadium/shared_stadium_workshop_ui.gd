extends RefCounted
## Shared starter, seating, ground, display, light and receiver workshop.
## Later families stay intact and read-only until
## their existing public command/gate contracts are adapted explicitly.
const PoolUI = preload("res://src/presentation/stadium/shared_stadium_pool_ui.gd")
const Transaction = preload("res://src/presentation/stadium/shared_stadium_transaction_ui.gd")
const Access = preload("res://src/presentation/stadium/stadium_career_access.gd")


static func show(app: Node, draft: Dictionary = {}, revision: int = -1) -> void:
	var menu: SeasonMenu = app.menu
	menu._screen("shared_stadium", "SHARED STADIUM WORKSHOP", "Current shared inventory • Frozen seasons stay unchanged")
	var context: Dictionary = Access.presentation(app)
	var paid: ClubAssetLedger = context.ledger
	if paid == null:
		SeasonPages.wrapped(menu._body, "Recover the exact saved shared owner before editing.")
		menu._button(menu._body, "RECOVER SHARED CAREER", app.dynasty_owner._recover)
		menu._button(menu._footer, "CLUB RECORD", ClubCareerUI.show.bind(menu, 0))
		_guard_controls(app)
		return
	var view: Dictionary = paid.view()
	if draft.is_empty():
		draft = view.stadium_draft.duplicate(true)
		revision = paid.revision()
	if draft.get("version") == 16 and Access.Assets.Pool.supported(draft):
		PoolUI.show(app, draft, revision)
		return
	PoolUI.entries(app, draft, revision)
	menu._label(menu._body, "CLUB BUCKS • %d" % paid.balance(), 26)
	SeasonPages.wrapped(menu._body, "Purchases use the single shared balance. Save and Apply change only future season admissions. Your current and paused home fields, rosters and draft pools stay frozen.")
	var changed: bool = not ClubCareer.same(draft, view.stadium_draft)
	menu._button(menu._body, "OWNED COPY CATALOG", _navigate.bind(app, changed, show_catalog.bind(app, "ST-080")))
	menu._button(menu._body, "FIELD UPGRADES", _navigate.bind(app, changed, show_upgrades.bind(app, 0, 1)))
	if not Access.Assets.layout_adapted(draft):
		SeasonPages.wrapped(menu._body, "This saved layout family is preserved read-only here. Its shared workshop adapter is not enabled yet; no field is replaced and no purchase is made.")
		menu._button(menu._footer, "CLUB RECORD", ClubCareerUI.show.bind(menu, 0))
		_guard_controls(app)
		return
	var editable: bool = context.editable
	var stale: bool = revision != paid.revision()
	var valid: Dictionary = _validate(draft, paid)
	if not editable:
		SeasonPages.wrapped(menu._body, "Editing opens at completion or before the first draft pick. Existing fields remain playable.")
	if stale:
		SeasonPages.wrapped(menu._body, "Shared inventory changed. Reload before saving this preview.")
	if not valid.ok:
		SeasonPages.wrapped(menu._body, valid.error)
		# Never pass untrusted held previews to builders or placement controls.
		menu._button(menu._footer, "RELOAD SAVED", _navigate.bind(app, changed, show.bind(app, {}, -1)))
		menu._button(menu._footer, "CLUB RECORD", _back.bind(app, changed))
		_guard_controls(app)
		return
	menu._label(menu._body, StadiumLightItemsUI.status(valid), 18)
	StadiumLightItemsUI.warning(menu, view.stadium_active, valid, paid.construction(), view.land, paid)
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	menu._body.add_child(preview)
	preview.build(draft, paid.construction(), true, view.land, paid.wall_pieces(), paid.scoreboards(), paid.surface_owned())
	_preview_controls(menu, preview)
	if draft.version == 47:
		StadiumWaterfallAnimationUI.controls(menu, draft, revision, editable and not stale, _preview.bind(app, menu._body))
	else:
		_slot(menu, app, draft, revision, paid, "RECEIVER-PRIMARY", editable and not stale)
		for site: String in StadiumStarterLayout.SITES:
			_slot(menu, app, draft, revision, paid, site, editable and not stale)
		var copies: Dictionary = paid.construction().copies
		for copy: String in copies:
			var item: String = copies[copy].item
			if item == "ST-112" or not StadiumOutfieldPlazaItemsUI.placement(draft, copy).is_empty():
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				StadiumOutfieldPlazaItemsUI.card(menu, card, draft, copy, revision,
					editable and not stale, paid, _preview.bind(app, menu._body))
				continue
			if item == StadiumMasteryBannerItems.ITEM or item == "ST-005" or StadiumMountedDisplayItems.ITEMS.has(item) or StadiumStringLightItems.ITEMS.has(item):
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				if item == StadiumMasteryBannerItems.ITEM:
					StadiumMasteryBannerItemsUI.card(menu, card, draft, copy, revision, editable and not stale, paid, _preview.bind(app, menu._body))
				elif item == "ST-005":
					StadiumSalvageCarUI.card(menu, card, draft, copy, revision, editable and not stale, paid, _preview.bind(app, menu._body))
				elif StadiumMountedDisplayItems.ITEMS.has(item):
					StadiumMountedDisplayItemsUI.card(menu, card, draft, copy, revision, editable and not stale, paid, _preview.bind(app, menu._body))
				else:
					StadiumStringLightItemsUI.card(menu, card, draft, copy, revision, editable and not stale, paid, _preview.bind(app, menu._body))
			elif StadiumSmallYardSceneryItems.ITEMS.has(item):
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				StadiumSmallYardSceneryItemsUI.card(menu, card, draft, copy, item, revision,
					editable and not stale, paid, _preview.bind(app, menu._body))
			elif item == "ST-043" or StadiumGroundPropsItems.PRICES.has(item) or StadiumFloodlightOwnedItems.PRICES.has(item) or StadiumLandscapeOwnedItems.PRICES.has(item) or StadiumLiveFurnishingItems.PRICES.has(item):
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				if item == "ST-043":
					StadiumClubItemsUI.flag_card(menu, card, draft, copy, revision, editable and not stale, paid, _preview.bind(app, menu._body))
				elif StadiumGroundPropsItems.PRICES.has(item):
					StadiumClubItemsUI.ground_props_card(menu, card, draft, copy, item, revision, editable and not stale, paid, _preview.bind(app, menu._body))
				elif StadiumFloodlightOwnedItems.PRICES.has(item):
					StadiumFloodlightOwnedItemsUI.card(menu, card, draft, copy, revision, editable and not stale, paid, _preview.bind(app, menu._body))
				elif StadiumLandscapeOwnedItems.PRICES.has(item):
					StadiumLandscapeOwnedItemsUI.card(menu, card, draft, copy, item, revision, editable and not stale, paid, _preview.bind(app, menu._body))
				else:
					StadiumLiveFurnishingItemsUI.card(menu, card, draft, copy, item, revision, editable and not stale, paid, _preview.bind(app, menu._body))
			elif StadiumPurchases.SEATING.has(item):
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				StadiumSeatingEditorUI.card(menu, card, draft, copy, item, revision,
					editable and not stale, view.land, _preview.bind(app, menu._body))
			elif StadiumPurchases.DISPLAYS.has(item):
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				StadiumClubItemsUI.card(menu, card, draft, copy, item, revision,
					editable and not stale, _preview.bind(app, menu._body))
			elif StadiumPurchases.BLEACHERS.has(item) or item in ["ST-026", "ST-025", "ST-037"]:
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				var return_preview: Callable = _preview.bind(app, menu._body)
				if StadiumPurchases.BLEACHERS.has(item):
					StadiumBleacherItemsUI.card(menu, card, draft, copy, item, revision,
						editable and not stale, view.land, return_preview)
				elif item == "ST-026":
					StadiumTargetItemsUI.card(menu, card, draft, copy, revision, editable and not stale, return_preview)
				elif item == "ST-025":
					StadiumNetItemsUI.card(menu, card, draft, copy, revision, editable and not stale, return_preview)
				else:
					StadiumLightItemsUI.card(menu, card, draft, copy, revision, editable and not stale, return_preview)
			elif _structure_card(item).is_valid():
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				_structure_card(item).call(menu, card, draft, copy, item, revision,
					editable and not stale, paid, _preview.bind(app, menu._body))
			elif _assembly_card(item).is_valid():
				var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
				menu._label(card, StadiumFieldLabels.item_name(item) + " • " + copy, 18)
				_assembly_card(item).call(menu, card, draft, copy, revision,
					editable and not stale, paid, _preview.bind(app, menu._body))
		if StadiumMoldedSeatItems.has_pad(draft) or copies.values().any(func(row: Dictionary) -> bool: return row.item == "ST-051"):
			var pad_panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
			menu._label(pad_panel, "MOLDED SEAT PAD", 18)
			StadiumMoldedSeatItemsUI.pad_controls(menu, pad_panel, paid, draft, revision,
				editable and not stale, _preview.bind(app, menu._body))
		if draft.has("boundary") or copies.values().any(func(row: Dictionary) -> bool: return row.item in StadiumBoundaryItems.PRICES):
			StadiumBoundaryItemsUI.runs(menu, paid, draft, revision, editable and not stale, _preview.bind(app, menu._body))

		_salvage_clearance(app, paid, revision, editable and not stale and not changed)
		StadiumFloodlightOwnedItemsUI.presets(menu, paid, draft, revision, editable and not stale, _preview.bind(app, menu._body))
		if StadiumWallItems.RUNTIME_READY:
			StadiumWallItemsUI.show(menu, paid, draft, revision, editable and not stale, false, _preview.bind(app, menu._body))
		if StadiumScoreboardLayout.RUNTIME_READY:
			StadiumScoreboardUI.show(menu, paid, draft, revision, editable and not stale, false, _preview.bind(app, menu._body))
		var appearance: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(appearance, "FIELD APPEARANCE", 22)
		SeasonPages.wrapped(appearance, "Select purchased looks from current shared inventory. Save and Apply affect only future admissions.")
		for channel: String in StadiumFieldStyleModels.CHANNELS:
			menu._label(appearance, "BASELINES" if channel == "line" else "GRASS PATTERN", 18)
			StadiumFieldStylesUI._selector(menu, appearance, draft, paid.construction(), channel,
				revision, editable and not stale, _preview.bind(app, menu._body))
		menu._label(appearance, "DIRT / GRASS LAYOUT", 18)
		StadiumGroundStylesUI._selector(menu, appearance, draft, paid.construction(),
			revision, editable and not stale, paid.surface_owned(), _preview.bind(app, menu._body))
		menu._label(appearance, "BASE MARKERS", 18)
		StadiumBaseMarkersUI._selector(menu, appearance, draft, paid.construction(),
			revision, editable and not stale, _preview.bind(app, menu._body))
		var foundation: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(foundation, "FIELD FOUNDATION", 22)
		SeasonPages.wrapped(foundation, "Choose owned flat dirt or grass finishes. Textured surfaces use the existing daylight admission rules. Purchase preparation and grass in Field Upgrades.")
		if draft.version == 17:
			StadiumSurfaceUI._terrain_choices(menu, foundation, draft, paid.surface_owned(), revision,
				editable and not stale, _preview.bind(app, menu._body))
		elif draft.has("surface"):
			StadiumSurfaceUI._choices(menu, foundation, draft, paid.surface_owned(), revision,
				editable and not stale, _preview.bind(app, menu._body))
		else:
			var opt: Button = menu._button(foundation, "PREVIEW TEXTURED SURFACE",
				StadiumSurfaceUI._opt_in.bind(menu, draft, paid.surface_owned(), revision, _preview.bind(app, menu._body)))
			opt.set_meta("surface_opt_in", true)
			opt.disabled = not editable or stale
		var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(draft, paid.surface_owned())
		if not terrain.is_empty() and StadiumProperty.BOUNDS.has(view.land):
			var terrain_button: Button = menu._button(foundation, "PREVIEW PLAYABLE DIRT TERRAIN",
				_preview.bind(terrain, revision, app, menu._body))
			terrain_button.set_meta("terrain_opt_in", true)
			terrain_button.disabled = not editable or stale or not app.season.owned_surface_night.is_empty()
		menu._label(menu._body, "EXTRA STARTER COPIES • Stored until placed", 22)
		for item: String in StadiumPurchases.PRICES:
			var buy: Button = menu._button(menu._body, "%s • %d CB" % [StadiumFieldLabels.item_name(item), StadiumPurchases.PRICES[item]], _buy.bind(app, item, paid.revision()))
			buy.set_meta("shared_stadium_buy", item)
			buy.disabled = not editable or stale or changed or paid.balance() < StadiumPurchases.PRICES[item]
		StadiumWaterfallAnimationUI.offer(menu, paid, draft, revision, editable and not stale, _preview.bind(app, menu._body))
	var save: Button = menu._button(menu._footer, "SAVE SHARED DRAFT", _save.bind(app, draft, revision))
	save.set_meta("shared_stadium_action", "save")
	save.disabled = not editable or stale or not valid.ok or not changed or not ClubConstruction.draft_admission(app.season, draft, true).ok
	var apply: Button = menu._button(menu._footer, "APPLY FOR FUTURE SEASONS", _ask_apply.bind(app, draft, revision))
	apply.set_meta("shared_stadium_action", "apply")
	apply.disabled = not editable or stale or not valid.ok or changed or ClubCareer.same(draft, view.stadium_active) or not ClubConstruction.apply_admission(app.season, draft, true).ok
	menu._button(menu._footer, "RELOAD SAVED", _navigate.bind(app, changed, show.bind(app, {}, -1)))
	menu._button(menu._footer, "CLUB RECORD", _back.bind(app, changed))
	_guard_controls(app)


static func _slot(menu: SeasonMenu, app: Node, draft: Dictionary, revision: int, paid: ClubAssetLedger, site: String, enabled: bool) -> void:
	menu._label(menu._body, site, 18)
	var choices: Array[String] = [""]
	var current: String = draft.receiver if site == "RECEIVER-PRIMARY" else ""
	for row: Dictionary in draft.obstacles:
		if row.site == site:
			current = row.copy
	var select: OptionButton = OptionButton.new()
	select.add_item("Empty / stored")
	var copies: Dictionary = paid.construction().copies
	var ids: Array = copies.keys()
	ids.sort()
	for id: String in ids:
		if (site == "RECEIVER-PRIMARY" and copies[id].item == "ST-079") \
			or (site != "RECEIVER-PRIMARY" and copies[id].item in ["ST-001", "ST-003"]):
			choices.append(id)
			select.add_item("%s • %s" % [StadiumFieldLabels.item_name(copies[id].item), id])
	select.select(maxi(0, choices.find(current)))
	select.disabled = not enabled
	select.set_meta("shared_stadium_site", site)
	select.item_selected.connect(func(index: int) -> void:
		if select.is_inside_tree() and not select.disabled:
			_choose(index, app, draft, revision, site, choices))
	menu._body.add_child(select)
	if site != "RECEIVER-PRIMARY" and not current.is_empty() and copies.get(current, {}).get("item") == "ST-003":
		var yaw: OptionButton = OptionButton.new()
		for value: int in [0, 90, 180, 270]:
			yaw.add_item("Turn %d°" % value)
		for row: Dictionary in draft.obstacles:
			if row.site == site:
				yaw.select(int(row.yaw) / 90)
		yaw.disabled = not enabled
		yaw.item_selected.connect(func(index: int) -> void:
			if yaw.is_inside_tree() and not yaw.disabled and index >= 0 and index < yaw.item_count:
				_turn(index, app, draft, revision, site))
		menu._body.add_child(yaw)


static func _choose(index: int, app: Node, draft: Dictionary, revision: int, site: String, choices: Array[String]) -> void:
	if index < 0 or index >= choices.size():
		return
	var next: Dictionary = draft.duplicate(true)
	if site == "RECEIVER-PRIMARY":
		next.receiver = choices[index]
		if not next.receiver.is_empty():
			if next.has("target"):
				next.target = ""
			if next.has("net"):
				next.net = ""
	else:
		if not choices[index].is_empty() and next.has("yard_scenery"):
			next = StadiumSmallYardSceneryItems.store_copy(next, choices[index])
		next.obstacles = next.obstacles.filter(func(row: Dictionary) -> bool: return row.site != site)
		if not choices[index].is_empty():
			next.obstacles.append({"copy": choices[index], "site": site, "yaw": 0})
		next.obstacles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	_preview(next, revision, app, app.menu._body)


static func _turn(index: int, app: Node, draft: Dictionary, revision: int, site: String) -> void:
	var next: Dictionary = draft.duplicate(true)
	for row: Dictionary in next.obstacles:
		if row.site == site:
			row.yaw = index * 90
	_preview(next, revision, app, app.menu._body)


static func _save(app: Node, draft: Dictionary, revision: int) -> void:
	Transaction.run(app, _origin_guard(app.menu), "SAVING SHARED DRAFT…",
		Access.save_draft.bind(app, draft, revision), _saved.bind(app, draft, revision))


static func _saved(result: Dictionary, app: Node, draft: Dictionary, revision: int) -> void:
	app.notice = "Shared draft saved. Apply it for future seasons." if result.ok else result.error
	show(app, {} if result.ok else draft, -1 if result.ok else revision)


static func _ask_apply(app: Node, draft: Dictionary, revision: int) -> void:
	app._confirm("Apply this shared field for future seasons? Current and paused fields remain unchanged. No Club Bucks are charged.", _route_action(app, _apply.bind(app, draft, revision)))


static func _apply(app: Node, draft: Dictionary, revision: int) -> void:
	Transaction.run(app, _origin_guard(app.menu), "APPLYING FIELD FOR FUTURE SEASONS…",
		Access.apply_draft.bind(app, draft, revision), _applied.bind(app, draft, revision))


static func _applied(result: Dictionary, app: Node, draft: Dictionary, revision: int) -> void:
	app.notice = "Field saved for future season admissions. Existing fields are unchanged." if result.ok else result.error
	show(app, {} if result.ok else draft, -1 if result.ok else revision)


static func _buy(app: Node, item: String, revision: int) -> void:
	Transaction.run(app, _origin_guard(app.menu), "PURCHASING SHARED COPY…",
		Access.buy_copy.bind(app, item, revision), _bought.bind(app))


static func _bought(result: Dictionary, app: Node) -> void:
	app.notice = "One copy bought and stored in shared inventory." if result.ok else result.error
	show(app)


static func _navigate(app: Node, changed: bool, destination: Callable) -> void:
	if changed:
		app._confirm("Discard unsaved shared stadium preview edits?", _route_action(app, destination))
	else:
		destination.call()


static func _back(app: Node, changed: bool) -> void:
	_navigate(app, changed, ClubCareerUI.show.bind(app.menu, 0))


static func show_catalog(app: Node, item: String = "ST-080") -> void:
	var menu: SeasonMenu = app.menu
	menu._screen("shared_stadium_catalog", "SHARED OWNED COPY CATALOG", "Existing catalog • Shared balance • Stored copies")
	SeasonPages.wrapped(menu._body, "Blueprints, earned requirements and copy prices follow the existing workshop catalog. Buying stores a copy; current and paused fields stay unchanged. Layout-family editing remains separately gated.")
	var items: Array[String] = []
	for id: String in ClubConstruction.copy_items():
		if Access.Assets.copy_enabled(id):
			items.append(id)
	var choice: OptionButton = OptionButton.new()
	for id: String in items:
		choice.add_item("%s • %s" % [id, StadiumFieldLabels.item_name(id)])
	choice.select(maxi(0, items.find(item)))
	choice.item_selected.connect(_catalog_select.bind(app, items))
	menu._body.add_child(choice)
	var quote: Dictionary = Access.copy_quote(app, item)
	if quote.ok:
		menu._label(menu._body, "ONE COPY • %d CB TOTAL" % quote.cost, 24)
		SeasonPages.wrapped(menu._body, "Includes any required blueprint. No recurring cost. The exact quoted total is debited once.")
		menu._button(menu._body, "REVIEW PURCHASE", _catalog_confirm.bind(app, item, quote))
	else:
		SeasonPages.wrapped(menu._body, quote.error)
	menu._button(menu._footer, "WORKSHOP", show.bind(app, {}, -1))
	_guard_controls(app)


static func _catalog_select(index: int, app: Node, items: Array[String]) -> void:
	if index >= 0 and index < items.size():
		show_catalog(app, items[index])


static func _catalog_confirm(app: Node, item: String, quote: Dictionary) -> void:
	app._confirm("Buy one %s copy for %d shared Club Bucks, including any required blueprint? Existing fields stay unchanged." % [StadiumFieldLabels.item_name(item), quote.cost], _route_action(app, _catalog_buy.bind(app, item, quote)))


static func _catalog_buy(app: Node, item: String, quote: Dictionary) -> void:
	Transaction.run(app, _origin_guard(app.menu), "PURCHASING SHARED COPY…",
		Access.commit_quote.bind(app, quote), _catalog_bought.bind(app, item))


static func _catalog_bought(result: Dictionary, app: Node, item: String) -> void:
	app.notice = "Copy stored in shared inventory." if result.ok else result.error
	show_catalog(app, item)


static func show_upgrades(app: Node, selection: int = 0, quantity: int = 1) -> void:
	var menu: SeasonMenu = app.menu
	menu._screen("shared_stadium_upgrades", "SHARED FIELD UPGRADES", "Existing prices and earned requirements")
	SeasonPages.wrapped(menu._body, "These purchases change shared inventory for future admissions. Current and paused home fields, lighting and pools stay frozen. Placement and layout-family gates remain unchanged.")
	var rows: Array[Dictionary] = Access.Assets.Upgrades.entries()
	selection = clampi(selection, 0, rows.size() - 1)
	var selected: Dictionary = rows[selection]
	var choice: OptionButton = OptionButton.new()
	for row: Dictionary in rows:
		choice.add_item(row.label)
	choice.select(selection)
	choice.item_selected.connect(_upgrade_select.bind(app))
	menu._body.add_child(choice)
	if selected.op in ["stadium_buy", "stadium_wall_piece", "stadium_scoreboard"]:
		var count: SpinBox = SpinBox.new()
		count.min_value = 1
		count.max_value = 64
		count.step = 1
		count.value = quantity
		count.value_changed.connect(_upgrade_quantity.bind(app, selection))
		menu._body.add_child(count)
	else:
		quantity = 1
	var quote: Dictionary = Access.upgrade_quote(app, selected.op, selected.item, quantity)
	if quote.ok:
		menu._label(menu._body, "TOTAL • %d SHARED CB" % quote.cost, 24)
		menu._button(menu._body, "REVIEW UPGRADE", _upgrade_confirm.bind(app, selection, quantity, selected.label, quote))
	else:
		SeasonPages.wrapped(menu._body, quote.error)
	menu._button(menu._footer, "WORKSHOP", show.bind(app, {}, -1))
	_guard_controls(app)


static func _upgrade_select(index: int, app: Node) -> void:
	show_upgrades(app, index, 1)


static func _upgrade_quantity(value: float, app: Node, selection: int) -> void:
	show_upgrades(app, selection, int(value))


static func _upgrade_confirm(app: Node, selection: int, quantity: int, label: String, quote: Dictionary) -> void:
	app._confirm("%s (quantity %d) for %d shared Club Bucks total? Any required blueprint is included. Existing fields remain unchanged." % [label, quantity, quote.cost], _route_action(app, _upgrade_buy.bind(app, selection, quantity, quote)))


static func _upgrade_buy(app: Node, selection: int, quantity: int, quote: Dictionary) -> void:
	Transaction.run(app, _origin_guard(app.menu), "SAVING SHARED UPGRADE…",
		Access.commit_quote.bind(app, quote), _upgrade_bought.bind(app, selection, quantity))


static func _upgrade_bought(result: Dictionary, app: Node, selection: int, quantity: int) -> void:
	app.notice = "Shared upgrade saved for future admissions." if result.ok else result.error
	show_upgrades(app, selection, quantity)


static func _attached(menu: Variant, origin: Variant, page: String) -> bool:
	return is_instance_valid(menu) and menu.is_inside_tree() and menu.page == page \
		and is_instance_valid(origin) and origin.is_inside_tree() and menu._body == origin


static func _origin_guard(menu: SeasonMenu) -> Callable:
	# Weak captures remain safe even when a retained callback outlives its nodes.
	var menu_ref: WeakRef = weakref(menu)
	var origin_ref: WeakRef = weakref(menu._body)
	var page: String = menu.page
	return func() -> bool:
		return _attached(menu_ref.get_ref(), origin_ref.get_ref(), page)


static func _route_guard(menu: SeasonMenu) -> Callable:
	var attached: Callable = _origin_guard(menu)
	var menu_ref: WeakRef = weakref(menu)
	return func() -> bool:
		return attached.call() and not Transaction.busy(menu_ref.get_ref())


static func _route_action(app: Node, action: Callable) -> Callable:
	var current: Callable = _route_guard(app.menu)
	var used: Array[bool] = [false]
	return func() -> void:
		if not used[0] and current.call():
			used[0] = true
			action.call()


static func _guard_controls(app: Node) -> void:
	# Shared-only boundary: reject retired or disabled controls before invoking
	# reusable card callbacks. Ordinary editor wiring and defaults stay untouched.
	var menu: SeasonMenu = app.menu
	var current: Callable = _route_guard(menu)
	for parent: Control in [menu._body, menu._footer]:
		for node: Node in parent.find_children("*", "Control", true, false):
			if node is OptionButton:
				_guard_selection(current, node)
			elif node is Button:
				_guard_button(current, node)
			elif node is SpinBox:
				_guard_quantity(current, node)


static func _guard_button(current: Callable, button: Button) -> void:
	var control: WeakRef = weakref(button)
	for connection: Dictionary in button.pressed.get_connections():
		var action: Callable = connection.callable
		button.pressed.disconnect(action)
		button.pressed.connect(func() -> void:
			if not current.call():
				return
			var live: Button = control.get_ref()
			if is_instance_valid(live) and live.is_inside_tree() and not live.disabled:
				action.call(), connection.flags)


static func _guard_selection(current: Callable, choice: OptionButton) -> void:
	var control: WeakRef = weakref(choice)
	for connection: Dictionary in choice.item_selected.get_connections():
		var action: Callable = connection.callable
		choice.item_selected.disconnect(action)
		choice.item_selected.connect(func(index: int) -> void:
			if not current.call():
				return
			var live: OptionButton = control.get_ref()
			if is_instance_valid(live) and live.is_inside_tree() and not live.disabled \
				and index >= 0 and index < live.item_count and not live.is_item_disabled(index):
				action.call(index), connection.flags)


static func _guard_quantity(current: Callable, count: SpinBox) -> void:
	var control: WeakRef = weakref(count)
	for connection: Dictionary in count.value_changed.get_connections():
		var action: Callable = connection.callable
		count.value_changed.disconnect(action)
		count.value_changed.connect(func(value: float) -> void:
			if not current.call():
				return
			var live: SpinBox = control.get_ref()
			if is_instance_valid(live) and live.is_inside_tree() and live.editable \
				and value >= live.min_value and value <= live.max_value and value == floorf(value):
				action.call(value), connection.flags)


static func _preview(draft: Dictionary, revision: int, app: Variant, origin: Variant) -> void:
	# Render identity comes before current shared authority and paid validation.
	if not is_instance_valid(app) or not _attached(app.menu, origin, "shared_stadium") or Transaction.busy(app.menu):
		return
	var context: Dictionary = Access.presentation(app)
	var paid: ClubAssetLedger = context.ledger
	if paid == null or not context.editable or paid.revision() != revision:
		return
	if not Access.Assets.layout_adapted(draft):
		return
	if not _validate(draft, paid).ok:
		return
	show(app, draft, revision)


static func _validate(draft: Dictionary, paid: ClubAssetLedger) -> Dictionary:
	return StadiumEditorUI._checked(paid, draft, paid.view().land)


static func _preview_controls(menu: SeasonMenu, preview: StadiumDraftPreview) -> void:
	# Camera and environment controls affect this read-only preview only. Detached
	# callbacks cannot move a replacement screen or a retired preview instance.
	var origin: VBoxContainer = menu._body
	var current: Callable = func() -> bool:
		return is_instance_valid(preview) and preview.is_inside_tree() \
			and is_instance_valid(origin) and menu._body == origin
	var overview: Button = menu._button(origin, "FIELD VIEW", func() -> void:
		if current.call():
			preview.overview())
	overview.set_meta("shared_preview_action", "overview")
	if is_instance_valid(preview.lighting_kit_preview) or preview.night_eligible:
		var label: String = "DAY / LIGHTING STUDY (NOT SEASON NIGHT)" \
			if is_instance_valid(preview.lighting_kit_preview) else "DAY / NIGHT PREVIEW"
		var lighting: Button = menu._button(origin, label, func() -> void:
			if current.call():
				preview.toggle_environment())
		lighting.set_meta("shared_preview_action", "lighting")
	var ids: Array = preview.positions.keys()
	ids.sort()
	for copy: String in ids:
		var item: String = str(preview.items.get(copy, ""))
		var name: String = StadiumFieldLabels.item_name(item) if not item.is_empty() else copy
		var focus: Button = menu._button(origin, "FOCUS " + name.to_upper() + " • " + copy,
			func() -> void:
				if current.call():
					preview.focus_copy(copy))
		focus.set_meta("shared_preview_action", "focus")
		focus.set_meta("shared_preview_copy", copy)

static func _structure_card(item: String) -> Callable:
	if item in StadiumReceiverOwnedItems.PRICES:
		return StadiumReceiverOwnedItemsUI.card
	if item in StadiumBoundaryItems.PRICES:
		return StadiumBoundaryItemsUI.card
	if item in StadiumFacilityItems.PRICES:
		return StadiumFacilityItemsUI.card
	if item in StadiumRoofItems.PRICES:
		return StadiumRoofItemsUI.card
	if item in StadiumStraightItems.HOSTS or item in StadiumStraightItems.MOUNTS:
		return StadiumStraightItemsUI.card
	return Callable()


static func _assembly_card(item: String) -> Callable:
	if item in StadiumWaterfallItems.ITEMS:
		return StadiumWaterfallItemsUI.card
	if item in StadiumLightingKitItems.ITEMS:
		return StadiumLightingKitItemsUI.card
	if item in StadiumMoldedSeatItems.ITEMS:
		return StadiumMoldedSeatItemsUI.card
	if item in StadiumGroundBoxItems.ITEMS:
		return StadiumGroundBoxItemsUI.card
	if item in StadiumPracticeFacilityItems.ITEMS:
		return StadiumPracticeFacilityItemsUI.card
	if item in StadiumTreehouseItems.ITEMS:
		return StadiumTreehouseItemsUI.card
	if item in StadiumLandmarkItems.ITEMS:
		return StadiumLandmarkItemsUI.card
	if item in StadiumOutfieldBleacherItems.ITEMS:
		return StadiumOutfieldBleacherItemsUI.card
	if item in StadiumRisingAppleItems.ITEMS:
		return StadiumRisingAppleItemsUI.card
	if item in StadiumWallTopTerraceItems.ITEMS:
		return StadiumWallTopTerraceItemsUI.card
	if item in StadiumPlayerTunnelItems.ITEMS:
		return StadiumPlayerTunnelItemsUI.card
	return Callable()

static func _salvage_clearance(app: Node, paid: ClubAssetLedger, revision: int, enabled: bool) -> void:
	var view: Dictionary = paid.view()
	if view.get("salvage_origin", {}).is_empty() or view.get("salvage_cleared", false):
		return
	var menu: SeasonMenu = app.menu
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "STARTER CAR CLEARANCE", 22)
	SeasonPages.wrapped(panel, "Pay 190 shared Club Bucks once to store the same starter car. No blueprint or duplicate copy is granted. Current and paused home fields remain frozen.")
	var review: Button = menu._button(panel, "REVIEW CLEARANCE • 190 CB", func() -> void: pass)
	review.set_meta("shared_salvage_clear", true)
	review.disabled = not enabled or paid.balance() < 190
	review.pressed.connect(func() -> void:
		if review.is_inside_tree() and not review.disabled:
			_review_clearance(app, revision))


static func _review_clearance(app: Node, revision: int) -> void:
	var quote: Dictionary = Access.upgrade_quote(app, "stadium_salvage_clear", "", 1)
	if not quote.get("ok", false) or quote.get("command", {}).get("rev") != revision:
		app.notice = quote.error if not quote.get("ok", false) else "Shared inventory changed. Reload before clearance."
		show(app)
		return
	app._confirm("Pay %d shared Club Bucks once to clear the starter car into storage? The same copy remains owned; no blueprint or duplicate is granted. This saves immediately for future admissions. Current and paused fields stay unchanged." % quote.cost,
		_route_action(app, _commit_clearance.bind(app, quote)))


static func _commit_clearance(app: Node, quote: Dictionary) -> void:
	Transaction.run(app, _origin_guard(app.menu), "CLEARING STARTER CAR INTO STORAGE…",
		Access.commit_quote.bind(app, quote), _cleared.bind(app))


static func _cleared(result: Dictionary, app: Node) -> void:
	app.notice = "Starter car cleared. The same owned copy is stored for future seasons." if result.ok else result.error
	show(app)
