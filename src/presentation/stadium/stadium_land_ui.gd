class_name StadiumLandUI
extends RefCounted
## Expansion confirms its complete price and preserves every placed and stored copy.


static func show(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var tier: String = ledger.view().land
	var target: String = StadiumLand.next_tier(tier)
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "PROPERTY • " + StadiumLand.NAMES[tier].to_upper(), 22)
	SeasonPages.wrapped(panel, "Expansion adds land and supported sites. Your field dimensions, "
		+ "four-live-object limit, placed items and stored copies stay the same. No free objects.")
	if target.is_empty():
		return
	var warning: String = _night_change(ledger.view().stadium_active, ledger.construction(),
		tier, target, ledger)
	if not warning.is_empty():
		SeasonPages.wrapped(panel, warning)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var row: Dictionary = StadiumCatalog.LAND[target]
	var quote: Dictionary = StadiumLand.quote(tier, target, progress)
	SeasonPages.wrapped(panel, "%s • Requires %d completed seasons and %d regular-season wins" % [
		StadiumLand.NAMES[target], row.seasons, row.wins])
	var buy: Button = menu._button(panel, "EXPAND TO %s • %d CB" % [
		StadiumLand.NAMES[target].to_upper(), row.price], _confirm.bind(menu, target, ledger.revision()))
	buy.set_meta("stadium_land", target)
	buy.disabled = not enabled or not ClubConstruction.can_expand(menu.app.season) \
		or not quote.ok or ledger.balance() < row.price
	if not ClubConstruction.can_expand(menu.app.season):
		buy.tooltip_text = "Expand between seasons. Older field profiles must finish their season."
	elif not quote.ok:
		buy.tooltip_text = quote.error


static func _confirm(menu: SeasonMenu, tier: String, revision: int) -> void:
	var message: String = "Spend %d Club Bucks to expand to %s? " % [
		StadiumCatalog.LAND[tier].price, StadiumLand.NAMES[tier]]
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var warning: String = _night_change(ledger.view().stadium_active, ledger.construction(),
		ledger.view().land, tier, ledger)
	menu.app._confirm(message + warning + " No items or larger playing field included. "
		+ "Current placements and stored copies are preserved.", _buy.bind(menu, tier, revision))


static func _buy(menu: SeasonMenu, tier: String, revision: int) -> void:
	var result: Dictionary = ClubConstruction.buy_land(menu.app.season, tier, revision)
	menu.app.notice = ("Property expanded. Existing items and playing-field dimensions preserved."
		if result.ok else result.error)
	StadiumEditorUI.show(menu)


static func _night_change(layout: Dictionary, stock: StadiumStock,
	before: String, after: String, ledger: ClubAssetLedger = null) -> String:
	var previous: Dictionary = StadiumEditorUI._checked(ledger, layout, before) if ledger != null \
		else StadiumHomeLayout.validate(layout, stock, before)
	var next: Dictionary = StadiumEditorUI._checked(ledger, layout, after) if ledger != null \
		else StadiumHomeLayout.validate(layout, stock, after)
	return "Yard lights become decorative here; future home starts will be daylight-only." \
		if previous.get("night_qualified", false) and not next.get("night_qualified", false) else ""
