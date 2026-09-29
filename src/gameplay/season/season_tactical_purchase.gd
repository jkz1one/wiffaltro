class_name SeasonTacticalPurchase
extends RefCounted
# gdlint: disable=max-returns
## Exact paid receipts; result consumption is part of the atomic build journal.


static func buy(build: SeasonBuild, command: Dictionary) -> String:
	if build._format < 14 or build._visit.number < build._tactical_from:
		return "Tactical supplies start at your next shop visit."
	if not build._keys(command, ["offer"]) or not command.offer is String:
		return "Choose an exact tactical offer."
	var id: String = build._visit.offers.get(command.offer, "")
	if SeasonTacticalCatalog.item(id).is_empty():
		return "This tactical offer is no longer available."
	var receipt: String = "tactical-purchase:%d" % build.revision()
	var stocked: Dictionary = (
		build
		. _bank
		. commit(
			{
				"id": receipt + ":quote",
				"rev": build._bank.revision(),
				"op": "stock",
				"offers": {receipt: id},
			}
		)
	)
	if not stocked.ok:
		return stocked.error
	var bought: Dictionary = (
		build
		. _bank
		. commit(
			{
				"id": receipt,
				"rev": build._bank.revision(),
				"op": "buy",
				"offer": receipt,
				"replace": "",
				"discard": [],
			}
		)
	)
	if not bought.ok:
		return bought.error
	build._visit.offers.erase(command.offer)
	return ""


static func settle(build: SeasonBuild, value: Variant, performance: Dictionary) -> String:
	if not value is Array or value.size() > build._bank.view().capacity.held:
		return "Invalid tactical consumption ledger."
	var appearances: int = 0
	for line: Dictionary in performance.values():
		appearances += int(line.pa)
	var receipts: Array[String] = []
	var recovered: Array[String] = []
	var previous_pa: int = 0
	for action: Variant in value:
		if (
			not action is Dictionary
			or not SeasonOwnership._keys(action, ["receipt", "player", "pa", "swing"])
		):
			return "Invalid tactical activation."
		if not action.receipt is String or receipts.has(action.receipt):
			return "A tactical copy can be consumed only once."
		var owned: Dictionary = SeasonOwnership._owned(build._bank.view(), action.receipt)
		if owned.is_empty() or not SeasonTacticalCatalog.ITEMS.has(owned.item):
			return "Consume only a tactical copy held before this game."
		if (
			not action.player is String
			or not build.roster().has(action.player)
			or not performance.has(action.player)
			or not SeasonOwnership._whole(action.pa, previous_pa + 1, appearances)
		):
			return "Choose a current player and one activation per club per PA."
		var evidence: String = "pitches" if owned.item == "C02" else "pa"
		if int(performance[action.player][evidence]) < 1:
			return "Tactical use requires actual completed-game participation."
		if owned.item == "C03":
			if action.swing not in ["swing.contact", "swing.power"]:
				return "Swing Plan requires the exact locked swing."
		elif action.swing != "":
			return "Only Swing Plan locks a swing."
		if owned.item == "C02":
			if recovered.has(action.player):
				return "Recovery Pack is limited to once per pitcher per game."
			recovered.append(action.player)
		receipts.append(action.receipt)
		previous_pa = int(action.pa)
	if receipts.is_empty():
		return ""
	var consumed: Dictionary = (
		build
		. _bank
		. commit(
			{
				"id": "tactical-use:%d" % build.revision(),
				"rev": build._bank.revision(),
				"op": "discard",
				"receipts": receipts,
			}
		)
	)
	return "" if consumed.ok else consumed.error
