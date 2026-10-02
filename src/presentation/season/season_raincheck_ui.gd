class_name SeasonRaincheckUI
extends RefCounted


static func entry(window: SeasonShopWindow) -> void:
	var build: SeasonBuild = window.app.season.build
	var pending: Dictionary = build._reservation
	var protected: Dictionary = SeasonRaincheck.protected_offer(build)
	if not pending.is_empty():
		(
			window
			. _label(
				(
					"Reserved for shop %d: %s • base %d Cash. Buying or rerolling it here cancels the carry."
					% [
						pending.destination,
						SeasonRaincheck.quote(build, pending.item).get("name", pending.item),
						pending.price
					]
				)
			)
		)
	elif not protected.is_empty():
		window._label(
			(
				"RAINCHECK • %s • base %d Cash • protected from rerolls, expires after this visit."
				% [
					SeasonRaincheck.quote(build, protected.values()[0]).get(
						"name", protected.values()[0]
					),
					build._visit.rain_price
				]
			)
		)
	if not pending.is_empty() or not protected.is_empty():
		window._button(
			"RELEASE RESERVATION",
			window._preview.bind(
				window._request("release_reservation"),
				"Release this reservation. No Cash, item or free replacement is granted."
			)
		)
	if SeasonRaincheck.available(build) and pending.is_empty():
		window._button("RAINCHECK • RESERVE & LEAVE", choose.bind(window))


static func choose(window: SeasonShopWindow) -> void:
	window._clear()
	window._label("RAINCHECK • ONE UNBOUGHT OFFER FOR THE NEXT SHOP")
	(
		window
		. _label(
			(
				"Reserve and return to the season. No purchase now; one of the next shop's four slots is used. "
				+ "The base price is fixed; eventual discounts are evaluated when buying. Selling Raincheck "
				+ "before that shop opens cancels the carry. "
				+ "Buying or rerolling this offer after reopening cancels it."
			)
		)
	)
	var build: SeasonBuild = window.app.season.build
	for offer: String in build._visit.offers:
		if offer == build._visit.get("rain_carried", ""):
			continue
		var item: Dictionary = SeasonRaincheck.quote(build, build._visit.offers[offer])
		if item.is_empty():
			continue
		(
			window
			. _button(
				"RESERVE %s • base %d Cash" % [item.name, item.price],
				window._preview.bind(
					window._request("reserve_offer", {"offer": offer}),
					(
						"Reserve %s at base %d Cash and leave. No item or discount is banked."
						% [item.name, item.price]
					)
				)
			)
			. set_meta("rain_offer", offer)
		)
	(
		window
		. _label(
			"Packs and recruits cannot be reserved. Capacity and legal recipients are checked when buying."
		)
	)
	window._button("BACK TO SHOP", window._refresh)
	window._focus_first.call_deferred()


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		(
			"Raincheck Reservations • "
			+ ("SHOP ELIGIBLE" if menu.app.season.career.rain_access() else "LOCKED")
		),
		22
	)
	SeasonPages.wrapped(
		card,
		(
			"Career: buy one ordinary individual offer for at least 16 actual Cash. "
			+ "Packs, Wholesale and multiple-recipient deals do not count. "
			+ "12 Season Cash • Uncommon • Working. "
			+ ClubCollectionUI.effect(menu, "G01")
		)
	)
	if menu.app.season.build == null or menu.app.season.build._rain_start == null:
		SeasonPages.wrapped(
			card, "This older active save begins this tracking next Working season."
		)


static func purchase_review(build: SeasonBuild, command: Dictionary, result: Dictionary) -> String:
	if command.op != "buy" or not SeasonRaincheck.protected_offer(build).has(command.get("offer")):
		return ""
	var base: int = build._visit.rain_price
	var paid: int = build.cash() - int(result.after.wallet.cash)
	return "\nRaincheck base: %d Cash • discount now: %d • pay: %d." % [base, base - paid, paid]
