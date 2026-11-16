class_name StadiumMountedDisplayItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Complete paid rigid displays, bound to one owned host and named current-family socket.

const NIGHT_REASON: String = ("Installed ribbon, clock and PA mounts remain daylight-only until " \
	+ "their lighting and camera views are qualified.")


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "RIBBON, CLOCK & PA MOUNTS", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumMountedDisplayItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"%d mounted displays • %d owned copies"
			% [draft.get("mounted_displays", []).size(), owned_count]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Each ribbon is one rigid section on a named straight ST-030 or ST-031 front fascia, "
				+ "with stable club colors. Clock and PA choices use named sockets on an owned entrance "
				+ "gate or the legacy small manual scoreboard. Curved ribbons, arbitrary surfaces, "
				+ "ST-040 and the separate scoreboard layout families are unsupported here."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumMountedDisplayItems.ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		var cost: int = (
			int(entry.copy_price)
			+ (0 if stock.blueprints.has(item) else int(entry.blueprint_price))
		)
		SeasonPages.wrapped(
			panel,
			(
				"%s • %d seasons / %d validated wins • %d blueprint + %d per copy • next copy %d CB"
				% [
					entry.name,
					entry.requires.seasons,
					entry.requires.wins,
					entry.blueprint_price,
					entry.copy_price,
					cost
				]
			)
		)
		var quote: Dictionary = StadiumPurchases.quote(
			stock,
			item,
			1,
			"mounted-display-preview:" + item,
			StadiumMountedDisplayItems.PRICE_VERSION,
			progress
		)
		var buy: Button = menu._button(
			panel, "BUY " + entry.name.to_upper(), StadiumEditorUI._buy.bind(menu, item, revision)
		)
		buy.set_meta("stadium_buy", item)
		buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
		if not quote.ok:
			buy.tooltip_text = quote.error
	(
		SeasonPages
		. wrapped(
			panel,
			(
				StadiumMountedDisplayItems.STORE_FIRST
				+ (" Clock hands follow the game's simulation clock. The PA is silent " + \
					"visual equipment; no audio implementation is claimed. These mounts " + \
					"add no gameplay, income, score or live-object budget. ")
				+ NIGHT_REASON
			)
		)
	)


static func choices(layout: Dictionary, stock: StadiumStock, item: String) -> Array[String]:
	var result: Array[String] = ["Stored"]
	for candidate: Dictionary in StadiumMountedDisplayItems.candidates(layout, stock, item):
		result.append(candidate.host_site + " / " + candidate.host_item + " / " + candidate.socket)
	return result


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
	var item: String = stock.copies[copy].item
	var available: Array[Dictionary] = StadiumMountedDisplayItems.candidates(draft, stock, item)
	var names: Array[String] = choices(draft, stock, item)
	var selected: int = 0
	for placed: Dictionary in draft.get("mounted_displays", []):
		if placed.copy == copy:
			for index in range(available.size()):
				if (
					available[index].host == placed.host
					and available[index].socket == placed.socket
				):
					selected = index + 1
			if selected == 0:
				# Keep Store reachable after an unsaved host edit invalidates this row.
				available.append({"host": placed.host, "socket": placed.socket})
				names.append("Unavailable host / " + placed.socket)
				selected = names.size() - 1
	SeasonPages.wrapped(panel, StadiumMountedDisplayItems.STORE_FIRST)
	if available.is_empty():
		(
			SeasonPages
			. wrapped(
				panel,
				"Install a compatible exact paid host to reveal its named socket. This stored copy is retained."
			)
		)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var socket: Dictionary = available[index - 1]
		var candidate: Dictionary = StadiumMountedDisplayItems.place(
			draft, stock, copy, socket.host, socket.socket, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("mounted_displays", []):
			if (
				placed.copy == copy
				and placed.host == socket.host
				and placed.socket == socket.socket
			):
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			(
				choice
				. set_item_tooltip(
					index,
					(
						checked.error
						if not checked.ok
						else "This exact layout cannot adopt this mounted display; its copy remains stored."
					)
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
				return
			if choice.is_item_disabled(index):
				return
			if index == selected:
				return
			var candidate: Dictionary = (
				StadiumMountedDisplayItems.store_copy(draft, copy)
				if index == 0
				else StadiumMountedDisplayItems.place(
					draft,
					stock,
					copy,
					available[index - 1].host,
					available[index - 1].socket,
					ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)
