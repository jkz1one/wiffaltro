class_name StadiumPlayerTunnelItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Exact paid tunnel choices keep structural hosts and restored caps explicit.

const NIGHT_REASON: String = ("The player tunnel is daylight-only until its lighting and camera " \
	+ "views are qualified.")


static func choices() -> Array[String]:
	return ["Stored", "TUNNEL-L", "TUNNEL-R"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "COVERED PLAYER ENTRANCE TUNNEL", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumPlayerTunnelItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Player tunnel sites: %d of 2 filled • %d owned copies"
			% [draft.get("player_tunnels", []).size(), owned_count]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Each complete ST-058 copy needs Club or Mogul property, a separately owned ST-074 "
				+ "concrete dugout and a separately owned ST-029 at BASE-L1 or BASE-R1 on the same "
				+ "side. The symmetric shell, turn, roof, supports and capped unused port are included; "
				+ "they create no extra copies."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var entry: Dictionary = StadiumCatalog.item("ST-058")
	var cost: int = (
		int(entry.copy_price)
		+ (0 if stock.blueprints.has("ST-058") else int(entry.blueprint_price))
	)
	SeasonPages.wrapped(
		panel,
		(
			"%s • 12 seasons / 36 validated wins • %d blueprint + %d per copy • next copy %d CB"
			% [entry.name, entry.blueprint_price, entry.copy_price, cost]
		)
	)
	var quote: Dictionary = StadiumPurchases.quote(
		stock,
		"ST-058",
		1,
		"player-tunnel-preview",
		StadiumPlayerTunnelItems.PRICE_VERSION,
		progress
	)
	var buy: Button = menu._button(
		panel, "BUY " + entry.name.to_upper(), StadiumEditorUI._buy.bind(menu, "ST-058", revision)
	)
	buy.set_meta("stadium_buy", "ST-058")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
	if not quote.ok:
		buy.tooltip_text = quote.error
	(
		SeasonPages
		. wrapped(
			panel,
			(
				StadiumPlayerTunnelItems.STORE_FIRST
				+ (" Restoring a host never places the tunnel automatically. This passage " + \
					"stays behind the existing dead boundary, adds no scoring aperture, " + \
					"live-object unit or gameplay award, and includes no player walkout " + "simulation. ")
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
	for placed: Dictionary in draft.get("player_tunnels", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	SeasonPages.wrapped(panel, StadiumPlayerTunnelItems.STORE_FIRST)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var host: Dictionary = StadiumPlayerTunnelItems.host_info(draft, stock, names[index])
		var candidate: Dictionary = StadiumPlayerTunnelItems.place(
			draft, stock, copy, names[index], 0.0, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("player_tunnels", []):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				(
					checked.error
					if not checked.ok
					else (
						host.error
						if not host.ok
						else "Store the installed copy before choosing another site."
					)
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumPlayerTunnelItems.store_copy(draft, copy)
				if index == 0
				else StadiumPlayerTunnelItems.place(
					draft, stock, copy, names[index], 0.0, ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)
