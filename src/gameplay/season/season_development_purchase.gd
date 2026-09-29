class_name SeasonDevelopmentPurchase
extends RefCounted
# gdlint: disable=max-returns


static func buy(build: SeasonBuild, command: Dictionary) -> String:
	var fields: Array = ["offer", "mode", "player", "pitch", "replace"]
	if build._format >= 11 and command.has("concession"):
		fields.append("concession")
	if not build._keys(command, fields):
		return "Invalid purchase fields."
	if not command.offer is String or not build._visit.offers.has(command.offer):
		return "This exact offer is no longer available."
	var item_id: String = build._visit.offers[command.offer]
	var item: Dictionary = DevelopmentShopCatalog.item(item_id)
	var concession: Dictionary = SeasonSchoolSponsors.discount(build, item_id, command)
	if not concession.error.is_empty():
		return concession.error
	if command.mode == "hold":
		if (
			not DevelopmentShopCatalog.CARDS.has(item_id)
			or command.player != ""
			or (command.pitch != "" or command.replace != "")
		):
			return "Only loose development cards can be held, without a preassigned target."
		if build.targets(item_id).is_empty():
			return "This card has no eligible current roster target."
		var quote: String = "quote:%d" % build.revision()
		var stock: Dictionary = build._bank.commit(
			{"id": quote, "rev": build._bank.revision(), "op": "stock", "offers": {quote: item_id}}
		)
		if not stock.ok:
			return stock.error
		var payment: Dictionary = {
			"id": "purchase:%d" % build.revision(),
			"rev": build._bank.revision(),
			"op": "buy",
			"offer": quote,
			"replace": "",
			"discard": [],
			"discount": concession.amount
		}
		if build._format < 11:
			payment.erase("discount")
		var purchase: Dictionary = build._bank.commit(payment)
		if not purchase.ok:
			return purchase.error
	elif command.mode == "use":
		var error: String = build._develop(item_id, command)
		if error.is_empty():
			error = build._charge(maxi(0, item.price - concession.amount))
		if not error.is_empty():
			return error
	else:
		return "Choose Buy and Hold or Buy and Use."
	build._visit.offers.erase(command.offer)
	return SeasonSchoolSponsors.consume(build, concession)
