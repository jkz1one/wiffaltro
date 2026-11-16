class_name StadiumMoldedSeatItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Four exact property-authored sockets. The pad grants no inventory or represented crowd.

const NIGHT_REASON: String = ("The molded-seat pad plan is daylight-only until its lighting and " \
	+ "camera views are qualified.")


static func choices() -> Array[String]:
	return ["Stored", "SEAT-PAD-1", "SEAT-PAD-2", "SEAT-PAD-3", "SEAT-PAD-4"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "MOLDED STADIUM SEATS", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if stock.copies[copy].item == "ST-051":
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Pad: %d of 4 sockets filled • %d owned copies"
			% [draft.get("molded_seats", []).size(), owned_count]
		)
	)
	var entry: Dictionary = StadiumCatalog.item("ST-051")
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var cost: int = (
		int(entry.copy_price)
		+ (0 if stock.blueprints.has("ST-051") else int(entry.blueprint_price))
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Expanded+ supplies one fixed pad with four empty sockets. Every visible seat costs "
				+ "one owned ST-051 copy. Partly filled pads are allowed. No bundled stand seats, "
				+ "spectator chairs, free seats or crowd are added."
			)
		)
	)
	SeasonPages.wrapped(
		panel,
		(
			"%d seasons / %d wins • %d blueprint + %d per copy • next copy %d CB"
			% [
				entry.requires.seasons,
				entry.requires.wins,
				entry.blueprint_price,
				entry.copy_price,
				cost
			]
		)
	)
	var quote: Dictionary = StadiumPurchases.quote(
		stock, "ST-051", 1, "molded-seat-preview", StadiumMoldedSeatItems.PRICE_VERSION, progress
	)
	var buy: Button = menu._button(
		panel, "BUY " + entry.name.to_upper(), StadiumEditorUI._buy.bind(menu, "ST-051", revision)
	)
	buy.set_meta("stadium_buy", "ST-051")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
	if not quote.ok:
		buy.tooltip_text = quote.error
	pad_controls(menu, panel, ledger, draft, revision, enabled)


static func pad_controls(menu: SeasonMenu, panel: VBoxContainer, ledger: ClubAssetLedger,
	draft: Dictionary, revision: int, enabled: bool, preview: Callable = Callable()) -> void:
	var stock: StadiumStock = ledger.construction()
	if not StadiumMoldedSeatItems.has_pad(draft):
		var candidate: Dictionary = StadiumMoldedSeatItems.upgrade(draft, ledger.surface_owned())
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var opt: Button = menu._button(
			panel,
			"PREVIEW EMPTY FOUR-SOCKET PAD",
			func() -> void:
				if enabled and checked.ok:
					EditorAccess.editor_preview(menu, candidate, revision, preview)
		)
		opt.set_meta("molded_pad_preview", true)
		opt.disabled = not enabled or not checked.ok
		if not checked.ok:
			opt.tooltip_text = checked.error
	else:
		var no_seats: bool = draft.get("molded_seats", []).is_empty()
		var candidate: Dictionary = StadiumMoldedSeatItems.remove_pad(draft)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var removal: Button = menu._button(
			panel,
			"PREVIEW REMOVE EMPTY PAD",
			func() -> void:
				if enabled and no_seats and checked.ok and not StadiumMoldedSeatItems.has_pad(candidate):
					EditorAccess.editor_preview(menu, candidate, revision, preview)
		)
		removal.set_meta("molded_pad_remove", true)
		removal.disabled = (
			not enabled
			or not no_seats
			or not checked.ok
			or StadiumMoldedSeatItems.has_pad(candidate)
		)
		if not no_seats:
			removal.tooltip_text = ("Store every molded seat before removing the empty pad. All paid " + \
				"copies stay owned.")
		elif not checked.ok:
			removal.tooltip_text = checked.error
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"The fixed pad reserves its full 6 × 3 m footprint and local approach/ramp. This is "
					+ "a local access representation; no connected pedestrian route or crowd simulation is "
					+ "claimed. "
				)
				+ NIGHT_REASON
			)
		)
	)


static func card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	revision: int,
	editable: bool,
	supplied: ClubAssetLedger = null,
	preview: Callable = Callable()
) -> void:
	var ledger: ClubAssetLedger = EditorAccess.editor_ledger(menu, supplied)
	var stock: StadiumStock = ledger.construction()
	var names: Array[String] = choices()
	var selected: int = 0
	for placed: Dictionary in draft.get("molded_seats", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var candidate: Dictionary = StadiumMoldedSeatItems.place(
			draft, stock, copy, names[index], 0.0, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("molded_seats", []):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				checked.error if not checked.ok else "This exact layout cannot adopt the pad plan."
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumMoldedSeatItems.store_copy(draft, copy)
				if index == 0
				else StadiumMoldedSeatItems.place(
					draft, stock, copy, names[index], 0.0, ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)
