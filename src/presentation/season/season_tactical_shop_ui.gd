class_name SeasonTacticalShopUI
extends RefCounted


static func offer(window: SeasonShopWindow, quote: String, id: String) -> void:
	var item: Dictionary = SeasonTacticalCatalog.item(id)
	window._label(
		"%s • %d Cash • Working tactical supply\n%s" % [item.name, item.price, item.effect]
	)
	var button: Button = window._button(
		"BUY AND HOLD " + item.name,
		window._preview.bind(
			window._request("tactical_buy", {"offer": quote}),
			(
				(
					"Hold %s\n%s\nShared consumable slot. Use before the first pitch of a PA. "
					+ "No resale or refund."
				)
				% [item.name, item.effect]
			)
		)
	)
	button.set_meta("tactical_offer", quote)


static func held(window: SeasonShopWindow, receipt: Dictionary) -> void:
	var item: Dictionary = SeasonTacticalCatalog.item(receipt.item)
	window._label(
		"%s • paid %d • held for match readiness\n%s" % [item.name, receipt.paid, item.effect]
	)
	window._button(
		"DISCARD " + item.name,
		window._preview.bind(
			window._request("discard", {"receipt": receipt.id}),
			"Discard this exact " + item.name + " copy. No effect or refund."
		)
	)
