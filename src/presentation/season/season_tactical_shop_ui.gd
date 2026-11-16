class_name SeasonTacticalShopUI
extends RefCounted


static func offer(window: SeasonShopWindow, quote: String, id: String) -> void:
	var item: Dictionary = SeasonTacticalCatalog.item(id)
	window._label(
		"%s • %d Cash • Working tactical supply\n%s" % [item.name, item.price, item.effect]
	)
	var button: Button = window._purchase(
		"BUY AND HOLD " + item.name,
		window._request("tactical_buy", {"offer": quote}),
		(
			(
				"Hold %s\n%s\nShared consumable slot. Use before the first pitch of a PA. "
				+ "No resale or refund."
			)
			% [item.name, item.effect]
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

	if SeasonSchoolSponsors.active(window.app.season.build, "J07").is_empty():
		return
	for target: String in SeasonTacticalExchange.TYPES:
		if receipt.item == target or not SeasonTacticalExchange.TYPES.has(receipt.item):
			continue
		var amount: int = SeasonTacticalExchange.cost(receipt.item, target)
		var target_item: Dictionary = SeasonTacticalCatalog.item(target)
		var button: Button = window._purchase(
			"PICK & MIX → %s • %d Cash" % [target_item.name, amount],
			window._request("tactical_exchange", {"receipt": receipt.id, "item": target}),
			(
				(
					"Exchange this exact %s (list %d) for %s (list %d). Pay %d Cash. "
					% [item.name, item.price, target_item.name, target_item.price, amount]
				)
				+ "Same slot; input is destroyed. No trade-down refund or resale. "
				+ "Uses Pick & Mix once this visit. Compatibility is a testing Proposal."
			)
		)
		button.set_meta("exchange_receipt", receipt.id)
		button.set_meta("exchange_target", target)
		var reason: String = SeasonTacticalExchange.reason(
			window.app.season.build, receipt.id, target
		)
		if not reason.is_empty():
			button.tooltip_text = reason
			button.disabled = true
