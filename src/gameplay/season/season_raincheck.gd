class_name SeasonRaincheck
extends RefCounted
# gdlint: disable=max-returns
## Working G01. Loose development reservation remains an unapproved extension.

const ITEMS: Dictionary = {
	"G01":
	{
		"name": "Raincheck Reservations",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Carry one unbought fixed-price offer to the next shop in one of its four slots. "
			+ "Protect it from rerolls. No free item, extra slot or repeat carry."
		)
	}
}


static func after(before: SeasonBuild, next: SeasonBuild, command: Dictionary) -> void:
	if next._format < 24:
		return
	if before._rain_start != null and command.op in ["buy", "equip", "sponsor_buy", "tactical_buy"]:
		var paid: int = before.cash() - next.cash()
		# Replacements refund a different owned receipt; count the actual new item's price.
		if command.op in ["equip", "sponsor_buy"]:
			var prefix: String = "sponsor-purchase:" if command.op == "sponsor_buy" else "purchase:"
			var receipt: Dictionary = SeasonOwnership._owned(
				next._bank.view(), prefix + str(before.revision())
			)
			if (
				command.op == "sponsor_buy"
				and next._format >= 28
				and (command.has("sales") or (next._format >= 32 and command.has("discard")))
			):
				receipt = SeasonOwnership._owned(
					next._bank.view(),
					SeasonSponsorSet.receipt_id("sponsor-group:%d" % before.revision(), 0)
				)
			paid = int(receipt.get("paid", 0))
		if paid >= 16:
			next._rain_earned = true
	if next._reservation.is_empty():
		return
	if SeasonSchoolSponsors.active(next, "G01").is_empty():
		next._reservation.clear()
	elif next._visit.number == next._reservation.source:
		if not next._visit.get("offers", {}).has(next._reservation.offer):
			next._reservation.clear()


static func quote(build: SeasonBuild, id: String) -> Dictionary:
	if not SeasonGearCatalog.item(id).is_empty():
		var item: Dictionary = SeasonGearCatalog.item(id)
		var pool: Dictionary = SeasonGearCatalog.eligible(
			build._bank.view().gear, 3, build._gear_progress.eligible()
		)
		return item if pool.get(item.slot, []).has(id) else {}
	if not SeasonSponsorCatalog.item(id).is_empty():
		return SeasonSponsorCatalog.item(id) if SeasonEarnedSponsors.eligible(build).has(id) else {}
	if SeasonTacticalCatalog.catalog(build._tactical_catalog_version()).has(id):
		return SeasonTacticalCatalog.catalog(build._tactical_catalog_version())[id]
	if id.begins_with("lesson.") and not build.targets(id).is_empty():
		return DevelopmentShopCatalog.item(id)
	return {}


static func available(build: SeasonBuild) -> bool:
	return (
		build._format >= 24
		and build._market == 0
		and build._visit.open
		and build._visit.number < 10
		and not SeasonSchoolSponsors.active(build, "G01").is_empty()
	)


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if build._format < 24 or build._market != 0:
		return "Raincheck is unavailable in this shop."
	if command.op == "release_reservation":
		if not build._keys(command, []):
			return "Release the exact reservation."
		if not build._reservation.is_empty():
			build._reservation.clear()
		elif not protected_offer(build).is_empty():
			build._visit.offers.erase(build._visit.rain_carried)
		else:
			return "No unbought reservation remains."
		return ""
	if not build._keys(command, ["offer"]) or not command.offer is String:
		return "Choose an exact unpurchased offer."
	if not available(build) or not build._reservation.is_empty():
		return "An active Raincheck and an empty reservation are required before a regular-season game."
	if command.offer == build._visit.get("rain_carried", ""):
		return "A carried offer cannot be reserved again."
	var id: String = build._visit.offers.get(command.offer, "")
	var item: Dictionary = quote(build, id)
	if item.is_empty():
		return "Reserve Gear, sponsors, tactical supplies or an eligible fixed-price pitch lesson."
	build._reservation = {
		"source": build._visit.number,
		"destination": build._visit.number + 1,
		"offer": command.offer,
		"item": id,
		"price": int(item.price)
	}
	return ""


static func deliver(build: SeasonBuild) -> void:
	if build._reservation.is_empty():
		return
	var held: Dictionary = build._reservation.duplicate()
	build._reservation.clear()
	if (
		held.destination != build._visit.number
		or SeasonSchoolSponsors.active(build, "G01").is_empty()
	):
		return
	var item: Dictionary = quote(build, held.item)
	# The normal first slot is its one replacement if revalidation fails.
	if item.is_empty() or int(item.price) != held.price:
		return
	var offer: String = "rain:%d:%s" % [build._visit.number, held.offer]
	build._visit["rain_carried"] = offer
	build._visit["rain_price"] = held.price
	preserve(build, {offer: held.item})


static func protected_offer(build: SeasonBuild) -> Dictionary:
	var offer: String = build._visit.get("rain_carried", "")
	if offer.is_empty() or not build._visit.get("offers", {}).has(offer):
		return {}
	return {offer: build._visit.offers[offer]}


static func preserve(build: SeasonBuild, protected: Dictionary) -> void:
	if protected.is_empty():
		return
	var offers: Dictionary = build._visit.offers
	# Prefer replacing an incidental duplicate identity, otherwise replace position zero.
	var remove: String = offers.keys()[0] if not offers.is_empty() else ""
	for key: String in offers:
		if protected.values().has(offers[key]):
			remove = key
			break
	offers.erase(remove)
	var result: Dictionary = protected.duplicate()
	result.merge(offers)
	build._visit.offers = result
