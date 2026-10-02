class_name SeasonWholesale
extends RefCounted
# gdlint: disable=max-returns
## All operations run on the build candidate. No client-supplied prices or discounts.


static func available(build: SeasonBuild) -> bool:
	return (
		build._format >= 13
		and not build._visit.get("wholesale_used", false)
		and not (SeasonSchoolSponsors.active(build, "J02").is_empty())
	)


static func category(id: String) -> String:
	if not SeasonGearCatalog.item(id).is_empty():
		return "gear"
	if not SeasonSponsorCatalog.item(id).is_empty():
		return "sponsor"
	if SeasonTacticalCatalog.catalog().has(id):
		return "tactical"
	if DevelopmentShopCatalog.item(id).get("op") == "learn":
		return "lesson"
	return ""


static func item(id: String) -> Dictionary:
	match category(id):
		"gear":
			return SeasonGearCatalog.item(id)
		"sponsor":
			return SeasonSponsorCatalog.item(id)
		"lesson":
			return DevelopmentShopCatalog.item(id)
		"tactical":
			return SeasonTacticalCatalog.item(id)
	return {}


static func targets(build: SeasonBuild, offer: String) -> Array[Dictionary]:
	var id: String = build._visit.get("offers", {}).get(offer, "")
	var result: Array[Dictionary] = []
	var wallet: Dictionary = build._bank.view()
	match category(id):
		"tactical":
			if (
				build._format >= 14
				and build._visit.number >= build._tactical_from
				and SeasonTacticalCatalog.catalog(build._tactical_catalog_version()).has(id)
			):
				result.append({"offer": offer, "replace": ""})
		"gear":
			var old: Dictionary = wallet.gear[item(id).slot]
			if old.get("item") != id:
				result.append({"offer": offer, "replace": old.get("id", "")})
		"sponsor":
			if not SeasonEarnedSponsors.eligible(build).has(id):
				return result
			var destinations: Array[String] = []
			if build._format >= 28 or wallet.sponsors.size() < wallet.capacity.sponsors:
				destinations.append("")
			for old: Dictionary in wallet.sponsors:
				destinations.append(old.id)
			for destination: String in destinations:
				if id == "J10":
					for student: String in build.roster():
						if SeasonSchoolSponsors.eligible_student(build, student):
							result.append(
								{"offer": offer, "replace": destination, "student": student}
							)
				else:
					result.append({"offer": offer, "replace": destination})
		"lesson":
			for target: Dictionary in build.targets(id):
				var selected: Dictionary = target.duplicate(true)
				selected["offer"] = offer
				result.append(selected)
	return result


static func reduction(price: int) -> int:
	return mini(4, int(price / 4))


static func purchase(build: SeasonBuild, command: Dictionary) -> String:
	var fields: Array = ["first", "second", "discounted"]
	if build._format >= 28 and command.has("sales"):
		fields.append("sales")
	if build._format >= 32 and command.has("discard"):
		fields.append("discard")
	if not available(build) or not build._keys(command, fields):
		return "No unused Wholesale deal at this visit."
	if not command.first is Dictionary or not command.second is Dictionary:
		return "Review both exact offers and destinations."
	var selections: Array = [command.first, command.second]
	var ids: Array[String] = []
	for choice: Dictionary in selections:
		if not choice.get("offer") is String or not targets(build, choice.offer).has(choice):
			return "Both offers require valid current destinations and exact replacement choices."
		ids.append(build._visit.offers[choice.offer])
	var kind: String = category(ids[0])
	if (
		command.first.offer == command.second.offer
		or (ids[0] == ids[1] and kind != "tactical")
		or kind != category(ids[1])
	):
		return "Choose two different offers in the same supported category."
	if kind == "gear" and item(ids[0]).slot == item(ids[1]).slot:
		return "Paired Gear must occupy two different equipped slots."
	if not command.discounted is String:
		return "Choose which offer receives the discount."
	var discounted: int = -1
	for index in range(2):
		if selections[index].offer == command.discounted:
			discounted = index
	if discounted < 0 or item(ids[discounted]).price > item(ids[1 - discounted]).price:
		return "Discount the cheaper item; on equal prices choose either."
	if (
		build._format >= 28
		and kind == "sponsor"
		and (
			command.has("sales")
			or command.has("discard")
			or (build._format >= 37 and ids.has("F09"))
			or ids.has("J05")
			or not SeasonSchoolSponsors.active(build, "J05").is_empty()
		)
	):
		return SeasonAssociationShop.wholesale(build, command, ids, discounted)
	if command.has("sales") or command.has("discard"):
		return "Extra sponsor sales require a sponsor pair."
	# Sell all explicitly selected OLD receipts first, so both proceeds can finance
	# the pair. The enclosing candidate rolls everything back if any later step fails.
	var replaced: Array[String] = []
	if kind != "lesson":
		for index in range(2):
			var receipt: String = selections[index].replace
			if receipt.is_empty():
				continue
			if replaced.has(receipt):
				return "An existing receipt can be replaced only once."
			replaced.append(receipt)
			var old: Dictionary = SeasonOwnership._owned(build._bank.view(), receipt)
			var sold: Dictionary = build._bank.commit(
				{
					"id": "wholesale-sale:%d:%d" % [build.revision(), index],
					"rev": build._bank.revision(),
					"op": "sell",
					"receipt": receipt,
					"discard": []
				}
			)
			if not sold.ok:
				return sold.error
			if kind == "gear":
				SeasonReclamation.sold(build, old)
			else:
				build._scholarships.erase(receipt)
	for index in range(2):
		var choice: Dictionary = selections[index]
		var discount: int = reduction(item(ids[index]).price) if index == discounted else 0
		if kind == "lesson":
			var error: String = build._develop(ids[index], choice, ":wholesale:%d" % index)
			if not error.is_empty():
				return error
		else:
			var receipt: String = "wholesale-purchase:%d:%d" % [build.revision(), index]
			var stocked: Dictionary = build._bank.commit(
				{
					"id": receipt + ":quote",
					"rev": build._bank.revision(),
					"op": "stock",
					"offers": {receipt: ids[index]}
				}
			)
			if not stocked.ok:
				return stocked.error
			var bought: Dictionary = build._bank.commit(
				{
					"id": receipt,
					"rev": build._bank.revision(),
					"op": "buy",
					"offer": receipt,
					"replace": "",
					"discard": [],
					"wholesale_discount": discount
				}
			)
			if not bought.ok:
				return bought.error
			if ids[index] == "J10":
				build._scholarships[receipt] = {"player": choice.student, "uses": 3}
	if kind == "lesson":
		var cost: int = (
			item(ids[0]).price + item(ids[1]).price - reduction(item(ids[discounted]).price)
		)
		var error: String = build._charge(cost)
		if not error.is_empty():
			return error
	for choice: Dictionary in selections:
		build._visit.offers.erase(choice.offer)
	build._visit["wholesale_used"] = true
	return ""
