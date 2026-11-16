class_name StadiumLowWallUI
extends RefCounted


## Explicit whole-profile choices and separately purchased low copies. No conversion or
## auto-storage.
static func show(
	menu: SeasonMenu,
	ledger: ClubAssetLedger,
	draft: Dictionary,
	revision: int,
	editable: bool,
	buyable: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "SHORT & MIXED OUTFIELD WALLS", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Low flanks: 16 separately owned 1.625 m panels plus 7 standard 3.25 m panels. Low "
				+ "outfield: 23 low panels. The straight field footprint stays unchanged. Store the "
				+ "current back wall first. Outer plaza backdrops remain separate, out-of-play scenery. "
				+ "Daylight only."
			)
		)
	)
	var progress_rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(progress_rows, progress_rows.size())
	for material: String in StadiumWallRecipes.BACK_IDS:
		var id: String = StadiumWallPieceCatalog.identity(material, "low")
		var quote: Dictionary = ledger.wall_pieces().quote(
			id, 23, "low-wall-preview", progress, ledger.construction().capacity_count()
		)
		var button: Button = menu._button(
			panel,
			"BUY 23 LOW " + StadiumWallItemsUI.SHORT_NAMES[material].to_upper() + " PANELS",
			_buy.bind(menu, id, int(quote.get("cost", 0)), revision)
		)
		button.disabled = (
			not buyable or not quote.ok or ledger.balance() < int(quote.get("cost", 0))
		)
		button.tooltip_text = (
			(
				"Working price: "
				+ str(quote.get("cost", 0))
				+ " Club Bucks, including any unowned low blueprint. Stored, not installed."
			)
			if quote.ok
			else quote.error
		)
		for profile: String in StadiumLowWallRecipes.PROFILES:
			var candidate: Dictionary = proposal(ledger, draft, profile, material)
			var choose: Button = menu._button(
				panel,
				(
					profile.replace("_", " ").capitalize()
					+ " · "
					+ StadiumWallItemsUI.SHORT_NAMES[material]
				),
				_choose.bind(menu, candidate.get("layout", {}), revision)
			)
			choose.disabled = not editable or not candidate.ok
			choose.tooltip_text = candidate.error
	if StadiumLowWallLayout.is_family(draft):
		(
			SeasonPages
			. wrapped(
				panel,
				(
					"Store this low-wall profile before editing inherited property components. All other "
					+ "exact owned placements remain in place."
				)
			)
		)
		var stored: Dictionary = StadiumLowWallLayout.base(draft)
		var store: Button = menu._button(
			panel, "STORE COMPLETE LOW-WALL PROFILE", _choose.bind(menu, stored, revision)
		)
		store.disabled = not editable


static func proposal(
	ledger: ClubAssetLedger, draft: Dictionary, profile: String, material: String
) -> Dictionary:
	var layout: Dictionary = StadiumLowWallLayout.upgrade(draft, ledger.surface_owned())
	if layout.is_empty() or not layout.walls.back.is_empty():
		return StadiumStarterLayout._error(
			"Store the existing complete back wall first; no copies are moved automatically."
		)
	if layout.low_wall != StadiumLowWallManifest.empty():
		return StadiumStarterLayout._error(
			"Store the current low-wall profile before choosing another."
		)
	var suggested: Dictionary = StadiumLowWallManifest.suggest(
		profile, material, ledger.construction(), ledger.wall_pieces().stock
	)
	if not suggested.ok:
		return suggested
	layout.low_wall = suggested.manifest
	var checked: Dictionary = StadiumLowWallLayout.validate(
		layout,
		ledger.construction(),
		ledger.wall_pieces(),
		ledger.surface_owned(),
		ledger.view().land
	)
	return {"ok": true, "error": "", "layout": layout} if checked.ok else checked


static func _choose(menu: SeasonMenu, layout: Dictionary, revision: int) -> void:
	if not layout.is_empty():
		StadiumEditorUI.show(menu, layout, revision)


static func _buy(menu: SeasonMenu, item: String, cost: int, revision: int) -> void:
	(
		menu
		. app
		. _confirm(
			(
				(
					"Buy 23 separately owned low wall panels for %d Club Bucks, including any unowned "
					+ "low blueprint? Panels go into storage; the field does not change."
				)
				% cost
			),
			_complete_buy.bind(menu, item, revision)
		)
	)


static func _complete_buy(menu: SeasonMenu, item: String, revision: int) -> void:
	var result: Dictionary = ClubConstruction.buy_wall_pieces(menu.app.season, item, 23, revision)
	menu.app.notice = (
		"Low panels purchased and stored. Select an owned profile, save, then apply."
		if result.ok
		else result.error
	)
	StadiumEditorUI.show(menu)
