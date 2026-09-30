class_name SeasonAssociationShop
extends RefCounted
# gdlint: disable=max-returns
## Build28 adapter. Only trusted catalog prices and Wholesale reductions reach ownership.


static func selected(build: SeasonBuild, command: Dictionary, required: Array) -> Array:
	var extra: Variant = command.get("sales", [])
	if not extra is Array:
		return [null]
	var result: Array = required.duplicate()
	result.append_array(extra)
	var seen: Array = []
	for id: Variant in result:
		if not id is String or seen.has(id):
			return [null]
		if SeasonOwnership._owned(build._bank.view(), id).get("kind") != "sponsor":
			return [null]
		seen.append(id)
	return result


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if build._visit.number < build._sponsor_from:
		return "Sponsors are not available at this visit."
	var fields: Array = ["receipt"] if command.op == "sponsor_sell" else ["offer", "replace"]
	if command.has("sales"):
		fields.append("sales")
	var required: Array = []
	var purchases: Array = []
	if command.op == "sponsor_sell":
		required.append(command.get("receipt"))
	else:
		if not command.get("offer") is String or not command.get("replace") is String:
			return "Review an exact sponsor offer and replacement."
		var id: String = build._visit.offers.get(command.offer, "")
		if not SeasonEarnedSponsors.eligible(build).has(id):
			return "This sponsor offer is no longer available."
		var purchase: Dictionary = {"item": id, "discount": 0}
		if id == "J10":
			fields.append("student")
			if (
				not command.get("student") is String
				or not SeasonSchoolSponsors.eligible_student(build, command.student)
			):
				return "Choose an eligible undeveloped student (unapproved Proposal)."
			purchase["student"] = command.student
		purchases.append(purchase)
		if not command.replace.is_empty():
			required.append(command.replace)
	if not build._keys(command, fields):
		return "Review the exact sponsor transaction."
	var sales: Array = selected(build, command, required)
	if sales.has(null):
		return "Choose distinct active sponsor receipts for every sale."
	var error: String = apply(build, sales, purchases)
	if error.is_empty() and command.op == "sponsor_buy":
		build._visit.offers.erase(command.offer)
	return error


static func apply(build: SeasonBuild, sales: Array, purchases: Array) -> String:
	var identity: String = "sponsor-group:%d" % build.revision()
	var offers: Dictionary = {}
	var choices: Array = []
	for index in range(purchases.size()):
		var offer: String = identity + ":offer:%d" % index
		offers[offer] = purchases[index].item
		choices.append({"offer": offer, "discount": purchases[index].discount})
	if not offers.is_empty():
		var stock: Dictionary = build._bank.commit(
			{
				"id": identity + ":quote",
				"rev": build._bank.revision(),
				"op": "stock",
				"offers": offers
			}
		)
		if not stock.ok:
			return stock.error
	var result: Dictionary = build._bank.commit(
		{
			"id": identity,
			"rev": build._bank.revision(),
			"op": "sponsor_set",
			"sales": sales,
			"purchases": choices
		}
	)
	if not result.ok:
		return result.error
	for id: String in sales:
		build._scholarships.erase(id)
	for index in range(purchases.size()):
		if purchases[index].item == "J10":
			build._scholarships[SeasonSponsorSet.receipt_id(identity, index)] = {
				"player": purchases[index].student, "uses": 3
			}
	return ""


static func wholesale(
	build: SeasonBuild, command: Dictionary, ids: Array[String], discounted: int
) -> String:
	var required: Array = []
	var purchases: Array = []
	var selections: Array = [command.first, command.second]
	for index in range(2):
		var choice: Dictionary = selections[index]
		if not choice.replace.is_empty():
			required.append(choice.replace)
		var purchase: Dictionary = {
			"item": ids[index],
			"discount":
			(
				SeasonWholesale.reduction(SeasonWholesale.item(ids[index]).price)
				if index == discounted
				else 0
			)
		}
		if ids[index] == "J10":
			purchase["student"] = choice.student
		purchases.append(purchase)
	var sales: Array = selected(build, command, required)
	if sales.has(null):
		return "Each old sponsor can be sold only once."
	var error: String = apply(build, sales, purchases)
	if not error.is_empty():
		return error
	for choice: Dictionary in selections:
		build._visit.offers.erase(choice.offer)
	build._visit["wholesale_used"] = true
	return ""


static func review(before: Dictionary, after: Dictionary) -> String:
	var lines: PackedStringArray = []
	for receipt: Dictionary in before.sponsors:
		if SeasonOwnership._owned(after, receipt.id).is_empty():
			var item: Dictionary = SeasonSponsorCatalog.item(receipt.item)
			lines.append(
				(
					"Sell %s • %d Cash\nRemove: %s"
					% [item.name, SeasonSponsorCatalog.resale(receipt), item.effect]
				)
			)
	if (
		lines.is_empty()
		and before.sponsors.size() == after.sponsors.size()
		and before.capacity.sponsors == after.capacity.sponsors
	):
		return ""
	return (
		"\n"
		+ "\n".join(lines)
		+ (
			"\nActive sponsors: %d / %d. No reserves."
			% [after.sponsors.size(), after.capacity.sponsors]
		)
	)
