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
		var item: Dictionary = SeasonSponsorCatalog.item(receipt.item)
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
		if receipt.item == "B02":
			_college_status(window)
		var button: Button = (
			window
			. _button(
				"SELL " + item.name,
				(
					window
					. _preview
					. bind(
						window._request("sponsor_sell", {"receipt": receipt.id}),
						(
							"Sell %s for %d Cash. Remove its future effect. Already settled income stays.\n%s"
							% [item.name, floori(float(receipt.paid) / 2), item.effect]
						)
					)
				)
			)
		)
		button.set_meta("sponsor_sell", receipt.id)


static func offer(
	window: SeasonShopWindow, offer_id: String, id: String, wallet: Dictionary
) -> void:
	var item: Dictionary = SeasonSponsorCatalog.item(id)
	window._label(
		"%s • %s • %d Cash • Working\n%s" % [item.name, item.rarity, item.price, item.effect]
	)
	window._label(_timing(id))
	if id == "B02":
		_college_status(window)
	if wallet.sponsors.size() < wallet.capacity.sponsors:
		_purchase(window, offer_id, id, {})
	for receipt: Dictionary in wallet.sponsors:
		_purchase(window, offer_id, id, receipt)


static func _purchase(
	window: SeasonShopWindow, offer_id: String, id: String, old: Dictionary
) -> void:
	var item: Dictionary = SeasonSponsorCatalog.item(id)
	var review: String = (
		"Activate %s for %d Cash • Working\n%s\n%s"
		% [item.name, item.price, item.effect, _timing(id)]
	)
	var label: String = "BUY AND ACTIVATE"
	if not old.is_empty():
		var previous: Dictionary = SeasonSponsorCatalog.item(old.item)
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


static func _timing(id: String) -> String:
	if id == "F03":
		return ("Match effect, no Cash payout. Choose before confirming each at-bat. "
			+ "Defaults to normal. Gear applies first; ordinary contact quality uses the new ellipse.")
	if id in ["F02", "G04"]:
		return ("Match effect, no Cash payout. Only existing legal tag races change. "
			+ "Courier and opposing Trackside modify different parts of the same timing comparison.")
	if id == "B03":
		return (
			"Match effect, no Cash payout. Repeated pitches and later distinct recipes "
			+ "add nothing. Delivery variants count separately; only the credited pitcher's "
			+ "own releases count. No refund without the K, and no extra substitution rights."
		)
	if id == "A07":
		return (
			"Match effect, no Cash payout. A new game starts with no chain. Bonus adds "
			+ "to the Bat exit modifier; Gloves still apply once."
		)
	if id == "B02":
		return (
			"Match effect, no Cash payout. Prior earned growth counts; departing players "
			+ "stop contributing and the same returning instance restores its "
			+ "contribution. Gear workload factors still apply once."
		)
	return "Future completed games only. No guaranteed return; unfinished games pay nothing."


static func _college_status(window: SeasonShopWindow) -> void:
	var build: SeasonBuild = window.app.season.build
	var count: int = mini(4, build._book.earned_players(build.roster()).size())
	window._label(
		(
			"College eligibility now: %d / 4 players • %d%% natural-delivery reduction"
			% [count, count * 3]
		)
	)
