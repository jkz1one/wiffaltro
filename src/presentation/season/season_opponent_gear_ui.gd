class_name SeasonOpponentGearUI
extends RefCounted
## Read-only committed team slots, actual paid receipts and shared effects.


static func equipment(card: VBoxContainer, build: SeasonBuild) -> void:
	SeasonPages.wrapped(card, "TEAM GEAR • equipped for the next match").set_meta(
		"opponent_gear", true)
	var gear: Dictionary = build._bank.view().gear
	for slot: String in SeasonOwnership.GEAR_SLOTS:
		var owned: Dictionary = gear[slot]
		if owned.is_empty():
			SeasonPages.wrapped(card, "%s • %s" % [slot.capitalize(),
				"Empty" if slot == "misc" else "Neutral standard"])
			continue
		var item: Dictionary = SeasonGearCatalog.item(owned.item)
		var box: VBoxContainer = SeasonPlayerCard.panel(card, false)
		SeasonPages.wrapped(box, "%s • %s • paid %d Cash" % [
			slot.capitalize(), item.name, owned.paid])
		SeasonPages.wrapped(box, item.get("status", "Working") + " • " + item.effect)
