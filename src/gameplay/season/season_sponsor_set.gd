class_name SeasonSponsorSet
extends RefCounted
# gdlint: disable=max-returns
## Internal ownership primitive. The season shop must derive discounts and choices.
## Only the complete candidate is published; intermediate capacity is not ownership.


static func receipt_id(transaction: String, index: int) -> String:
	return "sponsor-set:%s:%d" % [transaction.sha256_text(), index]


static func normalize(command: Dictionary) -> void:
	# JSON restores numbers as floats. Normalize only valid whole discounts, before
	# retry identity comparison; malformed choices still fail ordinary validation.
	if not command.get("purchases") is Array:
		return
	for purchase: Variant in command.purchases:
		if purchase is Dictionary and SeasonOwnership._whole(purchase.get("discount"), 0, 4):
			purchase.discount = int(purchase.discount)


static func apply(bank: SeasonOwnership, next: Dictionary, command: Dictionary) -> String:
	if not SeasonOwnership._keys(command, ["id", "rev", "op", "sales", "purchases"]):
		return "Review the complete sponsor transaction."
	if (
		not command.sales is Array
		or not command.purchases is Array
		or command.sales.size() > 32
		or command.purchases.size() > 2
		or (command.sales.is_empty() and command.purchases.is_empty())
	):
		return "Choose exact sponsor sales and at most two purchases."
	var selected: Array[String] = []
	for receipt: Variant in command.sales:
		if not SeasonOwnership._text(receipt) or selected.has(receipt):
			return "Each sponsor sale must name a different owned receipt."
		if SeasonOwnership._owned(next, receipt).get("kind") != "sponsor":
			return "Only active sponsors belong in this transaction."
		selected.append(receipt)
	var offers: Array[String] = []
	for index in range(command.purchases.size()):
		var purchase: Variant = command.purchases[index]
		if (
			not purchase is Dictionary
			or not SeasonOwnership._keys(purchase, ["offer", "discount"])
			or not SeasonOwnership._text(purchase.offer)
			or offers.has(purchase.offer)
			or not next.stock.has(purchase.offer)
		):
			return "Choose each exact sponsor offer once."
		var item: Dictionary = bank._catalog[next.stock[purchase.offer]]
		if item.kind != "sponsor":
			return "Only sponsor purchases belong in this transaction."
		if not SeasonOwnership._whole(purchase.discount, 0, mini(4, int(item.price / 4))):
			return "Invalid sponsor receipt discount."
		var identity: String = receipt_id(command.id, index)
		if bank._requests.has(identity) or identity == command.id:
			return "A generated sponsor receipt identity was already used."
		offers.append(purchase.offer)
	# All reviewed proceeds are available to the combined purchase. The caller's
	# detached candidate is discarded if a sale, purchase or final rule fails.
	for receipt: String in selected:
		var error: String = bank._sell(next, receipt)
		if not error.is_empty():
			return error
	for index in range(command.purchases.size()):
		var purchase: Dictionary = command.purchases[index]
		var error: String = bank._buy(
			next,
			{
				"id": receipt_id(command.id, index),
				"offer": purchase.offer,
				"replace": "",
				"wholesale_discount": purchase.discount
			}
		)
		if not error.is_empty():
			return error
	return ""


static func validate_peers(state: Dictionary, catalog: Dictionary) -> String:
	for active: Dictionary in state.sponsors:
		var required: String = catalog[active.item].get("peer_rarity", "")
		if required.is_empty():
			continue
		for peer: Dictionary in state.sponsors:
			if peer.id != active.id and catalog[peer.item].get("rarity", "") != required:
				return "Resolve the sponsor rarity restriction explicitly before confirming."
	return ""
