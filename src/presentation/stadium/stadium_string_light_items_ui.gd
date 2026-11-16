class_name StadiumStringLightItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Paid fixed DG spans. Complete candidate counts never imply qualified Night lighting.

const NIGHT_REASON: String = \
	("Installed string-light spans remain daylight-only until the complete " + \
	"rig, cameras and ball readability are qualified.")


static func choices() -> Array[String]:
	var result: Array[String] = ["Stored"]
	for site: String in StadiumStringLightItems.SITES:
		result.append(site)
	return result


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "FIXED STRING-LIGHT SPANS", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumStringLightItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"%d installed spans • %d owned copies"
			% [draft.get("string_lights", []).size(), owned_count]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Each complete ST-036 copy includes one fixed 14 m cable, fourteen warm bulbs and two "
				+ "freestanding supports. Choose only the named reference STRAIGHT-field sockets. "
				+ "Supports are included, cannot be detached or shared, and create no extra copies."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var entry: Dictionary = StadiumCatalog.item("ST-036")
	var cost: int = (
		int(entry.copy_price)
		+ (0 if stock.blueprints.has("ST-036") else int(entry.blueprint_price))
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
		stock, "ST-036", 1, "string-light-preview", StadiumStringLightItems.PRICE_VERSION, progress
	)
	var buy: Button = menu._button(
		panel, "BUY " + entry.name.to_upper(), StadiumEditorUI._buy.bind(menu, "ST-036", revision)
	)
	buy.set_meta("stadium_buy", "ST-036")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
	if not quote.ok:
		buy.tooltip_text = quote.error
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Festoon candidate: STR-LF, LD, RF, RD, BL and BR, consuming six spans. Mixed "
				+ "candidate: STR-LF, RF and BC plus separately owned rear ST-037 poles at YLIGHT-RL "
				+ "and RR. Front poles cannot substitute. STR-BC excludes BL/BR; conflicting copies "
				+ "must be explicitly stored, never hidden or deleted."
			)
		)
	)
	var profile: String = StadiumStringLightItems.complete_profile(
		draft.get("string_lights", []), draft.get("lights", [])
	)
	if not profile.is_empty():
		SeasonPages.wrapped(
			panel, "Complete candidate counts: " + profile + ". This is not Night qualification."
		)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"Moving and storing retain the same paid copies and cost no moving fee. Partial "
					+ "installations are decorative only, add no live-object or scoring authority, and "
					+ "receive no partial Night credit. "
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
	var sites: Array[String] = choices()
	var names: Array[String] = ["Stored"]
	for index in range(1, sites.size()):
		names.append(StadiumStringLightItems.site_name(sites[index]))
	var selected: int = 0
	for placed: Dictionary in draft.get("string_lights", []):
		if placed.copy == copy:
			selected = sites.find(placed.site)
			if selected < 0:
				sites.append(placed.site)
				names.append("Unavailable socket / " + placed.site)
				selected = sites.size() - 1
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, sites.size()):
		var candidate: Dictionary = StadiumStringLightItems.place(
			draft, stock, copy, sites[index], ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("string_lights", []):
			if placed.copy == copy and placed.site == sites[index]:
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
						else "This exact layout cannot install this fixed span. The copy remains owned and stored."
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
				StadiumStringLightItems.store_copy(draft, copy)
				if index == 0
				else StadiumStringLightItems.place(
					draft, stock, copy, sites[index], ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)
