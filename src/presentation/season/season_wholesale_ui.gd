class_name SeasonWholesaleUI
extends RefCounted


static func entry(window: SeasonShopWindow) -> void:
	var build: SeasonBuild = window.app.season.build
	if SeasonSchoolSponsors.active(build, "J02").is_empty():
		return
	if build.view().shop.get("wholesale_used", false):
		window._label("Wholesale deal used this visit; ordinary purchases remain available.")
	else:
		window._button("WHOLESALE • BUY TWO", offers.bind(window))


static func offers(window: SeasonShopWindow, first: Dictionary = {}) -> void:
	window._clear()
	window._label("WHOLESALE • choose %s offer" % ("first" if first.is_empty() else "second"))
	window._label(SeasonSponsorCatalog.item("J02").effect)
	var build: SeasonBuild = window.app.season.build
	var stock: Dictionary = build.view().shop.offers
	var count: int = 0
	for offer: String in stock:
		var id: String = stock[offer]
		if SeasonWholesale.targets(build, offer).is_empty():
			continue
		if not first.is_empty():
			var first_id: String = stock.get(first.offer, "")
			if (
				offer == first.offer
				or SeasonWholesale.category(id) != SeasonWholesale.category(first_id)
			):
				continue
			if (
				SeasonWholesale.category(id) == "gear"
				and (SeasonWholesale.item(id).slot == SeasonWholesale.item(first_id).slot)
			):
				continue
		var item: Dictionary = SeasonWholesale.item(id)
		window._label("%s • %d Cash base\n%s" % [item.name, item.price, item.get("effect", "")])
		window._button("SELECT " + item.name, destinations.bind(window, offer, first)).set_meta(
			"wholesale_offer", offer
		)
		count += 1
	if count == 0:
		window._label("No eligible matching offer remains. Rerolling may change ordinary stock.")
	window._button("CANCEL WHOLESALE", window._refresh)
	window._focus_first.call_deferred()


static func destinations(window: SeasonShopWindow, offer: String, first: Dictionary) -> void:
	window._clear()
	window._label("WHOLESALE • choose exact destination and replacement")
	var build: SeasonBuild = window.app.season.build
	for target: Dictionary in SeasonWholesale.targets(build, offer):
		var callback: Callable = (
			offers.bind(window, target)
			if first.is_empty()
			else discounts.bind(window, first, target)
		)
		window._label(describe(window, target))
		window._button("SELECT DESTINATION", callback).set_meta("wholesale_target", target)
	window._button("CANCEL WHOLESALE", window._refresh)
	window._focus_first.call_deferred()


static func describe(window: SeasonShopWindow, target: Dictionary) -> String:
	var build: SeasonBuild = window.app.season.build
	var id: String = build.view().shop.offers.get(target.offer, "")
	var item: Dictionary = SeasonWholesale.item(id)
	if SeasonWholesale.category(id) == "lesson":
		return item.name + "\n" + window._target_text(item, target)
	if SeasonWholesale.category(id) == "tactical":
		return "Hold " + item.name + " • shared consumable slot; no resale or refund"
	var text: String = "Equip " if SeasonWholesale.category(id) == "gear" else "Activate "
	text += item.name
	if target.has("student"):
		text += " • Student: " + build.definition(target.student).display_name
	if target.replace.is_empty():
		text += (
			" • add to final loadout; resolve capacity before confirming"
			if build._format >= 28 and SeasonWholesale.category(id) == "sponsor"
			else " • use empty slot"
		)
	else:
		var old: Dictionary = SeasonOwnership._owned(build.view().wallet, target.replace)
		if not old.is_empty():
			text += (
				" • sell %s for %d; no reserve"
				% [SeasonWholesale.item(old.item).name, SeasonSponsorCatalog.resale(old)]
			)
	return text


static func discounts(window: SeasonShopWindow, first: Dictionary, second: Dictionary) -> void:
	var stock: Dictionary = window.app.season.build.view().shop.offers
	if not stock.has(first.offer) or not stock.has(second.offer):
		window._refresh()
		return
	var a: Dictionary = SeasonWholesale.item(stock[first.offer])
	var b: Dictionary = SeasonWholesale.item(stock[second.offer])
	if a.price != b.price:
		review(window, first, second, first.offer if a.price < b.price else second.offer)
		return
	window._clear()
	window._label("EQUAL PRICES • choose the discounted receipt")
	window._label("Paid price stays with each copy. Tactical supplies have no resale.")
	for choice: Dictionary in [first, second]:
		(
			window
			. _button(
				"DISCOUNT " + SeasonWholesale.item(stock[choice.offer]).name,
				review.bind(window, first, second, choice.offer)
			)
			. set_meta("wholesale_discount", choice.offer)
		)
	window._button("CANCEL WHOLESALE", window._refresh)
	window._focus_first.call_deferred()


static func review(
	window: SeasonShopWindow, first: Dictionary, second: Dictionary, discounted: String
) -> void:
	var stock: Dictionary = window.app.season.build.view().shop.offers
	var text: String = "WHOLESALE • one atomic purchase, once this visit\n"
	for choice: Dictionary in [first, second]:
		var item: Dictionary = SeasonWholesale.item(stock.get(choice.offer, ""))
		if item.is_empty():
			window._refresh()
			return
		var off: int = SeasonWholesale.reduction(item.price) if choice.offer == discounted else 0
		text += (
			"%s\nBase %d − discount %d = paid %d.\n%s\n%s\n"
			% [
				describe(window, choice),
				item.price,
				off,
				item.price - off,
				item.get("status", "Working"),
				item.get("effect", "")
			]
		)
	text += "Both targets must remain legal. No development, packs or other price concessions."
	window._preview(
		window._request("wholesale", {"first": first, "second": second, "discounted": discounted}),
		text
	)
