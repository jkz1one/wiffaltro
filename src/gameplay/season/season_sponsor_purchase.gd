class_name SeasonSponsorPurchase
extends RefCounted
# gdlint: disable=max-returns
## Historical individual receipt identities remain frozen.


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if (
		(build._format >= 28 and command.has("sales"))
		or (build._format >= 32 and command.has("discard"))
	):
		return SeasonAssociationShop.commit(build, command)
	if build._format < 6 or build._visit.number < build._sponsor_from:
		return "Sponsors are not available at this visit."
	if command.op == "sponsor_sell":
		if not build._keys(command, ["receipt"]) or not command.receipt is String:
			return "Choose an active sponsor."
		var owned: Dictionary = SeasonOwnership._owned(build._bank.view(), command.receipt)
		if owned.get("kind") != "sponsor":
			return "Choose an active sponsor."
		var sold: Dictionary = build._bank.commit(
			{
				"id": "sponsor-sale:%d" % build.revision(),
				"rev": build._bank.revision(),
				"op": "sell",
				"receipt": command.receipt,
				"discard": []
			}
		)
		if sold.ok:
			build._scholarships.erase(command.receipt)
		return "" if sold.ok else sold.error
	if not command.get("offer") is String:
		return "Review an exact sponsor offer."
	var item_id: String = build._visit.offers.get(command.offer, "")
	if not SeasonEarnedSponsors.eligible(build).has(item_id):
		return "This sponsor offer is no longer available."
	var fields: Array = ["offer", "replace"]
	if item_id == "J10":
		fields.append("student")
		if (
			not command.get("student") is String
			or not SeasonSchoolSponsors.eligible_student(build, command.student)
		):
			return "Choose an eligible undeveloped student (unapproved Proposal)."
	if not build._keys(command, fields):
		return "Review the exact sponsor and nomination."
	# Reject same-identity replacement before sale can temporarily remove it.
	if not SeasonEarnedSponsors.eligible(build).has(item_id):
		return "That sponsor is already active."
	var quote: String = "sponsor:%d" % build.revision()
	var stock: Dictionary = build._bank.commit(
		{
			"id": quote,
			"rev": build._bank.revision(),
			"op": "stock",
			"offers": {quote: item_id}
		}
	)
	if not stock.ok:
		return stock.error
	var bought: Dictionary = build._bank.commit(
		{
			"id": "sponsor-purchase:%d" % build.revision(),
			"rev": build._bank.revision(),
			"op": "buy",
			"offer": quote,
			"replace": command.replace,
			"discard": []
		}
	)
	if not bought.ok:
		return bought.error
	build._scholarships.erase(command.replace)
	if item_id == "J10":
		build._scholarships["sponsor-purchase:%d" % build.revision()] = {
			"player": command.student, "uses": 3
		}
	build._visit.offers.erase(command.offer)
	return ""
