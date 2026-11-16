class_name StadiumSalvageCarUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## One-time salvage payment is a complete atomic action, not an editable removal fee.


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "RUSTY COMPACT CAR", 22)
	var view: Dictionary = ledger.view()
	if not view.get("salvage_origin", {}).is_empty() and not view.get("salvage_cleared", false):
		(
			SeasonPages
			. wrapped(
				panel,
				(
					"This exact abandoned car partly straddles the left foul line. Clearing it costs 190 "
					+ "Club Bucks once and moves the same owned car into storage. It consumes all four "
					+ "live-capacity units while installed. Clearing does not unlock its blueprint or "
					+ "grant another copy."
				)
			)
		)
		var clear: Button = menu._button(
			panel, "CLEAR TO STORAGE • 190 CB", _confirm_clear.bind(menu, revision)
		)
		clear.set_meta("stadium_salvage_clear", true)
		clear.disabled = not enabled or ledger.balance() < 190
	else:
		(
			SeasonPages
			. wrapped(
				panel,
				(
					"Stored cars can return to the fixed CAR-START site at no moving fee. Closed body "
					+ "panels ricochet; a genuinely trapped, unreachable fair ball keeps its earned result "
					+ "with a minimum Single. Merely rolling under the car does not award a Double."
				)
			)
		)
	var stock: StadiumStock = ledger.construction()
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var quote: Dictionary = StadiumPurchases.quote(
		stock, "ST-005", 1, "salvage-car-preview", StadiumSalvageCarItems.PRICE_VERSION, progress
	)
	var cost: int = 190 + (0 if stock.blueprints.has("ST-005") else 620)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Ordinary Working catalog access is unchanged: seven seasons and twenty wins; 620 CB "
				+ "blueprint plus 190 CB per additional copy. Starter clearance does not bypass that "
				+ "requirement."
			)
		)
	)
	var buy: Button = menu._button(
		panel,
		"BUY ORDINARY COPY • %d CB" % cost,
		StadiumEditorUI._buy.bind(menu, "ST-005", revision)
	)
	buy.set_meta("stadium_buy", "ST-005")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
	if not quote.ok:
		buy.tooltip_text = quote.error


static func _confirm_clear(menu: SeasonMenu, revision: int) -> void:
	(
		menu
		. app
		. _confirm(
			(
				"Pay 190 Club Bucks once to clear the starter car? The same car will move into "
				+ "storage; no blueprint or duplicate is granted. This saves immediately."
			),
			_clear.bind(menu, revision)
		)
	)


static func _clear(menu: SeasonMenu, revision: int) -> void:
	var result: Dictionary = ClubConstruction.clear_salvage(menu.app.season, revision)
	menu.app.notice = (
		"Car cleared. The same owned copy is now stored." if result.ok else result.error
	)
	StadiumEditorUI.show(menu)


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
	var view: Dictionary = ledger.view()
	var uncleared: bool = (
		copy == StadiumStock.SALVAGE_COPY
		and not view.get("salvage_origin", {}).is_empty()
		and not view.get("salvage_cleared", false)
	)
	var installed: bool = false
	for placed: Dictionary in draft.get("salvage_cars", []):
		if placed.copy == copy:
			installed = true
	var choice: OptionButton = StadiumEditorUI._options(
		panel, ["Stored", "CAR-START • Left foul line"], 1 if installed else 0
	)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or uncleared
	if uncleared:
		choice.tooltip_text = "Use Clear to Storage for the one-time 190 CB salvage payment."
	var candidate: Dictionary = StadiumSalvageCarItems.place(
		draft, ledger.construction(), copy, StadiumSalvageCarItems.SITE, ledger.surface_owned()
	)
	var checked: Dictionary = StadiumHomeLayout.validate(
		candidate, ledger.construction(), view.land
	)
	choice.set_item_disabled(1, not checked.ok)
	if not checked.ok:
		choice.set_item_tooltip(1, checked.error)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
				return
			if choice.is_item_disabled(index):
				return
			var next: Dictionary = (
				StadiumSalvageCarItems.store_copy(draft, copy) if index == 0 else candidate
			)
			EditorAccess.editor_preview(menu, next, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)
