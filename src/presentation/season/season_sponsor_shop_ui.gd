class_name SeasonSponsorShopUI
extends RefCounted


static func active(window: SeasonShopWindow, wallet: Dictionary) -> void:
	window._label(
		(
			"ACTIVE SPONSORS • %d / %d • No reserves"
			% [wallet.sponsors.size(), wallet.capacity.sponsors]
		)
	)
	for receipt: Dictionary in wallet.sponsors:
		var item: Dictionary = SeasonSponsorCatalog.ITEMS[receipt.item]
		window._label(
			(
				"%s • %s • Working • Paid %d • Sell %d\n%s"
				% [
					item.name,
					item.rarity,
					receipt.paid,
					floori(float(receipt.paid) / 2),
					item.effect
				]
			)
		)
		var button: Button = window._button(
			"SELL " + item.name,
			window._preview.bind(
				window._request("sponsor_sell", {"receipt": receipt.id}),
				(
					"Sell %s for %d Cash. Remove future earnings. Already settled income stays.\n%s"
					% [item.name, floori(float(receipt.paid) / 2), item.effect]
				)
			)
		)
		button.set_meta("sponsor_sell", receipt.id)


static func offer(
	window: SeasonShopWindow, offer_id: String, id: String, wallet: Dictionary
) -> void:
	var item: Dictionary = SeasonSponsorCatalog.ITEMS[id]
	window._label(
		"%s • %s • %d Cash • Working\n%s" % [item.name, item.rarity, item.price, item.effect]
	)
	window._label(
		"Future completed games only. No guaranteed return; unfinished games pay nothing."
	)
	if wallet.sponsors.size() < wallet.capacity.sponsors:
		_purchase(window, offer_id, id, {})
	for receipt: Dictionary in wallet.sponsors:
		_purchase(window, offer_id, id, receipt)


static func _purchase(
	window: SeasonShopWindow, offer_id: String, id: String, old: Dictionary
) -> void:
	var item: Dictionary = SeasonSponsorCatalog.ITEMS[id]
	var review: String = (
		"Activate %s for %d Cash • Working\n%s\nFuture completed games only."
		% [item.name, item.price, item.effect]
	)
	var label: String = "BUY AND ACTIVATE"
	if not old.is_empty():
		var previous: Dictionary = SeasonSponsorCatalog.ITEMS[old.item]
		label = "REPLACE " + previous.name
		review += (
			"\nSell %s for %d Cash. Remove: %s\nNo reserve retained."
			% [previous.name, floori(float(old.paid) / 2), previous.effect]
		)
	var button: Button = window._button(
		label,
		window._preview.bind(
			window._request("sponsor_buy", {"offer": offer_id, "replace": old.get("id", "")}),
			review
		)
	)
	button.set_meta("sponsor_offer", offer_id)
	button.set_meta("sponsor_replace", old.get("id", ""))
