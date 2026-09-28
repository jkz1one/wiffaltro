class_name SeasonGearShopUI
extends RefCounted


static func equipped(window: SeasonShopWindow, gear: Dictionary) -> void:
	window._label("TEAM GEAR • One equipped item per slot; no spares")
	for slot: String in SeasonOwnership.GEAR_SLOTS:
		var receipt: Dictionary = gear[slot]
		if receipt.is_empty():
			window._label(slot.capitalize() + ": " + ("Empty" if slot == "misc" else "Standard"))
			continue
		var item: Dictionary = SeasonGearCatalog.item(receipt.item)
		var refund: int = floori(float(receipt.paid) / 2.0)
		window._label(
			(
				"%s: %s • Paid %d • Sell %d • %s\n%s"
				% [
					slot.capitalize(),
					item.name,
					receipt.paid,
					refund,
					item.get("status", "Working"),
					item.effect
				]
			)
		)
		var button: Button = window._button(
			"SELL " + item.name,
			window._preview.bind(
				window._request("sell_gear", {"receipt": receipt.id}),
				(
					"Sell %s for %d Cash. Restore %s.\nRemove: %s"
					% [
						item.name,
						refund,
						"empty Misc" if slot == "misc" else "standard " + slot,
						item.effect
					]
				)
			)
		)
		button.set_meta("gear_sell", receipt.id)


static func offer(window: SeasonShopWindow, offer_id: String, id: String, gear: Dictionary) -> void:
	var item: Dictionary = SeasonGearCatalog.item(id)
	var old: Dictionary = gear[item.slot]
	window._label(
		(
			"%s • %d Cash • %s\n%s"
			% [item.name, item.price, item.get("status", "Working"), item.effect]
		)
	)
	if item.slot == "ball":
		window._label(
			(
				"Scales authored lift/perforation. "
				+ "Eephus gravity arc and natural Knuckle wobble stay unchanged."
			)
		)
	var description: String = (
		"Equip %s for %d Cash.\n%s\n%s"
		% [item.name, item.price, item.get("status", "Working"), item.effect]
	)
	var replace_id: String = ""
	if not old.is_empty():
		replace_id = old.id
		var previous: Dictionary = SeasonGearCatalog.item(old.item)
		description += (
			"\nSell %s for %d Cash.\nRemove: %s\nNo spare retained."
			% [previous.name, floori(float(old.paid) / 2.0), previous.effect]
		)
	var button: Button = window._button(
		"BUY AND EQUIP" if old.is_empty() else "REVIEW REPLACEMENT",
		window._preview.bind(
			window._request("equip", {"offer": offer_id, "replace": replace_id}), description
		)
	)
	button.set_meta("gear_offer", offer_id)
	button.disabled = old.get("item", "") == id
	if button.disabled:
		button.text = "ALREADY EQUIPPED"
